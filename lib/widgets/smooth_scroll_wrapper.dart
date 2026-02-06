import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 平滑滚动配置
class SmoothScrollConfig {
  /// 滚动速度倍数 (默认 1.0)
  final double scrollSpeed;

  /// 动画持续时间
  final Duration animationDuration;

  /// 动画曲线
  final Curve animationCurve;

  /// 滚轮灵敏度倍数
  final double wheelSensitivity;

  const SmoothScrollConfig({
    this.scrollSpeed = 1.0,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOutCubic,
    this.wheelSensitivity = 1.2,
  });

  /// 默认配置 - 平衡模式
  static const SmoothScrollConfig defaults = SmoothScrollConfig();

  /// 快速响应配置 - 适中的速度和流畅度
  static const SmoothScrollConfig fast = SmoothScrollConfig(
    scrollSpeed: 1.35,
    animationDuration: Duration(milliseconds: 180),
    animationCurve: Curves.easeOutCubic,
    wheelSensitivity: 1.15,
  );

  /// 超级流畅配置 - 更慢更丝滑
  static const SmoothScrollConfig smooth = SmoothScrollConfig(
    scrollSpeed: 0.9,
    animationDuration: Duration(milliseconds: 400),
    animationCurve: Curves.easeOutQuart,
    wheelSensitivity: 1.0,
  );
}

/// 平滑滚动包装器
class SmoothScrollWrapper extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final SmoothScrollConfig config;
  final Axis scrollDirection;

  const SmoothScrollWrapper({
    super.key,
    required this.child,
    this.controller,
    this.config = const SmoothScrollConfig(),
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<SmoothScrollWrapper> createState() => _SmoothScrollWrapperState();
}

class _SmoothScrollWrapperState extends State<SmoothScrollWrapper>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  double _targetOffset = 0;
  bool _isAnimating = false;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      _scrollController = widget.controller!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }

    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();

    if (_ownsController) {
      _scrollController.dispose();
    }

    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) {
      _stopSmoothScroll();
      return;
    }

    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    if (dtMicros <= 0) {
      return;
    }
    _lastTick = elapsed;

    final minExtent = _scrollController.position.minScrollExtent;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final diff = _targetOffset - currentOffset;

    if (diff.abs() < 0.5) {
      _scrollController.jumpTo(_targetOffset.clamp(minExtent, maxExtent));
      _stopSmoothScroll();
      return;
    }

    final durationSeconds =
        widget.config.animationDuration.inMicroseconds / 1000000.0;
    if (durationSeconds <= 0) {
      _scrollController.jumpTo(_targetOffset.clamp(minExtent, maxExtent));
      _stopSmoothScroll();
      return;
    }

    final tau = durationSeconds / 3;
    final smoothing = 1 - math.exp(-(dtMicros / 1000000.0) / tau);
    final nextOffset = currentOffset + diff * smoothing;
    _scrollController.jumpTo(nextOffset.clamp(minExtent, maxExtent));
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      double delta;
      if (widget.scrollDirection == Axis.vertical) {
        delta = event.scrollDelta.dy;
      } else {
        delta = event.scrollDelta.dx;
      }

      // 应用滚动速度和灵敏度
      delta *= widget.config.scrollSpeed * widget.config.wheelSensitivity;

      final isTrackpad = event.kind == PointerDeviceKind.trackpad;
      final currentOffset = _scrollController.offset;
      final baseOffset = isTrackpad ? currentOffset : (_isAnimating ? _targetOffset : currentOffset);

      _targetOffset = (baseOffset + delta).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      if (isTrackpad) {
        _stopSmoothScroll();
        _scrollController.jumpTo(_targetOffset);
        return;
      }

      _startSmoothScroll();
    }
  }

  void _startSmoothScroll() {
    if (!_scrollController.hasClients) return;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    _isAnimating = true;
  }

  void _stopSmoothScroll() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _isAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: ScrollConfiguration(
        behavior: _SmoothScrollBehavior(),
        child: _injectController(widget.child),
      ),
    );
  }

  Widget _injectController(Widget child) {
    if (widget.controller != null) {
      return child;
    }

    return PrimaryScrollController(
      controller: _scrollController,
      child: child,
    );
  }
}

/// 自定义滚动行为
class _SmoothScrollBehavior extends ScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

/// 平滑滚动的 ListView
class SmoothListView extends StatefulWidget {
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final List<Widget>? children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final SmoothScrollConfig config;
  final Axis scrollDirection;
  final bool shrinkWrap;
  final double? cacheExtent;
  final bool addRepaintBoundaries;
  final bool addAutomaticKeepAlives;

  const SmoothListView.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.config = const SmoothScrollConfig(),
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.cacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
  }) : children = null;

  const SmoothListView({
    super.key,
    required this.children,
    this.padding,
    this.controller,
    this.config = const SmoothScrollConfig(),
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.cacheExtent,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
  })  : itemCount = null,
        itemBuilder = null;

  @override
  State<SmoothListView> createState() => _SmoothListViewState();
}

