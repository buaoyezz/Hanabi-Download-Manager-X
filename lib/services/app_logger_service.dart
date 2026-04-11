import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String source;
  final String message;

  // 缓存格式化结果，避免重复计算
  late final String formattedTime = _formatTime();
  late final String levelString = _formatLevel();

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  String _formatTime() {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  String _formatLevel() {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  String format({bool fullTimestamp = false}) {
    final timeText =
        fullTimestamp ? timestamp.toIso8601String() : formattedTime;
    return '[$timeText] [$levelString] [$source] $message';
  }
}

class AppLoggerService extends ChangeNotifier {
  static final AppLoggerService _instance = AppLoggerService._internal();
  static const bool _isFlutterTest = bool.fromEnvironment('FLUTTER_TEST');
  factory AppLoggerService() => _instance;
  AppLoggerService._internal();

  final Queue<LogEntry> _logs = Queue();
  final int _maxLogs = 1000;
  bool _consoleOutputEnabled = kDebugMode;

  // 节流：最多每 100ms 通知一次
  Timer? _notifyTimer;
  bool _pendingNotify = false;

  // 快照缓存：避免每次 Consumer 重建都 toList
  int _version = 0;
  int _snapshotVersion = -1;
  List<LogEntry> _snapshot = const [];

  // FULL LOG 持久化缓冲，避免每条日志都立即刷盘。
  final StringBuffer _fullLogBuffer = StringBuffer();
  Timer? _fullLogFlushTimer;
  bool _fullLogFlushing = false;
  File? _fullLogFile;
  Future<File>? _fullLogFileFuture;
  bool _initialized = false;
  bool _hasPersistedEntry = false;

  /// 日志版本号，每次新增/清空时递增
  int get version => _version;

  List<LogEntry> get logs {
    if (_snapshotVersion != _version) {
      _snapshot = _logs.toList(growable: false);
      _snapshotVersion = _version;
    }
    return _snapshot;
  }

  /// 直接访问内部队列长度，避免创建新 List
  int get logCount => _logs.length;

  void _scheduleNotify() {
    if (_notifyTimer != null) {
      _pendingNotify = true;
      return;
    }

    // 始终延迟通知，避免在 build/layout 阶段触发重建导致递归
    _pendingNotify = false;
    _notifyTimer = Timer(const Duration(milliseconds: 100), () {
      _notifyTimer = null;
      notifyListeners();
      // 如果在通知期间又有新日志，继续调度
      if (_pendingNotify) {
        _pendingNotify = false;
        _scheduleNotify();
      }
    });
  }

  void setConsoleOutputEnabled(bool enabled) {
    _consoleOutputEnabled = enabled;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (_isFlutterTest) {
      _initialized = true;
      return;
    }

    final file = await _ensureFullLogFile();
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    _initialized = true;
  }

  Future<File> _createFullLogFile() async {
    if (_isFlutterTest) {
      final date = DateTime.now().toIso8601String().split('T')[0];
      return File('${Directory.systemTemp.path}/hanabi_runtime_full_$date.log');
    }

    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/HanabiDownloadManagerX/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final date = DateTime.now().toIso8601String().split('T')[0];
    return File('${logDir.path}/runtime_full_$date.log');
  }

  Future<File> _ensureFullLogFile() async {
    final existing = _fullLogFile;
    if (existing != null) {
      return existing;
    }

    final pending = _fullLogFileFuture;
    if (pending != null) {
      return pending;
    }

    final creation = _createFullLogFile();
    _fullLogFileFuture = creation;
    try {
      final file = await creation;
      _fullLogFile = file;
      return file;
    } finally {
      if (identical(_fullLogFileFuture, creation)) {
        _fullLogFileFuture = null;
      }
    }
  }

  void _scheduleFullLogFlush({bool immediate = false}) {
    if (immediate) {
      _fullLogFlushTimer?.cancel();
      _fullLogFlushTimer = null;
      unawaited(_flushFullLog());
      return;
    }

    if (_fullLogFlushTimer != null) {
      return;
    }

    _fullLogFlushTimer = Timer(const Duration(milliseconds: 150), () {
      _fullLogFlushTimer = null;
      unawaited(_flushFullLog());
    });
  }

  Future<void> _flushFullLog() async {
    if (_fullLogFlushing || _fullLogBuffer.isEmpty) {
      return;
    }

    _fullLogFlushing = true;
    final content = _fullLogBuffer.toString();
    _fullLogBuffer.clear();

    try {
      final file = await _ensureFullLogFile();
      await file.writeAsString(
        content,
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      final pending = _fullLogBuffer.toString();
      _fullLogBuffer
        ..clear()
        ..write(content)
        ..write(pending);
      Zone.root.print('FULL LOG write failed: $e');
    } finally {
      _fullLogFlushing = false;
      if (_fullLogBuffer.isNotEmpty) {
        _scheduleFullLogFlush();
      }
    }
  }

  Future<void> flushFullLog() async {
    _fullLogFlushTimer?.cancel();
    _fullLogFlushTimer = null;
    await _flushFullLog();
  }

  Future<void> _resetFullLogStorage() async {
    _fullLogBuffer.clear();
    _fullLogFlushTimer?.cancel();
    _fullLogFlushTimer = null;
    _hasPersistedEntry = false;

    while (_fullLogFlushing) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final file = await _ensureFullLogFile();
    await file.writeAsString('');
  }

  Future<File> getFullLogFile() async {
    await flushFullLog();
    return _ensureFullLogFile();
  }

  Future<List<String>> readFullLogLines() async {
    final file = await getFullLogFile();
    if (!await file.exists()) {
      return const [];
    }

    return file.readAsLines();
  }

  void ingest(
    LogEntry entry, {
    bool? toConsole,
    bool immediateFlush = false,
    bool persist = true,
  }) {
    _logs.addLast(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
    _version++;

    if (!_isFlutterTest && persist) {
      _fullLogBuffer.writeln(entry.format(fullTimestamp: true));
      final shouldFlushImmediately = immediateFlush || !_hasPersistedEntry;
      _hasPersistedEntry = true;
      _scheduleFullLogFlush(immediate: shouldFlushImmediately);
    }

    final emitToConsole = toConsole ?? _consoleOutputEnabled;
    if (emitToConsole) {
      // 避免被 Zone 的 print 拦截导致递归
      Zone.root.print(entry.format());
    }

    _scheduleNotify();
  }

  void log(
    LogLevel level,
    String source,
    String message, {
    bool? toConsole,
    bool immediateFlush = false,
  }) {
    ingest(
      LogEntry(
        timestamp: DateTime.now(),
        level: level,
        source: source,
        message: message,
      ),
      toConsole: toConsole,
      immediateFlush: immediateFlush,
    );
  }

  void debug(String source, String message, {bool? toConsole}) =>
      log(LogLevel.debug, source, message, toConsole: toConsole);
  void info(String source, String message, {bool? toConsole}) =>
      log(LogLevel.info, source, message, toConsole: toConsole);
  void warning(String source, String message, {bool? toConsole}) => log(
        LogLevel.warning,
        source,
        message,
        toConsole: toConsole,
        immediateFlush: true,
      );
  void error(String source, String message, {bool? toConsole}) => log(
        LogLevel.error,
        source,
        message,
        toConsole: toConsole,
        immediateFlush: true,
      );

  void clear() {
    _logs.clear();
    _version++;
    _snapshot = const [];
    _snapshotVersion = _version;
    unawaited(_resetFullLogStorage());
    notifyListeners();
  }

  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  List<LogEntry> getLogsBySource(String source) {
    return _logs.where((log) => log.source == source).toList();
  }
}
