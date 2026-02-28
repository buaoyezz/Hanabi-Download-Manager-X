import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import '../models/task.dart';
import '../models/segment.dart';
import '../config/download_config.dart';
import 'http_client.dart';
import '../../../../services/speed_history_service.dart';
import '../../../app_logger_service.dart';

class DownloadEngine {
  static const String _rangeNotSupportedError = 'RANGE_NOT_SUPPORTED';
  static const String _rangeNotSatisfiableError = 'RANGE_NOT_SATISFIABLE';

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
  final Map<String, _Semaphore> _taskSemaphores = {}; // 跟踪每个任务的并发控制器

  // 用于速度计算的历史数据（基于内存计数器）
  final Map<String, int> _lastDownloaded = {};
  final Map<String, DateTime> _lastUpdateTime = {};

  // 全局带宽限制器
  // 速度历史记录
  final _speedHistory = SpeedHistoryService();

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
      onProgress(task); // 立即通知 UI 状态已改变

      final headers = _buildHeaders(task);
      final fileInfo = await httpClient.getFileInfo(task.url, headers);
      _logger.info('NSFX-Engine',
          'File info for ${task.filename}: size=${fileInfo.size}, supportsRange=${fileInfo.supportsRange}');

      if (fileInfo.size == 0) {
        _logger.info('NSFX-Engine',
            'Unknown file size, falling back to single thread download');
        await _singleThreadDownload(
          task,
          headers,
          supportsRange: fileInfo.supportsRange,
        );
        return;
      }

      task.totalSize = fileInfo.size;
      onProgress(task); // 通知 UI 文件大小已获取

      if (!fileInfo.supportsRange) {
        _logger.info('NSFX-Engine',
            'Server does not support Range requests, using single thread');
        await _singleThreadDownload(
          task,
          headers,
          supportsRange: false,
          totalSizeHint: fileInfo.size,
        );
        return;
      }

      if (fileInfo.size < 1024 * 1024) {
        _logger.info('NSFX-Engine',
            'File too small (${fileInfo.size} bytes < 1MB), using single thread');
        await _singleThreadDownload(
          task,
          headers,
          supportsRange: fileInfo.supportsRange,
          totalSizeHint: fileInfo.size,
        );
        return;
      }

