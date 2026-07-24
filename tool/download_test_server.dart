import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Deterministic content generator used by the local download test server.
///
/// Bytes can be reproduced from any absolute offset, so range responses do
/// not need a large fixture file in memory or on disk.
class DownloadTestPattern {
  static int byteAt(int offset, {int seed = 7, int version = 1}) {
    final mixed = offset * 31 + (offset >> 8) * 17 + seed * 13 + version * 29;
    return mixed & 0xff;
  }

  static Uint8List bytes(
    int offset,
    int length, {
    int seed = 7,
    int version = 1,
  }) {
    final output = Uint8List(length);
    for (var index = 0; index < length; index++) {
      output[index] = byteAt(offset + index, seed: seed, version: version);
    }
    return output;
  }
}

class DownloadTestScenario {
  static const normal = 'normal';
  static const slow = 'slow';
  static const noRange = 'no-range';
  static const disconnectOnce = 'disconnect-once';
  static const stallOnce = 'stall-once';
  static const flaky503 = 'flaky-503';
  static const badContentRange = 'bad-content-range';
  static const truncated = 'truncated';
  static const changing = 'changing';
  static const status = 'status';

  static const supported = <String>{
    normal,
    slow,
    noRange,
    disconnectOnce,
    stallOnce,
    flaky503,
    badContentRange,
    truncated,
    changing,
    status,
  };

  static const descriptions = <String, String>{
    normal: 'Correct HTTP byte-range server.',
    slow: 'Correct byte ranges with configurable per-chunk delay.',
    noRange: 'Ignores Range and always returns HTTP 200.',
    disconnectOnce: 'Closes the first transfer after a partial body.',
    stallOnce:
        'Stalls the first transfer long enough to exercise read timeout.',
    flaky503: 'Returns HTTP 503 for the configured number of attempts.',
    badContentRange: 'Returns a deliberately shifted Content-Range.',
    truncated: 'Always closes before the advertised body is complete.',
    changing: 'Versioned content controlled through the resource API.',
    status: 'Returns the status code supplied through ?code=.',
  };
}

class LocalDownloadTestServer {
  LocalDownloadTestServer({
    this.host = '127.0.0.1',
    this.port = 0,
    this.allowRemote = false,
    this.quiet = true,
  });

  final String host;
  final int port;
  final bool allowRemote;
  final bool quiet;

  HttpServer? _server;
  DateTime? _startedAt;
  int _totalRequests = 0;
  int _activeRequests = 0;
  int _maxActiveRequests = 0;
  int _rangeRequests = 0;
  int _completedTransfers = 0;
  int _injectedFailures = 0;
  int _bytesSent = 0;
  final Map<String, int> _scenarioRequests = {};
  final Map<String, int> _transferAttempts = {};
  final Map<String, int> _resourceVersions = {};
  final List<Map<String, dynamic>> _recentRequests = [];

  bool get isRunning => _server != null;
  int get boundPort => _server?.port ?? port;
  Uri get baseUri => Uri.parse('http://${_uriHost(host)}:$boundPort');

  void setResourceVersion(String resource, int version) {
    final normalized = resource.trim();
    if (normalized.isEmpty || version < 1) {
      throw ArgumentError('Resource and positive version are required.');
    }
    _resourceVersions[normalized] = version;
    _transferAttempts.removeWhere((key, _) => key.endsWith('|$normalized'));
  }

  Future<Uri> start() async {
    if (_server != null) return baseUri;
    if (!_isLoopbackHost(host) && !allowRemote) {
      throw ArgumentError(
        'Refusing to bind download test APIs to non-loopback host "$host". '
        'Pass allowRemote=true explicitly if this is intentional.',
      );
    }
    if (port < 0 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'must be between 0 and 65535');
    }

