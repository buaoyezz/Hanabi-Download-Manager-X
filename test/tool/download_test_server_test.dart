import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/download_test_server.dart';

void main() {
  late LocalDownloadTestServer server;
  late HttpClient client;

  setUp(() async {
    server = LocalDownloadTestServer(port: 0);
    await server.start();
    client = HttpClient()..autoUncompress = false;
  });

  tearDown(() async {
    client.close(force: true);
    await server.close();
  });

  test('health, capabilities and scenarios APIs are available', () async {
    final health = await _getJson(client, server.baseUri.resolve('health'));
    final capabilities = await _getJson(
      client,
      server.baseUri.resolve('api/v1/capabilities'),
    );
    final scenarios = await _getJson(
      client,
      server.baseUri.resolve('api/v1/scenarios'),
    );

    expect(health['ok'], isTrue);
    expect(capabilities['apiVersion'], 1);
    expect(
      (scenarios['scenarios'] as List)
          .whereType<Map>()
          .map((entry) => entry['id']),
      contains(DownloadTestScenario.disconnectOnce),
    );
  });

  test('normal endpoint serves exact deterministic byte ranges', () async {
    final request = await client.getUrl(
      server.baseUri.resolve('download/normal/1m.bin?seed=19'),
    );
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=1024-8191');
    final response = await request.close();
    final bytes = await _readBytes(response);

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 1024-8191/1048576');
    expect(
        response.headers.value(HttpHeaders.contentEncodingHeader), 'identity');
    expect(
      bytes,
      DownloadTestPattern.bytes(1024, 8192 - 1024, seed: 19),
    );
  });

  test('HEAD is metadata-only and no-range deliberately ignores Range',
      () async {
    final head = await client.openUrl(
      'HEAD',
      server.baseUri.resolve('download/normal/2m.bin'),
    );
    final headResponse = await head.close();
    expect(headResponse.statusCode, HttpStatus.ok);
    expect(headResponse.contentLength, 2 * 1024 * 1024);
    expect(await _readBytes(headResponse), isEmpty);

    final request = await client.getUrl(
      server.baseUri.resolve('download/no-range/16k.bin'),
    );
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=100-199');
    final response = await request.close();
    final bytes = await _readBytes(response);
    expect(response.statusCode, HttpStatus.ok);
    expect(bytes.length, 16 * 1024);
  });

  test('bad Content-Range and statistics are observable through API', () async {
    final request = await client.getUrl(
      server.baseUri.resolve('download/bad-content-range/1m.bin'),
    );
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=1024-2047');
    final response = await request.close();
    await response.drain<void>();

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 1025-2047/1048576');

    final stats = await _getJson(
      client,
      server.baseUri.resolve('api/v1/stats'),
    );
    expect(stats['rangeRequests'], greaterThanOrEqualTo(1));
    expect((stats['scenarioRequests'] as Map)['bad-content-range'], 1);
  });

  test('resource version API changes ETag and deterministic content', () async {
    final first = await _getResponse(
      client,
      server.baseUri.resolve('download/changing/8k.bin?resource=release'),
    );
    final firstEtag = first.response.headers.value(HttpHeaders.etagHeader);
    final firstBytes = first.bytes;

    final controlRequest = await client.postUrl(
      server.baseUri.resolve('api/v1/resources/version'),
    );
    controlRequest.headers.contentType = ContentType.json;
    controlRequest.write(jsonEncode({'resource': 'release', 'version': 2}));
    final controlResponse = await controlRequest.close();
    expect(controlResponse.statusCode, HttpStatus.ok);
    await controlResponse.drain<void>();

    final second = await _getResponse(
      client,
      server.baseUri.resolve('download/changing/8k.bin?resource=release'),
    );
    expect(second.response.headers.value(HttpHeaders.etagHeader),
        isNot(firstEtag));
    expect(second.bytes, isNot(firstBytes));
    expect(second.bytes, DownloadTestPattern.bytes(0, 8 * 1024, version: 2));
  });

  test('disconnect-once truncates first transfer and completes the second',
      () async {
    final uri = server.baseUri.resolve(
      'download/disconnect-once/512k.bin?resource=drop-test&failAfterBytes=65536',
    );
    final firstRequest = await client.getUrl(uri);
    final firstResponse = await firstRequest.close();
    Object? firstError;
    try {
      await _readBytes(firstResponse);
    } catch (error) {
      firstError = error;
    }
    expect(firstError, isNotNull);

    final second = await _getResponse(client, uri);
    expect(second.response.statusCode, HttpStatus.ok);
    expect(second.bytes.length, 512 * 1024);
    expect(second.bytes, DownloadTestPattern.bytes(0, 512 * 1024));
  });
}

Future<Map<String, dynamic>> _getJson(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  expect(response.statusCode, HttpStatus.ok);
  final text = await utf8.decoder.bind(response).join();
  return Map<String, dynamic>.from(jsonDecode(text) as Map);
}

Future<({HttpClientResponse response, List<int> bytes})> _getResponse(
  HttpClient client,
  Uri uri,
) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  final bytes = await _readBytes(response);
  return (response: response, bytes: bytes);
}

Future<List<int>> _readBytes(HttpClientResponse response) {
  return response.fold<List<int>>(<int>[], (buffer, chunk) {
    buffer.addAll(chunk);
    return buffer;
  });
}
