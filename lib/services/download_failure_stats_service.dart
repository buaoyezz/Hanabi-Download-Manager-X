import 'package:flutter/foundation.dart';
import '../models/download_task.dart';

class DownloadFailureRecord {
  final DateTime timestamp;
  final String taskId;
  final String filename;
  final String? url;
  final String reason;
  final String? rawError;
  final String? downloadCore;

  DownloadFailureRecord({
    required this.timestamp,
    required this.taskId,
    required this.filename,
    required this.reason,
    this.url,
    this.rawError,
    this.downloadCore,
  });
}

class DownloadFailureStatsService extends ChangeNotifier {
  static final DownloadFailureStatsService _instance =
      DownloadFailureStatsService._internal();
  factory DownloadFailureStatsService() => _instance;
  DownloadFailureStatsService._internal();

  final List<DownloadFailureRecord> _records = [];
  final Map<String, int> _reasonCounts = {};
  final Map<String, DateTime> _lastRecordedAt = {};

  List<DownloadFailureRecord> get recentFailures =>
      List.unmodifiable(_records.take(10));
  List<DownloadFailureRecord> get records =>
      List.unmodifiable(_records);
  Map<String, int> get reasonCounts => Map.unmodifiable(_reasonCounts);
  int get totalFailures => _records.length;

  String classifyReasonKey(String? error) => _classifyReason(error);

  void recordFailure(DownloadTask task) {
    final now = DateTime.now();
    final last = _lastRecordedAt[task.id];
    if (last != null && now.difference(last).inSeconds < 2) {
      return;
    }

    final reason = _classifyReason(task.error);
    _lastRecordedAt[task.id] = now;

    final record = DownloadFailureRecord(
      timestamp: now,
      taskId: task.id,
      filename: task.fileName,
      url: task.url,
      reason: reason,
      rawError: task.error,
      downloadCore: task.downloadCore,
    );

    _records.insert(0, record);
    if (_records.length > 200) {
      _records.removeLast();
    }

    _reasonCounts.update(reason, (count) => count + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  String _classifyReason(String? error) {
    if (error == null || error.trim().isEmpty) return 'unknown';

    final msg = error.toLowerCase();
    final httpCode = _extractHttpCode(msg);
    if (httpCode != null) {
      if (httpCode == 401 || httpCode == 403) return 'auth:$httpCode';
      if (httpCode == 404) return 'not_found:$httpCode';
      if (httpCode == 416) return 'range:$httpCode';
      if (httpCode == 429) return 'rate_limit:$httpCode';
      if (httpCode >= 500) return 'server:$httpCode';
      if (httpCode >= 400) return 'http:$httpCode';
    }

    if (_containsAny(msg, ['timeout', 'timed out', '超时'])) {
      return 'timeout';
    }
    if (_containsAny(msg, [
      'connection reset',
      'reset by peer',
      'broken pipe',
      'connection closed',
      'refused',
      '连接被重置',
      '连接断开',
      '拒绝连接',
    ])) {
      return 'connection';
    }
    if (_containsAny(msg, [
      'failed host lookup',
      'name or service not known',
      'no address associated',
      'dns',
      '无法解析',
      '解析失败',
    ])) {
      return 'dns';
    }
    if (_containsAny(msg, [
      'ssl',
      'handshake',
      'certificate',
      '证书',
    ])) {
      return 'ssl';
    }
    if (_containsAny(msg, [
      'size mismatch',
      'corrupt',
      'checksum',
      '校验',
      '文件损坏',
    ])) {
      return 'checksum';
    }
    if (_containsAny(msg, [
      'no space left',
      'disk full',
      'permission',
      'access denied',
      'readonly',
      'filesystemexception',
      '空间不足',
      '权限',
      '拒绝访问',
    ])) {
      return 'disk';
    }
    if (_containsAny(msg, ['range not satisfiable', 'range'])) {
      return 'range';
    }

    return 'other';
  }

  int? _extractHttpCode(String msg) {
    final patterns = [
      RegExp(r'http\s*(\d{3})'),
      RegExp(r'status\s*code\s*(\d{3})'),
      RegExp(r'code\s*(\d{3})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(msg);
      if (match != null) {
        final code = int.tryParse(match.group(1) ?? '');
        if (code != null) return code;
      }
    }
    return null;
  }

  bool _containsAny(String msg, List<String> patterns) {
    for (final p in patterns) {
      if (msg.contains(p)) return true;
    }
    return false;
  }
}
