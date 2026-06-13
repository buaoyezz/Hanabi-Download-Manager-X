import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_delegate.dart';
import 'l10n/fallback_localizations_delegate.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:scroll_animator/scroll_animator.dart';
import 'services/integrated_download_service.dart';
import 'services/kernel/kernel_manager.dart';
import 'services/kernel/next/downloader/proxy_runtime.dart';
import 'services/download_listener_service.dart';
import 'services/clipboard_listener_service.dart';
import 'services/system_tray_service.dart';
import 'services/app_logger_service.dart';
import 'services/logger_service.dart';
import 'services/log_capture.dart';
import 'services/network_status_service.dart';
import 'services/developer_mode_service.dart';
import 'services/client_config_service.dart';
import 'services/native_render_log_service.dart';
import 'services/speed_history_service.dart';
import 'services/quick_path_service.dart';
import 'services/font_service.dart';
import 'services/update_service.dart';
import 'services/window_effect_service.dart';
import 'services/user_profile_service.dart';
import 'services/notification_settings_service.dart';
import 'services/notice_service.dart';
import 'services/crash_report_service.dart';
import 'services/download_failure_stats_service.dart';
import 'services/localization_service.dart';
import 'services/popup_bridge_service.dart';
import 'services/main_window_command_service.dart';
import 'services/single_instance_service.dart';
import 'services/plugin_lifecycle_service.dart';
import 'services/plugin_store_service.dart';
import 'services/plugin_process_runner.dart';
import 'screens/home_screen.dart';
import 'screens/widgets/oobe_dialog.dart';
import 'popup/popup_window_bootstrap.dart';
import 'tray_menu/tray_menu_bootstrap.dart'
    show
        TrayMenuLaunchData,
        TrayMenuThemeConfig,
        parseTrayLocaleTag,
        runTrayMenuApp;
import 'theme/app_theme.dart';
import 'widgets/animated_notifications.dart';
import 'utils/fluent_icons.dart';
import 'utils/constants.dart';
import 'models/download_task.dart';

final systemTrayService = SystemTrayService();
final navigatorKey = GlobalKey<NavigatorState>();

bool get _disableWindowsSemanticsWorkaround =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

Future<void> _loadCustomFonts(FontService fontService) async {
  try {
    final customFonts = fontService.customFonts;
    for (final entry in customFonts.entries) {
      final fontName = entry.key;
      final fontPath = entry.value;

      final file = File(fontPath);
      if (await file.exists()) {
        final fontData = await file.readAsBytes();
        final fontLoader = FontLoader(fontName);
        fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
        await fontLoader.load();
      }
    }
  } catch (e) {
    debugPrint('Error loading custom fonts: $e');
  }
}

Future<void> _configureMainWindowLaunch({
  required ClientConfigService clientConfig,
  required WindowEffectService windowEffectService,
  required bool isAutoStart,
}) async {
  if (!Platform.isWindows) {
    return;
  }

  double screenWidth = 1920.0;
  double screenHeight = 1080.0;
  try {
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    screenWidth = primaryDisplay.size.width;
    screenHeight = primaryDisplay.size.height;
    debugPrint('Screen size: $screenWidth x $screenHeight');
    await clientConfig.autoSetScaleFactorByResolution(
        screenWidth, screenHeight);
  } catch (e) {
    debugPrint('Failed to get screen size: $e');
  }

  final rememberSize = clientConfig.getWindowRememberSize();
  final defaultWidth = clientConfig.getWindowDefaultWidth();
  final defaultHeight = clientConfig.getWindowDefaultHeight();

  double targetWidth = defaultWidth;
  double targetHeight = defaultHeight;
  if (rememberSize) {
    final savedWidth = clientConfig.getWindowWidth();
    final savedHeight = clientConfig.getWindowHeight();
    final isOldConfig = (savedWidth == 1280.0 && savedHeight == 800.0) ||
        (savedWidth == 1200.0 && savedHeight == 800.0);

    if (isOldConfig) {
      await clientConfig.setWindowWidth(defaultWidth);
      await clientConfig.setWindowHeight(defaultHeight);
    } else {
      targetWidth = savedWidth;
      targetHeight = savedHeight;
    }
  }

  final initialSize = Size(
    targetWidth.clamp(600.0, screenWidth).toDouble(),
    targetHeight.clamp(400.0, screenHeight).toDouble(),
  );

  final windowOptions = WindowOptions(
    size: initialSize,
    minimumSize: const Size(600, 400),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Hanabi Download ManagerX',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowEffectService.applyWindowEffect();
    if (!isAutoStart) {
      await windowManager.show();
      await windowManager.focus();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await windowEffectService.applyWindowEffect();
    }
  });
}

