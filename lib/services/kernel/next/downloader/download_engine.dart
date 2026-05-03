import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:rhttp/rhttp.dart' as rhttp;
import '../models/task.dart';
import '../models/segment.dart';
import '../config/download_config.dart';
import 'download_header_builder.dart';
import 'dynamic_segment_policy.dart';
import 'http_client.dart';
import 'proxy_runtime.dart';
import '../../../../services/speed_history_service.dart';
import '../../../app_logger_service.dart';

class DownloadEngine {
  static const String _rangeNotSupportedError = 'RANGE_NOT_SUPPORTED';
  static const String _rangeNotSatisfiableError = 'RANGE_NOT_SATISFIABLE';
  static const String _startupStatusMatchingHttp = 'matching_http_protocol';
  static Future<void>? _rhttpInitFuture;
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
  final Map<String, NsfxHttpClient> _taskHttpClients = {};
  final Map<String, List<Isolate>> _taskIsolates = {};
  final Map<String, ReceivePort> _progressPorts = {};
  final Map<String, _Semaphore> _taskSemaphores = {};
  final Map<String, Map<int, _SegmentRuntimeState>> _segmentRuntimeStates = {};
  final Map<String, Map<int, _SegmentExecutionHandle>> _taskSegmentExecutions =
      {};
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

  NsfxHttpClient _clientForTask(Task task) {
    return _taskHttpClients.putIfAbsent(task.id, () {
      final client = NsfxHttpClient(config);
      client.adoptAdaptivePolicyHint(task.url);
      task.httpPolicyDecisionReason = client.lastPolicyDecisionReason;
      return client;
    });
  }

  String? _resolveNegotiatedHttpVersion(Task task) {
    final client = _clientForTask(task);
    return client.lastNegotiatedHttpVersion ??
        NsfxHttpClient.normalizeObservedHttpVersion(
          task.negotiatedHttpVersion,
        ) ??
        NsfxHttpClient.normalizeNegotiatedHttpVersion(
          client.effectiveHttpVersionPolicy,
        );
  }

  void _applyFileInfoMetadata(
    Task task,
    NsfxHttpClient client,
    FileInfo fileInfo,
  ) {
    task.effectiveHttpVersionPolicy = client.effectiveHttpVersionPolicy;
    task.negotiatedHttpVersion = fileInfo.negotiatedHttpVersion;
    task.targetReachable = true;
    task.httpPolicyDecisionReason = client.lastPolicyDecisionReason;
    task.ifRangeValidator = fileInfo.ifRangeValidator;
    task.httpConnectionType = fileInfo.connectionType;
    _refreshResumeSafetyFromFileInfo(task, fileInfo);
  }

  void _syncHttpPolicyDecision(Task task, NsfxHttpClient client) {
    task.effectiveHttpVersionPolicy = client.effectiveHttpVersionPolicy;
    task.httpPolicyDecisionReason = client.lastPolicyDecisionReason;
    task.negotiatedHttpVersion =
        _resolveNegotiatedHttpVersion(task) ?? task.negotiatedHttpVersion;
  }

  void _clearConcurrencyDecision(Task task) {
    task.hostConcurrencyCap = null;
    task.hostConcurrencyReason = null;
  }

  void _recordConcurrencyDecision(
    Task task, {
    required int cap,
    required String reason,
    bool warning = false,
  }) {
    task.hostConcurrencyCap = cap;
    task.hostConcurrencyReason = reason;
    if (warning) {
      _logger.warning(
        'NSFX-Engine',
        'Host concurrency decision for ${task.filename}: $reason',
      );
    } else {
      _logger.info(
        'NSFX-Engine',
        'Host concurrency decision for ${task.filename}: $reason',
      );
    }
  }

  bool _taskHasPartialData(Task task) {
    if (task.downloadedSize > 0) return true;
    return task.segments.any((segment) => segment.downloadedBytes > 0);
  }

  void _refreshResumeSafetyFromFileInfo(Task task, FileInfo fileInfo) {
    if (fileInfo.hasStrongValidator) {
      task.resumeSafetyLevel = NsfxResumeSafetyLevel.strictValidator;
      return;
    }

    final hasPartialData = _taskHasPartialData(task);
    if (hasPartialData &&
        task.resumeDataOrigin == NsfxResumeDataOrigin.runtime &&
        fileInfo.supportsRange &&
        fileInfo.size > 0 &&
        task.resumeSafetyLevel != NsfxResumeSafetyLevel.verifiedNoValidator) {
      task.resumeSafetyLevel = NsfxResumeSafetyLevel.sessionOnly;
      return;
    }

    if (task.resumeSafetyLevel == NsfxResumeSafetyLevel.strictValidator) {
      task.resumeSafetyLevel = NsfxResumeSafetyLevel.unknown;
    }
  }

  String? _parallelDownloadBlockReason(
    Task task,
    FileInfo fileInfo, {
    int? storedTotalSize,
  }) {
    return NsfxParallelDownloadPolicy.parallelBlockReason(
      url: task.url,
      hasStrongValidator: fileInfo.hasStrongValidator,
      hasPartialProgress: _taskHasPartialData(task),
      resumeDataOrigin: task.resumeDataOrigin,
      resumeSafetyLevel: task.resumeSafetyLevel,
      supportsRange: fileInfo.supportsRange,
      storedTotalSize: storedTotalSize,
      observedTotalSize: fileInfo.size > 0 ? fileInfo.size : null,
    );
  }

  void _recordResumeDecision(
    Task task, {
    required String label,
    required String reason,
    bool blocked = false,
  }) {
    task.resumeDecisionLabel = label;
    task.resumeDecisionReason = reason;
    final message = 'Resume decision for ${task.filename}: [$label] $reason';
    if (blocked) {
      _logger.warning('NSFX-Engine', message);
    } else {
      _logger.info('NSFX-Engine', message);
    }
    onProgress(task);
  }

  void _setStartupStatus(
    Task task,
    String? statusKey, {
    bool notify = false,
  }) {
    if (task.startupStatusKey == statusKey) {
      return;
    }
    task.startupStatusKey = statusKey;
    if (notify) {
      onProgress(task);
    }
  }

