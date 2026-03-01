import 'dart:async';

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
  merging,
}

class DownloadTask {
  final String id;
  final String url;
  final String filename;
  final String filepath;
  DownloadStatus status;
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
  DateTime createdTime; // task creation time
  String? effectiveHttpVersionPolicy;
  String? negotiatedHttpVersion;
  bool? targetReachable;
  List<SegmentInfo> segments;

  DownloadTask({
    required this.id,
    required this.url,
    required this.filename,
    required this.filepath,
    this.status = DownloadStatus.pending,
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
    this.effectiveHttpVersionPolicy,
    this.negotiatedHttpVersion,
    this.targetReachable,
    DateTime? createdTime, // optional persisted creation time
    List<SegmentInfo>? segments,
  })  : createdTime = createdTime ?? DateTime.now(),
        segments = segments ?? [];

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
        'createdTime': createdTime.toIso8601String(), // serialize creation time
        'effectiveHttpVersionPolicy': effectiveHttpVersionPolicy,
        'negotiatedHttpVersion': negotiatedHttpVersion,
        'targetReachable': targetReachable,
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        filename: json['filename']?.toString() ?? '',
        filepath: json['filepath']?.toString() ?? '',
        status: _parseStatus(json['status']),
        totalSize: (json['totalSize'] as num?)?.toInt() ??
            (json['total_size'] as num?)?.toInt() ??
            0,
        downloadedSize: (json['downloadedSize'] as num?)?.toInt() ??
            (json['downloaded_size'] as num?)?.toInt() ??
            0,
        speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        eta: (json['eta'] as num?)?.toInt() ?? 0,
        errorMessage: json['errorMessage']?.toString() ??
            json['error_message']?.toString(),
        threadCount: (json['threadCount'] as num?)?.toInt() ??
            (json['thread_count'] as num?)?.toInt() ??
            1,
        peakSpeed: (json['peakSpeed'] as num?)?.toDouble() ??
            (json['peak_speed'] as num?)?.toDouble() ??
            0.0,
        averageSpeed: (json['averageSpeed'] as num?)?.toDouble() ??
            (json['average_speed'] as num?)?.toDouble() ??
            0.0,
        startTime: json['startTime'] != null
            ? DateTime.tryParse(json['startTime'].toString())
            : null,
        endTime: json['endTime'] != null
            ? DateTime.tryParse(json['endTime'].toString())
            : null,
        effectiveHttpVersionPolicy:
            json['effectiveHttpVersionPolicy']?.toString(),
        negotiatedHttpVersion: json['negotiatedHttpVersion']?.toString(),
        targetReachable: json['targetReachable'] as bool?,
        createdTime: json['createdTime'] != null
            ? DateTime.tryParse(json['createdTime'].toString())
            : null, // parse creation time
        segments: (json['segments'] as List?)
                ?.map((s) => SegmentInfo.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );

  static DownloadStatus _parseStatus(dynamic status) {
    if (status is String) {
      return DownloadStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == status.toLowerCase(),
        orElse: () => DownloadStatus.pending,
      );
    }
    return DownloadStatus.pending;
  }
}

class SegmentInfo {
  final int index;
  final int startByte;
  final int endByte;
  int downloadedBytes;
  double speed;
  String status;
  int retryCount;
  double progress;

  SegmentInfo({
    required this.index,
    required this.startByte,
    required this.endByte,
    this.downloadedBytes = 0,
    this.speed = 0,
    this.status = 'pending',
    this.retryCount = 0,
    this.progress = 0,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'startByte': startByte,
        'endByte': endByte,
        'downloadedBytes': downloadedBytes,
        'speed': speed,
        'status': status,
        'retryCount': retryCount,
        'progress': progress,
      };

  factory SegmentInfo.fromJson(Map<String, dynamic> json) => SegmentInfo(
        index: (json['index'] as num?)?.toInt() ?? 0,
        startByte: (json['startByte'] as num?)?.toInt() ??
            (json['start_byte'] as num?)?.toInt() ??
            0,
        endByte: (json['endByte'] as num?)?.toInt() ??
            (json['end_byte'] as num?)?.toInt() ??
            0,
        downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ??
            (json['downloaded_bytes'] as num?)?.toInt() ??
            0,
        speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
        status: json['status']?.toString() ?? 'pending',
        retryCount: (json['retryCount'] as num?)?.toInt() ??
            (json['retry_count'] as num?)?.toInt() ??
            0,
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      );
}

class DownloadConfig {
  static const String defaultUserAgentFallback =
      'NSFX/2.0 (Next Speed Force X)';

  static String normalizeHttpVersionPolicy(String? value) {
    if (value == 'http1_only' ||
        value == 'http2_only' ||
        value == 'http3_only' ||
        value == 'auto') {
      return value!;
    }
    return 'auto';
  }

  int threads;
  int? segments;
  String mode;
  int maxConcurrentTasks;
  int segmentSpeedLimit;
  int globalSpeedLimit; // global bandwidth limit (bytes/s), 0 = unlimited
  bool enableDynamicSegments;
  String conflictStrategy;
  String defaultUserAgent;
  String httpVersionPolicy;
  ProxyConfig? proxy;

