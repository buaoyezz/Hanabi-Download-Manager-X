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
import '../../app_logger_service.dart';

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
      _httpClient = NsfxHttpClient(_config);

      _engine = DownloadEngine(
        config: _config,
        httpClient: _httpClient,
        onProgress: _onTaskProgress,
        onComplete: _onTaskComplete,
        onError: _onTaskError,
      );

      _tasks.addAll(await _storage.loadTasks());
      if (_tasks.isNotEmpty) {
        _logger.info('NSFX', 'Loaded ${_tasks.length} tasks from storage');
      }

      // 设置默认下载目录
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.current.path;
      _downloadDir = p.join(home, 'Downloads');

      // 启动统计定时器
      _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _emitStatistics();
      });

      // 启动自动保存
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _storage.saveTasks(_tasks);
      });

      // 启动 HTTP 服务器（用于浏览器插件通信）
      _httpServer = NsfxHttpServer(this);
      final httpStarted = await _httpServer!.start();
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
    await _storage.saveTasks(_tasks);
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
  }) async {
    if (!_isRunning) return null;

    final id = _generateId();
    final resolvedFilename = await _resolveFileNameConflict(filename);
    final filepath = p.join(_downloadDir, resolvedFilename);

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
      userAgent: userAgent,
      referer: referer,
      cookies: cookies,
      headers: headers?.map((k, v) => MapEntry(k, v.toString())),
    );

    _tasks[id] = task;

    // 立即保存任务列表
    await _storage.saveTasks(_tasks);

    _checkQueue();

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

  Future<String> _resolveFileNameConflict(String filename) async {
    final cleaned = filename.trim();
    if (cleaned.isEmpty) return filename;

    final originalPath = p.join(_downloadDir, cleaned);
    final strategy = _config.conflictStrategy;

    final exists = await _conflictExists(originalPath, cleaned);
    if (!exists) return cleaned;

    if (strategy == 'overwrite') {
      await _deleteIfExists(originalPath);
      return cleaned;
    }

    final baseName = p.basenameWithoutExtension(cleaned);
    final extension = p.extension(cleaned);

    if (strategy == 'timestamp') {
      final stamp = _formatTimestamp(DateTime.now());
      var candidate = '${baseName}_${stamp}${extension}';
      var candidatePath = p.join(_downloadDir, candidate);
      if (await _conflictExists(candidatePath, candidate)) {
        candidate =
            '${baseName}_${stamp}_${DateTime.now().millisecondsSinceEpoch}${extension}';
      }
      return candidate;
    }

    // 默认：递增序号 (1)(2)...
    for (int i = 1; i < 10000; i++) {
      final candidate = '$baseName ($i)$extension';
      final candidatePath = p.join(_downloadDir, candidate);
      if (!await _conflictExists(candidatePath, candidate)) {
        return candidate;
      }
    }

    return '${baseName}_${DateTime.now().millisecondsSinceEpoch}$extension';
  }

  Future<bool> _conflictExists(String filepath, String filename) async {
    final lower = filename.toLowerCase();
    final hasTaskConflict = _tasks.values.any((task) {
      final name = p.basename(task.filepath).toLowerCase();
      return name == lower;
    });
    if (hasTaskConflict) return true;
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

    // 立即保存任务列表
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
    _engine.cancelDownload(taskId);
    _tasks.remove(taskId);

    // 立即保存任务列表
    await _storage.saveTasks(_tasks);

    // 清理文件
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
    await _storage.clearAll();
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
  void dispose() {
    stop();
    _progressController.close();
    _completeController.close();
    _statsController.close();
  }

  void _onTaskProgress(Task task) {
    final now = DateTime.now();

    // 检查是否有关键变化（状态变化或文件大小变化）
    final lastStatus = _lastEmittedStatus[task.id];
    final lastTotalSize = _lastEmittedTotalSize[task.id];
    final isStatusChanged = lastStatus != task.status;
    final isTotalSizeChanged =
        lastTotalSize != task.totalSize && task.totalSize > 0;
    final isCriticalChange = isStatusChanged || isTotalSizeChanged;

    // 关键变化必须立即发送，普通进度更新才节流
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
    _completeController.add(_toDownloadTask(task));
    _checkQueue();
  }

  void _onTaskError(Task task) {
    _logger.error(
        'NSFX', 'Download failed: ${task.filename} - ${task.errorMessage}');
    _progressController.add(_toDownloadTask(task));
    _checkQueue();
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
      createdTime: task.createdTime, // 传递创建时间
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
}
