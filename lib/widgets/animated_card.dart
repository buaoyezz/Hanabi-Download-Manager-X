import 'package:flutter/material.dart';
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
    this.animationDuration = const Duration(milliseconds: 120),
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  bool _isHovered = false;

  // 缓存颜色值，避免每帧重新计算
  late Color _bgColor;
  late Color _hoverColor;
  late Color _borderColor;
  late Color _hoverBorderColor;

  @override
  void initState() {
    super.initState();
    _initColors();
    _hoverController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
  }

  void _initColors() {
    _bgColor = widget.backgroundColor ?? AppTheme.surfaceCard.withValues(alpha: 0.85);
    _hoverColor = widget.hoverColor ?? (widget.backgroundColor == Colors.transparent
        ? Colors.transparent
        : AppTheme.surfaceCard.withValues(alpha: 0.95));
    _borderColor = widget.borderColor ?? AppTheme.borderSubtle;
    _hoverBorderColor = widget.hoverBorderColor ?? (widget.borderColor == Colors.transparent
        ? Colors.transparent
        : AppTheme.accentPrimary.withValues(alpha: 0.4));
  }

  @override
  void didUpdateWidget(AnimatedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backgroundColor != widget.backgroundColor ||
        oldWidget.hoverColor != widget.hoverColor ||
        oldWidget.borderColor != widget.borderColor ||
        oldWidget.hoverBorderColor != widget.hoverBorderColor) {
      _initColors();
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent _) {
    if (widget.enableHoverAnimation && !_isHovered) {
      _isHovered = true;
      _hoverController.forward();
    }
  }

  void _onExit(PointerEvent _) {
    if (widget.enableHoverAnimation && _isHovered) {
      _isHovered = false;
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _hoverController,
            builder: (context, child) {
              final hoverValue = _hoverController.value;
              
              // 优化：使用简单的透明度变化代替 Color.lerp
              final currentBgColor = _bgColor.withValues(
                alpha: _bgColor.a + (_hoverColor.a - _bgColor.a) * hoverValue
              );
              final currentBorderColor = _borderColor.withValues(
                alpha: _borderColor.a + (_hoverBorderColor.a - _borderColor.a) * hoverValue
              );
              
              // 优化：只在非 hover 时显示静态阴影
              final showShadows = widget.enableGlowAnimation && hoverValue <= 0.01;
              
              return Container(
                margin: widget.margin,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: currentBorderColor,
                    width: 1.0,
                  ),
                  boxShadow: showShadows
                      ? [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )]
                      : const <BoxShadow>[],
                ),
                child: Container(
                  padding: widget.padding ?? EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: currentBgColor,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
                  child: child,
                ),
              );
            },
            child: widget.child,
          ),
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
  final bool showGlow;
  final bool showShine;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.height = 6.0,
    this.backgroundColor,
    this.progressColor,
    this.borderRadius,
    this.animationDuration = const Duration(milliseconds: 400), // 更快的响应
    this.showGlow = true,
    this.showShine = true,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
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
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.progress - widget.progress).abs() > 0.001) {
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
    final radius = widget.borderRadius ?? BorderRadius.circular(widget.height / 2);
    
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, _) {
          final progress = _progressAnimation.value;
          
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
                  // 进度条主体
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            progressColor,
                            progressColor.withValues(alpha: 0.85),
                          ],
                        ),
                        // 优化：移除进度条的 BoxShadow glow 效果
                        // 下载时进度条每帧都在更新，BoxShadow 会导致每帧都触发 saveLayer
                      ),
                    ),
                  ),
                  // 光泽效果
                  if (widget.showShine && progress > 0.01)
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5],
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

/// 数字计数动画组件
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration animationDuration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.animationDuration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
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
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value - widget.value).abs() > 0.001) {
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
