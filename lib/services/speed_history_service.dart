import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 速度历史记录服务 — 为每个下载任务维护速度曲线数据，支持持久化
class SpeedHistoryService {
  static final SpeedHistoryService _instance = SpeedHistoryService._internal();
  factory SpeedHistoryService() => _instance;
  SpeedHistoryService._internal();

  /// 每个任务最多保留 60 个数据点（60秒 = 1分钟的曲线）
  static const int maxDataPoints = 60;

  /// taskId -> 速度历史（bytes/s）
  final Map<String, Queue<double>> _histories = {};

  /// 持久化文件路径缓存
  String? _filePath;

  /// 是否已加载
  bool _loaded = false;
  bool _persistenceEnabled = true;

  void setPersistenceEnabled(bool enabled) {
    _persistenceEnabled = enabled;
  }

  /// 获取持久化文件路径
  Future<String> _getFilePath() async {
    if (_filePath != null) return _filePath!;
    final dir = await getApplicationSupportDirectory();
    _filePath = '${dir.path}${Platform.pathSeparator}speed_history.json';
    return _filePath!;
  }

  /// 从磁盘加载历史数据（启动时调用一次）
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (!await file.exists()) return;
      final json = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(json);
      for (final entry in data.entries) {
        final list = (entry.value as List).cast<num>().map((e) => e.toDouble());
        final queue = Queue<double>.from(list);
        // 只保留最近 maxDataPoints 个
        while (queue.length > maxDataPoints) {
          queue.removeFirst();
        }
        _histories[entry.key] = queue;
      }
    } catch (e) {
      debugPrint('SpeedHistoryService.load error: $e');
    }
  }

  /// 保存到磁盘（节流：不会每次 record 都写）
  int _saveCounter = 0;
  Future<void> _saveToDisk() async {
    if (!_persistenceEnabled) return;
    // 每 10 次 record 保存一次，减少 IO
    _saveCounter++;
    if (_saveCounter < 10) return;
    _saveCounter = 0;
    await forceSave();
  }

  /// 强制保存到磁盘
  Future<void> forceSave() async {
    if (!_persistenceEnabled) return;
    try {
      final path = await _getFilePath();
      final Map<String, List<double>> data = {};
      for (final entry in _histories.entries) {
        data[entry.key] = entry.value.toList();
      }
      await File(path).writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('SpeedHistoryService.save error: $e');
    }
  }

  /// 记录一个速度采样点
  void record(String taskId, double speed) {
    final queue = _histories.putIfAbsent(taskId, () => Queue<double>());
    queue.addLast(speed);
    while (queue.length > maxDataPoints) {
      queue.removeFirst();
    }
    _saveToDisk();
  }

  /// 获取某个任务的速度历史
  List<double> getHistory(String taskId) {
    return _histories[taskId]?.toList() ?? [];
  }

  /// 清除某个任务的历史
  void clear(String taskId) {
    _histories.remove(taskId);
    _saveToDisk();
  }

  /// 清除所有历史
  void clearAll() {
    _histories.clear();
    _saveToDisk();
  }

  /// 获取某个任务的峰值速度（从历史数据中）
  double getPeakSpeed(String taskId) {
    final history = _histories[taskId];
    if (history == null || history.isEmpty) return 0;
    return history.reduce((a, b) => a > b ? a : b);
  }
}
