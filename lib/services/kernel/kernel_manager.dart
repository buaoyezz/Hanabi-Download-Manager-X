import 'dart:async';
import 'package:flutter/foundation.dart';
import 'kernel_interface.dart';
import 'next/nsfx_kernel.dart';

class KernelManager extends ChangeNotifier {
  static final KernelManager _instance = KernelManager._internal();
  factory KernelManager() => _instance;
  KernelManager._internal();

  KernelInterface? _kernel;
  bool _isStarting = false;
  double _startupProgress = 0;
  String _startupStatus = '';

  KernelInterface? get kernel => _kernel;
  bool get isRunning => _kernel?.isRunning ?? false;
  bool get isStarting => _isStarting;
  double get startupProgress => _startupProgress;
  String get startupStatus => _startupStatus;
  String get kernelName => _kernel?.name ?? 'NSFX (Next Speed Force X)';

  Stream<DownloadTask>? get onProgress => _kernel?.onProgress;
  Stream<DownloadTask>? get onComplete => _kernel?.onComplete;
  Stream<DownloadStatistics>? get onStatistics => _kernel?.onStatistics;

  Future<bool> start() async {
    if (_isStarting) return false;
    if (_kernel?.isRunning == true) return true;

    _isStarting = true;
    _startupProgress = 0;
    _startupStatus = '正在初始化...';
    notifyListeners();

    try {
      _startupProgress = 0.2;
      _startupStatus = '正在创建内核实例...';
      notifyListeners();

      _kernel ??= NsfxKernel();

      _startupProgress = 0.4;
      _startupStatus = '正在启动内核...';
      notifyListeners();

      final success = await _kernel!.start();

      if (success) {
        _startupProgress = 1.0;
        _startupStatus = '启动完成';
      } else {
        _startupProgress = 0;
        _startupStatus = '启动失败';
      }

      return success;
    } catch (e) {
      _startupProgress = 0;
      _startupStatus = '启动出错: $e';
      return false;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_kernel != null) {
      await _kernel!.stop();
      _kernel!.dispose();
      _kernel = null;
    }
    notifyListeners();
  }

  // 代理方法，方便直接调用
  Future<String?> addDownload(
    String url,
    String filename, {
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
  }) async {
    return _kernel?.addDownload(
      url,
      filename,
      referer: referer,
      userAgent: userAgent,
      cookies: cookies,
      headers: headers,
    );
  }

  Future<bool> pauseDownload(String taskId) async {
    return await _kernel?.pauseDownload(taskId) ?? false;
  }

  Future<bool> resumeDownload(String taskId) async {
    return await _kernel?.resumeDownload(taskId) ?? false;
  }

  Future<bool> cancelDownload(String taskId) async {
    return await _kernel?.cancelDownload(taskId) ?? false;
  }

  Future<List<DownloadTask>> getTasks() async {
    return await _kernel?.getTasks() ?? [];
  }

  Future<DownloadStatistics?> getStatistics() async {
    return await _kernel?.getStatistics();
  }

  Future<bool> renameTask(String taskId, String newFileName) async {
    return await _kernel?.renameTask(taskId, newFileName) ?? false;
  }

  Future<bool> moveTask(String taskId, String targetDir) async {
    return await _kernel?.moveTask(taskId, targetDir) ?? false;
  }

  Future<DownloadConfig?> getConfig() async {
    return await _kernel?.getConfig();
  }

  Future<bool> setConfig(DownloadConfig config) async {
    return await _kernel?.setConfig(config) ?? false;
  }

  Future<String?> getDownloadDir() async {
    return await _kernel?.getDownloadDir();
  }

  Future<bool> setDownloadDir(String path) async {
    return await _kernel?.setDownloadDir(path) ?? false;
  }

  Future<bool> clearAllData() async {
    return await _kernel?.clearAllData() ?? false;
  }

  Future<bool> retryFailedSegments(String taskId) async {
    return await _kernel?.retryFailedSegments(taskId) ?? false;
  }

  Future<bool> retrySegment(String taskId, int segmentIndex) async {
    return await _kernel?.retrySegment(taskId, segmentIndex) ?? false;
  }

  Future<bool> testProxyConnection({
    required String type,
    required String host,
    required int port,
    String? username,
    String? password,
  }) async {
    return await _kernel?.testProxyConnection(
          type: type,
          host: host,
          port: port,
          username: username,
          password: password,
        ) ??
        false;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
