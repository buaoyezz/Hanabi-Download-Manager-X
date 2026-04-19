import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:math' as math;

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
import '../widgets/file_icon_widget.dart';
import '../utils/fluent_icons.dart' as CustomIcons;

const MethodChannel _popupWindowChannel =
    MethodChannel('com.hanabi.download/window');
const String _popupBridgeBaseUrl = 'http://127.0.0.1:19998';
const int _popupCloseMessage = WM_APP + 2;
const int _popupMinimizeMessage = WM_APP + 3;
const int _popupStartDragMessage = WM_APP + 4;
bool get _disableWindowsSemanticsWorkaround =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

class PopupWindowThemeConfig {
  const PopupWindowThemeConfig({
    required this.fontFamily,
    this.fontFamilyFallback = const [],
    this.textScaleFactor = 1.0,
  });

  final String fontFamily;
  final List<String> fontFamilyFallback;
  final double textScaleFactor;

  bool get hasFontFamily => fontFamily.trim().isNotEmpty;
  double get safeTextScaleFactor =>
      textScaleFactor.isFinite && textScaleFactor > 0 ? textScaleFactor : 1.0;
}

Future<void> runPopupWindowApp(
  List<String> args, {
  PopupWindowThemeConfig? themeConfig,
}) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await CustomIcons.FluentIcons.initialize();
  final launchData = PopupWindowLaunchData.fromArgs(args);
  final locale = parsePopupLocaleTag(launchData.localeTag) ??
      binding.platformDispatcher.locale;

  runApp(PopupWindowApp(
    launchData: launchData,
    locale: locale,
    themeConfig: themeConfig,
  ));
}

