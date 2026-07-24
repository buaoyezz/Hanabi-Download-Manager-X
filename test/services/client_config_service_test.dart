import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/client_config_service.dart';

void main() {
  group('ClientConfigService.normalizePopupWindowEffectMode', () {
    test('keeps the reduced popup effect modes', () {
      expect(
        ClientConfigService.normalizePopupWindowEffectMode(
          ClientConfigService.popupWindowEffectFollowMain,
        ),
        ClientConfigService.popupWindowEffectFollowMain,
      );
      expect(
        ClientConfigService.normalizePopupWindowEffectMode(
          ClientConfigService.popupWindowEffectAcrylic,
        ),
        ClientConfigService.popupWindowEffectAcrylic,
      );
      expect(
        ClientConfigService.normalizePopupWindowEffectMode(
          ClientConfigService.popupWindowEffectMicaMain,
        ),
        ClientConfigService.popupWindowEffectMicaMain,
      );
    });

    test('folds legacy popup modes into the supported surface', () {
      expect(
        ClientConfigService.normalizePopupWindowEffectMode(
          ClientConfigService.popupWindowEffectBlur,
        ),
        ClientConfigService.popupWindowEffectAcrylic,
      );
      expect(
        ClientConfigService.normalizePopupWindowEffectMode(
          ClientConfigService.popupWindowEffectMicaTransient,
        ),
        ClientConfigService.popupWindowEffectMicaMain,
      );
      expect(
        ClientConfigService.normalizePopupWindowEffectMode(
          ClientConfigService.popupWindowEffectSolid,
        ),
        ClientConfigService.popupWindowEffectFollowMain,
      );
    });
  });

  group('ClientConfigService.normalizeDownloadKernelId', () {
    test('keeps all supported kernel routing modes', () {
      expect(
        ClientConfigService.normalizeDownloadKernelId(
          ClientConfigService.downloadKernelAuto,
        ),
        ClientConfigService.downloadKernelAuto,
      );
      expect(
        ClientConfigService.normalizeDownloadKernelId(
          ClientConfigService.downloadKernelNeoNsf,
        ),
        ClientConfigService.downloadKernelNeoNsf,
      );
      expect(
        ClientConfigService.normalizeDownloadKernelId('unknown'),
        ClientConfigService.downloadKernelNsfx,
      );
      expect(
        ClientConfigService.normalizeDownloadKernelId(null),
        ClientConfigService.downloadKernelNsfx,
      );
    });
  });
}
