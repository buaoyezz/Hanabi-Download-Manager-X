import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:path/path.dart' as path;
import 'logger_service.dart';

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  bool _isInitialized = false;
  final _logger = LoggerService();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final iconPath = await _getIconPath();
      _logger.info('System tray init, iconPath=$iconPath');
      
      await _systemTray.initSystemTray(
        title: "Hanabi Download ManagerX",
        iconPath: iconPath,
        toolTip: "Hanabi Download ManagerX - Running in background",
      );

      await _menu.buildFrom([
        MenuItemLabel(
          label: 'Show Window',
          onClicked: (menuItem) => showMainWindow(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Exit',
          onClicked: (menuItem) => exitApp(),
        ),
      ]);

      await _systemTray.setContextMenu(_menu);

      _systemTray.registerSystemTrayEventHandler((eventName) {
        _logger.debug('Tray event: $eventName');
        if (eventName == kSystemTrayEventClick) {
          showMainWindow();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      _isInitialized = true;
      _logger.info('System tray initialized');
    } catch (e) {
      _logger.error('System tray init failed: $e');
    }
  }

  Future<String> _getIconPath() async {
    if (Platform.isWindows) {
      final exePath = Platform.resolvedExecutable;
      final exeDir = path.dirname(exePath);
      
      final possiblePaths = [
        path.join(exeDir, 'data', 'flutter_assets', 'assets', 'logo', 'logo.ico'),
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
  }

  void hideMainWindow() {
    _logger.info('Hide main window to tray');
    appWindow.hide();
  }

  void exitApp() {
    _logger.info('Exit app from tray');
    appWindow.close();
  }

  void dispose() {
    _systemTray.destroy();
  }
}
