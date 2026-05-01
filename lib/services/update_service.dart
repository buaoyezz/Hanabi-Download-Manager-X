import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../utils/constants.dart';
import 'app_logger_service.dart';

/// 版本通道枚举
/// alpha < release
enum VersionChannel {
  alpha,
  release,
}

/// 更新紧急程度
enum UpdateUrgency {
  normal,
  recommended,
  forced,
}

/// 版本信息类
class VersionInfo {
  final int major;
  final int minor;
  final int patch;
  final VersionChannel channel;
  final int preReleaseNumber;
  final String? preReleaseLabel;
  final bool isSupportedChannel;

  VersionInfo({
    required this.major,
    required this.minor,
    required this.patch,
    required this.channel,
    this.preReleaseNumber = 0,
    this.preReleaseLabel,
    this.isSupportedChannel = true,
  });

  /// 从版本字符串解析，如 "1.0.2", "1.0.2-alpha", "1.0.2-alpha.2"
  factory VersionInfo.parse(String versionStr) {
    // 移除 v/V 前缀
    var cleaned = versionStr
        .replaceAll('。', '.')
        .replaceAll('．', '.')
        .replaceFirst(RegExp(r'^[vV]'), '')
        .trim();
    final buildMetadataIndex = cleaned.indexOf('+');
    if (buildMetadataIndex >= 0) {
      cleaned = cleaned.substring(0, buildMetadataIndex);
    }

    // 分离版本号和通道
    VersionChannel channel = VersionChannel.release;
    var preReleaseNumber = 0;
    String? preReleaseLabel;
    var isSupportedChannel = true;
    if (cleaned.contains('-')) {
      final separatorIndex = cleaned.indexOf('-');
      final channelStr = cleaned.substring(separatorIndex + 1).toLowerCase();
      cleaned = cleaned.substring(0, separatorIndex);
      final channelMatch =
          RegExp(r'^([a-z][a-z0-9]*)(?:[._-]?(\d+))?$').firstMatch(channelStr);
      final channelName = channelMatch?.group(1);
      preReleaseLabel = channelName;
      if (channelName == 'alpha') {
        channel = VersionChannel.alpha;
      } else {
        channel = VersionChannel.alpha;
        isSupportedChannel = false;
      }
      preReleaseNumber = int.tryParse(channelMatch?.group(2) ?? '') ?? 0;
    }

    // 解析版本号
    final versionParts = cleaned.split('.');
    return VersionInfo(
      major: int.tryParse(versionParts.isNotEmpty ? versionParts[0] : '0') ?? 0,
      minor: int.tryParse(versionParts.length > 1 ? versionParts[1] : '0') ?? 0,
      patch: int.tryParse(versionParts.length > 2 ? versionParts[2] : '0') ?? 0,
      channel: channel,
      preReleaseNumber: preReleaseNumber,
      preReleaseLabel: preReleaseLabel,
      isSupportedChannel: isSupportedChannel,
    );
  }

  /// 获取通道优先级 (release > alpha)
  int get channelPriority {
    switch (channel) {
      case VersionChannel.alpha:
        return 0;
      case VersionChannel.release:
        return 1;
    }
  }

