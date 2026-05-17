import 'dart:async';
import 'dart:io';
import 'package:rhttp/rhttp.dart' as rhttp;

import '../config/download_config.dart';
import '../../../app_logger_service.dart';
import 'proxy_runtime.dart';

class NsfxHttpConnectionType {
  static const String http1 = 'http1';
  static const String http2 = 'http2';
  static const String quic = 'quic';
  static const String unknown = 'unknown';
}

class NsfxHttpClient {
  static const Duration _fileInfoProbeDeadline = Duration(seconds: 5);
  static const Duration _strictProbeTimeoutCap = Duration(milliseconds: 900);

  final NsfxConfig config;
  final Duration adaptiveStatusHintTtl;
  final Duration adaptiveTransportHintTtl;
  final Duration adaptiveTimeoutHintTtl;
  HttpClient? _client;
  Future<HttpClient>? _clientFuture;
  final _logger = AppLoggerService();
  final List<String> _httpPolicyFallbackChain;
  int _httpPolicyIndex = 0;
  String? _adaptivePolicyHost;
  static Future<void>? _rhttpInitFuture;
  static final Map<String, _AdaptiveHostStrategyHint> _adaptivePolicyHints = {};
  static const Duration _defaultConcurrencyHintTtl = Duration(minutes: 45);
  static final RegExp _httpStatusCodePattern =
      RegExp(r'http(?:exception:)?\s*(\d{3})', caseSensitive: false);
  static const Set<String> _hopByHopHeaders = {
    'connection',
    'keep-alive',
    'proxy-connection',
    'transfer-encoding',
    'upgrade',
  };

  String? _lastNegotiatedHttpVersion;
  String? _lastPolicyDecisionReason;
  String? _activeRequestUrl;
  NsfxResolvedProxy _lastResolvedProxy = const NsfxResolvedProxy.direct();

  NsfxHttpClient(
    this.config, {
    this.adaptiveStatusHintTtl = const Duration(minutes: 10),
    this.adaptiveTransportHintTtl = const Duration(minutes: 30),
    this.adaptiveTimeoutHintTtl = const Duration(minutes: 15),
  }) : _httpPolicyFallbackChain = List<String>.from(
          NsfxHttpVersionPolicy.preferredChainForUrl(
            config.httpVersionPolicy,
          ),
        );

  static void clearAdaptivePolicyHints() {
    _adaptivePolicyHints.clear();
  }

  static Map<String, dynamic> exportAdaptiveHostStrategies() {
    final now = DateTime.now();
    final json = <String, dynamic>{};

    _adaptivePolicyHints.removeWhere((host, hint) {
      final sanitized = hint.sanitized(now);
      if (sanitized == null) {
        return true;
      }
      json[host] = sanitized.toJson();
      return false;
    });

    return json;
  }

  static void restoreAdaptiveHostStrategies(Map<String, dynamic>? json) {
    _adaptivePolicyHints.clear();
    if (json == null || json.isEmpty) return;

    final now = DateTime.now();
    for (final entry in json.entries) {
      if (entry.value is! Map<String, dynamic>) {
        continue;
      }
      final hint = _AdaptiveHostStrategyHint.fromJson(entry.value, now);
      if (hint != null) {
        _adaptivePolicyHints[entry.key] = hint;
      }
    }
  }

  static int suggestedMaxConcurrencyForUrl(
    String url, {
    required int requested,
  }) {
    final host = _extractHost(url);
    if (host == null) return requested;

    final now = DateTime.now();
    final hint = _adaptivePolicyHints[host];
    final maxConcurrency = hint?.maxConcurrencyFor(now);
    if (hint != null && hint.sanitized(now) == null) {
      _adaptivePolicyHints.remove(host);
    }
    if (maxConcurrency == null) {
      return requested;
    }
    final boundedRequested = requested.clamp(1, 64);
    return boundedRequested <= maxConcurrency
        ? boundedRequested
        : maxConcurrency;
  }

  static void rememberHostConcurrencyCap(
    String url,
    int maxConcurrency, {
    Duration ttl = _defaultConcurrencyHintTtl,
  }) {
    final host = _extractHost(url);
    if (host == null) return;

    final boundedConcurrency = maxConcurrency.clamp(1, 64);
    final now = DateTime.now();
    final candidate = _AdaptiveHostStrategyHint(
      maxConcurrency: boundedConcurrency,
      maxConcurrencyExpiresAt: now.add(ttl),
    );
    final existing = _adaptivePolicyHints[host];
    _adaptivePolicyHints[host] =
        (existing ?? const _AdaptiveHostStrategyHint()).merge(candidate, now);
  }

  static void clearSharedProxyState() {
    NsfxProxyRuntime.clearBadProxies();
  }

  static void compactSharedCaches() {
    NsfxProxyRuntime.compactCaches();
  }

  static HttpClient createRawHttpClient({
    required String httpVersionPolicy,
    Duration? connectionTimeout,
    Duration? idleTimeout,
    int? maxConnectionsPerHost,
    bool autoUncompress = false,
    String? userAgent,
  }) {
    final normalizedPolicy =
        NsfxHttpVersionPolicy.fallbackChainForDartIo(httpVersionPolicy).first;
    HttpClient client;

    if (normalizedPolicy == NsfxHttpVersionPolicy.auto) {
      client = HttpClient();
    } else {
      try {
        final context = SecurityContext(withTrustedRoots: true);
        context.setAlpnProtocols(
          normalizedPolicy == NsfxHttpVersionPolicy.http2Only
              ? const ['h2']
              : const ['http/1.1'],
          false,
        );
        client = HttpClient(context: context);
      } catch (_) {
        client = HttpClient();
      }
    }

    if (connectionTimeout != null) {
      client.connectionTimeout = connectionTimeout;
    }
    if (idleTimeout != null) {
      client.idleTimeout = idleTimeout;
    }
    if (maxConnectionsPerHost != null) {
      client.maxConnectionsPerHost = maxConnectionsPerHost;
    }
    client.autoUncompress = autoUncompress;
    client.badCertificateCallback = (cert, host, port) => true;

    final normalizedAgent = (userAgent ?? '').trim();
    if (normalizedAgent.isNotEmpty) {
      client.userAgent = normalizedAgent;
    }

    return client;
  }

  String get _activeHttpPolicy => _httpPolicyFallbackChain[_httpPolicyIndex];
  String get effectiveHttpVersionPolicy => _activeHttpPolicy;
  String? get lastNegotiatedHttpVersion => _lastNegotiatedHttpVersion;
  String? get lastPolicyDecisionReason => _lastPolicyDecisionReason;

  void adoptAdaptivePolicyHint(String url) {
    _activeRequestUrl = url;
    _refreshHttpPolicyChainForUrl(url);
    final host = _extractHost(url);
    if (host == null || host == _adaptivePolicyHost) {
      return;
    }

    final hintedPolicy = _hintedPolicyForHost(host);
    final nextIndex = hintedPolicy == null
        ? 0
        : _httpPolicyFallbackChain.indexOf(hintedPolicy);
    final boundedIndex = nextIndex < 0 ? 0 : nextIndex;
    _adaptivePolicyHost = host;

    if (boundedIndex == _httpPolicyIndex) {
      return;
    }

    final fromPolicy = _activeHttpPolicy;
    _applyHttpPolicyIndex(boundedIndex);
    _lastPolicyDecisionReason = 'Cached host policy reused for $host: '
        '${_formatHttpPolicyDisplay(fromPolicy)} -> '
        '${_formatHttpPolicyDisplay(_activeHttpPolicy)} after previous strict '
        'transport failures on this host.';
    _logger.info(
      'NSFX-HTTP',
      'Adaptive HTTP policy hint applied for $host: '
          '$fromPolicy -> $_activeHttpPolicy',
    );
  }

  static String? normalizeNegotiatedHttpVersion(String? policy) {
    final normalizedPolicy = NsfxHttpVersionPolicy.normalize(policy);
    switch (normalizedPolicy) {
      case NsfxHttpVersionPolicy.http3Only:
        return 'http3';
      case NsfxHttpVersionPolicy.http2Only:
        return 'http2';
      case NsfxHttpVersionPolicy.http1Only:
        return 'http1_1';
      case NsfxHttpVersionPolicy.auto:
      default:
        return null;
    }
  }

