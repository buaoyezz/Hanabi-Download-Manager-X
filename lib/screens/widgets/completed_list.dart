import 'dart:io';
import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/integrated_download_service.dart';
import '../../models/download_task.dart';
import '../../theme/app_theme.dart';

class CompletedList extends StatelessWidget {
  const CompletedList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<IntegratedDownloadService>(
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
                  return _CompletedTaskCard(task: task);
                },
              ),
            ),
          ],
        );
      },
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.statusSuccess.withValues(alpha: 0.3),
                  blurRadius: 60,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              FluentIcons.completed,
              size: 40,
              color: AppTheme.statusSuccess.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无已完成任务',
            style: FluentTheme.of(context).typography.subtitle?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '完成的下载任务将显示在这里',
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: AppTheme.textTertiary,
            ),
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
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final downloadService = context.read<IntegratedDownloadService>();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: _isHovered
                ? AppTheme.statusSuccess.withValues(alpha: 0.4)
                : AppTheme.borderSubtle,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered ? AppTheme.shadowMd : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard.withValues(alpha: 0.85),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildStatusIcon(),
                  const SizedBox(width: 14),
                  Expanded(child: _buildTaskInfo()),
                  const SizedBox(width: 12),
                  _buildActions(downloadService),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.statusSuccess.withValues(alpha: 0.2),
            AppTheme.statusSuccess.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.statusSuccess.withValues(alpha: 0.3),
        ),
      ),
      child: Icon(
        FluentIcons.completed,
        color: AppTheme.statusSuccess,
        size: 20,
      ),
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
