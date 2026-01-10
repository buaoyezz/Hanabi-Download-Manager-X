import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import '../models/task.dart';
import '../models/segment.dart';
import '../config/download_config.dart';
import 'http_client.dart';
import '../../../app_logger_service.dart';

class DownloadEngine {
  final NsfxConfig config;
  final NsfxHttpClient httpClient;
  final void Function(Task) onProgress;
  final void Function(Task) onComplete;
  final void Function(Task) onError;
  final _logger = AppLoggerService();

  final Map<String, bool> _cancelledTasks = {};
  final Map<String, bool> _pausedTasks = {};

  DownloadEngine({
    required this.config,
    required this.httpClient,
    required this.onProgress,
    required this.onComplete,
    required this.onError,
  });

  Future<void> startDownload(Task task) async {
    _cancelledTasks[task.id] = false;
    _pausedTasks[task.id] = false;

    try {
      _logger.info('NSFX-Engine', 'Starting download: ${task.filename}');
      task.status = TaskStatus.downloading;
      task.startTime = DateTime.now();

      final headers = _buildHeaders(task);
      final fileInfo = await httpClient.getFileInfo(task.url, headers);
      _logger.info('NSFX-Engine', 'File info for ${task.filename}: size=${fileInfo.size}, supportsRange=${fileInfo.supportsRange}');

      if (fileInfo.size == 0) {
        _logger.info('NSFX-Engine', 'Unknown file size, falling back to single thread download');
        await _singleThreadDownload(task, headers);
        return;
      }

      task.totalSize = fileInfo.size;

      if (!fileInfo.supportsRange) {
        _logger.info('NSFX-Engine', 'Server does not support Range requests, using single thread');
        await _singleThreadDownload(task, headers);
        return;
      }
      
      if (fileInfo.size < 1024 * 1024) {
        _logger.info('NSFX-Engine', 'File too small (${fileInfo.size} bytes < 1MB), using single thread');
        await _singleThreadDownload(task, headers);
        return;
      }

      _logger.info('NSFX-Engine', 'Using Isolate-based multi-thread download for ${task.filename}');
      await _isolateMultiThreadDownload(task, headers, fileInfo.size);

    } catch (e) {
      _logger.error('NSFX-Engine', 'Download failed: ${task.filename} - $e');
      task.status = TaskStatus.failed;
      task.errorMessage = e.toString();
      onError(task);
    } finally {
      _cancelledTasks.remove(task.id);
      _pausedTasks.remove(task.id);
    }
  }

