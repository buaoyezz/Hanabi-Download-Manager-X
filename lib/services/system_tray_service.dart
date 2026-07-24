import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:win32/win32.dart' as win32;
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;

import 'logger_service.dart';
import 'client_config_service.dart';
import 'kernel/kernel_manager.dart';

class SystemTrayService with TrayListener {
  static const MethodChannel _windowChannel =
      MethodChannel('com.hanabi.download/window');
  bool _isInitialized = false;
  bool _isExiting = false;
  Timer? _trayMenuPrewarmTimer;
  Future<void>? _trayMenuPreparation;
  Future<void>? _trayMenuRequest;
  DateTime? _lastTrayMenuRequestAt;
  String? _lastTooltip;
  Future<bool> Function()? onExitRequested;
  Future<void> Function()? onBeforeExit;
  void Function(bool isVisible)? onMainWindowVisibilityChanged;
  List<Map<String, dynamic>> Function()? activeTaskPayloadProvider;
  final _logger = LoggerService();

  Future<void> initialize({
    bool showWindow = true,
  }) async {
    if (_isInitialized) return;

    try {
      final iconPath = await _getIconPath();
      _logger
          .info('System tray init, iconPath=$iconPath, showWindow=$showWindow');

      await trayManager.setIcon(iconPath);
      await trayManager.setToolTip("Hanabi Download ManagerX");
      _lastTooltip = "Hanabi Download ManagerX";
      trayManager.addListener(this);

      _isInitialized = true;
      _logger.info('System tray initialized with custom Fluent menu');

      if (showWindow) {
        await showMainWindow();
      } else {
        updateToolTip(false);
      }
      _scheduleTrayMenuPrewarm();
    } catch (e) {
      _logger.error('System tray init failed: $e');
    }
  }

  Future<void> _showCustomTrayMenu() async {
    if (!_isInitialized || _isExiting) {
      return;
    }
    final pendingRequest = _trayMenuRequest;
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _performShowCustomTrayMenu();
    _trayMenuRequest = request;
    try {
      await request;
    } finally {
      if (identical(_trayMenuRequest, request)) {
        _trayMenuRequest = null;
      }
    }
  }

  Future<void> _performShowCustomTrayMenu() async {
    try {
      final preparation = _trayMenuPreparation;
      if (preparation != null) {
        await preparation;
      }
      final cursorPos = await _getCursorPos();

      await _windowChannel.invokeMethod<bool>(
        'showTrayMenu',
        {
          'payload': jsonEncode(
            _buildTrayMenuPayload(cursorPos, showOnReady: true),
          ),
          'title': 'Hanabi Tray Menu',
        },
      );
    } catch (e) {
      _logger.warning('Failed to show custom tray menu: $e');
    }
  }

  void _scheduleTrayMenuPrewarm() {
    if (!Platform.isWindows || !_isInitialized || _isExiting) {
      return;
    }
    _trayMenuPrewarmTimer?.cancel();
    _trayMenuPrewarmTimer = Timer(const Duration(milliseconds: 500), () {
      _trayMenuPrewarmTimer = null;
      _trayMenuPreparation ??= _prepareCustomTrayMenu();
    });
  }

  Future<void> _prepareCustomTrayMenu() async {
    try {
      await _windowChannel.invokeMethod<bool>(
        'prepareTrayMenu',
        {
          'payload': jsonEncode(
            _buildTrayMenuPayload(
              const {'x': 0.0, 'y': 0.0},
              showOnReady: false,
            ),
          ),
          'title': 'Hanabi Tray Menu',
        },
      );
      _logger.info('Custom tray menu prewarmed');
    } catch (e) {
      _logger.warning('Failed to prewarm custom tray menu: $e');
    }
  }

  Map<String, dynamic> _buildTrayMenuPayload(
    Map<String, double> cursorPos, {
    required bool showOnReady,
  }) {
    final localeTag =
        WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
    List<Map<String, dynamic>> activeTasks = const <Map<String, dynamic>>[];
    try {
      activeTasks = activeTaskPayloadProvider?.call() ?? activeTasks;
    } catch (e) {
      _logger.warning('Failed to build tray active task payload: $e');
    }

    final clientConfig = ClientConfigService();
    final themeMode = clientConfig.getThemeMode();
    final classicControlVisuals = clientConfig.getClassicControlVisuals();

    return <String, dynamic>{
      'locale': localeTag,
      'mouse_x': cursorPos['x'] ?? 0.0,
      'mouse_y': cursorPos['y'] ?? 0.0,
      'show_on_ready': showOnReady,
      'theme_mode': themeMode,
      'classic_control_visuals': classicControlVisuals,
      'active_tasks': activeTasks,
    };
  }

  Future<Map<String, double>> _getCursorPos() async {
    try {
      final result = await _windowChannel.invokeMethod<Map>('getCursorPos');
      if (result != null) {
        return {
          'x': (result['x'] ?? 0).toDouble(),
          'y': (result['y'] ?? 0).toDouble(),
        };
      }
    } catch (e) {
      _logger.warning('Failed to get cursor pos via method channel: $e');
    }

    if (Platform.isWindows) {
      final point = calloc.allocate<win32.POINT>(1);
      try {
        if (win32.GetCursorPos(point).value) {
          return {
            'x': point.ref.x.toDouble(),
            'y': point.ref.y.toDouble(),
          };
        }
      } finally {
        calloc.free(point);
      }
    }

    return {'x': 0.0, 'y': 0.0};
  }

