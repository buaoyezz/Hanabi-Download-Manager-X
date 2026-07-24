import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../platform/windows/window_state_bridge.dart';
import 'app_logger_service.dart';
import 'client_config_service.dart';

final windowSizePersistenceService = WindowSizePersistenceService();

class WindowSizePersistenceService {
  WindowSizePersistenceService({
    WindowsWindowStateBridge bridge = const WindowsWindowStateBridge(),
  }) : _bridge = bridge;

  final WindowsWindowStateBridge _bridge;
  Future<void> _saveTail = Future<void>.value();

  Future<void> save(ClientConfigService config) {
    final operation = _saveTail.then((_) => _saveNow(config));
    _saveTail = operation.catchError((Object error, StackTrace stackTrace) {
      AppLoggerService().error(
        'App',
        'Window size persistence failed: $error\n$stackTrace',
      );
    });
    return operation;
  }

  Future<void> _saveNow(ClientConfigService config) async {
    if (!config.getWindowRememberSize()) {
      return;
    }

    try {
      final size = await _readNormalWindowSize();
      if (size == null || !_isValidSize(size)) {
        if (size != null) {
          AppLoggerService().warning(
            'App',
            'Invalid normal window size: '
                '${size.width.toInt()}x${size.height.toInt()}',
          );
        }
        return;
      }

      if ((size.width - config.getWindowWidth()).abs() <= 1 &&
          (size.height - config.getWindowHeight()).abs() <= 1) {
        return;
      }

      await config.setWindowSize(size.width, size.height);
      AppLoggerService().debug(
        'App',
        'Normal window size saved: '
            '${size.width.toInt()}x${size.height.toInt()}',
      );
    } catch (error, stackTrace) {
      AppLoggerService().error(
        'App',
        'Failed to save normal window size: $error\n$stackTrace',
      );
    }
  }

  Future<Size?> _readNormalWindowSize() async {
    if (Platform.isWindows) {
      try {
        return (await _bridge.getPlacement()).normalSize;
      } on MissingPluginException {
        // Supports older/custom runners during development.
      } on PlatformException {
        // Fall back to window_manager if the native query is unavailable.
      }
    }

    final transientBefore = await _isTransientWindowState();
    if (transientBefore) {
      return null;
    }
    final size = await windowManager.getSize();
    final transientAfter = await _isTransientWindowState();
    return transientAfter ? null : size;
  }

  Future<bool> _isTransientWindowState() async {
    return await windowManager.isMaximized() ||
        await windowManager.isMinimized() ||
        await windowManager.isFullScreen();
  }

  bool _isValidSize(Size size) {
    return size.width >= 600 &&
        size.height >= 400 &&
        size.width <= 4096 &&
        size.height <= 2160;
  }
}
