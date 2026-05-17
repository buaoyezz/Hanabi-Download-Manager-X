import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NetworkInfo {
  final bool isConnected;
  final bool hasInternet;
  final String? localIP;
  final int? ping;
  final String connectionType;

  NetworkInfo({
    required this.isConnected,
    required this.hasInternet,
    this.localIP,
    this.ping,
    this.connectionType = 'Unknown',
  });
}

class NetworkStatusService extends ChangeNotifier {
  NetworkInfo _networkInfo = NetworkInfo(
    isConnected: false,
    hasInternet: false,
  );

  NetworkInfo get networkInfo => _networkInfo;

  Timer? _checkTimer;
  bool _isChecking = false;
  bool _isForegroundActive = true;
  static const _foregroundInterval = Duration(seconds: 30);
  static const _backgroundInterval = Duration(minutes: 2);

  void startMonitoring() {
    stopMonitoring();
    unawaited(_checkNetworkStatus());
    _scheduleNextCheck();
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  void setForegroundActive(bool active) {
    if (_isForegroundActive == active) return;
    _isForegroundActive = active;
    _scheduleNextCheck();
  }

  void _scheduleNextCheck() {
    _checkTimer?.cancel();
    final interval =
        _isForegroundActive ? _foregroundInterval : _backgroundInterval;
    _checkTimer = Timer(interval, () async {
      await _checkNetworkStatus();
      _scheduleNextCheck();
    });
  }

  Future<void> _checkNetworkStatus() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      // 检查本地网络连接
      final interfaces = await NetworkInterface.list();
      final hasConnection = interfaces.isNotEmpty;

      String? localIP;
      if (hasConnection) {
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              localIP = addr.address;
              break;
            }
          }
          if (localIP != null) break;
        }
      }

      // 检查互联网连接
      int? ping;
      bool hasInternet = false;
      try {
        final stopwatch = Stopwatch()..start();
        final response = await http
            .get(
              Uri.parse('https://www.google.com'),
            )
            .timeout(const Duration(seconds: 5));
        stopwatch.stop();

        if (response.statusCode == 200) {
          hasInternet = true;
          ping = stopwatch.elapsedMilliseconds;
        }
      } catch (e) {
        // 尝试备用地址
        try {
          final stopwatch = Stopwatch()..start();
          final response = await http
              .get(
                Uri.parse('https://www.baidu.com'),
              )
              .timeout(const Duration(seconds: 5));
          stopwatch.stop();

          if (response.statusCode == 200) {
            hasInternet = true;
            ping = stopwatch.elapsedMilliseconds;
          }
        } catch (_) {
          hasInternet = false;
        }
      }

      final nextInfo = NetworkInfo(
        isConnected: hasConnection,
        hasInternet: hasInternet,
        localIP: localIP,
        ping: ping,
        connectionType: _getConnectionType(),
      );

      if (_hasNetworkInfoChanged(_networkInfo, nextInfo)) {
        _networkInfo = nextInfo;
        notifyListeners();
      } else {
        _networkInfo = nextInfo;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Network status check error: $e');
      }
    } finally {
      _isChecking = false;
    }
  }

  bool _hasNetworkInfoChanged(NetworkInfo previous, NetworkInfo next) {
    return previous.isConnected != next.isConnected ||
        previous.hasInternet != next.hasInternet ||
        previous.localIP != next.localIP ||
        previous.connectionType != next.connectionType ||
        (previous.ping ?? -1) != (next.ping ?? -1);
  }

  String _getConnectionType() {
    // 在 Windows 上，可以通过其他方式检测
    // 这里简化处理
    return 'Ethernet/WiFi';
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
