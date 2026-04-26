import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';

/// 高性能动画配置
class AnimationConfig {
  // 标准动画时长
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration emphasis = Duration(milliseconds: 500);

  // 优化的动画曲线 - 更加丝滑
  static const Curve smoothOut = Curves.easeOutCubic;
  static const Curve smoothIn = Curves.easeInCubic;
  static const Curve smoothInOut = Curves.easeInOutCubic;
  static const Curve bounce = Curves.elasticOut;
  static const Curve spring = _SpringCurve();
  static const Curve decelerate = Curves.decelerate;

  // 微交互曲线
  static const Curve microInteraction = Curves.easeOutQuart;
}

/// 自定义弹簧曲线 - 更自然的物理效果
class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    // 阻尼弹簧公式
    const damping = 0.7;
    const frequency = 3.5;
    return 1 -
        math.pow(math.e, -damping * t * 10) * math.cos(frequency * math.pi * t);
  }
}

/// 高性能淡入淡出动画组件
class SmoothFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double startOpacity;

  const SmoothFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.startOpacity = 0.0,
  });

  @override
  State<SmoothFadeIn> createState() => _SmoothFadeInState();
}

class _SmoothFadeInState extends State<SmoothFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: Tween<double>(
          begin: widget.startOpacity,
          end: 1.0,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}

/// 高性能滑入动画组件
class SmoothSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Offset beginOffset;
  final bool fadeIn;

  const SmoothSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.beginOffset = const Offset(0, 0.15),
    this.fadeIn = true,
  });

  /// 从右侧滑入
  const SmoothSlideIn.fromRight({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.fadeIn = true,
  }) : beginOffset = const Offset(0.2, 0);

  /// 从左侧滑入
  const SmoothSlideIn.fromLeft({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.fadeIn = true,
  }) : beginOffset = const Offset(-0.2, 0);

  /// 从底部滑入
  const SmoothSlideIn.fromBottom({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.fadeIn = true,
  }) : beginOffset = const Offset(0, 0.15);

  @override
  State<SmoothSlideIn> createState() => _SmoothSlideInState();
}

class _SmoothSlideInState extends State<SmoothSlideIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(curvedAnimation);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.fadeIn
            ? FadeTransition(opacity: _fadeAnimation, child: widget.child)
            : widget.child,
      ),
    );
  }
}

/// 高性能缩放动画组件
class SmoothScale extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final double beginScale;
  final bool fadeIn;

  const SmoothScale({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutBack,
    this.beginScale = 0.8,
    this.fadeIn = true,
  });

  /// 弹性缩放效果
  const SmoothScale.bounce({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = Duration.zero,
    this.fadeIn = true,
  })  : curve = Curves.elasticOut,
        beginScale = 0.5;

  @override
  State<SmoothScale> createState() => _SmoothScaleState();
}

class _SmoothScaleState extends State<SmoothScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.fadeIn
            ? FadeTransition(opacity: _fadeAnimation, child: widget.child)
            : widget.child,
      ),
    );
  }
}

/// 高性能悬停效果组件
class SmoothHover extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context, bool isHovered, double hoverValue)
      builder;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SmoothHover({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 150),
    this.curve = Curves.easeOutCubic,
    this.onTap,
    this.onLongPress,
  }) : child = const SizedBox.shrink();

  @override
  State<SmoothHover> createState() => _SmoothHoverState();
}

class _SmoothHoverState extends State<SmoothHover>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent _) {
    setState(() => _isHovered = true);
    _controller.forward();
  }

  void _onExit(PointerEvent _) {
    setState(() => _isHovered = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final curvedValue = widget.curve.transform(_controller.value);
              return widget.builder(context, _isHovered, curvedValue);
            },
          ),
        ),
      ),
    );
  }
}

/// 高性能按压效果组件
class SmoothPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressScale;
  final Duration duration;

  const SmoothPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressScale = 0.97,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<SmoothPressable> createState() => _SmoothPressableState();
}

class _SmoothPressableState extends State<SmoothPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onLongPress: widget.onLongPress,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 高性能列表项动画组件
class SmoothListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration staggerDelay;
  final Duration duration;
  final Curve curve;

  const SmoothListItem({
    super.key,
    required this.child,
    required this.index,
    this.staggerDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SmoothListItem> createState() => _SmoothListItemState();
}

class _SmoothListItemState extends State<SmoothListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // 限制最大延迟，避免列表过长时动画太慢
    final maxIndex = math.min(widget.index, 8);
    final delay = widget.staggerDelay * maxIndex;

    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 高性能进度条动画组件
class SmoothProgressBar extends StatefulWidget {
  final double progress;
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;
  final Color? glowColor;
  final BorderRadius? borderRadius;
  final bool showGlow;
  final Duration duration;

  const SmoothProgressBar({
    super.key,
    required this.progress,
    this.height = 6.0,
    this.backgroundColor,
    this.progressColor,
    this.glowColor,
    this.borderRadius,
    this.showGlow = true,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<SmoothProgressBar> createState() => _SmoothProgressBarState();
}

class _SmoothProgressBarState extends State<SmoothProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _updateAnimation();
    _controller.forward();
  }

  void _updateAnimation() {
    _progressAnimation = Tween<double>(
      begin: _previousProgress,
      end: widget.progress.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(SmoothProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _previousProgress = _progressAnimation.value;
      _updateAnimation();
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppTheme.bgLayer1;
    final progressColor = widget.progressColor ?? AppTheme.accentPrimary;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(widget.height / 2);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, _) {
          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: radius,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  // 进度条
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            progressColor,
                            progressColor.withValues(alpha: 0.8),
                          ],
                        ),
                        boxShadow:
                            widget.showGlow && _progressAnimation.value > 0.01
                                ? [
                                    BoxShadow(
                                      color: (widget.glowColor ?? progressColor)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 0),
                                    ),
                                  ]
                                : null,
                      ),
                    ),
                  ),
                  // 光泽效果
                  if (_progressAnimation.value > 0.01)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progressAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 高性能数字动画组件
