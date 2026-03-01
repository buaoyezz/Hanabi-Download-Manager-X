enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  merging, // 正在校验和合并分段
}

class SegmentInfo {
  final int index;
  final int startByte;
  final int endByte;
  final int downloadedBytes;
  final double speed;
  final String status; // pending, downloading, completed, failed, paused
  final int retryCount; // 重试次数

  SegmentInfo({
    required this.index,
    required this.startByte,
    required this.endByte,
    required this.downloadedBytes,
    required this.speed,
    this.status = 'pending',
    this.retryCount = 0,
  });

  double get progress {
    final total = endByte - startByte;
    if (total <= 0) return 0.0;
    return downloadedBytes / total;
  }

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isDownloading => status == 'downloading';
  bool get isPending => status == 'pending';
  bool get isPaused => status == 'paused';

  /// 是否可以重试（失败或暂停状态）
  bool get canRetry => isFailed || isPaused;

  /// 获取状态显示文本
  String get statusText {
    switch (status) {
      case 'pending':
        return '等待';
      case 'downloading':
        return '下载中';
      case 'completed':
        return '完成';
      case 'failed':
        return '失败';
      case 'paused':
        return '暂停';
      default:
        return '未知';
    }
  }
}

class DownloadTask {
  final String id;
  final String url;
  final String fileName;
  DownloadStatus status;
  double progress;
  int? fileSize;
  int? downloadedSize;
  double? speed; // 字节/秒
  Duration? remainingTime;
  DateTime? startTime;
  DateTime? endTime;
  String? filePath;
  String? error;
  DateTime createdAt;
  List<SegmentInfo>? segments; // 分段信息

  // 统计信息
  double? peakSpeed; // 峰值速度（字节/秒）
  double? averageSpeed; // 平均速度（字节/秒）
  int? threadCount; // 线程数
  int? segmentCount; // 分段数
  String? downloadCore; // 下载核心标识
  String? effectiveHttpVersionPolicy;
  String? negotiatedHttpVersion;
  bool? targetReachable;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.status,
    required this.progress,
    this.fileSize,
    this.downloadedSize,
    this.speed,
    this.remainingTime,
    this.startTime,
    this.endTime,
    this.filePath,
    this.error,
    DateTime? createdAt,
    this.segments,
    this.peakSpeed,
    this.averageSpeed,
    this.threadCount,
    this.segmentCount,
    this.downloadCore,
    this.effectiveHttpVersionPolicy,
    this.negotiatedHttpVersion,
    this.targetReachable,
  }) : createdAt = createdAt ?? DateTime.now();

  String get formattedFileSize {
    if (fileSize == null) return '未知';
    return _formatBytes(fileSize!);
  }

  String get formattedDownloadedSize {
    if (downloadedSize == null) return '0 B';
    return _formatBytes(downloadedSize!);
  }

  String get formattedSpeed {
    if (speed == null || speed == 0) return '0 B/s';
    if (speed!.isInfinite || speed!.isNaN) return '0 B/s';
    return '${_formatBytes(speed!.toInt())}/s';
  }

  String get formattedPeakSpeed {
    if (peakSpeed == null || peakSpeed == 0) return '0 B/s';
    if (peakSpeed!.isInfinite || peakSpeed!.isNaN) return '0 B/s';
    return '${_formatBytes(peakSpeed!.toInt())}/s';
  }

  String get formattedAverageSpeed {
    if (averageSpeed == null || averageSpeed == 0) return '0 B/s';
    if (averageSpeed!.isInfinite || averageSpeed!.isNaN) return '0 B/s';
    return '${_formatBytes(averageSpeed!.toInt())}/s';
  }

  Duration? get totalDuration {
    if (startTime == null || endTime == null) return null;
    return endTime!.difference(startTime!);
  }

  String get formattedDuration {
    final duration = totalDuration;
    if (duration == null) return '--:--';

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedRemainingTime {
    if (remainingTime == null) return '--:--';
    final hours = remainingTime!.inHours;
    final minutes = remainingTime!.inMinutes % 60;
    final seconds = remainingTime!.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 获取失败的分段列表
  List<SegmentInfo> get failedSegments {
    if (segments == null) return [];
    return segments!.where((s) => s.isFailed).toList();
  }

  /// 是否有失败的分段
  bool get hasFailedSegments => failedSegments.isNotEmpty;

  /// 获取可重试的分段列表
  List<SegmentInfo> get retryableSegments {
    if (segments == null) return [];
    return segments!.where((s) => s.canRetry).toList();
  }

  /// 是否有可重试的分段
  bool get hasRetryableSegments => retryableSegments.isNotEmpty;
}
