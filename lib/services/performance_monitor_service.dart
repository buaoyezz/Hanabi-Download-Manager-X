import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 帧数据
class FrameData {
  final DateTime timestamp;
  final Duration buildTime;
  final Duration rasterTime;
  final Duration totalTime;
  final bool isJank; // 是否卡顿帧 (>16.67ms)

  FrameData({
    required this.timestamp,
    required this.buildTime,
    required this.rasterTime,
    required this.totalTime,
    required this.isJank,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'buildTime_ms': buildTime.inMicroseconds / 1000,
    'rasterTime_ms': rasterTime.inMicroseconds / 1000,
    'totalTime_ms': totalTime.inMicroseconds / 1000,
    'isJank': isJank,
  };

  @override
  String toString() {
    return '[${timestamp.toString().substring(11, 23)}] '
        'Build: ${(buildTime.inMicroseconds / 1000).toStringAsFixed(2)}ms, '
        'Raster: ${(rasterTime.inMicroseconds / 1000).toStringAsFixed(2)}ms, '
        'Total: ${(totalTime.inMicroseconds / 1000).toStringAsFixed(2)}ms'
        '${isJank ? " [JANK]" : ""}';
  }
}

/// 重建统计数据
class RebuildData {
  final String widgetName;
  int count;
  DateTime lastRebuild;

  RebuildData({
    required this.widgetName,
    this.count = 1,
    DateTime? lastRebuild,
  }) : lastRebuild = lastRebuild ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'widgetName': widgetName,
    'count': count,
    'lastRebuild': lastRebuild.toIso8601String(),
  };
}

/// 性能统计摘要
class PerformanceStats {
  final int totalFrames;
  final int jankFrames;
  final double avgBuildTime;
  final double avgRasterTime;
  final double avgTotalTime;
  final double maxBuildTime;
  final double maxRasterTime;
  final double maxTotalTime;
  final double fps;
  final double jankRate;
  final int totalRebuilds;
  final int trackedWidgets;

  PerformanceStats({
    required this.totalFrames,
    required this.jankFrames,
    required this.avgBuildTime,
    required this.avgRasterTime,
    required this.avgTotalTime,
    required this.maxBuildTime,
    required this.maxRasterTime,
    required this.maxTotalTime,
    required this.fps,
    required this.jankRate,
    this.totalRebuilds = 0,
    this.trackedWidgets = 0,
  });

  Map<String, dynamic> toJson() => {
    'totalFrames': totalFrames,
    'jankFrames': jankFrames,
    'avgBuildTime_ms': avgBuildTime,
    'avgRasterTime_ms': avgRasterTime,
    'avgTotalTime_ms': avgTotalTime,
    'maxBuildTime_ms': maxBuildTime,
    'maxRasterTime_ms': maxRasterTime,
    'maxTotalTime_ms': maxTotalTime,
    'fps': fps,
    'jankRate_percent': jankRate,
    'totalRebuilds': totalRebuilds,
    'trackedWidgets': trackedWidgets,
  };
}

/// 性能监控服务
class PerformanceMonitorService extends ChangeNotifier {
  static final PerformanceMonitorService _instance = PerformanceMonitorService._internal();
  factory PerformanceMonitorService() => _instance;
  PerformanceMonitorService._internal();

  // 配置
  static const int maxFrameHistory = 300; // 保留最近300帧数据
  static const double jankThresholdMs = 16.67; // 60fps 阈值

  // 状态
  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  // 帧数据历史
  final Queue<FrameData> _frameHistory = Queue<FrameData>();
  List<FrameData> get frameHistory => _frameHistory.toList();

  // 重建次数追踪
  final Map<String, RebuildData> _rebuildTracker = {};
  Map<String, RebuildData> get rebuildTracker => Map.unmodifiable(_rebuildTracker);
  int _totalRebuilds = 0;
  int get totalRebuilds => _totalRebuilds;

  // 实时数据
  double _currentFps = 0;
  double _currentBuildTime = 0;
  double _currentRasterTime = 0;
  double _currentTotalTime = 0;
  bool _currentIsJank = false;

  double get currentFps => _currentFps;
  double get currentBuildTime => _currentBuildTime;
  double get currentRasterTime => _currentRasterTime;
  double get currentTotalTime => _currentTotalTime;
  bool get currentIsJank => _currentIsJank;

  // FPS 计算
  int _frameCount = 0;
  DateTime? _lastFpsUpdate;
  Timer? _fpsTimer;