  static String? normalizeObservedHttpVersion(String? rawVersion) {
    final raw = (rawVersion ?? '').trim().toLowerCase();
    if (raw.isEmpty) {
      return null;
    }

    final normalized = raw.replaceAll('-', '_');
    switch (normalized) {
      case 'http/0.9':
      case 'http09':
      case 'http0_9':
      case '0.9':
        return 'http0_9';
      case 'http/1.0':
      case 'http10':
      case 'http1_0':
      case '1.0':
        return 'http1_0';
      case 'http/1.1':
      case 'http11':
      case 'http1_1':
      case 'http1':
      case '1.1':
        return 'http1_1';
      case 'http/2':
      case 'http2':
      case 'h2':
      case '2':
      case '2.0':
        return 'http2';
      case 'http/3':
      case 'http3':
      case 'h3':
      case '3':
      case '3.0':
        return 'http3';
      case 'other':
        return 'other';
      default:
        return null;
    }
  }

  static String coarseConnectionTypeForVersion(String? rawVersion) {
    switch (normalizeObservedHttpVersion(rawVersion)) {
      case 'http1_0':
      case 'http1_1':
        return NsfxHttpConnectionType.http1;
      case 'http2':
        return NsfxHttpConnectionType.http2;
      case 'http3':
        return NsfxHttpConnectionType.quic;
      case 'http0_9':
      case 'other':
      case null:
        return NsfxHttpConnectionType.unknown;
      default:
        return NsfxHttpConnectionType.unknown;
    }
  }