class _SmoothListViewState extends State<SmoothListView>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  double _targetOffset = 0;
  bool _isAnimating = false;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      _scrollController = widget.controller!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }

    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();

    if (_ownsController) {
      _scrollController.dispose();
    }

    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) {
      _stopSmoothScroll();
      return;
    }

    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    if (dtMicros <= 0) {
      return;
    }
    _lastTick = elapsed;

    final minExtent = _scrollController.position.minScrollExtent;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final diff = _targetOffset - currentOffset;

    if (diff.abs() < 0.5) {
      _scrollController.jumpTo(_targetOffset.clamp(minExtent, maxExtent));
      _stopSmoothScroll();
      return;
    }

    final durationSeconds =
        widget.config.animationDuration.inMicroseconds / 1000000.0;
    if (durationSeconds <= 0) {
      _scrollController.jumpTo(_targetOffset.clamp(minExtent, maxExtent));
      _stopSmoothScroll();
      return;
    }

    final tau = durationSeconds / 3;
    final smoothing = 1 - math.exp(-(dtMicros / 1000000.0) / tau);
    final nextOffset = currentOffset + diff * smoothing;
    _scrollController.jumpTo(nextOffset.clamp(minExtent, maxExtent));
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      double delta;
      if (widget.scrollDirection == Axis.vertical) {
        delta = event.scrollDelta.dy;
      } else {
        delta = event.scrollDelta.dx;
      }

      // 应用滚动速度和灵敏度
      delta *= widget.config.scrollSpeed * widget.config.wheelSensitivity;

      final isTrackpad = event.kind == PointerDeviceKind.trackpad;
      final currentOffset = _scrollController.offset;
      final baseOffset = isTrackpad ? currentOffset : (_isAnimating ? _targetOffset : currentOffset);

      _targetOffset = (baseOffset + delta).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      if (isTrackpad) {
        _stopSmoothScroll();
        _scrollController.jumpTo(_targetOffset);
        return;
      }

      _startSmoothScroll();
    }
  }

  void _startSmoothScroll() {
    if (!_scrollController.hasClients) return;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    _isAnimating = true;
  }

  void _stopSmoothScroll() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _isAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    Widget listView;

    if (widget.itemBuilder != null) {
      listView = ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        scrollDirection: widget.scrollDirection,
        shrinkWrap: widget.shrinkWrap,
        cacheExtent: widget.cacheExtent ?? 500,
        addRepaintBoundaries: widget.addRepaintBoundaries,
        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder!,
      );
    } else {
      listView = ListView(
        controller: _scrollController,
        padding: widget.padding,
        scrollDirection: widget.scrollDirection,
        shrinkWrap: widget.shrinkWrap,
        cacheExtent: widget.cacheExtent ?? 500,
        addRepaintBoundaries: widget.addRepaintBoundaries,
        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
        physics: const NeverScrollableScrollPhysics(),
        children: widget.children ?? [],
      );
    }

    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: listView,
    );
  }
}

/// 平滑滚动的 SingleChildScrollView
class SmoothSingleChildScrollView extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final SmoothScrollConfig config;
  final Axis scrollDirection;

  const SmoothSingleChildScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
    this.config = const SmoothScrollConfig(),
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<SmoothSingleChildScrollView> createState() =>
      _SmoothSingleChildScrollViewState();
}

class _SmoothSingleChildScrollViewState
    extends State<SmoothSingleChildScrollView>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  double _targetOffset = 0;
  bool _isAnimating = false;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();

    if (widget.controller != null) {
      _scrollController = widget.controller!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }

    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();

    if (_ownsController) {
      _scrollController.dispose();
    }

    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_scrollController.hasClients) {
      _stopSmoothScroll();
      return;
    }

    final dtMicros = (elapsed - _lastTick).inMicroseconds;
    if (dtMicros <= 0) {
      return;
    }
    _lastTick = elapsed;

    final minExtent = _scrollController.position.minScrollExtent;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final diff = _targetOffset - currentOffset;

    if (diff.abs() < 0.5) {
      _scrollController.jumpTo(_targetOffset.clamp(minExtent, maxExtent));
      _stopSmoothScroll();
      return;
    }

    final durationSeconds =
        widget.config.animationDuration.inMicroseconds / 1000000.0;
    if (durationSeconds <= 0) {
      _scrollController.jumpTo(_targetOffset.clamp(minExtent, maxExtent));
      _stopSmoothScroll();
      return;
    }

    final tau = durationSeconds / 3;
    final smoothing = 1 - math.exp(-(dtMicros / 1000000.0) / tau);
    final nextOffset = currentOffset + diff * smoothing;
    _scrollController.jumpTo(nextOffset.clamp(minExtent, maxExtent));
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      double delta;
      if (widget.scrollDirection == Axis.vertical) {
        delta = event.scrollDelta.dy;
      } else {
        delta = event.scrollDelta.dx;
      }

      delta *= widget.config.scrollSpeed * widget.config.wheelSensitivity;

      final isTrackpad = event.kind == PointerDeviceKind.trackpad;
      final currentOffset = _scrollController.offset;
      final baseOffset = isTrackpad ? currentOffset : (_isAnimating ? _targetOffset : currentOffset);

      _targetOffset = (baseOffset + delta).clamp(
        _scrollController.position.minScrollExtent,
        _scrollController.position.maxScrollExtent,
      );

      if (isTrackpad) {
        _stopSmoothScroll();
        _scrollController.jumpTo(_targetOffset);
        return;
      }

      _startSmoothScroll();
    }
  }

  void _startSmoothScroll() {
    if (!_scrollController.hasClients) return;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    _isAnimating = true;
  }

  void _stopSmoothScroll() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _isAnimating = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: widget.padding,
        scrollDirection: widget.scrollDirection,
        physics: const NeverScrollableScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}