  /// 使用 Isolate 的多线程下载
  Future<void> _isolateMultiThreadDownload(Task task, Map<String, String> headers, int fileSize) async {
    final (threads, segmentCount) = DynamicSegmentConfig.calculate(fileSize, config);
    final actualThreads = threads.clamp(1, 8);
    task.threadCount = actualThreads;
    _logger.info('NSFX-Engine', 'Using $actualThreads concurrent isolates, $segmentCount segments');

    // 创建分段
    if (task.segments.isEmpty) {
      final segmentSize = fileSize ~/ segmentCount;
      for (int i = 0; i < segmentCount; i++) {
        final start = i * segmentSize;
        final end = (i == segmentCount - 1) ? fileSize : (i + 1) * segmentSize;
        task.segments.add(Segment(index: i, startByte: start, endByte: end));
      }
    }

    final tempDir = await _getTempDir(task);
    await tempDir.create(recursive: true);

    // 进度更新定时器
    final progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (task.status == TaskStatus.downloading) {
        _updateTaskProgress(task, tempDir);
        onProgress(task);
      }
    });

    try {
      // 使用信号量控制并发
      final semaphore = _Semaphore(actualThreads);
      final futures = <Future<bool>>[];

      for (final segment in task.segments) {
        if (segment.status == SegmentStatus.completed) continue;
        
        final tempFile = '${tempDir.path}/${task.filename}.part${segment.index}';
        
        futures.add(semaphore.run(() async {
          if (_cancelledTasks[task.id] == true) return false;
          if (_pausedTasks[task.id] == true) return false;
          
          segment.status = SegmentStatus.downloading;
          
          return await _downloadSegmentInIsolate(
            task: task,
            segment: segment,
            headers: headers,
            tempFilePath: tempFile,
          );
        }));
      }

      final results = await Future.wait(futures);
      progressTimer.cancel();

      if (_cancelledTasks[task.id] == true) {
        task.status = TaskStatus.cancelled;
        return;
      }

      if (_pausedTasks[task.id] == true) {
        task.status = TaskStatus.paused;
        return;
      }

      // 检查所有分段是否完成
      final allCompleted = task.segments.every((s) => s.status == SegmentStatus.completed);
      if (!allCompleted) {
        final failedCount = task.segments.where((s) => s.status == SegmentStatus.failed).length;
        task.status = TaskStatus.failed;
        task.errorMessage = '$failedCount segments failed';
        onError(task);
        return;
      }

      // 合并分段
      task.status = TaskStatus.merging;
      onProgress(task);
      _logger.info('NSFX-Engine', 'Merging segments: ${task.filename}');

      await _mergeSegments(task, tempDir);

      task.status = TaskStatus.completed;
      task.endTime = DateTime.now();
      task.progress = 100;
      
      if (task.startTime != null && task.endTime != null) {
        final duration = task.endTime!.difference(task.startTime!).inSeconds;
        if (duration > 0) task.averageSpeed = task.totalSize / duration;
      }

      _logger.info('NSFX-Engine', 'Download completed: ${task.filename}');
      onComplete(task);

    } finally {
      progressTimer.cancel();
    }
  }

  /// 在 Isolate 中下载单个分段
  Future<bool> _downloadSegmentInIsolate({
    required Task task,
    required Segment segment,
    required Map<String, String> headers,
    required String tempFilePath,
  }) async {
    int retryCount = 0;
    
    while (retryCount < config.maxRetries) {
      if (_cancelledTasks[task.id] == true || _pausedTasks[task.id] == true) {
        return false;
      }
      
      try {
        final receivePort = ReceivePort();
        
        await Isolate.spawn(
          _isolateSegmentDownload,
          _IsolateParams(
            sendPort: receivePort.sendPort,
            url: task.url,
            tempFilePath: tempFilePath,
            startByte: segment.startByte,
            endByte: segment.endByte,
            headers: headers,
            connectionTimeout: config.connectionTimeout,
          ),
        );
        
        final result = await receivePort.first as _IsolateResult;
        receivePort.close();
        
        if (result.success) {
          segment.downloadedBytes = result.downloadedBytes;
          segment.status = SegmentStatus.completed;
          return true;
        } else {
          throw Exception(result.error ?? 'Unknown error');
        }
        
      } catch (e) {
        retryCount++;
        segment.retryCount = retryCount;
        segment.lastError = e.toString();
        
        if (retryCount < config.maxRetries) {
          await Future.delayed(Duration(seconds: (1 << retryCount).clamp(1, 30)));
        }
      }
    }
    
    segment.status = SegmentStatus.failed;
    return false;
  }

  /// Isolate 入口点 - 下载单个分段
  static void _isolateSegmentDownload(_IsolateParams params) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(seconds: params.connectionTimeout);
      client.idleTimeout = const Duration(seconds: 60);
      
      final uri = Uri.parse(params.url);
      final request = await client.getUrl(uri);
      
      params.headers.forEach((key, value) {
        request.headers.set(key, value);
      });
      
      request.headers.set('Range', 'bytes=${params.startByte}-${params.endByte - 1}');
      
      final response = await request.close();
      
      if (response.statusCode != 206 && response.statusCode != 200) {
        await response.drain();
        client.close();
        params.sendPort.send(_IsolateResult(
          success: false,
          error: 'HTTP ${response.statusCode}',
          downloadedBytes: 0,
        ));
        return;
      }
      
      final file = File(params.tempFilePath);
      final sink = file.openWrite(mode: FileMode.writeOnly);
      int downloadedBytes = 0;
      final expectedSize = params.endByte - params.startByte;
      
      await for (final chunk in response) {
        final remaining = expectedSize - downloadedBytes;
        if (remaining <= 0) break;
        
        final toWrite = chunk.length > remaining 
            ? chunk.sublist(0, remaining) 
            : chunk;
        
        sink.add(toWrite);
        downloadedBytes += toWrite.length;
      }
      
      await sink.flush();
      await sink.close();
      client.close();
      
      params.sendPort.send(_IsolateResult(
        success: downloadedBytes >= expectedSize,
        downloadedBytes: downloadedBytes,
        error: downloadedBytes < expectedSize 
            ? 'Incomplete: $downloadedBytes/$expectedSize' 
            : null,
      ));
      
    } catch (e) {
      params.sendPort.send(_IsolateResult(
        success: false,
        error: e.toString(),
        downloadedBytes: 0,
      ));
    }
  }

  /// 更新任务进度（从临时文件读取）
  Future<void> _updateTaskProgress(Task task, Directory tempDir) async {
    int totalDownloaded = 0;
    
    for (final segment in task.segments) {
      if (segment.status == SegmentStatus.completed) {
        totalDownloaded += segment.size;
      } else {
        final partFile = File('${tempDir.path}/${task.filename}.part${segment.index}');
        if (await partFile.exists()) {
          final size = await partFile.length();
          segment.downloadedBytes = size;
          totalDownloaded += size;
        }
      }
    }
    
    task.downloadedSize = totalDownloaded;
    if (task.totalSize > 0) {
      task.progress = (totalDownloaded / task.totalSize) * 100;
      
      // 计算速度
      if (task.startTime != null) {
        final elapsed = DateTime.now().difference(task.startTime!).inSeconds;
        if (elapsed > 0) {
          task.speed = totalDownloaded / elapsed;
          if (task.speed > task.peakSpeed) task.peakSpeed = task.speed;
          
          final remaining = task.totalSize - totalDownloaded;
          if (task.speed > 0) {
            task.eta = (remaining / task.speed).round();
          }
        }
      }
    }
  }

  Future<void> _singleThreadDownload(Task task, Map<String, String> headers) async {
    task.threadCount = 1;
    task.status = TaskStatus.downloading;

    final file = File(task.filepath);
    await file.parent.create(recursive: true);

    final response = await httpClient.get(task.url, headers);
    
    if (response.statusCode != 200) {
      await response.drain();
      throw HttpException('HTTP ${response.statusCode}');
    }

    if (response.contentLength > 0) task.totalSize = response.contentLength;

    final sink = file.openWrite();
    int bytesThisInterval = 0;
    DateTime lastUpdate = DateTime.now();

    try {
      await for (final chunk in response) {
        if (_cancelledTasks[task.id] == true) {
          await sink.close();
          await file.delete();
          task.status = TaskStatus.cancelled;
          return;
        }

        if (_pausedTasks[task.id] == true) {
          await sink.close();
          task.status = TaskStatus.paused;
          return;
        }

        sink.add(chunk);
        task.downloadedSize += chunk.length;
        bytesThisInterval += chunk.length;

        if (task.totalSize > 0) {
          task.progress = (task.downloadedSize / task.totalSize) * 100;
        }

        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds >= 1000) {
          final elapsed = now.difference(lastUpdate).inMilliseconds / 1000;
          task.speed = bytesThisInterval / elapsed;
          if (task.speed > task.peakSpeed) task.peakSpeed = task.speed;
          bytesThisInterval = 0;
          lastUpdate = now;

          if (task.totalSize > 0 && task.speed > 0) {
            task.eta = ((task.totalSize - task.downloadedSize) / task.speed).round();
          }
          onProgress(task);
        }
      }

      await sink.flush();
      await sink.close();

      task.status = TaskStatus.completed;
      task.endTime = DateTime.now();
      task.progress = 100;

      if (task.startTime != null && task.endTime != null) {
        final duration = task.endTime!.difference(task.startTime!).inSeconds;
        if (duration > 0) task.averageSpeed = task.totalSize / duration;
      }

      onComplete(task);

    } catch (e) {
      await sink.close();
      rethrow;
    }
  }

  Future<void> _mergeSegments(Task task, Directory tempDir) async {
    final outputFile = File(task.filepath);
    await outputFile.parent.create(recursive: true);
    
    final sink = outputFile.openWrite();

    try {
      for (final segment in task.segments..sort((a, b) => a.index.compareTo(b.index))) {
        final partFile = File('${tempDir.path}/${task.filename}.part${segment.index}');
        if (await partFile.exists()) {
          await sink.addStream(partFile.openRead());
          await partFile.delete();
        }
      }

      await sink.flush();
      await sink.close();

      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

    } catch (e) {
      await sink.close();
      rethrow;
    }
  }

  Future<Directory> _getTempDir(Task task) async {
    final parent = File(task.filepath).parent;
    final tempRoot = Directory('${parent.path}/.nsfx_temp');
    return Directory('${tempRoot.path}/${task.id}');
  }

  void pauseDownload(String taskId) {
    _pausedTasks[taskId] = true;
  }

  void cancelDownload(String taskId) {
    _cancelledTasks[taskId] = true;
  }

  Map<String, String> _buildHeaders(Task task) {
    final headers = <String, String>{
      'User-Agent': task.userAgent ?? 'NSFX/2.0 (Next Speed Force X)',
      'Accept': '*/*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Connection': 'keep-alive',
    };

    if (task.referer != null && task.referer!.isNotEmpty) {
      headers['Referer'] = task.referer!;
    } else {
      try {
        final uri = Uri.parse(task.url);
        headers['Referer'] = '${uri.scheme}://${uri.host}/';
      } catch (_) {}
    }

    if (task.cookies != null && task.cookies!.isNotEmpty) {
      headers['Cookie'] = task.cookies!;
    }

    if (task.headers != null) headers.addAll(task.headers!);

    return headers;
  }
}

/// Isolate 参数
class _IsolateParams {
  final SendPort sendPort;
  final String url;
  final String tempFilePath;
  final int startByte;
  final int endByte;
  final Map<String, String> headers;
  final int connectionTimeout;

  _IsolateParams({
    required this.sendPort,
    required this.url,
    required this.tempFilePath,
    required this.startByte,
    required this.endByte,
    required this.headers,
    required this.connectionTimeout,
  });
}

/// Isolate 结果
class _IsolateResult {
  final bool success;
  final int downloadedBytes;
  final String? error;

  _IsolateResult({
    required this.success,
    required this.downloadedBytes,
    this.error,
  });
}

class _Semaphore {
  final int maxConcurrent;
  int _current = 0;
  final _queue = <Completer<void>>[];

  _Semaphore(this.maxConcurrent);

  Future<T> run<T>(Future<T> Function() task) async {
    await _acquire();
    try {
      return await task();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_current < maxConcurrent) {
      _current++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
  }

  void _release() {
    if (_queue.isNotEmpty) {
      final completer = _queue.removeAt(0);
      completer.complete();
    } else {
      _current--;
    }
  }
}
