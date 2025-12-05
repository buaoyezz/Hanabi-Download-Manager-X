import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/integrated_download_service.dart';
import '../../models/download_task.dart';

class DownloadList extends StatelessWidget {
  const DownloadList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<IntegratedDownloadService>(
      builder: (context, downloadService, child) {
        final activeTasks = downloadService.tasks
            .where((t) => t.status != DownloadStatus.completed)
            .toList();

        if (activeTasks.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: activeTasks.length,
          itemBuilder: (context, index) {
            final task = activeTasks[index];
            return _DownloadTaskCard(task: task);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.download,
              size: 48,
              color: FluentTheme.of(context).accentColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无下载任务',
            style: FluentTheme.of(context).typography.subtitle?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角"新建任务"按钮开始下载',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
            ),
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
  bool _isHovered = false;
  bool _isSegmentsExpanded = false;
  bool _showAllSegments = false;
  int _maxVisibleSegments = 5;
  
  @override
  void initState() {
    super.initState();
    _loadSegmentsExpandedSetting();
  }
  
  Future<void> _loadSegmentsExpandedSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultExpanded = prefs.getBool('segments_default_expanded') ?? false;
    final maxVisible = prefs.getInt('segments_max_visible') ?? 5;
    if (mounted) {
      setState(() {
        _isSegmentsExpanded = defaultExpanded;
        _maxVisibleSegments = maxVisible;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<IntegratedDownloadService>();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered
                ? FluentTheme.of(context).accentColor.withValues(alpha: 0.5)
                : FluentTheme.of(context).resources.cardStrokeColorDefault,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: FluentTheme.of(context).accentColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatusIcon(),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTaskInfo()),
                      _buildActionButtons(downloadService),
                    ],
                  ),
                  const SizedBox(height: 16),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getStatusIcon(),
        color: _getStatusColor(),
        size: 24,
      ),
    );
  }

  Widget _buildTaskInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.task.fileName,
          style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          widget.task.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _getStatusText(),
        style: FluentTheme.of(context).typography.caption?.copyWith(
          color: _getStatusColor(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButtons(IntegratedDownloadService service) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.task.status == DownloadStatus.pending ||
            widget.task.status == DownloadStatus.paused)
          IconButton(
            icon: const Icon(FluentIcons.play, size: 16),
            onPressed: () => service.startTask(widget.task.id),
          ),
        if (widget.task.status == DownloadStatus.downloading)
          IconButton(
            icon: const Icon(FluentIcons.pause, size: 16),
            onPressed: () => service.pauseTask(widget.task.id),
          ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(FluentIcons.delete, size: 16),
          onPressed: () => _confirmDelete(service),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    // 检查是否是未知文件大小（fileSize = null 或 0）
    final isUnknownSize = (widget.task.fileSize == null || widget.task.fileSize == 0) && 
                          widget.task.status == DownloadStatus.downloading;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 总进度条
        Row(
          children: [
            Expanded(
              child: isUnknownSize
                  ? const ProgressBar(
                      strokeWidth: 6,
                      // 不设置 value 就是 indeterminate 模式（流动动画）
                    )
                  : ProgressBar(
                      value: widget.task.progress * 100,
                      strokeWidth: 6,
                    ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 60,
              child: Text(
                isUnknownSize 
                    ? '未知'
                    : '${(widget.task.progress * 100).toStringAsFixed(1)}%',
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        // 分段进度条
        if (widget.task.segments != null && widget.task.segments!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSegmentsProgress(),
        ],
      ],
    );
  }

  Widget _buildSegmentsProgress() {
    final segments = widget.task.segments!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isSegmentsExpanded = !_isSegmentsExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.split_object,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  '分段下载 (${segments.length})',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _isSegmentsExpanded ? FluentIcons.chevron_up : FluentIcons.chevron_down,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        if (_isSegmentsExpanded) ...[
          const SizedBox(height: 8),
          // 显示前N个分段或全部分段
          ...(_showAllSegments ? segments : segments.take(_maxVisibleSegments)).map((segment) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    '分段 ${segment.index + 1}',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                  ),
                ),
                Expanded(
                  child: ProgressBar(
                    value: segment.progress * 100,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${_formatBytes(segment.downloadedBytes)}/${_formatBytes(segment.endByte - segment.startByte)}',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: Text(
                    _formatSpeed(segment.speed),
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          )),
          // 显示"显示更多/收起"按钮
          if (segments.length > _maxVisibleSegments) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showAllSegments = !_showAllSegments;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAllSegments ? FluentIcons.chevron_up_small : FluentIcons.chevron_down_small,
                      size: 12,
                      color: FluentTheme.of(context).accentColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showAllSegments 
                          ? '收起 (隐藏 ${segments.length - _maxVisibleSegments} 个分段)'
                          : '显示更多 (还有 ${segments.length - _maxVisibleSegments} 个分段)',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: FluentTheme.of(context).accentColor.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
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
    
    return Row(
      children: [
        const Icon(FluentIcons.speed_high, size: 12),
        const SizedBox(width: 6),
        Text(
          widget.task.formattedSpeed,
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        if (!isUnknownSize) ...[
          const SizedBox(width: 16),
          const Icon(FluentIcons.clock, size: 12),
          const SizedBox(width: 6),
          Text(
            widget.task.formattedRemainingTime,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
        const SizedBox(width: 16),
        Text(
          isUnknownSize
              ? '${widget.task.formattedDownloadedSize} / 未知大小'
              : '${widget.task.formattedDownloadedSize} / ${widget.task.formattedFileSize}',
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.error_badge,
            size: 16,
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下载失败',
                  style: FluentTheme.of(context).typography.body?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.task.error!,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: Colors.red.withValues(alpha: 0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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

  IconData _getStatusIcon() {
    switch (widget.task.status) {
      case DownloadStatus.pending:
        return FluentIcons.clock;
      case DownloadStatus.downloading:
        return FluentIcons.download;
      case DownloadStatus.paused:
        return FluentIcons.pause;
      case DownloadStatus.completed:
        return FluentIcons.completed;
      case DownloadStatus.failed:
        return FluentIcons.error_badge;
    }
  }

  Color _getStatusColor() {
    switch (widget.task.status) {
      case DownloadStatus.pending:
        return Colors.orange;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.paused:
        return Colors.grey[100];
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
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
    }
  }
}
