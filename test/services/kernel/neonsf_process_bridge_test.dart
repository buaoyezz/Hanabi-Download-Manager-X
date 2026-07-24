import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/kernel/neonsf/neonsf_process_bridge.dart';
import 'package:path/path.dart' as path;

import '../../../tool/download_test_server.dart';

void main() {
  late LocalDownloadTestServer server;
  late Directory tempDir;
  late NeoNsfProcessBridge bridge;

  setUp(() async {
    server = LocalDownloadTestServer(port: 0);
    await server.start();
    tempDir = await Directory.systemTemp.createTemp('neonsf_bridge_');
    bridge = NeoNsfProcessBridge();
    final ready = await bridge.start();
    expect(ready['protocolVersion'], 1);
    expect(ready['name'], 'NeoNSFX');
    expect(ready['version'], '0.1.0');
    expect(
      (ready['capabilities'] as Map?)?['multiRange'],
      isTrue,
    );
  });

  tearDown(() async {
    await bridge.dispose();
    await server.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('downloads a known small file without sending bytes through Dart',
      () async {
    const size = 512 * 1024;
    const taskId = 'neo-small';
    final output = path.join(tempDir.path, 'small.bin');
    final terminal = bridge.events.firstWhere(
      (event) =>
          (event['type'] == 'completed' || event['type'] == 'failed') &&
          event['taskId'] == taskId,
    );

    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve('download/normal/512k.bin?resource=neo-small')
            .toString(),
        'filePath': output,
        'expectedSize': size,
        'headers': const <String, String>{},
        'httpVersionPolicy': 'auto',
      }),
      isTrue,
    );

    final event = await terminal.timeout(const Duration(seconds: 10));
    expect(event['type'], 'completed', reason: event['error']?.toString());
    expect(event['downloadedBytes'], size);
    final bytes = await File(output).readAsBytes();
    expect(bytes, DownloadTestPattern.bytes(0, size));
  });

  test('pauses and resumes the same native task', () async {
    const size = 2 * 1024 * 1024;
    const taskId = 'neo-resume';
    final output = path.join(tempDir.path, 'resume.bin');
    final firstProgress = bridge.events.firstWhere(
      (event) =>
          event['type'] == 'progress' &&
          event['taskId'] == taskId &&
          (event['downloadedBytes'] as num? ?? 0) > 0,
    );

    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve(
              'download/slow/2m.bin?resource=neo-resume&chunkBytes=32768&delayMs=20',
            )
            .toString(),
        'filePath': output,
        'expectedSize': size,
        'headers': const <String, String>{},
      }),
      isTrue,
    );

    final progressEvent =
        await firstProgress.timeout(const Duration(seconds: 10));
    expect((progressEvent['instantBps'] as num).toDouble(), greaterThan(0));
    expect(progressEvent['windowBps'], progressEvent['instantBps']);
    expect((progressEvent['rawInstantBps'] as num).toDouble(), greaterThan(0));
    expect((progressEvent['averageBps'] as num).toDouble(), greaterThan(0));
    expect((progressEvent['activeTicks'] as num).toInt(), greaterThan(0));
    final paused = bridge.events.firstWhere(
      (event) => event['type'] == 'paused' && event['taskId'] == taskId,
    );
    expect(await bridge.pause(taskId), isTrue);
    await paused.timeout(const Duration(seconds: 5));

    final partial = File('$output.neonsf.partial');
    expect(await partial.exists(), isTrue);
    final pausedLength = await partial.length();
    expect(pausedLength, inExclusiveRange(0, size));

    final terminal = bridge.events.firstWhere(
      (event) =>
          (event['type'] == 'completed' || event['type'] == 'failed') &&
          event['taskId'] == taskId,
    );
    expect(await bridge.resume(taskId), isTrue);
    final terminalEvent = await terminal.timeout(const Duration(seconds: 15));
    expect(
      terminalEvent['type'],
      'completed',
      reason: terminalEvent['error']?.toString(),
    );
    expect((terminalEvent['averageBps'] as num).toDouble(), greaterThan(0));
    expect(await File(output).length(), size);
    expect(
        await File(output).readAsBytes(), DownloadTestPattern.bytes(0, size));
  });

  test('downloads a known large file with native parallel ranges', () async {
    const size = 16 * 1024 * 1024;
    const taskId = 'neo-large-parallel';
    final output = path.join(tempDir.path, 'large.bin');
    final headers = bridge.events.firstWhere(
      (event) => event['type'] == 'headers' && event['taskId'] == taskId,
    );
    final terminal = bridge.events.firstWhere(
      (event) =>
          (event['type'] == 'completed' || event['type'] == 'failed') &&
          event['taskId'] == taskId,
    );

    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve('download/normal/16m.bin?resource=neo-large')
            .toString(),
        'filePath': output,
        'expectedSize': size,
        'maxConnections': 4,
        'headers': const <String, String>{},
      }),
      isTrue,
    );

    final headerEvent = await headers.timeout(const Duration(seconds: 5));
    expect(headerEvent['transferMode'], 'parallel_range');
    expect((headerEvent['connectionCount'] as num).toInt(), 4);
    final terminalEvent = await terminal.timeout(const Duration(seconds: 20));
    expect(
      terminalEvent['type'],
      'completed',
      reason: terminalEvent['error']?.toString(),
    );
    expect(await File(output).length(), size);
    expect(
      await File(output).readAsBytes(),
      DownloadTestPattern.bytes(0, size),
    );
    final stats = await _serverStats(server.baseUri);
    expect((stats['rangeRequests'] as num).toInt(), greaterThanOrEqualTo(4));
    expect((stats['maxActiveRequests'] as num).toInt(), greaterThan(1));
  });

  test('pauses and resumes a checkpointed parallel transfer', () async {
    const size = 16 * 1024 * 1024;
    const taskId = 'neo-large-resume';
    final output = path.join(tempDir.path, 'large-resume.bin');
    final firstProgress = bridge.events.firstWhere(
      (event) =>
          event['type'] == 'progress' &&
          event['taskId'] == taskId &&
          (event['downloadedBytes'] as num? ?? 0) > 0,
    );

    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve(
              'download/slow/16m.bin?resource=neo-large-resume&chunkBytes=32768&delayMs=10',
            )
            .toString(),
        'filePath': output,
        'expectedSize': size,
        'maxConnections': 4,
        'headers': const <String, String>{},
      }),
      isTrue,
    );
    await firstProgress.timeout(const Duration(seconds: 10));
    final paused = bridge.events.firstWhere(
      (event) => event['type'] == 'paused' && event['taskId'] == taskId,
    );
    expect(await bridge.pause(taskId), isTrue);
    await paused.timeout(const Duration(seconds: 5));

    expect(await File('$output.neonsf.partial').length(), size);
    expect(await File('$output.neonsf.state').exists(), isTrue);

    final terminal = bridge.events.firstWhere(
      (event) =>
          (event['type'] == 'completed' || event['type'] == 'failed') &&
          event['taskId'] == taskId,
    );
    expect(await bridge.resume(taskId), isTrue);
    final event = await terminal.timeout(const Duration(seconds: 20));
    expect(event['type'], 'completed', reason: event['error']?.toString());
    expect(await File('$output.neonsf.state').exists(), isFalse);
    expect(
      await File(output).readAsBytes(),
      DownloadTestPattern.bytes(0, size),
    );
  });

  test('plans an unknown large file into native parallel ranges', () async {
    const size = 16 * 1024 * 1024;
    const taskId = 'neo-unknown-large';
    final output = path.join(tempDir.path, 'unknown-large.bin');
    final headers = bridge.events.firstWhere(
      (event) => event['type'] == 'headers' && event['taskId'] == taskId,
    );
    final terminal = bridge.events.firstWhere(
      (event) =>
          (event['type'] == 'completed' || event['type'] == 'failed') &&
          event['taskId'] == taskId,
    );

    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve('download/normal/16m.bin?resource=neo-unknown-large')
            .toString(),
        'filePath': output,
        'maxConnections': 4,
        'headers': const <String, String>{},
      }),
      isTrue,
    );
    expect(
      (await headers.timeout(const Duration(seconds: 5)))['transferMode'],
      'parallel_range',
    );
    final event = await terminal.timeout(const Duration(seconds: 20));
    expect(event['type'], 'completed', reason: event['error']?.toString());
    expect(await File(output).length(), size);
  });

  test('converges to one connection when a large server rejects ranges',
      () async {
    const size = 16 * 1024 * 1024;
    const taskId = 'neo-large-no-range';
    final output = path.join(tempDir.path, 'no-range.bin');
    final headers = bridge.events.firstWhere(
      (event) => event['type'] == 'headers' && event['taskId'] == taskId,
    );
    final terminal = bridge.events.firstWhere(
      (event) =>
          (event['type'] == 'completed' || event['type'] == 'failed') &&
          event['taskId'] == taskId,
    );

    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve('download/no-range/16m.bin?resource=neo-no-range')
            .toString(),
        'filePath': output,
        'expectedSize': size,
        'maxConnections': 4,
        'headers': const <String, String>{},
      }),
      isTrue,
    );
    final headerEvent = await headers.timeout(const Duration(seconds: 5));
    expect(headerEvent['transferMode'], 'direct');
    expect(headerEvent['connectionCount'], 1);
    final event = await terminal.timeout(const Duration(seconds: 20));
    expect(event['type'], 'completed', reason: event['error']?.toString());
    expect(await File(output).length(), size);
  });

  test('validator change restarts from zero instead of joining mixed bytes',
      () async {
    const size = 2 * 1024 * 1024;
    const taskId = 'neo-validator-change';
    const resource = 'neo-changing';
    final output = path.join(tempDir.path, 'changing.bin');
    final firstProgress = bridge.events.firstWhere(
      (event) =>
          event['type'] == 'progress' &&
          event['taskId'] == taskId &&
          (event['downloadedBytes'] as num? ?? 0) > 0,
    );

    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve(
              'download/changing/2m.bin?resource=$resource&chunkBytes=32768&delayMs=20',
            )
            .toString(),
        'filePath': output,
        'expectedSize': size,
        'headers': const <String, String>{},
      }),
      isTrue,
    );
    await firstProgress.timeout(const Duration(seconds: 10));
    final paused = bridge.events.firstWhere(
      (event) => event['type'] == 'paused' && event['taskId'] == taskId,
    );
    expect(await bridge.pause(taskId), isTrue);
    await paused.timeout(const Duration(seconds: 5));

    server.setResourceVersion(resource, 2);
    final validatorRetry = bridge.events.firstWhere(
      (event) =>
          event['type'] == 'retrying' &&
          event['taskId'] == taskId &&
          event['error'].toString().contains('RESUME_VALIDATOR_CHANGED'),
    );
    final terminal = bridge.events.firstWhere(
      (event) =>
          (event['type'] == 'completed' || event['type'] == 'failed') &&
          event['taskId'] == taskId,
    );
    expect(await bridge.resume(taskId), isTrue);
    await validatorRetry.timeout(const Duration(seconds: 10));
    final terminalEvent = await terminal.timeout(const Duration(seconds: 15));
    expect(
      terminalEvent['type'],
      'completed',
      reason: terminalEvent['error']?.toString(),
    );
    expect(
      await File(output).readAsBytes(),
      DownloadTestPattern.bytes(0, size, version: 2),
    );
  });

  test('releases a failed native task id so Dart can retry it', () async {
    const size = 512 * 1024;
    const taskId = 'neo-retry-after-failure';
    final output = path.join(tempDir.path, 'retry.bin');
    final failed = bridge.events.firstWhere(
      (event) => event['type'] == 'failed' && event['taskId'] == taskId,
    );

    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve('download/status/512k.bin?code=404&resource=neo-fail')
            .toString(),
        'filePath': output,
        'expectedSize': size,
        'headers': const <String, String>{},
      }),
      isTrue,
    );
    await failed.timeout(const Duration(seconds: 5));

    final completed = bridge.events.firstWhere(
      (event) => event['type'] == 'completed' && event['taskId'] == taskId,
    );
    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve('download/normal/512k.bin?resource=neo-retry')
            .toString(),
        'filePath': output,
        'expectedSize': size,
        'headers': const <String, String>{},
      }),
      isTrue,
    );
    await completed.timeout(const Duration(seconds: 10));
    expect(
        await File(output).readAsBytes(), DownloadTestPattern.bytes(0, size));
  });

  test('pause during retry backoff reaches a stable paused state', () async {
    const taskId = 'neo-pause-backoff';
    final output = path.join(tempDir.path, 'backoff.bin');
    final retrying = bridge.events.firstWhere(
      (event) => event['type'] == 'retrying' && event['taskId'] == taskId,
    );

    expect(
      await bridge.enqueue(<String, dynamic>{
        'taskId': taskId,
        'url': server.baseUri
            .resolve(
              'download/flaky-503/512k.bin?failures=100&resource=neo-backoff',
            )
            .toString(),
        'filePath': output,
        'expectedSize': 512 * 1024,
        'headers': const <String, String>{},
        'maxRetries': 5,
      }),
      isTrue,
    );
    await retrying.timeout(const Duration(seconds: 5));

    final paused = bridge.events.firstWhere(
      (event) => event['type'] == 'paused' && event['taskId'] == taskId,
    );
    expect(await bridge.pause(taskId), isTrue);
    await paused.timeout(const Duration(seconds: 5));
    final cancelled = bridge.events.firstWhere(
      (event) => event['type'] == 'cancelled' && event['taskId'] == taskId,
    );
    expect(await bridge.cancel(taskId), isTrue);
    await cancelled.timeout(const Duration(seconds: 5));
  });
}

Future<Map<String, dynamic>> _serverStats(Uri baseUri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(baseUri.resolve('api/v1/stats'));
    final response = await request.close();
    final body = await response.transform(const Utf8Decoder()).join();
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}
