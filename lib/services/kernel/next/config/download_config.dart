class NsfxHttpVersionPolicy {
  static const String auto = 'auto';
  static const String http1Only = 'http1_only';
  static const String http2Only = 'http2_only';
  static const String http3Only = 'http3_only';

  static bool isSupported(String? value) {
    return value == auto ||
        value == http1Only ||
        value == http2Only ||
        value == http3Only;
  }

  static String normalize(String? value) {
    if (isSupported(value)) return value!;
    return auto;
  }

  static bool isSupportedByDartIo(String? value) {
    return normalize(value) != http3Only;
  }

  /// Generic fallback order for protocol policies.
  ///
  /// Keep strict preference first, then gracefully degrade.
  static List<String> fallbackChain(String? value) {
    final normalized = normalize(value);

    switch (normalized) {
      case http3Only:
        return const [http3Only, http2Only, http1Only];
      case http2Only:
        return const [http2Only, http1Only];
      case http1Only:
        return const [http1Only];
      case auto:
      default:
        return const [http1Only, http2Only, http3Only];
    }
  }

  static List<String> preferredChainForUrl(
    String? value, {
    String? url,
  }) {
    final normalized = normalize(value);
    final scheme = Uri.tryParse(url ?? '')?.scheme.toLowerCase();

    if (scheme == 'http') {
      return const [http1Only];
    }

    if (normalized == auto) {
      return fallbackChain(auto);
    }

    return fallbackChain(normalized);
  }

  /// Returns protocol fallback order for current dart:io transport.
  ///
  /// dart:io currently has no HTTP/3 transport, so `http3_only` should
  /// explicitly downgrade to `http2_only` first, then `http1_only`.
  static List<String> fallbackChainForDartIo(String? value) {
    final normalized = normalize(value);

    switch (normalized) {
      case http3Only:
        return const [http2Only, http1Only];
      case http2Only:
        return const [http2Only, http1Only];
      case http1Only:
        return const [http1Only];
      case auto:
      default:
        return const [http1Only, http2Only];
    }
  }

  static String normalizeForDartIo(String? value) {
    return fallbackChainForDartIo(value).first;
  }
}

class NsfxConfig {
  static const String defaultUserAgentFallback =
      'NSFX/2.0 (Next Speed Force X)';

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
  String defaultUserAgent;
  String httpVersionPolicy;

  /// When true, TLS certificate verification is disabled (compatibility mode).
  bool allowInsecureTls;