  void _recordAllowedParallelDecision(
    Task task,
    FileInfo fileInfo, {
    int? storedTotalSize,
  }) {
    final hasPartialData = _taskHasPartialData(task);
    if (!hasPartialData) {
      _recordResumeDecision(
        task,
        label: 'Parallel Fresh',
        reason: 'Fresh ranged download can start in parallel.',
      );
      return;
    }

    if (fileInfo.hasStrongValidator) {
      _recordResumeDecision(
        task,
        label: 'Resume Validator',
        reason: 'Strong validator allows safe parallel resume.',
      );
      return;
    }

    if (task.resumeDataOrigin == NsfxResumeDataOrigin.runtime) {
      _recordResumeDecision(
        task,
        label: 'Resume Runtime',
        reason: 'Current-session partial data can continue in parallel without '
            'validator.',
      );
      return;
    }

    if (task.resumeSafetyLevel == NsfxResumeSafetyLevel.verifiedNoValidator &&
        storedTotalSize != null &&
        storedTotalSize > 0 &&
        storedTotalSize == fileInfo.size) {
      _recordResumeDecision(
        task,
        label: 'Resume Verified',
        reason: 'Persisted partial data matched current size and previously '
            'verified stable range behavior.',
      );
      return;
    }

    _recordResumeDecision(
      task,
      label: 'Parallel Resume',
      reason: 'Parallel resume allowed after current safety checks passed.',
    );
  }

  _SegmentRuntimeState _segmentRuntimeState(Task task, int segmentIndex) {
    final taskStates = _segmentRuntimeStates.putIfAbsent(task.id, () => {});
    return taskStates.putIfAbsent(segmentIndex, _SegmentRuntimeState.new);
  }

  void _registerSegmentExecution(
    String taskId,
    int segmentIndex,
    _SegmentExecutionHandle handle,
  ) {
    final taskHandles = _taskSegmentExecutions.putIfAbsent(taskId, () => {});
    taskHandles[segmentIndex] = handle;
  }

  Future<void> _releaseSegmentExecution(
    String taskId,
    int segmentIndex,
    _SegmentExecutionHandle handle,
  ) async {
    final taskHandles = _taskSegmentExecutions[taskId];
    if (taskHandles?[segmentIndex] == handle) {
      taskHandles?.remove(segmentIndex);
      if (taskHandles != null && taskHandles.isEmpty) {
        _taskSegmentExecutions.remove(taskId);
      }
    }
    await handle.dispose();
  }

  Future<bool> _requestSegmentStop(
    String taskId,
    int segmentIndex,
    String reason,
  ) async {
    final handle = _taskSegmentExecutions[taskId]?[segmentIndex];
    if (handle == null) return false;
    return handle.requestStop(reason);
  }

  bool _shouldPreferImmediateSingleConnection() {
    return config.threads.clamp(1, 64) <= 1;
  }

  Future<FileInfo?> _tryQuickStartupFileInfo(
    Task task,
    Map<String, String> headers,
  ) async {
    if (!NsfxStartupProbePolicy.shouldUseFastStart(
      hasPartialProgress: _taskHasPartialData(task),
      configuredThreads: config.threads,
    )) {
      return null;
    }

    final probeClient = NsfxHttpClient(config);
    probeClient.adoptAdaptivePolicyHint(task.url);

    try {
      final fileInfo = await probeClient.getFileInfo(
        task.url,
        headers,
        probeDeadline: NsfxStartupProbePolicy.quickMetadataProbeDeadline,
        strictProbeTimeoutCap:
            NsfxStartupProbePolicy.quickStrictProbeTimeoutCap,
      );
      if (fileInfo.size > 0) {
        _logger.info(
          'NSFX-Engine',
          'Quick metadata probe resolved startup file info for '
              '${task.filename}: size=${fileInfo.size}, '
              'supportsRange=${fileInfo.supportsRange}',
        );
        return fileInfo;
      }

      _logger.info(
        'NSFX-Engine',
        'Quick metadata probe did not resolve size for ${task.filename} '
            'within startup budget; starting direct transfer',
      );
      return null;
    } catch (e) {
      _logger.debug(
        'NSFX-Engine',
        'Quick metadata probe failed for ${task.filename}: $e',
      );
      return null;
    } finally {
      probeClient.close();
    }
  }

