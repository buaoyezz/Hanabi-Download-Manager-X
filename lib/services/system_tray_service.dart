import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:system_tray/system_tray.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'logger_service.dart';
import 'client_config_service.dart';
import 'kernel/kernel_manager.dart';

class SystemTrayService {
  static const MethodChannel _windowChannel =
      MethodChannel('com.hanabi.download/window');
  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;
  bool _isExiting = false;
  bool _trayMenuPrewarmed = false;
  Timer? _trayMenuPrewarmTimer;
  Future<bool> Function()? onExitRequested;
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

      await _systemTray.initSystemTray(
        title: "Hanabi Download ManagerX",
        iconPath: iconPath,
        toolTip: "Hanabi Download ManagerX",
      );

      _systemTray.registerSystemTrayEventHandler((eventName) {
        _logger.debug('Tray event: $eventName');
        if (eventName == kSystemTrayEventClick) {
          showMainWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          _showCustomTrayMenu();
        }
      });

      final Menu menu = Menu();
      await menu.buildFrom([]);
      await _systemTray.setContextMenu(menu);
      _scheduleTrayMenuPrewarm();

      _isInitialized = true;
      _logger.info('System tray initialized with custom Fluent menu');

      if (showWindow) {
        showMainWindow();
      } else {
        updateToolTip(false);
      }
    } catch (e) {
      _logger.error('System tray init failed: $e');
    }
  }

  void _scheduleTrayMenuPrewarm() {
    _trayMenuPrewarmTimer?.cancel();
    _trayMenuPrewarmTimer = Timer(const Duration(milliseconds: 450), () {
      if (_isExiting || _trayMenuPrewarmed) {
        return;
      }
      unawaited(_prepareCustomTrayMenu());
    });
  }

  Future<void> _showCustomTrayMenu() async {
    try {
      final cursorPos = await _getCursorPos();

      await _windowChannel.invokeMethod<bool>(
        'showTrayMenu',
        {
          'payload': jsonEncode(_buildTrayMenuPayload(cursorPos)),
          'title': 'Hanabi Tray Menu',
        },
      );
    } catch (e) {
      _logger.warning('Failed to show custom tray menu: $e');
    }
  }

  Future<void> _prepareCustomTrayMenu() async {
    if (_trayMenuPrewarmed || _isExiting) {
      return;
    }
    try {
      final prepared = await _windowChannel.invokeMethod<bool>(
        'prepareTrayMenu',
        {
          'payload': jsonEncode(
            _buildTrayMenuPayload(const {'x': 0.0, 'y': 0.0}),
          ),
          'title': 'Hanabi Tray Menu',
        },
      );
      _trayMenuPrewarmed = prepared ?? true;
    } catch (e) {
      _trayMenuPrewarmed = false;
      _logger.warning('Failed to prewarm custom tray menu: $e');
    }
  }

  Map<String, dynamic> _buildTrayMenuPayload(Map<String, double> cursorPos) {
    final localeTag =
        WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
    List<Map<String, dynamic>> activeTasks = const <Map<String, dynamic>>[];
    try {
      activeTasks = activeTaskPayloadProvider?.call() ?? activeTasks;
    } catch (e) {
      _logger.warning('Failed to build tray active task payload: $e');
    }

    return <String, dynamic>{
      'locale': localeTag,
      'mouse_x': cursorPos['x'] ?? 0.0,
      'mouse_y': cursorPos['y'] ?? 0.0,
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

    try {
      if (Platform.isWindows) {
        final result = await Process.run('powershell', [
          '-Command',
          r'Add-Type -AssemblyName System.Windows.Forms; $pos = [System.Windows.Forms.Cursor]::Position; Write-Output "$($pos.X),$($pos.Y)"'
        ]);
        final output = (result.stdout as String).trim();
        final parts = output.split(',');
        if (parts.length == 2) {
          return {
            'x': double.parse(parts[0]),
            'y': double.parse(parts[1]),
          };
        }
      }
    } catch (e) {
      _logger.warning('Failed to get cursor pos via powershell: $e');
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

    _systemTray.setToolTip(tooltip);
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

  void showMainWindow() {
    _logger.info('Show main window');
    appWindow.show();
    appWindow.restore();
    updateToolTip(true);
  }

  void hideMainWindow() {
    _logger.info('Hide main window to tray');
    appWindow.hide();
    updateToolTip(false);
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
    _trayMenuPrewarmTimer?.cancel();

    _logger.info('Exit app from tray - beginning shutdown sequence...');

    try {
      // 先销毁托盘图标，避免用户误以为应用只是退到后台。
      _systemTray.destroy();
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
        appWindow.close();
      } catch (e) {
        _logger.warning('Window close failed during exit: $e');
      }
    }

    // 作为最后一道兜底，若原生关闭请求未生效，仍尝试直接结束 Dart 进程。
    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  void dispose() {
    _systemTray.destroy();
  }
}
