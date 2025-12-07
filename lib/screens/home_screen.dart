import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../utils/constants.dart';
import '../services/integrated_download_service.dart';
import '../services/developer_mode_service.dart';
import '../services/app_logger_service.dart';
import '../services/kernel_service.dart';
import '../services/window_effect_service.dart';
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
    _animationController.value = 0; // 默认展开状态
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    final contentBgOpacity = isTransparent ? 0.3 : 0.85;
    
    if (_currentIndex >= navItems.length) {
      _currentIndex = 0;
    }
    
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
                    child: Container(
                      color: AppTheme.bgSolid.withValues(alpha: sidebarOpacity),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.bgSolid.withValues(alpha: contentBgOpacity),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: kernelService.isRunning
                            ? navItems[_currentIndex].body
                            : _buildLoadingIndicator(),
                      ),
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

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(),
          const SizedBox(height: 16),
          Text(
            '正在启动下载内核...',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
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
            child: Row(
          children: [
            // 左侧：Logo + 标题
            MoveWindow(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Row(
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
                    const SizedBox(width: 12),
                    // 应用名称
                    Text(
                      AppConstants.appName,
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // 中间：可拖动区域
            Expanded(child: MoveWindow()),
            
            // 右侧：统计信息 + 新建按钮 + 托盘按钮 + 窗口控制
            _buildStatsChip(),
            const SizedBox(width: 12),
            _buildNewTaskButton(context),
            const SizedBox(width: 8),
            _buildTrayButton(),
            const SizedBox(width: 8),
            _buildWindowButtons(context),
          ],
        ),
          ),
        ),
      ),
    );
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
                      child: Icon(
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
                  .where((entry) => !['日志', '状态', '设置', '关于'].contains(entry.value.title))
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
              
              // 底部导航项
              ...navItems.asMap().entries
                  .where((entry) => ['日志', '状态', '设置', '关于'].contains(entry.value.title))
                  .map((entry) => _buildNavItemWidget(context, entry.key, entry.value, isCompact)),
              
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

  /// 托盘按钮
  Widget _buildTrayButton() {
    return SizedBox(
      height: 28,
      width: 28,
      child: Button(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
        ),
        onPressed: () => systemTrayService.hideMainWindow(),
        child: const Icon(FluentIcons.chrome_minimize, size: 12),
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
          setState(() => _currentIndex = index);
        },
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context, bool isCompact) {
    if (isCompact) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            FluentIcons.info,
            size: 12,
            color: AppTheme.accentLight,
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.accentPrimary.withValues(alpha: 0.1),
              AppTheme.accentPrimary.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: AppTheme.accentPrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                FluentIcons.download,
                size: 16,
                color: AppTheme.accentLight,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppConstants.appName,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v${AppConstants.version}',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
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
          CloseWindowButton(colors: closeButtonColors),
        ],
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
