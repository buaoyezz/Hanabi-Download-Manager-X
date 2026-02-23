import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../kernel_interface.dart';
import '../../logger_service.dart';

class SodaKernel implements KernelInterface {
  final _logger = LoggerService();
  Process? _kernelProcess;
  bool _isRunning = false;
  final String _baseUrl = 'http://127.0.0.1:9710';

  final _progressController = StreamController<DownloadTask>.broadcast();
  final _completeController = StreamController<DownloadTask>.broadcast();
  final _statsController = StreamController<DownloadStatistics>.broadcast();

  Timer? _pollTimer;

  @override
  String get name => 'Soda Speed Force (Legacy)';

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
      await _killOrphanedProcesses();

      if (await _checkHealth()) {
        _isRunning = true;
        _startPolling();
        return true;
      }

      bool success;
      if (kDebugMode) {
        success = await _startPythonKernel();
      } else {
        success = await _startExeKernel();
      }

      if (success) {
        _startPolling();
      }
      return success;
    } catch (e) {
      _logger.error('Failed to start Soda kernel: $e');
      return false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      if (!_isRunning) return;
      
      try {
        final tasks = await getTasks();
        final stats = await getStatistics();
        
        for (final task in tasks) {
          if (task.status == DownloadStatus.downloading) {
            _progressController.add(task);
          } else if (task.status == DownloadStatus.completed) {
            _completeController.add(task);
          }
        }
        
        if (stats != null) {
          _statsController.add(stats);
        }
      } catch (_) {}
    });
  }

  Future<bool> _startPythonKernel() async {
    final scriptPath = path.join(Directory.current.path, 'python', 'soda_bridge_server.py');
    
    if (!await File(scriptPath).exists()) {
      _logger.error('Python script not found: $scriptPath');
      return false;
    }

    _kernelProcess = await Process.start(
      'python',
      [scriptPath],
      workingDirectory: path.join(Directory.current.path, 'python'),
    );

    _setupProcessListeners();
    return await _waitForHealth();
  }

  Future<bool> _startExeKernel() async {
    final exePath = await _getKernelPath();
    
    if (!await File(exePath).exists()) {
      _logger.error('Kernel exe not found: $exePath');
      return false;
    }

    _kernelProcess = await Process.start(exePath, []);
    _setupProcessListeners();
    return await _waitForHealth();
  }

  void _setupProcessListeners() {
    final decoder = Platform.isWindows ? systemEncoding.decoder : const Utf8Decoder(allowMalformed: true);
    
    _kernelProcess!.stdout.transform(decoder).listen((data) {
      for (var line in data.split('\n')) {
        if (line.trim().isNotEmpty) _logger.info(line.trim());
      }
    });

    _kernelProcess!.stderr.transform(decoder).listen((data) {
      for (var line in data.split('\n')) {
        if (line.trim().isNotEmpty) _logger.error(line.trim());
      }
    });
  }

  Future<bool> _waitForHealth() async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await _checkHealth()) {
        _isRunning = true;
        return true;
      }
    }
    await stop();
    return false;
  }

  Future<bool> _checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> _getKernelPath() async {
    final exeDir = kDebugMode
        ? path.join(Directory.current.path, 'python', 'dist')
        : path.dirname(Platform.resolvedExecutable);
    return path.join(exeDir, 'soda_bridge_server.exe');
  }

  Future<void> _killOrphanedProcesses() async {
    if (!Platform.isWindows) return;
    
    try {
      final result = await Process.run('netstat', ['-ano']);
      if (result.exitCode == 0) {
        for (final line in result.stdout.toString().split('\n')) {
          if (line.contains(':9710') && line.contains('LISTENING')) {
            final pid = line.trim().split(RegExp(r'\s+')).last;
            await Process.run('taskkill', ['/F', '/PID', pid]);
          }
        }
      }
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _pollTimer?.cancel();
    
    if (_kernelProcess != null) {
      _kernelProcess!.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 500));
      _kernelProcess!.kill(ProcessSignal.sigkill);
      _kernelProcess = null;
    }

    await _killOrphanedProcesses();
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
  }) async {
    if (!_isRunning) return null;

    try {
      final body = <String, dynamic>{'url': url, 'filename': filename};
      if (referer != null) body['referer'] = referer;
      if (userAgent != null) body['user_agent'] = userAgent;
      if (cookies != null) body['cookies'] = cookies;
      if (headers != null) body['headers'] = headers;

      final response = await http.post(
        Uri.parse('$_baseUrl/download/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) return result['data']['id'];
      }
    } catch (e) {
      _logger.error('Failed to add download: $e');
    }
    return null;
  }

  @override
  Future<bool> pauseDownload(String taskId) async {
    return await _postAction('/download/pause', {'id': taskId});
  }

  @override
  Future<bool> resumeDownload(String taskId) async {
    return await _postAction('/download/resume', {'id': taskId});
  }

  @override
  Future<bool> cancelDownload(String taskId) async {
    return await _postAction('/download/cancel', {'id': taskId});
  }

  @override
  Future<bool> retryFailedSegments(String taskId) async {
    return await _postAction('/download/retry-segments', {'id': taskId});
  }

  @override
  Future<bool> retrySegment(String taskId, int segmentIndex) async {
    return await _postAction('/download/retry-segment', {
      'id': taskId,
      'segment_index': segmentIndex,
    });
  }

  Future<bool> _postAction(String endpoint, Map<String, dynamic> body) async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] ?? false;
      }
    } catch (e) {
      _logger.error('Failed to execute $endpoint: $e');
    }
    return false;
  }

  @override
  Future<List<DownloadTask>> getTasks() async {
    if (!_isRunning) return [];

    try {
      final response = await http.get(Uri.parse('$_baseUrl/download/tasks'));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return (result['data'] as List)
              .map((e) => DownloadTask.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      _logger.error('Failed to get tasks: $e');
    }
    return [];
  }

  @override
  Future<DownloadStatistics?> getStatistics() async {
    if (!_isRunning) return null;

    try {
      final response = await http.get(Uri.parse('$_baseUrl/download/statistics'));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return DownloadStatistics.fromJson(result['data']);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> renameTask(String taskId, String newFileName) async {
    // Legacy kernel does not support rename yet.
    return false;
  }

  @override
  Future<bool> moveTask(String taskId, String targetDir) async {
    // Legacy kernel does not support move yet.
    return false;
  }

  @override
  Future<DownloadConfig?> getConfig() async {
    if (!_isRunning) return null;

    try {
      final response = await http.get(Uri.parse('$_baseUrl/settings/download-config'));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return DownloadConfig.fromJson(result['data']);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> setConfig(DownloadConfig config) async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/settings/download-config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(config.toJson()),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] ?? false;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<String?> getDownloadDir() async {
    if (!_isRunning) return null;

    try {
      final response = await http.get(Uri.parse('$_baseUrl/settings/download-dir'));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) return result['data']['path'];
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<bool> setDownloadDir(String path) async {
    return await _postAction('/settings/download-dir', {'path': path});
  }

  @override
  Future<bool> clearAllData() async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/settings/clear-all-data'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] ?? false;
      }
    } catch (_) {}
    return false;
  }

  @override
  Future<bool> testProxyConnection({
    required String type,
    required String host,
    required int port,
    String? username,
    String? password,
  }) async {
    if (!_isRunning) return false;

    try {
      final body = <String, dynamic>{
        'type': type,
        'host': host,
        'port': port,
      };
      if (username != null) body['username'] = username;
      if (password != null) body['password'] = password;

      final response = await http.post(
        Uri.parse('$_baseUrl/proxy/test'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] ?? false;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _progressController.close();
    _completeController.close();
    _statsController.close();
    stop();
  }
}
