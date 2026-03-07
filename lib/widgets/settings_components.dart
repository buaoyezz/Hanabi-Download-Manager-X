import 'package:fluent_ui/fluent_ui.dart';
import '../theme/app_theme.dart';
import '../utils/fluent_icons.dart' as CustomIcons;
import '../l10n/app_localizations.dart';

/// 设置页面区块卡片 - Fluent Design 风格
class SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderSubtle.withValues(alpha: 0.6)),
        // 优化：移除 BoxShadow，静态卡片不需要阴影
        // BoxShadow 会触发 saveLayer，增加 GPU 合成层开销
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 设置项组件 - Fluent Design 风格
class SettingsItem extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget trailing;
  final bool stackOnNarrow;
  final double narrowBreakpoint;
  final AlignmentGeometry stackedTrailingAlignment;

  const SettingsItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.stackOnNarrow = false,
    this.narrowBreakpoint = 760,
    this.stackedTrailingAlignment = Alignment.centerLeft,
  });

  @override
  State<SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<SettingsItem> {
  bool _isHovered = false;

  Widget _buildTitleContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FluentTheme.of(context).typography.body?.copyWith(
                fontWeight: FontWeight.w400,
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
          ),
        ],
      ],
    );
  }

  void _setHovered(bool value) {
    if (_isHovered == value) {
      return;
    }
    setState(() => _isHovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusSm);
    final background = _isHovered
        ? AppTheme.bgLayer2.withValues(alpha: 0.70)
        : AppTheme.bgLayer2.withValues(alpha: 0.52);
    final borderColor = _isHovered
        ? AppTheme.borderStrong.withValues(alpha: 0.65)
        : AppTheme.borderSubtle.withValues(alpha: 0.45);

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = widget.stackOnNarrow &&
                  constraints.maxWidth < widget.narrowBreakpoint;

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleContent(context),
                    const SizedBox(height: 10),
                    Align(
                      alignment: widget.stackedTrailingAlignment,
                      child: widget.trailing,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildTitleContent(context),
                  ),
                  const SizedBox(width: 12),
                  widget.trailing,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 状态指示器组件
class StatusIndicator extends StatelessWidget {
  final String title;
  final bool isOnline;
  final IconData icon;

  const StatusIndicator({
    super.key,
    required this.title,
    required this.isOnline,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final color = isOnline ? AppTheme.statusSuccess : AppTheme.statusError;

    final baseColor = Color.lerp(AppTheme.surfaceCard, color, 0.10) ??
        color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? t.statusOnline : t.statusOffline,
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 危险操作区域
class DangerZone extends StatelessWidget {
  final List<Widget> children;

  const DangerZone({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.statusError.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  CustomIcons.FluentIcons.warning,
                  size: 14,
                  color: AppTheme.statusError,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.settingsDangerZoneTitle,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.statusError,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// 页面头部组件
class SettingsPageHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const SettingsPageHeader({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PageHeader(
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
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
            child: Icon(icon, size: 18, color: AppTheme.accentLight),
          ),
          const SizedBox(width: 14),
          Text(title),
        ],
      ),
    );
  }
}
