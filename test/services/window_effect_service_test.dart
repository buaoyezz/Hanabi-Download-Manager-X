import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Color;
import 'package:hanabi_download_manager_x/platform/windows/window_effect_bridge.dart';
import 'package:hanabi_download_manager_x/services/window_effect_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    test('maps blur to documented materials on Windows 11', () {
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeBlur,
          22000,
        ),
        WindowEffectService.modeAcrylic,
      );
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeBlur,
          22621,
        ),
        WindowEffectService.modeMicaMain,
      );
    });

    test('falls back Mica family on pre-system-backdrop Windows 11', () {
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeMicaMain,
          22000,
        ),
        WindowEffectService.modeAcrylic,
      );
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeMicaTransient,
          22000,
        ),
        WindowEffectService.modeAcrylic,
      );
    });

    test('uses the Microsoft-documented build 22621 threshold', () {
      expect(
        WindowEffectService.supportsSystemBackdropForBuild(22620),
        isFalse,
      );
      expect(
        WindowEffectService.supportsSystemBackdropForBuild(22621),
        isTrue,
      );
    });

    test('keeps Mica Alt on system backdrop builds', () {
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeMicaTransient,
          22621,
        ),
        WindowEffectService.modeMicaTransient,
      );
    });

    test('keeps acrylic on Windows 11 when requested', () {
      expect(
        WindowEffectService.normalizeModeForWindowsBuild(
          WindowEffectService.modeAcrylic,
          22621,
        ),
        WindowEffectService.modeAcrylic,
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

  test('Windows 11 materials keep shell geometry stable and use Fluent layers',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'window_effect_enabled': true,
      'window_effect_mode': WindowEffectService.modeMicaMain,
    });
    final bridge = _FakeWindowEffectBridge();
    final service = WindowEffectService(bridge: bridge);
    await service.initialize();
    await service.applyWindowEffect(force: true);

    final expectedContentAlpha = <String, int>{
      WindowEffectService.modeMicaMain: 0x4C,
      WindowEffectService.modeMicaTransient: 0x38,
      WindowEffectService.modeAcrylic: 0x30,
    };
    for (final entry in expectedContentAlpha.entries) {
      final mode = entry.key;
      await service.setEffectMode(mode);
      final presentation = service.presentation(
        solidShell: const Color(0xFF202020),
        solidContent: const Color(0xFF202020),
      );
      expect(presentation.usesNativeBackdrop, isTrue, reason: mode);
      expect(presentation.windowColor.a, 0, reason: mode);
      expect(presentation.commandingLayerColor.a, 0, reason: mode);
      expect(
        presentation.contentLayerColor.a,
        closeTo(entry.value / 255, 0.001),
        reason: mode,
      );
    }
  });

  test('stays solid until the native backdrop has been confirmed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'window_effect_enabled': true,
      'window_effect_mode': WindowEffectService.modeMicaMain,
    });
    final service = WindowEffectService(bridge: _FakeWindowEffectBridge());
    await service.initialize();

    final presentation = service.presentation(
      solidShell: const Color(0xFF202020),
      solidContent: const Color(0xFF202020),
    );

    expect(presentation.usesNativeBackdrop, isFalse);
    expect(presentation.windowColor, const Color(0xFF202020));
  });

  test('clears stale native success when a later apply throws', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'window_effect_enabled': true,
      'window_effect_mode': WindowEffectService.modeMicaMain,
    });
    final bridge = _FakeWindowEffectBridge();
    final service = WindowEffectService(bridge: bridge);
    await service.initialize();
    await service.applyWindowEffect(force: true);
    expect(service.nativeMaterialReady, isTrue);

    bridge.throwApply = true;
    await service.applyWindowEffect(force: true);

    expect(service.nativeMaterialReady, isFalse);
  });

  test(
      'force refresh reaches the native bridge and failed native state is solid',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'window_effect_enabled': true,
      'window_effect_mode': WindowEffectService.modeMicaMain,
    });
    final bridge = _FakeWindowEffectBridge(failApply: true);
    final service = WindowEffectService(bridge: bridge);
    await service.initialize();

    await service.applyWindowEffect(force: true);

    expect(bridge.requests.single.force, isTrue);
    final presentation = service.presentation(
      solidShell: const Color(0xFF202020),
      solidContent: const Color(0xFF202020),
    );
    expect(presentation.usesNativeBackdrop, isFalse);
    expect(presentation.windowColor, const Color(0xFF202020));
    expect(presentation.contentLayerColor, const Color(0xFF202020));
  });

  test('system transparency changes update Flutter material state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'window_effect_enabled': true,
      'window_effect_mode': WindowEffectService.modeMicaMain,
    });
    final service = WindowEffectService(bridge: _FakeWindowEffectBridge());
    await service.initialize();
    await service.applyWindowEffect(force: true);
    expect(service.nativeMaterialReady, isTrue);

    service.handleNativeStateChanged(
      _nativeWindowState(
        appliedMode: WindowsWindowEffectMode.none,
        transparencyEnabled: false,
        usedFallback: true,
      ),
    );

    expect(service.effectEnabled, isTrue);
    expect(service.systemTransparencyEnabled, isFalse);
    expect(service.nativeMaterialReady, isFalse);
    expect(
      service
          .presentation(
            solidShell: const Color(0xFF202020),
            solidContent: const Color(0xFF202020),
          )
          .usesNativeBackdrop,
      isFalse,
    );

    service.handleNativeStateChanged(_nativeWindowState());

    expect(service.systemTransparencyEnabled, isTrue);
    expect(service.nativeMaterialReady, isTrue);
  });

  test('keeps the selected material while system transparency is unavailable',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'window_effect_enabled': true,
      'window_effect_mode': WindowEffectService.modeMicaMain,
    });
    final bridge = _FakeWindowEffectBridge(
      capabilities: const WindowsWindowCapabilities(
        windowsBuild: 26200,
        isWindows11: true,
        supportsSystemBackdrop: true,
        compositionEnabled: true,
        transparencyEnabled: false,
        highContrast: false,
      ),
    );
    final service = WindowEffectService(bridge: bridge);
    await service.initialize();

    await service.applyWindowEffect(force: true);

    expect(service.effectEnabled, isTrue);
    expect(bridge.requests.single.mode, WindowsWindowEffectMode.micaMain);
    expect(service.nativeMaterialReady, isFalse);
  });
}