  Future<void> _continueDownloadWithFileInfo(
    Task task,
    Map<String, String> headers,
    FileInfo fileInfo, {
    int? storedResumeSize,
  }) async {
    _setStartupStatus(task, null);
    final client = _clientForTask(task);
    _logger.info('NSFX-Engine',
        'File info for ${task.filename}: size=${fileInfo.size}, supportsRange=${fileInfo.supportsRange}, protocol=${fileInfo.negotiatedHttpVersion ?? 'unknown'}, connection=${fileInfo.connectionType}, validator=${fileInfo.ifRangeValidator != null ? 'present' : 'missing'}');
    _applyFileInfoMetadata(task, client, fileInfo);

    if (fileInfo.size == 0) {
      _recordResumeDecision(
        task,
        label: 'Single Connection',
        reason: 'Remote size is unknown, so segmented resume is disabled.',
      );
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
      _recordResumeDecision(
        task,
        label: 'Single Connection',
        reason: 'Server does not support byte ranges, so parallel resume is '
            'unavailable.',
        blocked: _taskHasPartialData(task),
      );
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
      _recordResumeDecision(
        task,
        label: 'Single Connection',
        reason: 'File is too small to justify segmented transfer.',
      );
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

    final parallelBlockReason = _parallelDownloadBlockReason(
      task,
      fileInfo,
      storedTotalSize: storedResumeSize,
    );
    if (parallelBlockReason != null) {
      _recordResumeDecision(
        task,
        label: 'Resume Blocked',
        reason: parallelBlockReason,
        blocked: true,
      );
      _logger.info(
        'NSFX-Engine',
        'Parallel download disabled for ${task.filename}: $parallelBlockReason',
      );
      await _singleThreadDownload(
        task,
        headers,
        supportsRange: fileInfo.supportsRange,
        totalSizeHint: fileInfo.size,
      );
      return;
    }

    final (calculatedThreads, segmentCount) =
        DynamicSegmentConfig.calculate(fileInfo.size, config);
    final actualThreads = calculatedThreads.clamp(1, segmentCount);
    if (actualThreads <= 1 || segmentCount <= 1) {
      _recordResumeDecision(
        task,
        label: 'Single Connection',
        reason:
            'Segment planner resolved to one connection after current limits.',
      );
      _logger.info(
        'NSFX-Engine',
        'Segment plan resolves to a single connection '
            '(threads=$actualThreads, segments=$segmentCount), '
            'using direct single-thread download',
      );
      await _singleThreadDownload(
        task,
        headers,
        supportsRange: fileInfo.supportsRange,
        totalSizeHint: fileInfo.size,
      );
      return;
    }

    _recordAllowedParallelDecision(
      task,
      fileInfo,
      storedTotalSize: storedResumeSize,
    );
    _logger.info('NSFX-Engine',
        'Using Isolate-based multi-thread download for ${task.filename}');
    await _isolateMultiThreadDownload(
      task,
      _buildRangeHeaders(task, headers),
      fileInfo.size,
    );
  }

  // 下载入口：探测资源后选择单线程或多线程
  Future<void> startDownload(Task task) async {
    final client = _clientForTask(task);
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
      await _executeDownloadAttempt(task);
    } catch (e) {
      Object currentError = e;
      while (client.fallbackHttpPolicyOnTransferError(
        currentError,
        url: task.url,
      )) {
        _logger.warning(
          'NSFX-Engine',
          'Transfer failed under strict transport, retrying with downgraded '
              'HTTP policy (${client.effectiveHttpVersionPolicy}): '
              '$currentError',
        );
        _syncHttpPolicyDecision(task, client);
        _setStartupStatus(task, _startupStatusMatchingHttp);
        onProgress(task);

        try {
          task.status = TaskStatus.downloading;
          task.errorMessage = null;
          await _executeDownloadAttempt(task);
          return;
        } catch (retryError) {
          currentError = retryError;
        }
      }

      final errorText = currentError.toString();
      final shouldBypassProxy =
          client.shouldSwitchToDirectOnError(currentError);
      if (shouldBypassProxy || _isTargetConnectivityErrorText(errorText)) {
        task.targetReachable = false;
      }
      _syncHttpPolicyDecision(task, client);
      if ((errorText.contains('HTTP 502') ||
              errorText.contains('HTTP 503') ||
              errorText.contains('HTTP 504') ||
              errorText.contains('HTTP 407') ||
              errorText.contains('PROXY_ERROR_') ||
              shouldBypassProxy) &&
          client.config.proxy.enabled) {
        _logger.warning(
            'NSFX-Engine',
            'Proxy error during download, retrying with direct connection: '
                '$currentError');
        client.switchToDirectOnProxyError();
        try {
          task.status = TaskStatus.downloading;
          task.downloadedSize = 0;
          task.progress = 0;
          task.segments.clear();
          task.errorMessage = null;

          final headers = _buildHeaders(task);
          if (_shouldPreferImmediateSingleConnection()) {
            await _singleThreadDownload(
              task,
              headers,
              supportsRange: null,
            );
            return;
          }
          final fileInfo = await client.getFileInfo(task.url, headers);
          _applyFileInfoMetadata(task, client, fileInfo);
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
        _logger.error(
            'NSFX-Engine', 'Download failed: ${task.filename} - $currentError');
        task.status = TaskStatus.failed;
        _setStartupStatus(task, null);
        task.errorMessage = currentError.toString();
        onError(task);
      }
    } finally {
      _cancelledTasks.remove(task.id);
      _pausedTasks.remove(task.id);
      _taskSemaphores.remove(task.id);
      final taskClient = _taskHttpClients.remove(task.id);
      taskClient?.close();

      _lastDownloaded.remove(task.id);
      _lastUpdateTime.remove(task.id);
      _speedHistory.clear(task.id);
      _segmentRuntimeStates.remove(task.id);
      final executionHandles = _taskSegmentExecutions.remove(task.id);
      if (executionHandles != null) {
        for (final handle in executionHandles.values) {
          await handle.dispose();
        }
      }

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

  Future<void> _executeDownloadAttempt(Task task) async {
    final client = _clientForTask(task);
    final hasPartialData = _taskHasPartialData(task);
    final storedResumeSize =
        hasPartialData && task.totalSize > 0 ? task.totalSize : null;
    _normalizeTaskFilePathForCurrentPlatform(task);
    _logger.info('NSFX-Engine', 'Starting download: ${task.filename}');
    task.status = TaskStatus.downloading;
    task.startTime = DateTime.now();
    task.effectiveHttpVersionPolicy = client.effectiveHttpVersionPolicy;
    task.negotiatedHttpVersion = null;
    task.targetReachable = null;
    task.httpPolicyDecisionReason = client.lastPolicyDecisionReason;
    _setStartupStatus(task, _startupStatusMatchingHttp);
    task.ifRangeValidator = null;
    task.httpConnectionType = null;
    _clearConcurrencyDecision(task);
    onProgress(task);

    final headers = _buildHeaders(task);
    if (_shouldPreferImmediateSingleConnection()) {
      _setStartupStatus(task, null);
      _recordResumeDecision(
        task,
        label: 'Single Connection',
        reason:
            'Configured thread limit prefers the single-connection fast path.',
      );
      _logger.info(
        'NSFX-Engine',
        'Single-thread fast path enabled, starting direct download without '
            'metadata probe',
      );
      await _singleThreadDownload(
        task,
        headers,
        supportsRange: null,
      );
      return;
    }

    if (!hasPartialData &&
        NsfxStartupProbePolicy.shouldUseFastStart(
          hasPartialProgress: false,
          configuredThreads: config.threads,
        )) {
      final quickFileInfo = await _tryQuickStartupFileInfo(task, headers);
      if (quickFileInfo == null) {
        _setStartupStatus(task, null);
        _recordResumeDecision(
          task,
          label: 'Fast Start',
          reason: 'Metadata probe exceeded the startup budget, so the real '
              'transfer started immediately and file size will be learned '
              'from response headers.',
        );
        await _singleThreadDownload(
          task,
          headers,
          supportsRange: null,
        );
        return;
      }
      client.adoptAdaptivePolicyHint(task.url);
      await _continueDownloadWithFileInfo(
        task,
        headers,
        quickFileInfo,
        storedResumeSize: storedResumeSize,
      );
      return;
    }

    final fileInfo = await client.getFileInfo(task.url, headers);
    await _continueDownloadWithFileInfo(
      task,
      headers,
      fileInfo,
      storedResumeSize: storedResumeSize,
    );
  }

  // 处理分段进度增量消息
  void _handleProgressMessage(Task task, _ProgressMessage message) {
    if (message.segmentIndex < task.segments.length) {
      final segment = task.segments[message.segmentIndex];
      final runtimeState = _segmentRuntimeState(task, segment.index);
      final now = DateTime.now();

      final segmentSize = segment.endByte - segment.startByte;
      final newDownloaded = segment.downloadedBytes + message.bytesDelta;
      var actualDelta = message.bytesDelta;

      if (newDownloaded > segmentSize) {
        actualDelta = segmentSize - segment.downloadedBytes;
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

      if (actualDelta > 0) {
        task.resumeDataOrigin = NsfxResumeDataOrigin.runtime;
        if (task.ifRangeValidator == null) {
          task.resumeSafetyLevel = NsfxResumeSafetyLevel.verifiedNoValidator;
        }
        final lastProgressAt = runtimeState.lastProgressAt;
        if (lastProgressAt != null) {
          final elapsed =
              now.difference(lastProgressAt).inMicroseconds / 1000000.0;
          if (elapsed >= 0.05) {
            final instantSpeed = actualDelta / elapsed;
            const alpha = 0.30;
            segment.speed = segment.speed <= 0
                ? instantSpeed
                : (segment.speed * (1 - alpha)) + (instantSpeed * alpha);
          }
        }
        runtimeState.lastProgressAt = now;
      }

      if (segment.downloadedBytes >= segmentSize) {
        segment.speed = 0;
      }

      if (task.totalSize > 0) {
        task.progress = (task.downloadedSize / task.totalSize) * 100;
      }
    }
  }

  // 多线程分段下载入口
  Future<void> _isolateMultiThreadDownload(
      Task task, Map<String, String> headers, int fileSize) async {
    final client = _clientForTask(task);
    final (calculatedThreads, segmentCount) =
        DynamicSegmentConfig.calculate(fileSize, config);
    final plannedThreads = calculatedThreads.clamp(1, segmentCount);
    final actualThreads = NsfxHttpClient.suggestedMaxConcurrencyForUrl(
      task.url,
      requested: plannedThreads,
    );
    task.threadCount = actualThreads;
    _logger.info('NSFX-Engine', '========================================');
    _logger.info('NSFX-Engine', 'Multi-thread download configuration:');
    _logger.info('NSFX-Engine', '  File: ${task.filename}');
    _logger.info('NSFX-Engine',
        '  Size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
    _logger.info('NSFX-Engine',
        '  Threads: $actualThreads (calculated=$calculatedThreads)');
    if (actualThreads < plannedThreads) {
      _logger.info(
        'NSFX-Engine',
        '  Host strategy cap applied: $plannedThreads -> $actualThreads',
      );
    }
    _logger.info('NSFX-Engine', '  Segments: $segmentCount');
    _logger.info('NSFX-Engine', '  Config mode: ${config.mode}');
    _logger.info('NSFX-Engine', '  Config threads: ${config.threads}');
    _logger.info('NSFX-Engine', '========================================');
    if (actualThreads < plannedThreads) {
      _recordConcurrencyDecision(
        task,
        cap: actualThreads,
        reason: 'Cached host concurrency cap applied: requested '
            '$plannedThreads, starting with $actualThreads because previous '
            'higher concurrency attempts on this host failed.',
      );
      onProgress(task);
    } else {
      _clearConcurrencyDecision(task);
    }
    final semaphore = _taskSemaphores[task.id] = _Semaphore(actualThreads);
    int retryConcurrency = actualThreads;

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
      final resumeProbe =
          await _probeResumeCompatibility(task, headers, fileSize);
      if (!resumeProbe.compatible) {
        task.resumeSafetyLevel = NsfxResumeSafetyLevel.unknown;
        _recordResumeDecision(
          task,
          label: 'Resume Blocked',
          reason: resumeProbe.failureReason ??
              'Resume compatibility probe failed after reload.',
          blocked: true,
        );
        _failTaskPreservingSegments(
          task,
          resumeProbe.failureReason ??
              'Server no longer honors range requests during resume; kept '
                  'partial segments instead of discarding progress.',
        );
        return;
      }
      if (resumeProbe.verifiedStableBehavior && task.ifRangeValidator == null) {
        task.resumeSafetyLevel = NsfxResumeSafetyLevel.verifiedNoValidator;
        _recordResumeDecision(
          task,
          label: 'Resume Verified',
          reason: 'Resume probe confirmed stable byte-range behavior for the '
              'current resource.',
        );
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
      const maxGlobalRetryRounds = NsfxRetryPolicy.defaultMaxGlobalRetryRounds;
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
          final hasActiveDownloads =
              task.segments.any((s) => s.status == SegmentStatus.downloading);
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
          _logger.info(
              'NSFX-Engine',
              'Retry round $globalRetryRound: ${pendingSegments.length} '
                  'segments pending, $failedCount failed, concurrency='
                  '$retryConcurrency');

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

        final roundFailedCount = pendingSegments
            .where((segment) => segment.status == SegmentStatus.failed)
            .length;
        final roundCompletedCount = pendingSegments
            .where((segment) => segment.status == SegmentStatus.completed)
            .length;

        if (roundFailedCount > 0 && retryConcurrency > 1) {
          final shouldReduceConcurrency = roundCompletedCount == 0 ||
              roundFailedCount >= roundCompletedCount;
          if (shouldReduceConcurrency) {
            final nextConcurrency = max(1, retryConcurrency ~/ 2);
            if (nextConcurrency != retryConcurrency) {
              retryConcurrency = nextConcurrency;
              semaphore.updateLimit(retryConcurrency);
              task.threadCount = retryConcurrency;
              NsfxHttpClient.rememberHostConcurrencyCap(
                task.url,
                retryConcurrency,
              );
              _recordConcurrencyDecision(
                task,
                cap: retryConcurrency,
                reason: 'Adaptive host concurrency cap learned after '
                    '$roundFailedCount failures in the latest round; future '
                    'downloads on this host will start capped at '
                    '$retryConcurrency.',
                warning: true,
              );
              _logger.warning(
                'NSFX-Engine',
                'Reduced segment concurrency to $retryConcurrency after '
                    '$roundFailedCount failures in the latest round',
              );
              onProgress(task);
            }
          }
        }

        final hasDynamicSegmentsInFlight =
            task.segments.any((s) => s.status == SegmentStatus.downloading);
        if (hasDynamicSegmentsInFlight) {
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }

        if (_shouldAbortParallelResume(task)) {
          progressTimer.cancel();
          dynamicSegmentTimer.cancel();
          _failTaskPreservingSegments(
            task,
            _parallelResumeFailureMessage(task),
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

      _markTaskCompleted(task, client: client);
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
      _logger.debug('NSFX-Engine', 'Dynamic segment split already in progress');
      return;
    }

    try {
      final downloadingSegments = task.segments
          .where(
              (s) => s.status == SegmentStatus.downloading && s.remaining > 0)
          .toList();

      if (downloadingSegments.isEmpty) {
        _logger.debug('NSFX-Engine', 'No downloading segments');
        return;
      }

      if (task.segments.length >= 256) {
        _logger.warning('NSFX-Engine', 'Max segments (256) reached');
        return;
      }

      final now = DateTime.now();
      final semaphore = _taskSemaphores[task.id];
      final maxConcurrent = semaphore?.maxConcurrent ?? task.threadCount;
      final snapshots = downloadingSegments.map((segment) {
        final runtimeState = _segmentRuntimeState(task, segment.index);
        final lastProgressAt = runtimeState.lastProgressAt;
        final lastSplitAt = runtimeState.lastSplitAt;
        return DynamicSplitSnapshot(
          segmentIndex: segment.index,
          remainingBytes: segment.remaining,
          speedBytesPerSecond: segment.speed,
          idleFor: lastProgressAt == null
              ? Duration.zero
              : now.difference(lastProgressAt),
          sinceLastSplit: lastSplitAt == null
              ? const Duration(days: 365)
              : now.difference(lastSplitAt),
        );
      }).toList();
      final splitPlans = DynamicSegmentPolicy.plan(
        snapshots: snapshots,
        maxConcurrent: maxConcurrent,
        totalSegments: task.segments.length,
      );

      if (splitPlans.isEmpty) {
        _logger.debug(
          'NSFX-Engine',
          'Dynamic split check found no throughput/tail candidates',
        );
        return;
      }

      _logger.info(
        'NSFX-Engine',
        'Dynamic split check selected ${splitPlans.length} candidate(s) '
            'with maxConcurrent=$maxConcurrent',
      );

      final tempDir = await _getTempDir(task);
      int splitCount = 0;

      for (final plan in splitPlans) {
        if (task.segments.length >= 256) break;

        Segment? targetSegment;
        for (final segment in task.segments) {
          if (segment.index == plan.segmentIndex) {
            targetSegment = segment;
            break;
          }
        }
        final slowSeg = targetSegment;
        if (slowSeg == null || slowSeg.status != SegmentStatus.downloading) {
          continue;
        }

        final remaining = slowSeg.remaining;
        if (remaining < DynamicSegmentPolicy.minSplitBytes * 2) continue;

        final stealBytes = min(
          max(plan.stealBytes, DynamicSegmentPolicy.minSplitBytes),
          remaining - DynamicSegmentPolicy.minSplitBytes,
        );
        if (stealBytes <= 0) continue;

        final keepBytes = remaining - stealBytes;
        final currentDownloaded = slowSeg.downloadedBytes;
        final splitStart = slowSeg.startByte + currentDownloaded + keepBytes;
        if (splitStart <= slowSeg.startByte + currentDownloaded ||
            splitStart >= slowSeg.endByte) {
          continue;
        }

        final newSegment = Segment(
          index: task.segments.length,
          startByte: splitStart,
          endByte: slowSeg.endByte,
        );

        final oldEndByte = slowSeg.endByte;
        slowSeg.endByte = splitStart;

        final partFile =
            await _resolveSegmentPartFile(tempDir, task, slowSeg.index);
        if (await partFile.exists()) {
          final fileSize = await partFile.length();
          final expectedSize = slowSeg.size;
          if (fileSize > expectedSize) {
            _logger.warning(
                'NSFX-Engine',
                'Segment ${slowSeg.index} temp file ($fileSize bytes) exceeds '
                    'new size ($expectedSize bytes) after split, truncating');
            try {
              final raf = await partFile.open(mode: FileMode.writeOnlyAppend);
              await raf.truncate(expectedSize);
              await raf.close();
              _logger.info('NSFX-Engine',
                  'Segment ${slowSeg.index} truncated to $expectedSize bytes after dynamic split');
            } catch (e) {
              _logger.error('NSFX-Engine',
                  'Failed to truncate segment ${slowSeg.index}: $e');
              slowSeg.endByte = oldEndByte;
              continue;
            }
          }
        }

        task.segments.add(newSegment);
        _segmentRuntimeState(task, slowSeg.index).lastSplitAt = now;
        _segmentRuntimeState(task, newSegment.index).lastSplitAt = now;

        final stopSent = await _requestSegmentStop(
          task.id,
          slowSeg.index,
          'split',
        );
        if (!stopSent) {
          _logger.warning(
            'NSFX-Engine',
            'Segment ${slowSeg.index} had no active execution handle during '
                'tail steal; split will apply on the next retry boundary',
          );
        }
        splitCount++;

        _logger.info(
          'NSFX-Engine',
          'Tail steal on segment ${slowSeg.index} (${plan.reason}): '
              '${slowSeg.startByte}-$oldEndByte => '
              '${slowSeg.startByte}-${slowSeg.endByte} + '
              '${newSegment.startByte}-${newSegment.endByte} '
              '(speed=${(slowSeg.speed / 1024 / 1024).toStringAsFixed(2)} MB/s, '
              'remaining=${(remaining / 1024 / 1024).toStringAsFixed(2)} MB, '
              'steal=${(stealBytes / 1024 / 1024).toStringAsFixed(2)} MB, '
              'segments=${task.segments.length})',
        );

        _startNewSegmentDownload(task, newSegment);
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
    final headers = _buildRangeHeaders(task, _buildHeaders(task));

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

  Future<_SegmentExecutionHandle> _spawnSegmentExecution({
    required Task task,
    required Segment segment,
    required Map<String, String> headers,
    required String tempFilePath,
    required int alreadyDownloaded,
  }) async {
    final client = _clientForTask(task);
    final receivePort = ReceivePort();
    final readyCompleter = Completer<SendPort>();
    final resultCompleter = Completer<_IsolateResult>();
    late final StreamSubscription<dynamic> subscription;
    subscription = receivePort.listen((message) {
      if (message is _IsolateControlReady) {
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete(message.controlPort);
        }
        return;
      }
      if (message is _IsolateResult && !resultCompleter.isCompleted) {
        resultCompleter.complete(message);
      }
    });

    _syncHttpPolicyDecision(task, client);
    final activeProxy = client.getActiveProxySettings(task.url);
    final isolate = await Isolate.spawn(
      _isolateSegmentDownload,
      _IsolateParams(
        sendPort: receivePort.sendPort,
        progressPort: _progressPorts[task.id]?.sendPort,
        url: task.url,
        tempFilePath: tempFilePath,
        startByte: segment.startByte + alreadyDownloaded,
        endByte: segment.endByte,
        headers: headers,
        connectionTimeout: config.connectionTimeout,
        alreadyDownloaded: alreadyDownloaded,
        taskId: task.id,
        segmentIndex: segment.index,
        proxyHost: activeProxy.isManual ? activeProxy.host : null,
        proxyPort: activeProxy.isManual ? activeProxy.port : null,
        proxyType: activeProxy.hasProxy ? activeProxy.type : null,
        proxyRequiresAuth: activeProxy.requiresAuth,
        proxyUsername:
            activeProxy.supportsHttpBasicAuth ? activeProxy.username : null,
        proxyPassword:
            activeProxy.supportsHttpBasicAuth ? activeProxy.password : null,
        httpVersionPolicy: client.effectiveHttpVersionPolicy,
        globalSpeedLimit: config.globalSpeedLimit > 0
            ? (config.globalSpeedLimit ~/ task.threadCount)
                .clamp(1024, config.globalSpeedLimit)
            : 0,
      ),
    );

    _taskIsolates[task.id]?.add(isolate);
    final handle = _SegmentExecutionHandle(
      isolate: isolate,
      receivePort: receivePort,
      subscription: subscription,
      controlPortFuture: readyCompleter.future,
      resultFuture: resultCompleter.future,
    );
    _registerSegmentExecution(task.id, segment.index, handle);
    return handle;
  }

  // 在 Isolate 中下载单个分段
  Future<bool> _downloadSegmentInIsolate({
    required Task task,
    required Segment segment,
    required Map<String, String> headers,
    required String tempFilePath,
  }) async {
    final client = _clientForTask(task);
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

        final handle = await _spawnSegmentExecution(
          task: task,
          segment: segment,
          headers: headers,
          tempFilePath: tempFilePath,
          alreadyDownloaded: alreadyDownloaded,
        );

        final result = await handle.resultFuture;
        await _releaseSegmentExecution(task.id, segment.index, handle);
        _taskIsolates[task.id]?.remove(handle.isolate);

        segment.downloadedBytes = min(result.downloadedBytes, expectedSize);

        if (result.interrupted) {
          if (result.reason == 'split') {
            if (result.downloadedBytes > expectedSize) {
              await _truncateSegmentFileToSize(tempFilePath, expectedSize);
              segment.downloadedBytes = expectedSize;
            }
            if (segment.downloadedBytes >= expectedSize) {
              segment.status = SegmentStatus.completed;
              segment.speed = 0;
              return true;
            }
            segment.status = SegmentStatus.downloading;
            segment.speed = 0;
            continue;
          }
          segment.status = _cancelledTasks[task.id] == true
              ? SegmentStatus.cancelled
              : _pausedTasks[task.id] == true
                  ? SegmentStatus.paused
                  : SegmentStatus.pending;
          segment.speed = 0;
          return false;
        }

        if (result.success) {
          if (result.downloadedBytes >= expectedSize) {
            if (result.downloadedBytes > expectedSize) {
              await _truncateSegmentFileToSize(tempFilePath, expectedSize);
              _logger.info(
                'NSFX-Engine',
                'Segment ${segment.index} completed after tail steal; '
                    'truncated overlap ${result.downloadedBytes - expectedSize} '
                    'bytes',
              );
            }
            segment.status = SegmentStatus.completed;
            segment.speed = 0;
            _logger.debug('NSFX-Engine',
                'Segment ${segment.index} completed: $expectedSize bytes');
            return true;
          } else {
            _logger.warning('NSFX-Engine',
                'Segment ${segment.index} size mismatch after download: ${result.downloadedBytes}/$expectedSize');
            segment.status = SegmentStatus.failed;
            segment.lastError =
                'Size mismatch: ${result.downloadedBytes}/$expectedSize';
            segment.speed = 0;
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
          segment.speed = 0;
          return false;
        }
        if (errorText.contains(_rangeNotSatisfiableError) ||
            errorText.contains('HTTP 416')) {
          segment.lastError = _rangeNotSatisfiableError;
          segment.status = SegmentStatus.failed;
          segment.speed = 0;
          return false;
        }
        if (client.fallbackHttpPolicyOnTransferError(e, url: task.url)) {
          _logger.warning(
            'NSFX-Engine',
            'Segment ${segment.index} transfer error under strict transport, '
                'downgrading HTTP policy to '
                '${client.effectiveHttpVersionPolicy} and retrying: '
                '$errorText',
          );
          segment.lastError = errorText;
          _syncHttpPolicyDecision(task, client);
          onProgress(task);
          continue;
        }
        if (client.shouldSwitchToDirectOnError(e)) {
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} proxy transport error: $errorText, triggering fallback');
          segment.lastError = 'PROXY_ERROR_TRANSPORT: $errorText';
          segment.status = SegmentStatus.failed;
          segment.speed = 0;
          task.targetReachable = false;
          _syncHttpPolicyDecision(task, client);
          client.switchToDirectOnProxyError();
          return false;
        }

        if (errorText.contains('PROXY_ERROR_')) {
          _logger.warning('NSFX-Engine',
              'Segment ${segment.index} proxy error: $errorText, triggering fallback');
          segment.lastError = errorText;
          segment.status = SegmentStatus.failed;
          segment.speed = 0;
          task.targetReachable = false;
          _syncHttpPolicyDecision(task, client);
          client.switchToDirectOnProxyError();
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
          final delayMs = NsfxRetryPolicy.segmentRetryDelayMs(retryCount);
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }

    segment.status = SegmentStatus.failed;
    segment.speed = 0;
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

  static Map<String, String> _sanitizeHeadersForPolicy(
    Map<String, String> headers,
    String httpVersionPolicy,
  ) {
    const hopByHopHeaders = {
      'connection',
      'keep-alive',
      'proxy-connection',
      'transfer-encoding',
      'upgrade',
    };
    if (!_usesRhttpTransport(httpVersionPolicy)) {
      return headers;
    }

    final sanitized = Map<String, String>.from(headers);
    sanitized.removeWhere(
      (key, _) => hopByHopHeaders.contains(key.toLowerCase()),
    );
    return sanitized;
  }

  static NsfxResolvedProxy _resolvedProxyFromParams(_IsolateParams params) {
    final proxyType = params.proxyType?.trim().toLowerCase() ?? '';
    if (proxyType.isEmpty) {
      return const NsfxResolvedProxy.direct();
    }
    if (proxyType == 'system') {
      return const NsfxResolvedProxy.system();
    }

    final proxyHost = params.proxyHost?.trim() ?? '';
    final proxyPort = params.proxyPort ?? 0;
    if (proxyHost.isEmpty || proxyPort <= 0) {
      return const NsfxResolvedProxy.direct();
    }

    return NsfxResolvedProxy.manual(
      type: proxyType,
      host: proxyHost,
      port: proxyPort,
      username: params.proxyUsername,
      password: params.proxyPassword,
      requiresAuth: params.proxyRequiresAuth,
    );
  }

  static rhttp.ProxySettings? _toRhttpProxySettings(_IsolateParams params) {
    return NsfxProxyRuntime.toRhttpProxySettings(
      _resolvedProxyFromParams(params),
    );
  }

  static void _configureDartIoProxy(HttpClient client, _IsolateParams params) {
    NsfxProxyRuntime.applyToHttpClient(
      client,
      _resolvedProxyFromParams(params),
    );
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
    final controlPort = ReceivePort();
    var stopRequested = false;
    String? stopReason;

    try {
      controlPort.listen((message) {
        if (message is _IsolateStopRequest) {
          stopRequested = true;
          stopReason = message.reason;
        }
      });
      params.sendPort.send(_IsolateControlReady(controlPort.sendPort));

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
        if (stopRequested) break;
        final currentRemaining = remainingSize - downloadedBytes;
        if (currentRemaining <= 0) break;

        final toWrite = chunk.length > currentRemaining
            ? chunk.sublist(0, currentRemaining)
            : chunk;
        if (stopRequested) break;

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
        success: !stopRequested && totalDownloaded == segmentTotalSize,
        downloadedBytes: totalDownloaded,
        interrupted: stopRequested,
        reason: stopReason,
        error: !stopRequested && totalDownloaded != segmentTotalSize
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
    } finally {
      controlPort.close();
    }
  }

  // 计算速度与 ETA（使用 EMA 平滑）
  void _calculateSpeed(Task task) {
    final now = DateTime.now();
    final currentDownloaded = task.downloadedSize;
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

  Future<_ResumeCompatibilityProbe> _probeResumeCompatibility(
    Task task,
    Map<String, String> headers,
    int fileSize,
  ) async {
    final client = _clientForTask(task);
    try {
      final start = fileSize > 2 ? 1 : 0;
      final end = start + 1;
      final response = await client.getRange(
        task.url,
        _buildRangeHeaders(task, headers),
        start,
        end,
      );
      task.negotiatedHttpVersion =
          _resolveNegotiatedHttpVersion(task) ?? task.negotiatedHttpVersion;
      final status = response.statusCode;
      final totalFromRange =
          _parseTotalFromContentRange(response.headers.value('content-range'));
      await response.drain();
      if (status == 206) {
        if (totalFromRange != null &&
            fileSize > 0 &&
            totalFromRange != fileSize) {
          return const _ResumeCompatibilityProbe(
            compatible: false,
            failureReason:
                'Stored file size no longer matches remote resource during '
                'resume; kept partial segments instead of restarting.',
          );
        }
        return _ResumeCompatibilityProbe(
          compatible: true,
          verifiedStableBehavior: totalFromRange == null || totalFromRange > 0,
        );
      }
      if (status == 200) {
        return const _ResumeCompatibilityProbe(
          compatible: false,
          failureReason:
              'Server no longer honors byte ranges for this resume; kept '
              'partial segments instead of discarding progress.',
        );
      }
      if (status == 416) {
        if (totalFromRange != null &&
            fileSize > 0 &&
            totalFromRange != fileSize) {
          return const _ResumeCompatibilityProbe(
            compatible: false,
            failureReason:
                'Stored file size no longer matches remote resource during '
                'resume; kept partial segments instead of restarting.',
          );
        }
        return const _ResumeCompatibilityProbe(
          compatible: false,
          failureReason:
              'Server reported an invalid byte range while resuming; kept '
              'partial segments instead of restarting from zero.',
        );
      }
    } catch (e) {
      _logger.debug('NSFX-Engine', 'Resume range probe failed: $e');
    }
    return const _ResumeCompatibilityProbe(compatible: true);
  }

  bool _shouldAbortParallelResume(Task task) {
    for (final segment in task.segments) {
      if (segment.lastError == _rangeNotSupportedError ||
          segment.lastError == _rangeNotSatisfiableError) {
        return true;
      }
    }
    return false;
  }

  String _parallelResumeFailureMessage(Task task) {
    final hasRangeMismatch = task.segments
        .any((segment) => segment.lastError == _rangeNotSatisfiableError);
    if (hasRangeMismatch) {
      return 'Server reported an invalid byte range while resuming; kept '
          'partial segments instead of restarting from zero.';
    }
    return 'Server stopped honoring byte ranges for this download; kept '
        'partial segments instead of discarding progress.';
  }

  void _failTaskPreservingSegments(Task task, String message) {
    task.status = TaskStatus.failed;
    task.errorMessage = message;
    _logger.error('NSFX-Engine', message);
    onError(task);
  }

  void _markTaskCompleted(
    Task task, {
    int? downloadedSize,
    NsfxHttpClient? client,
  }) {
    if (downloadedSize != null) {
      task.downloadedSize = downloadedSize;
    } else if (task.totalSize > 0) {
      task.downloadedSize = task.totalSize;
    }

    if (task.totalSize <= 0 && task.downloadedSize > 0) {
      task.totalSize = task.downloadedSize;
    }

    task.status = TaskStatus.completed;
    task.endTime = DateTime.now();
    task.progress = 100;
    task.speed = 0;
    task.eta = 0;
    task.targetReachable = true;

    if (client != null) {
      _syncHttpPolicyDecision(task, client);
    }

    if (task.startTime != null && task.endTime != null) {
      final duration = task.endTime!.difference(task.startTime!).inSeconds;
      if (duration > 0 && task.totalSize > 0) {
        task.averageSpeed = task.totalSize / duration;
      }
    }
  }

  Future<bool> _completeSingleThreadTaskIfFileFinished(
    Task task,
    File file,
    NsfxHttpClient client,
  ) async {
    if (task.totalSize <= 0 || !await file.exists()) {
      return false;
    }

    final finalSize = await file.length();
    if (finalSize < task.totalSize) {
      return false;
    }

    _markTaskCompleted(task, downloadedSize: finalSize, client: client);
    _logger.info(
      'NSFX-Engine',
      'Single-thread transfer reached expected size before stream close: '
          '${task.filename}',
    );
    onComplete(task);
    return true;
  }

  Future<void> _singleThreadDownload(
    Task task,
    Map<String, String> headers, {
    bool? supportsRange,
    int? totalSizeHint,
  }) async {
    final client = _clientForTask(task);
    _setStartupStatus(task, null);
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

    if (existingLength > 0 && supportsRange != false) {
      requestedRange = true;
      response = await _getRangeResponse(task, task.url, headers,
          existingLength, task.totalSize > 0 ? task.totalSize : null);
      task.negotiatedHttpVersion =
          _resolveNegotiatedHttpVersion(task) ?? task.negotiatedHttpVersion;

      if (response.statusCode == 416) {
        final totalFromRange = _parseTotalFromContentRange(
            response.headers.value('content-range'));
        await response.drain();
        if (totalFromRange != null && existingLength >= totalFromRange) {
          task.totalSize = totalFromRange;
          _markTaskCompleted(
            task,
            downloadedSize: totalFromRange,
            client: client,
          );
          onComplete(task);
          return;
        }
        task.resumeSafetyLevel = NsfxResumeSafetyLevel.unknown;
        _recordResumeDecision(
          task,
          label: 'Resume Blocked',
          reason:
              'Server rejected the requested byte range, so the download was '
              'restarted from zero.',
          blocked: true,
        );
        existingLength = 0;
        supportsRange = false;
        requestedRange = false;
        await file.writeAsBytes(const [], mode: FileMode.write);
        response = await client.get(task.url, headers);
        task.negotiatedHttpVersion =
            _resolveNegotiatedHttpVersion(task) ?? task.negotiatedHttpVersion;
      } else if (response.statusCode == 200) {
        await response.drain();
        task.resumeSafetyLevel = NsfxResumeSafetyLevel.unknown;
        _recordResumeDecision(
          task,
          label: 'Resume Blocked',
          reason:
              'Server ignored the resume range request, so the download was '
              'restarted from zero.',
          blocked: true,
        );
        existingLength = 0;
        supportsRange = false;
        requestedRange = false;
        await file.writeAsBytes(const [], mode: FileMode.write);
        response = await client.get(task.url, headers);
        task.negotiatedHttpVersion =
            _resolveNegotiatedHttpVersion(task) ?? task.negotiatedHttpVersion;
      }
    } else {
      if (existingLength > 0 && supportsRange == false) {
        existingLength = 0;
        await file.writeAsBytes(const [], mode: FileMode.write);
      }
      response = await client.get(task.url, headers);
      task.negotiatedHttpVersion =
          _resolveNegotiatedHttpVersion(task) ?? task.negotiatedHttpVersion;
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
    _syncHttpPolicyDecision(task, client);

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
        task.resumeDataOrigin = NsfxResumeDataOrigin.runtime;
        if (requestedRange && task.ifRangeValidator == null) {
          task.resumeSafetyLevel = NsfxResumeSafetyLevel.verifiedNoValidator;
        }
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
      _markTaskCompleted(task, downloadedSize: finalSize, client: client);

      onComplete(task);
    } catch (e) {
      await sink.close();
      if (await _completeSingleThreadTaskIfFileFinished(task, file, client)) {
        return;
      }
      if (client.fallbackHttpPolicyOnTransferError(e, url: task.url)) {
        _logger.warning(
          'NSFX-Engine',
          'Single-thread stream read failed, retrying with downgraded HTTP '
              'policy (${client.effectiveHttpVersionPolicy}): $e',
        );
        await _singleThreadDownload(
          task,
          headers,
          supportsRange: supportsRange,
          totalSizeHint: task.totalSize > 0 ? task.totalSize : totalSizeHint,
        );
        return;
      }
      rethrow;
    }
  }

  Future<HttpClientResponse> _getRangeResponse(
    Task task,
    String url,
    Map<String, String> headers,
    int start,
    int? end,
  ) async {
    final client = _clientForTask(task);
    final rangeHeaders = _buildRangeHeaders(task, headers);
    if (end != null && end > start) {
      return client.getRange(url, rangeHeaders, start, end);
    }
    return client.get(url, {
      ...rangeHeaders,
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

  Future<void> _truncateSegmentFileToSize(String path, int expectedSize) async {
    final file = File(path);
    if (!await file.exists()) return;
    final raf = await file.open(mode: FileMode.writeOnlyAppend);
    try {
      await raf.truncate(expectedSize);
    } finally {
      await raf.close();
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

    final handles = _taskSegmentExecutions[taskId];
    if (handles != null) {
      for (final handle in handles.values) {
        unawaited(handle.requestStop('pause'));
      }
    }
    if (handles == null || handles.isEmpty) {
      final isolates = _taskIsolates[taskId];
      if (isolates != null) {
        for (final isolate in isolates) {
          isolate.kill(priority: Isolate.immediate);
        }
        isolates.clear();
      }
    }
  }

  void cancelDownload(String taskId) {
    _cancelledTasks[taskId] = true;

    final handles = _taskSegmentExecutions[taskId];
    if (handles != null) {
      for (final handle in handles.values) {
        unawaited(handle.requestStop('cancel'));
      }
    }
    if (handles == null || handles.isEmpty) {
      final isolates = _taskIsolates[taskId];
      if (isolates != null) {
        for (final isolate in isolates) {
          isolate.kill(priority: Isolate.immediate);
        }
        isolates.clear();
      }
    }
  }

  Map<String, String> _buildHeaders(Task task) {
    return buildDownloadHeaders(task, config);
  }

  Map<String, String> _buildRangeHeaders(
    Task task,
    Map<String, String> baseHeaders,
  ) {
    final headers = Map<String, String>.from(baseHeaders);
    final validator = task.ifRangeValidator?.trim();
    if (validator != null && validator.isNotEmpty) {
      headers['If-Range'] = validator;
    }
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
  final bool interrupted;
  final String? reason;

  _IsolateResult({
    required this.success,
    required this.downloadedBytes,
    this.error,
    this.interrupted = false,
    this.reason,
  });
}

class _IsolateControlReady {
  final SendPort controlPort;

  const _IsolateControlReady(this.controlPort);
}

class _IsolateStopRequest {
  final String reason;

  const _IsolateStopRequest(this.reason);
}

class _ResumeCompatibilityProbe {
  final bool compatible;
  final bool verifiedStableBehavior;
  final String? failureReason;

  const _ResumeCompatibilityProbe({
    required this.compatible,
    this.verifiedStableBehavior = false,
    this.failureReason,
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

class _SegmentRuntimeState {
  DateTime? lastProgressAt;
  DateTime? lastSplitAt;
}

class _SegmentExecutionHandle {
  final Isolate isolate;
  final ReceivePort receivePort;
  final StreamSubscription<dynamic> subscription;
  final Future<SendPort> controlPortFuture;
  final Future<_IsolateResult> resultFuture;

  _SegmentExecutionHandle({
    required this.isolate,
    required this.receivePort,
    required this.subscription,
    required this.controlPortFuture,
    required this.resultFuture,
  });

  Future<bool> requestStop(String reason) async {
    try {
      final port = await controlPortFuture.timeout(const Duration(seconds: 2));
      port.send(_IsolateStopRequest(reason));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    await subscription.cancel();
    receivePort.close();
  }
}

// 简易信号量：控制并发
class _Semaphore {
  int maxConcurrent;
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

  void updateLimit(int nextLimit) {
    maxConcurrent = nextLimit.clamp(1, 64);
    while (_current < maxConcurrent && _queue.isNotEmpty) {
      _current++;
      _queue.removeAt(0).complete();
    }
  }

  void _release() {
    _current--;
    while (_current < maxConcurrent && _queue.isNotEmpty) {
      _current++;
      _queue.removeAt(0).complete();
    }
  }
}
