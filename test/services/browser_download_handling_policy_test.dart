import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_managerx/services/client_config_service.dart';

void main() {
  group('Browser download handling policy', () {
    test('normalizes unknown modes to smart', () {
      expect(
        ClientConfigService.normalizeBrowserDownloadHandlingMode('wat'),
        ClientConfigService.browserDownloadModeSmart,
      );
      expect(
        ClientConfigService.normalizeBrowserDownloadHandlingMode(
          ClientConfigService.browserDownloadModeAlwaysAsk,
        ),
        ClientConfigService.browserDownloadModeAlwaysAsk,
      );
    });

    test('smart mode silently accepts known small safe downloads', () {
      final result = ClientConfigService.shouldSilentlyAcceptBrowserDownload(
        mode: ClientConfigService.browserDownloadModeSmart,
        fileSizeBytes: 2 * 1024 * 1024,
        smallFileThresholdBytes: 8 * 1024 * 1024,
      );

      expect(result, isTrue);
    });

    test('smart mode asks for unknown or large downloads', () {
      expect(
        ClientConfigService.shouldSilentlyAcceptBrowserDownload(
          mode: ClientConfigService.browserDownloadModeSmart,
          fileSizeBytes: null,
        ),
        isFalse,
      );
      expect(
        ClientConfigService.shouldSilentlyAcceptBrowserDownload(
          mode: ClientConfigService.browserDownloadModeSmart,
          fileSizeBytes: 32 * 1024 * 1024,
          smallFileThresholdBytes: 8 * 1024 * 1024,
        ),
        isFalse,
      );
    });

    test('silent mode accepts safe downloads but not unsafe browser danger', () {
      expect(
        ClientConfigService.shouldSilentlyAcceptBrowserDownload(
          mode: ClientConfigService.browserDownloadModeSilentTakeover,
          fileSizeBytes: null,
        ),
        isTrue,
      );
      expect(
        ClientConfigService.shouldSilentlyAcceptBrowserDownload(
          mode: ClientConfigService.browserDownloadModeSilentTakeover,
          fileSizeBytes: 1024,
          hasUnsafeBrowserDanger: true,
        ),
        isFalse,
      );
    });

    test('ask modes do not silently accept downloads', () {
      for (final mode in [
        ClientConfigService.browserDownloadModeAlwaysAsk,
        ClientConfigService.browserDownloadModeSmallFilesToBrowser,
      ]) {
        expect(
          ClientConfigService.shouldSilentlyAcceptBrowserDownload(
            mode: mode,
            fileSizeBytes: 1024,
          ),
          isFalse,
        );
      }
    });
  });
}
