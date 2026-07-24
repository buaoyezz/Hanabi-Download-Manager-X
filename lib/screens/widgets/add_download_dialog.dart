import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/download_intent.dart';
import '../../models/download_task.dart';
import '../../services/integrated_download_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_notifications.dart';
import '../../widgets/smooth_scroll_wrapper.dart';

enum _DuplicateAction {
  useExisting,
  addNew,
  cancel,
}

class AddDownloadDialog extends StatefulWidget {
  final String? initialUrl;
  final String? initialFileName;
  final VoidCallback? onMuteClipboardForSession;

  const AddDownloadDialog({
    super.key,
    this.initialUrl,
    this.initialFileName,
    this.onMuteClipboardForSession,
  });

  @override
  State<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends State<AddDownloadDialog> {
  final _urlController = TextEditingController();
  final _fileNameController = TextEditingController();
  final _urlFocusNode = FocusNode();
  final _fileNameFocusNode = FocusNode();

  bool _isLoading = false;
  bool _showAdvanced = false;
  bool _hasUserEditedFileName = false;
  bool _isUpdatingFileNameProgrammatically = false;
  String? _parsedFileName;
  String? _urlError;
  String? _lastSuggestedFileName;

  AppLocalizations get t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty) {
      _urlController.text = widget.initialUrl!.trim();
    }
    if (widget.initialFileName != null &&
        widget.initialFileName!.trim().isNotEmpty) {
      _fileNameController.text = widget.initialFileName!.trim();
      _hasUserEditedFileName = true;
    }

