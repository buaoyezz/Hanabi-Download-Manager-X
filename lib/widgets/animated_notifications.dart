import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'dart:ui';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/notification_settings_service.dart';

/// 通知类型
enum NotificationType {
  success,
  warning,
  error,
  info,
  custom, // 自定义类型
}

/// 通知动作数据（用于点击跳转等）
class NotificationAction {
  final String? route; // 跳转路由
  final Map<String, dynamic>? params; // 跳转参数
  final String? actionId; // 动作标识（用于自定义处理）
  final dynamic data; // 附加数据

  const NotificationAction({
    this.route,
    this.params,
    this.actionId,
    this.data,
  });
}

/// 通知数据模型
class NotificationData {
  final String id;
  final String title;
  final String? message;
  final NotificationType type;
  final Duration duration;
  final DateTime createdAt;

  // 自定义属性
  final IconData? customIcon;
  final Color? customColor;
  final Color? customBackgroundColor;

  // 点击交互属性
  final VoidCallback? onTap; // 点击回调
  final NotificationAction? action; // 动作数据（用于跳转等）
  final bool dismissOnTap; // 点击后是否自动关闭

  NotificationData({
    required this.id,
    required this.title,
    this.message,
    required this.type,
    this.duration = const Duration(seconds: 4),
    DateTime? createdAt,
    this.customIcon,
    this.customColor,
    this.customBackgroundColor,
    this.onTap,
    this.action,
    this.dismissOnTap = true,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// 现代化通知卡片
class ModernNotificationCard extends StatefulWidget {
  final NotificationData data;
  final VoidCallback onDismiss;
  final double yOffset;

  const ModernNotificationCard({
    super.key,
    required this.data,
    required this.onDismiss,
    this.yOffset = 0,
  });

  @override
  State<ModernNotificationCard> createState() => _ModernNotificationCardState();
}

class _ModernNotificationCardState extends State<ModernNotificationCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _positionController;
  late AnimationController
      _progressController; // 使用 AnimationController 替代 Timer
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  double _currentYOffset = 0;
  bool _isExpanded = false;
  bool _isHovered = false;

  // 通知设置服务
  final _notificationSettings = NotificationSettingsService();

  @override
  void initState() {
    super.initState();

    // 滑入动画 - Fluent 2 使用更快速的入场动画
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 位置动画（用于堆叠移动）
    _positionController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // 进度条动画 - 使用 AnimationController 实现 vsync 同步
    _progressController = AnimationController(
      duration: widget.data.duration,
      vsync: this,
    );

    // Fluent 2 动画曲线：快速入场，优雅退出
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart, // Fluent 2 推荐的曲线
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic, // 更平滑的缩放
    ));

    _slideController.forward();
    _currentYOffset = widget.yOffset;

    // 启动进度条动画
    _progressController.addStatusListener(_onProgressComplete);
    _progressController.forward();
  }

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _dismiss();
    }
  }

  @override
  void didUpdateWidget(ModernNotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.yOffset != widget.yOffset) {
      _animateToPosition(widget.yOffset);
    }
  }

  void _animateToPosition(double newOffset) {
    final double oldOffset = _currentYOffset;
    _positionController.reset();
    _positionController.forward();

    _positionController.addListener(() {
      setState(() {
        _currentYOffset =
            oldOffset + (newOffset - oldOffset) * _positionController.value;
      });
    });
  }

  void _pauseProgress() {
    _progressController.stop();
  }

  void _resumeProgress() {
    if (!_isExpanded && _progressController.value < 1.0) {
      _progressController.forward();
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _pauseProgress();
    } else if (!_isHovered) {
      _resumeProgress();
    }
  }

  @override
  void dispose() {
    _progressController.removeStatusListener(_onProgressComplete);
    _progressController.dispose();
    _slideController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _slideController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  void _handleTap() {
    // 执行点击回调
    widget.data.onTap?.call();

    // 如果设置了点击后关闭，则关闭通知
    if (widget.data.dismissOnTap &&
        (widget.data.onTap != null || widget.data.action != null)) {
      _dismiss();
    }
  }

  Color get _accentColor {
    if (widget.data.type == NotificationType.custom &&
        widget.data.customColor != null) {
      return widget.data.customColor!;
    }

    final isDark = fluent.FluentTheme.of(context).brightness == Brightness.dark;

    switch (widget.data.type) {
      case NotificationType.success:
        return _notificationSettings.getSuccessColor(isDark);
      case NotificationType.warning:
        return _notificationSettings.getWarningColor(isDark);
      case NotificationType.error:
        return _notificationSettings.getErrorColor(isDark);
      case NotificationType.info:
        return _notificationSettings.getInfoColor(isDark);
      case NotificationType.custom:
        return _notificationSettings.getInfoColor(isDark);
    }
  }

  Color get _cardColor {
    final isDark = fluent.FluentTheme.of(context).brightness == Brightness.dark;
    return _notificationSettings.getCardColor(isDark);
  }

  Color get _textPrimaryColor {
    final isDark = fluent.FluentTheme.of(context).brightness == Brightness.dark;
    return _notificationSettings.getTextPrimaryColor(isDark);
  }

  Color get _textSecondaryColor {
    final isDark = fluent.FluentTheme.of(context).brightness == Brightness.dark;
    return _notificationSettings.getTextSecondaryColor(isDark);
  }

  IconData get _icon {
    if (widget.data.type == NotificationType.custom &&
        widget.data.customIcon != null) {
      return widget.data.customIcon!;
    }

    switch (widget.data.type) {
      case NotificationType.success:
        return fluent.FluentIcons.completed_solid;
      case NotificationType.warning:
        return fluent.FluentIcons.warning;
      case NotificationType.error:
        return fluent.FluentIcons.status_error_full;
      case NotificationType.info:
        return fluent.FluentIcons.info;
      case NotificationType.custom:
        return fluent.FluentIcons.message;
    }
  }

  bool _doesTextOverflow(
    String text,
    TextStyle? style,
    double maxWidth, {
    required int maxLines,
  }) {
    if (text.isEmpty || maxWidth <= 0) {
      return false;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style ?? DefaultTextStyle.of(context).style,
      ),
      maxLines: maxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);

    return textPainter.didExceedMaxLines;
  }

  fluent.IconButton _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return fluent.IconButton(
      icon: Icon(
        icon,
        size: 10,
        color: AppTheme.textTertiary,
      ),
      onPressed: onPressed,
      style: fluent.ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.all(4),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.isPressed) {
            return AppTheme.bgLayer2.withValues(alpha: 0.6);
          }
          if (states.isHovered) {
            return AppTheme.bgLayer2.withValues(alpha: 0.3);
          }
          return Colors.transparent;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blurSigma = _notificationSettings.blurSigma;
    final enableBlur = _notificationSettings.enableBlur;

    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _currentYOffset),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: widget.data.onTap != null || widget.data.action != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) {
            _isHovered = true;
            _pauseProgress();
          },
          onExit: (_) {
            _isHovered = false;
            _resumeProgress();
          },
          child: Container(
            width: 280,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: enableBlur
                  ? BackdropFilter(
                      filter: ImageFilter.blur(
                          sigmaX: blurSigma, sigmaY: blurSigma),
                      child: _buildCardBody(),
                    )
                  : _buildCardBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardBody() {
    final titleStyle =
        fluent.FluentTheme.of(context).typography.bodyStrong?.copyWith(
              color: _textPrimaryColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
              letterSpacing: -0.2,
            );
    final messageStyle =
        fluent.FluentTheme.of(context).typography.body?.copyWith(
              color: _textSecondaryColor,
              fontSize: 11,
              height: 1.3,
            );

    return Container(
      decoration: BoxDecoration(
        color: _cardColor.withValues(
            alpha: _notificationSettings.enableBlur ? 0.92 : 1.0),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double textMaxWidth = constraints.maxWidth - 24 - 8 - 6 - 28;
                if (textMaxWidth < 80) {
                  textMaxWidth = 80;
                }

                final titleOverflow = _doesTextOverflow(
                  widget.data.title,
                  titleStyle,
                  textMaxWidth,
                  maxLines: 1,
                );
                final messageOverflow = widget.data.message != null &&
                    _doesTextOverflow(
                      widget.data.message!,
                      messageStyle,
                      textMaxWidth,
                      maxLines: 1,
                    );
                final canExpand = titleOverflow || messageOverflow;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        _icon,
                        size: 14,
                        color: _accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.data.title,
                            style: titleStyle,
                            maxLines: _isExpanded ? null : 1,
                            overflow: _isExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                          ),
                          if (widget.data.message != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.data.message!,
                              style: messageStyle,
                              maxLines: _isExpanded ? null : 1,
                              overflow: _isExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 28,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(
                            icon: fluent.FluentIcons.chrome_close,
                            onPressed: _dismiss,
                          ),
                          if (canExpand) ...[
                            const SizedBox(height: 2),
                            _buildActionButton(
                              icon: _isExpanded
                                  ? fluent.FluentIcons.chevron_up
                                  : fluent.FluentIcons.chevron_down,
                              onPressed: _toggleExpanded,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // 进度条 - 使用 AnimatedBuilder 监听进度动画
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return SizedBox(
                height: 2,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0 - _progressController.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 现代化通知管理器
class NotificationManager extends StatefulWidget {
  final Widget child;

  const NotificationManager({
    super.key,
    required this.child,
  });

  static NotificationManagerState? of(BuildContext context) {
    return context.findAncestorStateOfType<NotificationManagerState>();
  }

  @override
  State<NotificationManager> createState() => NotificationManagerState();
}

class NotificationManagerState extends State<NotificationManager> {
  final List<NotificationData> _notifications = [];
  final int _maxNotifications = 6; // 紧凑设计可以显示更多
  final _notificationSettings = NotificationSettingsService();

  void showNotification({
    required String title,
    String? message,
    required NotificationType type,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
    NotificationAction? action,
    bool dismissOnTap = true,
  }) {
    // 检查是否启用通知
    if (!_notificationSettings.enabled) {
      return;
    }

    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      duration: duration,
      onTap: onTap,
      action: action,
      dismissOnTap: dismissOnTap,
    );

    setState(() {
      _notifications.insert(0, notification);

      // 限制通知数量，移除最旧的
      if (_notifications.length > _maxNotifications) {
        _notifications.removeLast();
      }
    });
  }

  void _removeNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  void showSuccess(
    String title, {
    String? message,
    VoidCallback? onTap,
    NotificationAction? action,
    bool dismissOnTap = true,
  }) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.success,
      onTap: onTap,
      action: action,
      dismissOnTap: dismissOnTap,
    );
  }

  void showWarning(
    String title, {
    String? message,
    VoidCallback? onTap,
    NotificationAction? action,
    bool dismissOnTap = true,
  }) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.warning,
      onTap: onTap,
      action: action,
      dismissOnTap: dismissOnTap,
    );
  }

  void showError(
    String title, {
    String? message,
    VoidCallback? onTap,
    NotificationAction? action,
    bool dismissOnTap = true,
  }) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.error,
      onTap: onTap,
      action: action,
      dismissOnTap: dismissOnTap,
    );
  }

  void showInfo(
    String title, {
    String? message,
    VoidCallback? onTap,
    NotificationAction? action,
    bool dismissOnTap = true,
  }) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.info,
      onTap: onTap,
      action: action,
      dismissOnTap: dismissOnTap,
    );
  }

  void showCustom({
    required String title,
    String? message,
    required IconData icon,
    required Color color,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
    NotificationAction? action,
    bool dismissOnTap = true,
  }) {
    // 检查是否启用通知
    if (!_notificationSettings.enabled) {
      return;
    }

    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: NotificationType.custom,
      duration: duration,
      customIcon: icon,
      customColor: color,
      customBackgroundColor: backgroundColor ?? color.withValues(alpha: 0.12),
      onTap: onTap,
      action: action,
      dismissOnTap: dismissOnTap,
    );

    setState(() {
      _notifications.insert(0, notification);

      if (_notifications.length > _maxNotifications) {
        _notifications.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_notificationSettings.enabled)
          Positioned(
            top: _notificationSettings.position == NotificationPosition.topRight
                ? 48
                : null, // titlebar 下方
            bottom: _notificationSettings.position ==
                    NotificationPosition.bottomRight
                ? 16
                : null,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_notifications.length, (index) {
                final notification = _notifications[index];

                return ModernNotificationCard(
                  key: ValueKey(notification.id),
                  data: notification,
                  yOffset: 0,
                  onDismiss: () => _removeNotification(notification.id),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// 浮动消息组件（轻量级，用于简单提示）
class FloatingMessage extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Duration duration;

  const FloatingMessage({
    super.key,
    required this.message,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<FloatingMessage> createState() => _FloatingMessageState();
}

class _FloatingMessageState extends State<FloatingMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.backgroundColor?.withValues(alpha: 0.95) ??
                      AppTheme.cardBackground(
                        darkAlpha: 0.88,
                        lightAlpha: 0.95,
                      ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.borderSubtle.withValues(alpha: 0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(
                        widget.icon,
                        size: 18,
                        color: widget.textColor ?? AppTheme.textPrimary,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      widget.message,
                      style: fluent.FluentTheme.of(context)
                          .typography
                          .body
                          ?.copyWith(
                            color: widget.textColor ?? AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
