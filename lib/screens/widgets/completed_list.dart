import 'dart:io';
import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/integrated_download_service.dart';
import '../../models/download_task.dart';
import '../../theme/app_theme.dart';
import '../../widgets/file_icon_widget.dart';
import '../../widgets/animated_card.dart';

class CompletedList extends StatelessWidget {
  const CompletedList({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Consumer<IntegratedDownloadService>(
        builder: (context, downloadService, child) {
          final completedTasks = downloadService.tasks
              .where((t) => t.status == DownloadStatus.completed)
              .toList();

          if (completedTasks.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              _buildHeader(context, completedTasks.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: completedTasks.length,
                  itemBuilder: (context, index) {
                    final task = completedTasks[index];
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300 + (index * 80)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: _CompletedTaskCard(task: task),
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

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.statusSuccess.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              FluentIcons.completed,
              size: 14,
              color: AppTheme.statusSuccess,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '已完成',
            style: FluentTheme.of(context).typography.body?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.statusSuccess.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            ),
            child: Text(
              '$count',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.statusSuccess,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
          Button(
            onPressed: () async {
              final folder = Directory("${Platform.environment['USERPROFILE']}\\Downloads").path;
              final target = folder.replaceAll('/', '\\');
              await Process.run('explorer', [target]);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.folder_open, size: 12),
                SizedBox(width: 6),
                Text('打开文件夹', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
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
                          color: AppTheme.statusSuccess.withValues(alpha: 0.3 * value),
                          blurRadius: 60 * value,
                          spreadRadius: 10 * value,
                        ),
                      ],
                    ),
                    child: Icon(
                      FluentIcons.completed,
                      size: 40,
                      color: AppTheme.statusSuccess.withValues(alpha: 0.6),
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
                      '暂无已完成任务',
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
                      '完成的下载任务将显示在这里',
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

class _CompletedTaskCard extends StatefulWidget {
  final DownloadTask task;

  const _CompletedTaskCard({required this.task});

  @override
  State<_CompletedTaskCard> createState() => _CompletedTaskCardState();
}

class _CompletedTaskCardState extends State<_CompletedTaskCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<IntegratedDownloadService>();

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      backgroundColor: AppTheme.surfaceCard.withValues(alpha: 0.85),
      hoverColor: AppTheme.surfaceCard.withValues(alpha: 0.95),
      borderColor: AppTheme.borderSubtle,
      hoverBorderColor: AppTheme.statusSuccess.withValues(alpha: 0.4),
      borderRadius: AppTheme.radiusLg,
      enableGlowAnimation: true,
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 14),
              Expanded(child: _buildTaskInfo()),
              const SizedBox(width: 12),
              _buildActions(downloadService),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildStatistics(),
            ),
            crossFadeState: _isExpanded 
                ? CrossFadeState.showSecond 
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatistics() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                FluentIcons.chart,
                size: 14,
                color: AppTheme.accentPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                '下载统计',
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatsGrid(),
        ],
      ),
    );
  }
  
  Widget _buildStatsGrid() {
    final stats = [
      // 第一行：重要统计
      _StatItem(
        icon: FluentIcons.speed_high,
        label: '峰值速度',
        value: widget.task.formattedPeakSpeed,
        color: AppTheme.statusSuccess,
      ),
      _StatItem(
        icon: FluentIcons.timeline_progress,
        label: '平均速度',
        value: widget.task.formattedAverageSpeed,
        color: AppTheme.accentPrimary,
      ),
      _StatItem(
        icon: FluentIcons.clock,
        label: '用时',
        value: widget.task.formattedDuration,
        color: AppTheme.statusWarning,
      ),
      // 第二行：详细信息
      _StatItem(
        icon: FluentIcons.split,
        label: '分段数',
        value: '${widget.task.segmentCount ?? 0}',
        color: AppTheme.textSecondary,
      ),
      _StatItem(
        icon: FluentIcons.processing,
        label: '线程数',
        value: '${widget.task.threadCount ?? 0}',
        color: AppTheme.textSecondary,
      ),
      _StatItem(
        icon: FluentIcons.server,
        label: '下载核心',
        value: widget.task.downloadCore ?? 'NSF-X',
        color: AppTheme.textSecondary,
      ),
    ];
    
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: stats,
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
        Row(
          children: [
            Icon(
              FluentIcons.check_mark,
              size: 10,
              color: AppTheme.statusSuccess,
            ),
            const SizedBox(width: 4),
            Text(
              widget.task.formattedFileSize,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
            if (widget.task.endTime != null) ...[
              Container(
                width: 1,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppTheme.borderSubtle,
              ),
              Text(
                _formatDate(widget.task.endTime!),
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActions(IntegratedDownloadService service) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: FluentIcons.play,
          label: '运行',
          color: AppTheme.accentPrimary,
          onPressed: () => _runFile(widget.task.filePath),
        ),
        const SizedBox(width: 6),
        _ActionButton(
          icon: FluentIcons.folder_open,
          label: '位置',
          color: AppTheme.textSecondary,
          onPressed: () => _openFileLocation(widget.task.filePath),
        ),
        const SizedBox(width: 6),
        _IconActionButton(
          icon: _isExpanded ? FluentIcons.chevron_up : FluentIcons.chevron_down,
          color: AppTheme.textSecondary,
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
        ),
        const SizedBox(width: 6),
        _IconActionButton(
          icon: FluentIcons.delete,
          color: AppTheme.statusError,
          onPressed: () => _confirmDelete(service),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    
    return '${date.month}/${date.day}';
  }

  void _runFile(String? filePath) async {
    if (filePath == null) {
      _showMessage('文件路径不存在');
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _showMessage('文件不存在');
        return;
      }

      final safePath = filePath.replaceAll('/', '\\');
      await Process.start('cmd', ['/c', 'start', '', safePath], runInShell: true);
    } catch (e) {
      _showMessage('运行文件失败: $e');
    }
  }

  void _openFileLocation(String? filePath) async {
    if (filePath == null) {
      _showMessage('文件路径不存在');
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _showMessage('文件不存在');
        return;
      }

      final safePath = filePath.replaceAll('/', '\\');
      await Process.run('explorer', ['/select,', safePath]);
    } catch (e) {
      _showMessage('打开文件位置失败: $e');
    }
  }

  void _showMessage(String message) {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('提示'),
        content: Text(message),
        severity: InfoBarSeverity.warning,
        onClose: close,
      ),
    );
  }

  void _confirmDelete(IntegratedDownloadService service) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要从列表中删除 "${widget.task.fileName}" 吗？\n文件不会被删除。'),
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
}

/// 带文字的操作按钮
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered 
                ? widget.color.withValues(alpha: 0.15)
                : AppTheme.bgLayer2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: _isHovered 
                  ? widget.color.withValues(alpha: 0.3)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 12,
                color: _isHovered ? widget.color : AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  color: _isHovered ? widget.color : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 统计项组件
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 11,
                color: color,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// 纯图标操作按钮
class _IconActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<_IconActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 28,
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
            size: 12,
            color: _isHovered ? widget.color : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
