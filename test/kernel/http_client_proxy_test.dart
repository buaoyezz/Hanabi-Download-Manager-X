import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_managerx/services/kernel/next/downloader/http_client.dart';
import 'package:hanabi_download_managerx/services/kernel/next/downloader/proxy_runtime.dart';
import 'dart:async';

void main() {
  group('NsfxHttpClient proxy settings', () {
    setUp(() {
      NsfxHttpClient.clearAdaptivePolicyHints();
      NsfxHttpClient.clearSharedProxyState();
    });

    tearDown(() {
      NsfxHttpClient.clearAdaptivePolicyHints();
      NsfxHttpClient.clearSharedProxyState();
    });

    test('returns socks5 directive for socks5 proxy type', () {
      final config = NsfxConfig(
        proxy: NsfxProxyConfig(
          enabled: true,
          type: 'socks5',
          host: '10.0.0.2',
          port: 1080,
        ),
      );

      final client = NsfxHttpClient(config);
      final proxy = client.getActiveProxySettings(
        'https://example.com/archive.bin',
      );

      expect(proxy.proxyDirective, 'SOCKS5 10.0.0.2:1080');
      expect(proxy.supportsHttpBasicAuth, isFalse);
    });

    test('uses system proxy mode without forcing host:port proxy string', () {
      final configuredProxy = NsfxProxyRuntime.configuredFromNextConfig(
        NsfxProxyConfig(
          enabled: true,
          type: 'system',
        ),
      );

      expect(configuredProxy.usesSystemSettings, isTrue);
    });

    test('supports http basic auth only for non-socks5 proxies', () {
      final config = NsfxConfig(
        proxy: NsfxProxyConfig(
          enabled: true,
          type: 'http',
          host: '127.0.0.1',
          port: 7897,
          requiresAuth: true,
          username: 'user',
          password: 'pass',
        ),
      );

      final client = NsfxHttpClient(config);
      final proxy = client.getActiveProxySettings(
        'https://example.com/archive.bin',
      );

      expect(proxy.supportsHttpBasicAuth, isTrue);
    });

    test('shares bad proxy cache across clients until cleared', () {
      final config = NsfxConfig(
        proxy: NsfxProxyConfig(
            enabled: true, type: 'http', host: '127.0.0.1', port: 7897),
      );

      final firstClient = NsfxHttpClient(config);
      expect(
        firstClient
            .getActiveProxySettings('https://example.com/archive.bin')
            .hasProxy,
        isTrue,
      );

      firstClient.switchToDirectOnProxyError();
      expect(
        firstClient
            .getActiveProxySettings('https://example.com/archive.bin')
            .isDirect,
        isTrue,
      );

      final secondClient = NsfxHttpClient(config);
      expect(
        secondClient
            .getActiveProxySettings('https://example.com/archive.bin')
            .isDirect,
        isTrue,
      );

      NsfxHttpClient.clearSharedProxyState();

      final thirdClient = NsfxHttpClient(config);
      expect(
        thirdClient
            .getActiveProxySettings('https://example.com/archive.bin')
            .hasProxy,
        isTrue,
      );
    });

    test(
        'manual proxy mode treats transport connect errors as fallback eligible',
        () {
      final config = NsfxConfig(
        proxy: NsfxProxyConfig(
          enabled: true,
          type: 'http',
          host: '127.0.0.1',
          port: 7897,
        ),
      );

      final client = NsfxHttpClient(config);
      client.getActiveProxySettings('https://example.com/archive.bin');
      expect(
        client.shouldSwitchToDirectOnError(
          Exception('Connection refused 127.0.0.1:7897'),
        ),
        isTrue,
      );
    });

    test('proxy fallback detector stays off when proxy is disabled', () {
      final config = NsfxConfig(
        proxy: NsfxProxyConfig(enabled: false, type: 'system'),
      );

      final client = NsfxHttpClient(config);
      client.getActiveProxySettings('https://example.com/archive.bin');
      expect(
        client.shouldSwitchToDirectOnError(Exception('Connection refused')),
        isFalse,
      );
    });

    test('bypasses configured proxy for localhost targets', () {
      final config = NsfxConfig(
        proxy: NsfxProxyConfig(
          enabled: true,
          type: 'http',
          host: '10.0.0.2',
          port: 8080,
        ),
      );

      final client = NsfxHttpClient(config);
      expect(
        client.getActiveProxySettings('http://localhost:8000/health').isDirect,
        isTrue,
      );
      expect(
        client
            .getActiveProxySettings('https://example.com/archive.bin')
            .hasProxy,
        isTrue,
      );
    });

    test('HTTP version fallback only reacts to protocol negotiation errors',
        () {
      expect(
        NsfxHttpClient.isHttpProtocolNegotiationError(
          Exception('Connection refused'),
        ),
        isFalse,
      );
      expect(
        NsfxHttpClient.isHttpProtocolNegotiationError(
          Exception('Request timed out'),
        ),
        isFalse,
      );
      expect(
        NsfxHttpClient.isHttpProtocolNegotiationError(
          Exception('ALPN negotiation failed for h2'),
        ),
        isTrue,
      );
      expect(
        NsfxHttpClient.isHttpProtocolNegotiationError(
          Exception('QUIC handshake failed'),
        ),
        isTrue,
      );
      expect(
        NsfxHttpClient.isHttpVersionFallbackEligibleStatus(
          500,
          usesStrictTransport: true,
        ),
        isTrue,
      );
      expect(
        NsfxHttpClient.isHttpVersionFallbackEligibleStatus(
          421,
          usesStrictTransport: true,
        ),
        isTrue,
      );
      expect(
        NsfxHttpClient.isHttpVersionFallbackEligibleStatus(
          404,
          usesStrictTransport: true,
        ),
        isFalse,
      );
    });

    test('strict transport also allows fallback on response header timeout',
        () {
      final timeout = TimeoutException('Future not completed');

      expect(
        NsfxHttpClient.isHttpVersionFallbackEligibleError(
          timeout,
          usesStrictTransport: true,
        ),
        isTrue,
      );
      expect(
        NsfxHttpClient.isHttpVersionFallbackEligibleError(
          timeout,
          usesStrictTransport: false,
        ),
        isFalse,
      );
    });

    test('normalizes observed HTTP versions from transport responses', () {
      expect(
        NsfxHttpClient.normalizeObservedHttpVersion('HTTP/2'),
        'http2',
      );
      expect(
        NsfxHttpClient.normalizeObservedHttpVersion('http1_1'),
        'http1_1',
      );
      expect(
        NsfxHttpClient.normalizeObservedHttpVersion('h3'),
        'http3',
      );
      expect(
        NsfxHttpClient.normalizeObservedHttpVersion('other'),
        'other',
      );
    });

    test('derives Chromium-style connection hints from observed protocol', () {
      expect(
        NsfxHttpClient.coarseConnectionTypeForVersion('http1_1'),
        NsfxHttpConnectionType.http1,
      );
      expect(
        NsfxHttpClient.coarseConnectionTypeForVersion('http2'),
        NsfxHttpConnectionType.http2,
      );
      expect(
        NsfxHttpClient.coarseConnectionTypeForVersion('http3'),
        NsfxHttpConnectionType.quic,
      );
      expect(
        NsfxHttpClient.coarseConnectionTypeForVersion(null),
        NsfxHttpConnectionType.unknown,
      );
    });

    test('keeps only strong validators for ranged resumes', () {
      expect(
        NsfxHttpClient.extractStrongEtag('"etag-123"'),
        '"etag-123"',
      );
      expect(
        NsfxHttpClient.extractStrongEtag('W/"etag-123"'),
        isNull,
      );
      expect(
        NsfxHttpClient.selectIfRangeValidator(
          etag: '"etag-123"',
          lastModified: 'Wed, 21 Oct 2015 07:28:00 GMT',
        ),
        '"etag-123"',
      );
      expect(
        NsfxHttpClient.selectIfRangeValidator(
          etag: 'W/"etag-123"',
          lastModified: 'Wed, 21 Oct 2015 07:28:00 GMT',
        ),
        'Wed, 21 Oct 2015 07:28:00 GMT',
      );
    });

    test('file info marks parallel-safe connections conservatively', () {
      final safeInfo = FileInfo(
        size: 1024,
        supportsRange: true,
        negotiatedHttpVersion: 'http1_1',
        connectionType: NsfxHttpConnectionType.http1,
        etag: '"etag-123"',
      );
      final unsafeInfo = FileInfo(
        size: 1024,
        supportsRange: true,
        negotiatedHttpVersion: 'http2',
        connectionType: NsfxHttpConnectionType.http2,
        etag: '"etag-123"',
      );

      expect(safeInfo.hasStrongValidator, isTrue);
      expect(safeInfo.ifRangeValidator, '"etag-123"');
      expect(safeInfo.usesParallelSafeConnection, isTrue);
      expect(unsafeInfo.usesParallelSafeConnection, isFalse);
    });

    test('strict transport falls back on response body decode errors', () {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.http2Only,
      );

      final client = NsfxHttpClient(config);
      expect(
          client.effectiveHttpVersionPolicy, NsfxHttpVersionPolicy.http2Only);

      final triggered = client.fallbackHttpPolicyOnTransferError(
        Exception('[RhttpUnknownException] error decoding response body'),
      );

      expect(triggered, isTrue);
      expect(
          client.effectiveHttpVersionPolicy, NsfxHttpVersionPolicy.http1Only);
    });

    test('http1 transport ignores response body decode fallback', () {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.http1Only,
      );

      final client = NsfxHttpClient(config);
      final triggered = client.fallbackHttpPolicyOnTransferError(
        Exception('[RhttpUnknownException] error decoding response body'),
      );

      expect(triggered, isFalse);
      expect(
          client.effectiveHttpVersionPolicy, NsfxHttpVersionPolicy.http1Only);
    });

    test('strict transport falls back on wrapped HTTP 500 status', () {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.http2Only,
      );

      final client = NsfxHttpClient(config);
      final triggered = client.fallbackHttpPolicyOnTransferError(
        Exception('HttpException: HTTP 500'),
      );

      expect(triggered, isTrue);
      expect(
        client.effectiveHttpVersionPolicy,
        NsfxHttpVersionPolicy.http1Only,
      );
    });

    test('strict transport falls back on rhttp connection close request errors',
        () {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.http3Only,
      );

      final client = NsfxHttpClient(config);
      final triggered = client.fallbackHttpPolicyOnTransferError(
        Exception(
          '[RhttpUnknownException] request::Error { kind: Request, '
          'source: ConnectionClosed(ConnectionClose { '
          'error_code: Code::crypto(28), frame_type: None, reason: b"" }) }',
        ),
      );

      expect(triggered, isTrue);
      expect(
        client.effectiveHttpVersionPolicy,
        NsfxHttpVersionPolicy.http2Only,
      );
    });

    test('adaptive hint reuses downgraded policy for same host only', () {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.auto,
      );

      final client = NsfxHttpClient(config);
      final triggered = client.fallbackHttpPolicyOnTransferError(
        Exception('HttpException: HTTP 500'),
        url: 'https://edgedl.me.gvt1.com/android/studio.exe',
      );

      expect(triggered, isTrue);
      expect(
        client.effectiveHttpVersionPolicy,
        NsfxHttpVersionPolicy.http2Only,
      );

      final sameHostClient = NsfxHttpClient(config);
      sameHostClient.adoptAdaptivePolicyHint(
        'https://edgedl.me.gvt1.com/android/other.exe',
      );
      expect(
        sameHostClient.effectiveHttpVersionPolicy,
        NsfxHttpVersionPolicy.http2Only,
      );

      final otherHostClient = NsfxHttpClient(config);
      otherHostClient.adoptAdaptivePolicyHint(
        'https://example.com/download.bin',
      );
      expect(
        otherHostClient.effectiveHttpVersionPolicy,
        NsfxHttpVersionPolicy.http1Only,
      );
    });

    test('adaptive hint exposes cached policy decision reason', () {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.auto,
      );

      final client = NsfxHttpClient(config);
      expect(
        client.fallbackHttpPolicyOnTransferError(
          Exception('HttpException: HTTP 500'),
          url: 'https://edgedl.me.gvt1.com/android/studio.exe',
        ),
        isTrue,
      );

      final followupClient = NsfxHttpClient(config);
      followupClient.adoptAdaptivePolicyHint(
        'https://edgedl.me.gvt1.com/android/followup.exe',
      );

      expect(
        followupClient.lastPolicyDecisionReason,
        contains('Cached host policy reused for edgedl.me.gvt1.com'),
      );
      expect(
        followupClient.lastPolicyDecisionReason,
        contains('HTTP/1.1 -> HTTP/2'),
      );
    });

    test('adaptive hint remembers latest protocol candidate reached', () {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.auto,
      );

      final client = NsfxHttpClient(config);
      expect(
        client.fallbackHttpPolicyOnTransferError(
          Exception('HttpException: HTTP 500'),
          url: 'https://edgedl.me.gvt1.com/android/studio.exe',
        ),
        isTrue,
      );
      expect(
        client.fallbackHttpPolicyOnTransferError(
          Exception('HttpException: HTTP 500'),
          url: 'https://edgedl.me.gvt1.com/android/studio.exe',
        ),
        isTrue,
      );
      expect(
        client.effectiveHttpVersionPolicy,
        NsfxHttpVersionPolicy.http3Only,
      );

      final followupClient = NsfxHttpClient(config);
      followupClient.adoptAdaptivePolicyHint(
        'https://edgedl.me.gvt1.com/android/followup.exe',
      );
      expect(
        followupClient.effectiveHttpVersionPolicy,
        NsfxHttpVersionPolicy.http3Only,
      );
    });

    test('adaptive hint expires back to requested policy', () async {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.auto,
      );

      final client = NsfxHttpClient(
        config,
        adaptiveStatusHintTtl: const Duration(milliseconds: 5),
      );
      expect(
        client.fallbackHttpPolicyOnTransferError(
          Exception('HttpException: HTTP 500'),
          url: 'https://edgedl.me.gvt1.com/android/studio.exe',
        ),
        isTrue,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final followupClient = NsfxHttpClient(config);
      followupClient.adoptAdaptivePolicyHint(
        'https://edgedl.me.gvt1.com/android/after-expiry.exe',
      );
      expect(
        followupClient.effectiveHttpVersionPolicy,
        NsfxHttpVersionPolicy.http1Only,
      );
    });

    test('fallback exposes latest protocol downgrade reason', () {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.http2Only,
      );

      final client = NsfxHttpClient(config);
      expect(
        client.fallbackHttpPolicyOnTransferError(
          Exception('HttpException: HTTP 500'),
          url: 'https://example.com/archive.bin',
        ),
        isTrue,
      );

      expect(
        client.lastPolicyDecisionReason,
        'HTTP fallback triggered by response status 500: HTTP/2 -> HTTP/1.1.',
      );
    });

    test('host strategy remembers conservative concurrency cap per host', () {
      NsfxHttpClient.rememberHostConcurrencyCap(
        'https://edgedl.me.gvt1.com/android/studio.exe',
        3,
      );

      expect(
        NsfxHttpClient.suggestedMaxConcurrencyForUrl(
          'https://edgedl.me.gvt1.com/android/other.exe',
          requested: 8,
        ),
        3,
      );
      expect(
        NsfxHttpClient.suggestedMaxConcurrencyForUrl(
          'https://example.com/download.bin',
          requested: 8,
        ),
        8,
      );
    });

    test('host strategy export and restore preserves policy and concurrency',
        () {
      final config = NsfxConfig(
        httpVersionPolicy: NsfxHttpVersionPolicy.auto,
      );
      final client = NsfxHttpClient(config);

      expect(
        client.fallbackHttpPolicyOnTransferError(
          Exception('HttpException: HTTP 500'),
          url: 'https://edgedl.me.gvt1.com/android/studio.exe',
        ),
        isTrue,
      );
      NsfxHttpClient.rememberHostConcurrencyCap(
        'https://edgedl.me.gvt1.com/android/studio.exe',
        2,
      );

      final exported = NsfxHttpClient.exportAdaptiveHostStrategies();
      expect(exported, contains('edgedl.me.gvt1.com'));

      NsfxHttpClient.clearAdaptivePolicyHints();
      NsfxHttpClient.restoreAdaptiveHostStrategies(exported);

      final followupClient = NsfxHttpClient(config);
      followupClient.adoptAdaptivePolicyHint(
        'https://edgedl.me.gvt1.com/android/followup.exe',
      );
      expect(
        followupClient.effectiveHttpVersionPolicy,
        NsfxHttpVersionPolicy.http2Only,
      );
      expect(
        NsfxHttpClient.suggestedMaxConcurrencyForUrl(
          'https://edgedl.me.gvt1.com/android/followup.exe',
          requested: 8,
        ),
        2,
      );
    });
  });
}
