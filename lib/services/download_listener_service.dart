import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'client_config_service.dart';
import 'integrated_download_service.dart';
import 'popup_window_service.dart';
import 'logger_service.dart';

// 下载监听服务 - 监听来自浏览器插件的下载请求
class DownloadListenerService {
  final BuildContext context;
  final _logger = LoggerService();
  bool _isListening = false;
  bool _isChecking = false;
  bool _isForegroundActive = true;
  bool _isShowingPopup = false; // 防止独立 popup 创建期间重复触发
  String? _lastPopupSignature;
  DateTime? _lastPopupOpenedAt;
  static const Duration _popupDedupWindow = Duration(seconds: 4);

  DownloadListenerService(this.context);

  // 开始监听下载请求
  void startListening() {
    if (_isListening) return;
    _isListening = true;
    _logger.info('Download listener started');
    unawaited(_pollLoop());
  }

  // 停止监听
  void stopListening() {
    _isListening = false;
    _isChecking = false;
    _isShowingPopup = false;
    _lastPopupSignature = null;
    _lastPopupOpenedAt = null;
    _logger.info('Download listener stopped');
  }

  void setForegroundActive(bool active) {
    if (_isForegroundActive == active) return;
    _isForegroundActive = active;
    _logger.info(
      'Download listener ${active ? 'foreground' : 'background'} mode',
    );
  }

  Future<void> _pollLoop() async {
    while (_isListening) {
      await _checkForNewDownloads();
      if (!_isListening) return;
      if (_isShowingPopup) {
        await Future.delayed(const Duration(milliseconds: 500));
      } else if (!_isForegroundActive) {
        await Future.delayed(const Duration(seconds: 30));
      }
    }
  }

  // 检查是否有新的下载请求
  Future<void> _checkForNewDownloads() async {
    // 如果正在检查或正在显示弹窗，跳过本次检查
    if (_isChecking || _isShowingPopup) return;
    _isChecking = true;

    try {
      final config = Provider.of<ClientConfigService>(context, listen: false);
      final baseUrl = config.getBrowserExtensionBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/download/pending-popup')
                .replace(queryParameters: {
              'wait_ms': _isForegroundActive ? '15000' : '1000',
            }),
          )
          .timeout(
            _isForegroundActive
                ? const Duration(seconds: 20)
                : const Duration(seconds: 4),
          );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final success = result['success'] == true;
        if (success && result['data'] != null) {
          final downloadData = result['data'] as Map<String, dynamic>;
          _logger
              .info('New download from browser: ${downloadData['filename']}');
          await _handleDownloadRequest(downloadData);
        }
      }
    } catch (e) {
      // 静默处理错误，避免日志刷屏
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _handleDownloadRequest(Map<String, dynamic> downloadData) async {
    final config = Provider.of<ClientConfigService>(context, listen: false);
    final enablePopup = config.getEnablePopupWindow();

    if (enablePopup) {
      await _showPopupForDownload(downloadData);
      return;
    }

    final url = downloadData['url']?.toString() ?? '';
    final filename = downloadData['filename']?.toString() ?? '';
    if (url.isEmpty || filename.isEmpty) {
      _logger.warning('Invalid download data from browser');
      return;
    }

    final downloadService =
        Provider.of<IntegratedDownloadService>(context, listen: false);
    final headersRaw = downloadData['headers'];
    final headers =
        headersRaw is Map ? headersRaw.cast<String, dynamic>() : null;

    final taskId = await downloadService.addTask(
      url,
      filename,
      referer: downloadData['referer']?.toString(),
      userAgent:
          (downloadData['user_agent'] ?? downloadData['userAgent'])?.toString(),
      cookies: downloadData['cookies']?.toString(),
      headers: headers,
    );

    if (taskId == null) {
      _logger.warning(
        'Download auto-accept rejected: ${downloadService.lastAddTaskError ?? filename}',
      );
      return;
    }

    _logger.info('Download auto-accepted: $filename');
  }

  // 为新下载显示独立 popup 窗口
  Future<void> _showPopupForDownload(Map<String, dynamic> downloadData) async {
    if (_isShowingPopup) return;

    final popupSignature = _popupSignatureFor(downloadData);
    final now = DateTime.now();
    if (_lastPopupSignature == popupSignature &&
        _lastPopupOpenedAt != null &&
        now.difference(_lastPopupOpenedAt!) < _popupDedupWindow) {
      _logger.warning(
        'Suppress duplicate standalone popup for ${downloadData['filename']}',
      );
      return;
    }

    _isShowingPopup = true;
    _lastPopupSignature = popupSignature;
    _lastPopupOpenedAt = now;
    try {
      await PopupWindowService.showPopupDownloadWindow(
        url: downloadData['url'] ?? '',
        suggestedFilename: downloadData['filename'],
        referer: downloadData['referer'],
        userAgent: downloadData['user_agent'],
        cookies: downloadData['cookies']?.toString(),
        headers: downloadData['headers'] as Map<String, dynamic>?,
        isFromBrowser: true,
      );
    } catch (e) {
      _logger.error('Failed to show popup download window: $e');
    } finally {
      // 延迟重置标志，给窗口和对话框一些时间完成切换
      Future.delayed(const Duration(milliseconds: 500), () {
        _isShowingPopup = false;
      });
    }
  }

  String _popupSignatureFor(Map<String, dynamic> downloadData) {
    final url = _normalizePopupSignatureField(downloadData['url']);
    final filename = _normalizePopupSignatureField(downloadData['filename']);
    final referer = _normalizePopupSignatureField(downloadData['referer']);
    return '$url|$filename|$referer';
  }

  String _normalizePopupSignatureField(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return '';
    }

    try {
      final parsed = Uri.parse(text);
      if (!parsed.hasScheme || !parsed.hasAuthority) {
        return text;
      }
      return parsed.removeFragment().toString();
    } catch (_) {
      return text;
    }
  }
}