  /// Max concurrent segment connections across all active tasks.
  int globalMaxConnections;

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
    this.maxRetries = NsfxRetryPolicy.defaultMaxRetries,
    this.enableDynamicSegments = true,
    this.defaultUserAgent = defaultUserAgentFallback,
    this.httpVersionPolicy = NsfxHttpVersionPolicy.auto,
    this.allowInsecureTls = false,
    this.globalMaxConnections =
        NsfxConnectionBudget.defaultGlobalMaxConnections,
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
        'default_user_agent': defaultUserAgent,
        'http_version_policy':
            NsfxHttpVersionPolicy.normalize(httpVersionPolicy),
        'allow_insecure_tls': allowInsecureTls,
        'global_max_connections': globalMaxConnections,
      };

  factory NsfxConfig.fromJson(Map<String, dynamic> json) => NsfxConfig(
        threads: json['threads'] ?? 8,
        segments: json['segments'],
        mode: json['mode'] ?? 'auto',
        maxConcurrentTasks:
            json['max_concurrent_tasks'] ?? json['maxConcurrentTasks'] ?? 3,
        segmentSpeedLimit:
            json['segment_speed_limit'] ?? json['segmentSpeedLimit'] ?? 0,
        globalSpeedLimit:
            json['global_speed_limit'] ?? json['globalSpeedLimit'] ?? 0,
        conflictStrategy: json['conflict_strategy'] ??
            json['conflictStrategy'] ??
            'increment',
        proxy: json['proxy'] != null
            ? NsfxProxyConfig.fromJson(json['proxy'])
            : null,
        chunkSize: json['chunk_size'] ?? json['chunkSize'] ?? 1024 * 1024,
        connectionTimeout:
            json['connection_timeout'] ?? json['connectionTimeout'] ?? 30,
        readTimeout: json['read_timeout'] ?? json['readTimeout'] ?? 120,
        maxRetries: json['max_retries'] ??
            json['maxRetries'] ??
            NsfxRetryPolicy.defaultMaxRetries,
        enableDynamicSegments: json['enable_dynamic_segments'] ??
            json['enableDynamicSegments'] ??
            true,
        defaultUserAgent: (() {
          final value = (json['default_user_agent'] ??
                  json['defaultUserAgent'] ??
                  defaultUserAgentFallback)
              .toString()
              .trim();
          return value.isEmpty ? defaultUserAgentFallback : value;
        })(),
        httpVersionPolicy: NsfxHttpVersionPolicy.normalize(
          (json['http_version_policy'] ?? json['httpVersionPolicy'])
              ?.toString(),
        ),
        allowInsecureTls:
            json['allow_insecure_tls'] ?? json['allowInsecureTls'] ?? false,
        globalMaxConnections: json['global_max_connections'] ??
            json['globalMaxConnections'] ??
            NsfxConnectionBudget.defaultGlobalMaxConnections,
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

  factory NsfxProxyConfig.fromJson(Map<String, dynamic> json) =>
      NsfxProxyConfig(
        enabled: json['enabled'] ?? false,
        type: json['type'] ?? 'system',
        host: json['host'] ?? '',
        port: json['port'] ?? 7897,
        username: json['username'],
        password: json['password'],
        requiresAuth: json['requires_auth'] ?? json['requiresAuth'] ?? false,
      );

  bool get looksLikeLegacyImplicitSystemProxyDefault {
    final normalizedHost = host.trim().toLowerCase();
    final normalizedUser = username?.trim() ?? '';
    final normalizedPassword = password?.trim() ?? '';

    return enabled &&
        type == 'system' &&
        normalizedHost == '127.0.0.1' &&
        port == 7897 &&
        !requiresAuth &&
        normalizedUser.isEmpty &&
        normalizedPassword.isEmpty;
  }

  String? toProxyUrl() {
    if (!enabled || type == 'system') return null;
    if (host.isEmpty) return null;

    final auth = requiresAuth && username != null && password != null
        ? '$username:$password@'
        : '';
    return '$type://$auth$host:$port';
  }
}

class NsfxParallelDownloadPolicy {
  /// Parallel resume decisions are split across current runtime state,
  /// reloaded persisted state, explicit validators, and previously verified
  /// stable range behavior without validators.
  static String? parallelBlockReason({
    required String url,
    required bool hasStrongValidator,
    required bool hasPartialProgress,
    required String resumeDataOrigin,
    required String resumeSafetyLevel,
    required bool supportsRange,
    int? storedTotalSize,
    int? observedTotalSize,
  }) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return 'URL scheme is not HTTP(S)';
    }
    if (!hasPartialProgress) {
      return null;
    }
    if (!supportsRange) {
      return 'server does not support byte ranges for resume';
    }
    if (hasStrongValidator) {
      return null;
    }

    final origin = NsfxResumeDataOrigin.normalize(resumeDataOrigin);
    if (origin == NsfxResumeDataOrigin.runtime) {
      return null;
    }

    final normalizedSafety = NsfxResumeSafetyLevel.normalize(resumeSafetyLevel);
    final expectedSize = storedTotalSize ?? 0;
    final currentSize = observedTotalSize ?? 0;

    if (expectedSize <= 0 || currentSize <= 0) {
      return 'cannot verify persisted multi-part resume without both stored '
          'and current file size';
    }
    if (expectedSize != currentSize) {
      return 'stored file size no longer matches remote resource';
    }
    if (normalizedSafety != NsfxResumeSafetyLevel.verifiedNoValidator) {
      return 'cannot safely resume persisted multi-part download without '
          'validator or verified stable range behavior';
    }
    return null;
  }
}

class NsfxResumeDataOrigin {
  static const String runtime = 'runtime';
  static const String persisted = 'persisted';

  static bool isSupported(String? value) {
    return value == runtime || value == persisted;
  }

  static String normalize(String? value) {
    if (isSupported(value)) return value!;
    return runtime;
  }
}

class NsfxResumeSafetyLevel {
  static const String unknown = 'unknown';
  static const String sessionOnly = 'session_only';
  static const String verifiedNoValidator = 'verified_no_validator';
  static const String strictValidator = 'strict_validator';

