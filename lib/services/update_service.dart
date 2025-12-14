import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/constants.dart';
import 'app_logger_service.dart';

/// 版本通道枚举
/// alpha < beta < release
enum VersionChannel {
  alpha, 
  beta,   
  release, 
}

/// 版本信息类
class VersionInfo {
  final int major;
  final int minor;
  final int patch;
  final VersionChannel channel;

  VersionInfo({
    required this.major,
    required this.minor,
    required this.patch,
    required this.channel,
  });

  /// 从版本字符串解析，如 "1.0.2", "1.0.2-alpha", "1.0.2-beta"
  factory VersionInfo.parse(String versionStr) {
    // 移除 v/V 前缀
    var cleaned = versionStr.replaceFirst(RegExp(r'^[vV]'), '').trim();
    
    // 分离版本号和通道
    VersionChannel channel = VersionChannel.release;
    if (cleaned.contains('-')) {
      final parts = cleaned.split('-');
      cleaned = parts[0];
      final channelStr = parts[1].toLowerCase();
      if (channelStr == 'alpha') {
        channel = VersionChannel.alpha;
      } else if (channelStr == 'beta') {
        channel = VersionChannel.beta;
      }
    }

    // 解析版本号
    final versionParts = cleaned.split('.');
    return VersionInfo(
      major: int.tryParse(versionParts.isNotEmpty ? versionParts[0] : '0') ?? 0,
      minor: int.tryParse(versionParts.length > 1 ? versionParts[1] : '0') ?? 0,
      patch: int.tryParse(versionParts.length > 2 ? versionParts[2] : '0') ?? 0,
      channel: channel,
    );
  }

  /// 获取通道优先级 (release > beta > alpha)
  int get channelPriority {
    switch (channel) {
      case VersionChannel.alpha:
        return 0;
      case VersionChannel.beta:
        return 1;
      case VersionChannel.release:
        return 2;
    }
  }

  /// 比较两个版本，返回 >0 表示当前版本更新，<0 表示更旧，0 表示相同
  int compareTo(VersionInfo other) {
    // 先比较主版本号
    if (major != other.major) return major - other.major;
    if (minor != other.minor) return minor - other.minor;
    if (patch != other.patch) return patch - other.patch;
    // 版本号相同时比较通道
    return channelPriority - other.channelPriority;
  }

  /// 只比较版本号，不比较通道
  int compareVersionOnly(VersionInfo other) {
    if (major != other.major) return major - other.major;
    if (minor != other.minor) return minor - other.minor;
    return patch - other.patch;
  }

  String get versionString => '$major.$minor.$patch';
  
  String get fullVersionString {
    if (channel == VersionChannel.release) {
      return versionString;
    }
    return '$versionString-${channel.name}';
  }

  @override
  String toString() => fullVersionString;
}


/// 更新信息类
class UpdateInfo {
  final String version;
  final VersionInfo versionInfo;
  final String downloadUrl;
  final String changelog;
  final String publishedAt;
  final bool isPrerelease;

  UpdateInfo({
    required this.version,
    required this.versionInfo,
    required this.downloadUrl,
    required this.changelog,
    required this.publishedAt,
    required this.isPrerelease,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    // 查找 Windows 可执行文件
    String downloadUrl = '';
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.exe') || name.endsWith('.zip')) {
        downloadUrl = asset['browser_download_url'] as String? ?? '';
        break;
      }
    }

    String version = json['tag_name'] as String? ?? '';
    version = version.replaceFirst(RegExp(r'^[vV]'), '');

    return UpdateInfo(
      version: version,
      versionInfo: VersionInfo.parse(version),
      downloadUrl: downloadUrl,
      changelog: json['body'] as String? ?? '暂无更新日志',
      publishedAt: json['published_at'] as String? ?? '',
      isPrerelease: json['prerelease'] as bool? ?? false,
    );
  }
}

/// 更新检查间隔枚举
enum UpdateCheckInterval {
  startup,      // 仅启动时
  hourly,       // 每小时
  daily,        // 每天
  weekly,       // 每周
  never,        // 从不自动检查
}

extension UpdateCheckIntervalExtension on UpdateCheckInterval {
  String get displayName {
    switch (this) {
      case UpdateCheckInterval.startup:
        return '仅启动时';
      case UpdateCheckInterval.hourly:
        return '每小时';
      case UpdateCheckInterval.daily:
        return '每天';
      case UpdateCheckInterval.weekly:
        return '每周';
      case UpdateCheckInterval.never:
        return '从不';
    }
  }

