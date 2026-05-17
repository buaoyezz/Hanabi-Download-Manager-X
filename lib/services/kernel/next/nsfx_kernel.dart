import 'dart:async';
import 'dart:convert';
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
import '../../app_logger_service.dart';
import '../../client_config_service.dart';

class NsfxKernel implements KernelInterface {
  bool _isRunning = false;
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
  final _statsController = StreamController<DownloadStatistics>.broadcast();

  Timer? _statsTimer;
  Timer? _saveTimer;
  int _tasksRevision = 0;
  int _savedTasksRevision = 0;
  String? _lastSavedHostStrategiesJson;
  static const int _defaultCompletedTaskDetailKeepCount = 80;

  // 节流控制，避免 Windows 消息队列溢出
  DateTime _lastProgressEmit = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minProgressEmitInterval = Duration(milliseconds: 100);

  // 记录上次发送的状态和文件大小，用于检测关键变化
  final Map<String, TaskStatus> _lastEmittedStatus = {};
  final Map<String, int> _lastEmittedTotalSize = {};

  @override
  String get name => 'NSFX (Next Speed Force X)';

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
      _savedTasksRevision = _tasksRevision;
      _lastSavedHostStrategiesJson =
          jsonEncode(NsfxHttpClient.exportAdaptiveHostStrategies());

      // 设置默认下载目录
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.current.path;
      _downloadDir = p.join(home, 'Downloads');

