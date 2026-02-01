import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WindowEffectService extends ChangeNotifier {
  String _effectMode = 'acrylic';
  int _alpha = 160;
  bool _effectEnabled = true; // 窗口效果总开关
  final MethodChannel _windowChannel = const MethodChannel('com.hanabi.download/window');
  bool _isInitialized = false;

  String get effectMode => _effectMode;
  int get alpha => _alpha;
  bool get effectEnabled => _effectEnabled;

  // Helper to determine if we should use transparent Flutter background
  bool get isTransparentBackground => _effectEnabled && (_effectMode == 'acrylic' || _effectMode == 'blur');

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _effectMode = prefs.getString('window_effect_mode') ?? 'acrylic';
    _alpha = prefs.getInt('window_effect_alpha') ?? 160;
    _effectEnabled = prefs.getBool('window_effect_enabled') ?? true;

    await _applyWindowEffect();
    _isInitialized = true;
    notifyListeners();
  }

  /// 设置窗口效果开关
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

  Future<void> _applyWindowEffect() async {
    try {
      // 如果效果被禁用，使用 'none' 模式
      final effectiveMode = _effectEnabled ? _effectMode : 'none';
      await _windowChannel.invokeMethod('setWindowEffect', {
        'mode': effectiveMode,
        'alpha': _effectEnabled ? _alpha : 255, // 禁用时使用不透明背景
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
  }
}