Map<Object?, Object?> _nativeWindowState({
  WindowsWindowEffectMode requestedMode = WindowsWindowEffectMode.micaMain,
  WindowsWindowEffectMode appliedMode = WindowsWindowEffectMode.micaMain,
  bool usedFallback = false,
  int hresult = 0,
  bool compositionEnabled = true,
  bool transparencyEnabled = true,
  bool highContrast = false,
}) {
  return <Object?, Object?>{
    'requestedMode': requestedMode.nativeName,
    'appliedMode': appliedMode.nativeName,
    'usedFallback': usedFallback,
    'hresult': hresult,
    'windowsBuild': 26200,
    'isWindows11': true,
    'supportsSystemBackdrop': true,
    'compositionEnabled': compositionEnabled,
    'transparencyEnabled': transparencyEnabled,
    'highContrast': highContrast,
  };
}

class _FakeWindowEffectBridge extends WindowsWindowEffectBridge {
  _FakeWindowEffectBridge({
    this.failApply = false,
    this.capabilities = const WindowsWindowCapabilities(
      windowsBuild: 26200,
      isWindows11: true,
      supportsSystemBackdrop: true,
      compositionEnabled: true,
      transparencyEnabled: true,
      highContrast: false,
    ),
  });

  bool failApply;
  bool throwApply = false;
  WindowsWindowCapabilities capabilities;
  final List<WindowsWindowEffectRequest> requests = [];

  @override
  Future<WindowsWindowCapabilities> getCapabilities() async => capabilities;

  @override
  Future<WindowsWindowEffectResult> applyEffect(
    WindowsWindowEffectRequest request,
  ) async {
    requests.add(request);
    if (throwApply) {
      throw StateError('native bridge unavailable');
    }
    final materialAvailable = capabilities.compositionEnabled &&
        capabilities.transparencyEnabled &&
        !capabilities.highContrast;
    final appliedMode = failApply || !materialAvailable
        ? WindowsWindowEffectMode.none
        : request.mode;
    return WindowsWindowEffectResult(
      requestedMode: request.mode,
      appliedMode: appliedMode,
      usedFallback: failApply ||
          (!materialAvailable && request.mode != WindowsWindowEffectMode.none),
      hresult: failApply ? -1 : 0,
      windowsBuild: 26200,
      transparencyEnabled: capabilities.transparencyEnabled,
    );
  }

  @override
  Future<void> setDragSuspend(bool enabled) async {}
}
