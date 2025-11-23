import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../utils/constants.dart';
import '../services/integrated_download_service.dart';
import '../models/download_task.dart';
import '../main.dart';
import 'widgets/download_list.dart';
import 'widgets/add_download_dialog.dart';
import 'widgets/completed_list.dart';
import 'widgets/settings_page.dart';

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

  final List<NavigationItem> _navItems = [
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
    NavigationItem(
      icon: FluentIcons.settings,
      title: '设置',
      body: const SettingsPage(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _widthAnimation = Tween<double>(begin: 200, end: 60).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.value = 0; // 初始展开
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
    return Container(
      color: const Color(0xFF1a1a1a),
      child: Column(
        children: [
          _buildCustomTitleBar(context),
          Expanded(
            child: Row(
              children: [
                _buildSideNavigation(context),
                Expanded(
                  child: Container(
                    color: const Color(0xFF1a1a1a),
                    child: _navItems[_currentIndex].body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTitleBar(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          // 纯色背景
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF242424),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF404040),
                  width: 1,
                ),
              ),
            ),
          ),
          // 内容层
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              return Row(
                children: [
                  Expanded(
                    child: WindowTitleBarBox(
                      child: MoveWindow(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.asset(
                                  'assets/logo/logo.png',
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  AppConstants.appName,
                                  style: FluentTheme.of(context).typography.caption?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    _buildStatsInfo(),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 26,
                      child: FilledButton(
                        onPressed: () => _showAddDownloadDialog(context),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.add, size: 11),
                            SizedBox(width: 4),
                            Text('新建', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 26,
                      child: Button(
                        onPressed: () => systemTrayService.hideMainWindow(),
                        child: const Text('最小化到托盘', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: IconButton(
                        icon: const Icon(FluentIcons.info, size: 13),
                        onPressed: () => _showAboutDialog(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  _buildWindowButtons(context),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavigation(BuildContext context) {
    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        final width = _widthAnimation.value;
        final isCompact = width < 100;
        
        return Container(
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFF242424),
            border: Border(
              right: BorderSide(
                color: const Color(0xFF404040),
                width: 1,
              ),
            ),
          ),
          child: Column(
                children: [
                  if (!isCompact) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          if (width > 150)
                            Text(
                              'Welcome',
                              style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: FluentTheme.of(context).accentColor,
                              ),
                            ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(FluentIcons.back, size: 14),
                            onPressed: _toggleSidebar,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        style: DividerThemeData(
                          decoration: BoxDecoration(
                            color: FluentTheme.of(context)
                                .resources
                                .dividerStrokeColorDefault,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (isCompact) ...[
                    const SizedBox(height: 12),
                    IconButton(
                      icon: const Icon(FluentIcons.global_nav_button, size: 14),
                      onPressed: _toggleSidebar,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  // 导航项
                  ..._navItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = _currentIndex == index;
                    
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 6 : 12,
                        vertical: 4,
                      ),
                      child: _buildNavItem(
                        context,
                        icon: item.icon,
                        title: item.title,
                        isSelected: isSelected,
                        isCompact: isCompact,
                        onTap: () => setState(() => _currentIndex = index),
                      ),
                    );
                  }),
                  const Spacer(),
                  // 底部信息
                  if (!isCompact)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FluentTheme.of(context)
                              .resources
                              .cardBackgroundFillColorDefault
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: FluentTheme.of(context)
                                .resources
                                .cardStrokeColorDefault
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FluentIcons.info,
                                  size: 12,
                                  color: FluentTheme.of(context).accentColor.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    AppConstants.appName,
                                    style: FluentTheme.of(context).typography.caption?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'v${AppConstants.version}',
                              style: FluentTheme.of(context).typography.caption?.copyWith(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isCompact)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        FluentIcons.info,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
        );
      },
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required bool isCompact,
    required VoidCallback onTap,
  }) {
    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 6 : 12,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? FluentTheme.of(context).accentColor.withValues(alpha: 0.15)
                : states.isHovered
                    ? FluentTheme.of(context).resources.subtleFillColorSecondary
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: FluentTheme.of(context).accentColor.withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: isCompact
              ? Center(
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? FluentTheme.of(context).accentColor
                        : Colors.white.withValues(alpha: 0.8),
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FluentTheme.of(context).accentColor.withValues(alpha: 0.2)
                            : states.isHovered
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        icon,
                        size: 15,
                        color: isSelected
                            ? FluentTheme.of(context).accentColor
                            : Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: FluentTheme.of(context).typography.body?.copyWith(
                          color: isSelected
                              ? FluentTheme.of(context).accentColor
                              : Colors.white.withValues(alpha: 0.9),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 13,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: FluentTheme.of(context).accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildWindowButtons(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: Colors.white.withValues(alpha: 0.8),
      iconMouseDown: Colors.white,
      iconMouseOver: Colors.white,
      normal: Colors.transparent,
      mouseOver: Colors.white.withValues(alpha: 0.1),
      mouseDown: Colors.white.withValues(alpha: 0.15),
    );

    final closeButtonColors = WindowButtonColors(
      iconNormal: Colors.white.withValues(alpha: 0.8),
      iconMouseDown: Colors.white,
      iconMouseOver: Colors.white,
      normal: Colors.transparent,
      mouseOver: const Color(0xFFE81123),
      mouseDown: const Color(0xFFC50F1F),
    );

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          MinimizeWindowButton(colors: buttonColors),
          MaximizeWindowButton(colors: buttonColors),
          CloseWindowButton(colors: closeButtonColors),
        ],
      ),
    );
  }

  Widget _buildStatsInfo() {
    return Consumer<IntegratedDownloadService>(
      builder: (context, service, _) {
        final downloading = service.tasks.where((t) => t.status == DownloadStatus.downloading).length;
        final completed = service.tasks.where((t) => t.status == DownloadStatus.completed).length;
        
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: FluentTheme.of(context).resources.cardStrokeColorDefault.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.download,
                size: 10,
                color: Colors.blue.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 3),
              Text(
                '$downloading',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 1,
                height: 10,
                color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
              ),
              const SizedBox(width: 6),
              Icon(
                FluentIcons.completed,
                size: 10,
                color: Colors.green.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 3),
              Text(
                '$completed',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddDownloadDialog(),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('关于'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(context, FluentIcons.app_icon_default, '软件名称', AppConstants.appName),
              const SizedBox(height: 12),
              _buildInfoRow(context, FluentIcons.build_queue, '版本', AppConstants.version),
              const SizedBox(height: 12),
              _buildInfoRow(context, FluentIcons.contact, '开发者', AppConstants.developer),
              const SizedBox(height: 12),
              _buildInfoRow(context, FluentIcons.processing, '下载核心', AppConstants.kernelName),
            ],
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: FluentTheme.of(context).accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value,
                style: FluentTheme.of(context).typography.body,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
