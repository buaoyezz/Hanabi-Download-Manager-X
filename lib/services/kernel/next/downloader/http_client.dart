import 'dart:io';
import 'dart:async';
import '../config/download_config.dart';
import '../../../app_logger_service.dart';

class NsfxHttpClient {
  final NsfxConfig config;
  HttpClient? _client;
  final _logger = AppLoggerService();

  NsfxHttpClient(this.config);

  HttpClient get client {
    _client ??= _createClient();
    return _client!;
  }

  HttpClient _createClient() {
    final client = HttpClient();

    // 优化：缩短连接超时，提高响应速度
    client.connectionTimeout = Duration(seconds: config.connectionTimeout.clamp(5, 15));
    client.idleTimeout = const Duration(seconds: 30); // 缩短空闲超时
    client.maxConnectionsPerHost = 128; // 增加连接数
    client.autoUncompress = false;
    
    // 代理配置
    if (config.proxy.enabled) {
      if (config.proxy.type == 'system') {
        client.findProxy = HttpClient.findProxyFromEnvironment;
      } else {
        final proxyUrl = config.proxy.toProxyUrl();
        if (proxyUrl != null) {
          client.findProxy = (_) => 'PROXY ${config.proxy.host}:${config.proxy.port}';
          
          if (config.proxy.requiresAuth && 
              config.proxy.username != null && 
              config.proxy.password != null) {
            client.addProxyCredentials(
              config.proxy.host,
              config.proxy.port,
              'Basic',
              HttpClientBasicCredentials(
                config.proxy.username!,
                config.proxy.password!,
              ),
            );
          }
        }
      }
    }

    // 忽略 SSL 证书错误（可选，提高兼容性）
    client.badCertificateCallback = (cert, host, port) => true;

    return client;
  }

  /// 快速获取文件信息 - 优化版
  /// 直接用 Range 请求，一次获取所有信息
  Future<FileInfo> getFileInfo(String url, Map<String, String> headers) async {
    final uri = Uri.parse(url);
    const timeout = Duration(seconds: 3); // 缩短超时到3秒

    // 使用独立的 HttpClient 进行探测，避免影响主下载连接池
    // 探测完成后直接 force close，不会卡住
    HttpClient? probeClient;

    // 策略：直接发 Range 请求，一次性获取文件大小和 Range 支持信息
    try {
      probeClient = HttpClient();
      probeClient.connectionTimeout = const Duration(seconds: 3);
      probeClient.idleTimeout = const Duration(seconds: 5);

      final request = await probeClient.getUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      request.headers.set('Range', 'bytes=0-0');

      final response = await request.close().timeout(timeout);
      final statusCode = response.statusCode;
      final contentRange = response.headers.value('content-range');
      final contentLength = response.contentLength;

      // 立即强制关闭，不等待响应体
      probeClient.close(force: true);
      probeClient = null;

      if (statusCode == 206 && contentRange != null) {
        // 格式: bytes 0-0/12345
        final match = RegExp(r'bytes \d+-\d+/(\d+|\*)').firstMatch(contentRange);
        if (match != null && match.group(1) != '*') {
          final size = int.parse(match.group(1)!);
          _logger.info('NSFX-HTTP', 'Fast probe: size=$size, range=true');
          return FileInfo(size: size, supportsRange: true);
        }
      } else if (statusCode == 200 && contentLength > 0) {
        // 服务器不支持 Range，返回了完整内容
        _logger.info('NSFX-HTTP', 'Fast probe: size=$contentLength, range=false');
        return FileInfo(size: contentLength, supportsRange: false);
      }
    } catch (e) {
      _logger.debug('NSFX-HTTP', 'Range probe failed: $e');
    } finally {
      probeClient?.close(force: true);
    }

    // 备用方案：HEAD 请求
    try {
      probeClient = HttpClient();
      probeClient.connectionTimeout = const Duration(seconds: 3);

      final request = await probeClient.headUrl(uri).timeout(timeout);
      _applyHeaders(request, headers);
      final response = await request.close().timeout(timeout);

      final statusCode = response.statusCode;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');

      probeClient.close(force: true);
      probeClient = null;

      if (statusCode == 200 && contentLength > 0) {
        final supportsRange = acceptRanges?.toLowerCase() == 'bytes';
        _logger.info('NSFX-HTTP', 'HEAD fallback: size=$contentLength, range=$supportsRange');
        return FileInfo(size: contentLength, supportsRange: supportsRange);
      }
    } catch (e) {
      _logger.debug('NSFX-HTTP', 'HEAD fallback failed: $e');
    } finally {
      probeClient?.close(force: true);
    }

    _logger.warning('NSFX-HTTP', 'Could not determine file info');
    return FileInfo(size: 0, supportsRange: false);
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

  void close() {
    _client?.close(force: true);
    _client = null;
  }
}

class FileInfo {
  final int size;
  final bool supportsRange;

  FileInfo({required this.size, required this.supportsRange});
}
