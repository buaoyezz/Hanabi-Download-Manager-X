import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'dart:io';
import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'services/integrated_download_service.dart';
import 'services/kernel_service.dart';
import 'services/kernel/kernel_manager.dart';
import 'services/download_listener_service.dart';
import 'services/system_tray_service.dart';
import 'services/app_logger_service.dart';
import 'services/log_capture.dart';
import 'services/network_status_service.dart';
import 'services/developer_mode_service.dart';
import 'services/client_config_service.dart';
import 'services/quick_path_service.dart';
import 'services/font_service.dart';
import 'services/update_service.dart';
import 'services/window_effect_service.dart';
import 'services/online_stats_service.dart';
import 'services/user_profile_service.dart';
import 'services/notification_settings_service.dart';
import 'services/pipe_listener_service.dart';
import 'services/popup_progress_service.dart';
import 'services/download_failure_stats_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/animated_notifications.dart';
import 'utils/fluent_icons.dart';

final systemTrayService = SystemTrayService();
final navigatorKey = GlobalKey<NavigatorState>();

/// 获取当前应用的窗口句柄
int _getAppWindowHandle() {
  debugPrint('[Window] Attempting to get window handle...');
  
  // 方法1: 尝试通过窗口标题查找
  final title = 'Hanabi Download ManagerX'.toNativeUtf16();
  var hwnd = FindWindow(nullptr, title);
  calloc.free(title);
  
  if (hwnd != 0) {
    debugPrint('[Window] Found window by title: $hwnd');
    return hwnd;
  }
  debugPrint('[Window] FindWindow by title failed');
  
  // 方法2: 使用前台窗口
  hwnd = GetForegroundWindow();
  if (hwnd != 0) {
    debugPrint('[Window] Found foreground window: $hwnd');
    return hwnd;
  }
  debugPrint('[Window] GetForegroundWindow failed');
  
  // 方法3: 使用活动窗口
  hwnd = GetActiveWindow();
  debugPrint('[Window] GetActiveWindow returned: $hwnd');
  return hwnd;
}

/// 使用 Windows API 正确最大化窗口（不覆盖任务栏）
Future<void> maximizeWindowProperly() async {
  debugPrint('[Window] maximizeWindowProperly called');
  if (Platform.isWindows) {
    try {
      // 使用 Future.microtask 避免在渲染帧期间调用
      await Future.microtask(() {
        final hwnd = _getAppWindowHandle();
        if (hwnd != 0) {
          // 检查并修复窗口样式
          final style = GetWindowLongPtr(hwnd, GWL_STYLE);
          debugPrint('[Window] Current window style: $style');
          
          // 确保窗口有 WS_MAXIMIZEBOX 和 WS_CAPTION 样式
          const WS_MAXIMIZEBOX = 0x00010000;
          const WS_CAPTION = 0x00C00000;
          
          if ((style & WS_MAXIMIZEBOX) == 0 || (style & WS_CAPTION) == 0) {
            debugPrint('[Window] Adding WS_MAXIMIZEBOX and WS_CAPTION styles');
            final newStyle = style | WS_MAXIMIZEBOX | WS_CAPTION;
            SetWindowLongPtr(hwnd, GWL_STYLE, newStyle);
          }
          
          debugPrint('[Window] Calling ShowWindow with SW_MAXIMIZE ($SW_MAXIMIZE) on handle $hwnd');
          final result = ShowWindow(hwnd, SW_MAXIMIZE);
          debugPrint('[Window] ShowWindow returned: $result');
          
          // 验证窗口状态
          final placement = calloc<WINDOWPLACEMENT>();
          placement.ref.length = sizeOf<WINDOWPLACEMENT>();
          if (GetWindowPlacement(hwnd, placement) != 0) {
            debugPrint('[Window] Window showCmd after maximize: ${placement.ref.showCmd}');
            calloc.free(placement);
          }
        } else {
          debugPrint('[Window] Failed to get window handle, using bitsdojo_window');
          appWindow.maximize();
        }
      });
    } catch (e) {
      debugPrint('[Window] Error maximizing window: $e');
      // 如果 Windows API 失败，回退到 bitsdojo_window
      appWindow.maximize();
    }
  } else {
    appWindow.maximize();
  }
}

