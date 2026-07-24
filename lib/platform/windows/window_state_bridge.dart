import 'package:flutter/services.dart';

class WindowsWindowPlacement {
  const WindowsWindowPlacement({
    required this.normalSize,
    required this.isMaximized,
    required this.isMinimized,
    required this.isVisible,
  });

  factory WindowsWindowPlacement.fromMap(Map<Object?, Object?> value) {
    double readDimension(String key) {
      final raw = value[key];
      if (raw is num) {
        return raw.toDouble();
      }
      throw FormatException('Missing numeric window placement field: $key');
    }

    bool readFlag(String key) => value[key] == true;

    return WindowsWindowPlacement(
      normalSize: Size(
        readDimension('normalWidth'),
        readDimension('normalHeight'),
      ),
      isMaximized: readFlag('isMaximized'),
      isMinimized: readFlag('isMinimized'),
      isVisible: readFlag('isVisible'),
    );
  }

  final Size normalSize;
  final bool isMaximized;
  final bool isMinimized;
  final bool isVisible;
}

class WindowsWindowStateBridge {
  const WindowsWindowStateBridge({
    MethodChannel channel = const MethodChannel('com.hanabi.download/window'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<WindowsWindowPlacement> getPlacement() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getWindowPlacement',
    );
    if (result == null) {
      throw const FormatException('Native window placement was empty');
    }
    return WindowsWindowPlacement.fromMap(result);
  }
}
