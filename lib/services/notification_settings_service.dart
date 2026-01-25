import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 通知位置
enum NotificationPosition {
  topRight,
  bottomRight,
}

/// 通知配色方案
enum NotificationColorScheme {
  defaultScheme, // 跟随主题
  light, // 浅色系
  dark, // 深色系
  fluent2, // Fluent 2 色系
  custom, // 自定义
}

/// Fluent 2 配色
class Fluent2Colors {
  // 主色调
  static const primary = Color(0xFF0078D4); // Fluent Blue
  static const success = Color(0xFF107C10); // Fluent Green
  static const warning = Color(0xFFF7630C); // Fluent Orange
  static const error = Color(0xFFD13438); // Fluent Red
  static const info = Color(0xFF0078D4); // Fluent Blue
  
  // 背景色
  static const cardLight = Color(0xFFFAFAFA);
  static const cardDark = Color(0xFF2D2D2D);
  
  // 文本色
  static const textPrimaryLight = Color(0xFF242424);
  static const textSecondaryLight = Color(0xFF605E5C);
  static const textPrimaryDark = Color(0xFFFFFFFF);
  static const textSecondaryDark = Color(0xFFC8C6C4);
}

/// 通知设置服务
class NotificationSettingsService {
  static final NotificationSettingsService _instance = NotificationSettingsService._internal();
  factory NotificationSettingsService() => _instance;
  NotificationSettingsService._internal();

  static const String _keyEnabled = 'notification_enabled';
  static const String _keyColorScheme = 'notification_color_scheme';
  static const String _keyPosition = 'notification_position';
  static const String _keyCustomPrimary = 'notification_custom_primary';
  static const String _keyCustomSuccess = 'notification_custom_success';
  static const String _keyCustomWarning = 'notification_custom_warning';
  static const String _keyCustomError = 'notification_custom_error';
  static const String _keyCustomInfo = 'notification_custom_info';

  SharedPreferences? _prefs;
  
  // 默认值
  bool _enabled = true;
  NotificationColorScheme _colorScheme = NotificationColorScheme.fluent2;
  NotificationPosition _position = NotificationPosition.topRight;
  
  // 自定义颜色
  Color _customPrimary = Fluent2Colors.primary;
  Color _customSuccess = Fluent2Colors.success;
  Color _customWarning = Fluent2Colors.warning;
  Color _customError = Fluent2Colors.error;
  Color _customInfo = Fluent2Colors.info;

  // Getters
  bool get enabled => _enabled;
  NotificationColorScheme get colorScheme => _colorScheme;
  NotificationPosition get position => _position;
  Color get customPrimary => _customPrimary;
  Color get customSuccess => _customSuccess;
  Color get customWarning => _customWarning;
  Color get customError => _customError;
  Color get customInfo => _customInfo;

  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    _enabled = _prefs?.getBool(_keyEnabled) ?? true;
    
    final colorSchemeIndex = _prefs?.getInt(_keyColorScheme) ?? NotificationColorScheme.fluent2.index;
    _colorScheme = NotificationColorScheme.values[colorSchemeIndex];
    
    final positionIndex = _prefs?.getInt(_keyPosition) ?? NotificationPosition.topRight.index;
    _position = NotificationPosition.values[positionIndex];
    
