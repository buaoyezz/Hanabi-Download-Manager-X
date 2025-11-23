import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/integrated_download_service.dart';

class AddDownloadDialog extends StatefulWidget {
  const AddDownloadDialog({super.key});

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  final _urlController = TextEditingController();
  final _fileNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: FluentTheme.of(context).accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              FluentIcons.add,
              size: 16,
              color: FluentTheme.of(context).accentColor,
            ),
          ),
          const SizedBox(width: 12),
          const Text('新建下载任务'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoLabel(
                label: '下载链接',
                child: TextBox(
                  controller: _urlController,
                  placeholder: '请输入 HTTP/HTTPS 下载链接',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(FluentIcons.link, size: 16),
                  ),
                  maxLines: 2,
                  style: FluentTheme.of(context).typography.body,
                ),
              ),
              const SizedBox(height: 20),
              InfoLabel(
                label: '文件名',
                child: TextBox(
                  controller: _fileNameController,
                  placeholder: '请输入保存的文件名（含扩展名）',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(FluentIcons.document, size: 16),
                  ),
                  style: FluentTheme.of(context).typography.body,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: FluentTheme.of(context).accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.info,
                      size: 16,
                      color: FluentTheme.of(context).accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '支持多线程下载，自动断点续传',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: FluentTheme.of(context).accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Button(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('添加中...'),
                  ],
                )
              : const Text('开始下载'),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (_urlController.text.isEmpty || _fileNameController.text.isEmpty) {
      await _showErrorDialog('请填写完整信息');
      return;
    }

    if (!_urlController.text.startsWith('http://') &&
        !_urlController.text.startsWith('https://')) {
      await _showErrorDialog('请输入有效的 HTTP/HTTPS 链接');
      return;
    }

    setState(() => _isLoading = true);

    try {
      context.read<IntegratedDownloadService>().addTask(
            _urlController.text,
            _fileNameController.text,
          );
      
      if (mounted) {
        Navigator.pop(context);
        _showSuccessMessage();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await _showErrorDialog('添加任务失败: $e');
      }
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage() {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('任务已添加'),
        content: const Text('下载任务已成功添加到队列'),
        severity: InfoBarSeverity.success,
        onClose: close,
      ),
    );
  }
}
