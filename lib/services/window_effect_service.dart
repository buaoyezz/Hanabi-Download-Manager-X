import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/windows/window_effect_bridge.dart';
import 'client_config_service.dart';

@immutable
class WindowMaterialPresentation {
  const WindowMaterialPresentation({
    required this.mode,
    required this.usesNativeBackdrop,
    required this.windowColor,
    required this.commandingLayerColor,
    required this.contentLayerColor,
    required this.legacyBlurSigma,
  });

  final String mode;
  final bool usesNativeBackdrop;
  final Color windowColor;
  final Color commandingLayerColor;
  final Color contentLayerColor;
  final double legacyBlurSigma;
}

/// Coordinates Flutter's layer colors with the single native window backdrop.
///
/// Microsoft guidance used by this service:
/// - Mica is the base layer and is applied once per top-level window.
/// - Transparent title/navigation layers reveal that base.
/// - Content uses LayerFillColorDefault, not an opaque app background.
/// - DWM_SYSTEMBACKDROP_TYPE is documented from Windows 11 build 22621.
class WindowEffectService extends ChangeNotifier {
  WindowEffectService({
    WindowsWindowEffectBridge bridge = const WindowsWindowEffectBridge(),
  }) : _bridge = bridge;

  static const int windows11Build = 22000;
  static const int systemBackdropBuild = 22621;
  static const double cornerRadius = 8.0;

  static const String popupEffectCrashGuardPreferenceKey =
      'popup_window_effect_applying_native_effect';

  static const String modeNone = 'none';
  static const String modeBlur = 'blur';
  static const String modeAcrylic = 'acrylic';
  static const String modeMicaMain = 'mica_main';
  // Kept for stored-setting compatibility. This mode is Mica Alt.
  static const String modeMicaTransient = 'mica_transient';

  static const int fixedAcrylicNativeAlpha = 150;
  static const int fixedPopupAcrylicNativeAlpha = 110;
  static const int defaultBlurNativeAlpha = 140;

  final WindowsWindowEffectBridge _bridge;

  String _effectMode = modeAcrylic;
  int _blurAlpha = defaultBlurNativeAlpha;
  bool _effectEnabled = true;
  bool _dragSuspend = true;
  bool _roundedCornersEnabled = true;
  bool _darkMode = true;
  bool _isInitialized = false;
  bool _recoveredFromCrash = false;
  WindowsWindowCapabilities? _capabilities;
  WindowsWindowEffectResult? _lastApplyResult;
  int _applyGeneration = 0;

  String get effectMode => _effectMode;
  int get alpha => effectiveNativeAlpha;
  int get blurAlpha => _blurAlpha;
  bool get isInitialized => _isInitialized;
  bool get windowEffectsAvailable =>
      Platform.isWindows && (_capabilities?.compositionEnabled ?? false);
  bool get effectEnabled => _effectEnabled;
  bool get isWindows11 =>
      _capabilities?.isWindows11 ?? isWindows11Build(_windowsBuildNumber);
  int get windowsBuildNumber => _capabilities?.windowsBuild ?? 0;
  int get _windowsBuildNumber => _capabilities?.windowsBuild ?? 0;
  bool get supportsSystemBackdrop =>
      _capabilities?.supportsSystemBackdrop ?? false;
  bool get supportsMicaAlt => supportsSystemBackdrop;
  bool get supportsWin11Acrylic => supportsSystemBackdrop;
  bool get systemTransparencyEnabled =>
      _capabilities?.transparencyEnabled ?? false;
  bool get systemHighContrast => _capabilities?.highContrast ?? false;
  bool get recoveredFromCrash => _recoveredFromCrash;
  bool get dragSuspend => _dragSuspend;
  bool get roundedCornersEnabled => _roundedCornersEnabled;
  bool get darkMode => _darkMode;
  double get windowCornerRadius => cornerRadius;
  WindowsWindowEffectResult? get lastApplyResult => _lastApplyResult;

  // Native regions/corner preferences own window clipping on every Windows
  // version. Flutter must not add another full-window ClipRRect/saveLayer.
  bool get usesCustomWindowClip => false;

