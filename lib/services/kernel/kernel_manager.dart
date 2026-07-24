import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../utils/constants.dart';
import '../app_logger_service.dart';
import '../client_config_service.dart';
import 'kernel_interface.dart';
import 'neonsf/neonsf_kernel.dart';
import 'next/nsfx_kernel.dart';

/// Owns both built-in engines and routes every task back to its original owner.
///
/// NSFX is always the stable control plane and browser-bridge host. Auto routes
/// new HTTP tasks through NeoNSFX when its native runtime can accept them and
/// falls back to NSFX only before the native task has been accepted.
class KernelManager extends ChangeNotifier implements KernelInterface {
  static String get neoNsfxVersion => AppConstants.neoKernelVersion;
  static final KernelManager _instance = KernelManager._internal();
  factory KernelManager() => _instance;
  KernelManager._internal();

  final AppLoggerService _logger = AppLoggerService();
  final ClientConfigService _clientConfig = ClientConfigService();
  final Map<String, String> _taskOwners = <String, String>{};

  final StreamController<DownloadTask> _progressController =
      StreamController<DownloadTask>.broadcast(sync: true);
  final StreamController<DownloadTask> _completeController =
      StreamController<DownloadTask>.broadcast(sync: true);
  final StreamController<DownloadStatistics> _statisticsController =
      StreamController<DownloadStatistics>.broadcast(sync: true);

  NsfxKernel? _nsfx;
  NeoNsfKernel? _neoNsf;
  StreamSubscription<DownloadTask>? _nsfxProgressSubscription;
  StreamSubscription<DownloadTask>? _nsfxCompleteSubscription;
  StreamSubscription<DownloadTask>? _neoProgressSubscription;
  StreamSubscription<DownloadTask>? _neoCompleteSubscription;
  Future<bool>? _neoNsfStartupFuture;
  Timer? _selectionNotifyTimer;
  Timer? _neoNsfPrewarmTimer;
  String? _pendingSelectedKernelId;
  Future<void> _kernelPersistenceQueue = Future<void>.value();
  Timer? _statisticsTimer;
  bool _statisticsEmissionInProgress = false;
  bool _isStarting = false;
  bool _disposed = false;
  double _startupProgress = 0;
  String _startupStatus = '';
  String _selectedKernelId = DownloadTask.nsfxKernelId;
  String? _neoNsfStartupError;

  KernelInterface? get kernel => isRunning ? this : null;

  @override
  String get name => kernelName;

  @override
  bool get isRunning => _nsfx?.isRunning ?? false;

  bool get isStarting => _isStarting;
  bool get isNeoNsfRunning => _neoNsf?.isRunning ?? false;
  bool get isNeoNsfSelected => _selectedKernelId == DownloadTask.neoNsfKernelId;
  bool get isAutoSelected =>
      _selectedKernelId == ClientConfigService.downloadKernelAuto;
  double get startupProgress => _startupProgress;
  String get startupStatus => _startupStatus;
  String get selectedKernelId => _selectedKernelId;
  String? get neoNsfStartupError => _neoNsfStartupError;

  String get kernelName => switch (_selectedKernelId) {
        ClientConfigService.downloadKernelAuto => 'Auto',
        DownloadTask.neoNsfKernelId => AppConstants.neoKernelName,
        _ => 'NSFX',
      };

  String get kernelDisplayName => switch (_selectedKernelId) {
        ClientConfigService.downloadKernelAuto =>
          'Auto | ${AppConstants.nsfxKernelFormattedString} + ${AppConstants.neoKernelFormattedString}',
        DownloadTask.neoNsfKernelId => AppConstants.neoKernelFormattedString,
        _ => AppConstants.nsfxKernelFormattedString,
      };

  @override
  Stream<DownloadTask> get onProgress => _progressController.stream;

  @override
  Stream<DownloadTask> get onComplete => _completeController.stream;

  @override
  Stream<DownloadStatistics> get onStatistics => _statisticsController.stream;

