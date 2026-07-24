import 'dart:io';
import 'dart:math';

import 'package:hanabi_download_manager_x/services/app_logger_service.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/download_engine.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/downloader/http_client.dart';
import 'package:hanabi_download_manager_x/services/kernel/next/models/task.dart';
import 'package:hanabi_download_manager_x/services/speed_history_service.dart';
import 'package:path/path.dart' as path;
import 'package:rhttp/rhttp.dart' as rhttp;

import 'download_test_server.dart';

const _warmupRuns = 2;
const _measuredRuns = 8;

Future<void> main() => runDownloadArchitectureBenchmark();

bool isArchitectureBenchmarkNativeRuntimeAvailable() =>
    _canAttemptRhttpLoad();

Future<void> runDownloadArchitectureBenchmark() async {
  final logger = AppLoggerService();
  final speedHistory = SpeedHistoryService();
  logger.setConsoleOutputEnabled(false);
  logger.setPersistenceEnabled(false);
  speedHistory.setPersistenceEnabled(false);
  final server = LocalDownloadTestServer(port: 0);
  final tempDir = await Directory.systemTemp.createTemp('hdmx_microbench_');
  await server.start();

  try {
    stdout.writeln('HDMX small-file architecture benchmark');
    stdout.writeln('server=${server.baseUri}');
    stdout.writeln(
      'Each result discards $_warmupRuns warmups and reports '
      '$_measuredRuns measured runs.',
    );

    stdout.writeln('\nCurrent DownloadEngine paths');
    for (final size in const [64 * 1024, 512 * 1024, 2 * 1024 * 1024]) {
      for (final strategy in const [
        _Strategy('single', mode: 'auto', threads: 8, segments: null),
        _Strategy('range-4', mode: 'manual', threads: 4, segments: 4),
        _Strategy('range-8', mode: 'manual', threads: 8, segments: 8),
      ]) {
        final samples = <_Sample>[];
        for (var run = 0; run < _warmupRuns + _measuredRuns; run++) {
          final sample = await _runOnce(
            server: server,
            tempDir: tempDir,
            size: size,
            strategy: strategy,
            run: run,
          );
          if (run >= _warmupRuns) samples.add(sample);
        }
        _printResult(size, strategy, samples);
      }
    }

    await _runTransportLifecycleBaselines(server);
  } finally {
    await server.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    logger.setPersistenceEnabled(true);
    speedHistory.setPersistenceEnabled(true);
  }
}

Future<void> _runTransportLifecycleBaselines(
  LocalDownloadTestServer server,
) async {
  stdout.writeln('\nTransport lifecycle baselines');
  final settings = const rhttp.ClientSettings(
    httpVersionPref: rhttp.HttpVersionPref.http1_1,
    throwOnStatusCode: false,
  );
  final warmDart = HttpClient()..autoUncompress = false;
  rhttp.RhttpClient? pooledRhttp;
  Object? rhttpUnavailable;

  if (!_canAttemptRhttpLoad()) {
    rhttpUnavailable = StateError(
      'rhttp.dll is not present in the process directory or PATH',
    );
  } else {
    try {
      await rhttp.Rhttp.init();
      pooledRhttp = await rhttp.RhttpClient.create(settings: settings);
    } catch (error) {
      rhttpUnavailable = error;
    }
  }

  try {
    for (final size in const [64 * 1024, 512 * 1024, 2 * 1024 * 1024]) {
      final cases = <_LifecycleCase>[
        _LifecycleCase('dart-cold', () => _downloadWithColdDart(server, size)),
        _LifecycleCase(
          'dart-pooled',
          () => _downloadWithDart(warmDart, server, size),
        ),
      ];
      final reusableRhttp = pooledRhttp;
      if (reusableRhttp != null) {
        cases.addAll([
          _LifecycleCase(
            'rhttp-static',
            () => _downloadWithStaticRhttp(settings, server, size),
          ),
          _LifecycleCase(
            'rhttp-pooled',
            () => _downloadWithPooledRhttp(reusableRhttp, server, size),
          ),
        ]);
      }

      for (final benchmarkCase in cases) {
        final samples = <int>[];
        for (var run = 0; run < _warmupRuns + _measuredRuns; run++) {
          final clock = Stopwatch()..start();
          final received = await benchmarkCase.action();
          clock.stop();
          if (received != size) {
            throw StateError(
              '${benchmarkCase.label} received $received bytes, expected $size',
            );
          }
          if (run >= _warmupRuns) {
            samples.add(clock.elapsedMicroseconds);
          }
        }
        _printLifecycleResult(size, benchmarkCase.label, samples);
      }
    }
    if (rhttpUnavailable != null) {
      stdout.writeln(
        'rhttp baselines skipped: native library is unavailable in the '
        'test process ($rhttpUnavailable)',
      );
    }
  } finally {
    warmDart.close(force: true);
    pooledRhttp?.dispose(cancelRunningRequests: true);
  }
}

bool _canAttemptRhttpLoad() {
  if (!Platform.isWindows) return true;

  final searchDirectories = <String>{
    Directory.current.path,
    File(Platform.resolvedExecutable).parent.path,
    ...?Platform.environment['PATH']
        ?.split(';')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty),
  };
  return searchDirectories.any(
    (directory) => File(path.join(directory, 'rhttp.dll')).existsSync(),
  );
}

Future<int> _downloadWithColdDart(
  LocalDownloadTestServer server,
  int size,
) async {
  final client = HttpClient()..autoUncompress = false;
  try {
    return await _downloadWithDart(client, server, size);
  } finally {
    client.close(force: true);
  }
}