  bool get isTransparentBackground =>
      effectEnabled &&
      const {
        modeAcrylic,
        modeBlur,
        modeMicaMain,
        modeMicaTransient,
      }.contains(_effectMode);

  bool get isMicaEffect =>
      effectEnabled &&
      (_effectMode == modeMicaMain || _effectMode == modeMicaTransient);
  bool get isAcrylicEffect => effectEnabled && _effectMode == modeAcrylic;
  bool get isBlurEffect => effectEnabled && _effectMode == modeBlur;

  bool get nativeMaterialReady {
    if (!effectEnabled || systemHighContrast || !systemTransparencyEnabled) {
      return false;
    }
    final result = _lastApplyResult;
    return result != null &&
        result.succeeded &&
        result.transparencyEnabled &&
        result.appliedMode != WindowsWindowEffectMode.none;
  }

  bool get supportsUserAlpha =>
      effectEnabled && !isWindows11 && _effectMode == modeBlur;

  int get effectiveNativeAlpha => nativeAlphaForMode(
        effectEnabled ? _effectMode : modeNone,
        blurAlpha: _blurAlpha,
      );

  static int nativeAlphaForMode(
    String mode, {
    int blurAlpha = defaultBlurNativeAlpha,
    bool popup = false,
  }) {
    return switch (mode) {
      modeAcrylic =>
        popup ? fixedPopupAcrylicNativeAlpha : fixedAcrylicNativeAlpha,
      modeBlur => blurAlpha.clamp(32, 200),
      _ => 255,
    };
  }

  /// The DWM material itself owns the top bar and navigation backdrop.
  /// Painting another tint here hides Acrylic and makes Mica Alt look flat.
  Color shellBackdropColor({required Color solidFallback}) {
    if (!nativeMaterialReady || !isTransparentBackground) {
      return solidFallback;
    }
    return Colors.transparent;
  }

  /// Fluent LayerFillColorDefault, the Microsoft-recommended Mica content
  /// layer. These values match fluent_ui's dark and light ColorResources.
  Color contentBackdropColor({required Color solidFallback}) {
    if (!nativeMaterialReady || !isTransparentBackground) {
      return solidFallback;
    }
    if (_effectMode == modeMicaMain) {
      return _darkMode ? const Color(0x4C3A3A3A) : const Color(0x80FFFFFF);
    }
    if (_effectMode == modeMicaTransient) {
      return _darkMode ? const Color(0x383A3A3A) : const Color(0x70FFFFFF);
    }
    if (_effectMode == modeAcrylic) {
      return _darkMode ? const Color(0x30303030) : const Color(0x66FFFFFF);
    }
    return solidFallback.withValues(
      alpha: (_blurAlpha / 255.0).clamp(0.18, 0.48),
    );
  }

  double get shellFillOpacity => shellBackdropColor(
        solidFallback: _darkMode ? const Color(0xFF202020) : Colors.white,
      ).a;

  double get contentFillOpacity => contentBackdropColor(
        solidFallback: _darkMode ? const Color(0xFF202020) : Colors.white,
      ).a;

  double get shellBackdropSigma {
    if (isWindows11 || !effectEnabled) return 0;
    if (isBlurEffect) return 6;
    if (isAcrylicEffect) return 2;
    return 0;
  }

  WindowMaterialPresentation presentation({
    required Color solidShell,
    required Color solidContent,
  }) {
    final usesBackdrop = nativeMaterialReady && isTransparentBackground;
    return WindowMaterialPresentation(
      mode: usesBackdrop ? _effectMode : modeNone,
      usesNativeBackdrop: usesBackdrop,
      windowColor: usesBackdrop ? Colors.transparent : solidShell,
      commandingLayerColor: usesBackdrop ? Colors.transparent : solidShell,
      contentLayerColor: usesBackdrop
          ? contentBackdropColor(solidFallback: solidContent)
          : solidContent,
      legacyBlurSigma: usesBackdrop ? shellBackdropSigma : 0,
    );
  }

