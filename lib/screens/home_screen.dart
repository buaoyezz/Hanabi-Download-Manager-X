import 'dart:ui';
import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../main.dart'
    show isWindowMaximized, maximizeWindowProperly, restoreWindowProperly;
import '../utils/fluent_icons.dart' as CustomIcons;
import '../services/integrated_download_service.dart';
import '../services/developer_mode_service.dart';
import '../services/app_logger_service.dart';
import '../services/kernel_service.dart';
import '../services/kernel/kernel_manager.dart';
import '../services/window_effect_service.dart';
import '../services/client_config_service.dart';
import '../services/update_service.dart';
import '../services/performance_monitor_service.dart';
import '../models/download_task.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../widgets/animated_notifications.dart';
import '../l10n/app_localizations.dart';
import 'widgets/download_list.dart';
import 'widgets/add_download_dialog.dart';
import 'widgets/completed_list.dart';
import 'widgets/settings_page.dart';
import 'widgets/about_page.dart';
import 'widgets/debug/log_page.dart';
import 'widgets/debug/status_page.dart';
import 'widgets/debug/web_check_page.dart';
import 'widgets/debug/connection_debug_page.dart';
import 'widgets/performance_monitor_page.dart';
import 'widgets/update_dialog.dart';

class NavigationItem {
  final String id;
  final IconData icon;
  final String title;
  final Widget body;

  NavigationItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _pageDownloading = 'downloading';
  static const String _pageCompleted = 'completed';
  static const String _pageLog = 'log';
  static const String _pageStatus = 'status';
  static const String _pageWebCheck = 'web_check';
  static const String _pagePerformance = 'performance';
  static const String _pageConnectionDebug = 'connection_debug';
  static const String _pageSettings = 'settings';
  static const String _pageAbout = 'about';

  static const Set<String> _debugPageIds = {
    _pageLog,
    _pageStatus,
    _pageWebCheck,
    _pagePerformance,
    _pageConnectionDebug,
    _pageSettings,
    _pageAbout,
  };

  static const Set<String> _bottomPageIds = {
    _pageLog,
    _pageStatus,
    _pageWebCheck,
    _pagePerformance,
    _pageConnectionDebug,
    _pageSettings,
    _pageAbout,
  };

  int _currentIndex = 0;
  bool _isSidebarExpanded = true;
  bool _isMaximized = false;
  late AnimationController _sidebarController;
  late Animation<double> _widthAnimation;

  // 当前选中的页面标识符
  String _currentPageId = _pageDownloading;

  // 窗口大小监听
  Timer? _windowSizeCheckTimer;
  double _lastSavedWidth = 0;
  double _lastSavedHeight = 0;
  bool _forcedUpdateDialogShown = false;

  List<NavigationItem> _getNavItems(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    // 使用 select 只监听影响导航列表的字段
    final showLogPage =
        context.select<DeveloperModeService, bool>((s) => s.showLogPage);
    final showStatusPage =
        context.select<DeveloperModeService, bool>((s) => s.showStatusPage);
    final showWebCheckPage =
        context.select<DeveloperModeService, bool>((s) => s.showWebCheckPage);
    final showPerformanceMonitorPage =
        context.select<DeveloperModeService, bool>(
            (s) => s.showPerformanceMonitorPage);
    final showConnectionDebugPage = context
        .select<DeveloperModeService, bool>((s) => s.showConnectionDebugPage);

    final items = <NavigationItem>[
      NavigationItem(
        id: _pageDownloading,
        icon: CustomIcons.FluentIcons.download,
        title: t.homeNavDownloading,
        body: const DownloadList(),
      ),
      NavigationItem(
        id: _pageCompleted,
        icon: CustomIcons.FluentIcons.completed_solid,
        title: t.homeNavCompleted,
        body: const CompletedList(),
      ),
    ];

    final bottomItems = <NavigationItem>[];

    if (showLogPage) {
      bottomItems.add(NavigationItem(
        id: _pageLog,
        icon: CustomIcons.FluentIcons.document,
        title: t.homeNavLog,
        body: const LogPage(key: ValueKey('log_page')),
      ));
    }

    if (showStatusPage) {
      bottomItems.add(NavigationItem(
        id: _pageStatus,
        icon: CustomIcons.FluentIcons.health,
        title: t.homeNavStatus,
        body: const StatusPage(key: ValueKey('status_page')),
      ));
    }

    if (showWebCheckPage) {
      bottomItems.add(NavigationItem(
        id: _pageWebCheck,
        icon: CustomIcons.FluentIcons.globe,
        title: t.homeNavWebCheck,
        body: const WebCheckPage(key: ValueKey('web_check_page')),
      ));
    }

    // 性能监控页面
    if (showPerformanceMonitorPage) {
      bottomItems.add(NavigationItem(
        id: _pagePerformance,
        icon: CustomIcons.FluentIcons.speed_high,
        title: t.homeNavPerformance,
        body: const PerformanceMonitorPage(
            key: ValueKey('performance_monitor_page')),
      ));
    }

    // 连接调试页面
    if (showConnectionDebugPage) {
      bottomItems.add(NavigationItem(
        id: _pageConnectionDebug,
        icon: CustomIcons.FluentIcons.plug_disconnected,
        title: t.homeNavConnectionDebug,
        body: const ConnectionDebugPage(key: ValueKey('connection_debug_page')),
      ));
    }

    bottomItems.addAll([
      NavigationItem(
        id: _pageSettings,
        icon: CustomIcons.FluentIcons.settings,
        title: t.homeNavSettings,
        body: const SettingsPage(key: ValueKey('settings_page')),
      ),
      NavigationItem(
        id: _pageAbout,
        icon: CustomIcons.FluentIcons.info,
        title: t.homeNavAbout,
        body: const AboutPage(key: ValueKey('about_page')),
      ),
    ]);

    return [...items, ...bottomItems];
  }

