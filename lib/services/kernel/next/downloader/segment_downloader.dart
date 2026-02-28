import 'dart:async';
import 'dart:io';
import '../models/segment.dart';
import '../models/task.dart';
import '../config/download_config.dart';
import 'http_client.dart';

class SegmentDownloader {
  final Task task;
  final Segment segment;
  final NsfxHttpClient httpClient;
  final NsfxConfig config;
  final File tempFile;
  final void Function(Segment) onProgress;

  bool _cancelled = false;
  bool _paused = false;

  // 节流控制，避免 Windows 消息队列溢出
  DateTime _lastProgressCall = DateTime.fromMillisecondsSinceEpoch(0);
  static const _minCallInterval = Duration(milliseconds: 500);

  // 计数器，用于定期让出控制权
  int _chunkCounter = 0;
  static const _yieldInterval = 50; // 每处理 50 个 chunk 让出一次

  SegmentDownloader({
    required this.task,
    required this.segment,
    required this.httpClient,
    required this.config,
    required this.tempFile,
    required this.onProgress,
  });

  void cancel() => _cancelled = true;
  void pause() => _paused = true;
  void resume() => _paused = false;

  Future<bool> download() async {
    int retryCount = 0;

    while (retryCount < config.maxRetries) {
      if (_cancelled) {
        segment.status = SegmentStatus.cancelled;
        return false;
      }

      if (_paused) {
        segment.status = SegmentStatus.paused;
        return false;
      }

      // 检查已下载的字节数
      if (await tempFile.exists()) {
        segment.downloadedBytes = await tempFile.length();
        if (segment.downloadedBytes > segment.size) {
          await tempFile.delete();
          segment.downloadedBytes = 0;
        }
      } else {
        segment.downloadedBytes = 0;
      }

      if (segment.isCompleted) {
        segment.status = SegmentStatus.completed;
        return true;
      }

      segment.status = SegmentStatus.downloading;

      try {
        final headers = _buildHeaders();
        final start = segment.startByte + segment.downloadedBytes;
        final response = await httpClient.getRange(
          task.url,
          headers,
          start,
          segment.endByte,
        );

        if (response.statusCode != 206 && response.statusCode != 200) {
          await response.drain();
          throw HttpException('HTTP ${response.statusCode}');
        }

        if (response.statusCode == 200 && segment.downloadedBytes > 0) {
          await response.drain();
          throw HttpException('Server does not support range requests');
        }

        final sink = tempFile.openWrite(mode: FileMode.append);
        final stopwatch = Stopwatch()..start();
        int bytesThisInterval = 0;
        DateTime lastUpdate = DateTime.now();
        _chunkCounter = 0;

        try {
          await for (final chunk in response) {
            if (_cancelled) {
              segment.status = SegmentStatus.cancelled;
              await sink.close();
              return false;
            }

            if (_paused) {
              segment.status = SegmentStatus.paused;
              await sink.close();
              return false;
            }

            final remaining = segment.size - segment.downloadedBytes;
            if (remaining <= 0) break;

            final toWrite =
                chunk.length > remaining ? chunk.sublist(0, remaining) : chunk;

            sink.add(toWrite);
            segment.downloadedBytes += toWrite.length;
            bytesThisInterval += toWrite.length;

            // 定期让出控制权给主线程，防止 Windows 消息队列阻塞
            _chunkCounter++;
            if (_chunkCounter >= _yieldInterval) {
              _chunkCounter = 0;
              // 使用 Future.delayed(Duration.zero) 让出控制权
              await Future.delayed(Duration.zero);
            }

            // 限速
            if (config.segmentSpeedLimit > 0) {
              final expectedDuration = Duration(
                microseconds:
                    (toWrite.length / config.segmentSpeedLimit * 1000000)
                        .round(),
              );
              final actualDuration = stopwatch.elapsed;
              if (expectedDuration > actualDuration) {
                await Future.delayed(expectedDuration - actualDuration);
              }
              stopwatch.reset();
            }

            // 更新速度（每秒）- 使用节流避免过于频繁的回调
            final now = DateTime.now();
            if (now.difference(lastUpdate).inMilliseconds >= 1000) {
              final elapsed = now.difference(lastUpdate).inMilliseconds / 1000;
              segment.speed = bytesThisInterval / elapsed;
              bytesThisInterval = 0;
              lastUpdate = now;

              // 节流：避免多个 segment 同时触发大量回调
              if (now.difference(_lastProgressCall) >= _minCallInterval) {
                _lastProgressCall = now;
                onProgress(segment);
              }
            }
          }

          await sink.flush();
          await sink.close();

          // 验证
          final actualSize = await tempFile.length();
          if (actualSize == segment.size) {
            segment.status = SegmentStatus.completed;
            segment.speed = 0;
            onProgress(segment);
            return true;
          } else if (actualSize < segment.size) {
            throw Exception('Incomplete download: $actualSize/${segment.size}');
          }

          segment.status = SegmentStatus.completed;
          segment.speed = 0;
          onProgress(segment);
          return true;
        } catch (e) {
          await sink.close();
          rethrow;
        }
      } catch (e) {
        retryCount++;
        segment.retryCount = retryCount;
        segment.lastError = e.toString();

        if (retryCount < config.maxRetries) {
          // 优化：使用更短的重试间隔，循环使用
          final delays = [200, 500, 1000, 1500, 2000];
          final delayMs = delays[retryCount % delays.length];
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }

    segment.status = SegmentStatus.failed;
    onProgress(segment);
    return false;
  }

  Map<String, String> _buildHeaders() {
    final userAgent = task.userAgent?.trim();
    final headers = <String, String>{
      'User-Agent': userAgent != null && userAgent.isNotEmpty
          ? userAgent
          : config.defaultUserAgent,
      'Accept': '*/*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Connection': 'keep-alive',
    };

    if (task.referer != null && task.referer!.isNotEmpty) {
      headers['Referer'] = task.referer!;
    }

    if (task.cookies != null && task.cookies!.isNotEmpty) {
      headers['Cookie'] = task.cookies!;
    }

    if (task.headers != null) {
      headers.addAll(task.headers!);
    }

    return headers;
  }
}
