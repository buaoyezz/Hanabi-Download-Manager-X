import 'package:fluent_ui/fluent_ui.dart';

/// Safer replacement for [CommandBarButton].
///
/// The upstream implementation resolves button state colors by repeatedly
/// calling `FluentTheme.of(context)` inside a state resolver closure. During
/// route teardown this can hit a deactivated context assertion.
///
/// This version captures theme once during build and only uses captured values
/// in resolver closures.
class SafeCommandBarButton extends CommandBarItem {
  final Widget? icon;
  final Widget? label;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? tooltip;
  final bool closeAfterClick;

  const SafeCommandBarButton({
    super.key,
    this.icon,
    this.label,
    this.subtitle,
    this.trailing,
    required this.onPressed,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.tooltip,
    this.closeAfterClick = true,
  });

  @override
  Widget build(BuildContext context, CommandBarItemDisplayMode displayMode) {
    assert(debugCheckHasFluentTheme(context));

    switch (displayMode) {
      case CommandBarItemDisplayMode.inPrimary:
      case CommandBarItemDisplayMode.inPrimaryCompact:
        final showIcon = icon != null;
        final showLabel = label != null &&
            (displayMode == CommandBarItemDisplayMode.inPrimary || !showIcon);
        final theme = FluentTheme.of(context);

        final button = IconButton(
          key: key,
          onPressed: onPressed,
          onLongPress: onLongPress,
          focusNode: focusNode,
          autofocus: autofocus,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              return ButtonThemeData.uncheckedInputColor(
                theme,
                states,
                transparentWhenNone: true,
              );
            }),
          ),
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon)
                IconTheme.merge(
                  data: const IconThemeData(size: 16.0),
                  child: icon!,
                ),
              if (showIcon && showLabel) const SizedBox(width: 10),
              if (showLabel) label!,
            ],
          ),
        );

        if (tooltip != null) {
          return Tooltip(message: tooltip!, child: button);
        }
        return button;

      case CommandBarItemDisplayMode.inSecondary:
        return MenuFlyoutItem(
          key: key,
          onPressed: onPressed,
          onLongPress: onLongPress,
          leading: icon,
          text: label ?? const SizedBox.shrink(),
          trailing: () {
            if (trailing != null) return trailing!;
            if (tooltip != null) return Text(tooltip!);
            return null;
          }(),
          closeAfterClick: closeAfterClick,
        ).build(context);
    }
  }
}
