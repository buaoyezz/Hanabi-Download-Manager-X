import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/popup_download_dialog.dart';
import 'client_config_service.dart';
import 'kernel/kernel_manager.dart';
import 'logger_service.dart';
import 'window_effect_service.dart';
import '../main.dart';

enum PopupWindowPreviewStage {
  compose,
  progress,
  completed,
}

// 弹窗管理服务 - 用于显示下载弹窗
class PopupWindowService {
  static const platform = MethodChannel('com.hanabi.download/window');
  static const _popupEffectCrashGuardWindow = Duration(seconds: 10);
  static final _logger = LoggerService();

  static Future<void> showPopupDownloadWindow({
    required String url,
    String? suggestedFilename,
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
    bool isFromBrowser = false,
  }) async {
    final opened = await _openNativePopupWindow(
      url: url,
      suggestedFilename: suggestedFilename,
      referer: referer,
      userAgent: userAgent,
      cookies: cookies,
      headers: headers,
    );
    if (opened) {
      return;
    }

    _logger.warning(
      'Standalone popup unavailable, falling back to embedded dialog',
    );

    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      _logger.warning('Main window context unavailable for popup request');
      return;
    }
    await showPopupDownload(
      ctx,
      url: url,
      suggestedFilename: suggestedFilename,
      referer: referer,
      userAgent: userAgent,
      cookies: cookies,
      headers: headers,
      isFromBrowser: isFromBrowser,
    );
  }

  static Future<void> showPopupPreviewWindow({
    required PopupWindowPreviewStage stage,
  }) async {
    final previewFileName = switch (stage) {
      PopupWindowPreviewStage.compose => 'hanabi-popup-preview.zip',
      PopupWindowPreviewStage.progress => 'hanabi-popup-preview-video.mp4',
      PopupWindowPreviewStage.completed => 'hanabi-popup-preview.txt',
    };

    final opened = await _openNativePopupWindow(
      url: 'https://example.com/hanabi-popup-preview/$previewFileName',
      suggestedFilename: previewFileName,
      previewStage: stage,
    );

    if (!opened) {
      throw StateError('Standalone popup preview window is unavailable');
    }
  }

  static Future<bool> _openNativePopupWindow({
    required String url,
    String? suggestedFilename,
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
    PopupWindowPreviewStage? previewStage,
  }) async {
    if (!Platform.isWindows) return false;

    try {
      final downloadDir = await KernelManager().getDownloadDir();
      final localeTag =
          WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
      final windowTitle = previewStage == null
          ? 'Hanabi Download Pop ${DateTime.now().microsecondsSinceEpoch}'
          : 'Hanabi Popup Preview ${previewStage.name} ${DateTime.now().microsecondsSinceEpoch}';
      final windowEffectPayload = await _currentWindowEffectPayload();
      final guardNativeEffect = _shouldGuardNativeEffect(windowEffectPayload);

      final payload = <String, dynamic>{
        'url': url,
        if (suggestedFilename?.trim().isNotEmpty ?? false)
          'filename': suggestedFilename!.trim(),
        'window_title': windowTitle,
        'save_path': (downloadDir?.trim().isNotEmpty ?? false)
            ? downloadDir!.trim()
            : '',
        if (localeTag.trim().isNotEmpty) 'locale': localeTag,
        if (referer?.trim().isNotEmpty ?? false) 'referer': referer!.trim(),
        if (userAgent?.trim().isNotEmpty ?? false)
          'user_agent': userAgent!.trim(),
        if (cookies?.trim().isNotEmpty ?? false) 'cookies': cookies!.trim(),
        if (headers != null && headers.isNotEmpty) 'headers': headers,
        if (windowEffectPayload != null) 'window_effect': windowEffectPayload,
        if (previewStage != null)
          'debug_preview': <String, dynamic>{'stage': previewStage.name},
      };

      if (guardNativeEffect) {
        await _setPopupEffectCrashGuard(true);
      }

      final result = await platform.invokeMethod<bool>(
        'showPopupWindow',
        {
          'payload': jsonEncode(payload),
          'title': windowTitle,
          if (windowEffectPayload != null) 'windowEffect': windowEffectPayload,
        },
      );

      final success = result == true;
      if (guardNativeEffect) {
        if (success) {
          unawaited(_clearPopupEffectCrashGuardAfterLaunch());
        } else {
          unawaited(_setPopupEffectCrashGuard(false));
        }
      }
      if (!success) {
        _logger.warning('Runner declined popup window request');
      }
      return success;
    } catch (e) {
      unawaited(_setPopupEffectCrashGuard(false));
      _logger.error('Failed to open native popup window: $e');
      return false;
    }
  }

  static bool _shouldGuardNativeEffect(Map<String, dynamic>? payload) {
    if (!Platform.isWindows || payload == null) {
      return false;
    }
    if (payload['enabled'] != true) {
      return false;
    }
    final mode = payload['mode']?.toString();
    return mode == 'acrylic' || mode == 'blur';
  }

  static Future<void> _setPopupEffectCrashGuard(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      WindowEffectService.popupEffectCrashGuardPreferenceKey,
      value,
    );
  }

  static Future<void> _clearPopupEffectCrashGuardAfterLaunch() async {
    await Future<void>.delayed(_popupEffectCrashGuardWindow);
    await _setPopupEffectCrashGuard(false);
  }

  static Future<Map<String, dynamic>?> _currentWindowEffectPayload() async {
    final context = navigatorKey.currentContext;

    if (context != null && context.mounted) {
      try {
        final effect = Provider.of<WindowEffectService>(context, listen: false);
        final config = Provider.of<ClientConfigService>(context, listen: false);
        final popupMode = config.getPopupWindowEffectMode();
        final resolvedMode = _resolvePopupEffectMode(
          popupMode: popupMode,
          mainEffectMode: effect.effectMode,
          mainEffectEnabled: effect.effectEnabled,
          windowsBuildNumber: effect.windowsBuildNumber,
        );
        final effectEnabled = resolvedMode != 'none';
        return <String, dynamic>{
          'enabled': effectEnabled,
          'mode': resolvedMode,
          'alpha': effectEnabled ? effect.alpha : 255,
          'is_windows11': effect.isWindows11,
          'windows_build_number': effect.windowsBuildNumber,
          'rounded_corners_enabled': effect.roundedCornersEnabled,
          'corner_radius': effect.windowCornerRadius.round(),
          'dark_mode': effect.darkMode,
          'drag_suspend': effect.dragSuspend,
        };
      } catch (e) {
        _logger.warning('Unable to snapshot window effect from context: $e');
      }
    }

    try {
      final config = ClientConfigService();
      final popupMode = config.getPopupWindowEffectMode();
      if (popupMode == ClientConfigService.popupWindowEffectFollowMain) {
        return null;
      }
      final windowsBuildNumber = await _detectWindowsBuildNumber();
      final resolvedMode = _resolvePopupEffectMode(
        popupMode: popupMode,
        mainEffectMode: 'none',
        mainEffectEnabled: false,
        windowsBuildNumber: windowsBuildNumber,
      );
      final effectEnabled = resolvedMode != 'none';
      final darkMode =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
      final isWindows11 = windowsBuildNumber >= 22000;
      return <String, dynamic>{
        'enabled': effectEnabled,
        'mode': resolvedMode,
        'alpha': effectEnabled ? config.getWindowEffectAlpha() : 255,
        'is_windows11': isWindows11,
        'windows_build_number': windowsBuildNumber,
        'rounded_corners_enabled': true,
        'corner_radius': isWindows11 ? 8 : 6,
        'dark_mode': darkMode,
        'drag_suspend': true,
      };
    } catch (e) {
      _logger.warning('Unable to snapshot window effect from config: $e');
    }
    return null;
  }

  static Future<int> _detectWindowsBuildNumber() async {
    if (!Platform.isWindows) return 0;
    try {
      final result = await Process.run('cmd', ['/c', 'ver']);
      final match =
          RegExp(r'10\.0\.(\d+)').firstMatch(result.stdout.toString());
      return int.tryParse(match?.group(1) ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static String _resolvePopupEffectMode({
    required String popupMode,
    required String mainEffectMode,
    required bool mainEffectEnabled,
    required int windowsBuildNumber,
  }) {
    final isWindows11 = windowsBuildNumber >= 22000;
    final supportsSystemBackdrop = windowsBuildNumber >= 22621;
    final normalized =
        ClientConfigService.normalizePopupWindowEffectMode(popupMode);
    if (normalized == ClientConfigService.popupWindowEffectFollowMain) {
      return mainEffectEnabled ? mainEffectMode : 'none';
    }
    if (normalized == ClientConfigService.popupWindowEffectSolid) {
      return 'none';
    }
    if (!isWindows11 &&
        (normalized == ClientConfigService.popupWindowEffectMicaMain ||
            normalized == ClientConfigService.popupWindowEffectMicaTransient)) {
      return 'none';
    }
    if (isWindows11 &&
        !supportsSystemBackdrop &&
        normalized == ClientConfigService.popupWindowEffectMicaTransient) {
      return 'mica_main';
    }
    if (isWindows11 &&
        normalized == ClientConfigService.popupWindowEffectBlur) {
      return 'mica_main';
    }
    return normalized;
  }

  // 显示弹窗下载对话框（旧方式，需要拉起主窗口）
  static Future<void> showPopupDownload(
    BuildContext context, {
    required String url,
    String? suggestedFilename,
    String? referer,
    String? userAgent,
    String? cookies,
    Map<String, dynamic>? headers,
    bool isFromBrowser = false,
  }) async {
    _logger.info('Popup request: url=$url, filename=$suggestedFilename');
    await showAndBringToFront();
    await flashWindow();

    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

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
          cookies: cookies,
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
      windowManager.restore();
      _logger.debug('Show window');
      windowManager.show();

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
      await platform
          .invokeMethod('setAlwaysOnTop', {'alwaysOnTop': alwaysOnTop});
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
