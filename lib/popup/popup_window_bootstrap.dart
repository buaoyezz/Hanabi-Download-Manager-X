import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:win32/win32.dart';

import '../l10n/app_localizations.dart';
import '../l10n/fallback_localizations_delegate.dart';
import '../theme/app_theme.dart';
import '../utils/fluent_icons.dart' as CustomIcons;

const MethodChannel _popupWindowChannel =
    MethodChannel('com.hanabi.download/window');
const String _popupBridgeBaseUrl = 'http://127.0.0.1:19998';
const int _popupCloseMessage = WM_APP + 2;
const int _popupMinimizeMessage = WM_APP + 3;
const int _popupStartDragMessage = WM_APP + 4;
bool get _disableWindowsSemanticsWorkaround =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

Future<void> runPopupWindowApp(List<String> args) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await CustomIcons.FluentIcons.initialize();
  final launchData = PopupWindowLaunchData.fromArgs(args);
  final locale = _parseLocaleTag(launchData.localeTag) ??
      binding.platformDispatcher.locale;

  runApp(PopupWindowApp(
    launchData: launchData,
    locale: locale,
  ));
}

class PopupWindowLaunchData {
  const PopupWindowLaunchData({
    required this.url,
    required this.filename,
    required this.savePath,
    required this.windowTitle,
    this.localeTag,
    this.referer,
    this.userAgent,
    this.cookies,
    this.headers,
  });

  final String url;
  final String? filename;
  final String savePath;
  final String windowTitle;
  final String? localeTag;
  final String? referer;
  final String? userAgent;
  final String? cookies;
  final Map<String, dynamic>? headers;

  factory PopupWindowLaunchData.fromArgs(List<String> args) {
    if (args.isEmpty) {
      return PopupWindowLaunchData.empty();
    }

    try {
      final json = jsonDecode(args.first) as Map<Object?, Object?>;
      final headersRaw = json['headers'];
      return PopupWindowLaunchData(
        url: json['url']?.toString() ?? '',
        filename: json['filename']?.toString(),
        windowTitle: json['window_title']?.toString().trim().isNotEmpty == true
            ? json['window_title']!.toString().trim()
            : 'Hanabi Download Pop',
        savePath: json['save_path']?.toString().trim().isNotEmpty == true
            ? json['save_path']!.toString().trim()
            : _defaultDownloadDirectory(),
        localeTag: json['locale']?.toString(),
        referer: json['referer']?.toString(),
        userAgent: (json['user_agent'] ?? json['userAgent'])?.toString(),
        cookies: json['cookies']?.toString(),
        headers: headersRaw is Map
            ? headersRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : null,
      );
    } catch (_) {
      return PopupWindowLaunchData.empty();
    }
  }

  factory PopupWindowLaunchData.empty() => PopupWindowLaunchData(
        url: '',
        filename: null,
        windowTitle: 'Hanabi Download Pop',
        savePath: _defaultDownloadDirectory(),
      );
}

Locale? _parseLocaleTag(String? tag) {
  final value = tag?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  final parts = value.replaceAll('_', '-').split('-');
  if (parts.isEmpty || parts.first.isEmpty) {
    return null;
  }

  return Locale.fromSubtags(
    languageCode: parts.first.toLowerCase(),
    countryCode: parts.length > 1 ? parts[1].toUpperCase() : null,
  );
}

String _defaultDownloadDirectory() {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  return '$home\\Downloads';
}

class PopupWindowApp extends StatelessWidget {
  const PopupWindowApp({
    super.key,
    required this.launchData,
    required this.locale,
  });

  final PopupWindowLaunchData launchData;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Hanabi Download Pop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fluentDarkTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FallbackFluentLocalizationsDelegate(),
        FallbackMaterialLocalizationsDelegate(),
        FallbackCupertinoLocalizationsDelegate(),
        GlobalWidgetsLocalizations.delegate,
      ],
      builder: (context, child) {
        Widget content = child ?? const SizedBox.shrink();
        if (_disableWindowsSemanticsWorkaround) {
          content = ExcludeSemantics(child: content);
        }
        return content;
      },
      home: PopupWindowPage(launchData: launchData),
    );
  }
}

