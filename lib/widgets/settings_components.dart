import 'package:fluent_ui/fluent_ui.dart';
import '../theme/app_theme.dart';
import '../utils/fluent_icons.dart' as CustomIcons;
import '../l10n/app_localizations.dart';

class RegisteredSetting {
  final String id;
  final String targetId;
  final String title;
  final String subtitle;
  final int tabIndex;

  RegisteredSetting({
    required this.id,
    required this.targetId,
    required this.title,
    required this.subtitle,
    required this.tabIndex,
  });
}

class SettingsSearchRegistry {
  static final Map<String, GlobalKey> keys = {};
  static final Map<String, RegisteredSetting> items = {};

  static GlobalKey getKey(String id) {
    return keys.putIfAbsent(id, () => GlobalKey());
  }

  static void register({
    required String id,
    String? targetId,
    required String title,
    String subtitle = '',
    required int tabIndex,
  }) {
    items[id] = RegisteredSetting(
      id: id,
      targetId: targetId ?? id,
      title: title,
      subtitle: subtitle,
      tabIndex: tabIndex,
    );
  }

  static List<RegisteredSetting> getAllSettings() {
    return items.values.toList();
  }
}

class SettingsTabScope extends InheritedWidget {
  final int tabIndex;
  final bool isRegistrationPhase;

  const SettingsTabScope({
    super.key,
    required this.tabIndex,
    this.isRegistrationPhase = false,
    required super.child,
  });

  static SettingsTabScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsTabScope>();
  }

  @override
  bool updateShouldNotify(SettingsTabScope oldWidget) {
    return tabIndex != oldWidget.tabIndex;
  }
}

/// 设置页面区块卡片
class SettingsSection extends StatelessWidget {
  final String title;
  final String? searchId;
  final IconData? icon;
  final Widget Function(BuildContext, Color)? iconBuilder;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const SettingsSection({
    super.key,
    this.searchId,
    required this.title,
    this.icon,
    this.iconBuilder,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  }) : assert(icon != null || iconBuilder != null);

  @override
  Widget build(BuildContext context) {
    final tabScope = SettingsTabScope.of(context);
    final isReg = tabScope?.isRegistrationPhase ?? false;

    if (searchId != null) {
      if (tabScope != null) {
        SettingsSearchRegistry.register(
          id: searchId!,
          targetId: 'section:$searchId',
          title: title,
          tabIndex: tabScope.tabIndex,
        );
      }
    }

    final searchKey = (searchId != null && !isReg)
        ? SettingsSearchRegistry.getKey('section:$searchId')
        : null;

    final isDark = AppTheme.isDarkContext(context);
    return Container(
      key: searchKey,
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(
                      alpha: isDark ? 0.10 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: iconBuilder != null
                      ? iconBuilder!(
                          context,
                          isDark
                              ? AppTheme.accentLight
                              : AppTheme.accentPrimary,
                        )
                      : Icon(
                          icon,
                          size: 13,
                          color: isDark
                              ? AppTheme.accentLight
                              : AppTheme.accentPrimary,
                        ),
                ),
                const SizedBox(width: 9),
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
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 设置项组件
class SettingsItem extends StatefulWidget {
  final String title;
  final String? searchId;
  final String? subtitle;
  final Widget trailing;
  final bool stackOnNarrow;
  final double narrowBreakpoint;
  final AlignmentGeometry stackedTrailingAlignment;
  final bool showBetaBadge;

  const SettingsItem({
    super.key,
    this.searchId,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.stackOnNarrow = false,
    this.narrowBreakpoint = 760,
    this.stackedTrailingAlignment = Alignment.centerLeft,
    this.showBetaBadge = false,
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
              ),
            ),
            if (widget.showBetaBadge) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Beta',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.accentPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                ),
              ),
            ],
          ],
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
                  height: 1.25,
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
    final tabScope = SettingsTabScope.of(context);
    final isReg = tabScope?.isRegistrationPhase ?? false;

    if (widget.searchId != null) {
      if (tabScope != null) {
        SettingsSearchRegistry.register(
          id: widget.searchId!,
          targetId: 'item:${widget.searchId!}',
          title: widget.title,
          subtitle: widget.subtitle ?? '',
          tabIndex: tabScope.tabIndex,
        );
      }
    }

    final searchKey = (widget.searchId != null && !isReg)
        ? SettingsSearchRegistry.getKey('item:${widget.searchId!}')
        : null;

    final radius = BorderRadius.circular(AppTheme.radiusSm);
    final background =
        _isHovered ? AppTheme.surfaceCardHover : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        key: searchKey,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
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

/// 危险操作区域
class DangerZone extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const DangerZone({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final isDark = AppTheme.isDarkContext(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.statusError.withValues(
                      alpha: isDark ? 0.10 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    CustomIcons.FluentIcons.warning,
                    size: 13,
                    color: AppTheme.statusError,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  t.settingsDangerZoneTitle,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// 页面头部组件
class SettingsPageHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget Function(BuildContext, Color)? iconBuilder;
  final Widget? commandBar;

  const SettingsPageHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconBuilder,
    this.commandBar,
  }) : assert(icon != null || iconBuilder != null);

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkContext(context);
    return PageHeader(
      commandBar: commandBar,
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
                  AppTheme.accentPrimary.withValues(alpha: isDark ? 0.2 : 0.14),
                  AppTheme.accentPrimary.withValues(alpha: isDark ? 0.1 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.accentPrimary
                    .withValues(alpha: isDark ? 0.3 : 0.18),
              ),
            ),
            child: iconBuilder != null
                ? iconBuilder!(context,
                    isDark ? AppTheme.accentLight : AppTheme.accentPrimary)
                : Icon(
                    icon,
                    size: 18,
                    color:
                        isDark ? AppTheme.accentLight : AppTheme.accentPrimary,
                  ),
          ),
          const SizedBox(width: 14),
          Text(title),
        ],
      ),
    );
  }
}
