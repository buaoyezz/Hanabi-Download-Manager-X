import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/popup/popup_window_bootstrap.dart';

void main() {
  test('uses a solid popup until native material is ready', () {
    final effect = PopupWindowEffectConfig.fromJson(<String, Object>{
      'enabled': true,
      'mode': 'mica_main',
      'alpha': 255,
      'is_windows11': true,
      'native_material_ready': false,
    });

    expect(effect.enabled, isTrue);
    expect(effect.nativeMaterialReady, isFalse);
    expect(effect.isTransparentBackground, isFalse);
    expect(effect.panelBackgroundAlpha, 1);
  });

  test('tracks native fallback and recovery without losing user intent', () {
    const effect = PopupWindowEffectConfig(
      enabled: true,
      mode: 'mica_main',
      alpha: 255,
      isWindows11: true,
    );

    final fallback = effect.withNativeState(
      _nativeState(
        appliedMode: 'none',
        transparencyEnabled: false,
      ),
    );
    expect(fallback.enabled, isTrue);
    expect(fallback.nativeMaterialReady, isFalse);
    expect(fallback.isTransparentBackground, isFalse);

    final recovered = fallback.withNativeState(_nativeState());
    expect(recovered.enabled, isTrue);
    expect(recovered.nativeMaterialReady, isTrue);
    expect(recovered.isTransparentBackground, isTrue);
  });

  test('ignores a stale callback for a previous popup mode', () {
    const effect = PopupWindowEffectConfig(
      enabled: true,
      mode: 'mica_transient',
      alpha: 255,
      isWindows11: true,
      nativeMaterialReady: false,
    );

    final stale = effect.withNativeState(
      _nativeState(requestedMode: 'mica_main'),
    );

    expect(identical(stale, effect), isTrue);
  });
}

Map<Object?, Object?> _nativeState({
  String requestedMode = 'mica_main',
  String appliedMode = 'mica_main',
  bool transparencyEnabled = true,
}) {
  return <Object?, Object?>{
    'requestedMode': requestedMode,
    'appliedMode': appliedMode,
    'hresult': 0,
    'isWindows11': true,
    'compositionEnabled': true,
    'transparencyEnabled': transparencyEnabled,
    'highContrast': false,
  };
}