    final server = await HttpServer.bind(host, port, shared: false);
    _server = server;
    _startedAt = DateTime.now().toUtc();
    server.listen(
      _handleRequest,
      onError: (Object error, StackTrace stackTrace) {
        if (!quiet) stderr.writeln('[download-test-server] $error');
      },
    );
    return baseUri;
  }

  Future<void> close({bool force = true}) async {
    final server = _server;
    _server = null;
    if (server != null) await server.close(force: force);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _totalRequests++;
    _activeRequests++;
    _maxActiveRequests = max(_maxActiveRequests, _activeRequests);
    _applyCommonHeaders(request.response);
    _rememberRequest(request);

    try {
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      final segments = request.uri.pathSegments;
      if (request.uri.path == '/health') {
        await _sendJson(request.response, HttpStatus.ok, {
          'ok': true,
          'service': 'hdmx-download-test-server',
          'version': 1,
          'baseUrl': baseUri.toString(),
          'uptimeMs': _uptime.inMilliseconds,
        });
        return;
      }

      if (segments.length >= 2 && segments[0] == 'api' && segments[1] == 'v1') {
        await _handleApi(request, segments.skip(2).toList(growable: false));
        return;
      }

      if (segments.length >= 3 && segments[0] == 'download') {
        await _handleDownload(
          request,
          scenario: segments[1],
          sizeToken: segments[2],
        );
        return;
      }

      await _sendJson(request.response, HttpStatus.notFound, {
        'error': 'not_found',
        'message': 'Use /api/v1/scenarios or /download/{scenario}/{size}.bin',
      });
    } catch (error, stackTrace) {
      if (!quiet) {
        stderr.writeln('[download-test-server] request failed: $error');
        stderr.writeln(stackTrace);
      }
      try {
        await _sendJson(request.response, HttpStatus.internalServerError, {
          'error': 'internal_error',
          'message': error.toString(),
        });
      } catch (_) {}
    } finally {
      _activeRequests = max(0, _activeRequests - 1);
    }
  }

  Future<void> _handleApi(
    HttpRequest request,
    List<String> segments,
  ) async {
    final path = segments.join('/');
    if (request.method == 'GET' && path == 'capabilities') {
      await _sendJson(request.response, HttpStatus.ok, {
        'service': 'hdmx-download-test-server',
        'apiVersion': 1,
        'loopbackOnly': _isLoopbackHost(host),
        'maxGeneratedSize': _maxGeneratedSize,
        'sizeExamples': ['512k.bin', '8m.bin', '1g.bin'],
        'queryParameters': {
          'seed': 'deterministic content seed',
          'chunkBytes': 'response write chunk size',
          'delayMs': 'delay after each chunk',
          'failAfterBytes': 'bytes sent before disconnect/stall',
          'stallMs': 'stall duration',
          'failures': 'number of injected 503 responses',
          'code': 'HTTP status used by the status scenario',
          'resource': 'logical resource identity for attempts/versioning',
        },
      });
      return;
    }

    if (request.method == 'GET' && path == 'scenarios') {
      await _sendJson(request.response, HttpStatus.ok, {
        'scenarios': DownloadTestScenario.descriptions.entries
            .map((entry) => {
                  'id': entry.key,
                  'description': entry.value,
                  'example': baseUri
                      .resolve(
                        'download/${entry.key}/8m.bin',
                      )
                      .toString(),
                })
            .toList(growable: false),
      });
      return;
    }

    if (request.method == 'GET' && path == 'stats') {
      await _sendJson(request.response, HttpStatus.ok, _statsJson());
      return;
    }

    if (request.method == 'POST' &&
        (path == 'stats/reset' || path == 'control/reset')) {
      _resetStats(resetAttempts: path == 'control/reset');
      await _sendJson(request.response, HttpStatus.ok, {
        'ok': true,
        'resetAttempts': path == 'control/reset',
      });
      return;
    }

    if (request.method == 'GET' && path == 'resources') {
      await _sendJson(request.response, HttpStatus.ok, {
        'versions': Map<String, int>.from(_resourceVersions),
      });
      return;
    }

    if (request.method == 'POST' && path == 'resources/version') {
      final body = await _readJsonBody(request);
      final resource = (body['resource'] ?? 'default').toString().trim();
      final version = _intValue(body['version'], fallback: 1).clamp(1, 1000000);
      if (resource.isEmpty) {
        await _sendJson(request.response, HttpStatus.badRequest, {
          'error': 'invalid_resource',
        });
        return;
      }
      _resourceVersions[resource] = version;
      _transferAttempts.removeWhere((key, _) => key.endsWith('|$resource'));
      await _sendJson(request.response, HttpStatus.ok, {
        'ok': true,
        'resource': resource,
        'version': version,
      });
      return;
    }

    await _sendJson(request.response, HttpStatus.notFound, {
      'error': 'api_not_found',
      'path': '/api/v1/$path',
    });
  }

  Future<void> _handleDownload(
    HttpRequest request, {
    required String scenario,
    required String sizeToken,
  }) async {
    if (!DownloadTestScenario.supported.contains(scenario)) {
      await _sendJson(request.response, HttpStatus.notFound, {
        'error': 'unknown_scenario',
        'scenario': scenario,
      });
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      request.response.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
      await request.response.close();
      return;
    }

    final size = _parseSize(sizeToken);
    if (size == null || size <= 0 || size > _maxGeneratedSize) {
      await _sendJson(request.response, HttpStatus.badRequest, {
        'error': 'invalid_size',
        'message': 'Use a positive size up to $_maxGeneratedSize bytes.',
      });
      return;
    }

    final query = request.uri.queryParameters;
    final seed = _queryInt(query, 'seed', 7).clamp(0, 0x7fffffff);
    final chunkBytes =
        _queryInt(query, 'chunkBytes', 64 * 1024).clamp(1024, 4 * 1024 * 1024);
    final delayMs = _queryInt(
      query,
      'delayMs',
      scenario == DownloadTestScenario.slow ? 25 : 0,
    ).clamp(0, 60000);
    final failAfterBytes = _queryInt(
      query,
      'failAfterBytes',
      min(size, 256 * 1024),
    ).clamp(1, size);
    final stallMs = _queryInt(query, 'stallMs', 6000).clamp(1, 300000);
    final resource = (query['resource'] ?? sizeToken).trim();
    final version = _resourceVersions[resource] ?? 1;
    final transferKey = '$scenario|$resource';
    final requestedRange = _parseRange(
      request.headers.value(HttpHeaders.rangeHeader),
      size,
    );
    final isProbe = requestedRange?.start == 0 && requestedRange?.end == 0;
    final hasRangeHeader =
        request.headers.value(HttpHeaders.rangeHeader) != null;

    _scenarioRequests.update(scenario, (value) => value + 1, ifAbsent: () => 1);
    if (hasRangeHeader) _rangeRequests++;

    if (scenario == DownloadTestScenario.status) {
      final code = _queryInt(query, 'code', 500).clamp(100, 599);
      request.response.statusCode = code;
      request.response.headers.contentLength = 0;
      await request.response.close();
      return;
    }

    if (hasRangeHeader && requestedRange == null) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes */$size',
      );
      await request.response.close();
      return;
    }

    var attempt = _transferAttempts[transferKey] ?? 0;
    if (!isProbe && request.method == 'GET') {
      attempt++;
      _transferAttempts[transferKey] = attempt;
    }

    if (scenario == DownloadTestScenario.flaky503 && !isProbe) {
      final failures = _queryInt(query, 'failures', 2).clamp(0, 100);
      if (attempt <= failures) {
        _injectedFailures++;
        request.response.statusCode = HttpStatus.serviceUnavailable;
        request.response.headers.set(HttpHeaders.retryAfterHeader, '1');
        await _sendText(request.response, 'injected HTTP 503');
        return;
      }
    }

    final supportsRange = scenario != DownloadTestScenario.noRange;
    final range = supportsRange && requestedRange != null
        ? requestedRange
        : _ByteRange(0, size - 1);
    final partial = supportsRange && requestedRange != null;
    final bodyLength = range.length;
    final etag = '"hdmx-$resource-$seed-$size-v$version"';

    request.response.statusCode =
        partial ? HttpStatus.partialContent : HttpStatus.ok;
    request.response.headers
        .set(HttpHeaders.acceptRangesHeader, supportsRange ? 'bytes' : 'none');
    request.response.headers
        .set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
    request.response.headers.set(HttpHeaders.contentEncodingHeader, 'identity');
    request.response.headers.set(HttpHeaders.etagHeader, etag);
    request.response.headers.set(
      HttpHeaders.lastModifiedHeader,
      HttpDate.format(DateTime.utc(2026, 1, 1).add(Duration(days: version))),
    );
    if (partial) {
      final advertisedStart =
          scenario == DownloadTestScenario.badContentRange && !isProbe
              ? min(range.end, range.start + 1)
              : range.start;
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $advertisedStart-${range.end}/$size',
      );
    }
    request.response.headers.contentLength = bodyLength;

    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    final shouldDisconnect = scenario == DownloadTestScenario.truncated ||
        (scenario == DownloadTestScenario.disconnectOnce && attempt == 1);
    if (shouldDisconnect) {
      _injectedFailures++;
      final sent = await _sendPartialAndDisconnect(
        request.response,
        absoluteStart: range.start,
        totalBytes: bodyLength,
        failAfterBytes: failAfterBytes,
        chunkBytes: chunkBytes,
        seed: seed,
        version: version,
      );
      _bytesSent += sent;
      return;
    }

    final shouldStall =
        scenario == DownloadTestScenario.stallOnce && attempt == 1;
    final sent = await _streamGeneratedBody(
      request.response,
      absoluteStart: range.start,
      totalBytes: bodyLength,
      chunkBytes: chunkBytes,
      delayMs: delayMs,
      stallAfterBytes: shouldStall ? failAfterBytes : null,
      stallMs: stallMs,
      seed: seed,
      version: version,
    );
    _bytesSent += sent;
    if (sent == bodyLength) _completedTransfers++;
  }

  Future<int> _sendPartialAndDisconnect(
    HttpResponse response, {
    required int absoluteStart,
    required int totalBytes,
    required int failAfterBytes,
    required int chunkBytes,
    required int seed,
    required int version,
  }) async {
    Socket? socket;
    var sent = 0;
    try {
      socket = await response.detachSocket(writeHeaders: true);
      final limit = min(totalBytes, failAfterBytes);
      while (sent < limit) {
        final length = min(chunkBytes, limit - sent);
        socket.add(
          DownloadTestPattern.bytes(
            absoluteStart + sent,
            length,
            seed: seed,
            version: version,
          ),
        );
        sent += length;
      }
      await socket.flush();
    } catch (_) {
      // The disconnect itself is the test behavior.
    } finally {
      socket?.destroy();
    }
    return sent;
  }

  Future<int> _streamGeneratedBody(
    HttpResponse response, {
    required int absoluteStart,
    required int totalBytes,
    required int chunkBytes,
    required int delayMs,
    required int? stallAfterBytes,
    required int stallMs,
    required int seed,
    required int version,
  }) async {
    var sent = 0;
    var stalled = false;
    try {
      while (sent < totalBytes) {
        final length = min(chunkBytes, totalBytes - sent);
        response.add(
          DownloadTestPattern.bytes(
            absoluteStart + sent,
            length,
            seed: seed,
            version: version,
          ),
        );
        sent += length;
        // A force-closed downloader connection can leave HttpResponse.flush
        // pending on some Windows loopback stacks instead of completing with
        // an immediate socket error. Bound the flush so pause/cancel tests can
        // distinguish an aborted transfer from a client that keeps draining.
        await response.flush().timeout(const Duration(seconds: 1));

        if (!stalled &&
            stallAfterBytes != null &&
            sent >= stallAfterBytes &&
            sent < totalBytes) {
          stalled = true;
          _injectedFailures++;
          await Future<void>.delayed(Duration(milliseconds: stallMs));
        }
        if (delayMs > 0 && sent < totalBytes) {
          await Future<void>.delayed(Duration(milliseconds: delayMs));
        }
      }
      await response.close();
    } catch (_) {
      try {
        await response.close().timeout(const Duration(milliseconds: 500));
      } catch (_) {}
    }
    return sent;
  }

  Map<String, dynamic> _statsJson() => {
        'uptimeMs': _uptime.inMilliseconds,
        'totalRequests': _totalRequests,
        'activeRequests': _activeRequests,
        'maxActiveRequests': _maxActiveRequests,
        'rangeRequests': _rangeRequests,
        'completedTransfers': _completedTransfers,
        'injectedFailures': _injectedFailures,
        'bytesSent': _bytesSent,
        'scenarioRequests': Map<String, int>.from(_scenarioRequests),
        'transferAttempts': Map<String, int>.from(_transferAttempts),
        'resourceVersions': Map<String, int>.from(_resourceVersions),
        'recentRequests': List<Map<String, dynamic>>.from(_recentRequests),
      };

  void _resetStats({required bool resetAttempts}) {
    _totalRequests = 0;
    _activeRequests = 0;
    _maxActiveRequests = 0;
    _rangeRequests = 0;
    _completedTransfers = 0;
    _injectedFailures = 0;
    _bytesSent = 0;
    _scenarioRequests.clear();
    _recentRequests.clear();
    if (resetAttempts) {
      _transferAttempts.clear();
      _resourceVersions.clear();
    }
  }

  void _rememberRequest(HttpRequest request) {
    _recentRequests.add({
      'at': DateTime.now().toUtc().toIso8601String(),
      'method': request.method,
      'path': request.uri.path,
      'query': request.uri.query,
      'range': request.headers.value(HttpHeaders.rangeHeader),
      'userAgent': request.headers.value(HttpHeaders.userAgentHeader),
      'remoteAddress': request.connectionInfo?.remoteAddress.address,
    });
    if (_recentRequests.length > 50) _recentRequests.removeAt(0);
  }

  void _applyCommonHeaders(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Range, If-Range, User-Agent',
    );
    response.headers.set(
      'Access-Control-Expose-Headers',
      'Accept-Ranges, Content-Length, Content-Range, ETag, Last-Modified',
    );
    response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, POST');
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Download-Test-Server', 'hdmx/1');
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final content = await utf8.decoder.bind(request).join();
    if (content.length > 1024 * 1024) {
      throw const FormatException('JSON request body is too large');
    }
    if (content.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(content);
    if (decoded is! Map) throw const FormatException('Expected JSON object');
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _sendJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> payload,
  ) async {
    final bytes = utf8.encode(jsonEncode(payload));
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.headers.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
  }

  Future<void> _sendText(HttpResponse response, String text) async {
    final bytes = utf8.encode(text);
    response.headers.contentType = ContentType.text;
    response.headers.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
  }

  Duration get _uptime {
    final startedAt = _startedAt;
    return startedAt == null
        ? Duration.zero
        : DateTime.now().toUtc().difference(startedAt);
  }
}

