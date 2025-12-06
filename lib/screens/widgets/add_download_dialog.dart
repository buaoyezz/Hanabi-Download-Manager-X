import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/integrated_download_service.dart';
import '../../theme/app_theme.dart';

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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accentPrimary.withValues(alpha: 0.2),
                  AppTheme.accentPrimary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.accentPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              FluentIcons.add,
              size: 18,
              color: AppTheme.accentLight,
            ),
          ),
          const SizedBox(width: 14),
          const Text('新建下载任务'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputField(
                context,
                label: '下载链接',
                controller: _urlController,
                placeholder: '请输入 HTTP/HTTPS 下载链接',
                icon: FluentIcons.link,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                context,
                label: '文件名',
                controller: _fileNameController,
                placeholder: '请输入保存的文件名（含扩展名）',
                icon: FluentIcons.document,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentPrimary.withValues(alpha: 0.1),
                      AppTheme.accentPrimary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        FluentIcons.info,
                        size: 12,
                        color: AppTheme.accentLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '支持多线程下载，自动断点续传',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.accentLight,
                          fontSize: 12,
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
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.download, size: 14),
                    SizedBox(width: 6),
                    Text('开始下载'),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FluentTheme.of(context).typography.body?.copyWith(
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgLayer2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: TextBox(
            controller: controller,
            placeholder: placeholder,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(icon, size: 14, color: AppTheme.textTertiary),
            ),
            maxLines: maxLines,
            style: FluentTheme.of(context).typography.body,
            decoration: WidgetStateProperty.all(const BoxDecoration()),
          ),
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
