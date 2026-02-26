import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_logger_service.dart';
import '../utils/constants.dart';

class UserProfileService extends ChangeNotifier {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  
  final _logger = AppLoggerService();
  final _uuid = const Uuid();
  
  String? _deviceId;
  Map<String, dynamic>? _profile;
  String _appVersion = AppConstants.version;
  
  String? get deviceId => _deviceId;
  Map<String, dynamic>? get profile => _profile;
  String get appVersion => _appVersion;

  UserProfileService._internal();

  /// 初始化用户配置
  Future<void> initialize() async {
    try {
      await _loadAppVersion();
      
      final profileFile = await _getProfileFile();
      
      if (await profileFile.exists()) {
        final content = await profileFile.readAsString();
        _profile = jsonDecode(content);
        _deviceId = _profile!['device_id'];
        
        _logger.info('UserProfile', 'Loaded existing profile: $_deviceId');
        
        final savedVersion = _profile!['version'];
        if (savedVersion != _appVersion) {
          _logger.info('UserProfile', 'Version changed: $savedVersion -> $_appVersion');
          _profile!['version'] = _appVersion;
        }
        
        _profile!['last_launch'] = DateTime.now().toIso8601String();
        _profile!['launch_count'] = (_profile!['launch_count'] ?? 0) + 1;
        await _saveProfile();
      } else {
        await _createNewProfile();
      }
    } catch (e) {
      _logger.error('UserProfile', 'Failed to initialize: $e');
      await _createNewProfile();
    }
  }

  /// 从 pubspec.yaml 加载应用版本号
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _logger.info('UserProfile', 'App version loaded: $_appVersion');
    } catch (e) {
      _logger.warning('UserProfile', 'Failed to load app version, using fallback: $e');
      _appVersion = AppConstants.version;
    }
  }

  /// 创建新的用户配置
  Future<void> _createNewProfile() async {
    _deviceId = _uuid.v4();
    
    final deviceInfo = await _collectDeviceInfo();
    
    _profile = {
      'device_id': _deviceId,
      'created_at': DateTime.now().toIso8601String(),
      'last_launch': DateTime.now().toIso8601String(),
      'launch_count': 1,
      'device_info': deviceInfo,
      'version': _appVersion,
    };
    
    await _saveProfile();
    _logger.info('UserProfile', 'Created new profile: $_deviceId');
  }

  /// 收集设备信息
  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    try {
      return {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
        'number_of_processors': Platform.numberOfProcessors,
      };
    } catch (e) {
      _logger.warning('UserProfile', 'Failed to collect device info: $e');
      return {
        'platform': Platform.operatingSystem,
        'version': 'unknown',
      };
    }
  }

  /// 保存配置文件
  Future<void> _saveProfile() async {
    try {
      final profileFile = await _getProfileFile();
      await profileFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_profile),
      );
    } catch (e) {
      _logger.error('UserProfile', 'Failed to save profile: $e');
    }
  }

  /// 获取配置文件路径
  Future<File> _getProfileFile() async {
    final appDir = await getApplicationSupportDirectory();
    final dataDir = Directory('${appDir.path}/.hdmx/data');
    
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    
    return File('${dataDir.path}/User_Profile.json');
  }

  @override
  void dispose() {
    super.dispose();
  }
}
