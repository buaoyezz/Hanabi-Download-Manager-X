import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'app_logger_service.dart';
import '../utils/constants.dart';

/// 客户端配置服务
/// 配置目录结构：
/// ~/.hdmx/
///   ├── config/
///   │   ├── app.json          (应用配置)
///   │   ├── ui.json           (界面配置)
///   │   └── log.json          (日志配置)
///   ├── data/
///   │   ├── bookmarks.json    (书签数据)
///   │   └── history.json      (历史记录)
///   └── cache/
///       └── temp/             (临时文件)
class ClientConfigService extends ChangeNotifier {
  static final ClientConfigService _instance = ClientConfigService._internal();
  factory ClientConfigService() => _instance;
  ClientConfigService._internal();

  final _logger = AppLoggerService();
  
  // 目录路径
  late String _baseDir;
  late String _configDir;
  late String _dataDir;
  late String _cacheDir;
  
  // 配置文件路径
  late String _appConfigPath;
  late String _uiConfigPath;
  late String _logConfigPath;
  
  // 配置数据
  Map<String, dynamic> _appConfig = {};
  Map<String, dynamic> _uiConfig = {};
  Map<String, dynamic> _logConfig = {};
  bool _isLoaded = false;

  /// 初始化配置服务
  Future<void> initialize() async {
    try {
      // 获取用户主目录
      final homeDir = Platform.environment['USERPROFILE'] ?? 
                      Platform.environment['HOME'] ?? 
                      Directory.current.path;
      
      _baseDir = path.join(homeDir, '.hdmx');
      _configDir = path.join(_baseDir, 'config');
      _dataDir = path.join(_baseDir, 'data');
      _cacheDir = path.join(_baseDir, 'cache');
      
      _appConfigPath = path.join(_configDir, 'app.json');
      _uiConfigPath = path.join(_configDir, 'ui.json');
      _logConfigPath = path.join(_configDir, 'log.json');
      
      _logger.info('App', '配置基础目录: $_baseDir');
      
      // 创建目录结构
      await _createDirectories();
      
      // 加载配置
      await _loadAllConfigs();
      _isLoaded = true;
      
      _logger.info('App', '配置服务初始化完成');
    } catch (e) {
      _logger.error('App', '初始化配置服务失败: $e');
    }
  }

