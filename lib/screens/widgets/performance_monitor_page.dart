import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../services/performance_monitor_service.dart';
import '../../services/notification_settings_service.dart';
import '../../services/window_effect_service.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/animated_notifications.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;

class PerformanceMonitorPage extends StatefulWidget {
  const PerformanceMonitorPage({super.key});

  @override
  State<PerformanceMonitorPage> createState() => _PerformanceMonitorPageState();
}

class _PerformanceMonitorPageState extends State<PerformanceMonitorPage> {
  final _performanceMonitor = PerformanceMonitorService();
  final _notificationSettings = NotificationSettingsService();

  @override
  void initState() {
    super.initState();
    _performanceMonitor.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _performanceMonitor.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stats = _performanceMonitor.getStats();
    final isMonitoring = _performanceMonitor.isMonitoring;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和控制按钮
          _buildHeader(context, isMonitoring),
          const SizedBox(height: 24),

          // 实时数据面板
          _buildRealtimePanel(context),
          const SizedBox(height: 24),

          // 统计摘要
          _buildStatsPanel(context, stats),
          const SizedBox(height: 24),

          // 重建次数统计
          _buildRebuildStatsPanel(context, stats),
          const SizedBox(height: 24),

          // 帧时间图表
          _buildFrameChart(context),
          const SizedBox(height: 24),

          // 当前设置信息
          _buildSettingsInfo(context),
          const SizedBox(height: 24),

          // 操作按钮
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isMonitoring) {
    return Row(
      children: [
        Icon(
          CustomIcons.FluentIcons.speed_high,
          size: 28,
          color: AppTheme.accentPrimary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '性能监控',
                style: FluentTheme.of(context).typography.subtitle?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isMonitoring ? '正在监控中...' : '点击开始监控以收集性能数据',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        FilledButton(
          onPressed: () {
            if (isMonitoring) {
              _performanceMonitor.stopMonitoring();
            } else {
              _performanceMonitor.startMonitoring();
            }
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(
              isMonitoring ? Colors.red : AppTheme.accentPrimary,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isMonitoring
                    ? CustomIcons.FluentIcons.pause
                    : CustomIcons.FluentIcons.play,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(isMonitoring ? '停止监控' : '开始监控'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRealtimePanel(BuildContext context) {
    final fps = _performanceMonitor.currentFps;
    final buildTime = _performanceMonitor.currentBuildTime;
    final rasterTime = _performanceMonitor.currentRasterTime;
    final totalTime = _performanceMonitor.currentTotalTime;
    final isJank = _performanceMonitor.currentIsJank;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isJank
              ? Colors.red.withValues(alpha: 0.5)
              : AppTheme.borderSubtle.withValues(alpha: 0.3),
          width: isJank ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CustomIcons.FluentIcons.health,
                size: 16,
                color: isJank ? Colors.red : AppTheme.accentPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                '实时数据',
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  color: isJank ? Colors.red : null,
                ),
              ),
              if (isJank) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'JANK',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricCard(context, 'FPS', fps.toStringAsFixed(1), _getFpsColor(fps))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(context, 'Build', '${buildTime.toStringAsFixed(2)} ms', _getTimeColor(buildTime))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(context, 'Raster', '${rasterTime.toStringAsFixed(2)} ms', _getTimeColor(rasterTime))),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard(context, 'Total', '${totalTime.toStringAsFixed(2)} ms', _getTimeColor(totalTime))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontFamily: 'Consolas',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(BuildContext context, PerformanceStats stats) {
    return SettingsSection(
      title: '统计摘要',
      icon: CustomIcons.FluentIcons.chart,
      children: [
        _buildStatRow(context, '总帧数', '${stats.totalFrames}'),
        _buildStatRow(context, '卡顿帧数', '${stats.jankFrames}',
            valueColor: stats.jankFrames > 0 ? Colors.orange : null),
        _buildStatRow(context, '卡顿率', '${stats.jankRate.toStringAsFixed(2)}%',
            valueColor: _getJankRateColor(stats.jankRate)),
        const Divider(),
        _buildStatRow(context, '平均 Build 时间', '${stats.avgBuildTime.toStringAsFixed(2)} ms'),
        _buildStatRow(context, '平均 Raster 时间', '${stats.avgRasterTime.toStringAsFixed(2)} ms'),
        _buildStatRow(context, '平均 Total 时间', '${stats.avgTotalTime.toStringAsFixed(2)} ms'),
        const Divider(),
        _buildStatRow(context, '最大 Build 时间', '${stats.maxBuildTime.toStringAsFixed(2)} ms',
            valueColor: _getTimeColor(stats.maxBuildTime)),
        _buildStatRow(context, '最大 Raster 时间', '${stats.maxRasterTime.toStringAsFixed(2)} ms',
            valueColor: _getTimeColor(stats.maxRasterTime)),
        _buildStatRow(context, '最大 Total 时间', '${stats.maxTotalTime.toStringAsFixed(2)} ms',
            valueColor: _getTimeColor(stats.maxTotalTime)),
      ],
    );
  }

  Widget _buildRebuildStatsPanel(BuildContext context, PerformanceStats stats) {
    final topRebuilds = _performanceMonitor.getTopRebuilds(limit: 10);

    return SettingsSection(
      title: 'Widget 重建统计',
      icon: CustomIcons.FluentIcons.refresh,
      children: [
        _buildStatRow(context, '总重建次数', '${stats.totalRebuilds}',
            valueColor: stats.totalRebuilds > 100 ? Colors.orange : null),
        _buildStatRow(context, '追踪的 Widget 数', '${stats.trackedWidgets}'),
        if (topRebuilds.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              '重建次数最多的 Widget',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...topRebuilds.map((rebuild) => _buildRebuildRow(context, rebuild)),
        ],
        if (topRebuilds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                '暂无重建数据\n在代码中调用 trackRebuild() 来追踪',
                textAlign: TextAlign.center,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRebuildRow(BuildContext context, RebuildData rebuild) {
    final isHighFrequency = rebuild.count > 50;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isHighFrequency ? Colors.orange : AppTheme.accentPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rebuild.widgetName,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isHighFrequency
                  ? Colors.orange.withValues(alpha: 0.15)
                  : AppTheme.accentPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${rebuild.count}',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: isHighFrequency ? Colors.orange : AppTheme.accentPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Consolas',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: FluentTheme.of(context).typography.body,
          ),
          Text(
            value,
            style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
              color: valueColor,
              fontFamily: 'Consolas',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameChart(BuildContext context) {
    final frames = _performanceMonitor.frameHistory;

    return SettingsSection(
      title: '帧时间图表 (最近 ${frames.length} 帧)',
      icon: CustomIcons.FluentIcons.timeline_progress,
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.bgLayer1.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: frames.isEmpty
              ? Center(
                  child: Text(
                    '暂无数据，请开始监控',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                )
              : CustomPaint(
                  size: const Size(double.infinity, 120),
                  painter: _FrameChartPainter(frames),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegend(context, '正常帧', AppTheme.statusSuccess),
            const SizedBox(width: 16),
            _buildLegend(context, '卡顿帧 (>16.67ms)', Colors.red),
            const SizedBox(width: 16),
            _buildLegend(context, '60fps 阈值', Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsInfo(BuildContext context) {
    final windowEffect = context.watch<WindowEffectService>();

    return SettingsSection(
      title: '当前渲染设置',
      icon: CustomIcons.FluentIcons.settings,
      children: [
        _buildStatRow(context, '性能模式', _getPerformanceModeName(_notificationSettings.performanceMode)),
        _buildStatRow(context, '模糊效果', _notificationSettings.enableBlur ? '启用' : '禁用'),
        _buildStatRow(context, '模糊强度', '${_notificationSettings.blurSigma.toStringAsFixed(1)}'),
        const Divider(),
        _buildStatRow(
          context,
          '窗口特效',
          windowEffect.effectEnabled ? '启用 (${windowEffect.effectMode})' : '禁用',
          valueColor: windowEffect.effectEnabled ? Colors.orange : AppTheme.statusSuccess,
        ),
        _buildStatRow(context, '亚克力透明度', '${windowEffect.alpha}'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: windowEffect.effectEnabled
                ? Colors.orange.withValues(alpha: 0.1)
                : AppTheme.statusSuccess.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: windowEffect.effectEnabled
                  ? Colors.orange.withValues(alpha: 0.3)
                  : AppTheme.statusSuccess.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                windowEffect.effectEnabled
                    ? CustomIcons.FluentIcons.lightbulb
                    : CustomIcons.FluentIcons.completed_solid,
                size: 16,
                color: windowEffect.effectEnabled ? Colors.orange : AppTheme.statusSuccess,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  windowEffect.effectEnabled
                      ? '窗口特效已启用，可能影响性能。如果卡顿率较高，建议在"设置 → 界面 → 窗口效果"中关闭'
                      : '窗口特效已禁用，性能最佳。如需视觉效果可在"设置 → 界面 → 窗口效果"中开启',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: windowEffect.effectEnabled ? Colors.orange.darker : AppTheme.statusSuccess,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Button(
            onPressed: _performanceMonitor.frameHistory.isEmpty
                ? null
                : () => _exportLog(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CustomIcons.FluentIcons.save, size: 16),
                const SizedBox(width: 8),
                const Text('导出日志'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Button(
            onPressed: _performanceMonitor.frameHistory.isEmpty
                ? null
                : () => _copyToClipboard(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CustomIcons.FluentIcons.copy, size: 16),
                const SizedBox(width: 8),
                const Text('复制到剪贴板'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Button(
            onPressed: _performanceMonitor.frameHistory.isEmpty
                ? null
                : () {
                    _performanceMonitor.clearHistory();
                    _showInfoBar(context, '已清空', '历史数据已清空');
                  },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CustomIcons.FluentIcons.delete, size: 16),
                const SizedBox(width: 8),
                const Text('清空数据'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _exportLog(BuildContext context) async {
    try {
      final log = _performanceMonitor.exportLog();
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final file = File('${dir.path}/hanabi_performance_$timestamp.txt');
      await file.writeAsString(log);

      if (mounted) {
        _showInfoBar(context, '导出成功', '日志已保存到: ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        _showInfoBar(context, '导出失败', e.toString(), isError: true);
      }
    }
  }

  void _copyToClipboard(BuildContext context) {
    final log = _performanceMonitor.exportLog();
    Clipboard.setData(ClipboardData(text: log));
    _showInfoBar(context, '已复制', '性能日志已复制到剪贴板');
  }

  void _showInfoBar(BuildContext context, String title, String message, {bool isError = false}) {
    if (isError) {
      NotificationManager.of(context)?.showError(title, message: message);
    } else {
      NotificationManager.of(context)?.showSuccess(title, message: message);
    }
  }

  Color _getFpsColor(double fps) {
    if (fps >= 55) return AppTheme.statusSuccess;
    if (fps >= 30) return Colors.orange;
    return Colors.red;
  }

  Color _getTimeColor(double ms) {
    if (ms <= 8) return AppTheme.statusSuccess;
    if (ms <= 16.67) return Colors.orange;
    return Colors.red;
  }

  Color _getJankRateColor(double rate) {
    if (rate <= 1) return AppTheme.statusSuccess;
    if (rate <= 5) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceModeName(NotificationPerformanceMode mode) {
    switch (mode) {
      case NotificationPerformanceMode.quality:
        return '高质量';
      case NotificationPerformanceMode.balanced:
        return '平衡';
      case NotificationPerformanceMode.performance:
        return '性能优先';
    }
  }
}

/// 帧时间图表绘制器
class _FrameChartPainter extends CustomPainter {
  final List<FrameData> frames;

  _FrameChartPainter(this.frames);

  @override
  void paint(Canvas canvas, Size size) {
    if (frames.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    final thresholdPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 绘制 16.67ms 阈值线
    final thresholdY = size.height - (16.67 / 50 * size.height);
    canvas.drawLine(
      Offset(0, thresholdY),
      Offset(size.width, thresholdY),
      thresholdPaint,
    );

    // 绘制帧时间柱状图
    final barWidth = size.width / frames.length;
    for (var i = 0; i < frames.length; i++) {
      final frame = frames[i];
      final totalMs = frame.totalTime.inMicroseconds / 1000;
      final barHeight = (totalMs / 50 * size.height).clamp(1.0, size.height);

      paint.color = frame.isJank
          ? Colors.red.withValues(alpha: 0.8)
          : AppTheme.statusSuccess.withValues(alpha: 0.6);

      canvas.drawRect(
        Rect.fromLTWH(
          i * barWidth,
          size.height - barHeight,
          barWidth - 1,
          barHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FrameChartPainter oldDelegate) {
    return oldDelegate.frames.length != frames.length;
  }
}
