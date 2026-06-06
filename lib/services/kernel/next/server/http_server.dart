import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../nsfx_kernel.dart';
import '../../kernel_interface.dart';
import '../../../app_logger_service.dart';
import '../../../client_config_service.dart';

class NsfxHttpServer {
  HttpServer? _primaryServer;
  final List<HttpServer> _compatibilityServers = [];
  final NsfxKernel _kernel;
  final int port;
  final Set<int> compatibilityPorts;
  bool _isRunning = false;
  final _logger = AppLoggerService();

  // 待主窗口确认的浏览器下载请求队列
  final List<Map<String, dynamic>> _pendingPopups = [];
  final Map<String, DateTime> _recentPopupSignatures = {};
  static const Duration _popupDedupWindow = Duration(seconds: 4);

  // 在线用户统计
  final Map<String, DateTime> _activeSessions = {};
  final Map<String, Map<String, dynamic>> _deviceFingerprints =
      {}; // fingerprint -> device info
  final Map<String, String> _sessionToFingerprint =
      {}; // session_id -> fingerprint
  final List<Map<String, dynamic>> _onlineHistory = [];
  final List<Map<String, dynamic>> _allDevices = []; // 所有历史设备
  Timer? _cleanupTimer;
  Timer? _historyTimer;
  int? _lastLoggedUniqueDeviceCount;
  int? _lastLoggedSessionCount;
  int? _lastLoggedFingerprintMappingCount;
  static const Duration _sessionTimeout = Duration(minutes: 2);
  static const Duration _historyInterval = Duration(seconds: 10);

  bool get isRunning => _isRunning;

  NsfxHttpServer(
    this._kernel, {
    this.port = 9701,
    Iterable<int> compatibilityPorts = const [],
  }) : compatibilityPorts = compatibilityPorts
            .where((candidate) =>
                candidate != port &&
                ClientConfigService.isValidBrowserExtensionPortValue(candidate))
            .toSet();

  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      _primaryServer =
          await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _primaryServer!.listen(_handleRequest);
      _isRunning = true;
      _logger.info('NSFX-HTTP', 'HTTP server started on port $port');

      await _bindCompatibilityServers();

      // 启动会话清理定时器
      _startCleanupTimer();

      // 启动历史记录定时器
      _startHistoryTimer();