@pragma('vm:entry-point')
Future<void> popupMain(List<String> args) async {
  final appLogger = AppLoggerService();
  appLogger.setConsoleOutputEnabled(false);
  LogCapture.install(appLogger);

  await LogCapture.runZoned(appLogger, () async {
    WidgetsFlutterBinding.ensureInitialized();
    await appLogger.initialize();
    await LoggerService().initialize();
    await NativeRenderLogService().start();

    PopupWindowThemeConfig? popupThemeConfig;
    try {
      final clientConfig = ClientConfigService();
      final fontService = FontService();
      final localizationService = LocalizationService();
      await clientConfig.initialize();
      await fontService.loadFont();
      await localizationService.initialize(clientConfig);
      fontService.updateLanguagePackDefaults(localizationService.languagePacks);
      await _loadCustomFonts(fontService);

      final launchData = PopupWindowLaunchData.fromArgs(args);
      final popupLocale = parsePopupLocaleTag(launchData.localeTag) ??
          WidgetsBinding.instance.platformDispatcher.locale;
      final fontStack = fontService.resolveFontStack(popupLocale);
      popupThemeConfig = PopupWindowThemeConfig(
        themeMode:
            AppThemeModeStorage.fromStorageValue(clientConfig.getThemeMode()),
        fontFamily: fontStack.primaryFamily,
        fontFamilyFallback: fontStack.fallbackFamilies,
        textScaleFactor: clientConfig.getWindowScaleFactor(),
        classicControlVisuals: clientConfig.getClassicControlVisuals(),
      );
    } catch (e) {
      appLogger.warning('Popup', 'Failed to load popup font settings: $e');
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      appLogger.error('PopupFlutter', '${details.exception}\n${details.stack}');
      unawaited(appLogger.flushFullLog());
      unawaited(LoggerService().flush());
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      appLogger.error('PopupPlatform', '$error\n$stack');
      unawaited(appLogger.flushFullLog());
      unawaited(LoggerService().flush());
      return true;
    };

    appLogger.info('Popup', 'Standalone popup starting...');
    await runPopupWindowApp(args, themeConfig: popupThemeConfig);
  });
}

@pragma('vm:entry-point')
Future<void> trayMenuMain(List<String> args) async {
  final appLogger = AppLoggerService();
  appLogger.setConsoleOutputEnabled(false);
  LogCapture.install(appLogger);

  await LogCapture.runZoned(appLogger, () async {
    WidgetsFlutterBinding.ensureInitialized();
    await appLogger.initialize();
    await LoggerService().initialize();
    await NativeRenderLogService().start();

    TrayMenuThemeConfig? trayThemeConfig;
    try {
      final clientConfig = ClientConfigService();
      final fontService = FontService();
      final localizationService = LocalizationService();
      await clientConfig.initialize();
      await fontService.loadFont();
      await localizationService.initialize(clientConfig);
      fontService.updateLanguagePackDefaults(localizationService.languagePacks);
      await _loadCustomFonts(fontService);

      final launchData = TrayMenuLaunchData.fromArgs(args);
      final trayLocale = parseTrayLocaleTag(launchData.localeTag) ??
          WidgetsBinding.instance.platformDispatcher.locale;
      final fontStack = fontService.resolveFontStack(trayLocale);
      trayThemeConfig = TrayMenuThemeConfig(
        themeMode:
            AppThemeModeStorage.fromStorageValue(clientConfig.getThemeMode()),
        fontFamily: fontStack.primaryFamily,
        fontFamilyFallback: fontStack.fallbackFamilies,
        textScaleFactor: clientConfig.getWindowScaleFactor(),
        classicControlVisuals: clientConfig.getClassicControlVisuals(),
      );
    } catch (e) {
      appLogger.warning('TrayMenu', 'Failed to load tray font settings: $e');
    }

    FlutterError.onError = (FlutterErrorDetails details) {
      appLogger.error(
        'TrayMenuFlutter',
        '${details.exception}\n${details.stack}',
      );
      unawaited(appLogger.flushFullLog());
      unawaited(LoggerService().flush());
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      appLogger.error('TrayMenuPlatform', '$error\n$stack');
      unawaited(appLogger.flushFullLog());
      unawaited(LoggerService().flush());
      return true;
    };

    appLogger.info('TrayMenu', 'Standalone tray menu starting...');
    await runTrayMenuApp(args, themeConfig: trayThemeConfig);
  });
}