  static String? extractStrongEtag(String? rawHeader) {
    final normalized = rawHeader?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized.startsWith('W/') || normalized.startsWith('w/')) {
      return null;
    }
    return normalized;
  }

  static String? normalizeHttpValidatorValue(String? rawHeader) {
    final normalized =
        rawHeader?.replaceAll(RegExp(r'[\r\n]+'), ' ').trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static String? selectIfRangeValidator({
    String? etag,
    String? lastModified,
  }) {
    return extractStrongEtag(etag) ?? normalizeHttpValidatorValue(lastModified);
  }

  String? _activeNegotiatedHttpVersion() {
    return normalizeNegotiatedHttpVersion(_activeHttpPolicy);
  }

  String? _rememberNegotiatedHttpVersion(String? value) {
    final normalized = normalizeObservedHttpVersion(value);
    if (normalized == null || normalized.isEmpty) {
      return _lastNegotiatedHttpVersion;
    }
    _lastNegotiatedHttpVersion = normalized;
    return _lastNegotiatedHttpVersion;
  }

  String? _markActivePolicyAsNegotiated() {
    return _rememberNegotiatedHttpVersion(_activeNegotiatedHttpVersion());
  }

  Future<HttpClient> _buildClient({
    Duration? connectionTimeout,
    Duration? idleTimeout,
    int? maxConnectionsPerHost,
    bool autoUncompress = false,
    NsfxResolvedProxy? proxy,
  }) {
    final httpClient = createRawHttpClient(
      httpVersionPolicy: _activeHttpPolicy,
      connectionTimeout: connectionTimeout,
      idleTimeout: idleTimeout,
      maxConnectionsPerHost: maxConnectionsPerHost,
      autoUncompress: autoUncompress,
      userAgent: config.defaultUserAgent,
    );

    _applyProxy(httpClient, proxy: proxy);
    return Future<HttpClient>.value(httpClient);
  }

  NsfxResolvedProxy _resolveProxyForUrl(String? url) {
    final candidateUrl = (url ?? _activeRequestUrl ?? '').trim();
    if (candidateUrl.isNotEmpty) {
      _activeRequestUrl = candidateUrl;
    }
    final uri = Uri.tryParse(candidateUrl);
    final resolved = uri == null
        ? NsfxProxyRuntime.configuredFromNextConfig(config.proxy)
        : NsfxProxyRuntime.resolveFromNextConfig(config.proxy, uri);
    _lastResolvedProxy = resolved;
    return resolved;
  }

  Future<HttpClient> _createClient() async {
    final requestedPolicy =
        NsfxHttpVersionPolicy.normalize(config.httpVersionPolicy);
    final activePolicy = _activeHttpPolicy;
    final proxy = _resolveProxyForUrl(_activeRequestUrl);

    // Balance responsiveness and slow-server compatibility.
    final httpClient = await _buildClient(
      connectionTimeout:
          Duration(seconds: config.connectionTimeout.clamp(5, 30)),
      idleTimeout: const Duration(seconds: 30),
      maxConnectionsPerHost: 128,
      autoUncompress: false,
      proxy: proxy,
    );

    if (proxy.hasProxy) {
      if (proxy.usesSystemSettings) {
        _logger.info('NSFX-HTTP', 'Using system proxy settings');
      } else {
        _logger.info('NSFX-HTTP',
            'Using proxy: ${proxy.type} ${proxy.host}:${proxy.port}');
      }
    }
    if (requestedPolicy != activePolicy) {
      _logger.warning(
        'NSFX-HTTP',
        'HTTP policy fallback chain activated: '
            'requested=$requestedPolicy, active=$activePolicy, '
            'chain=${_httpPolicyFallbackChain.join(' -> ')}',
      );
    }
    _logger.info('NSFX-HTTP', 'HTTP policy active: $activePolicy');

    return httpClient;
  }

  Future<HttpClient> _ensureClient() async {
    final existing = _client;
    if (existing != null) return existing;

    final pending = _clientFuture;
    if (pending != null) return pending;

    final creation = _createClient();
    _clientFuture = creation;

    try {
      final client = await creation;
      _client = client;
      return client;
    } finally {
      if (identical(_clientFuture, creation)) {
        _clientFuture = null;
      }
    }
  }

  /// Probe file info with browser-like strategy and bounded total timeout.
  /// Falls back to direct mode only on explicit proxy errors.
  Future<FileInfo> getFileInfo(
    String url,
    Map<String, String> headers, {
    Duration? probeDeadline,
    Duration? strictProbeTimeoutCap,
  }) async {
    adoptAdaptivePolicyHint(url);
    final result = await _getFileInfoInternal(
      url,
      headers,
      probeDeadline: probeDeadline,
      strictProbeTimeoutCap: strictProbeTimeoutCap,
    );

    // Do not fallback merely because size is unknown (chunked/streaming can be valid).
    if (result.proxyError && _isProxyEnabled) {
      _logger.warning(
        'NSFX-HTTP',
        'Proxy probe failed (proxyError=${result.proxyError}), falling back to direct connection',
      );
      _switchToDirectConnection();
      return _getFileInfoInternal(
        url,
        headers,
        probeDeadline: probeDeadline,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
    }

    return result;
  }

  bool get _isProxyEnabled => _lastResolvedProxy.hasProxy;

  void _switchToDirectConnection() {
    final failedProxy = _lastResolvedProxy;
    NsfxProxyRuntime.markProxyFailure(failedProxy);
    _client?.close(force: true);
    _client = null;
    _clientFuture = null;
    _lastNegotiatedHttpVersion = null;

    final nextProxy = _activeRequestUrl == null
        ? const NsfxResolvedProxy.direct()
        : _resolveProxyForUrl(_activeRequestUrl);

    if (nextProxy.hasProxy) {
      _logger.info(
        'NSFX-HTTP',
        'Marked proxy as bad and rotated connection: '
            '${failedProxy.displayLabel ?? failedProxy.identity} -> '
            '${nextProxy.displayLabel ?? nextProxy.identity}',
      );
      return;
    }

    _lastResolvedProxy = const NsfxResolvedProxy.direct();
    _logger.info('NSFX-HTTP', 'Switched to direct connection (proxy bypassed)');
  }

  void switchToDirectOnProxyError() {
    if (!_lastResolvedProxy.hasProxy) return;
    _logger.warning('NSFX-HTTP',
        'Proxy error during download, switching to direct connection');
    _switchToDirectConnection();
  }

  /// External hook for callers (e.g. download isolate loop) to decide whether
  /// a transport error should trigger one-time direct fallback.
  bool shouldSwitchToDirectOnError(Object error) {
    return _isProxyTransportError(error);
  }

  bool _shouldUseRhttpTransport(String policy) {
    return policy == NsfxHttpVersionPolicy.http2Only ||
        policy == NsfxHttpVersionPolicy.http3Only;
  }

  static Future<void> _ensureRhttpInitialized() {
    final existing = _rhttpInitFuture;
    if (existing != null) return existing;

    final initFuture = rhttp.Rhttp.init();
    _rhttpInitFuture = initFuture;
    return initFuture.catchError((error) {
      if (identical(_rhttpInitFuture, initFuture)) {
        _rhttpInitFuture = null;
      }
      throw error;
    });
  }

  rhttp.ClientSettings _buildRhttpSettings({
    Duration? connectionTimeout,
    Duration? idleTimeout,
    NsfxResolvedProxy? proxy,
  }) {
    final versionPref = switch (_activeHttpPolicy) {
      NsfxHttpVersionPolicy.http1Only => rhttp.HttpVersionPref.http1_1,
      NsfxHttpVersionPolicy.http2Only => rhttp.HttpVersionPref.http2,
      NsfxHttpVersionPolicy.http3Only => rhttp.HttpVersionPref.http3,
      _ => rhttp.HttpVersionPref.all,
    };

    final proxySettings = NsfxProxyRuntime.toRhttpProxySettings(
      proxy ?? _resolveProxyForUrl(_activeRequestUrl),
    );
    final userAgent = (config.defaultUserAgent).trim();

    return rhttp.ClientSettings(
      httpVersionPref: versionPref,
      throwOnStatusCode: false,
      timeoutSettings: rhttp.TimeoutSettings(
        connectTimeout: connectionTimeout,
        keepAliveTimeout: idleTimeout,
      ),
      tlsSettings: const rhttp.TlsSettings(
        verifyCertificates: false,
      ),
      proxySettings: proxySettings,
      userAgent: userAgent.isEmpty ? null : userAgent,
    );
  }

  Future<_RequestResponse> _sendRhttpRequest({
    required String url,
    required Map<String, String> headers,
    required rhttp.HttpMethod method,
    int? start,
    int? end,
    Duration? connectionTimeout,
    Duration? idleTimeout,
    Duration? headerTimeout,
    NsfxResolvedProxy? proxy,
  }) async {
    await _ensureRhttpInitialized();

    final requestHeaders = Map<String, String>.from(
      _sanitizeHeadersForActivePolicy(headers),
    );
    if (start != null) {
      requestHeaders['Range'] =
          end != null ? 'bytes=$start-${end - 1}' : 'bytes=$start-';
    }

    final responseFuture = rhttp.Rhttp.requestStream(
      settings: _buildRhttpSettings(
        connectionTimeout: connectionTimeout,
        idleTimeout: idleTimeout,
        proxy: proxy ?? _resolveProxyForUrl(url),
      ),
      method: method,
      url: url,
      headers: requestHeaders.isEmpty
          ? null
          : rhttp.HttpHeaders.rawMap(requestHeaders),
    );

    final response = headerTimeout == null
        ? await responseFuture
        : await responseFuture.timeout(headerTimeout);
    final negotiatedHttpVersion =
        _rememberNegotiatedHttpVersion(response.version.name);
    return _RequestResponse(
      response: _RhttpHttpClientResponse.fromRhttp(response),
      negotiatedHttpVersion: negotiatedHttpVersion,
    );
  }

  FileInfo _buildFileInfo({
    required int size,
    required bool supportsRange,
    bool proxyError = false,
    String? negotiatedHttpVersion,
    HttpHeaders? headers,
  }) {
    final normalizedVersion = normalizeObservedHttpVersion(
      negotiatedHttpVersion,
    );
    final etag = extractStrongEtag(headers?.value('etag'));
    final lastModified = normalizeHttpValidatorValue(
      headers?.value('last-modified'),
    );
    return FileInfo(
      size: size,
      supportsRange: supportsRange,
      proxyError: proxyError,
      negotiatedHttpVersion: normalizedVersion,
      connectionType: coarseConnectionTypeForVersion(normalizedVersion),
      etag: etag,
      lastModified: lastModified,
    );
  }

  Future<FileInfo> _getFileInfoInternal(
    String url,
    Map<String, String> headers, {
    Duration? probeDeadline,
    Duration? strictProbeTimeoutCap,
  }) async {
    final effectiveProbeDeadline = probeDeadline ?? _fileInfoProbeDeadline;
    final deadline = DateTime.now().add(effectiveProbeDeadline);

    final rangeResult = await _probeRange(
      url,
      headers,
      deadline,
      'primary',
      strictProbeTimeoutCap: strictProbeTimeoutCap,
    );
    if (rangeResult != null) {
      if (rangeResult.proxyError) return rangeResult;
      // Prefer starting transfer quickly over exhaustively probing metadata.
      // Sites that expose ranged bodies without a reliable total size can still
      // reveal the length on the actual GET path.
      if (rangeResult.size > 0 || rangeResult.supportsRange) {
        if (rangeResult.size == 0 && rangeResult.supportsRange) {
          _logger.info(
            'NSFX-HTTP',
            'Range probe confirmed byte-range support but not total size; '
                'starting transfer with deferred size discovery',
          );
        }
        return rangeResult;
      }
      return rangeResult;
    }

    if (_isDeadlineExceeded(deadline)) {
      _logger.warning('NSFX-HTTP', 'Probe deadline exceeded after Range probe');
      return _buildFileInfo(
        size: 0,
        supportsRange: false,
        negotiatedHttpVersion:
            _lastNegotiatedHttpVersion ?? _activeNegotiatedHttpVersion(),
      );
    }

    final headResult = await _probeHead(
      url,
      headers,
      deadline,
      'fallback',
      strictProbeTimeoutCap: strictProbeTimeoutCap,
    );
    if (headResult != null) {
      if (headResult.size > 0 && !headResult.supportsRange) {
        final verifyRange = await _probeRange(
          url,
          headers,
          deadline,
          'verify_head',
          sizeHint: headResult.size,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
        if (verifyRange != null) {
          return verifyRange;
        }
      }
      return headResult;
    }

    if (_isDeadlineExceeded(deadline)) {
      _logger.warning('NSFX-HTTP', 'Probe deadline exceeded, giving up');
      return _buildFileInfo(
        size: 0,
        supportsRange: false,
        negotiatedHttpVersion:
            _lastNegotiatedHttpVersion ?? _activeNegotiatedHttpVersion(),
      );
    }

    // Full GET probe can be expensive on large files. Keep it as final fallback.
    final getResult = await _probeGet(
      url,
      headers,
      deadline,
      strictProbeTimeoutCap: strictProbeTimeoutCap,
    );
    if (getResult != null) {
      if (getResult.fileInfo.size > 0 && !getResult.fileInfo.supportsRange) {
        final verifyRange = await _probeRange(
          url,
          headers,
          deadline,
          'verify_get',
          sizeHint: getResult.fileInfo.size,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
        if (verifyRange != null) {
          return verifyRange;
        }
      }
      return getResult.fileInfo;
    }

    _logger.warning(
        'NSFX-HTTP', 'Could not determine file info after all strategies');
    return _buildFileInfo(
      size: 0,
      supportsRange: false,
      negotiatedHttpVersion:
          _lastNegotiatedHttpVersion ?? _activeNegotiatedHttpVersion(),
    );
  }

  bool _isDeadlineExceeded(DateTime deadline) =>
      DateTime.now().isAfter(deadline);

  Duration _remainingTime(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return const Duration(milliseconds: 250);
    }
    return remaining < const Duration(milliseconds: 250)
        ? const Duration(milliseconds: 250)
        : remaining;
  }

  Duration _probeTimeout(
    DateTime deadline, {
    Duration? strictProbeTimeoutCap,
  }) {
    var timeout = _remainingTime(deadline);
    // Strict h2/h3 probes should fail fast so fallback can happen quickly.
    final effectiveStrictCap = strictProbeTimeoutCap ?? _strictProbeTimeoutCap;
    if (_shouldUseRhttpTransport(_activeHttpPolicy) &&
        timeout > effectiveStrictCap) {
      timeout = effectiveStrictCap;
    }
    return timeout;
  }

  bool _isNetworkUnreachable(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('errno = 121') ||
        msg.contains('errno = 110') ||
        msg.contains('errno = 111') ||
        msg.contains('errno = 113') ||
        msg.contains('no route to host') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection refused') ||
        msg.contains('no address associated') ||
        msg.contains('name or service not known');
  }

  bool _isProxyErrorStatus(int statusCode) {
    return statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 407 ||
        statusCode == 504 ||
        statusCode == 523 ||
        statusCode == 525;
  }

  bool _isProxyTransportError(Object error) {
    if (!_isProxyEnabled) return false;

    final message = error.toString().toLowerCase();
    final proxy = _lastResolvedProxy;
    final isSystemProxy = proxy.usesSystemSettings;
    final proxyHost = proxy.host.toLowerCase();
    final proxyPort = proxy.port.toString();

    if (message.contains('proxy') ||
        message.contains('tunnel') ||
        message.contains('proxy authentication required') ||
        message.contains('http 407')) {
      return true;
    }

    final maybeNetworkTransportError = message.contains('connection refused') ||
        message.contains('timed out') ||
        message.contains('no route to host') ||
        message.contains('network is unreachable') ||
        message.contains('failed host lookup') ||
        message.contains('connection reset') ||
        message.contains('connection aborted') ||
        message.contains('connection closed');

    if (!maybeNetworkTransportError) return false;

    // In system-proxy mode we don't know host/port in advance, so when a
    // transport-level connect error happens we prefer one-time direct fallback.
    if (isSystemProxy) return true;

    if (proxyHost.isNotEmpty && message.contains(proxyHost)) return true;
    if (proxyPort.isNotEmpty && message.contains(':$proxyPort')) return true;

    return false;
  }

  static bool isHttpProtocolNegotiationError(Object error) {
    if (error is HandshakeException || error is TlsException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('alpn') ||
        message.contains('http/2') ||
        message.contains('http2') ||
        message.contains('http3') ||
        message.contains('quic') ||
        message.contains('invalid request method') ||
        message.contains('connection closed before full header') ||
        message.contains('protocol version') ||
        message.contains('connection terminated during handshake') ||
        message.contains('tls') ||
        message.contains('ssl');
  }

  static bool isStrictTransportConnectionCloseError(Object error) {
    final message = error.toString().toLowerCase();
    final looksLikeRhttpRequestError =
        message.contains('rhttpunknownexception') ||
            message.contains('request::error');
    final looksLikeTransportClose =
        message.contains('source: connectionclosed') ||
            message.contains('connectionclosed(connectionclose') ||
            message.contains('connection close {') ||
            message.contains('connection closed(') ||
            message.contains('code::crypto(') ||
            message.contains('frame_type:');

    return looksLikeRhttpRequestError && looksLikeTransportClose;
  }

  static bool isHttpVersionFallbackEligibleError(
    Object error, {
    required bool usesStrictTransport,
  }) {
    if (!usesStrictTransport) return false;
    final statusCode = extractHttpStatusCode(error);
    if (statusCode != null &&
        isHttpVersionFallbackEligibleStatus(
          statusCode,
          usesStrictTransport: true,
        )) {
      return true;
    }
    return isHttpProtocolNegotiationError(error) ||
        isStrictTransportConnectionCloseError(error) ||
        error is TimeoutException;
  }

  static int? extractHttpStatusCode(Object error) {
    final match = _httpStatusCodePattern.firstMatch(error.toString());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static bool isHttpVersionFallbackEligibleStatus(
    int statusCode, {
    required bool usesStrictTransport,
  }) {
    if (!usesStrictTransport) return false;
    return statusCode == 421 ||
        statusCode == 425 ||
        (statusCode >= 500 && statusCode <= 599);
  }

  bool _shouldFallbackHttpPolicyOnError(Object error) {
    return isHttpVersionFallbackEligibleError(
      error,
      usesStrictTransport: _shouldUseRhttpTransport(_activeHttpPolicy) ||
          _allowsProtocolCandidateAdvance,
    );
  }

  bool _shouldFallbackHttpPolicyOnStatus(int statusCode) {
    return isHttpVersionFallbackEligibleStatus(
      statusCode,
      usesStrictTransport: _shouldUseRhttpTransport(_activeHttpPolicy) ||
          _allowsProtocolCandidateAdvance,
    );
  }

  bool get _allowsProtocolCandidateAdvance {
    return NsfxHttpVersionPolicy.normalize(config.httpVersionPolicy) ==
            NsfxHttpVersionPolicy.auto &&
        _httpPolicyIndex < _httpPolicyFallbackChain.length - 1;
  }

  static bool isResponseBodyDecodingError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('error decoding response body') ||
        message.contains('closestreamexception') ||
        (message.contains('rhttpunknownexception') &&
            message.contains('response body'));
  }

  bool fallbackHttpPolicyOnTransferError(
    Object error, {
    String? url,
  }) {
    if (url != null && url.trim().isNotEmpty) {
      adoptAdaptivePolicyHint(url);
    }
    final isBodyDecodeError = isResponseBodyDecodingError(error);
    final isConnectionCloseError = isStrictTransportConnectionCloseError(error);
    final statusCode = extractHttpStatusCode(error);
    if (isBodyDecodeError && !_shouldUseRhttpTransport(_activeHttpPolicy)) {
      return false;
    }

    if (!_shouldFallbackHttpPolicyOnError(error) &&
        !isBodyDecodeError &&
        !isConnectionCloseError) {
      return false;
    }

    final reason = isBodyDecodeError
        ? 'response body decode error'
        : isConnectionCloseError
            ? 'strict transport connection closed'
            : (statusCode != null
                ? 'response status $statusCode'
                : 'transfer error');
    return _tryFallbackHttpPolicy(
      reason,
      url: url,
      hintTtl: _adaptiveHintTtlForError(
        error,
        isBodyDecodeError: isBodyDecodeError,
        statusCode: statusCode,
      ),
    );
  }

  Duration _responseHeaderTimeout() {
    final connectSeconds = config.connectionTimeout.clamp(5, 30);
    final readSeconds = config.readTimeout.clamp(10, 120);
    final capSeconds = _shouldUseRhttpTransport(_activeHttpPolicy) ? 6 : 8;
    final boundedConnect =
        connectSeconds < capSeconds ? connectSeconds : capSeconds;
    final timeoutSeconds =
        boundedConnect < readSeconds ? boundedConnect : readSeconds;
    return Duration(seconds: timeoutSeconds);
  }

  bool _tryFallbackHttpPolicy(
    String reason, {
    String? url,
    Duration? hintTtl,
  }) {
    if (_httpPolicyIndex >= _httpPolicyFallbackChain.length - 1) {
      return false;
    }

    final fromPolicy = _activeHttpPolicy;
    _applyHttpPolicyIndex(_httpPolicyIndex + 1);
    final toPolicy = _activeHttpPolicy;
    final host =
        (url == null ? null : _extractHost(url)) ?? _adaptivePolicyHost;
    if (host != null && hintTtl != null) {
      _rememberAdaptivePolicyHint(host, toPolicy, hintTtl);
    }
    _lastPolicyDecisionReason = 'HTTP fallback triggered by $reason: '
        '${_formatHttpPolicyDisplay(fromPolicy)} -> '
        '${_formatHttpPolicyDisplay(toPolicy)}.';

    _logger.warning(
      'NSFX-HTTP',
      'HTTP policy fallback triggered by $reason: $fromPolicy -> $toPolicy',
    );

    return true;
  }

  Future<_ProbeResult?> _probeGet(
    String url,
    Map<String, String> headers,
    DateTime deadline, {
    Duration? strictProbeTimeoutCap,
  }) async {
    if (_shouldUseRhttpTransport(_activeHttpPolicy)) {
      return _probeGetWithRhttp(
        url,
        headers,
        deadline,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
    }

    final uri = Uri.parse(url);
    HttpClient? probeClient;

    try {
      final timeout = _probeTimeout(
        deadline,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
      probeClient = await _buildClient(
        connectionTimeout: timeout,
        idleTimeout: Duration(seconds: timeout.inSeconds + 5),
        autoUncompress: false,
      );

      final strictRangeHint = _shouldUseRhttpTransport(_activeHttpPolicy);
      final request = await probeClient.getUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      if (strictRangeHint) {
        // Avoid expensive full-body probes on strict h2/h3 policies.
        request.headers.set('Range', 'bytes=0-0');
      }

      final response = await request.close().timeout(timeout);
      final statusCode = response.statusCode;
      final negotiatedHttpVersion = _markActivePolicyAsNegotiated();
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');
      final contentRange = response.headers.value('content-range');
      final shouldDrainBody = statusCode == 206 ||
          (contentLength >= 0 && contentLength <= 64 * 1024);
      if (shouldDrainBody) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
      }

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning(
            'NSFX-HTTP', 'GET probe: proxy error status=$statusCode');
        return _ProbeResult(
          _buildFileInfo(
            size: 0,
            supportsRange: false,
            proxyError: true,
            negotiatedHttpVersion: negotiatedHttpVersion,
            headers: response.headers,
          ),
        );
      }

      if (_shouldFallbackHttpPolicyOnStatus(statusCode) &&
          _tryFallbackHttpPolicy(
            'GET probe status=$statusCode',
            url: url,
            hintTtl: _adaptiveHintTtlForStatus(statusCode),
          )) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
        return _probeGet(
          url,
          headers,
          deadline,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP',
            'GET probe: size=$contentLength, range=$supportsRange');
        return _ProbeResult(
          _buildFileInfo(
            size: contentLength,
            supportsRange: supportsRange,
            negotiatedHttpVersion: negotiatedHttpVersion,
            headers: response.headers,
          ),
        );
      }

      if (statusCode == 206 && contentRange != null) {
        final match =
            RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
        if (match != null && match.group(1) != '*') {
          final size = int.parse(match.group(1)!);
          _logger.info('NSFX-HTTP', 'GET probe (206): size=$size, range=true');
          return _ProbeResult(
            _buildFileInfo(
              size: size,
              supportsRange: true,
              negotiatedHttpVersion: negotiatedHttpVersion,
              headers: response.headers,
            ),
          );
        }
      }

      if (statusCode == 200 && contentLength <= 0) {
        _logger.info(
            'NSFX-HTTP', 'GET probe: unknown size (chunked?), range=false');
        return _ProbeResult(
          _buildFileInfo(
            size: 0,
            supportsRange: false,
            negotiatedHttpVersion: negotiatedHttpVersion,
            headers: response.headers,
          ),
        );
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'GET probe failed: $error');

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'GET probe detected proxy transport error, fallback eligible');
        return _ProbeResult(
          _buildFileInfo(
            size: 0,
            supportsRange: false,
            proxyError: true,
          ),
        );
      }

      if (_shouldFallbackHttpPolicyOnError(error) &&
          _tryFallbackHttpPolicy(
            'GET probe error',
            url: url,
            hintTtl: _adaptiveHintTtlForError(error),
          )) {
        return _probeGet(
          url,
          headers,
          deadline,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }

      if (_isNetworkUnreachable(error)) {
        _logger.warning(
            'NSFX-HTTP', 'Network unreachable, skipping remaining probes');
      }
    } finally {
      probeClient?.close();
    }

    return null;
  }

  Future<_ProbeResult?> _probeGetWithRhttp(
    String url,
    Map<String, String> headers,
    DateTime deadline, {
    Duration? strictProbeTimeoutCap,
  }) async {
    try {
      final timeout = _probeTimeout(
        deadline,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
      final responseResult = await _sendRhttpRequest(
        url: url,
        headers: headers,
        method: rhttp.HttpMethod.get,
        start: 0,
        end: 1,
        connectionTimeout: timeout,
        idleTimeout: Duration(seconds: timeout.inSeconds + 5),
        headerTimeout: timeout,
        proxy: getActiveProxySettings(url),
      );
      final response = responseResult.response;
      final statusCode = response.statusCode;
      final negotiatedHttpVersion = responseResult.negotiatedHttpVersion;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');
      final contentRange = response.headers.value('content-range');
      final shouldDrainBody = statusCode == 206 ||
          (contentLength >= 0 && contentLength <= 64 * 1024);
      if (shouldDrainBody) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
      }

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning(
            'NSFX-HTTP', 'GET probe: proxy error status=$statusCode');
        return _ProbeResult(
          _buildFileInfo(
            size: 0,
            supportsRange: false,
            proxyError: true,
            negotiatedHttpVersion: negotiatedHttpVersion,
            headers: response.headers,
          ),
        );
      }

      if (_shouldFallbackHttpPolicyOnStatus(statusCode) &&
          _tryFallbackHttpPolicy(
            'GET probe status=$statusCode',
            url: url,
            hintTtl: _adaptiveHintTtlForStatus(statusCode),
          )) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
        return _probeGet(
          url,
          headers,
          deadline,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP',
            'GET probe: size=$contentLength, range=$supportsRange');
        return _ProbeResult(
          _buildFileInfo(
            size: contentLength,
            supportsRange: supportsRange,
            negotiatedHttpVersion: negotiatedHttpVersion,
            headers: response.headers,
          ),
        );
      }

      if (statusCode == 206 && contentRange != null) {
        final match =
            RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
        if (match != null && match.group(1) != '*') {
          final size = int.parse(match.group(1)!);
          _logger.info('NSFX-HTTP', 'GET probe (206): size=$size, range=true');
          return _ProbeResult(
            _buildFileInfo(
              size: size,
              supportsRange: true,
              negotiatedHttpVersion: negotiatedHttpVersion,
              headers: response.headers,
            ),
          );
        }
      }

      if (statusCode == 200 && contentLength <= 0) {
        _logger.info(
            'NSFX-HTTP', 'GET probe: unknown size (chunked?), range=false');
        return _ProbeResult(
          _buildFileInfo(
            size: 0,
            supportsRange: false,
            negotiatedHttpVersion: negotiatedHttpVersion,
            headers: response.headers,
          ),
        );
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'GET probe failed: $error');

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'GET probe detected proxy transport error, fallback eligible');
        return _ProbeResult(
          _buildFileInfo(
            size: 0,
            supportsRange: false,
            proxyError: true,
          ),
        );
      }

      if (_shouldFallbackHttpPolicyOnError(error) &&
          _tryFallbackHttpPolicy(
            'GET probe error',
            url: url,
            hintTtl: _adaptiveHintTtlForError(error),
          )) {
        return _probeGet(
          url,
          headers,
          deadline,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }

      if (_isNetworkUnreachable(error)) {
        _logger.warning(
            'NSFX-HTTP', 'Network unreachable, skipping remaining probes');
      }
    }

    return null;
  }

  Future<FileInfo?> _probeRange(
      String url, Map<String, String> headers, DateTime deadline, String label,
      {int? sizeHint, Duration? strictProbeTimeoutCap}) async {
    if (_shouldUseRhttpTransport(_activeHttpPolicy)) {
      return _probeRangeWithRhttp(
        url,
        headers,
        deadline,
        label,
        sizeHint: sizeHint,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
    }

    final uri = Uri.parse(url);
    HttpClient? probeClient;

    try {
      final timeout = _probeTimeout(
        deadline,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
      probeClient = await _buildClient(
        connectionTimeout: timeout,
        idleTimeout: Duration(seconds: timeout.inSeconds + 5),
      );

      final request = await probeClient.getUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      request.headers.set('Range', 'bytes=0-0');

      final response = await request.close().timeout(timeout);
      final statusCode = response.statusCode;
      final negotiatedHttpVersion = _markActivePolicyAsNegotiated();
      final contentRange = response.headers.value('content-range');
      final contentLength = response.contentLength;
      final shouldDrainBody = statusCode == 206 ||
          (contentLength >= 0 && contentLength <= 64 * 1024);
      if (shouldDrainBody) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
      }

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning('NSFX-HTTP',
            'Range probe ($label): proxy error status=$statusCode');
        return _buildFileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      }

      if (_shouldFallbackHttpPolicyOnStatus(statusCode) &&
          _tryFallbackHttpPolicy(
            'Range probe ($label) status=$statusCode',
            url: url,
            hintTtl: _adaptiveHintTtlForStatus(statusCode),
          )) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
        return _probeRange(
          url,
          headers,
          deadline,
          label,
          sizeHint: sizeHint,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }

      if (statusCode == 206) {
        if (contentRange != null) {
          final match =
              RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
          if (match != null && match.group(1) != '*') {
            final size = int.parse(match.group(1)!);
            _logger.info(
                'NSFX-HTTP', 'Range probe ($label): size=$size, range=true');
            return _buildFileInfo(
              size: size,
              supportsRange: true,
              negotiatedHttpVersion: negotiatedHttpVersion,
              headers: response.headers,
            );
          }
        }

        final inferredSize = (sizeHint != null && sizeHint > 0) ? sizeHint : 0;
        _logger.info(
          'NSFX-HTTP',
          'Range probe ($label): status=206, content-range unavailable, '
              'inferredSize=$inferredSize, range=true',
        );
        return _buildFileInfo(
          size: inferredSize,
          supportsRange: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      } else if (statusCode == 200 && contentLength > 0) {
        _logger.info('NSFX-HTTP',
            'Range probe ($label): size=$contentLength, range=false');
        return _buildFileInfo(
          size: contentLength,
          supportsRange: false,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'Range probe ($label) failed: $error');

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'Range probe ($label) detected proxy transport error, fallback eligible');
        return _buildFileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
        );
      }

      if (_shouldFallbackHttpPolicyOnError(error) &&
          _tryFallbackHttpPolicy(
            'Range probe ($label) error',
            url: url,
            hintTtl: _adaptiveHintTtlForError(error),
          )) {
        return _probeRange(
          url,
          headers,
          deadline,
          label,
          sizeHint: sizeHint,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }
    } finally {
      probeClient?.close();
    }

    return null;
  }

  Future<FileInfo?> _probeRangeWithRhttp(
    String url,
    Map<String, String> headers,
    DateTime deadline,
    String label, {
    int? sizeHint,
    Duration? strictProbeTimeoutCap,
  }) async {
    try {
      final timeout = _probeTimeout(
        deadline,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
      final responseResult = await _sendRhttpRequest(
        url: url,
        headers: headers,
        method: rhttp.HttpMethod.get,
        start: 0,
        end: 1,
        connectionTimeout: timeout,
        idleTimeout: Duration(seconds: timeout.inSeconds + 5),
        headerTimeout: timeout,
        proxy: getActiveProxySettings(url),
      );
      final response = responseResult.response;
      final statusCode = response.statusCode;
      final negotiatedHttpVersion = responseResult.negotiatedHttpVersion;
      final contentRange = response.headers.value('content-range');
      final contentLength = response.contentLength;
      final shouldDrainBody = statusCode == 206 ||
          (contentLength >= 0 && contentLength <= 64 * 1024);
      if (shouldDrainBody) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
      }

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning('NSFX-HTTP',
            'Range probe ($label): proxy error status=$statusCode');
        return _buildFileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      }

      if (_shouldFallbackHttpPolicyOnStatus(statusCode) &&
          _tryFallbackHttpPolicy(
            'Range probe ($label) status=$statusCode',
            url: url,
            hintTtl: _adaptiveHintTtlForStatus(statusCode),
          )) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
        return _probeRange(
          url,
          headers,
          deadline,
          label,
          sizeHint: sizeHint,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }

      if (statusCode == 206) {
        if (contentRange != null) {
          final match =
              RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
          if (match != null && match.group(1) != '*') {
            final size = int.parse(match.group(1)!);
            _logger.info(
                'NSFX-HTTP', 'Range probe ($label): size=$size, range=true');
            return _buildFileInfo(
              size: size,
              supportsRange: true,
              negotiatedHttpVersion: negotiatedHttpVersion,
              headers: response.headers,
            );
          }
        }

        final inferredSize = (sizeHint != null && sizeHint > 0) ? sizeHint : 0;
        _logger.info(
          'NSFX-HTTP',
          'Range probe ($label): status=206, content-range unavailable, '
              'inferredSize=$inferredSize, range=true',
        );
        return _buildFileInfo(
          size: inferredSize,
          supportsRange: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      } else if (statusCode == 200 && contentLength > 0) {
        _logger.info('NSFX-HTTP',
            'Range probe ($label): size=$contentLength, range=false');
        return _buildFileInfo(
          size: contentLength,
          supportsRange: false,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'Range probe ($label) failed: $error');

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'Range probe ($label) detected proxy transport error, fallback eligible');
        return _buildFileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
        );
      }

      if (_shouldFallbackHttpPolicyOnError(error) &&
          _tryFallbackHttpPolicy(
            'Range probe ($label) error',
            url: url,
            hintTtl: _adaptiveHintTtlForError(error),
          )) {
        return _probeRange(
          url,
          headers,
          deadline,
          label,
          sizeHint: sizeHint,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }
    }

    return null;
  }

  Future<FileInfo?> _probeHead(
    String url,
    Map<String, String> headers,
    DateTime deadline,
    String label, {
    Duration? strictProbeTimeoutCap,
  }) async {
    if (_shouldUseRhttpTransport(_activeHttpPolicy)) {
      return _probeHeadWithRhttp(
        url,
        headers,
        deadline,
        label,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
    }

    final uri = Uri.parse(url);
    HttpClient? probeClient;

    try {
      final timeout = _probeTimeout(
        deadline,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
      probeClient = await _buildClient(
        connectionTimeout: timeout,
      );

      final request = await probeClient.headUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      final response = await request.close().timeout(timeout);
      final negotiatedHttpVersion = _markActivePolicyAsNegotiated();

      final statusCode = response.statusCode;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning(
            'NSFX-HTTP', 'HEAD probe ($label): proxy error status=$statusCode');
        return _buildFileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      }

      if (_shouldFallbackHttpPolicyOnStatus(statusCode) &&
          _tryFallbackHttpPolicy(
            'HEAD probe ($label) status=$statusCode',
            url: url,
            hintTtl: _adaptiveHintTtlForStatus(statusCode),
          )) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
        return _probeHead(
          url,
          headers,
          deadline,
          label,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP',
            'HEAD probe ($label): size=$contentLength, range=$supportsRange');
        return _buildFileInfo(
          size: contentLength,
          supportsRange: supportsRange,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'HEAD probe ($label) failed: $error');

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'HEAD probe ($label) detected proxy transport error, fallback eligible');
        return _buildFileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
        );
      }

      if (_shouldFallbackHttpPolicyOnError(error) &&
          _tryFallbackHttpPolicy(
            'HEAD probe ($label) error',
            url: url,
            hintTtl: _adaptiveHintTtlForError(error),
          )) {
        return _probeHead(
          url,
          headers,
          deadline,
          label,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }
    } finally {
      probeClient?.close();
    }

    return null;
  }

  Future<FileInfo?> _probeHeadWithRhttp(
    String url,
    Map<String, String> headers,
    DateTime deadline,
    String label, {
    Duration? strictProbeTimeoutCap,
  }) async {
    try {
      final timeout = _probeTimeout(
        deadline,
        strictProbeTimeoutCap: strictProbeTimeoutCap,
      );
      final responseResult = await _sendRhttpRequest(
        url: url,
        headers: headers,
        method: rhttp.HttpMethod.head,
        connectionTimeout: timeout,
        headerTimeout: timeout,
        proxy: getActiveProxySettings(url),
      );
      final response = responseResult.response;
      final negotiatedHttpVersion = responseResult.negotiatedHttpVersion;

      final statusCode = response.statusCode;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning(
            'NSFX-HTTP', 'HEAD probe ($label): proxy error status=$statusCode');
        return _buildFileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      }

      if (_shouldFallbackHttpPolicyOnStatus(statusCode) &&
          _tryFallbackHttpPolicy(
            'HEAD probe ($label) status=$statusCode',
            url: url,
            hintTtl: _adaptiveHintTtlForStatus(statusCode),
          )) {
        try {
          await response.drain<void>().timeout(timeout);
        } catch (_) {}
        return _probeHead(
          url,
          headers,
          deadline,
          label,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP',
            'HEAD probe ($label): size=$contentLength, range=$supportsRange');
        return _buildFileInfo(
          size: contentLength,
          supportsRange: supportsRange,
          negotiatedHttpVersion: negotiatedHttpVersion,
          headers: response.headers,
        );
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'HEAD probe ($label) failed: $error');

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'HEAD probe ($label) detected proxy transport error, fallback eligible');
        return _buildFileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
        );
      }

      if (_shouldFallbackHttpPolicyOnError(error) &&
          _tryFallbackHttpPolicy(
            'HEAD probe ($label) error',
            url: url,
            hintTtl: _adaptiveHintTtlForError(error),
          )) {
        return _probeHead(
          url,
          headers,
          deadline,
          label,
          strictProbeTimeoutCap: strictProbeTimeoutCap,
        );
      }
    }

    return null;
  }

  Future<HttpClientResponse> getRange(
    String url,
    Map<String, String> headers,
    int start,
    int end,
  ) async {
    return _sendWithHttpPolicyFallback(
      url: url,
      headers: headers,
      start: start,
      end: end,
    );
  }

  Future<HttpClientResponse> get(
      String url, Map<String, String> headers) async {
    return _sendWithHttpPolicyFallback(
      url: url,
      headers: headers,
    );
  }

  Future<HttpClientResponse> _sendWithHttpPolicyFallback({
    required String url,
    required Map<String, String> headers,
    int? start,
    int? end,
  }) async {
    adoptAdaptivePolicyHint(url);
    final uri = Uri.parse(url);

    while (true) {
      try {
        if (_shouldUseRhttpTransport(_activeHttpPolicy)) {
          final responseResult = await _sendRhttpRequest(
            url: url,
            headers: headers,
            method: rhttp.HttpMethod.get,
            start: start,
            end: end,
            connectionTimeout:
                Duration(seconds: config.connectionTimeout.clamp(5, 30)),
            idleTimeout: const Duration(seconds: 30),
            headerTimeout: _responseHeaderTimeout(),
            proxy: getActiveProxySettings(url),
          );
          final response = responseResult.response;
          if (_shouldFallbackHttpPolicyOnStatus(response.statusCode) &&
              _tryFallbackHttpPolicy(
                'GET request status ${response.statusCode}',
                url: url,
                hintTtl: _adaptiveHintTtlForStatus(response.statusCode),
              )) {
            try {
              await response.drain<void>().timeout(const Duration(seconds: 2));
            } catch (_) {}
            continue;
          }
          return response;
        }

        final activeClient = await _ensureClient();
        final request = await activeClient.getUrl(uri);
        _applyHeaders(request, headers);

        if (start != null && end != null) {
          request.headers.set('Range', 'bytes=$start-${end - 1}');
        }

        final headerTimeout = _responseHeaderTimeout();
        final response = await request.close().timeout(headerTimeout);
        if (_shouldFallbackHttpPolicyOnStatus(response.statusCode) &&
            _tryFallbackHttpPolicy(
              'GET request status ${response.statusCode}',
              url: url,
              hintTtl: _adaptiveHintTtlForStatus(response.statusCode),
            )) {
          try {
            await response.drain<void>().timeout(const Duration(seconds: 2));
          } catch (_) {}
          continue;
        }
        _markActivePolicyAsNegotiated();
        return response;
      } catch (error, stackTrace) {
        if (error is TimeoutException) {
          _logger.warning(
            'NSFX-HTTP',
            'GET request timed out before response headers '
                '(policy=$_activeHttpPolicy, timeout=${_responseHeaderTimeout().inSeconds}s)',
          );
        }
        if (_shouldFallbackHttpPolicyOnError(error) &&
            _tryFallbackHttpPolicy(
              'GET request error',
              url: url,
              hintTtl: _adaptiveHintTtlForError(error),
            )) {
          continue;
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String> headers) {
    final effectiveHeaders = _sanitizeHeadersForActivePolicy(headers);
    effectiveHeaders.forEach((key, value) {
      request.headers.set(key, value);
    });
  }

  Map<String, String> _sanitizeHeadersForActivePolicy(
      Map<String, String> headers) {
    if (!_shouldUseRhttpTransport(_activeHttpPolicy)) {
      return headers;
    }

    final sanitized = Map<String, String>.from(headers);
    sanitized.removeWhere(
      (key, _) => _hopByHopHeaders.contains(key.toLowerCase()),
    );
    return sanitized;
  }

  void _applyProxy(HttpClient client, {NsfxResolvedProxy? proxy}) {
    NsfxProxyRuntime.applyToHttpClient(
      client,
      proxy ?? getActiveProxySettings(_activeRequestUrl),
    );
  }

  /// Existing API kept for compatibility with current download isolate params.
  String? getProxyString([String? url]) {
    final proxy = getActiveProxySettings(url);
    if (!proxy.hasProxy || proxy.usesSystemSettings) return null;
    return '${proxy.host}:${proxy.port}';
  }

  NsfxResolvedProxy getActiveProxySettings([String? url]) =>
      _resolveProxyForUrl(url);

  void close() {
    _resetClientState();
    _lastNegotiatedHttpVersion = null;
    _lastPolicyDecisionReason = null;
    _lastResolvedProxy = const NsfxResolvedProxy.direct();
    _httpPolicyIndex = 0;
    _adaptivePolicyHost = null;
    _activeRequestUrl = null;
  }

  Duration _adaptiveHintTtlForError(
    Object error, {
    bool isBodyDecodeError = false,
    int? statusCode,
  }) {
    final effectiveStatusCode = statusCode ?? extractHttpStatusCode(error);
    if (effectiveStatusCode != null) {
      return _adaptiveHintTtlForStatus(effectiveStatusCode);
    }
    if (isBodyDecodeError || isHttpProtocolNegotiationError(error)) {
      return adaptiveTransportHintTtl;
    }
    if (error is TimeoutException) {
      return adaptiveTimeoutHintTtl;
    }
    return adaptiveStatusHintTtl;
  }

  Duration _adaptiveHintTtlForStatus(int statusCode) {
    if (statusCode == 421 || statusCode == 425) {
      return adaptiveTransportHintTtl;
    }
    if (statusCode >= 500 && statusCode <= 599) {
      return adaptiveStatusHintTtl;
    }
    return adaptiveTransportHintTtl;
  }

  void _applyHttpPolicyIndex(int value) {
    final boundedValue = value.clamp(0, _httpPolicyFallbackChain.length - 1);
    if (boundedValue == _httpPolicyIndex) {
      return;
    }
    _httpPolicyIndex = boundedValue;
    _resetClientState();
  }

  void _refreshHttpPolicyChainForUrl(String? url) {
    final nextChain = NsfxHttpVersionPolicy.preferredChainForUrl(
      config.httpVersionPolicy,
      url: url,
    );
    if (_httpPolicyFallbackChain.length == nextChain.length) {
      var identicalChain = true;
      for (var i = 0; i < nextChain.length; i++) {
        if (_httpPolicyFallbackChain[i] != nextChain[i]) {
          identicalChain = false;
          break;
        }
      }
      if (identicalChain) {
        return;
      }
    }

    final currentPolicy = _httpPolicyFallbackChain.isEmpty
        ? null
        : _httpPolicyFallbackChain[_httpPolicyIndex.clamp(
            0,
            _httpPolicyFallbackChain.length - 1,
          )];
    _httpPolicyFallbackChain
      ..clear()
      ..addAll(nextChain);

    final nextIndex = currentPolicy == null
        ? -1
        : _httpPolicyFallbackChain.indexOf(currentPolicy);
    _httpPolicyIndex = nextIndex < 0 ? 0 : nextIndex;
    _resetClientState();
  }

  void _resetClientState() {
    _lastNegotiatedHttpVersion = null;
    _client?.close(force: true);
    _client = null;
    _clientFuture = null;
  }

  void _rememberAdaptivePolicyHint(
    String host,
    String policy,
    Duration ttl,
  ) {
    final normalizedPolicy = NsfxHttpVersionPolicy.normalize(policy);
    final now = DateTime.now();
    final candidate = _AdaptiveHostStrategyHint(
      policy: normalizedPolicy,
      policyExpiresAt: now.add(ttl),
    );
    final existing = _adaptivePolicyHints[host];
    _adaptivePolicyHints[host] =
        (existing ?? const _AdaptiveHostStrategyHint()).merge(candidate, now);
  }

  String? _hintedPolicyForHost(String host) {
    final now = DateTime.now();
    final hint = _adaptivePolicyHints[host];
    if (hint == null) {
      return null;
    }
    final sanitized = hint.sanitized(now);
    if (sanitized == null) {
      _adaptivePolicyHints.remove(host);
      return null;
    }
    _adaptivePolicyHints[host] = sanitized;
    return sanitized.policy;
  }

  static String? _extractHost(String url) {
    final host = Uri.tryParse(url)?.host.trim().toLowerCase();
    if (host == null || host.isEmpty) {
      return null;
    }
    return host;
  }

  static int _adaptivePolicyRank(String policy) {
    switch (NsfxHttpVersionPolicy.normalize(policy)) {
      case NsfxHttpVersionPolicy.http1Only:
        return 1;
      case NsfxHttpVersionPolicy.http2Only:
        return 2;
      case NsfxHttpVersionPolicy.http3Only:
        return 3;
      case NsfxHttpVersionPolicy.auto:
      default:
        return 0;
    }
  }

  static String _formatHttpPolicyDisplay(String policy) {
    switch (NsfxHttpVersionPolicy.normalize(policy)) {
      case NsfxHttpVersionPolicy.http3Only:
        return 'HTTP/3';
      case NsfxHttpVersionPolicy.http2Only:
        return 'HTTP/2';
      case NsfxHttpVersionPolicy.http1Only:
        return 'HTTP/1.1';
      case NsfxHttpVersionPolicy.auto:
        return 'HTTP Auto';
      default:
        return policy;
    }
  }
}

class _ProbeResult {
  final FileInfo fileInfo;

  _ProbeResult(this.fileInfo);
}

class _RequestResponse {
  final HttpClientResponse response;
  final String? negotiatedHttpVersion;

  const _RequestResponse({
    required this.response,
    required this.negotiatedHttpVersion,
  });
}

class _AdaptiveHostStrategyHint {
  final String? policy;
  final DateTime? policyExpiresAt;
  final int? maxConcurrency;
  final DateTime? maxConcurrencyExpiresAt;

  const _AdaptiveHostStrategyHint({
    this.policy,
    this.policyExpiresAt,
    this.maxConcurrency,
    this.maxConcurrencyExpiresAt,
  });

  _AdaptiveHostStrategyHint? sanitized(DateTime now) {
    final effectivePolicy = hasPolicy(now) ? policy : null;
    final effectivePolicyExpiry = hasPolicy(now) ? policyExpiresAt : null;
    final effectiveConcurrency = hasMaxConcurrency(now) ? maxConcurrency : null;
    final effectiveConcurrencyExpiry =
        hasMaxConcurrency(now) ? maxConcurrencyExpiresAt : null;

    if (effectivePolicy == null && effectiveConcurrency == null) {
      return null;
    }

    return _AdaptiveHostStrategyHint(
      policy: effectivePolicy,
      policyExpiresAt: effectivePolicyExpiry,
      maxConcurrency: effectiveConcurrency,
      maxConcurrencyExpiresAt: effectiveConcurrencyExpiry,
    );
  }

  _AdaptiveHostStrategyHint merge(
    _AdaptiveHostStrategyHint candidate,
    DateTime now,
  ) {
    final current = sanitized(now) ?? const _AdaptiveHostStrategyHint();
    final next = candidate.sanitized(now) ?? const _AdaptiveHostStrategyHint();

    final mergedPolicy = () {
      if (current.policy == null) return next.policy;
      if (next.policy == null) return current.policy;
      final currentRank = NsfxHttpClient._adaptivePolicyRank(current.policy!);
      final nextRank = NsfxHttpClient._adaptivePolicyRank(next.policy!);
      return nextRank >= currentRank ? next.policy : current.policy;
    }();

    final mergedPolicyExpiry = () {
      if (mergedPolicy == null) return null;
      if (current.policy == null) return next.policyExpiresAt;
      if (next.policy == null) return current.policyExpiresAt;
      final currentExpiry = current.policyExpiresAt!;
      final nextExpiry = next.policyExpiresAt!;
      return nextExpiry.isAfter(currentExpiry) ? nextExpiry : currentExpiry;
    }();

    final mergedConcurrency = () {
      if (current.maxConcurrency == null) return next.maxConcurrency;
      if (next.maxConcurrency == null) return current.maxConcurrency;
      return current.maxConcurrency! <= next.maxConcurrency!
          ? current.maxConcurrency
          : next.maxConcurrency;
    }();

    final mergedConcurrencyExpiry = () {
      if (mergedConcurrency == null) return null;
      if (current.maxConcurrency == null) return next.maxConcurrencyExpiresAt;
      if (next.maxConcurrency == null) {
        return current.maxConcurrencyExpiresAt;
      }
      final currentExpiry = current.maxConcurrencyExpiresAt!;
      final nextExpiry = next.maxConcurrencyExpiresAt!;
      return nextExpiry.isAfter(currentExpiry) ? nextExpiry : currentExpiry;
    }();

    return _AdaptiveHostStrategyHint(
      policy: mergedPolicy,
      policyExpiresAt: mergedPolicyExpiry,
      maxConcurrency: mergedConcurrency,
      maxConcurrencyExpiresAt: mergedConcurrencyExpiry,
    );
  }

  bool hasPolicy(DateTime now) =>
      policy != null &&
      policyExpiresAt != null &&
      policyExpiresAt!.isAfter(now);

  bool hasMaxConcurrency(DateTime now) =>
      maxConcurrency != null &&
      maxConcurrencyExpiresAt != null &&
      maxConcurrencyExpiresAt!.isAfter(now);

  int? maxConcurrencyFor(DateTime now) =>
      hasMaxConcurrency(now) ? maxConcurrency : null;

  Map<String, dynamic> toJson() => {
        if (policy != null) 'policy': policy,
        if (policyExpiresAt != null)
          'policyExpiresAt': policyExpiresAt!.toIso8601String(),
        if (maxConcurrency != null) 'maxConcurrency': maxConcurrency,
        if (maxConcurrencyExpiresAt != null)
          'maxConcurrencyExpiresAt': maxConcurrencyExpiresAt!.toIso8601String(),
      };

  static _AdaptiveHostStrategyHint? fromJson(
    Map<String, dynamic> json,
    DateTime now,
  ) {
    DateTime? parseDate(dynamic value) {
      final raw = value?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final policy = NsfxHttpVersionPolicy.isSupported(json['policy']?.toString())
        ? json['policy']?.toString()
        : null;
    final policyExpiresAt = parseDate(json['policyExpiresAt']);
    final maxConcurrency = (json['maxConcurrency'] as num?)?.toInt();
    final maxConcurrencyExpiresAt = parseDate(json['maxConcurrencyExpiresAt']);

    return _AdaptiveHostStrategyHint(
      policy: policy,
      policyExpiresAt: policyExpiresAt,
      maxConcurrency: maxConcurrency,
      maxConcurrencyExpiresAt: maxConcurrencyExpiresAt,
    ).sanitized(now);
  }
}

class FileInfo {
  final int size;
  final bool supportsRange;
  final bool proxyError;
  final String? negotiatedHttpVersion;
  final String connectionType;
  final String? etag;
  final String? lastModified;

  bool get hasStrongValidator => etag != null;
  bool get usesParallelSafeConnection =>
      negotiatedHttpVersion == 'http1_1' &&
      connectionType == NsfxHttpConnectionType.http1;
  String? get ifRangeValidator => NsfxHttpClient.selectIfRangeValidator(
        etag: etag,
        lastModified: lastModified,
      );

  FileInfo({
    required this.size,
    required this.supportsRange,
    this.proxyError = false,
    this.negotiatedHttpVersion,
    this.connectionType = NsfxHttpConnectionType.unknown,
    this.etag,
    this.lastModified,
  });

  FileInfo copyWith({
    int? size,
    bool? supportsRange,
    bool? proxyError,
    String? negotiatedHttpVersion,
    String? connectionType,
    String? etag,
    String? lastModified,
  }) {
    return FileInfo(
      size: size ?? this.size,
      supportsRange: supportsRange ?? this.supportsRange,
      proxyError: proxyError ?? this.proxyError,
      negotiatedHttpVersion:
          negotiatedHttpVersion ?? this.negotiatedHttpVersion,
      connectionType: connectionType ?? this.connectionType,
      etag: etag ?? this.etag,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

class _RhttpHttpClientResponse
    with Stream<List<int>>
    implements HttpClientResponse {
  final rhttp.HttpStreamResponse _response;
  final _RhttpHttpHeaders _headers;

  _RhttpHttpClientResponse._(this._response, this._headers);

  factory _RhttpHttpClientResponse.fromRhttp(
      rhttp.HttpStreamResponse response) {
    final headers = _RhttpHttpHeaders();
    for (final header in response.headers) {
      headers.add(header.$1, header.$2);
    }
    return _RhttpHttpClientResponse._(response, headers);
  }

  @override
  X509Certificate? get certificate => throw UnimplementedError();

  @override
  HttpClientResponseCompressionState get compressionState =>
      throw UnimplementedError();

  @override
  HttpConnectionInfo? get connectionInfo => throw UnimplementedError();

  @override
  int get contentLength =>
      int.tryParse(_headers.value('content-length') ?? '-1') ?? -1;

  @override
  List<Cookie> get cookies => throw UnimplementedError();

  @override
  Future<Socket> detachSocket() => throw UnimplementedError();

  @override
  HttpHeaders get headers => _headers;

  @override
  bool get isRedirect {
    if (_response.request.method == rhttp.HttpMethod.get ||
        _response.request.method == rhttp.HttpMethod.head) {
      return statusCode == HttpStatus.movedPermanently ||
          statusCode == HttpStatus.permanentRedirect ||
          statusCode == HttpStatus.found ||
          statusCode == HttpStatus.seeOther ||
          statusCode == HttpStatus.temporaryRedirect;
    } else if (_response.request.method == rhttp.HttpMethod.post) {
      return statusCode == HttpStatus.seeOther;
    }
    return false;
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _response.body.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase => '';

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnimplementedError();
  }

  @override
  List<RedirectInfo> get redirects => [];

  @override
  int get statusCode => _response.statusCode;
}

class _RhttpHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  bool chunkedTransferEncoding = false;

  @override
  int contentLength = -1;

  @override
  ContentType? contentType;

  @override
  DateTime? date;

  @override
  DateTime? expires;

  @override
  String? host;

  @override
  DateTime? ifModifiedSince;

  @override
  bool persistentConnection = true;

  @override
  int? port;

  String _normalizeHeaderName(String name) => name.toLowerCase();

  @override
  List<String>? operator [](String name) =>
      _headers[_normalizeHeaderName(name)];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    final normalizedName = _normalizeHeaderName(name);
    _headers.putIfAbsent(normalizedName, () => []).add(value.toString());
  }

  @override
  void clear() {
    _headers.clear();
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  void noFolding(String name) {
    throw UnimplementedError('noFolding is not supported');
  }

  @override
  void remove(String name, Object value) {
    final normalizedName = _normalizeHeaderName(name);
    final values = _headers[normalizedName];
    if (values == null) {
      return;
    }
    values.remove(value.toString());
    if (values.isEmpty) {
      _headers.remove(normalizedName);
    }
  }

  @override
  void removeAll(String name) {
    _headers.remove(_normalizeHeaderName(name));
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[_normalizeHeaderName(name)] = [value.toString()];
  }

  @override
  String? value(String name) {
    final values = _headers[_normalizeHeaderName(name)];
    if (values == null || values.isEmpty) {
      return null;
    }
    return values.first;
  }
}
