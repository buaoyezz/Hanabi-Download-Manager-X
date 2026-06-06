import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'app_logger_service.dart';

class NativeRenderLogService {
  static final NativeRenderLogService _instance =
      NativeRenderLogService._internal();
  factory NativeRenderLogService() => _instance;
  NativeRenderLogService._internal();

  static final RegExp _structuredLineRegex = RegExp(
    r'^\[([^\]]+)\]\s*\[(DEBUG|INFO|WARN(?:ING)?|ERROR)\]\s*\[([^\]]+)\]\s*(.*)$',
  );
  static final List<RegExp> _noisyRenderPatterns = [
    RegExp(
        r'^Win32Window WM_(?:NCPAINT|MOUSEACTIVATE|SIZE|ACTIVATE|SETFOCUS)\b'),
    RegExp(r'^Win32Window WM_NCACTIVATE\b'),
    RegExp(r'^NextFrameCallback (?:begin|end)$'),
    RegExp(r'^ForceRedraw called$'),
    RegExp(r'^DwmExtendFrameIntoClientArea hr=0x00000000$'),
    RegExp(r'^ApplyWindowEffect: .*changed=0\b'),
  ];
  static const Duration _noisyRenderDedupWindow = Duration(milliseconds: 1500);

  final AppLoggerService _appLogger = AppLoggerService();
  static const MethodChannel _windowChannel =
      MethodChannel('com.hanabi.download/window');
  final Map<String, DateTime> _recentNoisyRenderEntries = {};

  Timer? _pollTimer;
  File? _rawLogFile;
  int _offset = 0;
  String _pendingLine = '';
  bool _started = false;
  bool _polling = false;
  bool _nativeLoggingEnabled = false;

  Future<void> start() async {
    if (_started || !Platform.isWindows) {
      if (Platform.isWindows && !_nativeLoggingEnabled) {
        await _setNativeRenderLoggingEnabled(true);
      }
      return;
    }

    _started = true;
    await _setNativeRenderLoggingEnabled(true);
    _rawLogFile = await getRawLogFile();
    if (await _rawLogFile!.exists()) {
      _offset = await _rawLogFile!.length();
    }
    await _poll();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => unawaited(_poll()),
    );
  }

  Future<void> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _started = false;
    _recentNoisyRenderEntries.clear();
    await _setNativeRenderLoggingEnabled(false);
  }

  Future<void> _setNativeRenderLoggingEnabled(bool enabled) async {
    if (!Platform.isWindows || _nativeLoggingEnabled == enabled) {
      return;
    }

    try {
      await _windowChannel.invokeMethod<bool>(
        'setNativeRenderLoggingEnabled',
        {'enabled': enabled},
      );
      _nativeLoggingEnabled = enabled;
    } catch (e) {
      _appLogger.debug(
        'Render',
        'Native render logging toggle unavailable: $e',
        toConsole: false,
      );
    }
  }

  Future<File> getRawLogFile() async {
    final executable = File(Platform.resolvedExecutable);
    return File(
      '${executable.parent.path}${Platform.pathSeparator}window_render.log',
    );
  }

  Future<void> _poll() async {
    if (_polling) {
      return;
    }
    _polling = true;

    try {
      final file = _rawLogFile ?? await getRawLogFile();
      _rawLogFile = file;

      if (!await file.exists()) {
        return;
      }

      final length = await file.length();
      if (length < _offset) {
        _offset = 0;
        _pendingLine = '';
      }
      if (length == _offset) {
        return;
      }

      final raf = await file.open();
      try {
        await raf.setPosition(_offset);
        final bytes = await raf.read(length - _offset);
        _offset = length;
        _consumeChunk(utf8.decode(bytes, allowMalformed: true));
      } finally {
        await raf.close();
      }
    } finally {
      _polling = false;
    }
  }

  void _consumeChunk(String chunk) {
    final normalized =
        ('$_pendingLine$chunk').replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final segments = normalized.split('\n');
    _pendingLine = normalized.endsWith('\n') ? '' : segments.removeLast();

    for (final rawLine in segments) {
      _ingestLine(rawLine.trimRight());
    }
  }

  void _ingestLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final match = _structuredLineRegex.firstMatch(trimmed);
    late final LogEntry entry;
    if (match == null) {
      entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        source: 'Render',
        message: trimmed,
      );
    } else {
      entry = LogEntry(
        timestamp: DateTime.tryParse(match.group(1)!) ?? DateTime.now(),
        level: _parseLevel(match.group(2)!),
        source: match.group(3)?.trim().isNotEmpty == true
            ? match.group(3)!.trim()
            : 'Render',
        message: match.group(4)?.trim() ?? '',
      );
    }

    if (_shouldSuppressNoisyEntry(entry)) {
      return;
    }

    _appLogger.ingest(
      entry,
      toConsole: false,
    );
  }

  bool _shouldSuppressNoisyEntry(LogEntry entry) {
    if (entry.source != 'Render') {
      return false;
    }

    final isNoisy = _noisyRenderPatterns.any(
      (pattern) => pattern.hasMatch(entry.message),
    );
    if (!isNoisy) {
      return false;
    }

    final now = entry.timestamp;
    _recentNoisyRenderEntries.removeWhere(
      (_, seenAt) => now.difference(seenAt) > const Duration(seconds: 10),
    );

    final key = '${entry.level.name}|${entry.source}|${entry.message}';
    final lastSeenAt = _recentNoisyRenderEntries[key];
    if (lastSeenAt != null &&
        now.difference(lastSeenAt) <= _noisyRenderDedupWindow) {
      return true;
    }

    _recentNoisyRenderEntries[key] = now;
    return false;
  }

  LogLevel _parseLevel(String text) {
    switch (text.toUpperCase()) {
      case 'DEBUG':
        return LogLevel.debug;
      case 'WARNING':
      case 'WARN':
        return LogLevel.warning;
      case 'ERROR':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}
