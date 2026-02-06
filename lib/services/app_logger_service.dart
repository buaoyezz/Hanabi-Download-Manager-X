import 'dart:collection';
import 'dart:async';
import 'package:flutter/foundation.dart';

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
}

class AppLoggerService extends ChangeNotifier {
  static final AppLoggerService _instance = AppLoggerService._internal();
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

  void log(LogLevel level, String source, String message, {bool? toConsole}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      source: source,
      message: message,
    );

    _logs.addLast(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
    _version++;

    final emitToConsole = toConsole ?? _consoleOutputEnabled;
    if (emitToConsole) {
      // 避免被 Zone 的 print 拦截导致递归
      Zone.root.print('[${entry.formattedTime}] [${entry.levelString}] [$source] $message');
    }

    _scheduleNotify();
  }

  void debug(String source, String message, {bool? toConsole}) =>
      log(LogLevel.debug, source, message, toConsole: toConsole);
  void info(String source, String message, {bool? toConsole}) =>
      log(LogLevel.info, source, message, toConsole: toConsole);
  void warning(String source, String message, {bool? toConsole}) =>
      log(LogLevel.warning, source, message, toConsole: toConsole);
  void error(String source, String message, {bool? toConsole}) =>
      log(LogLevel.error, source, message, toConsole: toConsole);

  void clear() {
    _logs.clear();
    _version++;
    _snapshot = const [];
    _snapshotVersion = _version;
    notifyListeners();
  }

  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  List<LogEntry> getLogsBySource(String source) {
    return _logs.where((log) => log.source == source).toList();
  }
}