      return true;
    } catch (e) {
      _logger.error('NSFX-HTTP', 'Failed to start HTTP server: $e');
      return false;
    }
  }

  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _historyTimer?.cancel();
    _activeSessions.clear();
    _pendingPopups.clear();
    _recentPopupSignatures.clear();
    _deviceFingerprints.clear();
    _sessionToFingerprint.clear();
    _onlineHistory.clear();
    _lastLoggedUniqueDeviceCount = null;
    _lastLoggedSessionCount = null;
    _lastLoggedFingerprintMappingCount = null;
    // 不清空 _allDevices，保留历史记录

    for (final server in _compatibilityServers) {
      await server.close(force: true);
    }
    _compatibilityServers.clear();
    await _primaryServer?.close(force: true);
    _primaryServer = null;
    _isRunning = false;
    _logger.info('NSFX-HTTP', 'HTTP server stopped');
  }

  Future<void> _bindCompatibilityServers() async {
    for (final compatibilityPort in compatibilityPorts) {
      try {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          compatibilityPort,
        );
        server.listen(_handleRequest);
        _compatibilityServers.add(server);
        _logger.info(
          'NSFX-HTTP',
          'HTTP compatibility bridge started on port $compatibilityPort',
        );
      } catch (error) {
        _logger.warning(
          'NSFX-HTTP',
          'Failed to start compatibility bridge on port $compatibilityPort: $error',
        );
      }
    }
  }

  void _handleRequest(HttpRequest request) async {
    // CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers
        .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers
        .add('Access-Control-Allow-Headers', 'Content-Type');
    request.response.headers.contentType = ContentType.json;

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    // 只记录非轮询请求的日志
    if (!_isPollingPath(path)) {
      _logger.debug('NSFX-HTTP', '${request.method} $path');
    }

    try {
      switch (path) {
        case '/health':
          await _handleHealth(request);
          break;
        case '/download/add':
          await _handleAddDownload(request);
          break;
        case '/download/pending-popup':
          await _handlePendingPopup(request);
          break;
        case '/download/tasks':
          await _handleGetTasks(request);
          break;
        case '/download/statistics':
          await _handleGetStatistics(request);
          break;
        case '/download/pause':
          await _handlePause(request);
          break;
        case '/download/resume':
          await _handleResume(request);
          break;
        case '/download/cancel':
          await _handleCancel(request);
          break;
        case '/settings/download-config':
          if (request.method == 'GET') {
            await _handleGetConfig(request);
          } else {
            await _handleSetConfig(request);
          }
          break;
        case '/settings/download-dir':
          if (request.method == 'GET') {
            await _handleGetDownloadDir(request);
          } else {
            await _handleSetDownloadDir(request);
          }
          break;
        case '/stats/heartbeat':
          await _handleHeartbeat(request);
          break;
        case '/stats/offline':
          await _handleOffline(request);
          break;
        case '/stats/online':
          await _handleGetOnlineStats(request);
          break;
        default:
          _logger.warning('NSFX-HTTP', 'Unknown path: $path');
          _sendError(request, 404, 'Not found');
      }
    } catch (e) {
      _logger.error('NSFX-HTTP', 'Error handling $path: $e');
      _sendError(request, 500, e.toString());
    }
  }

  Future<void> _handleHealth(HttpRequest request) async {
    final clientConfig = ClientConfigService();
    final languagePreference = clientConfig.getLanguagePreference();
    final localeTag = _resolveExtensionLocaleTag(languagePreference);

    _sendJson(request, {
      'status': 'ok',
      'version': '2.0.0',
      'kernel': _kernel.name,
      'running': _kernel.isRunning,
      'language_preference': languagePreference,
      'locale': localeTag,
      'browser_download_handling_mode':
          clientConfig.getBrowserDownloadHandlingMode(),
      'browser_download_small_file_threshold':
          clientConfig.getBrowserDownloadSmallFileThreshold(),
    });
  }

  String _resolveExtensionLocaleTag(String preference) {
    final normalized = preference.trim().toLowerCase().replaceAll('-', '_');
    if (normalized.startsWith('zh')) {
      return 'zh';
    }
    if (normalized.startsWith('en')) {
      return 'en';
    }

    final systemLocale = Platform.localeName.toLowerCase().replaceAll('-', '_');
    if (systemLocale.startsWith('zh')) {
      return 'zh';
    }

    return 'en';
  }

  Future<void> _handleAddDownload(HttpRequest request) async {
    final body = await _readBody(request);

    final url = body['url'] as String?;
    final filename = body['filename'] as String?;

    if (url == null || filename == null) {
      _sendError(request, 400, 'Missing url or filename');
      return;
    }

    _logger.info('NSFX-HTTP', 'Add download request: $filename');

    final popupRequest = <String, dynamic>{
      'url': url,
      'filename': filename,
      'referer': body['referer'],
      'user_agent': body['userAgent'] ?? body['user_agent'],
      'cookies': body['cookies'],
      'headers': body['headers'],
      'save_dir': body['save_dir'] ?? body['saveDir'],
      'file_size': _readPositiveInt(
        body,
        const ['file_size', 'fileSize', 'total_bytes', 'totalBytes'],
      ),
      'mime': body['mime'],
      'danger': body['danger'],
      'browser': body['browser'],
      'from_browser': body['from_browser'],
      'timestamp': DateTime.now().toIso8601String(),
    };
    final popupSignature = _popupSignatureFor(popupRequest);
    _cleanupExpiredPopupSignatures();

    final hasQueuedDuplicate = _pendingPopups.any(
      (candidate) => _popupSignatureFor(candidate) == popupSignature,
    );
    final recentDuplicateUntil = _recentPopupSignatures[popupSignature];
    if (hasQueuedDuplicate ||
        (recentDuplicateUntil != null &&
            recentDuplicateUntil.isAfter(DateTime.now()))) {
      _logger.warning(
        'NSFX-HTTP',
        'Suppress duplicate browser download request: $filename',
      );
      _sendJson(request, {
        'success': true,
        'message': 'Duplicate browser download request suppressed',
        'handoff_action': 'duplicate_suppressed',
      });
      return;
    }

    final clientConfig = ClientConfigService();
    final handlingMode = clientConfig.getBrowserDownloadHandlingMode();
    final fileSize = popupRequest['file_size'] as int?;
    final unsafeBrowserDanger = _hasUnsafeBrowserDanger(body['danger']);
    final shouldAcceptSilently =
        ClientConfigService.shouldSilentlyAcceptBrowserDownload(
      mode: handlingMode,
      fileSizeBytes: fileSize,
      smallFileThresholdBytes:
          clientConfig.getBrowserDownloadSmallFileThreshold(),
      hasUnsafeBrowserDanger: unsafeBrowserDanger,
    );

    if (shouldAcceptSilently) {
      _recentPopupSignatures[popupSignature] =
          DateTime.now().add(_popupDedupWindow);
      await _acceptDownloadDirectly(
        request,
        popupRequest,
        mode: handlingMode,
      );
      return;
    }

    // 添加到待确认队列，由主程序拉起下载对话框处理
    _pendingPopups.add(popupRequest);
    _recentPopupSignatures[popupSignature] =
        DateTime.now().add(_popupDedupWindow);

    _logger.info(
        'NSFX-HTTP', 'Download queued for main-window confirmation: $filename');
    _sendJson(request, {
      'success': true,
      'message': 'Queued for main-window confirmation',
      'handoff_action': 'show_popup',
    });
  }

  Future<void> _handlePendingPopup(HttpRequest request) async {
    _cleanupExpiredPopupSignatures();
    if (_pendingPopups.isEmpty) {
      _sendJson(request, {'success': true, 'data': null});
      return;
    }

    // 取出第一个待处理的下载
    final popup = _pendingPopups.removeAt(0);
    _logger.info('NSFX-HTTP',
        'Dispatching queued browser download: ${popup['filename']}');
    _sendJson(request, {'success': true, 'data': popup});
  }

  Future<void> _acceptDownloadDirectly(
    HttpRequest request,
    Map<String, dynamic> downloadData, {
    required String mode,
  }) async {
    final url = downloadData['url']?.toString() ?? '';
    final filename = downloadData['filename']?.toString() ?? '';
    if (url.isEmpty || filename.isEmpty) {
      _sendError(request, 400, 'Missing url or filename');
      return;
    }

    final headersRaw = downloadData['headers'];
    final headers = headersRaw is Map
        ? headersRaw.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          )
        : null;
    final clientConfig = ClientConfigService();
    final saveDir =
        (downloadData['save_dir'] ?? downloadData['saveDir'])?.toString();
    final taskId = await _kernel.addDownload(
      url,
      filename,
      referer: downloadData['referer']?.toString(),
      userAgent:
          (downloadData['user_agent'] ?? downloadData['userAgent'])?.toString(),
      cookies: downloadData['cookies']?.toString(),
      headers: headers,
      saveDir: (saveDir?.trim().isNotEmpty ?? false) ? saveDir!.trim() : null,
      startPaused: !clientConfig.getAutoStartDownload(),
    );

    if (taskId == null) {
      _sendError(request, 500, 'Failed to add download task');
      return;
    }

    _logger.info(
      'NSFX-HTTP',
      'Download accepted without popup: $filename (mode=$mode, task=$taskId)',
    );
    _sendJson(request, {
      'success': true,
      'message': 'Download accepted without popup',
      'handoff_action': 'silent_add',
      'task_id': taskId,
    });
  }

  void _cleanupExpiredPopupSignatures() {
    final now = DateTime.now();
    _recentPopupSignatures.removeWhere(
      (_, expiresAt) => !expiresAt.isAfter(now),
    );
  }

  String _popupSignatureFor(Map<String, dynamic> popupRequest) {
    final url = _normalizePopupSignatureField(popupRequest['url']);
    final filename = _normalizePopupSignatureField(popupRequest['filename']);
    final referer = _normalizePopupSignatureField(popupRequest['referer']);
    return '$url|$filename|$referer';
  }

  String _normalizePopupSignatureField(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return '';
    }

    try {
      final parsed = Uri.parse(text);
      if (!parsed.hasScheme || !parsed.hasAuthority) {
        return text;
      }
      return parsed.removeFragment().toString();
    } catch (_) {
      return text;
    }
  }

  int? _readPositiveInt(
    Map<String, dynamic> data,
    Iterable<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      final parsed = value is num ? value.toInt() : int.tryParse('$value');
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  bool _hasUnsafeBrowserDanger(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty ||
        text == 'safe' ||
        text == 'accepted' ||
        text == 'allowlistedbypolicy') {
      return false;
    }
    return true;
  }

  Future<void> _handleGetTasks(HttpRequest request) async {
    final tasks = await _kernel.getTasks();
    _sendJson(request, {
      'success': true,
      'data': tasks.map(_taskToJson).toList(),
    });
  }

  Future<void> _handleGetStatistics(HttpRequest request) async {
    final stats = await _kernel.getStatistics();
    final tasks = await _kernel.getTasks();

    // 统计各状态的任务数
    int completedCount = 0;
    int failedCount = 0;

    for (final task in tasks) {
      if (task.status == DownloadStatus.completed) {
        completedCount++;
      } else if (task.status == DownloadStatus.failed) {
        failedCount++;
      }
    }

    _sendJson(request, {
      'success': true,
      'data': stats != null
          ? {
              'total_downloads': stats.totalTasks,
              'active_tasks': stats.activeDownloads,
              'completed_tasks': completedCount,
              'failed_tasks': failedCount,
              'total_downloaded_bytes': stats.totalDownloaded,
              'total_speed': stats.totalSpeed,
            }
          : null,
    });
  }

  Future<void> _handlePause(HttpRequest request) async {
    final body = await _readBody(request);
    final taskId = body['task_id'] as String?;

    if (taskId == null) {
      _sendError(request, 400, 'Missing task_id');
      return;
    }

    _logger.info('NSFX-HTTP', 'Pause task: $taskId');
    final success = await _kernel.pauseDownload(taskId);
    _sendJson(request, {'success': success});
  }

  Future<void> _handleResume(HttpRequest request) async {
    final body = await _readBody(request);
    final taskId = body['task_id'] as String?;

    if (taskId == null) {
      _sendError(request, 400, 'Missing task_id');
      return;
    }

    _logger.info('NSFX-HTTP', 'Resume task: $taskId');
    final success = await _kernel.resumeDownload(taskId);
    _sendJson(request, {'success': success});
  }

  Future<void> _handleCancel(HttpRequest request) async {
    final body = await _readBody(request);
    final taskId = body['task_id'] as String?;

    if (taskId == null) {
      _sendError(request, 400, 'Missing task_id');
      return;
    }

    _logger.info('NSFX-HTTP', 'Cancel task: $taskId');
    final success = await _kernel.cancelDownload(taskId);
    _sendJson(request, {'success': success});
  }

  Future<void> _handleGetConfig(HttpRequest request) async {
    final config = await _kernel.getConfig();
    _sendJson(request, {
      'success': true,
      'data': config != null
          ? {
              'threads': config.threads,
              'segments': config.segments,
              'mode': config.mode,
              'max_concurrent_tasks': config.maxConcurrentTasks,
              'segment_speed_limit': config.segmentSpeedLimit,
              'global_speed_limit': config.globalSpeedLimit,
              'enable_dynamic_segments': config.enableDynamicSegments,
              'conflict_strategy': config.conflictStrategy,
              'default_user_agent': config.defaultUserAgent,
              'http_version_policy': config.httpVersionPolicy,
              'proxy': config.proxy != null
                  ? {
                      'enabled': config.proxy!.enabled,
                      'type': config.proxy!.type,
                      'host': config.proxy!.host,
                      'port': config.proxy!.port,
                      'username': config.proxy!.username,
                      'password': config.proxy!.password,
                      'requires_auth': config.proxy!.requiresAuth,
                    }
                  : null,
            }
          : null,
    });
  }

  Future<void> _handleSetConfig(HttpRequest request) async {
    final body = await _readBody(request);
    _logger.info('NSFX-HTTP', 'Update config');

    final current = await _kernel.getConfig();

    ProxyConfig? proxy;
    if (body['proxy'] != null) {
      final p = body['proxy'] as Map<String, dynamic>;
      proxy = ProxyConfig(
        enabled: p['enabled'] ?? false,
        type: p['type'] ?? 'http',
        host: p['host'] ?? '',
        port: p['port'] ?? 7897,
        username: p['username'],
        password: p['password'],
        requiresAuth: p['requires_auth'] ?? false,
      );
    } else {
      proxy = current?.proxy;
    }

    final config = DownloadConfig(
      threads: body['threads'] ?? current?.threads ?? 8,
      segments: body['segments'] ?? current?.segments ?? 8,
      mode: body['mode'] ?? current?.mode ?? 'auto',
      maxConcurrentTasks:
          body['max_concurrent_tasks'] ?? current?.maxConcurrentTasks ?? 3,
      segmentSpeedLimit:
          body['segment_speed_limit'] ?? current?.segmentSpeedLimit ?? 0,
      globalSpeedLimit:
          body['global_speed_limit'] ?? current?.globalSpeedLimit ?? 0,
      enableDynamicSegments: body['enable_dynamic_segments'] ??
          current?.enableDynamicSegments ??
          true,
      conflictStrategy:
          body['conflict_strategy'] ?? current?.conflictStrategy ?? 'increment',
      defaultUserAgent: (body['default_user_agent'] ??
              current?.defaultUserAgent ??
              DownloadConfig.defaultUserAgentFallback)
          .toString(),
      httpVersionPolicy:
          (body['http_version_policy'] ?? current?.httpVersionPolicy ?? 'auto')
              .toString(),
      proxy: proxy,
    );

    final success = await _kernel.setConfig(config);
    _sendJson(request, {'success': success});
  }

  Future<void> _handleGetDownloadDir(HttpRequest request) async {
    final dir = await _kernel.getDownloadDir();
    _sendJson(request, {'success': true, 'data': dir});
  }

  Future<void> _handleSetDownloadDir(HttpRequest request) async {
    final body = await _readBody(request);
    final path = body['path'] as String?;

    if (path == null) {
      _sendError(request, 400, 'Missing path');
      return;
    }

    _logger.info('NSFX-HTTP', 'Set download dir: $path');
    final success = await _kernel.setDownloadDir(path);
    _sendJson(request, {'success': success});
  }

  // ========== 在线统计相关处理 ==========

  /// 启动会话清理定时器
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _cleanupExpiredSessions();
    });
  }

  /// 启动历史记录定时器
  void _startHistoryTimer() {
    _historyTimer = Timer.periodic(_historyInterval, (_) {
      _recordOnlineHistory();
    });
  }

  /// 清理过期会话
  void _cleanupExpiredSessions() {
    final now = DateTime.now();
    final expiredSessions = <String>[];

    _activeSessions.forEach((sessionId, lastHeartbeat) {
      if (now.difference(lastHeartbeat) > _sessionTimeout) {
        expiredSessions.add(sessionId);
      }
    });

    for (final sessionId in expiredSessions) {
      _activeSessions.remove(sessionId);
      _sessionToFingerprint.remove(sessionId); // 同时清理指纹映射
      _logger.debug('NSFX-HTTP', 'Session expired: $sessionId');
    }

    if (expiredSessions.isNotEmpty) {
      _logger.info(
          'NSFX-HTTP', 'Cleaned up ${expiredSessions.length} expired sessions');
      _logUniqueDeviceStatsIfChanged();
    }
  }

  /// 记录在线历史
  void _recordOnlineHistory() {
    final now = DateTime.now();
    final uniqueDevices = _getUniqueDeviceCount(); // 使用唯一设备数而不是会话数

    _onlineHistory.add({
      'timestamp': now.toIso8601String(),
      'count': uniqueDevices, // 记录唯一设备数
    });

    // 保留最近100个数据点（约16分钟）
    if (_onlineHistory.length > 100) {
      _onlineHistory.removeAt(0);
    }
  }

  /// 处理心跳请求
  Future<void> _handleHeartbeat(HttpRequest request) async {
    final body = await _readBody(request);
    final sessionId = body['session_id'] as String?;
    final fingerprint = body['device_fingerprint'] as String?;
    final deviceInfo = body['device_info'] as Map<String, dynamic>?;

    if (sessionId == null) {
      _sendError(request, 400, 'Missing session_id');
      return;
    }

    // 更新会话最后活跃时间
    final isNewSession = !_activeSessions.containsKey(sessionId);
    _activeSessions[sessionId] = DateTime.now();

    // 处理设备指纹
    if (fingerprint != null) {
      _sessionToFingerprint[sessionId] = fingerprint;
      _logger.debug(
          'NSFX-HTTP', 'Mapped session $sessionId to fingerprint $fingerprint');

      // 更新设备信息
      if (!_deviceFingerprints.containsKey(fingerprint)) {
        final fingerprintShort =
            fingerprint.length >= 8 ? fingerprint.substring(0, 8) : fingerprint;

        _deviceFingerprints[fingerprint] = {
          'fingerprint': fingerprint,
          'fingerprint_short': fingerprintShort,
          'device_info': deviceInfo,
          'device_summary': _getDeviceSummary(deviceInfo),
          'first_seen': DateTime.now().toIso8601String(),
          'last_seen': DateTime.now().toIso8601String(),
          'session_count': 1,
        };

        // 添加到历史设备列表
        _allDevices.add({
          ..._deviceFingerprints[fingerprint]!,
          'added_at': DateTime.now().toIso8601String(),
        });

        _logger.info('NSFX-HTTP', 'New device registered: $fingerprintShort');
      } else {
        // 更新现有设备
        _deviceFingerprints[fingerprint]!['last_seen'] =
            DateTime.now().toIso8601String();
        _deviceFingerprints[fingerprint]!['session_count'] =
            (_deviceFingerprints[fingerprint]!['session_count'] as int) + 1;
      }
    }

    if (isNewSession) {
      _logger.info('NSFX-HTTP', 'New session: $sessionId');
    }

    // 计算唯一设备数（去重）
    final uniqueDevices = _getUniqueDeviceCount();
    _logUniqueDeviceStatsIfChanged(uniqueDevices: uniqueDevices);

    _sendJson(request, {
      'success': true,
      'data': {
        'online_users': _activeSessions.length,
        'unique_devices': uniqueDevices,
        'session_id': sessionId,
      },
    });
  }

  /// 获取唯一设备数量
  int _getUniqueDeviceCount() {
    final activeFingerprints = <String>{};

    for (final sessionId in _activeSessions.keys) {
      final fingerprint = _sessionToFingerprint[sessionId];
      if (fingerprint != null) {
        activeFingerprints.add(fingerprint);
      }
    }

    return activeFingerprints.length;
  }

  void _logUniqueDeviceStatsIfChanged({int? uniqueDevices}) {
    final currentUniqueDevices = uniqueDevices ?? _getUniqueDeviceCount();
    final currentSessionCount = _activeSessions.length;
    final currentMappingCount = _sessionToFingerprint.length;

    if (_lastLoggedUniqueDeviceCount == currentUniqueDevices &&
        _lastLoggedSessionCount == currentSessionCount &&
        _lastLoggedFingerprintMappingCount == currentMappingCount) {
      return;
    }

    _lastLoggedUniqueDeviceCount = currentUniqueDevices;
    _lastLoggedSessionCount = currentSessionCount;
    _lastLoggedFingerprintMappingCount = currentMappingCount;

    _logger.debug('NSFX-HTTP',
        'Unique devices: $currentUniqueDevices (sessions: $currentSessionCount, mappings: $currentMappingCount)');
  }

  bool _isPollingPath(String path) {
    switch (path) {
      case '/download/pending-popup':
      case '/download/tasks':
      case '/download/statistics':
      case '/health':
      case '/stats/heartbeat':
      case '/stats/online':
        return true;
      default:
        return false;
    }
  }

  /// 获取设备摘要信息
  String _getDeviceSummary(Map<String, dynamic>? deviceInfo) {
    if (deviceInfo == null) return 'Unknown Device';

    final browser = deviceInfo['browser'] ?? 'Unknown';
    final os = deviceInfo['os'] ?? 'Unknown';
    final deviceType = deviceInfo['deviceType'] ?? 'Unknown';

    return '$browser on $os ($deviceType)';
  }

  /// 处理下线请求
  Future<void> _handleOffline(HttpRequest request) async {
    final body = await _readBody(request);
    final sessionId = body['session_id'] as String?;

    if (sessionId == null) {
      _sendError(request, 400, 'Missing session_id');
      return;
    }

    _activeSessions.remove(sessionId);
    _sessionToFingerprint.remove(sessionId);
    _logger.info('NSFX-HTTP', 'Session offline: $sessionId');
    _logUniqueDeviceStatsIfChanged();

    _sendJson(request, {
      'success': true,
      'data': {
        'online_users': _activeSessions.length,
        'unique_devices': _getUniqueDeviceCount(),
      },
    });
  }

  /// 获取在线统计数据
  Future<void> _handleGetOnlineStats(HttpRequest request) async {
    final uniqueDevices = _getUniqueDeviceCount();

    // 获取活跃设备列表
    final activeDevices = <Map<String, dynamic>>[];
    final activeFingerprints = <String>{};

    for (final sessionId in _activeSessions.keys) {
      final fingerprint = _sessionToFingerprint[sessionId];
      if (fingerprint != null && !activeFingerprints.contains(fingerprint)) {
        activeFingerprints.add(fingerprint);
        final deviceData = _deviceFingerprints[fingerprint];
        if (deviceData != null) {
          activeDevices.add(deviceData);
        }
      }
    }

    // 计算平均会话时间（简化版）
    final avgSessionTime = _activeSessions.isEmpty ? 0 : 5.0; // 简化计算

    _sendJson(request, {
      'success': true,
      'data': {
        'current_online': _activeSessions.length,
        'unique_devices': uniqueDevices,
        'avg_session_time': avgSessionTime,
        'history': _onlineHistory,
        'active_sessions': _activeSessions.length,
        'devices': activeDevices,
        'total_devices_ever': _allDevices.length,
      },
    });
  }

  Map<String, dynamic> _taskToJson(DownloadTask task) {
    return {
      'id': task.id,
      'url': task.url,
      'filename': task.filename,
      'filepath': task.filepath,
      'status': task.status.name,
      'totalSize': task.totalSize,
      'downloadedSize': task.downloadedSize,
      'speed': task.speed,
      'progress': task.progress,
      'eta': task.eta,
      'errorMessage': task.errorMessage,
      'threadCount': task.threadCount,
      'peakSpeed': task.peakSpeed,
      'averageSpeed': task.averageSpeed,
      'startTime': task.startTime?.toIso8601String(),
      'endTime': task.endTime?.toIso8601String(),
      'segments': task.segments
          .map((s) => {
                'index': s.index,
                'startByte': s.startByte,
                'endByte': s.endByte,
                'downloadedBytes': s.downloadedBytes,
                'speed': s.speed,
                'status': s.status,
                'retryCount': s.retryCount,
                'progress': s.progress,
              })
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _readBody(HttpRequest request) async {
    try {
      final content = await utf8.decoder.bind(request).join();
      if (content.isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void _sendJson(HttpRequest request, Map<String, dynamic> data) {
    request.response.statusCode = 200;
    final enriched = <String, dynamic>{...data};
    final connectedPort = request.connectionInfo?.localPort ?? port;

    enriched.putIfAbsent('api_port', () => port);
    enriched.putIfAbsent('connected_port', () => connectedPort);
    enriched.putIfAbsent(
      'requires_port_switch',
      () => connectedPort != port,
    );
    enriched.putIfAbsent('service_host', () => '127.0.0.1:$port');

    request.response.write(jsonEncode(enriched));
    request.response.close();
  }

  void _sendError(HttpRequest request, int code, String message) {
    request.response.statusCode = code;
    request.response.write(jsonEncode({'success': false, 'error': message}));
    request.response.close();
  }
}
