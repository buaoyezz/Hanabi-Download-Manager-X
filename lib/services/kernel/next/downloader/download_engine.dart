import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:rhttp/rhttp.dart' as rhttp;
import '../models/task.dart';
import '../models/segment.dart';
import '../config/download_config.dart';
import 'http_client.dart';
import '../../../../services/speed_history_service.dart';
import '../../../app_logger_service.dart';

class DownloadEngine {
  static const String _rangeNotSupportedError = 'RANGE_NOT_SUPPORTED';
  static const String _rangeNotSatisfiableError = 'RANGE_NOT_SATISFIABLE';
  static Future<void>? _rhttpInitFuture;
  static const Set<String> _hopByHopHeaders = {
    'connection',
    'keep-alive',
    'proxy-connection',
    'transfer-encoding',
    'upgrade',
  };
  static final RegExp _invalidFileNameChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  static final RegExp _trailingDotOrSpace = RegExp(r'[. ]+$');
  static final Set<String> _reservedWindowsNames = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  final NsfxConfig config;
  final NsfxHttpClient httpClient;
  final void Function(Task) onProgress;
  final void Function(Task) onComplete;
  final void Function(Task) onError;
  final _logger = AppLoggerService();

  final Map<String, bool> _cancelledTasks = {};
  final Map<String, bool> _pausedTasks = {};
  // 任务级运行时状态（隔离、进度端口、并发控制与速度统计）
  final Map<String, List<Isolate>> _taskIsolates = {};
  final Map<String, ReceivePort> _progressPorts = {};
  final Map<String, _Semaphore> _taskSemaphores = {};
  final Set<String> _dynamicSplitTasksInFlight = {};

  final Map<String, int> _lastDownloaded = {};
  final Map<String, DateTime> _lastUpdateTime = {};

  // 速度历史服务（用于速度与 ETA 计算）
  final _speedHistory = SpeedHistoryService();

  DownloadEngine({
    required this.config,
    required this.httpClient,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });

  String? _resolveNegotiatedHttpVersion() {
    return httpClient.lastNegotiatedHttpVersion ??
        NsfxHttpClient.normalizeNegotiatedHttpVersion(
          httpClient.effectiveHttpVersionPolicy,
        );
  }

