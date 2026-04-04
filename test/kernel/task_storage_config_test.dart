import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/next/storage/task_storage.dart';
import 'package:path/path.dart' as path;

void main() {
  group('TaskStorage config migration', () {
    late Directory tempHome;

    setUp(() async {
      tempHome = await Directory.systemTemp.createTemp('hdmx_task_storage_');
    });

    tearDown(() async {
      if (await tempHome.exists()) {
        await tempHome.delete(recursive: true);
      }
    });

    test('migrates legacy implicit system proxy default to disabled', () async {
      final storageDir = Directory(path.join(tempHome.path, '.hdmx', 'kernel'));
      await storageDir.create(recursive: true);

      final configFile = File(path.join(storageDir.path, 'config.json'));
      await configFile.writeAsString(jsonEncode({
        'threads': 8,
        'proxy': {
          'enabled': true,
          'type': 'system',
          'host': '127.0.0.1',
          'port': 7897,
          'requires_auth': false,
        },
      }));

      final storage = TaskStorage(homePath: tempHome.path);
      final config = await storage.loadConfig();

      expect(config.proxy.enabled, isFalse);
      expect(config.proxy.type, 'system');
      expect(config.proxy.host, isEmpty);

      final savedJson =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final savedProxy = savedJson['proxy'] as Map<String, dynamic>;

      expect(savedProxy['enabled'], isFalse);
      expect(savedProxy['type'], 'system');
      expect(savedProxy['host'], isEmpty);
    });

    test('keeps explicit system proxy choice intact', () async {
      final storageDir = Directory(path.join(tempHome.path, '.hdmx', 'kernel'));
      await storageDir.create(recursive: true);

      final configFile = File(path.join(storageDir.path, 'config.json'));
      await configFile.writeAsString(jsonEncode({
        'threads': 8,
        'proxy': {
          'enabled': true,
          'type': 'system',
          'host': '',
          'port': 7897,
          'requires_auth': false,
        },
      }));

      final storage = TaskStorage(homePath: tempHome.path);
      final config = await storage.loadConfig();

      expect(config.proxy.enabled, isTrue);
      expect(config.proxy.type, 'system');
      expect(config.proxy.host, isEmpty);
    });
  });
}
