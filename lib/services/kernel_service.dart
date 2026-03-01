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

  // 启动进度
  double _startupProgress = 0.0;
  String _startupStatus = '';

  bool get isRunning => _isRunning;
  double get startupProgress => _startupProgress;
  String get startupStatus => _startupStatus;

  void _updateProgress(double progress, String status) {
    _startupProgress = progress;
    _startupStatus = status;
    notifyListeners();
  }

  // 过滤掉过于频繁的日志
  bool _shouldLogLine(String line) {
    // 过滤掉 aiohttp.access 的日志（太频繁）
    if (line.contains('aiohttp.access')) {
      return false;
    }
    // 过滤掉 pending_popup 的日志（太频繁）
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
      _logger.info('========================================');
      _logger.info('Starting download kernel...');
      _logger.info('========================================');

      // 步骤 1: 清理旧进程 (0% -> 15%)
      _updateProgress(0.0, '正在清理旧进程...');
      _logger.info('[1/4] Cleaning up any orphaned kernel processes...');
      await _killOrphanedKernelProcesses();
      await Future.delayed(const Duration(milliseconds: 300));
      _logger.info('[1/4] Cleanup completed');
      _updateProgress(0.15, '清理完成');

      // 步骤 2: 检查现有服务 (15% -> 30%)
      _updateProgress(0.15, '正在检查现有服务...');
      _logger.info(
          '[2/4] Checking if kernel server is already running on $_baseUrl');

      final isHealthy = await _checkHealth();
      if (isHealthy) {
        _isRunning = true;
        _logger.info('[2/4] Kernel server is already running and healthy');
        _logger.info('========================================');
        _logger.info('Kernel startup completed successfully');
        _logger.info('========================================');
        _updateProgress(1.0, '启动完成');
        notifyListeners();
        return true;
      }
      _logger.info('[2/4] No existing kernel found, starting new instance...');
      _updateProgress(0.30, '准备启动新实例...');

      // 步骤 3: 启动进程 (30% -> 50%)
      _updateProgress(0.30, '正在启动内核进程...');
      _logger.info('[3/4] Launching kernel process...');
      bool success;
      if (kDebugMode) {
        // 开发模式：启动 Python 脚本
        _logger.info('Mode: Development (Python script)');
        success = await _startPythonKernel();
      } else {
        // 生产模式：启动 exe
        _logger.info('Mode: Production (Executable)');
        success = await _startExeKernel();
      }

      if (success) {
        _logger.info('[4/4] Kernel process started and health check passed');
        _logger.info('========================================');
        _logger.info('Kernel startup completed successfully');
        _logger.info('========================================');
        _updateProgress(1.0, '启动完成');
      } else {
        _logger.error(
            '[4/4] Kernel process failed to start or health check failed');
        _logger.error('========================================');
        _logger.error('Kernel startup FAILED');
        _logger.error('========================================');
        _updateProgress(0.0, '启动失败');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.error('========================================');
      _logger.error('CRITICAL ERROR during kernel startup');
      _logger.error('Error: $e');
      _logger.error('Stack trace: $stackTrace');
      _logger.error('========================================');
      _updateProgress(0.0, '启动出错');
      return false;
    }
  }

  /// 开发模式：启动 Python 脚本
  Future<bool> _startPythonKernel() async {
    final scriptPath =
        path.join(Directory.current.path, 'python', 'soda_bridge_server.py');
    _logger.info('Starting Python kernel: $scriptPath');

    final scriptFile = File(scriptPath);
    if (!await scriptFile.exists()) {
      _logger.error('Python script not found: $scriptPath');
      return false;
    }

    try {
      // 启动 Python 脚本，使用绝对路径
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
      // Windows 中文环境：Python 默认使用系统编码（GBK）
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
        _kernelProcess!.stdout
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen(
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

        _kernelProcess!.stderr
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen(
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

      // 等待内核启动 (50% -> 100%)
      _logger.info('Waiting for Python kernel to start...');
      _updateProgress(0.50, '等待内核响应...');
      bool isHealthyAfterStart = false;
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        isHealthyAfterStart = await _checkHealth();

        // 更新进度: 50% + (i/20 * 50%)
        final progress = 0.50 + (i / 20 * 0.50);
        _updateProgress(progress, '健康检查 ${i + 1}/20...');

        if (isHealthyAfterStart) {
          _logger.info('Health check passed on attempt ${i + 1}');
          _updateProgress(1.0, '启动完成');
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
        _logger
            .error('Process may have crashed or failed to bind to port 9710');
        _updateProgress(0.0, '健康检查失败');
        await stopKernel();
        return false;
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to start Python kernel: $e');
      _logger.error('Stack trace: $stackTrace');
      return false;
    }
  }

  /// 生产模式：启动 exe
  Future<bool> _startExeKernel() async {
    final exePath = await _getKernelPath();
    _logger.info('Starting exe kernel: $exePath');

    final exeFile = File(exePath);
    if (!await exeFile.exists()) {
      _logger.error('Kernel executable not found: $exePath');
      return false;
    }

    try {
      // 使用 normal 模式以捕获输出
      _kernelProcess = await Process.start(
        exePath,
        [],
        mode: ProcessStartMode.normal,
        runInShell: false,
      );

      _logger.info('Exe process started, PID: ${_kernelProcess?.pid}');

      // 监听进程输出并同步到日志
      // Windows 中文环境：Python 默认使用系统编码（GBK）
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
        _kernelProcess!.stdout
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen(
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

        _kernelProcess!.stderr
            .transform(const Utf8Decoder(allowMalformed: true))
            .listen(
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

      // 等待内核启动 (50% -> 100%)
      _logger.info('Waiting for exe kernel to start...');
      _updateProgress(0.50, '等待内核响应...');
      bool isHealthyAfterStart = false;
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        isHealthyAfterStart = await _checkHealth();

        // 更新进度: 50% + (i/15 * 50%)
        final progress = 0.50 + (i / 15 * 0.50);
        _updateProgress(progress, '健康检查 ${i + 1}/15...');

        if (isHealthyAfterStart) {
          _updateProgress(1.0, '启动完成');
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
        _updateProgress(0.0, '健康检查失败');
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

        // 如果还在运行，强制终止
        if (_kernelProcess != null) {
          _kernelProcess!.kill(ProcessSignal.sigkill);
        }
      } catch (e) {
        _logger.warning('Error stopping kernel process: $e');
      }
      _kernelProcess = null;
    }

    // 直接在 Dart 中清理可能残留的进程
    await _killOrphanedKernelProcesses();

    _isRunning = false;
    _logger.info('Kernel stopped successfully');
    notifyListeners();
  }

  /// 清理占用 9710 端口和所有 kernel 相关进程
  Future<void> _killOrphanedKernelProcesses() async {
    try {
      if (Platform.isWindows) {
        // 1. 查找占用 9710 端口的进程
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
        final tasklistResult = await Process.run('tasklist', [
          '/FI',
          'IMAGENAME eq soda_bridge_server.exe',
          '/FO',
          'CSV',
          '/NH'
        ]);
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
                    _logger.warning(
                        'Failed to kill soda_bridge_server.exe PID $pid: $e');
                  }
                }
              }
            }
          }
        }

        // 3. 查找 Python 进程中运行 soda_bridge_server.py 的进程
        // 使用 PowerShell 代替 wmic（Windows 11 已弃用 wmic）
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
                final List<dynamic> processes =
                    jsonData is List ? jsonData : [jsonData];

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
            const Duration(seconds: 5),
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
      final response =
          await http.get(Uri.parse('$_baseUrl/settings/download-config'));

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
    int? globalSpeedLimit,
    bool? enableDynamicSegments,
    String? conflictStrategy,
    String? defaultUserAgent,
    String? httpVersionPolicy,
    Map<String, dynamic>? proxyConfig,
  }) async {
    if (!_isRunning) return false;

    try {
      final body = <String, dynamic>{};
      if (threads != null) {
        body['threads'] = threads;
      }
      if (segments != null) {
        body['segments'] = segments;
      }
      if (mode != null) {
        body['mode'] = mode;
      }
      if (maxConcurrentTasks != null) {
        body['max_concurrent_tasks'] = maxConcurrentTasks;
      }
      if (segmentSpeedLimit != null) {
        body['segment_speed_limit'] = segmentSpeedLimit;
      }
      if (globalSpeedLimit != null) {
        body['global_speed_limit'] = globalSpeedLimit;
      }
      if (enableDynamicSegments != null) {
        body['enable_dynamic_segments'] = enableDynamicSegments;
      }
      if (conflictStrategy != null) {
        body['conflict_strategy'] = conflictStrategy;
      }
      if (defaultUserAgent != null) {
        body['default_user_agent'] = defaultUserAgent;
      }
      if (httpVersionPolicy != null) {
        body['http_version_policy'] = httpVersionPolicy;
      }
      if (proxyConfig != null) {
        body['proxy'] = proxyConfig;
      }

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

  /// 测试代理连接
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

      if (username != null && username.isNotEmpty) {
        body['username'] = username;
      }
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/proxy/test'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] ?? false;
      }
      return false;
    } catch (e) {
      _logger.error('Failed to test proxy connection: $e');
      return false;
    }
  }

  /// 检查 URL 状态
  Future<Map<String, dynamic>> checkUrlStatus(String url) async {
    if (!_isRunning) {
      throw Exception('Kernel is not running');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/debug/check-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return result['data'] as Map<String, dynamic>;
        } else {
          throw Exception(result['error'] ?? 'Unknown error');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _logger.error('Failed to check URL status: $e');
      rethrow;
    }
  }

  /// 扫描局域网设备
  Future<Map<String, dynamic>> scanLan() async {
    if (!_isRunning) {
      throw Exception('Kernel is not running');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/debug/scan-lan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          return result['data'] as Map<String, dynamic>;
        } else {
          throw Exception(result['error'] ?? 'Unknown error');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _logger.error('Failed to scan LAN: $e');
      rethrow;
    }
  }

  /// 重试失败的分段
  Future<bool> retryFailedSegments(String taskId) async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/download/retry-segments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': taskId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          _logger.info('Retrying failed segments for task: $taskId');
          return true;
        }
      }
      return false;
    } catch (e) {
      _logger.error('Failed to retry segments: $e');
      return false;
    }
  }

  /// 重试特定分段
  Future<bool> retrySegment(String taskId, int segmentIndex) async {
    if (!_isRunning) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/download/retry-segment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': taskId,
          'segment_index': segmentIndex,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          _logger.info('Retrying segment $segmentIndex for task: $taskId');
          return true;
        }
      }
      return false;
    } catch (e) {
      _logger.error('Failed to retry segment: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStatistics() async {
    if (!_isRunning) return null;

    try {
      final response =
          await http.get(Uri.parse('$_baseUrl/download/statistics'));

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
      final response =
          await http.get(Uri.parse('$_baseUrl/settings/download-dir'));

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
