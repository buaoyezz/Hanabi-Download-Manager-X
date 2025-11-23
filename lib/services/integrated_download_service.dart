import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_task.dart';
import 'kernel_service.dart';
import 'logger_service.dart';

class IntegratedDownloadService extends ChangeNotifier {
  final KernelService _kernelService;
  final _logger = LoggerService();
  final List<DownloadTask> _tasks = [];
  Timer? _pollTimer;

  IntegratedDownloadService(this._kernelService) {
    _startPolling();
  }

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  void _startPolling() {
    _pollTimer = Timer.periodic(Duration(seconds: 1), (_) async {
      await _updateTasks();
    });
  }

  Future<void> _updateTasks() async {
    if (!_kernelService.isRunning) return;

    try {
      final kernelTasks = await _kernelService.getTasks();
      
      for (var kernelTask in kernelTasks) {
        // 调试：打印原始segments数据
        if (kernelTask['segments'] != null) {
          _logger.info('原始segments数据类型: ${kernelTask['segments'].runtimeType}');
          _logger.info('原始segments长度: ${(kernelTask['segments'] as List).length}');
        }
        
        final existingIndex = _tasks.indexWhere((t) => t.id == kernelTask['id']);
        
        if (existingIndex != -1) {
          _tasks[existingIndex] = _convertKernelTask(kernelTask);
        } else {
          _tasks.add(_convertKernelTask(kernelTask));
        }
      }
      
      notifyListeners();
    } catch (e) {
      _logger.error('Failed to update tasks: $e');
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

    // 解析分段信息 - 只使用后端真实发送的数据
    List<SegmentInfo>? segments;
    if (kernelTask['segments'] != null && kernelTask['segments'] is List) {
      try {
        final segmentsList = kernelTask['segments'] as List;
        _logger.info('收到分段数据: ${segmentsList.length} 个分段');
        
        segments = segmentsList.map((seg) {
          final segInfo = SegmentInfo(
            index: seg['index'] is int ? seg['index'] : (seg['index'] as num).toInt(),
            startByte: seg['startByte'] is int ? seg['startByte'] : (seg['startByte'] as num).toInt(),
            endByte: seg['endByte'] is int ? seg['endByte'] : (seg['endByte'] as num).toInt(),
            downloadedBytes: seg['downloadedBytes'] is int ? seg['downloadedBytes'] : (seg['downloadedBytes'] as num).toInt(),
            speed: (seg['speed'] ?? 0.0) is double ? seg['speed'] : (seg['speed'] as num).toDouble(),
          );
          _logger.info('  分段 ${segInfo.index}: ${segInfo.downloadedBytes}/${segInfo.endByte - segInfo.startByte} bytes');
          return segInfo;
        }).toList();
        
        _logger.info('✓ 成功解析 ${segments.length} 个分段，准备传递给UI');
      } catch (e) {
        _logger.error('解析分段数据失败: $e');
        segments = null;
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
      speed: (kernelTask['speed'] ?? 0.0).toDouble(),
      segments: segments,
    );
  }

  Future<void> addTask(String url, String fileName) async {
    if (!_kernelService.isRunning) {
      _logger.error('Kernel not running');
      return;
    }

    final taskId = await _kernelService.addDownload(url, fileName);
    if (taskId != null) {
      _logger.info('Task added: $taskId');
      await _updateTasks();
    } else {
      _logger.error('Failed to add task');
    }
  }

  Future<void> pauseTask(String id) async {
    final success = await _kernelService.pauseDownload(id);
    if (success) {
      _logger.info('Task paused: $id');
      await _updateTasks();
    }
  }

  Future<void> resumeTask(String id) async {
    final success = await _kernelService.resumeDownload(id);
    if (success) {
      _logger.info('Task resumed: $id');
      await _updateTasks();
    }
  }

  Future<void> removeTask(String id) async {
    final success = await _kernelService.cancelDownload(id);
    if (success) {
      _tasks.removeWhere((task) => task.id == id);
      _logger.info('Task removed: $id');
      notifyListeners();
    }
  }

  Future<void> startTask(String id) async {
    await resumeTask(id);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