  @override
  Future<bool> start() async {
    if (_isStarting) return false;
    if (isRunning) return true;

    _isStarting = true;
    _startupProgress = 0;
    _startupStatus = 'Initializing download engines...';
    notifyListeners();

    try {
      _selectedKernelId = ClientConfigService.normalizeDownloadKernelId(
        _clientConfig.getDownloadKernelId(),
      );
      _startupProgress = 0.2;
      _startupStatus = 'Starting NSFX...';
      notifyListeners();

      final nsfx = NsfxKernel(commandRouter: this);
      _nsfx = nsfx;
      _bindNsfxStreams(nsfx);
      final nsfxStarted = await nsfx.start();
      if (!nsfxStarted) {
        _startupProgress = 0;
        _startupStatus = 'NSFX failed to start';
        return false;
      }

      _startupProgress = 0.75;
      _startupStatus = 'Restoring engine-owned tasks...';
      notifyListeners();

      final hasNeoHistory = await NeoNsfKernel.hasPersistedTasks();
      if (isAutoSelected || isNeoNsfSelected || hasNeoHistory) {
        final neoStarted = await _ensureNeoNsfStarted();
        if (!neoStarted && isNeoNsfSelected) {
          _logger.warning(
            'KernelRouter',
            'NeoNSFX is selected but unavailable.',
          );
        }
      }

      await _refreshTaskOwners();
      _statisticsTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_emitCombinedStatistics()),
      );
      _startupProgress = 1;
      _startupStatus = 'Download engines ready';
      return true;
    } catch (error) {
      _startupProgress = 0;
      _startupStatus = 'Download engine startup error: $error';
      _logger.error('KernelRouter', _startupStatus);
      return false;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  Future<bool> selectKernel(String kernelId) async {
    final normalized = ClientConfigService.normalizeDownloadKernelId(kernelId);
    if (_selectedKernelId == normalized) return true;
    _selectedKernelId = normalized;
    _pendingSelectedKernelId = normalized;

    _selectionNotifyTimer?.cancel();
    _selectionNotifyTimer = Timer(const Duration(milliseconds: 220), () {
      final pending = _pendingSelectedKernelId;
      _pendingSelectedKernelId = null;
      if (pending != null) _queueSelectedKernelPersistence(pending);
      if (!_disposed) notifyListeners();
    });
    _neoNsfPrewarmTimer?.cancel();
    if (isRunning &&
        (normalized == DownloadTask.neoNsfKernelId ||
            normalized == ClientConfigService.downloadKernelAuto)) {
      _neoNsfPrewarmTimer = Timer(
        const Duration(milliseconds: 260),
        () => unawaited(_prewarmNeoNsf()),
      );
    }
    return true;
  }

  Future<void> _persistSelectedKernel(String kernelId) async {
    try {
      await _clientConfig.setDownloadKernelId(kernelId);
    } catch (error) {
      _logger.warning(
        'KernelRouter',
        'Failed to persist selected kernel $kernelId: $error',
      );
    }
  }

  void _queueSelectedKernelPersistence(String kernelId) {
    _kernelPersistenceQueue = _kernelPersistenceQueue.then(
      (_) => _persistSelectedKernel(kernelId),
    );
  }

  Future<void> _prewarmNeoNsf() async {
    await _ensureNeoNsfStarted();
  }

  Future<bool> _ensureNeoNsfStarted() {
    if (_neoNsf?.isRunning == true) return Future<bool>.value(true);
    final inFlight = _neoNsfStartupFuture;
    if (inFlight != null) return inFlight;

    final startup = _startNeoNsf();
    _neoNsfStartupFuture = startup;
    return startup.whenComplete(() {
      if (identical(_neoNsfStartupFuture, startup)) {
        _neoNsfStartupFuture = null;
      }
    });
  }

  Future<bool> _startNeoNsf() async {
    final neoNsf = _neoNsf ?? NeoNsfKernel();
    _neoNsf = neoNsf;
    _bindNeoNsfStreams(neoNsf);
    try {
      final started = await neoNsf.start();
      if (!started) {
        _neoNsfStartupError = 'Native NeoNSFX sidecar failed its handshake.';
        return false;
      }

      final nsfxConfig = await _nsfx?.getConfig();
      if (nsfxConfig != null) {
        await neoNsf.setConfig(nsfxConfig);
      }
      final downloadDir = await _nsfx?.getDownloadDir();
      if (downloadDir != null && downloadDir.isNotEmpty) {
        await neoNsf.setDownloadDir(downloadDir);
      }
      _neoNsfStartupError = null;
      return true;
    } catch (error) {
      _neoNsfStartupError = error.toString();
      _logger.warning('KernelRouter', 'NeoNSFX startup failed: $error');
      return false;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  void _bindNsfxStreams(NsfxKernel kernel) {
    unawaited(_nsfxProgressSubscription?.cancel());
    unawaited(_nsfxCompleteSubscription?.cancel());
    _nsfxProgressSubscription = kernel.onProgress.listen(_forwardProgress);
    _nsfxCompleteSubscription = kernel.onComplete.listen(_forwardComplete);
  }

  void _bindNeoNsfStreams(NeoNsfKernel kernel) {
    unawaited(_neoProgressSubscription?.cancel());
    unawaited(_neoCompleteSubscription?.cancel());
    _neoProgressSubscription = kernel.onProgress.listen(_forwardProgress);
    _neoCompleteSubscription = kernel.onComplete.listen(_forwardComplete);
  }

  void _forwardProgress(DownloadTask task) {
    _taskOwners[task.id] = task.kernelId;
    if (!_progressController.isClosed) {
      _progressController.add(task);
    }
  }

  void _forwardComplete(DownloadTask task) {
    _taskOwners[task.id] = task.kernelId;
    if (!_completeController.isClosed) {
      _completeController.add(task);
    }
  }

  @override
  Future<void> stop() async {
    _statisticsTimer?.cancel();
    _statisticsTimer = null;
    _selectionNotifyTimer?.cancel();
    _selectionNotifyTimer = null;
    _neoNsfPrewarmTimer?.cancel();
    _neoNsfPrewarmTimer = null;
    final pendingSelectedKernelId = _pendingSelectedKernelId;
    _pendingSelectedKernelId = null;
    if (pendingSelectedKernelId != null) {
      _queueSelectedKernelPersistence(pendingSelectedKernelId);
    }
    await _kernelPersistenceQueue;
    await _neoNsfStartupFuture;
    await _neoProgressSubscription?.cancel();
    await _neoCompleteSubscription?.cancel();
    await _nsfxProgressSubscription?.cancel();
    await _nsfxCompleteSubscription?.cancel();
    _neoProgressSubscription = null;
    _neoCompleteSubscription = null;
    _nsfxProgressSubscription = null;
    _nsfxCompleteSubscription = null;

    final neoNsf = _neoNsf;
    _neoNsf = null;
    if (neoNsf != null) {
      await neoNsf.stop();
      neoNsf.dispose();
    }

    final nsfx = _nsfx;
    _nsfx = null;
    if (nsfx != null) {
      await nsfx.stop();
      nsfx.dispose();
    }
    _taskOwners.clear();
    if (!_disposed) notifyListeners();
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
    if (!isRunning) return null;

    if (isAutoSelected || isNeoNsfSelected) {
      final neoNsf = _neoNsf;
      final neoAvailable =
          neoNsf?.isRunning == true || await _ensureNeoNsfStarted();
      if (neoAvailable &&
          _neoNsf!.canAccept(url: url, expectedSizeHint: expectedSizeHint)) {
        final taskId = await _neoNsf!.addDownload(
          url,
          filename,
          referer: referer,
          userAgent: userAgent,
          cookies: cookies,
          headers: headers,
          saveDir: saveDir,
          startPaused: startPaused,
          expectedSizeHint: expectedSizeHint,
        );
        if (taskId != null) {
          _taskOwners[taskId] = DownloadTask.neoNsfKernelId;
          return taskId;
        }
      }
      if (isNeoNsfSelected) {
        if (!neoAvailable) {
          throw StateError(
              'NeoNSFX was explicitly selected but is not available. Startup Error: $_neoNsfStartupError');
        }
        throw StateError(
            'NeoNSFX was explicitly selected but did not accept the task for an unknown reason.');
      }
      _logger.info(
        'KernelRouter',
        'Auto could not use NeoNSFX before acceptance; using NSFX.',
      );
    }

    final taskId = await _nsfx?.addDownload(
      url,
      filename,
      referer: referer,
      userAgent: userAgent,
      cookies: cookies,
      headers: headers,
      saveDir: saveDir,
      startPaused: startPaused,
      expectedSizeHint: expectedSizeHint,
    );
    if (taskId != null) {
      _taskOwners[taskId] = DownloadTask.nsfxKernelId;
      return taskId;
    }

    throw StateError(
        'NSFX kernel is not running or failed to create the download task.');
  }

  Future<KernelInterface?> _ownerFor(String taskId) async {
    var ownerId = _taskOwners[taskId];
    if (ownerId == null) {
      await _refreshTaskOwners();
      ownerId = _taskOwners[taskId];
    }
    if (ownerId == DownloadTask.neoNsfKernelId || taskId.startsWith('neo_')) {
      if (_neoNsf?.isRunning != true && !await _ensureNeoNsfStarted()) {
        return null;
      }
      return _neoNsf;
    }
    return _nsfx;
  }

  Future<void> _refreshTaskOwners() async {
    final nsfx = _nsfx;
    if (nsfx?.isRunning == true) {
      for (final task in await nsfx!.getTasks()) {
        _taskOwners[task.id] = DownloadTask.nsfxKernelId;
      }
    }
    final neoNsf = _neoNsf;
    if (neoNsf?.isRunning == true) {
      for (final task in await neoNsf!.getTasks()) {
        _taskOwners[task.id] = DownloadTask.neoNsfKernelId;
      }
    }
  }

  @override
  Future<bool> pauseDownload(String taskId) async =>
      await (await _ownerFor(taskId))?.pauseDownload(taskId) ?? false;

  @override
  Future<bool> resumeDownload(String taskId) async =>
      await (await _ownerFor(taskId))?.resumeDownload(taskId) ?? false;

  @override
  Future<bool> cancelDownload(String taskId) async =>
      await (await _ownerFor(taskId))?.cancelDownload(taskId) ?? false;

  @override
  Future<List<DownloadTask>> getTasks() async {
    final tasks = <DownloadTask>[];
    if (_nsfx?.isRunning == true) {
      tasks.addAll(await _nsfx!.getTasks());
    }
    if (_neoNsf?.isRunning == true) {
      tasks.addAll(await _neoNsf!.getTasks());
    }
    for (final task in tasks) {
      _taskOwners[task.id] = task.kernelId;
    }
    tasks.sort((a, b) => b.createdTime.compareTo(a.createdTime));
    return tasks;
  }

  @override
  Future<DownloadStatistics?> getStatistics() async {
    final nsfx = await _nsfx?.getStatistics();
    final neoNsf = await _neoNsf?.getStatistics();
    if (nsfx == null && neoNsf == null) return null;
    return DownloadStatistics(
      totalTasks: (nsfx?.totalTasks ?? 0) + (neoNsf?.totalTasks ?? 0),
      activeDownloads:
          (nsfx?.activeDownloads ?? 0) + (neoNsf?.activeDownloads ?? 0),
      totalSpeed: (nsfx?.totalSpeed ?? 0) + (neoNsf?.totalSpeed ?? 0),
      totalDownloaded:
          (nsfx?.totalDownloaded ?? 0) + (neoNsf?.totalDownloaded ?? 0),
    );
  }

  Future<void> _emitCombinedStatistics() async {
    if (_statisticsEmissionInProgress || _statisticsController.isClosed) return;
    _statisticsEmissionInProgress = true;
    try {
      final statistics = await getStatistics();
      if (statistics != null && !_statisticsController.isClosed) {
        _statisticsController.add(statistics);
      }
    } finally {
      _statisticsEmissionInProgress = false;
    }
  }

  @override
  Future<bool> renameTask(String taskId, String newFileName) async =>
      await (await _ownerFor(taskId))?.renameTask(taskId, newFileName) ?? false;

  @override
  Future<bool> moveTask(String taskId, String targetDir) async =>
      await (await _ownerFor(taskId))?.moveTask(taskId, targetDir) ?? false;

  @override
  Future<DownloadConfig?> getConfig() async => _nsfx?.getConfig();

  @override
  Future<bool> setConfig(DownloadConfig config) async {
    final nsfxUpdated = await _nsfx?.setConfig(config) ?? false;
    if (_neoNsf?.isRunning == true) {
      await _neoNsf!.setConfig(config);
    }
    return nsfxUpdated;
  }

  @override
  Future<String?> getDownloadDir() async => _nsfx?.getDownloadDir();

  @override
  Future<bool> setDownloadDir(String path) async {
    final nsfxUpdated = await _nsfx?.setDownloadDir(path) ?? false;
    if (_neoNsf?.isRunning == true) {
      await _neoNsf!.setDownloadDir(path);
    }
    return nsfxUpdated;
  }

  @override
  Future<bool> clearAllData() async {
    final nsfxCleared = await _nsfx?.clearAllData() ?? false;
    final neoCleared =
        _neoNsf?.isRunning == true ? await _neoNsf!.clearAllData() : true;
    _taskOwners.clear();
    return nsfxCleared && neoCleared;
  }

  @override
  Future<bool> retryFailedSegments(String taskId) async =>
      await (await _ownerFor(taskId))?.retryFailedSegments(taskId) ?? false;

  @override
  Future<bool> retrySegment(String taskId, int segmentIndex) async =>
      await (await _ownerFor(taskId))?.retrySegment(taskId, segmentIndex) ??
      false;

  @override
  Future<Map<String, dynamic>> getAdaptiveHostStrategies() async =>
      await _nsfx?.getAdaptiveHostStrategies() ?? <String, dynamic>{};

  @override
  Future<bool> clearAdaptiveHostStrategies() async =>
      await _nsfx?.clearAdaptiveHostStrategies() ?? false;

  @override
  Future<bool> testProxyConnection({
    required String type,
    required String host,
    required int port,
    String? username,
    String? password,
  }) async =>
      await _nsfx?.testProxyConnection(
        type: type,
        host: host,
        port: port,
        username: username,
        password: password,
      ) ??
      false;

  @override
  Future<bool> updateBrowserBridgePort(
    int port, {
    Iterable<int> compatibilityPorts = const <int>[],
  }) async =>
      await _nsfx?.updateBrowserBridgePort(
        port,
        compatibilityPorts: compatibilityPorts,
      ) ??
      true;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop());
    unawaited(_progressController.close());
    unawaited(_completeController.close());
    unawaited(_statisticsController.close());
    super.dispose();
  }
}