    _urlController.addListener(_onUrlChanged);
    _fileNameController.addListener(_onFileNameChanged);
    if (_urlController.text.trim().isNotEmpty) {
      _onUrlChanged();
    }
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      final shouldClearSuggestedName = !_hasUserEditedFileName &&
          (_fileNameController.text.trim().isEmpty ||
              _fileNameController.text.trim() == _lastSuggestedFileName);
      setState(() {
        _parsedFileName = null;
        _urlError = null;
      });
      if (shouldClearSuggestedName) {
        _setFileNameFromSuggestion('');
      }
      _lastSuggestedFileName = null;
      return;
    }

    final nextSuggestedName = DownloadIntent.parse(url).suggestedFileName();
    final previousSuggestion = _lastSuggestedFileName;
    final currentFileName = _fileNameController.text.trim();
    final shouldApplySuggestion = currentFileName.isEmpty ||
        !_hasUserEditedFileName ||
        (previousSuggestion != null && currentFileName == previousSuggestion);

    setState(() {
      _parsedFileName = nextSuggestedName;
      _urlError = null;
    });
    _lastSuggestedFileName = nextSuggestedName;

    if (shouldApplySuggestion) {
      _setFileNameFromSuggestion(nextSuggestedName ?? '');
    }
  }

  void _onFileNameChanged() {
    if (_isUpdatingFileNameProgrammatically) return;

    final text = _fileNameController.text.trim();
    final suggestion = _lastSuggestedFileName?.trim();
    _hasUserEditedFileName = text.isNotEmpty && text != (suggestion ?? '');
  }

  void _setFileNameFromSuggestion(String value) {
    _isUpdatingFileNameProgrammatically = true;
    _fileNameController.text = value;
    _fileNameController.selection =
        TextSelection.collapsed(offset: _fileNameController.text.length);
    _isUpdatingFileNameProgrammatically = false;
    _hasUserEditedFileName = false;
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _fileNameController.removeListener(_onFileNameChanged);
    _urlController.dispose();
    _fileNameController.dispose();
    _urlFocusNode.dispose();
    _fileNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final availableWidth =
        (size.width - 48).clamp(0.0, double.infinity).toDouble();
    final dialogWidth = availableWidth.clamp(0.0, 480.0).toDouble();
    final dialogMaxHeight = (size.height - 48).clamp(0.0, 720.0).toDouble();
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: BoxConstraints(
        minWidth: dialogWidth,
        maxWidth: dialogWidth,
        maxHeight: dialogMaxHeight,
      ),
      style: ContentDialogThemeData(
        titleStyle: theme.typography.subtitle?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        actionsDecoration: BoxDecoration(
          color: theme.resources.layerFillColorAlt,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(AppTheme.radiusLg),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      ),
      title: Text(t.addDownloadTitle),
      content: _buildContent(context),
      actions: _buildActions(),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = FluentTheme.of(context);

    return SmoothSingleChildScrollView(
      config: SmoothScrollConfig.fast,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.addDownloadSubtitle,
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _buildUrlInput(context),
          AnimatedSwitcher(
            duration: theme.fastAnimationDuration,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildUrlFeedback(context),
          ),
          const SizedBox(height: 16),
          _buildAdvancedOptions(context),
        ],
      ),
    );
  }

  InlineSpan _requiredLabel(BuildContext context, String label) {
    final theme = FluentTheme.of(context);
    return TextSpan(
      children: [
        TextSpan(text: label),
        TextSpan(
          text: ' *',
          style: TextStyle(
            color: theme.resources.systemFillColorCritical,
          ),
        ),
      ],
    );
  }

  Widget _buildUrlInput(BuildContext context) {
    final theme = FluentTheme.of(context);
    final errorColor = theme.resources.systemFillColorCritical;

    return InfoLabel.rich(
      label: _requiredLabel(context, t.addDownloadUrlLabel),
      child: TextBox(
        controller: _urlController,
        focusNode: _urlFocusNode,
        autofocus: widget.initialUrl == null,
        enabled: !_isLoading,
        placeholder: t.addDownloadUrlPlaceholder,
        highlightColor: _urlError == null ? null : errorColor,
        unfocusedColor: _urlError == null ? null : errorColor,
        suffix: _urlController.text.isEmpty
            ? null
            : SmallIconButton(
                child: Tooltip(
                  message: t.logClearFiltersButton,
                  child: IconButton(
                    icon: const Icon(FluentIcons.clear, size: 12),
                    onPressed: _isLoading
                        ? null
                        : () {
                            _urlController.clear();
                            _urlFocusNode.requestFocus();
                          },
                  ),
                ),
              ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (!_isLoading) _handleSubmit();
        },
      ),
    );
  }

  Widget _buildUrlFeedback(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (_urlError != null) {
      return Padding(
        key: const ValueKey('url-error'),
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                FluentIcons.error_badge,
                size: 12,
                color: theme.resources.systemFillColorCritical,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _urlError!,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.systemFillColorCritical,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_parsedFileName == null || _showAdvanced) {
      return const SizedBox.shrink(key: ValueKey('url-feedback-empty'));
    }

    return Padding(
      key: const ValueKey('parsed-file-name'),
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            FluentIcons.document_approval,
            size: 12,
            color: theme.resources.systemFillColorSuccess,
          ),
          const SizedBox(width: 6),
          Text(
            '${t.addDownloadParsedFileNameTitle}:',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _parsedFileName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptions(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Expander(
      leading: Icon(
        FluentIcons.rename,
        size: 16,
        color: theme.resources.textFillColorSecondary,
      ),
      header: Text(t.addDownloadAdvancedToggle),
      trailing: Text(
        _showAdvanced
            ? t.addDownloadAdvancedExpandedHint
            : t.addDownloadAdvancedCollapsedHint,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.typography.caption?.copyWith(
          color: theme.resources.textFillColorTertiary,
        ),
      ),
      enabled: !_isLoading,
      initiallyExpanded: false,
      onStateChanged: (expanded) {
        setState(() => _showAdvanced = expanded);
        if (expanded && widget.initialFileName != null) {
          _fileNameFocusNode.requestFocus();
        }
      },
      contentPadding: const EdgeInsets.all(16),
      content: InfoLabel(
        label: '${t.addDownloadFileNameLabel} (${t.addDownloadOptionalBadge})',
        child: TextBox(
          controller: _fileNameController,
          focusNode: _fileNameFocusNode,
          enabled: !_isLoading,
          placeholder: t.addDownloadFileNamePlaceholder,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isLoading) _handleSubmit();
          },
        ),
      ),
    );
  }

  List<Widget> _buildActions() {
    return [
      if (widget.onMuteClipboardForSession != null)
        Button(
          onPressed: _isLoading ? null : _handleMuteClipboardForSession,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.volume_disabled, size: 13),
                const SizedBox(width: 7),
                Text(t.clipboardListenerMuteSessionButton),
              ],
            ),
          ),
        ),
      Button(
        onPressed: _isLoading ? null : () => Navigator.pop(context, false),
        child: Text(t.addDownloadCancelButton),
      ),
      FilledButton(
        onPressed: _isLoading ? null : _handleSubmit,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: ProgressRing(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Text(_isLoading ? t.addDownloadAdding : t.addDownloadStart),
            ],
          ),
        ),
      ),
    ];
  }

  void _handleMuteClipboardForSession() {
    widget.onMuteClipboardForSession?.call();
    NotificationManager.of(context)?.showInfo(
      t.clipboardListenerSessionMutedTitle,
      message: t.clipboardListenerSessionMutedMessage,
    );
    Navigator.pop(context, false);
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
            onPressed: () =>
                Navigator.pop(context, _DuplicateAction.useExisting),
            child: Text(t.downloadDuplicateUseExistingButton),
          ),
        ],
      ),
    );
    return result ?? _DuplicateAction.cancel;
  }

  void _showUrlError(String message) {
    setState(() => _urlError = message);
    _urlFocusNode.requestFocus();
  }

  Future<void> _handleSubmit() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showUrlError(t.addDownloadErrorMissingUrl);
      return;
    }

    final intent = DownloadIntent.parse(url);
    if (!url.startsWith('test_task_') && !intent.isRecognized) {
      _showUrlError(t.addDownloadErrorInvalidUrl);
      return;
    }

    setState(() => _urlError = null);

    String fileName = _fileNameController.text.trim();
    if (fileName.isEmpty) {
      fileName = _parsedFileName ??
          intent.suggestedFileName() ??
          'download_${DateTime.now().millisecondsSinceEpoch}';
    }

    final downloadService = context.read<IntegratedDownloadService>();
    final duplicate = downloadService.findDuplicateTask(url);
    if (duplicate != null) {
      final action = await _showDuplicateDialog(duplicate);
      if (!mounted) return;
      if (action == _DuplicateAction.cancel) return;
      if (action == _DuplicateAction.useExisting) {
        if (duplicate.status == DownloadStatus.paused ||
            duplicate.status == DownloadStatus.failed ||
            duplicate.status == DownloadStatus.pending) {
          await downloadService.resumeTask(duplicate.id);
        }
        if (mounted) Navigator.pop(context, true);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final taskId = await downloadService.addTask(url, fileName);
      if (taskId == null) {
        throw StateError(
          downloadService.lastAddTaskError ?? 'Failed to add task',
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
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
    final theme = FluentTheme.of(context);
    await showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.addDownloadErrorTitle),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                FluentIcons.error_badge,
                size: 16,
                color: theme.resources.systemFillColorCritical,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.addDownloadErrorConfirm),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String fileName) {
    if (!mounted) return;
    NotificationManager.of(context)?.showSuccess(
      t.addDownloadSuccessTitle,
      message: t.addDownloadSuccessMessage(fileName),
    );
  }
}
