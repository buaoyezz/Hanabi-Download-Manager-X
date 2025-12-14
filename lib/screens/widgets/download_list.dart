import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/integrated_download_service.dart';
import '../../models/download_task.dart' show DownloadTask, DownloadStatus, SegmentInfo;
import '../../theme/app_theme.dart';
import '../../widgets/file_icon_widget.dart';
import '../../widgets/animated_card.dart';

class DownloadList extends StatelessWidget {
  const DownloadList({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Consumer<IntegratedDownloadService>(
        builder: (context, downloadService, child) {
          final activeTasks = downloadService.tasks
              .where((t) => t.status != DownloadStatus.completed)
              .toList();

          if (activeTasks.isEmpty) {
            return _buildEmptyState(context);
          }

        // 计算总体统计
        final downloadingTasks = activeTasks.where((t) => t.status == DownloadStatus.downloading).toList();
        final totalSpeed = downloadingTasks.fold<double>(0, (sum, t) => sum + (t.speed ?? 0));
        final totalSegments = downloadingTasks.fold<int>(0, (sum, t) => sum + (t.segments?.length ?? 0));

        return Column(
          children: [
            // 下载统计栏
            if (downloadingTasks.isNotEmpty)
              _buildStatsBar(context, downloadingTasks.length, totalSpeed, totalSegments),
            // 任务列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: activeTasks.length,
                itemBuilder: (context, index) {
                  final task = activeTasks[index];
                  return TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 300 + (index * 100)),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: _DownloadTaskCard(task: task),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
        },
      ),
    );
  }
  
  Widget _buildStatsBar(BuildContext context, int activeCount, double totalSpeed, int totalSegments) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 活跃任务数
          _buildStatItem(
            context,
            icon: FluentIcons.download,
            label: '下载中',
            value: '$activeCount',
            color: AppTheme.accentPrimary,
          ),
          _buildDivider(),
          // 总速度
          _buildStatItem(
            context,
            icon: FluentIcons.speed_high,
            label: '总速度',
            value: _formatSpeed(totalSpeed),
            color: AppTheme.accentLight,
          ),
          _buildDivider(),
          // 活跃分段
          _buildStatItem(
            context,
            icon: FluentIcons.split_object,
            label: '活跃分段',
            value: '$totalSegments',
            color: AppTheme.statusSuccess,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  color: color,
                  fontSize: 13,
                ),
              ),
              Text(
                label,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppTheme.borderSubtle,
    );
  }
  
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    if (bytesPerSecond < 1024 * 1024 * 1024) return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1200),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentPrimary.withValues(alpha: 0.3 * value),
                          blurRadius: 60 * value,
                          spreadRadius: 10 * value,
                        ),
                      ],
                    ),
                    child: Icon(
                      FluentIcons.download,
                      size: 40,
                      color: AppTheme.accentPrimary.withValues(alpha: 0.6),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: Text(
                      '暂无下载任务',
                      style: FluentTheme.of(context).typography.subtitle?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: Text(
                      '点击右上角"新建"按钮开始下载',
                      style: FluentTheme.of(context).typography.body?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
      ),
    );
  }
}

class _DownloadTaskCard extends StatefulWidget {
  final DownloadTask task;

  const _DownloadTaskCard({required this.task});

  @override
  State<_DownloadTaskCard> createState() => _DownloadTaskCardState();
}

class _DownloadTaskCardState extends State<_DownloadTaskCard> {
  bool _isSegmentsExpanded = false;
  bool _showAllSegments = false;
  int _maxVisibleSegments = 5;
  String _segmentsDisplayMode = 'merged'; // 'merged' (合并) 或 'list' (列表)
  
  @override
  void initState() {
    super.initState();
    _loadSegmentsExpandedSetting();
  }
  
