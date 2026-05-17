import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'client_config_service.dart';
import '../platform/windows/window_effect_bridge.dart';

class WindowEffectService extends ChangeNotifier {
  // Keep this switch available as a hard fallback, but Win11 effects should be
  // user-controllable. The native runner now uses a safer Win11 DWM path.
  static const bool _disableNativeEffectsOnWindows11 = false;

  // Win10's manual region clipping looks visibly rounder than Win11's native
  // DWM corner preference, so keep it slightly tighter to match the same feel.
  static const double _windows10CornerRadius = 6.0;
  static const double _windows11CornerRadius = 8.0;
  static const String popupEffectCrashGuardPreferenceKey =
      'popup_window_effect_applying_native_effect';

  String _effectMode = 'acrylic';
  int _alpha = 160;
  bool _effectEnabled = true;
  bool _dragSuspend = true; // Win10: disable effect during drag
  bool _roundedCornersEnabled = true;
  bool _darkMode = true;
  final WindowsWindowEffectBridge _windowBridge =
      const WindowsWindowEffectBridge();
  bool _isInitialized = false;
  bool _isWindows11 = false;
  bool _recoveredFromCrash = false;

  String get effectMode => _effectMode;
  int get alpha => _alpha;
  bool get windowEffectsAvailable =>
      !_isWindows11 || !_disableNativeEffectsOnWindows11;
  bool get effectEnabled => _effectEnabled && windowEffectsAvailable;
  bool get isWindows11 => _isWindows11;
  bool get recoveredFromCrash => _recoveredFromCrash;
  bool get dragSuspend => _dragSuspend;
  bool get roundedCornersEnabled => _roundedCornersEnabled;
  bool get darkMode => _darkMode;
  double get windowCornerRadius =>
      _isWindows11 ? _windows11CornerRadius : _windows10CornerRadius;
  bool get usesCustomWindowClip =>
      !_isWindows11 ||
      (effectEnabled && (_effectMode == 'acrylic' || _effectMode == 'blur'));

  bool get isTransparentBackground =>
      effectEnabled &&
      (_effectMode == 'acrylic' ||
          _effectMode == 'blur' ||
          _effectMode == 'mica_main' ||
          _effectMode == 'mica_transient');

  bool get isMicaEffect =>
      effectEnabled &&
      (_effectMode == 'mica_main' || _effectMode == 'mica_transient');

  void clearCrashRecoveryFlag() {
    if (_recoveredFromCrash) {
      _recoveredFromCrash = false;
      notifyListeners();
    }
  }

