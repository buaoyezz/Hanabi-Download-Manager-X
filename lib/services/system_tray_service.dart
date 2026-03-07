import 'dart:io';
import 'package:system_tray/system_tray.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:path/path.dart' as path;
import 'logger_service.dart';
import 'client_config_service.dart';
import 'kernel/kernel_manager.dart';

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;
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
          onClicked: (menuItem) => exitApp(),
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
    _logger.info('Show main window');
    appWindow.restore();
    appWindow.show();
    updateToolTip(true);
  }

  void hideMainWindow() {
    _logger.info('Hide main window to tray');
    appWindow.hide();
    updateToolTip(false);
  }

  Future<void> exitApp() async {
    _logger.info('Exit app from tray - cleaning up kernel...');

    await KernelManager().stop();

    _logger.info('Kernel cleaned up, closing window...');
    appWindow.close();

    // 强制退出进程
    await Future.delayed(const Duration(milliseconds: 500));
    exit(0);
  }

  void dispose() {
    _systemTray.destroy();
  }
}
