import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/download_intent.dart';
import '../models/download_task.dart';
import 'download_intent_dispatcher.dart';
import 'kernel/kernel_manager.dart';
import 'kernel/kernel_interface.dart' as kernel;
import 'client_config_service.dart';
import 'app_logger_service.dart';
import 'download_failure_stats_service.dart';
import 'plugin_task_service.dart';
import 'process_memory_trim_service.dart';

class IntegratedDownloadService extends ChangeNotifier
    with WidgetsBindingObserver {
  final _kernelManager = KernelManager();
  late final DownloadIntentDispatcher _intentDispatcher =
      DownloadIntentDispatcher(kernelManager: _kernelManager);
  final _pluginTaskService = PluginTaskService();
  final _clientConfig = ClientConfigService();
  final _appLogger = AppLoggerService();
  final List<DownloadTask> _tasks = [];
  final Map<String, DownloadTask> _tasksById = {};
  List<DownloadTask>? _tasksSnapshot;
  Timer? _pollTimer;

  // 节流控制，避免 Windows 消息队列溢出
  // override notifyListeners() 从根源拦截所有通知，强制走节流
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  static const _foregroundNotifyInterval = Duration(milliseconds: 250);
  static const _backgroundNotifyInterval = Duration(seconds: 2);
  bool _pendingNotify = false;
  Timer? _notifyTimer;
  bool _immediate = false; // 标记本次通知是否需要立即发送

  // 智能轮询：根据是否有活跃下载调整间隔
  bool _hasActiveDownloads = false;
  bool _hasLoadedOnce = false;
  String? _lastAddTaskError;
  bool _isForegroundActive = true;
  static const _foregroundActivePollingInterval = Duration(seconds: 3);
  static const _backgroundActivePollingInterval = Duration(seconds: 10);
  static const _foregroundIdlePollingInterval = Duration(seconds: 20);
  static const _backgroundIdlePollingInterval = Duration(seconds: 60);

  // Stream 订阅
  StreamSubscription? _progressSubscription;
  StreamSubscription? _completeSubscription;
  Timer? _backgroundMemoryMaintenanceTimer;
  bool _backgroundMemoryMaintenanceBusy = false;
  static const _backgroundMemoryMaintenanceInterval = Duration(minutes: 5);
  static const _backgroundCompletedTaskKeepCount = 80;
  bool _pluginTaskPollingEnabled = true;
  Future<void>? _pluginTaskInitFuture;

  IntegratedDownloadService({
    bool startPluginTaskPolling = true,
  }) : _pluginTaskPollingEnabled = startPluginTaskPolling {
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForegroundActive = lifecycleState != AppLifecycleState.hidden &&
        lifecycleState != AppLifecycleState.paused &&
        lifecycleState != AppLifecycleState.detached;
    _startPolling();
    _subscribeToKernelStreams();
    if (_pluginTaskPollingEnabled) {
      unawaited(enablePluginTaskPolling());
    }
    // 立即尝试首次加载，不等待轮询间隔
    _immediateFirstLoad();
  }

  bool get isKernelRunning => _kernelManager.isRunning;

  List<DownloadTask> get tasks => _tasksSnapshot ??= List.unmodifiable(_tasks);
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get lastAddTaskError => _lastAddTaskError;
  bool get isForegroundActive => _isForegroundActive;

  DownloadTask? getTaskById(String id) => _tasksById[id];

  Future<void> enablePluginTaskPolling() {
    _pluginTaskPollingEnabled = true;
    return _pluginTaskInitFuture ??= _initializePluginTaskPolling();
  }

  Future<void> _initializePluginTaskPolling() async {
    try {
      await _pluginTaskService.initialize();
      final (hasChanges, _) = await _syncPluginTasks(refresh: false);
      if (hasChanges) {
        notifyNow();
      }
    } catch (error) {
      _appLogger.warning('PluginTask', 'Plugin task init failed: $error');
    } finally {
      _pluginTaskInitFuture = null;
    }
  }

  DownloadTask? findDuplicateTask(String url) {
    final normalized = _normalizeUrl(url);
    for (final task in _tasks) {
      if (_normalizeUrl(task.url) == normalized) {
        return task;
      }
    }
    return null;
  }

  String _normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final intent = DownloadIntent.parse(trimmed);
    if (intent.isRecognized) {
      final normalized = intent.normalizedValue;
      if (intent.isHttp &&
          normalized.endsWith('/') &&
          intent.uri?.path == '/' &&
          (intent.uri?.query.isEmpty ?? true)) {
        return normalized.substring(0, normalized.length - 1);
      }
      return normalized;
    }

    return trimmed;
  }

  DownloadTask? _findTaskById(String id) => getTaskById(id);

  void _invalidateTaskSnapshot() {
    _tasksSnapshot = null;
  }

  void _addTask(DownloadTask task) {
    _tasks.add(task);
    _tasksById[task.id] = task;
    _invalidateTaskSnapshot();
  }

  void _setTaskAt(int index, DownloadTask task) {
    final oldTask = _tasks[index];
    if (oldTask.id != task.id) {
      _tasksById.remove(oldTask.id);
    }
    _tasks[index] = task;
    _tasksById[task.id] = task;
    _invalidateTaskSnapshot();
  }

  void _removeTaskById(String id) {
    _tasks.removeWhere((task) => task.id == id);
    _tasksById.remove(id);
    _invalidateTaskSnapshot();
  }

  void _clearTasks() {
    _tasks.clear();
    _tasksById.clear();
    _invalidateTaskSnapshot();
  }

  bool _computeHasActiveDownloads() {
    return _tasks.any((t) =>
        t.status == DownloadStatus.downloading ||
        t.status == DownloadStatus.merging ||
        t.status == DownloadStatus.pending);
  }

  void _setHasActiveDownloads(bool value) {
    if (_hasActiveDownloads == value) return;
    _hasActiveDownloads = value;
    _scheduleNextPoll();
  }

  void setForegroundActive(bool active) {
    if (_isForegroundActive == active) {
      if (!active) {
        _startBackgroundMemoryMaintenance();
      }
      return;
    }
    _isForegroundActive = active;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _pendingNotify = false;
    _scheduleNextPoll();
    if (active) {
      _stopBackgroundMemoryMaintenance();
      notifyNow();
    } else {
      _startBackgroundMemoryMaintenance();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setForegroundActive(state != AppLifecycleState.hidden &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached);
  }

  void _startPolling() {
    _scheduleNextPoll();
  }

  /// 启动时立即尝试加载任务，最多重试 10 次（每 500ms），
  /// 避免等待 5 秒的空闲轮询间隔
  Future<void> _immediateFirstLoad() async {
    for (int i = 0; i < 10; i++) {
      if (_hasLoadedOnce) return;
      // Always attempt to update tasks, even if the kernel isn't running yet.
      // _updateTasks() can set _hasLoadedOnce via the plugin-task sync path,
      // which prevents the UI from being stuck on "Loading tasks...".
      await _updateTasks();
      if (_hasLoadedOnce) return;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// 订阅内核的进度 Stream，实现实时更新
  void _subscribeToKernelStreams() {
    // 取消旧的订阅
    _progressSubscription?.cancel();
    _completeSubscription?.cancel();
    _progressSubscription = null;
    _completeSubscription = null;

    if (_kernelManager.isRunning) {
      _appLogger.info('App', 'Subscribing to kernel streams...');

      // 监听进度更新
      final progressStream = _kernelManager.onProgress;
      if (progressStream != null) {
        _progressSubscription = progressStream.listen((task) {
          _handleStreamUpdate(task);
        });
        _appLogger.info('App', 'Subscribed to progress stream');
      }

      // 监听完成事件
      final completeStream = _kernelManager.onComplete;
      if (completeStream != null) {
        _completeSubscription = completeStream.listen((task) {
          _appLogger.info('App', 'Stream complete: ${task.filename}');
          _handleStreamUpdate(task);
        });
        _appLogger.info('App', 'Subscribed to complete stream');
      }
    }
  }

  /// 处理来自 Stream 的更新
  void _handleStreamUpdate(kernel.DownloadTask kernelTask) {
    final taskMap = _convertDownloadTaskToMap(kernelTask);
    final newTask = _convertKernelTask(taskMap);

    final existingIndex = _tasks.indexWhere((t) => t.id == newTask.id);

    if (existingIndex != -1) {
      final oldTask = _tasks[existingIndex];
      _setTaskAt(existingIndex, newTask);
      _logDiagnosticDecisionChanges(oldTask, newTask);

      // 检查是否有关键变化
      final isStatusChanged = oldTask.status != newTask.status;
      final isSizeChanged = oldTask.fileSize != newTask.fileSize &&
          newTask.fileSize != null &&
          newTask.fileSize! > 0;

      if (isStatusChanged && newTask.status == DownloadStatus.failed) {
        DownloadFailureStatsService().recordFailure(newTask);
      }

      if (isStatusChanged || isSizeChanged) {
        // 关键变化走即时通知
        _appLogger.debug('App',
            'Critical change detected: status=$isStatusChanged, size=$isSizeChanged');
        notifyNow();
      } else {
        // 普通进度更新走节流
        notifyListeners();
      }
    } else {
      // 新任务
      _addTask(newTask);
      if (newTask.status == DownloadStatus.failed) {
        DownloadFailureStatsService().recordFailure(newTask);
      }
      notifyNow();
    }

    // 更新活跃下载状态
    _setHasActiveDownloads(_computeHasActiveDownloads());
  }

  void _logDiagnosticDecisionChanges(
    DownloadTask oldTask,
    DownloadTask newTask,
  ) {
    if (oldTask.resumeDecisionLabel != newTask.resumeDecisionLabel ||
        oldTask.resumeDecisionReason != newTask.resumeDecisionReason) {
      final label = (newTask.resumeDecisionLabel ?? '').trim();
      final reason = (newTask.resumeDecisionReason ?? '').trim();
      if (label.isNotEmpty || reason.isNotEmpty) {
        _appLogger.info(
          'App',
          'Resume decision updated: ${newTask.fileName} -> '
              '[${label.isEmpty ? '--' : label}] ${reason.isEmpty ? 'No reason' : reason}',
        );
      }
    }

    if (oldTask.httpPolicyDecisionReason != newTask.httpPolicyDecisionReason) {
      final reason = (newTask.httpPolicyDecisionReason ?? '').trim();
      if (reason.isNotEmpty) {
        _appLogger.info(
          'App',
          'HTTP policy decision updated: ${newTask.fileName} -> $reason',
        );
      }
    }

    if (oldTask.hostConcurrencyCap != newTask.hostConcurrencyCap ||
        oldTask.hostConcurrencyReason != newTask.hostConcurrencyReason) {
      final cap = newTask.hostConcurrencyCap;
      final reason = (newTask.hostConcurrencyReason ?? '').trim();
      if (cap != null || reason.isNotEmpty) {
        _appLogger.info(
          'App',
          'Host concurrency decision updated: ${newTask.fileName} -> '
              '${cap == null ? 'no cap' : 'cap=$cap'}'
              '${reason.isEmpty ? '' : ' ($reason)'}',
        );
      }
    }
  }

  // 智能轮询：根据下载状态动态调整间隔
  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    final interval = _hasActiveDownloads
        ? (_isForegroundActive
            ? _foregroundActivePollingInterval
            : _backgroundActivePollingInterval)
        : (_isForegroundActive
            ? _foregroundIdlePollingInterval
            : _backgroundIdlePollingInterval);
    _pollTimer = Timer(interval, () async {
      // 确保已订阅内核 Stream
      if ((_progressSubscription == null || _completeSubscription == null) &&
          isKernelRunning) {
        _subscribeToKernelStreams();
      }
      await _updateTasks();
      _scheduleNextPoll();
    });
  }

  void _startBackgroundMemoryMaintenance() {
    if (_backgroundMemoryMaintenanceTimer != null) {
      return;
    }

    unawaited(_runBackgroundMemoryMaintenance());
    _backgroundMemoryMaintenanceTimer =
        Timer.periodic(_backgroundMemoryMaintenanceInterval, (_) {
      unawaited(_runBackgroundMemoryMaintenance());
    });
  }

  void _stopBackgroundMemoryMaintenance() {
    _backgroundMemoryMaintenanceTimer?.cancel();
    _backgroundMemoryMaintenanceTimer = null;
  }

  Future<void> _runBackgroundMemoryMaintenance() async {
    if (_backgroundMemoryMaintenanceBusy ||
        _isForegroundActive ||
        !isKernelRunning) {
      return;
    }

    _backgroundMemoryMaintenanceBusy = true;
    try {
      final compacted = await _kernelManager.compactCompletedTaskHistory(
        keepRecentFullDetails: _backgroundCompletedTaskKeepCount,
      );
      if (compacted > 0) {
        _appLogger.info(
          'App',
          'Background memory maintenance compacted $compacted completed task histories',
        );
        await _updateTasks();
        ProcessMemoryTrimService.trimCurrentProcessWorkingSet(
          reason: 'background-task-history-compact',
        );
      }
    } catch (error) {
      _appLogger.warning('App', 'Background memory maintenance failed: $error');
    } finally {
      _backgroundMemoryMaintenanceBusy = false;
    }
  }

  /// 从根源 override notifyListeners，所有通知强制走节流
  /// 外部调用 notifyListeners() 默认走节流模式
  /// 需要立即通知时，先设 _immediate = true 再调用
  @override
  void notifyListeners() {
    if (_immediate) {
      _immediate = false;
      _notifyTimer?.cancel();
      _pendingNotify = false;
      _lastNotify = DateTime.now();
      super.notifyListeners();
      return;
    }

    // 节流模式
    final now = DateTime.now();
    final minNotifyInterval = _isForegroundActive
        ? _foregroundNotifyInterval
        : _backgroundNotifyInterval;
    if (now.difference(_lastNotify) >= minNotifyInterval) {
      _lastNotify = now;
      super.notifyListeners();
      return;
    }

    // 距离上次通知太近，延迟合并
    if (_pendingNotify) return;
    _pendingNotify = true;

    _notifyTimer?.cancel();
    _notifyTimer = Timer(minNotifyInterval, () {
      _pendingNotify = false;
      _lastNotify = DateTime.now();
      super.notifyListeners();
    });
  }

  /// 立即通知 UI（用于任务增删等结构性变化）
  void notifyNow() {
    _immediate = true;
    notifyListeners();
  }

  Future<(bool, bool)> _syncPluginTasks({bool refresh = true}) async {
    if (!_pluginTaskPollingEnabled) {
      return (false, false);
    }
    await _pluginTaskService.ensureInitialized();
    final records = refresh
        ? await _pluginTaskService.refreshActiveTasks()
        : _pluginTaskService.records;
    var hasChanges = false;
    var hasCriticalChange = false;

    final taskIndices = <String, int>{};
    for (var i = 0; i < _tasks.length; i++) {
      taskIndices[_tasks[i].id] = i;
    }

    for (final record in records) {
      final newTask = record.toDownloadTask();
      final existingIndex = taskIndices[newTask.id] ?? -1;
      if (existingIndex == -1) {
        _addTask(newTask);
        taskIndices[newTask.id] = _tasks.length - 1;
        hasChanges = true;
        hasCriticalChange = true;
        if (newTask.status == DownloadStatus.failed) {
          DownloadFailureStatsService().recordFailure(newTask);
        }
        continue;
      }

      final oldTask = _tasks[existingIndex];
      final statusChanged = oldTask.status != newTask.status;
      final sizeChanged = oldTask.fileSize != newTask.fileSize ||
          oldTask.downloadedSize != newTask.downloadedSize;
      final progressChanged =
          (oldTask.progress - newTask.progress).abs() > 0.001;
      final speedChanged = oldTask.speed != newTask.speed;
      final errorChanged = oldTask.error != newTask.error;

      if (statusChanged ||
          sizeChanged ||
          progressChanged ||
          speedChanged ||
          errorChanged) {
        _setTaskAt(existingIndex, newTask);
        hasChanges = true;
        hasCriticalChange = hasCriticalChange || statusChanged || sizeChanged;
        if (statusChanged && newTask.status == DownloadStatus.failed) {
          DownloadFailureStatsService().recordFailure(newTask);
        }
      }
    }

    return (hasChanges, hasCriticalChange);
  }

  Future<void> _updateTasks() async {
    try {
      if (!isKernelRunning) {
        final (pluginChanges, pluginCriticalChange) = await _syncPluginTasks();
        if (pluginChanges) {
          if (pluginCriticalChange) {
            notifyNow();
          } else {
            notifyListeners();
          }
        }
        if (!_hasLoadedOnce) {
          _hasLoadedOnce = true;
          notifyNow();
        }
        _setHasActiveDownloads(_computeHasActiveDownloads());
        return;
      }

      final tasks = await _kernelManager.getTasks();
      final kernelTasks = tasks.map(_convertDownloadTaskToMap).toList();

      bool hasChanges = false;
      bool hasCriticalChange = false;

      final taskIndices = <String, int>{};
      for (var i = 0; i < _tasks.length; i++) {
        taskIndices[_tasks[i].id] = i;
      }

      for (var kernelTask in kernelTasks) {
        final existingIndex = taskIndices[kernelTask['id']] ?? -1;

        final newTask = _convertKernelTask(kernelTask);

        if (existingIndex != -1) {
          final oldTask = _tasks[existingIndex];

          // 检查是否有实际变化（包括文件大小变化）
          final isStatusChanged = oldTask.status != newTask.status;
          final isSizeChanged = oldTask.fileSize != newTask.fileSize;
          final isProgressChanged =
              (oldTask.progress - newTask.progress).abs() > 0.001;
          final isSpeedChanged = oldTask.speed != newTask.speed;

          final hasTaskChanged = isStatusChanged ||
              isSizeChanged ||
              isProgressChanged ||
              isSpeedChanged;
          final isCriticalChange = isStatusChanged || isSizeChanged;

          if (isStatusChanged && newTask.status == DownloadStatus.failed) {
            DownloadFailureStatsService().recordFailure(newTask);
          }

          if (hasTaskChanged) {
            hasChanges = true;
          }

          // 标记关键变化
          if (isCriticalChange) {
            hasCriticalChange = true;
            _appLogger.debug('App',
                'Critical change in polling: status=$isStatusChanged, size=$isSizeChanged');
          }

          // Log status changes (only when status actually changes)
          if (oldTask.status != newTask.status) {
            _appLogger.debug('App',
                'Kernel task status: ${kernelTask['id']} -> ${kernelTask['status']}');
            _appLogger.info('App',
                'Status change: ${newTask.fileName} from ${oldTask.status} to ${newTask.status}');
            switch (newTask.status) {
              case DownloadStatus.completed:
                _appLogger.info('App', 'Task completed: ${newTask.fileName}');
                break;
              case DownloadStatus.failed:
                _appLogger.error('App',
                    'Task failed: ${newTask.fileName}, Error: ${newTask.error ?? 'Unknown error'}');
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

          _logDiagnosticDecisionChanges(oldTask, newTask);
          _setTaskAt(existingIndex, newTask);
        } else {
          _addTask(newTask);
          hasChanges = true;
          _appLogger.info(
              'App', 'New task added: ${newTask.fileName} (${newTask.status})');
          if (newTask.status == DownloadStatus.failed) {
            DownloadFailureStatsService().recordFailure(newTask);
          }
        }
      }

      final (pluginChanges, pluginCriticalChange) = await _syncPluginTasks();
      hasChanges = hasChanges || pluginChanges;
      hasCriticalChange = hasCriticalChange || pluginCriticalChange;

      // 只在有变化时才通知 UI
      if (hasChanges) {
        if (hasCriticalChange) {
          notifyNow();
        } else {
          notifyListeners();
        }
      }

      // 更新活跃下载状态，用于智能轮询
      final newHasActiveDownloads = _computeHasActiveDownloads();
      if (newHasActiveDownloads != _hasActiveDownloads) {
        _setHasActiveDownloads(newHasActiveDownloads);
        _appLogger.debug('App',
            'Active downloads: $_hasActiveDownloads, polling interval adjusted');
      }

      // 标记首次加载完成
      if (!_hasLoadedOnce) {
        _hasLoadedOnce = true;
        notifyNow();
      }
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
      'createdTime': task.createdTime.toIso8601String(), // 添加创建时间
      'segmentCount': task.segmentCount ?? task.segments.length,
      'effectiveHttpVersionPolicy': task.effectiveHttpVersionPolicy,
      'negotiatedHttpVersion': task.negotiatedHttpVersion,
      'targetReachable': task.targetReachable,
      'httpPolicyDecisionReason': task.httpPolicyDecisionReason,
      'startupStatusKey': task.startupStatusKey,
      'resumeDecisionLabel': task.resumeDecisionLabel,
      'resumeDecisionReason': task.resumeDecisionReason,
      'hostConcurrencyCap': task.hostConcurrencyCap,
      'hostConcurrencyReason': task.hostConcurrencyReason,
      'segments': task.segments
          .map((s) => {
                'index': s.index,
                'startByte': s.startByte,
                'endByte': s.endByte,
                'downloadedBytes': s.downloadedBytes,
                'speed': s.speed,
                'status': s.status,
                'retryCount': s.retryCount,
              })
          .toList(),
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
            startByte: (seg['startByte'] as num?)?.toInt() ??
                (seg['start_byte'] as num?)?.toInt() ??
                0,
            endByte: (seg['endByte'] as num?)?.toInt() ??
                (seg['end_byte'] as num?)?.toInt() ??
                0,
            downloadedBytes: (seg['downloadedBytes'] as num?)?.toInt() ??
                (seg['downloaded_bytes'] as num?)?.toInt() ??
                0,
            speed: (seg['speed'] as num?)?.toDouble() ?? 0.0,
            status: seg['status']?.toString() ?? 'pending',
            retryCount: (seg['retryCount'] as num?)?.toInt() ??
                (seg['retry_count'] as num?)?.toInt() ??
                0,
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
    final segmentCount = (kernelTask['segmentCount'] as num?)?.toInt() ??
        (kernelTask['segment_count'] as num?)?.toInt() ??
        segments?.length;
    final downloadCore = kernelTask['downloadCore'] as String? ?? 'NSF-X';
    final effectiveHttpVersionPolicy =
        kernelTask['effectiveHttpVersionPolicy']?.toString();
    final negotiatedHttpVersion =
        kernelTask['negotiatedHttpVersion']?.toString();
    final httpPolicyDecisionReason =
        kernelTask['httpPolicyDecisionReason']?.toString();
    final startupStatusKey = kernelTask['startupStatusKey']?.toString();
    final resumeDecisionLabel = kernelTask['resumeDecisionLabel']?.toString();
    final resumeDecisionReason = kernelTask['resumeDecisionReason']?.toString();
    final hostConcurrencyCap =
        (kernelTask['hostConcurrencyCap'] as num?)?.toInt();
    final hostConcurrencyReason =
        kernelTask['hostConcurrencyReason']?.toString();
    final targetReachableRaw = kernelTask['targetReachable'];
    final bool? targetReachable = targetReachableRaw is bool
        ? targetReachableRaw
        : (targetReachableRaw is String
            ? (targetReachableRaw.toLowerCase() == 'true'
                ? true
                : (targetReachableRaw.toLowerCase() == 'false' ? false : null))
            : null);

    // 解析时间
    DateTime? startTime;
    DateTime? endTime;
    DateTime? createdTime;
    try {
      if (kernelTask['startTime'] != null) {
        startTime = DateTime.parse(kernelTask['startTime']);
      }
      if (kernelTask['endTime'] != null) {
        endTime = DateTime.parse(kernelTask['endTime']);
      }
      if (kernelTask['createdTime'] != null) {
        createdTime = DateTime.parse(kernelTask['createdTime']);
      }
    } catch (e) {
      _appLogger.error('App', 'Failed to parse time: $e');
    }

    // 注意：kernelTask['progress'] 是 0-100 的百分比，需要转换为 0-1 的小数供 UI 使用
    final progressValue = (kernelTask['progress'] ?? 0.0).toDouble();
    final normalizedProgress =
        status == DownloadStatus.completed ? 1.0 : progressValue / 100.0;

    return DownloadTask(
      id: kernelTask['id'],
      url: kernelTask['url'],
      fileName: kernelTask['filename'],
      status: status,
      progress: normalizedProgress,
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
      effectiveHttpVersionPolicy: effectiveHttpVersionPolicy,
      negotiatedHttpVersion: negotiatedHttpVersion,
      targetReachable: targetReachable,
      httpPolicyDecisionReason: httpPolicyDecisionReason,
      startupStatusKey: startupStatusKey,
      resumeDecisionLabel: resumeDecisionLabel,
      resumeDecisionReason: resumeDecisionReason,
      hostConcurrencyCap: hostConcurrencyCap,
      hostConcurrencyReason: hostConcurrencyReason,
      startTime: startTime,
      endTime: endTime,
      createdAt: createdTime, // 传递创建时间
    );
  }

  Future<String?> addTask(
    String url,
    String fileName, {
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
    String? saveDir,
    bool startPaused = false,
  }) async {
    _lastAddTaskError = null;
    // 检查是否是测试任务
    if (url.startsWith('test_task_')) {
      return _addTestTask(url, fileName);
    }

    final intent = DownloadIntent.parse(url);
    if (!intent.isRecognized) {
      _appLogger.warning(
          'App', 'Rejected download task with invalid URL: $url');
      _lastAddTaskError = 'Unsupported or invalid download intent';
      return null;
    }

    // 确保已订阅内核 Stream（内核可能刚启动）
    if (intent.isHttp &&
        (_progressSubscription == null || _completeSubscription == null)) {
      _subscribeToKernelStreams();
    }

    _appLogger.info('App',
        'Adding download task: $fileName (intent=${intent.type.wireName})');
    if (referer != null ||
        userAgent != null ||
        cookies != null ||
        headers != null ||
        (saveDir?.trim().isNotEmpty ?? false)) {
      _appLogger.info('App', 'With download request metadata');
    }

    final result = await _intentDispatcher.dispatch(
      DownloadDispatchRequest(
        intent: intent,
        fileName: fileName,
        referer: referer,
        userAgent: userAgent,
        cookies: cookies,
        headers: headers,
        saveDir: saveDir,
        startPaused: startPaused,
      ),
    );

    if (!result.accepted) {
      _lastAddTaskError = result.message;
      _appLogger.error(
        'App',
        'Failed to add task via ${result.handlerId}: ${result.message}',
      );
      return null;
    }

    final taskId = result.taskId;
    if (taskId != null && intent.isHttp) {
      _appLogger.info('App',
          'Task added successfully: $taskId - $fileName (${result.handlerId})');
      // 立即切换到快速轮询模式
      _hasActiveDownloads = true;
      // 立即更新任务列表
      await _updateTasks();
      // _updateTasks 内部已经会通知 UI，不需要再次通知
    } else if (taskId != null) {
      final pluginId = result.metadata['pluginId']?.toString();
      final pluginResultRaw = result.metadata['pluginResult'];
      final pluginResult = pluginResultRaw is Map
          ? pluginResultRaw.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
      if (pluginId != null && pluginId.isNotEmpty) {
        final record = await _pluginTaskService.registerTask(
          pluginId: pluginId,
          taskId: taskId,
          intent: intent,
          fileName: fileName,
          saveDir: saveDir,
          pluginResult: pluginResult,
        );
        final existingIndex = _tasks.indexWhere((task) => task.id == record.id);
        final pluginTask = record.toDownloadTask();
        if (existingIndex == -1) {
          _addTask(pluginTask);
        } else {
          _setTaskAt(existingIndex, pluginTask);
        }
        _setHasActiveDownloads(true);
        notifyNow();
      }
      _appLogger.info('App',
          'Plugin task accepted: $taskId - $fileName (${result.handlerId})');
    }

    return taskId;
  }

  Future<DownloadDispatchResult> dispatchIntent(
    DownloadIntent intent,
    String fileName, {
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
    String? saveDir,
    bool startPaused = false,
  }) async {
    final result = await _intentDispatcher.dispatch(
      DownloadDispatchRequest(
        intent: intent,
        fileName: fileName,
        referer: referer,
        userAgent: userAgent,
        cookies: cookies,
        headers: headers,
        saveDir: saveDir,
        startPaused: startPaused,
      ),
    );
    _lastAddTaskError = result.accepted ? null : result.message;
    return result;
  }

  // 添加测试任务
  String? _addTestTask(String testType, String fileName) {
    final id = 'test_${DateTime.now().millisecondsSinceEpoch}';
    DownloadTask testTask;

    switch (testType) {
      case 'test_task_merging':
        testTask = DownloadTask(
          id: id,
          url: testType,
          fileName: fileName.isEmpty ? 'test_merging_file.zip' : fileName,
          status: DownloadStatus.merging,
          progress: 0.75, // 75% 合并进度
          fileSize: 1024 * 1024 * 500, // 500 MB
          downloadedSize: 1024 * 1024 * 375, // 375 MB
          filePath: '/test/path/$fileName',
        );
        break;

      case 'test_task_downloading':
        testTask = DownloadTask(
          id: id,
          url: testType,
          fileName: fileName.isEmpty ? 'test_downloading_file.iso' : fileName,
          status: DownloadStatus.downloading,
          progress: 0.45, // 45%
          fileSize: 1024 * 1024 * 1024 * 4, // 4 GB
          downloadedSize: 1024 * 1024 * 1024 * 4 * 0.45.toInt(),
          speed: 1024 * 1024 * 15.5, // 15.5 MB/s
          remainingTime: const Duration(minutes: 5, seconds: 30),
          filePath: '/test/path/$fileName',
          segments: _generateTestSegments(32, 0.45),
        );
        break;

      case 'test_task_paused':
        testTask = DownloadTask(
          id: id,
          url: testType,
          fileName: fileName.isEmpty ? 'test_paused_file.mp4' : fileName,
          status: DownloadStatus.paused,
          progress: 0.62, // 62%
          fileSize: 1024 * 1024 * 800, // 800 MB
          downloadedSize: 1024 * 1024 * 800 * 0.62.toInt(),
          filePath: '/test/path/$fileName',
          segments: _generateTestSegments(16, 0.62),
        );
        break;

      case 'test_task_pending':
        testTask = DownloadTask(
          id: id,
          url: testType,
          fileName: fileName.isEmpty ? 'test_pending_file.pdf' : fileName,
          status: DownloadStatus.pending,
          progress: 0.0,
          fileSize: 1024 * 1024 * 50, // 50 MB
          downloadedSize: 0,
          filePath: '/test/path/$fileName',
        );
        break;

      case 'test_task_failed':
        testTask = DownloadTask(
          id: id,
          url: testType,
          fileName: fileName.isEmpty ? 'test_failed_file.exe' : fileName,
          status: DownloadStatus.failed,
          progress: 0.28, // 28%
          fileSize: 1024 * 1024 * 200, // 200 MB
          downloadedSize: 1024 * 1024 * 200 * 0.28.toInt(),
          error: 'Network connection lost',
          filePath: '/test/path/$fileName',
          segments: _generateTestSegments(8, 0.28, failedCount: 2),
        );
        break;

      default:
        _appLogger.warning('App', 'Unknown test task type: $testType');
        return null;
    }

    _addTask(testTask);
    _appLogger.info(
        'App', 'Test task added: ${testTask.fileName} (${testTask.status})');
    notifyNow();
    return id;
  }

  // 生成测试分段
  List<SegmentInfo> _generateTestSegments(int count, double overallProgress,
      {int failedCount = 0}) {
    final segments = <SegmentInfo>[];
    const segmentSize = 1024 * 1024 * 100; // 每个分段 100 MB

    for (int i = 0; i < count; i++) {
      final startByte = i * segmentSize;
      final endByte = (i + 1) * segmentSize;

      String status;
      int downloadedBytes;
      double speed = 0;

      if (i < count * overallProgress) {
        // 已完成的分段
        status = 'completed';
        downloadedBytes = segmentSize;
      } else if (i == (count * overallProgress).floor() &&
          overallProgress % 1 != 0) {
        // 正在下载的分段
        status = 'downloading';
        downloadedBytes = (segmentSize * (overallProgress % 1)).toInt();
        speed = 1024 * 1024 * 0.5; // 0.5 MB/s
      } else if (failedCount > 0 && i >= count - failedCount) {
        // 失败的分段
        status = 'failed';
        downloadedBytes = (segmentSize * 0.3).toInt();
      } else {
        // 等待的分段
        status = 'pending';
        downloadedBytes = 0;
      }

      segments.add(SegmentInfo(
        index: i,
        startByte: startByte,
        endByte: endByte,
        downloadedBytes: downloadedBytes,
        speed: speed,
        status: status,
        retryCount: status == 'failed' ? 2 : 0,
      ));
    }

    return segments;
  }

  Future<void> pauseTask(String id) async {
    await _pluginTaskService.ensureInitialized();
    if (_pluginTaskService.hasTask(id)) {
      final success = await _pluginTaskService.pauseTask(id);
      if (success) {
        await _syncPluginTasks(refresh: false);
        notifyNow();
      } else {
        _appLogger.error('App', 'Failed to pause plugin task: $id');
      }
      return;
    }

    final task = _findTaskById(id);
    if (task == null) {
      _appLogger.warning('App', 'Pause ignored: task not found (ID: $id)');
      return;
    }
    _appLogger.info('App', 'Pausing task: ${task.fileName} (ID: $id)');

    final success = await _kernelManager.pauseDownload(id);

    if (success) {
      _appLogger.info('App', 'Task paused successfully: ${task.fileName}');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to pause task: ${task.fileName}');
    }
  }

  Future<void> resumeTask(String id) async {
    await _pluginTaskService.ensureInitialized();
    if (_pluginTaskService.hasTask(id)) {
      final success = await _pluginTaskService.resumeTask(id);
      if (success) {
        await _syncPluginTasks(refresh: false);
        notifyNow();
      } else {
        _appLogger.error('App', 'Failed to resume plugin task: $id');
      }
      return;
    }

    final task = _findTaskById(id);
    if (task == null) {
      _appLogger.warning('App', 'Resume ignored: task not found (ID: $id)');
      return;
    }
    _appLogger.info('App', 'Resuming task: ${task.fileName} (ID: $id)');

    final success = await _kernelManager.resumeDownload(id);

    if (success) {
      _appLogger.info('App', 'Task resumed successfully: ${task.fileName}');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to resume task: ${task.fileName}');
    }
  }

  Future<void> removeTask(String id) async {
    await _pluginTaskService.ensureInitialized();
    if (_pluginTaskService.hasTask(id)) {
      await _pluginTaskService.removeTask(id);
      _removeTaskById(id);
      _clientConfig.setTaskTags(id, []);
      _appLogger.info('App', 'Plugin task removed successfully: $id');
      notifyNow();
      return;
    }

    final task = _findTaskById(id);

    if (task == null) {
      _appLogger.error('App', 'Task not found for removal: $id');
      return;
    }

    _appLogger.info('App', 'Removing task: ${task.fileName} (ID: $id)');

    final success = await _kernelManager.cancelDownload(id);

    if (success) {
      _removeTaskById(id);
      _clientConfig.setTaskTags(id, []);
      _appLogger.info('App', 'Task removed successfully: ${task.fileName}');
      notifyNow();
    } else {
      _appLogger.error(
          'App', 'Failed to remove task: ${task.fileName} (ID: $id)');
    }
  }

  Future<bool> renameTaskFile(String id, String newFileName) async {
    await _pluginTaskService.ensureInitialized();
    if (_pluginTaskService.hasTask(id)) {
      _appLogger.warning('App', 'Rename ignored for plugin task (ID: $id)');
      return false;
    }

    final task = _findTaskById(id);
    if (task == null) {
      _appLogger.warning('App', 'Rename ignored: task not found (ID: $id)');
      return false;
    }
    final success = await _kernelManager.renameTask(id, newFileName);
    if (success) {
      _appLogger.info('App', 'Task renamed: ${task.fileName} -> $newFileName');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to rename task: ${task.fileName}');
    }
    return success;
  }

  Future<bool> moveTaskFile(String id, String targetDir) async {
    await _pluginTaskService.ensureInitialized();
    if (_pluginTaskService.hasTask(id)) {
      _appLogger.warning('App', 'Move ignored for plugin task (ID: $id)');
      return false;
    }

    final task = _findTaskById(id);
    if (task == null) {
      _appLogger.warning('App', 'Move ignored: task not found (ID: $id)');
      return false;
    }
    final success = await _kernelManager.moveTask(id, targetDir);
    if (success) {
      _appLogger.info('App', 'Task moved: ${task.fileName} -> $targetDir');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to move task: ${task.fileName}');
    }
    return success;
  }

  Future<void> startTask(String id) async {
    await resumeTask(id);
  }

  /// 重启内核后：清空任务缓存并重新拉取
  Future<void> resetTasksAndReload() async {
    _clearTasks();
    _hasActiveDownloads = false;
    _hasLoadedOnce = false;
    notifyNow();

    // 重新订阅内核流
    _subscribeToKernelStreams();
    await _updateTasks();
  }

  Future<Map<String, dynamic>?> getDownloadConfig() async {
    final config = await _kernelManager.getConfig();
    if (config == null) return null;
    return {
      'threads': config.threads,
      'segments': config.segments,
      'mode': config.mode,
      'max_concurrent_tasks': config.maxConcurrentTasks,
      'segment_speed_limit': config.segmentSpeedLimit,
      'global_speed_limit': config.globalSpeedLimit,
      'enable_dynamic_segments': config.enableDynamicSegments,
      'conflict_strategy': config.conflictStrategy,
      'default_user_agent': config.defaultUserAgent,
      'http_version_policy': config.httpVersionPolicy,
      'proxy': config.proxy != null
          ? {
              'enabled': config.proxy!.enabled,
              'type': config.proxy!.type,
              'host': config.proxy!.host,
              'port': config.proxy!.port,
              'username': config.proxy!.username,
              'password': config.proxy!.password,
              'requires_auth': config.proxy!.requiresAuth,
            }
          : null,
    };
  }

  Future<bool> setDownloadConfig({
    int? threads,
    int? segments,
    String? mode,
    int? maxConcurrentTasks,
    int? segmentSpeedLimit,
    int? globalSpeedLimit,
    bool? enableDynamicSegments,
    String? conflictStrategy,
    String? defaultUserAgent,
    String? httpVersionPolicy,
    Map<String, dynamic>? proxyConfig,
  }) async {
    final existing = await _kernelManager.getConfig();
    String effectiveConflictStrategy =
        conflictStrategy ?? existing?.conflictStrategy ?? 'increment';

    kernel.ProxyConfig? proxy;
    if (proxyConfig != null) {
      proxy = kernel.ProxyConfig(
        enabled: proxyConfig['enabled'] ?? false,
        type: proxyConfig['type'] ?? 'http',
        host: proxyConfig['host'] ?? '',
        port: proxyConfig['port'] ?? 7897,
        username: proxyConfig['username'],
        password: proxyConfig['password'],
        requiresAuth: proxyConfig['requires_auth'] ?? false,
      );
    }

    final config = kernel.DownloadConfig(
      threads: threads ?? existing?.threads ?? 8,
      segments: segments ?? existing?.segments ?? 8,
      mode: mode ?? existing?.mode ?? 'auto',
      maxConcurrentTasks:
          maxConcurrentTasks ?? existing?.maxConcurrentTasks ?? 3,
      segmentSpeedLimit: segmentSpeedLimit ?? existing?.segmentSpeedLimit ?? 0,
      globalSpeedLimit: globalSpeedLimit ?? existing?.globalSpeedLimit ?? 0,
      enableDynamicSegments:
          enableDynamicSegments ?? existing?.enableDynamicSegments ?? true,
      conflictStrategy: effectiveConflictStrategy,
      defaultUserAgent: defaultUserAgent ??
          existing?.defaultUserAgent ??
          kernel.DownloadConfig.defaultUserAgentFallback,
      httpVersionPolicy:
          httpVersionPolicy ?? existing?.httpVersionPolicy ?? 'auto',
      proxy: proxy ?? existing?.proxy,
    );
    final success = await _kernelManager.setConfig(config);

    if (success) {
      _appLogger.info('App',
          'Download config updated: threads=$threads, segments=$segments, mode=$mode, concurrent=$maxConcurrentTasks, segLimit=$segmentSpeedLimit, globalLimit=$globalSpeedLimit, dynamicSegments=$enableDynamicSegments, proxy=${proxyConfig != null ? 'enabled' : 'unchanged'}');
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
      final result = await _kernelManager.testProxyConnection(
        type: type,
        host: host,
        port: port,
        username: username,
        password: password,
      );
      _appLogger.info('App',
          'Proxy connection test: $type://$host:$port - ${result ? 'success' : 'failed'}');
      return result;
    } catch (e) {
      _appLogger.error('App', 'Proxy connection test failed: $e');
      return false;
    }
  }

  /// 重试失败的分段
  Future<void> retryFailedSegments(String id) async {
    final task = _findTaskById(id);
    if (task == null) {
      _appLogger.warning('App', 'Retry ignored: task not found (ID: $id)');
      return;
    }
    _appLogger.info(
        'App', 'Retrying failed segments for task: ${task.fileName} (ID: $id)');

    final success = await _kernelManager.retryFailedSegments(id);

    if (success) {
      _appLogger.info(
          'App', 'Failed segments retry initiated: ${task.fileName}');
      await _updateTasks();
    } else {
      _appLogger.error('App', 'Failed to retry segments: ${task.fileName}');
    }
  }

  /// 重试特定分段
  Future<void> retrySegment(String id, int segmentIndex) async {
    final task = _findTaskById(id);
    if (task == null) {
      _appLogger.warning(
          'App', 'Segment retry ignored: task not found (ID: $id)');
      return;
    }
    _appLogger.info('App',
        'Retrying segment $segmentIndex for task: ${task.fileName} (ID: $id)');

    final success = await _kernelManager.retrySegment(id, segmentIndex);

    if (success) {
      _appLogger.info(
          'App', 'Segment $segmentIndex retry initiated: ${task.fileName}');
      await _updateTasks();
    } else {
      _appLogger.error(
          'App', 'Failed to retry segment $segmentIndex: ${task.fileName}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _notifyTimer?.cancel();
    _stopBackgroundMemoryMaintenance();
    _progressSubscription?.cancel();
    _completeSubscription?.cancel();
    super.dispose();
  }
}
