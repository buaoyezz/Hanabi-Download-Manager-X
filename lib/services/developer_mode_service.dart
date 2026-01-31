import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperModeService extends ChangeNotifier {
  static final DeveloperModeService _instance = DeveloperModeService._internal();
  factory DeveloperModeService() => _instance;
  DeveloperModeService._internal();

  bool _developerMode = false;
  bool _showLogPage = false;
  bool _showStatusPage = false;
  bool _showWebCheckPage = false;
  bool _showOnlineStatsPage = false;

  bool get developerMode => _developerMode;
  bool get showLogPage => _showLogPage;
  bool get showStatusPage => _showStatusPage;
  bool get showWebCheckPage => _showWebCheckPage;
  bool get showOnlineStatsPage => _showOnlineStatsPage;

  // 是否显示任何调试页面
  bool get hasAnyDebugPage => _showLogPage || _showStatusPage || _showWebCheckPage || _showOnlineStatsPage;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _developerMode = prefs.getBool('developer_mode') ?? false;
    _showLogPage = prefs.getBool('show_log_page') ?? false;
    _showStatusPage = prefs.getBool('show_status_page') ?? false;
    _showWebCheckPage = prefs.getBool('show_web_check_page') ?? false;
    _showOnlineStatsPage = prefs.getBool('show_online_stats_page') ?? false;
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
      _showWebCheckPage = false;
      _showOnlineStatsPage = false;
      await prefs.setBool('show_log_page', false);
      await prefs.setBool('show_status_page', false);
      await prefs.setBool('show_web_check_page', false);
      await prefs.setBool('show_online_stats_page', false);
    }
    
    notifyListeners();
  }

  Future<void> setShowLogPage(bool value) async {
    if (_showLogPage == value) return; // 避免不必要的更新
    _showLogPage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_log_page', value);
    notifyListeners();
  }

  Future<void> setShowStatusPage(bool value) async {
    if (_showStatusPage == value) return; // 避免不必要的更新
    _showStatusPage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_status_page', value);
    notifyListeners();
  }

  Future<void> setShowWebCheckPage(bool value) async {
    if (_showWebCheckPage == value) return; // 避免不必要的更新
    _showWebCheckPage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_web_check_page', value);
    notifyListeners();
  }

  Future<void> setShowOnlineStatsPage(bool value) async {
    if (_showOnlineStatsPage == value) return; // 避免不必要的更新
    _showOnlineStatsPage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_online_stats_page', value);
    notifyListeners();
  }
}
