import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/kernel_interface.dart'
    as kernel;
import 'package:hanabi_download_managerx/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_managerx/services/kernel/next/downloader/proxy_runtime.dart';

void main() {
  group('NsfxProxyRuntime', () {
    setUp(() async {
      await NsfxProxyRuntime.stopSystemProxyObserver();
      NsfxProxyRuntime.clearBadProxies();
    });

    tearDown(() async {
      await NsfxProxyRuntime.stopSystemProxyObserver();
      NsfxProxyRuntime.clearBadProxies();
    });

    test('resolves configured manual and system proxies consistently', () {
      final manual = NsfxProxyRuntime.configuredFromNextConfig(
        NsfxProxyConfig(
          enabled: true,
          type: 'http',
          host: '',
          port: 7897,
        ),
      );
      final system = NsfxProxyRuntime.configuredFromKernelConfig(
        kernel.ProxyConfig(
          enabled: true,
          type: 'system',
        ),
      );

      expect(manual.isManual, isTrue);
      expect(manual.host, '127.0.0.1');
      expect(manual.port, 7897);
      expect(system.usesSystemSettings, isTrue);
    });

    test('bypasses localhost targets even when manual proxy is enabled', () {
      final config = NsfxProxyConfig(
        enabled: true,
        type: 'http',
        host: '10.0.0.2',
        port: 8080,
      );

      final resolved = NsfxProxyRuntime.resolveFromNextConfig(
        config,
        Uri.parse('http://localhost:9000/health'),
      );

      expect(resolved.isDirect, isTrue);
    });

    test('shares bad proxy cache across kernel and next config resolvers', () {
      final nextConfig = NsfxProxyConfig(
        enabled: true,
        type: 'http',
        host: '127.0.0.1',
        port: 7897,
      );
      final kernelConfig = kernel.ProxyConfig(
        enabled: true,
        type: 'http',
        host: '127.0.0.1',
        port: 7897,
      );
      final targetUri = Uri.parse('https://example.com/archive.bin');

      final initial = NsfxProxyRuntime.resolveFromNextConfig(
        nextConfig,
        targetUri,
      );
      expect(initial.hasProxy, isTrue);

      NsfxProxyRuntime.markProxyFailure(initial);

      expect(
        NsfxProxyRuntime.resolveFromNextConfig(nextConfig, targetUri).isDirect,
        isTrue,
      );
      expect(
        NsfxProxyRuntime.resolveFromKernelConfig(kernelConfig, targetUri)
            .isDirect,
        isTrue,
      );
    });

    test('parses per-scheme Windows proxy lists conservatively', () {
      final resolved = NsfxProxyRuntime.resolveProxyListString(
        'http=proxy-a:8080;https=proxy-b:8443;socks=socks-box:1080',
        Uri.parse('https://example.com/archive.bin'),
      );

      expect(resolved.isManual, isTrue);
      expect(resolved.type, 'http');
      expect(resolved.host, 'proxy-b');
      expect(resolved.port, 8443);
    });

    test('respects bypass list and rotates away from bad proxies', () {
      final targetUri = Uri.parse('https://downloads.example.com/archive.bin');

      final first = NsfxProxyRuntime.resolveProxyListString(
        'proxy-a:8080,proxy-b:8081,DIRECT',
        targetUri,
      );
      expect(first.host, 'proxy-a');

      NsfxProxyRuntime.markProxyFailure(first);

      final second = NsfxProxyRuntime.resolveProxyListString(
        'proxy-a:8080,proxy-b:8081,DIRECT',
        targetUri,
      );
      expect(second.host, 'proxy-b');

      final bypassed = NsfxProxyRuntime.resolveProxyListString(
        'proxy-a:8080,proxy-b:8081,DIRECT',
        targetUri,
        bypassList: '*.example.com;<local>',
      );
      expect(bypassed.isDirect, isTrue);
    });

    test('builds HttpClient proxy chains while skipping bad proxies', () {
      final targetUri = Uri.parse('https://downloads.example.com/archive.bin');

      expect(
        NsfxProxyRuntime.buildHttpClientProxyDirective(
          'proxy-a:8080,proxy-b:8081,DIRECT',
          targetUri,
        ),
        'PROXY proxy-a:8080; PROXY proxy-b:8081; DIRECT',
      );

      final first = NsfxProxyRuntime.resolveProxyListString(
        'proxy-a:8080,proxy-b:8081,DIRECT',
        targetUri,
      );
      NsfxProxyRuntime.markProxyFailure(first);

      expect(
        NsfxProxyRuntime.buildHttpClientProxyDirective(
          'proxy-a:8080,proxy-b:8081,DIRECT',
          targetUri,
        ),
        'PROXY proxy-b:8081; DIRECT',
      );
    });

    test('keeps the active proxy aligned with the remaining chain', () {
      final targetUri = Uri.parse('https://downloads.example.com/archive.bin');

      final first = NsfxProxyRuntime.resolveProxyListString(
        'proxy-a:8080,proxy-b:8081,DIRECT',
        targetUri,
      );
      expect(first.host, 'proxy-a');
      expect(
        first.proxyChainDirective,
        'PROXY proxy-a:8080; PROXY proxy-b:8081; DIRECT',
      );

      NsfxProxyRuntime.markProxyFailure(first);

      final second = NsfxProxyRuntime.resolveProxyListString(
        'proxy-a:8080,proxy-b:8081,DIRECT',
        targetUri,
      );
      expect(second.host, 'proxy-b');
      expect(
        second.proxyChainDirective,
        'PROXY proxy-b:8081; DIRECT',
      );
    });
  });
}