  /// 开始监控
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    // 清空历史数据
    _frameHistory.clear();
    _frameCount = 0;
    _lastFpsUpdate = DateTime.now();

    // 注册帧回调
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

    // 启动 FPS 更新定时器
    _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateFps();
    });

    debugPrint('[PerformanceMonitor] Started monitoring');
    notifyListeners();
  }

  /// 停止监控
  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;

    // 移除帧回调
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);

    // 停止定时器
    _fpsTimer?.cancel();
    _fpsTimer = null;

    debugPrint('[PerformanceMonitor] Stopped monitoring');
    notifyListeners();
  }

  /// 帧时序回调
  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final buildTime = Duration(
        microseconds: timing.buildDuration.inMicroseconds,
      );
      final rasterTime = Duration(
        microseconds: timing.rasterDuration.inMicroseconds,
      );
      final totalTime = Duration(
        microseconds: timing.totalSpan.inMicroseconds,
      );

      final isJank = totalTime.inMicroseconds > (jankThresholdMs * 1000);

      final frameData = FrameData(
        timestamp: DateTime.now(),
        buildTime: buildTime,
        rasterTime: rasterTime,
        totalTime: totalTime,
        isJank: isJank,
      );

      // 添加到历史
      _frameHistory.addLast(frameData);
      while (_frameHistory.length > maxFrameHistory) {
        _frameHistory.removeFirst();
      }

      // 更新实时数据
      _currentBuildTime = buildTime.inMicroseconds / 1000;
      _currentRasterTime = rasterTime.inMicroseconds / 1000;
      _currentTotalTime = totalTime.inMicroseconds / 1000;
      _currentIsJank = isJank;
      _frameCount++;
    }

    notifyListeners();
  }

  /// 更新 FPS
  void _updateFps() {
    final now = DateTime.now();
    if (_lastFpsUpdate != null) {
      final elapsed = now.difference(_lastFpsUpdate!).inMilliseconds / 1000;
      if (elapsed > 0) {
        _currentFps = _frameCount / elapsed;
      }
    }
    _frameCount = 0;
    _lastFpsUpdate = now;
    notifyListeners();
  }

  /// 追踪 Widget 重建
  void trackRebuild(String widgetName) {
    if (!_isMonitoring) return;

    _totalRebuilds++;
    if (_rebuildTracker.containsKey(widgetName)) {
      _rebuildTracker[widgetName]!.count++;
      _rebuildTracker[widgetName]!.lastRebuild = DateTime.now();
    } else {
      _rebuildTracker[widgetName] = RebuildData(widgetName: widgetName);
    }
  }

  /// 获取重建次数最多的 Widget 列表
  List<RebuildData> getTopRebuilds({int limit = 10}) {
    final sorted = _rebuildTracker.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return sorted.take(limit).toList();
  }

  /// 获取性能统计
  PerformanceStats getStats() {
    if (_frameHistory.isEmpty) {
      return PerformanceStats(
        totalFrames: 0,
        jankFrames: 0,
        avgBuildTime: 0,
        avgRasterTime: 0,
        avgTotalTime: 0,
        maxBuildTime: 0,
        maxRasterTime: 0,
        maxTotalTime: 0,
        fps: 0,
        jankRate: 0,
        totalRebuilds: _totalRebuilds,
        trackedWidgets: _rebuildTracker.length,
      );
    }

    final frames = _frameHistory.toList();
    final totalFrames = frames.length;
    final jankFrames = frames.where((f) => f.isJank).length;

    double sumBuild = 0, sumRaster = 0, sumTotal = 0;
    double maxBuild = 0, maxRaster = 0, maxTotal = 0;

    for (final frame in frames) {
      final buildMs = frame.buildTime.inMicroseconds / 1000;
      final rasterMs = frame.rasterTime.inMicroseconds / 1000;
      final totalMs = frame.totalTime.inMicroseconds / 1000;

      sumBuild += buildMs;
      sumRaster += rasterMs;
      sumTotal += totalMs;

      if (buildMs > maxBuild) maxBuild = buildMs;
      if (rasterMs > maxRaster) maxRaster = rasterMs;
      if (totalMs > maxTotal) maxTotal = totalMs;
    }

    return PerformanceStats(
      totalFrames: totalFrames,
      jankFrames: jankFrames,
      avgBuildTime: sumBuild / totalFrames,
      avgRasterTime: sumRaster / totalFrames,
      avgTotalTime: sumTotal / totalFrames,
      maxBuildTime: maxBuild,
      maxRasterTime: maxRaster,
      maxTotalTime: maxTotal,
      fps: _currentFps,
      jankRate: (jankFrames / totalFrames) * 100,
      totalRebuilds: _totalRebuilds,
      trackedWidgets: _rebuildTracker.length,
    );
  }

  /// 导出日志
  String exportLog() {
    final buffer = StringBuffer();
    final stats = getStats();
    final now = DateTime.now();

    buffer.writeln('=' * 60);
    buffer.writeln('Hanabi Download Manager - Performance Report');
    buffer.writeln('Generated: ${now.toIso8601String()}');
    buffer.writeln('=' * 60);
    buffer.writeln();

    // 统计摘要
    buffer.writeln('## Summary');
    buffer.writeln('-' * 40);
    buffer.writeln('Total Frames: ${stats.totalFrames}');
    buffer.writeln('Jank Frames: ${stats.jankFrames}');
    buffer.writeln('Jank Rate: ${stats.jankRate.toStringAsFixed(2)}%');
    buffer.writeln('Current FPS: ${stats.fps.toStringAsFixed(1)}');
    buffer.writeln();
    buffer.writeln('Average Build Time: ${stats.avgBuildTime.toStringAsFixed(2)} ms');
    buffer.writeln('Average Raster Time: ${stats.avgRasterTime.toStringAsFixed(2)} ms');
    buffer.writeln('Average Total Time: ${stats.avgTotalTime.toStringAsFixed(2)} ms');
    buffer.writeln();
    buffer.writeln('Max Build Time: ${stats.maxBuildTime.toStringAsFixed(2)} ms');
    buffer.writeln('Max Raster Time: ${stats.maxRasterTime.toStringAsFixed(2)} ms');
    buffer.writeln('Max Total Time: ${stats.maxTotalTime.toStringAsFixed(2)} ms');
    buffer.writeln();

    // 重建次数统计
    buffer.writeln('## Widget Rebuilds');
    buffer.writeln('-' * 40);
    buffer.writeln('Total Rebuilds: ${stats.totalRebuilds}');
    buffer.writeln('Tracked Widgets: ${stats.trackedWidgets}');
    buffer.writeln();

    final topRebuilds = getTopRebuilds(limit: 20);
    if (topRebuilds.isNotEmpty) {
      buffer.writeln('Top Rebuilding Widgets:');
      for (var i = 0; i < topRebuilds.length; i++) {
        final rebuild = topRebuilds[i];
        buffer.writeln('  ${i + 1}. ${rebuild.widgetName}: ${rebuild.count} rebuilds');
      }
      buffer.writeln();
    }

    // 帧数据详情
    buffer.writeln('## Frame Details (Last ${_frameHistory.length} frames)');
    buffer.writeln('-' * 40);
    for (final frame in _frameHistory) {
      buffer.writeln(frame.toString());
    }
    buffer.writeln();

    // JSON 格式数据
    buffer.writeln('## JSON Data');
    buffer.writeln('-' * 40);
    buffer.writeln('{');
    buffer.writeln('  "stats": ${_jsonEncode(stats.toJson())},');
    buffer.writeln('  "topRebuilds": [');
    for (var i = 0; i < topRebuilds.length; i++) {
      final comma = i < topRebuilds.length - 1 ? ',' : '';
      buffer.writeln('    ${_jsonEncode(topRebuilds[i].toJson())}$comma');
    }
    buffer.writeln('  ],');
    buffer.writeln('  "frames": [');
    final framesList = _frameHistory.toList();
    for (var i = 0; i < framesList.length; i++) {
      final comma = i < framesList.length - 1 ? ',' : '';
      buffer.writeln('    ${_jsonEncode(framesList[i].toJson())}$comma');
    }
    buffer.writeln('  ]');
    buffer.writeln('}');

    return buffer.toString();
  }

  String _jsonEncode(Map<String, dynamic> map) {
    final entries = map.entries.map((e) {
      final value = e.value is String ? '"${e.value}"' : e.value;
      return '"${e.key}": $value';
    }).join(', ');
    return '{$entries}';
  }

  /// 清空历史数据
  void clearHistory() {
    _frameHistory.clear();
    _rebuildTracker.clear();
    _totalRebuilds = 0;
    _currentFps = 0;
    _currentBuildTime = 0;
    _currentRasterTime = 0;
    _currentTotalTime = 0;
    _currentIsJank = false;
    _frameCount = 0;
    notifyListeners();
  }

  /// 清空重建追踪数据
  void clearRebuildTracker() {
    _rebuildTracker.clear();
    _totalRebuilds = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
