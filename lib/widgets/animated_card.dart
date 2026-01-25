import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';

/// 带动画效果的卡片组件 - 优化版本
/// 使用 RepaintBoundary 减少重绘，优化动画曲线
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
    this.animationDuration = const Duration(milliseconds: 150), // 更快的响应
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _tapController;
  
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

    _tapController = AnimationController(
      duration: const Duration(milliseconds: 80), // 更快的按压响应
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
    return RepaintBoundary(
      child: MouseRegion(
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
            animation: Listenable.merge([_hoverController, _tapController]),
            builder: (context, child) {
              // 使用更丝滑的曲线
              final hoverValue = Curves.easeOutCubic.transform(_hoverController.value);
              final tapValue = Curves.easeOutCubic.transform(_tapController.value);
              
              // 计算缩放 - 禁用缩放动画
              final scale = 1.0; // 始终保持 1.0，不缩放
              
              // 插值颜色
              final currentBgColor = Color.lerp(_bgColor, _hoverColor, hoverValue)!;
              final currentBorderColor = Color.lerp(_borderColor, _hoverBorderColor, hoverValue)!;
              
              return Container(
                margin: widget.margin,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: currentBorderColor,
                    width: 1.0,
                  ),
                  boxShadow: [
                    // 基础阴影
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                    // 发光效果 - 使用 shader 优化
                    if (widget.enableGlowAnimation)
                      BoxShadow(
                        color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 0),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: Container(
                    padding: widget.padding,
                    decoration: BoxDecoration(
                      color: currentBgColor,
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: widget.child, // 使用 child 参数避免子组件重建
          ),
        ),
      ),
    );
  }
}

/// 带进度动画的进度条组件 - 优化版本
/// 使用自定义绘制提升性能，添加光泽效果
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
                        boxShadow: widget.showGlow && progress > 0.01
                            ? [
                                BoxShadow(
                                  color: progressColor.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 0),
                                ),
                              ]
                            : null,
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

/// 数字计数动画组件 - 优化版本
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