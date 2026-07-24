import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/updater_launch_monitor.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('updater_launch_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reports ready after the updater writes its handshake', () async {
    final readyPath = '${tempDir.path}${Platform.pathSeparator}ready';
    final exit = Completer<int>();
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 20), () async {
        await File(readyPath).writeAsString('ready');
      }),
    );

    final result = await UpdaterLaunchMonitor.waitForReady(
      readyFilePath: readyPath,
      exitCode: exit.future,
      timeout: const Duration(seconds: 1),
      pollInterval: const Duration(milliseconds: 5),
    );

    expect(result.status, UpdaterLaunchStatus.ready);
    expect(result.isReady, isTrue);
  });

  test('reports an updater that exits before becoming ready', () async {
    final result = await UpdaterLaunchMonitor.waitForReady(
      readyFilePath: '${tempDir.path}${Platform.pathSeparator}missing',
      exitCode: Future<int>.value(23),
      timeout: const Duration(seconds: 1),
      pollInterval: const Duration(milliseconds: 5),
    );

    expect(result.status, UpdaterLaunchStatus.exitedEarly);
    expect(result.exitCode, 23);
  });

  test('times out while a process stays alive without a handshake', () async {
    final result = await UpdaterLaunchMonitor.waitForReady(
      readyFilePath: '${tempDir.path}${Platform.pathSeparator}missing',
      exitCode: Completer<int>().future,
      timeout: const Duration(milliseconds: 30),
      pollInterval: const Duration(milliseconds: 5),
    );

    expect(result.status, UpdaterLaunchStatus.timedOut);
    expect(result.exitCode, isNull);
  });
}
