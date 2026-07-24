import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/download_engine.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/http_client.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/models/segment.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/models/task.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/storage/task_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  // Do not call TestWidgetsFlutterBinding.ensureInitialized() here:
  // it stubs HttpClient and breaks real local-server download tests.

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('nsfx_p2_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('P2: hasRecoverablePartialData', () {
    test('detects multi-segment part files', () async {
      final engine = _buildEngine();
      const taskId = 'recover-parts';
      final filepath = p.join(tempRoot.path, 'a.bin');
      final task = Task(
        id: taskId,
        url: 'http://127.0.0.1/a.bin',
        filename: 'a.bin',
        filepath: filepath,
        totalSize: 1000,
        segments: [
          Segment(index: 0, startByte: 0, endByte: 500),
          Segment(index: 1, startByte: 500, endByte: 1000),
        ],
      );

      expect(await engine.hasRecoverablePartialData(task), isFalse);

      final tempDir = Directory(p.join(tempRoot.path, '.nsfx_temp', taskId));
      await tempDir.create(recursive: true);
      await File(p.join(tempDir.path, 'task_$taskId.part0'))
          .writeAsBytes(List<int>.filled(120, 1));

      expect(await engine.hasRecoverablePartialData(task), isTrue);
    });

    test('detects incomplete single-thread file', () async {
      final engine = _buildEngine();
      final filepath = p.join(tempRoot.path, 'b.bin');
      await File(filepath).writeAsBytes(List<int>.filled(40, 2));
      final task = Task(
        id: 'recover-single',
        url: 'http://127.0.0.1/b.bin',
        filename: 'b.bin',
        filepath: filepath,
        totalSize: 100,
      );

      expect(await engine.hasRecoverablePartialData(task), isTrue);
    });
  });

  group('P2: task persistence isolation', () {
    test('queued writes persist the state captured at save time', () async {
      final storage = TaskStorage(homePath: tempRoot.path);
      final task = Task(
        id: 'snapshot-task',
        url: 'https://example.com/snapshot.bin',
        filename: 'snapshot.bin',
        filepath: p.join(tempRoot.path, 'snapshot.bin'),
        status: TaskStatus.pending,
      );

      final pendingWrite = storage.saveTasks({'snapshot-task': task});
      task.status = TaskStatus.downloading;
      task.downloadedSize = 4096;
      await pendingWrite;

      final restored = await TaskStorage(homePath: tempRoot.path).loadTasks();
      expect(restored['snapshot-task']!.status, TaskStatus.pending);
      expect(restored['snapshot-task']!.downloadedSize, 0);
    });

    test('one malformed task does not hide valid resumable tasks', () async {
      final storage = TaskStorage(homePath: tempRoot.path);
      final valid = Task(
        id: 'valid-task',
        url: 'https://example.com/file.bin',
        filename: 'file.bin',
        filepath: p.join(tempRoot.path, 'file.bin'),
        totalSize: 1000,
        downloadedSize: 250,
        measuredTransferBytes: 320,
        activeTransferMicros: 800000,
        averageSpeed: 400,
        expectedSizeHint: 1000,
        segments: [
          Segment(
            index: 0,
            startByte: 0,
            endByte: 1000,
            downloadedBytes: 250,
            status: SegmentStatus.failed,
            lastError: 'connection reset',
          ),
        ],
      );
      await storage.saveTasks({'valid-task': valid});

      final tasksFile = File(
        p.join(tempRoot.path, '.hdmx', 'kernel', 'tasks.json'),
      );
      final json =
          jsonDecode(await tasksFile.readAsString()) as Map<String, dynamic>;
      json['broken-task'] = {'id': null, 'url': 123};
      await tasksFile.writeAsString(jsonEncode(json), flush: true);

      final restored = await TaskStorage(homePath: tempRoot.path).loadTasks();

      expect(restored.keys, contains('valid-task'));
      expect(restored.keys, isNot(contains('broken-task')));
      expect(restored['valid-task']!.resumeDataOrigin,
          NsfxResumeDataOrigin.persisted);
      expect(restored['valid-task']!.measuredTransferBytes, 320);
      expect(restored['valid-task']!.activeTransferMicros, 800000);
      expect(restored['valid-task']!.averageSpeed, 400);
      expect(restored['valid-task']!.expectedSizeHint, 1000);
      expect(
        restored['valid-task']!.segments.single.lastError,
        'connection reset',
      );
    });
  });

  group('P2: single-thread resume fail-preserve', () {
    test('HTTP 200 on range resume keeps partial file and fails task',
        () async {
      final payload = _patternBytes(256 * 1024);
      final server = await _startServer(
        payload,
        ignoreRange: true, // always 200 full body
      );
      addTearDown(() async {
        await server.close(force: true);
      });

      final filepath = p.join(tempRoot.path, 'partial.bin');
      final existing = payload.sublist(0, 50 * 1024);
      await File(filepath).writeAsBytes(existing);

      final failed = Completer<Task>();
      final config = NsfxConfig(
        threads: 1,
        enableDynamicSegments: false,
        maxRetries: 2,
        connectionTimeout: 10,
      );
      final engine = DownloadEngine(
        config: config,
        httpClient: NsfxHttpClient(config),
        onProgress: (_) {},
        onComplete: (_) {},
        onError: (task) {
          if (!failed.isCompleted) failed.complete(task);
        },
      );

      final task = Task(
        id: 'task-200-preserve',
        url: 'http://127.0.0.1:${server.port}/partial.bin',
        filename: 'partial.bin',
        filepath: filepath,
        totalSize: payload.length,
        downloadedSize: existing.length,
      );

      unawaited(engine.startDownload(task));
      final done = await failed.future.timeout(const Duration(seconds: 20));

      expect(done.status, TaskStatus.failed);
      expect(done.errorMessage, contains('HTTP 200'));
      expect(await File(filepath).exists(), isTrue);
      expect(await File(filepath).length(), existing.length);
      expect(await File(filepath).readAsBytes(), existing);
      expect(done.downloadedSize, existing.length);
    });

    test('range-ignored server keeps partial bytes on resume attempt',
        () async {
      final payload = _patternBytes(128 * 1024);
      final server = await _startServer(payload, ignoreRange: true);
      addTearDown(() async {
        await server.close(force: true);
      });

      final filepath = p.join(tempRoot.path, 'norange.bin');
      final existing = payload.sublist(0, 20 * 1024);
      await File(filepath).writeAsBytes(existing);

      final failed = Completer<Task>();
      final config = NsfxConfig(
        threads: 1,
        enableDynamicSegments: false,
        maxRetries: 2,
        connectionTimeout: 10,
      );
      final engine = DownloadEngine(
        config: config,
        httpClient: NsfxHttpClient(config),
        onProgress: (_) {},
        onComplete: (_) {},
        onError: (task) {
          if (!failed.isCompleted) failed.complete(task);
        },
      );

      final task = Task(
        id: 'task-no-range-preserve',
        url: 'http://127.0.0.1:${server.port}/norange.bin',
        filename: 'norange.bin',
        filepath: filepath,
        totalSize: payload.length,
        downloadedSize: existing.length,
      );

      unawaited(engine.startDownload(task));
      final done = await failed.future.timeout(const Duration(seconds: 20));

      expect(done.status, TaskStatus.failed);
      expect(await File(filepath).length(), existing.length);
      expect(done.downloadedSize, existing.length);
    });
  });

  group('P2: merge journal + continuity contracts', () {
    test('successful multi-segment merge leaves no journal or parts', () async {
      final payload = _patternBytes(2 * 1024 * 1024);
      final server = await _startServer(payload);
      addTearDown(() async {
        await server.close(force: true);
      });

      final filepath = p.join(tempRoot.path, 'merge.bin');
      final completed = Completer<Task>();
      final failed = Completer<String>();
      final config = NsfxConfig(
        threads: 4,
        mode: 'manual',
        segments: 4,
        enableDynamicSegments: false,
        maxRetries: 5,
        connectionTimeout: 10,
      );
      final engine = DownloadEngine(
        config: config,
        httpClient: NsfxHttpClient(config),
        onProgress: (_) {},
        onComplete: (task) {
          if (!completed.isCompleted) completed.complete(task);
        },
        onError: (task) {
          if (!failed.isCompleted) {
            failed.complete(task.errorMessage ?? 'error');
          }
        },
      );

      final task = Task(
        id: 'task-merge-journal',
        url: 'http://127.0.0.1:${server.port}/merge.bin',
        filename: 'merge.bin',
        filepath: filepath,
      );

      unawaited(engine.startDownload(task));
      await Future.any<Object>([
        completed.future,
        failed.future.then((e) => throw TestFailure(e)),
      ]).timeout(const Duration(seconds: 60));

      expect(await File(filepath).exists(), isTrue);
      expect(await File(filepath).length(), payload.length);
      expect(await File('$filepath.nsfx_merging').exists(), isFalse);

      final tempDir =
          Directory(p.join(tempRoot.path, '.nsfx_temp', 'task-merge-journal'));
      expect(await tempDir.exists(), isFalse);
    });

    test('engine source enforces continuity verification and merge journal',
        () async {
      final source = await File(
        p.join(
          Directory.current.path,
          'lib',
          'services',
          'kernel',
          'next',
          'downloader',
          'download_engine.dart',
        ),
      ).readAsString();

      expect(source.contains('_verifySegmentContinuity'), isTrue);
      expect(source.contains('_writeMergeJournal'), isTrue);
      expect(source.contains('merge.journal'), isTrue);
      expect(source.contains('_failSingleThreadPreservingPartial'), isTrue);
      expect(
        source.contains('restarted from zero'),
        isFalse,
      );
    });

    test('kernel recovery scans partial data beyond active statuses', () async {
      final source = await File(
        p.join(
          Directory.current.path,
          'lib',
          'services',
          'kernel',
          'next',
          'nsfx_kernel.dart',
        ),
      ).readAsString();

      expect(source.contains('hasRecoverablePartialData'), isTrue);
      expect(source.contains('disk-calibrated'), isTrue);
      expect(source.contains('_saveTasksInBackground'), isTrue);
      expect(source.contains("enteredMerging"), isTrue);
      expect(source.contains("'merging'"), isTrue);
    });
  });

  group('P2: discard merge journal with artifact', () {
    test('discardIncompleteMergeArtifact removes journal file', () async {
      final engine = _buildEngine();
      const taskId = 'task-journal-clean';
      final filepath = p.join(tempRoot.path, 'j.bin');
      final task = Task(
        id: taskId,
        url: 'http://127.0.0.1/j.bin',
        filename: 'j.bin',
        filepath: filepath,
      );

      final tempDir = Directory(p.join(tempRoot.path, '.nsfx_temp', taskId));
      await tempDir.create(recursive: true);
      final journal = File(p.join(tempDir.path, 'merge.journal'));
      await journal.writeAsString('{"phase":"merging"}');
      final merging = File('$filepath.nsfx_merging');
      await merging.writeAsBytes(const [1, 2, 3]);

      await engine.discardIncompleteMergeArtifact(task);

      expect(await journal.exists(), isFalse);
      expect(await merging.exists(), isFalse);
    });
  });
}

