import 'segment.dart';

class Task {
  final String id;
  final String url;
  final String filename;
  final String filepath;
  TaskStatus status;
  int totalSize;
  int downloadedSize;
  double speed;
  double progress;
  int eta;
  String? errorMessage;
  int threadCount;
  double peakSpeed;
  double averageSpeed;
  DateTime? startTime;
  DateTime? endTime;
  DateTime createdTime;
  List<Segment> segments;

  String? userAgent;
  String? referer;
  String? cookies;
  Map<String, String>? headers;

  Task({
    required this.id,
    required this.url,
    required this.filename,
    required this.filepath,
    this.status = TaskStatus.pending,
    this.totalSize = 0,
    this.downloadedSize = 0,
    this.speed = 0,
    this.progress = 0,
    this.eta = 0,
    this.errorMessage,
    this.threadCount = 1,
    this.peakSpeed = 0,
    this.averageSpeed = 0,
    this.startTime,
    this.endTime,
    DateTime? createdTime,
    List<Segment>? segments,
    this.userAgent,
    this.referer,
    this.cookies,
    this.headers,
  }) : createdTime = createdTime ?? DateTime.now(),
       segments = segments ?? [];

  void updateProgress() {
    if (segments.isEmpty) return;
    
    downloadedSize = segments.fold(0, (sum, s) => sum + s.downloadedBytes);
    speed = segments
        .where((s) => s.status == SegmentStatus.downloading)
        .fold(0.0, (sum, s) => sum + s.speed);
    
    if (totalSize > 0) {
      progress = (downloadedSize / totalSize) * 100;
      if (speed > 0) {
        eta = ((totalSize - downloadedSize) / speed).round();
      }
    }

    if (speed > peakSpeed) peakSpeed = speed;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'filename': filename,
    'filepath': filepath,
    'status': status.name,
    'totalSize': totalSize,
    'downloadedSize': downloadedSize,
    'speed': speed,
    'progress': progress,
    'eta': eta,
    'errorMessage': errorMessage,
    'threadCount': threadCount,
    'peakSpeed': peakSpeed,
    'averageSpeed': averageSpeed,
    'startTime': startTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'createdTime': createdTime.toIso8601String(),
    'segments': segments.map((s) => s.toJson()).toList(),
  };
}

enum TaskStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
  merging,
}
