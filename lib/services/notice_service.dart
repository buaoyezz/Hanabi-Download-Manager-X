import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notice_model.dart';
import '../utils/constants.dart';
import 'app_logger_service.dart';

class NoticeService extends ChangeNotifier {
  static const String _noticeApiBase = 'https://x.zzbuaoye.top/api/v1';

  final AppLoggerService? _logger;

  List<Notice> _notices = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetchTime;

  List<Notice> get notices => _notices;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;

  List<Notice> get pinnedNotices =>
      _notices.where((n) => n.pinned && n.isActive).toList();

  List<Notice> get activeNotices =>
      _notices.where((n) => n.isActive).toList();

  NoticeService({AppLoggerService? logger}) : _logger = logger;

  Future<void> fetchNotices({bool force = false}) async {
    if (_isLoading) return;

    if (!force && _notices.isNotEmpty && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed.inMinutes < 5) return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      const channel = AppConstants.channel;
      final uri = Uri.parse('$_noticeApiBase/notices').replace(
        queryParameters: {
          'surface': 'app',
          'platform': 'windows',
          'channel': channel,
        },
      );

      _logger?.info('Notice', 'Fetching notices from $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final data = body['items'] as List<dynamic>;
        _notices = data
            .map((item) => Notice.fromJson(item as Map<String, dynamic>))
            .where((n) => n.status == NoticeStatus.published)
            .toList();

        _notices.sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        _lastFetchTime = DateTime.now();
        _logger?.info('Notice', 'Fetched ${_notices.length} notices');
      } else {
        _error = 'HTTP ${response.statusCode}';
        _logger?.error('Notice', 'Failed to fetch notices: $_error');
      }
    } catch (e) {
      _error = e.toString();
      _logger?.error('Notice', 'Error fetching notices: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Notice?> fetchNoticeById(String id) async {
    try {
      final uri = Uri.parse('$_noticeApiBase/notices/$id');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Notice.fromJson(data);
      }
      return null;
    } catch (e) {
      _logger?.error('Notice', 'Error fetching notice $id: $e');
      return null;
    }
  }
}
