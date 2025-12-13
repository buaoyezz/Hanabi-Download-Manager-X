import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';

/// 脉冲加载动画
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

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (widget.color ?? AppTheme.accentPrimary)
                .withValues(alpha: 0.3 * (1 - _animation.value)),
          ),
          child: Transform.scale(
            scale: _animation.value,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color ?? AppTheme.accentPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 波浪加载动画
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
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(widget.waveCount, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = index * 0.2;
              final animationValue = Curves.easeInOut.transform(
                ((_controller.value - delay) % 1.0).clamp(0.0, 1.0),
              );
              
              return Transform.scale(
                scaleY: 0.3 + (0.7 * animationValue),
                child: Container(
                  width: 4,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: widget.color ?? AppTheme.accentPrimary,
                    borderRadius: BorderRadius.circular(2),
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

/// 旋转加载动画
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159,
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
        );
      },
    );
  }
}

/// 点跳跃加载动画
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
      duration: const Duration(milliseconds: 1400),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.dotCount, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final animationValue = Curves.easeInOut.transform(
              ((_controller.value - delay) % 1.0).clamp(0.0, 1.0),
            );
            
            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.size * 0.2),
              child: Transform.translate(
                offset: Offset(0, -10 * animationValue),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (widget.color ?? AppTheme.accentPrimary)
                        .withValues(alpha: 0.3 + (0.7 * animationValue)),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// 骨架屏加载动画
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
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
    );
  }
}

/// 进度条加载动画
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
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
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
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppTheme.bgLayer2,
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: widget.width * _animation.value,
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.progressColor ?? AppTheme.accentPrimary,
                borderRadius: BorderRadius.circular(widget.height / 2),
              ),
            ),
          );
        },
      ),
    );
  }
}