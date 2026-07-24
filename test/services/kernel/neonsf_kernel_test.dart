import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/kernel/kernel_interface.dart';
import 'package:hanabi_download_manager_x/services/kernel/neonsf/neonsf_kernel.dart';
import 'package:hanabi_download_manager_x/services/kernel/neonsf/neonsf_process_bridge.dart';
import 'package:hanabi_download_manager_x/services/kernel/neonsf/neonsf_task_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempHome;

  setUp(() async {
    tempHome = await Directory.systemTemp.createTemp('neonsf_kernel_');
  });

  tearDown(() async {
    if (await tempHome.exists()) {
      await tempHome.delete(recursive: true);
    }
  });

  test('storage recovers active NeoNSF tasks as paused', () async {
    final storage = NeoNsfTaskStorage(homePath: tempHome.path);
    final task = DownloadTask(
      id: 'neo_recovery',
      url: 'https://example.test/file.bin',
      filename: 'file.bin',
      filepath: '${tempHome.path}\\file.bin',
      status: DownloadStatus.downloading,
      totalSize: 1024,
      downloadedSize: 256,
      kernelId: DownloadTask.neoNsfKernelId,
    );

    await storage.saveTasks(<String, DownloadTask>{task.id: task});
    final restored = (await storage.loadTasks())[task.id];

    expect(restored, isNotNull);
    expect(restored!.status, DownloadStatus.paused);
    expect(restored.speed, 0);
    expect(restored.kernelId, DownloadTask.neoNsfKernelId);
    expect(
      storage.directory.path,
      endsWith('.hdmx\\kernel\\neo_nsf'),
    );
  });

  test('known small task remains Neo-owned across kernel restart', () async {
    final storage = NeoNsfTaskStorage(homePath: tempHome.path);
    final firstBridge = _FakeNeoNsfBridge();
    final firstKernel = NeoNsfKernel(bridge: firstBridge, storage: storage);
    expect(await firstKernel.start(), isTrue);

    final taskId = await firstKernel.addDownload(
      'https://example.test/tiny.bin',
      'tiny.bin',
      saveDir: tempHome.path,
      expectedSizeHint: 4096,
      referer: 'https://example.test/page',
      userAgent: 'NeoNSF-Test/1.0',
      cookies: 'session=test',
      headers: const <String, dynamic>{'X-Test': 'persisted'},
    );
    expect(taskId, startsWith('neo_'));
    expect(firstBridge.enqueuedPayloads, hasLength(1));
    firstBridge.emit(<String, dynamic>{
      'type': 'headers',
      'taskId': taskId,
      'totalBytes': 4096,
      'httpVersion': '2.0',
      'etag': '"persisted-etag"',
      'lastModified': 'Thu, 02 Jan 2026 00:00:00 GMT',
    });
    expect(await firstKernel.pauseDownload(taskId!), isTrue);
    await firstKernel.stop();
    firstKernel.dispose();

    final secondBridge = _FakeNeoNsfBridge();
    final secondKernel = NeoNsfKernel(
      bridge: secondBridge,
      storage: NeoNsfTaskStorage(homePath: tempHome.path),
    );
    expect(await secondKernel.start(), isTrue);
    final restored = (await secondKernel.getTasks()).single;
    expect(restored.id, taskId);
    expect(restored.kernelId, DownloadTask.neoNsfKernelId);
    expect(restored.status, DownloadStatus.paused);

    expect(await secondKernel.renameTask(taskId, 'renamed.bin'), isTrue);
    await secondKernel.setConfig(
      DownloadConfig(
        proxy: ProxyConfig(enabled: true, type: 'system'),
      ),
    );
    expect(await secondKernel.resumeDownload(taskId), isTrue);
    expect(secondBridge.enqueuedPayloads, hasLength(1));
    final payload = secondBridge.enqueuedPayloads.single;
    expect(payload['taskId'], taskId);
    expect(payload['headers'],
        containsPair('Referer', 'https://example.test/page'));
    expect(payload['headers'], containsPair('Cookie', 'session=test'));
    expect(payload['headers'], containsPair('User-Agent', 'NeoNSF-Test/1.0'));
    expect(payload['headers'], containsPair('X-Test', 'persisted'));
    expect(payload['proxy'], containsPair('enabled', true));
    expect(payload['proxy'], containsPair('type', 'system'));
    expect(payload['proxy'], isNot(contains('host')));
    expect(payload['filePath'], endsWith('renamed.bin'));
    expect(payload['expectedETag'], '"persisted-etag"');
    expect(
      payload['expectedLastModified'],
      'Thu, 02 Jan 2026 00:00:00 GMT',
    );
    await secondKernel.stop();
    secondKernel.dispose();
  });

  test('native events update speed and complete a Neo-owned task', () async {
    final bridge = _FakeNeoNsfBridge();
    final kernel = NeoNsfKernel(
      bridge: bridge,
      storage: NeoNsfTaskStorage(homePath: tempHome.path),
    );
    expect(await kernel.start(), isTrue);
    final taskId = await kernel.addDownload(
      'https://example.test/tiny.bin',
      'tiny.bin',
      saveDir: tempHome.path,
      expectedSizeHint: 8192,
    );
    expect(taskId, isNotNull);

    final completed = kernel.onComplete.first;
    bridge.emit(<String, dynamic>{
      'type': 'headers',
      'taskId': taskId,
      'totalBytes': 8192,
      'httpVersion': '2.0',
    });
    bridge.emit(<String, dynamic>{
      'type': 'progress',
      'taskId': taskId,
      'downloadedBytes': 4096,
      'totalBytes': 8192,
      'instantBps': 2048.0,
      'averageBps': 1024.0,
    });
    bridge.emit(<String, dynamic>{
      'type': 'completed',
      'taskId': taskId,
      'downloadedBytes': 8192,
      'totalBytes': 8192,
      'averageBps': 1536.0,
    });

    final task = await completed;
    expect(task.status, DownloadStatus.completed);
    expect(task.progress, 100);
    expect(task.downloadedSize, 8192);
    expect(task.averageSpeed, 1536);
    expect(task.negotiatedHttpVersion, 'http2');
    expect(task.kernelId, DownloadTask.neoNsfKernelId);
    await kernel.stop();
    kernel.dispose();
  });
}

class _FakeNeoNsfBridge extends NeoNsfProcessBridge {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final List<Map<String, dynamic>> enqueuedPayloads = <Map<String, dynamic>>[];
  bool _running = false;

  void emit(Map<String, dynamic> event) => _controller.add(event);

  @override
  Stream<Map<String, dynamic>> get events => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<Map<String, dynamic>> start({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _running = true;
    return <String, dynamic>{'protocolVersion': 1, 'ready': true};
  }

  @override
  Future<bool> enqueue(Map<String, dynamic> payload) async {
    enqueuedPayloads.add(Map<String, dynamic>.from(payload));
    return true;
  }

  @override
  Future<bool> pause(String taskId) async {
    if (!_running) return false;
    emit(<String, dynamic>{'type': 'paused', 'taskId': taskId});
    return true;
  }

  @override
  Future<bool> resume(String taskId) async => false;

  @override
  Future<bool> cancel(String taskId, {bool deletePartial = true}) async {
    if (!_running) return false;
    emit(<String, dynamic>{'type': 'cancelled', 'taskId': taskId});
    return true;
  }

  @override
  Future<void> stop({bool force = false}) async {
    _running = false;
  }

  @override
  Future<void> dispose() async {
    _running = false;
    await _controller.close();
  }
}
