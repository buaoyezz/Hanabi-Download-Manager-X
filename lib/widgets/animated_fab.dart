import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';

/// 带动画效果的浮动操作按钮
class AnimatedFab extends StatefulWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isVisible;
  final bool isLoading;

  const AnimatedFab({
    super.key,
    this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.foregroundColor,
    this.isVisible = true,
    this.isLoading = false,
  });

  @override
  State<AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<AnimatedFab>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.isVisible) {
      _scaleController.forward();
    }

    // 启动脉冲动画
    _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AnimatedFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (widget.isVisible) {
        _scaleController.forward();
      } else {
        _scaleController.reverse();
      }
    }
    
    if (oldWidget.icon != widget.icon) {
      _rotationController.forward().then((_) {
        _rotationController.reset();
      });
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _rotationAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * 
                 (_isPressed ? 0.95 : 1.0) * 
                 (_isHovered ? _pulseAnimation.value : 1.0),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? AppTheme.accentPrimary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.backgroundColor ?? AppTheme.accentPrimary)
                          .withValues(alpha: 0.3),
                      blurRadius: _isHovered ? 20 : 12,
                      offset: Offset(0, _isHovered ? 8 : 4),
                    ),
                  ],
                ),
                child: widget.isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: fluent.ProgressRing(strokeWidth: 2),
                        ),
                      )
                    : Transform.rotate(
                        angle: _rotationAnimation.value * 0.5,
                        child: Icon(
                          widget.icon,
                          size: 24,
                          color: widget.foregroundColor ?? Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 展开式浮动操作按钮
class ExpandableFab extends StatefulWidget {
  final List<FabAction> actions;
  final IconData icon;
  final IconData? expandedIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ExpandableFab({
    super.key,
    required this.actions,
    required this.icon,
    this.expandedIcon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 展开的操作按钮
        ...widget.actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;
          
          return AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              final delay = index * 0.1;
              final animationValue = Curves.easeOutCubic.transform(
                (_expandAnimation.value - delay).clamp(0.0, 1.0) / (1.0 - delay),
              );
              
              return Transform.translate(
                offset: Offset(0, (1 - animationValue) * 60),
                child: Opacity(
                  opacity: animationValue,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (action.label != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppTheme.shadowSm,
                            ),
                            child: Text(
                              action.label!,
                              style: fluent.FluentTheme.of(context)
                                  .typography.caption?.copyWith(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        AnimatedFab(
                          icon: action.icon,
                          onPressed: () {
                            action.onPressed?.call();
                            _toggle();
                          },
                          backgroundColor: action.backgroundColor,
                          foregroundColor: action.foregroundColor,
                          tooltip: action.tooltip,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
        
        // 主按钮
        AnimatedFab(
          icon: _isExpanded 
              ? (widget.expandedIcon ?? fluent.FluentIcons.chrome_close)
              : widget.icon,
          onPressed: _toggle,
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
        ),
      ],
    );
  }
}

/// 浮动操作按钮动作
class FabAction {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const FabAction({
    required this.icon,
    this.label,
    this.tooltip,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });
}