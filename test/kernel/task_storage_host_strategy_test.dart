import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/next/storage/task_storage.dart';

void main() {
  group('TaskStorage host strategy cache', () {
    late Directory tempHome;

    setUp(() async {
      tempHome = await Directory.systemTemp.createTemp('hdmx_host_strategy_');
    });

    tearDown(() async {
      if (await tempHome.exists()) {
        await tempHome.delete(recursive: true);
      }
    });

    test('persists host strategies across reloads', () async {
      final storage = TaskStorage(homePath: tempHome.path);
      final strategies = <String, dynamic>{
        'edgedl.me.gvt1.com': {
          'policy': 'http2_only',
          'policyExpiresAt':
              DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
          'maxConcurrency': 2,
          'maxConcurrencyExpiresAt':
              DateTime.now().add(const Duration(minutes: 20)).toIso8601String(),
        },
      };

      await storage.saveHostStrategies(strategies);
      final restored = await storage.loadHostStrategies();

      expect(restored['edgedl.me.gvt1.com'], isA<Map<String, dynamic>>());
      final restoredEntry =
          restored['edgedl.me.gvt1.com'] as Map<String, dynamic>;
      expect(restoredEntry['policy'], 'http2_only');
      expect(restoredEntry['maxConcurrency'], 2);
    });
  });
}
