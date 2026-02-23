import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/integrated_download_service.dart';
import '../../models/download_task.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

import '../../widgets/animated_notifications.dart';

enum _DuplicateAction {
  useExisting,
  addNew,
  cancel,
}

class AddDownloadDialog extends StatefulWidget {
  final String? initialUrl;
  final String? initialFileName;

  const AddDownloadDialog({
    super.key,
    this.initialUrl,
    this.initialFileName,
  });

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController();
  final _fileNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showAdvanced = false;
  String? _parsedFileName;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  AppLocalizations get t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      _urlController.text = widget.initialUrl!.trim();
    }
    if (widget.initialFileName != null && widget.initialFileName!.trim().isNotEmpty) {
      _fileNameController.text = widget.initialFileName!.trim();
    }
    // 监听 URL 变化，自动解析文件名
    _urlController.addListener(_onUrlChanged);
    if (_urlController.text.trim().isNotEmpty) {
      _onUrlChanged();
    }
    
    // 初始化动画
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _parsedFileName = null);
      return;
    }
    
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      if (path.isNotEmpty) {
        final segments = path.split('/');
        final lastSegment = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
        if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
          // 解码 URL 编码的文件名
          final decodedName = Uri.decodeComponent(lastSegment);
          setState(() => _parsedFileName = decodedName);
          // 如果用户没有手动输入文件名，自动填充
          if (_fileNameController.text.isEmpty) {
            _fileNameController.text = decodedName;
          }
        }
      }
    } catch (e) {
      // 忽略解析错误
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _fileNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ContentDialog(
        constraints: const BoxConstraints(maxWidth: 600),
        style: ContentDialogThemeData(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderSubtle.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
        ),
        title: _buildHeader(context),
        content: _buildContent(context),
        actions: _buildActions(context),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 图标容器
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accentPrimary.withValues(alpha: 0.2),
                  AppTheme.accentLight.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              FluentIcons.download,
              size: 22,
              color: AppTheme.accentLight,
            ),
          ),
          const SizedBox(width: 16),
          // 标题和描述
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.addDownloadTitle,
                  style: FluentTheme.of(context).typography.subtitle?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.addDownloadSubtitle,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // URL 输入框
            _buildUrlInput(context),
            const SizedBox(height: 20),
            // 自动解析的文件名提示
            if (_parsedFileName != null && _fileNameController.text.isEmpty)
              _buildParsedFileNameHint(context),
            // 高级选项切换
            _buildAdvancedToggle(context),
            // 高级选项内容
            if (_showAdvanced) ...[
              const SizedBox(height: 16),
              _buildFileNameInput(context),
            ],
            const SizedBox(height: 20),
            // 功能提示卡片
            _buildFeatureCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              FluentIcons.link,
              size: 14,
              color: AppTheme.accentLight,
            ),
            const SizedBox(width: 6),
            Text(
              t.addDownloadUrlLabel,
              style: FluentTheme.of(context).typography.body?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.statusError.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                t.addDownloadRequiredBadge,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.statusError,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgLayer2.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _urlController.text.isNotEmpty
                  ? AppTheme.accentPrimary.withValues(alpha: 0.4)
                  : AppTheme.borderSubtle.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: TextBox(
                controller: _urlController,
                placeholder: t.addDownloadUrlPlaceholder,
                maxLines: 3,
                minLines: 2,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontSize: 13,
                  height: 1.5,
                ),
                placeholderStyle: FluentTheme.of(context).typography.body?.copyWith(
                  color: AppTheme.textTertiary.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                decoration: WidgetStateProperty.all(
                  BoxDecoration(
                    color: Colors.transparent,
                  ),
                ),
                padding: const EdgeInsets.all(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParsedFileNameHint(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.statusSuccess.withValues(alpha: 0.1),
            AppTheme.statusSuccess.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.statusSuccess.withValues(alpha: 0.3),
          width: 1,
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
            child: const Icon(
              FluentIcons.check_mark,
              size: 14,
              color: AppTheme.statusSuccess,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.addDownloadParsedFileNameTitle,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.statusSuccess,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _parsedFileName!,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedToggle(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _showAdvanced
              ? AppTheme.accentPrimary.withValues(alpha: 0.1)
              : AppTheme.bgLayer2.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _showAdvanced
                ? AppTheme.accentPrimary.withValues(alpha: 0.3)
                : AppTheme.borderSubtle.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _showAdvanced ? FluentIcons.chevron_down : FluentIcons.chevron_right,
              size: 12,
              color: _showAdvanced ? AppTheme.accentLight : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              t.addDownloadAdvancedToggle,
              style: FluentTheme.of(context).typography.body?.copyWith(
                color: _showAdvanced ? AppTheme.accentLight : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              _showAdvanced ? t.addDownloadAdvancedExpandedHint : t.addDownloadAdvancedCollapsedHint,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileNameInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              FluentIcons.document,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              t.addDownloadFileNameLabel,
              style: FluentTheme.of(context).typography.body?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                t.addDownloadOptionalBadge,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgLayer2.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.borderSubtle.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: TextBox(
            controller: _fileNameController,
            placeholder: t.addDownloadFileNamePlaceholder,
            style: FluentTheme.of(context).typography.body?.copyWith(
              fontSize: 13,
            ),
            placeholderStyle: FluentTheme.of(context).typography.body?.copyWith(
              color: AppTheme.textTertiary.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            decoration: WidgetStateProperty.all(
              const BoxDecoration(
                color: Colors.transparent,
              ),
            ),
            padding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentPrimary.withValues(alpha: 0.08),
            AppTheme.accentLight.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentPrimary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  FluentIcons.lightbulb,
                  size: 12,
                  color: AppTheme.accentLight,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.addDownloadFeatureTitle,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  color: AppTheme.accentLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(context, FluentIcons.split_object, t.addDownloadFeature1Title, t.addDownloadFeature1Desc),
          const SizedBox(height: 8),
          _buildFeatureItem(context, FluentIcons.sync, t.addDownloadFeature2Title, t.addDownloadFeature2Desc),
          const SizedBox(height: 8),
          _buildFeatureItem(context, FluentIcons.processing, t.addDownloadFeature3Title, t.addDownloadFeature3Desc),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppTheme.accentLight.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                description,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      Button(
        onPressed: _isLoading ? null : () => Navigator.pop(context),
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
        child: Text(t.addDownloadCancelButton),
      ),
      FilledButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.isDisabled) {
              return AppTheme.accentPrimary.withValues(alpha: 0.3);
            }
            if (states.isHovered) {
              return AppTheme.accentLight;
            }
            return AppTheme.accentPrimary;
          }),
        ),
        child: _isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(t.addDownloadAdding),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.download, size: 16),
                  SizedBox(width: 8),
                  Text(t.addDownloadStart),
                ],
              ),
      ),
    ];
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
      default:
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

  Future<void> _handleSubmit() async {
    // 验证 URL
    if (_urlController.text.trim().isEmpty) {
      await _showErrorDialog(t.addDownloadErrorMissingUrl);
      return;
    }

    final url = _urlController.text.trim();
    // 允许测试URL或正常的HTTP/HTTPS链接
    if (!url.startsWith('test_task_') && 
        !url.startsWith('http://') && 
        !url.startsWith('https://')) {
      await _showErrorDialog(t.addDownloadErrorInvalidUrl);
      return;
    }

    // 获取文件名：优先使用用户输入，否则使用自动解析的，最后使用默认名称
    String fileName = _fileNameController.text.trim();
    if (fileName.isEmpty) {
      fileName = _parsedFileName ?? 'download_${DateTime.now().millisecondsSinceEpoch}';
    }

    final downloadService = context.read<IntegratedDownloadService>();
    final duplicate = downloadService.findDuplicateTask(url);
    if (duplicate != null) {
      final action = await _showDuplicateDialog(duplicate);
      if (!mounted) return;
      if (action == _DuplicateAction.cancel) {
        return;
      }
      if (action == _DuplicateAction.useExisting) {
        if (duplicate.status == DownloadStatus.paused ||
            duplicate.status == DownloadStatus.failed ||
            duplicate.status == DownloadStatus.pending) {
          await downloadService.resumeTask(duplicate.id);
        }
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      downloadService.addTask(url, fileName);
      
      if (mounted) {
        Navigator.pop(context);
        _showSuccessMessage(fileName);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await _showErrorDialog(t.addDownloadErrorAddFailed(e.toString()));
      }
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.statusError.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
            child: const Icon(
              FluentIcons.error_badge,
              size: 16,
              color: AppTheme.statusError,
            ),
          ),
          const SizedBox(width: 12),
          Text(t.addDownloadErrorTitle),
        ],
      ),
        content: Text(
          message,
          style: FluentTheme.of(context).typography.body?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(t.addDownloadErrorConfirm),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String fileName) {
    if (mounted) {
      NotificationManager.of(context)?.showSuccess(
        t.addDownloadSuccessTitle,
        message: t.addDownloadSuccessMessage(fileName),
      );
    }
  }

}
