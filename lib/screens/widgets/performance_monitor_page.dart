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
import '../../widgets/smooth_scroll_wrapper.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;
import '../../l10n/app_localizations.dart';

class PerformanceMonitorPage extends StatefulWidget {
  const PerformanceMonitorPage({super.key});

  @override
  State<PerformanceMonitorPage> createState() => _PerformanceMonitorPageState();
}

class _PerformanceMonitorPageState extends State<PerformanceMonitorPage> {
  final _performanceMonitor = PerformanceMonitorService();
  final _notificationSettings = NotificationSettingsService();
  AppLocalizations get t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _performanceMonitor.attachResourceSampling();
    _performanceMonitor.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _performanceMonitor.removeListener(_onUpdate);
    _performanceMonitor.detachResourceSampling();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stats = _performanceMonitor.getStats();
    final isMonitoring = _performanceMonitor.isMonitoring;

    return SmoothSingleChildScrollView(
      config: SmoothScrollConfig.fast,
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
                t.performanceMonitorTitle,
                style: FluentTheme.of(context).typography.subtitle?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                isMonitoring
                    ? t.performanceMonitorStatusRunning
                    : t.performanceMonitorStatusIdle,
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
              Text(isMonitoring
                  ? t.performanceMonitorButtonStop
                  : t.performanceMonitorButtonStart),
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
    final appCpu = _performanceMonitor.currentAppCpuPercent;
    final appMemory = _performanceMonitor.currentAppMemoryMb;
    final peakMemory = _performanceMonitor.peakAppMemoryMb;

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
                t.performanceMonitorRealtimeTitle,
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                      color: isJank ? Colors.red : null,
                    ),
              ),
              if (isJank) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    t.performanceMonitorJankBadge,
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
          _buildMetricGrid(
            context,
            [
              _buildMetricCard(
                context,
                t.performanceMonitorMetricFps,
                fps.toStringAsFixed(1),
                _getFpsColor(fps),
              ),
              _buildMetricCard(
                context,
                t.performanceMonitorMetricBuild,
                '${buildTime.toStringAsFixed(2)} ms',
                _getTimeColor(buildTime),
              ),
              _buildMetricCard(
                context,
                t.performanceMonitorMetricRaster,
                '${rasterTime.toStringAsFixed(2)} ms',
                _getTimeColor(rasterTime),
              ),
              _buildMetricCard(
                context,
                t.performanceMonitorMetricTotal,
                '${totalTime.toStringAsFixed(2)} ms',
                _getTimeColor(totalTime),
              ),
              _buildMetricCard(
                context,
                _processCpuLabel(context),
                '${appCpu.toStringAsFixed(1)}%',
                _getCpuColor(appCpu),
              ),
              _buildMetricCard(
                context,
                _processMemoryLabel(context),
                _formatMemoryMb(appMemory),
                AppTheme.accentPrimary,
              ),
              _buildMetricCard(
                context,
                _processPeakMemoryLabel(context),
                _formatMemoryMb(peakMemory),
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      BuildContext context, String label, String value, Color color) {
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

  Widget _buildMetricGrid(BuildContext context, List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const minCardWidth = 148.0;
        final availableWidth = constraints.maxWidth;
        final rawColumns =
            ((availableWidth + spacing) / (minCardWidth + spacing)).floor();
        final columns = rawColumns.clamp(1, 4);
        final cardWidth = ((availableWidth - (columns - 1) * spacing) / columns)
            .clamp(minCardWidth, availableWidth)
            .toDouble();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatsPanel(BuildContext context, PerformanceStats stats) {
    return SettingsSection(
      title: t.performanceMonitorStatsTitle,
      icon: CustomIcons.FluentIcons.chart,
      children: [
        _buildStatRow(context, t.performanceMonitorStatTotalFrames,
            '${stats.totalFrames}'),
        _buildStatRow(
            context, t.performanceMonitorStatJankFrames, '${stats.jankFrames}',
            valueColor: stats.jankFrames > 0 ? Colors.orange : null),
        _buildStatRow(context, t.performanceMonitorStatJankRate,
            '${stats.jankRate.toStringAsFixed(2)}%',
            valueColor: _getJankRateColor(stats.jankRate)),
        const Divider(),
        _buildStatRow(context, t.performanceMonitorStatAvgBuildTime,
            '${stats.avgBuildTime.toStringAsFixed(2)} ms'),
        _buildStatRow(context, t.performanceMonitorStatAvgRasterTime,
            '${stats.avgRasterTime.toStringAsFixed(2)} ms'),
        _buildStatRow(context, t.performanceMonitorStatAvgTotalTime,
            '${stats.avgTotalTime.toStringAsFixed(2)} ms'),
        const Divider(),
        _buildStatRow(context, _processCpuLabel(context),
            '${stats.appCpuPercent.toStringAsFixed(1)}%',
            valueColor: _getCpuColor(stats.appCpuPercent)),
        _buildStatRow(context, _processMemoryLabel(context),
            _formatMemoryMb(stats.appMemoryMb)),
        _buildStatRow(context, _processPeakMemoryLabel(context),
            _formatMemoryMb(stats.peakAppMemoryMb),
            valueColor: Colors.orange),
        const Divider(),
        _buildStatRow(context, t.performanceMonitorStatMaxBuildTime,
            '${stats.maxBuildTime.toStringAsFixed(2)} ms',
            valueColor: _getTimeColor(stats.maxBuildTime)),
        _buildStatRow(context, t.performanceMonitorStatMaxRasterTime,
            '${stats.maxRasterTime.toStringAsFixed(2)} ms',
            valueColor: _getTimeColor(stats.maxRasterTime)),
        _buildStatRow(context, t.performanceMonitorStatMaxTotalTime,
            '${stats.maxTotalTime.toStringAsFixed(2)} ms',
            valueColor: _getTimeColor(stats.maxTotalTime)),
      ],
    );
  }

  Widget _buildRebuildStatsPanel(BuildContext context, PerformanceStats stats) {
    final topRebuilds = _performanceMonitor.getTopRebuilds(limit: 10);

    return SettingsSection(
      title: t.performanceMonitorRebuildTitle,
      icon: CustomIcons.FluentIcons.refresh,
      children: [
        _buildStatRow(
            context, t.performanceMonitorRebuildTotal, '${stats.totalRebuilds}',
            valueColor: stats.totalRebuilds > 100 ? Colors.orange : null),
        _buildStatRow(context, t.performanceMonitorRebuildTracked,
            '${stats.trackedWidgets}'),
        if (topRebuilds.isNotEmpty) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              t.performanceMonitorRebuildTopTitle,
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
                t.performanceMonitorRebuildEmpty,
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
                    color: isHighFrequency
                        ? Colors.orange
                        : AppTheme.accentPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Consolas',
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value,
      {Color? valueColor}) {
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
      title: t.performanceMonitorFrameChartTitle(frames.length),
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
                    t.performanceMonitorFrameChartEmpty,
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
            _buildLegend(context, t.performanceMonitorLegendNormal,
                AppTheme.statusSuccess),
            const SizedBox(width: 16),
            _buildLegend(
                context, t.performanceMonitorLegendJankMs(16.67), Colors.red),
            const SizedBox(width: 16),
            _buildLegend(
                context, t.performanceMonitorLegendFpsThreshold, Colors.orange),
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
      title: t.performanceMonitorSettingsTitle,
      icon: CustomIcons.FluentIcons.settings,
      children: [
        _buildStatRow(context, t.performanceMonitorSettingsModeLabel,
            _getPerformanceModeName(_notificationSettings.performanceMode)),
        _buildStatRow(
            context,
            t.performanceMonitorSettingsBlurLabel,
            _notificationSettings.enableBlur
                ? t.performanceMonitorValueEnabled
                : t.performanceMonitorValueDisabled),
        _buildStatRow(context, t.performanceMonitorSettingsBlurStrengthLabel,
            _notificationSettings.blurSigma.toStringAsFixed(1)),
        const Divider(),
        _buildStatRow(
          context,
          t.performanceMonitorSettingsWindowEffectLabel,
          windowEffect.effectEnabled
              ? t.performanceMonitorWindowEffectEnabled(windowEffect.effectMode)
              : t.performanceMonitorValueDisabled,
          valueColor: windowEffect.effectEnabled
              ? Colors.orange
              : AppTheme.statusSuccess,
        ),
        _buildStatRow(context, t.performanceMonitorSettingsAcrylicOpacityLabel,
            '${windowEffect.alpha}'),
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
                color: windowEffect.effectEnabled
                    ? Colors.orange
                    : AppTheme.statusSuccess,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  windowEffect.effectEnabled
                      ? t.performanceMonitorWindowEffectHintEnabled
                      : t.performanceMonitorWindowEffectHintDisabled,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: windowEffect.effectEnabled
                            ? Colors.orange.darker
                            : AppTheme.statusSuccess,
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
                Text(t.performanceMonitorActionExport),
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
                Text(t.performanceMonitorActionCopy),
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
                    _showInfoBar(context, t.performanceMonitorToastClearedTitle,
                        t.performanceMonitorToastClearedMessage);
                  },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CustomIcons.FluentIcons.delete, size: 16),
                const SizedBox(width: 8),
                Text(t.performanceMonitorActionClear),
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
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final file = File('${dir.path}/hanabi_performance_$timestamp.txt');
      await file.writeAsString(log);

      if (mounted) {
        _showInfoBar(
          context,
          t.performanceMonitorToastExportSuccessTitle,
          t.performanceMonitorToastExportSuccessMessage(file.path),
        );
      }
    } catch (e) {
      if (mounted) {
        _showInfoBar(
          context,
          t.performanceMonitorToastExportFailedTitle,
          t.performanceMonitorToastExportFailedMessage(e),
          isError: true,
        );
      }
    }
  }

  void _copyToClipboard(BuildContext context) {
    final log = _performanceMonitor.exportLog();
    Clipboard.setData(ClipboardData(text: log));
    _showInfoBar(
      context,
      t.performanceMonitorToastCopiedTitle,
      t.performanceMonitorToastCopiedMessage,
    );
  }

  void _showInfoBar(BuildContext context, String title, String message,
      {bool isError = false}) {
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

  Color _getCpuColor(double cpuPercent) {
    if (cpuPercent <= 25) return AppTheme.statusSuccess;
    if (cpuPercent <= 60) return Colors.orange;
    return Colors.red;
  }

  String _formatMemoryMb(double memoryMb) {
    return '${memoryMb.toStringAsFixed(1)} MB';
  }

  bool _isZhUi(BuildContext context) {
    return Localizations.localeOf(context)
        .languageCode
        .toLowerCase()
        .startsWith('zh');
  }

  String _processCpuLabel(BuildContext context) {
    return _isZhUi(context) ? '软件 CPU' : 'App CPU';
  }

  String _processMemoryLabel(BuildContext context) {
    return _isZhUi(context) ? '软件内存' : 'App Memory';
  }

  String _processPeakMemoryLabel(BuildContext context) {
    return _isZhUi(context) ? '峰值内存' : 'Peak Memory';
  }

  String _getPerformanceModeName(NotificationPerformanceMode mode) {
    switch (mode) {
      case NotificationPerformanceMode.quality:
        return t.performanceMonitorModeQuality;
      case NotificationPerformanceMode.balanced:
        return t.performanceMonitorModeBalanced;
      case NotificationPerformanceMode.performance:
        return t.performanceMonitorModePerformance;
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