class PopupWindowLaunchData {
  const PopupWindowLaunchData({
    required this.url,
    required this.filename,
    required this.savePath,
    required this.windowTitle,
    this.debugPreviewStage,
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
  final String? debugPreviewStage;
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
      final debugPreviewRaw = json['debug_preview'];
      return PopupWindowLaunchData(
        url: json['url']?.toString() ?? '',
        filename: json['filename']?.toString(),
        windowTitle: json['window_title']?.toString().trim().isNotEmpty == true
            ? json['window_title']!.toString().trim()
            : 'Hanabi Download Pop',
        savePath: json['save_path']?.toString().trim().isNotEmpty == true
            ? json['save_path']!.toString().trim()
            : _defaultDownloadDirectory(),
        debugPreviewStage: debugPreviewRaw is Map
            ? debugPreviewRaw['stage']?.toString()
            : json['debug_preview_stage']?.toString(),
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
        debugPreviewStage: null,
      );
}

Locale? parsePopupLocaleTag(String? tag) {
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

enum _PopupWindowStage {
  compose,
  progress,
  completed,
}

_PopupWindowStage? _parsePopupWindowStage(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'compose' => _PopupWindowStage.compose,
    'progress' => _PopupWindowStage.progress,
    'completed' => _PopupWindowStage.completed,
    _ => null,
  };
}

const int _popupComposeWindowHeight = 388;
const int _popupComposeWindowHeightWithError = 424;
const int _popupProgressWindowHeight = 280;
const int _popupProgressWindowHeightWithError = 404;
const int _popupCompletedWindowHeight = 272;

class _PopupSegmentSnapshot {
  const _PopupSegmentSnapshot({
    required this.index,
    required this.progress,
    required this.status,
  });

  final int index;
  final double progress;
  final String status;

  factory _PopupSegmentSnapshot.fromJson(Map<String, dynamic> json) {
    return _PopupSegmentSnapshot(
      index: _asInt(json['index']),
      progress: _asDouble(json['progress']).clamp(0, 1).toDouble(),
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class _PopupTaskSnapshot {
  const _PopupTaskSnapshot({
    required this.taskId,
    required this.fileName,
    required this.status,
    required this.progress,
    required this.downloadedSize,
    required this.totalSize,
    required this.speed,
    required this.remainingSeconds,
    required this.segments,
    this.error,
  });

  final String taskId;
  final String fileName;
  final String status;
  final double progress;
  final int downloadedSize;
  final int totalSize;
  final int speed;
  final int remainingSeconds;
  final List<_PopupSegmentSnapshot> segments;
  final String? error;

  bool get isCompleted => status == 'completed';
  bool get isPaused => status == 'paused';
  bool get isFailed => status == 'failed';
  bool get isMerging => status == 'merging';
  bool get isPending => status == 'pending';
  bool get isDownloading => status == 'downloading';
  double get progressRatio => (progress / 100).clamp(0, 1).toDouble();

  _PopupTaskSnapshot copyWith({
    String? taskId,
    String? fileName,
    String? status,
    double? progress,
    int? downloadedSize,
    int? totalSize,
    int? speed,
    int? remainingSeconds,
    List<_PopupSegmentSnapshot>? segments,
    String? error,
    bool clearError = false,
  }) {
    return _PopupTaskSnapshot(
      taskId: taskId ?? this.taskId,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedSize: downloadedSize ?? this.downloadedSize,
      totalSize: totalSize ?? this.totalSize,
      speed: speed ?? this.speed,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      segments: segments ?? this.segments,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory _PopupTaskSnapshot.fromJson(Map<String, dynamic> json) {
    final segmentsRaw = json['segments'];
    return _PopupTaskSnapshot(
      taskId: json['task_id']?.toString() ?? '',
      fileName: json['filename']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      progress: _asDouble(json['progress']).clamp(0, 100).toDouble(),
      downloadedSize: _asInt(json['downloaded_size']),
      totalSize: _asInt(json['total_size']),
      speed: _asInt(json['speed']),
      remainingSeconds: _asInt(json['remaining_seconds']),
      segments: segmentsRaw is List
          ? segmentsRaw
              .whereType<Map>()
              .map(
                (entry) => _PopupSegmentSnapshot.fromJson(
                  entry.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList()
          : const [],
      error: json['error']?.toString(),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class PopupWindowApp extends StatelessWidget {
  const PopupWindowApp({
    super.key,
    required this.launchData,
    required this.locale,
    this.themeConfig,
  });

  final PopupWindowLaunchData launchData;
  final Locale locale;
  final PopupWindowThemeConfig? themeConfig;

  @override
  Widget build(BuildContext context) {
    final baseTheme = AppTheme.fluentDarkTheme;
    final typography = baseTheme.typography;
    final fontFamily = themeConfig?.fontFamily.trim() ?? '';
    final fontFallbacks = themeConfig?.fontFamilyFallback ?? const <String>[];
    final appliedTheme = themeConfig?.hasFontFamily == true
        ? baseTheme.copyWith(
            typography: Typography.raw(
              body: typography.body?.copyWith(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallbacks,
              ),
              bodyLarge: typography.bodyLarge?.copyWith(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallbacks,
              ),
              bodyStrong: typography.bodyStrong?.copyWith(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallbacks,
              ),
              caption: typography.caption?.copyWith(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallbacks,
              ),
              subtitle: typography.subtitle?.copyWith(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallbacks,
              ),
              title: typography.title?.copyWith(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallbacks,
              ),
              titleLarge: typography.titleLarge?.copyWith(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallbacks,
              ),
              display: typography.display?.copyWith(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallbacks,
              ),
            ),
          )
        : baseTheme;

    return FluentApp(
      title: 'Hanabi Download Pop',
      debugShowCheckedModeBanner: false,
      theme: appliedTheme,
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
        if (themeConfig?.hasFontFamily == true) {
          content = DefaultTextStyle.merge(
            style: TextStyle(
              fontFamily: fontFamily,
              fontFamilyFallback: fontFallbacks,
            ),
            child: content,
          );
        }
        if (_disableWindowsSemanticsWorkaround) {
          content = ExcludeSemantics(child: content);
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              themeConfig?.safeTextScaleFactor ?? 1.0,
            ),
          ),
          child: content,
        );
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
  Timer? _progressPollTimer;

  bool _isSubmitting = false;
  bool _isTransferActionBusy = false;
  bool _progressPollInFlight = false;
  String? _errorText;
  String? _parsedFileName;
  String? _lastSuggestedFileName;
  bool _hasUserEditedFileName = false;
  bool _isUpdatingFileNameProgrammatically = false;
  String _defaultFileName = 'download';
  bool _windowHeightSyncScheduled = false;
  int? _lastRequestedWindowHeight;
  _PopupWindowStage _stage = _PopupWindowStage.compose;
  String? _activeTaskId;
  _PopupTaskSnapshot? _taskSnapshot;

  AppLocalizations get t => AppLocalizations.of(context)!;
  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
            'zh',
          );
  bool get _isDebugPreview =>
      _parsePopupWindowStage(widget.launchData.debugPreviewStage) != null;
  _PopupWindowStage? get _debugPreviewStage =>
      _parsePopupWindowStage(widget.launchData.debugPreviewStage);
  String get _openWithActionLabel => _isChinese ? '用其他方式打开' : 'Open with...';

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
    _applyDebugPreviewStateIfNeeded();

    _urlController.addListener(_onUrlChanged);
    _fileNameController.addListener(_onFileNameChanged);
    _logToMain(
      'info',
      'Popup window initialized for ${widget.launchData.url} title=${widget.launchData.windowTitle}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_logChannelWindowDebugInfo('init'));
      unawaited(_syncWindowHeightForCurrentLayout(force: true));
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) {
          return;
        }
        unawaited(_syncWindowHeightForCurrentLayout(force: true));
      });
    });
  }

  void _applyDebugPreviewStateIfNeeded() {
    final previewStage = _debugPreviewStage;
    if (previewStage == null) {
      return;
    }

    final fileName = _effectivePreviewFileName().trim().isNotEmpty
        ? _effectivePreviewFileName().trim()
        : 'hanabi-popup-preview.txt';
    _isSubmitting = false;
    _isTransferActionBusy = false;
    _errorText = null;
    _activeTaskId = 'debug-preview-${previewStage.name}';
    _stage = previewStage;
    _taskSnapshot = switch (previewStage) {
      _PopupWindowStage.compose => null,
      _PopupWindowStage.progress => _buildDebugPreviewSnapshot(
          stage: _PopupWindowStage.progress,
          fileName: fileName,
        ),
      _PopupWindowStage.completed => _buildDebugPreviewSnapshot(
          stage: _PopupWindowStage.completed,
          fileName: fileName,
        ),
    };

    if (previewStage == _PopupWindowStage.completed) {
      unawaited(_ensureDebugPreviewFile());
    }
  }

  _PopupTaskSnapshot _buildDebugPreviewSnapshot({
    required _PopupWindowStage stage,
    required String fileName,
    int? totalSize,
  }) {
    switch (stage) {
      case _PopupWindowStage.compose:
        throw StateError('Compose preview does not use a task snapshot');
      case _PopupWindowStage.progress:
        const totalBytes = 268 * 1024 * 1024;
        const progress = 67.4;
        return _PopupTaskSnapshot(
          taskId: 'debug-preview-progress',
          fileName: fileName,
          status: 'downloading',
          progress: progress,
          downloadedSize: ((progress / 100) * totalBytes).round(),
          totalSize: totalBytes,
          speed: 12 * 1024 * 1024,
          remainingSeconds: 19,
          segments: const [
            _PopupSegmentSnapshot(index: 0, progress: 0.92, status: 'done'),
            _PopupSegmentSnapshot(
                index: 1, progress: 0.76, status: 'downloading'),
            _PopupSegmentSnapshot(
                index: 2, progress: 0.61, status: 'downloading'),
            _PopupSegmentSnapshot(index: 3, progress: 0.38, status: 'pending'),
          ],
        );
      case _PopupWindowStage.completed:
        final safeTotalSize = totalSize ?? 1536;
        return _PopupTaskSnapshot(
          taskId: 'debug-preview-completed',
          fileName: fileName,
          status: 'completed',
          progress: 100,
          downloadedSize: safeTotalSize,
          totalSize: safeTotalSize,
          speed: 0,
          remainingSeconds: 0,
          segments: const [],
        );
    }
  }

  Future<void> _ensureDebugPreviewFile() async {
    if (_debugPreviewStage != _PopupWindowStage.completed) {
      return;
    }

    final filePath = _resolvedDownloadedFilePath();
    if (filePath == null) {
      return;
    }

    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      if (!await file.exists()) {
        final isChineseLocale =
            (widget.launchData.localeTag ?? '').toLowerCase().startsWith('zh');
        final content = isChineseLocale
            ? 'Hanabi Download Manager X\n这是用于调试完成态弹窗的本地预览文件。\n你可以直接测试打开、打开目录和“用其他方式打开”。\n'
            : 'Hanabi Download Manager X\nThis is a local preview file for debugging the completed popup state.\nYou can test open file, open folder, and Open with from here.\n';
        await file.writeAsString(content);
      }
      final size = await file.length();
      if (!mounted || _taskSnapshot == null || !_taskSnapshot!.isCompleted) {
        return;
      }
      setState(() {
        _taskSnapshot = _taskSnapshot!.copyWith(
          downloadedSize: size,
          totalSize: size,
        );
      });
    } catch (e) {
      _logToMain('warning', 'Failed to prepare popup debug preview file: $e');
    }
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
    _progressPollTimer?.cancel();
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
      color: AppTheme.bgBase,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.bgBase,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.borderStrong.withValues(alpha: 0.94),
            width: 1.15,
          ),
          boxShadow: AppTheme.shadowSm,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 360;
              final verticalPadding =
                  (compact ? 10.0 : 14.0) + (compact ? 10.0 : 12.0);
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 16,
                  compact ? 10 : 14,
                  compact ? 14 : 16,
                  compact ? 10 : 12,
                ),
                child: SizedBox(
                  height: math.max(
                    0.0,
                    constraints.maxHeight - verticalPadding,
                  ),
                  child: _buildWorkspacePanel(compact: compact),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _syncWindowHeightForCurrentLayout({bool force = false}) async {
    if (!mounted || !Platform.isWindows) {
      return;
    }
    await _syncWindowHeight(force: force);
  }

  void _scheduleCurrentLayoutHeightSync({bool force = false}) {
    if (!Platform.isWindows || _windowHeightSyncScheduled) {
      return;
    }
    _windowHeightSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _windowHeightSyncScheduled = false;
      unawaited(_syncWindowHeightForCurrentLayout(force: force));
    });
  }

  Future<void> _syncWindowHeight({bool force = false}) async {
    if (!mounted || !Platform.isWindows) {
      return;
    }

    final desiredHeight = _targetWindowHeight();
    if (!force &&
        _lastRequestedWindowHeight != null &&
        (_lastRequestedWindowHeight! - desiredHeight).abs() <= 1) {
      return;
    }

    _lastRequestedWindowHeight = desiredHeight;
    try {
      await _popupWindowChannel.invokeMethod<void>(
        'resizeWindow',
        <String, Object>{
          'height': desiredHeight,
        },
      );
    } catch (e) {
      _logToMain('warning', 'resizeWindow channel failed: $e');
    }
  }

  int _targetWindowHeight() {
    final hasError = (_errorText?.trim().isNotEmpty ?? false);
    return switch (_stage) {
      _PopupWindowStage.compose => hasError
          ? _popupComposeWindowHeightWithError
          : _popupComposeWindowHeight,
      _PopupWindowStage.progress => hasError
          ? _popupProgressWindowHeightWithError
          : _popupProgressWindowHeight,
      _PopupWindowStage.completed => _popupCompletedWindowHeight,
    };
  }

  Widget _buildWorkspacePanel({required bool compact}) {
    final actionGap = _stage == _PopupWindowStage.progress
        ? (compact ? 2.0 : 3.0)
        : (compact ? 4.0 : 6.0);
    final stageBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(_stage),
            child: switch (_stage) {
              _PopupWindowStage.compose =>
                _buildComposeStageBody(compact: compact),
              _PopupWindowStage.progress =>
                _buildProgressStageBody(compact: compact),
              _PopupWindowStage.completed =>
                _buildCompletedStageBody(compact: compact),
            },
          ),
        ),
        if (_errorText != null) ...[
          SizedBox(height: compact ? 8 : 10),
          _buildErrorBanner(_errorText!),
        ],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkspaceSummary(compact: compact),
        SizedBox(height: compact ? 6 : 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: stageBody,
                ),
              );
            },
          ),
        ),
        SizedBox(height: actionGap),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildWorkspaceSummary({required bool compact}) {
    final pillText = _summaryPillLabel();
    final pillAccent = _summaryPillAccent();
    return Row(
      children: [
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                _logToMain(
                  'debug',
                  'Workspace pointer down x=${event.position.dx.toStringAsFixed(1)} y=${event.position.dy.toStringAsFixed(1)}',
                );
                unawaited(_startWindowDrag());
              },
              child: Row(
                children: [
                  SizedBox(
                    width: compact ? 36 : 40,
                    height: compact ? 36 : 40,
                    child: IgnorePointer(
                      child: FileIconWidget(
                        fileName: _effectivePreviewFileName(),
                        size: compact ? 36 : 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _summaryTitle(),
                          style: FluentTheme.of(context)
                              .typography
                              .bodyStrong
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: compact ? 13.5 : 14,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _summarySubtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FluentTheme.of(context)
                              .typography
                              .caption
                              ?.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildPillLabel(
          pillText,
          accentColor: pillAccent,
        ),
        const SizedBox(width: 8),
        _WindowFrameButton(
          debugLabel: 'minimize',
          icon: CustomIcons.FluentIcons.subtract_24,
          onPointerDownLog: (message) => _logToMain('debug', message),
          onPressed: _isSubmitting ? null : _minimizeWindow,
        ),
        const SizedBox(width: 4),
        _WindowFrameButton(
          debugLabel: 'close',
          icon: CustomIcons.FluentIcons.dismiss_24,
          isDestructive: true,
          onPointerDownLog: (message) => _logToMain('debug', message),
          onPressed: _isSubmitting ? null : _closeWindow,
        ),
      ],
    );
  }

  Widget _buildPillLabel(
    String text, {
    Color? accentColor,
  }) {
    final color = accentColor ?? AppTheme.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: accentColor == null ? 0.12 : 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: color.withValues(alpha: accentColor == null ? 0.22 : 0.34),
        ),
      ),
      child: Text(
        text,
        style: FluentTheme.of(context).typography.caption?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
      ),
    );
  }

  Widget _buildComposeStageBody({required bool compact}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildEditorSection(compact: compact),
          ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            color: AppTheme.borderSubtle.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: compact ? 196 : 212,
            child: _buildContextSection(compact: compact),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStageBody({required bool compact}) {
    final snapshot = _taskSnapshot;
    final progressValue = snapshot?.progress ?? 0;
    final indeterminate = snapshot == null ||
        ((snapshot.isPending || snapshot.isDownloading) &&
            snapshot.totalSize <= 0 &&
            snapshot.progress <= 0);
    final progressBorderColor = _statusAccent(snapshot?.status).withValues(
      alpha: snapshot?.isFailed == true ? 0.28 : 0.14,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 9 : 10,
        compact ? 10 : 12,
        compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: progressBorderColor,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snapshot?.fileName ?? _effectivePreviewFileName(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FluentTheme.of(context)
                          .typography
                          .bodyStrong
                          ?.copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: compact ? 13.5 : 14,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _progressHeroMessage(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                height: 1.3,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatPercent(progressValue),
                style: FluentTheme.of(context).typography.titleLarge?.copyWith(
                      color: _statusAccent(snapshot?.status),
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 22 : 26,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _buildProgressOverviewRow(snapshot),
          const SizedBox(height: 4),
          _buildPrimaryProgressBar(
            value: snapshot?.progressRatio ?? 0,
            indeterminate: indeterminate,
            accentColor: _statusAccent(snapshot?.status),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: _buildProgressMetricTile(
                  label: t.popupDownloadMetricDownloaded,
                  value: _downloadedSummary(),
                  icon: CustomIcons.FluentIcons.arrow_download_20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProgressMetricTile(
                  label: t.popupDownloadMetricSpeed,
                  value: _formatSpeed(_taskSnapshot?.speed ?? 0),
                  icon: CustomIcons.FluentIcons.top_speed_20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProgressMetricTile(
                  label: t.popupDownloadMetricEta,
                  value: _formatRemainingSeconds(
                    _taskSnapshot?.remainingSeconds ?? 0,
                  ),
                  icon: CustomIcons.FluentIcons.clock_20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildProgressMetricTile(
                  label: t.popupDownloadMetricStatus,
                  value: _statusLabel(snapshot?.status),
                  accentColor: _statusAccent(snapshot?.status),
                  icon: snapshot?.isPaused == true
                      ? CustomIcons.FluentIcons.pause_20
                      : snapshot?.isCompleted == true
                          ? CustomIcons.FluentIcons.checkmark_circle_20
                          : CustomIcons.FluentIcons.data_bar_vertical_20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _buildProgressFooterStrip(snapshot),
        ],
      ),
    );
  }

  Widget _buildProgressOverviewRow(_PopupTaskSnapshot? snapshot) {
    return Row(
      children: [
        Icon(
          CustomIcons.FluentIcons.arrow_download_20,
          size: 13,
          color: _statusAccent(snapshot?.status),
        ),
        const SizedBox(width: 6),
        Text(
          t.popupDownloadMetricProgress,
          style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        Text(
          _downloadedSummary(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 10.5,
              ),
        ),
      ],
    );
  }

  Widget _buildProgressMetricTile({
    required String label,
    required String value,
    required IconData icon,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppTheme.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.54),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppTheme.textTertiary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 10,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.body?.copyWith(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressFooterStrip(_PopupTaskSnapshot? snapshot) {
    final previewSegments = _segmentPreviewData(snapshot);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.46),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CustomIcons.FluentIcons.globe_20,
                size: 12,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_currentHostLabel()}  •  ${_currentFolderLabel()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                      ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CustomIcons.FluentIcons.data_bar_vertical_20,
                    size: 12,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${previewSegments.length} ${t.popupDownloadMetricSegments}',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 10.5,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildSegmentPreviewStrip(previewSegments),
        ],
      ),
    );
  }

  List<_PopupSegmentSnapshot> _segmentPreviewData(
      _PopupTaskSnapshot? snapshot) {
    final segments = snapshot?.segments ?? const <_PopupSegmentSnapshot>[];
    if (segments.isNotEmpty) {
      return segments.take(8).toList();
    }
    return <_PopupSegmentSnapshot>[
      _PopupSegmentSnapshot(
        index: 0,
        progress: (snapshot?.progressRatio ?? 0).clamp(0, 1).toDouble(),
        status: snapshot?.status ?? 'pending',
      ),
    ];
  }

  Widget _buildSegmentPreviewStrip(List<_PopupSegmentSnapshot> segments) {
    final visibleSegments = segments.isEmpty
        ? const <_PopupSegmentSnapshot>[]
        : segments.take(8).toList();
    if (visibleSegments.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusRound),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: AppTheme.bgLayer2.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        ),
        child: Row(
          children: [
            for (var i = 0; i < visibleSegments.length; i++)
              Expanded(
                child: _buildSegmentPreviewBar(
                  visibleSegments[i],
                  showSeparator: i < visibleSegments.length - 1,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentPreviewBar(
    _PopupSegmentSnapshot segment, {
    required bool showSeparator,
  }) {
    final statusColor = _statusAccent(segment.status);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showSeparator
            ? Border(
                right: BorderSide(
                  color: AppTheme.bgBase.withValues(alpha: 0.72),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: AppTheme.borderSubtle.withValues(alpha: 0.36),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: segment.progress.clamp(0, 1).toDouble(),
            heightFactor: 1,
            child: ColoredBox(
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedStageBody({required bool compact}) {
    return _buildCompletedHeroCard(compact: compact);
  }

  Widget _buildCompletedHeroCard({required bool compact}) {
    final metricsSpacing = compact ? 4.0 : 6.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.82),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: metricsSpacing,
            runSpacing: metricsSpacing,
            children: [
              _buildHeroMetricChip(
                label: t.popupDownloadMetricProgress,
                value: _formatPercent(_taskSnapshot?.progress ?? 100),
                icon: CustomIcons.FluentIcons.chart,
                accentColor: AppTheme.statusSuccess,
                compact: compact,
              ),
              _buildHeroMetricChip(
                label: t.popupDownloadMetricTotalSize,
                value: _formatBytes(_taskSnapshot?.totalSize ?? 0),
                icon: CustomIcons.FluentIcons.arrow_download_20,
                accentColor: AppTheme.statusSuccess,
                compact: compact,
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          _buildContextMetricRow(
            label: t.popupDownloadFileNameLabel,
            value: _effectivePreviewFileName(),
            icon: CustomIcons.FluentIcons.document_20,
            compact: compact,
          ),
          SizedBox(height: compact ? 3 : 4),
          _buildContextMetricRow(
            label: t.popupDownloadMetricSaveTo,
            value: _currentSavePathLabel(),
            icon: CustomIcons.FluentIcons.folder_open_20,
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryProgressBar({
    required double value,
    bool indeterminate = false,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppTheme.accentPrimary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusRound),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.bgLayer2.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
              ),
            ),
            if (indeterminate)
              ProgressBar(
                strokeWidth: 10,
                activeColor: color,
              )
            else
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0, 1).toDouble(),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color,
                            color.withValues(alpha: 0.72),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusRound),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMetricChip({
    required String label,
    required String value,
    required IconData icon,
    Color? accentColor,
    bool compact = false,
  }) {
    final color = accentColor ?? AppTheme.accentLight;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 9,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: color.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          SizedBox(width: compact ? 6 : 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: compact ? 9.5 : 10,
                    ),
              ),
              SizedBox(height: compact ? 0 : 1),
              Text(
                value,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: compact ? 10.5 : 11,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorSection({required bool compact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldBlock(
          label: t.popupDownloadLinkLabel,
          child: _buildTextField(
            controller: _urlController,
            placeholder: t.popupDownloadLinkPlaceholder,
            autofocus: widget.launchData.url.trim().isEmpty,
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        _buildFieldBlock(
          label: t.popupDownloadFileNameLabel,
          child: Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _fileNameController,
                  placeholder: t.popupDownloadFileNamePlaceholder,
                  autofocus: widget.launchData.url.trim().isNotEmpty,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: _buildCompactMetric(
                  title: 'Type',
                  value: _currentExtensionLabel(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 10 : 12),
        _buildFieldBlock(
          label: t.popupDownloadSavePathLabel,
          child: _buildSavePathField(),
        ),
        SizedBox(height: compact ? 8 : 10),
        Text(
          t.popupDownloadFeatureHint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
        ),
      ],
    );
  }

  Widget _buildContextSection({required bool compact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContextMetricRow(
          label: 'Host',
          value: _currentHostLabel(),
          icon: CustomIcons.FluentIcons.globe_20,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildContextMetricRow(
                label: 'Cookie',
                value: widget.launchData.cookies?.trim().isNotEmpty == true
                    ? 'YES'
                    : '--',
                icon: CustomIcons.FluentIcons.tag_20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildContextMetricRow(
                label: 'Headers',
                value: _headerCountLabel(),
                icon: CustomIcons.FluentIcons.list_20,
              ),
            ),
          ],
        ),
        if (_hasContextDetails()) ...[
          SizedBox(height: compact ? 10 : 12),
          Text(
            _contextDetailsSummary(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 10.5,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildContextMetricRow({
    required String label,
    required String value,
    IconData? icon,
    bool compact = false,
  }) {
    return Container(
      height: compact ? 28 : 32,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 9),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.72),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 12, color: AppTheme.textTertiary),
            SizedBox(width: compact ? 5 : 6),
          ],
          Text(
            label,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: compact ? 10 : 10.5,
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: compact ? 11 : 11.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldBlock({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FluentTheme.of(context).typography.body?.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
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
        color: AppTheme.bgLayer2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.82),
        ),
      ),
      child: TextBox(
        controller: controller,
        autofocus: autofocus,
        maxLines: maxLines,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: dense ? 8 : 9,
        ),
        style: FluentTheme.of(context).typography.body?.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 12,
            ),
        placeholder: placeholder,
        decoration: WidgetStateProperty.all(const BoxDecoration()),
        onSubmitted: (_) => _handleSubmit(),
      ),
    );
  }

  Widget _buildSavePathField({bool dense = false}) {
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
              return AppTheme.bgLayer2.withValues(alpha: 0.9);
            }),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                side: BorderSide(
                  color: AppTheme.borderSubtle.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
          child: SizedBox(
            width: dense ? 42 : 44,
            height: dense ? 38 : 42,
            child: Center(
              child: Icon(
                CustomIcons.FluentIcons.folder_open,
                size: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMetric({
    required String title,
    required String value,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.82),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.24),
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

  Widget _buildActionBar() {
    return switch (_stage) {
      _PopupWindowStage.compose => _buildComposeActionBar(),
      _PopupWindowStage.progress => _buildProgressActionBar(),
      _PopupWindowStage.completed => _buildCompletedActionBar(),
    };
  }

  Widget _buildComposeActionBar() {
    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.borderSubtle.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _effectivePreviewFileName(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_currentHostLabel()}  •  ${_currentFolderLabel()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 10.5,
                      ),
                ),
              ],
            ),
          ),
          Button(
            onPressed: _isSubmitting ? null : _closeWindow,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CustomIcons.FluentIcons.dismiss_20, size: 13),
                const SizedBox(width: 8),
                Text(t.popupDownloadCancel),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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

  Widget _buildProgressActionBar() {
    final snapshot = _taskSnapshot;
    final canResume = snapshot?.isPaused == true || snapshot?.isFailed == true;
    final canPause =
        snapshot?.isDownloading == true || snapshot?.isMerging == true;
    final canToggle = canPause || canResume;

    return Container(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.borderSubtle.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_statusLabel(snapshot?.status)}  •  ${_effectivePreviewFileName()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 11.5,
                  ),
            ),
          ),
          if (canToggle)
            Button(
              onPressed: _isTransferActionBusy ? null : _toggleTransferState,
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
              child: _isTransferActionBusy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          canResume
                              ? CustomIcons.FluentIcons.play_20
                              : CustomIcons.FluentIcons.pause_20,
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          canResume
                              ? t.popupDownloadActionResume
                              : t.popupDownloadActionPause,
                        ),
                      ],
                    ),
            ),
          if (canToggle) const SizedBox(width: 8),
          FilledButton(
            onPressed: _closeWindow,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  snapshot?.isDownloading == true ||
                          snapshot?.isPending == true ||
                          snapshot?.isMerging == true
                      ? CustomIcons.FluentIcons.subtract_20
                      : CustomIcons.FluentIcons.dismiss_20,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Text(
                  snapshot?.isDownloading == true ||
                          snapshot?.isPending == true ||
                          snapshot?.isMerging == true
                      ? t.popupDownloadActionBackground
                      : t.popupDownloadActionClose,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedActionBar() {
    return Container(
      padding: const EdgeInsets.only(top: 5, bottom: 3),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.borderSubtle.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: Row(
        children: [
          Button(
            onPressed: _openDownloadedFileWithChooser,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CustomIcons.FluentIcons.apps_20, size: 13),
                const SizedBox(width: 6),
                Text(_openWithActionLabel),
              ],
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _openDownloadedFile,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CustomIcons.FluentIcons.document_20, size: 13),
                const SizedBox(width: 6),
                Text(t.popupDownloadActionOpenFile),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Button(
            onPressed: _openDownloadFolder,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CustomIcons.FluentIcons.folder_open_20, size: 13),
                const SizedBox(width: 6),
                Text(t.popupDownloadActionOpenFolder),
              ],
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: _closeWindow,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CustomIcons.FluentIcons.dismiss_20, size: 13),
                const SizedBox(width: 6),
                Text(t.popupDownloadActionClose),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _effectivePreviewFileName() {
    final tracked = _taskSnapshot?.fileName.trim();
    if (tracked != null && tracked.isNotEmpty) {
      return tracked;
    }
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

  String _currentFolderLabel() {
    final path = _savePathController.text.trim();
    if (path.isEmpty) {
      return 'Downloads';
    }

    final normalized = path.replaceAll('/', '\\');
    final segments = normalized
        .split('\\')
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return normalized;
    }
    return segments.last;
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

  bool _hasContextDetails() {
    return widget.launchData.referer?.trim().isNotEmpty == true ||
        widget.launchData.userAgent?.trim().isNotEmpty == true;
  }

  String _contextDetailsSummary() {
    final hasReferer = widget.launchData.referer?.trim().isNotEmpty == true;
    final hasUserAgent = widget.launchData.userAgent?.trim().isNotEmpty == true;
    if (hasReferer && hasUserAgent) {
      return 'Additional request metadata available';
    }
    if (hasReferer) {
      return 'Referer metadata available';
    }
    if (hasUserAgent) {
      return 'User-Agent metadata available';
    }
    return '';
  }

  String _headerCountLabel() {
    final count = widget.launchData.headers?.length ?? 0;
    return count > 0 ? count.toString() : '--';
  }

  String _currentSavePathLabel() {
    final path = _savePathController.text.trim();
    return path.isEmpty ? t.popupDownloadSavePathPlaceholder : path;
  }

  String _summaryTitle() {
    return switch (_stage) {
      _PopupWindowStage.compose => t.popupDownloadTitle,
      _PopupWindowStage.progress => t.popupDownloadProgressTitle,
      _PopupWindowStage.completed => t.popupDownloadCompletedTitle,
    };
  }

  String _summarySubtitle() {
    if (_stage == _PopupWindowStage.progress && _taskSnapshot != null) {
      return '${_downloadedSummary()}  •  ${_formatSpeed(_taskSnapshot!.speed)}';
    }
    return '${_currentHostLabel()}  •  ${_currentFolderLabel()}';
  }

  String _summaryPillLabel() {
    return switch (_stage) {
      _PopupWindowStage.compose => _currentExtensionLabel(),
      _PopupWindowStage.progress => _taskSnapshot == null ||
              _taskSnapshot!.isPending ||
              _taskSnapshot!.isFailed ||
              _taskSnapshot!.isPaused ||
              _taskSnapshot!.isMerging
          ? _statusLabel(_taskSnapshot?.status)
          : _formatPercent(_taskSnapshot?.progress ?? 0),
      _PopupWindowStage.completed => t.popupDownloadStatusCompleted,
    };
  }

  Color _summaryPillAccent() {
    return switch (_stage) {
      _PopupWindowStage.compose => AppTheme.textPrimary,
      _PopupWindowStage.progress => _statusAccent(_taskSnapshot?.status),
      _PopupWindowStage.completed => AppTheme.statusSuccess,
    };
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'downloading':
        return t.popupDownloadStatusDownloading;
      case 'paused':
        return t.popupDownloadStatusPaused;
      case 'merging':
        return t.popupDownloadStatusMerging;
      case 'completed':
        return t.popupDownloadStatusCompleted;
      case 'failed':
        return t.popupDownloadStatusFailed;
      case 'pending':
        return t.popupDownloadStatusPending;
      default:
        return t.popupDownloadStatusUnknown;
    }
  }

  Color _statusAccent(String? status) {
    switch (status) {
      case 'completed':
        return AppTheme.statusSuccess;
      case 'failed':
        return AppTheme.statusError;
      case 'paused':
        return AppTheme.statusWarning;
      case 'merging':
        return AppTheme.accentLight;
      case 'pending':
        return AppTheme.textSecondary;
      default:
        return AppTheme.accentPrimary;
    }
  }

  String _progressHeroMessage() {
    final snapshot = _taskSnapshot;
    if (snapshot == null) {
      return t.popupDownloadProgressWaiting;
    }
    if (snapshot.isFailed) {
      final error = snapshot.error?.trim();
      return error != null && error.isNotEmpty
          ? error
          : t.popupDownloadStatusFailed;
    }
    if (snapshot.isPending) {
      final languageCode = Localizations.localeOf(context).languageCode;
      if (languageCode.toLowerCase() == 'zh') {
        return '当前有其他下载在进行，任务正在队列中等待启动';
      }
      return 'Waiting in queue for an available download slot';
    }
    return t.popupDownloadProgressHint;
  }

  String _downloadedSummary() {
    final snapshot = _taskSnapshot;
    if (snapshot == null) {
      return '--';
    }
    final downloaded = _formatBytes(snapshot.downloadedSize);
    if (snapshot.totalSize <= 0) {
      return downloaded;
    }
    return '$downloaded / ${_formatBytes(snapshot.totalSize)}';
  }

  String _formatPercent(double value) {
    final safe = value.clamp(0, 100).toDouble();
    return '${safe.toStringAsFixed(safe >= 100 ? 0 : 1)}%';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '--';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '--';
    return '${_formatBytes(bytesPerSecond)}/s';
  }

  String _formatRemainingSeconds(int seconds) {
    if (seconds <= 0) return '--';
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) {
      return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
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
      _scheduleCurrentLayoutHeightSync();
    } catch (e) {
      _logToMain('error', 'Folder picker failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = t.popupDownloadErrorAddFailed(e.toString());
      });
      _scheduleCurrentLayoutHeightSync();
    }
  }

  Future<void> _openDownloadFolder() async {
    final savePath = _savePathController.text.trim();
    if (savePath.isEmpty) {
      setState(() => _errorText = t.popupDownloadSavePathPlaceholder);
      _scheduleCurrentLayoutHeightSync();
      return;
    }

    try {
      final fileName = _effectivePreviewFileName().trim();
      final candidateFile = fileName.isEmpty
          ? null
          : File('${savePath.replaceAll('/', '\\')}\\$fileName');
      if (candidateFile != null && await candidateFile.exists()) {
        await Process.start(
          'explorer',
          ['/select,', candidateFile.path],
          mode: ProcessStartMode.detached,
        );
      } else {
        await Process.start(
          'explorer',
          [savePath.replaceAll('/', '\\')],
          mode: ProcessStartMode.detached,
        );
      }
      if (mounted && _errorText != null) {
        setState(() => _errorText = null);
      }
      await _closeWindow();
    } catch (e) {
      _logToMain('error', 'Open download folder failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = t.popupDownloadErrorOpenFolderFailed(e.toString());
      });
      _scheduleCurrentLayoutHeightSync();
    }
  }

  Future<void> _openDownloadedFileWithChooser() async {
    final filePath = _resolvedDownloadedFilePath();
    if (filePath == null) {
      setState(() => _errorText = t.popupDownloadSavePathPlaceholder);
      _scheduleCurrentLayoutHeightSync();
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw StateError(file.path);
      }
      if (Platform.isWindows) {
        final safePath = file.path.replaceAll('/', '\\');
        // Cmd.exe interprets some characters as operators, we must escape them with ^
        // We pass the whole command as a single string to cmd /c so Dart doesn't auto-quote the path
        final escapedPath = safePath.replaceAllMapped(
          RegExp(r'[&|()<>^]'),
          (Match m) => '^${m.group(0)}',
        );
        await Process.start(
          'cmd',
          ['/c', 'rundll32.exe shell32.dll,OpenAs_RunDLL $escapedPath'],
          mode: ProcessStartMode.detached,
        );
      } else {
        await Process.start(
          file.path,
          const <String>[],
          mode: ProcessStartMode.detached,
          runInShell: true,
        );
      }
      if (mounted && _errorText != null) {
        setState(() => _errorText = null);
      }
    } catch (e) {
      _logToMain('error', 'Open downloaded file with chooser failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = t.popupDownloadErrorOpenFileFailed(e.toString());
      });
      _scheduleCurrentLayoutHeightSync();
    }
  }

  Future<void> _openDownloadedFile() async {
    final filePath = _resolvedDownloadedFilePath();
    if (filePath == null) {
      setState(() => _errorText = t.popupDownloadSavePathPlaceholder);
      _scheduleCurrentLayoutHeightSync();
      return;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw StateError(file.path);
      }
      await Process.start(
        file.path,
        const <String>[],
        mode: ProcessStartMode.detached,
        runInShell: true,
      );
      if (mounted && _errorText != null) {
        setState(() => _errorText = null);
      }
      await _closeWindow();
    } catch (e) {
      _logToMain('error', 'Open downloaded file failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = t.popupDownloadErrorOpenFileFailed(e.toString());
      });
      _scheduleCurrentLayoutHeightSync();
    }
  }

  String? _resolvedDownloadedFilePath() {
    final savePath = _savePathController.text.trim();
    final fileName = _effectivePreviewFileName().trim();
    if (savePath.isEmpty || fileName.isEmpty) {
      return null;
    }
    return '${savePath.replaceAll('/', '\\')}\\$fileName';
  }

  void _startProgressTracking({
    required String taskId,
    required String fileName,
  }) {
    _progressPollTimer?.cancel();
    setState(() {
      _activeTaskId = taskId;
      _taskSnapshot = _PopupTaskSnapshot(
        taskId: taskId,
        fileName: fileName,
        status: 'pending',
        progress: 0,
        downloadedSize: 0,
        totalSize: 0,
        speed: 0,
        remainingSeconds: 0,
        segments: const [],
      );
      _stage = _PopupWindowStage.progress;
    });
    _scheduleCurrentLayoutHeightSync(force: true);
    _progressPollTimer = Timer.periodic(
      const Duration(milliseconds: 450),
      (_) => unawaited(_pollTaskSnapshot()),
    );
    unawaited(_pollTaskSnapshot(forceLog: true));
  }

  Future<void> _pollTaskSnapshot({bool forceLog = false}) async {
    final taskId = _activeTaskId;
    if (!mounted || taskId == null || taskId.isEmpty || _progressPollInFlight) {
      return;
    }

    _progressPollInFlight = true;
    try {
      final response = await http
          .get(
            Uri.parse('$_popupBridgeBaseUrl/api/progress')
                .replace(queryParameters: {'task_id': taskId}),
          )
          .timeout(const Duration(milliseconds: 900));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (forceLog) {
          _logToMain(
            'warning',
            'Progress polling returned HTTP ${response.statusCode}',
          );
        }
        return;
      }

      final raw = jsonDecode(response.body);
      if (raw is! Map) {
        return;
      }

      final payload = raw.map((key, value) => MapEntry(key.toString(), value));
      if (payload['task_id'] == null || payload['task_id'].toString().isEmpty) {
        return;
      }

      final snapshot = _PopupTaskSnapshot.fromJson(payload);
      if (!mounted) {
        return;
      }

      final nextStage = snapshot.isCompleted
          ? _PopupWindowStage.completed
          : _PopupWindowStage.progress;
      final stageChanged = nextStage != _stage;
      final hadError = (_errorText?.trim().isNotEmpty ?? false);
      final nextErrorText = snapshot.isFailed
          ? ((snapshot.error?.trim().isNotEmpty ?? false)
              ? snapshot.error!.trim()
              : t.popupDownloadStatusFailed)
          : null;
      setState(() {
        _taskSnapshot = snapshot;
        _stage = nextStage;
        _errorText = nextErrorText;
      });
      if (stageChanged || hadError != (nextErrorText != null)) {
        _scheduleCurrentLayoutHeightSync();
      }

      if (snapshot.isCompleted) {
        _progressPollTimer?.cancel();
        _progressPollTimer = null;
        _logToMain('info', 'Popup task completed: ${snapshot.fileName}');
      }
    } catch (e) {
      if (forceLog) {
        _logToMain('warning', 'Progress polling failed: $e');
      }
    } finally {
      _progressPollInFlight = false;
    }
  }

  Future<void> _toggleTransferState() async {
    final snapshot = _taskSnapshot;
    if (snapshot == null || _activeTaskId == null || _isTransferActionBusy) {
      return;
    }

    if (_isDebugPreview) {
      _toggleDebugPreviewTransferState(snapshot);
      return;
    }

    final endpoint =
        snapshot.isPaused || snapshot.isFailed ? 'resume' : 'pause';
    setState(() => _isTransferActionBusy = true);
    try {
      final response = await http.post(
        Uri.parse('$_popupBridgeBaseUrl/api/$endpoint'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'task_id': _activeTaskId}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = response.body.trim();
        if (mounted) {
          setState(() {
            _errorText = body.isNotEmpty
                ? body
                : t.popupDownloadErrorAddFailed('HTTP ${response.statusCode}');
          });
          _scheduleCurrentLayoutHeightSync();
        }
        return;
      }

      if (mounted) {
        setState(() => _errorText = null);
        _scheduleCurrentLayoutHeightSync();
      }
      await _pollTaskSnapshot(forceLog: true);
    } catch (e) {
      _logToMain('error', 'Popup transfer action failed: $e');
      if (mounted) {
        setState(() {
          _errorText = t.popupDownloadErrorAddFailed(e.toString());
        });
        _scheduleCurrentLayoutHeightSync();
      }
    } finally {
      if (mounted) {
        setState(() => _isTransferActionBusy = false);
      } else {
        _isTransferActionBusy = false;
      }
    }
  }

  void _toggleDebugPreviewTransferState(_PopupTaskSnapshot snapshot) {
    final resume = snapshot.isPaused || snapshot.isFailed;
    setState(() {
      _errorText = null;
      _taskSnapshot = snapshot.copyWith(
        status: resume ? 'downloading' : 'paused',
        speed: resume ? 12 * 1024 * 1024 : 0,
        remainingSeconds: resume ? 19 : snapshot.remainingSeconds,
        clearError: true,
      );
    });
  }

  Future<void> _closeWindow() async {
    _logToMain('debug', 'Close requested');
    await _logChannelWindowDebugInfo('close');
    try {
      await _popupWindowChannel.invokeMethod<void>('closeWindow');
      return;
    } catch (e) {
      _logToMain('warning',
          'closeWindow channel failed, fallback to HWND message: $e');
    }

    if (_invokeNativeWindowClose()) {
      return;
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

    _logToMain(
      'warning',
      'FindWindow missed title=${widget.launchData.windowTitle}; skip native HWND fallback to avoid closing the main window',
    );
    return 0;
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

    final result = PostMessage(hwnd, _popupCloseMessage, 0, 0);
    _logToMain('debug', 'Close message posted hwnd=$hwnd result=$result');
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

    final result = PostMessage(hwnd, _popupMinimizeMessage, 0, 0);
    _logToMain('debug', 'Minimize message posted hwnd=$hwnd result=$result');
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

    if (_isDebugPreview) {
      await _simulateDebugPreviewSubmit();
      return;
    }

    final url = _urlController.text.trim();
    final savePath = _savePathController.text.trim();
    var fileName = _fileNameController.text.trim();

    if (url.isEmpty || savePath.isEmpty) {
      setState(() => _errorText = t.popupDownloadErrorMissingInfo);
      _scheduleCurrentLayoutHeightSync();
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.isAbsolute ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _errorText = t.popupDownloadErrorInvalidUrl);
      _scheduleCurrentLayoutHeightSync();
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
    _scheduleCurrentLayoutHeightSync();
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
        final raw = jsonDecode(response.body);
        final payload = raw is Map
            ? raw.map((key, value) => MapEntry(key.toString(), value))
            : const <String, dynamic>{};
        final taskId = payload['task_id']?.toString().trim();
        _logToMain(
          'info',
          'Popup download accepted: $fileName taskId=${taskId ?? 'unknown'}',
        );
        setState(() {
          _isSubmitting = false;
          _errorText = null;
        });
        if (taskId != null && taskId.isNotEmpty) {
          _startProgressTracking(taskId: taskId, fileName: fileName);
        } else {
          _logToMain(
            'warning',
            'Popup download accepted without task id, staying on progress placeholder',
          );
          setState(() {
            _stage = _PopupWindowStage.progress;
            _taskSnapshot = _PopupTaskSnapshot(
              taskId: '',
              fileName: fileName,
              status: 'pending',
              progress: 0,
              downloadedSize: 0,
              totalSize: 0,
              speed: 0,
              remainingSeconds: 0,
              segments: const [],
            );
          });
          _scheduleCurrentLayoutHeightSync(force: true);
        }
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
      _scheduleCurrentLayoutHeightSync();
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
      _scheduleCurrentLayoutHeightSync();
    }
  }

  Future<void> _simulateDebugPreviewSubmit() async {
    final fileName = _fileNameController.text.trim().isNotEmpty
        ? _fileNameController.text.trim()
        : _defaultFileName;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    _scheduleCurrentLayoutHeightSync();

    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _activeTaskId = 'debug-preview-progress';
      _stage = _PopupWindowStage.progress;
      _taskSnapshot = _buildDebugPreviewSnapshot(
        stage: _PopupWindowStage.progress,
        fileName: fileName,
      );
    });
    _scheduleCurrentLayoutHeightSync(force: true);
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
          width: 32,
          height: 24,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4.5),
          ),
          child: Icon(
            widget.icon,
            size: 13,
            color: foregroundColor,
          ),
        ),
      ),
    );
  }
}
