import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_task.dart';
import 'kernel_service.dart';
import 'app_logger_service.dart';

class IntegratedDownloadService extends ChangeNotifier {
  final KernelService _kernelService;
  final _appLogger = AppLoggerService();
  final List<DownloadTask> _tasks = [];
  Timer? _pollTimer;

  IntegratedDownloadService(this._kernelService) {
    _startPolling();
  }

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _updateTasks();
    });
  }

  Future<void> _updateTasks() async {
    if (!_kernelService.isRunning) return;

    try {
      final kernelTasks = await _kernelService.getTasks();
      
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
      
      notifyListeners();
    } catch (e) {
      _appLogger.error('App', 'Failed to update tasks: $e');
    }
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
      default:
        status = DownloadStatus.pending;
    }

    // 解析分段信息
    List<SegmentInfo>? segments;
    if (kernelTask['segments'] != null && kernelTask['segments'] is List) {
      try {
        final segmentsList = kernelTask['segments'] as List;
        segments = segmentsList.map((seg) {
          return SegmentInfo(
            index: seg['index'] is int ? seg['index'] : (seg['index'] as num).toInt(),
            startByte: seg['startByte'] is int ? seg['startByte'] : (seg['startByte'] as num).toInt(),
            endByte: seg['endByte'] is int ? seg['endByte'] : (seg['endByte'] as num).toInt(),
            downloadedBytes: seg['downloadedBytes'] is int ? seg['downloadedBytes'] : (seg['downloadedBytes'] as num).toInt(),
            speed: (seg['speed'] ?? 0.0) is double ? seg['speed'] : (seg['speed'] as num).toDouble(),
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
    );
  }

  Future<void> addTask(String url, String fileName) async {
    if (!_kernelService.isRunning) {
      _appLogger.error('App', 'Kernel not running');
      return;
    }

    _appLogger.info('App', 'Adding download task: $fileName');
    final taskId = await _kernelService.addDownload(url, fileName);
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
    final success = await _kernelService.pauseDownload(id);
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
    final success = await _kernelService.resumeDownload(id);
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
    final success = await _kernelService.cancelDownload(id);
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
    return await _kernelService.getDownloadConfig();
  }

  Future<bool> setDownloadConfig({
    int? threads,
    int? segments,
    String? mode,
    int? maxConcurrentTasks,
    int? segmentSpeedLimit,
  }) async {
    final success = await _kernelService.setDownloadConfig(
      threads: threads,
      segments: segments,
      mode: mode,
      maxConcurrentTasks: maxConcurrentTasks,
      segmentSpeedLimit: segmentSpeedLimit,
    );
    if (success) {
      _appLogger.info('App', 'Download config updated: threads=$threads, segments=$segments, mode=$mode, concurrent=$maxConcurrentTasks, limit=$segmentSpeedLimit');
    }
    return success;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