  /// 创建目录结构
  Future<void> _createDirectories() async {
    final dirs = [
      _configDir,
      _dataDir,
      path.join(_cacheDir, 'temp'),
    ];
    
    for (final dir in dirs) {
      final directory = Directory(dir);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        _logger.info('App', '创建目录: $dir');
      }
    }
  }

  /// 加载所有配置
  Future<void> _loadAllConfigs() async {
    _appConfig = await _loadConfigFile(_appConfigPath, _getDefaultAppConfig());
    _uiConfig = await _loadConfigFile(_uiConfigPath, _getDefaultUiConfig());
    _logConfig = await _loadConfigFile(_logConfigPath, _getDefaultLogConfig());
  }

  /// 加载单个配置文件
  Future<Map<String, dynamic>> _loadConfigFile(String filePath, Map<String, dynamic> defaultConfig) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final config = jsonDecode(content) as Map<String, dynamic>;
        _logger.info('App', '加载配置: ${path.basename(filePath)}');
        return config;
      } else {
        _logger.info('App', '配置文件不存在，创建默认配置: ${path.basename(filePath)}');
        await _saveConfigFile(filePath, defaultConfig);
        return defaultConfig;
      }
    } catch (e) {
      _logger.error('App', '加载配置失败 ${path.basename(filePath)}: $e');
      return defaultConfig;
    }
  }

  /// 保存单个配置文件
  Future<void> _saveConfigFile(String filePath, Map<String, dynamic> config) async {
    try {
      final file = File(filePath);
      final content = const JsonEncoder.withIndent('  ').convert(config);
      await file.writeAsString(content);
      _logger.debug('App', '保存配置: ${path.basename(filePath)}');
    } catch (e) {
      _logger.error('App', '保存配置失败 ${path.basename(filePath)}: $e');
    }
  }

  /// 获取默认应用配置
  Map<String, dynamic> _getDefaultAppConfig() {
    return {
      'version': AppConstants.version,
      'last_updated': DateTime.now().toIso8601String(),
      'behavior': {
        'auto_start_download': true,
        'notify_on_complete': true,
        'close_button_behavior': 'minimize_to_tray', // 默认最小化到托盘
      },
    };
  }

  /// 获取默认界面配置
  Map<String, dynamic> _getDefaultUiConfig() {
    return {
      'version': AppConstants.version,
      'window': {
        'effect_mode': 'acrylic',
        'effect_alpha': 160,
        'width': 889.0,  // 上次保存的窗口宽度
        'height': 586.0, // 上次保存的窗口高度
        'is_maximized': false,
        'remember_size': false, // 默认不记忆窗口大小，使用默认值
        'default_width': 889.0,  // 默认窗口宽度
        'default_height': 586.0, // 默认窗口高度
        'scale_factor': 1.0, // UI缩放比例，1.0为100%
      },
      'sidebar': {
        'default_expanded': true, // 默认侧边栏展开
      },
      'segments': {
        'default_expanded': false,
        'max_visible': 5,
      },
      'completed_list': {
        'custom_categories': [], // 自定义分类列表
      },
    };
  }

  /// 获取默认日志配置
  Map<String, dynamic> _getDefaultLogConfig() {
    return {
      'version': AppConstants.version,
      'display': {
        'show_stats': true,
        'auto_scroll': true,
      },
      'regex_rules': [
        {
          'name': 'URL',
          'pattern': r'https?://[^\s]+',
          'enabled': true,
          'color': 0xFF60CDFF,
        },
        {
          'name': 'IP地址',
          'pattern': r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b',
          'enabled': true,
          'color': 0xFF6CCB5F,
        },
        {
          'name': '文件路径',
          'pattern': r'[A-Za-z]:\\[^\s]+|/[^\s]+',
          'enabled': true,
          'color': 0xFFFFB900,
        },
        {
          'name': '数字',
          'pattern': r'\b\d+\.?\d*\s*(MB|KB|GB|ms|s|%)\b',
          'enabled': false,
          'color': 0xFFFF6B6B,
        },
      ],
    };
  }

  /// 获取配置值（从指定的配置文件）
  T? _getFromConfig<T>(Map<String, dynamic> config, String key, {T? defaultValue}) {
    if (!_isLoaded) {
      return defaultValue;
    }
    
    final keys = key.split('.');
    dynamic value = config;
    
    for (final k in keys) {
      if (value is Map<String, dynamic> && value.containsKey(k)) {
        value = value[k];
      } else {
        return defaultValue;
      }
    }
    
    return value as T?;
  }

  /// 设置配置值（到指定的配置文件）
  Future<void> _setToConfig(Map<String, dynamic> config, String filePath, String key, dynamic value) async {
    final keys = key.split('.');
    Map<String, dynamic> current = config;
    
    for (int i = 0; i < keys.length - 1; i++) {
      final k = keys[i];
      if (!current.containsKey(k) || current[k] is! Map<String, dynamic>) {
        current[k] = <String, dynamic>{};
      }
      current = current[k] as Map<String, dynamic>;
    }
    
    current[keys.last] = value;
    config['last_updated'] = DateTime.now().toIso8601String();
    
    await _saveConfigFile(filePath, config);
    notifyListeners();
  }

  // ========== 日志配置 ==========
  
  List<Map<String, dynamic>> getLogRegexRules() {
    final rules = _getFromConfig<List>(_logConfig, 'regex_rules', defaultValue: []);
    return rules?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<void> saveLogRegexRules(List<Map<String, dynamic>> rules) async {
    await _setToConfig(_logConfig, _logConfigPath, 'regex_rules', rules);
  }

  bool getLogShowStats() {
    return _getFromConfig<bool>(_logConfig, 'display.show_stats', defaultValue: true) ?? true;
  }

  Future<void> setLogShowStats(bool value) async {
    await _setToConfig(_logConfig, _logConfigPath, 'display.show_stats', value);
  }

  bool getLogAutoScroll() {
    return _getFromConfig<bool>(_logConfig, 'display.auto_scroll', defaultValue: true) ?? true;
  }

  Future<void> setLogAutoScroll(bool value) async {
    await _setToConfig(_logConfig, _logConfigPath, 'display.auto_scroll', value);
  }

  // ========== 界面配置 ==========
  
  String getWindowEffectMode() {
    return _getFromConfig<String>(_uiConfig, 'window.effect_mode', defaultValue: 'acrylic') ?? 'acrylic';
  }

  Future<void> setWindowEffectMode(String mode) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'window.effect_mode', mode);
  }

  int getWindowEffectAlpha() {
    return _getFromConfig<int>(_uiConfig, 'window.effect_alpha', defaultValue: 160) ?? 160;
  }

  Future<void> setWindowEffectAlpha(int alpha) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'window.effect_alpha', alpha);
  }

  double getWindowWidth() {
    return _getFromConfig<double>(_uiConfig, 'window.width', defaultValue: 889.0) ?? 889.0;
  }

  Future<void> setWindowWidth(double width) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'window.width', width);
  }

  double getWindowHeight() {
    return _getFromConfig<double>(_uiConfig, 'window.height', defaultValue: 586.0) ?? 586.0;
  }

  Future<void> setWindowHeight(double height) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'window.height', height);
  }

  bool getWindowMaximized() {
    return _getFromConfig<bool>(_uiConfig, 'window.is_maximized', defaultValue: false) ?? false;
  }

  Future<void> setWindowMaximized(bool maximized) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'window.is_maximized', maximized);
  }

  bool getWindowRememberSize() {
    return _getFromConfig<bool>(_uiConfig, 'window.remember_size', defaultValue: false) ?? false;
  }

  Future<void> setWindowRememberSize(bool value) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'window.remember_size', value);
  }

  double getWindowDefaultWidth() {
    return _getFromConfig<double>(_uiConfig, 'window.default_width', defaultValue: 889.0) ?? 889.0;
  }

  Future<void> setWindowDefaultWidth(double width) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'window.default_width', width);
  }

  double getWindowDefaultHeight() {
    return _getFromConfig<double>(_uiConfig, 'window.default_height', defaultValue: 586.0) ?? 586.0;
  }

  Future<void> setWindowDefaultHeight(double height) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'window.default_height', height);
  }

  bool getSegmentsDefaultExpanded() {
    return _getFromConfig<bool>(_uiConfig, 'segments.default_expanded', defaultValue: false) ?? false;
  }

  Future<void> setSegmentsDefaultExpanded(bool value) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'segments.default_expanded', value);
  }

  int getSegmentsMaxVisible() {
    return _getFromConfig<int>(_uiConfig, 'segments.max_visible', defaultValue: 5) ?? 5;
  }

  Future<void> setSegmentsMaxVisible(int value) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'segments.max_visible', value);
  }

  bool getSidebarDefaultExpanded() {
    return _getFromConfig<bool>(_uiConfig, 'sidebar.default_expanded', defaultValue: true) ?? true;
  }

  Future<void> setSidebarDefaultExpanded(bool value) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'sidebar.default_expanded', value);
  }

  String getCloseButtonBehavior() {
    return _getFromConfig<String>(_appConfig, 'behavior.close_button_behavior', defaultValue: 'minimize_to_tray') ?? 'minimize_to_tray';
  }

  Future<void> setCloseButtonBehavior(String behavior) async {
    await _setToConfig(_appConfig, _appConfigPath, 'behavior.close_button_behavior', behavior);
  }

  double getWindowScaleFactor() {
    return _getFromConfig<double>(_uiConfig, 'window.scale_factor', defaultValue: 1.0) ?? 1.0;
  }

  Future<void> setWindowScaleFactor(double scale) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'window.scale_factor', scale);
  }

  // ========== 自定义分类配置 ==========
  
  /// 获取自定义分类列表
  List<Map<String, dynamic>> getCustomCategories() {
    final categories = _getFromConfig<List>(_uiConfig, 'completed_list.custom_categories', defaultValue: []);
    return categories?.cast<Map<String, dynamic>>() ?? [];
  }

  /// 保存自定义分类列表
  Future<void> saveCustomCategories(List<Map<String, dynamic>> categories) async {
    await _setToConfig(_uiConfig, _uiConfigPath, 'completed_list.custom_categories', categories);
  }

  /// 添加自定义分类
  Future<void> addCustomCategory(String name, List<String> extensions) async {
    final categories = getCustomCategories();
    categories.add({
      'name': name,
      'extensions': extensions,
      'created_at': DateTime.now().toIso8601String(),
    });
    await saveCustomCategories(categories);
  }

  /// 删除自定义分类
  Future<void> removeCustomCategory(int index) async {
    final categories = getCustomCategories();
    if (index >= 0 && index < categories.length) {
      categories.removeAt(index);
      await saveCustomCategories(categories);
    }
  }

  /// 更新自定义分类
  Future<void> updateCustomCategory(int index, String name, List<String> extensions) async {
    final categories = getCustomCategories();
    if (index >= 0 && index < categories.length) {
      categories[index] = {
        'name': name,
        'extensions': extensions,
        'created_at': categories[index]['created_at'],
        'updated_at': DateTime.now().toIso8601String(),
      };
      await saveCustomCategories(categories);
    }
  }

  /// 根据屏幕分辨率自动设置缩放比例（仅在首次启动或缩放为默认值时）
  Future<void> autoSetScaleFactorByResolution(double screenWidth, double screenHeight) async {
    // 只有当前缩放为默认值 1.0 时才自动设置
    final currentScale = getWindowScaleFactor();
    if (currentScale != 1.0) {
      _logger.info('App', '缩放已手动设置为 ${(currentScale * 100).toInt()}%，跳过自动设置');
      return;
    }

    // 根据屏幕分辨率计算推荐的缩放比例
    double recommendedScale = 1.0;
    
    // 计算屏幕的像素密度（以 1920x1080 为基准）
    final pixelCount = screenWidth * screenHeight;
    
    if (pixelCount >= 3840 * 2160) {
      // 4K 及以上 (8,294,400 像素)
      recommendedScale = 1.25;
      _logger.info('App', '检测到 4K 或更高分辨率屏幕 (${screenWidth.toInt()}x${screenHeight.toInt()})，推荐缩放: 125%');
    } else if (pixelCount >= 2560 * 1440) {
      // 2K (3,686,400 像素)
      recommendedScale = 1.15;
      _logger.info('App', '检测到 2K 分辨率屏幕 (${screenWidth.toInt()}x${screenHeight.toInt()})，推荐缩放: 115%');
    } else if (pixelCount >= 1920 * 1080) {
      // FHD (2,073,600 像素)
      recommendedScale = 1.0;
      _logger.info('App', '检测到 FHD 分辨率屏幕 (${screenWidth.toInt()}x${screenHeight.toInt()})，使用默认缩放: 100%');
    } else {
      // 低于 FHD
      recommendedScale = 1.0;
      _logger.info('App', '检测到标准分辨率屏幕 (${screenWidth.toInt()}x${screenHeight.toInt()})，使用默认缩放: 100%');
    }

    // 应用推荐的缩放比例
    if (recommendedScale != currentScale) {
      await setWindowScaleFactor(recommendedScale);
      _logger.info('App', '已自动设置 UI 缩放为 ${(recommendedScale * 100).toInt()}%');
    }
  }

  // ========== 应用配置 ==========
  
  /// 通用的 bool 配置获取方法
  bool getBool(String key, {bool defaultValue = false}) {
    return _getFromConfig<bool>(_appConfig, key, defaultValue: defaultValue) ?? defaultValue;
  }

  /// 通用的 bool 配置设置方法
  Future<void> setBool(String key, bool value) async {
    await _setToConfig(_appConfig, _appConfigPath, key, value);
  }

  bool getAutoStartDownload() {
    return _getFromConfig<bool>(_appConfig, 'behavior.auto_start_download', defaultValue: true) ?? true;
  }

  Future<void> setAutoStartDownload(bool value) async {
    await _setToConfig(_appConfig, _appConfigPath, 'behavior.auto_start_download', value);
  }

  bool getNotifyOnComplete() {
    return _getFromConfig<bool>(_appConfig, 'behavior.notify_on_complete', defaultValue: true) ?? true;
  }

  Future<void> setNotifyOnComplete(bool value) async {
    await _setToConfig(_appConfig, _appConfigPath, 'behavior.notify_on_complete', value);
  }

  // ========== 配置管理 ==========
  
  /// 导出所有配置到目录
  Future<bool> exportAllConfigs(String targetDir) async {
    try {
      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      await File(_appConfigPath).copy(path.join(targetDir, 'app.json'));
      await File(_uiConfigPath).copy(path.join(targetDir, 'ui.json'));
      await File(_logConfigPath).copy(path.join(targetDir, 'log.json'));
      
      _logger.info('App', '导出所有配置到: $targetDir');
      return true;
    } catch (e) {
      _logger.error('App', '导出配置失败: $e');
      return false;
    }
  }

  /// 从目录导入所有配置
  Future<bool> importAllConfigs(String sourceDir) async {
    try {
      final appFile = File(path.join(sourceDir, 'app.json'));
      final uiFile = File(path.join(sourceDir, 'ui.json'));
      final logFile = File(path.join(sourceDir, 'log.json'));
      
      if (await appFile.exists()) {
        _appConfig = jsonDecode(await appFile.readAsString());
        await _saveConfigFile(_appConfigPath, _appConfig);
      }
      
      if (await uiFile.exists()) {
        _uiConfig = jsonDecode(await uiFile.readAsString());
        await _saveConfigFile(_uiConfigPath, _uiConfig);
      }
      
      if (await logFile.exists()) {
        _logConfig = jsonDecode(await logFile.readAsString());
        await _saveConfigFile(_logConfigPath, _logConfig);
      }
      
      notifyListeners();
      _logger.info('App', '导入配置成功');
      return true;
    } catch (e) {
      _logger.error('App', '导入配置失败: $e');
      return false;
    }
  }

  /// 重置为默认配置
  Future<void> resetToDefault() async {
    _appConfig = _getDefaultAppConfig();
    _uiConfig = _getDefaultUiConfig();
    _logConfig = _getDefaultLogConfig();
    
    await _saveConfigFile(_appConfigPath, _appConfig);
    await _saveConfigFile(_uiConfigPath, _uiConfig);
    await _saveConfigFile(_logConfigPath, _logConfig);
    
    notifyListeners();
    _logger.info('App', '重置为默认配置');
  }

  // ========== 路径访问器 ==========
  
  String get baseDir => _baseDir;
  String get configDir => _configDir;
  String get dataDir => _dataDir;
  String get cacheDir => _cacheDir;
  
  String get appConfigPath => _appConfigPath;
  String get uiConfigPath => _uiConfigPath;
  String get logConfigPath => _logConfigPath;
}

