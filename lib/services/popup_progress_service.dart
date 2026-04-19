import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/download_task.dart';
import 'integrated_download_service.dart';
import 'logger_service.dart';

/// 下载进度数据，用于推送给弹窗
class DownloadProgressData {
  final String taskId;
  final String filename;
  final String status;
  final double progress;
  final int downloadedSize;
  final int totalSize;
  final int speed;
  final int remainingSeconds;
  final List<SegmentProgressData> segments;
  final String? error;

  DownloadProgressData({
    required this.taskId,
    required this.filename,
    required this.status,
    required this.progress,
    required this.downloadedSize,
    required this.totalSize,
    required this.speed,
    required this.remainingSeconds,
    required this.segments,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'task_id': taskId,
        'filename': filename,
        'status': status,
        'progress': progress,
        'downloaded_size': downloadedSize,
        'total_size': totalSize,
        'speed': speed,
        'remaining_seconds': remainingSeconds,
        'segments': segments.map((s) => s.toJson()).toList(),
        'error': error,
      };
}

class SegmentProgressData {
  final int index;
  final double progress;
  final String status;

  SegmentProgressData({
    required this.index,
    required this.progress,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'progress': progress,
        'status': status,
      };
}

/// 弹窗进度推送服务
/// 通过 HTTP Server + WebSocket 向弹窗推送下载进度
class PopupProgressService {
  static final _logger = LoggerService();
  static const int _port = 19998;

  HttpServer? _server;
  final Set<WebSocket> _clients = {};
  final IntegratedDownloadService _downloadService;
  Timer? _broadcastTimer;
  String? _activeTaskId;

  PopupProgressService(this._downloadService);

  /// 启动进度推送服务
  Future<void> start() async {
    if (_server != null) {
      _logger.info('PopupProgressService already running');
      return;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
      _logger.info('PopupProgressService started on port $_port');

      _server!.listen(_handleRequest);

      // 定时广播进度 (200ms 间隔)
      _broadcastTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        _broadcastProgress();
      });
    } catch (e) {
      _logger.error('Failed to start PopupProgressService: $e');
    }
  }

  /// 停止服务
  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();

