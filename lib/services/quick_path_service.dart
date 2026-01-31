import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'app_logger_service.dart';

/// 快捷路径项
class QuickPath {
  final String name;
  final String path;

  QuickPath({required this.name, required this.path});

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
  };

  factory QuickPath.fromJson(Map<String, dynamic> json) {
    return QuickPath(
      name: json['name'] as String,
      path: json['path'] as String,
    );
  }
}

/// 快捷路径服务
class QuickPathService extends ChangeNotifier {
  static final QuickPathService _instance = QuickPathService._internal();
  factory QuickPathService() => _instance;
  QuickPathService._internal();

  final _logger = AppLoggerService();
  final List<QuickPath> _quickPaths = [];
  late String _configPath;
  bool _isLoaded = false;

  List<QuickPath> get quickPaths => List.unmodifiable(_quickPaths);

  /// 初始化服务
  Future<void> initialize(String configDir) async {
    try {
      _configPath = path.join(configDir, 'quick_paths.json');
      _logger.info('App', '快捷路径配置: $_configPath');
      
      await _loadQuickPaths();
      _isLoaded = true;
      
      _logger.info('App', '快捷路径服务初始化完成，共 ${_quickPaths.length} 个快捷路径');
    } catch (e) {
      _logger.error('App', '初始化快捷路径服务失败: $e');
    }
  }

  /// 加载快捷路径
  Future<void> _loadQuickPaths() async {
    try {
      final file = File(_configPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final paths = (data['paths'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        _quickPaths.clear();
        for (final pathData in paths) {
          _quickPaths.add(QuickPath.fromJson(pathData));
        }
        
        _logger.info('App', '加载了 ${_quickPaths.length} 个快捷路径');
      } else {
        // 创建默认快捷路径
        await _createDefaultQuickPaths();
      }
    } catch (e) {
      _logger.error('App', '加载快捷路径失败: $e');
      await _createDefaultQuickPaths();
    }
  }

  /// 创建默认快捷路径
  Future<void> _createDefaultQuickPaths() async {
    _quickPaths.clear();
    
    // 获取常用系统路径
    final userProfile = Platform.environment['USERPROFILE'] ?? 
                       Platform.environment['HOME'] ?? 
                       '';
    
    if (userProfile.isNotEmpty) {
      final defaultPaths = [
        QuickPath(name: '桌面', path: path.join(userProfile, 'Desktop')),
        QuickPath(name: '文档', path: path.join(userProfile, 'Documents')),
        QuickPath(name: '下载', path: path.join(userProfile, 'Downloads')),
        QuickPath(name: '图片', path: path.join(userProfile, 'Pictures')),
        QuickPath(name: '视频', path: path.join(userProfile, 'Videos')),
        QuickPath(name: '音乐', path: path.join(userProfile, 'Music')),
      ];
      
      // 只添加存在的路径
      for (final quickPath in defaultPaths) {
        if (await Directory(quickPath.path).exists()) {
          _quickPaths.add(quickPath);
        }
      }
    }
    
    await _saveQuickPaths();
    _logger.info('App', '创建了 ${_quickPaths.length} 个默认快捷路径');
  }

  /// 保存快捷路径
  Future<void> _saveQuickPaths() async {
    try {
      final data = {
        'version': '1.0',
        'last_updated': DateTime.now().toIso8601String(),
        'paths': _quickPaths.map((p) => p.toJson()).toList(),
      };
      
      final file = File(_configPath);
      final content = const JsonEncoder.withIndent('  ').convert(data);
      await file.writeAsString(content);
      
      _logger.debug('App', '保存快捷路径配置');
    } catch (e) {
      _logger.error('App', '保存快捷路径失败: $e');
    }
  }

  /// 添加快捷路径
  Future<bool> addQuickPath(String pathStr, {String? customName}) async {
    if (!_isLoaded) return false;
    
    try {
      // 验证路径是否存在
      final dir = Directory(pathStr);
      if (!await dir.exists()) {
        _logger.warning('App', '路径不存在: $pathStr');
        return false;
      }
      
      // 检查是否已存在
      if (_quickPaths.any((p) => p.path == pathStr)) {
        _logger.warning('App', '快捷路径已存在: $pathStr');
        return false;
      }
      
      // 生成名称
      String name;
      if (customName != null && customName.isNotEmpty) {
        name = customName;
      } else {
        // 自动生成名称（使用文件夹名）
        name = path.basename(pathStr);
        if (name.isEmpty || name == path.separator) {
          name = pathStr; // 如果是根目录，使用完整路径
        }
      }
      
      final quickPath = QuickPath(name: name, path: pathStr);
      _quickPaths.add(quickPath);
      
      await _saveQuickPaths();
      notifyListeners();
      
      _logger.info('App', '添加快捷路径: $name -> $pathStr');
      return true;
    } catch (e) {
      _logger.error('App', '添加快捷路径失败: $e');
      return false;
    }
  }

  /// 删除快捷路径
  Future<bool> removeQuickPath(String pathStr) async {
    if (!_isLoaded) return false;
    
    try {
      final index = _quickPaths.indexWhere((p) => p.path == pathStr);
      if (index == -1) {
        _logger.warning('App', '快捷路径不存在: $pathStr');
        return false;
      }
      
      final removed = _quickPaths.removeAt(index);
      await _saveQuickPaths();
      notifyListeners();
      
      _logger.info('App', '删除快捷路径: ${removed.name}');
      return true;
    } catch (e) {
      _logger.error('App', '删除快捷路径失败: $e');
      return false;
    }
  }

  /// 更新快捷路径名称
  Future<bool> updateQuickPathName(String pathStr, String newName) async {
    if (!_isLoaded) return false;
    
    try {
      final index = _quickPaths.indexWhere((p) => p.path == pathStr);
      if (index == -1) {
        _logger.warning('App', '快捷路径不存在: $pathStr');
        return false;
      }
      
      _quickPaths[index] = QuickPath(name: newName, path: pathStr);
      await _saveQuickPaths();
      notifyListeners();
      
      _logger.info('App', '更新快捷路径名称: $newName');
      return true;
    } catch (e) {
      _logger.error('App', '更新快捷路径名称失败: $e');
      return false;
    }
  }

  /// 清空所有快捷路径
  Future<void> clearAll() async {
    _quickPaths.clear();
    await _saveQuickPaths();
    notifyListeners();
    _logger.info('App', '清空所有快捷路径');
  }

  /// 重置为默认快捷路径
  Future<void> resetToDefault() async {
    await _createDefaultQuickPaths();
    notifyListeners();
    _logger.info('App', '重置为默认快捷路径');
  }
}
