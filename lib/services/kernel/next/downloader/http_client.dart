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
    
    client.connectionTimeout = Duration(seconds: config.connectionTimeout);
    client.idleTimeout = const Duration(seconds: 120);
    client.maxConnectionsPerHost = 64;
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

  Future<FileInfo> getFileInfo(String url, Map<String, String> headers) async {
    final uri = Uri.parse(url);
    int? fileSize;
    
    // 先尝试 HEAD 请求获取文件大小
    try {
      final request = await client.headUrl(uri);
      _applyHeaders(request, headers);
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final contentLength = response.contentLength;
        final acceptRanges = response.headers.value('accept-ranges');
        
        await response.drain();
        
        if (contentLength > 0) {
          fileSize = contentLength;
          // 如果明确声明支持 Range，直接返回
          if (acceptRanges?.toLowerCase() == 'bytes') {
            _logger.info('NSFX-HTTP', 'HEAD: size=$contentLength, range=true (Accept-Ranges header)');
            return FileInfo(size: contentLength, supportsRange: true);
          }
          _logger.info('NSFX-HTTP', 'HEAD: size=$contentLength, checking Range support...');
        }
      } else {
        await response.drain();
      }
    } catch (e) {
      _logger.warning('NSFX-HTTP', 'HEAD request failed: $e');
    }

    // 用 Range 请求验证是否支持断点续传
    try {
      final request = await client.getUrl(uri);
      _applyHeaders(request, headers);
      request.headers.set('Range', 'bytes=0-0');
      final response = await request.close();

      if (response.statusCode == 206) {
        final contentRange = response.headers.value('content-range');
        if (contentRange != null) {
          final match = RegExp(r'bytes \d+-\d+/(\d+)').firstMatch(contentRange);
          if (match != null) {
            final size = int.parse(match.group(1)!);
            await response.drain();
            _logger.info('NSFX-HTTP', 'Range probe: size=$size, range=true');
            return FileInfo(size: size, supportsRange: true);
          }
        }
        await response.drain();
        // 206 但没有 Content-Range，使用 HEAD 获取的大小
        if (fileSize != null) {
          _logger.info('NSFX-HTTP', 'Range probe: 206 without Content-Range, size=$fileSize, range=true');
          return FileInfo(size: fileSize, supportsRange: true);
        }
      } else if (response.statusCode == 200) {
        // 服务器忽略了 Range 请求，不支持断点续传
        final contentLength = response.contentLength;
        await response.drain();
        final size = fileSize ?? contentLength;
        _logger.info('NSFX-HTTP', 'Range probe: server returned 200 (ignores Range), size=$size, range=false');
        return FileInfo(size: size, supportsRange: false);
      }
      
      await response.drain();
    } catch (e) {
      _logger.warning('NSFX-HTTP', 'Range probe failed: $e');
    }

    // 如果有 HEAD 获取的大小，返回它（假设不支持 Range）
    if (fileSize != null) {
      _logger.info('NSFX-HTTP', 'Fallback: size=$fileSize, range=false');
      return FileInfo(size: fileSize, supportsRange: false);
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
