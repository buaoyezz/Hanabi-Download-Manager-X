import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WindowEffectService extends ChangeNotifier {
  // Win10's manual region clipping looks visibly rounder than Win11's native
  // DWM corner preference, so keep it slightly tighter to match the same feel.
  static const double _windows10CornerRadius = 6.0;
  static const double _windows11CornerRadius = 8.0;

  String _effectMode = 'acrylic';
  int _alpha = 160;
  bool _effectEnabled = true;
  bool _dragSuspend = true; // Win10: disable effect during drag
  bool _roundedCornersEnabled = true;
  final MethodChannel _windowChannel =
      const MethodChannel('com.hanabi.download/window');
  bool _isInitialized = false;
  bool _isWindows11 = false;

  String get effectMode => _effectMode;
  int get alpha => _alpha;
  bool get effectEnabled => _effectEnabled;
  bool get isWindows11 => _isWindows11;
  bool get dragSuspend => _dragSuspend;
  bool get roundedCornersEnabled => _roundedCornersEnabled;
  double get windowCornerRadius =>
      _isWindows11 ? _windows11CornerRadius : _windows10CornerRadius;
  bool get usesCustomWindowClip =>
      !_isWindows11 ||
      (_effectEnabled && (_effectMode == 'acrylic' || _effectMode == 'blur'));

  bool get isTransparentBackground =>
      _effectEnabled &&
      (_effectMode == 'acrylic' ||
          _effectMode == 'blur' ||
          _effectMode == 'mica_main' ||
          _effectMode == 'mica_transient');

  bool get isMicaEffect =>
      _effectMode == 'mica_main' || _effectMode == 'mica_transient';

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _detectWindowsVersion();

    final prefs = await SharedPreferences.getInstance();
    _effectMode = prefs.getString('window_effect_mode') ?? 'acrylic';
    _alpha = prefs.getInt('window_effect_alpha') ?? 160;

    // 如果没有保存过设置（新用户），Win11 默认开启，Win10 默认关闭（性能考虑）
    if (prefs.containsKey('window_effect_enabled')) {
      _effectEnabled = prefs.getBool('window_effect_enabled')!;
    } else {
      _effectEnabled = _isWindows11;
    }

    _dragSuspend = prefs.getBool('window_effect_drag_suspend') ?? true;
    _roundedCornersEnabled = prefs.getBool('window_rounded_corners') ?? true;

    if (!_isWindows11 &&
        (_effectMode == 'mica_main' || _effectMode == 'mica_transient')) {
      _effectMode = 'acrylic';
      await _saveSettings();
    }

    await _applyWindowEffect();
    try {
      await _windowChannel.invokeMethod('setDragSuspend', {
        'enabled': _dragSuspend,
      });
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
    if (_effectEnabled != enabled) {
      _effectEnabled = enabled;
      await _applyWindowEffect();
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> setEffectMode(String mode) async {
    if (_effectMode != mode) {
      _effectMode = mode;
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
        await _windowChannel.invokeMethod('setDragSuspend', {
          'enabled': value,
        });
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

  Future<void> _applyWindowEffect() async {
    try {
      final effectiveMode = _effectEnabled ? _effectMode : 'none';
      await _windowChannel.invokeMethod('setWindowEffect', {
        'mode': effectiveMode,
        'alpha': _effectEnabled ? _alpha : 255,
        'roundedCornersEnabled': _roundedCornersEnabled,
        'cornerRadius': windowCornerRadius.round(),
      });
    } catch (e) {
      debugPrint('setWindowEffect error: $e');
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
