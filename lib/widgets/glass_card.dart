import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/notification_settings_service.dart';

/// 现代毛玻璃卡片组件 - Fluent Design Mica 风格
/// 支持多种样式变体和交互状态 - 优化版本
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

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  bool _isHovered = false;

  // 性能设置
  final _performanceSettings = NotificationSettingsService();

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent _) {
    if (widget.enableHover) {
      setState(() => _isHovered = true);
      _hoverController.forward();
    }
  }

  void _onExit(PointerEvent _) {
    if (widget.enableHover) {
      setState(() => _isHovered = false);
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enableBlur = _performanceSettings.enableBlur;
    final blurSigma = _performanceSettings.blurSigma;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _hoverController,
            builder: (context, child) {
              final hoverValue = Curves.easeOutCubic.transform(_hoverController.value);

              return Container(
                margin: widget.margin,
                decoration: _getDecoration(isDark, hoverValue),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: enableBlur
                      ? BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: blurSigma + (hoverValue * 2),
                            sigmaY: blurSigma + (hoverValue * 2),
                          ),
                          child: _buildContent(isDark, hoverValue, child),
                        )
                      : _buildContent(isDark, hoverValue, child),
                ),
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, double hoverValue, Widget? child) {
    final enableBlur = _performanceSettings.enableBlur;
    return Container(
      decoration: BoxDecoration(
        gradient: _getGradient(isDark, hoverValue),
        // 无模糊时使用纯色背景
        color: enableBlur ? null : (isDark ? AppTheme.surfaceCard : Colors.white),
      ),
      padding: widget.padding,
      child: child,
    );
  }

  BoxDecoration _getDecoration(bool isDark, double hoverValue) {
    switch (widget.variant) {
      case GlassCardVariant.standard:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: Color.lerp(
              AppTheme.borderSubtle.withValues(alpha: 0.5),
              AppTheme.borderDefault.withValues(alpha: 0.6),
              hoverValue,
            )!,
            width: 1,
          ),
        );
      
      case GlassCardVariant.elevated:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: Color.lerp(
              AppTheme.borderSubtle.withValues(alpha: 0.5),
              AppTheme.accentPrimary.withValues(alpha: 0.4),
              hoverValue,
            )!,
            width: 1,
          ),
          boxShadow: hoverValue > 0.01 ? AppTheme.shadowSm : null,
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
            color: AppTheme.accentPrimary.withValues(alpha: 0.25 + (hoverValue * 0.25)),
            width: 1,
          ),
        );
    }
  }

  LinearGradient _getGradient(bool isDark, double hoverValue) {
    switch (widget.variant) {
      case GlassCardVariant.standard:
      case GlassCardVariant.elevated:
        final baseAlpha = isDark ? 0.7 : 0.8;
        final hoverAlpha = isDark ? 0.85 : 0.9;
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppTheme.surfaceCard.withValues(alpha: baseAlpha + (hoverValue * (hoverAlpha - baseAlpha))),
                  AppTheme.surfaceCard.withValues(alpha: (baseAlpha - 0.1) + (hoverValue * (hoverAlpha - baseAlpha))),
                ]
              : [
                  Colors.white.withValues(alpha: baseAlpha + (hoverValue * (hoverAlpha - baseAlpha))),
                  Colors.white.withValues(alpha: (baseAlpha - 0.2) + (hoverValue * (hoverAlpha - baseAlpha))),
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
            AppTheme.accentPrimary.withValues(alpha: 0.08 + (hoverValue * 0.04)),
            AppTheme.accentPrimary.withValues(alpha: 0.04 + (hoverValue * 0.02)),
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

/// 简单的表面卡片 - Fluent Design 风格（无毛玻璃效果，性能更好）- 优化版本
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

class _SurfaceCardState extends State<SurfaceCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent _) {
    if (widget.enableHover) _hoverController.forward();
  }

  void _onExit(PointerEvent _) {
    if (widget.enableHover) _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppTheme.surfaceCard.withValues(alpha: 0.7);
    final hoverBgColor = widget.backgroundColor ?? AppTheme.surfaceCardHover.withValues(alpha: 0.85);
    final borderColor = widget.borderColor ?? AppTheme.borderSubtle.withValues(alpha: 0.5);
    final hoverBorderColor = widget.borderColor ?? AppTheme.borderDefault.withValues(alpha: 0.6);
    
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _hoverController,
            builder: (context, child) {
              final hoverValue = Curves.easeOutCubic.transform(_hoverController.value);
              
              return Container(
                margin: widget.margin,
                padding: widget.padding,
                decoration: BoxDecoration(
                  color: Color.lerp(bgColor, hoverBgColor, hoverValue),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: Color.lerp(borderColor, hoverBorderColor, hoverValue)!,
                    width: 1,
                  ),
                ),
                child: child,
              );
            },
            child: widget.child,
          ),
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