      // 启动统计定时器。无监听者时跳过计算，降低后台空转。
      _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _emitStatistics();
      });

      // 启动脏数据自动保存。空闲时不再每 5 秒重复写盘。
      _saveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(_flushPeriodicState());
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
    _logger.info('NSFX', 'Stopping NSFX kernel...');
    _statsTimer?.cancel();
    _saveTimer?.cancel();

    await _httpServer?.stop();
    await _saveTasksNow('shutdown');
    await _saveHostStrategiesIfChanged(force: true);
    _httpClient.close();

    _isRunning = false;
    _logger.info('NSFX', 'NSFX kernel stopped');
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
    );

    _tasks[id] = task;
    _markTasksDirty();

    // 绔嬪嵆淇濆瓨浠诲姟鍒楄〃
    await _saveTasksNow('add');

    if (!startPaused) {
      _checkQueue();
    }

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
      if (task.status != TaskStatus.downloading &&
          task.status != TaskStatus.merging) {
        continue;
      }

      task.speed = 0;
      task.eta = 0;

      final file = File(task.filepath);
      final fileExists = await file.exists();
      final fileLength = fileExists ? await file.length() : 0;
      final hasExpectedSize =
          task.totalSize > 0 && fileLength >= task.totalSize;
      final hasPersistedCompleteProgress = task.progress >= 100 &&
          task.downloadedSize > 0 &&
          fileLength >= task.downloadedSize;
      final isCompleteFile = fileExists &&
          fileLength > 0 &&
          (hasExpectedSize || hasPersistedCompleteProgress);

      if (isCompleteFile) {
        task.status = TaskStatus.completed;
        task.downloadedSize = fileLength;
        if (task.totalSize <= 0 || fileLength > task.totalSize) {
          task.totalSize = fileLength;
        }
        task.progress = 100;
        task.endTime ??= DateTime.now();
        task.targetReachable = true;
        _logger.info(
          'NSFX',
          'Recovered completed task from disk: ${task.filename}',
        );
      } else {
        task.status = TaskStatus.paused;
        task.progress = task.totalSize > 0
            ? (task.downloadedSize / task.totalSize) * 100
            : 0;
        for (final segment in task.segments) {
          if (segment.status == SegmentStatus.downloading) {
            segment.status = SegmentStatus.paused;
            segment.speed = 0;
          }
        }
        _logger.warning(
          'NSFX',
          'Recovered interrupted active task as paused: ${task.filename}',
        );
      }

      changed = true;
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
    _engine.pauseDownload(taskId);
    _progressController.add(_toDownloadTask(task));
    _markTasksDirty();

    // 绔嬪嵆淇濆瓨浠诲姟鍒楄〃
    await _saveTasksNow('pause');

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
    _markTasksDirty();
    _checkQueue();
    return true;
  }

  @override
  Future<bool> cancelDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return false;

    task.status = TaskStatus.cancelled;
    _engine.cancelDownload(taskId);
    _tasks.remove(taskId);
    _dropTaskBookkeeping(taskId);
    _markTasksDirty();

    // 绔嬪嵆淇濆瓨浠诲姟鍒楄〃
    await _saveTasksNow('cancel');

    // 娓呯悊鏂囦欢
    try {
      final file = File(task.filepath);
      if (await file.exists()) await file.delete();

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
      _markTasksDirty();
      _checkQueue();
    } else {
      _markTasksDirty();
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
      _markTasksDirty();
      _checkQueue();
    } else {
      _markTasksDirty();
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
  Future<int> compactCompletedTaskHistory({
    int keepRecentFullDetails = _defaultCompletedTaskDetailKeepCount,
  }) async {
    final compacted = _compactCompletedTaskHistoryInMemory(
      keepRecentFullDetails: keepRecentFullDetails,
    );
    NsfxHttpClient.compactSharedCaches();
    if (compacted == 0) {
      return 0;
    }

    _markTasksDirty();
    _logger.info(
      'NSFX',
      'Compacted $compacted completed task histories for background memory',
    );
    await _saveTasksNow('compact-history');
    return compacted;
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
    _lastEmittedStatus.clear();
    _lastEmittedTotalSize.clear();
    NsfxHttpClient.clearAdaptivePolicyHints();
    _markTasksDirty();
    await _storage.clearAll();
    _savedTasksRevision = _tasksRevision;
    _lastSavedHostStrategiesJson = jsonEncode(<String, dynamic>{});
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
    _lastSavedHostStrategiesJson = jsonEncode(<String, dynamic>{});
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
    _markTasksDirty();
    await _saveTasksNow('move');

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
      this,
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
      this,
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
    stop();
    _progressController.close();
    _completeController.close();
    _statsController.close();
  }

  void _onTaskProgress(Task task) {
    final now = DateTime.now();
    _markTasksDirty();

    // 检查是否有关键变化（状态变化或文件大小变化）
    final lastStatus = _lastEmittedStatus[task.id];
    final lastTotalSize = _lastEmittedTotalSize[task.id];
    final isStatusChanged = lastStatus != task.status;
    final isTotalSizeChanged =
        lastTotalSize != task.totalSize && task.totalSize > 0;
    final isCriticalChange = isStatusChanged || isTotalSizeChanged;

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
  }

  void _onTaskComplete(Task task) {
    _logger.info('NSFX', 'Download completed: ${task.filename}');
    _markTasksDirty();
    final completedTask = _toDownloadTask(task);
    _lastEmittedStatus[task.id] = task.status;
    _lastEmittedTotalSize[task.id] = task.totalSize;
    _progressController.add(completedTask);
    _completeController.add(completedTask);
    _saveTasksInBackground('completion');
    _checkQueue();
  }

  void _onTaskError(Task task) {
    _markTasksDirty();
    final errorMessage = task.errorMessage?.trim();
    if (errorMessage == null || errorMessage.isEmpty) {
      _logger.error('NSFX', 'Download failed: ${task.filename}');
    }
    _progressController.add(_toDownloadTask(task));
    _saveTasksInBackground('failure');
    _checkQueue();
  }

  void _saveTasksInBackground(String reason) {
    unawaited(_saveTasksNow(reason).catchError((error) {
      _logger.warning('NSFX', 'Failed to save tasks after $reason: $error');
    }));
  }

  void _emitStatistics() {
    if (!_statsController.hasListener) {
      return;
    }
    _statsController.add(_calculateStatistics());
  }

  void _markTasksDirty() {
    _tasksRevision++;
  }

  int _compactCompletedTaskHistoryInMemory({
    required int keepRecentFullDetails,
  }) {
    final completedTasks = _tasks.values
        .where((task) => task.status == TaskStatus.completed)
        .toList(growable: false)
      ..sort((a, b) {
        final aTime = a.endTime ?? a.createdTime;
        final bTime = b.endTime ?? b.createdTime;
        return bTime.compareTo(aTime);
      });

    if (completedTasks.length <= keepRecentFullDetails) {
      return 0;
    }

    var compacted = 0;
    for (var i = keepRecentFullDetails; i < completedTasks.length; i++) {
      if (_compactCompletedTask(completedTasks[i])) {
        compacted++;
      }
    }
    return compacted;
  }

  bool _compactCompletedTask(Task task) {
    var changed = false;

    final existingSegmentCount = task.segmentCountHint ?? task.segments.length;
    if (existingSegmentCount > 0 &&
        (task.segmentCountHint == null ||
            task.segmentCountHint! < existingSegmentCount)) {
      task.segmentCountHint = existingSegmentCount;
      changed = true;
    }

    if (task.segments.isNotEmpty) {
      task.segments.clear();
      changed = true;
    }
    if (task.headers != null) {
      task.headers = null;
      changed = true;
    }
    if (task.cookies != null && task.cookies!.isNotEmpty) {
      task.cookies = null;
      changed = true;
    }
    if (task.userAgent != null && task.userAgent!.isNotEmpty) {
      task.userAgent = null;
      changed = true;
    }
    if (task.ifRangeValidator != null) {
      task.ifRangeValidator = null;
      changed = true;
    }
    if (task.startupStatusKey != null) {
      task.startupStatusKey = null;
      changed = true;
    }
    if (task.speed != 0) {
      task.speed = 0;
      changed = true;
    }
    if (task.eta != 0) {
      task.eta = 0;
      changed = true;
    }
    if (task.totalSize > 0 && task.downloadedSize != task.totalSize) {
      task.downloadedSize = min(task.downloadedSize, task.totalSize);
      changed = true;
    }
    if (task.progress != 100) {
      task.progress = 100;
      changed = true;
    }

    if (changed) {
      _dropTaskBookkeeping(task.id);
    }
    return changed;
  }

  void _dropTaskBookkeeping(String taskId) {
    _lastEmittedStatus.remove(taskId);
    _lastEmittedTotalSize.remove(taskId);
  }

  Future<void> _saveTasksNow(String reason) async {
    final revision = _tasksRevision;
    await _storage.saveTasks(_tasks);
    if (_savedTasksRevision < revision) {
      _savedTasksRevision = revision;
    }
  }

  Future<void> _flushPeriodicState() async {
    NsfxHttpClient.compactSharedCaches();
    if (_tasksRevision != _savedTasksRevision) {
      try {
        await _saveTasksNow('periodic');
      } catch (error) {
        _logger.warning('NSFX', 'Periodic task save failed: $error');
      }
    }
    try {
      await _saveHostStrategiesIfChanged();
    } catch (error) {
      _logger.warning('NSFX', 'Periodic host strategy save failed: $error');
    }
  }

  Future<void> _saveHostStrategiesIfChanged({bool force = false}) async {
    final strategies = NsfxHttpClient.exportAdaptiveHostStrategies();
    final encoded = jsonEncode(strategies);
    if (!force && encoded == _lastSavedHostStrategiesJson) {
      return;
    }
    await _storage.saveHostStrategies(strategies);
    _lastSavedHostStrategiesJson = encoded;
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
      segmentCount: task.segmentCountHint ?? task.segments.length,
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
      this,
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
