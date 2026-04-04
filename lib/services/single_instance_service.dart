import 'dart:io';

import 'package:flutter/services.dart';

class SingleInstanceService {
  static const MethodChannel _platform =
      MethodChannel('com.hanabi.download/window');

  static Future<bool> hasStartupConflict() async {
    if (!Platform.isWindows) return false;

    final result = await _platform
        .invokeMapMethod<String, dynamic>('getStartupConflictState');
    return result?['hasExistingInstance'] == true;
  }

  static Future<bool> focusExistingInstance() async {
    if (!Platform.isWindows) return false;

    final focused = await _platform.invokeMethod<bool>('focusExistingInstance');
    return focused ?? false;
  }

  static Future<bool> closeExistingInstanceAndAcquireLock() async {
    if (!Platform.isWindows) return true;

    final closed = await _platform
        .invokeMethod<bool>('closeExistingInstanceAndAcquireLock');
    return closed ?? false;
  }
}
