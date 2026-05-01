import 'dart:convert';
import 'dart:io';

class PluginDiagnosticLogger {
  static final PluginDiagnosticLogger _instance =
      PluginDiagnosticLogger._internal();

  factory PluginDiagnosticLogger() => _instance;

  PluginDiagnosticLogger._internal();

  static const int _maxStringLength = 600;

  File? _logFile;
  File? _lastEventFile;

  void mark(
    String event, {
    String? pluginId,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    final now = DateTime.now();
    final payload = <String, Object?>{
      'time': now.toIso8601String(),
      'pid': pid,
      'event': event,
      if (pluginId != null) 'pluginId': pluginId,
      if (data.isNotEmpty) 'data': _sanitize(data),
    };

    final line = _formatLine(payload);
    try {
      final logFile = _ensureLogFile();
      logFile.writeAsStringSync(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
      _ensureLastEventFile().writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(payload),
        flush: true,
      );
    } catch (_) {
      // Diagnostics must never crash the app.
    }
  }

  void error(
    String event,
    Object error, {
    String? pluginId,
    StackTrace? stackTrace,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    mark(
      event,
      pluginId: pluginId,
      data: <String, Object?>{
        ...data,
        'error': error.toString(),
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
      },
    );
  }

  File _ensureLogFile() {
    final existing = _logFile;
    if (existing != null) {
      return existing;
    }
    final file = File('${_ensureLogDirectory().path}\\plugin_diagnostics.log');
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    _logFile = file;
    return file;
  }

  File _ensureLastEventFile() {
    final existing = _lastEventFile;
    if (existing != null) {
      return existing;
    }
    final file = File('${_ensureLogDirectory().path}\\plugin_last_event.json');
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }
    _lastEventFile = file;
    return file;
  }

  Directory _ensureLogDirectory() {
    final userProfile = Platform.environment['USERPROFILE'];
    final basePath = userProfile == null || userProfile.trim().isEmpty
        ? Directory.systemTemp.path
        : '$userProfile\\Documents';
    final directory = Directory('$basePath\\HanabiDownloadManagerX\\logs');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  String _formatLine(Map<String, Object?> payload) {
    final data = payload['data'];
    final buffer = StringBuffer()
      ..write('[')
      ..write(payload['time'])
      ..write('] [pid=')
      ..write(payload['pid'])
      ..write('] ')
      ..write(payload['event']);
    final pluginId = payload['pluginId'];
    if (pluginId != null) {
      buffer
        ..write(' plugin=')
        ..write(pluginId);
    }
    if (data != null) {
      buffer
        ..write(' data=')
        ..write(jsonEncode(data));
    }
    return buffer.toString();
  }

  Object? _sanitize(Object? value) {
    if (value == null || value is num || value is bool || value is DateTime) {
      return value is DateTime ? value.toIso8601String() : value;
    }
    if (value is FileSystemEntity) {
      return value.path;
    }
    if (value is String) {
      if (value.length <= _maxStringLength) {
        return value;
      }
      return '${value.substring(0, _maxStringLength)}...';
    }
    if (value is Iterable) {
      return value.map(_sanitize).toList(growable: false);
    }
    if (value is Map) {
      return value.map<String, Object?>(
        (key, mapValue) => MapEntry(key.toString(), _sanitize(mapValue)),
      );
    }
    return value.toString();
  }
}