  // 下载入口：探测资源后选择单线程或多线程
  Future<void> startDownload(Task task) async {
    _cancelledTasks[task.id] = false;
    _pausedTasks[task.id] = false;
    _taskIsolates[task.id] = [];

    final progressPort = ReceivePort();
    _progressPorts[task.id] = progressPort;
    progressPort.listen((message) {
      if (message is _ProgressMessage) {
        _handleProgressMessage(task, message);
      }
    });

    try {
      _normalizeTaskFilePathForCurrentPlatform(task);
      _logger.info('NSFX-Engine', 'Starting download: ${task.filename}');
      task.status = TaskStatus.downloading;
      task.startTime = DateTime.now();
      task.effectiveHttpVersionPolicy = httpClient.effectiveHttpVersionPolicy;
      task.negotiatedHttpVersion = null;
      task.targetReachable = null;
      onProgress(task);

      final headers = _buildHeaders(task);
      final fileInfo = await httpClient.getFileInfo(task.url, headers);
      _logger.info('NSFX-Engine',
          'File info for ${task.filename}: size=${fileInfo.size}, supportsRange=${fileInfo.supportsRange}');
      task.effectiveHttpVersionPolicy = httpClient.effectiveHttpVersionPolicy;
      task.negotiatedHttpVersion = fileInfo.negotiatedHttpVersion;
      task.targetReachable = true;

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
      onProgress(task);

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
      final shouldBypassProxy = httpClient.shouldSwitchToDirectOnError(e);
      if (shouldBypassProxy || _isTargetConnectivityErrorText(errorText)) {
        task.targetReachable = false;
      }
      task.effectiveHttpVersionPolicy = httpClient.effectiveHttpVersionPolicy;
      task.negotiatedHttpVersion =
          _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
      if ((errorText.contains('HTTP 502') ||
              errorText.contains('HTTP 503') ||
              errorText.contains('HTTP 504') ||
              errorText.contains('HTTP 407') ||
              errorText.contains('PROXY_ERROR_') ||
              shouldBypassProxy) &&
          httpClient.config.proxy.enabled) {
        _logger.warning('NSFX-Engine',
            'Proxy error during download, retrying with direct connection: $e');
        httpClient.switchToDirectOnProxyError();
        try {
          task.status = TaskStatus.downloading;
          task.downloadedSize = 0;
          task.progress = 0;
          task.segments.clear();
          task.errorMessage = null;

          final headers = _buildHeaders(task);
          final fileInfo = await httpClient.getFileInfo(task.url, headers);
          task.effectiveHttpVersionPolicy =
              httpClient.effectiveHttpVersionPolicy;
          task.negotiatedHttpVersion = fileInfo.negotiatedHttpVersion;
          task.targetReachable = true;
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

      _lastDownloaded.remove(task.id);
      _lastUpdateTime.remove(task.id);
      _speedHistory.clear(task.id);

      final progressPort = _progressPorts.remove(task.id);
      progressPort?.close();

      final isolates = _taskIsolates.remove(task.id);
      if (isolates != null) {
        for (final isolate in isolates) {
          isolate.kill(priority: Isolate.immediate);
        }
      }
    }
  }

  // 处理分段进度增量消息
  void _handleProgressMessage(Task task, _ProgressMessage message) {
    if (message.segmentIndex < task.segments.length) {
      final segment = task.segments[message.segmentIndex];

      final segmentSize = segment.endByte - segment.startByte;
      final newDownloaded = segment.downloadedBytes + message.bytesDelta;

      if (newDownloaded > segmentSize) {
        final actualDelta = segmentSize - segment.downloadedBytes;
        if (actualDelta > 0) {
          segment.downloadedBytes = segmentSize;
          task.downloadedSize += actualDelta;
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} reached boundary, clamped: ${segment.downloadedBytes}/$segmentSize');
        }
      } else {
        segment.downloadedBytes = newDownloaded;
        task.downloadedSize += message.bytesDelta;
      }

      if (task.totalSize > 0) {
        task.progress = (task.downloadedSize / task.totalSize) * 100;
      }
    }
  }

  // 多线程分段下载入口
  Future<void> _isolateMultiThreadDownload(
      Task task, Map<String, String> headers, int fileSize) async {
    final (calculatedThreads, segmentCount) =
        DynamicSegmentConfig.calculate(fileSize, config);
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

    if (task.segments.isEmpty) {
      final segmentSize = fileSize ~/ segmentCount;
      for (int i = 0; i < segmentCount; i++) {
        final start = i * segmentSize;
        final end = (i == segmentCount - 1) ? fileSize : (i + 1) * segmentSize;
        task.segments.add(Segment(index: i, startByte: start, endByte: end));
      }
    } else {
      _logger.info('NSFX-Engine',
          'Resuming download with ${task.segments.length} existing segments');
      for (final segment in task.segments) {
        if (segment.status != SegmentStatus.completed) {
          segment.downloadedBytes = 0;
          segment.status = SegmentStatus.pending;
        }
      }
    }

    int restoredBytes = 0;
    for (final segment in task.segments) {
      final partFile =
          await _resolveSegmentPartFile(tempDir, task, segment.index);
      final segmentSize = segment.endByte - segment.startByte;

      if (await partFile.exists()) {
        final fileSize = await partFile.length();

        if (fileSize > segmentSize) {
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} temp file too large: $fileSize > $segmentSize, truncating');
          try {
            final raf = await partFile.open(mode: FileMode.writeOnlyAppend);
            await raf.truncate(segmentSize);
            await raf.close();
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
          segment.downloadedBytes = fileSize;
          segment.status = SegmentStatus.completed;
          restoredBytes += fileSize;
          _logger.debug('NSFX-Engine',
              'Segment ${segment.index} already completed ($fileSize bytes)');
        } else if (fileSize > 0) {
          segment.downloadedBytes = fileSize;
          segment.status = SegmentStatus.pending;
          restoredBytes += fileSize;
          _logger.debug('NSFX-Engine',
              'Segment ${segment.index} partial: $fileSize/$segmentSize bytes, will resume');
        } else {
          segment.downloadedBytes = 0;
          segment.status = SegmentStatus.pending;
        }
      } else {
        segment.downloadedBytes = 0;
        if (segment.status == SegmentStatus.completed) {
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

    final progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (task.status == TaskStatus.downloading) {
        _calculateSpeed(task);
        onProgress(task);
      }
    });

    final dynamicCheckInterval = task.totalSize > 1024 * 1024 * 1024
        ? const Duration(seconds: 10)
        : task.totalSize > 100 * 1024 * 1024
            ? const Duration(seconds: 5)
            : const Duration(seconds: 3);
    final dynamicSegmentTimer = Timer.periodic(dynamicCheckInterval, (_) {
      if (task.status == TaskStatus.downloading) {
        _checkAndSplitSlowSegments(task);
      }
    });

    try {
      int globalRetryRound = 0;
      const maxGlobalRetryRounds = 9999;
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

        final pendingSegments = task.segments
            .where((s) =>
                s.status == SegmentStatus.pending ||
                s.status == SegmentStatus.failed)
            .toList();

        if (pendingSegments.isEmpty) {
          final hasActiveDownloads = task.segments
              .any((s) => s.status == SegmentStatus.downloading);
          if (hasActiveDownloads) {
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }
          break;
        }

        if (globalRetryRound > 0) {
          final failedCount = task.segments
              .where((s) => s.status == SegmentStatus.failed)
              .length;
          _logger.info('NSFX-Engine',
              'Retry round $globalRetryRound: ${pendingSegments.length} segments pending, $failedCount failed');

          for (final segment in pendingSegments) {
            if (segment.status == SegmentStatus.failed) {
              segment.status = SegmentStatus.pending;
              segment.retryCount = 0;
            }
          }

          await Future.delayed(const Duration(milliseconds: 500));
        }

        final futures = <Future<bool>>[];

        for (final segment in pendingSegments) {
          final tempFile = _segmentPartFilePath(tempDir, task, segment.index);

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

        await Future.wait(futures);

        final hasDynamicSegmentsInFlight = task.segments
            .any((s) => s.status == SegmentStatus.downloading);
        if (hasDynamicSegmentsInFlight) {
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }

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

      task.status = TaskStatus.merging;
      onProgress(task);
      _logger.info(
          'NSFX-Engine', 'Verifying and merging segments: ${task.filename}');

      final verifyResult = await _verifyAllSegmentsBeforeMerge(task, tempDir);
      if (!verifyResult) {
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
      task.targetReachable = true;
      task.effectiveHttpVersionPolicy = httpClient.effectiveHttpVersionPolicy;
      task.negotiatedHttpVersion =
          _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;

      if (task.startTime != null && task.endTime != null) {
        final duration = task.endTime!.difference(task.startTime!).inSeconds;
        if (duration > 0) task.averageSpeed = task.totalSize / duration;
      }

      task.targetReachable = true;
      task.effectiveHttpVersionPolicy = httpClient.effectiveHttpVersionPolicy;
      task.negotiatedHttpVersion =
          _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
      _logger.info('NSFX-Engine', 'Download completed: ${task.filename}');
      onComplete(task);
    } catch (e) {
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

  // 动态分段：检测慢分段并拆分
  Future<void> _checkAndSplitSlowSegments(Task task) async {
    if (!config.enableDynamicSegments) {
      _logger.debug('NSFX-Engine', 'Dynamic segments disabled');
      return;
    }
    if (task.status != TaskStatus.downloading) return;
    if (!_dynamicSplitTasksInFlight.add(task.id)) {
      _logger.debug(
          'NSFX-Engine', 'Dynamic segment split already in progress');
      return;
    }

    try {
      final downloadingSegments = task.segments
          .where((s) => s.status == SegmentStatus.downloading)
          .toList();

      if (downloadingSegments.isEmpty) {
        _logger.debug('NSFX-Engine', 'No downloading segments');
        return;
      }

      if (downloadingSegments.length < 2) {
        _logger.debug(
            'NSFX-Engine', 'Only 1 downloading segment, cannot compare');
        return;
      }

      final totalRemaining = downloadingSegments.fold<int>(
          0, (sum, s) => sum + (s.size - s.downloadedBytes));
      final avgRemaining = totalRemaining / downloadingSegments.length;

      _logger.info('NSFX-Engine',
          'Dynamic segment check: ${downloadingSegments.length} downloading, avg remaining: ${(avgRemaining / 1024 / 1024).toStringAsFixed(2)} MB');

      final slowSegments = downloadingSegments
          .where((s) => (s.size - s.downloadedBytes) > avgRemaining * 1.5)
          .where((s) => (s.size - s.downloadedBytes) > 5 * 1024 * 1024)
          .toList();

      if (slowSegments.isEmpty) {
        _logger.info('NSFX-Engine',
            'No slow segments found (threshold: ${(avgRemaining * 1.5 / 1024 / 1024).toStringAsFixed(2)} MB)');
        return;
      }

      _logger.info(
          'NSFX-Engine', 'Found ${slowSegments.length} slow segments to split');

      if (task.segments.length >= 256) {
        _logger.warning('NSFX-Engine', 'Max segments (256) reached');
        return;
      }

      final tempDir = await _getTempDir(task);
      int splitCount = 0;

      for (final slowSeg in slowSegments) {
        if (task.segments.length >= 256 || splitCount >= 5) break;

        final remaining = slowSeg.size - slowSeg.downloadedBytes;
        if (remaining < 5 * 1024 * 1024) {
          continue;
        }

        final currentDownloaded = slowSeg.downloadedBytes;
        final midPoint =
            slowSeg.startByte + currentDownloaded + (remaining ~/ 2);

        final newSegment = Segment(
          index: task.segments.length,
          startByte: midPoint,
          endByte: slowSeg.endByte,
        );

        final oldEndByte = slowSeg.endByte;
        final oldDownloadedBytes = slowSeg.downloadedBytes;
        slowSeg.endByte = midPoint;

        final newSegmentSize = slowSeg.endByte - slowSeg.startByte;
        if (slowSeg.downloadedBytes > newSegmentSize) {
          final excessBytes = slowSeg.downloadedBytes - newSegmentSize;
          slowSeg.downloadedBytes = newSegmentSize;
          task.downloadedSize -= excessBytes;
          _logger.warning('NSFX-Engine',
              'Segment ${slowSeg.index} downloadedBytes ($oldDownloadedBytes) exceeds new size ($newSegmentSize), adjusted and reduced total by ${(excessBytes / 1024 / 1024).toStringAsFixed(2)} MB');
        }

        final partFile =
            await _resolveSegmentPartFile(tempDir, task, slowSeg.index);
        if (await partFile.exists()) {
          final fileSize = await partFile.length();

          if (fileSize > newSegmentSize) {
            _logger.warning('NSFX-Engine',
                'Segment ${slowSeg.index} temp file ($fileSize bytes) exceeds new size ($newSegmentSize bytes) after split, truncating');
            try {
              final raf = await partFile.open(mode: FileMode.writeOnlyAppend);
              await raf.truncate(newSegmentSize);
              await raf.close();
              slowSeg.status = SegmentStatus.completed;
              _logger.info('NSFX-Engine',
                  'Segment ${slowSeg.index} truncated to $newSegmentSize bytes and marked complete');
            } catch (e) {
              _logger.error('NSFX-Engine',
                  'Failed to truncate segment ${slowSeg.index}: $e');
              slowSeg.endByte = oldEndByte;
              slowSeg.downloadedBytes = oldDownloadedBytes;
              task.downloadedSize +=
                  (oldDownloadedBytes - slowSeg.downloadedBytes);
              continue;
            }
          }
        }

        task.segments.add(newSegment);
        splitCount++;

        _logger.info('NSFX-Engine',
            'Split segment ${slowSeg.index}: ${slowSeg.startByte}-$oldEndByte => ${slowSeg.startByte}-${slowSeg.endByte} + ${newSegment.startByte}-${newSegment.endByte} (remaining: ${(remaining / 1024 / 1024).toStringAsFixed(2)} MB, total segments: ${task.segments.length})');

        if (slowSeg.status != SegmentStatus.completed) {
          _startNewSegmentDownload(task, newSegment);
        }
      }

      if (splitCount > 0) {
        onProgress(task);
        _logger.info('NSFX-Engine',
            'Split $splitCount segments, total segments now: ${task.segments.length}');
      }
    } finally {
      _dynamicSplitTasksInFlight.remove(task.id);
    }
  }

  void _startNewSegmentDownload(Task task, Segment segment) async {
    final tempDir = await _getTempDir(task);
    final tempFile = _segmentPartFilePath(tempDir, task, segment.index);
    final headers = _buildHeaders(task);

    segment.status = SegmentStatus.downloading;
    final semaphore = _taskSemaphores[task.id];
    if (semaphore == null) {
      _logger.warning('NSFX-Engine',
          'Semaphore missing for task ${task.id}, starting segment without limit');
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
        segment.status = SegmentStatus.pending;
        return false;
      }
      return await _downloadSegmentInIsolate(
        task: task,
        segment: segment,
        headers: headers,
        tempFilePath: tempFile,
      );
    });
  }

  // 在 Isolate 中下载单个分段
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
        int alreadyDownloaded = 0;
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          alreadyDownloaded = await tempFile.length();
          segment.downloadedBytes = alreadyDownloaded;
        }

        final expectedSize = segment.endByte - segment.startByte;

        if (alreadyDownloaded >= expectedSize) {
          if (alreadyDownloaded > expectedSize) {
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

        task.effectiveHttpVersionPolicy = httpClient.effectiveHttpVersionPolicy;
        task.negotiatedHttpVersion =
            _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
        final activeProxy = httpClient.getActiveProxySettings();
        final isolate = await Isolate.spawn(
          _isolateSegmentDownload,
          _IsolateParams(
            sendPort: receivePort.sendPort,
            progressPort: progressPort?.sendPort,
            url: task.url,
            tempFilePath: tempFilePath,
            startByte: actualStartByte,
            endByte: segment.endByte,
            headers: headers,
            connectionTimeout: config.connectionTimeout,
            alreadyDownloaded: alreadyDownloaded,
            taskId: task.id,
            segmentIndex: segment.index,
            proxyHost: activeProxy?.host,
            proxyPort: activeProxy?.port,
            proxyType: activeProxy?.type,
            proxyRequiresAuth: activeProxy?.supportsHttpBasicAuth ?? false,
            proxyUsername: activeProxy?.username,
            proxyPassword: activeProxy?.password,
            httpVersionPolicy: httpClient.effectiveHttpVersionPolicy,
            globalSpeedLimit: config.globalSpeedLimit > 0
                ? (config.globalSpeedLimit ~/ task.threadCount)
                    .clamp(1024, config.globalSpeedLimit)
                : 0,
          ),
        );

        _taskIsolates[task.id]?.add(isolate);

        final result = await receivePort.first as _IsolateResult;
        receivePort.close();

        _taskIsolates[task.id]?.remove(isolate);

        segment.downloadedBytes = result.downloadedBytes;

        if (result.success) {
          if (result.downloadedBytes == expectedSize) {
            segment.status = SegmentStatus.completed;
            _logger.debug('NSFX-Engine',
                'Segment ${segment.index} completed: ${result.downloadedBytes} bytes');
            return true;
          } else {
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
        if (httpClient.shouldSwitchToDirectOnError(e)) {
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} proxy transport error: $errorText, triggering fallback');
          segment.lastError = 'PROXY_ERROR_TRANSPORT: $errorText';
          segment.status = SegmentStatus.failed;
          task.targetReachable = false;
          task.effectiveHttpVersionPolicy =
              httpClient.effectiveHttpVersionPolicy;
          task.negotiatedHttpVersion =
              _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
          httpClient.switchToDirectOnProxyError();
          return false;
        }

        if (errorText.contains('PROXY_ERROR_')) {
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} proxy error: $errorText, triggering fallback');
          segment.lastError = errorText;
          segment.status = SegmentStatus.failed;
          task.targetReachable = false;
          task.effectiveHttpVersionPolicy =
              httpClient.effectiveHttpVersionPolicy;
          task.negotiatedHttpVersion =
              _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
          httpClient.switchToDirectOnProxyError();
          return false;
        }

        retryCount++;
        segment.retryCount = retryCount;
        segment.lastError = errorText;

        if (retryCount % 10 == 1 || retryCount >= config.maxRetries) {
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} retry $retryCount/${config.maxRetries}: $e');
        }

        if (retryCount < config.maxRetries) {
          int delayMs;
          if (retryCount <= 50) {
            delayMs = 20 + (retryCount ~/ 10) * 6; // 20-50ms
          } else if (retryCount <= 200) {
            delayMs = 50 + (retryCount - 50) ~/ 3; // 50-100ms
          } else {
            delayMs = 150;
          }
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }

    segment.status = SegmentStatus.failed;
    return false;
  }

  static bool _usesRhttpTransport(String policy) {
    final normalized = NsfxHttpVersionPolicy.normalize(policy);
    return normalized == NsfxHttpVersionPolicy.http2Only ||
        normalized == NsfxHttpVersionPolicy.http3Only;
  }

  static Future<void> _ensureRhttpInitialized() {
    final existing = _rhttpInitFuture;
    if (existing != null) return existing;

    final initFuture = rhttp.Rhttp.init();
    _rhttpInitFuture = initFuture;
    return initFuture.catchError((error) {
      if (identical(_rhttpInitFuture, initFuture)) {
        _rhttpInitFuture = null;
      }
      throw error;
    });
  }

  static bool _isLocalHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  static Map<String, String> _sanitizeHeadersForPolicy(
    Map<String, String> headers,
    String httpVersionPolicy,
  ) {
    if (!_usesRhttpTransport(httpVersionPolicy)) {
      return headers;
    }

    final sanitized = Map<String, String>.from(headers);
    sanitized.removeWhere(
      (key, _) => _hopByHopHeaders.contains(key.toLowerCase()),
    );
    return sanitized;
  }

  static rhttp.ProxySettings? _toRhttpProxySettings(_IsolateParams params) {
    final host = Uri.tryParse(params.url)?.host ?? '';
    if (_isLocalHost(host)) {
      return const rhttp.ProxySettings.noProxy();
    }

    final proxyType = params.proxyType ?? 'http';
    if (proxyType == 'system') {
      // `null` means follow OS/system proxy.
      return null;
    }

    final proxyHost = params.proxyHost;
    final proxyPort = params.proxyPort;
    if (proxyHost == null || proxyPort == null || proxyHost.trim().isEmpty) {
      return const rhttp.ProxySettings.noProxy();
    }

    final scheme = proxyType == 'socks5' ? 'socks5' : 'http';
    String auth = '';
    if (params.proxyRequiresAuth &&
        proxyType != 'socks5' &&
        params.proxyUsername != null &&
        params.proxyUsername!.isNotEmpty &&
        params.proxyPassword != null &&
        params.proxyPassword!.isNotEmpty) {
      final user = Uri.encodeComponent(params.proxyUsername!);
      final pass = Uri.encodeComponent(params.proxyPassword!);
      auth = '$user:$pass@';
    }

    return rhttp.ProxySettings.proxy(
      '$scheme://$auth${proxyHost.trim()}:$proxyPort',
    );
  }

  static void _configureDartIoProxy(HttpClient client, _IsolateParams params) {
    final proxyType = params.proxyType ?? 'http';
    if (proxyType == 'system') {
      client.findProxy = (uri) {
        if (_isLocalHost(uri.host)) return 'DIRECT';
        return HttpClient.findProxyFromEnvironment(uri);
      };
      return;
    }

    if (params.proxyHost == null || params.proxyPort == null) {
      return;
    }

    final proxyDirective = proxyType == 'socks5'
        ? 'SOCKS5 ${params.proxyHost}:${params.proxyPort}'
        : 'PROXY ${params.proxyHost}:${params.proxyPort}';
    client.findProxy = (uri) {
      if (_isLocalHost(uri.host)) return 'DIRECT';
      return proxyDirective;
    };

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

  static Future<HttpClient> _createIsolateHttpClient(
      _IsolateParams params) async {
    if (_usesRhttpTransport(params.httpVersionPolicy)) {
      await _ensureRhttpInitialized();

      final normalized =
          NsfxHttpVersionPolicy.normalize(params.httpVersionPolicy);
      final versionPref = switch (normalized) {
        NsfxHttpVersionPolicy.http2Only => rhttp.HttpVersionPref.http2,
        NsfxHttpVersionPolicy.http3Only => rhttp.HttpVersionPref.http3,
        NsfxHttpVersionPolicy.http1Only => rhttp.HttpVersionPref.http1_1,
        _ => rhttp.HttpVersionPref.all,
      };

      final settings = rhttp.ClientSettings(
        httpVersionPref: versionPref,
        throwOnStatusCode: false,
        timeoutSettings: rhttp.TimeoutSettings(
          connectTimeout: Duration(
            seconds: params.connectionTimeout.clamp(5, 15),
          ),
          keepAliveTimeout: const Duration(seconds: 30),
        ),
        tlsSettings: const rhttp.TlsSettings(
          verifyCertificates: false,
        ),
        proxySettings: _toRhttpProxySettings(params),
      );

      final client = await rhttp.IoCompatibleClient.create(settings: settings);
      client.autoUncompress = false;
      return client;
    }

    final client = NsfxHttpClient.createRawHttpClient(
      httpVersionPolicy: params.httpVersionPolicy,
      connectionTimeout:
          Duration(seconds: params.connectionTimeout.clamp(5, 15)),
      idleTimeout: const Duration(seconds: 30),
      maxConnectionsPerHost: 4,
      autoUncompress: false,
    );
    _configureDartIoProxy(client, params);
    return client;
  }

  static void _isolateSegmentDownload(_IsolateParams params) async {
    final remainingSize = params.endByte - params.startByte;
    final segmentTotalSize = remainingSize + params.alreadyDownloaded;
    int downloadedBytes = 0;
    HttpClient? client;
    IOSink? sink;

    try {
      client = await _createIsolateHttpClient(params);

      final uri = Uri.parse(params.url);
      final request = await client.getUrl(uri);

      final requestHeaders =
          _sanitizeHeadersForPolicy(params.headers, params.httpVersionPolicy);
      requestHeaders.forEach((key, value) {
        request.headers.set(key, value);
      });

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
      sink = file.openWrite(
          mode: params.alreadyDownloaded > 0
              ? FileMode.append
              : FileMode.writeOnly);

      int bufferedBytes = 0;
      const int bufferThreshold = 64 * 1024; // 64KB
      DateTime lastProgressTime = DateTime.now();
      const progressInterval = Duration(milliseconds: 100);

      final int perSegmentLimit = params.globalSpeedLimit;
      int bytesThisSecond = 0;
      DateTime secondStart = DateTime.now();

      await for (final chunk in response) {
        final currentRemaining = remainingSize - downloadedBytes;
        if (currentRemaining <= 0) break;

        final toWrite = chunk.length > currentRemaining
            ? chunk.sublist(0, currentRemaining)
            : chunk;

        sink.add(toWrite);
        downloadedBytes += toWrite.length;
        bufferedBytes += toWrite.length;

        if (perSegmentLimit > 0) {
          bytesThisSecond += toWrite.length;
          final elapsed = DateTime.now().difference(secondStart);
          if (bytesThisSecond >= perSegmentLimit) {
            final sleepMs = 1000 - elapsed.inMilliseconds;
            if (sleepMs > 10) {
              await Future.delayed(Duration(milliseconds: sleepMs));
            }
            bytesThisSecond = 0;
            secondStart = DateTime.now();
          } else if (elapsed.inMilliseconds >= 1000) {
            bytesThisSecond = 0;
            secondStart = DateTime.now();
          }
        }

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

        if (remainingSize - downloadedBytes <= 0) break;
      }

      if (bufferedBytes > 0) {
        params.progressPort?.send(_ProgressMessage(
          taskId: params.taskId,
          segmentIndex: params.segmentIndex,
          bytesDelta: bufferedBytes,
        ));
      }

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
      try {
        client?.close(force: true);
        if (sink != null) {
          await sink.flush();
          await sink.close();
        }
      } catch (_) {}

      final actualDownloaded = params.alreadyDownloaded + downloadedBytes;
      params.sendPort.send(_IsolateResult(
        success: false,
        error: e.toString(),
        downloadedBytes: actualDownloaded,
      ));
    }
  }

  // 计算速度与 ETA（使用 EMA 平滑）
  void _calculateSpeed(Task task) {
    final now = DateTime.now();
    final currentDownloaded =
        task.downloadedSize;
    final lastDownloaded = _lastDownloaded[task.id];
    final lastTime = _lastUpdateTime[task.id];

    if (lastDownloaded == null || lastTime == null) {
      _lastDownloaded[task.id] = currentDownloaded;
      _lastUpdateTime[task.id] = now;
      task.speed = 0;
      _speedHistory.record(task.id, 0);
      return;
    }

    final durationInSeconds =
        now.difference(lastTime).inMicroseconds / 1000000.0;

    if (durationInSeconds >= 0.9) {
      final bytesDiff = currentDownloaded - lastDownloaded;

      if (bytesDiff >= 0) {
        final instantSpeed = bytesDiff / durationInSeconds;

        const double alpha = 0.2;

        if (task.speed == 0) {
          task.speed = instantSpeed;
        } else {
          task.speed = (task.speed * (1 - alpha)) + (instantSpeed * alpha);
        }

        if (instantSpeed > task.peakSpeed) {
          task.peakSpeed = instantSpeed;
        }

        _lastDownloaded[task.id] = currentDownloaded;
        _lastUpdateTime[task.id] = now;

        if (task.totalSize > 0 && task.speed > 0) {
          final remaining = task.totalSize - task.downloadedSize;
          task.eta = (remaining / task.speed).ceil();
        }

        _speedHistory.record(task.id, task.speed);
      }
    }

    // ---------------------------------------------------------
    final realTotalDownloaded =
        task.segments.fold<int>(0, (sum, s) => sum + s.downloadedBytes);

    final driftThreshold = max(256 * 1024, (task.totalSize * 0.001).toInt());
    if ((task.downloadedSize - realTotalDownloaded).abs() > driftThreshold) {
      _logger.warning('NSFX-Engine',
          'Progress drift detected: ${task.downloadedSize} vs $realTotalDownloaded, calibrating');
      task.downloadedSize = realTotalDownloaded;
    }

    if (task.totalSize > 0 && task.downloadedSize > task.totalSize) {
      _logger.warning('NSFX-Engine',
          'Downloaded size (${task.downloadedSize}) exceeds total size (${task.totalSize}), clamping');
      task.downloadedSize = task.totalSize;
    }

    if (task.totalSize > 0) {
      task.progress = (task.downloadedSize / task.totalSize) * 100;

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
      task.negotiatedHttpVersion =
          _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
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
      task.negotiatedHttpVersion =
          _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;

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
          task.targetReachable = true;
          task.effectiveHttpVersionPolicy =
              httpClient.effectiveHttpVersionPolicy;
          task.negotiatedHttpVersion =
              _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
          onComplete(task);
          return;
        }
        existingLength = 0;
        requestedRange = false;
        await file.writeAsBytes(const [], mode: FileMode.write);
        response = await httpClient.get(task.url, headers);
        task.negotiatedHttpVersion =
            _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
      } else if (response.statusCode == 200) {
        await response.drain();
        existingLength = 0;
        requestedRange = false;
        await file.writeAsBytes(const [], mode: FileMode.write);
        response = await httpClient.get(task.url, headers);
        task.negotiatedHttpVersion =
            _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
      }
    } else {
      if (existingLength > 0 && !supportsRange) {
        existingLength = 0;
        await file.writeAsBytes(const [], mode: FileMode.write);
      }
      response = await httpClient.get(task.url, headers);
      task.negotiatedHttpVersion =
          _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;
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
    task.targetReachable = true;
    task.effectiveHttpVersionPolicy = httpClient.effectiveHttpVersionPolicy;
    task.negotiatedHttpVersion =
        _resolveNegotiatedHttpVersion() ?? task.negotiatedHttpVersion;

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
    if (end != null && end > start) {
      return httpClient.getRange(url, headers, start, end);
    }
    return httpClient.get(url, {
      ...headers,
      'Range': 'bytes=$start-',
    });
  }

  int? _parseTotalFromContentRange(String? contentRange) {
    if (contentRange == null) return null;
    final match = RegExp(r'bytes\s+\d+-\d+/(\d+|\*)').firstMatch(contentRange);
    if (match == null) return null;
    final totalStr = match.group(1);
    if (totalStr == null || totalStr == '*') return null;
    return int.tryParse(totalStr);
  }

  Future<bool> _verifyAllSegmentsBeforeMerge(
      Task task, Directory tempDir) async {
    _logger.info('NSFX-Engine', 'Verifying all segments before merge...');

    bool allValid = true;
    int totalVerifiedBytes = 0;

    for (final segment in task.segments) {
      final partFile =
          await _resolveSegmentPartFile(tempDir, task, segment.index);
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
        _logger.warning('NSFX-Engine',
            'Segment ${segment.index} file too large: $actualSize > $expectedSize, truncating...');
        try {
          final raf = await partFile.open(mode: FileMode.writeOnlyAppend);
          await raf.truncate(expectedSize);
          await raf.close();
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
        _logger.error('NSFX-Engine',
            'Segment ${segment.index} file too small: $actualSize < $expectedSize');
        segment.status = SegmentStatus.failed;
        segment.lastError = 'Size mismatch: $actualSize/$expectedSize';
        segment.downloadedBytes = actualSize;
        allValid = false;
        continue;
      }

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

  // 合并分段临时文件
  Future<void> _mergeSegments(Task task, Directory tempDir) async {
    final outputFile = File(task.filepath);
    await outputFile.parent.create(recursive: true);

    final sortedSegments = task.segments.toList()
      ..sort((a, b) => a.startByte.compareTo(b.startByte));

    final sink = outputFile.openWrite();
    int totalMergedBytes = 0;

    try {
      for (final segment in sortedSegments) {
        final partFile =
            await _resolveSegmentPartFile(tempDir, task, segment.index);
        if (await partFile.exists()) {
          final expectedSize = segment.endByte - segment.startByte;

          await sink.addStream(partFile.openRead());
          totalMergedBytes += expectedSize;

          await _deleteFileWithRetry(partFile);
        } else {
          _logger.error('NSFX-Engine',
              'Segment ${segment.index} temp file missing during merge');
          throw Exception('Segment ${segment.index} temp file missing');
        }
      }

      await sink.flush();
      await sink.close();

      if (totalMergedBytes != task.totalSize) {
        _logger.warning('NSFX-Engine',
            'Merged bytes mismatch: $totalMergedBytes != ${task.totalSize}');
      }

      final finalSize = await outputFile.length();
      if (finalSize != task.totalSize) {
        _logger.error('NSFX-Engine',
            'Final file size mismatch: $finalSize != ${task.totalSize}');
        await outputFile.delete();
        throw Exception(
            'Final file corrupted: size $finalSize != ${task.totalSize}');
      }

      _logger.info('NSFX-Engine',
          'Merge completed: ${task.filename}, size: ${(finalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      if (await tempDir.exists()) {
        await _deleteDirWithRetry(tempDir);
      }
    } catch (e) {
      await sink.close();
      if (await outputFile.exists()) {
        try {
          await outputFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  // 带重试的文件删除
  Future<void> _deleteFileWithRetry(File file, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          _logger.warning('NSFX-Engine',
              'Failed to delete file after $maxRetries attempts: ${file.path}');
          return;
        }
        await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
      }
    }
  }

  // 带重试的目录删除
  Future<void> _deleteDirWithRetry(Directory dir, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
        return;
      } catch (e) {
        if (i == maxRetries - 1) {
          _logger.warning('NSFX-Engine',
              'Failed to delete directory after $maxRetries attempts: ${dir.path}');
          return;
        }
        await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
      }
    }
  }

  Future<Directory> _getTempDir(Task task) async {
    final parent = File(task.filepath).parent;
    final tempRoot = Directory('${parent.path}/.nsfx_temp');
    return Directory('${tempRoot.path}/${task.id}');
  }

  void _normalizeTaskFilePathForCurrentPlatform(Task task) {
    final normalizedName = _sanitizeFileNameForCurrentPlatform(task.filename);
    if (normalizedName == task.filename) return;

    final parentDir = File(task.filepath).parent.path;
    var candidateName = normalizedName;
    var candidatePath = '$parentDir/$candidateName';

    if (File(candidatePath).existsSync()) {
      final dot = candidateName.lastIndexOf('.');
      final base = dot > 0 ? candidateName.substring(0, dot) : candidateName;
      final ext = dot > 0 ? candidateName.substring(dot) : '';
      final shortId = task.id.length > 6 ? task.id.substring(0, 6) : task.id;
      candidateName = '${base}_$shortId$ext';
      candidatePath = '$parentDir/$candidateName';
    }

    _logger.warning(
      'NSFX-Engine',
      'Sanitized unsafe filename for filesystem: '
          '${task.filename} -> $candidateName',
    );
    task.filename = candidateName;
    task.filepath = candidatePath;
  }

  String _sanitizeFileNameForCurrentPlatform(String filename) {
    var cleaned = filename.trim();
    if (cleaned.isEmpty) return 'download.bin';

    if (Platform.isWindows) {
      cleaned = cleaned.replaceAll(_invalidFileNameChars, '_');
      cleaned = cleaned.replaceAll(_trailingDotOrSpace, '').trim();

      final dot = cleaned.lastIndexOf('.');
      var base = dot > 0 ? cleaned.substring(0, dot) : cleaned;
      final ext = dot > 0 ? cleaned.substring(dot) : '';

      if (base.isEmpty) {
        base = 'download';
      } else if (_reservedWindowsNames.contains(base.toUpperCase())) {
        base = '_$base';
      }

      cleaned = '$base$ext';
    }

    if (cleaned.isEmpty) return 'download.bin';

    const maxFileNameLength = 180;
    if (cleaned.length > maxFileNameLength) {
      final dot = cleaned.lastIndexOf('.');
      if (dot > 0 && dot < cleaned.length - 1) {
        final ext = cleaned.substring(dot);
        final keep = maxFileNameLength - ext.length;
        cleaned = keep > 1
            ? '${cleaned.substring(0, keep)}$ext'
            : cleaned.substring(0, maxFileNameLength);
      } else {
        cleaned = cleaned.substring(0, maxFileNameLength);
      }
    }

    return cleaned;
  }

  String _segmentPartFilePath(Directory tempDir, Task task, int segmentIndex) {
    return '${tempDir.path}/task_${task.id}.part$segmentIndex';
  }

  String _legacySegmentPartFilePath(
    Directory tempDir,
    Task task,
    int segmentIndex,
  ) {
    return '${tempDir.path}/${task.filename}.part$segmentIndex';
  }

  Future<File> _resolveSegmentPartFile(
    Directory tempDir,
    Task task,
    int segmentIndex,
  ) async {
    final primary = File(_segmentPartFilePath(tempDir, task, segmentIndex));
    if (await primary.exists()) return primary;

    final legacy =
        File(_legacySegmentPartFilePath(tempDir, task, segmentIndex));
    try {
      if (!await legacy.exists()) return primary;
    } catch (_) {
      return primary;
    }

    try {
      return await legacy.rename(primary.path);
    } catch (e) {
      _logger.warning(
        'NSFX-Engine',
        'Failed to migrate legacy temp segment file: ${legacy.path} -> '
            '${primary.path}; using legacy path, error=$e',
      );
      return legacy;
    }
  }

  void pauseDownload(String taskId) {
    _pausedTasks[taskId] = true;

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

  bool _isTargetConnectivityErrorText(String errorText) {
    final message = errorText.toLowerCase();
    return message.contains('connection refused') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('no route to host') ||
        message.contains('network is unreachable') ||
        message.contains('failed host lookup') ||
        message.contains('connection reset') ||
        message.contains('connection aborted') ||
        message.contains('proxy_error_') ||
        message.contains('handshake') ||
        message.contains('tls') ||
        message.contains('ssl');
  }
}

// Isolate 任务参数
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
  final int globalSpeedLimit;

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

// Isolate 结果
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

// 进度增量消息
class _ProgressMessage {
  final String taskId;
  final int segmentIndex;
  final int bytesDelta;

  _ProgressMessage({
    required this.taskId,
    required this.segmentIndex,
    required this.bytesDelta,
  });
}

// 简易信号量：控制并发
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
