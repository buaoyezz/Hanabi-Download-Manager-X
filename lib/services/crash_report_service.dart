import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:flutter/foundation.dart';

import 'app_logger_service.dart';

class CrashReport {
  final int schemaVersion;
  final String app;
  final String timestampLocal;
  final int? processId;
  final int? threadId;
  final String kind;
  final String reason;
  final String? exceptionCode;
  final String? exceptionAddress;
  final String? modulePath;
  final String crashDirectory;
  final String reportPath;
  final Map<String, Object?> raw;

  const CrashReport({
    required this.schemaVersion,
    required this.app,
    required this.timestampLocal,
    required this.processId,
    required this.threadId,
    required this.kind,
    required this.reason,
    required this.exceptionCode,
    required this.exceptionAddress,
    required this.modulePath,
    required this.crashDirectory,
    required this.reportPath,
    required this.raw,
  });

  factory CrashReport.fromJson(Map<String, Object?> json) {
    return CrashReport(
      schemaVersion: _intValue(json['schemaVersion']) ?? 1,
      app: _stringValue(json['app'], fallback: 'Hanabi Download ManagerX'),
      timestampLocal: _stringValue(json['timestampLocal']),
      processId: _intValue(json['processId']),
      threadId: _intValue(json['threadId']),
      kind: _stringValue(json['kind'], fallback: 'native'),
      reason: _stringValue(json['reason'], fallback: 'Unknown native crash'),
      exceptionCode: _nullableStringValue(json['exceptionCode']),
      exceptionAddress: _nullableStringValue(json['exceptionAddress']),
      modulePath: _nullableStringValue(json['modulePath']),
      crashDirectory: _stringValue(json['crashDirectory']),
      reportPath: _stringValue(json['reportPath']),
      raw: Map<String, Object?>.from(json),
    );
  }

  String userFacingReason({required bool isChinese}) {
    final normalizedCode = exceptionCode?.toUpperCase();
    if (normalizedCode == '0XC0000005') {
      return isChinese
          ? '访问冲突：native 代码读取或写入了无效内存。常见触发点是 Flutter Windows 引擎、窗口特效、插件或系统 DLL。'
          : 'Access violation: native code read or wrote invalid memory. This is commonly caused by the Flutter Windows engine, window effects, plugins, or system DLLs.';
    }
    if (normalizedCode == '0XC00000FD') {
      return isChinese
          ? '栈溢出：native 调用栈过深或发生了递归失控。'
          : 'Stack overflow: native calls became too deep or recursive.';
    }
    if (normalizedCode == '0XE06D7363') {
      return isChinese
          ? '未处理的 C++ 异常：native 层抛出的异常没有被捕获。'
          : 'Unhandled C++ exception: an exception from native code was not caught.';
    }
    if (kind == 'signal' && reason.toLowerCase().contains('abort')) {
      return isChinese
          ? 'C/C++ 运行时主动 abort：底层库认为状态已经不可恢复，所以直接终止了进程。'
          : 'C/C++ runtime abort: a native library considered the state unrecoverable and terminated the process.';
    }
    if (kind == 'terminate') {
      return isChinese
          ? 'std::terminate：C++ 异常或运行时状态没有被正常处理，进程被强制结束。'
          : 'std::terminate: a C++ exception or runtime state was not handled and the process was forced to exit.';
    }
    if (reason.trim().isNotEmpty) {
      return reason;
    }
    return isChinese
        ? '系统层 native 崩溃，原因未能进一步分类。'
        : 'Native crash; no more specific reason was captured.';
  }

  String kindLabel({required bool isChinese}) {
    switch (kind) {
      case 'seh':
        return isChinese ? 'Windows 结构化异常' : 'Windows SEH exception';
      case 'signal':
        return isChinese ? 'C 运行时信号' : 'C runtime signal';
      case 'terminate':
        return isChinese ? 'C++ 终止处理' : 'C++ terminate';
      default:
        return isChinese ? '系统层崩溃' : 'Native crash';
    }
  }

  static String _stringValue(Object? value, {String fallback = ''}) {
    final string = value?.toString() ?? '';
    return string.isEmpty ? fallback : string;
  }

  static String? _nullableStringValue(Object? value) {
    final string = value?.toString().trim();
    return string == null || string.isEmpty ? null : string;
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class CrashReportService extends ChangeNotifier {
  CrashReportService({AppLoggerService? logger})
      : _logger = logger ?? AppLoggerService();

  final AppLoggerService _logger;
  bool _initialized = false;
  CrashReport? _pendingReport;

  CrashReport? get pendingReport => _pendingReport;
  bool get hasPendingReport => _pendingReport != null;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!Platform.isWindows) {
      return;
    }

    // Launch the crash watchdog daemon in the background
    _spawnWatchdogDaemon();

    final file = _lastCrashFile;
    try {
      if (!await file.exists()) {
        return;
      }

      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is! Map) {
        _logger.warning(
          'CrashReport',
          'Ignoring malformed native crash report: ${file.path}',
        );
        return;
      }

      _pendingReport = CrashReport.fromJson(
        decoded.map<String, Object?>(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );

      _logger.warning(
        'CrashReport',
        'Pending native crash report detected: ${_pendingReport!.reportPath}. The download kernel might have caused an uncatchable native crash (e.g. within rhttp).',
      );
      notifyListeners();
    } catch (e, stack) {
      _logger.warning(
        'CrashReport',
        'Failed to load native crash report: $e\n$stack',
      );
    }
  }

  void _spawnWatchdogDaemon() async {
    try {
      final exePath = path.join(path.dirname(Platform.resolvedExecutable), 'HanabiDaemon.exe');
      if (File(exePath).existsSync()) {
        final currentPid = pid.toString(); // from dart:io
        final logDir = (await AppLoggerService().getLogDirectory()).path;
        final crashDir = crashDirectory.path;

        // Spawn completely detached so it doesn't block the main process exit
        Process.start(
          exePath,
          [currentPid, logDir, crashDir],
          mode: ProcessStartMode.detached,
        ).then((process) {
          _logger.info('CrashReport', 'Watchdog daemon spawned with PID: ${process.pid}');
        }).catchError((e) {
          _logger.warning('CrashReport', 'Failed to spawn watchdog daemon: $e');
        });
      } else {
        _logger.debug('CrashReport', 'Watchdog daemon not found at $exePath');
      }
    } catch (e) {
      _logger.warning('CrashReport', 'Error preparing watchdog daemon: $e');
    }
  }

  Future<void> acknowledgePendingReport() async {
    final report = _pendingReport;
    if (report == null) {
      return;
    }

    try {
      final file = _lastCrashFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      _logger.warning('CrashReport', 'Failed to acknowledge crash report: $e');
    } finally {
      _pendingReport = null;
      notifyListeners();
    }
  }

  Directory get crashDirectory {
    final userProfile = Platform.environment['USERPROFILE']?.trim();
    if (userProfile != null && userProfile.isNotEmpty) {
      return Directory('$userProfile\\.hdmx\\crash_reports');
    }
    return Directory(
      '${Directory.systemTemp.path}\\HanabiDownloadManagerX\\crash_reports',
    );
  }

  File get _lastCrashFile => File('${crashDirectory.path}\\last_crash.json');
}
