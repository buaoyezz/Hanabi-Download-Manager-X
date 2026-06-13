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
  static const Duration _monitorInterval = Duration(seconds: 30);

  NetworkInfo _networkInfo = NetworkInfo(
    isConnected: false,
    hasInternet: false,
  );

  NetworkInfo get networkInfo => _networkInfo;

  Timer? _checkTimer;
  bool _isMonitoring = false;
  bool _checkInFlight = false;

  void startMonitoring() {
    if (_isMonitoring) {
      return;
    }
    _isMonitoring = true;
    _checkNetworkStatus();
    _checkTimer = Timer.periodic(_monitorInterval, (_) {
      _checkNetworkStatus();
    });
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isMonitoring = false;
  }

  Future<void> refreshNow() {
    return _checkNetworkStatus();
  }

  Future<void> _checkNetworkStatus() async {
    if (_checkInFlight) {
      return;
    }
    _checkInFlight = true;

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
            .head(
              Uri.parse('https://www.gstatic.com/generate_204'),
            )
            .timeout(const Duration(seconds: 5));
        stopwatch.stop();

        if (response.statusCode >= 200 && response.statusCode < 400) {
          hasInternet = true;
          ping = stopwatch.elapsedMilliseconds;
        }
      } catch (e) {
        // 尝试备用地址
        try {
          final stopwatch = Stopwatch()..start();
          final response = await http
              .head(
                Uri.parse('https://www.baidu.com/favicon.ico'),
              )
              .timeout(const Duration(seconds: 5));
          stopwatch.stop();

          if (response.statusCode >= 200 && response.statusCode < 400) {
            hasInternet = true;
            ping = stopwatch.elapsedMilliseconds;
          }
        } catch (_) {
          hasInternet = false;
        }
      }

      final nextNetworkInfo = NetworkInfo(
        isConnected: hasConnection,
        hasInternet: hasInternet,
        localIP: localIP,
        ping: ping,
        connectionType: _getConnectionType(),
      );

      if (!_isSameNetworkInfo(_networkInfo, nextNetworkInfo)) {
        _networkInfo = nextNetworkInfo;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Network status check error: $e');
      }
    } finally {
      _checkInFlight = false;
    }
  }

  bool _isSameNetworkInfo(NetworkInfo a, NetworkInfo b) {
    return a.isConnected == b.isConnected &&
        a.hasInternet == b.hasInternet &&
        a.localIP == b.localIP &&
        a.ping == b.ping &&
        a.connectionType == b.connectionType;
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
