import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/download_engine.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/http_client.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/models/task.dart';
import 'package:path/path.dart' as p;

import '../../../tool/download_test_server.dart';

void main() {
  late Directory tempRoot;
  late LocalDownloadTestServer server;

  setUp(() async {
    NsfxHttpClient.clearAdaptivePolicyHints();
    tempRoot = await Directory.systemTemp.createTemp('nsfx_local_lab_');
    server = LocalDownloadTestServer(port: 0);
    await server.start();
  });

  tearDown(() async {
    await server.close();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('multi-segment core downloads deterministic lab content exactly',
      () async {
    const size = 4 * 1024 * 1024;
    const seed = 23;
    final filepath = p.join(tempRoot.path, 'normal.bin');
    final result = await _runDownload(
      url: server.baseUri
          .resolve('download/normal/4m.bin?seed=$seed&resource=normal-e2e')
          .toString(),
      filepath: filepath,
      config: NsfxConfig(
        threads: 4,
        mode: 'manual',
        segments: 4,
        enableDynamicSegments: false,
        maxRetries: 3,
        connectionTimeout: 5,
        readTimeout: 5,
      ),
    );

    expect(result.status, TaskStatus.completed);
    expect(await File(filepath).readAsBytes(),
        DownloadTestPattern.bytes(0, size, seed: seed));
    expect(result.measuredTransferBytes, size);
    expect(result.averageSpeed, greaterThan(0));

    final stats = await _serverStats(server.baseUri);
    expect(stats['rangeRequests'], 4);
    expect((stats['scenarioRequests'] as Map)['normal'], 5);
  });

  test('known small file starts immediately and reports a real average speed',
      () async {
    const size = 512 * 1024;
    final filepath = p.join(tempRoot.path, 'known-small.bin');
    final result = await _runDownload(
      url: server.baseUri
          .resolve('download/normal/512k.bin?resource=known-small-e2e')
          .toString(),
      filepath: filepath,
      expectedSizeHint: size,
      config: NsfxConfig(
        threads: 8,
        mode: 'auto',
        enableDynamicSegments: true,
        maxRetries: 3,
        connectionTimeout: 5,
        readTimeout: 5,
      ),
    );

    expect(result.status, TaskStatus.completed);
    expect(result.resumeDecisionLabel, 'Known Small File');
    expect(result.threadCount, 1);
    expect(result.measuredTransferBytes, size);
    expect(result.activeTransferMicros, greaterThan(0));
    expect(result.averageSpeed, greaterThan(0));
    expect(result.peakSpeed, greaterThan(0));
    expect(result.peakSpeed, lessThan(result.averageSpeed * 1.1));
    expect(
      result.averageSpeed,
      closeTo(
        result.measuredTransferBytes *
            Duration.microsecondsPerSecond /
            result.activeTransferMicros,
        0.01,
      ),
    );

    final stats = await _serverStats(server.baseUri);
    expect(stats['rangeRequests'], 0);
    expect((stats['scenarioRequests'] as Map)['normal'], 1);
  });

  test('unknown small file uses its first GET instead of a metadata probe',
      () async {
    const size = 512 * 1024;
    final filepath = p.join(tempRoot.path, 'unknown-small.bin');
    final result = await _runDownload(
      url: server.baseUri
          .resolve('download/normal/512k.bin?resource=unknown-small-e2e')
          .toString(),
      filepath: filepath,
      config: NsfxConfig(
        threads: 8,
        mode: 'auto',
        enableDynamicSegments: true,
        maxRetries: 3,
        connectionTimeout: 5,
        readTimeout: 5,
      ),
    );

    expect(result.status, TaskStatus.completed);
    expect(result.resumeDecisionLabel, 'Immediate GET');
    expect(result.threadCount, 1);
    expect(result.measuredTransferBytes, size);
    expect(result.averageSpeed, greaterThan(0));
    expect(result.peakSpeed, greaterThan(0));
    expect(result.peakSpeed, lessThan(result.averageSpeed * 1.1));

    final stats = await _serverStats(server.baseUri);
    expect(stats['rangeRequests'], 0);
    expect((stats['scenarioRequests'] as Map)['normal'], 1);
  });

  test('instant and average speeds track a throttled transfer', () async {
    const size = 2 * 1024 * 1024;
    const mib = 1024 * 1024;
    final observedSpeeds = <double>[];
    final filepath = p.join(tempRoot.path, 'paced.bin');
    final result = await _runDownload(
      url: server.baseUri
          .resolve(
            'download/slow/2m.bin?resource=paced-speed&chunkBytes=65536&delayMs=40',
          )
          .toString(),
      filepath: filepath,
      expectedSizeHint: size,
      observedSpeeds: observedSpeeds,
      config: NsfxConfig(
        threads: 8,
        mode: 'auto',
        enableDynamicSegments: true,
        maxRetries: 3,
        connectionTimeout: 5,
        readTimeout: 5,
      ),
    );

    expect(result.status, TaskStatus.completed);
    expect(result.measuredTransferBytes, size);
    expect(result.activeTransferMicros, greaterThan(1000000));
    expect(result.averageSpeed, inInclusiveRange(0.8 * mib, 2.4 * mib));
    expect(
      observedSpeeds.where((speed) => speed > 0),
      isNotEmpty,
    );
    expect(
      observedSpeeds.where((speed) => speed > 0).last,
      inInclusiveRange(0.8 * mib, 2.4 * mib),
    );
  });

  test('pausing stops local transfer without retrying', () async {
    const size = 64 * 1024 * 1024;
    final filepath = p.join(tempRoot.path, 'pause-resume.bin');
    final config = NsfxConfig(
      threads: 1,
      mode: 'auto',
      enableDynamicSegments: false,
      maxRetries: 3,
      connectionTimeout: 5,
      readTimeout: 5,
    );
    final client = NsfxHttpClient(config);
    final engine = DownloadEngine(
      config: config,
      httpClient: client,
      onProgress: (_) {},
      onComplete: (_) {},
      onError: (_) {},
    );
    final task = Task(
      id: 'pause-${DateTime.now().microsecondsSinceEpoch}',
      url: server.baseUri
          .resolve(
            'download/slow/64m.bin?resource=pause-abort&chunkBytes=65536&delayMs=10',
          )
          .toString(),
      filename: p.basename(filepath),
      filepath: filepath,
    );

    try {
      unawaited(engine.startDownload(task));
      await _waitUntil(
        () => task.downloadedSize >= 128 * 1024,
        timeout: const Duration(seconds: 5),
      );
      await engine.pauseDownload(task.id);

      final pausedBytes = task.downloadedSize;
      expect(task.status, TaskStatus.paused);
      expect(pausedBytes, inExclusiveRange(0, size));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(task.downloadedSize, pausedBytes);
      expect(await File(filepath).length(), pausedBytes);

      final pausedStats = await _serverStats(server.baseUri);
      final scenarioRequests = Map<String, dynamic>.from(
        pausedStats['scenarioRequests'] as Map,
      );
      final transferAttempts = Map<String, dynamic>.from(
        pausedStats['transferAttempts'] as Map,
      );
      expect(scenarioRequests['slow'], 1);
      expect(transferAttempts['slow|pause-abort'], 1);
    } finally {
      client.close();
    }
  });

  test('single-connection core resumes after injected disconnect', () async {
    const size = 1024 * 1024;
    final filepath = p.join(tempRoot.path, 'disconnect.bin');
    final result = await _runDownload(
      url: server.baseUri
          .resolve(
            'download/disconnect-once/1m.bin?resource=core-disconnect&failAfterBytes=131072',
          )
          .toString(),
      filepath: filepath,
      config: NsfxConfig(
        threads: 1,
        enableDynamicSegments: false,
        maxRetries: 3,
        connectionTimeout: 5,
        readTimeout: 5,
      ),
    );

    expect(result.status, TaskStatus.completed);
    expect(
        await File(filepath).readAsBytes(), DownloadTestPattern.bytes(0, size));
    expect(result.measuredTransferBytes, size);
    expect(result.averageSpeed, greaterThan(0));
    expect(result.peakSpeed, lessThan(result.averageSpeed * 2));

    final stats = await _serverStats(server.baseUri);
    expect(stats['injectedFailures'], 1);
    expect(stats['rangeRequests'], greaterThanOrEqualTo(1));
  });

  test('core rejects injected Content-Range corruption', () async {
    final filepath = p.join(tempRoot.path, 'bad-range.bin');
    final result = await _runDownload(
      url: server.baseUri
          .resolve(
            'download/bad-content-range/2m.bin?resource=bad-range-e2e',
          )
          .toString(),
      filepath: filepath,
      config: NsfxConfig(
        threads: 2,
        mode: 'manual',
        segments: 2,
        enableDynamicSegments: false,
        maxRetries: 2,
        connectionTimeout: 5,
        readTimeout: 5,
      ),
      expectFailure: true,
    );

    expect(result.status, TaskStatus.failed);
    expect(
      result.segments.any(
        (segment) =>
            segment.lastError?.contains('RANGE_RESPONSE_INVALID') ?? false,
      ),
      isTrue,
    );
    expect(await File(filepath).exists(), isFalse);
  });
}

Future<Task> _runDownload({
  required String url,
  required String filepath,
  required NsfxConfig config,
  int? expectedSizeHint,
  List<double>? observedSpeeds,
  bool expectFailure = false,
}) async {
  final completed = Completer<Task>();
  final failed = Completer<Task>();
  final client = NsfxHttpClient(config);
  final engine = DownloadEngine(
    config: config,
    httpClient: client,
    onProgress: (task) {
      observedSpeeds?.add(task.speed);
    },
    onComplete: (task) {
      if (!completed.isCompleted) completed.complete(task);
    },
    onError: (task) {
      if (!failed.isCompleted) failed.complete(task);
    },
  );
  final task = Task(
    id: 'lab-${DateTime.now().microsecondsSinceEpoch}',
    url: url,
    filename: p.basename(filepath),
    filepath: filepath,
    expectedSizeHint: expectedSizeHint,
  );

  unawaited(engine.startDownload(task));
  try {
    if (expectFailure) {
      return await failed.future.timeout(const Duration(seconds: 30));
    }
    return await Future.any<Task>([
      completed.future,
      failed.future.then(
        (task) => throw TestFailure(
          'Download failed unexpectedly: ${task.errorMessage}',
        ),
      ),
    ]).timeout(const Duration(seconds: 30));
  } finally {
    client.close();
  }
}

Future<Map<String, dynamic>> _serverStats(Uri baseUri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(baseUri.resolve('api/v1/stats'));
    final response = await request.close();
    final text = await response.transform(const Utf8Decoder()).join();
    return Map<String, dynamic>.from(jsonDecode(text) as Map);
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitUntil(
  bool Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition was not met before $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