/// 恢复窗口到正常大小
Future<void> restoreWindowProperly() async {
  if (Platform.isWindows) {
    try {
      await Future.microtask(() {
        final hwnd = _getAppWindowHandle();
        if (hwnd != 0) {
          ShowWindow(hwnd, SW_RESTORE);
          debugPrint('Window restored with handle: $hwnd');
        } else {
          appWindow.restore();
        }
      });
    } catch (e) {
      debugPrint('Error restoring window: $e');
      appWindow.restore();
    }
  } else {
    appWindow.restore();
  }
}

/// 检查窗口是否最大化
bool isWindowMaximized() {
  if (Platform.isWindows) {
    try {
      final hwnd = _getAppWindowHandle();
      if (hwnd != 0) {
        final placement = calloc<WINDOWPLACEMENT>();
        placement.ref.length = sizeOf<WINDOWPLACEMENT>();
        
        if (GetWindowPlacement(hwnd, placement) != 0) {
          final isMaximized = placement.ref.showCmd == SW_MAXIMIZE;
          calloc.free(placement);
          return isMaximized;
        }
        calloc.free(placement);
      }
    } catch (e) {
      debugPrint('Error checking window state: $e');
    }
  }
  // 回退到 bitsdojo_window
  return appWindow.isMaximized;
}

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

