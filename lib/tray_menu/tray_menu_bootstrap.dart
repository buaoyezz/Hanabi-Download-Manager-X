import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../l10n/fallback_localizations_delegate.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/fluent_icons.dart' as CustomIcons;

const MethodChannel _windowChannel =
    MethodChannel('com.hanabi.download/window');

bool get _disableWindowsSemanticsWorkaround =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

class TrayMenuThemeConfig {
  const TrayMenuThemeConfig({
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

Future<void> runTrayMenuApp(
  List<String> args, {
  TrayMenuThemeConfig? themeConfig,
}) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  await CustomIcons.FluentIcons.initialize();

  final launchData = TrayMenuLaunchData.fromArgs(args);
  final locale = parseTrayLocaleTag(launchData.localeTag) ??
      binding.platformDispatcher.locale;

  runApp(TrayMenuApp(
    launchData: launchData,
    locale: locale,
    themeConfig: themeConfig,
  ));
}

class TrayMenuLaunchData {
  const TrayMenuLaunchData({
    required this.localeTag,
    required this.mousePositionX,
    required this.mousePositionY,
    this.activeTasks = const [],
  });

  final String? localeTag;
  final double mousePositionX;
  final double mousePositionY;
  final List<TrayMenuActiveTaskPreview> activeTasks;

  factory TrayMenuLaunchData.fromJson(Map<String, dynamic> json) {
    final activeTasksRaw = json['active_tasks'];
    return TrayMenuLaunchData(
      localeTag: json['locale']?.toString(),
      mousePositionX: (json['mouse_x'] is num)
          ? (json['mouse_x'] as num).toDouble()
          : double.tryParse(json['mouse_x']?.toString() ?? '') ?? 0.0,
      mousePositionY: (json['mouse_y'] is num)
          ? (json['mouse_y'] as num).toDouble()
          : double.tryParse(json['mouse_y']?.toString() ?? '') ?? 0.0,
      activeTasks: activeTasksRaw is List
          ? activeTasksRaw
              .whereType<Map>()
              .map(
                (entry) => TrayMenuActiveTaskPreview.fromJson(
                  entry.map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                ),
              )
              .toList(growable: false)
          : const <TrayMenuActiveTaskPreview>[],
    );
  }

  factory TrayMenuLaunchData.fromArgs(List<String> args) {
    if (args.isEmpty) {
      return const TrayMenuLaunchData(
        localeTag: null,
        mousePositionX: 0,
        mousePositionY: 0,
      );
    }

    try {
      final json = jsonDecode(args.first) as Map<Object?, Object?>;
      return TrayMenuLaunchData.fromJson(
        json.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return const TrayMenuLaunchData(
        localeTag: null,
        mousePositionX: 0,
        mousePositionY: 0,
        activeTasks: <TrayMenuActiveTaskPreview>[],
      );
    }
  }
}

class TrayMenuActiveTaskPreview {
  const TrayMenuActiveTaskPreview({
    required this.id,
    required this.fileName,
    required this.status,
    required this.progress,
  });

  final String id;
  final String fileName;
  final String status;
  final double progress;

  factory TrayMenuActiveTaskPreview.fromJson(Map<String, dynamic> json) {
    return TrayMenuActiveTaskPreview(
      id: json['id']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      progress: (json['progress'] is num)
          ? (json['progress'] as num).toDouble()
          : double.tryParse(json['progress']?.toString() ?? '') ?? 0,
    );
  }
}

Locale? parseTrayLocaleTag(String? tag) {
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

class TrayMenuApp extends StatelessWidget {
  const TrayMenuApp({
    super.key,
    required this.launchData,
    required this.locale,
    this.themeConfig,
  });

  final TrayMenuLaunchData launchData;
  final Locale locale;
  final TrayMenuThemeConfig? themeConfig;

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
      title: 'Hanabi Tray Menu',
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
      home: TrayMenuWindowPage(launchData: launchData),
    );
  }
}

class TrayMenuWindowPage extends StatefulWidget {
  const TrayMenuWindowPage({
    super.key,
    required this.launchData,
  });

  final TrayMenuLaunchData launchData;

  @override
  State<TrayMenuWindowPage> createState() => _TrayMenuWindowPageState();
}

class _TrayMenuWindowPageState extends State<TrayMenuWindowPage> {
  static const int _windowOuterPadding = 16;
  static const String _updateTrayMenuPayloadMethod = 'updateTrayMenuPayload';

  final GlobalKey _contentKey = GlobalKey();
  bool _isClosing = false;
  bool _isActionRunning = false;
  bool _windowSizeSyncScheduled = false;
  late TrayMenuLaunchData _currentLaunchData;
  int _contentSessionId = 0;
  bool _needsPrecisePosition = true;
  Size? _reportedContentSize;
  int? _lastRequestedWindowHeight;
  int? _lastRequestedWindowWidth;

  @override
  void initState() {
    super.initState();
    _currentLaunchData = widget.launchData;
    _windowChannel.setMethodCallHandler(_handleWindowMethodCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleWindowSizeSync(force: true);
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) {
          return;
        }
        _scheduleWindowSizeSync(force: true);
      });
    });
  }

  @override
  void dispose() {
    _windowChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<Object?> _handleWindowMethodCall(MethodCall call) async {
    if (call.method != _updateTrayMenuPayloadMethod) {
      return null;
    }

    final args = call.arguments;
    String? rawPayload;
    if (args is Map) {
      rawPayload = args['payload']?.toString();
    } else if (args is String) {
      rawPayload = args;
    }

    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return false;
    }

    try {
      final decoded = jsonDecode(rawPayload) as Map<Object?, Object?>;
      final launchData = TrayMenuLaunchData.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      _applyUpdatedLaunchData(launchData);
      return true;
    } catch (e) {
      debugPrint('Failed to update tray menu payload: $e');
      return false;
    }
  }

  void _applyUpdatedLaunchData(TrayMenuLaunchData launchData) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentLaunchData = launchData;
      _contentSessionId++;
      _reportedContentSize = null;
      _needsPrecisePosition = true;
    });
    _scheduleWindowSizeSync(force: true);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      _scheduleWindowSizeSync(force: true);
    });
  }

  Future<void> _closeWindow() async {
    if (_isClosing) return;
    _isClosing = true;
    try {
      await _windowChannel.invokeMethod('closeWindow');
    } finally {
      _isClosing = false;
    }
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isActionRunning || _isClosing) {
      return;
    }
    setState(() => _isActionRunning = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isActionRunning = false);
      } else {
        _isActionRunning = false;
      }
    }
  }

  Future<void> _onShowWindow() async {
    await _runAction(() async {
      try {
        await _windowChannel.invokeMethod('showMainWindow');
      } catch (e) {
        debugPrint('Failed to show main window: $e');
      }
      await _closeWindow();
    });
  }

  Future<void> _openMainWindowToDownloadingPage() async {
    await _runAction(() async {
      try {
        await _windowChannel.invokeMethod(
          'showMainWindowWithAction',
          const <String, Object>{
            'action': 'show_downloading_page',
          },
        );
      } catch (e) {
        debugPrint('Failed to open downloading page from tray: $e');
      }
      await _closeWindow();
    });
  }

  Future<void> _openMainWindowToAddDownload() async {
    await _runAction(() async {
      try {
        await _windowChannel.invokeMethod(
          'showMainWindowWithAction',
          const <String, Object>{
            'action': 'open_add_download_dialog',
          },
        );
      } catch (e) {
        debugPrint('Failed to open add download dialog from tray: $e');
      }
      await _closeWindow();
    });
  }

  Future<void> _onExit() async {
    await _runAction(() async {
      try {
        await _windowChannel.invokeMethod('exitApp');
      } catch (e) {
        debugPrint('Failed to exit app: $e');
      }
      await _closeWindow();
    });
  }

  Future<void> _openDownloadsFolder() async {
    await _runAction(() async {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.current.path;
      final downloadPath = '$home\\Downloads';
      await Process.start(
        'explorer',
        [downloadPath],
        mode: ProcessStartMode.detached,
      );
      await _closeWindow();
    });
  }

  Future<void> _openLogsFolder() async {
    await _runAction(() async {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          Directory.current.path;
      final logsDir =
          Directory('$home\\Documents\\HanabiDownloadManagerX\\logs');
      if (!logsDir.existsSync()) {
        logsDir.createSync(recursive: true);
      }
      await Process.start(
        'explorer',
        [logsDir.path],
        mode: ProcessStartMode.detached,
      );
      await _closeWindow();
    });
  }

  Future<void> _openProjectPage() async {
    await _runAction(() async {
      await Process.start(
        'explorer',
        [AppConstants.githubUrl],
        mode: ProcessStartMode.detached,
      );
      await _closeWindow();
    });
  }

  Future<void> _openOfficialPage() async {
    await _runAction(() async {
      await Process.start(
        'explorer',
        [AppConstants.officialUrl],
        mode: ProcessStartMode.detached,
      );
      await _closeWindow();
    });
  }

  void _scheduleWindowSizeSync({bool force = false}) {
    if (!Platform.isWindows || _windowSizeSyncScheduled) {
      return;
    }
    _windowSizeSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _windowSizeSyncScheduled = false;
      unawaited(_syncWindowSize(force: force));
    });
  }

  void _handleDesiredContentSizeChanged(Size size) {
    final previous = _reportedContentSize;
    if (previous != null &&
        (previous.width - size.width).abs() <= 0.5 &&
        (previous.height - size.height).abs() <= 0.5) {
      return;
    }
    _reportedContentSize = size;
    _scheduleWindowSizeSync(force: true);
  }

  Future<void> _syncWindowSize({bool force = false}) async {
    if (!mounted || !Platform.isWindows) {
      return;
    }

    final context = _contentKey.currentContext;
    if (context == null) {
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final laidOutSize = renderObject.size;
    var measuredHeight = _reportedContentSize?.height ?? laidOutSize.height;
    if (_reportedContentSize == null) {
      try {
        final dryLayoutSize = renderObject.getDryLayout(
          BoxConstraints.tightFor(width: laidOutSize.width),
        );
        if (dryLayoutSize.height.isFinite &&
            dryLayoutSize.height > measuredHeight) {
          measuredHeight = dryLayoutSize.height;
        }
      } catch (_) {
        // Fallback to the current laid out size when dry layout isn't available.
      }
    }

    final contentWidth = _reportedContentSize?.width ?? laidOutSize.width;
    final contentHeight = _reportedContentSize?.height ?? measuredHeight;
    final desiredHeight = contentHeight.ceil() + _windowOuterPadding;
    final desiredWidth = contentWidth.ceil() + _windowOuterPadding;
    final heightUnchanged = _lastRequestedWindowHeight != null &&
        (_lastRequestedWindowHeight! - desiredHeight).abs() <= 1;
    final widthUnchanged = _lastRequestedWindowWidth != null &&
        (_lastRequestedWindowWidth! - desiredWidth).abs() <= 1;

    if (!force && heightUnchanged && widthUnchanged) {
      return;
    }

    _lastRequestedWindowHeight = desiredHeight;
    _lastRequestedWindowWidth = desiredWidth;
    try {
      await _windowChannel.invokeMethod<void>(
        'resizeWindow',
        <String, Object>{
          'width': desiredWidth,
          'height': desiredHeight,
        },
      );
      if (_needsPrecisePosition &&
          (_currentLaunchData.mousePositionX > 0 ||
              _currentLaunchData.mousePositionY > 0)) {
        await _windowChannel.invokeMethod<void>(
          'positionTrayMenu',
          <String, Object>{
            'x': _currentLaunchData.mousePositionX,
            'y': _currentLaunchData.mousePositionY,
          },
        );
        _needsPrecisePosition = false;
      }
    } catch (e) {
      debugPrint('Failed to sync tray menu window size: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          unawaited(_closeWindow());
        },
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.topLeft,
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                _scheduleWindowSizeSync();
                return false;
              },
              child: SizeChangedLayoutNotifier(
                child: KeyedSubtree(
                  key: _contentKey,
                  child: TrayMenuContent(
                    key: ValueKey(_contentSessionId),
                    onShowWindow: _onShowWindow,
                    onCreateDownload: _openMainWindowToAddDownload,
                    onOpenDownloadingPage: _openMainWindowToDownloadingPage,
                    onOpenDownloads: _openDownloadsFolder,
                    onOpenLogs: _openLogsFolder,
                    onOpenProject: _openProjectPage,
                    onOpenOfficial: _openOfficialPage,
                    onExit: _onExit,
                    isBusy: _isActionRunning,
                    activeTasks: _currentLaunchData.activeTasks,
                    onDesiredContentSizeChanged:
                        _handleDesiredContentSizeChanged,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TrayMenuContent extends StatefulWidget {
  final Future<void> Function() onShowWindow;
  final Future<void> Function() onCreateDownload;
  final Future<void> Function() onOpenDownloadingPage;
  final Future<void> Function() onOpenDownloads;
  final Future<void> Function() onOpenLogs;
  final Future<void> Function() onOpenProject;
  final Future<void> Function() onOpenOfficial;
  final Future<void> Function() onExit;
  final bool isBusy;
  final List<TrayMenuActiveTaskPreview> activeTasks;
  final ValueChanged<Size> onDesiredContentSizeChanged;

  const TrayMenuContent({
    super.key,
    required this.onShowWindow,
    required this.onCreateDownload,
    required this.onOpenDownloadingPage,
    required this.onOpenDownloads,
    required this.onOpenLogs,
    required this.onOpenProject,
    required this.onOpenOfficial,
    required this.onExit,
    required this.isBusy,
    required this.activeTasks,
    required this.onDesiredContentSizeChanged,
  });

  @override
  State<TrayMenuContent> createState() => _TrayMenuContentState();
}

class _TrayMenuContentState extends State<TrayMenuContent> {
  static const double _minMenuWidth = 156;
  static const double _maxMenuWidth = 228;
  static const double _menuTileChrome = 58;
  static const double _groupTileChrome = 74;
  static const double _submenuGap = 8;
  static const double _menuTileHeight = 32;
  static const double _panelInnerTop = 6;
  static const double _panelInnerBottom = 5;
  static const TextStyle _menuLabelBaseStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.22,
  );

  static const int _showWindowIndex = 0;
  static const int _createDownloadIndex = 1;
  static const int _activeTasksGroupIndex = 2;
  static const int _foldersGroupIndex = 3;
  static const int _downloadsIndex = 4;
  static const int _logsIndex = 5;
  static const int _linksGroupIndex = 6;
  static const int _projectIndex = 7;
  static const int _officialIndex = 8;
  static const int _activeTaskBaseIndex = 100;
  static const int _moreActiveTasksIndex = 104;
  static const int _exitIndex = 9;

  final GlobalKey _layoutKey = GlobalKey();
  final GlobalKey _mainPanelKey = GlobalKey();
  final GlobalKey _submenuPanelKey = GlobalKey();
  int? _hoveredIndex;
  _TraySubmenuGroup? _activeSubmenu;
  Size? _lastReportedMeasuredSize;
  String? _lastReportedRegionSignature;
  Timer? _submenuCloseTimer;

  @override
  void dispose() {
    _submenuCloseTimer?.cancel();
    super.dispose();
  }

  /// Schedule submenu close with a short delay.
  /// This allows the user to traverse diagonal paths from a main-menu
  /// trigger item to the submenu panel without the submenu flickering away.
  void _scheduleSubmenuClose() {
    _submenuCloseTimer?.cancel();
    _submenuCloseTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      if (_activeSubmenu != null) {
        setState(() => _activeSubmenu = null);
      }
    });
  }

  /// Cancel any pending submenu close (e.g. when the mouse enters a tile
  /// that should keep or change the active submenu).
  void _cancelSubmenuClose() {
    _submenuCloseTimer?.cancel();
    _submenuCloseTimer = null;
  }

  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
            'zh',
          );

  String get _foldersGroupTitle => _isChinese ? '打开目录' : 'Open folders';
  String get _createDownloadTitle => _isChinese ? '新建下载' : 'New download';
  String get _activeTasksGroupTitle => _isChinese ? '正在进行' : 'Active';
  String get _noActiveTasksTitle => _isChinese ? '暂无进行中任务' : 'No active tasks';
  String get _linksGroupTitle => _isChinese ? '相关链接' : 'Links';
  String get _downloadsTitle => _isChinese ? '下载目录' : 'Downloads';
  String get _logsTitle => _isChinese ? '日志目录' : 'Logs';
  String get _projectTitle => _isChinese ? '项目主页' : 'Project';
  String get _officialTitle => _isChinese ? '官方网站' : 'Website';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final resolvedLabelStyle =
        DefaultTextStyle.of(context).style.merge(_menuLabelBaseStyle);
    final mainMenuWidth = _resolveMenuWidth(
      context,
      [
        _MenuWidthSpec(
          label: t.trayMenuShowWindowTitle,
          chrome: _menuTileChrome,
        ),
        _MenuWidthSpec(
          label: _createDownloadTitle,
          chrome: _menuTileChrome,
        ),
        _MenuWidthSpec(
          label: _activeTasksGroupTitle,
          chrome: _groupTileChrome,
        ),
        _MenuWidthSpec(label: _foldersGroupTitle, chrome: _groupTileChrome),
        _MenuWidthSpec(label: _linksGroupTitle, chrome: _groupTileChrome),
        _MenuWidthSpec(label: t.trayMenuExitTitle, chrome: _menuTileChrome),
      ],
      resolvedLabelStyle,
    );
    final submenuSpecs = _activeSubmenuSpecs;
    final submenuWidth = submenuSpecs == null
        ? 0.0
        : _resolveMenuWidth(
            context,
            submenuSpecs
                .map(
                  (spec) => _MenuWidthSpec(
                      label: spec.title, chrome: _menuTileChrome),
                )
                .toList(growable: false),
            resolvedLabelStyle,
          );
    final submenuOffset = _resolveSubmenuOffset(_activeSubmenu);
    _scheduleMeasuredSizeReport();

    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: 0,
      minHeight: 0,
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      child: MouseRegion(
        onExit: (_) {
          if (_hoveredIndex == null && _activeSubmenu == null) {
            return;
          }
          setState(() {
            _hoveredIndex = null;
          });
          _scheduleSubmenuClose();
        },
        child: KeyedSubtree(
          key: _layoutKey,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMenuPanel(
                panelKey: _mainPanelKey,
                width: mainMenuWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMenuTile(
                      spec: _MenuActionSpec(
                        index: _showWindowIndex,
                        icon: CustomIcons.FluentIcons.window_20,
                        title: t.trayMenuShowWindowTitle,
                        iconColor: const Color(0xFF78C4FF),
                        onTap: widget.isBusy
                            ? null
                            : () {
                                unawaited(widget.onShowWindow());
                              },
                      ),
                      closeSubmenuOnEnter: true,
                    ),
                    _buildMenuTile(
                      spec: _MenuActionSpec(
                        index: _createDownloadIndex,
                        icon: CustomIcons.FluentIcons.add_20,
                        title: _createDownloadTitle,
                        iconColor: const Color(0xFFF2C879),
                        onTap: widget.isBusy
                            ? null
                            : () {
                                unawaited(widget.onCreateDownload());
                              },
                      ),
                      closeSubmenuOnEnter: true,
                    ),
                    _buildMenuTile(
                      spec: _MenuActionSpec(
                        index: _activeTasksGroupIndex,
                        icon: CustomIcons.FluentIcons.arrow_download_20,
                        title: _activeTasksGroupTitle,
                        iconColor: const Color(0xFF8FD8A9),
                        onTap: () =>
                            _toggleSubmenu(_TraySubmenuGroup.activeTasks),
                      ),
                      trailing: Icon(
                        CustomIcons.FluentIcons.chevron_right_20,
                        size: 10,
                        color: const Color(0xFF9B9B9B),
                      ),
                      isSelected:
                          _activeSubmenu == _TraySubmenuGroup.activeTasks,
                      submenuToActivateOnEnter: _TraySubmenuGroup.activeTasks,
                    ),
                    _buildMenuTile(
                      spec: _MenuActionSpec(
                        index: _foldersGroupIndex,
                        icon: CustomIcons.FluentIcons.folder_open_20,
                        title: _foldersGroupTitle,
                        iconColor: const Color(0xFF78C4FF),
                        onTap: () => _toggleSubmenu(_TraySubmenuGroup.folders),
                      ),
                      trailing: Icon(
                        CustomIcons.FluentIcons.chevron_right_20,
                        size: 10,
                        color: const Color(0xFF9B9B9B),
                      ),
                      isSelected: _activeSubmenu == _TraySubmenuGroup.folders,
                      submenuToActivateOnEnter: _TraySubmenuGroup.folders,
                    ),
                    _buildMenuTile(
                      spec: _MenuActionSpec(
                        index: _linksGroupIndex,
                        icon: CustomIcons.FluentIcons.link_20,
                        title: _linksGroupTitle,
                        iconColor: const Color(0xFF8FD8A9),
                        onTap: () => _toggleSubmenu(_TraySubmenuGroup.links),
                      ),
                      trailing: Icon(
                        CustomIcons.FluentIcons.chevron_right_20,
                        size: 10,
                        color: const Color(0xFF9B9B9B),
                      ),
                      isSelected: _activeSubmenu == _TraySubmenuGroup.links,
                      submenuToActivateOnEnter: _TraySubmenuGroup.links,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        height: 1,
                        color: AppTheme.borderSubtle,
                      ),
                    ),
                    _buildExitBar(
                      title: t.trayMenuExitTitle,
                      onTap: widget.isBusy
                          ? null
                          : () {
                              unawaited(widget.onExit());
                            },
                    ),
                  ],
                ),
              ),
              if (submenuSpecs != null) ...[
                const SizedBox(width: _submenuGap),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: submenuOffset),
                    _buildMenuPanel(
                      panelKey: _submenuPanelKey,
                      width: submenuWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final spec in submenuSpecs)
                            _buildMenuTile(
                              spec: spec,
                              closeSubmenuOnEnter: false,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleMeasuredSizeReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _layoutKey.currentContext;
      if (context == null) {
        return;
      }
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return;
      }
      final size = renderObject.size;
      _syncTrayMenuRegion(renderObject);

      final previous = _lastReportedMeasuredSize;
      if (previous != null &&
          (previous.width - size.width).abs() <= 0.5 &&
          (previous.height - size.height).abs() <= 0.5) {
        return;
      }
      _lastReportedMeasuredSize = size;
      widget.onDesiredContentSizeChanged(size);
    });
  }

  void _syncTrayMenuRegion(RenderBox layoutBox) {
    if (!Platform.isWindows) {
      return;
    }

    final rects = <Map<String, double>>[];
    void addPanelRect(GlobalKey key) {
      final context = key.currentContext;
      if (context == null) {
        return;
      }

      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return;
      }

      final offset = renderObject.localToGlobal(
        Offset.zero,
        ancestor: layoutBox,
      );
      rects.add(<String, double>{
        'x': offset.dx,
        'y': offset.dy,
        'width': renderObject.size.width,
        'height': renderObject.size.height,
      });
    }

    addPanelRect(_mainPanelKey);
    addPanelRect(_submenuPanelKey);
    if (rects.isEmpty) {
      return;
    }

    final signature = rects
        .map(
          (rect) => [
            rect['x']!.toStringAsFixed(1),
            rect['y']!.toStringAsFixed(1),
            rect['width']!.toStringAsFixed(1),
            rect['height']!.toStringAsFixed(1),
          ].join(','),
        )
        .join('|');
    if (_lastReportedRegionSignature == signature) {
      return;
    }

    _lastReportedRegionSignature = signature;
    unawaited(
      _windowChannel.invokeMethod<void>(
        'setTrayMenuRegion',
        <String, Object>{
          'radius': 14,
          'rects': rects,
        },
      ).catchError((Object e) {
        debugPrint('Failed to sync tray menu region: $e');
      }),
    );
  }

  List<_MenuActionSpec>? get _activeSubmenuSpecs {
    switch (_activeSubmenu) {
      case _TraySubmenuGroup.activeTasks:
        if (widget.activeTasks.isEmpty) {
          return [
            _MenuActionSpec(
              index: _activeTaskBaseIndex,
              icon: CustomIcons.FluentIcons.clock_20,
              title: _noActiveTasksTitle,
              iconColor: const Color(0xFF9B9B9B),
              onTap: null,
            ),
          ];
        }

        final visibleTasks = widget.activeTasks.take(3).toList(growable: false);
        final specs = <_MenuActionSpec>[
          for (var i = 0; i < visibleTasks.length; i++)
            _MenuActionSpec(
              index: _activeTaskBaseIndex + i,
              icon: _taskIconForStatus(visibleTasks[i].status),
              title: visibleTasks[i].fileName.trim().isNotEmpty
                  ? visibleTasks[i].fileName.trim()
                  : visibleTasks[i].id,
              iconColor: _taskColorForStatus(visibleTasks[i].status),
              onTap: widget.isBusy
                  ? null
                  : () {
                      unawaited(widget.onOpenDownloadingPage());
                    },
            ),
        ];

        if (widget.activeTasks.length > visibleTasks.length) {
          specs.add(
            _MenuActionSpec(
              index: _moreActiveTasksIndex,
              icon: CustomIcons.FluentIcons.more_horizontal_20,
              title: '...',
              iconColor: const Color(0xFF9FB0C9),
              onTap: widget.isBusy
                  ? null
                  : () {
                      unawaited(widget.onOpenDownloadingPage());
                    },
            ),
          );
        }

        return specs;
      case _TraySubmenuGroup.folders:
        return [
          _MenuActionSpec(
            index: _downloadsIndex,
            icon: CustomIcons.FluentIcons.arrow_download_20,
            title: _downloadsTitle,
            iconColor: const Color(0xFF78C4FF),
            onTap: widget.isBusy
                ? null
                : () {
                    unawaited(widget.onOpenDownloads());
                  },
          ),
          _MenuActionSpec(
            index: _logsIndex,
            icon: CustomIcons.FluentIcons.document_20,
            title: _logsTitle,
            iconColor: const Color(0xFF9FB0C9),
            onTap: widget.isBusy
                ? null
                : () {
                    unawaited(widget.onOpenLogs());
                  },
          ),
        ];
      case _TraySubmenuGroup.links:
        return [
          _MenuActionSpec(
            index: _projectIndex,
            icon: CustomIcons.FluentIcons.bookmark_20,
            title: _projectTitle,
            iconColor: const Color(0xFF8FD8A9),
            onTap: widget.isBusy
                ? null
                : () {
                    unawaited(widget.onOpenProject());
                  },
          ),
          _MenuActionSpec(
            index: _officialIndex,
            icon: CustomIcons.FluentIcons.globe_20,
            title: _officialTitle,
            iconColor: const Color(0xFFF2C879),
            onTap: widget.isBusy
                ? null
                : () {
                    unawaited(widget.onOpenOfficial());
                  },
          ),
        ];
      case null:
        return null;
    }
  }

  double _resolveSubmenuOffset(_TraySubmenuGroup? group) {
    switch (group) {
      case _TraySubmenuGroup.activeTasks:
        return _panelInnerTop + (_menuTileHeight * 2);
      case _TraySubmenuGroup.folders:
        return _panelInnerTop + (_menuTileHeight * 3);
      case _TraySubmenuGroup.links:
        return _panelInnerTop + (_menuTileHeight * 4);
      case null:
        return 0;
    }
  }

  IconData _taskIconForStatus(String status) {
    switch (status) {
      case 'downloading':
        return CustomIcons.FluentIcons.arrow_download_20;
      case 'merging':
        return CustomIcons.FluentIcons.arrow_sync_20;
      case 'pending':
      default:
        return CustomIcons.FluentIcons.clock_20;
    }
  }

  Color _taskColorForStatus(String status) {
    switch (status) {
      case 'downloading':
        return const Color(0xFF78C4FF);
      case 'merging':
        return const Color(0xFFF2C879);
      case 'pending':
      default:
        return const Color(0xFF8FD8A9);
    }
  }

  void _toggleSubmenu(_TraySubmenuGroup group) {
    setState(() {
      _activeSubmenu = _activeSubmenu == group ? null : group;
    });
  }

  Widget _buildMenuPanel({
    Key? panelKey,
    required double width,
    required Widget child,
  }) {
    return MouseRegion(
      onEnter: (_) => _cancelSubmenuClose(),
      child: Container(
        key: panelKey,
        width: width,
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.borderSubtle,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              6,
              _panelInnerTop,
              6,
              _panelInnerBottom,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required _MenuActionSpec spec,
    Widget? trailing,
    bool isSubmenu = false,
    bool isSelected = false,
    _TraySubmenuGroup? submenuToActivateOnEnter,
    bool closeSubmenuOnEnter = false,
  }) {
    final isHovered = _hoveredIndex == spec.index;
    final isHighlighted = isHovered || isSelected;
    final isDisabled = spec.onTap == null;
    final labelStyle =
        DefaultTextStyle.of(context).style.merge(_menuLabelBaseStyle).copyWith(
              color: isDisabled ? AppTheme.textDisabled : AppTheme.textPrimary,
            );
    const tilePadding = EdgeInsets.fromLTRB(8, 5, 8, 5);
    final tileRadius = isSubmenu ? 9.0 : 10.0;
    const iconBoxSize = 22.0;
    final iconRadius = isSubmenu ? 7.0 : 8.0;
    const iconSize = 11.0;
    final hoverColor = isSubmenu
        ? AppTheme.surfaceCardHover
        : AppTheme.bgLayer2;

    return MouseRegion(
      onEnter: (_) {
        _cancelSubmenuClose();
        final nextSubmenu = closeSubmenuOnEnter
            ? null
            : submenuToActivateOnEnter ?? _activeSubmenu;
        // When this tile would close the submenu, use a delay so that
        // diagonal mouse paths to the submenu panel don't flicker.
        if (closeSubmenuOnEnter && _activeSubmenu != null && nextSubmenu == null) {
          if (_hoveredIndex != spec.index) {
            setState(() => _hoveredIndex = spec.index);
          }
          _scheduleSubmenuClose();
          return;
        }
        final needsUpdate =
            _hoveredIndex != spec.index || _activeSubmenu != nextSubmenu;
        if (!needsUpdate) {
          return;
        }
        setState(() {
          _hoveredIndex = spec.index;
          _activeSubmenu = nextSubmenu;
        });
      },
      onExit: (_) {
        if (_hoveredIndex != spec.index) {
          return;
        }
        setState(() => _hoveredIndex = null);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: spec.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.zero,
          padding: tilePadding,
          decoration: BoxDecoration(
            color: isHighlighted ? hoverColor : Colors.transparent,
            borderRadius: BorderRadius.circular(tileRadius),
          ),
          child: Row(
            children: [
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: spec.iconColor
                      .withValues(alpha: isHighlighted ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(iconRadius),
                ),
                child: Icon(
                  spec.icon,
                  size: iconSize,
                  color: isDisabled ? AppTheme.textDisabled : spec.iconColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  spec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExitBar({
    required String title,
    required VoidCallback? onTap,
  }) {
    final isHovered = _hoveredIndex == _exitIndex;
    final isDisabled = onTap == null;
    final labelStyle =
        DefaultTextStyle.of(context).style.merge(_menuLabelBaseStyle).copyWith(
              color: isDisabled ? AppTheme.textDisabled : AppTheme.textPrimary,
            );
    return MouseRegion(
      onEnter: (_) {
        final needsUpdate =
            _hoveredIndex != _exitIndex || _activeSubmenu != null;
        if (!needsUpdate) {
          return;
        }
        setState(() => _hoveredIndex = _exitIndex);
        // Delay submenu close to allow diagonal mouse paths
        if (_activeSubmenu != null) {
          _scheduleSubmenuClose();
        }
      },
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isHovered
                ? AppTheme.bgLayer2
                : AppTheme.bgLayer1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered
                  ? AppTheme.statusError.withValues(alpha: 0.55)
                  : AppTheme.statusError.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppTheme.statusError.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CustomIcons.FluentIcons.dismiss_20,
                  size: 11,
                  color:
                      isDisabled ? AppTheme.textDisabled : AppTheme.statusError,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _resolveMenuWidth(
    BuildContext context,
    List<_MenuWidthSpec> items,
    TextStyle textStyle,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final maxRowWidth = items.fold<double>(0, (currentMax, item) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: textStyle),
        textDirection: direction,
        maxLines: 1,
        textScaler: scaler,
      )..layout();
      return math.max(currentMax, painter.width + item.chrome);
    });

    return maxRowWidth.clamp(
      _minMenuWidth,
      _maxMenuWidth,
    );
  }
}

class _MenuWidthSpec {
  const _MenuWidthSpec({
    required this.label,
    required this.chrome,
  });

  final String label;
  final double chrome;
}

enum _TraySubmenuGroup {
  activeTasks,
  folders,
  links,
}

class _MenuActionSpec {
  const _MenuActionSpec({
    required this.index,
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final String title;
  final Color iconColor;
  final VoidCallback? onTap;
}
