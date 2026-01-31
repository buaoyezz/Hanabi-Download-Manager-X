import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../models/task.dart';
import '../models/segment.dart';
import '../config/download_config.dart';
import 'http_client.dart';
import '../../../app_logger_service.dart';

class DownloadEngine {
  final NsfxConfig config;
  final NsfxHttpClient httpClient;
  final void Function(Task) onProgress;
  final void Function(Task) onComplete;
  final void Function(Task) onError;
  final _logger = AppLoggerService();

  final Map<String, bool> _cancelledTasks = {};
  final Map<String, bool> _pausedTasks = {};
  final Map<String, List<Isolate>> _taskIsolates = {}; // 跟踪每个任务的 Isolate
  final Map<String, ReceivePort> _progressPorts = {}; // 跟踪每个任务的进度端口
  
  // 用于速度计算的历史数据（基于内存计数器）
  final Map<String, int> _lastDownloaded = {};
  final Map<String, DateTime> _lastUpdateTime = {};

  DownloadEngine({
    required this.config,
    required this.httpClient,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });

  Future<void> startDownload(Task task) async {
    _cancelledTasks[task.id] = false;
    _pausedTasks[task.id] = false;
    _taskIsolates[task.id] = []; // 初始化 Isolate 列表
    
    // 创建进度监听端口
    final progressPort = ReceivePort();
    _progressPorts[task.id] = progressPort;
    progressPort.listen((message) {
      if (message is _ProgressMessage) {
        _handleProgressMessage(task, message);
      }
    });

    try {
      _logger.info('NSFX-Engine', 'Starting download: ${task.filename}');
      task.status = TaskStatus.downloading;
      task.startTime = DateTime.now();

      final headers = _buildHeaders(task);
      final fileInfo = await httpClient.getFileInfo(task.url, headers);
      _logger.info('NSFX-Engine', 'File info for ${task.filename}: size=${fileInfo.size}, supportsRange=${fileInfo.supportsRange}');

      if (fileInfo.size == 0) {
        _logger.info('NSFX-Engine', 'Unknown file size, falling back to single thread download');
        await _singleThreadDownload(task, headers);
        return;
      }

      task.totalSize = fileInfo.size;

      if (!fileInfo.supportsRange) {
        _logger.info('NSFX-Engine', 'Server does not support Range requests, using single thread');
        await _singleThreadDownload(task, headers);
        return;
      }
      
      if (fileInfo.size < 1024 * 1024) {
        _logger.info('NSFX-Engine', 'File too small (${fileInfo.size} bytes < 1MB), using single thread');
        await _singleThreadDownload(task, headers);
        return;
      }

      _logger.info('NSFX-Engine', 'Using Isolate-based multi-thread download for ${task.filename}');
      await _isolateMultiThreadDownload(task, headers, fileInfo.size);

    } catch (e) {
      _logger.error('NSFX-Engine', 'Download failed: ${task.filename} - $e');
      task.status = TaskStatus.failed;
      task.errorMessage = e.toString();
      onError(task);
    } finally {
      _cancelledTasks.remove(task.id);
      _pausedTasks.remove(task.id);
      
      // 清理速度计算的历史数据
      _lastDownloaded.remove(task.id);
      _lastUpdateTime.remove(task.id);
      
      // 关闭进度端口
      final progressPort = _progressPorts.remove(task.id);
      progressPort?.close();
      
      // 清理并终止所有相关的 Isolate
      final isolates = _taskIsolates.remove(task.id);
      if (isolates != null) {
        for (final isolate in isolates) {
          isolate.kill(priority: Isolate.immediate);
        }
      }
    }
  }
  
  /// 处理来自 Isolate 的进度消息（内存累加）
  void _handleProgressMessage(Task task, _ProgressMessage message) {
    // 找到对应的分段
    if (message.segmentIndex < task.segments.length) {
      final segment = task.segments[message.segmentIndex];
      
      // 关键修复：检查边界，防止超出分段大小
      final segmentSize = segment.endByte - segment.startByte;
      final newDownloaded = segment.downloadedBytes + message.bytesDelta;
      
      if (newDownloaded > segmentSize) {
        // 只累加到分段边界为止
        final actualDelta = segmentSize - segment.downloadedBytes;
        if (actualDelta > 0) {
          segment.downloadedBytes = segmentSize;
          task.downloadedSize += actualDelta;
          _logger.warning('NSFX-Engine', 
            'Segment ${segment.index} reached boundary, clamped: ${segment.downloadedBytes}/$segmentSize');
        }
        // 超出部分直接丢弃，不累加
      } else {
        // 正常累加
        segment.downloadedBytes = newDownloaded;
        task.downloadedSize += message.bytesDelta;
      }
      
      // 更新进度百分比
      if (task.totalSize > 0) {
        task.progress = (task.downloadedSize / task.totalSize) * 100;
      }
    }
  }