  DownloadConfig({
    this.threads = 8,
    this.segments,
    this.mode = 'auto',
    this.maxConcurrentTasks = 3,
    this.segmentSpeedLimit = 0,
    this.globalSpeedLimit = 0,
    this.enableDynamicSegments = true,
    this.conflictStrategy = 'increment',
    this.defaultUserAgent = defaultUserAgentFallback,
    this.httpVersionPolicy = 'auto',
    this.proxy,
  });

  Map<String, dynamic> toJson() => {
        'threads': threads,
        'segments': segments,
        'mode': mode,
        'max_concurrent_tasks': maxConcurrentTasks,
        'segment_speed_limit': segmentSpeedLimit,
        'global_speed_limit': globalSpeedLimit,
        'enable_dynamic_segments': enableDynamicSegments,
        'conflict_strategy': conflictStrategy,
        'default_user_agent': defaultUserAgent,
        'http_version_policy': httpVersionPolicy,
        'proxy': proxy?.toJson(),
      };

  factory DownloadConfig.fromJson(Map<String, dynamic> json) => DownloadConfig(
        threads: json['threads'] ?? 8,
        segments: json['segments'],
        mode: json['mode'] ?? 'auto',
        maxConcurrentTasks:
            json['max_concurrent_tasks'] ?? json['maxConcurrentTasks'] ?? 3,
        segmentSpeedLimit:
            json['segment_speed_limit'] ?? json['segmentSpeedLimit'] ?? 0,
        globalSpeedLimit:
            json['global_speed_limit'] ?? json['globalSpeedLimit'] ?? 0,
        enableDynamicSegments: json['enable_dynamic_segments'] ??
            json['enableDynamicSegments'] ??
            true,
        conflictStrategy: json['conflict_strategy'] ??
            json['conflictStrategy'] ??
            'increment',
        defaultUserAgent: (() {
          final value = (json['default_user_agent'] ??
                  json['defaultUserAgent'] ??
                  defaultUserAgentFallback)
              .toString()
              .trim();
          return value.isEmpty ? defaultUserAgentFallback : value;
        })(),
        httpVersionPolicy: normalizeHttpVersionPolicy(
          (json['http_version_policy'] ?? json['httpVersionPolicy'])
              ?.toString(),
        ),
        proxy:
            json['proxy'] != null ? ProxyConfig.fromJson(json['proxy']) : null,
      );
}

class ProxyConfig {
  bool enabled;
  String type;
  String host;
  int port;
  String? username;
  String? password;
  bool requiresAuth;

  ProxyConfig({
    this.enabled = false,
    this.type = 'system',
    this.host = '',
    this.port = 7897,
    this.username,
    this.password,
    this.requiresAuth = false,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'type': type,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'requires_auth': requiresAuth,
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> json) => ProxyConfig(
        enabled: json['enabled'] ?? false,
        type: json['type'] ?? 'system',
        host: json['host'] ?? '',
        port: json['port'] ?? 7897,
        username: json['username'],
        password: json['password'],
        requiresAuth: json['requires_auth'] ?? json['requiresAuth'] ?? false,
      );
}

class DownloadStatistics {
  int totalTasks;
  int activeDownloads;
  double totalSpeed;
  int totalDownloaded;

  DownloadStatistics({
    this.totalTasks = 0,
    this.activeDownloads = 0,
    this.totalSpeed = 0,
    this.totalDownloaded = 0,
  });

  Map<String, dynamic> toJson() => {
        'totalTasks': totalTasks,
        'activeDownloads': activeDownloads,
        'totalSpeed': totalSpeed,
        'totalDownloaded': totalDownloaded,
      };

  factory DownloadStatistics.fromJson(Map<String, dynamic> json) =>
      DownloadStatistics(
        totalTasks: json['totalTasks'] ?? json['total_tasks'] ?? 0,
        activeDownloads:
            json['activeDownloads'] ?? json['active_downloads'] ?? 0,
        totalSpeed: (json['totalSpeed'] ?? json['total_speed'] ?? 0).toDouble(),
        totalDownloaded:
            json['totalDownloaded'] ?? json['total_downloaded'] ?? 0,
      );
}

abstract class KernelInterface {
  String get name;
  bool get isRunning;

  Stream<DownloadTask> get onProgress;
  Stream<DownloadTask> get onComplete;
  Stream<DownloadStatistics> get onStatistics;

  Future<bool> start();
  Future<void> stop();

  Future<String?> addDownload(
    String url,
    String filename, {
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
  });

  Future<bool> pauseDownload(String taskId);
  Future<bool> resumeDownload(String taskId);
  Future<bool> cancelDownload(String taskId);

  Future<List<DownloadTask>> getTasks();
  Future<DownloadStatistics?> getStatistics();

  Future<bool> renameTask(String taskId, String newFileName);
  Future<bool> moveTask(String taskId, String targetDir);

  Future<DownloadConfig?> getConfig();
  Future<bool> setConfig(DownloadConfig config);

  Future<String?> getDownloadDir();
  Future<bool> setDownloadDir(String path);

  Future<bool> clearAllData();

  Future<bool> retryFailedSegments(String taskId);
  Future<bool> retrySegment(String taskId, int segmentIndex);

  Future<bool> testProxyConnection({
    required String type,
    required String host,
    required int port,
    String? username,
    String? password,
  });

  void dispose();
}
