import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_logger_service.dart';
import '../utils/constants.dart';

class UserProfileService extends ChangeNotifier {
  static final UserProfileService _instance = UserProfileService._internal();
  factory UserProfileService() => _instance;
  
  final _logger = AppLoggerService();
  final _uuid = const Uuid();
  late final http.Client _httpClient;
  
  String? _deviceId;
  Map<String, dynamic>? _profile;
  Timer? _heartbeatTimer;
  String _appVersion = AppConstants.version; // 后备版本号
  DateTime? _lastManualHeartbeat; // 上次手动发送心跳的时间
  bool _statsEnabled = true; // 是否启用在线统计（默认启用）
  
  // 统计服务器地址
  static const String statsServerUrl = 'https://online.zzbuaoye.top';
  static const Duration heartbeatInterval = Duration(minutes: 5);
  static const Duration manualHeartbeatCooldown = Duration(minutes: 5); // 手动心跳冷却时间
  static const bool enableOnlineStats = true; // 启用在线统计
  
  String? get deviceId => _deviceId;
  Map<String, dynamic>? get profile => _profile;
  String get appVersion => _appVersion;
  bool get statsEnabled => _statsEnabled;

  UserProfileService._internal() {
    // 创建忽略 SSL 证书错误的 HTTP 客户端（用于 Cloudflare 代理）
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    _httpClient = IOClient(ioClient);
  }

  /// 初始化用户配置
  Future<void> initialize() async {
    try {
      // 首先获取应用版本号
      await _loadAppVersion();
      
      final profileFile = await _getProfileFile();
      
      if (await profileFile.exists()) {
        // 读取现有配置
        final content = await profileFile.readAsString();
        _profile = jsonDecode(content);
        _deviceId = _profile!['device_id'];
        _statsEnabled = _profile!['stats_enabled'] ?? true; // 读取统计开关状态，默认启用
        
        _logger.info('UserProfile', 'Loaded existing profile: $_deviceId (stats: $_statsEnabled)');
        
        // 检查版本号是否需要更新
        final savedVersion = _profile!['version'];
        if (savedVersion != _appVersion) {
          _logger.info('UserProfile', 'Version changed: $savedVersion -> $_appVersion');
          _profile!['version'] = _appVersion;
        }
        
        // 更新最后启动时间
        _profile!['last_launch'] = DateTime.now().toIso8601String();
        _profile!['launch_count'] = (_profile!['launch_count'] ?? 0) + 1;
        await _saveProfile();
      } else {
        // 创建新配置
        await _createNewProfile();
      }
      
      // 启动心跳
      await _startHeartbeat();
    } catch (e) {
      _logger.error('UserProfile', 'Failed to initialize: $e');
      // 如果出错，创建新配置
      await _createNewProfile();
    }
  }

