import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_managerx/services/kernel/next/models/task.dart';
import 'package:hanabi_download_managerx/services/kernel/next/storage/task_storage.dart';
import 'package:path/path.dart' as path;

void main() {
  group('TaskStorage task metadata', () {
    late Directory tempHome;

    setUp(() async {
      tempHome = await Directory.systemTemp.createTemp('hdmx_task_metadata_');
    });

    tearDown(() async {
      if (await tempHome.exists()) {
        await tempHome.delete(recursive: true);
      }
    });

    test('persists validator and connection metadata for resume safety',
        () async {
      final storage = TaskStorage(homePath: tempHome.path);
      final task = Task(
        id: 'task-1',
        url: 'https://example.com/file.bin',
        filename: 'file.bin',
        filepath: path.join(tempHome.path, 'file.bin'),
        negotiatedHttpVersion: 'http1_1',
        httpPolicyDecisionReason:
            'Cached host policy reused for example.com: HTTP/3 -> HTTP/2.',
        ifRangeValidator: '"etag-123"',
        httpConnectionType: 'http1',
        resumeSafetyLevel: NsfxResumeSafetyLevel.verifiedNoValidator,
        resumeDecisionLabel: 'Resume Verified',
        resumeDecisionReason: 'Persisted partial data matched current size.',
        hostConcurrencyCap: 4,
        hostConcurrencyReason:
            'Cached host concurrency cap applied: requested 8, starting with 4.',
      );

      await storage.saveTasks({'task-1': task});
      final loadedTasks = await storage.loadTasks();
      final restored = loadedTasks['task-1'];

      expect(restored, isNotNull);
      expect(restored!.negotiatedHttpVersion, 'http1_1');
      expect(
        restored.httpPolicyDecisionReason,
        'Cached host policy reused for example.com: HTTP/3 -> HTTP/2.',
      );
      expect(restored.ifRangeValidator, '"etag-123"');
      expect(restored.httpConnectionType, 'http1');
      expect(
        restored.resumeSafetyLevel,
        NsfxResumeSafetyLevel.verifiedNoValidator,
      );
      expect(restored.resumeDataOrigin, NsfxResumeDataOrigin.persisted);
      expect(restored.resumeDecisionLabel, 'Resume Verified');
      expect(
        restored.resumeDecisionReason,
        'Persisted partial data matched current size.',
      );
      expect(restored.hostConcurrencyCap, 4);
      expect(
        restored.hostConcurrencyReason,
        'Cached host concurrency cap applied: requested 8, starting with 4.',
      );
    });
  });
}
