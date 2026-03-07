import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scroll_animator/scroll_animator.dart';

bool get _useAnimatedDesktopScroll =>
    !kIsWeb &&
    const {
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

/// 平滑滚动配置
class SmoothScrollConfig {
  /// 滚动动画工厂
  final ScrollAnimationFactory animationFactory;

  const SmoothScrollConfig({
    required this.animationFactory,
  });

  /// 默认配置 - Chromium 风格的平滑滚动（推荐）
  static const SmoothScrollConfig defaults = SmoothScrollConfig(
    animationFactory: ChromiumEaseInOut(),
  );

  /// Edge 风格 - Microsoft Edge 的滚动动画
  static const SmoothScrollConfig edge = SmoothScrollConfig(
    animationFactory: ChromiumImpulse(),
  );

  /// 快速响应配置 - 与 defaults 相同
  static const SmoothScrollConfig fast = SmoothScrollConfig(
    animationFactory: ChromiumEaseInOut(),
  );

  /// 超级流畅配置 - 与 defaults 相同
  static const SmoothScrollConfig smooth = SmoothScrollConfig(
    animationFactory: ChromiumEaseInOut(),
  );
}

ScrollController createSmoothScrollController({
  SmoothScrollConfig config = SmoothScrollConfig.defaults,
}) {
  if (_useAnimatedDesktopScroll) {
    return AnimatedScrollController(
      animationFactory: config.animationFactory,
    );
  }
  return ScrollController();
}

/// 平滑滚动的 ListView - 使用 scroll_animator
class SmoothListView extends StatefulWidget {
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final List<Widget>? children;
  final EdgeInsetsGeometry? padding;
  final SmoothScrollConfig config;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool shrinkWrap;
  final bool reverse;
  final double? cacheExtent;
  final bool addRepaintBoundaries;
  final bool addAutomaticKeepAlives;

  const SmoothListView.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.config =
        const SmoothScrollConfig(animationFactory: ChromiumEaseInOut()),
    this.controller,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.reverse = false,
    this.cacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
  }) : children = null;

  const SmoothListView({
    super.key,
    required this.children,
    this.padding,
    this.config =
        const SmoothScrollConfig(animationFactory: ChromiumEaseInOut()),
    this.controller,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.reverse = false,
    this.cacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
  })  : itemCount = null,
        itemBuilder = null;

  @override
  State<SmoothListView> createState() => _SmoothListViewState();
}

class _SmoothListViewState extends State<SmoothListView> {
  late ScrollController _scrollController;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _scrollController = widget.controller ??
        createSmoothScrollController(config: widget.config);
  }

  @override
  void dispose() {
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      scrollDirection: widget.scrollDirection,
      shrinkWrap: widget.shrinkWrap,
      reverse: widget.reverse,
      cacheExtent: widget.cacheExtent ?? 500,
      addRepaintBoundaries: widget.addRepaintBoundaries,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      itemCount: widget.itemCount ?? widget.children?.length ?? 0,
      itemBuilder:
          widget.itemBuilder ?? (context, index) => widget.children![index],
    );
  }
}

/// 平滑滚动的 SingleChildScrollView - 使用 scroll_animator
class SmoothSingleChildScrollView extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final SmoothScrollConfig config;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool reverse;

  const SmoothSingleChildScrollView({
    super.key,
    required this.child,
    this.padding,
    this.config =
        const SmoothScrollConfig(animationFactory: ChromiumEaseInOut()),
    this.controller,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
  });

  @override
  State<SmoothSingleChildScrollView> createState() =>
      _SmoothSingleChildScrollViewState();
}

class _SmoothSingleChildScrollViewState
    extends State<SmoothSingleChildScrollView> {
  late ScrollController _scrollController;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _scrollController = widget.controller ??
        createSmoothScrollController(config: widget.config);
  }

  @override
  void dispose() {
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      child: widget.child,
    );
  }
}