  Future<void> _loadSegmentsExpandedSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultExpanded = prefs.getBool('segments_default_expanded') ?? false;
    final maxVisible = prefs.getInt('segments_max_visible') ?? 5;
    final displayMode = prefs.getString('segments_display_mode') ?? 'merged';
    if (mounted) {
      setState(() {
        _isSegmentsExpanded = defaultExpanded;
        _maxVisibleSegments = maxVisible;
        _segmentsDisplayMode = displayMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<IntegratedDownloadService>();

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.85),
      hoverColor: AppTheme.surfaceCard.withValues(alpha: 0.95),
      borderColor: AppTheme.borderSubtle,
      hoverBorderColor: AppTheme.accentPrimary.withValues(alpha: 0.4),
      borderRadius: AppTheme.radiusLg,
      enableGlowAnimation: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(downloadService),
          const SizedBox(height: 14),
          _buildProgressSection(),
          if (widget.task.status == DownloadStatus.downloading) ...[
            const SizedBox(height: 12),
            _buildSpeedInfo(),
          ],
          if (widget.task.status == DownloadStatus.failed && widget.task.error != null) ...[
            const SizedBox(height: 12),
            _buildErrorInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(IntegratedDownloadService service) {
    return Row(
      children: [
        _buildStatusIcon(),
        const SizedBox(width: 14),
        Expanded(child: _buildTaskInfo()),
        _buildActionButtons(service),
      ],
    );
  }

  Widget _buildStatusIcon() {
    // 使用系统文件图标组件
    return FileIconWidget(
      fileName: widget.task.fileName,
      filePath: widget.task.filePath,
      size: 32,
    );
  }

  Widget _buildTaskInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.task.fileName,
          style: FluentTheme.of(context).typography.body?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        _buildUrlWithCopy(),
        const SizedBox(height: 6),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildUrlWithCopy() {
    return _HoverableUrl(
      url: widget.task.url,
      onTap: _copyUrlToClipboard,
    );
  }

  Future<void> _copyUrlToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.task.url));
      if (mounted) {
        // 显示复制成功的提示
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('复制成功'),
            content: const Text('链接已复制到剪贴板'),
            severity: InfoBarSeverity.success,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('复制失败'),
            content: Text('无法复制链接: $e'),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    }
  }

