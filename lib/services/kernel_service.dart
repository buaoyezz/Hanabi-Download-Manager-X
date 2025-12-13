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

  // 过滤掉过于频繁的日志
  bool _shouldLogLine(String line) {
    // 过滤�?aiohttp.access 的日志（太频繁）
    if (line.contains('aiohttp.access')) {
      return false;
    }
    // 过滤�?pending_popup 的日志（太频繁）
    if (line.contains('[bridge] pending_popup')) {
      return false;
    }
    // 过滤掉重复的 Task status 日志
    if (line.contains('[bridge] Task') && line.contains('status=')) {
      return false;
    }
    return true;
  }

  Future<bool> startKernel() async {
    if (_isRunning) {
      _logger.info('Kernel already running');
      return true;
    }

    try {
      // 先清理可能残留的旧进�?
      _logger.info('Cleaning up any orphaned kernel processes...');
      await _killOrphanedKernelProcesses();
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 检查服务器是否已经在运�?
      _logger.info('Checking if kernel server is running on $_baseUrl');
      
      final isHealthy = await _checkHealth();
      if (isHealthy) {
        _isRunning = true;
        _logger.info('Kernel server is already running and healthy');
        notifyListeners();
        return true;
      }
      
      // 根据环境选择启动方式
      if (kDebugMode) {
        // 开发模式：启动 Python 脚本
        return await _startPythonKernel();
      } else {
        // 生产模式：启�?exe
        return await _startExeKernel();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to start kernel: $e');
      _logger.error('Stack trace: $stackTrace');
      return false;
    }
  }

  /// 开发模式：启动 Python 脚本
  Future<bool> _startPythonKernel() async {
    final scriptPath = path.join(Directory.current.path, 'python', 'soda_bridge_server.py');
    _logger.info('Starting Python kernel: $scriptPath');
    
    final scriptFile = File(scriptPath);
    if (!await scriptFile.exists()) {
      _logger.error('Python script not found: $scriptPath');
      return false;
    }
    
    try {
      // 启动 Python 脚本，使用绝对路�?
      _logger.info('Executing: python $scriptPath');
      _kernelProcess = await Process.start(
        'python',
        [scriptPath],
        mode: ProcessStartMode.normal,
        runInShell: false,
        workingDirectory: path.join(Directory.current.path, 'python'),
      );

      _logger.info('Python process started, PID: ${_kernelProcess?.pid}');
      
      // 监听进程输出并同步到日志
      // Windows 中文环境�?Python 默认使用系统编码（GBK�?
      if (Platform.isWindows) {
        _kernelProcess!.stdout.transform(systemEncoding.decoder).listen(
          (data) {
            for (var line in data.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty && _shouldLogLine(trimmed)) {
                _logger.info(trimmed);
              }
            }
          },
          onError: (error) {
            _logger.error('Error reading stdout: $error');
          },
        );
        
        _kernelProcess!.stderr.transform(systemEncoding.decoder).listen(
          (data) {
            for (var line in data.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty) {
                _logger.error(trimmed);
              }
            }
          },
          onError: (error) {
            _logger.error('Error reading stderr: $error');
          },
        );
      } else {
        _kernelProcess!.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen(
          (data) {
            for (var line in data.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty && _shouldLogLine(trimmed)) {
                _logger.info(trimmed);
              }
            }
          },
          onError: (error) {
            _logger.error('Error reading stdout: $error');
          },
        );
        
        _kernelProcess!.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen(
          (data) {
            for (var line in data.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty) {
                _logger.error(trimmed);
              }
            }
          },
          onError: (error) {
            _logger.error('Error reading stderr: $error');
          },
        );
      }

      // 等待内核启动
      _logger.info('Waiting for Python kernel to start...');
      bool isHealthyAfterStart = false;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        isHealthyAfterStart = await _checkHealth();
        if (isHealthyAfterStart) {
          _logger.info('Health check passed on attempt ${i + 1}');
          break;
        }
        _logger.info('Health check attempt ${i + 1}/20...');
      }

      if (isHealthyAfterStart) {
        _isRunning = true;
        _logger.info('Python kernel started successfully');
        notifyListeners();
        return true;
      } else {
        _logger.error('Python kernel health check failed after start');
        _logger.error('Process may have crashed or failed to bind to port 9710');
        await stopKernel();
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to start Python kernel: $e');
      _logger.error('Stack trace: $stackTrace');
      return false;
    }
  }

  /// 生产模式：启�?exe
  Future<bool> _startExeKernel() async {
    final exePath = await _getKernelPath();
    _logger.info('Starting exe kernel: $exePath');
    
    final exeFile = File(exePath);
    if (!await exeFile.exists()) {
      _logger.error('Kernel executable not found: $exePath');
      return false;
    }
    
    try {
      // 使用normal模式以捕获输�?
      _kernelProcess = await Process.start(
        exePath,
        [],
        mode: ProcessStartMode.normal,
        runInShell: false,
      );

      _logger.info('Exe process started, PID: ${_kernelProcess?.pid}');
      
      // 监听进程输出并同步到日志
      // Windows 中文环境�?Python 默认使用系统编码（GBK�?
      if (Platform.isWindows) {
        _kernelProcess!.stdout.transform(systemEncoding.decoder).listen(
          (data) {
            for (var line in data.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty && _shouldLogLine(trimmed)) {
                _logger.info(trimmed);
              }
            }
          },
          onError: (error) {
            _logger.error('Error reading stdout: $error');
          },
        );
        
        _kernelProcess!.stderr.transform(systemEncoding.decoder).listen(
          (data) {
            for (var line in data.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty) {
                _logger.error(trimmed);
              }
            }
          },
          onError: (error) {
            _logger.error('Error reading stderr: $error');
          },
        );
      } else {
        _kernelProcess!.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen(
          (data) {
            for (var line in data.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty && _shouldLogLine(trimmed)) {
                _logger.info(trimmed);
              }
            }
          },
          onError: (error) {
            _logger.error('Error reading stdout: $error');
          },
        );
        
        _kernelProcess!.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen(
          (data) {
            for (var line in data.split('\n')) {
              final trimmed = line.trim();
              if (trimmed.isNotEmpty) {
                _logger.error(trimmed);
              }
            }
          },
          onError: (error) {
            _logger.error('Error reading stderr: $error');
          },
        );
      }

      // 等待内核启动
      _logger.info('Waiting for exe kernel to start...');
      bool isHealthyAfterStart = false;
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        isHealthyAfterStart = await _checkHealth();
        if (isHealthyAfterStart) {
          break;
        }
        _logger.info('Health check attempt ${i + 1}/15...');
      }

      if (isHealthyAfterStart) {
        _isRunning = true;
        _logger.info('Exe kernel started successfully');
        notifyListeners();
        return true;
      } else {
        _logger.error('Exe kernel health check failed after start');
        await stopKernel();
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to start exe kernel: $e');
      _logger.error('Stack trace: $stackTrace');
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
        
        // 如果还在运行，强制终�?
        if (_kernelProcess != null) {
          _kernelProcess!.kill(ProcessSignal.sigkill);
        }
      } catch (e) {
        _logger.warning('Error stopping kernel process: $e');
      }
      _kernelProcess = null;
    }
    
    // 直接�?Dart 中清理可能残留的进程
    await _killOrphanedKernelProcesses();
    
    _isRunning = false;
    _logger.info('Kernel stopped successfully');
    notifyListeners();
  }

  /// 清理占用 9710 端口和所�?kernel 相关进程
  Future<void> _killOrphanedKernelProcesses() async {
    try {
      if (Platform.isWindows) {
        // 1. 查找占用 9710 端口的进�?
        final netstatResult = await Process.run('netstat', ['-ano']);
        if (netstatResult.exitCode == 0) {
          final lines = netstatResult.stdout.toString().split('\n');
          for (final line in lines) {
            if (line.contains(':9710') && line.contains('LISTENING')) {
              final parts = line.trim().split(RegExp(r'\s+'));
              if (parts.isNotEmpty) {
                final pid = parts.last;
                try {
                  await Process.run('taskkill', ['/F', '/PID', pid]);
                  _logger.info('Killed process on port 9710, PID: $pid');
                } catch (e) {
                  _logger.warning('Failed to kill PID $pid: $e');
                }
              }
            }
          }
        }

        // 2. 查找所有 soda_bridge_server.exe 进程
        final tasklistResult = await Process.run('tasklist', ['/FI', 'IMAGENAME eq soda_bridge_server.exe', '/FO', 'CSV', '/NH']);
        if (tasklistResult.exitCode == 0) {
          final output = tasklistResult.stdout.toString();
          if (output.isNotEmpty && !output.contains('INFO: No tasks')) {
            final lines = output.split('\n');
            for (final line in lines) {
              if (line.contains('soda_bridge_server.exe')) {
                final parts = line.split(',');
                if (parts.length >= 2) {
                  final pid = parts[1].replaceAll('"', '').trim();
                  try {
                    await Process.run('taskkill', ['/F', '/PID', pid]);
                    _logger.info('Killed soda_bridge_server.exe, PID: $pid');
                  } catch (e) {
                    _logger.warning('Failed to kill soda_bridge_server.exe PID $pid: $e');
                  }
                }
              }
            }
          }
        }

        // 3. 查找 Python 进程中运�?soda_bridge_server.py 的进�?
        // 使用 PowerShell 代替 wmic（Windows 11 已弃�?wmic�?
        try {
          final psResult = await Process.run('powershell', [
            '-Command',
            'Get-CimInstance Win32_Process -Filter "name=\'python.exe\'" | Select-Object ProcessId,CommandLine | ConvertTo-Json'
          ]);
          
          if (psResult.exitCode == 0) {
            final output = psResult.stdout.toString();
            if (output.isNotEmpty && output.trim() != 'null') {
              try {
                final dynamic jsonData = jsonDecode(output);
                final List<dynamic> processes = jsonData is List ? jsonData : [jsonData];
                
                for (final proc in processes) {
                  final commandLine = proc['CommandLine']?.toString() ?? '';
                  if (commandLine.contains('soda_bridge_server.py')) {
                    final pid = proc['ProcessId']?.toString() ?? '';
                    if (pid.isNotEmpty) {
                      try {
                        await Process.run('taskkill', ['/F', '/PID', pid]);
                        _logger.info('Killed Python kernel process, PID: $pid');
                      } catch (e) {
                        _logger.warning('Failed to kill Python PID $pid: $e');
                      }
                    }
                  }
                }
              } catch (e) {
                _logger.warning('Failed to parse PowerShell output: $e');
              }
            }
          }
        } catch (e) {
          _logger.warning('Failed to query Python processes: $e');
        }
      }
    } catch (e) {
      _logger.warning('Error cleaning up orphaned processes: $e');
    }
  }



  Future<String> _getKernelPath() async {
    final exeDir = kDebugMode 
        ? path.join(Directory.current.path, 'python', 'dist')
        : path.dirname(Platform.resolvedExecutable);
    return path.join(exeDir, 'soda_bridge_server.exe');
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

  Future<String?> addDownload(
    String url, 
    String filename, {
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
  }) async {
    if (!_isRunning) {
      _logger.error('Kernel not running');
      return null;
    }

    try {
      final body = <String, dynamic>{
        'url': url,
        'filename': filename,
      };
      
      // 添加可选的身份验证参数
      if (referer != null && referer.isNotEmpty) {
        body['referer'] = referer;
      }
      if (userAgent != null && userAgent.isNotEmpty) {
        body['user_agent'] = userAgent;
      }
      if (cookies != null && cookies.isNotEmpty) {
        body['cookies'] = cookies;
      }
      if (headers != null && headers.isNotEmpty) {
        body['headers'] = headers;
      }
      
      final response = await http.post(
        Uri.parse('$_baseUrl/download/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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

  Future<Map<String, dynamic>?> getDownloadConfig() async {
    if (!_isRunning) return null;

    try {
      final response = await http.get(Uri.parse('$_baseUrl/settings/download-config'));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return result['data'];
        }
      }
      return null;
    } catch (e) {
      _logger.error('Failed to get download config: $e');
      return null;
    }
  }

  Future<bool> setDownloadConfig({
    int? threads,
    int? segments,
    String? mode,
    int? maxConcurrentTasks,
    int? segmentSpeedLimit,
  }) async {
    if (!_isRunning) return false;

    try {
      final body = <String, dynamic>{};
      if (threads != null) body['threads'] = threads;
      if (segments != null) body['segments'] = segments;
      if (mode != null) body['mode'] = mode;
      if (maxConcurrentTasks != null) body['max_concurrent_tasks'] = maxConcurrentTasks;
      if (segmentSpeedLimit != null) body['segment_speed_limit'] = segmentSpeedLimit;

      final response = await http.post(
        Uri.parse('$_baseUrl/settings/download-config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] ?? false;
      }
      return false;
    } catch (e) {
      _logger.error('Failed to set download config: $e');
      return false;
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

  Future<bool> clearAllData() async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/settings/clear-all-data'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          _logger.info('All data cleared successfully');
          return true;
        }
      }
      return false;
    } catch (e) {
      _logger.error('Failed to clear all data: $e');
      return false;
    }
  }

  @override
  void dispose() {
    stopKernel();
    super.dispose();
  }
}