  /// 使用 Isolate 的多线程下载
  Future<void> _isolateMultiThreadDownload(Task task, Map<String, String> headers, int fileSize) async {
    final (threads, segmentCount) = DynamicSegmentConfig.calculate(fileSize, config);
    // 移除线程数限制，使用计算出的值
    final actualThreads = threads;
    task.threadCount = actualThreads;
    _logger.info('NSFX-Engine', 'Using $actualThreads concurrent isolates, $segmentCount segments');

    final tempDir = await _getTempDir(task);
    await tempDir.create(recursive: true);
    
    // 创建分段（仅在首次下载时）
    if (task.segments.isEmpty) {
      final segmentSize = fileSize ~/ segmentCount;
      for (int i = 0; i < segmentCount; i++) {
        final start = i * segmentSize;
        final end = (i == segmentCount - 1) ? fileSize : (i + 1) * segmentSize;
        task.segments.add(Segment(index: i, startByte: start, endByte: end));
      }
    } else {
      // 恢复时：重置所有分段的下载状态（将从临时文件恢复实际进度）
      _logger.info('NSFX-Engine', 'Resuming download with ${task.segments.length} existing segments');
      for (final segment in task.segments) {
        // 重置状态，稍后会根据临时文件实际情况更新
        if (segment.status != SegmentStatus.completed) {
          segment.downloadedBytes = 0;
          segment.status = SegmentStatus.pending;
        }
      }
    }
    
    // 恢复已下载的进度（从临时文件）- 对所有分段都执行
    int restoredBytes = 0;
    for (final segment in task.segments) {
      final partFile = File('${tempDir.path}/${task.filename}.part${segment.index}');
      if (await partFile.exists()) {
        final fileSize = await partFile.length();
        final segmentSize = segment.endByte - segment.startByte;
        
        // 如果临时文件大小超过分段大小，截断它（可能是动态分段导致的）
        if (fileSize > segmentSize) {
          _logger.warning('NSFX-Engine', 'Segment ${segment.index} temp file too large: $fileSize > $segmentSize, truncating');
          final raf = await partFile.open(mode: FileMode.writeOnlyAppend);
          await raf.truncate(segmentSize);
          await raf.close();
          // 截断后，设置为分段大小并标记为完成
          segment.downloadedBytes = segmentSize;
          segment.status = SegmentStatus.completed;
          restoredBytes += segmentSize;
          _logger.info('NSFX-Engine', 'Segment ${segment.index} truncated and marked complete: $segmentSize bytes');
        } else {
          segment.downloadedBytes = fileSize;
          restoredBytes += fileSize;
          if (fileSize >= segmentSize) {
            segment.status = SegmentStatus.completed;
            _logger.debug('NSFX-Engine', 'Segment ${segment.index} already completed ($fileSize bytes)');
          } else if (fileSize > 0) {
            _logger.debug('NSFX-Engine', 'Segment ${segment.index} restored: $fileSize/$segmentSize bytes');
          }
        }
      }
    }
    
    if (restoredBytes > 0) {
      _logger.info('NSFX-Engine', 'Restored ${(restoredBytes / 1024 / 1024).toStringAsFixed(2)} MB from temp files');
    }
    
    // 立即更新一次进度（基于内存计数器）
    task.downloadedSize = restoredBytes;
    if (task.totalSize > 0) {
      task.progress = (task.downloadedSize / task.totalSize) * 100;
    }
    onProgress(task);

    // 进度更新定时器（仅用于速度计算和 ETA，不再读取文件）
    final progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (task.status == TaskStatus.downloading) {
        _calculateSpeed(task);
        onProgress(task);
      }
    });

    // 动态分段检查定时器（每5秒检查一次）
    final dynamicSegmentTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (task.status == TaskStatus.downloading) {
        _checkAndSplitSlowSegments(task);
      }
    });

    try {
      // 使用信号量控制并发
      final semaphore = _Semaphore(actualThreads);
      final futures = <Future<bool>>[];

      for (final segment in task.segments) {
        if (segment.status == SegmentStatus.completed) continue;
        
        final tempFile = '${tempDir.path}/${task.filename}.part${segment.index}';
        
        futures.add(semaphore.run(() async {
          if (_cancelledTasks[task.id] == true) return false;
          if (_pausedTasks[task.id] == true) return false;
          
          segment.status = SegmentStatus.downloading;
          
          return await _downloadSegmentInIsolate(
            task: task,
            segment: segment,
            headers: headers,
            tempFilePath: tempFile,
          );
        }));
      }

      final results = await Future.wait(futures);
      progressTimer.cancel();
      dynamicSegmentTimer.cancel();

      if (_cancelledTasks[task.id] == true) {
        task.status = TaskStatus.cancelled;
        return;
      }

      if (_pausedTasks[task.id] == true) {
        task.status = TaskStatus.paused;
        return;
      }

      // 检查所有分段是否完成
      final allCompleted = task.segments.every((s) => s.status == SegmentStatus.completed);
      if (!allCompleted) {
        final failedCount = task.segments.where((s) => s.status == SegmentStatus.failed).length;
        task.status = TaskStatus.failed;
        task.errorMessage = '$failedCount segments failed';
        onError(task);
        return;
      }

      // 合并分段
      task.status = TaskStatus.merging;
      onProgress(task);
      _logger.info('NSFX-Engine', 'Merging segments: ${task.filename}');

      await _mergeSegments(task, tempDir);

      task.status = TaskStatus.completed;
      task.endTime = DateTime.now();
      task.progress = 100;
      
      if (task.startTime != null && task.endTime != null) {
        final duration = task.endTime!.difference(task.startTime!).inSeconds;
        if (duration > 0) task.averageSpeed = task.totalSize / duration;
      }

      _logger.info('NSFX-Engine', 'Download completed: ${task.filename}');
      onComplete(task);

    } finally {
      progressTimer.cancel();
      dynamicSegmentTimer.cancel();
    }
  }

  /// 检查并分割慢速分段（动态分段）
  void _checkAndSplitSlowSegments(Task task) async {
    // 只在下载进行中且启用动态分段时执行
    if (!config.enableDynamicSegments) {
      _logger.debug('NSFX-Engine', 'Dynamic segments disabled');
      return;
    }
    if (task.status != TaskStatus.downloading) return;
    
    // 找出正在下载且剩余大小较大的分段
    final downloadingSegments = task.segments
        .where((s) => s.status == SegmentStatus.downloading)
        .toList();
    
    if (downloadingSegments.isEmpty) {
      _logger.debug('NSFX-Engine', 'No downloading segments');
      return;
    }
    
    // 至少需要 2 个分段才能比较
    if (downloadingSegments.length < 2) {
      _logger.debug('NSFX-Engine', 'Only 1 downloading segment, cannot compare');
      return;
    }
    
    // 计算平均剩余大小
    final totalRemaining = downloadingSegments.fold<int>(
      0, 
      (sum, s) => sum + (s.size - s.downloadedBytes)
    );
    final avgRemaining = totalRemaining / downloadingSegments.length;
    
    _logger.info('NSFX-Engine', 
      'Dynamic segment check: ${downloadingSegments.length} downloading, avg remaining: ${(avgRemaining / 1024 / 1024).toStringAsFixed(2)} MB');
    
    // 找出剩余大小超过平均值 1.5 倍的分段（降低阈值）
    final slowSegments = downloadingSegments
        .where((s) => (s.size - s.downloadedBytes) > avgRemaining * 1.5)
        .where((s) => (s.size - s.downloadedBytes) > 5 * 1024 * 1024) // 剩余至少 5MB 才分割（降低阈值）
        .toList();
    
    if (slowSegments.isEmpty) {
      _logger.info('NSFX-Engine', 'No slow segments found (threshold: ${(avgRemaining * 1.5 / 1024 / 1024).toStringAsFixed(2)} MB)');
      return;
    }
    
    _logger.info('NSFX-Engine', 'Found ${slowSegments.length} slow segments to split');
    
    // 限制总分段数不超过 256
    if (task.segments.length >= 256) {
      _logger.warning('NSFX-Engine', 'Max segments (256) reached');
      return;
    }
    
    final tempDir = await _getTempDir(task);
    int splitCount = 0;
    
    for (final slowSeg in slowSegments) {
      // 每次最多分割 5 个慢速分段
      if (task.segments.length >= 256 || splitCount >= 5) break;
      
      final remaining = slowSeg.size - slowSeg.downloadedBytes;
      if (remaining < 5 * 1024 * 1024) continue; // 剩余小于 5MB 不分割（降低阈值）
      
      // 将慢速分段一分为二
      final currentDownloaded = slowSeg.downloadedBytes;
      final midPoint = slowSeg.startByte + currentDownloaded + (remaining ~/ 2);
      
      // 创建新分段（下半部分）
      final newSegment = Segment(
        index: task.segments.length,
        startByte: midPoint,
        endByte: slowSeg.endByte,
      );
      
      // 修改原分段（上半部分）
      final oldEndByte = slowSeg.endByte;
      final oldDownloadedBytes = slowSeg.downloadedBytes;
      slowSeg.endByte = midPoint;
      
      // 关键修复1：调整 downloadedBytes 不超过新的分段大小
      final newSegmentSize = slowSeg.endByte - slowSeg.startByte;
      if (slowSeg.downloadedBytes > newSegmentSize) {
        final excessBytes = slowSeg.downloadedBytes - newSegmentSize;
        slowSeg.downloadedBytes = newSegmentSize;
        task.downloadedSize -= excessBytes; // 从总进度中减去超出部分
        _logger.warning('NSFX-Engine', 
          'Segment ${slowSeg.index} downloadedBytes ($oldDownloadedBytes) exceeds new size ($newSegmentSize), adjusted and reduced total by ${(excessBytes / 1024 / 1024).toStringAsFixed(2)} MB');
      }
      
      // 关键修复2：如果原分段的临时文件已经下载了超过新 endByte 的数据，需要截断
      final partFile = File('${tempDir.path}/${task.filename}.part${slowSeg.index}');
      if (await partFile.exists()) {
        final fileSize = await partFile.length();
        
        if (fileSize > newSegmentSize) {
          _logger.warning('NSFX-Engine', 
            'Segment ${slowSeg.index} temp file ($fileSize bytes) exceeds new size ($newSegmentSize bytes) after split, truncating');
          try {
            final raf = await partFile.open(mode: FileMode.writeOnlyAppend);
            await raf.truncate(newSegmentSize);
            await raf.close();
            // 标记为完成
            slowSeg.status = SegmentStatus.completed;
            _logger.info('NSFX-Engine', 'Segment ${slowSeg.index} truncated to $newSegmentSize bytes and marked complete');
          } catch (e) {
            _logger.error('NSFX-Engine', 'Failed to truncate segment ${slowSeg.index}: $e');
            // 如果截断失败，恢复原状态
            slowSeg.endByte = oldEndByte;
            slowSeg.downloadedBytes = oldDownloadedBytes;
            task.downloadedSize += (oldDownloadedBytes - slowSeg.downloadedBytes);
            continue;
          }
        }
      }
      
      // 添加新分段
      task.segments.add(newSegment);
      splitCount++;
      
      _logger.info('NSFX-Engine', 
        'Split segment ${slowSeg.index}: ${slowSeg.startByte}-$oldEndByte => ${slowSeg.startByte}-${slowSeg.endByte} + ${newSegment.startByte}-${newSegment.endByte} (remaining: ${(remaining / 1024 / 1024).toStringAsFixed(2)} MB, total segments: ${task.segments.length})');
      
      // 只有在原分段未完成时才启动新分段的下载
      if (slowSeg.status != SegmentStatus.completed) {
        _startNewSegmentDownload(task, newSegment);
      }
    }
    
    if (splitCount > 0) {
      _logger.info('NSFX-Engine', 'Split $splitCount segments, total segments now: ${task.segments.length}');
    }
  }

  /// 启动新分段的下载
  void _startNewSegmentDownload(Task task, Segment segment) async {
    final tempDir = await _getTempDir(task);
    final tempFile = '${tempDir.path}/${task.filename}.part${segment.index}';
    final headers = _buildHeaders(task);
    
    segment.status = SegmentStatus.downloading;
    
    await _downloadSegmentInIsolate(
      task: task,
      segment: segment,
      headers: headers,
      tempFilePath: tempFile,
    );
  }

  /// 在 Isolate 中下载单个分段
  Future<bool> _downloadSegmentInIsolate({
    required Task task,
    required Segment segment,
    required Map<String, String> headers,
    required String tempFilePath,
  }) async {
    int retryCount = 0;
    
    while (retryCount < config.maxRetries) {
      if (_cancelledTasks[task.id] == true || _pausedTasks[task.id] == true) {
        return false;
      }
      
      try {
        // 检查是否有已下载的部分（用于断点续传）
        int alreadyDownloaded = segment.downloadedBytes;
        final actualStartByte = segment.startByte + alreadyDownloaded;
        
        final receivePort = ReceivePort();
        final progressPort = _progressPorts[task.id];
        
        final isolate = await Isolate.spawn(
          _isolateSegmentDownload,
          _IsolateParams(
            sendPort: receivePort.sendPort,
            progressPort: progressPort?.sendPort, // 传递进度端口
            url: task.url,
            tempFilePath: tempFilePath,
            startByte: actualStartByte,  // 从已下载位置继续
            endByte: segment.endByte,
            headers: headers,
            connectionTimeout: config.connectionTimeout,
            alreadyDownloaded: alreadyDownloaded,  // 传递已下载字节数
            taskId: task.id,
            segmentIndex: segment.index,
          ),
        );
        
        // 跟踪 Isolate
        _taskIsolates[task.id]?.add(isolate);
        
        final result = await receivePort.first as _IsolateResult;
        receivePort.close();
        
        // 从跟踪列表中移除
        _taskIsolates[task.id]?.remove(isolate);
        
        if (result.success) {
          segment.downloadedBytes = result.downloadedBytes;
          segment.status = SegmentStatus.completed;
          return true;
        } else {
          throw Exception(result.error ?? 'Unknown error');
        }
        
      } catch (e) {
        retryCount++;
        segment.retryCount = retryCount;
        segment.lastError = e.toString();
        
        if (retryCount < config.maxRetries) {
          await Future.delayed(Duration(seconds: (1 << retryCount).clamp(1, 30)));
        }
      }
    }
    
    segment.status = SegmentStatus.failed;
    return false;
  }

  /// Isolate 入口点 - 下载单个分段
  static void _isolateSegmentDownload(_IsolateParams params) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: params.connectionTimeout);
      client.idleTimeout = const Duration(seconds: 60);
      
      final uri = Uri.parse(params.url);
      final request = await client.getUrl(uri);
      
      params.headers.forEach((key, value) {
        request.headers.set(key, value);
      });
      
      final expectedSize = params.endByte - params.startByte;
      final remainingSize = expectedSize - params.alreadyDownloaded;
      
      // [优化] 如果已经下载完成了，直接返回成功，不需要建立连接
      if (remainingSize <= 0) {
        client.close();
        params.sendPort.send(_IsolateResult(
          success: true,
          downloadedBytes: params.alreadyDownloaded,
        ));
        return;
      }
      
      request.headers.set('Range', 'bytes=${params.startByte}-${params.endByte - 1}');
      
      final response = await request.close();
      
      if (response.statusCode != 206 && response.statusCode != 200) {
        await response.drain();
        client.close();
        params.sendPort.send(_IsolateResult(
          success: false,
          error: 'HTTP ${response.statusCode}',
          downloadedBytes: params.alreadyDownloaded,
        ));
        return;
      }
      
      final file = File(params.tempFilePath);
      // 如果有已下载的数据，使用 append 模式；否则使用 writeOnly 模式
      final sink = file.openWrite(mode: params.alreadyDownloaded > 0 ? FileMode.append : FileMode.writeOnly);
      int downloadedBytes = 0;  // 本次下载的字节数
      
      // 进度上报：每下载 64KB 或每 100ms 通知一次主线程
      int bufferedBytes = 0;
      const int bufferThreshold = 64 * 1024; // 64KB
      DateTime lastProgressTime = DateTime.now();
      const progressInterval = Duration(milliseconds: 100);
      
      await for (final chunk in response) {
        // [关键修复] 严格计算剩余量
        final currentRemaining = remainingSize - downloadedBytes;
        if (currentRemaining <= 0) break; // 已经够了，强制退出循环
        
        final toWrite = chunk.length > currentRemaining 
            ? chunk.sublist(0, currentRemaining) 
            : chunk;
        
        sink.add(toWrite);
        downloadedBytes += toWrite.length;
        bufferedBytes += toWrite.length;
        
        // 达到阈值或时间间隔，发送进度通知
        final now = DateTime.now();
        if (bufferedBytes >= bufferThreshold || now.difference(lastProgressTime) >= progressInterval) {
          params.progressPort?.send(_ProgressMessage(
            taskId: params.taskId,
            segmentIndex: params.segmentIndex,
            bytesDelta: bufferedBytes,
          ));
          bufferedBytes = 0;
          lastProgressTime = now;
        }
        
        // [关键修复] 再次检查：如果刚刚写入导致满了，立即 break，不再等待下一个 chunk
        if (remainingSize - downloadedBytes <= 0) break;
      }
      
      // 发送剩余的 buffer
      if (bufferedBytes > 0) {
        params.progressPort?.send(_ProgressMessage(
          taskId: params.taskId,
          segmentIndex: params.segmentIndex,
          bytesDelta: bufferedBytes,
        ));
      }
      
      // [关键修复] 改变关闭顺序：先关闭网络连接，再处理文件
      // 这可以防止网络挂起导致文件流一直等待
      client.close(force: true);
      
      await sink.flush();
      await sink.close();
      
      final totalDownloaded = params.alreadyDownloaded + downloadedBytes;
      
      params.sendPort.send(_IsolateResult(
        success: totalDownloaded >= expectedSize,
        downloadedBytes: totalDownloaded,
        error: totalDownloaded < expectedSize 
            ? 'Incomplete: $totalDownloaded/$expectedSize' 
            : null,
      ));
      
    } catch (e) {
      params.sendPort.send(_IsolateResult(
        success: false,
        error: e.toString(),
        downloadedBytes: params.alreadyDownloaded,
      ));
    }
  }

  /// 计算速度（基于内存计数器，使用 EMA 平滑）
  void _calculateSpeed(Task task) {
    final now = DateTime.now();
    final currentDownloaded = task.downloadedSize; // 来自内存累加，非常快且准确
    final lastDownloaded = _lastDownloaded[task.id];
    final lastTime = _lastUpdateTime[task.id];
    
    // 如果是第一次更新，初始化记录但不计算速度
    if (lastDownloaded == null || lastTime == null) {
      _lastDownloaded[task.id] = currentDownloaded;
      _lastUpdateTime[task.id] = now;
      task.speed = 0;
      return;
    }
    
    final durationInSeconds = now.difference(lastTime).inMicroseconds / 1000000.0;
    
    // 只有时间间隔大于 0.9 秒才更新速度
    if (durationInSeconds >= 0.9) {
      final bytesDiff = currentDownloaded - lastDownloaded;
      
      // 基于内存累加，理论上不会出现负数，但做个保护
      if (bytesDiff >= 0) {
        final instantSpeed = bytesDiff / durationInSeconds;
        
        // === 引入 EMA 平滑算法 ===
        // alpha 越小越平滑，反应越慢；越大越灵敏，波动越大
        // 通常 0.1 - 0.3，这里使用 0.2
        const double alpha = 0.2;
        
        if (task.speed == 0) {
          // 第一次有速度数据，直接使用
          task.speed = instantSpeed;
        } else {
          // 使用 EMA 平滑
          task.speed = (task.speed * (1 - alpha)) + (instantSpeed * alpha);
        }
        
        // 更新峰值速度（使用瞬时速度，不使用平滑后的）
        if (instantSpeed > task.peakSpeed) {
          task.peakSpeed = instantSpeed;
        }
        
        // 更新记录
        _lastDownloaded[task.id] = currentDownloaded;
        _lastUpdateTime[task.id] = now;
        
        // 计算 ETA
        if (task.totalSize > 0 && task.speed > 0) {
          final remaining = task.totalSize - task.downloadedSize;
          task.eta = (remaining / task.speed).ceil();
        }
      }
    }
    
    // ---------------------------------------------------------
    // 强制校准进度：解决动态分段可能导致的进度漂移或双倍统计问题
    // 计算所有分段实际已下载量的总和
    final realTotalDownloaded = task.segments.fold<int>(
      0, 
      (sum, s) => sum + s.downloadedBytes
    );
    
    // 如果累加器(task.downloadedSize)与实际总和(realTotalDownloaded)偏差超过 1MB，则强制同步
    // 这种情况通常发生在动态分段触发后
    if ((task.downloadedSize - realTotalDownloaded).abs() > 1024 * 1024) {
      _logger.warning('NSFX-Engine', 
        'Progress drift detected: ${task.downloadedSize} vs ${realTotalDownloaded}, calibrating');
      task.downloadedSize = realTotalDownloaded;
    }
    
    // 最后的防线：确保下载量绝不超过总量
    if (task.totalSize > 0 && task.downloadedSize > task.totalSize) {
      _logger.warning('NSFX-Engine', 
        'Downloaded size (${task.downloadedSize}) exceeds total size (${task.totalSize}), clamping');
      task.downloadedSize = task.totalSize;
    }
    
    // 重新计算百分比，确保 UI 不会错误显示 100%
    if (task.totalSize > 0) {
      task.progress = (task.downloadedSize / task.totalSize) * 100;
      
      // 如果计算出 100% 但状态仍是 downloading，强制扣除一点点，避免用户误解
      if (task.progress >= 100.0 && task.status == TaskStatus.downloading) {
        task.progress = 99.9;
      }
    }
    // ---------------------------------------------------------
  }

  Future<void> _singleThreadDownload(Task task, Map<String, String> headers) async {
    task.threadCount = 1;
    task.status = TaskStatus.downloading;

    final file = File(task.filepath);
    await file.parent.create(recursive: true);

    final response = await httpClient.get(task.url, headers);
    
    if (response.statusCode != 200) {
      await response.drain();
      throw HttpException('HTTP ${response.statusCode}');
    }

    if (response.contentLength > 0) task.totalSize = response.contentLength;

    final sink = file.openWrite();
    int bytesThisInterval = 0;
    DateTime lastUpdate = DateTime.now();

    try {
      await for (final chunk in response) {
        if (_cancelledTasks[task.id] == true) {
          await sink.close();
          await file.delete();
          task.status = TaskStatus.cancelled;
          return;
        }

        if (_pausedTasks[task.id] == true) {
          await sink.close();
          task.status = TaskStatus.paused;
          return;
        }

        sink.add(chunk);
        task.downloadedSize += chunk.length;
        bytesThisInterval += chunk.length;

        if (task.totalSize > 0) {
          task.progress = (task.downloadedSize / task.totalSize) * 100;
        }

        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 1000) {
          final elapsed = now.difference(lastUpdate).inMilliseconds / 1000;
          task.speed = bytesThisInterval / elapsed;
          if (task.speed > task.peakSpeed) task.peakSpeed = task.speed;
          bytesThisInterval = 0;
          lastUpdate = now;

          if (task.totalSize > 0 && task.speed > 0) {
            task.eta = ((task.totalSize - task.downloadedSize) / task.speed).round();
          }
          onProgress(task);
        }
      }

      await sink.flush();
      await sink.close();

      task.status = TaskStatus.completed;
      task.endTime = DateTime.now();
      task.progress = 100;

      if (task.startTime != null && task.endTime != null) {
        final duration = task.endTime!.difference(task.startTime!).inSeconds;
        if (duration > 0) task.averageSpeed = task.totalSize / duration;
      }

      onComplete(task);

    } catch (e) {
      await sink.close();
      rethrow;
    }
  }

  Future<void> _mergeSegments(Task task, Directory tempDir) async {
    final outputFile = File(task.filepath);
    await outputFile.parent.create(recursive: true);
    
    final sink = outputFile.openWrite();

    try {
      for (final segment in task.segments..sort((a, b) => a.index.compareTo(b.index))) {
        final partFile = File('${tempDir.path}/${task.filename}.part${segment.index}');
        if (await partFile.exists()) {
          await sink.addStream(partFile.openRead());
          
          // 删除临时文件，带重试机制
          await _deleteFileWithRetry(partFile);
        }
      }

      await sink.flush();
      await sink.close();

      // 删除临时目录，带重试机制
      if (await tempDir.exists()) {
        await _deleteDirWithRetry(tempDir);
      }

    } catch (e) {
      await sink.close();
      rethrow;
    }
  }
  
  /// 带重试机制的文件删除
  Future<void> _deleteFileWithRetry(File file, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          // 最后一次重试失败，记录日志但不抛出异常
          _logger.warning('NSFX-Engine', 'Failed to delete file after $maxRetries attempts: ${file.path}');
          return;
        }
        // 等待一段时间后重试
        await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
      }
    }
  }
  
  /// 带重试机制的目录删除
  Future<void> _deleteDirWithRetry(Directory dir, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          // 最后一次重试失败，记录日志但不抛出异常
          _logger.warning('NSFX-Engine', 'Failed to delete directory after $maxRetries attempts: ${dir.path}');
          return;
        }
        // 等待一段时间后重试
        await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
      }
    }
  }

  Future<Directory> _getTempDir(Task task) async {
    final parent = File(task.filepath).parent;
    final tempRoot = Directory('${parent.path}/.nsfx_temp');
    return Directory('${tempRoot.path}/${task.id}');
  }

  void pauseDownload(String taskId) {
    _pausedTasks[taskId] = true;
    
    // 立即终止所有相关的 Isolate
    final isolates = _taskIsolates[taskId];
    if (isolates != null) {
      for (final isolate in isolates) {
        isolate.kill(priority: Isolate.immediate);
      }
      isolates.clear();
    }
  }

  void cancelDownload(String taskId) {
    _cancelledTasks[taskId] = true;
    
    // 立即终止所有相关的 Isolate
    final isolates = _taskIsolates[taskId];
    if (isolates != null) {
      for (final isolate in isolates) {
        isolate.kill(priority: Isolate.immediate);
      }
      isolates.clear();
    }
  }

  Map<String, String> _buildHeaders(Task task) {
    final headers = <String, String>{
      'User-Agent': task.userAgent ?? 'NSFX/2.0 (Next Speed Force X)',
      'Accept': '*/*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Connection': 'keep-alive',
    };

    if (task.referer != null && task.referer!.isNotEmpty) {
      headers['Referer'] = task.referer!;
    } else {
      try {
        final uri = Uri.parse(task.url);
        headers['Referer'] = '${uri.scheme}://${uri.host}/';
      } catch (_) {}
    }

    if (task.cookies != null && task.cookies!.isNotEmpty) {
      headers['Cookie'] = task.cookies!;
    }

    if (task.headers != null) headers.addAll(task.headers!);

    return headers;
  }
}

