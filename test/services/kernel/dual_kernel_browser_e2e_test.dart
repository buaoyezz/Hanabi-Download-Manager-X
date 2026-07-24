import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/client_config_service.dart';
import 'package:hanabi_download_manager_x/services/kernel/kernel_interface.dart';
import 'package:hanabi_download_manager_x/services/kernel/kernel_manager.dart';
import 'package:path/path.dart' as path;

import '../../../tool/download_test_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['HDMX_RUN_DUAL_KERNEL_E2E'] == '1';

  test(
    'browser API routes Auto tasks to NeoNSFX and honors explicit NSFX',
    () async {
      HttpOverrides.global = null;
      final home = Platform.environment['USERPROFILE'];
      expect(home, isNotNull);
      final outputDir = Directory(path.join(home!, 'e2e-downloads'));
      await outputDir.create(recursive: true);

      final portProbe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final bridgePort = portProbe.port;
      await portProbe.close(force: true);

      final config = ClientConfigService();
      await config.initialize();
      await config.setBrowserExtensionPort(bridgePort);
      await config.setBrowserDownloadHandlingMode(
        ClientConfigService.browserDownloadModeSilentTakeover,
      );
      await config.setDownloadKernelId(ClientConfigService.downloadKernelNsfx);

      final downloadServer = LocalDownloadTestServer(port: 0);
      await downloadServer.start();
      final manager = KernelManager();
      try {
        expect(await manager.start(), isTrue);
        expect(
          await manager.selectKernel(ClientConfigService.downloadKernelAuto),
          isTrue,
          reason: manager.neoNsfStartupError,
        );

        const tinySize = 512 * 1024;
        final tinyId = await _postBrowserDownload(
          bridgePort,
          url: downloadServer.baseUri
              .resolve('download/normal/512k.bin?resource=dual-tiny')
              .toString(),
          filename: 'dual-tiny.bin',
          saveDir: outputDir.path,
          size: tinySize,
        );
        expect(tinyId, startsWith('neo_'));
        final tinyTask = await _waitForTask(
          manager,
          tinyId,
          (task) => task.status == DownloadStatus.completed,
        );
        expect(tinyTask.kernelId, DownloadTask.neoNsfKernelId);
        expect(
          await File(tinyTask.filepath).readAsBytes(),
          DownloadTestPattern.bytes(0, tinySize),
        );

        const largeSize = 16 * 1024 * 1024;
        final largeId = await _postBrowserDownload(
          bridgePort,
          url: downloadServer.baseUri
              .resolve(
                'download/slow/16m.bin?resource=dual-large&chunkBytes=32768&delayMs=5',
              )
              .toString(),
          filename: 'dual-large.bin',
          saveDir: outputDir.path,
          size: largeSize,
        );
        expect(largeId, startsWith('neo_'));
        final largeTask = await _waitForTask(
          manager,
          largeId,
          (_) => true,
        );
        expect(largeTask.kernelId, DownloadTask.neoNsfKernelId);
        expect(await manager.cancelDownload(largeId), isTrue);

        expect(
          await manager.selectKernel(ClientConfigService.downloadKernelNsfx),
          isTrue,
        );
        final stableId = await _postBrowserDownload(
          bridgePort,
          url: downloadServer.baseUri
              .resolve('download/slow/512k.bin?resource=dual-nsfx&delayMs=5')
              .toString(),
          filename: 'dual-nsfx.bin',
          saveDir: outputDir.path,
          size: tinySize,
        );
        expect(stableId, isNot(startsWith('neo_')));
        final stableTask = await _waitForTask(manager, stableId, (_) => true);
        expect(stableTask.kernelId, DownloadTask.nsfxKernelId);
        expect(await manager.cancelDownload(stableId), isTrue);

        final tasks = await manager.getTasks();
        expect(tasks.any((task) => task.id == tinyId), isTrue);
        expect(
          tasks.where((task) => task.id == tinyId).single.kernelId,
          DownloadTask.neoNsfKernelId,
        );
        expect(config.getDownloadKernelId(), DownloadTask.nsfxKernelId);
      } finally {
        await manager.stop();
        await downloadServer.close();
      }
    },
    skip: enabled
        ? false
        : 'Set HDMX_RUN_DUAL_KERNEL_E2E=1 with a temporary USERPROFILE.',
    timeout: const Timeout(Duration(seconds: 90)),
  );
}

Future<String> _postBrowserDownload(
  int port, {
  required String url,
  required String filename,
  required String saveDir,
  required int size,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/download/add'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(<String, dynamic>{
      'url': url,
      'filename': filename,
      'save_dir': saveDir,
      'file_size': size,
      'from_browser': true,
    }));
    final response = await request.close();
    final decoded = jsonDecode(await utf8.decoder.bind(response).join())
        as Map<String, dynamic>;
    expect(response.statusCode, HttpStatus.ok, reason: decoded.toString());
    expect(decoded['success'], isTrue, reason: decoded.toString());
    return decoded['task_id']!.toString();
  } finally {
    client.close(force: true);
  }
}

Future<DownloadTask> _waitForTask(
  KernelManager manager,
  String taskId,
  bool Function(DownloadTask task) predicate,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    for (final task in await manager.getTasks()) {
      if (task.id == taskId && predicate(task)) return task;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Task $taskId did not reach the expected state.');
}
