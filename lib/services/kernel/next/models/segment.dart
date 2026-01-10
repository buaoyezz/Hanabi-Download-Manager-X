class Segment {
  final int index;
  final int startByte;
  final int endByte;
  int downloadedBytes;
  double speed;
  SegmentStatus status;
  int retryCount;
  String? lastError;

  Segment({
    required this.index,
    required this.startByte,
    required this.endByte,
    this.downloadedBytes = 0,
    this.speed = 0,
    this.status = SegmentStatus.pending,
    this.retryCount = 0,
    this.lastError,
  });

  int get size => endByte - startByte;
  int get remaining => size - downloadedBytes;
  double get progress => size > 0 ? (downloadedBytes / size) * 100 : 0;
  bool get isCompleted => downloadedBytes >= size;

  Map<String, dynamic> toJson() => {
    'index': index,
    'startByte': startByte,
    'endByte': endByte,
    'downloadedBytes': downloadedBytes,
    'speed': speed,
    'status': status.name,
    'retryCount': retryCount,
    'progress': progress,
  };
}

enum SegmentStatus {
  pending,
  downloading,
  completed,
  failed,
  paused,
  cancelled,
}