/// Isolate 参数
class _IsolateParams {
  final SendPort sendPort;
  final SendPort? progressPort; // 新增：用于实时汇报进度
  final String url;
  final String tempFilePath;
  final int startByte;
  final int endByte;
  final Map<String, String> headers;
  final int connectionTimeout;
  final int alreadyDownloaded;
  final String taskId; // 新增：任务ID
  final int segmentIndex; // 新增：分段索引

  _IsolateParams({
    required this.sendPort,
    this.progressPort,
    required this.url,
    required this.tempFilePath,
    required this.startByte,
    required this.endByte,
    required this.headers,
    required this.connectionTimeout,
    this.alreadyDownloaded = 0,
    required this.taskId,
    required this.segmentIndex,
  });
}

/// Isolate 结果
class _IsolateResult {
  final bool success;
  final int downloadedBytes;
  final String? error;

  _IsolateResult({
    required this.success,
    required this.downloadedBytes,
    this.error,
  });
}

/// 进度消息（从 Isolate 发送到主线程）
class _ProgressMessage {
  final String taskId;
  final int segmentIndex;
  final int bytesDelta; // 增量字节数

  _ProgressMessage({
    required this.taskId,
    required this.segmentIndex,
    required this.bytesDelta,
  });
}

class _Semaphore {
  final int maxConcurrent;
  int _current = 0;
  final _queue = <Completer<void>>[];

  _Semaphore(this.maxConcurrent);

  Future<T> run<T>(Future<T> Function() task) async {
    await _acquire();
    try {
      return await task();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_current < maxConcurrent) {
      _current++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
  }

  void _release() {
    if (_queue.isNotEmpty) {
      final completer = _queue.removeAt(0);
      completer.complete();
    } else {
      _current--;
    }
  }
}
