import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'services/integrated_download_service.dart';
import 'services/kernel_service.dart';
import 'services/download_listener_service.dart';
import 'services/system_tray_service.dart';
import 'services/app_logger_service.dart';
import 'services/network_status_service.dart';
import 'services/developer_mode_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

final systemTrayService = SystemTrayService();
final navigatorKey = GlobalKey<NavigatorState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 检查是否是开机自启动（通过命令行参数 --autostart）
  final bool isAutoStart = args.contains('--autostart');
  
  final kernelService = KernelService();
  
  // 初始化服务
  final appLogger = AppLoggerService();
  final networkStatus = NetworkStatusService();
  final developerMode = DeveloperModeService();
  
  appLogger.info('App', 'Application starting...');
  networkStatus.startMonitoring();
  await developerMode.loadSettings();
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
        Provider<bool>.value(value: isAutoStart), // 传递启动模式
      ],
      child: const MyApp(),
    ),
  );

  doWhenWindowReady(() {
    final win = appWindow;
    const initialSize = Size(1200, 800);
    win.minSize = const Size(800, 600);
    win.size = initialSize;
    win.alignment = Alignment.center;
    win.title = "Hanabi Download ManagerX";
    
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
    await systemTrayService.initialize(kernelService: kernelService);
    final isAutoStart = context.read<bool>();
    if (!isAutoStart) {
      systemTrayService.showMainWindow();
    }
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
    return fluent.FluentApp(
      navigatorKey: navigatorKey,
      title: 'Hanabi Download ManagerX',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fluentDarkTheme,
      home: const HomeScreen(),
    );
  }
}
