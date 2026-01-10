import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 动画工具类 - 提供统一的动画配置和便捷方法
class AnimationUtils {
  AnimationUtils._();
  
  // ============ 标准动画时长 ============
  
  /// 即时响应 - 用于按压反馈
  static const Duration instant = Duration(milliseconds: 80);
  
  /// 快速 - 用于悬停效果
  static const Duration fast = Duration(milliseconds: 150);
  
  /// 标准 - 用于大多数过渡
  static const Duration normal = Duration(milliseconds: 250);
  
  /// 慢速 - 用于页面切换
  static const Duration slow = Duration(milliseconds: 350);
  
  /// 强调 - 用于重要动画
  static const Duration emphasis = Duration(milliseconds: 500);
  
  // ============ 优化的动画曲线 ============
  
  /// 标准出场曲线 - 快速开始，平滑结束
  static const Curve smoothOut = Curves.easeOutCubic;
  
  /// 标准入场曲线
  static const Curve smoothIn = Curves.easeInCubic;
  
  /// 双向平滑曲线
  static const Curve smoothInOut = Curves.easeInOutCubic;
  
  /// 弹性曲线 - 用于强调效果
  static const Curve bounce = Curves.elasticOut;
  
  /// 减速曲线 - 用于自然停止
  static const Curve decelerate = Curves.decelerate;
  
  /// 微交互曲线 - 更快的响应
  static const Curve microInteraction = Curves.easeOutQuart;
  
  /// 弹簧曲线 - 物理效果
  static Curve get spring => const _SpringCurve();
  
  // ============ 便捷方法 ============
  
  /// 计算交错动画延迟
  /// [index] 列表项索引
  /// [baseDelay] 基础延迟
  /// [maxIndex] 最大索引限制，避免列表过长时动画太慢
  static Duration staggerDelay(int index, {
    Duration baseDelay = const Duration(milliseconds: 50),
    int maxIndex = 8,
  }) {
    final effectiveIndex = index.clamp(0, maxIndex);
    return baseDelay * effectiveIndex;
  }
  
  /// 创建平滑的颜色过渡
  static Color? lerpColor(Color? begin, Color? end, double t) {
    return Color.lerp(begin, end, smoothOut.transform(t));
  }
  
  /// 创建平滑的数值过渡
  static double lerpDouble(double begin, double end, double t) {
    return begin + (end - begin) * smoothOut.transform(t);
  }
  
  /// 计算按压缩放值
  static double pressScale(double animationValue, {double maxScale = 0.02}) {
    return 1.0 - (animationValue * maxScale);
  }
  
  /// 计算悬停缩放值
  static double hoverScale(double animationValue, {double maxScale = 0.015}) {
    return 1.0 + (animationValue * maxScale);
  }
}

/// 自定义弹簧曲线 - 更自然的物理效果
class _SpringCurve extends Curve {
  const _SpringCurve();
  
  @override
  double transformInternal(double t) {
    // 阻尼弹簧公式
    const damping = 0.7;
    const frequency = 3.5;
    return 1 - math.pow(math.e, -damping * t * 10) * 
           math.cos(frequency * math.pi * t);
  }
}

/// 动画状态混入 - 简化动画控制器管理
mixin AnimationStateMixin<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  final Map<String, AnimationController> _controllers = {};
  
  /// 创建或获取动画控制器
  AnimationController getController(String key, {
    Duration duration = AnimationUtils.normal,
    double? value,
  }) {
    if (!_controllers.containsKey(key)) {
      _controllers[key] = AnimationController(
        duration: duration,
        vsync: this,
        value: value,
      );
    }
    return _controllers[key]!;
  }
  
  /// 释放所有控制器
  void disposeControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
  
  @override
  void dispose() {
    disposeControllers();
    super.dispose();
  }
}

/// 悬停状态混入 - 简化悬停效果管理
mixin HoverStateMixin<T extends StatefulWidget> on State<T> {
  bool _isHovered = false;
  
  bool get isHovered => _isHovered;
  
  void onHoverEnter(PointerEvent _) {
    if (!_isHovered) {
      setState(() => _isHovered = true);
      onHoverChanged(true);
    }
  }
  
  void onHoverExit(PointerEvent _) {
    if (_isHovered) {
      setState(() => _isHovered = false);
      onHoverChanged(false);
    }
  }
  
  /// 子类可重写此方法响应悬停状态变化
  void onHoverChanged(bool isHovered) {}
}

/// 按压状态混入 - 简化按压效果管理
mixin PressStateMixin<T extends StatefulWidget> on State<T> {
  bool _isPressed = false;
  
  bool get isPressed => _isPressed;
  
  void onTapDown(TapDownDetails _) {
    if (!_isPressed) {
      setState(() => _isPressed = true);
      onPressChanged(true);
    }
  }
  
  void onTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      onPressChanged(false);
    }
  }
  
  void onTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      onPressChanged(false);
    }
  }
  
  /// 子类可重写此方法响应按压状态变化
  void onPressChanged(bool isPressed) {}
}
