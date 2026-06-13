import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../platform/windows/window_effect_bridge.dart';
import 'client_config_service.dart';

class WindowEffectService extends ChangeNotifier {
  WindowEffectService({
    WindowsWindowEffectBridge bridge = const WindowsWindowEffectBridge(),
  }) : _bridge = bridge;

  static const bool _disableNativeEffectsOnWindows11 = false;
  static const int _windows11Build = 22000;
  static const int _systemBackdropBuild = 22621;
  static const double _windows10CornerRadius = 8.0;
  static const double _windows11CornerRadius = 8.0;
  static const String popupEffectCrashGuardPreferenceKey =
      'popup_window_effect_applying_native_effect';

  static const String modeNone = 'none';
  static const String modeBlur = 'blur';
  static const String modeAcrylic = 'acrylic';
  static const String modeMicaMain = 'mica_main';
  static const String modeMicaTransient = 'mica_transient';

  final WindowsWindowEffectBridge _bridge;

  String _effectMode = modeAcrylic;
  int _alpha = 160;
  bool _effectEnabled = true;
  bool _dragSuspend = true;
  bool _roundedCornersEnabled = true;
  bool _darkMode = true;

  bool _isInitialized = false;
  bool _isWindows11 = false;
  int _windowsBuildNumber = 0;
  bool _recoveredFromCrash = false;

  String get effectMode => _effectMode;
  int get alpha => _alpha;
  bool get windowEffectsAvailable =>
      effectsAvailableForWindowsBuild(_windowsBuildNumber);
  bool get effectEnabled => _effectEnabled && windowEffectsAvailable;
  bool get isWindows11 => _isWindows11;
  int get windowsBuildNumber => _windowsBuildNumber;
  bool get supportsSystemBackdrop =>
      _isWindows11 && _windowsBuildNumber >= _systemBackdropBuild;
  bool get supportsMicaAlt => supportsSystemBackdrop;
  bool get supportsWin11Acrylic => _isWindows11;
  bool get recoveredFromCrash => _recoveredFromCrash;
  bool get dragSuspend => _dragSuspend;
  bool get roundedCornersEnabled => _roundedCornersEnabled;
  bool get darkMode => _darkMode;
  double get windowCornerRadius =>
      _isWindows11 ? _windows11CornerRadius : _windows10CornerRadius;
  bool get usesCustomWindowClip =>
      Platform.isWindows && (!_isWindows11 || (effectEnabled && _isLegacyBlur));

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

  bool get _isLegacyBlur => _effectMode == modeBlur;

  static bool effectsAvailableForWindowsBuild(int windowsBuildNumber) {
    final isWindows11 = windowsBuildNumber >= _windows11Build;
    return Platform.isWindows &&
        (!isWindows11 || !_disableNativeEffectsOnWindows11);
  }

  static bool isWindows11Build(int windowsBuildNumber) =>
      windowsBuildNumber >= _windows11Build;

  static bool supportsSystemBackdropForBuild(int windowsBuildNumber) =>
      windowsBuildNumber >= _systemBackdropBuild;

  static String normalizeModeForWindowsBuild(
    String? mode,
    int windowsBuildNumber,
  ) {
    final isWindows11 = isWindows11Build(windowsBuildNumber);
    final supportsSystemBackdrop =
        supportsSystemBackdropForBuild(windowsBuildNumber);
    final normalized = switch (mode?.trim().toLowerCase()) {
      modeNone => modeNone,
      modeBlur => modeBlur,
      modeAcrylic => modeAcrylic,
      modeMicaMain => modeMicaMain,
      modeMicaTransient => modeMicaTransient,
      _ => isWindows11 ? modeMicaMain : modeAcrylic,
    };

    if (!isWindows11) {
      return switch (normalized) {
        modeMicaMain || modeMicaTransient => modeAcrylic,
        _ => normalized,
      };
    }

    if (!supportsSystemBackdrop) {
      return switch (normalized) {
        modeNone => modeNone,
        modeBlur || modeMicaTransient => modeMicaMain,
        _ => normalized,
      };
    }

    if (normalized == modeBlur) {
      return modeMicaMain;
    }

    return normalized;
  }

  void clearCrashRecoveryFlag() {
    if (_recoveredFromCrash) {
      _recoveredFromCrash = false;
      notifyListeners();
    }
  }

