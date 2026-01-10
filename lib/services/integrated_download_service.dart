import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_task.dart';
import 'kernel_service.dart';
import 'kernel/kernel_manager.dart';
import 'kernel/kernel_interface.dart' as kernel;
import 'client_config_service.dart';
import 'app_logger_service.dart';

class IntegratedDownloadService extends ChangeNotifier {
  final KernelService _kernelService;
  final _kernelManager = KernelManager();
  final _clientConfig = ClientConfigService();
  final _appLogger = AppLoggerService();
  final List<DownloadTask> _tasks = [];
  Timer? _pollTimer;
  
  // 节流控制，避免 Windows 消息队列溢出
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minNotifyInterval = Duration(milliseconds: 500);
  bool _pendingNotify = false;
  Timer? _notifyTimer;

  IntegratedDownloadService(this._kernelService) {
    _startPolling();
  }

  bool get _useNewKernel => _clientConfig.getBool('kernel.use_new_kernel', defaultValue: true);
  bool get isKernelRunning => _useNewKernel ? _kernelManager.isRunning : _kernelService.isRunning;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  void _startPolling() {
    // 降低轮询频率到 2 秒，减少 UI 更新压力
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _updateTasks();
    });
  }
  
  // 节流的 notifyListeners，避免 Windows 消息队列溢出
  void _throttledNotify() {
    final now = DateTime.now();
    if (now.difference(_lastNotify) >= _minNotifyInterval) {
      _lastNotify = now;
      notifyListeners();
      return;
    }
    
    // 如果距离上次通知太近，延迟通知
    if (_pendingNotify) return;
    _pendingNotify = true;
    
    _notifyTimer?.cancel();
    _notifyTimer = Timer(_minNotifyInterval, () {
      _pendingNotify = false;
      _lastNotify = DateTime.now();
      notifyListeners();
    });
  }

  Future<void> _updateTasks() async {
    if (!isKernelRunning) return;

    try {
      List<Map<String, dynamic>> kernelTasks;
      
      if (_useNewKernel) {
        // 使用新内核
        final tasks = await _kernelManager.getTasks();
        kernelTasks = tasks.map(_convertDownloadTaskToMap).toList();
      } else {
        // 使用旧内核
        kernelTasks = await _kernelService.getTasks();
      }
      
      for (var kernelTask in kernelTasks) {
        final existingIndex = _tasks.indexWhere((t) => t.id == kernelTask['id']);
        
        final newTask = _convertKernelTask(kernelTask);
        
        if (existingIndex != -1) {
          final oldTask = _tasks[existingIndex];
          
          // Log status changes (only when status actually changes)
          if (oldTask.status != newTask.status) {
            _appLogger.debug('App', 'Kernel task status: ${kernelTask['id']} -> ${kernelTask['status']}');
            _appLogger.info('App', 'Status change: ${newTask.fileName} from ${oldTask.status} to ${newTask.status}');
            switch (newTask.status) {
              case DownloadStatus.completed:
                _appLogger.info('App', 'Task completed: ${newTask.fileName}');
                break;
              case DownloadStatus.failed:
                _appLogger.error('App', 'Task failed: ${newTask.fileName}, Error: ${newTask.error ?? 'Unknown error'}');
                break;
              case DownloadStatus.paused:
                _appLogger.info('App', 'Task paused: ${newTask.fileName}');
                break;
              case DownloadStatus.downloading:
                _appLogger.info('App', 'Task downloading: ${newTask.fileName}');
                break;
              case DownloadStatus.pending:
                _appLogger.info('App', 'Task pending: ${newTask.fileName}');
                break;
              case DownloadStatus.merging:
                _appLogger.info('App', 'Task merging: ${newTask.fileName}');
                break;
            }
          }
          
          // Log progress updates for downloading tasks
          if (newTask.status == DownloadStatus.downloading && 
              oldTask.progress != newTask.progress) {
            _appLogger.debug('App', 'Download progress: ${newTask.fileName} - ${(newTask.progress * 100).toStringAsFixed(1)}% @ ${newTask.formattedSpeed}');
          }
          _tasks[existingIndex] = newTask;
        } else {
          _tasks.add(newTask);
          _appLogger.info('App', 'New task added: ${newTask.fileName} (${newTask.status})');
        }
      }
      
      _throttledNotify();
    } catch (e) {
      _appLogger.error('App', 'Failed to update tasks: $e');
    }
  }

  // 将新内核的 DownloadTask 转换为 Map
  Map<String, dynamic> _convertDownloadTaskToMap(kernel.DownloadTask task) {
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
      'errorMessage': task.errorMessage,
      'threadCount': task.threadCount,
      'peakSpeed': task.peakSpeed,
      'averageSpeed': task.averageSpeed,
      'startTime': task.startTime?.toIso8601String(),
      'endTime': task.endTime?.toIso8601String(),
      'segments': task.segments.map((s) => {
        'index': s.index,
        'startByte': s.startByte,
        'endByte': s.endByte,
        'downloadedBytes': s.downloadedBytes,
        'speed': s.speed,
        'status': s.status,
        'retryCount': s.retryCount,
      }).toList(),
    };
  }

  DownloadTask _convertKernelTask(Map<String, dynamic> kernelTask) {
    DownloadStatus status;
    switch (kernelTask['status']) {
      case 'pending':
        status = DownloadStatus.pending;
        break;
      case 'downloading':
        status = DownloadStatus.downloading;
        break;
      case 'paused':
        status = DownloadStatus.paused;
        break;
      case 'completed':
        status = DownloadStatus.completed;
        break;
      case 'failed':
        status = DownloadStatus.failed;
        break;
      case 'cancelled':
        status = DownloadStatus.failed;
        break;
      case 'merging':
        status = DownloadStatus.merging;
        break;
      default:
        status = DownloadStatus.pending;
    }

    // 解析分段信息（包含新字段）
    List<SegmentInfo>? segments;
    if (kernelTask['segments'] != null && kernelTask['segments'] is List) {
      try {
        final segmentsList = kernelTask['segments'] as List;
        segments = segmentsList.map((seg) {
          return SegmentInfo(
            index: (seg['index'] as num?)?.toInt() ?? 0,
            startByte: (seg['startByte'] as num?)?.toInt() ?? (seg['start_byte'] as num?)?.toInt() ?? 0,
            endByte: (seg['endByte'] as num?)?.toInt() ?? (seg['end_byte'] as num?)?.toInt() ?? 0,
            downloadedBytes: (seg['downloadedBytes'] as num?)?.toInt() ?? (seg['downloaded_bytes'] as num?)?.toInt() ?? 0,
            speed: (seg['speed'] as num?)?.toDouble() ?? 0.0,
            status: seg['status']?.toString() ?? 'pending',
            retryCount: (seg['retryCount'] as num?)?.toInt() ?? (seg['retry_count'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      } catch (e) {
        _appLogger.error('App', 'Failed to parse segments: $e');
        segments = null;
      }
    }

    // 计算剩余时间
    Duration? remainingTime;
    final totalSize = kernelTask['totalSize'];
    final downloadedSize = kernelTask['downloadedSize'];
    final speed = (kernelTask['speed'] ?? 0.0).toDouble();
    
    if (totalSize != null && downloadedSize != null && speed > 0) {
      final remainingBytes = totalSize - downloadedSize;
      if (remainingBytes > 0) {
        final remainingSeconds = (remainingBytes / speed).ceil();
        remainingTime = Duration(seconds: remainingSeconds);
      }
    }

    // 解析统计信息
    final peakSpeed = kernelTask['peakSpeed'] != null 
        ? (kernelTask['peakSpeed'] as num).toDouble() 
        : null;
    final averageSpeed = kernelTask['averageSpeed'] != null 
        ? (kernelTask['averageSpeed'] as num).toDouble() 
        : null;
    final threadCount = kernelTask['threadCount'] as int?;
    final segmentCount = segments?.length;
    final downloadCore = kernelTask['downloadCore'] as String? ?? 'NSF-X';
    
    // 解析时间
    DateTime? startTime;
    DateTime? endTime;
    try {
      if (kernelTask['startTime'] != null) {
        startTime = DateTime.parse(kernelTask['startTime']);
      }
      if (kernelTask['endTime'] != null) {
        endTime = DateTime.parse(kernelTask['endTime']);
      }
    } catch (e) {
      _appLogger.error('App', 'Failed to parse time: $e');
    }

    return DownloadTask(
      id: kernelTask['id'],
      url: kernelTask['url'],
      fileName: kernelTask['filename'],
      status: status,
      progress: (kernelTask['progress'] ?? 0.0) / 100.0,
      filePath: kernelTask['filepath'],
      error: kernelTask['errorMessage'],
      fileSize: kernelTask['totalSize'],
      downloadedSize: kernelTask['downloadedSize'],
      speed: speed,
      remainingTime: remainingTime,
      segments: segments,
      peakSpeed: peakSpeed,
      averageSpeed: averageSpeed,
      threadCount: threadCount,
      segmentCount: segmentCount,
      downloadCore: downloadCore,
      startTime: startTime,
      endTime: endTime,
    );
  }

  Future<void> addTask(
    String url, 
    String fileName, {
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
  }) async {
    if (!isKernelRunning) {
      _appLogger.error('App', 'Kernel not running');
      return;
    }

    _appLogger.info('App', 'Adding download task: $fileName (using ${_useNewKernel ? 'NSFX' : 'Legacy'} kernel)');
    if (referer != null || userAgent != null || cookies != null || headers != null) {
      _appLogger.info('App', 'With authentication headers');
    }
    
    String? taskId;
    if (_useNewKernel) {
      taskId = await _kernelManager.addDownload(
        url, 
        fileName,
        referer: referer,
        userAgent: userAgent,
        cookies: cookies,
        headers: headers,
      );
    } else {
      taskId = await _kernelService.addDownload(
        url, 
        fileName,
        referer: referer,
        userAgent: userAgent,
        cookies: cookies,
        headers: headers,
      );
    }
    
    if (taskId != null) {
      _appLogger.info('App', 'Task added successfully: $taskId - $fileName');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to add task: $fileName');
    }
  }

  Future<void> pauseTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id, orElse: () => _tasks.first);
    _appLogger.info('App', 'Pausing task: ${task.fileName} (ID: $id)');
    
    bool success;
    if (_useNewKernel) {
      success = await _kernelManager.pauseDownload(id);
    } else {
      success = await _kernelService.pauseDownload(id);
    }
    
    if (success) {
      _appLogger.info('App', 'Task paused successfully: ${task.fileName}');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to pause task: ${task.fileName}');
    }
  }

  Future<void> resumeTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id, orElse: () => _tasks.first);
    _appLogger.info('App', 'Resuming task: ${task.fileName} (ID: $id)');
    
    bool success;
    if (_useNewKernel) {
      success = await _kernelManager.resumeDownload(id);
    } else {
      success = await _kernelService.resumeDownload(id);
    }
    
    if (success) {
      _appLogger.info('App', 'Task resumed successfully: ${task.fileName}');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to resume task: ${task.fileName}');
    }
  }

  Future<void> removeTask(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id, orElse: () => _tasks.first);
    _appLogger.info('App', 'Removing task: ${task.fileName} (ID: $id)');
    
    bool success;
    if (_useNewKernel) {
      success = await _kernelManager.cancelDownload(id);
    } else {
      success = await _kernelService.cancelDownload(id);
    }
    
    if (success) {
      _tasks.removeWhere((task) => task.id == id);
      _appLogger.info('App', 'Task removed successfully: ${task.fileName}');
      notifyListeners();
    } else {
      _appLogger.error('App', 'Failed to remove task: ${task.fileName}');
    }
  }

  Future<void> startTask(String id) async {
    await resumeTask(id);
  }

  Future<Map<String, dynamic>?> getDownloadConfig() async {
    if (_useNewKernel) {
      final config = await _kernelManager.getConfig();
      if (config == null) return null;
      return {
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
      };
    }
    return await _kernelService.getDownloadConfig();
  }

  Future<bool> setDownloadConfig({
    int? threads,
    int? segments,
    String? mode,
    int? maxConcurrentTasks,
    int? segmentSpeedLimit,
    Map<String, dynamic>? proxyConfig,
  }) async {
    bool success;
    
    if (_useNewKernel) {
      kernel.ProxyConfig? proxy;
      if (proxyConfig != null) {
        proxy = kernel.ProxyConfig(
          enabled: proxyConfig['enabled'] ?? false,
          type: proxyConfig['type'] ?? 'http',
          host: proxyConfig['host'] ?? '',
          port: proxyConfig['port'] ?? 8080,
          username: proxyConfig['username'],
          password: proxyConfig['password'],
          requiresAuth: proxyConfig['requires_auth'] ?? false,
        );
      }
      
      final config = kernel.DownloadConfig(
        threads: threads ?? 8,
        segments: segments ?? 8,
        mode: mode ?? 'auto',
        maxConcurrentTasks: maxConcurrentTasks ?? 3,
        segmentSpeedLimit: segmentSpeedLimit ?? 0,
        proxy: proxy,
      );
      success = await _kernelManager.setConfig(config);
    } else {
      success = await _kernelService.setDownloadConfig(
        threads: threads,
        segments: segments,
        mode: mode,
        maxConcurrentTasks: maxConcurrentTasks,
        segmentSpeedLimit: segmentSpeedLimit,
        proxyConfig: proxyConfig,
      );
    }
    
    if (success) {
      _appLogger.info('App', 'Download config updated: threads=$threads, segments=$segments, mode=$mode, concurrent=$maxConcurrentTasks, limit=$segmentSpeedLimit, proxy=${proxyConfig != null ? 'enabled' : 'unchanged'}');
    }
    return success;
  }

  /// 测试代理连接
  Future<bool> testProxyConnection({
    required String type,
    required String host,
    required int port,
    String? username,
    String? password,
  }) async {
    try {
      bool result;
      if (_useNewKernel) {
        result = await _kernelManager.testProxyConnection(
          type: type,
          host: host,
          port: port,
          username: username,
          password: password,
        );
      } else {
        result = await _kernelService.testProxyConnection(
          type: type,
          host: host,
          port: port,
          username: username,
          password: password,
        );
      }
      _appLogger.info('App', 'Proxy connection test: $type://$host:$port - ${result ? 'success' : 'failed'}');
      return result;
    } catch (e) {
      _appLogger.error('App', 'Proxy connection test failed: $e');
      return false;
    }
  }

  /// 重试失败的分段
  Future<void> retryFailedSegments(String id) async {
    final task = _tasks.firstWhere((t) => t.id == id, orElse: () => _tasks.first);
    _appLogger.info('App', 'Retrying failed segments for task: ${task.fileName} (ID: $id)');
    
    bool success;
    if (_useNewKernel) {
      success = await _kernelManager.retryFailedSegments(id);
    } else {
      success = await _kernelService.retryFailedSegments(id);
    }
    
    if (success) {
      _appLogger.info('App', 'Failed segments retry initiated: ${task.fileName}');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to retry segments: ${task.fileName}');
    }
  }

  /// 重试特定分段
  Future<void> retrySegment(String id, int segmentIndex) async {
    final task = _tasks.firstWhere((t) => t.id == id, orElse: () => _tasks.first);
    _appLogger.info('App', 'Retrying segment $segmentIndex for task: ${task.fileName} (ID: $id)');
    
    bool success;
    if (_useNewKernel) {
      success = await _kernelManager.retrySegment(id, segmentIndex);
    } else {
      success = await _kernelService.retrySegment(id, segmentIndex);
    }
    
    if (success) {
      _appLogger.info('App', 'Segment $segmentIndex retry initiated: ${task.fileName}');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to retry segment $segmentIndex: ${task.fileName}');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _notifyTimer?.cancel();
    super.dispose();
  }
}

