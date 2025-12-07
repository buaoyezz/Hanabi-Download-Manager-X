enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  merging,  // 正在校验和合并分段
}

class SegmentInfo {
  final int index;
  final int startByte;
  final int endByte;
  final int downloadedBytes;
  final double speed;
  final String status;  // pending, downloading, completed, failed, paused
  final int retryCount;  // 重试次数

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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