  Duration? get duration {
    switch (this) {
      case UpdateCheckInterval.startup:
        return null;
      case UpdateCheckInterval.hourly:
        return const Duration(hours: 1);
      case UpdateCheckInterval.daily:
        return const Duration(hours: 24);
      case UpdateCheckInterval.weekly:
        return const Duration(days: 7);
      case UpdateCheckInterval.never:
        return null;
    }
  }
}


/// 更新服务
class UpdateService extends ChangeNotifier {
  static const String _repoOwner = 'buaoyezz';
  static const String _repoName = 'Hanabi-Download-Manager-X';
  static const String _apiUrl = 'https://api.github.com/repos/$_repoOwner/$_repoName/releases';

  // 缓存相关的 SharedPreferences keys
  static const String _keyLastCheckTime = 'update_last_check_time';
  static const String _keyCachedChangelog = 'update_cached_changelog';
  static const String _keyCachedVersion = 'update_cached_version';
  static const String _keyCheckInterval = 'update_check_interval';
  static const String _keyAllowBeta = 'update_allow_beta';
  static const String _keyAllowAlpha = 'update_allow_alpha';

  final AppLoggerService? _logger;
  
  bool _isChecking = false;
  String? _error;
  UpdateInfo? _latestRelease;
  UpdateInfo? _currentRelease;
  UpdateInfo? _availableUpdate; // 根据用户设置筛选后的可用更新
  List<UpdateInfo> _allReleases = [];
  
  // 当前版本信息
  late VersionInfo _currentVersionInfo;
  String _currentVersion = AppConstants.version;
  VersionChannel _currentChannel = VersionChannel.release;

  // 用户设置
  bool _allowBeta = false;
  bool _allowAlpha = false;
  UpdateCheckInterval _checkInterval = UpdateCheckInterval.startup;
  DateTime? _lastCheckTime;
  String? _cachedChangelog;
  Timer? _autoCheckTimer;

  // Getters
  bool get isChecking => _isChecking;
  String? get error => _error;
  UpdateInfo? get latestRelease => _latestRelease;
  UpdateInfo? get currentRelease => _currentRelease;
  UpdateInfo? get availableUpdate => _availableUpdate;
  String get currentVersion => _currentVersion;
  VersionChannel get currentChannel => _currentChannel;
  bool get allowBeta => _allowBeta;
  bool get allowAlpha => _allowAlpha;
  UpdateCheckInterval get checkInterval => _checkInterval;
  DateTime? get lastCheckTime => _lastCheckTime;
  bool get isVersionNewer => _isCurrentVersionNewer();

  UpdateService({AppLoggerService? logger}) : _logger = logger {
    _currentVersionInfo = VersionInfo.parse(_currentVersion);
    _currentChannel = _parseChannel(AppConstants.channel);
  }

  VersionChannel _parseChannel(String channel) {
    switch (channel.toLowerCase()) {
      case 'alpha':
        return VersionChannel.alpha;
      case 'beta':
        return VersionChannel.beta;
      default:
        return VersionChannel.release;
    }
  }

  /// 初始化服务，加载设置和缓存
  Future<void> initialize() async {
    await _loadSettings();
    await _loadCache();
    _currentVersion = AppConstants.version;
    _currentVersionInfo = VersionInfo.parse(_currentVersion);
    _currentChannel = _parseChannel(AppConstants.channel);
    _logger?.info('Update', '当前版本: $_currentVersion (${_currentChannel.name})');
    
    // 启动自动检查定时器
    _startAutoCheckTimer();
    
    notifyListeners();
  }

  /// 加载用户设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowBeta = prefs.getBool(_keyAllowBeta) ?? false;
      _allowAlpha = prefs.getBool(_keyAllowAlpha) ?? false;
      final intervalIndex = prefs.getInt(_keyCheckInterval) ?? 0;
      _checkInterval = UpdateCheckInterval.values[intervalIndex.clamp(0, UpdateCheckInterval.values.length - 1)];
      
      final lastCheckMs = prefs.getInt(_keyLastCheckTime);
      if (lastCheckMs != null) {
        _lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
      }
      
