class NsfxConfig {
  int threads;
  int? segments;
  String mode;
  int maxConcurrentTasks;
  int segmentSpeedLimit;
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
    this.enabled = false,
    this.type = 'system',
    this.host = '',
    this.port = 8080,
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
    port: json['port'] ?? 8080,
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
  static const int minSegmentSize = 2 * 1024 * 1024;
  static const int maxSegmentSize = 100 * 1024 * 1024;
  static const int idealSegmentSize = 10 * 1024 * 1024;
  static const int smallFileThreshold = 20 * 1024 * 1024;
  static const int largeFileThreshold = 1024 * 1024 * 1024;

  static (int threads, int segments) calculate(int fileSize, NsfxConfig config) {
    final mb = 1024 * 1024;
    final maxThreads = config.threads.clamp(1, 64);

    if (config.mode == 'manual') {
      return (config.threads, config.segments ?? config.threads);
    }

    if (config.mode == 'threads_only') {
      int segs;
      if (fileSize < 10 * mb) {
        segs = config.threads.clamp(1, 4);
      } else if (fileSize < 50 * mb) {
        segs = config.threads.clamp(1, 8);
      } else if (fileSize < 200 * mb) {
        segs = config.threads.clamp(1, 16);
      } else {
        segs = config.threads;
      }
      return (config.threads, segs);
    }

    if (config.mode == 'segments_only') {
      final segs = config.segments ?? 16;
      int threads;
      if (fileSize < 10 * mb) {
        threads = segs.clamp(1, 4);
      } else if (fileSize < 50 * mb) {
        threads = segs.clamp(1, 8);
      } else {
        threads = segs;
      }
      return (threads, segs);
    }

    // auto mode
    if (!config.enableDynamicSegments) {
      int segs;
      if (fileSize < 5 * mb) {
        segs = 1;
      } else if (fileSize < 10 * mb) {
        segs = 4;
      } else if (fileSize < 30 * mb) {
        segs = 8;
      } else if (fileSize < 100 * mb) {
        segs = 16;
      } else if (fileSize < 300 * mb) {
        segs = 24;
      } else {
        segs = 32;
      }
      final threads = maxThreads.clamp(1, segs);
      return (threads, segs);
    }

    // dynamic segments
    if (fileSize < smallFileThreshold) {
      final segs = (fileSize ~/ (5 * mb)).clamp(1, 8);
      final threads = maxThreads.clamp(1, segs);
      return (threads, segs);
    }

    var idealSegs = fileSize ~/ idealSegmentSize;
    var minSegs = 8;
    var maxSegs = 64;

    if (fileSize >= largeFileThreshold) {
      minSegs = 32;
    }

    var segs = idealSegs.clamp(minSegs, maxSegs);

    final segSize = fileSize ~/ segs;
    if (segSize < minSegmentSize) {
      segs = (fileSize ~/ minSegmentSize).clamp(1, maxSegs);
    }
    if (segSize > maxSegmentSize) {
      segs = (fileSize ~/ maxSegmentSize).clamp(minSegs, maxSegs);
    }

    final threads = maxThreads.clamp(1, segs);
    return (threads, segs);
  }
}
