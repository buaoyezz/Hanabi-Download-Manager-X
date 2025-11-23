import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../widgets/popup_download_dialog.dart';
import 'logger_service.dart';
import '../main.dart';

// 弹窗管理服务 - 用于显示IDM风格的下载弹窗
class PopupWindowService {
  static const platform = MethodChannel('com.hanabi.download/window');
  static final _logger = LoggerService();
  
  // 显示弹窗下载对话框
  static Future<void> showPopupDownload(
    BuildContext context, {
    required String url,
    String? suggestedFilename,
    String? referer,
    String? userAgent,
    Map<String, dynamic>? headers,
    bool isFromBrowser = false,
  }) async {
    _logger.info('Popup request: url=$url, filename=$suggestedFilename');
    await showAndBringToFront();
    await flashWindow();
    
    final ctx = navigatorKey.currentContext ?? context;
    if (ctx == null) {
      _logger.error('No context available for dialog');
      return;
    }
    
    _logger.debug('Opening popup dialog');
    await fluent.showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (context) => fluent.ContentDialog(
        constraints: const BoxConstraints(maxWidth: 520),
        style: fluent.ContentDialogThemeData(
          padding: EdgeInsets.zero,
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
        ),
        content: PopupDownloadDialog(
          url: url,
          suggestedFilename: suggestedFilename,
          referer: referer,
          userAgent: userAgent,
          headers: headers,
          isFromBrowser: isFromBrowser,
        ),
      ),
    );
    _logger.debug('Popup dialog closed');
  }
  
  // 显示窗口并带到最前面
  static Future<void> showAndBringToFront() async {
    if (!Platform.isWindows) return;
    
    try {
      _logger.debug('Restore window');
      appWindow.restore();
      _logger.debug('Show window');
      appWindow.show();
      
      _logger.debug('Delay before bringToFront');
      await Future.delayed(const Duration(milliseconds: 50));
      
      _logger.debug('Invoke bringToFront');
      await platform.invokeMethod('bringToFront');
      _logger.debug('bringToFront done');
    } catch (e) {
      _logger.error('Show/bringToFront failed: $e');
    }
  }
  
  // 将窗口带到最前面（临时置顶）
  static Future<void> bringWindowToFront() async {
    if (!Platform.isWindows) return;
    
    try {
      _logger.debug('Invoke bringToFront');
      await platform.invokeMethod('bringToFront');
      _logger.debug('bringToFront done');
    } catch (e) {
      _logger.error('bringToFront failed: $e');
    }
  }
  
  // 设置窗口永久置顶
  static Future<void> setAlwaysOnTop(bool alwaysOnTop) async {
    if (!Platform.isWindows) return;
    
    try {
      _logger.debug('Invoke setAlwaysOnTop=$alwaysOnTop');
      await platform.invokeMethod('setAlwaysOnTop', {'alwaysOnTop': alwaysOnTop});
      _logger.debug('setAlwaysOnTop done');
    } catch (e) {
      _logger.error('setAlwaysOnTop failed: $e');
    }
  }
  
  // 闪烁窗口以引起注意
  static Future<void> flashWindow() async {
    if (!Platform.isWindows) return;
    
    try {
      _logger.debug('Invoke flashWindow');
      await platform.invokeMethod('flashWindow');
      _logger.debug('flashWindow done');
    } catch (e) {
      _logger.error('flashWindow failed: $e');
    }
  }
}