  Future<void> initialize(
      {Brightness initialBrightness = Brightness.dark}) async {
    if (_isInitialized) return;
    _darkMode = initialBrightness == Brightness.dark;
    await _detectWindowsVersion();

    final prefs = await SharedPreferences.getInstance();

    final wasApplyingPopupNativeEffect =
        prefs.getBool(popupEffectCrashGuardPreferenceKey) ?? false;
    if (wasApplyingPopupNativeEffect) {
      _recoveredFromCrash = true;
      await prefs.setBool(popupEffectCrashGuardPreferenceKey, false);
      try {
        await ClientConfigService().setPopupWindowEffectMode(
          ClientConfigService.popupWindowEffectSolid,
        );
      } catch (e) {
        debugPrint('popup window effect crash recovery error: $e');
      }
    }

    // Check if we crashed while applying acrylic previously
    if (_isWindows11) {
      final wasApplyingAcrylic =
          prefs.getBool('window_effect_applying_acrylic') ?? false;
      if (wasApplyingAcrylic) {
        _recoveredFromCrash = true;
        await prefs.setBool('window_effect_applying_acrylic', false);
        await prefs.setString('window_effect_mode', 'mica_main');
      }
    }

    _effectMode = prefs.getString('window_effect_mode') ??
        (_isWindows11 ? 'mica_main' : 'acrylic');
    _alpha = prefs.getInt('window_effect_alpha') ?? 160;

    // 新用户：Win11 默认启用 Mica，Win10 默认关闭窗口特效。
    // Win11 的 Mica 走 DWM 原生路径，比 Acrylic/Blur 更稳定。
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

    if (!_isWindows11 &&
        (_effectMode == 'mica_main' || _effectMode == 'mica_transient')) {
      _effectMode = 'acrylic';
      await _saveSettings();
    } else if (_isWindows11 && _effectMode == 'acrylic') {
      // 避免 Win11 开启 acrylic 导致硬崩溃，强转为 mica_main
      _effectMode = 'mica_main';
      await _saveSettings();
    }

    await _applyWindowEffect();
    try {
      await _windowBridge.setDragSuspend(_dragSuspend);
    } catch (e) {
      debugPrint('setDragSuspend init error: $e');
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _detectWindowsVersion() async {
    if (!Platform.isWindows) {
      _isWindows11 = false;
      return;
    }
    try {
      final result = await Process.run('cmd', ['/c', 'ver']);
      final output = result.stdout.toString();
      final match = RegExp(r'10\.0\.(\d+)').firstMatch(output);
      if (match != null) {
        final buildNumber = int.tryParse(match.group(1) ?? '0') ?? 0;
        _isWindows11 = buildNumber >= 22000;
        debugPrint('Windows build: $buildNumber, isWindows11: $_isWindows11');
      }
    } catch (e) {
      debugPrint('Failed to detect Windows version: $e');
      _isWindows11 = false;
    }
  }

  Future<void> setEffectEnabled(bool enabled) async {
    final nextEnabled = windowEffectsAvailable ? enabled : false;
    if (_effectEnabled != nextEnabled) {
      _effectEnabled = nextEnabled;
      await _applyWindowEffect();
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setEffectMode(String mode) async {
    String effectiveMode = mode;
    if (_isWindows11 && (mode == 'acrylic' || mode == 'blur')) {
      // Prevent crash if user manually selects acrylic/blur in settings on Win11
      effectiveMode = 'mica_main';
    }

    if (_effectMode != effectiveMode) {
      _effectMode = effectiveMode;
      await _applyWindowEffect();
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setAlpha(int alpha) async {
    if (_alpha != alpha) {
      _alpha = alpha;
      await _applyWindowEffect();
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setDragSuspend(bool value) async {
    if (_dragSuspend != value) {
      _dragSuspend = value;
      try {
        await _windowBridge.setDragSuspend(value);
      } catch (e) {
        debugPrint('setDragSuspend error: $e');
      }
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setRoundedCornersEnabled(bool value) async {
    if (_roundedCornersEnabled != value) {
      _roundedCornersEnabled = value;
      await _applyWindowEffect();
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setThemeBrightness(Brightness brightness) async {
    final nextDarkMode = brightness == Brightness.dark;
    if (_darkMode == nextDarkMode) {
      return;
    }
    _darkMode = nextDarkMode;
    if (_isInitialized) {
      await _applyWindowEffect();
      notifyListeners();
    }
  }

  Future<void> _applyWindowEffect() async {
    final prefs = await SharedPreferences.getInstance();
    final isTryingAcrylicOnWin11 = _isWindows11 &&
        effectEnabled &&
        (_effectMode == 'acrylic' || _effectMode == 'blur');

    if (isTryingAcrylicOnWin11) {
      // 写入标记，如果在此之后发生硬崩溃，下次启动 initialize 时能检测到
      await prefs.setBool('window_effect_applying_acrylic', true);
    }

    try {
      final effectiveMode = effectEnabled
          ? WindowsWindowEffectMode.fromName(_effectMode)
          : WindowsWindowEffectMode.none;
      await _windowBridge.applyEffect(
        WindowsWindowEffectRequest(
          mode: effectiveMode,
          alpha: effectEnabled ? _alpha : 255,
          roundedCornersEnabled: _roundedCornersEnabled,
          cornerRadius: windowCornerRadius.round(),
          darkMode: _darkMode,
        ),
      );
    } catch (e) {
      debugPrint('setWindowEffect error: $e');
    } finally {
      if (isTryingAcrylicOnWin11) {
        // 成功应用，清除标记
        await prefs.setBool('window_effect_applying_acrylic', false);
      }
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
