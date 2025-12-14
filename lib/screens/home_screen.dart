import 'dart:ui';
import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../utils/constants.dart';
import '../services/integrated_download_service.dart';
import '../services/developer_mode_service.dart';
import '../services/app_logger_service.dart';
import '../services/kernel_service.dart';
import '../services/window_effect_service.dart';
import '../services/client_config_service.dart';
import '../models/download_task.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'widgets/download_list.dart';
import 'widgets/add_download_dialog.dart';
import 'widgets/completed_list.dart';
import 'widgets/settings_page.dart';
import 'widgets/about_page.dart';
import 'widgets/debug/log_page.dart';
import 'widgets/debug/status_page.dart';
import 'widgets/debug/web_check_page.dart';

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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSidebarExpanded = true;
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  // 当前选中的页面标识符（使用页面标题作为唯一标识）
  String _currentPageTitle = '下载中';
  
  // 窗口大小监听
  Timer? _windowSizeCheckTimer;
  double _lastSavedWidth = 0;
  double _lastSavedHeight = 0;
  
  List<NavigationItem> _getNavItems(BuildContext context) {
    final devMode = context.watch<DeveloperModeService>();
    
    final items = <NavigationItem>[
      NavigationItem(
        icon: FluentIcons.download,
        title: '下载中',
        body: const DownloadList(),
      ),
      NavigationItem(
        icon: FluentIcons.completed,
        title: '已完成',
        body: const CompletedList(),
      ),
    ];
    
    final bottomItems = <NavigationItem>[];
    
    if (devMode.showLogPage) {
      bottomItems.add(NavigationItem(
        icon: FluentIcons.text_document,
        title: '日志',
        body: const LogPage(),
      ));
    }
    
    if (devMode.showStatusPage) {
      bottomItems.add(NavigationItem(
        icon: FluentIcons.health,
        title: '状态',
        body: const StatusPage(),
      ));
    }
    
    if (devMode.showWebCheckPage) {
      bottomItems.add(NavigationItem(
        icon: FluentIcons.globe,
        title: 'Web检测',
        body: const WebCheckPage(),
      ));
    }
    
    bottomItems.addAll([
      NavigationItem(
        icon: FluentIcons.settings,
        title: '设置',
        body: const SettingsPage(),
      ),
      NavigationItem(
        icon: FluentIcons.info,
        title: '关于',
        body: const AboutPage(),
      ),
    ]);
    
    return [...items, ...bottomItems];
  }

  @override
  void initState() {
    super.initState();
    AppLoggerService().info('App', 'HomeScreen initialized');
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _widthAnimation = Tween<double>(begin: 220, end: 50).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
    
    // 从配置中读取默认侧边栏状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSidebarState();
      _startWindowSizeMonitoring();
    });
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
        _animationController.value = 0; // 展开状态
      } else {
        _animationController.value = 1; // 收缩状态
      }
      
      AppLoggerService().info('App', 'Sidebar default state loaded: ${defaultExpanded ? "expanded" : "collapsed"}');
    } catch (e) {
      AppLoggerService().error('App', 'Failed to load sidebar state: $e');
      // 如果加载失败，使用默认展开状态
      _isSidebarExpanded = true;
      _animationController.value = 0;
    }
  }
  
  /// 智能更新当前索引，根据页面标题找到正确的索引
  void _updateCurrentIndex(List<NavigationItem> navItems) {
    // 尝试根据当前页面标题找到对应的索引
    int newIndex = -1;
    for (int i = 0; i < navItems.length; i++) {
      if (navItems[i].title == _currentPageTitle) {
        newIndex = i;
        break;
      }
    }
    
    // 如果找到了对应的页面，更新索引
    if (newIndex != -1) {
      _currentIndex = newIndex;
    } else {
      // 如果当前页面不存在了（比如调试页面被关闭），回退到安全的页面
      if (_currentIndex >= navItems.length) {
        // 如果当前索引超出范围，尝试回退到设置页面或第一个页面
        int settingsIndex = -1;
        for (int i = 0; i < navItems.length; i++) {
          if (navItems[i].title == '设置') {
            settingsIndex = i;
            break;
          }
        }
        
        if (settingsIndex != -1) {
          _currentIndex = settingsIndex;
          _currentPageTitle = '设置';
        } else {
          _currentIndex = 0;
          _currentPageTitle = navItems.isNotEmpty ? navItems[0].title : '下载中';
        }
        
        AppLoggerService().info('App', 'Page not found, fallback to: $_currentPageTitle');
      } else {
        // 更新当前页面标题为实际显示的页面
        _currentPageTitle = navItems[_currentIndex].title;
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      final isMaximized = appWindow.isMaximized;
      
      // 如果窗口最大化，不保存大小
      if (isMaximized) return;
      
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
        _animationController.reverse();
      } else {
        _animationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _getNavItems(context);
    final kernelService = context.watch<KernelService>();
    final windowEffect = context.watch<WindowEffectService>();
    final isTransparent = windowEffect.isTransparentBackground || 
                          windowEffect.effectMode.startsWith('mica');
    
    // 根据窗口效果调整背景透明度
    final sidebarOpacity = isTransparent ? 0.2 : 0.65;
    
    // 智能索引管理：根据页面标题找到正确的索引
    _updateCurrentIndex(navItems);
    
    return WindowBorder(
      color: Colors.transparent,
      width: 0,
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            // 顶部标题栏（横跨整个窗口）
            _buildTopTitleBar(context, sidebarOpacity),
            // 下方内容区（侧边栏 + 主内容）
            Expanded(
              child: Row(
                children: [
                  // 侧边栏
                  _buildSidebar(context, navItems, sidebarOpacity),
                  // 主内容区
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                      ),
                      child: _buildPageContent(kernelService, navItems),
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

  Widget _buildPageContent(KernelService kernelService, List<NavigationItem> navItems) {
    // 如果内核正在运行，或者当前页面是调试页面（日志、状态、Web检测），直接显示页面
    final currentPageTitle = navItems[_currentIndex].title;
    final isDebugPage = currentPageTitle == '日志' || 
                        currentPageTitle == '状态' || 
                        currentPageTitle == 'Web检测';
    
    if (kernelService.isRunning || isDebugPage) {
      return navItems[_currentIndex].body;
    }
    
    // 否则显示加载动画
    return _buildLoadingIndicator();
  }

  Widget _buildLoadingIndicator() {
    return Consumer<KernelService>(
      builder: (context, kernelService, child) {
        final progress = kernelService.startupProgress;
        final status = kernelService.startupStatus;
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.text_document, size: 14),
                          SizedBox(width: 6),
                          Text('查看日志'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () async {
                        // 重试启动
                        final kernelService = Provider.of<KernelService>(context, listen: false);
                        await kernelService.startKernel();
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.refresh, size: 14),
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

  /// 顶部标题栏 - 横跨整个窗口
  Widget _buildTopTitleBar(BuildContext context, double opacity) {
    return SizedBox(
      height: 60, // 标题栏高度
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.bgSolid.withValues(alpha: opacity),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final isNarrow = availableWidth < 600; // 窄屏阈值
                final isVeryNarrow = availableWidth < 400; // 极窄屏阈值
                
                return Row(
                  children: [
                    // 左侧：Logo + 标题
                    MoveWindow(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentPrimary.withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.asset(
                                  'assets/logo/logo.png',
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            if (!isVeryNarrow) ...[
                              const SizedBox(width: 12),
                              // 应用名称 - 极窄屏时隐藏
                              Text(
                                AppConstants.appName,
                                style: FluentTheme.of(context).typography.caption?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    // 中间：可拖动区域
                    Expanded(child: MoveWindow()),
                    
                    // 右侧：响应式组件布局
                    _buildResponsiveRightSide(context, isNarrow, isVeryNarrow),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 构建响应式右侧组件
  Widget _buildResponsiveRightSide(BuildContext context, bool isNarrow, bool isVeryNarrow) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 统计信息 - 窄屏时隐藏
        if (!isNarrow) ...[
          _buildStatsChip(),
          const SizedBox(width: 12),
        ],
        
        // 新建按钮 - 极窄屏时使用图标版本
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
        child: const Icon(FluentIcons.add, size: 12),
      ),
    );
  }

  /// 构建底部导航项（简化版本，移除有问题的动画）
  List<Widget> _buildBottomNavItems(BuildContext context, List<NavigationItem> navItems, bool isCompact) {
    final bottomItems = navItems.asMap().entries
        .where((entry) => ['日志', '状态', 'Web检测', '设置', '关于'].contains(entry.value.title))
        .toList();
    
    return bottomItems.map((entry) {
      final item = entry.value;
      final index = entry.key;
      
      // 使用简单的 AnimatedSwitcher 来处理页面的出现和消失
      return AnimatedSwitcher(
        key: ValueKey('${item.title}_switcher'),
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.3, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: _buildNavItemWidget(context, index, item, isCompact),
      );
    }).toList();
  }

  /// 侧边栏
  Widget _buildSidebar(BuildContext context, List<NavigationItem> navItems, double opacity) {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final width = _widthAnimation.value;
        final isCompact = width < 150;
        
        return Container(
          width: width,
          decoration: BoxDecoration(
            color: AppTheme.bgSolid.withValues(alpha: opacity),
          ),
          child: Column(
            children: [
              const SizedBox(height: 4),
              
              // 汉堡菜单按钮
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 0 : 12,
                  vertical: 4,
                ),
                child: SizedBox(
                  height: 36,
                  width: isCompact ? 40 : double.infinity,
                  child: Button(
                    onPressed: _toggleSidebar,
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                        isCompact 
                            ? EdgeInsets.zero 
                            : const EdgeInsets.only(left: 12),
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.isHovered) {
                          return AppTheme.bgLayer2.withValues(alpha: 0.5);
                        }
                        return Colors.transparent;
                      }),
                      shape: WidgetStateProperty.all(
                        const RoundedRectangleBorder(side: BorderSide.none),
                      ),
                    ),
                    child: Align(
                      alignment: isCompact ? Alignment.center : Alignment.centerLeft,
                      child: const Icon(
                        FluentIcons.global_nav_button,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              
              // 主导航项
              ...navItems.asMap().entries
                  .where((entry) => !['日志', '状态', 'Web检测', '设置', '关于'].contains(entry.value.title))
                  .map((entry) => _buildNavItemWidget(context, entry.key, entry.value, isCompact)),
              
              const Spacer(),
              
              // 分隔线
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 16, vertical: 8),
                child: Container(
                  height: 1,
                  color: AppTheme.borderSubtle.withValues(alpha: 0.5),
                ),
              ),
              
              // 底部导航项（带动画的调试页面）
              ..._buildBottomNavItems(context, navItems, isCompact),
              
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.add, size: 12),
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
                  child: const Icon(FluentIcons.chrome_minimize, size: 12),
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
    return Consumer<IntegratedDownloadService>(
      builder: (context, service, _) {
        final downloading = service.tasks.where((t) => t.status == DownloadStatus.downloading).length;
        final completed = service.tasks.where((t) => t.status == DownloadStatus.completed).length;
        
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
              _buildStatItem(FluentIcons.download, downloading, AppTheme.accentPrimary),
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: AppTheme.borderSubtle.withValues(alpha: 0.5),
              ),
              _buildStatItem(FluentIcons.completed, completed, AppTheme.statusSuccess),
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
        horizontal: isCompact ? 8 : 12,
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
      iconMouseDown: AppTheme.textPrimary,
      iconMouseOver: AppTheme.textPrimary,
      normal: Colors.transparent,
      mouseOver: AppTheme.statusError,
      mouseDown: const Color(0xFFC50F1F),
    );

    return SizedBox(
      height: 60,
      child: Row(
        children: [
          MinimizeWindowButton(colors: buttonColors),
          MaximizeWindowButton(colors: buttonColors),
          _buildCustomCloseButton(closeButtonColors),
        ],
      ),
    );
  }

  Widget _buildCustomCloseButton(WindowButtonColors colors) {
    return WindowButton(
      colors: colors,
      iconBuilder: (context) => Icon(
        FluentIcons.chrome_close,
        color: colors.iconNormal,
        size: 10,
      ),
      onPressed: () async {
        try {
          final config = Provider.of<ClientConfigService>(context, listen: false);
          final closeButtonBehavior = config.getCloseButtonBehavior();
          
          AppLoggerService().info('App', 'Close button pressed, behavior: $closeButtonBehavior');
          
          if (closeButtonBehavior == 'minimize_to_tray') {
            // 最小化到托盘
            systemTrayService.hideMainWindow();
          } else {
            // 退出应用
            await systemTrayService.exitApp();
          }
        } catch (e) {
          AppLoggerService().error('App', 'Error handling close button: $e');
          // 如果出错，默认退出应用
          await systemTrayService.exitApp();
        }
      },
    );
  }

  void _showAddDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddDownloadDialog(),
    );
  }
}

/// Fluent Design 导航项组件
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

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.isCompact
            ? _buildCompactContent()
            : AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOutCubic,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppTheme.bgLayer2.withValues(alpha: 0.8)
                      : _isHovered
                          ? AppTheme.bgLayer2.withValues(alpha: 0.5)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildExpandedContent(),
              ),
      ),
    );
  }

  Widget _buildCompactContent() {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        width: 40,
        height: 36,
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppTheme.bgLayer2.withValues(alpha: 0.8)
              : _isHovered
                  ? AppTheme.bgLayer2.withValues(alpha: 0.5)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 选中指示器
            if (widget.isSelected)
              Positioned(
                left: 4,
                child: Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Icon(
              widget.icon,
              size: 16,
              color: widget.isSelected
                  ? AppTheme.accentLight
                  : _isHovered
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Row(
      children: [
        // 选中指示器
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 3,
          height: widget.isSelected ? 16 : 0,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // 图标
        Icon(
          widget.icon,
          size: 16,
          color: widget.isSelected
              ? AppTheme.accentLight
              : _isHovered
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
        ),
        const SizedBox(width: 12),
        // 标题
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              color: widget.isSelected
                  ? AppTheme.textPrimary
                  : _isHovered
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