  /// 从 pubspec.yaml 加载应用版本号
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _logger.info('UserProfile', 'App version loaded from pubspec.yaml: $_appVersion');
    } catch (e) {
      _logger.warning('UserProfile', 'Failed to load app version, using fallback: $e');
      _appVersion = AppConstants.version; // 使用后备版本号
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
      'stats_enabled': true, // 默认启用统计
    };
    
    _statsEnabled = true;
    await _saveProfile();
    _logger.info('UserProfile', 'Created new profile: $_deviceId (stats enabled)');
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

  /// 启动心跳
  Future<void> _startHeartbeat() async {
    // 如果统计被禁用，不启动心跳
    if (!_statsEnabled) {
      _logger.info('UserProfile', 'Stats disabled, heartbeat not started');
      return;
    }
    
    // 立即发送一次心跳
    await _sendHeartbeat();
    
    // 启动定时器
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendHeartbeat();
    });
    
    _logger.info('UserProfile', 'Heartbeat started (interval: ${heartbeatInterval.inMinutes} minutes)');
  }

  /// 发送心跳到统计服务器
  Future<void> _sendHeartbeat() async {
    if (_deviceId == null) return;
    
    // 如果统计被禁用，不发送心跳
    if (!_statsEnabled) {
      _logger.debug('UserProfile', 'Stats disabled, heartbeat skipped');
      return;
    }
    
    try {
      // 始终使用当前应用版本号（从 pubspec.yaml 读取）
      final platform = _profile?['device_info']?['platform'] ?? Platform.operatingSystem;
      final version = _appVersion; // 使用从 pubspec.yaml 读取的版本号
      final launchCount = _profile?['launch_count'] ?? 1;
      final createdAt = _profile?['created_at'] ?? DateTime.now().toIso8601String();
      final lastLaunch = _profile?['last_launch'] ?? DateTime.now().toIso8601String();
      
      // 同步更新 profile 中的版本号
      if (_profile != null && _profile!['version'] != version) {
        _profile!['version'] = version;
        await _saveProfile();
        _logger.info('UserProfile', 'Version updated in profile: $version');
      }
      
      final payload = {
        'device_id': _deviceId,
        'platform': platform,
        'version': version,
        'launch_count': launchCount,
        'created_at': createdAt,
        'last_launch': lastLaunch,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _logger.debug('UserProfile', 'Sending heartbeat: platform=$platform, version=$version');
      
      final response = await _httpClient.post(
        Uri.parse('$statsServerUrl/api/heartbeat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        _logger.info('UserProfile', 'Heartbeat sent successfully');
      } else {
        _logger.warning('UserProfile', 'Heartbeat failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.warning('UserProfile', 'Failed to send heartbeat: $e');
    }
  }

  /// 手动发送心跳（供用户主动触发）
  Future<Map<String, dynamic>> sendHeartbeatManually() async {
    if (_deviceId == null) {
      _logger.warning('UserProfile', 'Cannot send heartbeat: device not initialized');
      return {
        'success': false,
        'message': '设备未初始化',
      };
    }
    
    // 检查冷却时间
    if (_lastManualHeartbeat != null) {
      final timeSinceLastManual = DateTime.now().difference(_lastManualHeartbeat!);
      if (timeSinceLastManual < manualHeartbeatCooldown) {
        final remainingSeconds = (manualHeartbeatCooldown - timeSinceLastManual).inSeconds;
        final remainingMinutes = (remainingSeconds / 60).ceil();
        _logger.info('UserProfile', 'Manual heartbeat on cooldown: $remainingSeconds seconds remaining');
        return {
          'success': false,
          'message': 'cooldown',
          'remaining_seconds': remainingSeconds,
          'remaining_minutes': remainingMinutes,
        };
      }
    }
    
    try {
      await _sendHeartbeat();
      _lastManualHeartbeat = DateTime.now();
      _logger.info('UserProfile', 'Manual heartbeat sent successfully');
      return {
        'success': true,
        'message': '信号发送成功',
      };
    } catch (e) {
      _logger.error('UserProfile', 'Manual heartbeat failed: $e');
      return {
        'success': false,
        'message': '发送失败，请检查网络连接',
      };
    }
  }

  /// 获取距离下次可以手动发送心跳的剩余时间（秒）
  int? getRemainingCooldownSeconds() {
    if (_lastManualHeartbeat == null) return null;
    
    final timeSinceLastManual = DateTime.now().difference(_lastManualHeartbeat!);
    if (timeSinceLastManual >= manualHeartbeatCooldown) return null;
    
    return (manualHeartbeatCooldown - timeSinceLastManual).inSeconds;
  }

  /// 停止心跳
  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _logger.info('UserProfile', 'Heartbeat stopped');
  }

  /// 获取用于统计的数据
  Map<String, dynamic> getStatsData() {
    return {
      'device_id': _deviceId,
      'platform': _profile?['device_info']?['platform'] ?? Platform.operatingSystem,
      'version': _appVersion, // 使用从 pubspec.yaml 读取的版本号
      'launch_count': _profile?['launch_count'] ?? 1,
      'created_at': _profile?['created_at'],
      'last_launch': _profile?['last_launch'],
      'stats_enabled': _statsEnabled,
    };
  }
  
  /// 设置是否启用在线统计
  Future<void> setStatsEnabled(bool enabled) async {
    if (_statsEnabled == enabled) return;
    
    _statsEnabled = enabled;
    
    // 更新配置文件
    if (_profile != null) {
      _profile!['stats_enabled'] = enabled;
      await _saveProfile();
    }
    
    if (enabled) {
      // 启用统计：启动心跳
      _logger.info('UserProfile', 'Stats enabled, starting heartbeat');
      await _startHeartbeat();
    } else {
      // 禁用统计：停止心跳
      _logger.info('UserProfile', 'Stats disabled, stopping heartbeat');
      stopHeartbeat();
    }
    
    // 通知监听者状态已改变
    notifyListeners();
  }
  
  /// 清理资源
  @override
  void dispose() {
    stopHeartbeat();
    super.dispose();
  }
}
