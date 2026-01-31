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

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  String get levelString {
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
  
  // 节流：最多每 100ms 通知一次
  Timer? _notifyTimer;
  bool _pendingNotify = false;

  List<LogEntry> get logs => _logs.toList();

  void _scheduleNotify() {
    if (_notifyTimer != null) {
      _pendingNotify = true;
      return;
    }
    
    notifyListeners();
    
    _notifyTimer = Timer(const Duration(milliseconds: 100), () {
      _notifyTimer = null;
      if (_pendingNotify) {
        _pendingNotify = false;
        _scheduleNotify();
      }
    });
  }

  void log(LogLevel level, String source, String message) {
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

    if (kDebugMode) {
      print('[${entry.formattedTime}] [${entry.levelString}] [$source] $message');
    }

    _scheduleNotify();
  }

  void debug(String source, String message) => log(LogLevel.debug, source, message);
  void info(String source, String message) => log(LogLevel.info, source, message);
  void warning(String source, String message) => log(LogLevel.warning, source, message);
  void error(String source, String message) => log(LogLevel.error, source, message);

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  List<LogEntry> getLogsBySource(String source) {
    return _logs.where((log) => log.source == source).toList();
  }
}