  @override
  void initState() {
    super.initState();
    AppLoggerService().info('App', 'HomeScreen initialized');

    // 初始化窗口最大化状态（一次性 FFI 调用）
    _isMaximized = isWindowMaximized();

    // 监听窗口尺寸变化（OS 级最大化/还原）
    WidgetsBinding.instance.addObserver(this);

    // 侧边栏动画控制器 - 快速响应的展开/收缩
    _sidebarController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // 宽度动画 - 使用 easeInOutCubic 曲线实现丝滑的双向过渡
    _widthAnimation = Tween<double>(begin: 200, end: 52).animate(
      CurvedAnimation(
        parent: _sidebarController,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      ),
    );

    // 从配置中读取默认侧边栏状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSidebarState();
      _startWindowSizeMonitoring();
      _checkForUpdates();
    });
  }

  /// 检查更新并显示通知
  Future<void> _checkForUpdates() async {
    try {
      final updateService = Provider.of<UpdateService>(context, listen: false);

      // 检查是否应该自动检查更新
      final shouldCheck = await updateService.shouldAutoCheck();
      if (!shouldCheck) {
        AppLoggerService().info('Update', '跳过自动更新检查');
        return;
      }

      // 执行更新检查
      final hasUpdate = await updateService.checkForUpdates();

      // 如果有更新，显示通知
      if (hasUpdate && mounted) {
        final availableUpdate = updateService.availableUpdate;
        if (availableUpdate != null) {
          final t = AppLocalizations.of(context)!;
          final currentVersion = updateService.currentVersion;
          final newVersion = availableUpdate.version;
          final isZh = Localizations.localeOf(context).languageCode == 'zh';

          if (updateService.isForcedUpdate) {
            NotificationManager.of(context)?.showError(
              t.homeUpdateFoundTitle,
              message:
                  '${t.homeUpdateFoundMessage(currentVersion, newVersion)}${isZh ? '（强制更新）' : ' (Forced update)'}',
            );

            if (!_forcedUpdateDialogShown) {
              _forcedUpdateDialogShown = true;
              await showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => PopScope(
                  canPop: false,
                  child: UpdateDialog(
                    updateInfo: availableUpdate,
                    currentVersion: currentVersion,
                  ),
                ),
              );
            }
          } else if (updateService.isRecommendedUpdate) {
            NotificationManager.of(context)?.showInfo(
              t.homeUpdateFoundTitle,
              message:
                  '${t.homeUpdateFoundMessage(currentVersion, newVersion)}${isZh ? '（推荐更新）' : ' (Recommended)'}',
            );
          } else {
            NotificationManager.of(context)?.showInfo(
              t.homeUpdateFoundTitle,
              message: t.homeUpdateFoundMessage(currentVersion, newVersion),
            );
          }

          AppLoggerService().info(
            'Update',
            '发现新版本: $newVersion，紧急程度=${availableUpdate.urgency.name}',
          );
        }
      }
    } catch (e) {
      AppLoggerService().error('Update', '检查更新失败: $e');
    }
  }

  void _loadSidebarState() {
    try {
      final config = Provider.of<ClientConfigService>(context, listen: false);
      final defaultExpanded = config.getSidebarDefaultExpanded();

      setState(() {
        _isSidebarExpanded = defaultExpanded;
      });

      // 设置动画状态
      if (defaultExpanded) {
        _sidebarController.value = 0; // 展开状态
      } else {
        _sidebarController.value = 1; // 收缩状态
      }

      AppLoggerService().info('App',
          'Sidebar default state loaded: ${defaultExpanded ? "expanded" : "collapsed"}');
    } catch (e) {
      AppLoggerService().error('App', 'Failed to load sidebar state: $e');
      // 如果加载失败，使用默认展开状态
      _isSidebarExpanded = true;
      _sidebarController.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sidebarController.dispose();
    _windowSizeCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // 窗口尺寸变化时同步最大化状态（捕获 OS 级操作：双击标题栏、拖到屏幕边缘等）
    final nowMaximized = isWindowMaximized();
    if (nowMaximized != _isMaximized) {
      setState(() => _isMaximized = nowMaximized);
    }
  }

  /// 启动窗口大小监听
  void _startWindowSizeMonitoring() {
    // 初始化上次保存的大小
    _lastSavedWidth = appWindow.size.width;
    _lastSavedHeight = appWindow.size.height;

    // 优化：从 3 秒提升到 10 秒，窗口大小变化极少发生，不需要频繁检查
    _windowSizeCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;

      final currentWidth = appWindow.size.width;
      final currentHeight = appWindow.size.height;

      // 快速判断：大小没变就跳过，避免不必要的 Provider 查询
      if ((currentWidth - _lastSavedWidth).abs() <= 1 &&
          (currentHeight - _lastSavedHeight).abs() <= 1) {
        return;
      }

      _checkAndSaveWindowSize();
    });
  }

  /// 检查并保存窗口大小
  Future<void> _checkAndSaveWindowSize() async {
    if (!mounted) return;

    try {
      final config = Provider.of<ClientConfigService>(context, listen: false);
      final rememberSize = config.getWindowRememberSize();

      // 只有在启用记忆大小时才保存
      if (!rememberSize) return;

      final currentWidth = appWindow.size.width;
      final currentHeight = appWindow.size.height;

      if (_isMaximized) return; // 最大化时不保存窗口大小

      // 验证窗口大小是否合理（防止保存异常值）
      // 最小尺寸 600x400，最大尺寸 4096x2160
      // 窗口最小化时，size 可能会变成很小的值（如 160x28），需要过滤掉
      if (currentWidth < 600 ||
          currentHeight < 400 ||
          currentWidth > 4096 ||
          currentHeight > 2160) {
        AppLoggerService().warning('App',
            'Invalid window size detected: ${currentWidth.toInt()}x${currentHeight.toInt()}, skipping save');
        return;
      }

      // 检查大小是否有变化（允许1像素的误差）
      if ((currentWidth - _lastSavedWidth).abs() > 1 ||
          (currentHeight - _lastSavedHeight).abs() > 1) {
        // 保存新的窗口大小
        await config.setWindowWidth(currentWidth);
        await config.setWindowHeight(currentHeight);

        _lastSavedWidth = currentWidth;
        _lastSavedHeight = currentHeight;

        AppLoggerService().debug('App',
            'Window size saved: ${currentWidth.toInt()}x${currentHeight.toInt()}');
      }
    } catch (e) {
      AppLoggerService().error('App', 'Failed to save window size: $e');
    }
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
      if (_isSidebarExpanded) {
        _sidebarController.reverse();
      } else {
        _sidebarController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 追踪重建
    PerformanceMonitorService().trackRebuild('HomeScreen');

    // 窗口最小化时 Windows 会给极小尺寸（约 160x28），跳过布局避免溢出
    final windowSize = MediaQuery.of(context).size;
    if (windowSize.height < 100) {
      return const SizedBox.shrink();
    }

    final navItems = _getNavItems(context);
    // 优化：合并多个 select 为一个 tuple，减少独立订阅数量
    // 每个 select 都是一个独立的监听器，多个 select 可能导致同一帧内多次重建
    final kernelIsRunning =
        context.select<KernelService, bool>((s) => s.isRunning);
    final kernelManagerIsRunning =
        context.select<KernelManager, bool>((s) => s.isRunning);

    // 合并 WindowEffectService 的多个 select 为单次读取
    final windowEffect = context.watch<WindowEffectService>();
    final isTransparent = windowEffect.isTransparentBackground ||
        windowEffect.effectMode.startsWith('mica');

    // 根据窗口效果调整背景透明度
    final sidebarOpacity = isTransparent ? 0.2 : 0.65;

    // 计算统一的 shell 背景色（标题栏+侧边栏共用）
    final isMica = windowEffect.isMicaEffect;
    final effectEnabled = windowEffect.effectEnabled;
    final shellBgAlpha = isMica ? 0.4 : (effectEnabled ? sidebarOpacity : 1.0);

    // 核心修复逻辑：确保 _currentIndex 与 _currentPageId 同步
    // 这解决了列表项动态增减（如在线统计出现/消失）导致的索引错位
    final correctIndex =
        navItems.indexWhere((item) => item.id == _currentPageId);

    if (correctIndex != -1) {
      // 找到了当前标题对应的页面，更新索引
      _currentIndex = correctIndex;
    } else {
      // 当前页面不在列表里了（可能是相关功能开关关闭了）
      // 检查索引越界情况
      if (_currentIndex >= navItems.length) {
        _currentIndex = navItems.length > 0 ? navItems.length - 1 : 0;
      }
      // 更新当前页面标识
      if (navItems.isNotEmpty) {
        _currentPageId = navItems[_currentIndex].id;
      }
    }

    Widget shellContent = Container(
      // 统一的 shell 背景色（标题栏 + 侧边栏一体）
      color: AppTheme.bgSolid.withValues(alpha: shellBgAlpha),
      child: Column(
        children: [
          // 顶部标题栏（横跨整个窗口）
          _buildUnifiedTitleBar(context, sidebarOpacity),
          // 下方：侧边栏 + 内容区
          Expanded(
            child: Row(
              children: [
                // 左侧：侧边栏（无独立背景，继承 shell 背景）
                _buildEdgeSidebar(context, navItems, sidebarOpacity),
                // 右侧：内容区（左上角圆角，覆盖在 shell 背景上）
                Expanded(
                  child: _buildContentArea(context, isTransparent,
                      kernelIsRunning, kernelManagerIsRunning, navItems),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // 统一的模糊效果，覆盖标题栏+侧边栏区域，消除割裂感
    // 优化：降低 BackdropFilter 的 sigma 值，从 4 降到 2
    // BackdropFilter 是 GPU 最昂贵的操作之一，sigma 越大开销越大
    // sigma=2 在视觉上仍有模糊效果，但 GPU 开销降低约 75%
    if (effectEnabled && isTransparent) {
      shellContent = RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: shellContent,
        ),
      );
    }

    return WindowBorder(
      color: Colors.transparent,
      width: 0,
      child: shellContent,
    );
  }

  /// 内容区域 - 根据窗口效果设置决定是否使用模糊
  Widget _buildContentArea(
      BuildContext context,
      bool isTransparent,
      bool kernelIsRunning,
      bool kernelManagerIsRunning,
      List<NavigationItem> navItems) {
    // 优化：使用 read 而非 select，因为 build() 中已经 select 了这些值
    // 这里只需要读取当前值，不需要再次订阅监听
    final effectService = context.read<WindowEffectService>();
    final effectEnabled = effectService.effectEnabled;
    final isMica = effectService.isMicaEffect;
    final useBlur = effectEnabled && isTransparent;

    // Mica 效果需要更透明的背景
    final bgAlpha = isMica ? 0.5 : (useBlur ? 0.75 : 0.95);

    final contentContainer = Container(
      decoration: BoxDecoration(
        color: AppTheme.bgBase.withValues(alpha: bgAlpha),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child:
          _buildPageContent(kernelIsRunning, kernelManagerIsRunning, navItems),
    );

    // 优化：移除内容区独立的 BackdropFilter，由外层 shell 统一处理模糊
    // 双层 BackdropFilter 是 GPU 卡顿的主要原因
    return contentContainer;
  }

  /// 统一的顶部标题栏 - 横跨整个窗口
  Widget _buildUnifiedTitleBar(BuildContext context, double opacity) {
    final windowWidth = MediaQuery.of(context).size.width;
    final isMicroWidth = windowWidth < 200;
    final menuWidth = isMicroWidth ? 40.0 : 52.0;
    final menuButtonSize = isMicroWidth ? 24.0 : 28.0;
    final menuIconSize = isMicroWidth ? 12.0 : 14.0;
    final logoSize = isMicroWidth ? 16.0 : 18.0;
    final logoSpacing = isMicroWidth ? 6.0 : 8.0;

    final titleBarContent = Container(
      height: 48,
      // 不设独立背景色，由外层 shell 背景提供
      child: Row(
        children: [
          // 左侧：汉堡菜单
          SizedBox(
            width: menuWidth,
            child: Center(
              child: SizedBox(
                width: menuButtonSize,
                height: menuButtonSize,
                child: Button(
                  onPressed: _toggleSidebar,
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.isHovered) {
                        return AppTheme.bgLayer2.withValues(alpha: 0.5);
                      }
                      return Colors.transparent;
                    }),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide.none,
                      ),
                    ),
                  ),
                  child: Icon(
                    CustomIcons.FluentIcons.global_nav_button,
                    size: menuIconSize,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          // 中间：Logo + 标题 + 可拖动区域
          Expanded(
            child: MoveWindow(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showLogo = constraints.maxWidth >= 140;
                  return Row(
                    children: [
                      if (showLogo) ...[
                        SizedBox(width: logoSpacing),
                        Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentPrimary
                                    .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/logo/logo.png',
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(width: logoSpacing),
                      ],
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.appTitle,
                          style: FluentTheme.of(context)
                              .typography
                              .caption
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          // 右侧：操作按钮（不抢占拖动区域空间）
          _buildTitleBarActions(context, compactButtons: isMicroWidth),
        ],
      ),
    );

    // 优化：降低模糊强度从10到6，减少GPU负担
    // 不再单独模糊标题栏，由外层 shell 统一处理
    return titleBarContent;
  }

  /// 标题栏右侧操作按钮
  Widget _buildTitleBarActions(BuildContext context,
      {bool compactButtons = false}) {
    // 基于窗口宽度做响应式，不依赖父级约束
    final windowWidth = MediaQuery.of(context).size.width;
    final isNarrow = windowWidth < 800;
    final isVeryNarrow = windowWidth < 650;
    final isUltraNarrow = windowWidth < 500;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 统计信息 - 窄屏时隐藏
        if (!isNarrow) ...[
          _buildStatsChip(),
          const SizedBox(width: 12),
        ],
        // 新建按钮 - 极窄时隐藏
        if (!isUltraNarrow) ...[
          if (isVeryNarrow)
            _buildCompactNewTaskButton(context)
          else
            _buildNewTaskButton(context),
          const SizedBox(width: 8),
        ],
        // 托盘按钮 - 极窄时隐藏
        if (!isUltraNarrow) ...[
          _buildAnimatedTrayButton(context),
          const SizedBox(width: 8),
        ],
        // 窗口控制按钮（始终显示）
        _buildWindowButtons(context, compact: compactButtons),
      ],
    );
  }

  Widget _buildPageContent(bool kernelIsRunning, bool kernelManagerIsRunning,
      List<NavigationItem> navItems) {
    // 检查新内核或旧内核是否在运行
    final isKernelRunning = kernelManagerIsRunning || kernelIsRunning;

    // 如果内核正在运行，或者当前页面是调试页面（日志、状态、Web检测、在线统计、性能监控），直接显示页面
    final currentPageId = navItems[_currentIndex].id;
    final isDebugPage = _debugPageIds.contains(currentPageId);

    if (isKernelRunning || isDebugPage) {
      // 使用 AnimatedSwitcher 实现页面切换的淡入淡出效果
      return RepaintBoundary(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          transitionBuilder: (child, animation) {
            // 仅淡入淡出，移除 SlideTransition 减少合成层开销
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: KeyedSubtree(
            // 核心修复点：使用标题作为 Key，而不是索引
            // 这样即使列表发生变化导致索引改变，只要标题没变，就不会触发页面重绘或跳转
            key: ValueKey(navItems[_currentIndex].id),
            child: navItems[_currentIndex].body,
          ),
        ),
      );
    }

    // 否则显示加载动画
    return _buildLoadingIndicator();
  }

  Widget _buildLoadingIndicator() {
    return Consumer2<KernelService, KernelManager>(
      builder: (context, kernelService, kernelManager, child) {
        // 优先使用新内核的状态
        final useNewKernel = context
            .read<ClientConfigService>()
            .getBool('kernel.use_new_kernel', defaultValue: true);

        double progress;
        String status;

        if (useNewKernel) {
          progress = kernelManager.startupProgress;
          status = kernelManager.startupStatus;
        } else {
          progress = kernelService.startupProgress;
          status = kernelService.startupStatus;
        }

        final percentage = (progress * 100).toInt();

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.borderSubtle.withValues(alpha: 0.5),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ProgressRing(),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context)!.homeKernelStartingTitle,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (status.isNotEmpty)
                    Text(
                      status,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    )
                  else
                    Text(
                      AppLocalizations.of(context)!.homeKernelStartingHint,
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 20),
                  // 进度条
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppTheme.bgLayer2,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentPrimary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 45,
                            child: Text(
                              '$percentage%',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Button(
                        onPressed: () async {
                          // 打开日志页面
                          final devMode = Provider.of<DeveloperModeService>(
                              context,
                              listen: false);
                          if (!devMode.showLogPage) {
                            await devMode.setShowLogPage(true);
                          }
                          // 等待一帧，让 UI 更新
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                          // 切换到日志页面（日志页面通常在索引 2）
                          if (mounted) {
                            setState(() {
                              _currentIndex = 2; // 下载中(0), 已完成(1), 日志(2)
                              _currentPageId = _pageLog;
                            });
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CustomIcons.FluentIcons.text_document,
                                size: 14),
                            SizedBox(width: 6),
                            Text(AppLocalizations.of(context)!.homeViewLog),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () async {
                          // 重试启动
                          final config = Provider.of<ClientConfigService>(
                              context,
                              listen: false);
                          final useNewKernel = config.getBool(
                              'kernel.use_new_kernel',
                              defaultValue: true);

                          if (useNewKernel) {
                            final kernelManager = Provider.of<KernelManager>(
                                context,
                                listen: false);
                            await kernelManager.start(type: KernelType.next);
                          } else {
                            final kernelService = Provider.of<KernelService>(
                                context,
                                listen: false);
                            await kernelService.startKernel();
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CustomIcons.FluentIcons.refresh, size: 14),
                            SizedBox(width: 6),
                            Text(AppLocalizations.of(context)!.homeRetry),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Edge 风格侧边栏 - 只包含导航项（优化版，减少重建）
  Widget _buildEdgeSidebar(
      BuildContext context, List<NavigationItem> navItems, double opacity) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _widthAnimation,
        builder: (context, child) {
          final width = _widthAnimation.value;
          final isCompact = width < 100;

          final sidebarContent = Container(
            // 不设独立背景色，与标题栏一体
            child: Column(
              children: [
                const SizedBox(height: 8),

                // 主导航项
                ...navItems
                    .asMap()
                    .entries
                    .where((entry) => !_bottomPageIds.contains(entry.value.id))
                    .map((entry) => _buildNavItemWidget(
                        context, entry.key, entry.value, isCompact)),

                const Spacer(),

                // 分隔线
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 16, vertical: 8),
                  child: Container(
                    height: 1,
                    color: AppTheme.borderSubtle.withValues(alpha: 0.3),
                  ),
                ),

                // 底部导航项
                ..._buildBottomNavItems(context, navItems, isCompact),

                const SizedBox(height: 8),
              ],
            ),
          );

          return Stack(
            children: [
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0,
                  child: SizedBox(
                    width: width,
                    // 不再单独模糊侧边栏，由外层 shell 统一处理
                    child: sidebarContent,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 紧凑版新建任务按钮（仅图标）
  Widget _buildCompactNewTaskButton(BuildContext context) {
    return SizedBox(
      height: 28,
      width: 28,
      child: Button(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
        ),
        onPressed: () => _showAddDownloadDialog(context),
        child: Icon(CustomIcons.FluentIcons.add, size: 12),
      ),
    );
  }

  /// 构建底部导航项
  List<Widget> _buildBottomNavItems(
      BuildContext context, List<NavigationItem> navItems, bool isCompact) {
    final bottomItems = navItems
        .asMap()
        .entries
        .where((entry) => _bottomPageIds.contains(entry.value.id))
        .toList();

    return bottomItems.map((entry) {
      final item = entry.value;
      final index = entry.key;
      return _buildNavItemWidget(context, index, item, isCompact);
    }).toList();
  }

  /// 新建任务按钮（标题栏）
  Widget _buildNewTaskButton(BuildContext context) {
    return SizedBox(
      height: 28,
      child: FilledButton(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        onPressed: () => _showAddDownloadDialog(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CustomIcons.FluentIcons.add, size: 12),
            SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)!.homeNewTask,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  /// 托盘按钮（带动画效果）
  Widget _buildAnimatedTrayButton(BuildContext context) {
    // 优化：使用 select 只监听 closeButtonBehavior，避免整个配置变化时重建
    final closeButtonBehavior = context
        .select<ClientConfigService, String>((c) => c.getCloseButtonBehavior());
    final shouldShowTrayButton = closeButtonBehavior != 'minimize_to_tray';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      // 优化：移除 ScaleTransition + elasticOut，改用简单的 FadeTransition
      // elasticOut 曲线会产生大量过冲帧，每帧都触发合成层重建
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: shouldShowTrayButton
          ? Container(
              key: const ValueKey('tray_button'),
              child: SizedBox(
                height: 28,
                width: 28,
                child: Button(
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () => systemTrayService.hideMainWindow(),
                  child:
                      Icon(CustomIcons.FluentIcons.chrome_minimize, size: 12),
                ),
              ),
            )
          : Container(
              key: const ValueKey('empty_tray'),
              width: 0,
              height: 28,
            ),
    );
  }

  Widget _buildStatsChip() {
    // 使用 Selector 只在任务数量变化时重建，而不是每次任务更新都重建
    return Selector<IntegratedDownloadService, (int, int)>(
      selector: (_, service) {
        final downloading = service.tasks
            .where((t) => t.status == DownloadStatus.downloading)
            .length;
        final completed = service.tasks
            .where((t) => t.status == DownloadStatus.completed)
            .length;
        return (downloading, completed);
      },
      builder: (context, counts, _) {
        final (downloading, completed) = counts;

        return Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgLayer2.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            border:
                Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem(CustomIcons.FluentIcons.download, downloading,
                  AppTheme.accentPrimary),
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppTheme.borderSubtle.withValues(alpha: 0.5),
              ),
              _buildStatItem(CustomIcons.FluentIcons.completed, completed,
                  AppTheme.statusSuccess),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildNavItemWidget(
      BuildContext context, int index, NavigationItem item, bool isCompact) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 12,
        vertical: 2,
      ),
      child: _NavItem(
        icon: item.icon,
        title: item.title,
        isSelected: isSelected,
        isCompact: isCompact,
        onTap: () {
          AppLoggerService().info('App', 'Navigated to: ${item.title}');
          setState(() {
            _currentIndex = index;
            _currentPageId = item.id;
          });
        },
      ),
    );
  }

  Widget _buildWindowButtons(BuildContext context, {bool compact = false}) {
    final buttonColors = WindowButtonColors(
      iconNormal: AppTheme.textSecondary,
      iconMouseDown: AppTheme.textPrimary,
      iconMouseOver: AppTheme.textPrimary,
      normal: Colors.transparent,
      mouseOver: AppTheme.bgLayer2.withValues(alpha: 0.8),
      mouseDown: AppTheme.bgLayer3,
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: AppTheme.textSecondary,
      iconMouseDown: Colors.white,
      iconMouseOver: Colors.white,
      normal: Colors.transparent,
      mouseOver: const Color(0xFFc42b1c),
      mouseDown: const Color(0xFFb52a1c),
    );

    final buttonWidth = compact ? 32.0 : 36.0;
    final buttonHeight = compact ? 26.0 : 28.0;
    final iconSize = compact ? 14.0 : 16.0;

    return Padding(
      padding: EdgeInsets.only(right: compact ? 4 : 8),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            _buildCustomMinimizeButton(
                buttonColors, buttonWidth, buttonHeight, iconSize),
            _buildCustomMaximizeButton(
                buttonColors, buttonWidth, buttonHeight, iconSize),
            _buildCustomCloseButton(
                closeButtonColors, buttonWidth, buttonHeight, iconSize),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMinimizeButton(
    WindowButtonColors colors,
    double width,
    double height,
    double iconSize,
  ) {
    return _buildWindowButton(
      colors: colors,
      icon: CustomIcons.FluentIcons.subtract_20,
      width: width,
      height: height,
      iconSize: iconSize,
      onPressed: () => appWindow.minimize(),
    );
  }

  Widget _buildCustomMaximizeButton(
    WindowButtonColors colors,
    double width,
    double height,
    double iconSize,
  ) {
    return _buildWindowButton(
      colors: colors,
      icon: _isMaximized
          ? CustomIcons.FluentIcons.minimize_20
          : CustomIcons.FluentIcons.maximize_20,
      width: width,
      height: height,
      iconSize: iconSize,
      onPressed: () async {
        if (_isMaximized) {
          await restoreWindowProperly();
        } else {
          await maximizeWindowProperly();
        }
        setState(() {
          _isMaximized = !_isMaximized;
        });
      },
    );
  }

  Widget _buildCustomCloseButton(
    WindowButtonColors colors,
    double width,
    double height,
    double iconSize,
  ) {
    return _buildWindowButton(
      colors: colors,
      icon: CustomIcons.FluentIcons.dismiss_20,
      width: width,
      height: height,
      iconSize: iconSize,
      onPressed: () async {
        try {
          final config =
              Provider.of<ClientConfigService>(context, listen: false);
          final closeButtonBehavior = config.getCloseButtonBehavior();

          AppLoggerService().info(
              'App', 'Close button pressed, behavior: $closeButtonBehavior');

          if (closeButtonBehavior == 'minimize_to_tray') {
            systemTrayService.hideMainWindow();
          } else {
            await systemTrayService.exitApp();
          }
        } catch (e) {
          AppLoggerService().error('App', 'Error handling close button: $e');
          await systemTrayService.exitApp();
        }
      },
    );
  }

  Widget _buildWindowButton({
    required WindowButtonColors colors,
    required IconData icon,
    required VoidCallback onPressed,
    double width = 36,
    double height = 28,
    double iconSize = 16,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) {
          Color bgColor = colors.normal;
          Color iconColor = colors.iconNormal;

          if (states.isPressing) {
            bgColor = colors.mouseDown;
            iconColor = colors.iconMouseDown;
          } else if (states.isHovering) {
            bgColor = colors.mouseOver;
            iconColor = colors.iconMouseOver;
          }

          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                icon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddDownloadDialog(),
    );
  }
}

/// Fluent Design 导航项组件 - 简洁版本（性能优化）
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  // 优化：合并为单个动画控制器，减少资源占用
  late AnimationController _controller;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
      value: widget.isSelected ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected != widget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent _) {
    if (!_isHovered) {
      setState(() => _isHovered = true);
    }
  }

  void _onExit(PointerEvent _) {
    if (_isHovered) {
      setState(() => _isHovered = false);
    }
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final selectValue = _controller.value;
              final hoverValue = _isHovered ? 1.0 : 0.0;
              final pressValue = _isPressed ? 1.0 : 0.0;

              // 轻微的缩放效果
              final scale = 1.0 - (pressValue * 0.02);

              return Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: widget.isCompact
                    ? _buildCompactContent(hoverValue, selectValue)
                    : _buildExpandedContent(hoverValue, selectValue),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactContent(double hoverValue, double selectValue) {
    final bgAlpha = (selectValue * 0.8 + hoverValue * 0.4 * (1 - selectValue))
        .clamp(0.0, 0.8);

    final iconColor = Color.lerp(
      Color.lerp(AppTheme.textSecondary, AppTheme.textPrimary, hoverValue),
      AppTheme.accentLight,
      selectValue,
    )!;

    // 优化：移除 AnimatedContainer 和 AnimatedPositioned，改用普通 Container
    // 外层 AnimatedBuilder 已经在驱动动画了，嵌套隐式动画会导致双重合成层
    return Center(
      child: Container(
        width: 40,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.bgLayer2.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 选中指示条
            if (selectValue > 0.01)
              Positioned(
                left: 4,
                top: (36 - (16 * selectValue).clamp(0.0, 16.0)) / 2,
                child: Container(
                  width: 3,
                  height: (16 * selectValue).clamp(0.0, 16.0),
                  decoration: BoxDecoration(
                    color:
                        AppTheme.accentPrimary.withValues(alpha: selectValue),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // 图标
            Icon(
              widget.icon,
              size: 16,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(double hoverValue, double selectValue) {
    final bgAlpha = (selectValue * 0.8 + hoverValue * 0.4 * (1 - selectValue))
        .clamp(0.0, 0.8);

    final iconColor = Color.lerp(
      Color.lerp(AppTheme.textSecondary, AppTheme.textPrimary, hoverValue),
      AppTheme.accentLight,
      selectValue,
    )!;

    final textColor = Color.lerp(
      AppTheme.textSecondary,
      AppTheme.textPrimary,
      (selectValue + hoverValue * (1 - selectValue)).clamp(0.0, 1.0),
    )!;

    // 优化：移除 AnimatedContainer，外层 AnimatedBuilder 已经在驱动动画
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // 选中指示条
          if (selectValue > 0.01)
            Container(
              width: 3,
              height: (16 * selectValue).clamp(0.0, 16.0),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: selectValue),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Icon(widget.icon, size: 16, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontWeight:
                    widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
