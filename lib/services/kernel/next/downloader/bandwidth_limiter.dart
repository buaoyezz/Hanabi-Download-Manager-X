import 'dart:async';

/// 全局带宽限制器 — 令牌桶算法
///
/// 所有下载任务共享同一个限制器实例。
/// 每秒补充 [bytesPerSecond] 个令牌，下载前需要申请令牌。
/// 设为 0 表示不限速。
class GlobalBandwidthLimiter {
  int _bytesPerSecond;
  int _availableTokens;
  Timer? _refillTimer;
  final List<Completer<void>> _waiters = [];

  GlobalBandwidthLimiter({int bytesPerSecond = 0})
      : _bytesPerSecond = bytesPerSecond,
        _availableTokens = bytesPerSecond > 0 ? bytesPerSecond : 0 {
    if (_bytesPerSecond > 0) {
      _startRefill();
    }
  }

  /// 是否启用限速
  bool get isEnabled => _bytesPerSecond > 0;

  /// 当前限速值（bytes/s）
  int get limit => _bytesPerSecond;

  /// 更新限速值（运行时可调）
  void updateLimit(int bytesPerSecond) {
    _bytesPerSecond = bytesPerSecond;
    _refillTimer?.cancel();
    if (_bytesPerSecond > 0) {
      _availableTokens = _bytesPerSecond;
      _startRefill();
    } else {
      _availableTokens = 0;
      // 不限速时，唤醒所有等待者
      _wakeAll();
    }
  }

  /// 申请发送 [bytes] 字节的许可
  ///
  /// 如果不限速，立即返回 [bytes]。
  /// 如果限速，返回实际允许发送的字节数（可能小于请求量）。
  /// 如果当前没有可用令牌，会等待下一次补充。
  Future<int> acquire(int bytes) async {
    if (_bytesPerSecond <= 0) return bytes;

    // 等待直到有可用令牌
    while (_availableTokens <= 0) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
      // 限速可能在等待期间被关闭
      if (_bytesPerSecond <= 0) return bytes;
    }

    // 分配令牌：取请求量和可用量的较小值
    final granted = bytes.clamp(1, _availableTokens);
    _availableTokens -= granted;
    return granted;
  }

  void _startRefill() {
    // 每 100ms 补充 1/10 的令牌，使流量更平滑
    const interval = Duration(milliseconds: 100);
    final refillAmount = (_bytesPerSecond / 10).ceil();

    _refillTimer = Timer.periodic(interval, (_) {
      if (_bytesPerSecond <= 0) return;
      _availableTokens = (_availableTokens + refillAmount).clamp(0, _bytesPerSecond);
      _wakeAll();
    });
  }

  void _wakeAll() {
    final waiters = List<Completer<void>>.from(_waiters);
    _waiters.clear();
    for (final w in waiters) {
      if (!w.isCompleted) w.complete();
    }
  }

  void dispose() {
    _refillTimer?.cancel();
    _wakeAll();
  }
}
