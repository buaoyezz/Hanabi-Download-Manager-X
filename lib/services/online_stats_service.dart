import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import 'app_logger_service.dart';

class OnlineStatsService extends ChangeNotifier {
  final _logger = AppLoggerService();
  Timer? _fetchTimer;
  late final http.Client _httpClient;
  
  // 统计数据
  final _statsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;
  
  // 配置
  static const String _baseUrl = 'https://online.zzbuaoye.top';
  static const Duration _fetchInterval = Duration(seconds: 10);
  static const bool _enableOnlineStats = true; // 启用在线统计
  static const String _adminToken = 'hanabi_admin_2024'; // 管理员令牌
  
  OnlineStatsService() {
    // 创建忽略 SSL 证书错误的 HTTP 客户端（用于 Cloudflare 代理）
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    _httpClient = IOClient(ioClient);
  }
  
  /// 开始获取统计数据
  void startFetching() {
    if (_fetchTimer != null) return;
    
    _logger.info('OnlineStats', 'Starting stats fetching');
    
    // 立即获取一次
    _fetchStats();
    
    // 启动定时器
    _fetchTimer = Timer.periodic(_fetchInterval, (_) => _fetchStats());
  }
  
  /// 停止获取统计数据
  void stopFetching() {
    _fetchTimer?.cancel();
    _fetchTimer = null;
    _logger.info('OnlineStats', 'Stats fetching stopped');
  }
  
  /// 获取统计数据
  Future<void> _fetchStats() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/api/stats?token=$_adminToken'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _statsController.add(data);
      } else if (response.statusCode == 403) {
        _logger.warning('OnlineStats', 'Access denied: Invalid admin token');
      }
    } catch (e) {
      _logger.debug('OnlineStats', 'Failed to fetch stats: $e');
    }
  }
  
  @override
  void dispose() {
    stopFetching();
    _statsController.close();
    _httpClient.close();
    super.dispose();
  }
}
