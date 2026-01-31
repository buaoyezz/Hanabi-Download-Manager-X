import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'popup_window_service.dart';
import 'logger_service.dart';

// 下载监听服务 - 监听来自浏览器插件的下载请求
class DownloadListenerService {
  final BuildContext context;
  final _logger = LoggerService();
  Timer? _pollTimer;
  final String _baseUrl = 'http://127.0.0.1:9710';
  bool _isChecking = false;
  bool _isShowingPopup = false; // 防止弹窗期间重复触发

  DownloadListenerService(this.context);

  // 开始监听下载请求
  void startListening() {
    _logger.info('Download listener started');
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      await _checkForNewDownloads();
    });
  }

  // 停止监听
  void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isChecking = false;
    _isShowingPopup = false;
    _logger.info('Download listener stopped');
  }

  // 检查是否有新的下载请求
  Future<void> _checkForNewDownloads() async {
    // 如果正在检查或正在显示弹窗，跳过本次检查
    if (_isChecking || _isShowingPopup) return;
    _isChecking = true;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/download/pending-popup'),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final success = result['success'] == true;
        if (success && result['data'] != null) {
          final downloadData = result['data'] as Map<String, dynamic>;
          _logger.info('New download from browser: ${downloadData['filename']}');
          await _showPopupForDownload(downloadData);
        }
      }
    } catch (e) {
      // 静默处理错误，避免日志刷屏
    } finally {
      _isChecking = false;
    }
  }

  // 为新下载显示弹窗
  Future<void> _showPopupForDownload(Map<String, dynamic> downloadData) async {
    if (!context.mounted || _isShowingPopup) return;

    _isShowingPopup = true;
    try {
      await PopupWindowService.showPopupDownload(
        context,
        url: downloadData['url'] ?? '',
        suggestedFilename: downloadData['filename'],
        referer: downloadData['referer'],
        userAgent: downloadData['user_agent'],
        headers: downloadData['headers'] as Map<String, dynamic>?,
        isFromBrowser: true,
      );
    } catch (e) {
      _logger.error('Failed to show popup: $e');
    } finally {
      _isShowingPopup = false;
    }
  }
}
