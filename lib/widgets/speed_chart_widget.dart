import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/speed_history_service.dart';

/// 速度曲线颜色预设
class SpeedChartColors {
  static const Map<String, Color> presets = {
    'blue': Color(0xFF0078D4),
    'cyan': Color(0xFF60CDFF),
    'purple': Color(0xFF8B5CF6),
    'green': Color(0xFF10B981),
    'pink': Color(0xFFEC4899),
    'orange': Color(0xFFF97316),
  };

  static Color fromName(String name) => presets[name] ?? presets['blue']!;
}

/// 线条位置：低/中/高
enum ChartPosition { low, mid, high }

/// 实时速度曲线图 — 自定义 CustomPainter 实现平滑贝塞尔曲线
class SpeedChartWidget extends StatelessWidget {
  final String taskId;
  final double currentSpeed;
  final double? height;
  /// 'downloading' | 'paused' | 'failed'
  final String status;
  /// 自定义线条颜色名称
  final String colorName;
  /// 线条位置
  final ChartPosition position;
  /// 下载进度 0.0~1.0，曲线宽度与进度同步
  final double progress;

  const SpeedChartWidget({
    super.key,
    required this.taskId,
    required this.currentSpeed,
    this.height,
    this.status = 'downloading',
    this.colorName = 'blue',
    this.position = ChartPosition.mid,
    this.progress = 1.0,
  });

  Color _lineColor() {
    switch (status) {
      case 'paused':
        return const Color(0xFFF59E0B);
      case 'failed':
        return const Color(0xFFEF4444);
      default:
        return SpeedChartColors.fromName(colorName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = SpeedHistoryService().getHistory(taskId);
    if (history.isEmpty || history.length < 2) return const SizedBox.shrink();

    final color = _lineColor();

    Widget chart = CustomPaint(
      painter: _SpeedCurvePainter(
        data: history,
        color: color,
        maxDataPoints: SpeedHistoryService.maxDataPoints,
        position: position,
        progress: progress,
      ),
      size: Size.infinite,
    );

    if (height != null) {
      return SizedBox(height: height, child: chart);
    }
    return chart;
  }
}


/// 自定义画笔 — 用三次贝塞尔曲线绘制平滑速度曲线 + 渐变填充
class _SpeedCurvePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final int maxDataPoints;
  final ChartPosition position;
  final double progress;

  _SpeedCurvePainter({
    required this.data,
    required this.color,
    required this.maxDataPoints,
    required this.position,
    required this.progress,
  });

  /// 根据位置设置决定曲线占卡片高度的比例
  double get _heightRatio {
    switch (position) {
      case ChartPosition.low:
        return 0.35;
      case ChartPosition.mid:
        return 0.6;
      case ChartPosition.high:
        return 0.85;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final maxSpeed = data.reduce((a, b) => a > b ? a : b);
    if (maxSpeed <= 0) return;

    // Y 轴上限：峰值的 1.3 倍
    final yMax = maxSpeed * 1.3;
    // 曲线区域：从底部往上占 _heightRatio 比例
    final chartHeight = size.height * _heightRatio;
    // chartBottom = size.height（画布底部）
    // chartTop = size.height - chartHeight

    // 将数据点映射到画布坐标
    final points = <Offset>[];
    // 曲线宽度与下载进度同步
    final drawWidth = size.width * progress.clamp(0.0, 1.0);
    final xStep = data.length > 1 ? drawWidth / (data.length - 1) : 0.0;
    // 数据左对齐（从左边开始画，宽度随进度增长）

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final yNorm = (data[i] / yMax).clamp(0.0, 1.0);
      // 速度越高 → y 越小（画布上方）
      // yNorm=0 → y=size.height（底部）, yNorm=1 → y=size.height-chartHeight（顶部）
      final y = size.height - chartHeight * yNorm;
      points.add(Offset(x, y));
    }

    // 构建平滑贝塞尔路径
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      // Catmull-Rom → Cubic Bezier 控制点
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    // 渐变填充：从曲线往下到画布底部
    final fillPath = Path.from(path);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.lineTo(points.first.dx, size.height);
    fillPath.close();

    final gradientTop = size.height - chartHeight;
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, gradientTop),
        Offset(0, size.height),
        [
          color.withValues(alpha: 0.30),
          color.withValues(alpha: 0.0),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    // 绘制线条
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedCurvePainter oldDelegate) {
    return oldDelegate.data.length != data.length ||
        oldDelegate.color != color ||
        oldDelegate.position != position ||
        oldDelegate.progress != progress ||
        (data.isNotEmpty && oldDelegate.data.isNotEmpty && oldDelegate.data.last != data.last);
  }
}
