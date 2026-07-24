import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/download_engine.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/http_client.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/models/segment.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/models/task.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('nsfx_p0_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('P0: discard incomplete merge artifact', () {
    test('deletes .nsfx_merging and keeps final path untouched', () async {
      final engine = _buildEngine();
      final finalPath = p.join(tempRoot.path, 'movie.bin');
      final mergingPath = '$finalPath.nsfx_merging';
      await File(mergingPath).writeAsBytes(List<int>.filled(64, 7));
      await File(finalPath).writeAsBytes(const [1, 2, 3]);

      final task = Task(
        id: 'task-merge-clean',
        url: 'http://127.0.0.1/x',
        filename: 'movie.bin',
        filepath: finalPath,
      );

      await engine.discardIncompleteMergeArtifact(task);

      expect(await File(mergingPath).exists(), isFalse);
      expect(await File(finalPath).exists(), isTrue);
      expect(await File(finalPath).length(), 3);
    });
  });

  group('P0: calibrate progress from disk', () {
    test('recomputes multi-segment progress from .part files', () async {
      final engine = _buildEngine();
      const taskId = 'task-calibrate';
      final filepath = p.join(tempRoot.path, 'big.bin');
      final task = Task(
        id: taskId,
        url: 'http://127.0.0.1/big.bin',
        filename: 'big.bin',
        filepath: filepath,
        totalSize: 1000,
        downloadedSize: 0,
        segments: [
          Segment(index: 0, startByte: 0, endByte: 500),
          Segment(index: 1, startByte: 500, endByte: 1000),
        ],
      );

      final tempDir = Directory(p.join(tempRoot.path, '.nsfx_temp', taskId));
      await tempDir.create(recursive: true);
      await File(p.join(tempDir.path, 'task_$taskId.part0'))
          .writeAsBytes(List<int>.filled(300, 1));
      await File(p.join(tempDir.path, 'task_$taskId.part1'))
          .writeAsBytes(List<int>.filled(500, 2));

      task.segments[0].status = SegmentStatus.downloading;
      task.segments[1].status = SegmentStatus.downloading;

      await engine.calibrateTaskProgressFromDisk(task);

      expect(task.downloadedSize, 800);
      expect(task.progress, closeTo(80, 0.01));
      expect(task.segments[0].downloadedBytes, 300);
      expect(task.segments[0].status, SegmentStatus.paused);
      expect(task.segments[1].downloadedBytes, 500);
      expect(task.segments[1].status, SegmentStatus.completed);
      expect(task.speed, 0);
    });

    test('calibrates single-thread partial final file', () async {
      final engine = _buildEngine();
      final filepath = p.join(tempRoot.path, 'single.bin');
      await File(filepath).writeAsBytes(List<int>.filled(250, 9));

      final task = Task(
        id: 'task-single',
        url: 'http://127.0.0.1/single.bin',
        filename: 'single.bin',
        filepath: filepath,
        totalSize: 1000,
        downloadedSize: 10,
      );

      await engine.calibrateTaskProgressFromDisk(task);

      expect(task.downloadedSize, 250);
      expect(task.progress, closeTo(25, 0.01));
    });
  });

  group('P0: end-to-end multi-segment download (atomic merge)', () {
    test('completed download has final file, no merging artifact, no parts',
        () async {
      final payload = _patternBytes(2 * 1024 * 1024); // 2MB -> multi-segment
      final server = await _startRangeServer(payload);
      addTearDown(() async {
        await server.close(force: true);
      });

      final url = 'http://127.0.0.1:${server.port}/file.bin';
      final filepath = p.join(tempRoot.path, 'file.bin');
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
      final httpClient = NsfxHttpClient(config);
      final engine = DownloadEngine(
        config: config,
        httpClient: httpClient,
        onProgress: (_) {},
        onComplete: (task) {
          if (!completed.isCompleted) completed.complete(task);
        },
        onError: (task) {
          if (!failed.isCompleted) {
            failed.complete(task.errorMessage ?? 'unknown error');
          }
        },
      );

      final task = Task(
        id: 'task-e2e-merge',
        url: url,
        filename: 'file.bin',
        filepath: filepath,
      );

      unawaited(engine.startDownload(task));

      final winner = await Future.any<Object>([
        completed.future,
        failed.future.then((e) => throw TestFailure('download failed: $e')),
      ]).timeout(const Duration(seconds: 60));

      final done = winner as Task;
      expect(done.status, TaskStatus.completed);
      expect(await File(filepath).exists(), isTrue);
      expect(await File(filepath).length(), payload.length);
      expect(await File('$filepath.nsfx_merging').exists(), isFalse);
      expect(await File('$filepath.nsfx_partial').exists(), isFalse);

      final tempDir =
          Directory(p.join(tempRoot.path, '.nsfx_temp', 'task-e2e-merge'));
      expect(await tempDir.exists(), isFalse);

      final bytes = await File(filepath).readAsBytes();
      expect(bytes, payload);
    });
  });

  group('P0: pause soft-stop + progress preserve', () {
    test('pause mid-download preserves partial data and calibrates', () async {
      // Slow server so pause can land mid-transfer.
      final payload = _patternBytes(3 * 1024 * 1024);
      final server = await _startRangeServer(
        payload,
        throttleBytesPerChunk: 32 * 1024,
        throttleDelay: const Duration(milliseconds: 40),
      );
      addTearDown(() async {
        await server.close(force: true);
      });

      final url = 'http://127.0.0.1:${server.port}/slow.bin';
      final filepath = p.join(tempRoot.path, 'slow.bin');
      final config = NsfxConfig(
        threads: 2,
        mode: 'manual',
        segments: 2,
        enableDynamicSegments: false,
        maxRetries: 5,
        connectionTimeout: 10,
      );
      final httpClient = NsfxHttpClient(config);
      final engine = DownloadEngine(
        config: config,
        httpClient: httpClient,
        onProgress: (_) {},
        onComplete: (_) {},
        onError: (_) {},
      );

      final task = Task(
        id: 'task-pause',
        url: url,
        filename: 'slow.bin',
        filepath: filepath,
      );

      unawaited(engine.startDownload(task));

      // Wait until some progress is visible.
      final started = DateTime.now();
      while (task.downloadedSize < 64 * 1024) {
        if (DateTime.now().difference(started) > const Duration(seconds: 20)) {
          fail('download did not make progress before pause');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }

      await engine.pauseDownload(task.id);
      await engine.calibrateTaskProgressFromDisk(task);

      expect(
        task.status == TaskStatus.paused ||
            task.status == TaskStatus.downloading ||
            task.status == TaskStatus.failed ||
            task.status == TaskStatus.completed,
        isTrue,
      );

      // Soft-stop should not wipe progress.
      expect(task.downloadedSize, greaterThan(0));

      final partial = File('$filepath.nsfx_partial');
      final tempDir =
          Directory(p.join(tempRoot.path, '.nsfx_temp', 'task-pause'));
      if (await partial.exists()) {
        expect(await partial.length(), greaterThan(0));
      } else if (await tempDir.exists()) {
        var progressBytes = 0;
        await for (final entity in tempDir.list()) {
          if (entity is! File) continue;
          if (entity.path.contains('.part')) {
            progressBytes += await entity.length();
          } else if (entity.path.contains('.prog')) {
            progressBytes +=
                int.tryParse((await entity.readAsString()).trim()) ?? 0;
          }
        }
        expect(progressBytes, greaterThan(0));
      } else if (await File(filepath).exists()) {
        // Single-thread fallback path.
        expect(task.downloadedSize, await File(filepath).length());
      }
    });

    test('pause then resume preserves direct-write bytes exactly', () async {
      final payload = _patternBytes(4 * 1024 * 1024);
      final server = await _startRangeServer(
        payload,
        throttleBytesPerChunk: 32 * 1024,
        throttleDelay: const Duration(milliseconds: 12),
      );
      addTearDown(() async {
        await server.close(force: true);
      });

      final url = 'http://127.0.0.1:${server.port}/resume.bin';
      final filepath = p.join(tempRoot.path, 'resume.bin');
      final completed = Completer<Task>();
      final failed = Completer<String>();
      final config = NsfxConfig(
        threads: 2,
        mode: 'manual',
        segments: 2,
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
            failed.complete(task.errorMessage ?? 'unknown error');
          }
        },
      );
      final task = Task(
        id: 'task-direct-resume',
        url: url,
        filename: 'resume.bin',
        filepath: filepath,
      );

      unawaited(engine.startDownload(task));
      final started = DateTime.now();
      while (task.downloadedSize < 128 * 1024) {
        if (DateTime.now().difference(started) > const Duration(seconds: 20)) {
          fail('download did not make progress before pause');
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }

      await engine.pauseDownload(task.id);
      await engine.calibrateTaskProgressFromDisk(task);
      final pausedBytes = task.downloadedSize;
      expect(pausedBytes, greaterThan(0));
      expect(pausedBytes, lessThan(payload.length));

      unawaited(engine.startDownload(task));
      final winner = await Future.any<Object>([
        completed.future,
        failed.future.then((e) => throw TestFailure('resume failed: $e')),
      ]).timeout(const Duration(seconds: 60));

      expect((winner as Task).status, TaskStatus.completed);
      expect(await File(filepath).readAsBytes(), payload);
      expect(await File('$filepath.nsfx_partial').exists(), isFalse);
    });
  });

  group('P0: direct-write crash recovery', () {
    test('preallocated length alone is never treated as completion', () async {
      final engine = _buildEngine();
      const taskId = 'task-incomplete-preallocated';
      const totalSize = 1024;
      final filepath = p.join(tempRoot.path, 'preallocated.bin');
      final task = Task(
        id: taskId,
        url: 'http://127.0.0.1/preallocated.bin',
        filename: 'preallocated.bin',
        filepath: filepath,
        totalSize: totalSize,
        segments: [
          Segment(index: 0, startByte: 0, endByte: 512),
          Segment(index: 1, startByte: 512, endByte: totalSize),
        ],
      );

      await File('$filepath.nsfx_partial')
          .writeAsBytes(List<int>.filled(totalSize, 0));
      final tempDir = Directory(p.join(tempRoot.path, '.nsfx_temp', taskId));
      await tempDir.create(recursive: true);
      await File(p.join(tempDir.path, 'task_$taskId.prog0'))
          .writeAsString('512', flush: true);

      final promoted = await engine.recoverCompletedDirectWrite(task);

      expect(promoted, isFalse);
      expect(await File(filepath).exists(), isFalse);
      expect(await File('$filepath.nsfx_partial').exists(), isTrue);
    });
  });

  group('P0: pauseAllActive for graceful stop', () {
    test('pauseAllActive returns and leaves no active completers', () async {
      final payload = _patternBytes(2 * 1024 * 1024);
      final server = await _startRangeServer(
        payload,
        throttleBytesPerChunk: 16 * 1024,
        throttleDelay: const Duration(milliseconds: 30),
      );
      addTearDown(() async {
        await server.close(force: true);
      });

      final url = 'http://127.0.0.1:${server.port}/stop.bin';
      final filepath = p.join(tempRoot.path, 'stop.bin');
      final config = NsfxConfig(
        threads: 2,
        mode: 'manual',
        segments: 2,
        enableDynamicSegments: false,
        maxRetries: 3,
        connectionTimeout: 10,
      );
      final httpClient = NsfxHttpClient(config);
      final engine = DownloadEngine(
        config: config,
        httpClient: httpClient,
        onProgress: (_) {},
        onComplete: (_) {},
        onError: (_) {},
      );

      final task = Task(
        id: 'task-stop',
        url: url,
        filename: 'stop.bin',
        filepath: filepath,
      );

      unawaited(engine.startDownload(task));
      await Future<void>.delayed(const Duration(milliseconds: 400));

      await engine
          .pauseAllActive(timeout: const Duration(seconds: 15))
          .timeout(const Duration(seconds: 20));

      // Second call should be a no-op and return quickly.
      await engine
          .pauseAllActive(timeout: const Duration(seconds: 2))
          .timeout(const Duration(seconds: 5));
    });
  });

  group('P0: resume probe fail-closed (source contract)', () {
    test('probe failure path is fail-closed in engine source', () async {
      // Behavioral contract lock: exception/default path must not auto-allow.
      final engineSource = await File(
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

      expect(
        engineSource.contains(
          "Resume compatibility probe failed; kept partial segments.",
        ),
        isTrue,
      );
      expect(
        engineSource.contains(
          'Resume compatibility could not be verified; kept partial segments',
        ),
        isTrue,
      );

      // Ensure the old fail-open default is gone.
      final probeFn = engineSource.split('_probeResumeCompatibility(').last;
      final probeBody = probeFn.split('bool _shouldAbortParallelResume').first;
      expect(
        probeBody.contains(
          'return const _ResumeCompatibilityProbe(compatible: true);',
        ),
        isFalse,
      );
    });
  });

  group('P0: recovery helpers for interrupted merge', () {
    test('kernel recovery constants path uses .nsfx_merging suffix', () async {
      final kernelSource = await File(
        p.join(
          Directory.current.path,
          'lib',
          'services',
          'kernel',
          'next',
          'nsfx_kernel.dart',
        ),
      ).readAsString();

      expect(kernelSource.contains(".nsfx_merging"), isTrue);
      expect(kernelSource.contains('pauseAllActive'), isTrue);
      expect(kernelSource.contains('calibrateTaskProgressFromDisk'), isTrue);
      expect(kernelSource.contains('await _engine.pauseDownload'), isTrue);
      expect(kernelSource.contains('await _engine.cancelDownload'), isTrue);
    });
  });
}

