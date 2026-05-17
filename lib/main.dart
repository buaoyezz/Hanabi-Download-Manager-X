import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
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
import 'services/speed_chart_settings_service.dart';
import 'services/quick_path_service.dart';
import 'services/font_service.dart';
import 'services/process_memory_trim_service.dart';
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

    // 初始化 Acrylic/Mica 效果 - 只初始化，不设置效果
    // 效果由 WindowEffectService 通过自定义 C++ 代码控制
    await Window.initialize();
    // 注意：不再调用 Window.setEffect()，由 flutter_window.cpp 处理

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
    final speedChartSettings = SpeedChartSettingsService();
    final noticeService =
        NoticeService(logger: appLogger, config: clientConfig);
    final crashReportService = CrashReportService(logger: appLogger);
    final localizationService = LocalizationService();
    final pluginLifecycleService = PluginLifecycleService();
    final pluginStoreService = PluginStoreService();
    var foregroundServicesStarted = false;
    var foregroundServicesStarting = false;

    Future<void> ensureForegroundServicesStarted() async {
      if (foregroundServicesStarted || foregroundServicesStarting) {
        return;
      }
      foregroundServicesStarting = true;
      try {
        networkStatus.startMonitoring();
        await FluentIcons.initialize();
        appLogger.info('App', 'FluentIcons initialized');
        noticeService.startOnlineHeartbeat();
        await pluginLifecycleService.initialize();
        await pluginStoreService.initialize();
        appLogger.info('Plugin', 'Plugin services initialized');
        foregroundServicesStarted = true;
      } catch (e, stack) {
        appLogger.warning(
          'App',
          'Foreground service initialization failed: $e\n$stack',
        );
      } finally {
        foregroundServicesStarting = false;
      }
    }

    appLogger.info('App', 'Application starting...');
    await clientConfig.initialize();
    await quickPathService.initialize(clientConfig.configDir);
    if (!isAutoStart) {
      networkStatus.startMonitoring();
    }
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
    await speedChartSettings.initialize();
    await crashReportService.initialize();
    await NsfxProxyRuntime.ensureSystemProxyObserverStarted();

    if (!isAutoStart) {
      await ensureForegroundServicesStarted();
    }

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

    // 加载速度历史（异步，不阻塞启动）
    SpeedHistoryService().load().catchError((e) {
      debugPrint('Failed to load speed history: $e');
    });

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: kernelManager),
          ChangeNotifierProvider(
            create: (context) => IntegratedDownloadService(
              startPluginTaskPolling: !isAutoStart,
            ),
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
          ChangeNotifierProvider.value(value: speedChartSettings),
          ChangeNotifierProvider.value(value: noticeService),
          ChangeNotifierProvider.value(value: crashReportService),
          ChangeNotifierProvider.value(value: localizationService),
          ChangeNotifierProvider.value(value: pluginLifecycleService),
          ChangeNotifierProvider.value(value: pluginStoreService),
          Provider<PluginProcessRunner>(create: (_) => PluginProcessRunner()),
          Provider<bool>.value(value: isAutoStart), // 传递启动模式
          Provider<Future<void> Function()>.value(
            value: ensureForegroundServicesStarted,
          ),
        ],
        child: const MyApp(),
      ),
    );

    doWhenWindowReady(() async {
      final win = appWindow;
      // 使用已经初始化的 ClientConfigService 实例
      // 注意：不能创建新实例，因为配置还没有加载

      // 获取屏幕大小（使用 screen_retriever）
      double screenWidth = 1920.0;
      double screenHeight = 1080.0;
      try {
        final primaryDisplay = await screenRetriever.getPrimaryDisplay();
        screenWidth = primaryDisplay.size.width;
        screenHeight = primaryDisplay.size.height;
        debugPrint('Screen size: $screenWidth x $screenHeight');

        // 根据屏幕分辨率自动设置缩放比例
        await clientConfig.autoSetScaleFactorByResolution(
            screenWidth, screenHeight);
      } catch (e) {
        debugPrint('Failed to get screen size: $e');
      }

      // 根据是否记忆大小来决定使用哪个尺寸
      // 使用已初始化的 clientConfig 实例
      Size initialSize;
      final rememberSize = clientConfig.getWindowRememberSize();
      final defaultWidth = clientConfig.getWindowDefaultWidth();
      final defaultHeight = clientConfig.getWindowDefaultHeight();

      debugPrint('Remember size: $rememberSize');
      debugPrint('Default size: $defaultWidth x $defaultHeight');

      if (rememberSize) {
        // 使用上次保存的大小，但不超过屏幕大小
        final savedWidth = clientConfig.getWindowWidth();
        final savedHeight = clientConfig.getWindowHeight();
        debugPrint('Saved size: $savedWidth x $savedHeight');

        // 检查是否是旧配置（width/height 是旧的默认值 1280x800 或其他不合理的值）
        // 如果 saved size 明显不合理（比如是旧的硬编码值），使用 default size
        bool isOldConfig = false;

        // 检测常见的旧默认值
        if ((savedWidth == 1280.0 && savedHeight == 800.0) ||
            (savedWidth == 1200.0 && savedHeight == 800.0)) {
          isOldConfig = true;
          debugPrint(
              'Detected old config with hardcoded size, migrating to default size');
        }

        double targetWidth = savedWidth;
        double targetHeight = savedHeight;

        if (isOldConfig) {
          // 使用默认大小并更新配置
          targetWidth = defaultWidth;
          targetHeight = defaultHeight;
          await clientConfig.setWindowWidth(defaultWidth);
          await clientConfig.setWindowHeight(defaultHeight);
          debugPrint(
              'Migrated to default size: $defaultWidth x $defaultHeight');
        }

        final safeWidth = targetWidth.clamp(600.0, screenWidth);
        final safeHeight = targetHeight.clamp(400.0, screenHeight);
        initialSize = Size(safeWidth, safeHeight);
        debugPrint('Using saved size (clamped): $safeWidth x $safeHeight');
      } else {
        // 使用默认大小，但不超过屏幕大小
        final safeWidth = defaultWidth.clamp(600.0, screenWidth);
        final safeHeight = defaultHeight.clamp(400.0, screenHeight);
        initialSize = Size(safeWidth, safeHeight);
        debugPrint('Using default size (clamped): $safeWidth x $safeHeight');
      }

      // 设置窗口属性
      win.minSize = const Size(600, 400);
      win.alignment = Alignment.center;
      win.title = "Hanabi Download ManagerX";

      // 设置窗口大小（需要在 show 之前设置）
      win.size = initialSize;
      debugPrint(
          'Window size requested: ${initialSize.width} x ${initialSize.height}');

      if (isAutoStart) {
        win.hide();
        final result =
            systemTrayService.onMainWindowVisibilityChanged?.call(false);
        if (result is Future<void>) {
          unawaited(result);
        }
      } else {
        final result =
            systemTrayService.onMainWindowVisibilityChanged?.call(true);
        if (result is Future<void>) {
          unawaited(result);
        }
        win.show();
        win.restore();
      }

      // 显示后再次确认窗口大小（bitsdojo_window 的 bug workaround）
      await Future.delayed(const Duration(milliseconds: 100));
      win.size = initialSize;
      debugPrint(
          'Window size confirmed: ${initialSize.width} x ${initialSize.height}');
    });
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
  bool _renderClientUi = !Platform.isWindows;
  bool _syncingPopupBridge = false;
  bool _oobeDialogShown = false;
  Timer? _clientUiSuspendTimer;
  final List<Timer> _clientUiMemoryTrimTimers = <Timer>[];
  int _clientUiTrimGeneration = 0;
  int? _foregroundImageCacheMaximumSize;
  int? _foregroundImageCacheMaximumSizeBytes;

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
    _configureWindowVisibilityPerformanceMode();
    final isAutoStart = context.read<bool>();
    setState(() {
      _showClientUi = true;
      _renderClientUi = !Platform.isWindows || !isAutoStart;
    });
    if (Platform.isWindows) {
      _applyWindowVisibilityPerformanceMode(!isAutoStart);
    }

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

  void _configureWindowVisibilityPerformanceMode() {
    systemTrayService.onMainWindowVisibilityChanged =
        _applyWindowVisibilityPerformanceMode;
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
          .take(4)
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

  Future<void> _applyWindowVisibilityPerformanceMode(bool visible) async {
    if (!mounted) {
      return;
    }
    final downloadService = context.read<IntegratedDownloadService>();
    final networkStatus = context.read<NetworkStatusService>();
    if (visible) {
      unawaited(context.read<Future<void> Function()>()());
      unawaited(downloadService.enablePluginTaskPolling());
    }
    downloadService.setForegroundActive(visible);
    networkStatus.setForegroundActive(visible);
    _downloadListener?.setForegroundActive(visible);
    _clipboardListener?.setForegroundActive(visible);
    await _setClientRenderingActive(visible);
  }

  Future<void> _setClientRenderingActive(bool active) async {
    if (!Platform.isWindows || !mounted) {
      return;
    }

    if (active) {
      _clientUiSuspendTimer?.cancel();
      _clientUiSuspendTimer = null;
      _cancelClientUiMemoryTrim();
      if (!_renderClientUi) {
        setState(() {
          _renderClientUi = true;
        });
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      return;
    }

    _clientUiSuspendTimer?.cancel();
    _clientUiSuspendTimer = Timer(const Duration(milliseconds: 350), () {
      _clientUiSuspendTimer = null;
      if (!mounted || _renderClientUi == false) {
        return;
      }
      setState(() {
        _renderClientUi = false;
      });
      _releaseClientUiMemoryForBackground();
    });
  }

  void _releaseClientUiMemoryForBackground() {
    if (!Platform.isWindows) {
      return;
    }

    final generation = ++_clientUiTrimGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _renderClientUi ||
          generation != _clientUiTrimGeneration) {
        return;
      }

      final imageCache = PaintingBinding.instance.imageCache;
      _foregroundImageCacheMaximumSize ??= imageCache.maximumSize;
      _foregroundImageCacheMaximumSizeBytes ??= imageCache.maximumSizeBytes;
      imageCache.maximumSize = 16;
      imageCache.maximumSizeBytes = 8 * 1024 * 1024;
      imageCache.clear();
      imageCache.clearLiveImages();

      _scheduleClientUiMemoryTrimPass(
        generation,
        const Duration(milliseconds: 200),
        'background-ui-unloaded',
      );
      _scheduleClientUiMemoryTrimPass(
        generation,
        const Duration(seconds: 3),
        'background-settled',
      );
    });
  }

  void _scheduleClientUiMemoryTrimPass(
    int generation,
    Duration delay,
    String reason,
  ) {
    late final Timer timer;
    timer = Timer(delay, () {
      _clientUiMemoryTrimTimers.remove(timer);
      if (!mounted ||
          _renderClientUi ||
          generation != _clientUiTrimGeneration) {
        return;
      }
      ProcessMemoryTrimService.trimCurrentProcessWorkingSet(reason: reason);
    });
    _clientUiMemoryTrimTimers.add(timer);
  }

  void _cancelClientUiMemoryTrim() {
    _clientUiTrimGeneration++;
    for (final timer in _clientUiMemoryTrimTimers) {
      timer.cancel();
    }
    _clientUiMemoryTrimTimers.clear();
    _restoreForegroundImageCacheBudget();
  }

  void _restoreForegroundImageCacheBudget() {
    final maximumSize = _foregroundImageCacheMaximumSize;
    final maximumSizeBytes = _foregroundImageCacheMaximumSizeBytes;
    if (maximumSize == null || maximumSizeBytes == null) {
      return;
    }

    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSize = maximumSize;
    imageCache.maximumSizeBytes = maximumSizeBytes;
    _foregroundImageCacheMaximumSize = null;
    _foregroundImageCacheMaximumSizeBytes = null;
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
    if (action == null || action.isEmpty || action == 'show_main_window') {
      await systemTrayService.showMainWindow();
      return action == 'show_main_window';
    }

    await systemTrayService.showMainWindow();
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
    if (Platform.isWindows) {
      _downloadListener!.setForegroundActive(_renderClientUi);
    }

    // 注意：在线统计功能已移至网页端
    // 访问 https://online.zzbuaoye.net 查看统计数据
  }

  void _initClipboardListener() {
    _clipboardListener = ClipboardListenerService(context);
    _clipboardListener!.start();
    if (Platform.isWindows) {
      _clipboardListener!.setForegroundActive(_renderClientUi);
    }
  }

  Future<void> _cleanup() async {
    _clientUiSuspendTimer?.cancel();
    _cancelClientUiMemoryTrim();
    // Cache dependencies before async gaps.
    final kernelManager = context.read<KernelManager>();
    // 保存窗口状态
    try {
      final win = appWindow;
      final config = context.read<ClientConfigService>();

      if (config.getWindowRememberSize()) {
        final currentWidth = win.size.width;
        final currentHeight = win.size.height;

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
    systemTrayService.onMainWindowVisibilityChanged = null;
    systemTrayService.activeTaskPayloadProvider = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clientUiSuspendTimer?.cancel();
    _cancelClientUiMemoryTrim();
    _windowChannel.setMethodCallHandler(null);
    _clientConfig?.removeListener(_handleClientConfigChanged);
    systemTrayService.onMainWindowVisibilityChanged = null;
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
    final shouldRenderClientUi = _showClientUi && _renderClientUi;
    Map<String, dynamic>? activeThemeOverrides;
    if (shouldRenderClientUi) {
      final pluginService = context.watch<PluginLifecycleService>();
      for (final plugin in pluginService.plugins) {
        if (plugin.enabled &&
            plugin.manifest.supportsCapability('theme_provider') &&
            plugin.manifest.themeOverrides != null) {
          activeThemeOverrides = plugin.manifest.themeOverrides;
          break;
        }
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
          home: !_showClientUi
              ? const _StartupShellScreen()
              : shouldRenderClientUi
                  ? const HomeScreen()
                  : const _BackgroundShellScreen(),
        );
      },
    );
  }
}

class _StartupShellScreen extends StatelessWidget {
  const _StartupShellScreen();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class _BackgroundShellScreen extends StatelessWidget {
  const _BackgroundShellScreen();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

class _WindowCornerFrame extends StatelessWidget {
  final Widget child;

  const _WindowCornerFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return child;
    }

    final windowEffect = context.watch<WindowEffectService>();
    if (!windowEffect.usesCustomWindowClip) {
      return child;
    }

    final radius = windowEffect.roundedCornersEnabled
        ? windowEffect.windowCornerRadius
        : 0.0;
    if (radius <= 0) {
      return child;
    }

    final borderRadius = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: AppTheme.borderSubtle.withValues(alpha: 0.55),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