      _logger?.info('Update', '设置已加载: allowBeta=$_allowBeta, allowAlpha=$_allowAlpha, interval=${_checkInterval.name}');
    } catch (e) {
      _logger?.error('Update', '加载设置失败: $e');
    }
  }

  /// 加载缓存的更新日志
  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedChangelog = prefs.getString(_keyCachedChangelog);
      final cachedVersion = prefs.getString(_keyCachedVersion);
      
      if (_cachedChangelog != null && cachedVersion == _currentVersion) {
        _logger?.info('Update', '已加载缓存的更新日志');
      } else {
        _cachedChangelog = null;
      }
    } catch (e) {
      _logger?.error('Update', '加载缓存失败: $e');
    }
  }

  /// 保存缓存
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentRelease != null) {
        await prefs.setString(_keyCachedChangelog, _currentRelease!.changelog);
        await prefs.setString(_keyCachedVersion, _currentVersion);
      }
      if (_lastCheckTime != null) {
        await prefs.setInt(_keyLastCheckTime, _lastCheckTime!.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger?.error('Update', '保存缓存失败: $e');
    }
  }


  /// 设置是否允许 Beta 更新
  Future<void> setAllowBeta(bool value) async {
    _allowBeta = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllowBeta, value);
    _filterAvailableUpdate();
    notifyListeners();
  }

  /// 设置是否允许 Alpha 更新
  Future<void> setAllowAlpha(bool value) async {
    _allowAlpha = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAllowAlpha, value);
    _filterAvailableUpdate();
    notifyListeners();
  }

  /// 设置检查间隔
  Future<void> setCheckInterval(UpdateCheckInterval interval) async {
    _checkInterval = interval;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCheckInterval, interval.index);
    _startAutoCheckTimer();
    notifyListeners();
  }

  /// 启动自动检查定时器
  void _startAutoCheckTimer() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = null;

    final duration = _checkInterval.duration;
    if (duration != null) {
      _autoCheckTimer = Timer.periodic(duration, (_) {
        checkForUpdates();
      });
      _logger?.info('Update', '自动检查定时器已启动: ${_checkInterval.displayName}');
    }
  }

  /// 检查是否需要自动检查更新
  Future<bool> shouldAutoCheck() async {
    if (_checkInterval == UpdateCheckInterval.never) return false;
    if (_checkInterval == UpdateCheckInterval.startup) return true;
    
    if (_lastCheckTime == null) return true;
    
    final duration = _checkInterval.duration;
    if (duration == null) return false;
    
    return DateTime.now().difference(_lastCheckTime!) >= duration;
  }

  /// 检查当前版本是否比云端最新版本更新
  bool _isCurrentVersionNewer() {
    if (_allReleases.isEmpty) return false;
    
    // 找到云端最高版本
    UpdateInfo? highest;
    for (final release in _allReleases) {
      if (highest == null || release.versionInfo.compareTo(highest.versionInfo) > 0) {
        highest = release;
      }
    }
    
    if (highest == null) return false;
    return _currentVersionInfo.compareTo(highest.versionInfo) > 0;
  }

  /// 检查更新
  Future<bool> checkForUpdates({bool force = false}) async {
    if (_isChecking) return false;
    
    _isChecking = true;
    _error = null;
    notifyListeners();

    _logger?.info('Update', '开始检查更新...');

    try {
      // 获取所有发布版本
      _allReleases = await _fetchAllReleases();
      _lastCheckTime = DateTime.now();
      
      if (_allReleases.isEmpty) {
        _error = '未找到任何发布版本';
        _isChecking = false;
        notifyListeners();
        return false;
      }

      // 查找当前版本的发布信息
      _currentRelease = _findReleaseByVersion(_currentVersion);
      
      // 如果当前版本在云端不存在，说明版本过新
      if (_currentRelease == null) {
        _logger?.info('Update', '当前版本 $_currentVersion 在云端不存在，可能是开发版本');
      }

      // 根据用户设置筛选可用更新
      _filterAvailableUpdate();
      
      // 保存缓存
      await _saveCache();

      _isChecking = false;
      notifyListeners();
      
      return _availableUpdate != null;
    } catch (e) {
      _error = '检查更新失败: $e';
      _logger?.error('Update', _error!);
      _isChecking = false;
      notifyListeners();
      return false;
    }
  }

  /// 获取所有发布版本
  Future<List<UpdateInfo>> _fetchAllReleases() async {
    try {
      _logger?.info('Update', '请求 GitHub API: $_apiUrl');
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        final releases = data.map((item) => UpdateInfo.fromJson(item as Map<String, dynamic>)).toList();
        _logger?.info('Update', '获取到 ${releases.length} 个发布版本');
        return releases;
      } else {
        _logger?.error('Update', 'API 响应错误: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _logger?.error('Update', '获取发布版本失败: $e');
      return [];
    }
  }

  /// 根据版本号查找发布信息
  UpdateInfo? _findReleaseByVersion(String version) {
    final targetVersion = VersionInfo.parse(version);
    for (final release in _allReleases) {
      if (release.versionInfo.versionString == targetVersion.versionString) {
        return release;
      }
    }
    return null;
  }


  /// 根据用户设置筛选可用更新
  void _filterAvailableUpdate() {
    _availableUpdate = null;
    _latestRelease = null;

    if (_allReleases.isEmpty) return;

    UpdateInfo? bestUpdate;
    
    for (final release in _allReleases) {
      final releaseVersion = release.versionInfo;
      
      // 检查是否比当前版本新
      if (releaseVersion.compareTo(_currentVersionInfo) <= 0) {
        continue;
      }

      // 检查通道是否允许
      if (!_isChannelAllowed(releaseVersion.channel)) {
        continue;
      }

      // 选择最新的符合条件的版本
      if (bestUpdate == null || releaseVersion.compareTo(bestUpdate.versionInfo) > 0) {
        bestUpdate = release;
      }
    }

    _availableUpdate = bestUpdate;
    
    // 同时设置 latestRelease 为最新的 release 版本（用于显示）
    for (final release in _allReleases) {
      if (release.versionInfo.channel == VersionChannel.release) {
        if (_latestRelease == null || release.versionInfo.compareTo(_latestRelease!.versionInfo) > 0) {
          _latestRelease = release;
        }
      }
    }

    if (_availableUpdate != null) {
      _logger?.info('Update', '发现可用更新: ${_availableUpdate!.version}');
    } else {
      _logger?.info('Update', '没有可用更新');
    }
  }

  /// 检查通道是否允许
  bool _isChannelAllowed(VersionChannel channel) {
    switch (channel) {
      case VersionChannel.alpha:
        return _allowAlpha;
      case VersionChannel.beta:
        return _allowBeta || _allowAlpha; // alpha 用户也能收到 beta
      case VersionChannel.release:
        return true; // release 总是允许
    }
  }

  /// 检查是否有更新
  bool hasUpdate() {
    return _availableUpdate != null;
  }

  /// 获取当前版本的更新日志（从GitHub获取，已格式化）
  String getCurrentChangelog() {
    // 优先使用缓存
    if (_cachedChangelog != null && _cachedChangelog!.isNotEmpty) {
      return _formatChangelog(_cachedChangelog!);
    }
    if (_currentRelease != null) {
      return _formatChangelog(_currentRelease!.changelog);
    }
    if (_isCurrentVersionNewer()) {
      return '当前版本 v$_currentVersion 抱歉无法获取到该版本的更新日志，该版本还未发布任何信息';
    }
    return '正在获取更新日志...';
  }

  /// 获取格式化后的最新版本更新日志
  String getLatestChangelog() {
    if (_availableUpdate != null) {
      return _formatChangelog(_availableUpdate!.changelog);
    }
    if (_latestRelease != null) {
      return _formatChangelog(_latestRelease!.changelog);
    }
    return '暂无更新日志';
  }

  /// 格式化 changelog，清理不需要的内容并改善显示
  String _formatChangelog(String raw) {
    if (raw.isEmpty) return '暂无更新日志';

    final lines = raw.split('\n');
    final result = <String>[];
    bool skipSection = false;

    for (var line in lines) {
      final trimmed = line.trim();

      // 跳过文件下载区域
      if (trimmed.startsWith('### File') || 
          trimmed.startsWith('### Extension') ||
          trimmed.startsWith('---')) {
        skipSection = true;
        continue;
      }

      // 跳过不需要的内容
      if (skipSection || 
          trimmed.startsWith('sha256:') ||
          trimmed.startsWith('&gt;[') ||
          trimmed.startsWith('>[') ||
          trimmed.startsWith('Official Website:') ||
          trimmed.startsWith('**Full Changelog**') ||
          trimmed.contains('browser_download_url') ||
          trimmed.contains('/releases/download/')) {
        continue;
      }

      // 处理 [+] [-] [*] 格式
      if (trimmed.startsWith('[+]') || 
          trimmed.startsWith('[-]') || 
          trimmed.startsWith('[*]')) {
        final content = trimmed.substring(3).trim();
        result.add('- $content');
        continue;
      }

      // 处理 HTML 转义字符
      var processed = line
          .replaceAll('&gt;', '>')
          .replaceAll('&lt;', '<')
          .replaceAll('&amp;', '&');

      result.add(processed);
    }

    // 清理多余的空行
    final cleaned = <String>[];
    bool lastWasEmpty = false;
    for (var line in result) {
      final isEmpty = line.trim().isEmpty;
      if (isEmpty && lastWasEmpty) continue;
      cleaned.add(line);
      lastWasEmpty = isEmpty;
    }

    return cleaned.join('\n').trim();
  }

  /// 获取通道显示名称
  String getChannelDisplayName(VersionChannel channel) {
    switch (channel) {
      case VersionChannel.alpha:
        return 'Alpha (测试版)';
      case VersionChannel.beta:
        return 'Beta (公测版)';
      case VersionChannel.release:
        return 'Release (稳定版)';
    }
  }

  /// 释放资源
  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }
}