void main(List<String> args) async {
  final appLogger = AppLoggerService();
  appLogger.setConsoleOutputEnabled(false);
  LogCapture.install(appLogger);

  await LogCapture.runZoned(appLogger, () async {
    WidgetsFlutterBinding.ensureInitialized();
    await appLogger.initialize();
    await LoggerService().initialize();
    await NativeRenderLogService().start();
    await AppConstants.initialize();
    // 以下是主窗口的初始化代码

    // 捕获 Flutter 框架错误，防止 Windows 消息队列错误导致崩溃
    FlutterError.onError = (FlutterErrorDetails details) {
      // 忽略 Windows 消息队列相关的错误
      final message = details.exception.toString();
      if (message.contains('Failed to post message to main thread')) {
        appLogger.debug('Flutter', 'Ignored Windows message queue error');
        return;
      }
      // 其他错误正常处理
      appLogger.error('Flutter', '${details.exception}\n${details.stack}');
      unawaited(appLogger.flushFullLog());
      unawaited(LoggerService().flush());
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      appLogger.error('Platform', '$error\n$stack');
      unawaited(appLogger.flushFullLog());
      unawaited(LoggerService().flush());
      return true;
    };

    // 初始化 WindowManager
    await windowManager.ensureInitialized();

    // 检查是否是开机自启动（启动参数 --autostart）
    final bool isAutoStart = args.contains('--autostart');

    final kernelManager = KernelManager();

    // 初始化服务
    final networkStatus = NetworkStatusService();
    final developerMode = DeveloperModeService();
    final clientConfig = ClientConfigService();
    final quickPathService = QuickPathService();
    final fontService = FontService();
    final updateService = UpdateService(logger: appLogger);
    final windowEffectService = WindowEffectService();
    final userProfileService = UserProfileService();
    final notificationSettings = NotificationSettingsService();
    final noticeService =
        NoticeService(logger: appLogger, config: clientConfig);
    final crashReportService = CrashReportService(logger: appLogger);
    final localizationService = LocalizationService();
    final pluginLifecycleService = PluginLifecycleService();
    final pluginStoreService = PluginStoreService();

    appLogger.info('App', 'Application starting...');
    await clientConfig.initialize();
    await quickPathService.initialize(clientConfig.configDir);
    networkStatus.startMonitoring();
    await developerMode.loadSettings();
    await fontService.loadFont();
    final initialThemeBrightness = AppTheme.resolveBrightness(
      AppThemeModeStorage.fromStorageValue(clientConfig.getThemeMode()),
      platformBrightness:
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    await windowEffectService.initialize(
      initialBrightness: initialThemeBrightness,
    );
    await updateService.initialize();
    await notificationSettings.init(); // 初始化通知设置
    await crashReportService.initialize();
    await NsfxProxyRuntime.ensureSystemProxyObserverStarted();

    // 初始化 FluentIcons（从 JSON 加载图标映射）
    await FluentIcons.initialize();
    appLogger.info('App', 'FluentIcons initialized');

    // 初始化用户配置并启动心跳
    await userProfileService.initialize();
    appLogger.info(
        'App', 'User profile initialized: ${userProfileService.deviceId}');

    await localizationService.initialize(clientConfig);
    appLogger.info('App', 'Localization service initialized');
    fontService.updateLanguagePackDefaults(localizationService.languagePacks);

    // 加载自定义字体（异步，不阻塞启动）
    _loadCustomFonts(fontService).catchError((e) {
      debugPrint('Failed to load custom fonts: $e');
    });

    appLogger.info('App', 'Services initialized');
    noticeService.startOnlineHeartbeat();

    // 插件扫描和插件商店索引加载可能触发大量文件 IO / 网络请求，
    // 放到主服务初始化之后异步执行，避免阻塞首帧和主窗口显示。
    unawaited(Future<void>(() async {
      try {
        await pluginLifecycleService.initialize();
        await pluginStoreService.initialize();
        appLogger.info('Plugin', 'Plugin services initialized asynchronously');
      } catch (e, stack) {
        appLogger.warning(
          'Plugin',
          'Async plugin service initialization failed: $e\n$stack',
        );
      }
    }));

    // 加载速度历史（异步，不阻塞启动）
    SpeedHistoryService().load().catchError((e) {
      debugPrint('Failed to load speed history: $e');
    });

    await _configureMainWindowLaunch(
      clientConfig: clientConfig,
      windowEffectService: windowEffectService,
      isAutoStart: isAutoStart,
    );

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: kernelManager),
          ChangeNotifierProvider(
            create: (context) => IntegratedDownloadService(),
          ),
          ChangeNotifierProvider.value(value: appLogger),
          ChangeNotifierProvider.value(value: DownloadFailureStatsService()),
          ChangeNotifierProvider.value(value: networkStatus),
          ChangeNotifierProvider.value(value: developerMode),
          ChangeNotifierProvider.value(value: clientConfig),
          ChangeNotifierProvider.value(value: quickPathService),
          ChangeNotifierProvider.value(value: fontService),
          ChangeNotifierProvider.value(value: updateService),
          ChangeNotifierProvider.value(value: windowEffectService),
          ChangeNotifierProvider.value(value: userProfileService),
          ChangeNotifierProvider.value(value: noticeService),
          ChangeNotifierProvider.value(value: crashReportService),
          ChangeNotifierProvider.value(value: localizationService),
          ChangeNotifierProvider.value(value: pluginLifecycleService),
          ChangeNotifierProvider.value(value: pluginStoreService),
          Provider<PluginProcessRunner>(create: (_) => PluginProcessRunner()),
          Provider<bool>.value(value: isAutoStart), // 传递启动模式
        ],
        child: const MyApp(),
      ),
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const MethodChannel _windowChannel =
      MethodChannel('com.hanabi.download/window');

  DownloadListenerService? _downloadListener;
  ClipboardListenerService? _clipboardListener;
  PopupBridgeService? _popupBridgeService;
  ClientConfigService? _clientConfig;
  bool _showClientUi = !Platform.isWindows;
  bool _syncingPopupBridge = false;
  bool _oobeDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _windowChannel.setMethodCallHandler(_handleWindowChannelCall);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupSequence();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final clientConfig = context.read<ClientConfigService>();
    if (!identical(_clientConfig, clientConfig)) {
      _clientConfig?.removeListener(_handleClientConfigChanged);
      _clientConfig = clientConfig;
      _clientConfig?.addListener(_handleClientConfigChanged);
    }
  }

  Future<void> _runStartupSequence() async {
    final canContinue = await _resolveExistingInstanceConflictIfNeeded();
    if (!canContinue || !mounted) return;

    _configureTrayMenuTaskProvider();
    setState(() {
      _showClientUi = true;
    });

    await _initSystemTray();
    await _initKernel();
    await _syncPopupBridgeState();
    _initDownloadListener();
    _initClipboardListener();
    await _showOobeIfNeeded();
  }

  void _handleClientConfigChanged() {
    unawaited(_syncPopupBridgeState());
  }

  Future<void> _showOobeIfNeeded() async {
    if (_oobeDialogShown || !mounted) return;

    final isAutoStart = context.read<bool>();
    if (isAutoStart) return;

    final clientConfig = _clientConfig ?? context.read<ClientConfigService>();
    if (!clientConfig.shouldShowOobe()) return;

    _oobeDialogShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || !clientConfig.shouldShowOobe()) return;

    final dialogHostContext = _currentDialogHostContext();
    if (dialogHostContext == null || !dialogHostContext.mounted) return;

    await showHanabiOobeDialog(dialogHostContext);
  }

  void _configureTrayMenuTaskProvider() {
    systemTrayService.activeTaskPayloadProvider = () {
      final downloadService = context.read<IntegratedDownloadService>();
      final activeTasks = downloadService.tasks
          .where((task) =>
              task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.pending ||
              task.status == DownloadStatus.merging)
          .toList(growable: false)
        ..sort((a, b) {
          final statusOrder = _trayTaskStatusOrder(a.status)
              .compareTo(_trayTaskStatusOrder(b.status));
          if (statusOrder != 0) {
            return statusOrder;
          }
          return b.createdAt.compareTo(a.createdAt);
        });

      return activeTasks
          .map(
            (task) => <String, dynamic>{
              'id': task.id,
              'file_name': task.fileName,
              'status': task.status.name,
              'progress': task.progress,
            },
          )
          .toList(growable: false);
    };
  }

  int _trayTaskStatusOrder(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.downloading => 0,
      DownloadStatus.merging => 1,
      DownloadStatus.pending => 2,
      DownloadStatus.paused => 3,
      DownloadStatus.failed => 4,
      DownloadStatus.completed => 5,
    };
  }

  Future<Object?> _handleWindowChannelCall(MethodCall call) async {
    if (call.method != 'handleMainWindowAction') {
      return null;
    }

    final arguments = call.arguments;
    final payload = arguments is Map
        ? arguments.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final action = payload['action']?.toString().trim();
    if (action == null || action.isEmpty) {
      return false;
    }

    systemTrayService.showMainWindow();
    switch (action) {
      case 'show_downloading_page':
        mainWindowCommandService.dispatch(
          MainWindowCommandType.showDownloadingPage,
        );
        return true;
      case 'open_add_download_dialog':
        mainWindowCommandService.dispatch(
          MainWindowCommandType.openAddDownloadDialog,
        );
        return true;
      default:
        return false;
    }
  }

  BuildContext? _currentDialogHostContext() =>
      navigatorKey.currentState?.overlay?.context ??
      navigatorKey.currentContext;

  Future<bool> _showExistingInstanceConflictDialog(
      BuildContext dialogHostContext) async {
    final locale = Localizations.maybeLocaleOf(dialogHostContext);
    final isZh = locale?.languageCode.toLowerCase() == 'zh';

    final title = isZh ? '发现已运行的旧实例' : 'Existing Instance Detected';
    final body = isZh
        ? 'Hanabi Download ManagerX 已经在后台运行。\n\n是否关闭旧实例并打开新的窗口？'
        : 'Hanabi Download ManagerX is already running in the background.\n\n'
            'Do you want to close the old instance and open a new window?';
    final closeLabel = isZh ? '关闭旧实例并继续' : 'Close Old and Continue';
    final cancelLabel = isZh ? '取消打开' : 'Cancel Launch';
    final workingLabel = isZh ? '正在关闭旧实例...' : 'Closing the old instance...';
    final failedLabel = isZh
        ? '无法关闭旧实例，请先手动退出后台中的旧实例后再重试。'
        : 'Failed to close the existing instance. Please exit it manually and try again.';

    final shouldContinue = await fluent.showDialog<bool>(
          context: dialogHostContext,
          barrierColor: Colors.transparent,
          barrierDismissible: false,
          builder: (dialogContext) {
            bool isClosing = false;
            String? errorText;

            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                Future<void> handleTakeover() async {
                  if (isClosing) return;
                  setDialogState(() {
                    isClosing = true;
                    errorText = null;
                  });

                  try {
                    final success = await SingleInstanceService
                        .closeExistingInstanceAndAcquireLock();
                    if (!dialogContext.mounted) return;

                    if (success) {
                      Navigator.of(dialogContext).pop(true);
                      return;
                    }

                    setDialogState(() {
                      isClosing = false;
                      errorText = failedLabel;
                    });
                  } catch (_) {
                    if (!dialogContext.mounted) return;
                    setDialogState(() {
                      isClosing = false;
                      errorText = failedLabel;
                    });
                  }
                }

                return PopScope(
                  canPop: false,
                  child: fluent.ContentDialog(
                    title: Text(title),
                    constraints: const BoxConstraints(maxWidth: 460),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(body),
                        if (isClosing) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const fluent.ProgressRing(strokeWidth: 3),
                              const SizedBox(width: 12),
                              Expanded(child: Text(workingLabel)),
                            ],
                          ),
                        ],
                        if (errorText != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            errorText!,
                            style: TextStyle(color: fluent.Colors.red),
                          ),
                        ],
                      ],
                    ),
                    actions: [
                      fluent.Button(
                        onPressed: isClosing
                            ? null
                            : () => Navigator.of(dialogContext).pop(false),
                        child: Text(cancelLabel),
                      ),
                      fluent.FilledButton(
                        onPressed: isClosing ? null : handleTakeover,
                        child: Text(closeLabel),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ) ??
        false;

    if (shouldContinue) {
      return true;
    }

    await SingleInstanceService.focusExistingInstance();
    exit(0);
  }

  Future<bool> _resolveExistingInstanceConflictIfNeeded() async {
    if (!Platform.isWindows || !mounted) return true;

    final hasConflict = await SingleInstanceService.hasStartupConflict();
    if (!hasConflict || !mounted) return true;
    final isAutoStartLaunch = context.read<bool>();

    if (isAutoStartLaunch) {
      exit(0);
    }

    var dialogHostContext = _currentDialogHostContext();
    if (dialogHostContext == null) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
      dialogHostContext = _currentDialogHostContext();
    }

    if (!mounted) return false;
    if (_currentDialogHostContext() == null) {
      await SingleInstanceService.focusExistingInstance();
      exit(0);
    }

    final resolvedDialogHostContext = _currentDialogHostContext()!;
    // ignore: use_build_context_synchronously
    return _showExistingInstanceConflictDialog(resolvedDialogHostContext);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      // 应用即将退出，清理资源
      _cleanup();
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _initSystemTray() async {
    final isAutoStart = context.read<bool>();
    await systemTrayService.initialize(
      showWindow: false, // 启动时由 doWhenWindowReady 负责显示，避免抢占冲突导致卡死
    );
    if (!isAutoStart) {
      systemTrayService.updateToolTip(true);
    }
  }

  Future<void> _initKernel() async {
    final kernelManager = context.read<KernelManager>();
    final appLogger = AppLoggerService();

    try {
      appLogger.info('App', 'Starting NSFX kernel...');
      final success = await kernelManager.start().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          appLogger.error('App', 'Kernel startup timeout after 30 seconds');
          return false;
        },
      );

      if (!success && mounted) {
        appLogger.error('App', 'Failed to start download kernel');
        _showKernelError();
      } else if (success) {
        appLogger.info('App', 'NSFX kernel started successfully');
      }
    } catch (e) {
      appLogger.error('App', 'Error starting kernel: $e');
      if (mounted) {
        _showKernelError(error: e.toString());
      }
    }
  }

  Future<void> _syncPopupBridgeState() async {
    if (!Platform.isWindows || _syncingPopupBridge) return;

    final clientConfig = _clientConfig ?? context.read<ClientConfigService>();
    final enablePopupWindow = clientConfig.getEnablePopupWindow();
    _syncingPopupBridge = true;

    try {
      if (enablePopupWindow) {
        if (_popupBridgeService != null) return;

        final downloadService = context.read<IntegratedDownloadService>();
        final popupBridgeService = PopupBridgeService(downloadService);
        await popupBridgeService.start();
        _popupBridgeService = popupBridgeService;
        return;
      }

      await _popupBridgeService?.stop();
      _popupBridgeService = null;
    } finally {
      _syncingPopupBridge = false;
    }
  }

  void _showKernelError({String? error}) {
    NotificationManager.of(context)?.showError(
      error != null ? '启动内核时发生错误' : '下载内核启动失败',
      message: error ?? '请查看日志了解详情',
      onTap: () async {
        final devMode =
            Provider.of<DeveloperModeService>(context, listen: false);
        if (!devMode.showLogPage) {
          await devMode.setShowLogPage(true);
        }
      },
    );
  }

  void _initDownloadListener() {
    _downloadListener = DownloadListenerService(context);
    _downloadListener!.startListening();

    // 注意：在线统计功能已移至网页端
    // 访问 https://online.zzbuaoye.net 查看统计数据
  }

  void _initClipboardListener() {
    _clipboardListener = ClipboardListenerService(context);
    _clipboardListener!.start();
  }

  Future<void> _cleanup() async {
    // Cache dependencies before async gaps.
    final kernelManager = context.read<KernelManager>();
    systemTrayService.activeTaskPayloadProvider = null;

    // 保存窗口状态
    try {
      final config = context.read<ClientConfigService>();

      if (config.getWindowRememberSize()) {
        final size = await windowManager.getSize();
        final currentWidth = size.width;
        final currentHeight = size.height;

        // 验证窗口大小是否合理（防止保存异常值）
        // 窗口最小化时，size 可能会变成很小的值（如 160x28），需要过滤掉
        if (currentWidth >= 600 &&
            currentHeight >= 400 &&
            currentWidth <= 4096 &&
            currentHeight <= 2160) {
          debugPrint('Saving window size: $currentWidth x $currentHeight');
          await config.setWindowWidth(currentWidth);
          await config.setWindowHeight(currentHeight);
        } else {
          debugPrint(
              'Invalid window size, not saving: $currentWidth x $currentHeight');
        }
      }
    } catch (e) {
      debugPrint('Failed to save window size: $e');
    }

    _downloadListener?.stopListening();
    _clipboardListener?.stop();
    await _popupBridgeService?.stop();
    _popupBridgeService = null;
    await NsfxProxyRuntime.stopSystemProxyObserver();

    // 停止新内核
    try {
      await kernelManager.stop();
    } catch (e) {
      // 忽略错误
    }

    systemTrayService.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _windowChannel.setMethodCallHandler(null);
    _clientConfig?.removeListener(_handleClientConfigChanged);
    systemTrayService.activeTaskPayloadProvider = null;
    // 同步清理，不等待异步操作
    _downloadListener?.stopListening();
    _clipboardListener?.stop();
    _popupBridgeService?.stop();
    _popupBridgeService = null;
    systemTrayService.dispose();
    NsfxProxyRuntime.stopSystemProxyObserver();

    // 异步清理新内核（不等待）
    try {
      final kernelManager = context.read<KernelManager>();
      kernelManager.stop();
    } catch (e) {
      // 忽略错误
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pluginService = context.watch<PluginLifecycleService>();
    Map<String, dynamic>? activeThemeOverrides;
    for (final plugin in pluginService.plugins) {
      if (plugin.enabled &&
          plugin.manifest.supportsCapability('theme_provider') &&
          plugin.manifest.themeOverrides != null) {
        activeThemeOverrides = plugin.manifest.themeOverrides;
        break;
      }
    }
    AppTheme.applyPluginOverrides(activeThemeOverrides);

    return Consumer3<FontService, ClientConfigService, LocalizationService>(
      builder:
          (context, fontService, clientConfig, localizationService, child) {
        final themeMode =
            AppThemeModeStorage.fromStorageValue(clientConfig.getThemeMode());
        final baseTheme = AppTheme.themeDataForMode(
          themeMode,
          platformBrightness:
              WidgetsBinding.instance.platformDispatcher.platformBrightness,
          classicControlVisuals: clientConfig.getClassicControlVisuals(),
        );
        AppTheme.applyBrightness(
          baseTheme.brightness,
          classicControlVisuals: clientConfig.getClassicControlVisuals(),
        );
        unawaited(
          context
              .read<WindowEffectService>()
              .setThemeBrightness(baseTheme.brightness),
        );
        final typography = baseTheme.typography;
        final scaleFactor = clientConfig.getWindowScaleFactor();
        final fontStack =
            fontService.resolveFontStack(localizationService.effectiveLocale);
        final fontFamily = fontStack.primaryFamily;
        final fontFallbacks = fontStack.fallbackFamilies;

        return fluent.FluentApp(
          navigatorKey: navigatorKey,
          title: 'Hanabi Download ManagerX',
          locale: localizationService.effectiveLocale,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          localizationsDelegates: [
            AppLocalizationsDelegate(localizationService),
            const FallbackFluentLocalizationsDelegate(),
            const FallbackMaterialLocalizationsDelegate(),
            const FallbackCupertinoLocalizationsDelegate(),
            GlobalWidgetsLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) {
              return localizationService.effectiveLocale;
            }
            return localizationService.resolveSupportedLocale(locale);
          },
          supportedLocales: localizationService.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: baseTheme.copyWith(
            typography: fluent.Typography.raw(
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
          ),
          builder: (context, child) {
            AppTheme.applyFluentTheme(
              fluent.FluentTheme.of(context),
              classicControlVisuals: clientConfig.getClassicControlVisuals(),
            );
            Widget content = NotificationManager(
              child: child!,
            );
            content = DefaultTextStyle.merge(
              style: TextStyle(
                fontFamily: fontFamily,
                fontFamilyFallback: fontFallbacks,
              ),
              child: content,
            );
            if (!kIsWeb &&
                const {
                  TargetPlatform.windows,
                  TargetPlatform.linux,
                  TargetPlatform.macOS,
                }.contains(defaultTargetPlatform)) {
              content = AnimatedPrimaryScrollController(
                animationFactory: const ChromiumEaseInOut(),
                child: content,
              );
            }
            if (_disableWindowsSemanticsWorkaround) {
              // Work around repeated AXTree update failures on Flutter Windows.
              content = ExcludeSemantics(child: content);
            }
            content = _WindowCornerFrame(child: content);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scaleFactor),
              ),
              child: content,
            );
          },
          home:
              _showClientUi ? const HomeScreen() : const _StartupShellScreen(),
        );
      },
    );
  }
}