    await _server?.close();
    _server = null;
    _logger.info('PopupProgressService stopped');
  }

  /// 设置当前活动的任务ID（弹窗正在显示的任务）
  void setActiveTask(String? taskId) {
    _activeTaskId = taskId;
    _logger.debug('Active task set to: $taskId');
  }

  void _handleRequest(HttpRequest request) async {
    _logger.debug('PopupProgressService request: ${request.uri.path}');

    // CORS headers for standalone popup clients
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers
        .add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers
        .add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    // 处理 WebSocket 升级请求
    if (request.uri.path == '/ws/progress') {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        _clients.add(socket);
        _logger.info('WebSocket client connected, total: ${_clients.length}');

        socket.listen(
          (data) => _handleMessage(socket, data),
          onDone: () {
            _clients.remove(socket);
            _logger.info(
                'WebSocket client disconnected, total: ${_clients.length}');
          },
          onError: (e) {
            _clients.remove(socket);
            _logger.error('WebSocket error: $e');
          },
        );

        // 立即发送当前进度
        _sendProgressToClient(socket);
      } catch (e) {
        _logger.error('WebSocket upgrade failed: $e');
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
      return;
    }

    // 处理 HTTP 轮询请求
    if (request.uri.path == '/api/progress' && request.method == 'GET') {
      final taskId = request.uri.queryParameters['task_id'] ?? _activeTaskId;
      final progress = _getProgressData(taskId);

      request.response.headers.contentType = ContentType.json;
      request.response
          .write(jsonEncode(progress?.toJson() ?? {'error': 'No active task'}));
      await request.response.close();
      return;
    }

    // 处理订阅请求
    if (request.uri.path == '/api/subscribe' && request.method == 'POST') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final taskId = json['task_id'] as String?;

        if (taskId != null) {
          setActiveTask(taskId);
          request.response.headers.contentType = ContentType.json;
          request.response
              .write(jsonEncode({'success': true, 'task_id': taskId}));
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(jsonEncode({'error': 'task_id required'}));
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': e.toString()}));
      }
      await request.response.close();
      return;
    }

    // 获取所有任务列表
    if (request.uri.path == '/api/tasks' && request.method == 'GET') {
      final tasks =
          _downloadService.tasks.map((t) => _convertTask(t).toJson()).toList();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'tasks': tasks}));
      await request.response.close();
      return;
    }

    // 添加下载任务 (HTTP fallback for Named Pipe)
    if (request.uri.path == '/api/download' && request.method == 'POST') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final url = json['url'] as String?;
        final filename = json['filename'] as String?;
        final savePath = json['save_path']?.toString().trim();
        final referer = json['referer']?.toString();
        final userAgent = (json['user_agent'] ?? json['userAgent'])?.toString();
        final cookies = json['cookies']?.toString();
        final headersRaw = json['headers'];
        final headers = headersRaw is Map
            ? headersRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : null;

        if (url != null && filename != null) {
          _logger.info('Received download request via HTTP: $filename');
          final taskId = await _downloadService.addTask(
            url,
            filename,
            referer: referer,
            userAgent: userAgent,
            cookies: cookies,
            headers: headers,
            saveDir: (savePath?.isNotEmpty ?? false) ? savePath : null,
          );
          if (taskId == null) {
            throw StateError('Failed to add download task');
          }
          setActiveTask(taskId);

          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'success': true,
            'message': 'Download task added',
            'task_id': taskId,
            'filename': filename,
          }));
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response
              .write(jsonEncode({'error': 'url and filename required'}));
        }
      } catch (e) {
        _logger.error('Failed to add download task: $e');
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
      }
      await request.response.close();
      return;
    }

    if (request.uri.path == '/api/log' && request.method == 'POST') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final level = json['level']?.toString().trim().toLowerCase() ?? 'info';
        final source = json['source']?.toString().trim().isNotEmpty == true
            ? json['source']!.toString().trim()
            : 'PopupWindow';
        final message = json['message']?.toString().trim() ?? '';

        if (message.isEmpty) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(jsonEncode({'error': 'message required'}));
        } else {
          switch (level) {
            case 'debug':
              _logger.debug(message, source: source);
              break;
            case 'warning':
            case 'warn':
              _logger.warning(message, source: source);
              break;
            case 'error':
              _logger.error(message, source: source);
              break;
            default:
              _logger.info(message, source: source);
              break;
          }

          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'success': true}));
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': e.toString()}));
      }
      await request.response.close();
      return;
    }

    // 暂停任务
    if (request.uri.path == '/api/pause' && request.method == 'POST') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final taskId = json['task_id'] as String? ?? _activeTaskId;

        if (taskId != null) {
          await _downloadService.pauseTask(taskId);
          request.response.headers.contentType = ContentType.json;
          request.response
              .write(jsonEncode({'success': true, 'task_id': taskId}));
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(jsonEncode({'error': 'No active task'}));
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
      }
      await request.response.close();
      return;
    }

    // 继续任务
    if (request.uri.path == '/api/resume' && request.method == 'POST') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final taskId = json['task_id'] as String? ?? _activeTaskId;

        if (taskId != null) {
          await _downloadService.resumeTask(taskId);
          request.response.headers.contentType = ContentType.json;
          request.response
              .write(jsonEncode({'success': true, 'task_id': taskId}));
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.write(jsonEncode({'error': 'No active task'}));
        }
      } catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
      }
      await request.response.close();
      return;
    }

    // 404
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  void _handleMessage(WebSocket socket, dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'subscribe') {
        final taskId = json['task_id'] as String?;
        if (taskId != null) {
          setActiveTask(taskId);
          _sendProgressToClient(socket);
        }
      }
    } catch (e) {
      _logger.error('Failed to handle WebSocket message: $e');
    }
  }

  void _broadcastProgress() {
    if (_clients.isEmpty) return;

    final progress = _getProgressData(_activeTaskId);
    if (progress == null) return;

    final json = jsonEncode({
      'type': 'progress',
      'data': progress.toJson(),
    });

    for (final client in _clients.toList()) {
      try {
        client.add(json);
      } catch (e) {
        _clients.remove(client);
      }
    }
  }

  void _sendProgressToClient(WebSocket socket) {
    final progress = _getProgressData(_activeTaskId);
    if (progress == null) return;

    try {
      socket.add(jsonEncode({
        'type': 'progress',
        'data': progress.toJson(),
      }));
    } catch (e) {
      _logger.error('Failed to send progress: $e');
    }
  }

  DownloadProgressData? _getProgressData(String? taskId) {
    final tasks = _downloadService.tasks;

    if (taskId == null || taskId.isEmpty) {
      // 如果没有指定任务，返回最新的下载中任务
      final activeTasks =
          tasks.where((t) => t.status == DownloadStatus.downloading).toList();
      if (activeTasks.isNotEmpty) {
        return _convertTask(activeTasks.first);
      }
      // 没有下载中的任务，返回最新任务
      if (tasks.isNotEmpty) {
        return _convertTask(tasks.last);
      }
      return null;
    }

    // 查找指定任务
    try {
      final task = tasks.firstWhere((t) => t.id == taskId);
      return _convertTask(task);
    } catch (e) {
      return null;
    }
  }

  DownloadProgressData _convertTask(DownloadTask task) {
    final totalSize = task.fileSize ?? 0;
    final downloadedSize = task.downloadedSize ?? 0;
    final rawSpeed = task.speed ?? 0;
    final safeSpeed = rawSpeed.isFinite && !rawSpeed.isNaN ? rawSpeed : 0.0;
    final speed = safeSpeed > 0 ? safeSpeed.round() : 0;
    final rawProgress = task.progress.isFinite && !task.progress.isNaN
        ? task.progress
        : 0.0;
    final progressPercent = (rawProgress * 100).clamp(0, 100).toDouble();

    final remainingBytes = (totalSize - downloadedSize).clamp(0, totalSize);
    final remainingSeconds = speed > 0 ? (remainingBytes / speed).round() : 0;

    // 转换分段信息
    final segments = task.segments
            ?.asMap()
            .entries
            .map((e) => SegmentProgressData(
                  index: e.key,
                  progress: e.value.progress,
                  status: e.value.status,
                ))
            .toList() ??
        [];

    return DownloadProgressData(
      taskId: task.id,
      filename: task.fileName,
      status: task.status.name,
      progress: progressPercent,
      downloadedSize: downloadedSize,
      totalSize: totalSize,
      speed: speed,
      remainingSeconds: remainingSeconds,
      segments: segments,
      error: task.error,
    );
  }
}
