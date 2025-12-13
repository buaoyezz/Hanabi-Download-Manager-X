import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';

/// 动画通知类型
enum NotificationType {
  success,
  warning,
  error,
  info,
}

/// 动画通知组件
class AnimatedNotification extends StatefulWidget {
  final String title;
  final String? message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback? onDismiss;
  final bool showProgress;

  const AnimatedNotification({
    super.key,
    required this.title,
    this.message,
    required this.type,
    this.duration = const Duration(seconds: 4),
    this.onDismiss,
    this.showProgress = true,
  });

  @override
  State<AnimatedNotification> createState() => _AnimatedNotificationState();
}

class _AnimatedNotificationState extends State<AnimatedNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _progressAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.linear,
    ));

    _slideController.forward();
    
    if (widget.showProgress) {
      _progressController.forward();
      _progressController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _slideController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  Color get _backgroundColor {
    switch (widget.type) {
      case NotificationType.success:
        return AppTheme.statusSuccess.withValues(alpha: 0.1);
      case NotificationType.warning:
        return AppTheme.statusWarning.withValues(alpha: 0.1);
      case NotificationType.error:
        return AppTheme.statusError.withValues(alpha: 0.1);
      case NotificationType.info:
        return AppTheme.accentPrimary.withValues(alpha: 0.1);
    }
  }

  Color get _borderColor {
    switch (widget.type) {
      case NotificationType.success:
        return AppTheme.statusSuccess;
      case NotificationType.warning:
        return AppTheme.statusWarning;
      case NotificationType.error:
        return AppTheme.statusError;
      case NotificationType.info:
        return AppTheme.accentPrimary;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case NotificationType.success:
        return fluent.FluentIcons.completed;
      case NotificationType.warning:
        return fluent.FluentIcons.warning;
      case NotificationType.error:
        return fluent.FluentIcons.error_badge;
      case NotificationType.info:
        return fluent.FluentIcons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: _borderColor.withValues(alpha: 0.3)),
          boxShadow: AppTheme.shadowMd,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _icon,
                    size: 20,
                    color: _borderColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: fluent.FluentTheme.of(context)
                              .typography.bodyStrong?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (widget.message != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.message!,
                            style: fluent.FluentTheme.of(context)
                                .typography.body?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  fluent.IconButton(
                    icon: const Icon(fluent.FluentIcons.chrome_close, size: 12),
                    onPressed: _dismiss,
                  ),
                ],
              ),
            ),
            if (widget.showProgress)
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Container(
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(AppTheme.radiusMd),
                        bottomRight: Radius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: LinearProgressIndicator(
                      value: _progressAnimation.value,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(_borderColor),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 通知管理器
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
  final List<Widget> _notifications = [];

  void showNotification({
    required String title,
    String? message,
    required NotificationType type,
    Duration duration = const Duration(seconds: 4),
  }) {
    final notification = AnimatedNotification(
      title: title,
      message: message,
      type: type,
      duration: duration,
      onDismiss: () {
        setState(() {
          _notifications.removeAt(0);
        });
      },
    );

    setState(() {
      _notifications.add(notification);
    });

    // 限制通知数量
    if (_notifications.length > 5) {
      setState(() {
        _notifications.removeAt(0);
      });
    }
  }

  void showSuccess(String title, {String? message}) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.success,
    );
  }

  void showWarning(String title, {String? message}) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.warning,
    );
  }

  void showError(String title, {String? message}) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.error,
    );
  }

  void showInfo(String title, {String? message}) {
    showNotification(
      title: title,
      message: message,
      type: NotificationType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 20,
          right: 20,
          child: SizedBox(
            width: 350,
            child: Column(
              children: _notifications,
            ),
          ),
        ),
      ],
    );
  }
}

/// 浮动消息组件
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
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
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.shadowMd,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.textColor ?? AppTheme.textPrimary,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.message,
                style: fluent.FluentTheme.of(context).typography.body?.copyWith(
                  color: widget.textColor ?? AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}