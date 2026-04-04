import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/kernel_interface.dart';
import 'package:hanabi_download_managerx/services/kernel/next/config/download_config.dart';

void main() {
  group('HTTP config fields', () {
    test('NsfxConfig keeps proxy disabled by default', () {
      final config = NsfxConfig();

      expect(config.proxy.enabled, isFalse);
      expect(config.proxy.type, 'system');
      expect(config.proxy.host, isEmpty);
    });

    test('NsfxConfig.fromJson keeps proxy disabled when proxy is absent', () {
      final config = NsfxConfig.fromJson({});

      expect(config.proxy.enabled, isFalse);
      expect(config.proxy.type, 'system');
      expect(config.proxy.host, isEmpty);
    });

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

    test('NsfxHttpVersionPolicy keeps strict chain then fallback', () {
      expect(
        NsfxHttpVersionPolicy.fallbackChain(NsfxHttpVersionPolicy.http3Only),
        const [
          NsfxHttpVersionPolicy.http3Only,
          NsfxHttpVersionPolicy.http2Only,
          NsfxHttpVersionPolicy.http1Only,
        ],
      );
      expect(
        NsfxHttpVersionPolicy.fallbackChain(NsfxHttpVersionPolicy.http2Only),
        const [
          NsfxHttpVersionPolicy.http2Only,
          NsfxHttpVersionPolicy.http1Only,
        ],
      );
      expect(
        NsfxHttpVersionPolicy.fallbackChain(NsfxHttpVersionPolicy.auto),
        const [
          NsfxHttpVersionPolicy.http1Only,
          NsfxHttpVersionPolicy.http2Only,
          NsfxHttpVersionPolicy.http3Only,
        ],
      );
      expect(
        NsfxHttpVersionPolicy.preferredChainForUrl(
          NsfxHttpVersionPolicy.auto,
          url: 'https://example.com/file.bin',
        ),
        const [
          NsfxHttpVersionPolicy.http1Only,
          NsfxHttpVersionPolicy.http2Only,
          NsfxHttpVersionPolicy.http3Only,
        ],
      );
      expect(
        NsfxHttpVersionPolicy.preferredChainForUrl(
          NsfxHttpVersionPolicy.auto,
          url: 'http://example.com/file.bin',
        ),
        const [
          NsfxHttpVersionPolicy.http1Only,
        ],
      );
      expect(
        NsfxHttpVersionPolicy.preferredChainForUrl(
          NsfxHttpVersionPolicy.http2Only,
          url: 'http://example.com/file.bin',
        ),
        const [
          NsfxHttpVersionPolicy.http1Only,
        ],
      );
      expect(
        NsfxHttpVersionPolicy.preferredChainForUrl(
          NsfxHttpVersionPolicy.http3Only,
          url: 'https://example.com/file.bin',
        ),
        const [
          NsfxHttpVersionPolicy.http3Only,
          NsfxHttpVersionPolicy.http2Only,
          NsfxHttpVersionPolicy.http1Only,
        ],
      );
    });

    test('NsfxHttpVersionPolicy downgrades http3 for dart:io transport', () {
      expect(
        NsfxHttpVersionPolicy.normalizeForDartIo(
            NsfxHttpVersionPolicy.http3Only),
        NsfxHttpVersionPolicy.http2Only,
      );
      expect(
        NsfxHttpVersionPolicy.normalizeForDartIo(
            NsfxHttpVersionPolicy.http2Only),
        NsfxHttpVersionPolicy.http2Only,
      );
      expect(
        NsfxHttpVersionPolicy.fallbackChainForDartIo(
            NsfxHttpVersionPolicy.http3Only),
        const [
          NsfxHttpVersionPolicy.http2Only,
          NsfxHttpVersionPolicy.http1Only,
        ],
      );
      expect(
        NsfxHttpVersionPolicy.fallbackChainForDartIo(
            NsfxHttpVersionPolicy.http2Only),
        const [
          NsfxHttpVersionPolicy.http2Only,
          NsfxHttpVersionPolicy.http1Only,
        ],
      );
      expect(
        NsfxHttpVersionPolicy.fallbackChainForDartIo(
            NsfxHttpVersionPolicy.auto),
        const [
          NsfxHttpVersionPolicy.http1Only,
          NsfxHttpVersionPolicy.http2Only,
        ],
      );
      expect(
        NsfxHttpVersionPolicy.isSupportedByDartIo(
            NsfxHttpVersionPolicy.http2Only),
        isTrue,
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
