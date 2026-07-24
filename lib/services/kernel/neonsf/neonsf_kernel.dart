import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;

import '../../../utils/constants.dart';
import '../../app_logger_service.dart';
import '../kernel_interface.dart';
import 'neonsf_process_bridge.dart';
import 'neonsf_task_storage.dart';

class NeoNsfKernel implements KernelInterface {
  NeoNsfKernel({
    NeoNsfProcessBridge? bridge,
    NeoNsfTaskStorage? storage,
  })  : _bridge = bridge ?? NeoNsfProcessBridge(),
        _storage = storage ?? NeoNsfTaskStorage();

  final NeoNsfProcessBridge _bridge;
  final NeoNsfTaskStorage _storage;
  final AppLoggerService _logger = AppLoggerService();
  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};
  final Map<String, Map<String, String>> _requestHeaders =
      <String, Map<String, String>>{};
  final Map<String, Map<String, String>> _resumeValidators =
      <String, Map<String, String>>{};
  final Set<String> _detachingTasks = <String>{};
  final StreamController<DownloadTask> _progressController =
      StreamController<DownloadTask>.broadcast(sync: true);
  final StreamController<DownloadTask> _completeController =
      StreamController<DownloadTask>.broadcast(sync: true);
  final StreamController<DownloadStatistics> _statisticsController =
      StreamController<DownloadStatistics>.broadcast(sync: true);

  StreamSubscription<Map<String, dynamic>>? _eventSubscription;
  Timer? _statisticsTimer;
  Timer? _saveTimer;
  bool _isRunning = false;
  DownloadConfig _config = DownloadConfig();
  late String _downloadDir;

  static Future<bool> hasPersistedTasks() async =>
      (await NeoNsfTaskStorage().loadTasks()).isNotEmpty;

  @override
  String get name =>
      '${AppConstants.neoKernelName} ${AppConstants.neoKernelVersion} (Experimental)';

  @override
  bool get isRunning => _isRunning;

  @override
  Stream<DownloadTask> get onProgress => _progressController.stream;

  @override
  Stream<DownloadTask> get onComplete => _completeController.stream;

  @override
  Stream<DownloadStatistics> get onStatistics => _statisticsController.stream;

  bool canAccept({required String url, int? expectedSizeHint}) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  @override
  Future<bool> start() async {
    if (_isRunning) return true;
    try {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.current.path;
      _downloadDir = path.join(home, 'Downloads');
      _tasks
        ..clear()
        ..addAll(await _storage.loadTasks());
      _requestHeaders
        ..clear()
        ..addEntries(
          _tasks.keys.map(
            (taskId) => MapEntry(taskId, _storage.requestHeadersFor(taskId)),
          ),
        );
      _resumeValidators
        ..clear()
        ..addEntries(
          _tasks.keys.map(
            (taskId) => MapEntry(
              taskId,
              _storage.resumeValidatorsFor(taskId),
            ),
          ),
        );
      _eventSubscription = _bridge.events.listen(_handleEvent);
      final ready = await _bridge.start();
      if (ready['protocolVersion'] != 1) {
        throw StateError('Unsupported NeoNSF protocol version.');
      }
      _statisticsTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _emitStatistics(),
      );
      _saveTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _saveInBackground(),
      );
      _isRunning = true;
      _logger.info('NeoNSF', 'NeoNSF experimental kernel started');
      return true;
    } catch (error) {
      _logger.warning('NeoNSF', 'NeoNSF startup failed: $error');
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      await _bridge.stop(force: true);
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (!_isRunning && !_bridge.isRunning) return;
    _statisticsTimer?.cancel();
    _statisticsTimer = null;
    _saveTimer?.cancel();
    _saveTimer = null;
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.pending) {
        try {
          await _bridge.pause(task.id);
        } catch (_) {}
        task.status = DownloadStatus.paused;
        task.speed = 0;
        task.eta = 0;
      }
    }
    await _saveTasks();
    await _bridge.stop();
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _isRunning = false;
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
    if (!_isRunning) {
      throw StateError('NeoNSFX is not running. Did it crash?');
    }
    if (!canAccept(url: url, expectedSizeHint: expectedSizeHint)) {
      throw StateError('NeoNSFX cannot accept this URL.');
    }
    final targetDir =
        (saveDir?.trim().isNotEmpty ?? false) ? saveDir!.trim() : _downloadDir;
    await Directory(targetDir).create(recursive: true);
    final resolvedName = await _resolveConflict(filename, targetDir);
    final taskId = _generateId();
    final task = DownloadTask(
      id: taskId,
      url: url,
      filename: resolvedName,
      filepath: path.join(targetDir, resolvedName),
      status: startPaused ? DownloadStatus.paused : DownloadStatus.pending,
      totalSize: expectedSizeHint ?? 0,
      threadCount: 1,
      kernelId: DownloadTask.neoNsfKernelId,
      effectiveHttpVersionPolicy: _config.httpVersionPolicy,
      resumeDecisionLabel: 'NeoNSFX Native Planner',
      resumeDecisionReason:
          'Native planner will choose direct or parallel range transfer.',
    );
    _tasks[taskId] = task;
    _requestHeaders[taskId] = _buildRequestHeaders(
      referer: referer,
      userAgent: userAgent,
      cookies: cookies,
      headers: headers,
    );
    await _saveTasks();

    if (!startPaused) {
      try {
        await _enqueueTask(task);
      } catch (e) {
        _tasks.remove(taskId);
        _requestHeaders.remove(taskId);
        _resumeValidators.remove(taskId);
        await _saveTasks();
        rethrow;
      }
    }
    _progressController.add(task);
    return taskId;
  }

  Map<String, String> _buildRequestHeaders({
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
  }) =>
      <String, String>{
        for (final entry in (headers ?? const <String, dynamic>{}).entries)
          entry.key: entry.value.toString(),
        if (referer?.trim().isNotEmpty ?? false) 'Referer': referer!.trim(),
        if (cookies?.trim().isNotEmpty ?? false) 'Cookie': cookies!.trim(),
        'User-Agent': (userAgent?.trim().isNotEmpty ?? false)
            ? userAgent!.trim()
            : _config.defaultUserAgent,
      };

  Future<bool> _enqueueTask(DownloadTask task) {
    final requestHeaders = _requestHeaders[task.id]?.isNotEmpty == true
        ? _requestHeaders[task.id]!
        : _buildRequestHeaders();
    final proxy = _config.proxy;
    return _bridge.enqueue(<String, dynamic>{
      'taskId': task.id,
      'url': task.url,
      'filePath': task.filepath,
      'expectedSize': task.totalSize > 0 ? task.totalSize : null,
      'headers': requestHeaders,
      'maxRetries': 3,
      'connectionTimeoutSeconds': _config.connectionTimeout,
      'readTimeoutSeconds': _config.readTimeout,
      'maxConnections': min(
        _config.threads.clamp(1, 16),
        _config.globalMaxConnections.clamp(1, 16),
      ),
      'httpVersionPolicy': _config.httpVersionPolicy,
      'allowInsecureTls': _config.allowInsecureTls,
      'expectedETag': _resumeValidators[task.id]?['etag'],
      'expectedLastModified': _resumeValidators[task.id]?['lastModified'],
      'proxy': <String, dynamic>{
        'enabled': proxy?.enabled == true,
        'type': proxy?.type ?? 'direct',
        if (proxy?.enabled == true && proxy!.type != 'system') ...{
          'host': proxy.host,
          'port': proxy.port,
          'username': proxy.username,
          'password': proxy.password,
        },
      },
    });
  }

  @override
  Future<bool> pauseDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return false;
    if (task.status == DownloadStatus.paused) return true;
    final paused = await _requestAndWaitForEvent(
      taskId: taskId,
      eventType: 'paused',
      request: () => _bridge.pause(taskId),
    );
    if (paused) {
      task.status = DownloadStatus.paused;
      task.speed = 0;
      task.eta = 0;
      await _saveTasks();
      _progressController.add(task);
    }
    return paused;
  }

  @override
  Future<bool> resumeDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || task.status == DownloadStatus.completed) return false;
    var resumed = await _bridge.resume(taskId);
    if (!resumed) {
      resumed = await _enqueueTask(task);
    }
    if (resumed) {
      task.status = DownloadStatus.pending;
      task.errorMessage = null;
      _progressController.add(task);
    }
    return resumed;
  }

  @override
  Future<bool> cancelDownload(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return false;
    if (task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.pending) {
      await _requestAndWaitForEvent(
        taskId: taskId,
        eventType: 'cancelled',
        request: () => _bridge.cancel(taskId),
      );
    }
    for (final candidate in <File>[
      File(task.filepath),
      File('${task.filepath}.neonsf.partial'),
      File('${task.filepath}.neonsf.state'),
      File('${task.filepath}.neonsf.state.tmp'),
    ]) {
      if (await candidate.exists()) {
        await candidate.delete();
      }
    }
    _tasks.remove(taskId);
    _requestHeaders.remove(taskId);
    _resumeValidators.remove(taskId);
    await _saveTasks();
    return true;
  }

  Future<bool> _requestAndWaitForEvent({
    required String taskId,
    required String eventType,
    required Future<bool> Function() request,
  }) async {
    final completer = Completer<void>();
    late final StreamSubscription<Map<String, dynamic>> subscription;
    subscription = _bridge.events.listen((event) {
      if (!completer.isCompleted &&
          event['type'] == eventType &&
          event['taskId'] == taskId) {
        completer.complete();
      }
    });
    try {
      final accepted = await request();
      if (!accepted) return false;
      try {
        await completer.future.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        _logger.warning(
          'NeoNSF',
          '$eventType acknowledgement timed out: $taskId',
        );
      }
      return true;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<List<DownloadTask>> getTasks() async => _tasks.values.toList()
    ..sort((a, b) => b.createdTime.compareTo(a.createdTime));

  @override
  Future<DownloadStatistics?> getStatistics() async => _statistics();

  @override
  Future<bool> renameTask(String taskId, String newFileName) async {
    final task = _tasks[taskId];
    if (task == null ||
        task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.pending) {
      return false;
    }
    await _detachPausedNativeTask(task);
    final nextPath = path.join(path.dirname(task.filepath), newFileName);
    if (await File(task.filepath).exists()) {
      await File(task.filepath).rename(nextPath);
    }
    final partial = File('${task.filepath}.neonsf.partial');
    if (await partial.exists()) {
      await partial.rename('$nextPath.neonsf.partial');
    }
    final checkpoint = File('${task.filepath}.neonsf.state');
    if (await checkpoint.exists()) {
      await checkpoint.rename('$nextPath.neonsf.state');
    }
    final checkpointTemp = File('${task.filepath}.neonsf.state.tmp');
    if (await checkpointTemp.exists()) {
      await checkpointTemp.rename('$nextPath.neonsf.state.tmp');
    }
    _tasks[taskId] = _copyTask(task, filename: newFileName, filepath: nextPath);
    await _saveTasks();
    _progressController.add(_tasks[taskId]!);
    return true;
  }

  @override
  Future<bool> moveTask(String taskId, String targetDir) async {
    final task = _tasks[taskId];
    if (task == null ||
        task.status == DownloadStatus.downloading ||
        task.status == DownloadStatus.pending) {
      return false;
    }
    await _detachPausedNativeTask(task);
    await Directory(targetDir).create(recursive: true);
    final nextPath = path.join(targetDir, task.filename);
    if (await File(task.filepath).exists()) {
      await File(task.filepath).rename(nextPath);
    }
    final partial = File('${task.filepath}.neonsf.partial');
    if (await partial.exists()) {
      await partial.rename('$nextPath.neonsf.partial');
    }
    final checkpoint = File('${task.filepath}.neonsf.state');
    if (await checkpoint.exists()) {
      await checkpoint.rename('$nextPath.neonsf.state');
    }
    final checkpointTemp = File('${task.filepath}.neonsf.state.tmp');
    if (await checkpointTemp.exists()) {
      await checkpointTemp.rename('$nextPath.neonsf.state.tmp');
    }
    _tasks[taskId] = _copyTask(task, filepath: nextPath);
    await _saveTasks();
    _progressController.add(_tasks[taskId]!);
    return true;
  }

  Future<void> _detachPausedNativeTask(DownloadTask task) async {
    if (task.status != DownloadStatus.paused) return;
    _detachingTasks.add(task.id);
    final detached = await _requestAndWaitForEvent(
      taskId: task.id,
      eventType: 'cancelled',
      request: () => _bridge.cancel(task.id, deletePartial: false),
    );
    if (!detached) {
      _detachingTasks.remove(task.id);
    }
    task.status = DownloadStatus.paused;
  }

  @override
  Future<DownloadConfig?> getConfig() async => _config;

  @override
  Future<bool> setConfig(DownloadConfig config) async {
    _config = config;
    return true;
  }

  @override
  Future<String?> getDownloadDir() async => _downloadDir;

  @override
  Future<bool> setDownloadDir(String pathValue) async {
    await Directory(pathValue).create(recursive: true);
    _downloadDir = pathValue;
    return true;
  }

  @override
  Future<bool> clearAllData() async {
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.downloading) {
        await _bridge.cancel(task.id);
      }
    }
    _tasks.clear();
    _requestHeaders.clear();
    _resumeValidators.clear();
    await _storage.clear();
    return true;
  }

  @override
  Future<bool> retryFailedSegments(String taskId) => resumeDownload(taskId);

  @override
  Future<bool> retrySegment(String taskId, int segmentIndex) async => false;

  @override
  Future<Map<String, dynamic>> getAdaptiveHostStrategies() async =>
      <String, dynamic>{};

  @override
  Future<bool> clearAdaptiveHostStrategies() async => true;

  @override
  Future<bool> testProxyConnection({
    required String type,
    required String host,
    required int port,
    String? username,
    String? password,
  }) async =>
      false;

  @override
  Future<bool> updateBrowserBridgePort(
    int port, {
    Iterable<int> compatibilityPorts = const <int>[],
  }) async =>
      true;

  void _handleEvent(Map<String, dynamic> event) {
    final taskId = event['taskId']?.toString();
    final task = taskId == null ? null : _tasks[taskId];
    if (task == null) {
      if (event['type'] == 'processExited') {
        _handleProcessExit(event);
      }
      return;
    }
    if (event['type'] == 'cancelled' && _detachingTasks.remove(taskId)) {
      return;
    }

    switch (event['type']) {
      case 'started':
        task.status = DownloadStatus.downloading;
        task.startTime ??= DateTime.now();
      case 'headers':
        task.totalSize =
            (event['totalBytes'] as num?)?.toInt() ?? task.totalSize;
        task.negotiatedHttpVersion =
            _normalizeHttpVersion(event['httpVersion']);
        task.targetReachable = true;
        task.threadCount =
            (event['connectionCount'] as num?)?.toInt() ?? task.threadCount;
        final transferMode = event['transferMode']?.toString();
        if (transferMode == 'parallel_range') {
          task.resumeDecisionLabel = 'NeoNSFX Parallel Range';
          task.resumeDecisionReason =
              'Native planner selected ${task.threadCount} concurrent ranges.';
        } else if (transferMode == 'direct') {
          task.resumeDecisionLabel = 'NeoNSFX Direct';
          task.resumeDecisionReason =
              'Native planner selected a single streaming connection.';
        }
        final etag = event['etag']?.toString();
        final lastModified = event['lastModified']?.toString();
        final validators = <String, String>{
          if (etag != null && etag.isNotEmpty) 'etag': etag,
          if (lastModified != null && lastModified.isNotEmpty)
            'lastModified': lastModified,
        };
        if (validators.isEmpty) {
          _resumeValidators.remove(task.id);
        } else {
          _resumeValidators[task.id] = validators;
        }
        _saveInBackground();
      case 'progress':
        task.status = DownloadStatus.downloading;
        task.downloadedSize =
            (event['downloadedBytes'] as num?)?.toInt() ?? task.downloadedSize;
        task.totalSize =
            (event['totalBytes'] as num?)?.toInt() ?? task.totalSize;
        task.speed = (event['instantBps'] as num?)?.toDouble() ?? 0;
        task.averageSpeed =
            (event['averageBps'] as num?)?.toDouble() ?? task.averageSpeed;
        task.peakSpeed = max(task.peakSpeed, task.speed);
        task.progress =
            task.totalSize > 0 ? task.downloadedSize * 100 / task.totalSize : 0;
        task.eta = task.speed > 0 && task.totalSize > task.downloadedSize
            ? ((task.totalSize - task.downloadedSize) / task.speed).ceil()
            : 0;
      case 'paused':
        task.status = DownloadStatus.paused;
        task.speed = 0;
        task.eta = 0;
        _saveInBackground();
      case 'cancelled':
        task.status = DownloadStatus.cancelled;
        task.speed = 0;
        task.eta = 0;
        _saveInBackground();
      case 'completed':
        task.status = DownloadStatus.completed;
        task.downloadedSize =
            (event['downloadedBytes'] as num?)?.toInt() ?? task.downloadedSize;
        task.totalSize =
            (event['totalBytes'] as num?)?.toInt() ?? task.totalSize;
        task.averageSpeed =
            (event['averageBps'] as num?)?.toDouble() ?? task.averageSpeed;
        task.progress = 100;
        task.speed = 0;
        task.eta = 0;
        task.endTime = DateTime.now();
        _saveInBackground();
        _completeController.add(task);
      case 'failed':
        task.status = DownloadStatus.failed;
        task.errorMessage = event['error']?.toString();
        task.speed = 0;
        task.eta = 0;
        _saveInBackground();
    }
    _progressController.add(task);
  }

  void _handleProcessExit(Map<String, dynamic> event) {
    for (final task in _tasks.values) {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.pending) {
        task.status = DownloadStatus.paused;
        task.speed = 0;
        task.eta = 0;
        task.errorMessage =
            'NeoNSF process exited (${event['exitCode'] ?? 'unknown'}).';
        _progressController.add(task);
      }
    }
    _saveInBackground();
  }

  DownloadStatistics _statistics() => DownloadStatistics(
        totalTasks: _tasks.length,
        activeDownloads: _tasks.values
            .where((task) => task.status == DownloadStatus.downloading)
            .length,
        totalSpeed:
            _tasks.values.fold<double>(0, (sum, task) => sum + task.speed),
        totalDownloaded: _tasks.values
            .fold<int>(0, (sum, task) => sum + task.downloadedSize),
      );

  void _emitStatistics() {
    if (!_statisticsController.isClosed) {
      _statisticsController.add(_statistics());
    }
  }

  void _saveInBackground() {
    unawaited(_saveTasks().catchError((error) {
      _logger.warning('NeoNSF', 'Failed to persist NeoNSF tasks: $error');
    }));
  }

  Future<void> _saveTasks() => _storage.saveTasks(
        _tasks,
        requestHeaders: _requestHeaders,
        resumeValidators: _resumeValidators,
      );

  Future<String> _resolveConflict(String filename, String directory) async {
    final extension = path.extension(filename);
    final stem = path.basenameWithoutExtension(filename);
    var candidate = filename;
    var index = 1;
    while (await File(path.join(directory, candidate)).exists() ||
        await File('${path.join(directory, candidate)}.neonsf.partial')
            .exists() ||
        await File('${path.join(directory, candidate)}.neonsf.state')
            .exists() ||
        await File('${path.join(directory, candidate)}.neonsf.state.tmp')
            .exists()) {
      candidate = '$stem ($index)$extension';
      index++;
    }
    return candidate;
  }

  String _generateId() {
    final random = Random.secure();
    final suffix = List<int>.generate(6, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'neo_${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }

  static String? _normalizeHttpVersion(Object? raw) {
    return switch (raw?.toString()) {
      '1.0' => 'http1_0',
      '1.1' => 'http1_1',
      '2.0' => 'http2',
      '3.0' => 'http3',
      _ => null,
    };
  }

  static DownloadTask _copyTask(
    DownloadTask source, {
    String? filename,
    String? filepath,
  }) {
    final json = source.toJson()
      ..['filename'] = filename ?? source.filename
      ..['filepath'] = filepath ?? source.filepath;
    return DownloadTask.fromJson(json);
  }

  @override
  void dispose() {
    unawaited(stop());
    unawaited(_progressController.close());
    unawaited(_completeController.close());
    unawaited(_statisticsController.close());
  }
}
