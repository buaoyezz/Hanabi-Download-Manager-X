import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/kernel_interface.dart';
import 'package:hanabi_download_managerx/services/kernel/next/config/download_config.dart';

void main() {
  group('HTTP config fields', () {
    test(
        'NsfxConfig keeps supported HTTP policy and normalizes empty user-agent',
        () {
      final config = NsfxConfig.fromJson({
        'default_user_agent': '   ',
        'http_version_policy': 'http3_only',
      });

      expect(config.defaultUserAgent, NsfxConfig.defaultUserAgentFallback);
      expect(config.httpVersionPolicy, NsfxHttpVersionPolicy.http3Only);
    });

    test('NsfxHttpVersionPolicy falls back http3 to auto for dart:io transport',
        () {
      expect(
        NsfxHttpVersionPolicy.normalizeForDartIo(
            NsfxHttpVersionPolicy.http3Only),
        NsfxHttpVersionPolicy.auto,
      );
      expect(
        NsfxHttpVersionPolicy.isSupportedByDartIo(
            NsfxHttpVersionPolicy.http3Only),
        isFalse,
      );
    });

    test('DownloadConfig normalizes invalid HTTP policy', () {
      final config = DownloadConfig.fromJson({
        'http_version_policy': 'invalid',
      });

      expect(config.httpVersionPolicy, 'auto');
      expect(config.defaultUserAgent, DownloadConfig.defaultUserAgentFallback);
    });
  });
}
