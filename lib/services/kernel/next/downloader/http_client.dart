import 'dart:async';
import 'dart:io';
import 'package:rhttp/rhttp.dart' as rhttp;

import '../config/download_config.dart';
import '../../../app_logger_service.dart';

class NsfxHttpClient {
  final NsfxConfig config;
  HttpClient? _client;
  Future<HttpClient>? _clientFuture;
  final _logger = AppLoggerService();
  final List<String> _httpPolicyFallbackChain;
  int _httpPolicyIndex = 0;
  static Future<void>? _rhttpInitFuture;
  static const Set<String> _hopByHopHeaders = {
    'connection',
    'keep-alive',
    'proxy-connection',
    'transfer-encoding',
    'upgrade',
  };

  /// Proxy connection failed and has been downgraded to direct mode.
  bool _proxyFailed = false;
  final Map<String, String> _negotiatedVersionCache = {};
  String? _lastNegotiatedHttpVersion;

  NsfxHttpClient(this.config)
      : _httpPolicyFallbackChain = NsfxHttpVersionPolicy.fallbackChain(
          config.httpVersionPolicy,
        );

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

  String? _activeNegotiatedHttpVersion() {
    return normalizeNegotiatedHttpVersion(_activeHttpPolicy);
  }

  String? _rememberNegotiatedHttpVersion(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return _lastNegotiatedHttpVersion;
    }
    _lastNegotiatedHttpVersion = normalized;
    return _lastNegotiatedHttpVersion;
  }

  String? _mapRhttpVersion(rhttp.HttpVersion version) {
    return switch (version) {
      rhttp.HttpVersion.http3 => 'http3',
      rhttp.HttpVersion.http2 => 'http2',
      rhttp.HttpVersion.http1_1 ||
      rhttp.HttpVersion.http1_0 ||
      rhttp.HttpVersion.http09 =>
        'http1_1',
      _ => null,
    };
  }

  Future<HttpClient> _buildClient({
    Duration? connectionTimeout,
    Duration? idleTimeout,
    int? maxConnectionsPerHost,
    bool autoUncompress = false,
    ProxySettings? proxy,
  }) async {
    final useRhttp = _shouldUseRhttpTransport(_activeHttpPolicy);
    if (useRhttp) {
      final rhttpClient = await _buildRhttpClient(
        connectionTimeout: connectionTimeout,
        idleTimeout: idleTimeout,
        proxy: proxy,
      );
      return rhttpClient;
    }

    final httpClient = createRawHttpClient(
      httpVersionPolicy: _activeHttpPolicy,
      connectionTimeout: connectionTimeout,
      idleTimeout: idleTimeout,
      maxConnectionsPerHost: maxConnectionsPerHost,
      autoUncompress: autoUncompress,
      userAgent: config.defaultUserAgent,
    );

    _applyProxy(httpClient, proxy: proxy);
    return httpClient;
  }

  Future<HttpClient> _createClient() async {
    final requestedPolicy =
        NsfxHttpVersionPolicy.normalize(config.httpVersionPolicy);
    final activePolicy = _activeHttpPolicy;

    // Balance responsiveness and slow-server compatibility.
    final httpClient = await _buildClient(
      connectionTimeout:
          Duration(seconds: config.connectionTimeout.clamp(5, 30)),
      idleTimeout: const Duration(seconds: 30),
      maxConnectionsPerHost: 128,
      autoUncompress: false,
      proxy: getActiveProxySettings(),
    );

    final proxy = getActiveProxySettings();
    if (proxy != null) {
      if (proxy.type == 'system') {
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
  Future<FileInfo> getFileInfo(String url, Map<String, String> headers) async {
    final result = await _getFileInfoInternal(url, headers);

    // Do not fallback merely because size is unknown (chunked/streaming can be valid).
    if (result.proxyError && _isProxyEnabled && !_proxyFailed) {
      _logger.warning(
        'NSFX-HTTP',
        'Proxy probe failed (proxyError=${result.proxyError}), falling back to direct connection',
      );
      _switchToDirectConnection();
      return _getFileInfoInternal(url, headers);
    }

    return result;
  }

  bool get _isProxyEnabled => config.proxy.enabled && !_proxyFailed;

  void _switchToDirectConnection() {
    _proxyFailed = true;
    _client?.close(force: true);
    _client = null;
    _clientFuture = null;
    _lastNegotiatedHttpVersion = null;
    _negotiatedVersionCache.clear();
    _logger.info('NSFX-HTTP', 'Switched to direct connection (proxy bypassed)');
  }

  void switchToDirectOnProxyError() {
    if (_proxyFailed) return;
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

  Future<HttpClient> _buildRhttpClient({
    Duration? connectionTimeout,
    Duration? idleTimeout,
    ProxySettings? proxy,
  }) async {
    await _ensureRhttpInitialized();

    final settings = _buildRhttpSettings(
      connectionTimeout: connectionTimeout,
      idleTimeout: idleTimeout,
      proxy: proxy,
    );

    return await rhttp.IoCompatibleClient.create(settings: settings);
  }

  Future<rhttp.RhttpClient> _buildNativeRhttpClient({
    Duration? connectionTimeout,
    Duration? idleTimeout,
    ProxySettings? proxy,
  }) async {
    await _ensureRhttpInitialized();

    final settings = _buildRhttpSettings(
      connectionTimeout: connectionTimeout,
      idleTimeout: idleTimeout,
      proxy: proxy,
    );

    return await rhttp.RhttpClient.create(settings: settings);
  }

  rhttp.ClientSettings _buildRhttpSettings({
    Duration? connectionTimeout,
    Duration? idleTimeout,
    ProxySettings? proxy,
  }) {
    final versionPref = switch (_activeHttpPolicy) {
      NsfxHttpVersionPolicy.http1Only => rhttp.HttpVersionPref.http1_1,
      NsfxHttpVersionPolicy.http2Only => rhttp.HttpVersionPref.http2,
      NsfxHttpVersionPolicy.http3Only => rhttp.HttpVersionPref.http3,
      _ => rhttp.HttpVersionPref.all,
    };

    final proxySettings = _toRhttpProxySettings(proxy);
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

  Future<String?> _resolveNegotiatedHttpVersionForUri(
    Uri uri,
    Map<String, String> headers,
    DateTime deadline,
  ) async {
    if (!_shouldUseRhttpTransport(_activeHttpPolicy)) {
      return _rememberNegotiatedHttpVersion(_activeNegotiatedHttpVersion());
    }

    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    final port = uri.hasPort ? uri.port : defaultPort;
    final cacheKey = '$_activeHttpPolicy|${uri.scheme}://${uri.host}:$port';
    final cached = _negotiatedVersionCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return _rememberNegotiatedHttpVersion(cached);
    }

    final probed = await _probeRhttpNegotiatedHttpVersion(
      uri: uri,
      headers: headers,
      deadline: deadline,
    );
    if (probed != null && probed.isNotEmpty) {
      _negotiatedVersionCache[cacheKey] = probed;
    }

    return _rememberNegotiatedHttpVersion(
      probed ?? _activeNegotiatedHttpVersion(),
    );
  }

  Future<String?> _probeRhttpNegotiatedHttpVersion({
    required Uri uri,
    required Map<String, String> headers,
    required DateTime deadline,
  }) async {
    rhttp.RhttpClient? probeClient;
    try {
      final timeout = _probeTimeout(deadline);
      probeClient = await _buildNativeRhttpClient(
        connectionTimeout: timeout,
        idleTimeout: Duration(seconds: timeout.inSeconds + 5),
        proxy: getActiveProxySettings(),
      );

      final effectiveHeaders = _sanitizeHeadersForActivePolicy(headers);
      final response = await probeClient
          .request(
            method: rhttp.HttpMethod.head,
            url: uri.toString(),
            headers: effectiveHeaders.isEmpty
                ? null
                : rhttp.HttpHeaders.rawMap(effectiveHeaders),
            expectBody: rhttp.HttpExpectBody.bytes,
          )
          .timeout(timeout);
      final negotiated = _mapRhttpVersion(response.version);
      _logger.debug(
        'NSFX-HTTP',
        'Negotiated HTTP version probe: '
            'policy=$_activeHttpPolicy, version=${negotiated ?? 'unknown'}',
      );
      return negotiated;
    } catch (error) {
      _logger.debug(
          'NSFX-HTTP', 'Negotiated HTTP version probe failed: $error');
      return null;
    } finally {
      probeClient?.dispose(cancelRunningRequests: true);
    }
  }

  rhttp.ProxySettings? _toRhttpProxySettings(ProxySettings? proxy) {
    final active = proxy ?? getActiveProxySettings();
    if (active == null) {
      return const rhttp.ProxySettings.noProxy();
    }

    if (active.type == 'system') {
      return null;
    }

    final scheme = active.type == 'socks5' ? 'socks5' : 'http';
    String auth = '';
    if (active.supportsHttpBasicAuth) {
      final user = Uri.encodeComponent(active.username!);
      final pass = Uri.encodeComponent(active.password!);
      auth = '$user:$pass@';
    }

    final proxyUrl = '$scheme://$auth${active.host}:${active.port}';
    return rhttp.ProxySettings.proxy(proxyUrl);
  }

  Future<FileInfo> _getFileInfoInternal(
      String url, Map<String, String> headers) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));

    final rangeResult = await _probeRange(url, headers, deadline, 'primary');
    final rangeProbeSupportsRange = rangeResult?.supportsRange ?? false;
    if (rangeResult != null) {
      if (rangeResult.proxyError) return rangeResult;
      // Keep probing if size is still unknown, otherwise we end up in
      // single-thread fallback despite having range capability.
      if (rangeResult.size > 0) {
        return rangeResult;
      }
      if (!rangeResult.supportsRange) {
        return rangeResult;
      }
    }

    if (_isDeadlineExceeded(deadline)) {
      _logger.warning('NSFX-HTTP', 'Probe deadline exceeded after Range probe');
      return FileInfo(
        size: 0,
        supportsRange: false,
        negotiatedHttpVersion:
            _lastNegotiatedHttpVersion ?? _activeNegotiatedHttpVersion(),
      );
    }

    final headResult = await _probeHead(url, headers, deadline, 'fallback');
    if (headResult != null) {
      if (headResult.size > 0 && !headResult.supportsRange) {
        final verifyRange = await _probeRange(
          url,
          headers,
          deadline,
          'verify_head',
          sizeHint: headResult.size,
        );
        if (verifyRange != null) {
          return verifyRange;
        }
      }
      if (rangeProbeSupportsRange && !headResult.supportsRange) {
        return FileInfo(
          size: headResult.size,
          supportsRange: true,
          proxyError: headResult.proxyError,
          negotiatedHttpVersion: headResult.negotiatedHttpVersion ??
              rangeResult?.negotiatedHttpVersion,
        );
      }
      return headResult;
    }

    if (_isDeadlineExceeded(deadline)) {
      _logger.warning('NSFX-HTTP', 'Probe deadline exceeded, giving up');
      return FileInfo(
        size: 0,
        supportsRange: false,
        negotiatedHttpVersion:
            _lastNegotiatedHttpVersion ?? _activeNegotiatedHttpVersion(),
      );
    }

    // Full GET probe can be expensive on large files. Keep it as final fallback.
    final getResult = await _probeGet(url, headers, deadline);
    if (getResult != null) {
      if (getResult.fileInfo.size > 0 && !getResult.fileInfo.supportsRange) {
        final verifyRange = await _probeRange(
          url,
          headers,
          deadline,
          'verify_get',
          sizeHint: getResult.fileInfo.size,
        );
        if (verifyRange != null) {
          return verifyRange;
        }
      }
      if (rangeProbeSupportsRange && !getResult.fileInfo.supportsRange) {
        return FileInfo(
          size: getResult.fileInfo.size,
          supportsRange: true,
          proxyError: getResult.fileInfo.proxyError,
          negotiatedHttpVersion: getResult.fileInfo.negotiatedHttpVersion ??
              rangeResult?.negotiatedHttpVersion,
        );
      }
      return getResult.fileInfo;
    }

    if (rangeProbeSupportsRange) {
      return FileInfo(
        size: 0,
        supportsRange: true,
        negotiatedHttpVersion: rangeResult?.negotiatedHttpVersion ??
            _lastNegotiatedHttpVersion ??
            _activeNegotiatedHttpVersion(),
      );
    }

    _logger.warning(
        'NSFX-HTTP', 'Could not determine file info after all strategies');
    return FileInfo(
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
    return remaining.inSeconds < 2 ? const Duration(seconds: 2) : remaining;
  }

  Duration _probeTimeout(DateTime deadline) {
    var timeout = _remainingTime(deadline);
    // Strict h2/h3 probes should fail fast so fallback can happen quickly.
    if (_shouldUseRhttpTransport(_activeHttpPolicy) &&
        timeout > const Duration(seconds: 6)) {
      timeout = const Duration(seconds: 6);
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
    final proxy = getActiveProxySettings();
    final isSystemProxy = proxy?.type == 'system';
    final proxyHost = proxy?.host.toLowerCase() ?? '';
    final proxyPort = proxy?.port.toString() ?? '';

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

  bool _isHttpProtocolError(Object error) {
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

  bool _shouldFallbackHttpPolicyOnError(Object error) {
    return _shouldUseRhttpTransport(_activeHttpPolicy) ||
        _isHttpProtocolError(error);
  }

  bool _tryFallbackHttpPolicy(String reason) {
    if (_httpPolicyIndex >= _httpPolicyFallbackChain.length - 1) {
      return false;
    }

    final fromPolicy = _activeHttpPolicy;
    _httpPolicyIndex += 1;
    final toPolicy = _activeHttpPolicy;

    _logger.warning(
      'NSFX-HTTP',
      'HTTP policy fallback triggered by $reason: $fromPolicy -> $toPolicy',
    );

    _lastNegotiatedHttpVersion = null;
    _client?.close(force: true);
    _client = null;
    _clientFuture = null;
    return true;
  }

  Future<_ProbeResult?> _probeGet(
    String url,
    Map<String, String> headers,
    DateTime deadline,
  ) async {
    final uri = Uri.parse(url);
    HttpClient? probeClient;

    try {
      final timeout = _probeTimeout(deadline);
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
      final negotiatedHttpVersion = await _resolveNegotiatedHttpVersionForUri(
        uri,
        headers,
        deadline,
      );
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
        return _ProbeResult(FileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
        ));
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP',
            'GET probe: size=$contentLength, range=$supportsRange');
        return _ProbeResult(FileInfo(
          size: contentLength,
          supportsRange: supportsRange,
          negotiatedHttpVersion: negotiatedHttpVersion,
        ));
      }

      if (statusCode == 206 && contentRange != null) {
        final match =
            RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
        if (match != null && match.group(1) != '*') {
          final size = int.parse(match.group(1)!);
          _logger.info('NSFX-HTTP', 'GET probe (206): size=$size, range=true');
          return _ProbeResult(FileInfo(
            size: size,
            supportsRange: true,
            negotiatedHttpVersion: negotiatedHttpVersion,
          ));
        }
      }

      if (statusCode == 200 && contentLength <= 0) {
        _logger.info(
            'NSFX-HTTP', 'GET probe: unknown size (chunked?), range=false');
        return _ProbeResult(FileInfo(
          size: 0,
          supportsRange: false,
          negotiatedHttpVersion: negotiatedHttpVersion,
        ));
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'GET probe failed: $error');

      if (_shouldFallbackHttpPolicyOnError(error) &&
          _tryFallbackHttpPolicy('GET probe error')) {
        return _probeGet(url, headers, deadline);
      }

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'GET probe detected proxy transport error, fallback eligible');
        return _ProbeResult(
            FileInfo(size: 0, supportsRange: false, proxyError: true));
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

  Future<FileInfo?> _probeRange(
      String url, Map<String, String> headers, DateTime deadline, String label,
      {int? sizeHint}) async {
    final uri = Uri.parse(url);
    HttpClient? probeClient;

    try {
      final timeout = _probeTimeout(deadline);
      probeClient = await _buildClient(
        connectionTimeout: timeout,
        idleTimeout: Duration(seconds: timeout.inSeconds + 5),
      );

      final request = await probeClient.getUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      request.headers.set('Range', 'bytes=0-0');

      final response = await request.close().timeout(timeout);
      final statusCode = response.statusCode;
      final negotiatedHttpVersion = await _resolveNegotiatedHttpVersionForUri(
        uri,
        headers,
        deadline,
      );
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
        return FileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
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
            return FileInfo(
              size: size,
              supportsRange: true,
              negotiatedHttpVersion: negotiatedHttpVersion,
            );
          }
        }

        final inferredSize = (sizeHint != null && sizeHint > 0) ? sizeHint : 0;
        _logger.info(
          'NSFX-HTTP',
          'Range probe ($label): status=206, content-range unavailable, '
              'inferredSize=$inferredSize, range=true',
        );
        return FileInfo(
          size: inferredSize,
          supportsRange: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
        );
      } else if (statusCode == 200 && contentLength > 0) {
        _logger.info('NSFX-HTTP',
            'Range probe ($label): size=$contentLength, range=false');
        return FileInfo(
          size: contentLength,
          supportsRange: false,
          negotiatedHttpVersion: negotiatedHttpVersion,
        );
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'Range probe ($label) failed: $error');

      if (_shouldFallbackHttpPolicyOnError(error) &&
          _tryFallbackHttpPolicy('Range probe ($label) error')) {
        return _probeRange(url, headers, deadline, label, sizeHint: sizeHint);
      }

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'Range probe ($label) detected proxy transport error, fallback eligible');
        return FileInfo(size: 0, supportsRange: false, proxyError: true);
      }
    } finally {
      probeClient?.close();
    }

    return null;
  }

  Future<FileInfo?> _probeHead(
    String url,
    Map<String, String> headers,
    DateTime deadline,
    String label,
  ) async {
    final uri = Uri.parse(url);
    HttpClient? probeClient;

    try {
      final timeout = _probeTimeout(deadline);
      probeClient = await _buildClient(
        connectionTimeout: timeout,
      );

      final request = await probeClient.headUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      final response = await request.close().timeout(timeout);
      final negotiatedHttpVersion = await _resolveNegotiatedHttpVersionForUri(
        uri,
        headers,
        deadline,
      );

      final statusCode = response.statusCode;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning(
            'NSFX-HTTP', 'HEAD probe ($label): proxy error status=$statusCode');
        return FileInfo(
          size: 0,
          supportsRange: false,
          proxyError: true,
          negotiatedHttpVersion: negotiatedHttpVersion,
        );
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP',
            'HEAD probe ($label): size=$contentLength, range=$supportsRange');
        return FileInfo(
          size: contentLength,
          supportsRange: supportsRange,
          negotiatedHttpVersion: negotiatedHttpVersion,
        );
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'HEAD probe ($label) failed: $error');

      if (_shouldFallbackHttpPolicyOnError(error) &&
          _tryFallbackHttpPolicy('HEAD probe ($label) error')) {
        return _probeHead(url, headers, deadline, label);
      }

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'HEAD probe ($label) detected proxy transport error, fallback eligible');
        return FileInfo(size: 0, supportsRange: false, proxyError: true);
      }
    } finally {
      probeClient?.close();
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
    final uri = Uri.parse(url);

    while (true) {
      try {
        final activeClient = await _ensureClient();
        final request = await activeClient.getUrl(uri);
        _applyHeaders(request, headers);

        if (start != null && end != null) {
          request.headers.set('Range', 'bytes=$start-${end - 1}');
        }

        final response = await request.close();
        if (!_shouldUseRhttpTransport(_activeHttpPolicy)) {
          _rememberNegotiatedHttpVersion(_activeNegotiatedHttpVersion());
        }
        return response;
      } catch (error, stackTrace) {
        if (_shouldFallbackHttpPolicyOnError(error) &&
            _tryFallbackHttpPolicy('GET request error')) {
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

  void _applyProxy(HttpClient client, {ProxySettings? proxy}) {
    final effectiveProxy = proxy ?? getActiveProxySettings();
    if (effectiveProxy == null) return;

    if (effectiveProxy.type == 'system') {
      client.findProxy = (uri) {
        if (_isLocalHost(uri.host)) return 'DIRECT';
        return HttpClient.findProxyFromEnvironment(uri);
      };
      return;
    }

    client.findProxy = (uri) {
      if (_isLocalHost(uri.host)) return 'DIRECT';
      return effectiveProxy.proxyDirective;
    };

    if (effectiveProxy.supportsHttpBasicAuth) {
      client.addProxyCredentials(
        effectiveProxy.host,
        effectiveProxy.port,
        'Basic',
        HttpClientBasicCredentials(
          effectiveProxy.username!,
          effectiveProxy.password!,
        ),
      );
    }
  }

  /// Existing API kept for compatibility with current download isolate params.
  String? getProxyString() {
    final proxy = getActiveProxySettings();
    if (proxy == null || proxy.type == 'system') return null;
    return '${proxy.host}:${proxy.port}';
  }

  ProxySettings? getActiveProxySettings() {
    if (!config.proxy.enabled || _proxyFailed) return null;

    if (config.proxy.type == 'system') {
      return const ProxySettings(
        type: 'system',
        host: '',
        port: 0,
      );
    }

    final proxyHost =
        config.proxy.host.isNotEmpty ? config.proxy.host : '127.0.0.1';

    return ProxySettings(
      type: config.proxy.type,
      host: proxyHost,
      port: config.proxy.port,
      username: config.proxy.username,
      password: config.proxy.password,
      requiresAuth: config.proxy.requiresAuth,
    );
  }

  void close() {
    _client?.close(force: true);
    _client = null;
    _clientFuture = null;
    _proxyFailed = false;
    _lastNegotiatedHttpVersion = null;
    _negotiatedVersionCache.clear();
  }

  bool _isLocalHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }
}

class _ProbeResult {
  final FileInfo fileInfo;

  _ProbeResult(this.fileInfo);
}

class ProxySettings {
  final String type;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final bool requiresAuth;

  const ProxySettings({
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.requiresAuth = false,
  });

  String get proxyDirective {
    if (type == 'socks5') {
      return 'SOCKS5 $host:$port';
    }
    return 'PROXY $host:$port';
  }

  bool get supportsHttpBasicAuth {
    return type != 'socks5' &&
        requiresAuth &&
        username != null &&
        username!.isNotEmpty &&
        password != null &&
        password!.isNotEmpty;
  }
}

class FileInfo {
  final int size;
  final bool supportsRange;
  final bool proxyError;
  final String? negotiatedHttpVersion;

  FileInfo(
      {required this.size,
      required this.supportsRange,
      this.proxyError = false,
      this.negotiatedHttpVersion});
}