    // 加载自定义颜色
    _customPrimary = Color(_prefs?.getInt(_keyCustomPrimary) ?? Fluent2Colors.primary.value);
    _customSuccess = Color(_prefs?.getInt(_keyCustomSuccess) ?? Fluent2Colors.success.value);
    _customWarning = Color(_prefs?.getInt(_keyCustomWarning) ?? Fluent2Colors.warning.value);
    _customError = Color(_prefs?.getInt(_keyCustomError) ?? Fluent2Colors.error.value);
    _customInfo = Color(_prefs?.getInt(_keyCustomInfo) ?? Fluent2Colors.info.value);
  }

  /// 设置是否启用通知
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs?.setBool(_keyEnabled, value);
  }

  /// 设置配色方案
  Future<void> setColorScheme(NotificationColorScheme scheme) async {
    _colorScheme = scheme;
    await _prefs?.setInt(_keyColorScheme, scheme.index);
  }

  /// 设置通知位置
  Future<void> setPosition(NotificationPosition pos) async {
    _position = pos;
    await _prefs?.setInt(_keyPosition, pos.index);
  }

  /// 设置自定义颜色
  Future<void> setCustomColors({
    Color? primary,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
  }) async {
    if (primary != null) {
      _customPrimary = primary;
      await _prefs?.setInt(_keyCustomPrimary, primary.value);
    }
    if (success != null) {
      _customSuccess = success;
      await _prefs?.setInt(_keyCustomSuccess, success.value);
    }
    if (warning != null) {
      _customWarning = warning;
      await _prefs?.setInt(_keyCustomWarning, warning.value);
    }
    if (error != null) {
      _customError = error;
      await _prefs?.setInt(_keyCustomError, error.value);
    }
    if (info != null) {
      _customInfo = info;
      await _prefs?.setInt(_keyCustomInfo, info.value);
    }
  }

  /// 获取当前配色的颜色
  Color getSuccessColor(bool isDark) {
    switch (_colorScheme) {
      case NotificationColorScheme.defaultScheme:
        return isDark ? const Color(0xFF4CAF50) : const Color(0xFF2E7D32);
      case NotificationColorScheme.light:
        return const Color(0xFF2E7D32);
      case NotificationColorScheme.dark:
        return const Color(0xFF66BB6A);
      case NotificationColorScheme.fluent2:
        return Fluent2Colors.success;
      case NotificationColorScheme.custom:
        return _customSuccess;
    }
  }

  Color getWarningColor(bool isDark) {
    switch (_colorScheme) {
      case NotificationColorScheme.defaultScheme:
        return isDark ? const Color(0xFFFFA726) : const Color(0xFFF57C00);
      case NotificationColorScheme.light:
        return const Color(0xFFF57C00);
      case NotificationColorScheme.dark:
        return const Color(0xFFFFB74D);
      case NotificationColorScheme.fluent2:
        return Fluent2Colors.warning;
      case NotificationColorScheme.custom:
        return _customWarning;
    }
  }

  Color getErrorColor(bool isDark) {
    switch (_colorScheme) {
      case NotificationColorScheme.defaultScheme:
        return isDark ? const Color(0xFFEF5350) : const Color(0xFFC62828);
      case NotificationColorScheme.light:
        return const Color(0xFFC62828);
      case NotificationColorScheme.dark:
        return const Color(0xFFE57373);
      case NotificationColorScheme.fluent2:
        return Fluent2Colors.error;
      case NotificationColorScheme.custom:
        return _customError;
    }
  }

  Color getInfoColor(bool isDark) {
    switch (_colorScheme) {
      case NotificationColorScheme.defaultScheme:
        return isDark ? const Color(0xFF42A5F5) : const Color(0xFF1976D2);
      case NotificationColorScheme.light:
        return const Color(0xFF1976D2);
      case NotificationColorScheme.dark:
        return const Color(0xFF64B5F6);
      case NotificationColorScheme.fluent2:
        return Fluent2Colors.info;
      case NotificationColorScheme.custom:
        return _customInfo;
    }
  }

  Color getCardColor(bool isDark) {
    switch (_colorScheme) {
      case NotificationColorScheme.light:
        return Fluent2Colors.cardLight;
      case NotificationColorScheme.dark:
        return Fluent2Colors.cardDark;
      case NotificationColorScheme.fluent2:
        return isDark ? Fluent2Colors.cardDark : Fluent2Colors.cardLight;
      default:
        return isDark ? const Color(0xFF2D2D2D) : const Color(0xFFFAFAFA);
    }
  }

  Color getTextPrimaryColor(bool isDark) {
    switch (_colorScheme) {
      case NotificationColorScheme.light:
        return Fluent2Colors.textPrimaryLight;
      case NotificationColorScheme.dark:
        return Fluent2Colors.textPrimaryDark;
      case NotificationColorScheme.fluent2:
        return isDark ? Fluent2Colors.textPrimaryDark : Fluent2Colors.textPrimaryLight;
      default:
        return isDark ? const Color(0xFFFFFFFF) : const Color(0xFF242424);
    }
  }

  Color getTextSecondaryColor(bool isDark) {
    switch (_colorScheme) {
      case NotificationColorScheme.light:
        return Fluent2Colors.textSecondaryLight;
      case NotificationColorScheme.dark:
        return Fluent2Colors.textSecondaryDark;
      case NotificationColorScheme.fluent2:
        return isDark ? Fluent2Colors.textSecondaryDark : Fluent2Colors.textSecondaryLight;
      default:
        return isDark ? const Color(0xFFC8C6C4) : const Color(0xFF605E5C);
    }
  }
}
