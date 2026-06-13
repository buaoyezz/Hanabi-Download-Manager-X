import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/services/window_effect_service.dart';

void main() {
  group('WindowEffectService.normalizeModeForWindowsBuild', () {
    test('falls back Mica effects to Acrylic on Windows 10', () {
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeMicaMain,
          19045,
        ),
        WindowEffectService.modeAcrylic,
      );
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeMicaTransient,
          19045,
        ),
        WindowEffectService.modeAcrylic,
      );
    });

    test('falls back unsupported Windows 11 modes on older builds', () {
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeBlur,
          22000,
        ),
        WindowEffectService.modeMicaMain,
      );
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeMicaTransient,
          22000,
        ),
        WindowEffectService.modeMicaMain,
      );
    });

    test('keeps supported Mica Alt on system backdrop builds', () {
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeMicaTransient,
          22621,
        ),
        WindowEffectService.modeMicaTransient,
      );
    });

    test('uses platform defaults for unknown modes', () {
      expect(
        WindowEffectService.normalizeModeForWindowsBuild('unknown', 19045),
        WindowEffectService.modeAcrylic,
      );
      expect(
        WindowEffectService.normalizeModeForWindowsBuild('unknown', 22621),
        WindowEffectService.modeMicaMain,
      );
    });
  });
}
