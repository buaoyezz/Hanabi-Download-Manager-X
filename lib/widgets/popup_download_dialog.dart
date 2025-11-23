import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../services/integrated_download_service.dart';

// IDM风格的弹窗下载对话框
class PopupDownloadDialog extends StatefulWidget {
  final String url;
  final String? suggestedFilename;
  final String? referer;
  final String? userAgent;
  final Map<String, dynamic>? headers;
  final bool isFromBrowser;

  const PopupDownloadDialog({
    super.key,
    required this.url,
    this.suggestedFilename,
    this.referer,
    this.userAgent,
    this.headers,
    this.isFromBrowser = false,
  });

  @override
  State<PopupDownloadDialog> createState() => _PopupDownloadDialogState();
}

class _PopupDownloadDialogState extends State<PopupDownloadDialog> {
  late TextEditingController _urlController;
  late TextEditingController _fileNameController;
  bool _isLoading = false;
  bool _autoStart = true;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.url);
    _fileNameController = TextEditingController(
      text: widget.suggestedFilename ?? _extractFilenameFromUrl(widget.url),
    );
    
    // 如果是从浏览器来的，自动开始下载
    _autoStart = widget.isFromBrowser;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  String _extractFilenameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        return segments.last;
      }
    } catch (e) {
      // ignore
    }
    return 'download';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 520,
      decoration: BoxDecoration(
        color: FluentTheme.of(context).micaBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FluentTheme.of(context).accentColor.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildContent(),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: FluentTheme.of(context).accentColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              FluentIcons.download,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '新建下载任务',
                  style: FluentTheme.of(context).typography.subtitle?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hanabi Download ManagerX',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: FluentTheme.of(context).typography.caption?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 12),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoLabel('下载链接', FluentIcons.link),
          const SizedBox(height: 8),
          TextBox(
            controller: _urlController,
            placeholder: 'HTTP/HTTPS 下载链接',
            maxLines: 2,
            style: FluentTheme.of(context).typography.body,
          ),
          const SizedBox(height: 16),
          _buildInfoLabel('文件名', FluentIcons.document),
          const SizedBox(height: 8),
          TextBox(
            controller: _fileNameController,
            placeholder: '保存的文件名',
            style: FluentTheme.of(context).typography.body,
          ),
          const SizedBox(height: 16),
          Checkbox(
            checked: _autoStart,
            onChanged: (value) => setState(() => _autoStart = value ?? true),
            content: const Text('立即开始下载'),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  FluentIcons.info,
                  size: 14,
                  color: FluentTheme.of(context).accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '支持多线程下载、断点续传、速度限制',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: FluentTheme.of(context).accentColor,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: FluentTheme.of(context).accentColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: FluentTheme.of(context).typography.body?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Button(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _isLoading ? null : _handleDownload,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
          ),
        ],
      ),
    );
  }

  Future<void> _handleDownload() async {
    final url = _urlController.text.trim();
    final filename = _fileNameController.text.trim();

    if (url.isEmpty || filename.isEmpty) {
      await _showError('请填写完整信息');
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      await _showError('请输入有效的 HTTP/HTTPS 链接');
      return;
    }

    setState(() => _isLoading = true);

    try {
      context.read<IntegratedDownloadService>().addTask(url, filename);
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await _showError('添加任务失败: $e');
      }
    }
  }

  Future<void> _showError(String message) async {
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
}
