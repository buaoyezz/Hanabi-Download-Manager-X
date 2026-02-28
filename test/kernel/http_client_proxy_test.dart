import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/kernel/next/config/download_config.dart';
import 'package:hanabi_download_managerx/services/kernel/next/downloader/http_client.dart';

void main() {
  group('NsfxHttpClient proxy settings', () {
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
      final proxy = client.getActiveProxySettings();

      expect(proxy, isNotNull);
      expect(proxy!.proxyDirective, 'SOCKS5 10.0.0.2:1080');
      expect(proxy.supportsHttpBasicAuth, isFalse);
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
      final proxy = client.getActiveProxySettings();

      expect(proxy, isNotNull);
      expect(proxy!.supportsHttpBasicAuth, isTrue);
    });

    test('disables proxy after proxy error until client closes', () {
      final config = NsfxConfig(
        proxy: NsfxProxyConfig(enabled: true, type: 'http', host: '127.0.0.1', port: 7897),
      );

      final client = NsfxHttpClient(config);
      expect(client.getActiveProxySettings(), isNotNull);

      client.switchToDirectOnProxyError();
      expect(client.getActiveProxySettings(), isNull);

      client.close();
      expect(client.getActiveProxySettings(), isNotNull);
    });
  });
}
