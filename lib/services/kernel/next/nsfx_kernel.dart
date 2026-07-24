import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import '../kernel_interface.dart';
import 'models/task.dart';
import 'models/segment.dart';
import 'config/download_config.dart';
import 'downloader/download_engine.dart';
import 'downloader/http_client.dart';
import 'storage/task_storage.dart';
import 'server/http_server.dart';
import '../../../utils/constants.dart';
import '../../app_logger_service.dart';
import '../../client_config_service.dart';

class NsfxKernel implements KernelInterface {
  NsfxKernel({KernelInterface? commandRouter}) : _commandRouter = commandRouter;

  final KernelInterface? _commandRouter;
  bool _isRunning = false;
  bool _stopping = false;
  Future<void>? _stopFuture;
  late NsfxConfig _config;
  late NsfxHttpClient _httpClient;
  late DownloadEngine _engine;
  late TaskStorage _storage;
  NsfxHttpServer? _httpServer;
  final _logger = AppLoggerService();

  String _downloadDir = '';
  final Map<String, Task> _tasks = {};

  final _progressController = StreamController<DownloadTask>.broadcast();
  final _completeController = StreamController<DownloadTask>.broadcast();
  late final _statsController = StreamController<DownloadStatistics>.broadcast(
    onListen: _ensureStatsTimer,
    onCancel: _stopStatsTimer,
  );

  Timer? _statsTimer;
  Timer? _saveTimer;

  // 节流控制，避免 Windows 消息队列溢出
  DateTime _lastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minProgressEmitInterval = Duration(milliseconds: 100);

  // 记录上次发送的状态和文件大小，用于检测关键变化
  final Map<String, TaskStatus> _lastEmittedStatus = {};
  final Map<String, int> _lastEmittedTotalSize = {};

  @override
  String get name => AppConstants.newKernelFullName;

  @override
  bool get isRunning => _isRunning;

  @override
  Stream<DownloadTask> get onProgress => _progressController.stream;

  @override
  Stream<DownloadTask> get onComplete => _completeController.stream;

  @override
  Stream<DownloadStatistics> get onStatistics => _statsController.stream;

  @override
  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      _logger.info('NSFX', 'Starting NSFX kernel...');

      _storage = TaskStorage();
      await _storage.init();

      _config = await _storage.loadConfig();
      NsfxHttpClient.restoreAdaptiveHostStrategies(
        await _storage.loadHostStrategies(),
      );
      _httpClient = NsfxHttpClient(_config);

      _engine = DownloadEngine(
        config: _config,
        httpClient: _httpClient,
        onProgress: _onTaskProgress,
        onComplete: _onTaskComplete,
        onError: _onTaskError,
      );

      _tasks.addAll(await _storage.loadTasks());
      final recoveredTaskStates = await _recoverLoadedTaskStates();
      if (_tasks.isNotEmpty) {
        _logger.info('NSFX', 'Loaded ${_tasks.length} tasks from storage');
      }
      if (recoveredTaskStates) {
        await _storage.saveTasks(_tasks);
      }

      // 设置默认下载目录
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.current.path;
      _downloadDir = p.join(home, 'Downloads');