class PopupWindowPage extends StatefulWidget {
  const PopupWindowPage({
    super.key,
    required this.launchData,
  });

  final PopupWindowLaunchData launchData;

  @override
  State<PopupWindowPage> createState() => _PopupWindowPageState();
}

class _PopupWindowPageState extends State<PopupWindowPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _fileNameController;
  late final TextEditingController _savePathController;

  bool _isSubmitting = false;
  String? _errorText;
  String? _parsedFileName;
  String? _lastSuggestedFileName;
  bool _hasUserEditedFileName = false;
  bool _isUpdatingFileNameProgrammatically = false;
  String _defaultFileName = 'download';

  AppLocalizations get t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    final initialFileName = (widget.launchData.filename ?? '').trim();
    final fallbackFileName = _extractFilenameFromUrl(widget.launchData.url);

    _urlController = TextEditingController(text: widget.launchData.url);
    _fileNameController = TextEditingController(
      text: initialFileName.isNotEmpty ? initialFileName : fallbackFileName,
    );
    _savePathController =
        TextEditingController(text: widget.launchData.savePath);

    _lastSuggestedFileName =
        initialFileName.isNotEmpty ? initialFileName : fallbackFileName;
    _parsedFileName =
        initialFileName.isNotEmpty ? initialFileName : fallbackFileName;
    _hasUserEditedFileName = initialFileName.isNotEmpty;

    _urlController.addListener(_onUrlChanged);
    _fileNameController.addListener(_onFileNameChanged);
    _logToMain(
      'info',
      'Popup window initialized for ${widget.launchData.url} title=${widget.launchData.windowTitle}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_logChannelWindowDebugInfo('init'));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localizedDefault = t.popupDownloadDefaultFileName;
    if (localizedDefault.isNotEmpty && localizedDefault != _defaultFileName) {
      final previousDefault = _defaultFileName;
      _defaultFileName = localizedDefault;
      if (_fileNameController.text == previousDefault) {
        _fileNameController.text = localizedDefault;
      }
      if ((_parsedFileName ?? '').isEmpty ||
          _parsedFileName == previousDefault) {
        _parsedFileName = localizedDefault;
      }
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _fileNameController.removeListener(_onFileNameChanged);
    _urlController.dispose();
    _fileNameController.dispose();
    _savePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.bgBase,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.borderSubtle.withValues(alpha: 0.88),
            ),
          ),
          child: Column(
            children: [
              _buildWindowHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 322;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        compact ? 14 : 18,
                        20,
                        compact ? 12 : 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWorkspaceHeader(compact: compact),
                          SizedBox(height: compact ? 12 : 16),
                          Expanded(
                            child: _buildWorkspacePanel(compact: compact),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _buildFooterBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindowHeader() {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1.withValues(alpha: 0.82),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderSubtle.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  _logToMain(
                    'debug',
                    'Header pointer down x=${event.position.dx.toStringAsFixed(1)} y=${event.position.dy.toStringAsFixed(1)}',
                  );
                  unawaited(_startWindowDrag());
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            'assets/logo/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hanabi Download Manager X',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              FluentTheme.of(context).typography.caption?.copyWith(
                                    color: AppTheme.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _WindowFrameButton(
            debugLabel: 'minimize',
            icon: CustomIcons.FluentIcons.subtract_20,
            onPointerDownLog: (message) => _logToMain('debug', message),
            onPressed: _isSubmitting ? null : _minimizeWindow,
          ),
          const SizedBox(width: 4),
          _WindowFrameButton(
            debugLabel: 'close',
            icon: CustomIcons.FluentIcons.dismiss_20,
            isDestructive: true,
            onPointerDownLog: (message) => _logToMain('debug', message),
            onPressed: _isSubmitting ? null : _closeWindow,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildWorkspaceHeader({required bool compact}) {
    final fileName = _effectivePreviewFileName();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 40 : 42,
          height: compact ? 40 : 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentPrimary.withValues(alpha: 0.22),
                AppTheme.accentLight.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.accentPrimary.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            CustomIcons.FluentIcons.download,
            size: compact ? 18 : 19,
            color: AppTheme.accentLight,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.popupDownloadTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FluentTheme.of(context).typography.subtitle?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 18 : 20,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: compact ? 12.5 : 13,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaBadge(
                    icon: CustomIcons.FluentIcons.globe,
                    text: _currentHostLabel(),
                  ),
                  _buildMetaBadge(
                    icon: CustomIcons.FluentIcons.document,
                    text: _currentExtensionLabel(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetaBadge({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspacePanel({required bool compact}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.72),
        ),
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          compact ? 14 : 16,
          16,
          compact ? 14 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputGroup(
              label: t.popupDownloadLinkLabel,
              icon: CustomIcons.FluentIcons.link,
              child: _buildTextField(
                controller: _urlController,
                placeholder: t.popupDownloadLinkPlaceholder,
                autofocus: widget.launchData.url.trim().isEmpty,
                maxLines: 1,
                dense: true,
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
            _buildInputGroup(
              label: t.popupDownloadFileNameLabel,
              icon: CustomIcons.FluentIcons.document,
              child: _buildTextField(
                controller: _fileNameController,
                placeholder: t.popupDownloadFileNamePlaceholder,
                autofocus: widget.launchData.url.trim().isNotEmpty,
                dense: true,
              ),
            ),
            SizedBox(height: compact ? 12 : 14),
            _buildInputGroup(
              label: t.popupDownloadSavePathLabel,
              icon: CustomIcons.FluentIcons.folder_open,
              child: _buildSavePathField(dense: true),
            ),
            if (_errorText != null) ...[
              SizedBox(height: compact ? 12 : 14),
              _buildErrorBanner(_errorText!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputGroup({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: AppTheme.accentLight,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    bool autofocus = false,
    int maxLines = 1,
    bool dense = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.9),
        ),
      ),
      child: TextBox(
        controller: controller,
        autofocus: autofocus,
        maxLines: maxLines,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: dense ? 10 : 11,
        ),
        style: FluentTheme.of(context).typography.body?.copyWith(
              color: AppTheme.textPrimary,
              fontSize: dense ? 12.5 : 13,
            ),
        placeholder: placeholder,
        decoration: WidgetStateProperty.all(const BoxDecoration()),
        onSubmitted: (_) => _handleSubmit(),
      ),
    );
  }

  Widget _buildSavePathField({required bool dense}) {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _savePathController,
            placeholder: t.popupDownloadSavePathPlaceholder,
            dense: dense,
          ),
        ),
        const SizedBox(width: 8),
        Button(
          onPressed: _isSubmitting ? null : _pickFolder,
          style: ButtonStyle(
            padding: WidgetStateProperty.all(EdgeInsets.zero),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return AppTheme.bgLayer3;
              }
              if (states.contains(WidgetState.hovered)) {
                return AppTheme.surfaceCardHover;
              }
              return AppTheme.bgLayer2.withValues(alpha: 0.82);
            }),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: AppTheme.borderSubtle.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          child: SizedBox(
            width: dense ? 38 : 40,
            height: dense ? 38 : 40,
            child: Icon(
              CustomIcons.FluentIcons.folder_open,
              size: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CustomIcons.FluentIcons.error_badge,
            size: 14,
            color: AppTheme.statusError,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: AppTheme.statusError,
                    fontSize: 12,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1.withValues(alpha: 0.42),
        border: Border(
          top: BorderSide(
            color: AppTheme.borderSubtle.withValues(alpha: 0.85),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  CustomIcons.FluentIcons.info,
                  size: 13,
                  color: AppTheme.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _displaySavePath(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 11.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Button(
            onPressed: _isSubmitting ? null : _closeWindow,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            child: Text(t.popupDownloadCancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
            ),
            child: _isSubmitting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(t.popupDownloadAdding),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CustomIcons.FluentIcons.download, size: 13),
                      const SizedBox(width: 8),
                      Text(t.popupDownloadStart),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _effectivePreviewFileName() {
    final typed = _fileNameController.text.trim();
    if (typed.isNotEmpty) {
      return typed;
    }
    final suggested = (_parsedFileName ?? '').trim();
    if (suggested.isNotEmpty) {
      return suggested;
    }
    return _defaultFileName;
  }

  String _currentHostLabel() {
    final uri = Uri.tryParse(_urlController.text.trim());
    final host = uri?.host.trim() ?? '';
    return host.isNotEmpty ? host : 'URL';
  }

  String _currentExtensionLabel() {
    final fileName = _effectivePreviewFileName().trim();
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > -1 && dotIndex < fileName.length - 1) {
      return fileName.substring(dotIndex + 1).toUpperCase();
    }
    return '--';
  }

  String _displaySavePath() {
    final path = _savePathController.text.trim();
    if (path.isEmpty) {
      return t.popupDownloadSavePathPlaceholder;
    }
    if (path.length <= 40) {
      return path;
    }
    return '${path.substring(0, 16)}...${path.substring(path.length - 18)}';
  }

  String _extractFilenameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        final lastSegment = Uri.decodeComponent(uri.pathSegments.last);
        if (lastSegment.trim().isNotEmpty) {
          return lastSegment;
        }
      }
    } catch (_) {
      // Ignore parse errors and use the default placeholder.
    }
    return _defaultFileName;
  }

  void _onUrlChanged() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      final shouldClearSuggestedName = !_hasUserEditedFileName &&
          (_fileNameController.text.trim().isEmpty ||
              _fileNameController.text.trim() == _lastSuggestedFileName);
      setState(() => _parsedFileName = null);
      if (shouldClearSuggestedName) {
        _setFileNameFromSuggestion('');
      }
      _lastSuggestedFileName = null;
      return;
    }

    final nextSuggestedName = _extractFilenameFromUrl(url);
    final previousSuggestion = _lastSuggestedFileName;
    final currentFileName = _fileNameController.text.trim();
    final shouldApplySuggestion = currentFileName.isEmpty ||
        !_hasUserEditedFileName ||
        (previousSuggestion != null && currentFileName == previousSuggestion);

    setState(() {
      _parsedFileName = nextSuggestedName;
      _lastSuggestedFileName = nextSuggestedName;
      _errorText = null;
    });

    if (shouldApplySuggestion) {
      _setFileNameFromSuggestion(nextSuggestedName);
    }
  }

  void _onFileNameChanged() {
    if (_isUpdatingFileNameProgrammatically) {
      return;
    }

    final text = _fileNameController.text.trim();
    final suggestion = _lastSuggestedFileName?.trim();
    setState(() {
      _hasUserEditedFileName = text.isNotEmpty && text != (suggestion ?? '');
      _errorText = null;
    });
  }

  void _setFileNameFromSuggestion(String value) {
    _isUpdatingFileNameProgrammatically = true;
    _fileNameController.text = value;
    _fileNameController.selection =
        TextSelection.collapsed(offset: _fileNameController.text.length);
    _isUpdatingFileNameProgrammatically = false;
    _hasUserEditedFileName = false;
  }

  Future<void> _pickFolder() async {
    try {
      final selected =
          await _popupWindowChannel.invokeMethod<String>('pickFolder');
      if (!mounted || selected == null || selected.trim().isEmpty) {
        return;
      }
      setState(() {
        _savePathController.text = selected.trim();
        _errorText = null;
      });
    } catch (e) {
      _logToMain('error', 'Folder picker failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = t.popupDownloadErrorAddFailed(e.toString());
      });
    }
  }

  Future<void> _closeWindow() async {
    _logToMain('debug', 'Close requested');
    await _logChannelWindowDebugInfo('close');
    if (_invokeNativeWindowClose()) {
      return;
    }

    try {
      await _popupWindowChannel.invokeMethod<void>('closeWindow');
      return;
    } catch (e) {
      _logToMain('warning', 'closeWindow channel fallback failed: $e');
    }

    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _minimizeWindow() async {
    _logToMain('debug', 'Minimize requested');
    await _logChannelWindowDebugInfo('minimize');
    if (_invokeNativeWindowMinimize()) {
      return;
    }

    try {
      await _popupWindowChannel.invokeMethod<void>('minimizeWindow');
    } catch (e) {
      _logToMain('warning', 'minimizeWindow channel fallback failed: $e');
    }
  }

  Future<void> _startWindowDrag() async {
    _logToMain('debug', 'Start drag requested');
    await _logChannelWindowDebugInfo('drag');
    if (_invokeNativeWindowDrag()) {
      return;
    }

    try {
      await _popupWindowChannel.invokeMethod<void>('startWindowDrag');
    } catch (e) {
      _logToMain('warning', 'startWindowDrag channel fallback failed: $e');
    }
  }

  int _resolvePopupWindowHandle() {
    final title = widget.launchData.windowTitle.toNativeUtf16();
    try {
      final hwnd = FindWindow(nullptr, title);
      if (hwnd != 0) {
        _logToMain(
          'debug',
          'FindWindow matched title=${widget.launchData.windowTitle} hwnd=$hwnd',
        );
        return hwnd;
      }
    } finally {
      calloc.free(title);
    }

    final foregroundHwnd = GetForegroundWindow();
    _logToMain(
      'warning',
      'FindWindow missed title=${widget.launchData.windowTitle}, foregroundHwnd=$foregroundHwnd',
    );
    return foregroundHwnd;
  }

  bool _invokeNativeWindowClose() {
    if (!Platform.isWindows) {
      return false;
    }

    final hwnd = _resolvePopupWindowHandle();
    if (hwnd == 0) {
      _logToMain('warning', 'Close requested but popup HWND was not found');
      return false;
    }

    final result = SendMessage(hwnd, _popupCloseMessage, 0, 0);
    _logToMain('debug', 'Close message sent hwnd=$hwnd result=$result');
    return true;
  }

  bool _invokeNativeWindowMinimize() {
    if (!Platform.isWindows) {
      return false;
    }

    final hwnd = _resolvePopupWindowHandle();
    if (hwnd == 0) {
      _logToMain('warning', 'Minimize requested but popup HWND was not found');
      return false;
    }

    final result = SendMessage(hwnd, _popupMinimizeMessage, 0, 0);
    _logToMain('debug', 'Minimize message sent hwnd=$hwnd result=$result');
    return true;
  }

  bool _invokeNativeWindowDrag() {
    if (!Platform.isWindows) {
      return false;
    }

    final hwnd = _resolvePopupWindowHandle();
    if (hwnd == 0) {
      _logToMain('warning', 'Drag requested but popup HWND was not found');
      return false;
    }

    final result = SendMessage(hwnd, _popupStartDragMessage, 0, 0);
    _logToMain('debug', 'Drag message sent hwnd=$hwnd result=$result');
    return true;
  }

  Future<void> _logChannelWindowDebugInfo(String reason) async {
    try {
      final raw = await _popupWindowChannel.invokeMethod<Object?>(
        'getWindowDebugInfo',
      );
      if (raw is Map) {
        final info = raw.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        _logToMain(
          'debug',
          'Channel window info[$reason]: hwnd=${info['hwnd']} kind=${info['kind']} title=${info['title']}',
        );
      } else {
        _logToMain('warning', 'Channel window info[$reason] returned $raw');
      }
    } catch (e) {
      _logToMain('warning', 'Channel window info[$reason] failed: $e');
    }
  }

  void _logToMain(String level, String message) {
    final payload = jsonEncode({
      'level': level,
      'source': 'PopupWindow',
      'message': message,
    });

    unawaited(
      () async {
        try {
          await http
              .post(
                Uri.parse('$_popupBridgeBaseUrl/api/log'),
                headers: const {'Content-Type': 'application/json'},
                body: payload,
              )
              .timeout(const Duration(milliseconds: 400));
        } catch (_) {
          // Ignore popup log relay failures.
        }
      }(),
    );
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }

    final url = _urlController.text.trim();
    final savePath = _savePathController.text.trim();
    var fileName = _fileNameController.text.trim();

    if (url.isEmpty || savePath.isEmpty) {
      setState(() => _errorText = t.popupDownloadErrorMissingInfo);
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.isAbsolute ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _errorText = t.popupDownloadErrorInvalidUrl);
      return;
    }

    if (fileName.isEmpty) {
      fileName = (_parsedFileName ?? '').trim();
    }
    if (fileName.isEmpty) {
      fileName = _defaultFileName;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    _logToMain('info', 'Submitting popup download: $fileName');

    try {
      final response = await http.post(
        Uri.parse('$_popupBridgeBaseUrl/api/download'),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'url': url,
          'filename': fileName,
          'save_path': savePath,
          if (widget.launchData.referer?.trim().isNotEmpty ?? false)
            'referer': widget.launchData.referer!.trim(),
          if (widget.launchData.userAgent?.trim().isNotEmpty ?? false)
            'user_agent': widget.launchData.userAgent!.trim(),
          if (widget.launchData.cookies?.trim().isNotEmpty ?? false)
            'cookies': widget.launchData.cookies!.trim(),
          if (widget.launchData.headers != null &&
              widget.launchData.headers!.isNotEmpty)
            'headers': widget.launchData.headers,
        }),
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _logToMain('info', 'Popup download accepted: $fileName');
        await _closeWindow();
        return;
      }

      final body = response.body.trim();
      setState(() {
        _isSubmitting = false;
        _errorText = body.isNotEmpty
            ? t.popupDownloadErrorAddFailed(body)
            : t.popupDownloadErrorAddFailed(
                'HTTP ${response.statusCode}',
              );
      });
      _logToMain(
        'error',
        'Popup download failed with HTTP ${response.statusCode}: $body',
      );
    } catch (e) {
      _logToMain('error', 'Popup download submit failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorText = t.popupDownloadErrorAddFailed(e.toString());
      });
    }
  }
}

class _WindowFrameButton extends StatefulWidget {
  const _WindowFrameButton({
    required this.debugLabel,
    required this.icon,
    this.onPointerDownLog,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String debugLabel;
  final IconData icon;
  final ValueChanged<String>? onPointerDownLog;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  State<_WindowFrameButton> createState() => _WindowFrameButtonState();
}

class _WindowFrameButtonState extends State<_WindowFrameButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final backgroundColor = disabled
        ? Colors.transparent
        : widget.isDestructive
            ? (_isHovered ? const Color(0xFFc42b1c) : Colors.transparent)
            : (_isHovered
                ? AppTheme.bgLayer3.withValues(alpha: 0.9)
                : Colors.transparent);
    final foregroundColor = disabled
        ? AppTheme.textDisabled
        : widget.isDestructive
            ? (_isHovered ? Colors.white : AppTheme.textSecondary)
            : (_isHovered ? AppTheme.textPrimary : AppTheme.textSecondary);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          widget.onPointerDownLog?.call(
            'Window button ${widget.debugLabel} pointer down x=${event.position.dx.toStringAsFixed(1)} y=${event.position.dy.toStringAsFixed(1)} enabled=${widget.onPressed != null}',
          );
          widget.onPressed?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 26,
          height: 20,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(3.5),
          ),
          child: Icon(
            widget.icon,
            size: 11,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}
