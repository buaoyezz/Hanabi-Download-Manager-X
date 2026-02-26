class NsfxConfig {
  int threads;
  int? segments;
  String mode;
  int maxConcurrentTasks;
  int segmentSpeedLimit;
  int globalSpeedLimit; // 全局带宽限制（bytes/s），0 = 不限速
  String conflictStrategy;
  NsfxProxyConfig proxy;

  // 高级配置
  int chunkSize;
  int connectionTimeout;
  int readTimeout;
  int maxRetries;
  bool enableDynamicSegments;

  NsfxConfig({
    this.threads = 8,
    this.segments,
    this.mode = 'auto',
    this.maxConcurrentTasks = 3,
    this.segmentSpeedLimit = 0,
    this.globalSpeedLimit = 0,
    this.conflictStrategy = 'increment',
    NsfxProxyConfig? proxy,
    this.chunkSize = 1024 * 1024,
    this.connectionTimeout = 30,
    this.readTimeout = 120,
    this.maxRetries = 500, // 大量重试次数，应对极端网络（配合外层无限循环）
    this.enableDynamicSegments = true,
  }) : proxy = proxy ?? NsfxProxyConfig();

  Map<String, dynamic> toJson() => {
    'threads': threads,
    'segments': segments,
    'mode': mode,
    'max_concurrent_tasks': maxConcurrentTasks,
    'segment_speed_limit': segmentSpeedLimit,
    'global_speed_limit': globalSpeedLimit,
    'conflict_strategy': conflictStrategy,
    'proxy': proxy.toJson(),
    'chunk_size': chunkSize,
    'connection_timeout': connectionTimeout,
    'read_timeout': readTimeout,
    'max_retries': maxRetries,
    'enable_dynamic_segments': enableDynamicSegments,
  };

  factory NsfxConfig.fromJson(Map<String, dynamic> json) => NsfxConfig(
    threads: json['threads'] ?? 8,
    segments: json['segments'],
    mode: json['mode'] ?? 'auto',
    maxConcurrentTasks: json['max_concurrent_tasks'] ?? json['maxConcurrentTasks'] ?? 3,
    segmentSpeedLimit: json['segment_speed_limit'] ?? json['segmentSpeedLimit'] ?? 0,
    globalSpeedLimit: json['global_speed_limit'] ?? json['globalSpeedLimit'] ?? 0,
    conflictStrategy: json['conflict_strategy'] ?? json['conflictStrategy'] ?? 'increment',
    proxy: json['proxy'] != null ? NsfxProxyConfig.fromJson(json['proxy']) : null,
    chunkSize: json['chunk_size'] ?? json['chunkSize'] ?? 1024 * 1024,
    connectionTimeout: json['connection_timeout'] ?? json['connectionTimeout'] ?? 30,
    readTimeout: json['read_timeout'] ?? json['readTimeout'] ?? 120,
    maxRetries: json['max_retries'] ?? json['maxRetries'] ?? 500, // 大量重试
    enableDynamicSegments: json['enable_dynamic_segments'] ?? json['enableDynamicSegments'] ?? true,
  );
}

class NsfxProxyConfig {
  bool enabled;
  String type;
  String host;
  int port;
  String? username;
  String? password;
  bool requiresAuth;

  NsfxProxyConfig({
    this.enabled = true,
    this.type = 'system',
    this.host = '127.0.0.1',
    this.port = 7897,
    this.username,
    this.password,
    this.requiresAuth = false,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'type': type,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'requires_auth': requiresAuth,
  };

  factory NsfxProxyConfig.fromJson(Map<String, dynamic> json) => NsfxProxyConfig(
    enabled: json['enabled'] ?? false,
    type: json['type'] ?? 'system',
    host: json['host'] ?? '',
    port: json['port'] ?? 7897,
    username: json['username'],
    password: json['password'],
    requiresAuth: json['requires_auth'] ?? json['requiresAuth'] ?? false,
  );

  String? toProxyUrl() {
    if (!enabled || type == 'system') return null;
    if (host.isEmpty) return null;

    final auth = requiresAuth && username != null && password != null
        ? '$username:$password@'
        : '';
    return '$type://$auth$host:$port';
  }
}

class DynamicSegmentConfig {
  // 保守策略：每个分段至少 5MB，保证稳定性
  static const int _minSegmentSize = 5 * 1024 * 1024;
  // 最大分段数上限 32（不再是 64）
  static const int _maxSegments = 32;

  /// 计算下载分段和线程数
  ///
  /// 设计原则：
  /// - 稳定优先：分段数保守，避免过多连接导致服务器拒绝
  /// - 线程 ≠ 分段：segments 是文件切割数，threads 是并发连接数
  /// - threads 由 config.threads 控制上限，不超过 segments
  static (int threads, int segments) calculate(int fileSize, NsfxConfig config) {
    const mb = 1024 * 1024;
    final maxThreads = config.threads.clamp(1, 64);

    // ── manual: 用户完全控制 ──
    if (config.mode == 'manual') {
      final segs = (config.segments ?? config.threads).clamp(1, 256);
      return (config.threads.clamp(1, segs), segs);
    }

    // ── threads_only: 用户指定线程，分段 = 线程 ──
    if (config.mode == 'threads_only') {
      final segs = config.threads.clamp(1, _maxSegments);
      return (config.threads, segs);
    }

    // ── segments_only: 用户指定分段，线程自适应 ──
    if (config.mode == 'segments_only') {
      final segs = (config.segments ?? 16).clamp(1, 256);
      final threads = maxThreads.clamp(1, segs);
      return (threads, segs);
    }

    // ── auto mode: 保守稳定策略 ──
    int segs;

    if (fileSize <= 0) {
      // 未知大小，单线程
      return (1, 1);
    } else if (fileSize < 5 * mb) {
      // < 5MB: 小文件，不分段
      segs = 1;
    } else if (fileSize < 20 * mb) {
      // 5-20MB: 轻度分段
      segs = 2;
    } else if (fileSize < 50 * mb) {
      // 20-50MB: 适度分段
      segs = 4;
    } else if (fileSize < 200 * mb) {
      // 50-200MB: 标准分段
      segs = 8;
    } else if (fileSize < 500 * mb) {
      // 200-500MB: 较多分段
      segs = 12;
    } else if (fileSize < 1024 * mb) {
      // 500MB-1GB: 中高分段
      segs = 16;
    } else if (fileSize < 2048 * mb) {
      // 1-2GB: 高分段
      segs = 20;
    } else {
      // ≥ 2GB: 最大分段
      segs = 24;
    }

    // 动态分段开启时，可根据每段大小微调
    if (config.enableDynamicSegments && segs > 1) {
      final segSize = fileSize ~/ segs;
      // 如果每段太小（< 5MB），减少分段数
      if (segSize < _minSegmentSize) {
        segs = (fileSize ~/ _minSegmentSize).clamp(1, segs);
      }
    }

    segs = segs.clamp(1, _maxSegments);
    final threads = maxThreads.clamp(1, segs);
    return (threads, segs);
  }
}