      _logger.info('NSFX-Engine',
          'Using Isolate-based multi-thread download for ${task.filename}');
      await _isolateMultiThreadDownload(task, headers, fileInfo.size);
    } catch (e) {
      final errorText = e.toString();
      // 代理错误 → 切换直连并重试一次
      if ((errorText.contains('HTTP 502') ||
              errorText.contains('HTTP 503') ||
              errorText.contains('HTTP 504') ||
              errorText.contains('HTTP 407') ||
              errorText.contains('PROXY_ERROR_')) &&
          httpClient.config.proxy.enabled) {
        _logger.warning('NSFX-Engine',
            'Proxy error during download, retrying with direct connection: $e');
        httpClient.switchToDirectOnProxyError();
        try {
          // 重置任务状态
          task.status = TaskStatus.downloading;
          task.downloadedSize = 0;
          task.progress = 0;
          task.segments.clear();
          task.errorMessage = null;

          final headers = _buildHeaders(task);
          final fileInfo = await httpClient.getFileInfo(task.url, headers);
          if (fileInfo.size > 0) {
            task.totalSize = fileInfo.size;
          }
          await _singleThreadDownload(
            task,
            headers,
            supportsRange: fileInfo.supportsRange,
            totalSizeHint: fileInfo.size > 0 ? fileInfo.size : null,
          );
          return;
        } catch (retryError) {
          _logger.error('NSFX-Engine',
              'Retry with direct connection also failed: $retryError');
          task.status = TaskStatus.failed;
          task.errorMessage = retryError.toString();
          onError(task);
        }
      } else {
        _logger.error('NSFX-Engine', 'Download failed: ${task.filename} - $e');
        task.status = TaskStatus.failed;
        task.errorMessage = e.toString();
        onError(task);
      }
    } finally {
      _cancelledTasks.remove(task.id);
      _pausedTasks.remove(task.id);
      _taskSemaphores.remove(task.id);

      // 清理速度计算的历史数据
      _lastDownloaded.remove(task.id);
      _lastUpdateTime.remove(task.id);
      _speedHistory.clear(task.id);

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
  Future<void> _isolateMultiThreadDownload(
      Task task, Map<String, String> headers, int fileSize) async {
    final (calculatedThreads, segmentCount) =
        DynamicSegmentConfig.calculate(fileSize, config);
    // 线程数 = 计算出的线程数，上限为分段数（不能比分段多）
    final actualThreads = calculatedThreads.clamp(1, segmentCount);
    task.threadCount = actualThreads;
    _logger.info('NSFX-Engine', '========================================');
    _logger.info('NSFX-Engine', 'Multi-thread download configuration:');
    _logger.info('NSFX-Engine', '  File: ${task.filename}');
    _logger.info('NSFX-Engine',
        '  Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
    _logger.info('NSFX-Engine',
        '  Threads: $actualThreads (calculated=$calculatedThreads)');
    _logger.info('NSFX-Engine', '  Segments: $segmentCount');
    _logger.info('NSFX-Engine', '  Config mode: ${config.mode}');
    _logger.info('NSFX-Engine', '  Config threads: ${config.threads}');
    _logger.info('NSFX-Engine', '========================================');
    final semaphore = _taskSemaphores[task.id] = _Semaphore(actualThreads);

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
      _logger.info('NSFX-Engine',
          'Resuming download with ${task.segments.length} existing segments');
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
      final partFile =
          File('${tempDir.path}/${task.filename}.part${segment.index}');
      final segmentSize = segment.endByte - segment.startByte;

      if (await partFile.exists()) {
        final fileSize = await partFile.length();

        // 如果临时文件大小超过分段大小，截断它（可能是动态分段导致的）
        if (fileSize > segmentSize) {
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} temp file too large: $fileSize > $segmentSize, truncating');
          try {
            final raf = await partFile.open(mode: FileMode.writeOnlyAppend);
            await raf.truncate(segmentSize);
            await raf.close();
            // 截断后，设置为分段大小并标记为完成
            segment.downloadedBytes = segmentSize;
            segment.status = SegmentStatus.completed;
            restoredBytes += segmentSize;
            _logger.info('NSFX-Engine',
                'Segment ${segment.index} truncated and marked complete: $segmentSize bytes');
          } catch (e) {
            _logger.error('NSFX-Engine',
                'Failed to truncate segment ${segment.index}: $e');
            segment.downloadedBytes = 0;
            segment.status = SegmentStatus.pending;
          }
        } else if (fileSize == segmentSize) {
          // 只有文件大小完全等于分段大小才标记为完成
          segment.downloadedBytes = fileSize;
          segment.status = SegmentStatus.completed;
          restoredBytes += fileSize;
          _logger.debug('NSFX-Engine',
              'Segment ${segment.index} already completed ($fileSize bytes)');
        } else if (fileSize > 0) {
          // 部分下载，需要继续
          segment.downloadedBytes = fileSize;
          segment.status = SegmentStatus.pending;
          restoredBytes += fileSize;
          _logger.debug('NSFX-Engine',
              'Segment ${segment.index} partial: $fileSize/$segmentSize bytes, will resume');
        } else {
          // 文件为空，重新下载
          segment.downloadedBytes = 0;
          segment.status = SegmentStatus.pending;
        }
      } else {
        // 临时文件不存在
        segment.downloadedBytes = 0;
        if (segment.status == SegmentStatus.completed) {
          // 之前标记为完成但文件不存在，需要重新下载
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} marked complete but temp file missing, resetting');
          segment.status = SegmentStatus.pending;
        }
      }
    }

    if (restoredBytes > 0) {
      _logger.info('NSFX-Engine',
          'Restored ${(restoredBytes / 1024 / 1024).toStringAsFixed(2)} MB from temp files');
    }

    // 立即更新一次进度（基于内存计数器）
    task.downloadedSize = restoredBytes;
    if (task.totalSize > 0) {
      task.progress = (task.downloadedSize / task.totalSize) * 100;
    }
    onProgress(task);

    if (restoredBytes > 0) {
      final supportsResume =
          await _probeResumeRangeSupport(task, headers, fileSize);
      if (!supportsResume) {
        await _fallbackToSingleThread(
          task,
          headers,
          fileSize,
          tempDir,
          reason: 'range not supported',
        );
        return;
      }
    }

    // 进度更新定时器（仅用于速度计算和 ETA，不再读取文件）
    final progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (task.status == TaskStatus.downloading) {
        _calculateSpeed(task);
        onProgress(task);
      }
    });

    // 动态分段检查定时器（根据文件大小自适应间隔）
    final dynamicCheckInterval = task.totalSize > 1024 * 1024 * 1024
        ? const Duration(seconds: 10) // >1GB: 10秒，避免频繁检查大量分段
        : task.totalSize > 100 * 1024 * 1024
            ? const Duration(seconds: 5) // >100MB: 5秒
            : const Duration(seconds: 3); // <100MB: 3秒，小文件需要更快响应
    final dynamicSegmentTimer = Timer.periodic(dynamicCheckInterval, (_) {
      if (task.status == TaskStatus.downloading) {
        _checkAndSplitSlowSegments(task);
      }
    });

    try {
      // 使用信号量控制并发
      // 无限循环重试失败的分段，直到全部完成或用户取消
      int globalRetryRound = 0;
      const maxGlobalRetryRounds = 9999; // 防止极端情况下的无限循环
      // 总超时保护：防止服务器彻底不可用时无限卡住
      final downloadDeadline = DateTime.now().add(const Duration(hours: 24));

      while (globalRetryRound < maxGlobalRetryRounds) {
        if (_cancelledTasks[task.id] == true) {
          task.status = TaskStatus.cancelled;
          progressTimer.cancel();
          dynamicSegmentTimer.cancel();
          return;
        }

        if (_pausedTasks[task.id] == true) {
          task.status = TaskStatus.paused;
          progressTimer.cancel();
          dynamicSegmentTimer.cancel();
          return;
        }

        // 超时检查
        if (DateTime.now().isAfter(downloadDeadline)) {
          _logger.error('NSFX-Engine',
              'Download timeout after 24 hours: ${task.filename}');
          task.status = TaskStatus.failed;
          task.errorMessage = 'Download timeout after 24 hours';
          progressTimer.cancel();
          dynamicSegmentTimer.cancel();
          onError(task);
          return;
        }

        // 找出所有未完成的分段（pending 或 failed）
        final pendingSegments = task.segments
            .where((s) => s.status != SegmentStatus.completed)
            .toList();

        // 如果没有未完成的分段，退出循环
        if (pendingSegments.isEmpty) {
          break;
        }

        // 如果是重试轮次，记录日志
        if (globalRetryRound > 0) {
          final failedCount = task.segments
              .where((s) => s.status == SegmentStatus.failed)
              .length;
          _logger.info('NSFX-Engine',
              'Retry round $globalRetryRound: ${pendingSegments.length} segments pending, $failedCount failed');

          // 重置失败分段的状态为 pending
          for (final segment in pendingSegments) {
            if (segment.status == SegmentStatus.failed) {
              segment.status = SegmentStatus.pending;
              segment.retryCount = 0; // 重置重试计数，给予新的重试机会
            }
          }

          // 在重试轮次之间稍作等待，避免过于激进
          await Future.delayed(const Duration(milliseconds: 500));
        }

        final futures = <Future<bool>>[];

        // 立即为所有待处理的分段创建下载任务
        for (final segment in pendingSegments) {
          final tempFile =
              '${tempDir.path}/${task.filename}.part${segment.index}';

          // 立即添加到 futures 列表，不要在循环中等待
          futures.add(semaphore.run(() async {
            if (_cancelledTasks[task.id] == true) return false;
            if (_pausedTasks[task.id] == true) return false;

            segment.status = SegmentStatus.downloading;
            _logger.debug(
                'NSFX-Engine', 'Starting segment ${segment.index} download');

            return await _downloadSegmentInIsolate(
              task: task,
              segment: segment,
              headers: headers,
              tempFilePath: tempFile,
            );
          }));
        }

        _logger.info('NSFX-Engine',
            'Started ${futures.length} segment downloads concurrently (max $actualThreads threads)');

        // 等待所有分段完成
        await Future.wait(futures);

        if (_shouldFallbackToSingleThread(task)) {
          progressTimer.cancel();
          dynamicSegmentTimer.cancel();
          await _fallbackToSingleThread(
            task,
            headers,
            fileSize,
            tempDir,
            reason: 'resume failed',
          );
          return;
        }

        // 检查是否全部完成
        final allCompleted =
            task.segments.every((s) => s.status == SegmentStatus.completed);
        if (allCompleted) {
          break;
        }

        globalRetryRound++;
      }

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

      // 最终检查所有分段是否完成
      final allCompleted =
          task.segments.every((s) => s.status == SegmentStatus.completed);
      if (!allCompleted) {
        final failedCount =
            task.segments.where((s) => s.status == SegmentStatus.failed).length;
        task.status = TaskStatus.failed;
        task.errorMessage =
            '$failedCount segments failed after $globalRetryRound retry rounds';
        _logger.error('NSFX-Engine', 'Download failed: ${task.errorMessage}');
        onError(task);
        return;
      }

      // 合并前严格验证所有分段的临时文件
      task.status = TaskStatus.merging;
      onProgress(task);
      _logger.info(
          'NSFX-Engine', 'Verifying and merging segments: ${task.filename}');

      final verifyResult = await _verifyAllSegmentsBeforeMerge(task, tempDir);
      if (!verifyResult) {
        // 验证失败，有分段文件不完整
        final failedSegments = task.segments
            .where((s) => s.status == SegmentStatus.failed)
            .toList();
        task.status = TaskStatus.failed;
        task.errorMessage =
            '${failedSegments.length} segments incomplete or corrupted';
        _logger.error('NSFX-Engine', 'Merge aborted: ${task.errorMessage}');
        onError(task);
        return;
      }

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
    } catch (e) {
      // 下载或合并失败
      _logger.error(
          'NSFX-Engine', 'Download/Merge failed: ${task.filename} - $e');
      task.status = TaskStatus.failed;
      task.errorMessage = 'Failed: $e';
      onError(task);
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
      _logger.debug(
          'NSFX-Engine', 'Only 1 downloading segment, cannot compare');
      return;
    }

    // 计算平均剩余大小
    final totalRemaining = downloadingSegments.fold<int>(
        0, (sum, s) => sum + (s.size - s.downloadedBytes));
    final avgRemaining = totalRemaining / downloadingSegments.length;

    _logger.info('NSFX-Engine',
        'Dynamic segment check: ${downloadingSegments.length} downloading, avg remaining: ${(avgRemaining / 1024 / 1024).toStringAsFixed(2)} MB');

    // 找出剩余大小超过平均值 1.5 倍的分段（降低阈值）
    final slowSegments = downloadingSegments
        .where((s) => (s.size - s.downloadedBytes) > avgRemaining * 1.5)
        .where((s) =>
            (s.size - s.downloadedBytes) >
            5 * 1024 * 1024) // 剩余至少 5MB 才分割（降低阈值）
        .toList();

    if (slowSegments.isEmpty) {
      _logger.info('NSFX-Engine',
          'No slow segments found (threshold: ${(avgRemaining * 1.5 / 1024 / 1024).toStringAsFixed(2)} MB)');
      return;
    }

    _logger.info(
        'NSFX-Engine', 'Found ${slowSegments.length} slow segments to split');

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
      final partFile =
          File('${tempDir.path}/${task.filename}.part${slowSeg.index}');
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
            _logger.info('NSFX-Engine',
                'Segment ${slowSeg.index} truncated to $newSegmentSize bytes and marked complete');
          } catch (e) {
            _logger.error('NSFX-Engine',
                'Failed to truncate segment ${slowSeg.index}: $e');
            // 如果截断失败，恢复原状态
            slowSeg.endByte = oldEndByte;
            slowSeg.downloadedBytes = oldDownloadedBytes;
            task.downloadedSize +=
                (oldDownloadedBytes - slowSeg.downloadedBytes);
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
      _logger.info('NSFX-Engine',
          'Split $splitCount segments, total segments now: ${task.segments.length}');
    }
  }

  /// 启动新分段的下载
  void _startNewSegmentDownload(Task task, Segment segment) async {
    final tempDir = await _getTempDir(task);
    final tempFile = '${tempDir.path}/${task.filename}.part${segment.index}';
    final headers = _buildHeaders(task);

    // 新分段加入队列，使用同一任务的并发控制器，避免动态分段导致并发失控
    segment.status = SegmentStatus.pending;
    final semaphore = _taskSemaphores[task.id];
    if (semaphore == null) {
      _logger.warning('NSFX-Engine',
          'Semaphore missing for task ${task.id}, starting segment without limit');
      segment.status = SegmentStatus.downloading;
      await _downloadSegmentInIsolate(
        task: task,
        segment: segment,
        headers: headers,
        tempFilePath: tempFile,
      );
      return;
    }

    // ignore: unawaited_futures
    semaphore.run(() async {
      if (_cancelledTasks[task.id] == true || _pausedTasks[task.id] == true) {
        return false;
      }
      segment.status = SegmentStatus.downloading;
      return await _downloadSegmentInIsolate(
        task: task,
        segment: segment,
        headers: headers,
        tempFilePath: tempFile,
      );
    });
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
        // [关键修复] 每次重试前，从临时文件获取实际大小，而非依赖内存值
        int alreadyDownloaded = 0;
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          alreadyDownloaded = await tempFile.length();
          // 同步更新 segment 的内存值
          segment.downloadedBytes = alreadyDownloaded;
        }

        final expectedSize = segment.endByte - segment.startByte;

        // 如果临时文件已经完整，直接返回成功
        if (alreadyDownloaded >= expectedSize) {
          if (alreadyDownloaded > expectedSize) {
            // 文件过大，截断
            _logger.warning('NSFX-Engine',
                'Segment ${segment.index} temp file too large, truncating');
            final raf = await tempFile.open(mode: FileMode.writeOnlyAppend);
            await raf.truncate(expectedSize);
            await raf.close();
            alreadyDownloaded = expectedSize;
          }
          segment.downloadedBytes = expectedSize;
          segment.status = SegmentStatus.completed;
          _logger.debug('NSFX-Engine',
              'Segment ${segment.index} already complete from temp file');
          return true;
        }

        final actualStartByte = segment.startByte + alreadyDownloaded;

        final receivePort = ReceivePort();
        final progressPort = _progressPorts[task.id];

        final activeProxy = httpClient.getActiveProxySettings();
        final isolate = await Isolate.spawn(
          _isolateSegmentDownload,
          _IsolateParams(
            sendPort: receivePort.sendPort,
            progressPort: progressPort?.sendPort, // 传递进度端口
            url: task.url,
            tempFilePath: tempFilePath,
            startByte: actualStartByte, // 从已下载位置继续
            endByte: segment.endByte,
            headers: headers,
            connectionTimeout: config.connectionTimeout,
            alreadyDownloaded: alreadyDownloaded, // 传递已下载字节数
            taskId: task.id,
            segmentIndex: segment.index,
            proxyHost: activeProxy?.host,
            proxyPort: activeProxy?.port,
            proxyType: activeProxy?.type,
            proxyRequiresAuth: activeProxy?.supportsHttpBasicAuth ?? false,
            proxyUsername: activeProxy?.username,
            proxyPassword: activeProxy?.password,
            httpVersionPolicy: config.httpVersionPolicy,
            globalSpeedLimit: config.globalSpeedLimit > 0
                ? (config.globalSpeedLimit ~/ task.threadCount)
                    .clamp(1024, config.globalSpeedLimit)
                : 0, // 全局限速均分到每个分段
          ),
        );

        // 跟踪 Isolate
        _taskIsolates[task.id]?.add(isolate);

        final result = await receivePort.first as _IsolateResult;
        receivePort.close();

        // 从跟踪列表中移除
        _taskIsolates[task.id]?.remove(isolate);

        // [关键修复] 无论成功失败，都更新已下载字节数
        segment.downloadedBytes = result.downloadedBytes;

        if (result.success) {
          // 验证下载的字节数是否等于分段大小
          if (result.downloadedBytes == expectedSize) {
            segment.status = SegmentStatus.completed;
            _logger.debug('NSFX-Engine',
                'Segment ${segment.index} completed: ${result.downloadedBytes} bytes');
            return true;
          } else {
            // 下载的字节数不匹配，标记为失败
            _logger.warning('NSFX-Engine',
                'Segment ${segment.index} size mismatch after download: ${result.downloadedBytes}/$expectedSize');
            segment.status = SegmentStatus.failed;
            segment.lastError =
                'Size mismatch: ${result.downloadedBytes}/$expectedSize';
            return false;
          }
        } else {
          throw Exception(result.error ?? 'Unknown error');
        }
      } catch (e) {
        final errorText = e.toString();
        if (errorText.contains(_rangeNotSupportedError)) {
          segment.lastError = _rangeNotSupportedError;
          segment.status = SegmentStatus.failed;
          return false;
        }
        if (errorText.contains(_rangeNotSatisfiableError) ||
            errorText.contains('HTTP 416')) {
          segment.lastError = _rangeNotSatisfiableError;
          segment.status = SegmentStatus.failed;
          return false;
        }
        // 代理错误（502/503/504/407）→ 不重试，立即失败，让外层触发直连 fallback
        if (errorText.contains('PROXY_ERROR_')) {
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} proxy error: $errorText, triggering fallback');
          segment.lastError = errorText;
          segment.status = SegmentStatus.failed;
          // 通知 httpClient 切换到直连
          httpClient.switchToDirectOnProxyError();
          return false;
        }

        retryCount++;
        segment.retryCount = retryCount;
        segment.lastError = errorText;

        // 只在每10次重试时打印日志，避免日志刷屏
        if (retryCount % 10 == 1 || retryCount >= config.maxRetries) {
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} retry $retryCount/${config.maxRetries}: $e');
        }

        if (retryCount < config.maxRetries) {
          // IDM 风格：极短的重试延迟，快速恢复连接
          // 在不稳定网络下，快速重试比等待更有效
          // 前50次：几乎立即重试（20-50ms）
          // 50-200次：短暂延迟（50-100ms）
          // 200次以上：稍长延迟（150ms）
          int delayMs;
          if (retryCount <= 50) {
            delayMs = 20 + (retryCount ~/ 10) * 6; // 20-50ms
          } else if (retryCount <= 200) {
            delayMs = 50 + (retryCount - 50) ~/ 3; // 50-100ms
          } else {
            delayMs = 150; // 最多150ms
          }
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }

    segment.status = SegmentStatus.failed;
    return false;
  }

  /// Isolate 入口点 - 下载单个分段
  /// 注意: Dart Isolate 之间无法共享 HttpClient 实例（Isolate 内存隔离），
  /// 因此每个 Isolate 必须创建独立的 HttpClient。这是 Dart 语言层面的限制。
  static void _isolateSegmentDownload(_IsolateParams params) async {
    // params.startByte 已经是调整后的起始位置（segment.startByte + alreadyDownloaded）
    // 所以 remainingSize 就是 endByte - startByte，不需要再减 alreadyDownloaded
    final remainingSize = params.endByte - params.startByte;
    // 整个分段的预期大小 = 剩余量 + 已下载量
    final segmentTotalSize = remainingSize + params.alreadyDownloaded;
    int downloadedBytes = 0; // 本次下载的字节数（在外部定义，catch可访问）
    HttpClient? client;
    IOSink? sink;

    try {
      client = NsfxHttpClient.createRawHttpClient(
        httpVersionPolicy: params.httpVersionPolicy,
        connectionTimeout:
            Duration(seconds: params.connectionTimeout.clamp(5, 15)),
        idleTimeout: const Duration(seconds: 30),
        maxConnectionsPerHost: 4,
        autoUncompress: false,
      );
      // 连接超时：兼顾快速检测和慢服务器（如 Google Drive 需要 SSL + 重定向）
      // 连接复用优化：延长空闲超时，让同一服务器的后续请求复用 TCP 连接
      // 允许同一 host 多个连接（同一 Isolate 内的重试可以复用）

      // 应用代理配置（Isolate 内存隔离，必须在每个 Isolate 独立配置）
      if (params.proxyHost != null && params.proxyPort != null) {
        final proxyType = params.proxyType ?? 'http';
        final proxyDirective = proxyType == 'socks5'
            ? 'SOCKS5 ${params.proxyHost}:${params.proxyPort}'
            : 'PROXY ${params.proxyHost}:${params.proxyPort}';
        client.findProxy = (_) => proxyDirective;

        if (params.proxyRequiresAuth &&
            proxyType != 'socks5' &&
            params.proxyUsername != null &&
            params.proxyUsername!.isNotEmpty &&
            params.proxyPassword != null &&
            params.proxyPassword!.isNotEmpty) {
          client.addProxyCredentials(
            params.proxyHost!,
            params.proxyPort!,
            'Basic',
            HttpClientBasicCredentials(
              params.proxyUsername!,
              params.proxyPassword!,
            ),
          );
        }
      }

      final uri = Uri.parse(params.url);
      final request = await client.getUrl(uri);

      params.headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      // [优化] 如果已经下载完成了，直接返回成功，不需要建立连接
      if (remainingSize <= 0) {
        client.close();
        params.sendPort.send(_IsolateResult(
          success: true,
          downloadedBytes: params.alreadyDownloaded,
        ));
        return;
      }

      request.headers
          .set('Range', 'bytes=${params.startByte}-${params.endByte - 1}');

      final response = await request.close();

      if (response.statusCode == 200 && params.startByte > 0) {
        await response.drain();
        client.close();
        params.sendPort.send(_IsolateResult(
          success: false,
          error: _rangeNotSupportedError,
          downloadedBytes: params.alreadyDownloaded,
        ));
        return;
      }

      if (response.statusCode == 416) {
        await response.drain();
        client.close();
        params.sendPort.send(_IsolateResult(
          success: false,
          error: _rangeNotSatisfiableError,
          downloadedBytes: params.alreadyDownloaded,
        ));
        return;
      }

      if (response.statusCode != 206 && response.statusCode != 200) {
        await response.drain();
        client.close();
        // 标记代理错误状态码，主线程可据此触发 fallback
        final isProxyErr = (response.statusCode == 502 ||
            response.statusCode == 503 ||
            response.statusCode == 504 ||
            response.statusCode == 407);
        params.sendPort.send(_IsolateResult(
          success: false,
          error: isProxyErr
              ? 'PROXY_ERROR_${response.statusCode}'
              : 'HTTP ${response.statusCode}',
          downloadedBytes: params.alreadyDownloaded,
        ));
        return;
      }

      final file = File(params.tempFilePath);
      // 如果有已下载的数据，使用 append 模式；否则使用 writeOnly 模式
      sink = file.openWrite(
          mode: params.alreadyDownloaded > 0
              ? FileMode.append
              : FileMode.writeOnly);

      // 进度上报：每下载 64KB 或每 100ms 通知一次主线程
      int bufferedBytes = 0;
      const int bufferThreshold = 64 * 1024; // 64KB
      DateTime lastProgressTime = DateTime.now();
      const progressInterval = Duration(milliseconds: 100);

      // 全局限速：在 Isolate 内实现令牌桶式限速
      // globalSpeedLimit 是总限速，每个分段分配一份（由主线程传入）
      final int perSegmentLimit = params.globalSpeedLimit;
      int bytesThisSecond = 0;
      DateTime secondStart = DateTime.now();

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

        // 全局限速逻辑
        if (perSegmentLimit > 0) {
          bytesThisSecond += toWrite.length;
          final elapsed = DateTime.now().difference(secondStart);
          if (bytesThisSecond >= perSegmentLimit) {
            // 本秒配额用完，等待到下一秒
            final sleepMs = 1000 - elapsed.inMilliseconds;
            if (sleepMs > 10) {
              await Future.delayed(Duration(milliseconds: sleepMs));
            }
            bytesThisSecond = 0;
            secondStart = DateTime.now();
          } else if (elapsed.inMilliseconds >= 1000) {
            // 一秒过去了，重置计数
            bytesThisSecond = 0;
            secondStart = DateTime.now();
          }
        }

        // 达到阈值或时间间隔，发送进度通知
        final now = DateTime.now();
        if (bufferedBytes >= bufferThreshold ||
            now.difference(lastProgressTime) >= progressInterval) {
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
      client = null;

      await sink.flush();
      await sink.close();
      sink = null;

      final totalDownloaded = params.alreadyDownloaded + downloadedBytes;

      params.sendPort.send(_IsolateResult(
        success: totalDownloaded == segmentTotalSize,
        downloadedBytes: totalDownloaded,
        error: totalDownloaded != segmentTotalSize
            ? 'Size mismatch: $totalDownloaded/$segmentTotalSize'
            : null,
      ));
    } catch (e) {
      // [关键修复] 网络中断时，确保文件流被正确关闭，数据刷新到磁盘
      try {
        client?.close(force: true);
        if (sink != null) {
          await sink.flush();
          await sink.close();
        }
      } catch (_) {}

      // [关键修复] 返回实际已下载的字节数（包括本次下载的）
      final actualDownloaded = params.alreadyDownloaded + downloadedBytes;
      params.sendPort.send(_IsolateResult(
        success: false,
        error: e.toString(),
        downloadedBytes: actualDownloaded, // 返回实际字节数，而非传入参数
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
      _speedHistory.record(task.id, 0);
      return;
    }

    final durationInSeconds =
        now.difference(lastTime).inMicroseconds / 1000000.0;

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

        // 记录速度历史（供速度图表使用）
        _speedHistory.record(task.id, task.speed);
      }
    }

    // ---------------------------------------------------------
    // 强制校准进度：解决动态分段可能导致的进度漂移或双倍统计问题
    // 计算所有分段实际已下载量的总和
    final realTotalDownloaded =
        task.segments.fold<int>(0, (sum, s) => sum + s.downloadedBytes);

    // 如果累加器(task.downloadedSize)与实际总和(realTotalDownloaded)偏差超过阈值，则强制同步
    // 阈值按文件大小的 0.1% 计算，最小 256KB，避免小文件漏检或大文件误触发
    final driftThreshold = max(256 * 1024, (task.totalSize * 0.001).toInt());
    if ((task.downloadedSize - realTotalDownloaded).abs() > driftThreshold) {
      _logger.warning('NSFX-Engine',
          'Progress drift detected: ${task.downloadedSize} vs $realTotalDownloaded, calibrating');
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

  Future<bool> _probeResumeRangeSupport(
    Task task,
    Map<String, String> headers,
    int fileSize,
  ) async {
    try {
      final start = fileSize > 2 ? 1 : 0;
      final end = start + 1;
      final response = await httpClient.getRange(task.url, headers, start, end);
      final status = response.statusCode;
      await response.drain();
      if (status == 206) return true;
      if (status == 200 || status == 416) return false;
    } catch (e) {
      _logger.debug('NSFX-Engine', 'Resume range probe failed: $e');
    }
    return true;
  }

  bool _shouldFallbackToSingleThread(Task task) {
    for (final segment in task.segments) {
      if (segment.lastError == _rangeNotSupportedError ||
          segment.lastError == _rangeNotSatisfiableError) {
        return true;
      }
    }
    return false;
  }

  Future<void> _fallbackToSingleThread(
    Task task,
    Map<String, String> headers,
    int fileSize,
    Directory tempDir, {
    String? reason,
  }) async {
    _logger.warning(
      'NSFX-Engine',
      'Resume failed${reason != null ? ' ($reason)' : ''}, falling back to single thread',
    );

    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}

    task.segments.clear();
    task.downloadedSize = 0;
    task.progress = 0;
    task.threadCount = 1;
    await _singleThreadDownload(
      task,
      headers,
      supportsRange: false,
      totalSizeHint: fileSize,
    );
  }

  Future<void> _singleThreadDownload(
    Task task,
    Map<String, String> headers, {
    bool supportsRange = false,
    int? totalSizeHint,
  }) async {
    task.threadCount = 1;
    task.status = TaskStatus.downloading;

    final file = File(task.filepath);
    await file.parent.create(recursive: true);

    if (totalSizeHint != null && totalSizeHint > 0) {
      task.totalSize = totalSizeHint;
    }

    int existingLength = 0;
    if (await file.exists()) {
      existingLength = await file.length();
    }

    HttpClientResponse response;
    bool requestedRange = false;

    if (existingLength > 0 && supportsRange) {
      requestedRange = true;
      response = await _getRangeResponse(task.url, headers, existingLength,
          task.totalSize > 0 ? task.totalSize : null);

      if (response.statusCode == 416) {
        final totalFromRange = _parseTotalFromContentRange(
            response.headers.value('content-range'));
        await response.drain();
        if (totalFromRange != null && existingLength >= totalFromRange) {
          task.totalSize = totalFromRange;
          task.downloadedSize = totalFromRange;
          task.progress = 100;
          task.status = TaskStatus.completed;
          task.endTime = DateTime.now();
          onComplete(task);
          return;
        }
        existingLength = 0;
        requestedRange = false;
        await file.writeAsBytes(const [], mode: FileMode.write);
        response = await httpClient.get(task.url, headers);
      } else if (response.statusCode == 200) {
        // 服务器忽略 Range，重新下载
        await response.drain();
        existingLength = 0;
        requestedRange = false;
        await file.writeAsBytes(const [], mode: FileMode.write);
        response = await httpClient.get(task.url, headers);
      }
    } else {
      if (existingLength > 0 && !supportsRange) {
        existingLength = 0;
        await file.writeAsBytes(const [], mode: FileMode.write);
      }
      response = await httpClient.get(task.url, headers);
    }

    if (requestedRange) {
      if (response.statusCode != 206 && response.statusCode != 200) {
        await response.drain();
        throw HttpException('HTTP ${response.statusCode}');
      }
    } else {
      if (response.statusCode != 200 && response.statusCode != 206) {
        await response.drain();
        throw HttpException('HTTP ${response.statusCode}');
      }
    }

    if (requestedRange) {
      final totalFromRange =
          _parseTotalFromContentRange(response.headers.value('content-range'));
      if (totalFromRange != null) {
        task.totalSize = totalFromRange;
      } else if (response.contentLength > 0 && task.totalSize <= 0) {
        task.totalSize = existingLength + response.contentLength;
      }
    } else {
      if (response.contentLength > 0) {
        task.totalSize = response.contentLength;
      }
    }

    if (existingLength > 0) {
      task.downloadedSize = existingLength;
      if (task.totalSize > 0) {
        task.progress = (task.downloadedSize / task.totalSize) * 100;
      }
      onProgress(task);
    }

    final sink = file.openWrite(
        mode: existingLength > 0 ? FileMode.append : FileMode.writeOnly);
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
            task.eta =
                ((task.totalSize - task.downloadedSize) / task.speed).round();
          }
          onProgress(task);
        }
      }

      await sink.flush();
      await sink.close();

      final finalSize = await file.length();
      if (task.totalSize <= 0) {
        task.totalSize = finalSize;
      }
      task.downloadedSize = finalSize;

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

  Future<HttpClientResponse> _getRangeResponse(
    String url,
    Map<String, String> headers,
    int start,
    int? end,
  ) async {
    final uri = Uri.parse(url);
    final request = await httpClient.client.getUrl(uri);
    headers.forEach((key, value) {
      request.headers.set(key, value);
    });
    final rangeValue = (end != null && end > start)
        ? 'bytes=$start-${end - 1}'
        : 'bytes=$start-';
    request.headers.set('Range', rangeValue);
    return await request.close();
  }

  int? _parseTotalFromContentRange(String? contentRange) {
    if (contentRange == null) return null;
    final match = RegExp(r'bytes\s+\d+-\d+/(\d+|\*)').firstMatch(contentRange);
    if (match == null) return null;
    final totalStr = match.group(1);
    if (totalStr == null || totalStr == '*') return null;
    return int.tryParse(totalStr);
  }

  /// 合并分段前的严格验证
  Future<bool> _verifyAllSegmentsBeforeMerge(
      Task task, Directory tempDir) async {
    _logger.info('NSFX-Engine', 'Verifying all segments before merge...');

    bool allValid = true;
    int totalVerifiedBytes = 0;

    for (final segment in task.segments) {
      final partFile =
          File('${tempDir.path}/${task.filename}.part${segment.index}');
      final expectedSize = segment.endByte - segment.startByte;

      if (!await partFile.exists()) {
        _logger.error(
            'NSFX-Engine', 'Segment ${segment.index} temp file missing!');
        segment.status = SegmentStatus.failed;
        segment.lastError = 'Temp file missing';
        allValid = false;
        continue;
      }

      final actualSize = await partFile.length();

      if (actualSize > expectedSize) {
        // 文件过大（可能是动态分段导致的），尝试截断
        _logger.warning('NSFX-Engine',
            'Segment ${segment.index} file too large: $actualSize > $expectedSize, truncating...');
        try {
          final raf = await partFile.open(mode: FileMode.writeOnlyAppend);
          await raf.truncate(expectedSize);
          await raf.close();
          // 截断成功，验证通过
          segment.downloadedBytes = expectedSize;
          segment.status = SegmentStatus.completed;
          totalVerifiedBytes += expectedSize;
          _logger.info('NSFX-Engine',
              'Segment ${segment.index} truncated and verified: $expectedSize bytes OK');
          continue;
        } catch (e) {
          _logger.error(
              'NSFX-Engine', 'Failed to truncate segment ${segment.index}: $e');
          segment.status = SegmentStatus.failed;
          segment.lastError = 'Truncate failed: $e';
          allValid = false;
          continue;
        }
      } else if (actualSize < expectedSize) {
        // 文件过小，需要重新下载
        _logger.error('NSFX-Engine',
            'Segment ${segment.index} file too small: $actualSize < $expectedSize');
        segment.status = SegmentStatus.failed;
        segment.lastError = 'Size mismatch: $actualSize/$expectedSize';
        segment.downloadedBytes = actualSize;
        allValid = false;
        continue;
      }

      // 大小完全匹配，验证通过
      segment.downloadedBytes = actualSize;
      segment.status = SegmentStatus.completed;
      totalVerifiedBytes += actualSize;
      _logger.debug('NSFX-Engine',
          'Segment ${segment.index} verified: $actualSize bytes OK');
    }

    if (allValid) {
      _logger.info('NSFX-Engine',
          'All ${task.segments.length} segments verified, total: ${(totalVerifiedBytes / 1024 / 1024).toStringAsFixed(2)} MB');
    } else {
      final failedCount =
          task.segments.where((s) => s.status == SegmentStatus.failed).length;
      _logger.error('NSFX-Engine',
          'Verification failed: $failedCount segments have issues');
    }

    return allValid;
  }

  Future<void> _mergeSegments(Task task, Directory tempDir) async {
    final outputFile = File(task.filepath);
    await outputFile.parent.create(recursive: true);

    // 按分段起始位置排序，确保正确的合并顺序
    final sortedSegments = task.segments.toList()
      ..sort((a, b) => a.startByte.compareTo(b.startByte));

    final sink = outputFile.openWrite();
    int totalMergedBytes = 0;

    try {
      for (final segment in sortedSegments) {
        final partFile =
            File('${tempDir.path}/${task.filename}.part${segment.index}');
        if (await partFile.exists()) {
          // _verifyAllSegmentsBeforeMerge 已验证分段完整性，此处直接使用 segment.size
          final expectedSize = segment.endByte - segment.startByte;

          await sink.addStream(partFile.openRead());
          totalMergedBytes += expectedSize;

          // 删除临时文件，带重试机制
          await _deleteFileWithRetry(partFile);
        } else {
          _logger.error('NSFX-Engine',
              'Segment ${segment.index} temp file missing during merge');
          throw Exception('Segment ${segment.index} temp file missing');
        }
      }

      await sink.flush();
      await sink.close();

      // 验证合并的字节数
      if (totalMergedBytes != task.totalSize) {
        _logger.warning('NSFX-Engine',
            'Merged bytes mismatch: $totalMergedBytes != ${task.totalSize}');
      }

      // 验证最终文件大小
      final finalSize = await outputFile.length();
      if (finalSize != task.totalSize) {
        _logger.error('NSFX-Engine',
            'Final file size mismatch: $finalSize != ${task.totalSize}');
        // 删除损坏的文件
        await outputFile.delete();
        throw Exception(
            'Final file corrupted: size $finalSize != ${task.totalSize}');
      }

      _logger.info('NSFX-Engine',
          'Merge completed: ${task.filename}, size: ${(finalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // 删除临时目录，带重试机制
      if (await tempDir.exists()) {
        await _deleteDirWithRetry(tempDir);
      }
    } catch (e) {
      await sink.close();
      // 如果合并失败，删除可能损坏的输出文件
      if (await outputFile.exists()) {
        try {
          await outputFile.delete();
        } catch (_) {}
      }
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
          _logger.warning('NSFX-Engine',
              'Failed to delete file after $maxRetries attempts: ${file.path}');
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
          _logger.warning('NSFX-Engine',
              'Failed to delete directory after $maxRetries attempts: ${dir.path}');
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
    final userAgent = task.userAgent?.trim();
    final headers = <String, String>{
      'User-Agent': userAgent != null && userAgent.isNotEmpty
          ? userAgent
          : config.defaultUserAgent,
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
  final SendPort? progressPort;
  final String url;
  final String tempFilePath;
  final int startByte;
  final int endByte;
  final Map<String, String> headers;
  final int connectionTimeout;
  final int alreadyDownloaded;
  final String taskId;
  final int segmentIndex;
  final String? proxyHost;
  final int? proxyPort;
  final String? proxyType;
  final bool proxyRequiresAuth;
  final String? proxyUsername;
  final String? proxyPassword;
  final String httpVersionPolicy;
  final int globalSpeedLimit; // 全局限速（bytes/s），0 = 不限

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
    this.proxyHost,
    this.proxyPort,
    this.proxyType,
    this.proxyRequiresAuth = false,
    this.proxyUsername,
    this.proxyPassword,
    this.httpVersionPolicy = NsfxHttpVersionPolicy.auto,
    this.globalSpeedLimit = 0,
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
    // 需要等待，添加到队列
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
