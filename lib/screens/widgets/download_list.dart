import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 总进度条
        Row(
          children: [
            Expanded(
              child: ProgressBar(
                value: widget.task.progress * 100,
                strokeWidth: 6,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 60,
              child: Text(
                '${(widget.task.progress * 100).toStringAsFixed(1)}%',
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
        Row(
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
          ],
        ),
        const SizedBox(height: 8),
        ...segments.map((segment) => Padding(
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
            ],
          ),
        )),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _buildSpeedInfo() {
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
        const SizedBox(width: 16),
        const Icon(FluentIcons.clock, size: 12),
        const SizedBox(width: 6),
        Text(
          widget.task.formattedRemainingTime,
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${widget.task.formattedDownloadedSize} / ${widget.task.formattedFileSize}',
          style: FluentTheme.of(context).typography.caption?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
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
