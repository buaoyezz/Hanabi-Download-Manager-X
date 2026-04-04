import 'dart:io';
import 'package:system_tray/system_tray.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/services.dart';
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
  Future<bool> Function()? onExitRequested;
  final _logger = LoggerService();

  Future<void> initialize({
    bool showWindow = true, // 是否在初始化后显示窗口
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

      // 注册托盘事件处理器
      _systemTray.registerSystemTrayEventHandler((eventName) {
        _logger.debug('Tray event: $eventName');
        if (eventName == kSystemTrayEventClick) {
          showMainWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      // 初始化系统菜单
      final Menu menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: '显示主界面',
          onClicked: (menuItem) => showMainWindow(),
        ),
        MenuItemLabel(
          label: '退出',
          onClicked: (menuItem) => requestExit(),
        ),
      ]);
      await _systemTray.setContextMenu(menu);

      _isInitialized = true;
      _logger.info('System tray initialized with native menu');

      // 根据参数决定是否显示窗口
      if (showWindow) {
        showMainWindow();
      } else {
        updateToolTip(false);
      }
    } catch (e) {
      _logger.error('System tray init failed: $e');
    }
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
    final config = ClientConfigService();
    final shouldMaximize = appWindow.isMaximized || config.getWindowMaximized();

    _logger.info('Show main window, shouldMaximize=$shouldMaximize');
    appWindow.show();
    if (shouldMaximize) {
      appWindow.maximize();
    } else {
      appWindow.restore();
    }
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