  /// 比较两个版本，返回 >0 表示当前版本更新，<0 表示更旧，0 表示相同
  int compareTo(VersionInfo other) {
    // 先比较主版本号
    if (major != other.major) return major - other.major;
    if (minor != other.minor) return minor - other.minor;
    if (patch != other.patch) return patch - other.patch;
    // 版本号相同时比较通道
    if (channelPriority != other.channelPriority) {
      return channelPriority - other.channelPriority;
    }
    if (channel != VersionChannel.release &&
        preReleaseLabel != other.preReleaseLabel) {
      return (preReleaseLabel ?? '').compareTo(other.preReleaseLabel ?? '');
    }
    if (channel != VersionChannel.release &&
        preReleaseNumber != other.preReleaseNumber) {
      return preReleaseNumber - other.preReleaseNumber;
    }
    return 0;
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
    final label = preReleaseLabel ?? channel.name;
    if (preReleaseNumber > 0) {
      return '$versionString-$label.$preReleaseNumber';
    }
    return '$versionString-$label';
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
  final UpdateUrgency urgency;
  final VersionInfo? minSupportedVersion;

  UpdateInfo({
    required this.version,
    required this.versionInfo,
    required this.downloadUrl,
    required this.changelog,
    required this.publishedAt,
    required this.isPrerelease,
    required this.urgency,
    this.minSupportedVersion,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    // 查找 Windows 主程序更新包，避免误选浏览器扩展或源码包。
    String downloadUrl = '';
    final assets = json['assets'] as List<dynamic>? ?? [];
    final asset = _selectWindowsPackageAsset(assets);
    if (asset != null) {
      downloadUrl = asset['browser_download_url'] as String? ?? '';
    }

    String version = json['tag_name'] as String? ?? '';
    version = version.replaceFirst(RegExp(r'^[vV]'), '');
    final isPrerelease = json['prerelease'] as bool? ?? false;
    final parsedVersion = VersionInfo.parse(version);
    final versionInfo =
        isPrerelease && parsedVersion.channel == VersionChannel.release
            ? VersionInfo(
                major: parsedVersion.major,
                minor: parsedVersion.minor,
                patch: parsedVersion.patch,
                channel: VersionChannel.alpha,
                preReleaseLabel: 'prerelease',
                isSupportedChannel: false,
              )
            : parsedVersion;

    final changelog = json['body'] as String? ?? '暂无更新日志';
    final explicitUrgency = (json['update_urgency'] ??
            json['update_level'] ??
            json['update_type'] ??
            json['urgency'])
        ?.toString();
    final explicitMinSupported = (json['min_supported_version'] ??
            json['minimum_supported_version'] ??
            json['min_version'])
        ?.toString();

    final urgency = explicitUrgency != null && explicitUrgency.trim().isNotEmpty
        ? _parseUrgencyValue(explicitUrgency)
        : _parseUrgencyFromChangelog(changelog);
    final minSupportedVersion =
        explicitMinSupported != null && explicitMinSupported.trim().isNotEmpty
            ? _tryParseVersion(explicitMinSupported)
            : _parseMinSupportedVersionFromChangelog(changelog);

    return UpdateInfo(
      version: version,
      versionInfo: versionInfo,
      downloadUrl: downloadUrl,
      changelog: changelog,
      publishedAt: json['published_at'] as String? ?? '',
      isPrerelease: isPrerelease,
      urgency: urgency,
      minSupportedVersion: minSupportedVersion,
    );
  }

  bool get isForcedUpdate => urgency == UpdateUrgency.forced;

  static Map<String, dynamic>? _selectWindowsPackageAsset(
    List<dynamic> assets,
  ) {
    final candidates = assets.whereType<Map>().where((asset) {
      final name = asset['name']?.toString() ?? '';
      return name.endsWith('.exe') || name.endsWith('.zip');
    }).map((asset) {
      return asset.map((key, value) => MapEntry(key.toString(), value));
    }).toList(growable: false);

    if (candidates.isEmpty) return null;

    int score(Map<String, dynamic> asset) {
      final name = (asset['name']?.toString() ?? '').toLowerCase();
      if (name.contains('source') ||
          name.contains('chrome_extension') ||
          name.contains('firefox_extension') ||
          name.contains('extension')) {
        return -1000;
      }

      var value = 0;
      if (name.contains('hanabidownloadmanagerx')) value += 100;
      if (name.contains('release_latest')) value += 80;
      if (name.contains('windows') ||
          name.contains('win64') ||
          name.contains('win-x64')) {
        value += 40;
      }
      if (name.contains('alpha')) value += 10;
      if (name.contains('mac') ||
          name.contains('darwin') ||
          name.contains('linux') ||
          name.contains('ubuntu')) {
        value -= 200;
      }

      final size = asset['size'];
      if (size is num) {
        if (size >= 10 * 1024 * 1024) value += 20;
        if (size > 0 && size < 1024 * 1024) value -= 50;
      }

      return value;
    }

    Map<String, dynamic>? best;
    var bestScore = 0;
    var bestSize = 0;
    for (final candidate in candidates) {
      final candidateScore = score(candidate);
      final candidateSize =
          candidate['size'] is num ? (candidate['size'] as num).toInt() : 0;
      if (candidateScore > bestScore ||
          (candidateScore == bestScore && candidateSize > bestSize)) {
        best = candidate;
        bestScore = candidateScore;
        bestSize = candidateSize;
      }
    }
    return best;
  }

  UpdateInfo copyWith({
    String? version,
    VersionInfo? versionInfo,
    String? downloadUrl,
    String? changelog,
    String? publishedAt,
    bool? isPrerelease,
    UpdateUrgency? urgency,
    VersionInfo? minSupportedVersion,
    bool keepMinSupportedVersion = true,
  }) {
    return UpdateInfo(
      version: version ?? this.version,
      versionInfo: versionInfo ?? this.versionInfo,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      changelog: changelog ?? this.changelog,
      publishedAt: publishedAt ?? this.publishedAt,
      isPrerelease: isPrerelease ?? this.isPrerelease,
      urgency: urgency ?? this.urgency,
      minSupportedVersion: keepMinSupportedVersion
          ? (minSupportedVersion ?? this.minSupportedVersion)
          : minSupportedVersion,
    );
  }

  static UpdateUrgency _parseUrgencyValue(String raw) {
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'forced':
      case 'force':
      case 'mandatory':
      case 'required':
      case 'critical':
        return UpdateUrgency.forced;
      case 'recommended':
      case 'recommend':
      case 'suggested':
      case 'important':
        return UpdateUrgency.recommended;
      default:
        return UpdateUrgency.normal;
    }
  }

  static UpdateUrgency _parseUrgencyFromChangelog(String changelog) {
    final text = changelog.toLowerCase();
    final forceFlag = RegExp(
      r'^\s*(force_update|mandatory_update|required_update)\s*[:=]\s*(1|true|yes)\s*$',
      multiLine: true,
      caseSensitive: false,
    );
    if (forceFlag.hasMatch(text) ||
        text.contains('#force-update') ||
        text.contains('#mandatory-update')) {
      return UpdateUrgency.forced;
    }

    final levelMatch = RegExp(
      r'^\s*(update_level|update_type|update_urgency|urgency)\s*[:=]\s*([a-z_]+)\s*$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(text);
    if (levelMatch != null) {
      return _parseUrgencyValue(levelMatch.group(2) ?? '');
    }

    if (text.contains('#recommended-update') || text.contains('#recommended')) {
      return UpdateUrgency.recommended;
    }
    return UpdateUrgency.normal;
  }

  static VersionInfo? _parseMinSupportedVersionFromChangelog(String changelog) {
    final match = RegExp(
      r'^\s*(min_supported_version|minimum_supported_version|min_version)\s*[:=]\s*([0-9]+\.[0-9]+\.[0-9]+(?:-[a-z]+)?)\s*$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(changelog);
    if (match == null) return null;
    final raw = match.group(2);
    if (raw == null || raw.trim().isEmpty) return null;
    return _tryParseVersion(raw);
  }

  static VersionInfo? _tryParseVersion(String raw) {
    try {
      return VersionInfo.parse(raw);
    } catch (_) {
      return null;
    }
  }
}

/// 更新检查间隔枚举
enum UpdateCheckInterval {
  startup, // 仅启动时
  hourly, // 每小时
  daily, // 每天
  weekly, // 每周
  never, // 从不自动检查
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
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases';

  // 缓存相关的 SharedPreferences keys
  static const String _keyLastCheckTime = 'update_last_check_time';
  static const String _keyCachedChangelog = 'update_cached_changelog';
  static const String _keyCachedVersion = 'update_cached_version';
  static const String _keyCheckInterval = 'update_check_interval';
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
  bool _allowAlpha = false;
  UpdateCheckInterval _checkInterval = UpdateCheckInterval.startup;
  DateTime? _lastCheckTime;
  String? _cachedChangelog;
  Timer? _autoCheckTimer;

  // 更新下载相关
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;

  // Getters
  bool get isChecking => _isChecking;
  String? get error => _error;
  UpdateInfo? get latestRelease => _latestRelease;
  UpdateInfo? get currentRelease => _currentRelease;
  UpdateInfo? get availableUpdate => _availableUpdate;
  String get currentVersion => _currentVersion;
  VersionChannel get currentChannel => _currentChannel;
  bool get allowAlpha => _allowAlpha;
  UpdateCheckInterval get checkInterval => _checkInterval;
  DateTime? get lastCheckTime => _lastCheckTime;
  bool get isVersionNewer => _isCurrentVersionNewer();
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get downloadError => _downloadError;
  bool get isForcedUpdate => _availableUpdate?.isForcedUpdate ?? false;
  bool get isRecommendedUpdate =>
      _availableUpdate?.urgency == UpdateUrgency.recommended;

  UpdateService({AppLoggerService? logger}) : _logger = logger {
    _currentVersionInfo = VersionInfo.parse(_currentVersion);
    _currentChannel = _resolveCurrentChannel(_currentVersionInfo);
  }

  VersionChannel _parseChannel(String channel) {
    switch (channel.toLowerCase()) {
      case 'alpha':
        return VersionChannel.alpha;
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
    _currentChannel = _resolveCurrentChannel(_currentVersionInfo);
    _logger?.info('Update', '当前版本: $_currentVersion (${_currentChannel.name})');

    // 启动自动检查定时器
    _startAutoCheckTimer();

    notifyListeners();
  }

  /// 加载用户设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowAlpha = prefs.getBool(_keyAllowAlpha) ?? false;
      final intervalIndex = prefs.getInt(_keyCheckInterval) ?? 0;
      _checkInterval = UpdateCheckInterval.values[
          intervalIndex.clamp(0, UpdateCheckInterval.values.length - 1)];

      final lastCheckMs = prefs.getInt(_keyLastCheckTime);
      if (lastCheckMs != null) {
        _lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
      }

      _logger?.info('Update',
          '设置已加载: allowAlpha=$_allowAlpha, interval=${_checkInterval.name}');
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
        await prefs.setInt(
            _keyLastCheckTime, _lastCheckTime!.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger?.error('Update', '保存缓存失败: $e');
    }
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
      if (highest == null ||
          release.versionInfo.compareTo(highest.versionInfo) > 0) {
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
        final releases = data
            .map((item) => UpdateInfo.fromJson(item as Map<String, dynamic>))
            .where((item) => item.versionInfo.isSupportedChannel)
            .toList();
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
    UpdateInfo? sameBaseVersion;
    for (final release in _allReleases) {
      if (!release.versionInfo.isSupportedChannel) {
        continue;
      }
      if (release.versionInfo.fullVersionString ==
          targetVersion.fullVersionString) {
        return release;
      }
      sameBaseVersion ??=
          release.versionInfo.versionString == targetVersion.versionString
              ? release
              : null;
    }
    if (targetVersion.channel != VersionChannel.release ||
        targetVersion.preReleaseNumber > 0) {
      return null;
    }
    return sameBaseVersion;
  }

  VersionChannel _resolveCurrentChannel(VersionInfo versionInfo) {
    if (versionInfo.channel != VersionChannel.release) {
      return versionInfo.channel;
    }
    return _parseChannel(AppConstants.channel);
  }

  /// 根据用户设置筛选可用更新
  void _filterAvailableUpdate() {
    _availableUpdate = null;
    _latestRelease = null;

    if (_allReleases.isEmpty) return;

    UpdateInfo? bestUpdate;

    for (final release in _allReleases) {
      final effectiveRelease = _applyUrgencyPolicy(release);
      final releaseVersion = effectiveRelease.versionInfo;
      if (!releaseVersion.isSupportedChannel) {
        continue;
      }

      // 检查是否比当前版本新
      if (releaseVersion.compareTo(_currentVersionInfo) <= 0) {
        continue;
      }

      // 强制更新不受更新通道开关限制
      if (effectiveRelease.urgency != UpdateUrgency.forced &&
          !_isChannelAllowed(releaseVersion.channel)) {
        continue;
      }

      // 选择最新的符合条件的版本
      if (bestUpdate == null ||
          releaseVersion.compareTo(bestUpdate.versionInfo) > 0) {
        bestUpdate = effectiveRelease;
      }
    }

    _availableUpdate = bestUpdate;

    // 同时设置 latestRelease 为最新的 release 版本（用于显示）
    for (final release in _allReleases) {
      if (release.versionInfo.channel == VersionChannel.release) {
        if (_latestRelease == null ||
            release.versionInfo.compareTo(_latestRelease!.versionInfo) > 0) {
          _latestRelease = release;
        }
      }
    }

    if (_availableUpdate != null) {
      _logger?.info(
        'Update',
        '发现可用更新: ${_availableUpdate!.version} (urgency=${_availableUpdate!.urgency.name})',
      );
    } else {
      _logger?.info('Update', '没有可用更新');
    }
  }

  UpdateInfo _applyUrgencyPolicy(UpdateInfo release) {
    var urgency = release.urgency;
    final minVersion = release.minSupportedVersion;
    if (minVersion != null &&
        _currentVersionInfo.compareVersionOnly(minVersion) < 0) {
      urgency = UpdateUrgency.forced;
    }
    if (urgency == release.urgency) return release;
    return release.copyWith(urgency: urgency);
  }

  /// 检查通道是否允许
  bool _isChannelAllowed(VersionChannel channel) {
    if (channel == VersionChannel.release) {
      return true;
    }

    if (_currentChannel == VersionChannel.alpha) {
      return true;
    }

    switch (channel) {
      case VersionChannel.alpha:
        return _allowAlpha;
      case VersionChannel.release:
        return true;
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

    // 处理可能存在的双转义 \n (文本中的 "\n" 字面量转为真正换行)
    raw = raw.replaceAll('\\n', '\n');

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
          RegExp(
            r'^(update_level|update_type|update_urgency|urgency)\s*[:=]',
            caseSensitive: false,
          ).hasMatch(trimmed) ||
          RegExp(
            r'^(min_supported_version|minimum_supported_version|min_version)\s*[:=]',
            caseSensitive: false,
          ).hasMatch(trimmed) ||
          RegExp(
            r'^(force_update|mandatory_update|required_update)\s*[:=]',
            caseSensitive: false,
          ).hasMatch(trimmed) ||
          trimmed.startsWith('#force-update') ||
          trimmed.startsWith('#mandatory-update') ||
          trimmed.startsWith('#recommended-update') ||
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
      case VersionChannel.release:
        return 'Release (稳定版)';
    }
  }

  @visibleForTesting
  void debugSetCurrentVersionForTest(
    String version, {
    VersionChannel? channel,
  }) {
    _currentVersion = version;
    _currentVersionInfo = VersionInfo.parse(version);
    _currentChannel = channel ?? _resolveCurrentChannel(_currentVersionInfo);
  }

  @visibleForTesting
  void debugSetReleasesForTest(List<UpdateInfo> releases) {
    _allReleases = releases;
  }

  @visibleForTesting
  UpdateInfo? debugFindReleaseByVersion(String version) {
    return _findReleaseByVersion(version);
  }

  @visibleForTesting
  void debugFilterAvailableUpdateForTest() {
    _filterAvailableUpdate();
  }

  /// 释放资源
  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  /// 下载更新包
  Future<String?> downloadUpdate() async {
    if (_availableUpdate == null) return null;
    if (_isDownloading) return null;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadError = null;
    notifyListeners();

    try {
      final downloadUrl = _availableUpdate!.downloadUrl;
      if (downloadUrl.isEmpty) {
        throw Exception('下载链接为空');
      }

      _logger?.info('Update', '开始下载更新包: $downloadUrl');

      // 创建临时目录
      final tempDir = await Directory.systemTemp.createTemp('hanabi_update_');
      final zipFileName = path.basename(downloadUrl);
      final zipPath = path.join(
          tempDir.path, zipFileName.isNotEmpty ? zipFileName : 'update.zip');

      // 使用 http 下载，支持进度回调
      final request = await HttpClient().getUrl(Uri.parse(downloadUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      final file = File(zipPath);
      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress = receivedBytes / totalBytes;
          notifyListeners();
        }
      }

      await sink.close();
      _downloadProgress = 1.0;
      _isDownloading = false;
      notifyListeners();

      _logger?.info('Update', '更新包下载完成: $zipPath');
      return zipPath;
    } catch (e) {
      _downloadError = '下载失败: $e';
      _logger?.error('Update', _downloadError!);
      _isDownloading = false;
      notifyListeners();
      return null;
    }
  }

  /// 查找更新器可执行文件
  Future<_UpdaterLocation?> _findUpdaterLocation() async {
    final exePath = Platform.resolvedExecutable;
    final exeDir = path.dirname(exePath);

    // 新更新器是 NativeAOT + Avalonia，小目录中包含 exe 和 native 渲染依赖。
    final possibleBundlePaths = [
      path.join(
          exeDir, 'data', 'zzbuaoye_assets', 'updater', 'HanabiUpdater.exe'),
      path.join(Directory.current.path, 'assets', 'update', 'updater',
          'HanabiUpdater.exe'),
      path.join(Directory.current.path, 'updater', 'dist', 'HanabiUpdater.exe'),
    ];

    for (final testPath in possibleBundlePaths) {
      if (await File(testPath).exists()) {
        return _UpdaterLocation(
          executablePath: testPath,
          bundleDirectory: path.dirname(testPath),
        );
      }
    }

    // 单文件更新器兼容路径。
    final possibleSinglePaths = [
      path.join(exeDir, 'data', 'zzbuaoye_assets', 'HanabiUpdater.exe'),
      path.join(
          Directory.current.path, 'assets', 'update', 'HanabiUpdater.exe'),
      path.join(exeDir, 'HanabiUpdater.exe'),
    ];

    for (final testPath in possibleSinglePaths) {
      if (await File(testPath).exists()) {
        return _UpdaterLocation(executablePath: testPath);
      }
    }

    return null;
  }

  /// 将更新器释放到临时目录
  Future<String?> _extractUpdaterToTemp() async {
    final updaterLocation = await _findUpdaterLocation();
    if (updaterLocation == null) {
      _downloadError = '更新器可执行文件未找到：请确认安装包包含 HanabiUpdater.exe';
      _logger?.error('Update', _downloadError!);
      return null;
    }

    final tempDir = await Directory.systemTemp.createTemp('hanabi_updater_');
    late final String destPath;

    if (updaterLocation.bundleDirectory != null) {
      final destDir = path.join(tempDir.path, 'updater');
      await _copyDirectory(updaterLocation.bundleDirectory!, destDir);
      destPath =
          path.join(destDir, path.basename(updaterLocation.executablePath));
    } else {
      destPath = path.join(
          tempDir.path, path.basename(updaterLocation.executablePath));
      await File(updaterLocation.executablePath).copy(destPath);
    }

    _logger?.info('Update', '更新器已释放到: $destPath');
    return destPath;
  }

  Future<void> _copyDirectory(String sourcePath, String destinationPath) async {
    final sourceDir = Directory(sourcePath);
    final destinationDir = Directory(destinationPath);
    await destinationDir.create(recursive: true);

    await for (final entity
        in sourceDir.list(recursive: true, followLinks: false)) {
      final relativePath = path.relative(entity.path, from: sourcePath);
      final targetPath = path.join(destinationPath, relativePath);

      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
      } else if (entity is File) {
        await Directory(path.dirname(targetPath)).create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  /// 启动更新器并退出主程序
  Future<bool> launchUpdater({
    String? zipPath,
    bool allowUpdaterDownload = false,
  }) async {
    try {
      _logger?.info('Update', '准备启动更新器...');

      String? actualZipPath = zipPath;
      if (actualZipPath == null && !allowUpdaterDownload) {
        actualZipPath = await downloadUpdate();
      }
      if (actualZipPath != null && !await File(actualZipPath).exists()) {
        _logger?.error('Update', '更新包不存在，无法启动更新器');
        return false;
      }
      if (actualZipPath == null &&
          (_availableUpdate == null || _availableUpdate!.downloadUrl.isEmpty)) {
        _downloadError = '更新包不存在，且没有可用的下载地址';
        _logger?.error('Update', _downloadError!);
        notifyListeners();
        return false;
      }

      // 将更新器释放到临时目录
      final updaterPath = await _extractUpdaterToTemp();
      if (updaterPath == null) {
        _downloadError ??= '无法准备更新器';
        _logger?.error('Update', _downloadError!);
        notifyListeners();
        return false;
      }

      // 获取当前进程 PID
      final currentPid = pid;

      // 获取主程序路径
      final appPath = Platform.resolvedExecutable;

      // 构建更新器参数
      final args = [
        '--app-path',
        appPath,
        if (actualZipPath != null) ...[
          '--zip-path',
          actualZipPath,
        ],
        '--app-name',
        'Hanabi Download Manager X',
        '--wait-pid',
        currentPid.toString(),
        if (_availableUpdate != null) ...[
          '--version',
          _availableUpdate!.version,
          if (_availableUpdate!.downloadUrl.isNotEmpty) ...[
            '--download-url',
            _availableUpdate!.downloadUrl,
          ],
          if (_availableUpdate!.versionInfo.channel == VersionChannel.alpha)
            '--alpha',
          if (_availableUpdate!.versionInfo.channel == VersionChannel.alpha)
            'true',
        ],
      ];

      _logger?.info('Update', '启动更新器: $updaterPath ${args.join(' ')}');

      // 启动更新器
      await Process.start(
        updaterPath,
        args,
        workingDirectory: path.dirname(updaterPath),
        mode: ProcessStartMode.detached,
      );

      _logger?.info('Update', '更新器已启动，准备退出主程序');

      // 延迟 500ms 后退出应用，确保更新器已启动
      Future.delayed(const Duration(milliseconds: 800), () {
        exit(0);
      });

      return true;
    } catch (e) {
      _downloadError = '启动更新器失败: $e';
      _logger?.error('Update', _downloadError!);
      notifyListeners();
      return false;
    }
  }

  /// 启动更新（下载 + 启动更新器）
  Future<bool> startUpdate() async {
    return launchUpdater(allowUpdaterDownload: true);
  }
}

class _UpdaterLocation {
  final String executablePath;
  final String? bundleDirectory;

  const _UpdaterLocation({
    required this.executablePath,
    this.bundleDirectory,
  });
}
