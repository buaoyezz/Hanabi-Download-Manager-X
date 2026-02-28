import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/next/config/download_config.dart';

void main() {
  group('DynamicSegmentConfig.calculate', () {
    test('uses single segment for very small files in auto mode', () {
      final config = NsfxConfig(mode: 'auto', threads: 8, enableDynamicSegments: true);

      final result = DynamicSegmentConfig.calculate(4 * 1024 * 1024, config);

      expect(result.$1, 1);
      expect(result.$2, 1);
    });

    test('respects manual segment limit for thread count', () {
      final config = NsfxConfig(mode: 'manual', threads: 16, segments: 4);

      final result = DynamicSegmentConfig.calculate(100 * 1024 * 1024, config);

      expect(result.$1, 4);
      expect(result.$2, 4);
    });

    test('caps auto mode segments to configured maximum strategy', () {
      final config = NsfxConfig(mode: 'auto', threads: 64, enableDynamicSegments: true);

      final result = DynamicSegmentConfig.calculate(10 * 1024 * 1024 * 1024, config);

      expect(result.$2, lessThanOrEqualTo(32));
      expect(result.$1, lessThanOrEqualTo(result.$2));
    });
  });
}