  void updateToolTip(bool isVisible) {
    final config = ClientConfigService();
    final showStatus = config.getShowTrayRunningStatus();

    String tooltip = "Hanabi Download ManagerX";
    if (showStatus && !isVisible) {
      tooltip += " - 正在后台运行";
    }

    unawaited(_setToolTipIfChanged(tooltip));
  }

  Future<void> _setToolTipIfChanged(String tooltip) async {
    if (!_isInitialized || _lastTooltip == tooltip) {
      return;
    }
    final previous = _lastTooltip;
    _lastTooltip = tooltip;
    try {
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      _lastTooltip = previous;
      _logger.warning('Failed to update system tray tooltip: $e');
    }
  }

  Future<String> _getIconPath() async {
    if (Platform.isWindows) {
      final exePath = Platform.resolvedExecutable;
      final exeDir = path.dirname(exePath);

      final possiblePaths = [
        path.join(
            exeDir, 'data', 'flutter_assets', 'assets', 'logo', 'logo.ico'),
        path.join(Directory.current.path, 'assets', 'logo', 'logo.ico'),
      ];

      for (final iconPath in possiblePaths) {
        if (await File(iconPath).exists()) {
          return iconPath;
        }
      }
    }

    return '';
  }

  Future<void> showMainWindow() async {
    _logger.info('Show main window');
    try {
      if (Platform.isWindows) {
        await _windowChannel.invokeMethod<void>('bringToFront');
      } else {
        if (await windowManager.isMinimized()) {
          await windowManager.restore();
        }
        await windowManager.show();
        await windowManager.focus();
      }
      updateToolTip(true);
      onMainWindowVisibilityChanged?.call(true);
    } catch (e) {
      _logger.warning('Native window restore failed, using fallback: $e');
      try {
        if (await windowManager.isMinimized()) {
          await windowManager.restore();
        }
        await windowManager.show();
        await windowManager.focus();
        updateToolTip(true);
        onMainWindowVisibilityChanged?.call(true);
      } catch (fallbackError) {
        _logger.error('Failed to show main window: $fallbackError');
      }
    }
  }

  void hideMainWindow() {
    _logger.info('Hide main window to tray');
    windowManager.hide();
    updateToolTip(false);
    onMainWindowVisibilityChanged?.call(false);
  }

  Future<bool> _requestNativeQuit() async {
    if (!Platform.isWindows) return false;

    try {
      final result = await _windowChannel.invokeMethod<bool>('quitApplication');
      return result ?? false;
    } catch (e) {
      _logger.warning('Native quit request failed: $e');
      return false;
    }
  }

  Future<void> requestExit() async {
    if (_isExiting) {
      _logger.info('Exit already in progress, ignoring duplicate request');
      return;
    }

    var shouldExit = true;
    final exitHandler = onExitRequested;
    if (exitHandler != null) {
      try {
        shouldExit = await exitHandler();
      } catch (e) {
        _logger.warning('Exit confirmation handler failed: $e');
      }
    }

    if (!shouldExit) {
      _logger.info('Exit request cancelled');
      return;
    }

    await exitApp();
  }

  Future<void> exitApp() async {
    if (_isExiting) {
      _logger.info('Exit already in progress, ignoring duplicate request');
      return;
    }
    _isExiting = true;

    _logger.info('Exit app from tray - beginning shutdown sequence...');

    if (Platform.isWindows) {
      try {
        await _windowChannel.invokeMethod<bool>('beginApplicationExit');
      } catch (e) {
        _logger.warning('Failed to mark native window as exiting: $e');
      }
    }

    final beforeExit = onBeforeExit;
    if (beforeExit != null) {
      try {
        await beforeExit();
      } catch (e) {
        _logger.warning('Pre-exit persistence failed: $e');
      }
    }

    try {
      // 先销毁托盘图标，避免用户误以为应用只是退到后台。
      await trayManager.destroy();
      _isInitialized = false;
    } catch (e) {
      _logger.warning('Failed to destroy system tray during exit: $e');
    }

    try {
      await KernelManager().stop().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          _logger.warning('Kernel stop timed out, forcing app exit');
        },
      );
    } catch (e) {
      _logger.warning('Kernel stop failed during exit: $e');
    }

    _logger.info('Shutdown sequence finished, closing window...');

    final nativeQuitRequested = await _requestNativeQuit();
    if (!nativeQuitRequested) {
      try {
        windowManager.close();
      } catch (e) {
        _logger.warning('Window close failed during exit: $e');
      }
    }

    // 作为最后一道兜底，若原生关闭请求未生效，仍尝试直接结束 Dart 进程。
    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(showMainWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    final now = DateTime.now();
    final lastRequest = _lastTrayMenuRequestAt;
    if (lastRequest != null &&
        now.difference(lastRequest) < const Duration(milliseconds: 120)) {
      return;
    }
    _lastTrayMenuRequestAt = now;
    unawaited(_showCustomTrayMenu());
  }

  void dispose() {
    _trayMenuPrewarmTimer?.cancel();
    _trayMenuPrewarmTimer = null;
    trayManager.removeListener(this);
    unawaited(trayManager.destroy());
    _isInitialized = false;
    _lastTooltip = null;
    onBeforeExit = null;
    onMainWindowVisibilityChanged = null;
    activeTaskPayloadProvider = null;
  }
}