  Widget _buildStatusChip() {
    final color = _getStatusColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        _getStatusText(),
        style: FluentTheme.of(context).typography.caption?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildActionButtons(IntegratedDownloadService service) {
    final isMerging = widget.task.status == DownloadStatus.merging;
    final hasRetryableSegments = widget.task.hasRetryableSegments;
    final isFailed = widget.task.status == DownloadStatus.failed;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMerging && (widget.task.status == DownloadStatus.pending ||
            widget.task.status == DownloadStatus.paused))
          _ActionButton(
            icon: FluentIcons.play,
            color: AppTheme.statusSuccess,
            onPressed: () => service.startTask(widget.task.id),
            tooltip: '开始',
          ),
        if (!isMerging && widget.task.status == DownloadStatus.downloading)
          _ActionButton(
            icon: FluentIcons.pause,
            color: AppTheme.statusWarning,
            onPressed: () => service.pauseTask(widget.task.id),
            tooltip: '暂停',
          ),
        // 添加间距
        if (!isMerging && (widget.task.status == DownloadStatus.pending ||
            widget.task.status == DownloadStatus.paused ||
            widget.task.status == DownloadStatus.downloading))
          const SizedBox(width: 6),
        // 重试失败分段按钮 - 显示在删除按钮左边
        if (!isMerging && (hasRetryableSegments || isFailed)) ...[
          _ActionButton(
            icon: FluentIcons.refresh,
            color: AppTheme.accentLight,
            onPressed: () => service.retryFailedSegments(widget.task.id),
            tooltip: hasRetryableSegments ? '重试失败分段' : '重新下载',
          ),
          const SizedBox(width: 6),
        ],
        if (!isMerging)
          _ActionButton(
            icon: FluentIcons.delete,
            color: AppTheme.statusError,
            onPressed: () => _confirmDelete(service),
            tooltip: '删除',
          ),
      ],
    );
  }

  Widget _buildProgressSection() {
    final isUnknownSize = (widget.task.fileSize == null || widget.task.fileSize == 0) && 
                          widget.task.status == DownloadStatus.downloading;
    final isMerging = widget.task.status == DownloadStatus.merging;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: (isUnknownSize || isMerging)
                    ? const ProgressBar(strokeWidth: 6)
                    : AnimatedProgressBar(
                        progress: widget.task.progress,
                        height: 6,
                        backgroundColor: AppTheme.bgLayer1,
                        borderRadius: BorderRadius.circular(4),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgLayer2,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: isMerging
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: ProgressRing(strokeWidth: 2),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '正在校验和合并数据',
                          style: FluentTheme.of(context).typography.caption?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentPrimary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      isUnknownSize 
                          ? '计算中'
                          : '${(widget.task.progress * 100).toStringAsFixed(1)}%',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                      ),
                    ),
            ),
          ],
        ),
        if (widget.task.segments != null && widget.task.segments!.isNotEmpty && !isMerging) ...[
          const SizedBox(height: 10),
          _buildSegmentsProgress(),
        ],
      ],
    );
  }

  Widget _buildSegmentsProgress() {
    final segments = widget.task.segments!;
    
    // 简洁模式：不显示分段信息
    if (_segmentsDisplayMode == 'none') {
      return const SizedBox.shrink();
    }
    
    // 合并进度条模式
    if (_segmentsDisplayMode == 'merged') {
      return _buildMergedSegmentsBar(segments);
    }
    
    // 列表模式
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _isSegmentsExpanded = !_isSegmentsExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgLayer2,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.split_object,
                  size: 12,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  '分段下载 (${segments.length})',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _isSegmentsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    FluentIcons.chevron_down,
                    size: 10,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _buildSegmentsList(segments),
          crossFadeState: _isSegmentsExpanded 
              ? CrossFadeState.showSecond 
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
  
  /// 合并分段进度条
  Widget _buildMergedSegmentsBar(List<SegmentInfo> segments) {
    final totalSize = widget.task.fileSize ?? 0;
    if (totalSize == 0) return const SizedBox.shrink();
    
    // 统计分段状态
    final completedCount = segments.where((s) => s.status == 'completed').length;
    final downloadingCount = segments.where((s) => s.status == 'downloading').length;
    final failedCount = segments.where((s) => s.status == 'failed').length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分段信息标题
        Row(
          children: [
            Icon(
              FluentIcons.split_object,
              size: 12,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              '分段下载',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            // 分段状态统计
            _buildSegmentStatusBadge(completedCount, AppTheme.statusSuccess, '完成'),
            const SizedBox(width: 4),
            _buildSegmentStatusBadge(downloadingCount, AppTheme.accentPrimary, '下载'),
            if (failedCount > 0) ...[
              const SizedBox(width: 4),
              _buildSegmentStatusBadge(failedCount, AppTheme.statusError, '失败'),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // 合并进度条
        Container(
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.bgLayer2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppTheme.borderSubtle,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: CustomPaint(
              painter: _SegmentProgressPainter(
                segments: segments,
                totalSize: totalSize,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // 分段数量提示
        Row(
          children: [
            Expanded(
              child: Text(
                '${segments.length} 个分段 · $completedCount 完成 · $downloadingCount 下载中' +
                (failedCount > 0 ? ' · $failedCount 失败' : ''),
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ),
            // 快速重试按钮
            if (failedCount > 0) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.read<IntegratedDownloadService>().retryFailedSegments(widget.task.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppTheme.accentLight.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        FluentIcons.refresh,
                        size: 8,
                        color: AppTheme.accentLight,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '重试',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.accentLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
  
  Widget _buildSegmentStatusBadge(int count, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count$label',
        style: FluentTheme.of(context).typography.caption?.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSegmentsList(List<SegmentInfo> segments) {
    final visibleSegments = _showAllSegments 
        ? segments 
        : segments.take(_maxVisibleSegments).toList();
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          ...visibleSegments.map((segment) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildSegmentRow(segment),
          )),
          if (segments.length > _maxVisibleSegments)
            _buildShowMoreButton(segments.length),
        ],
      ),
    );
  }

  Widget _buildSegmentRow(SegmentInfo segment) {
    final downloadService = context.read<IntegratedDownloadService>();
    
    // 根据分段状态选择颜色
    Color statusColor;
    switch (segment.status) {
      case 'downloading':
        statusColor = AppTheme.accentPrimary;
        break;
      case 'completed':
        statusColor = AppTheme.statusSuccess;
        break;
      case 'failed':
        statusColor = AppTheme.statusError;
        break;
      case 'paused':
        statusColor = AppTheme.statusWarning;
        break;
      default:
        statusColor = AppTheme.textTertiary;
    }
    
    return Row(
      children: [
        // 分段编号和状态指示器
        Container(
          width: 60,
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '分段 ${segment.index + 1}',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedProgressBar(
            progress: segment.progress,
            height: 3,
            backgroundColor: AppTheme.bgLayer1,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        // 状态文本
        SizedBox(
          width: 35,
          child: Text(
            segment.statusText,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: statusColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: Text(
            '${_formatBytes(segment.downloadedBytes)}/${_formatBytes(segment.endByte - segment.startByte)}',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 9,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 55,
          child: Text(
            _formatSpeed(segment.speed),
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: segment.speed > 0 ? AppTheme.accentLight : AppTheme.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        // 重试次数显示
        if (segment.retryCount > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.statusWarning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '重试${segment.retryCount}',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.statusWarning,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        // 单个分段重试按钮
        if (segment.canRetry) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => downloadService.retrySegment(widget.task.id, segment.index),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.accentLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: AppTheme.accentLight.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Icon(
                FluentIcons.refresh,
                size: 8,
                color: AppTheme.accentLight,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildShowMoreButton(int totalCount) {
    return GestureDetector(
      onTap: () => setState(() => _showAllSegments = !_showAllSegments),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.accentPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.accentPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showAllSegments ? FluentIcons.chevron_up_small : FluentIcons.chevron_down_small,
              size: 12,
              color: AppTheme.accentLight,
            ),
            const SizedBox(width: 6),
            Text(
              _showAllSegments 
                  ? '收起'
                  : '显示全部 ${totalCount - _maxVisibleSegments} 个',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.accentLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    if (bytesPerSecond < 1024 * 1024 * 1024) return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  Widget _buildSpeedInfo() {
    final isUnknownSize = widget.task.fileSize == null || widget.task.fileSize == 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          _buildAnimatedInfoChip(FluentIcons.speed_high, widget.task.speed ?? 0, _formatSpeed, AppTheme.accentLight),
          if (!isUnknownSize) ...[
            _buildDivider(),
            _buildInfoChip(FluentIcons.clock, widget.task.formattedRemainingTime, AppTheme.textSecondary),
          ],
          _buildDivider(),
          Expanded(
            child: Text(
              isUnknownSize
                  ? '${widget.task.formattedDownloadedSize} / 未知'
                  : '${widget.task.formattedDownloadedSize} / ${widget.task.formattedFileSize}',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedInfoChip(IconData icon, double value, String Function(double) formatter, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        AnimatedCounter(
          value: value,
          formatter: formatter,
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppTheme.borderSubtle,
    );
  }

  Widget _buildErrorInfo() {
    final downloadService = context.read<IntegratedDownloadService>();
    final hasRetryableSegments = widget.task.hasRetryableSegments;
    final failedCount = widget.task.failedSegments.length;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.error_badge,
                size: 16,
                color: AppTheme.statusError,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '下载失败',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.statusError,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.task.error!,
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.statusError.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 分段失败信息和重试按钮
          if (hasRetryableSegments) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppTheme.accentLight.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.info,
                    size: 12,
                    color: AppTheme.accentLight,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$failedCount 个分段失败，可以尝试重新下载',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.accentLight,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => downloadService.retryFailedSegments(widget.task.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.accentLight.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FluentIcons.refresh,
                            size: 10,
                            color: AppTheme.accentLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '重试',
                            style: FluentTheme.of(context).typography.caption?.copyWith(
                              color: AppTheme.accentLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(IntegratedDownloadService service) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务 "${widget.task.fileName}" 吗？'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
            ),
            onPressed: () {
              service.removeTask(widget.task.id);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  Color _getStatusColor() {
    switch (widget.task.status) {
      case DownloadStatus.pending:
        return AppTheme.statusWarning;
      case DownloadStatus.downloading:
        return AppTheme.accentPrimary;
      case DownloadStatus.paused:
        return AppTheme.textTertiary;
      case DownloadStatus.completed:
        return AppTheme.statusSuccess;
      case DownloadStatus.failed:
        return AppTheme.statusError;
      case DownloadStatus.merging:
        return AppTheme.accentLight;
    }
  }

  String _getStatusText() {
    switch (widget.task.status) {
      case DownloadStatus.pending:
        return '等待中';
      case DownloadStatus.downloading:
        return '下载中';
      case DownloadStatus.paused:
        return '已暂停';
      case DownloadStatus.completed:
        return '已完成';
      case DownloadStatus.failed:
        return '失败';
      case DownloadStatus.merging:
        return '合并中';
    }
  }
}

/// 分段进度条绘制器
class _SegmentProgressPainter extends CustomPainter {
  final List<SegmentInfo> segments;
  final int totalSize;
  
  _SegmentProgressPainter({
    required this.segments,
    required this.totalSize,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (totalSize == 0 || segments.isEmpty) return;
    
    final width = size.width;
    final height = size.height;
    
    // 背景色
    final bgPaint = Paint()
      ..color = AppTheme.bgLayer1
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);
    
    // 绘制每个分段
    for (final segment in segments) {
      final startRatio = segment.startByte / totalSize;
      final endRatio = segment.endByte / totalSize;
      final segmentWidth = (endRatio - startRatio) * width;
      final startX = startRatio * width;
      
      // 计算分段内的进度（确保不超过 1.0，防止回弹）
      final segmentSize = segment.endByte - segment.startByte;
      double progressRatio = 0.0;
      if (segmentSize > 0) {
        progressRatio = (segment.downloadedBytes / segmentSize).clamp(0.0, 1.0);
      }
      final progressWidth = (segmentWidth * progressRatio).clamp(0.0, segmentWidth);
      
      // 选择颜色
      Color color;
      switch (segment.status) {
        case 'completed':
          color = AppTheme.statusSuccess;
          break;
        case 'downloading':
          color = AppTheme.accentPrimary;
          break;
        case 'failed':
          color = AppTheme.statusError;
          break;
        case 'paused':
          color = AppTheme.statusWarning;
          break;
        default:
          color = AppTheme.textTertiary.withValues(alpha: 0.3);
      }
      
      // 绘制已下载部分
      if (progressWidth > 0) {
        final progressPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(startX, 0, progressWidth, height),
          progressPaint,
        );
      }
      
      // 绘制分段边界线
      if (segments.length > 1) {
        final borderPaint = Paint()
          ..color = AppTheme.borderSubtle.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;
        canvas.drawLine(
          Offset(startX + segmentWidth, 0),
          Offset(startX + segmentWidth, height),
          borderPaint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant _SegmentProgressPainter oldDelegate) {
    // 只有在分段数量变化或总大小变化时才重绘
    // 进度更新会通过 CustomPaint 的 rebuild 自动触发
    if (oldDelegate.segments.length != segments.length) return true;
    if (oldDelegate.totalSize != totalSize) return true;
    
    // 检查是否有实质性的进度变化（避免微小波动导致重绘）
    for (int i = 0; i < segments.length; i++) {
      final oldSeg = oldDelegate.segments[i];
      final newSeg = segments[i];
      
      // 状态变化
      if (oldSeg.status != newSeg.status) return true;
      
      // 进度变化超过 0.1%（避免频繁重绘）
      final oldProgress = oldSeg.downloadedBytes / (oldSeg.endByte - oldSeg.startByte);
      final newProgress = newSeg.downloadedBytes / (newSeg.endByte - newSeg.startByte);
      if ((newProgress - oldProgress).abs() > 0.001) return true;
    }
    
    return false;
  }
}

/// 操作按钮组件
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovered 
                  ? widget.color.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _isHovered 
                    ? widget.color.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _isHovered ? widget.color : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 可悬停的URL组件，支持hover动画
class _HoverableUrl extends StatefulWidget {
  final String url;
  final VoidCallback onTap;

  const _HoverableUrl({
    required this.url,
    required this.onTap,
  });

  @override
  State<_HoverableUrl> createState() => _HoverableUrlState();
}

class _HoverableUrlState extends State<_HoverableUrl> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: '点击复制链接',
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 11,
              decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
              decorationColor: AppTheme.textTertiary.withValues(alpha: 0.7),
            ) ?? const TextStyle(),
            child: Text(
              widget.url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