  Future<void> initialize({
    Brightness initialBrightness = Brightness.dark,
  }) async {
    if (_isInitialized) return;

    _darkMode = initialBrightness == Brightness.dark;
    await _detectWindowsVersion();

    final prefs = await SharedPreferences.getInstance();
    await _recoverPopupEffectCrashIfNeeded(prefs);
    await _recoverMainEffectCrashIfNeeded(prefs);

    _effectMode = _normalizeModeForPlatform(
      prefs.getString('window_effect_mode') ??
          (_isWindows11 ? modeMicaMain : modeAcrylic),
    );
    _alpha = (prefs.getInt('window_effect_alpha') ?? 160).clamp(0, 255).toInt();

    if (prefs.containsKey('window_effect_enabled')) {
      _effectEnabled = prefs.getBool('window_effect_enabled')!;
    } else {
      _effectEnabled = _isWindows11;
    }
    if (!windowEffectsAvailable) {
      _effectEnabled = false;
    }

    _dragSuspend = prefs.getBool('window_effect_drag_suspend') ?? true;
    _roundedCornersEnabled = prefs.getBool('window_rounded_corners') ?? true;

    await applyWindowEffect();
    await _setNativeDragSuspend();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _recoverPopupEffectCrashIfNeeded(
    SharedPreferences prefs,
  ) async {
    final wasApplyingPopupNativeEffect =
        prefs.getBool(popupEffectCrashGuardPreferenceKey) ?? false;
    if (!wasApplyingPopupNativeEffect) return;

    _recoveredFromCrash = true;
    await prefs.setBool(popupEffectCrashGuardPreferenceKey, false);
    try {
      await ClientConfigService().setPopupWindowEffectMode(
        ClientConfigService.popupWindowEffectFollowMain,
      );
    } catch (e) {
      debugPrint('popup window effect crash recovery error: $e');
    }
  }

  Future<void> _recoverMainEffectCrashIfNeeded(
    SharedPreferences prefs,
  ) async {
    final wasApplyingAcrylic =
        prefs.getBool('window_effect_applying_acrylic') ?? false;
    if (!wasApplyingAcrylic) return;

    _recoveredFromCrash = true;
    await prefs.setBool('window_effect_applying_acrylic', false);
    await prefs.setString('window_effect_mode', modeMicaMain);
  }

  Future<void> _detectWindowsVersion() async {
    if (!Platform.isWindows) {
      _isWindows11 = false;
      _windowsBuildNumber = 0;
      return;
    }

    try {
      final result = await Process.run('cmd', ['/c', 'ver']);
      final match = RegExp(r'10\.0\.(\d+)').firstMatch(
        result.stdout.toString(),
      );
      final buildNumber = int.tryParse(match?.group(1) ?? '') ?? 0;
      _windowsBuildNumber = buildNumber;
      _isWindows11 = buildNumber >= _windows11Build;
      debugPrint('Windows build: $buildNumber, isWindows11: $_isWindows11');
    } catch (e) {
      debugPrint('Failed to detect Windows version: $e');
      _isWindows11 = false;
      _windowsBuildNumber = 0;
    }
  }

  String _normalizeModeForPlatform(String mode) =>
      normalizeModeForWindowsBuild(mode, _windowsBuildNumber);

  Future<void> setEffectEnabled(bool enabled) async {
    final nextEnabled = windowEffectsAvailable ? enabled : false;
    if (_effectEnabled == nextEnabled) return;

    _effectEnabled = nextEnabled;
    await applyWindowEffect();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setEffectMode(String mode) async {
    final nextMode = _normalizeModeForPlatform(mode);
    if (_effectMode == nextMode) return;

    _effectMode = nextMode;
    await applyWindowEffect();
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAlpha(int alpha) async {
    final nextAlpha = alpha.clamp(0, 255).toInt();
    if (_alpha == nextAlpha) return;

    _alpha = nextAlpha;
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
    final nextDarkMode = brightness == Brightness.dark;
    if (_darkMode == nextDarkMode) return;

    _darkMode = nextDarkMode;
    if (_isInitialized) {
      await applyWindowEffect();
      notifyListeners();
    }
  }

  Future<void> applyWindowEffect() async {
    if (!Platform.isWindows) return;

    final prefs = await SharedPreferences.getInstance();
    final mode = _normalizeModeForPlatform(_effectMode);
    if (mode != _effectMode) {
      _effectMode = mode;
    }

    final isApplyingAcrylicOnWin11 =
        _isWindows11 && effectEnabled && mode == modeAcrylic;

    if (isApplyingAcrylicOnWin11) {
      await prefs.setBool('window_effect_applying_acrylic', true);
    }

    try {
      await _bridge.applyEffect(
        WindowsWindowEffectRequest(
          mode: effectEnabled
              ? WindowsWindowEffectMode.fromName(mode)
              : WindowsWindowEffectMode.none,
          alpha: effectEnabled ? _alpha : 255,
          roundedCornersEnabled: _roundedCornersEnabled,
          cornerRadius: windowCornerRadius.round(),
          darkMode: _darkMode,
        ),
      );
    } catch (e) {
      debugPrint('setWindowEffect error: $e');
    } finally {
      if (isApplyingAcrylicOnWin11) {
        await prefs.setBool('window_effect_applying_acrylic', false);
      }
    }
  }

  Future<void> _setNativeDragSuspend() async {
    if (!Platform.isWindows) return;
    try {
      await _bridge.setDragSuspend(_dragSuspend);
    } catch (e) {
      debugPrint('setDragSuspend error: $e');
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('window_effect_mode', _effectMode);
    await prefs.setInt('window_effect_alpha', _alpha);
    await prefs.setBool('window_effect_enabled', _effectEnabled);
    await prefs.setBool('window_effect_drag_suspend', _dragSuspend);
    await prefs.setBool('window_rounded_corners', _roundedCornersEnabled);
  }
}