class SmoothCounter extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const SmoothCounter({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SmoothCounter> createState() => _SmoothCounterState();
}

class _SmoothCounterState extends State<SmoothCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _updateAnimation();
    _controller.forward();
  }

  void _updateAnimation() {
    _animation = Tween<double>(
      begin: _previousValue,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void didUpdateWidget(SmoothCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = _animation.value;
      _updateAnimation();
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Text(
            widget.formatter(_animation.value),
            style: widget.style,
          );
        },
      ),
    );
  }
}

/// 高性能卡片组件 - 带悬停和按压效果
class SmoothCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? hoverColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool enableHover;
  final bool enablePress;
  final bool enableGlow;

  const SmoothCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.hoverColor,
    this.borderColor,
    this.hoverBorderColor,
    this.borderRadius = 8.0,
    this.onTap,
    this.enableHover = true,
    this.enablePress = true,
    this.enableGlow = false,
  });

  @override
  State<SmoothCard> createState() => _SmoothCardState();
}

class _SmoothCardState extends State<SmoothCard> with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent _) {
    if (widget.enableHover) _hoverController.forward();
  }

  void _onExit(PointerEvent _) {
    if (widget.enableHover) _hoverController.reverse();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.enablePress) _pressController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.enablePress) _pressController.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    if (widget.enablePress) _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ??
        AppTheme.cardBackground(darkAlpha: 0.78, lightAlpha: 0.85);
    final hoverColor = widget.hoverColor ??
        AppTheme.cardHoverBackground(darkAlpha: 0.88, lightAlpha: 0.95);
    final borderColor = widget.borderColor ?? AppTheme.borderSubtle;
    final hoverBorderColor = widget.hoverBorderColor ??
        AppTheme.accentPrimary.withValues(alpha: 0.4);

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        child: GestureDetector(
          onTapDown: widget.onTap != null ? _onTapDown : null,
          onTapUp: widget.onTap != null ? _onTapUp : null,
          onTapCancel: widget.onTap != null ? _onTapCancel : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([_hoverController, _pressController]),
            builder: (context, child) {
              final hoverValue =
                  Curves.easeOutCubic.transform(_hoverController.value);
              final pressValue = _pressController.value;
              final scale = 1.0 - (pressValue * 0.02);

              return Transform.scale(
                scale: scale,
                child: Container(
                  margin: widget.margin,
                  decoration: BoxDecoration(
                    color: Color.lerp(bgColor, hoverColor, hoverValue),
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(
                      color: Color.lerp(
                          borderColor, hoverBorderColor, hoverValue)!,
                      width: 1.0 + (hoverValue * 0.5),
                    ),
                    boxShadow: widget.enableGlow && hoverValue > 0.01
                        ? [
                            BoxShadow(
                              color: AppTheme.accentPrimary
                                  .withValues(alpha: 0.15 * hoverValue),
                              blurRadius: 12 * hoverValue,
                              offset: Offset(0, 4 * hoverValue),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: Container(
                      padding: widget.padding,
                      child: widget.child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 高性能页面切换动画
class SmoothPageTransition extends StatefulWidget {
  final Widget child;
  final String pageKey;
  final Duration duration;
  final Curve curve;
  final PageTransitionType type;

  const SmoothPageTransition({
    super.key,
    required this.child,
    required this.pageKey,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutCubic,
    this.type = PageTransitionType.fadeSlide,
  });

  @override
  State<SmoothPageTransition> createState() => _SmoothPageTransitionState();
}

enum PageTransitionType {
  fade,
  slide,
  fadeSlide,
  scale,
}

class _SmoothPageTransitionState extends State<SmoothPageTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _setupAnimations();
    _controller.forward();
  }

  void _setupAnimations() {
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(curved);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(curved);
  }

  @override
  void didUpdateWidget(SmoothPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          Widget child = widget.child;

          switch (widget.type) {
            case PageTransitionType.fade:
              child = Opacity(opacity: _fadeAnimation.value, child: child);
              break;
            case PageTransitionType.slide:
              child = SlideTransition(position: _slideAnimation, child: child);
              break;
            case PageTransitionType.fadeSlide:
              child = SlideTransition(
                position: _slideAnimation,
                child: Opacity(opacity: _fadeAnimation.value, child: child),
              );
              break;
            case PageTransitionType.scale:
              child = Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(opacity: _fadeAnimation.value, child: child),
              );
              break;
          }

          return child;
        },
      ),
    );
  }
}

/// 高性能脉冲动画组件
class SmoothPulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final bool enabled;

  const SmoothPulse({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 1.0,
    this.maxScale = 1.05,
    this.enabled = true,
  });

  @override
  State<SmoothPulse> createState() => _SmoothPulseState();
}

class _SmoothPulseState extends State<SmoothPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.enabled) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SmoothPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return RepaintBoundary(
      child: ScaleTransition(
        scale: _animation,
        child: widget.child,
      ),
    );
  }
}

/// 高性能闪烁动画组件
class SmoothShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Duration duration;

  const SmoothShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<SmoothShimmer> createState() => _SmoothShimmerState();
}

class _SmoothShimmerState extends State<SmoothShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [
                  (_animation.value - 0.3).clamp(0.0, 1.0),
                  _animation.value.clamp(0.0, 1.0),
                  (_animation.value + 0.3).clamp(0.0, 1.0),
                ],
                colors: [
                  AppTheme.bgLayer2,
                  AppTheme.bgLayer2.withValues(alpha: 0.5),
                  AppTheme.bgLayer2,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
