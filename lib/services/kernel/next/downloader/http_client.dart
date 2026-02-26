import 'dart:io';
import 'dart:async';
import '../config/download_config.dart';
import '../../../app_logger_service.dart';

class NsfxHttpClient {
  final NsfxConfig config;
  HttpClient? _client;
  final _logger = AppLoggerService();

  /// 代理连接失败后自动降级为直连
  bool _proxyFailed = false;

  NsfxHttpClient(this.config);

  HttpClient get client {
    _client ??= _createClient();
    return _client!;
  }

  HttpClient _createClient() {
    final client = HttpClient();

    // 连接超时：兼顾响应速度和慢服务器兼容性
    client.connectionTimeout = Duration(seconds: config.connectionTimeout.clamp(5, 30));
    client.idleTimeout = const Duration(seconds: 30); // 缩短空闲超时
    client.maxConnectionsPerHost = 128; // 增加连接数
    client.autoUncompress = false;
    
    // 代理配置（降级后跳过）
    if (config.proxy.enabled && !_proxyFailed) {
      final proxyHost = config.proxy.host.isNotEmpty ? config.proxy.host : '127.0.0.1';
      final proxyPort = config.proxy.port;

      if (config.proxy.type == 'system') {
        // 系统代理：走本地代理端口（Clash Verge 默认 7897）
        client.findProxy = (_) => 'PROXY $proxyHost:$proxyPort';
        _logger.info('NSFX-HTTP', 'Using system proxy: $proxyHost:$proxyPort');
      } else {
        client.findProxy = (_) => 'PROXY $proxyHost:$proxyPort';
        
        if (config.proxy.requiresAuth && 
            config.proxy.username != null && 
            config.proxy.password != null) {
          client.addProxyCredentials(
            proxyHost,
            proxyPort,
            'Basic',
            HttpClientBasicCredentials(
              config.proxy.username!,
              config.proxy.password!,
            ),
          );
        }
      }
    }

    // 忽略 SSL 证书错误（可选，提高兼容性）
    client.badCertificateCallback = (cert, host, port) => true;

    return client;
  }

  /// 获取文件信息 - 浏览器式策略 + 总超时保护
  /// 优先 GET 探测，回退 Range 和 HEAD。
  /// 总超时 15 秒（所有策略共享），网络不可达时立即失败。
  /// 代理开启时，若代理返回错误（502/503/407等）或连接失败，自动降级直连重试。
  Future<FileInfo> getFileInfo(String url, Map<String, String> headers) async {
    final result = await _getFileInfoInternal(url, headers);
    
    // 代理开启且探测失败（size==0 或被标记为代理错误） → 降级直连重试
    if ((result.size == 0 || result.proxyError) && _isProxyEnabled && !_proxyFailed) {
      _logger.warning('NSFX-HTTP', 'Proxy probe failed (proxyError=${result.proxyError}), falling back to direct connection');
      _switchToDirectConnection();
      return await _getFileInfoInternal(url, headers);
    }
    return result;
  }

  /// 是否当前配置了代理（且未降级）
  bool get _isProxyEnabled => config.proxy.enabled && !_proxyFailed;

  /// 降级为直连：关闭旧 client，标记代理失败
  void _switchToDirectConnection() {
    _proxyFailed = true;
    _client?.close(force: true);
    _client = null; // 下次访问 client getter 会创建无代理的新实例
    _logger.info('NSFX-HTTP', 'Switched to direct connection (proxy bypassed)');
  }

  /// 外部调用：下载过程中遇到代理错误时切换到直连
  void switchToDirectOnProxyError() {
    if (_proxyFailed) return; // 已经切换过了
    _logger.warning('NSFX-HTTP', 'Proxy error during download, switching to direct connection');
    _switchToDirectConnection();
  }

