import 'package:flutter/material.dart';

/// A widget that adds a subtle scale down effect when pressed,
/// and a scale up / hover effect when hovered.
class AnimatedPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enableHoverScale;
  final double hoverScale;
  final double pressScale;

  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enableHoverScale = true,
    this.hoverScale = 1.015,
    this.pressScale = 0.97,
  });

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double>? _scaleAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _updateScaleAnimation(false);
  }

  void _updateScaleAnimation(bool forward) {
    double targetScale = 1.0;
    if (_isPressed) {
      targetScale = widget.pressScale;
    } else if (_isHovered && widget.enableHoverScale) {
      targetScale = widget.hoverScale;
    }

    _scaleAnimation = Tween<double>(
      begin: _scaleAnimation?.value ?? 1.0,
      end: targetScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    ));

    if (forward) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(AnimatedPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hoverScale != widget.hoverScale ||
        oldWidget.pressScale != widget.pressScale ||
        oldWidget.enableHoverScale != widget.enableHoverScale) {
      _updateScaleAnimation(true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovered) {
    if (_isHovered == isHovered) return;
    setState(() {
      _isHovered = isHovered;
    });
    _updateScaleAnimation(true);
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _updateScaleAnimation(true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _updateScaleAnimation(true);
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _updateScaleAnimation(true);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTapDown: widget.onTap != null ? _handleTapDown : null,
        onTapUp: widget.onTap != null ? _handleTapUp : null,
        onTapCancel: widget.onTap != null ? _handleTapCancel : null,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation?.value ?? 1.0,
              alignment: Alignment.center,
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Adds a staggered slide and fade animation based on an index.
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delayBase;
  final Duration duration;

  const StaggeredEntrance({
    super.key,
    required this.child,
    required this.index,
    this.delayBase = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 400),
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(widget.delayBase * widget.index, () {
      if (mounted) {
        _controller.forward();
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