void main(List<String> args) async {
  final appLogger = AppLoggerService();
  appLogger.setConsoleOutputEnabled(false);
  LogCapture.install(appLogger);

  await LogCapture.runZoned(appLogger, () async {
    WidgetsFlutterBinding.ensureInitialized();
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
      FlutterError.presentError(details);
    };
    
    // 初始化 Acrylic/Mica 效果 - 只初始化，不设置效果
    // 效果由 WindowEffectService 通过自定义 C++ 代码控制
    await Window.initialize();
    // 注意：不再调用 Window.setEffect()，由 flutter_window.cpp 处理
    
    // 检查是否是开机自启动（启动参数 --autostart）
    final bool isAutoStart = args.contains('--autostart');
    
    final kernelService = KernelService();
    final kernelManager = KernelManager();
    
    // 初始化服务
    final networkStatus = NetworkStatusService();
    final developerMode = DeveloperModeService();
    final clientConfig = ClientConfigService();
    final quickPathService = QuickPathService();
    final fontService = FontService();
    final updateService = UpdateService(logger: appLogger);
    final windowEffectService = WindowEffectService();
    final onlineStatsService = OnlineStatsService();
    final userProfileService = UserProfileService();
    final notificationSettings = NotificationSettingsService();
    
    appLogger.info('App', 'Application starting...');
    await clientConfig.initialize();
    await quickPathService.initialize(clientConfig.configDir);
    networkStatus.startMonitoring();
    await developerMode.loadSettings();
    await fontService.loadFont();
    await windowEffectService.initialize();
    await updateService.initialize();
    await notificationSettings.init(); // 初始化通知设置
    
    // 初始化 FluentIcons（从 JSON 加载图标映射）
    await FluentIcons.initialize();
    appLogger.info('App', 'FluentIcons initialized');
    
    // 初始化用户配置并启动心跳
    await userProfileService.initialize();
    appLogger.info('App', 'User profile initialized: ${userProfileService.deviceId}');
    
    // 加载自定义字体（异步，不阻塞启动）
    _loadCustomFonts(fontService).catchError((e) {
      debugPrint('Failed to load custom fonts: $e');
    });
    
    appLogger.info('App', 'Services initialized');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: kernelService),
          ChangeNotifierProvider.value(value: kernelManager),
          ChangeNotifierProxyProvider<KernelService, IntegratedDownloadService>(
            create: (context) => IntegratedDownloadService(kernelService),
            update: (context, kernel, previous) => previous ?? IntegratedDownloadService(kernel),
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
          ChangeNotifierProvider.value(value: onlineStatsService),
          ChangeNotifierProvider.value(value: userProfileService),
          Provider<bool>.value(value: isAutoStart), // 传递启动模式
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
        await clientConfig.autoSetScaleFactorByResolution(screenWidth, screenHeight);
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
          debugPrint('Detected old config with hardcoded size, migrating to default size');
        }
        
        double targetWidth = savedWidth;
        double targetHeight = savedHeight;
        
        if (isOldConfig) {
          // 使用默认大小并更新配置
          targetWidth = defaultWidth;
          targetHeight = defaultHeight;
          await clientConfig.setWindowWidth(defaultWidth);
          await clientConfig.setWindowHeight(defaultHeight);
          debugPrint('Migrated to default size: $defaultWidth x $defaultHeight');
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
      debugPrint('Window size requested: ${initialSize.width} x ${initialSize.height}');

      if (clientConfig.getWindowMaximized()) {
        debugPrint("Window maximized");
        maximizeWindowProperly();
      } else {
        restoreWindowProperly();
      }
      
      // 注意：bitsdojo_window 不支持 onWindowClose 事件
      // 我们需要在 CloseWindowButton 中自定义处理逻辑
      
      // 如果是开机自启动，隐藏窗口；否则显示窗口
      if (isAutoStart) {
        win.hide();
      } else {
        win.show();
      }
      
      // 显示后再次确认窗口大小（bitsdojo_window 的 bug workaround）
      await Future.delayed(const Duration(milliseconds: 100));
      if (!clientConfig.getWindowMaximized()) {
        win.size = initialSize;
        debugPrint('Window size confirmed: ${initialSize.width} x ${initialSize.height}');
      }
    });
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DownloadListenerService? _downloadListener;
  PipeListenerService? _pipeListener;
  PopupProgressService? _popupProgressService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSystemTray();
      _initKernel();  // 异步启动，不阻塞 UI
      _initDownloadListener();
      _initPipeListener();  // 初始化管道监听
      _initPopupProgressService();  // 初始化弹窗进度推送服务
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      // 应用即将退出，清理资源
      _cleanup();
    }
  }

  Future<void> _initSystemTray() async {
    final kernelService = context.read<KernelService>();
    final isAutoStart = context.read<bool>();
    await systemTrayService.initialize(
      kernelService: kernelService,
      showWindow: !isAutoStart,  // 只在非自启动时显示窗口
    );
  }

  Future<void> _initKernel() async {
    final kernelManager = context.read<KernelManager>();
    final kernelService = context.read<KernelService>();
    final appLogger = AppLoggerService();
    final clientConfig = context.read<ClientConfigService>();
    
    // 读取用户选择的内核类型
    final useNewKernel = clientConfig.getBool('kernel.use_new_kernel', defaultValue: true);
    
    try {
      if (useNewKernel) {
        // 使用新的 NSFX 内核（默认）
        appLogger.info('App', 'Starting NSFX kernel (new)...');
        final success = await kernelManager.start(type: KernelType.next);
        
        if (success) {
          appLogger.info('App', 'NSFX kernel started successfully');
        } else {
          appLogger.error('App', 'Failed to start NSFX kernel, falling back to legacy kernel');
          // 回退到旧内核
          await kernelService.startKernel().timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              appLogger.error('App', 'Legacy kernel startup timeout');
              return false;
            },
          );
        }
      } else {
        // 使用旧的 Python 内核
        appLogger.info('App', 'Starting legacy kernel...');
        final success = await kernelService.startKernel().timeout(
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
          appLogger.info('App', 'Download kernel started successfully');
        }
      }
    } catch (e) {
      appLogger.error('App', 'Error starting kernel: $e');
      if (mounted) {
        _showKernelError(error: e.toString());
      }
    }
  }
  
  void _showKernelError({String? error}) {
    NotificationManager.of(context)?.showError(
      error != null ? '启动内核时发生错误' : '下载内核启动失败',
      message: error ?? '请查看日志了解详情',
      onTap: () async {
        final devMode = Provider.of<DeveloperModeService>(context, listen: false);
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
    // 访问 https://online.zzbuaoye.top 查看统计数据
  }

  /// 初始化管道监听服务，接收来自 Hanabi Popup 的下载请求
  void _initPipeListener() {
    if (!Platform.isWindows) return;

    _pipeListener = PipeListenerService();
    _pipeListener!.onDownloadRequest = (request) {
      debugPrint('[Main] Received download request from popup: ${request.url}');

      // 添加下载任务
      final downloadService = context.read<IntegratedDownloadService>();
      downloadService.addTask(
        request.url,
        request.filename,
      );

      // 显示通知
      final appLogger = context.read<AppLoggerService>();
      appLogger.info('PipeListener', 'Download added from popup: ${request.filename}');
    };

    _pipeListener!.start();
    debugPrint('[Main] Pipe listener started');
  }

  /// 初始化弹窗进度推送服务
  void _initPopupProgressService() {
    final downloadService = context.read<IntegratedDownloadService>();
    _popupProgressService = PopupProgressService(downloadService);
    _popupProgressService!.start();
    debugPrint('[Main] Popup progress service started');
  }

  Future<void> _cleanup() async {
    // 停止在线统计
    try {
      final onlineStats = context.read<OnlineStatsService>();
      onlineStats.stopFetching();
    } catch (e) {
      // 忽略错误
    }
    
    // 保存窗口状态
    try {
      final win = appWindow;
      final config = context.read<ClientConfigService>();
      
      // 保存最大化状态
      await config.setWindowMaximized(win.isMaximized);
      
      // 只有在启用记忆大小且窗口未最大化时才保存当前窗口大小
      if (config.getWindowRememberSize() && !win.isMaximized) {
        final currentWidth = win.size.width;
        final currentHeight = win.size.height;
        
        // 验证窗口大小是否合理（防止保存异常值）
        // 窗口最小化时，size 可能会变成很小的值（如 160x28），需要过滤掉
        if (currentWidth >= 600 && currentHeight >= 400 && 
            currentWidth <= 4096 && currentHeight <= 2160) {
          debugPrint('Saving window size: $currentWidth x $currentHeight');
          await config.setWindowWidth(currentWidth);
          await config.setWindowHeight(currentHeight);
        } else {
          debugPrint('Invalid window size, not saving: $currentWidth x $currentHeight');
        }
      }
    } catch (e) {
      debugPrint('Failed to save window size: $e');
    }

    _downloadListener?.stopListening();

    // 停止管道监听
    _pipeListener?.stop();

    // 停止弹窗进度推送服务
    _popupProgressService?.stop();

    // 停止新内核
    try {
      final kernelManager = context.read<KernelManager>();
      await kernelManager.stop();
    } catch (e) {
      // 忽略错误
    }
    
    // 停止旧kernel服务
    try {
      final kernelService = context.read<KernelService>();
      await kernelService.stopKernel();
    } catch (e) {
      // 忽略错误，确保清理继续
    }
    
    systemTrayService.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 同步清理，不等待异步操作
    _downloadListener?.stopListening();
    systemTrayService.dispose();
    
    // 异步清理新内核（不等待）
    try {
      final kernelManager = context.read<KernelManager>();
      kernelManager.stop();
    } catch (e) {
      // 忽略错误
    }
    
    // 异步清理旧 kernel（不等待）
    try {
      final kernelService = context.read<KernelService>();
      kernelService.stopKernel();
    } catch (e) {
      // 忽略错误
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FontService, ClientConfigService>(
      builder: (context, fontService, clientConfig, child) {
        final baseTheme = AppTheme.fluentDarkTheme;
        final typography = baseTheme.typography;
        final scaleFactor = clientConfig.getWindowScaleFactor();
        
        return fluent.FluentApp(
          navigatorKey: navigatorKey,
          title: 'Hanabi Download ManagerX',
          debugShowCheckedModeBanner: false,
          theme: baseTheme.copyWith(
            typography: fluent.Typography.raw(
              body: typography.body?.copyWith(fontFamily: fontService.fontFamily),
              bodyLarge: typography.bodyLarge?.copyWith(fontFamily: fontService.fontFamily),
              bodyStrong: typography.bodyStrong?.copyWith(fontFamily: fontService.fontFamily),
              caption: typography.caption?.copyWith(fontFamily: fontService.fontFamily),
              subtitle: typography.subtitle?.copyWith(fontFamily: fontService.fontFamily),
              title: typography.title?.copyWith(fontFamily: fontService.fontFamily),
              titleLarge: typography.titleLarge?.copyWith(fontFamily: fontService.fontFamily),
              display: typography.display?.copyWith(fontFamily: fontService.fontFamily),
            ),
          ),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scaleFactor),
              ),
              child: NotificationManager(
                child: child!,
              ),
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
