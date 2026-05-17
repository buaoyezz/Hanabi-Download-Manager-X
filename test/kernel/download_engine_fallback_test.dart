import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_managerx/services/kernel/next/downloader/download_engine.dart';
import 'package:hanabi_download_managerx/services/kernel/next/downloader/http_client.dart';
import 'package:hanabi_download_managerx/services/kernel/next/models/segment.dart';
import 'package:hanabi_download_managerx/services/kernel/next/models/task.dart';
import 'package:path/path.dart' as p;

void main() {
  test('segmented download writes directly to final temp output', () async {
    final payload = Uint8List.fromList(
      List<int>.generate(6 * 1024 * 1024, (index) => (index * 7) % 251),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    unawaited(() async {
      await for (final request in server) {
        await _serveRangeDownload(request, payload);
      }
    }());

    final tempRoot = await Directory.systemTemp.createTemp('nsfx_engine_');
    final config = NsfxConfig(
      mode: 'manual',
      threads: 3,
      segments: 3,
      maxRetries: 1,
      enableDynamicSegments: false,
    );
    final rootClient = NsfxHttpClient(config);

    try {
      const taskId = 'direct-output';
      final outputPath = p.join(tempRoot.path, 'file.bin');
      final tempDir = Directory(p.join(tempRoot.path, '.nsfx_temp', taskId));
      final task = Task(
        id: taskId,
        url: 'http://${server.address.host}:${server.port}/file.bin',
        filename: 'file.bin',
        filepath: outputPath,
      );

      final errors = <Task>[];
      var completed = false;
      final engine = DownloadEngine(
        config: config,
        httpClient: rootClient,
        onProgress: (_) {},
        onComplete: (_) => completed = true,
        onError: errors.add,
      );

      await engine.startDownload(task).timeout(const Duration(seconds: 10));

      expect(errors, isEmpty);
      expect(completed, isTrue);
      expect(task.status, TaskStatus.completed);
      expect(await File(outputPath).readAsBytes(), payload);
      expect(await tempDir.exists(), isFalse);
      expect(
        await Directory(p.join(tempRoot.path, '.nsfx_temp')).exists(),
        isTrue,
      );
      expect(
        Directory(p.join(tempRoot.path, '.nsfx_temp'))
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.contains('.part')),
        isEmpty,
      );
    } finally {
      rootClient.close();
      await server.close(force: true);
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
  });

  test('segmented resume migrates legacy part files into direct output',
      () async {
    final payload = Uint8List.fromList(
      List<int>.generate(6 * 1024 * 1024, (index) => (index * 11) % 251),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    unawaited(() async {
      await for (final request in server) {
        await _serveRangeDownload(request, payload);
      }
    }());

    final tempRoot = await Directory.systemTemp.createTemp('nsfx_engine_');
    final config = NsfxConfig(
      mode: 'manual',
      threads: 3,
      segments: 3,
      maxRetries: 1,
      enableDynamicSegments: false,
    );
    final rootClient = NsfxHttpClient(config);

    try {
      const taskId = 'legacy-part-resume';
      final outputPath = p.join(tempRoot.path, 'file.bin');
      final tempDir = Directory(p.join(tempRoot.path, '.nsfx_temp', taskId));
      await tempDir.create(recursive: true);

      final segmentSize = payload.length ~/ 3;
      final restoredBytes = segmentSize ~/ 2;
      await File(p.join(tempDir.path, 'task_$taskId.part0')).writeAsBytes(
        payload.sublist(0, restoredBytes),
      );

      final task = Task(
        id: taskId,
        url: 'http://${server.address.host}:${server.port}/file.bin',
        filename: 'file.bin',
        filepath: outputPath,
        status: TaskStatus.pending,
        totalSize: payload.length,
        downloadedSize: restoredBytes,
        segments: [
          Segment(
            index: 0,
            startByte: 0,
            endByte: segmentSize,
            downloadedBytes: restoredBytes,
          ),
          Segment(
            index: 1,
            startByte: segmentSize,
            endByte: segmentSize * 2,
          ),
          Segment(
            index: 2,
            startByte: segmentSize * 2,
            endByte: payload.length,
          ),
        ],
      );

      final errors = <Task>[];
      var completed = false;
      final engine = DownloadEngine(
        config: config,
        httpClient: rootClient,
        onProgress: (_) {},
        onComplete: (_) => completed = true,
        onError: errors.add,
      );

      await engine.startDownload(task).timeout(const Duration(seconds: 10));

      expect(errors, isEmpty);
      expect(completed, isTrue);
      expect(task.status, TaskStatus.completed);
      expect(await File(outputPath).readAsBytes(), payload);
      expect(await tempDir.exists(), isFalse);
      expect(
        await File(p.join(tempDir.path, 'task_$taskId.part0')).exists(),
        isFalse,
      );
    } finally {
      rootClient.close();
      await server.close(force: true);
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
  });

  test(
      'segmented resume falls back to single-thread restart when range is ignored',
      () async {
    final payload = Uint8List.fromList(
      List<int>.generate(1152 * 1024, (index) => index % 251),
    );
    final seenRequests = <_SeenRequest>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    unawaited(() async {
      await for (final request in server) {
        await _serveRangeThenIgnoreResumeProbe(
          request,
          payload,
          seenRequests,
        );
      }
    }());

    final tempRoot = await Directory.systemTemp.createTemp('nsfx_engine_');
    final config = NsfxConfig(
      mode: 'manual',
      threads: 2,
      segments: 2,
      maxRetries: 1,
      enableDynamicSegments: false,
    );
    final rootClient = NsfxHttpClient(config);

    try {
      const taskId = 'resume-fallback';
      final outputPath = p.join(tempRoot.path, 'file.bin');
      final tempDir = Directory(p.join(tempRoot.path, '.nsfx_temp', taskId));
      await tempDir.create(recursive: true);

      final firstSegmentEnd = payload.length ~/ 2;
      const restoredBytes = 64 * 1024;
      await File(p.join(tempDir.path, 'task_$taskId.part0')).writeAsBytes(
        payload.sublist(0, restoredBytes),
      );

      final task = Task(
        id: taskId,
        url: 'http://${server.address.host}:${server.port}/file.bin',
        filename: 'file.bin',
        filepath: outputPath,
        status: TaskStatus.pending,
        totalSize: payload.length,
        downloadedSize: restoredBytes,
        segments: [
          Segment(
            index: 0,
            startByte: 0,
            endByte: firstSegmentEnd,
            downloadedBytes: restoredBytes,
          ),
          Segment(
            index: 1,
            startByte: firstSegmentEnd,
            endByte: payload.length,
          ),
        ],
      );

      final errors = <Task>[];
      var completed = false;
      final engine = DownloadEngine(
        config: config,
        httpClient: rootClient,
        onProgress: (_) {},
        onComplete: (_) => completed = true,
        onError: errors.add,
      );

      await engine.startDownload(task).timeout(const Duration(seconds: 10));

      expect(errors, isEmpty);
      expect(completed, isTrue);
      expect(task.status, TaskStatus.completed);
      expect(task.threadCount, 1);
      expect(task.segments, isEmpty);
      expect(task.resumeDecisionLabel, 'Single Restart');
      expect(task.resumeDecisionReason, contains('Restarting from zero'));
      expect(await tempDir.exists(), isFalse);
      expect(await File(outputPath).readAsBytes(), payload);
      expect(
        seenRequests.any((request) => request.range == 'bytes=0-0'),
        isTrue,
      );
      expect(
        seenRequests.any((request) => request.range == 'bytes=1-1'),
        isTrue,
      );
      expect(
        seenRequests.any(
          (request) => request.range == null && request.ifRange != null,
        ),
        isFalse,
      );
    } finally {
      rootClient.close();
      await server.close(force: true);
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
  });
}

Future<void> _serveRangeDownload(
  HttpRequest request,
  Uint8List payload,
) async {
  final response = request.response;
  response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
  response.headers
      .set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
  response.headers.set(HttpHeaders.etagHeader, '"direct-etag"');

  final range = request.headers.value(HttpHeaders.rangeHeader);
  if (range == null) {
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.contentLengthHeader, '${payload.length}');
    response.add(payload);
    await response.close();
    return;
  }

  final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range);
  if (match == null) {
    response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
    await response.close();
    return;
  }

  final start = int.parse(match.group(1)!);
  final requestedEnd = match.group(2);
  final end = requestedEnd == null || requestedEnd.isEmpty
      ? payload.length - 1
      : int.parse(requestedEnd);

  if (start < 0 || start >= payload.length || end < start) {
    response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
    response.headers
        .set(HttpHeaders.contentRangeHeader, 'bytes */${payload.length}');
    await response.close();
    return;
  }

  final clampedEnd = end.clamp(start, payload.length - 1);
  response.statusCode = HttpStatus.partialContent;
  response.headers.set(
    HttpHeaders.contentRangeHeader,
    'bytes $start-$clampedEnd/${payload.length}',
  );
  response.headers
      .set(HttpHeaders.contentLengthHeader, '${clampedEnd - start + 1}');
  response.add(payload.sublist(start, clampedEnd + 1));
  await response.close();
}

Future<void> _serveRangeThenIgnoreResumeProbe(
  HttpRequest request,
  Uint8List payload,
  List<_SeenRequest> seenRequests,
) async {
  final range = request.headers.value(HttpHeaders.rangeHeader);
  final ifRange = request.headers.value('if-range');
  seenRequests.add(_SeenRequest(range: range, ifRange: ifRange));

  final response = request.response;
  response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
  response.headers
      .set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
  response.headers.set(HttpHeaders.etagHeader, '"resume-etag"');

  if (range == 'bytes=0-0') {
    response.statusCode = HttpStatus.partialContent;
    response.headers
        .set(HttpHeaders.contentRangeHeader, 'bytes 0-0/${payload.length}');
    response.headers.set(HttpHeaders.contentLengthHeader, '1');
    response.add(payload.sublist(0, 1));
    await response.close();
    return;
  }

  if (range != null) {
    response.statusCode = HttpStatus.ok;
    response.headers.set(HttpHeaders.contentLengthHeader, '${payload.length}');
    response.add(payload);
    await response.close();
    return;
  }

  response.statusCode = HttpStatus.ok;
  response.headers.set(HttpHeaders.contentLengthHeader, '${payload.length}');
  response.add(payload);
  await response.close();
}

class _SeenRequest {
  const _SeenRequest({
    required this.range,
    required this.ifRange,
  });

  final String? range;
  final String? ifRange;
}
