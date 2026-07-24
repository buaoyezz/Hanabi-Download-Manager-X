import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/platform/windows/window_effect_bridge.dart';

void main() {
  test('serializes a complete native backdrop request', () {
    const request = WindowsWindowEffectRequest(
      mode: WindowsWindowEffectMode.micaAlt,
      alpha: 999,
      roundedCornersEnabled: true,
      cornerRadius: 99,
      darkMode: true,
    );

    expect(request.toNativeArguments(), {
      'mode': 'mica_transient',
      'alpha': 255,
      'roundedCornersEnabled': true,
      'cornerRadius': 32,
      'darkMode': true,
      'force': false,
    });
  });

  test('parses native capabilities and apply diagnostics', () {
    final capabilities = WindowsWindowCapabilities.fromMap(const {
      'windowsBuild': 26200,
      'isWindows11': true,
      'supportsSystemBackdrop': true,
      'compositionEnabled': true,
      'transparencyEnabled': true,
      'highContrast': false,
    });
    final result = WindowsWindowEffectResult.fromMap(const {
      'requestedMode': 'mica_main',
      'appliedMode': 'mica_main',
      'usedFallback': false,
      'hresult': 0,
      'windowsBuild': 26200,
      'transparencyEnabled': true,
    });

    expect(capabilities.windowsBuild, 26200);
    expect(capabilities.supportsSystemBackdrop, isTrue);
    expect(result.appliedMode, WindowsWindowEffectMode.micaMain);
    expect(result.succeeded, isTrue);
    expect(result.usedFallback, isFalse);
  });
}