  static bool isWindows11Build(int build) => build >= windows11Build;

  static bool supportsSystemBackdropForBuild(int build) =>
      build >= systemBackdropBuild;

  static bool effectsAvailableForWindowsBuild(int build) => Platform.isWindows;

  static String normalizeModeForWindowsBuild(String? mode, int build) {
    final win11 = isWindows11Build(build);
    final supportsBackdrop = supportsSystemBackdropForBuild(build);
    final normalized = switch (mode?.trim().toLowerCase()) {
      modeNone => modeNone,
      modeBlur => modeBlur,
      modeAcrylic => modeAcrylic,
      modeMicaMain => modeMicaMain,
      modeMicaTransient => modeMicaTransient,
      _ => supportsBackdrop ? modeMicaMain : modeAcrylic,
    };

    if (!win11) {
      return switch (normalized) {
        modeMicaMain || modeMicaTransient => modeAcrylic,
        _ => normalized,
      };
    }

    // This app intentionally uses the documented Win32 DWM route. Builds
    // before 22621 therefore use Acrylic rather than undocumented Mica flags.
    if (!supportsBackdrop) {
      return normalized == modeNone ? modeNone : modeAcrylic;
    }
    if (normalized == modeBlur) return modeMicaMain;
    return normalized;
  }

  void clearCrashRecoveryFlag() {
    if (!_recoveredFromCrash) return;
    _recoveredFromCrash = false;
    notifyListeners();
  }