class _StartupShellScreen extends StatelessWidget {
  const _StartupShellScreen();

  @override
  Widget build(BuildContext context) {
    final brightness = fluent.FluentTheme.of(context).brightness;
    final backgroundColor = brightness == Brightness.dark
        ? const Color(0xFF202020)
        : const Color(0xFFF3F3F3);
    return ColoredBox(
      color: backgroundColor,
      child: const SizedBox.expand(),
    );
  }
}

class _WindowCornerFrame extends StatefulWidget {
  final Widget child;

  const _WindowCornerFrame({required this.child});

  @override
  State<_WindowCornerFrame> createState() => _WindowCornerFrameState();
}

class _WindowCornerFrameState extends State<_WindowCornerFrame>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      unawaited(_syncMaximizedState());
    }
  }

  Future<void> _syncMaximizedState() async {
    try {
      final isMaximized = await windowManager.isMaximized();
      if (mounted) {
        setState(() => _isMaximized = isMaximized);
      }
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() => _isMaximized = true);
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() => _isMaximized = false);
    }
  }

  @override
  void onWindowRestore() {
    unawaited(_syncMaximizedState());
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return widget.child;
    }

    final windowEffect = context.watch<WindowEffectService>();
    if (!windowEffect.usesCustomWindowClip || _isMaximized) {
      return widget.child;
    }

    final radius = windowEffect.roundedCornersEnabled
        ? windowEffect.windowCornerRadius
        : 0.0;
    if (radius <= 0) {
      return widget.child;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: widget.child,
    );
  }
}
