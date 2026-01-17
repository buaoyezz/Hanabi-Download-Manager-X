import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../nsfx_kernel.dart';
import '../../kernel_interface.dart';
import '../../../app_logger_service.dart';

class NsfxHttpServer {
  HttpServer? _server;
  final NsfxKernel _kernel;
  final int port;
  bool _isRunning = false;
  final _logger = AppLoggerService();
  
  // 待弹窗的下载请求队列
  final List<Map<String, dynamic>> _pendingPopups = [];
  
  // 在线用户统计
  final Map<String, DateTime> _activeSessions = {};
  final Map<String, Map<String, dynamic>> _deviceFingerprints = {}; // fingerprint -> device info
  final Map<String, String> _sessionToFingerprint = {}; // session_id -> fingerprint
  final List<Map<String, dynamic>> _onlineHistory = [];
  final List<Map<String, dynamic>> _allDevices = []; // 所有历史设备
  Timer? _cleanupTimer;
  Timer? _historyTimer;
  static const Duration _sessionTimeout = Duration(minutes: 2);
  static const Duration _historyInterval = Duration(seconds: 10);

  bool get isRunning => _isRunning;

  NsfxHttpServer(this._kernel, {this.port = 9710});

  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _isRunning = true;
      _logger.info('NSFX-HTTP', 'HTTP server started on port $port');

      _server!.listen(_handleRequest);
      
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
    _deviceFingerprints.clear();
    _sessionToFingerprint.clear();
    _onlineHistory.clear();
    // 不清空 _allDevices，保留历史记录
    
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _logger.info('NSFX-HTTP', 'HTTP server stopped');
  }

  void _handleRequest(HttpRequest request) async {
    // CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
    request.response.headers.contentType = ContentType.json;

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    
    // 只记录非轮询请求的日志
    if (path != '/download/pending-popup' && path != '/health') {
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
    _sendJson(request, {
      'status': 'ok',
      'version': '2.0.0',
      'kernel': _kernel.name,
      'running': _kernel.isRunning,
    });
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
    
    // 添加到待弹窗队列（让客户端弹窗确认）
    _pendingPopups.add({
      'url': url,
      'filename': filename,
      'referer': body['referer'],
      'user_agent': body['userAgent'] ?? body['user_agent'],
      'cookies': body['cookies'],
      'headers': body['headers'],
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _logger.info('NSFX-HTTP', 'Download added to popup queue: $filename');
    _sendJson(request, {'success': true, 'message': 'Added to popup queue'});
  }

  Future<void> _handlePendingPopup(HttpRequest request) async {
    if (_pendingPopups.isEmpty) {
      _sendJson(request, {'success': true, 'data': null});
      return;
    }

    // 取出第一个待处理的下载
    final popup = _pendingPopups.removeAt(0);
    _logger.info('NSFX-HTTP', 'Sending popup for: ${popup['filename']}');
    _sendJson(request, {'success': true, 'data': popup});
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
    
    if (tasks != null) {
      for (final task in tasks) {
        if (task.status == 'completed') {
          completedCount++;
        } else if (task.status == 'failed' || task.status == 'error') {
          failedCount++;
        }
      }
    }
    
    _sendJson(request, {
      'success': true,
      'data': stats != null ? {
        'total_downloads': stats.totalTasks,
        'active_tasks': stats.activeDownloads,
        'completed_tasks': completedCount,
        'failed_tasks': failedCount,
        'total_downloaded_bytes': stats.totalDownloaded,
        'total_speed': stats.totalSpeed,
      } : null,
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
      'data': config != null ? {
        'threads': config.threads,
        'segments': config.segments,
        'mode': config.mode,
        'max_concurrent_tasks': config.maxConcurrentTasks,
        'segment_speed_limit': config.segmentSpeedLimit,
        'proxy': config.proxy != null ? {
          'enabled': config.proxy!.enabled,
          'type': config.proxy!.type,
          'host': config.proxy!.host,
          'port': config.proxy!.port,
          'username': config.proxy!.username,
          'password': config.proxy!.password,
          'requires_auth': config.proxy!.requiresAuth,
        } : null,
      } : null,
    });
  }

  Future<void> _handleSetConfig(HttpRequest request) async {
    final body = await _readBody(request);
    _logger.info('NSFX-HTTP', 'Update config');
    
    ProxyConfig? proxy;
    if (body['proxy'] != null) {
      final p = body['proxy'] as Map<String, dynamic>;
      proxy = ProxyConfig(
        enabled: p['enabled'] ?? false,
        type: p['type'] ?? 'http',
        host: p['host'] ?? '',
        port: p['port'] ?? 8080,
        username: p['username'],
        password: p['password'],
        requiresAuth: p['requires_auth'] ?? false,
      );
    }

    final config = DownloadConfig(
      threads: body['threads'] ?? 8,
      segments: body['segments'] ?? 8,
      mode: body['mode'] ?? 'auto',
      maxConcurrentTasks: body['max_concurrent_tasks'] ?? 3,
      segmentSpeedLimit: body['segment_speed_limit'] ?? 0,
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
      _logger.info('NSFX-HTTP', 'Cleaned up ${expiredSessions.length} expired sessions');
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
      _logger.debug('NSFX-HTTP', 'Mapped session $sessionId to fingerprint $fingerprint');
      
      // 更新设备信息
      if (!_deviceFingerprints.containsKey(fingerprint)) {
        final fingerprintShort = fingerprint.length >= 8 
            ? fingerprint.substring(0, 8) 
            : fingerprint;
        
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
        _deviceFingerprints[fingerprint]!['last_seen'] = DateTime.now().toIso8601String();
        _deviceFingerprints[fingerprint]!['session_count'] = 
            (_deviceFingerprints[fingerprint]!['session_count'] as int) + 1;
      }
    }
    
    if (isNewSession) {
      _logger.info('NSFX-HTTP', 'New session: $sessionId');
    }
    
    // 计算唯一设备数（去重）
    final uniqueDevices = _getUniqueDeviceCount();
    
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
    
    _logger.debug('NSFX-HTTP', 'Unique devices: ${activeFingerprints.length} (sessions: ${_activeSessions.length}, mappings: ${_sessionToFingerprint.length})');
    
    return activeFingerprints.length;
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
      'total_size': task.totalSize,
      'downloaded_size': task.downloadedSize,
      'speed': task.speed,
      'progress': task.progress,
      'eta': task.eta,
      'error_message': task.errorMessage,
      'thread_count': task.threadCount,
      'peak_speed': task.peakSpeed,
      'average_speed': task.averageSpeed,
      'start_time': task.startTime?.toIso8601String(),
      'end_time': task.endTime?.toIso8601String(),
      'segments': task.segments?.map((s) => {
        'index': s.index,
        'start_byte': s.startByte,
        'end_byte': s.endByte,
        'downloaded_bytes': s.downloadedBytes,
        'speed': s.speed,
        'status': s.status,
        'retry_count': s.retryCount,
        'progress': s.progress,
      }).toList(),
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
    request.response.write(jsonEncode(data));
    request.response.close();
  }

  void _sendError(HttpRequest request, int code, String message) {
    request.response.statusCode = code;
    request.response.write(jsonEncode({'success': false, 'error': message}));
    request.response.close();
  }
}
