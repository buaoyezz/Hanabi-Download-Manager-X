import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/download_intent.dart';
import '../models/download_task.dart';
import 'app_logger_service.dart';
import 'plugin_lifecycle_service.dart';
import 'plugin_process_runner.dart';

class PluginTaskRecord {
  const PluginTaskRecord({
    required this.id,
    required this.pluginId,
    required this.url,
    required this.fileName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.saveDir,
    this.filePath,
    this.error,
    this.totalSize,
    this.downloadedSize,
    this.speed,
    this.progress = 0,
    this.pluginData = const <String, dynamic>{},
  });

  final String id;
  final String pluginId;
  final String url;
  final String fileName;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? saveDir;
  final String? filePath;
  final String? error;
  final int? totalSize;
  final int? downloadedSize;
  final double? speed;
  final double progress;
  final Map<String, dynamic> pluginData;

  factory PluginTaskRecord.fromJson(Map<String, dynamic> json) {
    final pluginDataRaw = json['pluginData'];
    return PluginTaskRecord(
      id: json['id']?.toString() ?? '',
      pluginId: json['pluginId']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      saveDir: json['saveDir']?.toString(),
      filePath: json['filePath']?.toString(),
      error: json['error']?.toString(),
      totalSize: (json['totalSize'] as num?)?.toInt(),
      downloadedSize: (json['downloadedSize'] as num?)?.toInt(),
      speed: (json['speed'] as num?)?.toDouble(),
      progress: _normalizeProgress(json['progress']),
      pluginData: pluginDataRaw is Map
          ? pluginDataRaw.map((key, value) => MapEntry(key.toString(), value))
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pluginId': pluginId,
        'url': url,
        'fileName': fileName,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (saveDir != null && saveDir!.isNotEmpty) 'saveDir': saveDir,
        if (filePath != null && filePath!.isNotEmpty) 'filePath': filePath,
        if (error != null && error!.isNotEmpty) 'error': error,
        if (totalSize != null) 'totalSize': totalSize,
        if (downloadedSize != null) 'downloadedSize': downloadedSize,
        if (speed != null) 'speed': speed,
        'progress': progress,
        if (pluginData.isNotEmpty) 'pluginData': pluginData,
      };

  Map<String, dynamic> toPluginJson() => {
        'taskId': id,
        'pluginId': pluginId,
        'url': url,
        'fileName': fileName,
        if (saveDir != null && saveDir!.isNotEmpty) 'saveDir': saveDir,
        if (filePath != null && filePath!.isNotEmpty) 'filePath': filePath,
        'pluginData': pluginData,
      };

  PluginTaskRecord mergePluginResult(Map<String, dynamic> result) {
    final pluginDataRaw = result['pluginData'] ?? result['plugin_data'];
    final nextPluginData = <String, dynamic>{...pluginData};
    if (pluginDataRaw is Map) {
      nextPluginData.addAll(
        pluginDataRaw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    final nextTotalSize = _firstInt(result, ['totalSize', 'total_size']);
    final nextDownloadedSize =
        _firstInt(result, ['downloadedSize', 'downloaded_size']);
    return copyWith(
      status: result['status']?.toString(),
      filePath:
          result['filePath']?.toString() ?? result['file_path']?.toString(),
      error: result['error']?.toString(),
      totalSize: nextTotalSize,
      downloadedSize: nextDownloadedSize,
      speed: _firstDouble(result, ['speed', 'downloadSpeed', 'download_speed']),
      progress: result.containsKey('progress')
          ? _normalizeProgress(result['progress'])
          : _progressFromSizes(nextDownloadedSize, nextTotalSize) ?? progress,
      pluginData: nextPluginData,
      updatedAt: DateTime.now(),
    );
  }

  PluginTaskRecord copyWith({
    String? status,
    DateTime? updatedAt,
    String? saveDir,
    String? filePath,
    String? error,
    int? totalSize,
    int? downloadedSize,
    double? speed,
    double? progress,
    Map<String, dynamic>? pluginData,
  }) {
    return PluginTaskRecord(
      id: id,
      pluginId: pluginId,
      url: url,
      fileName: fileName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      saveDir: saveDir ?? this.saveDir,
      filePath: filePath ?? this.filePath,
      error: error ?? this.error,
      totalSize: totalSize ?? this.totalSize,
      downloadedSize: downloadedSize ?? this.downloadedSize,
      speed: speed ?? this.speed,
      progress: progress ?? this.progress,
      pluginData: Map.unmodifiable(pluginData ?? this.pluginData),
    );
  }

  DownloadTask toDownloadTask() {
    return DownloadTask(
      id: id,
      url: url,
      fileName: fileName,
      status: _downloadStatus(status),
      progress: progress.clamp(0.0, 1.0),
      filePath: filePath ?? saveDir,
      error: error,
      fileSize: totalSize,
      downloadedSize: downloadedSize,
      speed: speed,
      downloadCore: 'Plugin: $pluginId',
      createdAt: createdAt,
    );
  }

  bool get isActive {
    final normalized = status.toLowerCase();
    return normalized != 'completed' &&
        normalized != 'complete' &&
        normalized != 'failed' &&
        normalized != 'error' &&
        normalized != 'removed';
  }

  static DownloadStatus _downloadStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'downloading':
      case 'seeding':
        return DownloadStatus.downloading;
      case 'paused':
      case 'stopped':
        return DownloadStatus.paused;
      case 'complete':
      case 'completed':
        return DownloadStatus.completed;
      case 'checking':
      case 'verifying':
      case 'merging':
        return DownloadStatus.merging;
      case 'failed':
      case 'error':
      case 'removed':
        return DownloadStatus.failed;
      case 'waiting':
      case 'pending':
      default:
        return DownloadStatus.pending;
    }
  }

  static double _normalizeProgress(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null || number.isNaN || number.isInfinite) {
      return 0;
    }
    if (number > 1) {
      return (number / 100).clamp(0.0, 1.0);
    }
    return number.clamp(0.0, 1.0);
  }

