import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WindowEffectService extends ChangeNotifier {
  String _effectMode = 'acrylic';
  int _alpha = 160;
  final MethodChannel _windowChannel = const MethodChannel('com.hanabi.download/window');
  bool _isInitialized = false;

  String get effectMode => _effectMode;
  int get alpha => _alpha;

  // Helper to determine if we should use transparent Flutter background
  bool get isTransparentBackground => _effectMode == 'acrylic' || _effectMode == 'blur';

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    _effectMode = prefs.getString('window_effect_mode') ?? 'acrylic';
    _alpha = prefs.getInt('window_effect_alpha') ?? 160;
    
    await _applyWindowEffect();
    _isInitialized = true;
    notifyListeners();
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
      await _windowChannel.invokeMethod('setWindowEffect', {
        'mode': _effectMode,
        'alpha': _alpha,
      });
    } catch (e) {
      debugPrint('setWindowEffect error: $e');
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('window_effect_mode', _effectMode);
    await prefs.setInt('window_effect_alpha', _alpha);
  }
}
