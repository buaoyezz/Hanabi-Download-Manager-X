import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/plugin_manifest.dart';
import '../utils/constants.dart';
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
    this.errorCode,
    this.errorData,
  });

  final bool success;
  final Object? result;
  final String? error;
  final int? exitCode;
  final String stdout;
  final String stderr;
  final Object? errorCode;
  final Object? errorData;
}

typedef PluginDirectoryResolver = String Function(InstalledPlugin plugin);

class _PluginProcessSpec {
  const _PluginProcessSpec({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
}

class PluginProcessRunner {
  PluginProcessRunner({
    PluginLifecycleService? pluginService,
    AppLoggerService? logger,
    PluginDirectoryResolver? logDirectoryResolver,
    PluginDirectoryResolver? dataDirectoryResolver,
  })  : _pluginService = pluginService ?? PluginLifecycleService(),
        _logger = logger ?? AppLoggerService(),
        _logDirectoryResolver = logDirectoryResolver,
        _dataDirectoryResolver = dataDirectoryResolver;

  final PluginLifecycleService _pluginService;
  final AppLoggerService _logger;
  final PluginDirectoryResolver? _logDirectoryResolver;
  final PluginDirectoryResolver? _dataDirectoryResolver;
  final PluginDiagnosticLogger _diag = PluginDiagnosticLogger();

  Future<PluginInvocationResult> invoke(
    InstalledPlugin plugin, {
    required String method,
    required Map<String, dynamic> params,
    Duration? timeout,
  }) async {
    final effectiveTimeout =
        timeout ?? Duration(seconds: plugin.manifest.runtime.timeoutSeconds);
    final spec = _buildProcessSpec(plugin);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final logDir = Directory(_resolveLogDirectory(plugin));
    final dataDir = Directory(_resolveDataDirectory(plugin));
    await Future.wait([
      logDir.create(recursive: true),
      dataDir.create(recursive: true),
    ]);
    final request = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
      'meta': {
        'apiVersion': plugin.manifest.apiVersion,
        'host': {
          'name': 'Hanabi Download Manager X',
          'version': AppConstants.version,
          'platform': Platform.operatingSystem,
        },
        'plugin': {
          'id': plugin.id,
          'version': plugin.version,
        },
        'invocation': {
          'method': method,
          'requestedAt': DateTime.now().toUtc().toIso8601String(),
          'timeoutMs': effectiveTimeout.inMilliseconds,
        },
        'paths': {
          'plugin': plugin.directory,
          'data': dataDir.path,
          'logs': logDir.path,
        },
      },
    };

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
          'workingDirectory': spec.workingDirectory,
          'timeoutMs': effectiveTimeout.inMilliseconds,
        },
      );
      process = await Process.start(
        spec.executable,
        spec.arguments,
        workingDirectory: spec.workingDirectory,
        environment: {
          ...plugin.manifest.runtime.environment,
          'HANABI_PLUGIN_ID': plugin.id,
          'HANABI_PLUGIN_DIR': plugin.directory,
          'HANABI_PLUGIN_LOG_DIR': logDir.path,
          'HANABI_PLUGIN_DATA_DIR': dataDir.path,
          'HANABI_API_VERSION': plugin.manifest.apiVersion,
          'HANABI_APP_VERSION': AppConstants.version,
          'HANABI_REQUEST_ID': id,
          'HANABI_REQUEST_METHOD': method,
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

      final exitCode =
          await process.exitCode.timeout(effectiveTimeout, onTimeout: () {
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
          'Plugin ${plugin.id} timed out after ${effectiveTimeout.inSeconds}s',
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

      final protocolError = _validateResponse(decoded, id);
      if (protocolError != null) {
        _diag.mark(
          'process.response.invalid',
          pluginId: plugin.id,
          data: <String, Object?>{
            'method': method,
            'requestId': id,
            'error': protocolError,
          },
        );
        return PluginInvocationResult(
          success: false,
          error: protocolError,
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
          errorCode: error is Map ? error['code'] : null,
          errorData: error is Map ? error['data'] : null,
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
    final runtime = plugin.manifest.runtime;
    final workingDirectory = runtime.workingDirectory == null
        ? plugin.directory
        : path.normalize(path.join(plugin.directory, runtime.workingDirectory));
    final runtimeArguments = runtime.arguments
        .map((argument) => argument
            .replaceAll('{entry}', entryPath)
            .replaceAll('{pluginDir}', plugin.directory))
        .toList(growable: false);

    if (runtime.executable != null) {
      final executable = _resolveExecutable(plugin, runtime.executable!);
      final hasEntryPlaceholder =
          runtime.arguments.any((argument) => argument.contains('{entry}'));
      return _PluginProcessSpec(
        executable: executable,
        arguments: hasEntryPlaceholder
            ? runtimeArguments
            : [entryPath, ...runtimeArguments],
        workingDirectory: workingDirectory,
      );
    }

    switch (extension) {
      case '.py':
        return _PluginProcessSpec(
          executable: 'python',
          arguments: [entryPath, ...runtimeArguments],
          workingDirectory: workingDirectory,
        );
      case '.js':
      case '.mjs':
      case '.cjs':
        return _PluginProcessSpec(
          executable: 'node',
          arguments: [entryPath, ...runtimeArguments],
          workingDirectory: workingDirectory,
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
            ...runtimeArguments,
          ],
          workingDirectory: workingDirectory,
        );
      case '.bat':
      case '.cmd':
        return _PluginProcessSpec(
          executable: 'cmd',
          arguments: ['/c', entryPath, ...runtimeArguments],
          workingDirectory: workingDirectory,
        );
      default:
        return _PluginProcessSpec(
          executable: entryPath,
          arguments: runtimeArguments,
          workingDirectory: workingDirectory,
        );
    }
  }

  String _resolveExecutable(InstalledPlugin plugin, String executable) {
    if (path.isAbsolute(executable)) {
      return path.normalize(executable);
    }
    if (executable.contains('/') || executable.contains('\\')) {
      return path.normalize(path.join(plugin.directory, executable));
    }
    return executable;
  }

  String _resolveLogDirectory(InstalledPlugin plugin) {
    return _logDirectoryResolver?.call(plugin) ??
        _pluginService.pluginLogDir(plugin.id);
  }

  String _resolveDataDirectory(InstalledPlugin plugin) {
    return _dataDirectoryResolver?.call(plugin) ??
        _pluginService.pluginDataDir(plugin.id);
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

  String? _validateResponse(Map<String, dynamic> response, String requestId) {
    final jsonrpc = response['jsonrpc'];
    if (jsonrpc != null && jsonrpc.toString() != '2.0') {
      return 'plugin returned unsupported JSON-RPC version: $jsonrpc';
    }
    final responseId = response['id'];
    if (responseId != null && responseId.toString() != requestId) {
      return 'plugin response id does not match request id';
    }
    final hasResult = response.containsKey('result');
    final hasError = response.containsKey('error');
    if (hasResult == hasError) {
      return 'plugin response must contain exactly one of result or error';
    }
    if (hasError && response['error'] == null) {
      return 'plugin error response cannot be null';
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