      // 启动统计定时器
      // 启动自动保存
      _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!_hasActiveWork()) {
          return;
        }
        _saveTasksInBackground('periodic checkpoint');
      });

      // 启动 HTTP 服务器（用于浏览器扩展通信）
      final httpStarted = await _startHttpServer();
      if (!httpStarted) {
        _logger.warning('NSFX',
            'HTTP server failed to start, browser extension may not work');
      }

      _isRunning = true;
      _logger.info('NSFX', 'NSFX kernel started successfully');
      return true;
    } catch (e) {
      _logger.error('NSFX', 'Failed to start kernel: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (_stopFuture != null) {
      await _stopFuture;
      return;
    }
    _stopping = true;
    _stopFuture = _stopInternal();
    try {
      await _stopFuture;
    } finally {
      _stopping = false;
      _stopFuture = null;
    }
  }

  Future<void> _stopInternal() async {
    _logger.info('NSFX', 'Stopping NSFX kernel...');
    _stopStatsTimer();
    _saveTimer?.cancel();
    _saveTimer = null;

    for (final task in _tasks.values) {
      if (task.status == TaskStatus.downloading ||
          task.status == TaskStatus.merging) {
        task.status = TaskStatus.paused;
        task.speed = 0;
        task.eta = 0;
        for (final segment in task.segments) {
          if (segment.status == SegmentStatus.downloading) {
            segment.status = SegmentStatus.paused;
            segment.speed = 0;
          }
        }
      }
    }

    try {
      await _engine.pauseAllActive();
    } catch (e) {
      _logger.warning('NSFX', 'Failed to pause active downloads on stop: $e');
    }

    for (final task in _tasks.values) {
      if (task.status == TaskStatus.paused ||
          task.status == TaskStatus.failed) {
        try {
          await _engine.discardIncompleteMergeArtifact(task);
          await _engine.calibrateTaskProgressFromDisk(task);
        } catch (e) {
          _logger.debug(
            'NSFX',
            'Failed to calibrate task ${task.id} on stop: $e',
          );
        }
      }
    }

    await _httpServer?.stop();
    await _storage.saveTasks(_tasks);
    await _storage
        .saveHostStrategies(NsfxHttpClient.exportAdaptiveHostStrategies());
    _httpClient.close();

    _isRunning = false;
    _logger.info('NSFX', 'NSFX kernel stopped');
  }

  void _ensureStatsTimer() {
    _statsTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      _emitStatistics();
    });
  }

  void _stopStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  bool _hasActiveWork() {
    return _tasks.values.any(
      (task) =>
          task.status == TaskStatus.downloading ||
          task.status == TaskStatus.pending ||
          task.status == TaskStatus.merging,
    );
  }

  @override
  Future<String?> addDownload(
    String url,
    String filename, {
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
    String? saveDir,
    bool startPaused = false,
    int? expectedSizeHint,
  }) async {
    if (!_isRunning) return null;

    final id = _generateId();
    final targetDir =
        (saveDir?.trim().isNotEmpty ?? false) ? saveDir!.trim() : _downloadDir;
    final dir = Directory(targetDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final resolvedFilename =
        await _resolveFileNameConflict(filename, targetDir);
    final filepath = p.join(targetDir, resolvedFilename);

    if (resolvedFilename != filename) {
      _logger.info(
          'NSFX', 'Filename conflict resolved: $filename -> $resolvedFilename');
    }
    _logger.info('NSFX', 'Adding download: $resolvedFilename');
    _logger.debug('NSFX', 'URL: $url');

    final task = Task(
      id: id,
      url: url,
      filename: resolvedFilename,
      filepath: filepath,
      status: startPaused ? TaskStatus.paused : TaskStatus.pending,
      userAgent: userAgent,
      referer: referer,
      cookies: cookies,
      headers: headers?.map((k, v) => MapEntry(k, v.toString())),
      expectedSizeHint: expectedSizeHint != null && expectedSizeHint > 0
          ? expectedSizeHint
          : null,
    );

    _tasks[id] = task;

    // Snapshot the task for durable storage immediately, but do not hold the
    // first network request behind a full atomic JSON flush. The add call still
    // awaits persistence before it reports success, while the transfer and the
    // disk write can make progress concurrently.
    final persistence = _storage.saveTasks(_tasks);

    if (!startPaused) {
      _checkQueue();
    }

    await persistence;

    _logger.info('NSFX', 'Download added with ID: $id');
    return id;
  }

  void _checkQueue() {
    final activeCount =
        _tasks.values.where((t) => t.status == TaskStatus.downloading).length;

    if (activeCount >= _config.maxConcurrentTasks) return;

    final pendingTasks = _tasks.values
        .where((t) => t.status == TaskStatus.pending)
        .toList()
      ..sort((a, b) => a.createdTime.compareTo(b.createdTime));

    final slotsAvailable = _config.maxConcurrentTasks - activeCount;
    for (int i = 0; i < slotsAvailable && i < pendingTasks.length; i++) {
      _engine.startDownload(pendingTasks[i]);
    }
  }

  Future<bool> _recoverLoadedTaskStates() async {
    var changed = false;

    for (final task in _tasks.values) {
      // 1) Always discard incomplete merge staging / journal leftovers.
      try {
        final mergingFile = File('${task.filepath}.nsfx_merging');
        final hadMerging = await mergingFile.exists();
        await _engine.discardIncompleteMergeArtifact(task);
        if (hadMerging) {
          _logger.warning(
            'NSFX',
            'Discarded incomplete merge artifact on recovery: '
                '${mergingFile.path}',
          );
          changed = true;
        }
      } catch (e) {
        _logger.warning(
          'NSFX',
          'Failed to discard merge artifacts for ${task.filename}: $e',
        );
      }

      // Completed tasks: only heal dirty segment runtime flags.
      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.cancelled) {
        continue;
      }

      task.speed = 0;
      task.eta = 0;

      final file = File(task.filepath);
      final partialFile = File('${task.filepath}.nsfx_partial');
      var fileExists = await file.exists();
      var fileLength = fileExists ? await file.length() : 0;

      // A direct-write partial is preallocated to totalSize, so file length is
      // not evidence of completion.  Promote only after the engine verifies
      // the continuous segment layout and every durable completion marker.
      if (!fileExists && await partialFile.exists()) {
        try {
          final promoted = await _engine.recoverCompletedDirectWrite(task);
          if (promoted) {
            fileExists = true;
            fileLength = await file.length();
            changed = true;
            _logger.info(
              'NSFX',
              'Promoted completed direct-write partial on recovery: '
                  '${task.filename}',
            );
          }
        } catch (e) {
          _logger.warning(
            'NSFX',
            'Failed to verify/promote direct-write partial for '
                '${task.filename}: $e',
          );
        }
      }

      final hasExpectedSize =
          task.totalSize > 0 && fileLength >= task.totalSize;
      final hasPersistedCompleteProgress = task.progress >= 100 &&
          task.downloadedSize > 0 &&
          fileLength >= task.downloadedSize;
      final isCompleteFile = fileExists &&
          fileLength > 0 &&
          (hasExpectedSize || hasPersistedCompleteProgress);

      // 2) Full final file => completed.
      if (isCompleteFile) {
        if (task.status != TaskStatus.completed) {
          task.status = TaskStatus.completed;
          task.downloadedSize = fileLength;
          if (task.totalSize <= 0 || fileLength > task.totalSize) {
            task.totalSize = fileLength;
          }
          task.progress = 100;
          task.endTime ??= DateTime.now();
          task.targetReachable = true;
          task.errorMessage = null;
          _logger.info(
            'NSFX',
            'Recovered completed task from disk: ${task.filename}',
          );
          changed = true;
        }
        continue;
      }

      final wasActive = task.status == TaskStatus.downloading ||
          task.status == TaskStatus.merging;
      final hasDirtySegmentRuntime = task.segments.any(
        (segment) =>
            segment.status == SegmentStatus.downloading ||
            (wasActive && segment.status == SegmentStatus.pending),
      );
      final hasPartialData = await _engine.hasRecoverablePartialData(task) ||
          task.downloadedSize > 0 ||
          task.segments.any((s) => s.downloadedBytes > 0);

      // 3/4) Interrupted active work, or any partial on disk => paused + calibrate.
      if (wasActive || hasDirtySegmentRuntime || hasPartialData) {
        final previousStatus = task.status;
        if (wasActive || task.status == TaskStatus.pending) {
          task.status = TaskStatus.paused;
        }

        try {
          await _engine.calibrateTaskProgressFromDisk(task);
        } catch (_) {
          task.progress = task.totalSize > 0
              ? (task.downloadedSize / task.totalSize) * 100
              : 0;
          for (final segment in task.segments) {
            if (segment.status == SegmentStatus.downloading) {
              segment.status = SegmentStatus.paused;
              segment.speed = 0;
            }
          }
        }

        // Keep failed tasks failed unless they were mid-transfer.
        if (wasActive && previousStatus != TaskStatus.failed) {
          task.status = TaskStatus.paused;
        } else if (previousStatus == TaskStatus.failed) {
          task.status = TaskStatus.failed;
        }

        _logger.warning(
          'NSFX',
          'Recovered task as ${task.status.name} with disk-calibrated '
              'progress: ${task.filename} '
              '(${task.downloadedSize}/${task.totalSize})',
        );
        changed = true;
        continue;
      }

      // 5) Clear leftover downloading markers on idle tasks.
      if (task.status == TaskStatus.downloading ||
          task.status == TaskStatus.merging) {
        task.status = TaskStatus.paused;
        changed = true;
      }
      for (final segment in task.segments) {
        if (segment.status == SegmentStatus.downloading) {
          segment.status = SegmentStatus.paused;
          segment.speed = 0;
          changed = true;
        }
      }
    }

    return changed;
  }

  Future<String> _resolveFileNameConflict(
    String filename,
    String targetDir,
  ) async {
    final cleaned = filename.trim();
    if (cleaned.isEmpty) return filename;

    final originalPath = p.join(targetDir, cleaned);
    final strategy = _config.conflictStrategy;
    final taskConflict = _hasTaskConflict(originalPath);
    final fileExists = await File(originalPath).exists();
    if (!taskConflict && !fileExists) return cleaned;

    if (strategy == 'overwrite' && !taskConflict && fileExists) {
      await _deleteIfExists(originalPath);
      return cleaned;
    }

    final baseName = p.basenameWithoutExtension(cleaned);
    final extension = p.extension(cleaned);

    if (strategy == 'timestamp') {
      final stamp = _formatTimestamp(DateTime.now());
      var candidate = '${baseName}_$stamp$extension';
      var candidatePath = p.join(targetDir, candidate);
      if (await _pathConflictExists(candidatePath)) {
        candidate =
            '${baseName}_${stamp}_${DateTime.now().millisecondsSinceEpoch}$extension';
      }
      return candidate;
    }

    // 默认：递增序号 (1)(2)...
    for (int i = 1; i < 10000; i++) {
      final candidate = '$baseName ($i)$extension';
      final candidatePath = p.join(targetDir, candidate);
      if (!await _pathConflictExists(candidatePath)) {
        return candidate;
      }
    }

    return '${baseName}_${DateTime.now().millisecondsSinceEpoch}$extension';
  }

  bool _hasTaskConflict(String filepath) {
    final normalizedPath = p.normalize(filepath).toLowerCase();
    return _tasks.values.any(
      (task) => p.normalize(task.filepath).toLowerCase() == normalizedPath,
    );
  }

  Future<bool> _pathConflictExists(String filepath) async {
    if (_hasTaskConflict(filepath)) return true;
    return await File(filepath).exists();
  }

  Future<void> _deleteIfExists(String filepath) async {
    try {
      final file = File(filepath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String _formatTimestamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}_${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }

  @override
  Future<bool> pauseDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status != TaskStatus.downloading) return false;

    task.status = TaskStatus.paused;
    await _engine.pauseDownload(taskId);
    try {
      await _engine.calibrateTaskProgressFromDisk(task);
    } catch (e) {
      _logger.debug('NSFX', 'Failed to calibrate paused task $taskId: $e');
    }
    if (!_progressController.isClosed) {
      _progressController.add(_toDownloadTask(task));
    }

    await _storage.saveTasks(_tasks);

    _checkQueue();
    return true;
  }

  @override
  Future<bool> resumeDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return false;
    if (task.status != TaskStatus.paused && task.status != TaskStatus.failed) {
      return false;
    }

    task.status = TaskStatus.pending;
    _checkQueue();
    return true;
  }

  @override
  Future<bool> cancelDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return false;

    task.status = TaskStatus.cancelled;
    await _engine.cancelDownload(taskId);
    _tasks.remove(taskId);

    await _storage.saveTasks(_tasks);

    try {
      final file = File(task.filepath);
      if (await file.exists()) await file.delete();

      final mergingFile = File('${task.filepath}.nsfx_merging');
      if (await mergingFile.exists()) await mergingFile.delete();

      final partialFile = File('${task.filepath}.nsfx_partial');
      if (await partialFile.exists()) await partialFile.delete();

      final tempDir = Directory(p.join(
        File(task.filepath).parent.path,
        '.nsfx_temp',
        taskId,
      ));
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}

    _checkQueue();
    return true;
  }

  @override
  Future<bool> renameTask(String taskId, String newFileName) async {
    final task = _tasks[taskId];
    if (task == null) return false;
    if (task.status != TaskStatus.completed) return false;
    final trimmed = newFileName.trim();
    if (trimmed.isEmpty) return false;

    final currentPath = task.filepath;
    final dir = p.dirname(currentPath);
    final newPath = p.join(dir, trimmed);
    return _updateTaskFilePath(task, newPath);
  }

  @override
  Future<bool> moveTask(String taskId, String targetDir) async {
    final task = _tasks[taskId];
    if (task == null) return false;
    if (task.status != TaskStatus.completed) return false;
    final trimmed = targetDir.trim();
    if (trimmed.isEmpty) return false;

    final fileName = p.basename(task.filepath);
    final newPath = p.join(trimmed, fileName);
    return _updateTaskFilePath(task, newPath);
  }

  @override
  Future<bool> retryFailedSegments(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return false;

    for (final segment in task.segments) {
      if (segment.status == SegmentStatus.failed) {
        segment.status = SegmentStatus.pending;
        segment.retryCount = 0;
      }
    }

    if (task.status == TaskStatus.failed) {
      task.status = TaskStatus.pending;
      _checkQueue();
    }

    return true;
  }

  @override
  Future<bool> retrySegment(String taskId, int segmentIndex) async {
    final task = _tasks[taskId];
    if (task == null) return false;

    final segment = task.segments.firstWhere(
      (s) => s.index == segmentIndex,
      orElse: () => throw Exception('Segment not found'),
    );

    segment.status = SegmentStatus.pending;
    segment.retryCount = 0;

    if (task.status == TaskStatus.failed) {
      task.status = TaskStatus.pending;
      _checkQueue();
    }

    return true;
  }

  @override
  Future<List<DownloadTask>> getTasks() async {
    return _tasks.values.map(_toDownloadTask).toList();
  }

  @override
  Future<DownloadStatistics?> getStatistics() async {
    return _calculateStatistics();
  }

  @override
  Future<DownloadConfig?> getConfig() async {
    return DownloadConfig(
      threads: _config.threads,
      segments: _config.segments,
      mode: _config.mode,
      maxConcurrentTasks: _config.maxConcurrentTasks,
      segmentSpeedLimit: _config.segmentSpeedLimit,
      globalSpeedLimit: _config.globalSpeedLimit,
      enableDynamicSegments: _config.enableDynamicSegments,
      conflictStrategy: _config.conflictStrategy,
      defaultUserAgent: _config.defaultUserAgent,
      httpVersionPolicy: _config.httpVersionPolicy,
      allowInsecureTls: _config.allowInsecureTls,
      globalMaxConnections: _config.globalMaxConnections,
      connectionTimeout: _config.connectionTimeout,
      readTimeout: _config.readTimeout,
      proxy: ProxyConfig(
        enabled: _config.proxy.enabled,
        type: _config.proxy.type,
        host: _config.proxy.host,
        port: _config.proxy.port,
        username: _config.proxy.username,
        password: _config.proxy.password,
        requiresAuth: _config.proxy.requiresAuth,
      ),
    );
  }

  @override
  Future<bool> setConfig(DownloadConfig config) async {
    _config.threads = config.threads;
    _config.segments = config.segments;
    _config.mode = config.mode;
    _config.maxConcurrentTasks = config.maxConcurrentTasks;
    _config.segmentSpeedLimit = config.segmentSpeedLimit;
    _config.globalSpeedLimit = config.globalSpeedLimit;
    _config.enableDynamicSegments = config.enableDynamicSegments;
    _config.conflictStrategy = config.conflictStrategy;
    _config.defaultUserAgent = config.defaultUserAgent.trim().isEmpty
        ? NsfxConfig.defaultUserAgentFallback
        : config.defaultUserAgent;
    _config.httpVersionPolicy =
        NsfxHttpVersionPolicy.normalize(config.httpVersionPolicy);
    _config.allowInsecureTls = config.allowInsecureTls;
    _config.globalMaxConnections =
        NsfxConnectionBudget.normalize(config.globalMaxConnections);
    _config.connectionTimeout = config.connectionTimeout.clamp(3, 120);
    _config.readTimeout = config.readTimeout.clamp(5, 300);
    _config.maxRetries =
        NsfxRetryPolicy.effectiveMaxRetries(_config.maxRetries);
    _engine.syncRuntimeBudgets();

    if (config.proxy != null) {
      _config.proxy.enabled = config.proxy!.enabled;
      _config.proxy.type = config.proxy!.type;
      _config.proxy.host = config.proxy!.host;
      _config.proxy.port = config.proxy!.port;
      _config.proxy.username = config.proxy!.username;
      _config.proxy.password = config.proxy!.password;
      _config.proxy.requiresAuth = config.proxy!.requiresAuth;
    }

    await _storage.saveConfig(_config);

    // 重建 HTTP 客户端以应用新配置
    NsfxHttpClient.clearSharedProxyState();
    _httpClient.close();
    _httpClient = NsfxHttpClient(_config);

    return true;
  }

  @override
  Future<String?> getDownloadDir() async {
    return _downloadDir;
  }

  @override
  Future<bool> setDownloadDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _downloadDir = path;
    return true;
  }

  @override
  Future<bool> clearAllData() async {
    _tasks.clear();
    NsfxHttpClient.clearAdaptivePolicyHints();
    await _storage.clearAll();
    return true;
  }

  @override
  Future<Map<String, dynamic>> getAdaptiveHostStrategies() async {
    return NsfxHttpClient.exportAdaptiveHostStrategies();
  }

  @override
  Future<bool> clearAdaptiveHostStrategies() async {
    NsfxHttpClient.clearAdaptivePolicyHints();
    await _storage.saveHostStrategies(<String, dynamic>{});
    return true;
  }

  Future<bool> _updateTaskFilePath(Task task, String newPath) async {
    final currentPath = task.filepath;
    if (currentPath == newPath) return true;

    final currentFile = File(currentPath);
    if (!await currentFile.exists()) {
      _logger.warning(
          'NSFX', 'File not found for task ${task.id}: $currentPath');
      return false;
    }

    final newDir = Directory(p.dirname(newPath));
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }

    final moved = await _moveFile(currentPath, newPath);
    if (!moved) {
      _logger.warning('NSFX', 'Failed to move file: $currentPath -> $newPath');
      return false;
    }

    task.filepath = newPath;
    task.filename = p.basename(newPath);
    await _storage.saveTasks(_tasks);

    _progressController.add(_toDownloadTask(task));
    return true;
  }

  Future<bool> _moveFile(String fromPath, String toPath) async {
    final source = File(fromPath);
    try {
      await source.rename(toPath);
      return true;
    } catch (_) {
      try {
        await source.copy(toPath);
        await source.delete();
        return true;
      } catch (e) {
        _logger.warning('NSFX', 'File move failed: $e');
        return false;
      }
    }
  }

  @override
  Future<bool> testProxyConnection({
    required String type,
    required String host,
    required int port,
    String? username,
    String? password,
  }) async {
    try {
      final testConfig = NsfxConfig(
        proxy: NsfxProxyConfig(
          enabled: true,
          type: type,
          host: host,
          port: port,
          username: username,
          password: password,
          requiresAuth: username != null && password != null,
        ),
      );

      final testClient = NsfxHttpClient(testConfig);
      await testClient.getFileInfo(
        'https://www.google.com',
        {'User-Agent': 'NSFX/2.0'},
      );
      testClient.close();

      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> updateBrowserBridgePort(
    int port, {
    Iterable<int> compatibilityPorts = const [],
  }) async {
    final clientConfig = ClientConfigService();
    final normalizedPort =
        ClientConfigService.normalizeBrowserExtensionPortValue(port);
    final fallbackPort = clientConfig.getBrowserExtensionPort();
    final fallbackCompatibilityPorts =
        clientConfig.getBrowserExtensionCompatibilityPorts();

    final nextServer = NsfxHttpServer(
      _commandRouter ?? this,
      port: normalizedPort,
      compatibilityPorts: _buildCompatibilityPorts(
        primaryPort: normalizedPort,
        extraPorts: compatibilityPorts,
      ),
    );

    await _httpServer?.stop();
    _httpServer = nextServer;
    final started = await nextServer.start();
    if (started) {
      _logger.info(
        'NSFX',
        'Browser bridge rebound to 127.0.0.1:$normalizedPort',
      );
      return true;
    }

    _logger.error(
      'NSFX',
      'Failed to rebind browser bridge to port $normalizedPort',
    );
    final fallbackServer = NsfxHttpServer(
      _commandRouter ?? this,
      port: fallbackPort,
      compatibilityPorts: _buildCompatibilityPorts(
        primaryPort: fallbackPort,
        extraPorts: fallbackCompatibilityPorts,
      ),
    );
    _httpServer = fallbackServer;
    final rollbackStarted = await fallbackServer.start();
    if (!rollbackStarted) {
      _httpServer = null;
      _logger.error(
        'NSFX',
        'Failed to restore browser bridge on fallback port $fallbackPort',
      );
    }
    return false;
  }

  @override
  void dispose() {
    if (_isRunning && !_stopping) {
      unawaited(stop());
    }
    if (!_progressController.isClosed) {
      _progressController.close();
    }
    if (!_completeController.isClosed) {
      _completeController.close();
    }
    if (!_statsController.isClosed) {
      _statsController.close();
    }
  }

  void _onTaskProgress(Task task) {
    if (!_isRunning || _progressController.isClosed) return;

    final now = DateTime.now();

    // 检查是否有关键变化（状态变化或文件大小变化）
    final lastStatus = _lastEmittedStatus[task.id];
    final lastTotalSize = _lastEmittedTotalSize[task.id];
    final isStatusChanged = lastStatus != task.status;
    final isTotalSizeChanged =
        lastTotalSize != task.totalSize && task.totalSize > 0;
    final enteredMerging = isStatusChanged && task.status == TaskStatus.merging;
    final isCriticalChange =
        isStatusChanged || isTotalSizeChanged || enteredMerging;

    // 关键变化必须立即发送，普通进度更新会被节流
    if (!isCriticalChange &&
        now.difference(_lastProgressEmit) < _minProgressEmitInterval) {
      return;
    }

    // 更新记录
    _lastEmittedStatus[task.id] = task.status;
    _lastEmittedTotalSize[task.id] = task.totalSize;
    _lastProgressEmit = now;

    _progressController.add(_toDownloadTask(task));

    // 进入 merging / 关键状态变化时立即落盘，降低崩溃窗口
    if (enteredMerging ||
        (isStatusChanged &&
            (task.status == TaskStatus.paused ||
                task.status == TaskStatus.failed ||
                task.status == TaskStatus.completed))) {
      _saveTasksInBackground(
        enteredMerging ? 'merging' : 'status:${task.status.name}',
      );
    }
  }

  void _onTaskComplete(Task task) {
    if (!_isRunning) return;
    _logger.info('NSFX', 'Download completed: ${task.filename}');
    final completedTask = _toDownloadTask(task);
    _lastEmittedStatus[task.id] = task.status;
    _lastEmittedTotalSize[task.id] = task.totalSize;
    if (!_progressController.isClosed) {
      _progressController.add(completedTask);
    }
    if (!_completeController.isClosed) {
      _completeController.add(completedTask);
    }
    _saveTasksInBackground('completion');
    _checkQueue();
  }

  void _onTaskError(Task task) {
    if (!_isRunning) return;
    final errorMessage = task.errorMessage?.trim();
    if (errorMessage == null || errorMessage.isEmpty) {
      _logger.error('NSFX', 'Download failed: ${task.filename}');
    }
    if (!_progressController.isClosed) {
      _progressController.add(_toDownloadTask(task));
    }
    _saveTasksInBackground('failure');
    _checkQueue();
  }

  void _saveTasksInBackground(String reason) {
    unawaited(_storage.saveTasks(_tasks).catchError((error) {
      _logger.warning('NSFX', 'Failed to save tasks after $reason: $error');
    }));
    unawaited(
      _storage
          .saveHostStrategies(NsfxHttpClient.exportAdaptiveHostStrategies())
          .catchError((error) {
        _logger.warning(
          'NSFX',
          'Failed to save host strategies after $reason: $error',
        );
      }),
    );
  }

  void _emitStatistics() {
    _statsController.add(_calculateStatistics());
  }

  DownloadStatistics _calculateStatistics() {
    int activeDownloads = 0;
    double totalSpeed = 0;
    int totalDownloaded = 0;

    for (final task in _tasks.values) {
      if (task.status == TaskStatus.downloading) {
        activeDownloads++;
        totalSpeed += task.speed;
      }
      totalDownloaded += task.downloadedSize;
    }

    return DownloadStatistics(
      totalTasks: _tasks.length,
      activeDownloads: activeDownloads,
      totalSpeed: totalSpeed,
      totalDownloaded: totalDownloaded,
    );
  }

  DownloadTask _toDownloadTask(Task task) {
    return DownloadTask(
      id: task.id,
      url: task.url,
      filename: task.filename,
      filepath: task.filepath,
      status: _convertStatus(task.status),
      totalSize: task.totalSize,
      downloadedSize: task.downloadedSize,
      speed: task.speed,
      progress: task.progress,
      eta: task.eta,
      errorMessage: task.errorMessage,
      threadCount: task.threadCount,
      peakSpeed: task.peakSpeed,
      averageSpeed: task.averageSpeed,
      startTime: task.startTime,
      endTime: task.endTime,
      createdTime: task.createdTime, // preserve creation time
      effectiveHttpVersionPolicy: task.effectiveHttpVersionPolicy,
      negotiatedHttpVersion: task.negotiatedHttpVersion,
      targetReachable: task.targetReachable,
      httpPolicyDecisionReason: task.httpPolicyDecisionReason,
      startupStatusKey: task.startupStatusKey,
      resumeDecisionLabel: task.resumeDecisionLabel,
      resumeDecisionReason: task.resumeDecisionReason,
      hostConcurrencyCap: task.hostConcurrencyCap,
      hostConcurrencyReason: task.hostConcurrencyReason,
      segments: task.segments
          .map((s) => SegmentInfo(
                index: s.index,
                startByte: s.startByte,
                endByte: s.endByte,
                downloadedBytes: s.downloadedBytes,
                speed: s.speed,
                status: s.status.name,
                retryCount: s.retryCount,
                progress: s.progress,
              ))
          .toList(),
    );
  }

  DownloadStatus _convertStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return DownloadStatus.pending;
      case TaskStatus.downloading:
        return DownloadStatus.downloading;
      case TaskStatus.paused:
        return DownloadStatus.paused;
      case TaskStatus.completed:
        return DownloadStatus.completed;
      case TaskStatus.failed:
        return DownloadStatus.failed;
      case TaskStatus.cancelled:
        return DownloadStatus.cancelled;
      case TaskStatus.merging:
        return DownloadStatus.merging;
    }
  }

  String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<bool> _startHttpServer() async {
    final clientConfig = ClientConfigService();
    final bridgePort = clientConfig.getBrowserExtensionPort();
    _httpServer = NsfxHttpServer(
      _commandRouter ?? this,
      port: bridgePort,
      compatibilityPorts: _buildCompatibilityPorts(
        primaryPort: bridgePort,
        extraPorts: clientConfig.getBrowserExtensionCompatibilityPorts(),
      ),
    );
    return _httpServer!.start();
  }

  Iterable<int> _buildCompatibilityPorts({
    required int primaryPort,
    Iterable<int> extraPorts = const [],
  }) {
    final ports = <int>{
      ClientConfigService.defaultBrowserExtensionPort,
      ...extraPorts,
    };

    ports.remove(primaryPort);
    ports.removeWhere(
      (candidate) =>
          !ClientConfigService.isValidBrowserExtensionPortValue(candidate),
    );
    return ports;
  }
}
