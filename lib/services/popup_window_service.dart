import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:provider/provider.dart';
import '../widgets/popup_download_dialog.dart';
import 'logger_service.dart';
import 'localization_service.dart';
import '../main.dart';

// 弹窗管理服务 - 用于显示下载弹窗
class PopupWindowService {
  static const platform = MethodChannel('com.hanabi.download/window');
  static final _logger = LoggerService();

  static String _localeToTag(Locale locale) {
    final buffer = StringBuffer(locale.languageCode);
    final script = locale.scriptCode;
    final country = locale.countryCode;
    if (script != null && script.isNotEmpty) {
      buffer.write('-$script');
    }
    if (country != null && country.isNotEmpty) {
      buffer.write('-$country');
    }
    return buffer.toString();
  }

  /// 获取 hanabi-popup.exe 的路径
  static String? _getPopupExePath() {
    final exeDir = Platform.resolvedExecutable.replaceAll(RegExp(r'[^\\]+$'), '');
    // 尝试多个可能的位置
    final possiblePaths = [
      // Release 模式：data/zzbuaoye_assets 目录
      '${exeDir}data\\zzbuaoye_assets\\hanabi-popup.exe',
      // 开发时的位置
      '${Directory.current.path}\\hanabi-popup\\src-tauri\\target\\release\\hanabi-popup.exe',
      // 备用：与主程序同目录
      '${Directory.current.path}\\hanabi-popup.exe',
      '${exeDir}hanabi-popup.exe',
    ];

    for (final path in possiblePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  // 使用独立的 Tauri 弹窗显示下载对话框
  static Future<void> showPopupDownloadWindow({
    required String url,
    String? suggestedFilename,
    String? referer,
    String? userAgent,
    Map<String, dynamic>? headers,
    bool isFromBrowser = false,
  }) async {
    _logger.info('Popup window request: url=$url, filename=$suggestedFilename');

    try {
      final popupExePath = _getPopupExePath();

      if (popupExePath != null) {
        // 使用新的 Tauri 弹窗
        _logger.info('Launching Tauri popup: $popupExePath');

        final args = <String>[];
        if (url.isNotEmpty) {
          args.addAll(['--url', url]);
        }
        if (suggestedFilename != null && suggestedFilename.isNotEmpty) {
          args.addAll(['--filename', suggestedFilename]);
        }

        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          final locale = ctx.read<LocalizationService>().effectiveLocale;
          final localeTag = _localeToTag(locale);
          if (localeTag.isNotEmpty) {
            args.addAll(['--locale', localeTag]);
          }
        }

        await Process.start(popupExePath, args, mode: ProcessStartMode.detached);
        _logger.info('Tauri popup launched successfully');
        return;
      }

      // 如果找不到 Tauri 弹窗，回退到 Dialog 方式
      _logger.info('Tauri popup not found, falling back to dialog mode');
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        await showPopupDownload(
          ctx,
          url: url,
          suggestedFilename: suggestedFilename,
          referer: referer,
          userAgent: userAgent,
          headers: headers,
          isFromBrowser: isFromBrowser,
        );
      }
    } catch (e) {
      _logger.error('Failed to launch popup: $e');
      // 回退到旧的 Dialog 方式
      _logger.info('Falling back to dialog mode');
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        await showPopupDownload(
          ctx,
          url: url,
          suggestedFilename: suggestedFilename,
          referer: referer,
          userAgent: userAgent,
          headers: headers,
          isFromBrowser: isFromBrowser,
        );
      }
    }
  }

  // 显示弹窗下载对话框（旧方式，需要拉起主窗口）
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
