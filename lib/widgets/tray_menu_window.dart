import 'package:fluent_ui/fluent_ui.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../services/kernel/kernel_manager.dart';
import 'package:provider/provider.dart';
import '../utils/fluent_icons.dart' as CustomIcons;

class TrayMenuWindow extends StatefulWidget {
  final VoidCallback onShowWindow;
  final VoidCallback onExit;

  const TrayMenuWindow({
    super.key,
    required this.onShowWindow,
    required this.onExit,
  });

  @override
  State<TrayMenuWindow> createState() => _TrayMenuWindowState();
}

class _TrayMenuWindowState extends State<TrayMenuWindow> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final kernelManager = context.watch<KernelManager>();
    final t = AppLocalizations.of(context)!;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.bgSolid.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.borderDefault.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部
            _buildHeader(context),

            // 分隔线
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppTheme.borderSubtle.withValues(alpha: 0.3),
            ),

            // 菜单项
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMenuItem(
                    index: 0,
                    icon: CustomIcons.FluentIcons.chrome_restore,
                    title: t.trayMenuShowWindowTitle,
                    subtitle: t.trayMenuShowWindowSubtitle,
                    onTap: () {
                      widget.onShowWindow();
                      appWindow.hide(); // 隐藏托盘菜单窗口
                    },
                  ),
                  _buildMenuItem(
                    index: 1,
                    icon: CustomIcons.FluentIcons.status_circle_checkmark,
                    title: t.trayMenuKernelTitle,
                    subtitle: kernelManager.isRunning
                        ? t.trayMenuKernelSubtitleRunning
                        : t.trayMenuKernelSubtitleStopped,
                    trailing: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: kernelManager.isRunning
                            ? AppTheme.statusSuccess
                            : AppTheme.textTertiary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  // 分隔线
                  Container(
                    height: 1,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    color: AppTheme.borderSubtle.withValues(alpha: 0.2),
                  ),

                  _buildMenuItem(
                    index: 2,
                    icon: CustomIcons.FluentIcons.chrome_close,
                    title: t.trayMenuExitTitle,
                    subtitle: t.trayMenuExitSubtitle,
                    iconColor: AppTheme.statusError,
                    onTap: () {
                      widget.onExit();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accentPrimary.withValues(alpha: 0.2),
                  AppTheme.accentPrimary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.accentPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              CustomIcons.FluentIcons.download,
              size: 20,
              color: AppTheme.accentLight,
            ),
          ),
          const SizedBox(width: 12),
          // 应用信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.appTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'v${AppConstants.version}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isHovered
                ? AppTheme.bgLayer2.withValues(alpha: 0.8)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            children: [
              // 图标
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isHovered
                      ? (iconColor ?? AppTheme.accentPrimary)
                          .withValues(alpha: 0.15)
                      : (iconColor ?? AppTheme.accentPrimary)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: iconColor ?? AppTheme.accentLight,
                ),
              ),
              const SizedBox(width: 12),
              // 文本
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isHovered
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 尾部
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ] else if (onTap != null)
                Icon(
                  CustomIcons.FluentIcons.chevron_right,
                  size: 12,
                  color: isHovered
                      ? AppTheme.textSecondary
                      : AppTheme.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