  Future<void> initialize({
    Brightness initialBrightness = Brightness.dark,
  }) async {
    if (_isInitialized) return;

    _darkMode = initialBrightness == Brightness.dark;
    if (Platform.isWindows) {
      try {
        _capabilities = await _bridge.getCapabilities();
      } catch (error) {
        debugPrint('Window capability detection failed: $error');
        _capabilities = const WindowsWindowCapabilities(
          windowsBuild: 0,
          isWindows11: false,
          supportsSystemBackdrop: false,
          compositionEnabled: false,
          transparencyEnabled: false,
          highContrast: false,
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await _recoverPopupEffectCrashIfNeeded(prefs);
    // Clear a stale guard from the previous dual-controller implementation.
    await prefs.setBool('window_effect_applying_acrylic', false);

    _effectMode = normalizeModeForWindowsBuild(
      prefs.getString('window_effect_mode') ??
          (supportsSystemBackdrop ? modeMicaMain : modeAcrylic),
      _windowsBuildNumber,
    );
    _blurAlpha = (prefs.getInt('window_effect_alpha') ?? defaultBlurNativeAlpha)
        .clamp(32, 200);
    _effectEnabled = prefs.containsKey('window_effect_enabled')
        ? (prefs.getBool('window_effect_enabled') ?? false)
        : supportsSystemBackdrop;
    _dragSuspend = prefs.getBool('window_effect_drag_suspend') ?? true;
    _roundedCornersEnabled = prefs.getBool('window_rounded_corners') ?? true;

    // Material application is deliberately deferred until window_manager has
    // finished its one-time size and title-bar setup.
    await _setNativeDragSuspend();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _recoverPopupEffectCrashIfNeeded(SharedPreferences prefs) async {
    if (!(prefs.getBool(popupEffectCrashGuardPreferenceKey) ?? false)) return;
    _recoveredFromCrash = true;
    await prefs.setBool(popupEffectCrashGuardPreferenceKey, false);
    try {
      await ClientConfigService().setPopupWindowEffectMode(
        ClientConfigService.popupWindowEffectFollowMain,
      );
    } catch (error) {
      debugPrint('Popup effect crash recovery failed: $error');
    }
  }

  Future<void> setEffectEnabled(bool enabled) async {
    if (_effectEnabled == enabled) return;
    _effectEnabled = enabled;
    await applyWindowEffect();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setEffectMode(String mode) async {
    final next = normalizeModeForWindowsBuild(mode, _windowsBuildNumber);
    if (_effectMode == next) return;
    _effectMode = next;
    await applyWindowEffect();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAlpha(int alpha) async {
    if (isWindows11 || _effectMode != modeBlur) return;
    final next = alpha.clamp(32, 200);
    if (_blurAlpha == next) return;
    _blurAlpha = next;
    await applyWindowEffect();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDragSuspend(bool value) async {
    if (_dragSuspend == value) return;
    _dragSuspend = value;
    await _setNativeDragSuspend();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setRoundedCornersEnabled(bool value) async {
    if (_roundedCornersEnabled == value) return;
    _roundedCornersEnabled = value;
    await applyWindowEffect();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setThemeBrightness(Brightness brightness) async {
    final next = brightness == Brightness.dark;
    if (_darkMode == next) return;
    _darkMode = next;
    if (_isInitialized) await applyWindowEffect();
    notifyListeners();
  }

  Future<WindowsWindowEffectResult?> applyWindowEffect({
    bool force = false,
  }) async {
    if (!Platform.isWindows || !_isInitialized && _capabilities == null) {
      return null;
    }

    final mode = normalizeModeForWindowsBuild(
      _effectMode,
      _windowsBuildNumber,
    );
    if (mode != _effectMode) _effectMode = mode;

    final generation = ++_applyGeneration;
    try {
      final result = await _bridge.applyEffect(
        WindowsWindowEffectRequest(
          mode: _effectEnabled
              ? WindowsWindowEffectMode.fromName(mode)
              : WindowsWindowEffectMode.none,
          alpha: effectiveNativeAlpha,
          roundedCornersEnabled: _roundedCornersEnabled,
          cornerRadius: windowCornerRadius.round(),
          darkMode: _darkMode,
          force: force,
        ),
      );
      if (generation == _applyGeneration) {
        _lastApplyResult = result;
        if (force) notifyListeners();
      }
      return result;
    } catch (error) {
      debugPrint('Window backdrop apply failed: $error');
      if (generation == _applyGeneration) {
        _lastApplyResult = null;
        if (force) notifyListeners();
      }
      return null;
    }
  }

  void handleNativeStateChanged(Map<Object?, Object?> payload) {
    if (!_isInitialized) return;

    final capabilities = WindowsWindowCapabilities.fromMap(payload);
    final result = WindowsWindowEffectResult.fromMap(payload);
    final normalizedMode = normalizeModeForWindowsBuild(
      _effectMode,
      capabilities.windowsBuild,
    );
    final expectedMode = _effectEnabled
        ? WindowsWindowEffectMode.fromName(normalizedMode)
        : WindowsWindowEffectMode.none;
    final capabilitiesChanged = !_sameCapabilities(
      _capabilities,
      capabilities,
    );

    if (result.requestedMode != expectedMode) {
      if (capabilitiesChanged) {
        _capabilities = capabilities;
        _lastApplyResult = null;
        notifyListeners();
      }
      return;
    }

    _capabilities = capabilities;
    _lastApplyResult = result;
    _applyGeneration++;
    notifyListeners();
  }

  static bool _sameCapabilities(
    WindowsWindowCapabilities? left,
    WindowsWindowCapabilities right,
  ) {
    return left != null &&
        left.windowsBuild == right.windowsBuild &&
        left.isWindows11 == right.isWindows11 &&
        left.supportsSystemBackdrop == right.supportsSystemBackdrop &&
        left.compositionEnabled == right.compositionEnabled &&
        left.transparencyEnabled == right.transparencyEnabled &&
        left.highContrast == right.highContrast;
  }

  Future<void> _setNativeDragSuspend() async {
    if (!Platform.isWindows) return;
    try {
      await _bridge.setDragSuspend(_dragSuspend);
    } catch (error) {
      debugPrint('Window drag-suspend update failed: $error');
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('window_effect_mode', _effectMode);
    await prefs.setInt('window_effect_alpha', _blurAlpha);
    await prefs.setBool('window_effect_enabled', _effectEnabled);
    await prefs.setBool('window_effect_drag_suspend', _dragSuspend);
    await prefs.setBool('window_rounded_corners', _roundedCornersEnabled);
  }
}