Future<int> _downloadWithDart(
  HttpClient client,
  LocalDownloadTestServer server,
  int size,
) async {
  final request = await client.getUrl(_benchmarkUri(server, size, 'dart'));
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('Unexpected HTTP ${response.statusCode}');
  }
  return response.fold<int>(0, (total, chunk) => total + chunk.length);
}

Future<int> _downloadWithStaticRhttp(
  rhttp.ClientSettings settings,
  LocalDownloadTestServer server,
  int size,
) async {
  final response = await rhttp.Rhttp.requestStream(
    settings: settings,
    method: rhttp.HttpMethod.get,
    url: _benchmarkUri(server, size, 'rhttp-static').toString(),
  );
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('Unexpected HTTP ${response.statusCode}');
  }
  return response.body.fold<int>(0, (total, chunk) => total + chunk.length);
}

Future<int> _downloadWithPooledRhttp(
  rhttp.RhttpClient client,
  LocalDownloadTestServer server,
  int size,
) async {
  final response = await client.requestStream(
    method: rhttp.HttpMethod.get,
    url: _benchmarkUri(server, size, 'rhttp-pooled').toString(),
  );
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('Unexpected HTTP ${response.statusCode}');
  }
  return response.body.fold<int>(0, (total, chunk) => total + chunk.length);
}

Uri _benchmarkUri(
  LocalDownloadTestServer server,
  int size,
  String transport,
) {
  return server.baseUri.resolve(
    'download/normal/$size.bin?transport=$transport&run='
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}

void _printLifecycleResult(int size, String label, List<int> samples) {
  samples.sort();
  final average = samples.reduce((a, b) => a + b) / samples.length;
  final p50 = samples[samples.length ~/ 2];
  final p95 =
      samples[min(samples.length - 1, (samples.length * 0.95).ceil() - 1)];
  stdout.writeln(
    '${(size / 1024).toStringAsFixed(0).padLeft(4)} KiB  '
    '${label.padRight(12)}  '
    'avg=${(average / 1000).toStringAsFixed(2).padLeft(7)} ms  '
    'p50=${(p50 / 1000).toStringAsFixed(2).padLeft(7)} ms  '
    'p95=${(p95 / 1000).toStringAsFixed(2).padLeft(7)} ms',
  );
}

Future<_Sample> _runOnce({
  required LocalDownloadTestServer server,
  required Directory tempDir,
  required int size,
  required _Strategy strategy,
  required int run,
}) async {
  final sizeToken = size == 64 * 1024
      ? '64k.bin'
      : size == 512 * 1024
          ? '512k.bin'
          : size == 2 * 1024 * 1024
              ? '2m.bin'
              : '$size.bin';
  final id =
      '${strategy.label}-$size-$run-${DateTime.now().microsecondsSinceEpoch}';
  final config = NsfxConfig(
    mode: strategy.mode,
    threads: strategy.threads,
    segments: strategy.segments,
    maxConcurrentTasks: 1,
    globalMaxConnections: 32,
  );
  final rootClient = NsfxHttpClient(config);
  final task = Task(
    id: id,
    url: server.baseUri
        .resolve('download/normal/$sizeToken?resource=$id')
        .toString(),
    filename: '$id.bin',
    filepath: path.join(tempDir.path, '$id.bin'),
    expectedSizeHint: size,
  );
  final engine = DownloadEngine(
    config: config,
    httpClient: rootClient,
    onProgress: (_) {},
    onComplete: (_) {},
    onError: (_) {},
  );

  final wallClock = Stopwatch()..start();
  await engine.startDownload(task);
  wallClock.stop();
  rootClient.close();

  if (task.status != TaskStatus.completed) {
    throw StateError(
      '${strategy.label} failed for $size bytes: ${task.errorMessage}',
    );
  }
  final file = File(task.filepath);
  if (!await file.exists() || await file.length() != size) {
    throw StateError('${strategy.label} produced an invalid file for $size');
  }

  return _Sample(
    wallMicros: wallClock.elapsedMicroseconds,
    activeMicros: task.activeTransferMicros,
  );
}

void _printResult(int size, _Strategy strategy, List<_Sample> samples) {
  final wall = samples.map((sample) => sample.wallMicros).toList()..sort();
  final active = samples.map((sample) => sample.activeMicros).toList()..sort();
  final averageWall = wall.reduce((a, b) => a + b) / wall.length;
  final p50 = wall[wall.length ~/ 2];
  final p95 = wall[min(wall.length - 1, (wall.length * 0.95).ceil() - 1)];
  final activeP50 = active[active.length ~/ 2];
  final throughput = size * Duration.microsecondsPerSecond / averageWall;
  stdout.writeln(
    '${(size / 1024).toStringAsFixed(0).padLeft(4)} KiB  '
    '${strategy.label.padRight(7)}  '
    'wall avg=${(averageWall / 1000).toStringAsFixed(2).padLeft(7)} ms  '
    'p50=${(p50 / 1000).toStringAsFixed(2).padLeft(7)} ms  '
    'p95=${(p95 / 1000).toStringAsFixed(2).padLeft(7)} ms  '
    'active p50=${(activeP50 / 1000).toStringAsFixed(2).padLeft(7)} ms  '
    'effective=${(throughput / 1024 / 1024).toStringAsFixed(2)} MiB/s',
  );
}

class _Strategy {
  const _Strategy(
    this.label, {
    required this.mode,
    required this.threads,
    required this.segments,
  });

  final String label;
  final String mode;
  final int threads;
  final int? segments;
}

class _Sample {
  const _Sample({required this.wallMicros, required this.activeMicros});

  final int wallMicros;
  final int activeMicros;
}

class _LifecycleCase {
  const _LifecycleCase(this.label, this.action);

  final String label;
  final Future<int> Function() action;
}
