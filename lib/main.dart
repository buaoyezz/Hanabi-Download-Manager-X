import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'services/integrated_download_service.dart';
import 'services/kernel_service.dart';
import 'services/download_listener_service.dart';
import 'services/system_tray_service.dart';
import 'services/app_logger_service.dart';
import 'services/network_status_service.dart';
import 'services/developer_mode_service.dart';
import 'services/client_config_service.dart';
import 'services/font_service.dart';
import 'services/update_service.dart';
import 'services/window_effect_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

final systemTrayService = SystemTrayService();
final navigatorKey = GlobalKey<NavigatorState>();

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
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Acrylic/Mica 效果
  await Window.initialize();
  await Window.setEffect(
    effect: WindowEffect.mica,
    dark: true,
  );
  
  // 检查是否是开机自启动（通过命令行参数 --autostart）
  final bool isAutoStart = args.contains('--autostart');
  
  final kernelService = KernelService();
  
  // 初始化服务
  final appLogger = AppLoggerService();
  final networkStatus = NetworkStatusService();
  final developerMode = DeveloperModeService();
  final clientConfig = ClientConfigService();
  final fontService = FontService();
  final updateService = UpdateService(logger: appLogger);
  final windowEffectService = WindowEffectService();
  
  appLogger.info('App', 'Application starting...');
  await clientConfig.initialize();
  networkStatus.startMonitoring();
  await developerMode.loadSettings();
  await fontService.loadFont();
  await windowEffectService.initialize();
  await updateService.initialize();
  
  // 加载自定义字体（异步，不阻塞启动）
  _loadCustomFonts(fontService).catchError((e) {
    debugPrint('Failed to load custom fonts: $e');
  });
  
  appLogger.info('App', 'Services initialized');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: kernelService),
        ChangeNotifierProxyProvider<KernelService, IntegratedDownloadService>(
          create: (context) => IntegratedDownloadService(kernelService),
          update: (context, kernel, previous) => previous ?? IntegratedDownloadService(kernel),
        ),
        ChangeNotifierProvider.value(value: appLogger),
        ChangeNotifierProvider.value(value: networkStatus),
        ChangeNotifierProvider.value(value: developerMode),
        ChangeNotifierProvider.value(value: clientConfig),
        ChangeNotifierProvider.value(value: fontService),
        ChangeNotifierProvider.value(value: updateService),
        ChangeNotifierProvider.value(value: windowEffectService),
        Provider<bool>.value(value: isAutoStart), // 传递启动模式
      ],
      child: const MyApp(),
    ),
  );

  doWhenWindowReady(() async {
    final win = appWindow;
    final config = ClientConfigService();
    
    // 获取屏幕大小（使用 screen_retriever）
    double screenWidth = 1920.0;
    double screenHeight = 1080.0;
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      screenWidth = primaryDisplay.size.width;
      screenHeight = primaryDisplay.size.height;
    } catch (e) {
      debugPrint('Failed to get screen size: $e');
    }
    
    // 根据是否记忆大小来决定使用哪个尺寸
    Size initialSize;
    if (config.getWindowRememberSize()) {
      // 使用上次保存的大小，但不超过屏幕大小
      final savedWidth = config.getWindowWidth().clamp(600.0, screenWidth);
      final savedHeight = config.getWindowHeight().clamp(400.0, screenHeight);
      initialSize = Size(savedWidth, savedHeight);
    } else {
      // 使用默认大小，但不超过屏幕大小
      final defaultWidth = config.getWindowDefaultWidth().clamp(600.0, screenWidth);
      final defaultHeight = config.getWindowDefaultHeight().clamp(400.0, screenHeight);
      initialSize = Size(defaultWidth, defaultHeight);
    }
    
    win.minSize = const Size(600, 400);
    win.size = initialSize;
    win.alignment = Alignment.center;
    win.title = "Hanabi Download ManagerX";

    if (config.getWindowMaximized()) {
      win.maximize();
    }
    
    // 如果是开机自启动，隐藏窗口；否则显示窗口
    if (isAutoStart) {
      win.hide();
    } else {
      win.show();
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  DownloadListenerService? _downloadListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSystemTray();
      _initKernel();
      _initDownloadListener();
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
    final kernelService = context.read<KernelService>();
    final success = await kernelService.startKernel();
    
    if (!success && mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to start download kernel'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initDownloadListener() {
    _downloadListener = DownloadListenerService(context);
    _downloadListener!.startListening();
  }

  Future<void> _cleanup() async {
    // 保存窗口大小（仅在记忆模式下）
    try {
      final win = appWindow;
      final config = context.read<ClientConfigService>();
      
      await config.setWindowMaximized(win.isMaximized);
      
      // 只有在启用记忆大小时才保存当前窗口大小
      if (config.getWindowRememberSize() && !win.isMaximized) {
        await config.setWindowWidth(win.size.width);
        await config.setWindowHeight(win.size.height);
      }
    } catch (e) {
      debugPrint('Failed to save window size: $e');
    }

    _downloadListener?.stopListening();
    
    // 停止kernel服务
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
    
    // 异步清理 kernel（不等待）
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
    return Consumer<FontService>(
      builder: (context, fontService, child) {
        final baseTheme = AppTheme.fluentDarkTheme;
        final typography = baseTheme.typography;
        
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
          home: const HomeScreen(),
        );
      },
    );
  }
}