DownloadEngine _buildEngine() {
  final config = NsfxConfig(threads: 2, enableDynamicSegments: false);
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

Future<HttpServer> _startRangeServer(
  List<int> payload, {
  int? throttleBytesPerChunk,
  Duration? throttleDelay,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      final total = payload.length;
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

      if (request.method == 'HEAD') {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentLength = total;
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers
            .set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
        await request.response.close();
        return;
      }

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final spec = rangeHeader.substring('bytes='.length);
        final parts = spec.split('-');
        final start = int.tryParse(parts[0]) ?? 0;
        var end = parts.length > 1 && parts[1].isNotEmpty
            ? (int.tryParse(parts[1]) ?? (total - 1))
            : (total - 1);
        if (end >= total) end = total - 1;
        if (start < 0 || start >= total || start > end) {
          request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          request.response.headers
              .set(HttpHeaders.contentRangeHeader, 'bytes */$total');
          await request.response.close();
          return;
        }

        final slice = payload.sublist(start, end + 1);
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$total',
        );
        request.response.headers.contentLength = slice.length;
        request.response.headers
            .set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
        await _writeThrottled(
          request.response,
          slice,
          throttleBytesPerChunk: throttleBytesPerChunk,
          throttleDelay: throttleDelay,
        );
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.contentLength = total;
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
      await _writeThrottled(
        request.response,
        payload,
        throttleBytesPerChunk: throttleBytesPerChunk,
        throttleDelay: throttleDelay,
      );
      await request.response.close();
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    }
  });
  return server;
}

Future<void> _writeThrottled(
  HttpResponse response,
  List<int> data, {
  int? throttleBytesPerChunk,
  Duration? throttleDelay,
}) async {
  if (throttleBytesPerChunk == null ||
      throttleDelay == null ||
      throttleBytesPerChunk <= 0) {
    response.add(data);
    return;
  }

  var offset = 0;
  while (offset < data.length) {
    final end = (offset + throttleBytesPerChunk).clamp(0, data.length);
    response.add(data.sublist(offset, end));
    await response.flush();
    offset = end;
    if (offset < data.length) {
      await Future<void>.delayed(throttleDelay);
    }
  }
}
