import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notice_model.dart';
import '../utils/constants.dart';
import 'app_logger_service.dart';
import 'client_config_service.dart';

class NoticeService extends ChangeNotifier {
  static const String _noticeApiBase = 'https://x.zzbuaoye.net/api/v1';
  static const Duration _foregroundHeartbeatInterval = Duration(minutes: 2);
  static const Duration _backgroundHeartbeatInterval = Duration(minutes: 10);

  final AppLoggerService? _logger;
  final ClientConfigService _config;

  List<Notice> _notices = [];
  bool _isLoading = false;
  bool _onlineHeartbeatInFlight = false;
  String? _error;
  DateTime? _lastFetchTime;
  Timer? _onlineHeartbeatTimer;
  String? _onlineSessionId;
  int? _onlineUserCount;
  DateTime? _onlineLastSeenAt;
  bool _isBackgroundMode = false;

  List<Notice> get notices => _notices;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastFetchTime => _lastFetchTime;
  int? get onlineUserCount => _onlineUserCount;
  DateTime? get onlineLastSeenAt => _onlineLastSeenAt;
  bool get isBackgroundMode => _isBackgroundMode;

  List<Notice> get pinnedNotices =>
      _notices.where((n) => n.pinned && n.isActive).toList();

  List<Notice> get activeNotices => _notices.where((n) => n.isActive).toList();

  NoticeService({
    AppLoggerService? logger,
    ClientConfigService? config,
  })  : _logger = logger,
        _config = config ?? ClientConfigService() {
    _config.addListener(_handleConfigChanged);
  }

  void startOnlineHeartbeat() {
    if (!_canSendOnlineHeartbeat()) {
      stopOnlineHeartbeat();
      return;
    }

    if (_onlineHeartbeatTimer != null) return;

    _startOnlineHeartbeatTimer(sendImmediately: true);
  }

  void setBackgroundMode(bool isBackgroundMode) {
    if (_isBackgroundMode == isBackgroundMode) {
      return;
    }

    _isBackgroundMode = isBackgroundMode;
    if (!_canSendOnlineHeartbeat()) {
      stopOnlineHeartbeat();
      return;
    }

    if (_onlineHeartbeatTimer != null) {
      _startOnlineHeartbeatTimer(sendImmediately: !isBackgroundMode);
    }
  }

  void stopOnlineHeartbeat() {
    final hadOnlineState = _onlineHeartbeatTimer != null ||
        _onlineSessionId != null ||
        _onlineUserCount != null ||
        _onlineLastSeenAt != null;

    _onlineHeartbeatTimer?.cancel();
    _onlineHeartbeatTimer = null;
    _onlineSessionId = null;
    _onlineUserCount = null;
    _onlineLastSeenAt = null;

    if (hadOnlineState) {
      notifyListeners();
    }
  }

  Future<void> sendOnlineHeartbeat() async {
    if (!_canSendOnlineHeartbeat()) return;
    if (_onlineHeartbeatInFlight) return;
    _onlineHeartbeatInFlight = true;

    try {
      final activityId = await _config.getSoftwareActivityDailyId();
      if (!_canSendOnlineHeartbeat()) return;

      final uri = Uri.parse('$_noticeApiBase/activity/software/online');
      final response = await http
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              if (_onlineSessionId != null) 'sessionId': _onlineSessionId,
              'activityId': activityId,
              'surface': 'software',
              'platform': 'windows',
              'channel': AppConstants.channel,
              'version': AppConstants.version,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200 && response.statusCode != 202) {
        _logger?.debug(
          'Notice',
          'Online heartbeat rejected: HTTP ${response.statusCode}',
        );
        return;
      }

      if (!_canSendOnlineHeartbeat()) return;

      final payload = json.decode(response.body) as Map<String, dynamic>;
      var changed = false;

      final sessionId = payload['sessionId'];
      if (sessionId is String && sessionId.isNotEmpty) {
        if (_onlineSessionId != sessionId) {
          _onlineSessionId = sessionId;
          changed = true;
        }
      }

      final online = payload['online'];
      if (online is Map<String, dynamic>) {
        final total = online['total'];
        if (total is num && _onlineUserCount != total.toInt()) {
          _onlineUserCount = total.toInt();
          changed = true;
        }

        final lastSeenAt = online['lastSeenAt'];
        if (lastSeenAt is String) {
          final parsedLastSeenAt = DateTime.tryParse(lastSeenAt);
          if (_onlineLastSeenAt != parsedLastSeenAt) {
            _onlineLastSeenAt = parsedLastSeenAt;
            changed = true;
          }
        }
      }

      if (changed) {
        notifyListeners();
      }
    } catch (e) {
      _logger?.debug('Notice', 'Online heartbeat failed: $e');
    } finally {
      _onlineHeartbeatInFlight = false;
    }
  }

  void _handleConfigChanged() {
    if (_canSendOnlineHeartbeat()) {
      startOnlineHeartbeat();
    } else {
      stopOnlineHeartbeat();
    }
  }

  bool _canSendOnlineHeartbeat() {
    return _config.getEnableOnlineStats() && !_config.shouldShowOobe();
  }

  void _startOnlineHeartbeatTimer({required bool sendImmediately}) {
    _onlineHeartbeatTimer?.cancel();
    _onlineHeartbeatTimer = Timer.periodic(
      _isBackgroundMode
          ? _backgroundHeartbeatInterval
          : _foregroundHeartbeatInterval,
      (_) => unawaited(sendOnlineHeartbeat()),
    );

    if (sendImmediately) {
      unawaited(sendOnlineHeartbeat());
    }
  }

  @override
  void dispose() {
    _config.removeListener(_handleConfigChanged);
    _onlineHeartbeatTimer?.cancel();
    _onlineHeartbeatTimer = null;
    super.dispose();
  }

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
