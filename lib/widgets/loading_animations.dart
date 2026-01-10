import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';

/// 脉冲加载动画 - 优化版本
class PulseLoadingAnimation extends StatefulWidget {
  final double size;
  final Color? color;
  final Duration duration;

  const PulseLoadingAnimation({
    super.key,
    this.size = 40,
    this.color,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<PulseLoadingAnimation> createState() => _PulseLoadingAnimationState();
}

class _PulseLoadingAnimationState extends State<PulseLoadingAnimation>
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
      curve: Curves.easeInOut,
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
    final color = widget.color ?? AppTheme.accentPrimary;
    
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.25 * (1 - _animation.value)),
            ),
            child: Transform.scale(
              scale: 0.3 + (_animation.value * 0.7),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 波浪加载动画 - 优化版本
class WaveLoadingAnimation extends StatefulWidget {
  final double width;
  final double height;
  final Color? color;
  final int waveCount;

  const WaveLoadingAnimation({
    super.key,
    this.width = 60,
    this.height = 40,
    this.color,
    this.waveCount = 3,
  });

  @override
  State<WaveLoadingAnimation> createState() => _WaveLoadingAnimationState();
}

class _WaveLoadingAnimationState extends State<WaveLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
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
    final color = widget.color ?? AppTheme.accentPrimary;
    
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(widget.waveCount, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final delay = index * 0.15;
                final phase = (_controller.value + delay) % 1.0;
                final scale = 0.4 + (0.6 * math.sin(phase * math.pi));
                
                return Transform.scale(
                  scaleY: scale,
                  child: Container(
                    width: 4,
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

/// 旋转加载动画 - 优化版本
class SpinLoadingAnimation extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const SpinLoadingAnimation({
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2,
  });

  @override
  State<SpinLoadingAnimation> createState() => _SpinLoadingAnimationState();
}

class _SpinLoadingAnimationState extends State<SpinLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
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
      child: RotationTransition(
        turns: _controller,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            strokeWidth: widget.strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.color ?? AppTheme.accentPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 点跳跃加载动画 - 优化版本
class DotsLoadingAnimation extends StatefulWidget {
  final double size;
  final Color? color;
  final int dotCount;

  const DotsLoadingAnimation({
    super.key,
    this.size = 8,
    this.color,
    this.dotCount = 3,
  });

  @override
  State<DotsLoadingAnimation> createState() => _DotsLoadingAnimationState();
}

class _DotsLoadingAnimationState extends State<DotsLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
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
    final color = widget.color ?? AppTheme.accentPrimary;
    
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.dotCount, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final delay = index * 0.2;
              final phase = (_controller.value + delay) % 1.0;
              // 使用正弦函数创建平滑的弹跳效果
              final bounce = math.sin(phase * math.pi);
              
              return Container(
                margin: EdgeInsets.symmetric(horizontal: widget.size * 0.25),
                child: Transform.translate(
                  offset: Offset(0, -8 * bounce),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.4 + (0.6 * bounce)),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// 骨架屏加载动画 - 优化版本
class SkeletonLoadingAnimation extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoadingAnimation({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoadingAnimation> createState() => _SkeletonLoadingAnimationState();
}

class _SkeletonLoadingAnimationState extends State<SkeletonLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

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
                  AppTheme.bgLayer2.withValues(alpha: 0.4),
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

/// 进度条加载动画 - 优化版本
class ProgressLoadingAnimation extends StatefulWidget {
  final double width;
  final double height;
  final Color? backgroundColor;
  final Color? progressColor;

  const ProgressLoadingAnimation({
    super.key,
    this.width = 200,
    this.height = 4,
    this.backgroundColor,
    this.progressColor,
  });

  @override
  State<ProgressLoadingAnimation> createState() => _ProgressLoadingAnimationState();
}

class _ProgressLoadingAnimationState extends State<ProgressLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _positionAnimation = Tween<double>(
      begin: -0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _widthAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 0.1), weight: 50),
    ]).animate(_controller);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppTheme.bgLayer2;
    final progressColor = widget.progressColor ?? AppTheme.accentPrimary;
    
    return RepaintBoundary(
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Align(
              alignment: Alignment(
                (_positionAnimation.value * 2) - 1,
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: _widthAnimation.value,
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: progressColor,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                    boxShadow: [
                      BoxShadow(
                        color: progressColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
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

/// 呼吸灯效果组件
class BreathingAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minOpacity;
  final double maxOpacity;

  const BreathingAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
    this.minOpacity = 0.5,
    this.maxOpacity = 1.0,
  });

  @override
  State<BreathingAnimation> createState() => _BreathingAnimationState();
}

class _BreathingAnimationState extends State<BreathingAnimation>
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
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.repeat(reverse: true);
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
        opacity: _animation,
        child: widget.child,
      ),
    );
  }
}
