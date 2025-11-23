import 'dart:io';
import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/integrated_download_service.dart';
import '../../models/download_task.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.completed, size: 16),
          const SizedBox(width: 8),
          Text(
            '已完成 ($count)',
            style: FluentTheme.of(context).typography.bodyStrong,
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
                Icon(FluentIcons.folder_open, size: 14),
                SizedBox(width: 6),
                Text('打开文件夹'),
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.completed,
              size: 48,
              color: Colors.green.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无已完成任务',
            style: FluentTheme.of(context).typography.subtitle?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '完成的下载任务将显示在这里',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
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
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isHovered
                ? Colors.green.withValues(alpha: 0.5)
                : FluentTheme.of(context).resources.cardStrokeColorDefault,
            width: _isHovered ? 1.5 : 1,
          ),
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
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      FluentIcons.completed,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Button(
                    onPressed: () => _runFile(widget.task.filePath),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.play, size: 14),
                        SizedBox(width: 6),
                        Text('运行'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: () => _openFileLocation(widget.task.filePath),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.folder_open, size: 14),
                        SizedBox(width: 6),
                        Text('打开位置'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(FluentIcons.delete, size: 16),
                    onPressed: () => _confirmDelete(downloadService),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
