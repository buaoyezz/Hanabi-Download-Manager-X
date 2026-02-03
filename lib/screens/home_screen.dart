import 'dart:ui';
import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../main.dart' show isWindowMaximized, maximizeWindowProperly, restoreWindowProperly;
import '../utils/constants.dart';
import '../utils/fluent_icons.dart' as CustomIcons;
import '../services/integrated_download_service.dart';
import '../services/developer_mode_service.dart';
import '../services/app_logger_service.dart';
import '../services/kernel_service.dart';
import '../services/kernel/kernel_manager.dart';
import '../services/window_effect_service.dart';
import '../services/client_config_service.dart';
import '../services/user_profile_service.dart';
import '../services/update_service.dart';
import '../services/performance_monitor_service.dart';
import '../models/download_task.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../widgets/animated_notifications.dart';
import 'widgets/download_list.dart';
import 'widgets/add_download_dialog.dart';
import 'widgets/completed_list.dart';
import 'widgets/settings_page.dart';
import 'widgets/about_page.dart';
import 'widgets/debug/log_page.dart';
import 'widgets/debug/status_page.dart';
import 'widgets/debug/web_check_page.dart';
import 'widgets/debug/online_stats_page.dart';
import 'widgets/performance_monitor_page.dart';

class NavigationItem {
  final IconData icon;
  final String title;
  final Widget body;