  Future<FileInfo> _getFileInfoInternal(String url, Map<String, String> headers) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));

    // 策略1（主）：直接 GET，从响应头提取信息
    final getResult = await _probeGet(url, headers, deadline);
    if (getResult != null) return getResult.fileInfo;
    // 网络不可达（DNS 失败、TCP 拒绝、信号灯超时等），直接放弃不重试
    if (getResult == null && _isDeadlineExceeded(deadline)) {
      _logger.warning('NSFX-HTTP', 'Probe deadline exceeded, giving up');
      return FileInfo(size: 0, supportsRange: false);
    }

    // 策略2（备）：Range 探测（精确确认 Range 支持）
    final rangeResult = await _probeRange(url, headers, deadline, 'fallback');
    if (rangeResult != null) return rangeResult;
    if (_isDeadlineExceeded(deadline)) {
      _logger.warning('NSFX-HTTP', 'Probe deadline exceeded after Range probe');
      return FileInfo(size: 0, supportsRange: false);
    }

    // 策略3（兜底）：HEAD 请求
    final headResult = await _probeHead(url, headers, deadline, 'fallback');
    if (headResult != null) return headResult;

    _logger.warning('NSFX-HTTP', 'Could not determine file info after all strategies');
    return FileInfo(size: 0, supportsRange: false);
  }

  bool _isDeadlineExceeded(DateTime deadline) {
    return DateTime.now().isAfter(deadline);
  }

  Duration _remainingTime(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    // 至少给 2 秒，避免超短超时导致无意义请求
    return remaining.inSeconds < 2 ? const Duration(seconds: 2) : remaining;
  }

  /// 判断是否为网络不可达错误（不值得重试）
  bool _isNetworkUnreachable(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('errno = 121') ||       // Windows 信号灯超时
           msg.contains('errno = 110') ||       // Linux ETIMEDOUT
           msg.contains('errno = 111') ||       // Linux ECONNREFUSED
           msg.contains('errno = 113') ||       // Linux EHOSTUNREACH
           msg.contains('no route to host') ||
           msg.contains('network is unreachable') ||
           msg.contains('connection refused') ||
           msg.contains('no address associated') || // DNS 失败
           msg.contains('name or service not known');
  }

  /// 判断 HTTP 状态码是否为代理相关错误
  bool _isProxyErrorStatus(int statusCode) {
    return statusCode == 502 || // Bad Gateway
           statusCode == 503 || // Service Unavailable
           statusCode == 407 || // Proxy Authentication Required
           statusCode == 504 || // Gateway Timeout
           statusCode == 523 || // Origin Is Unreachable (Cloudflare via proxy)
           statusCode == 525;   // SSL Handshake Failed (proxy SSL issue)
  }

  /// GET 探测：发送普通 GET，从响应头提取文件信息后立即断开
  Future<_ProbeResult?> _probeGet(
    String url, Map<String, String> headers, DateTime deadline,
  ) async {
    final uri = Uri.parse(url);
    HttpClient? probeClient;
    try {
      final timeout = _remainingTime(deadline);
      probeClient = HttpClient();
      probeClient.connectionTimeout = timeout;
      probeClient.idleTimeout = Duration(seconds: timeout.inSeconds + 5);
      probeClient.autoUncompress = false;
      probeClient.badCertificateCallback = (cert, host, port) => true;
      _applyProxy(probeClient);

      final request = await probeClient.getUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);

      final response = await request.close().timeout(timeout);
      final statusCode = response.statusCode;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');
      final contentRange = response.headers.value('content-range');

      probeClient.close(force: true);
      probeClient = null;

      // 代理错误码 → 立即返回，触发 fallback
      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning('NSFX-HTTP', 'GET probe: proxy error status=$statusCode');
        return _ProbeResult(FileInfo(size: 0, supportsRange: false, proxyError: true));
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP', 'GET probe: size=$contentLength, range=$supportsRange');
        return _ProbeResult(FileInfo(size: contentLength, supportsRange: supportsRange));
      } else if (statusCode == 206 && contentRange != null) {
        final match = RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
        if (match != null && match.group(1) != '*') {
          final size = int.parse(match.group(1)!);
          _logger.info('NSFX-HTTP', 'GET probe (206): size=$size, range=true');
          return _ProbeResult(FileInfo(size: size, supportsRange: true));
        }
      } else if (statusCode == 200 && contentLength <= 0) {
        _logger.info('NSFX-HTTP', 'GET probe: unknown size (chunked?), range=false');
        return _ProbeResult(FileInfo(size: 0, supportsRange: false));
      }
    } catch (e) {
      _logger.debug('NSFX-HTTP', 'GET probe failed: $e');
      if (_isNetworkUnreachable(e)) {
        _logger.warning('NSFX-HTTP', 'Network unreachable, skipping remaining probes');
        // 返回 null，外层检查 deadline 会直接放弃
      }
    } finally {
      probeClient?.close(force: true);
    }
    return null;
  }

  /// Range 探测：bytes=0-0 获取文件大小和 Range 支持
  Future<FileInfo?> _probeRange(
    String url, Map<String, String> headers, DateTime deadline, String label,
  ) async {
    final uri = Uri.parse(url);
    HttpClient? probeClient;
    try {
      final timeout = _remainingTime(deadline);
      probeClient = HttpClient();
      probeClient.connectionTimeout = timeout;
      probeClient.idleTimeout = Duration(seconds: timeout.inSeconds + 5);
      probeClient.badCertificateCallback = (cert, host, port) => true;
      _applyProxy(probeClient);

      final request = await probeClient.getUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      request.headers.set('Range', 'bytes=0-0');

      final response = await request.close().timeout(timeout);
      final statusCode = response.statusCode;
      final contentRange = response.headers.value('content-range');
      final contentLength = response.contentLength;

      probeClient.close(force: true);
      probeClient = null;

      // 代理错误码 → 立即返回，触发 fallback
      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning('NSFX-HTTP', 'Range probe ($label): proxy error status=$statusCode');
        return FileInfo(size: 0, supportsRange: false, proxyError: true);
      }

      if (statusCode == 206 && contentRange != null) {
        final match = RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
        if (match != null && match.group(1) != '*') {
          final size = int.parse(match.group(1)!);
          _logger.info('NSFX-HTTP', 'Range probe ($label): size=$size, range=true');
          return FileInfo(size: size, supportsRange: true);
        }
      } else if (statusCode == 200 && contentLength > 0) {
        _logger.info('NSFX-HTTP', 'Range probe ($label): size=$contentLength, range=false');
        return FileInfo(size: contentLength, supportsRange: false);
      }
    } catch (e) {
      _logger.debug('NSFX-HTTP', 'Range probe ($label) failed: $e');
    } finally {
      probeClient?.close(force: true);
    }
    return null;
  }

  /// HEAD 探测：获取 Content-Length 和 Accept-Ranges
  Future<FileInfo?> _probeHead(
    String url, Map<String, String> headers, DateTime deadline, String label,
  ) async {
    final uri = Uri.parse(url);
    HttpClient? probeClient;
    try {
      final timeout = _remainingTime(deadline);
      probeClient = HttpClient();
      probeClient.connectionTimeout = timeout;
      probeClient.badCertificateCallback = (cert, host, port) => true;
      _applyProxy(probeClient);

      final request = await probeClient.headUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      final response = await request.close().timeout(timeout);

      final statusCode = response.statusCode;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');

      probeClient.close(force: true);
      probeClient = null;

      // 代理错误码 → 立即返回，触发 fallback
      if (_isProxyEnabled && _isProxyErrorStatus(statusCode)) {
        _logger.warning('NSFX-HTTP', 'HEAD probe ($label): proxy error status=$statusCode');
        return FileInfo(size: 0, supportsRange: false, proxyError: true);
      }

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP', 'HEAD probe ($label): size=$contentLength, range=$supportsRange');
        return FileInfo(size: contentLength, supportsRange: supportsRange);
      }
    } catch (e) {
      _logger.debug('NSFX-HTTP', 'HEAD probe ($label) failed: $e');
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
    return await request.close();
  }

  Future<HttpClientResponse> get(String url, Map<String, String> headers) async {
    final uri = Uri.parse(url);
    final request = await client.getUrl(uri);
    _applyHeaders(request, headers);
    return await request.close();
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String> headers) {
    headers.forEach((key, value) {
      request.headers.set(key, value);
    });
  }

  /// 给任意 HttpClient 应用代理配置（代理降级后不再应用）
  void _applyProxy(HttpClient client) {
    if (!config.proxy.enabled || _proxyFailed) return;
    final proxyHost = config.proxy.host.isNotEmpty ? config.proxy.host : '127.0.0.1';
    final proxyPort = config.proxy.port;
    client.findProxy = (_) => 'PROXY $proxyHost:$proxyPort';
  }

  /// 获取代理配置字符串，供 Isolate 使用（代理降级后返回 null）
  String? getProxyString() {
    if (!config.proxy.enabled || _proxyFailed) return null;
    final proxyHost = config.proxy.host.isNotEmpty ? config.proxy.host : '127.0.0.1';
    return '$proxyHost:${config.proxy.port}';
  }

  void close() {
    _client?.close(force: true);
    _client = null;
    _proxyFailed = false; // 重置代理降级状态，下次任务重新尝试代理
  }
}

class _ProbeResult {
  final FileInfo fileInfo;
  _ProbeResult(this.fileInfo);
}

class FileInfo {
  final int size;
  final bool supportsRange;
  final bool proxyError;

  FileInfo({required this.size, required this.supportsRange, this.proxyError = false});
}
