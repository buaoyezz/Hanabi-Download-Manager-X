import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/plugin_manifest.dart';
import 'app_logger_service.dart';
import 'plugin_diagnostic_logger.dart';
import 'plugin_lifecycle_service.dart';

class PluginInvocationResult {
  const PluginInvocationResult({
    required this.success,
    this.result,
    this.error,
    this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final bool success;
  final Object? result;
  final String? error;
  final int? exitCode;
  final String stdout;
  final String stderr;
}

class _PluginProcessSpec {
  const _PluginProcessSpec({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

class PluginProcessRunner {
  PluginProcessRunner({
    PluginLifecycleService? pluginService,
    AppLoggerService? logger,
  })  : _pluginService = pluginService ?? PluginLifecycleService(),
        _logger = logger ?? AppLoggerService();

  final PluginLifecycleService _pluginService;
  final AppLoggerService _logger;
  final PluginDiagnosticLogger _diag = PluginDiagnosticLogger();

  Future<PluginInvocationResult> invoke(
    InstalledPlugin plugin, {
    required String method,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final spec = _buildProcessSpec(plugin);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final request = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };

    final logDir = Directory(_pluginService.pluginLogDir(plugin.id));
    await logDir.create(recursive: true);
    final logFile = File(path.join(logDir.path, 'runtime.log'));

    Process? process;
    try {
      _diag.mark(
        'process.invoke.start',
        pluginId: plugin.id,
        data: <String, Object?>{
          'method': method,
          'requestId': id,
          'directory': plugin.directory,
          'executable': spec.executable,
          'arguments': spec.arguments,
          'params': params,
          'timeoutMs': timeout.inMilliseconds,
        },
      );
      process = await Process.start(
        spec.executable,
        spec.arguments,
        workingDirectory: plugin.directory,
        environment: {
          'HANABI_PLUGIN_ID': plugin.id,
          'HANABI_PLUGIN_DIR': plugin.directory,
          'HANABI_PLUGIN_LOG_DIR': logDir.path,
        },
      );
      _diag.mark(
        'process.started',
        pluginId: plugin.id,
        data: <String, Object?>{
          'method': method,
          'requestId': id,
          'pid': process.pid,
        },
      );

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();

      process.stdin.writeln(jsonEncode(request));
      await process.stdin.close();
      _diag.mark(
        'process.stdin.closed',
        pluginId: plugin.id,
        data: <String, Object?>{'method': method, 'requestId': id},
      );

      final exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
        _diag.mark(
          'process.timeout',
          pluginId: plugin.id,
          data: <String, Object?>{
            'method': method,
            'requestId': id,
            'pid': process?.pid,
          },
        );
        process?.kill(ProcessSignal.sigkill);
        throw TimeoutException(
          'Plugin ${plugin.id} timed out after ${timeout.inSeconds}s',
        );
      });

      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;
      await _appendLog(logFile, method, exitCode, stdout, stderr);
      _diag.mark(
        'process.exited',
        pluginId: plugin.id,
        data: <String, Object?>{
          'method': method,
          'requestId': id,
          'exitCode': exitCode,
          'stdoutLength': stdout.length,
          'stderrLength': stderr.length,
          'stdoutTail': _tail(stdout),
          'stderrTail': _tail(stderr),
        },
      );

      if (exitCode != 0) {
        return PluginInvocationResult(
          success: false,
          error:
              stderr.trim().isEmpty ? 'plugin exited with $exitCode' : stderr,
          exitCode: exitCode,
          stdout: stdout,
          stderr: stderr,
        );
      }

      final decoded = _decodeResponse(stdout);
      if (decoded == null) {
        _diag.mark(
          'process.decode.empty',
          pluginId: plugin.id,
          data: <String, Object?>{
            'method': method,
            'requestId': id,
            'stdoutTail': _tail(stdout),
          },
        );
        return PluginInvocationResult(
          success: false,
          error: 'plugin returned no JSON-RPC response',
          exitCode: exitCode,
          stdout: stdout,
          stderr: stderr,
        );
      }

      final error = decoded['error'];
      if (error != null) {
        _diag.mark(
          'process.response.error',
          pluginId: plugin.id,
          data: <String, Object?>{
            'method': method,
            'requestId': id,
            'error': error,
          },
        );
        return PluginInvocationResult(
          success: false,
          error: error is Map
              ? (error['message']?.toString() ?? error.toString())
              : error.toString(),
          exitCode: exitCode,
          stdout: stdout,
          stderr: stderr,
        );
      }

      _diag.mark(
        'process.invoke.success',
        pluginId: plugin.id,
        data: <String, Object?>{
          'method': method,
          'requestId': id,
          'result': decoded['result'],
        },
      );
      return PluginInvocationResult(
        success: true,
        result: decoded['result'],
        exitCode: exitCode,
        stdout: stdout,
        stderr: stderr,
      );
    } catch (e, stackTrace) {
      if (process != null) {
        process.kill(ProcessSignal.sigkill);
      }
      _diag.error(
        'process.invoke.error',
        e,
        pluginId: plugin.id,
        stackTrace: stackTrace,
        data: <String, Object?>{
          'method': method,
          'requestId': id,
          'pid': process?.pid,
        },
      );
      _logger.error('Plugin', 'Plugin invocation failed: ${plugin.id}: $e');
      await logFile.writeAsString(
        '[${DateTime.now().toIso8601String()}] $method failed: $e\n',
        mode: FileMode.append,
      );
      return PluginInvocationResult(success: false, error: e.toString());
    }
  }

  _PluginProcessSpec _buildProcessSpec(InstalledPlugin plugin) {
    final entryPath = path.normalize(path.join(
      plugin.directory,
      plugin.manifest.entry,
    ));
    final extension = path.extension(entryPath).toLowerCase();

    switch (extension) {
      case '.py':
        return _PluginProcessSpec(
          executable: 'python',
          arguments: [entryPath],
        );
      case '.js':
      case '.mjs':
      case '.cjs':
        return _PluginProcessSpec(
          executable: 'node',
          arguments: [entryPath],
        );
      case '.ps1':
        return _PluginProcessSpec(
          executable: 'powershell',
          arguments: [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            entryPath,
          ],
        );
      case '.bat':
      case '.cmd':
        return _PluginProcessSpec(
          executable: 'cmd',
          arguments: ['/c', entryPath],
        );
      default:
        return _PluginProcessSpec(executable: entryPath, arguments: const []);
    }
  }

  Map<String, dynamic>? _decodeResponse(String stdout) {
    final lines = const LineSplitter().convert(stdout);
    for (final line in lines.reversed) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> _appendLog(
    File file,
    String method,
    int exitCode,
    String stdout,
    String stderr,
  ) async {
    final buffer = StringBuffer()
      ..writeln('[${DateTime.now().toIso8601String()}] $method exit=$exitCode');
    if (stdout.trim().isNotEmpty) {
      buffer
        ..writeln('stdout:')
        ..writeln(stdout.trimRight());
    }
    if (stderr.trim().isNotEmpty) {
      buffer
        ..writeln('stderr:')
        ..writeln(stderr.trimRight());
    }
    await file.writeAsString('${buffer.toString()}\n', mode: FileMode.append);
  }

  String _tail(String value) {
    const maxLength = 400;
    if (value.length <= maxLength) {
      return value;
    }
    return value.substring(value.length - maxLength);
  }
}