class _ByteRange {
  const _ByteRange(this.start, this.end);

  final int start;
  final int end;
  int get length => end - start + 1;
}

const int _maxGeneratedSize = 16 * 1024 * 1024 * 1024;

_ByteRange? _parseRange(String? header, int totalSize) {
  if (header == null || header.trim().isEmpty) return null;
  final match = RegExp(r'^bytes=(\d*)-(\d*)$', caseSensitive: false)
      .firstMatch(header.trim());
  if (match == null) return null;

  final startText = match.group(1) ?? '';
  final endText = match.group(2) ?? '';
  int start;
  int end;
  if (startText.isEmpty) {
    final suffix = int.tryParse(endText);
    if (suffix == null || suffix <= 0) return null;
    start = max(0, totalSize - suffix);
    end = totalSize - 1;
  } else {
    start = int.tryParse(startText) ?? -1;
    end = endText.isEmpty ? totalSize - 1 : int.tryParse(endText) ?? -1;
  }
  if (start < 0 || start >= totalSize || end < start) return null;
  return _ByteRange(start, min(end, totalSize - 1));
}

int? _parseSize(String token) {
  final normalized = token.toLowerCase().replaceFirst(RegExp(r'\.bin$'), '');
  final match = RegExp(r'^(\d+)([kmgt]?)$').firstMatch(normalized);
  if (match == null) return null;
  final value = int.tryParse(match.group(1) ?? '');
  if (value == null) return null;
  final multiplier = switch (match.group(2)) {
    'k' => 1024,
    'm' => 1024 * 1024,
    'g' => 1024 * 1024 * 1024,
    't' => 1024 * 1024 * 1024 * 1024,
    _ => 1,
  };
  return value * multiplier;
}

