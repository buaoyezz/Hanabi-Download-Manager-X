import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/download_engine.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/http_client.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/models/task.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('nsfx_p3_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('P3: error classification', () {
    test('classifies permanent HTTP and range failures', () {
      expect(NsfxErrorClassifier.isPermanent('HTTP 404'), isTrue);
      expect(
          NsfxErrorClassifier.isPermanent('HttpException: HTTP 403'), isTrue);
      expect(NsfxErrorClassifier.isPermanent('RANGE_NOT_SUPPORTED'), isTrue);
      expect(NsfxErrorClassifier.isPermanent('RANGE_NOT_SATISFIABLE'), isTrue);
      expect(NsfxErrorClassifier.isPermanent('RANGE_RESPONSE_INVALID'), isTrue);
      expect(
        NsfxErrorClassifier.isPermanent('CERTIFICATE_VERIFY_FAILED'),
        isTrue,
      );
      expect(NsfxErrorClassifier.isPermanent('connection reset'), isFalse);
      expect(NsfxErrorClassifier.isTransient('timeout'), isTrue);
      expect(NsfxErrorClassifier.isTransient('HTTP 503'), isTrue);
      expect(
        NsfxErrorClassifier.isTransient('Incomplete transfer: 10/20'),
        isTrue,
      );
      expect(NsfxErrorClassifier.isTransient('HTTP 404'), isFalse);
    });

    test('retry budget is clamped for stability', () {
      expect(NsfxRetryPolicy.effectiveMaxRetries(200), 32);
      expect(NsfxRetryPolicy.effectiveMaxRetries(0), 32);
      expect(NsfxRetryPolicy.effectiveMaxRetries(8), 8);
      expect(NsfxConnectionBudget.normalize(0), 32);
      expect(NsfxConnectionBudget.normalize(999), 128);
      expect(NsfxConnectionBudget.normalize(16), 16);
    });
  });

  group('P3: TLS defaults', () {
    test('config defaults keep TLS verification enabled', () {
      final config = NsfxConfig();
      expect(config.allowInsecureTls, isFalse);
      expect(config.globalMaxConnections, 32);

      final encoded = config.toJson();
      expect(encoded['allow_insecure_tls'], isFalse);
      expect(encoded['global_max_connections'], 32);

      final restored = NsfxConfig.fromJson({
        ...encoded,
        'allow_insecure_tls': true,
        'global_max_connections': 12,
      });
      expect(restored.allowInsecureTls, isTrue);
      expect(restored.globalMaxConnections, 12);
    });

    test('http client source verifies certificates unless insecure mode',
        () async {
      final source = await File(
        p.join(
          Directory.current.path,
          'lib',
          'services',
          'kernel',
          'next',
          'downloader',
          'http_client.dart',
        ),
      ).readAsString();

      expect(
          source.contains('allowInsecureTls: config.allowInsecureTls'), isTrue);
      expect(source.contains('verifyCertificates: !config.allowInsecureTls'),
          isTrue);
      expect(
        source.contains('client.badCertificateCallback = null;'),
        isTrue,
      );
    });
  });

  group('P3: permanent fail-fast download path', () {
    test('HTTP 404 fails without long retry storm', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('missing');
        await request.response.close();
      });

      final filepath = p.join(tempRoot.path, 'missing.bin');
      final failed = Completer<Task>();
      final config = NsfxConfig(
        threads: 1,
        maxRetries: 32,
        enableDynamicSegments: false,
        connectionTimeout: 5,
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

      final started = DateTime.now();
      unawaited(
        engine.startDownload(
          Task(
            id: 'task-404',
            url: 'http://127.0.0.1:${server.port}/missing.bin',
            filename: 'missing.bin',
            filepath: filepath,
          ),
        ),
      );

      final done = await failed.future.timeout(const Duration(seconds: 15));
      final elapsed = DateTime.now().difference(started);

      expect(done.status, TaskStatus.failed);
      expect(done.errorMessage, contains('404'));
      // Permanent fail-fast should not burn multi-minute retry budget.
      expect(elapsed.inSeconds, lessThan(12));
    });
  });

  group('P3: multi-segment still works with connection budget', () {
    test('download completes under global connection cap', () async {
      final payload = _patternBytes(2 * 1024 * 1024);
      final server = await _startRangeServer(payload);
      addTearDown(() async {
        await server.close(force: true);
      });

      final filepath = p.join(tempRoot.path, 'budget.bin');
      final completed = Completer<Task>();
      final failed = Completer<String>();
      final config = NsfxConfig(
        threads: 4,
        mode: 'manual',
        segments: 4,
        enableDynamicSegments: false,
        globalMaxConnections: 2,
        maxRetries: 8,
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

      unawaited(
        engine.startDownload(
          Task(
            id: 'task-budget',
            url: 'http://127.0.0.1:${server.port}/budget.bin',
            filename: 'budget.bin',
            filepath: filepath,
          ),
        ),
      );

      await Future.any<Object>([
        completed.future,
        failed.future.then((e) => throw TestFailure(e)),
      ]).timeout(const Duration(seconds: 60));

      expect(await File(filepath).length(), payload.length);
    });
  });

  group('P3: strict ranges and transient recovery', () {
    test('single-thread resumes after the first response is cut short',
        () async {
      final payload = _patternBytes(512 * 1024);
      var requestCount = 0;
      var sawIdentityEncoding = false;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        requestCount++;
        sawIdentityEncoding = sawIdentityEncoding ||
            request.headers.value(HttpHeaders.acceptEncodingHeader) ==
                'identity';
        final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

        if (requestCount == 1 && rangeHeader == null) {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentLength = payload.length;
          request.response.add(payload.sublist(0, 96 * 1024));
          await request.response.flush();
          await Future<void>.delayed(const Duration(seconds: 6));
          try {
            await request.response.close();
          } catch (_) {}
          return;
        }

        final start = rangeHeader == null
            ? 0
            : int.parse(
                rangeHeader.substring('bytes='.length).split('-').first,
              );
        final end = payload.length - 1;
        final slice = payload.sublist(start);
        request.response.statusCode =
            rangeHeader == null ? HttpStatus.ok : HttpStatus.partialContent;
        request.response.headers.contentLength = slice.length;
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        if (rangeHeader != null) {
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/${payload.length}',
          );
        }
        request.response.add(slice);
        await request.response.close();
      });

      final filepath = p.join(tempRoot.path, 'single-retry.bin');
      final completed = Completer<Task>();
      final failed = Completer<String>();
      final config = NsfxConfig(
        threads: 1,
        maxRetries: 3,
        enableDynamicSegments: false,
        connectionTimeout: 5,
        readTimeout: 5,
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

      unawaited(
        engine.startDownload(
          Task(
            id: 'task-single-transient-retry',
            url: 'http://127.0.0.1:${server.port}/single-retry.bin',
            filename: 'single-retry.bin',
            filepath: filepath,
          ),
        ),
      );

      await Future.any<Object>([
        completed.future,
        failed.future.then((e) => throw TestFailure(e)),
      ]).timeout(const Duration(seconds: 30));

      expect(requestCount, greaterThanOrEqualTo(2));
      expect(sawIdentityEncoding, isTrue);
      expect(await File(filepath).readAsBytes(), payload);
    });

    test('multi-segment rejects mismatched Content-Range without finalizing',
        () async {
      final payload = _patternBytes(2 * 1024 * 1024);
      final server = await _startRangeServer(
        payload,
        misalignTransferRanges: true,
      );
      addTearDown(() async {
        await server.close(force: true);
      });

      final filepath = p.join(tempRoot.path, 'bad-range.bin');
      final failed = Completer<Task>();
      final config = NsfxConfig(
        threads: 2,
        mode: 'manual',
        segments: 2,
        enableDynamicSegments: false,
        maxRetries: 2,
        connectionTimeout: 5,
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

      unawaited(
        engine.startDownload(
          Task(
            id: 'task-bad-content-range',
            url: 'http://127.0.0.1:${server.port}/bad-range.bin',
            filename: 'bad-range.bin',
            filepath: filepath,
          ),
        ),
      );

      final done = await failed.future.timeout(const Duration(seconds: 30));
      expect(done.status, TaskStatus.failed);
      expect(
        done.segments.any(
          (segment) =>
              segment.lastError?.contains('RANGE_RESPONSE_INVALID') ?? false,
        ),
        isTrue,
      );
      expect(await File(filepath).exists(), isFalse);
    });
  });

  group('P3: source contracts', () {
    test('dynamic split waits for segment stop before steal', () async {
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

      expect(source.contains('_waitForSegmentExecutionEnd'), isTrue);
      expect(source.contains('_withConnectionBudget'), isTrue);
      expect(source.contains('_dynamicSegmentWorkers'), isTrue);
      expect(source.contains('NsfxErrorClassifier.isPermanent'), isTrue);
      expect(source.contains('allowInsecureTls'), isTrue);
    });
  });
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
  bool misalignTransferRanges = false,
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
        final slice = payload.sublist(start, end + 1);
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        final responseStart =
            misalignTransferRanges && !(start == 0 && end == 0)
                ? start + 1
                : start;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $responseStart-$end/$total',
        );
        request.response.headers.contentLength = slice.length;
        request.response.add(slice);
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
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