  static bool isSupported(String? value) {
    return value == unknown ||
        value == sessionOnly ||
        value == verifiedNoValidator ||
        value == strictValidator;
  }

  static String normalize(String? value) {
    if (isSupported(value)) return value!;
    return unknown;
  }
}

class NsfxRetryPolicy {
  static const int defaultMaxRetries = 32;
  static const int maxTransientRetriesPerSegment = 32;
  static const int defaultMaxGlobalRetryRounds = 6;

  /// Deterministic exponential backoff with bounded jitter.
  static int segmentRetryDelayMs(int retryCount) {
    final attempt = retryCount < 1 ? 1 : retryCount;
    final exponent = attempt > 6 ? 5 : attempt - 1;
    final baseDelay = 500 * (1 << exponent);
    final jitter = (attempt * 137) % 250;
    return (baseDelay + jitter).clamp(500, 15000);
  }

  static int effectiveMaxRetries(int configured) {
    final normalized = configured < 1 ? defaultMaxRetries : configured;
    return normalized.clamp(1, maxTransientRetriesPerSegment);
  }
}

class NsfxConnectionBudget {
  static const int defaultGlobalMaxConnections = 32;
  static const int minGlobalMaxConnections = 1;
  static const int maxGlobalMaxConnections = 128;

  static int normalize(int value) {
    if (value < minGlobalMaxConnections) return defaultGlobalMaxConnections;
    return value.clamp(minGlobalMaxConnections, maxGlobalMaxConnections);
  }
}

/// Classifies transfer errors so permanent failures fail fast.
class NsfxErrorClassifier {
  static final RegExp _httpStatusPattern =
      RegExp(r'http(?:exception:)?\s*(\d{3})', caseSensitive: false);

  static const Set<int> permanentHttpStatuses = {
    400,
    401,
    403,
    404,
    405,
    410,
    416,
    451,
  };

  static bool isPermanent(String? errorText) {
    if (errorText == null || errorText.trim().isEmpty) return false;
    final message = errorText.toLowerCase();

    if (message.contains('range_not_supported') ||
        message.contains('range_not_satisfiable') ||
        message.contains('range_response_invalid') ||
        message.contains('certificate_verify_failed') ||
        message.contains('certificate_verify') ||
        message.contains('certificateverifyfailed') ||
        message.contains('handshakeexception') &&
            (message.contains('certificate') || message.contains('ssl'))) {
      return true;
    }

    final match = _httpStatusPattern.firstMatch(message);
    if (match != null) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null && permanentHttpStatuses.contains(code)) {
        return true;
      }
    }

    return false;
  }

  static bool isTransient(String? errorText) {
    if (errorText == null || errorText.trim().isEmpty) return true;
    if (isPermanent(errorText)) return false;
    final message = errorText.toLowerCase();
    return message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('connection reset') ||
        message.contains('connection closed') ||
        message.contains('connection aborted') ||
        message.contains('connection refused') ||
        message.contains('broken pipe') ||
        message.contains('network is unreachable') ||
        message.contains('no route to host') ||
        message.contains('failed host lookup') ||
        message.contains('proxy_error_') ||
        message.contains('http 429') ||
        message.contains('http 502') ||
        message.contains('http 503') ||
        message.contains('http 504') ||
        message.contains('incomplete transfer') ||
        message.contains('unexpected end') ||
        message.contains('temporarily');
  }
}

class NsfxStartupProbePolicy {
  static const int knownSmallFileImmediateTransferLimit = 8 * 1024 * 1024;

  /// Fresh downloads start a real GET immediately and may promote that
  /// response to a segmented transfer after inspecting its headers. Persisted
  /// or runtime partial data stays on the strict metadata path.
  static bool shouldUseFastStart({
    required bool hasPartialProgress,
    required int configuredThreads,
  }) {
    if (hasPartialProgress) {
      return false;
    }
    return configuredThreads > 1;
  }

  static bool shouldStartKnownSizeImmediately(int? expectedSize) {
    return expectedSize != null &&
        expectedSize > 0 &&
        expectedSize <= knownSmallFileImmediateTransferLimit;
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
  static (int threads, int segments) calculate(
      int fileSize, NsfxConfig config) {
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