int _queryInt(Map<String, String> query, String key, int fallback) {
  return int.tryParse(query[key] ?? '') ?? fallback;
}

int _intValue(Object? value, {required int fallback}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _isLoopbackHost(String host) {
  final normalized = host.trim().toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1' ||
      normalized == '[::1]';
}

String _uriHost(String host) {
  final normalized = host.trim();
  if (normalized.contains(':') && !normalized.startsWith('[')) {
    return '[$normalized]';
  }
  return normalized;
}

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('''
HDMX local download test server

Usage:
  dart run tool/download_test_server.dart [options]

Options:
  --host <address>   Bind address (default: 127.0.0.1)
  --port <number>    Port, 0 selects a free port (default: 18080)
  --allow-remote     Explicitly allow a non-loopback bind address
  --quiet            Suppress per-request diagnostics
  --help             Show this help
''');
    return;
  }

  var host = '127.0.0.1';
  var port = 18080;
  var allowRemote = false;
  var quiet = false;
  for (var index = 0; index < args.length; index++) {
    switch (args[index]) {
      case '--host':
        if (++index >= args.length) throw ArgumentError('Missing --host value');
        host = args[index];
      case '--port':
        if (++index >= args.length) throw ArgumentError('Missing --port value');
        port = int.parse(args[index]);
      case '--allow-remote':
        allowRemote = true;
      case '--quiet':
        quiet = true;
      default:
        throw ArgumentError('Unknown argument: ${args[index]}');
    }
  }

  final server = LocalDownloadTestServer(
    host: host,
    port: port,
    allowRemote: allowRemote,
    quiet: quiet,
  );
  final baseUri = await server.start();
  stdout.writeln('HDMX download test server is running at $baseUri');
  stdout.writeln('Health:      ${baseUri.resolve('health')}');
  stdout.writeln('Scenarios:   ${baseUri.resolve('api/v1/scenarios')}');
  stdout.writeln('Statistics:  ${baseUri.resolve('api/v1/stats')}');
  stdout.writeln('Example:     ${baseUri.resolve('download/normal/64m.bin')}');
  stdout.writeln('Press Ctrl+C to stop.');

  final stopped = Completer<void>();
  Future<void> stop(ProcessSignal signal) async {
    if (stopped.isCompleted) return;
    stdout.writeln('\nStopping after ${signal.name}...');
    await server.close();
    stopped.complete();
  }

  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  subscriptions.add(ProcessSignal.sigint.watch().listen(stop));
  if (!Platform.isWindows) {
    subscriptions.add(ProcessSignal.sigterm.watch().listen(stop));
  }
  await stopped.future;
  for (final subscription in subscriptions) {
    await subscription.cancel();
  }
}