  static int? _firstInt(Map<String, dynamic> result, List<String> keys) {
    for (final key in keys) {
      final value = result[key];
      if (value is num) {
        return value.toInt();
      }
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static double? _firstDouble(Map<String, dynamic> result, List<String> keys) {
    for (final key in keys) {
      final value = result[key];
      if (value is num) {
        return value.toDouble();
      }
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static double? _progressFromSizes(int? downloaded, int? total) {
    if (downloaded == null || total == null || total <= 0) {
      return null;
    }
    return (downloaded / total).clamp(0.0, 1.0);
  }
}

class PluginTaskService extends ChangeNotifier {
  static final PluginTaskService _instance = PluginTaskService._internal();

  factory PluginTaskService() => _instance;

  PluginTaskService._internal();

  final PluginLifecycleService _pluginService = PluginLifecycleService();
  final PluginProcessRunner _runner = PluginProcessRunner();
  final AppLoggerService _logger = AppLoggerService();
  final Map<String, PluginTaskRecord> _records = <String, PluginTaskRecord>{};

  late String _tasksPath;
  bool _initialized = false;

  List<PluginTaskRecord> get records => List.unmodifiable(_records.values);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await _pluginService.ensureInitialized();
    _tasksPath = path.join(_pluginService.pluginsRootDir, 'plugin_tasks.json');
    await _load();
    _initialized = true;
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  bool hasTask(String id) => _records.containsKey(id);

  Future<PluginTaskRecord> registerTask({
    required String pluginId,
    required String taskId,
    required DownloadIntent intent,
    required String fileName,
    String? saveDir,
    Map<String, dynamic> pluginResult = const <String, dynamic>{},
  }) async {
    await ensureInitialized();
    final now = DateTime.now();
    final initial = PluginTaskRecord(
      id: taskId,
      pluginId: pluginId,
      url: intent.normalizedValue,
      fileName: fileName,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      saveDir: saveDir,
    ).mergePluginResult(pluginResult);
    _records[taskId] = initial;
    await _save();
    notifyListeners();
    return initial;
  }

  Future<List<PluginTaskRecord>> refreshActiveTasks() async {
    await ensureInitialized();
    var changed = false;
    for (final record in _records.values.toList(growable: false)) {
      if (!record.isActive) {
        continue;
      }
      final plugin = _pluginService.getPlugin(record.pluginId);
      if (plugin == null || !plugin.enabled) {
        _records[record.id] = record.copyWith(
          status: 'failed',
          error: 'Plugin ${record.pluginId} is not enabled',
          updatedAt: DateTime.now(),
        );
        changed = true;
        continue;
      }

      final result = await _runner.invoke(
        plugin,
        method: 'hanabi.download.status',
        params: record.toPluginJson(),
        timeout: const Duration(seconds: 10),
      );
      if (!result.success) {
        _logger.warning(
          'PluginTask',
          'Plugin task status failed: ${record.id}: ${result.error}',
        );
        continue;
      }
      if (result.result is Map) {
        _records[record.id] = record.mergePluginResult(
          (result.result as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
        changed = true;
      }
    }
    if (changed) {
      await _save();
      notifyListeners();
    }
    return records;
  }

  Future<bool> pauseTask(String id) => _callTaskMethod(id, 'pause');

  Future<bool> resumeTask(String id) => _callTaskMethod(id, 'resume');

  Future<bool> removeTask(String id) async {
    final called = await _callTaskMethod(id, 'remove', keepRecord: false);
    _records.remove(id);
    await _save();
    notifyListeners();
    return called;
  }

  Future<bool> _callTaskMethod(
    String id,
    String action, {
    bool keepRecord = true,
  }) async {
    await ensureInitialized();
    final record = _records[id];
    if (record == null) {
      return false;
    }
    final plugin = _pluginService.getPlugin(record.pluginId);
    if (plugin == null || !plugin.enabled) {
      return false;
    }

    final result = await _runner.invoke(
      plugin,
      method: 'hanabi.download.$action',
      params: record.toPluginJson(),
      timeout: const Duration(seconds: 15),
    );
    if (!result.success) {
      _logger.warning(
        'PluginTask',
        'Plugin task $action failed: $id: ${result.error}',
      );
      return false;
    }
    if (keepRecord && result.result is Map) {
      _records[id] = record.mergePluginResult(
        (result.result as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
      await _save();
      notifyListeners();
    }
    return true;
  }

  Future<void> _load() async {
    _records.clear();
    final file = File(_tasksPath);
    if (!await file.exists()) {
      return;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      final tasks = decoded is Map ? decoded['tasks'] : null;
      if (tasks is List) {
        for (final task in tasks.whereType<Map>()) {
          final record = PluginTaskRecord.fromJson(
            task.map((key, value) => MapEntry(key.toString(), value)),
          );
          if (record.id.isNotEmpty) {
            _records[record.id] = record;
          }
        }
      }
    } catch (e) {
      _logger.warning('PluginTask', 'Failed to load plugin tasks: $e');
    }
  }

  Future<void> _save() async {
    final file = File(_tasksPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'updatedAt': DateTime.now().toIso8601String(),
        'tasks': _records.values.map((record) => record.toJson()).toList(),
      }),
    );
  }
}
