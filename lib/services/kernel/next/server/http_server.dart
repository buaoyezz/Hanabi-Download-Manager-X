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

  bool get isRunning => _isRunning;

  NsfxHttpServer(this._kernel, {this.port = 9710});

  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _isRunning = true;
      _logger.info('NSFX-HTTP', 'HTTP server started on port $port');

      _server!.listen(_handleRequest);
      return true;
    } catch (e) {
      _logger.error('NSFX-HTTP', 'Failed to start HTTP server: $e');
      return false;
    }
  }

  Future<void> stop() async {
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
    _sendJson(request, {
      'success': true,
      'data': stats != null ? {
        'total_downloads': stats.totalTasks,
        'active_tasks': stats.activeDownloads,
        'completed_tasks': 0,
        'failed_tasks': 0,
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
