import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';

/// 带动画效果的卡片组件
class AnimatedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? hoverColor;
  final Color? borderColor;
  final Color? hoverBorderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool enableHoverAnimation;
  final bool enableScaleAnimation;
  final bool enableGlowAnimation;
  final Duration animationDuration;

  const AnimatedCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.hoverColor,
    this.borderColor,
    this.hoverBorderColor,
    this.borderRadius = 12.0,
    this.onTap,
    this.enableHoverAnimation = true,
    this.enableScaleAnimation = true,
    this.enableGlowAnimation = true,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _tapController;
  late Animation<double> _hoverAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _backgroundColorAnimation;
  late Animation<Color?> _borderColorAnimation;
  late Animation<double> _glowAnimation;



  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _tapController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _hoverAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.enableScaleAnimation ? 1.02 : 1.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _backgroundColorAnimation = ColorTween(
      begin: widget.backgroundColor ?? AppTheme.surfaceCard.withValues(alpha: 0.85),
      end: widget.hoverColor ?? AppTheme.surfaceCard.withValues(alpha: 0.95),
    ).animate(_hoverAnimation);

    _borderColorAnimation = ColorTween(
      begin: widget.borderColor ?? AppTheme.borderSubtle,
      end: widget.hoverBorderColor ?? AppTheme.accentPrimary.withValues(alpha: 0.4),
    ).animate(_hoverAnimation);

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: widget.enableGlowAnimation ? 1.0 : 0.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _tapController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _tapController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _tapController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.enableHoverAnimation
          ? (_) => _hoverController.forward()
          : null,
      onExit: widget.enableHoverAnimation
          ? (_) => _hoverController.reverse()
          : null,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _handleTapDown : null,
        onTapUp: widget.onTap != null ? _handleTapUp : null,
        onTapCancel: widget.onTap != null ? _handleTapCancel : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_hoverAnimation, _tapController]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value * (1.0 - (_tapController.value * 0.02)),
              child: Container(
                margin: widget.margin,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: _borderColorAnimation.value!,
                    width: 1.0 + (_hoverAnimation.value * 0.5),
                  ),
                  boxShadow: [
                    // 基础阴影
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                    // 悬停发光效果
                    if (widget.enableGlowAnimation)
                      BoxShadow(
                        color: AppTheme.accentPrimary.withValues(alpha: 0.2 * _glowAnimation.value),
                        blurRadius: 12 * _glowAnimation.value,
                        offset: Offset(0, 4 * _glowAnimation.value),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: Container(
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      color: _backgroundColorAnimation.value,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 带进度动画的进度条组件
class AnimatedProgressBar extends StatefulWidget {
  final double progress;
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;
  final BorderRadius? borderRadius;
  final Duration animationDuration;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.height = 6.0,
    this.backgroundColor,
    this.progressColor,
    this.borderRadius,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _lastProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _progressAnimation = Tween<double>(
        begin: _lastProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _lastProgress = widget.progress;
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
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppTheme.bgLayer1,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(widget.height / 2),
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(widget.height / 2),
        child: AnimatedBuilder(
          animation: _progressAnimation,
          builder: (context, child) {
            return fluent.ProgressBar(
              value: _progressAnimation.value * 100,
              strokeWidth: widget.height,
            );
          },
        ),
      ),
    );
  }
}

/// 数字计数动画组件
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration animationDuration;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.animationDuration = const Duration(milliseconds: 600),
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _lastValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _lastValue,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _lastValue = widget.value;
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          widget.formatter(_animation.value),
          style: widget.style,
        );
      },
    );
  }
}