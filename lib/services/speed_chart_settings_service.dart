import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpeedChartSettingsService extends ChangeNotifier {
  static final SpeedChartSettingsService _instance =
      SpeedChartSettingsService._internal();

  factory SpeedChartSettingsService() => _instance;

  SpeedChartSettingsService._internal();

  static const String keyShowSpeedChart = 'show_speed_chart';
  static const String keyShowChartFrost = 'show_chart_frost';
  static const String keyChartPosition = 'chart_position';
  static const String keyChartColor = 'chart_color';

  static const Set<String> validPositions = {'low', 'mid', 'high'};
  static const Set<String> validColors = {
    'blue',
    'cyan',
    'purple',
    'green',
    'pink',
    'orange',
  };

  SharedPreferences? _prefs;
  bool _showSpeedChart = true;
  bool _showChartFrost = true;
  String _chartPosition = 'mid';
  String _chartColor = 'blue';

  bool get showSpeedChart => _showSpeedChart;
  bool get showChartFrost => _showChartFrost;
  String get chartPosition => _chartPosition;
  String get chartColor => _chartColor;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _showSpeedChart = _prefs?.getBool(keyShowSpeedChart) ?? true;
    _showChartFrost = _prefs?.getBool(keyShowChartFrost) ?? true;
    _chartPosition = normalizePosition(_prefs?.getString(keyChartPosition));
    _chartColor = normalizeColor(_prefs?.getString(keyChartColor));
  }

  static String normalizePosition(String? value) {
    final normalized = value?.trim().toLowerCase();
    return validPositions.contains(normalized) ? normalized! : 'mid';
  }

  static String normalizeColor(String? value) {
    final normalized = value?.trim().toLowerCase();
    return validColors.contains(normalized) ? normalized! : 'blue';
  }

  Future<SharedPreferences> _preferences() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> setShowSpeedChart(bool value) async {
    if (_showSpeedChart == value) return;
    _showSpeedChart = value;
    await (await _preferences()).setBool(keyShowSpeedChart, value);
    notifyListeners();
  }

  Future<void> setShowChartFrost(bool value) async {
    if (_showChartFrost == value) return;
    _showChartFrost = value;
    await (await _preferences()).setBool(keyShowChartFrost, value);
    notifyListeners();
  }

  Future<void> setChartPosition(String value) async {
    final normalized = normalizePosition(value);
    if (_chartPosition == normalized) return;
    _chartPosition = normalized;
    await (await _preferences()).setString(keyChartPosition, normalized);
    notifyListeners();
  }

  Future<void> setChartColor(String value) async {
    final normalized = normalizeColor(value);
    if (_chartColor == normalized) return;
    _chartColor = normalized;
    await (await _preferences()).setString(keyChartColor, normalized);
    notifyListeners();
  }
}
