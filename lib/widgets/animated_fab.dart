import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';

/// 带动画效果的浮动操作按钮 - 优化版本
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
  late AnimationController _hoverController;
  late AnimationController _pressController;
  late AnimationController _iconController;
  
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    );
    
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    if (widget.isVisible) {
      _scaleController.forward();
    }
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
      _iconController.forward().then((_) {
        _iconController.reset();
      });
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _hoverController.dispose();
    _pressController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent _) {
    setState(() => _isHovered = true);
    _hoverController.forward();
  }

  void _onExit(PointerEvent _) {
    setState(() => _isHovered = false);
    _hoverController.reverse();
  }

  void _onTapDown(TapDownDetails _) => _pressController.forward();
  
  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onPressed?.call();
  }
  
  void _onTapCancel() => _pressController.reverse();

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppTheme.accentPrimary;
    
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _scaleController, 
          _hoverController, 
          _pressController, 
          _iconController
        ]),
        builder: (context, child) {
          final scaleValue = Curves.easeOutBack.transform(_scaleController.value);
          final hoverValue = Curves.easeOutCubic.transform(_hoverController.value);
          final pressValue = Curves.easeOutCubic.transform(_pressController.value);
          
          // 计算最终缩放
          final scale = scaleValue * (1.0 - pressValue * 0.05) * (1.0 + hoverValue * 0.05);
          
          // 计算阴影
          final shadowBlur = 12.0 + (hoverValue * 8);
          final shadowOffset = 4.0 + (hoverValue * 4);
          
          return Transform.scale(
            scale: scale,
            child: MouseRegion(
              onEnter: _onEnter,
              onExit: _onExit,
              child: GestureDetector(
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: bgColor.withValues(alpha: 0.25 + hoverValue * 0.1),
                        blurRadius: shadowBlur,
                        offset: Offset(0, shadowOffset),
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
                          angle: _iconController.value * 0.3,
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
      ),
    );
  }
}

/// 展开式浮动操作按钮 - 优化版本
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
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
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
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 展开的操作按钮
          ...widget.actions.asMap().entries.map((entry) {
            final index = entry.key;
            final action = entry.value;
            
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // 计算每个按钮的动画进度（交错效果）
                final delay = index * 0.1;
                final progress = ((_controller.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                final curvedProgress = Curves.easeOutCubic.transform(progress);
                
                return Transform.translate(
                  offset: Offset(0, (1 - curvedProgress) * 40),
                  child: Opacity(
                    opacity: curvedProgress,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (action.label != null) ...[
                            Transform.scale(
                              scale: curvedProgress,
                              child: Container(
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
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Transform.rotate(
                angle: _controller.value * 0.75,
                child: AnimatedFab(
                  icon: _isExpanded 
                      ? (widget.expandedIcon ?? fluent.FluentIcons.chrome_close)
                      : widget.icon,
                  onPressed: _toggle,
                  backgroundColor: widget.backgroundColor,
                  foregroundColor: widget.foregroundColor,
                ),
              );
            },
          ),
        ],
      ),
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
