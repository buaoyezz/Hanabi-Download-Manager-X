import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 现代毛玻璃卡片组件 - Fluent Design Mica 风格
/// 支持多种样式变体和交互状态
class GlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enableHover;
  final VoidCallback? onTap;
  final GlassCardVariant variant;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 6,
    this.padding,
    this.margin,
    this.enableHover = false,
    this.onTap,
    this.variant = GlassCardVariant.standard,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: widget.enableHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enableHover ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: widget.margin,
          decoration: _getDecoration(isDark),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _isHovered ? 25 : 20,
                sigmaY: _isHovered ? 25 : 20,
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: _getGradient(isDark),
                ),
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _getDecoration(bool isDark) {
    switch (widget.variant) {
      case GlassCardVariant.standard:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _isHovered
                ? AppTheme.borderDefault.withValues(alpha: 0.6)
                : AppTheme.borderSubtle.withValues(alpha: 0.5),
            width: 1,
          ),
        );
      
      case GlassCardVariant.elevated:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _isHovered
                ? AppTheme.accentPrimary.withValues(alpha: 0.4)
                : AppTheme.borderSubtle.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: _isHovered ? AppTheme.shadowSm : null,
        );
      
      case GlassCardVariant.subtle:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: AppTheme.borderSubtle.withValues(alpha: 0.3),
            width: 1,
          ),
        );
      
      case GlassCardVariant.accent:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: AppTheme.accentPrimary.withValues(alpha: _isHovered ? 0.5 : 0.25),
            width: 1,
          ),
        );
    }
  }

  LinearGradient _getGradient(bool isDark) {
    switch (widget.variant) {
      case GlassCardVariant.standard:
      case GlassCardVariant.elevated:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.surfaceCard.withValues(alpha: _isHovered ? 0.85 : 0.7),
                  AppTheme.surfaceCard.withValues(alpha: _isHovered ? 0.75 : 0.6),
                ]
              : [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.6),
                ],
        );
      
      case GlassCardVariant.subtle:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.surfaceCard.withValues(alpha: 0.5),
                  AppTheme.surfaceCard.withValues(alpha: 0.4),
                ]
              : [
                  Colors.white.withValues(alpha: 0.6),
                  Colors.white.withValues(alpha: 0.4),
                ],
        );
      
      case GlassCardVariant.accent:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentPrimary.withValues(alpha: _isHovered ? 0.12 : 0.08),
            AppTheme.accentPrimary.withValues(alpha: _isHovered ? 0.06 : 0.04),
          ],
        );
    }
  }
}

/// 卡片样式变体
enum GlassCardVariant {
  /// 标准样式 - 适用于一般内容卡片
  standard,
  /// 提升样式 - 适用于重要内容，有更强的阴影和边框
  elevated,
  /// 微妙样式 - 适用于次要内容，更轻的视觉效果
  subtle,
  /// 强调样式 - 使用主题色强调
  accent,
}

/// 简单的表面卡片 - Fluent Design 风格（无毛玻璃效果，性能更好）
class SurfaceCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enableHover;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  const SurfaceCard({
    super.key,
    required this.child,
    this.borderRadius = 6,
    this.padding,
    this.margin,
    this.enableHover = false,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: widget.enableHover ? (_) => setState(() => _isHovered = true) : null,
      onExit: widget.enableHover ? (_) => setState(() => _isHovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          margin: widget.margin,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? 
                (_isHovered 
                    ? AppTheme.surfaceCardHover.withValues(alpha: 0.85) 
                    : AppTheme.surfaceCard.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: widget.borderColor ?? 
                  (_isHovered 
                      ? AppTheme.borderDefault.withValues(alpha: 0.6) 
                      : AppTheme.borderSubtle.withValues(alpha: 0.5)),
              width: 1,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 状态指示卡片 - Fluent Design 风格
class StatusCard extends StatelessWidget {
  final Widget child;
  final Color statusColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const StatusCard({
    super.key,
    required this.child,
    required this.statusColor,
    this.borderRadius = 6,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
