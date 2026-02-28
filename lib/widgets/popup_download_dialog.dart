import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../services/integrated_download_service.dart';
import '../models/download_task.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/fluent_icons.dart' as CustomIcons;

enum _DuplicateAction {
  useExisting,
  addNew,
  cancel,
}

// 弹窗下载对话框
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
  String _defaultFileName = 'download';

  AppLocalizations get t => AppLocalizations.of(context)!;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localized = AppLocalizations.of(context)?.popupDownloadDefaultFileName;
    if (localized != null && localized.isNotEmpty && localized != _defaultFileName) {
      final previous = _defaultFileName;
      _defaultFileName = localized;
      if (_fileNameController.text == previous) {
        _fileNameController.text = localized;
      }
    }
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
    return _defaultFileName;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 520,
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: AppTheme.shadowLg,
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
        color: AppTheme.bgLayer2.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusLg),
          topRight: Radius.circular(AppTheme.radiusLg),
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderSubtle.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(CustomIcons.FluentIcons.download,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.popupDownloadTitle,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.appTitle,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _CloseButton(onPressed: () => Navigator.of(context).pop()),
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
          _buildInfoLabel(t.popupDownloadLinkLabel, CustomIcons.FluentIcons.link),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgLayer2,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: TextBox(
              controller: _urlController,
              placeholder: t.popupDownloadLinkPlaceholder,
              maxLines: 2,
              style: FluentTheme.of(context).typography.body,
              decoration: WidgetStateProperty.all(const BoxDecoration()),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoLabel(t.popupDownloadFileNameLabel, CustomIcons.FluentIcons.document),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgLayer2,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: TextBox(
              controller: _fileNameController,
              placeholder: t.popupDownloadFileNamePlaceholder,
              style: FluentTheme.of(context).typography.body,
              decoration: WidgetStateProperty.all(const BoxDecoration()),
            ),
          ),
          const SizedBox(height: 16),
          Checkbox(
            checked: _autoStart,
            onChanged: (value) => setState(() => _autoStart = value ?? true),
            content: Text(
              t.popupDownloadAutoStart,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
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
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(CustomIcons.FluentIcons.info,
                    size: 12,
                    color: AppTheme.accentLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.popupDownloadFeatureHint,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.accentLight,
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
        Icon(icon, size: 13, color: AppTheme.accentLight),
        const SizedBox(width: 6),
        Text(
          label,
          style: FluentTheme.of(context).typography.body?.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 13,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusLg),
          bottomRight: Radius.circular(AppTheme.radiusLg),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.borderSubtle.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Button(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(t.popupDownloadCancel),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _isLoading ? null : _handleDownload,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: ProgressRing(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(t.popupDownloadAdding),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.download, size: 12),
                        SizedBox(width: 6),
                        Text(t.popupDownloadStart),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return t.downloadStatusDownloading;
      case DownloadStatus.paused:
        return t.downloadStatusPaused;
      case DownloadStatus.completed:
        return t.downloadStatusCompleted;
      case DownloadStatus.failed:
        return t.downloadStatusFailed;
      case DownloadStatus.merging:
        return t.downloadStatusMerging;
      case DownloadStatus.pending:
        return t.downloadStatusPending;
    }
  }

  Future<_DuplicateAction> _showDuplicateDialog(DownloadTask task) async {
    final statusLabel = _getStatusLabel(task.status);
    final result = await showDialog<_DuplicateAction>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.downloadDuplicateTitle),
        content: Text(t.downloadDuplicateMessage(task.fileName, statusLabel)),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, _DuplicateAction.cancel),
            child: Text(t.downloadDuplicateCancelButton),
          ),
          Button(
            onPressed: () => Navigator.pop(context, _DuplicateAction.addNew),
            child: Text(t.downloadDuplicateAddNewButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _DuplicateAction.useExisting),
            child: Text(t.downloadDuplicateUseExistingButton),
          ),
        ],
      ),
    );
    return result ?? _DuplicateAction.cancel;
  }

  Future<void> _handleDownload() async {
    final url = _urlController.text.trim();
    final filename = _fileNameController.text.trim();

    if (url.isEmpty || filename.isEmpty) {
      await _showError(t.popupDownloadErrorMissingInfo);
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      await _showError(t.popupDownloadErrorInvalidUrl);
      return;
    }

    try {
      final downloadService = context.read<IntegratedDownloadService>();
      final duplicate = downloadService.findDuplicateTask(url);
      if (duplicate != null) {
        final action = await _showDuplicateDialog(duplicate);
        if (!mounted) return;
        if (action == _DuplicateAction.cancel) {
          setState(() => _isLoading = false);
          return;
        }
        if (action == _DuplicateAction.useExisting) {
          if (duplicate.status == DownloadStatus.paused ||
              duplicate.status == DownloadStatus.failed ||
              duplicate.status == DownloadStatus.pending) {
            await downloadService.resumeTask(duplicate.id);
          }
          if (mounted) {
            Navigator.of(context).pop(true);
          }
          return;
        }
      }

      setState(() => _isLoading = true);

      // 传递浏览器的身份验证信息
      downloadService.addTask(
        url, 
        filename,
        referer: widget.referer,
        userAgent: widget.userAgent,
        cookies: widget.headers?['Cookie'] as String?,
        headers: widget.headers,
      );
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await _showError(t.popupDownloadErrorAddFailed(e.toString()));
      }
    }
  }

  Future<void> _showError(String message) async {
    await showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.popupDownloadErrorTitle),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.popupDownloadErrorConfirm),
          ),
        ],
      ),
    );
  }
}


/// 关闭按钮
class _CloseButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _CloseButton({required this.onPressed});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
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
                ? AppTheme.statusError.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            CustomIcons.FluentIcons.chrome_close,
            size: 10,
            color: _isHovered ? AppTheme.statusError : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
