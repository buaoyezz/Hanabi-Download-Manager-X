import 'dart:async';
import 'package:flutter/foundation.dart';
import 'app_logger_service.dart';

class LogCapture {
  LogCapture._();

  static bool _installed = false;
  static bool _processing = false; // 防重入

  // 匹配格式: [tag] message
  static final RegExp _tagRegex = RegExp(r'^\[([^\]]+)\]\s*(.*)$');

  // 匹配 AppLoggerService 自身输出格式: [HH:MM:SS] [LEVEL] [source] message
  // 避免重复捕获已经格式化的日志
  static final RegExp _formattedLogRegex = RegExp(
    r'^\[\d{2}:\d{2}:\d{2}\]\s*\[(DEBUG|INFO|WARN|ERROR)\]\s*\[([^\]]+)\]\s*(.*)$',
  );

  // 匹配步骤格式: [1/4] message — 归类为 Kernel
  static final RegExp _stepRegex = RegExp(r'^\[(\d+/\d+)\]\s*(.*)$');

  // 匹配 Flutter 框架日志: I/flutter (PID): message 或 D/ClassName(PID): message
  static final RegExp _flutterNativeRegex = RegExp(
    r'^([DIWEF])/(\S+)\s*\(\s*\d+\s*\):\s*(.*)$',
  );

  // 错误/警告关键词检测
  static final RegExp _errorKeywords = RegExp(
    r'\b(error|exception|critical|fatal|crash|panic|失败|错误|异常)\b',
    caseSensitive: false,
  );
  static final RegExp _warningKeywords = RegExp(
    r'\b(warning|warn|timeout|retry|注意|警告|超时|重试)\b',
    caseSensitive: false,
  );

  // 分隔线检测（预编译）
  static final RegExp _separatorRegex = RegExp(r'^[=\-*~#]{3,}$');

  static void install(AppLoggerService logger) {
    if (_installed) return;
    _installed = true;

    debugPrint = (String? message, {int? wrapWidth}) {
      if (message == null || message.isEmpty) return;
      _logConsole(logger, message);
    };
  }

  static Future<void> runZoned(
      AppLoggerService logger, Future<void> Function() body) {
    return runZonedGuarded<Future<void>>(
          () => body(),
          (error, stack) {
            logger.error('Zone', '$error\n$stack');
          },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, line) {
              if (line.isEmpty) return;
              _logConsole(logger, line);
            },
          ),
        ) ??
        Future<void>.value();
  }

  static void _logConsole(AppLoggerService logger, String message) {
    // 防重入：如果正在处理日志，直接跳过
    if (_processing) return;
    _processing = true;
    try {
      _logConsoleInner(logger, message);
    } finally {
      _processing = false;
    }
  }

  static void _logConsoleInner(AppLoggerService logger, String message) {
    // 跳过纯分隔线（如 ========）
    if (_isSeparatorLine(message)) return;

    // 1. 检查是否是已格式化的日志（避免重复捕获）
    final formattedMatch = _formattedLogRegex.firstMatch(message);
    if (formattedMatch != null) {
      // 已经是 AppLoggerService 格式化的输出，跳过避免递归
      return;
    }

    // 2. Flutter native 日志: I/flutter (PID): message
    final nativeMatch = _flutterNativeRegex.firstMatch(message);
    if (nativeMatch != null) {
      final level = _parseNativeLevel(nativeMatch.group(1)!);
      final source = nativeMatch.group(2)!;
      final body = nativeMatch.group(3)?.trim() ?? message;
      logger.log(level, source, body, toConsole: false);
      return;
    }

    // 3. 步骤格式: [1/4] message — 归类为 Kernel
    final stepMatch = _stepRegex.firstMatch(message);
    if (stepMatch != null) {
      final step = stepMatch.group(1)!;
      final body = stepMatch.group(2)?.trim() ?? message;
      logger.info('Kernel', '[$step] $body', toConsole: false);
      return;
    }

    // 4. 通用 [tag] message 格式
    final tagMatch = _tagRegex.firstMatch(message);
    if (tagMatch != null) {
      final tag = tagMatch.group(1)!.trim();
      final body = (tagMatch.group(2) ?? '').trim();
      final finalMessage = body.isEmpty ? message : body;
      final level = _inferLevel(finalMessage);
      logger.log(level, tag, finalMessage, toConsole: false);
      return;
    }

    // 5. 无格式消息 — 通过关键词推断级别
    final level = _inferLevel(message);
    logger.log(level, 'Console', message.trim(), toConsole: false);
  }

  /// 判断是否为纯分隔线（全是 =、-、* 等）
  static bool _isSeparatorLine(String message) {
    final trimmed = message.trim();
    if (trimmed.length < 3) return false;
    return _separatorRegex.hasMatch(trimmed);
  }

  /// 解析 Flutter native 日志级别 (D/I/W/E/F)
  static LogLevel _parseNativeLevel(String tag) {
    switch (tag) {
      case 'D':
        return LogLevel.debug;
      case 'I':
        return LogLevel.info;
      case 'W':
        return LogLevel.warning;
      case 'E':
      case 'F':
        return LogLevel.error;
      default:
        return LogLevel.debug;
    }
  }

  /// 通过关键词推断日志级别
  static LogLevel _inferLevel(String message) {
    if (_errorKeywords.hasMatch(message)) return LogLevel.error;
    if (_warningKeywords.hasMatch(message)) return LogLevel.warning;
    return LogLevel.debug;
  }
}