DownloadEngine _buildEngine() {
  final config = NsfxConfig(threads: 1, enableDynamicSegments: false);
  return DownloadEngine(
    config: config,
    httpClient: NsfxHttpClient(config),
    onProgress: (_) {},
    onComplete: (_) {},
    onError: (_) {},
  );
}

Uint8List _patternBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = i & 0xFF;
  }
  return bytes;
}

Future<HttpServer> _startServer(
  List<int> payload, {
  bool ignoreRange = false,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      final total = payload.length;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

      if (request.method == 'HEAD') {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentLength = total;
        request.response.headers.set(
          HttpHeaders.acceptRangesHeader,
          ignoreRange ? 'none' : 'bytes',
        );
        await request.response.close();
        return;
      }

      if (!ignoreRange &&
          rangeHeader != null &&
          rangeHeader.startsWith('bytes=')) {
        final spec = rangeHeader.substring('bytes='.length);
        final parts = spec.split('-');
        final start = int.tryParse(parts[0]) ?? 0;
        var end = parts.length > 1 && parts[1].isNotEmpty
            ? (int.tryParse(parts[1]) ?? (total - 1))
            : (total - 1);
        if (end >= total) end = total - 1;
        final slice = payload.sublist(start, end + 1);
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$total',
        );
        request.response.headers.contentLength = slice.length;
        request.response.add(slice);
        await request.response.close();
        return;
      }

      // Full body 200 (also used when ignoreRange=true for resume probes)
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.set(
        HttpHeaders.acceptRangesHeader,
        ignoreRange ? 'none' : 'bytes',
      );
      request.response.headers.contentLength = total;
      request.response.add(payload);
      await request.response.close();
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    }
  });
  return server;
}
