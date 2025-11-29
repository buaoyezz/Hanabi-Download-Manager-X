import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperModeService extends ChangeNotifier {
  static final DeveloperModeService _instance = DeveloperModeService._internal();
  factory DeveloperModeService() => _instance;
  DeveloperModeService._internal();

  bool _developerMode = false;
  bool _showLogPage = false;
  bool _showStatusPage = false;

  bool get developerMode => _developerMode;
  bool get showLogPage => _showLogPage;
  bool get showStatusPage => _showStatusPage;

  // 是否显示任何调试页面
  bool get hasAnyDebugPage => _showLogPage || _showStatusPage;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _developerMode = prefs.getBool('developer_mode') ?? false;
    _showLogPage = prefs.getBool('show_log_page') ?? false;
    _showStatusPage = prefs.getBool('show_status_page') ?? false;
    notifyListeners();
  }

  Future<void> setDeveloperMode(bool value) async {
    _developerMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('developer_mode', value);
    
    // 如果关闭开发者模式，同时关闭所有调试页面
    if (!value) {
      _showLogPage = false;
      _showStatusPage = false;
      await prefs.setBool('show_log_page', false);
      await prefs.setBool('show_status_page', false);
    }
    
    notifyListeners();
  }

  Future<void> setShowLogPage(bool value) async {
    _showLogPage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_log_page', value);
    notifyListeners();
  }

  Future<void> setShowStatusPage(bool value) async {
    _showStatusPage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_status_page', value);
    notifyListeners();
  }
}
