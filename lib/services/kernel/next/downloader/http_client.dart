import 'dart:async';
import 'dart:io';

import '../config/download_config.dart';
import '../../../app_logger_service.dart';

class NsfxHttpClient {
  final NsfxConfig config;
  HttpClient? _client;
  final _logger = AppLoggerService();

  /// Proxy connection failed and has been downgraded to direct mode.
  bool _proxyFailed = false;

  NsfxHttpClient(this.config);

  static HttpClient createRawHttpClient({
    required String httpVersionPolicy,
    Duration? connectionTimeout,
    Duration? idleTimeout,
    int? maxConnectionsPerHost,
    bool autoUncompress = false,
    String? userAgent,
  }) {
    final normalizedPolicy =
        NsfxHttpVersionPolicy.normalizeForDartIo(httpVersionPolicy);
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

  HttpClient get client {
    _client ??= _createClient();
    return _client!;
  }

  HttpClient _buildClient({
    Duration? connectionTimeout,
    Duration? idleTimeout,
    int? maxConnectionsPerHost,
    bool autoUncompress = false,
    ProxySettings? proxy,
  }) {
    final httpClient = createRawHttpClient(
      httpVersionPolicy: config.httpVersionPolicy,
      connectionTimeout: connectionTimeout,
      idleTimeout: idleTimeout,
      maxConnectionsPerHost: maxConnectionsPerHost,
      autoUncompress: autoUncompress,
      userAgent: config.defaultUserAgent,
    );

    _applyProxy(httpClient, proxy: proxy);
    return httpClient;
  }

  HttpClient _createClient() {
    final normalizedPolicy =
        NsfxHttpVersionPolicy.normalize(config.httpVersionPolicy);
    final effectivePolicy =
        NsfxHttpVersionPolicy.normalizeForDartIo(config.httpVersionPolicy);

    // Balance responsiveness and slow-server compatibility.
    final httpClient = _buildClient(
      connectionTimeout:
          Duration(seconds: config.connectionTimeout.clamp(5, 30)),
      idleTimeout: const Duration(seconds: 30),
      maxConnectionsPerHost: 128,
      autoUncompress: false,
      proxy: getActiveProxySettings(),
    );

    final proxy = getActiveProxySettings();
    if (proxy != null) {
      _logger.info('NSFX-HTTP',
          'Using proxy: ${proxy.type} ${proxy.host}:${proxy.port}');
    }
    if (!NsfxHttpVersionPolicy.isSupportedByDartIo(normalizedPolicy)) {
      _logger.warning(
        'NSFX-HTTP',
        'HTTP/3 is not supported by current dart:io HttpClient transport, '
            'fallback to $effectivePolicy',
      );
    }
    _logger.info('NSFX-HTTP',
        'HTTP policy: $normalizedPolicy (effective=$effectivePolicy)');

    return httpClient;
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
    _logger.info('NSFX-HTTP', 'Switched to direct connection (proxy bypassed)');
  }

  void switchToDirectOnProxyError() {
    if (_proxyFailed) return;
    _logger.warning('NSFX-HTTP',
        'Proxy error during download, switching to direct connection');
    _switchToDirectConnection();
  }

  Future<FileInfo> _getFileInfoInternal(
      String url, Map<String, String> headers) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));

    final getResult = await _probeGet(url, headers, deadline);
    if (getResult != null) return getResult.fileInfo;

    if (_isDeadlineExceeded(deadline)) {
      _logger.warning('NSFX-HTTP', 'Probe deadline exceeded, giving up');
      return FileInfo(size: 0, supportsRange: false);
    }

    final rangeResult = await _probeRange(url, headers, deadline, 'fallback');
    if (rangeResult != null) return rangeResult;

    if (_isDeadlineExceeded(deadline)) {
      _logger.warning('NSFX-HTTP', 'Probe deadline exceeded after Range probe');
      return FileInfo(size: 0, supportsRange: false);
    }

    final headResult = await _probeHead(url, headers, deadline, 'fallback');
    if (headResult != null) return headResult;

    _logger.warning(
        'NSFX-HTTP', 'Could not determine file info after all strategies');
    return FileInfo(size: 0, supportsRange: false);
  }

  bool _isDeadlineExceeded(DateTime deadline) =>
      DateTime.now().isAfter(deadline);

  Duration _remainingTime(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    return remaining.inSeconds < 2 ? const Duration(seconds: 2) : remaining;
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
        message.contains('failed host lookup');

    if (!maybeNetworkTransportError) return false;

    if (proxyHost.isNotEmpty && message.contains(proxyHost)) return true;
    if (proxyPort.isNotEmpty && message.contains(':$proxyPort')) return true;

    return false;
  }

  Future<_ProbeResult?> _probeGet(
    String url,
    Map<String, String> headers,
    DateTime deadline,
  ) async {
    final uri = Uri.parse(url);
    HttpClient? probeClient;

    try {
      final timeout = _remainingTime(deadline);
      probeClient = _buildClient(
        connectionTimeout: timeout,
        idleTimeout: Duration(seconds: timeout.inSeconds + 5),
        autoUncompress: false,
      );

      final request = await probeClient.getUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);

      final response = await request.close().timeout(timeout);
      final statusCode = response.statusCode;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');
      final contentRange = response.headers.value('content-range');

      probeClient.close(force: true);
      probeClient = null;

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning(
            'NSFX-HTTP', 'GET probe: proxy error status=$statusCode');
        return _ProbeResult(
            FileInfo(size: 0, supportsRange: false, proxyError: true));
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP',
            'GET probe: size=$contentLength, range=$supportsRange');
        return _ProbeResult(
            FileInfo(size: contentLength, supportsRange: supportsRange));
      }

      if (statusCode == 206 && contentRange != null) {
        final match =
            RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
        if (match != null && match.group(1) != '*') {
          final size = int.parse(match.group(1)!);
          _logger.info('NSFX-HTTP', 'GET probe (206): size=$size, range=true');
          return _ProbeResult(FileInfo(size: size, supportsRange: true));
        }
      }

      if (statusCode == 200 && contentLength <= 0) {
        _logger.info(
            'NSFX-HTTP', 'GET probe: unknown size (chunked?), range=false');
        return _ProbeResult(FileInfo(size: 0, supportsRange: false));
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'GET probe failed: $error');

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
      probeClient?.close(force: true);
    }

    return null;
  }

  Future<FileInfo?> _probeRange(
    String url,
    Map<String, String> headers,
    DateTime deadline,
    String label,
  ) async {
    final uri = Uri.parse(url);
    HttpClient? probeClient;

    try {
      final timeout = _remainingTime(deadline);
      probeClient = _buildClient(
        connectionTimeout: timeout,
        idleTimeout: Duration(seconds: timeout.inSeconds + 5),
      );

      final request = await probeClient.getUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      request.headers.set('Range', 'bytes=0-0');

      final response = await request.close().timeout(timeout);
      final statusCode = response.statusCode;
      final contentRange = response.headers.value('content-range');
      final contentLength = response.contentLength;

      probeClient.close(force: true);
      probeClient = null;

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning('NSFX-HTTP',
            'Range probe ($label): proxy error status=$statusCode');
        return FileInfo(size: 0, supportsRange: false, proxyError: true);
      }

      if (statusCode == 206 && contentRange != null) {
        final match =
            RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
        if (match != null && match.group(1) != '*') {
          final size = int.parse(match.group(1)!);
          _logger.info(
              'NSFX-HTTP', 'Range probe ($label): size=$size, range=true');
          return FileInfo(size: size, supportsRange: true);
        }
      } else if (statusCode == 200 && contentLength > 0) {
        _logger.info('NSFX-HTTP',
            'Range probe ($label): size=$contentLength, range=false');
        return FileInfo(size: contentLength, supportsRange: false);
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'Range probe ($label) failed: $error');

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'Range probe ($label) detected proxy transport error, fallback eligible');
        return FileInfo(size: 0, supportsRange: false, proxyError: true);
      }
    } finally {
      probeClient?.close(force: true);
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
      final timeout = _remainingTime(deadline);
      probeClient = _buildClient(
        connectionTimeout: timeout,
      );

      final request = await probeClient.headUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      final response = await request.close().timeout(timeout);

      final statusCode = response.statusCode;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');

      probeClient.close(force: true);
      probeClient = null;

      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning(
            'NSFX-HTTP', 'HEAD probe ($label): proxy error status=$statusCode');
        return FileInfo(size: 0, supportsRange: false, proxyError: true);
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP',
            'HEAD probe ($label): size=$contentLength, range=$supportsRange');
        return FileInfo(size: contentLength, supportsRange: supportsRange);
      }
    } catch (error) {
      _logger.debug('NSFX-HTTP', 'HEAD probe ($label) failed: $error');

      if (_isProxyTransportError(error)) {
        _logger.warning('NSFX-HTTP',
            'HEAD probe ($label) detected proxy transport error, fallback eligible');
        return FileInfo(size: 0, supportsRange: false, proxyError: true);
      }
    } finally {
      probeClient?.close(force: true);
    }

    return null;
  }

  Future<HttpClientResponse> getRange(
    String url,
    Map<String, String> headers,
    int start,
    int end,
  ) async {
    final uri = Uri.parse(url);
    final request = await client.getUrl(uri);
    _applyHeaders(request, headers);
    request.headers.set('Range', 'bytes=$start-${end - 1}');
    return request.close();
  }

  Future<HttpClientResponse> get(
      String url, Map<String, String> headers) async {
    final uri = Uri.parse(url);
    final request = await client.getUrl(uri);
    _applyHeaders(request, headers);
    return request.close();
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String> headers) {
    headers.forEach((key, value) {
      request.headers.set(key, value);
    });
  }

  void _applyProxy(HttpClient client, {ProxySettings? proxy}) {
    final effectiveProxy = proxy ?? getActiveProxySettings();
    if (effectiveProxy == null) return;

    client.findProxy = (_) => effectiveProxy.proxyDirective;

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
    if (proxy == null) return null;
    return '${proxy.host}:${proxy.port}';
  }

  ProxySettings? getActiveProxySettings() {
    if (!config.proxy.enabled || _proxyFailed) return null;

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
    _proxyFailed = false;
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

  FileInfo(
      {required this.size,
      required this.supportsRange,
      this.proxyError = false});
}