  NavigationItem({
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSidebarExpanded = true;
  late AnimationController _sidebarController;
  late Animation<double> _widthAnimation;

  // 当前选中的页面标识符（使用页面标题作为唯一标识）
  String _currentPageTitle = '下载中';
  
  // 窗口大小监听
  Timer? _windowSizeCheckTimer;
  double _lastSavedWidth = 0;
  double _lastSavedHeight = 0;
  
  List<NavigationItem> _getNavItems(BuildContext context) {
    // 使用 select 只监听影响导航列表的字段
    final showLogPage = context.select<DeveloperModeService, bool>((s) => s.showLogPage);
    final showStatusPage = context.select<DeveloperModeService, bool>((s) => s.showStatusPage);
    final showWebCheckPage = context.select<DeveloperModeService, bool>((s) => s.showWebCheckPage);
    final showOnlineStatsPage = context.select<DeveloperModeService, bool>((s) => s.showOnlineStatsPage);
    final showPerformanceMonitorPage = context.select<DeveloperModeService, bool>((s) => s.showPerformanceMonitorPage);
    final statsEnabled = context.select<UserProfileService, bool>((s) => s.statsEnabled);
    
    final items = <NavigationItem>[
      NavigationItem(
        icon: CustomIcons.FluentIcons.download,
        title: '下载中',
        body: const DownloadList(),
      ),
      NavigationItem(
        icon: CustomIcons.FluentIcons.completed_solid,
        title: '已完成',
        body: const CompletedList(),
      ),
    ];
    
    final bottomItems = <NavigationItem>[];
    
    if (showLogPage) {
      bottomItems.add(NavigationItem(
        icon: CustomIcons.FluentIcons.document,
        title: '日志',
        body: const LogPage(key: ValueKey('log_page')),
      ));
    }
    
    if (showStatusPage) {
      bottomItems.add(NavigationItem(
        icon: CustomIcons.FluentIcons.health,
        title: '状态',
        body: const StatusPage(key: ValueKey('status_page')),
      ));
    }
    
    if (showWebCheckPage) {
      bottomItems.add(NavigationItem(
        icon: CustomIcons.FluentIcons.globe,
        title: 'Web检测',
        body: const WebCheckPage(key: ValueKey('web_check_page')),
      ));
    }
    
    // 在线统计页面（独立开关）
    if (showOnlineStatsPage && statsEnabled) {
      bottomItems.add(NavigationItem(
        icon: CustomIcons.FluentIcons.people,
        title: '在线统计',
        body: const OnlineStatsPage(key: ValueKey('online_stats_page')),
      ));
    }

    // 性能监控页面
    if (showPerformanceMonitorPage) {
      bottomItems.add(NavigationItem(
        icon: CustomIcons.FluentIcons.speed_high,
        title: '性能监控',
        body: const PerformanceMonitorPage(key: ValueKey('performance_monitor_page')),
      ));
    }
    
    bottomItems.addAll([
      NavigationItem(
        icon: CustomIcons.FluentIcons.settings,
        title: '设置',
        body: const SettingsPage(key: ValueKey('settings_page')),
      ),
      NavigationItem(
        icon: CustomIcons.FluentIcons.info,
        title: '关于',
        body: const AboutPage(key: ValueKey('about_page')),
      ),
    ]);
    
    return [...items, ...bottomItems];
  }

  @override
  void initState() {
    super.initState();
    AppLoggerService().info('App', 'HomeScreen initialized');
    
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
          final currentVersion = updateService.currentVersion;
          final newVersion = availableUpdate.version;
          
          NotificationManager.of(context)?.showInfo(
            '检测到了船新的版本啦',
            message: '本次更新为 $currentVersion -> $newVersion\n快去设置页面更新吧！',
          );
          
          AppLoggerService().info('Update', '发现新版本: $newVersion，已显示通知');
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
      
      AppLoggerService().info('App', 'Sidebar default state loaded: ${defaultExpanded ? "expanded" : "collapsed"}');
    } catch (e) {
      AppLoggerService().error('App', 'Failed to load sidebar state: $e');
      // 如果加载失败，使用默认展开状态
      _isSidebarExpanded = true;
      _sidebarController.value = 0;
    }
  }
  
  @override
  void dispose() {
    _sidebarController.dispose();
    _windowSizeCheckTimer?.cancel();
    super.dispose();
  }
  
  /// 启动窗口大小监听
  void _startWindowSizeMonitoring() {
    // 初始化上次保存的大小
    _lastSavedWidth = appWindow.size.width;
    _lastSavedHeight = appWindow.size.height;
    
    // 每秒检查一次窗口大小变化
    _windowSizeCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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
      final isMaximized = isWindowMaximized();

      if (isMaximized) return; // 最大化时不保存窗口大小
      
      // 验证窗口大小是否合理（防止保存异常值）
      // 最小尺寸 600x400，最大尺寸 4096x2160
      // 窗口最小化时，size 可能会变成很小的值（如 160x28），需要过滤掉
      if (currentWidth < 600 || currentHeight < 400 || 
          currentWidth > 4096 || currentHeight > 2160) {
        AppLoggerService().warning('App', 'Invalid window size detected: ${currentWidth.toInt()}x${currentHeight.toInt()}, skipping save');
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
        
        AppLoggerService().debug('App', 'Window size saved: ${currentWidth.toInt()}x${currentHeight.toInt()}');
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

    final navItems = _getNavItems(context);
    // 优化：使用 select 只监听需要的字段，避免不必要的重建
    final kernelIsRunning = context.select<KernelService, bool>((s) => s.isRunning);
    final kernelManagerIsRunning = context.select<KernelManager, bool>((s) => s.isRunning);
    final isTransparent = context.select<WindowEffectService, bool>(
      (s) => s.isTransparentBackground || s.effectMode.startsWith('mica')
    );
    
    // 根据窗口效果调整背景透明度
    final sidebarOpacity = isTransparent ? 0.2 : 0.65;
    
    // 核心修复逻辑：确保 _currentIndex 与 _currentPageTitle 同步
    // 这解决了列表项动态增减（如在线统计出现/消失）导致的索引错位
    final correctIndex = navItems.indexWhere((item) => item.title == _currentPageTitle);
    
    if (correctIndex != -1) {
      // 找到了当前标题对应的页面，更新索引
      _currentIndex = correctIndex;
    } else {
      // 当前页面不在列表里了（可能是相关功能开关关闭了）
      // 检查索引越界情况
      if (_currentIndex >= navItems.length) {
        _currentIndex = navItems.length > 0 ? navItems.length - 1 : 0;
      }
      // 更新标题为当前索引的新页面
      if (navItems.isNotEmpty) {
        _currentPageTitle = navItems[_currentIndex].title;
      }
    }
    
    return WindowBorder(
      color: Colors.transparent,
      width: 0,
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            // 顶部标题栏（横跨整个窗口）
            _buildUnifiedTitleBar(context, sidebarOpacity),
            // 下方：侧边栏 + 内容区
            Expanded(
              child: Row(
                children: [
                  // 左侧：侧边栏（不含标题）
                  _buildEdgeSidebar(context, navItems, sidebarOpacity),
                  // 右侧：内容区（带圆角）
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                      ),
                      child: _buildContentArea(context, isTransparent, kernelIsRunning, kernelManagerIsRunning, navItems),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 内容区域 - 根据窗口效果设置决定是否使用模糊
  Widget _buildContentArea(BuildContext context, bool isTransparent, bool kernelIsRunning, bool kernelManagerIsRunning, List<NavigationItem> navItems) {
    final effectEnabled = context.select<WindowEffectService, bool>((s) => s.effectEnabled);
    final useBlur = effectEnabled && isTransparent;

    final contentContainer = Container(
      decoration: BoxDecoration(
        color: AppTheme.bgBase.withValues(alpha: useBlur ? 0.75 : 0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
        ),
        border: Border(
          left: BorderSide(
            color: AppTheme.borderSubtle.withValues(alpha: 0.3),
            width: 1,
          ),
          top: BorderSide(
            color: AppTheme.borderSubtle.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildPageContent(kernelIsRunning, kernelManagerIsRunning, navItems),
    );

    // 只有在启用窗口效果时才使用 BackdropFilter，并用 RepaintBoundary 隔离
    if (useBlur) {
      return RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: contentContainer,
        ),
      );
    }

    return contentContainer;
  }

  /// 统一的顶部标题栏 - 横跨整个窗口
  Widget _buildUnifiedTitleBar(BuildContext context, double opacity) {
    final windowEffect = context.watch<WindowEffectService>();
    final useBlur = windowEffect.effectEnabled;

    final titleBarContent = Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.bgSolid.withValues(alpha: useBlur ? opacity : 1.0),
      ),
      child: Row(
        children: [
          // 左侧：汉堡菜单（固定52px，与收缩后的侧边栏对齐）
          SizedBox(
            width: 52,
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
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
                  child: Icon(CustomIcons.FluentIcons.global_nav_button,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          // 中间：Logo + 标题 + 可拖动区域
          Expanded(
            child: MoveWindow(
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  // Logo
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/logo/logo.png',
                        width: 18,
                        height: 18,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 标题
                  Text(
                    'Hanabi Download Manager X',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  // 剩余空间也可拖动
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
          // 右侧：操作按钮
          _buildTitleBarActions(context),
        ],
      ),
    );

    // 只有在启用窗口效果时才使用 BackdropFilter，并用 RepaintBoundary 隔离
    if (useBlur) {
      return RepaintBoundary(
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: titleBarContent,
          ),
        ),
      );
    }

    return titleBarContent;
  }

  /// 标题栏右侧操作按钮
  Widget _buildTitleBarActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final isVeryNarrow = constraints.maxWidth < 350;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 统计信息 - 窄屏时隐藏
            if (!isNarrow) ...[
              _buildStatsChip(),
              const SizedBox(width: 12),
            ],
            // 新建按钮
            if (isVeryNarrow)
              _buildCompactNewTaskButton(context)
            else
              _buildNewTaskButton(context),
            const SizedBox(width: 8),
            // 托盘按钮
            _buildAnimatedTrayButton(context),
            const SizedBox(width: 8),
            // 窗口控制按钮
            _buildWindowButtons(context),
          ],
        );
      },
    );
  }

  Widget _buildPageContent(bool kernelIsRunning, bool kernelManagerIsRunning, List<NavigationItem> navItems) {
    // 检查新内核或旧内核是否在运行
    final isKernelRunning = kernelManagerIsRunning || kernelIsRunning;

    // 如果内核正在运行，或者当前页面是调试页面（日志、状态、Web检测、在线统计、性能监控），直接显示页面
    final currentPageTitle = navItems[_currentIndex].title;
    final isDebugPage = currentPageTitle == '日志' ||
                        currentPageTitle == '状态' ||
                        currentPageTitle == 'Web检测' ||
                        currentPageTitle == '在线统计' ||
                        currentPageTitle == '性能监控' ||
                        currentPageTitle == '设置' ||
                        currentPageTitle == '关于';
    
    if (isKernelRunning || isDebugPage) {
      // 使用 AnimatedSwitcher 实现页面切换的淡入淡出效果
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        transitionBuilder: (child, animation) {
          // 淡入淡出 + 轻微位移，更流畅
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.015, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          // 核心修复点：使用标题作为 Key，而不是索引
          // 这样即使列表发生变化导致索引改变，只要标题没变，就不会触发页面重绘或跳转
          key: ValueKey(navItems[_currentIndex].title),
          child: navItems[_currentIndex].body,
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
        final useNewKernel = context.read<ClientConfigService>().getBool('kernel.use_new_kernel', defaultValue: true);
        
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ProgressRing(),
                const SizedBox(height: 20),
                const Text(
                  '正在启动下载内核...',
                  style: TextStyle(
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
                  const Text(
                    '请稍候，这可能需要几秒钟',
                    style: TextStyle(
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
                        final devMode = Provider.of<DeveloperModeService>(context, listen: false);
                        if (!devMode.showLogPage) {
                          await devMode.setShowLogPage(true);
                        }
                        // 等待一帧，让 UI 更新
                        await Future.delayed(const Duration(milliseconds: 100));
                        // 切换到日志页面（日志页面通常在索引 2）
                        if (mounted) {
                          setState(() {
                            _currentIndex = 2;  // 下载中(0), 已完成(1), 日志(2)
                            _currentPageTitle = '日志';
                          });
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CustomIcons.FluentIcons.text_document, size: 14),
                          SizedBox(width: 6),
                          Text('查看日志'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () async {
                        // 重试启动
                        final config = Provider.of<ClientConfigService>(context, listen: false);
                        final useNewKernel = config.getBool('kernel.use_new_kernel', defaultValue: true);
                        
                        if (useNewKernel) {
                          final kernelManager = Provider.of<KernelManager>(context, listen: false);
                          await kernelManager.start(type: KernelType.next);
                        } else {
                          final kernelService = Provider.of<KernelService>(context, listen: false);
                          await kernelService.startKernel();
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CustomIcons.FluentIcons.refresh, size: 14),
                          SizedBox(width: 6),
                          Text('重试'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Edge 风格侧边栏 - 只包含导航项（优化版，减少重建）
  Widget _buildEdgeSidebar(BuildContext context, List<NavigationItem> navItems, double opacity) {
    final effectEnabled = context.select<WindowEffectService, bool>((s) => s.effectEnabled);
    final useBlur = effectEnabled;

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final width = _widthAnimation.value;
        final isCompact = width < 100;

        final sidebarContent = Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSolid.withValues(alpha: useBlur ? opacity : 1.0),
            border: const Border(
              right: BorderSide(
                color: AppTheme.borderSubtle,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // 主导航项
              ...navItems.asMap().entries
                  .where((entry) => !['日志', '状态', 'Web检测', '在线统计', '性能监控', '设置', '关于'].contains(entry.value.title))
                  .map((entry) => _buildNavItemWidget(context, entry.key, entry.value, isCompact)),

              const Spacer(),

              // 分隔线
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16, vertical: 8),
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
            // 主侧边栏 - 使用 RepaintBoundary 隔离模糊效果
            ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1.0,
                child: SizedBox(
                  width: width,
                  child: useBlur
                      ? RepaintBoundary(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: sidebarContent,
                          ),
                        )
                      : sidebarContent,
                ),
              ),
            ),
            // 右上角圆角装饰 - 填补三角形缝隙
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.bgSolid.withValues(alpha: useBlur ? opacity : 1.0),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
  List<Widget> _buildBottomNavItems(BuildContext context, List<NavigationItem> navItems, bool isCompact) {
    final bottomItems = navItems.asMap().entries
        .where((entry) => ['日志', '状态', 'Web检测', '在线统计', '性能监控', '设置', '关于'].contains(entry.value.title))
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
            Text('新建', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  /// 托盘按钮（带动画效果）
  Widget _buildAnimatedTrayButton(BuildContext context) {
    final config = context.watch<ClientConfigService>();
    final closeButtonBehavior = config.getCloseButtonBehavior();
    final shouldShowTrayButton = closeButtonBehavior != 'minimize_to_tray';
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.elasticOut,
          )),
          child: FadeTransition(
            opacity: Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
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
                  child: Icon(CustomIcons.FluentIcons.chrome_minimize, size: 12),
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
        final downloading = service.tasks.where((t) => t.status == DownloadStatus.downloading).length;
        final completed = service.tasks.where((t) => t.status == DownloadStatus.completed).length;
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
            border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem(CustomIcons.FluentIcons.download, downloading, AppTheme.accentPrimary),
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppTheme.borderSubtle.withValues(alpha: 0.5),
              ),
              _buildStatItem(CustomIcons.FluentIcons.completed, completed, AppTheme.statusSuccess),
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

  Widget _buildNavItemWidget(BuildContext context, int index, NavigationItem item, bool isCompact) {
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
            _currentPageTitle = item.title;
          });
        },
      ),
    );
  }



  Widget _buildWindowButtons(BuildContext context) {
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

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            _buildCustomMinimizeButton(buttonColors),
            _buildCustomMaximizeButton(buttonColors),
            _buildCustomCloseButton(closeButtonColors),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomMinimizeButton(WindowButtonColors colors) {
    return _buildWindowButton(
      colors: colors,
      icon: CustomIcons.FluentIcons.subtract_20,
      onPressed: () => appWindow.minimize(),
    );
  }

  Widget _buildCustomMaximizeButton(WindowButtonColors colors) {
    final isMaximized = isWindowMaximized();
    return _buildWindowButton(
      colors: colors,
      icon: isMaximized ? CustomIcons.FluentIcons.minimize_20 : CustomIcons.FluentIcons.maximize_20,
      onPressed: () async {
        if (isMaximized) {
          await restoreWindowProperly();
        } else {
          await maximizeWindowProperly();
        }
        setState(() {});
      },
    );
  }

  Widget _buildCustomCloseButton(WindowButtonColors colors) {
    return _buildWindowButton(
      colors: colors,
      icon: CustomIcons.FluentIcons.dismiss_20,
      onPressed: () async {
        try {
          final config = Provider.of<ClientConfigService>(context, listen: false);
          final closeButtonBehavior = config.getCloseButtonBehavior();

          AppLoggerService().info('App', 'Close button pressed, behavior: $closeButtonBehavior');

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
  }) {
    return SizedBox(
      width: 36,
      height: 28,
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) {
          Color bgColor = colors.normal ?? Colors.transparent;
          Color iconColor = colors.iconNormal ?? AppTheme.textSecondary;

          if (states.isPressing) {
            bgColor = colors.mouseDown ?? AppTheme.bgLayer3;
            iconColor = colors.iconMouseDown ?? AppTheme.textPrimary;
          } else if (states.isHovering) {
            bgColor = colors.mouseOver ?? AppTheme.bgLayer2;
            iconColor = colors.iconMouseOver ?? AppTheme.textPrimary;
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
                size: 16,
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

/// Fluent Design 导航项组件 - 简洁版本
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

class _NavItemState extends State<_NavItem> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _hoverController;
  late AnimationController _selectController;
  
  // 缓存动画值，避免每帧重新计算
  late Animation<double> _pressAnimation;
  late Animation<double> _hoverAnimation;
  late Animation<double> _selectAnimation;
  
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    // 按压动画 - 快速响应，使用 easeOut 让释放更自然
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    // Hover 动画 - 使用 easeOutQuart 实现优雅的减速效果
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    // 选中动画 - 使用 easeInOutCubic 实现平滑的状态切换
    _selectController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    
    // 创建缓存的动画对象
    _pressAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOut,
    );
    _hoverAnimation = CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutQuart,
    );
    _selectAnimation = CurvedAnimation(
      parent: _selectController,
      curve: Curves.easeInOutCubic,
    );
    
    if (widget.isSelected) {
      _selectController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected != widget.isSelected) {
      if (widget.isSelected) {
        _selectController.forward();
      } else {
        _selectController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _hoverController.dispose();
    _selectController.dispose();
    // CurvedAnimation 会自动被 controller dispose 时清理，不需要手动 dispose
    super.dispose();
  }

  void _onEnter(PointerEvent _) {
    if (!_isHovered) {
      setState(() => _isHovered = true);
      _hoverController.forward();
    }
  }

  void _onExit(PointerEvent _) {
    if (_isHovered) {
      setState(() => _isHovered = false);
      _hoverController.reverse();
    }
  }

  void _onTapDown(TapDownDetails _) => _pressController.forward();
  
  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onTap();
  }
  
  void _onTapCancel() => _pressController.reverse();

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
            animation: Listenable.merge([_pressAnimation, _hoverAnimation, _selectAnimation]),
            builder: (context, child) {
              // 直接使用缓存的动画值，不需要再次应用曲线
              final pressValue = _pressAnimation.value;
              final hoverValue = _hoverAnimation.value;
              final selectValue = _selectAnimation.value;
              
              // 轻微的缩放效果，避免过度动画
              final scale = 1.0 - (pressValue * 0.015);
              
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
    final bgAlpha = (selectValue * 0.8 + hoverValue * 0.4 * (1 - selectValue)).clamp(0.0, 0.8);
    
    final iconColor = Color.lerp(
      Color.lerp(AppTheme.textSecondary, AppTheme.textPrimary, hoverValue),
      AppTheme.accentLight,
      selectValue,
    )!;
    
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOutCubic,
        width: 40,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.bgLayer2.withValues(alpha: bgAlpha),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 选中指示条 - 使用 AnimatedContainer 实现高度动画
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOutCubic,
              left: 4,
              top: (36 - (16 * selectValue).clamp(0.0, 16.0)) / 2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOutCubic,
                width: 3,
                height: (16 * selectValue).clamp(0.0, 16.0),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: selectValue),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 图标 - 使用 AnimatedSwitcher 实现颜色过渡
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                widget.icon,
                key: ValueKey('${widget.icon}_$selectValue'),
                size: 16,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent(double hoverValue, double selectValue) {
    final bgAlpha = (selectValue * 0.8 + hoverValue * 0.4 * (1 - selectValue)).clamp(0.0, 0.8);
    
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
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOutCubic,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // 选中指示条 - 使用 AnimatedContainer 实现宽度和高度动画
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOutCubic,
            width: selectValue > 0.01 ? 3 : 0,
            height: (16 * selectValue).clamp(0.0, 16.0),
            margin: EdgeInsets.only(right: selectValue > 0.01 ? 12 : 0),
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withValues(alpha: selectValue),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(widget.icon, size: 16, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOutCubic,
              style: TextStyle(
                color: textColor,
                fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              child: Text(
                widget.title,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


