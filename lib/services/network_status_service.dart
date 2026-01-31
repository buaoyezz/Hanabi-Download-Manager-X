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

  void startMonitoring() {
    _checkNetworkStatus();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkNetworkStatus();
    });
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
  }

  Future<void> _checkNetworkStatus() async {
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
        final response = await http.get(
          Uri.parse('https://www.google.com'),
        ).timeout(const Duration(seconds: 5));
        stopwatch.stop();
        
        if (response.statusCode == 200) {
          hasInternet = true;
          ping = stopwatch.elapsedMilliseconds;
        }
      } catch (e) {
        // 尝试备用地址
        try {
          final stopwatch = Stopwatch()..start();
          final response = await http.get(
            Uri.parse('https://www.baidu.com'),
          ).timeout(const Duration(seconds: 5));
          stopwatch.stop();
          
          if (response.statusCode == 200) {
            hasInternet = true;
            ping = stopwatch.elapsedMilliseconds;
          }
        } catch (_) {
          hasInternet = false;
        }
      }

      _networkInfo = NetworkInfo(
        isConnected: hasConnection,
        hasInternet: hasInternet,
        localIP: localIP,
        ping: ping,
        connectionType: _getConnectionType(),
      );

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Network status check error: $e');
      }
    }
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
