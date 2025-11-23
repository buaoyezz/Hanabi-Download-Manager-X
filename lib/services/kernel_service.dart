import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'logger_service.dart';

class KernelService extends ChangeNotifier {
  final _logger = LoggerService();
  Process? _kernelProcess;
  bool _isRunning = false;
  final String _baseUrl = 'http://127.0.0.1:9710';
  
  bool get isRunning => _isRunning;

  Future<bool> startKernel() async {
    if (_isRunning) {
      _logger.info('Kernel already running');
      return true;
    }

    try {
      // 直接检查服务器是否已经在运行（开发模式下手动启动）
      print('🟢 Checking if kernel server is running on $_baseUrl');
      _logger.info('Checking if kernel server is running on $_baseUrl');
      
      final isHealthy = await _checkHealth();
      if (isHealthy) {
        _isRunning = true;
        _logger.info('Kernel server is running and healthy');
        notifyListeners();
        return true;
      }
      
      // 如果服务器未运行，尝试启动exe（生产模式）
      final exePath = await _getKernelPath();
      
      if (await File(exePath).exists()) {
        _logger.info('Starting kernel: $exePath');
        
        // 使用detachedWithStdio模式，不显示窗口
        _kernelProcess = await Process.start(
          exePath,
          [],
          mode: ProcessStartMode.detachedWithStdio,
          runInShell: false, // 不使用shell，避免CMD窗口
        );

        // 等待内核启动，使用重试机制
        _logger.info('Waiting for kernel to start...');
        bool isHealthyAfterStart = false;
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          isHealthyAfterStart = await _checkHealth();
          if (isHealthyAfterStart) {
            break;
          }
          _logger.info('Health check attempt ${i + 1}/10...');
        }

        if (isHealthyAfterStart) {
          _isRunning = true;
          _logger.info('Kernel started successfully');
          notifyListeners();
          return true;
        } else {
          _logger.error('Kernel health check failed after start');
          await stopKernel();
          return false;
        }
      } else {
        _logger.warning('Kernel executable not found: $exePath');
        _logger.warning('Please start the Python server manually: python python/soda_bridge_server.py');
        return false;
      }
    } catch (e) {
      _logger.error('Failed to start kernel: $e');
      return false;
    }
  }

  Future<void> stopKernel() async {
    _logger.info('Stopping kernel...');
    
    if (_kernelProcess != null) {
      try {
        // 尝试优雅关闭
        _kernelProcess!.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 如果还在运行，强制终止
        if (_kernelProcess != null) {
          _kernelProcess!.kill(ProcessSignal.sigkill);
        }
      } catch (e) {
        _logger.warning('Error stopping kernel process: $e');
      }
      _kernelProcess = null;
    } else {
      // 只有在没有进程引用时，才尝试使用 kill_server 清理可能残留的进程
      // 这样可以避免杀死手动启动的或其他实例的内核
      try {
        final killServerPath = await _getKillServerPath();
        if (await File(killServerPath).exists()) {
          _logger.info('Running kill_server to clean up any orphaned processes');
          await Process.start(
            killServerPath, 
            [],
            mode: ProcessStartMode.detachedWithStdio,
            runInShell: false,
          );
        }
      } catch (e) {
        _logger.warning('Error running kill_server: $e');
      }
    }
    
    _isRunning = false;
    _logger.info('Kernel stopped successfully');
    notifyListeners();
  }

  Future<String> _getKillServerPath() async {
    final exeDir = kDebugMode 
        ? path.join(Directory.current.path, 'python', 'dist')
        : path.dirname(Platform.resolvedExecutable);
    return path.join(exeDir, 'kill_server.exe');
  }

  Future<String> _getKernelPath() async {
    final exeDir = kDebugMode 
        ? path.join(Directory.current.path, 'python', 'dist')
        : path.dirname(Platform.resolvedExecutable);
    return path.join(exeDir, 'soda_kernel.exe');
  }

  Future<bool> _checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health')).timeout(
        Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<String?> addDownload(String url, String filename) async {
    if (!_isRunning) {
      _logger.error('Kernel not running');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/download/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          'filename': filename,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return result['data']['id'];
        }
      }
      return null;
    } catch (e) {
      _logger.error('Failed to add download: $e');
      return null;
    }
  }

  Future<bool> pauseDownload(String taskId) async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/download/pause'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': taskId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] ?? false;
      }
      return false;
    } catch (e) {
      _logger.error('Failed to pause download: $e');
      return false;
    }
  }

  Future<bool> resumeDownload(String taskId) async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/download/resume'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': taskId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] ?? false;
      }
      return false;
    } catch (e) {
      _logger.error('Failed to resume download: $e');
      return false;
    }
  }

  Future<bool> cancelDownload(String taskId) async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/download/cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': taskId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] ?? false;
      }
      return false;
    } catch (e) {
      _logger.error('Failed to cancel download: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    if (!_isRunning) return [];

    try {
      final response = await http.get(Uri.parse('$_baseUrl/download/tasks'));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return List<Map<String, dynamic>>.from(result['data']);
        }
      }
      return [];
    } catch (e) {
      _logger.error('Failed to get tasks: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStatistics() async {
    if (!_isRunning) return null;

    try {
      final response = await http.get(Uri.parse('$_baseUrl/download/statistics'));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return result['data'];
        }
      }
      return null;
    } catch (e) {
      _logger.error('Failed to get statistics: $e');
      return null;
    }
  }

  Future<bool> setDownloadDir(String path) async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/settings/download-dir'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'path': path}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          _logger.info('Download directory set to: $path');
          return true;
        }
      }
      return false;
    } catch (e) {
      _logger.error('Failed to set download directory: $e');
      return false;
    }
  }

  Future<String?> getDownloadDir() async {
    if (!_isRunning) return null;

    try {
      final response = await http.get(Uri.parse('$_baseUrl/settings/download-dir'));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return result['data']['path'];
        }
      }
      return null;
    } catch (e) {
      _logger.error('Failed to get download directory: $e');
      return null;
    }
  }

  @override
  void dispose() {
    stopKernel();
    super.dispose();
  }
}
