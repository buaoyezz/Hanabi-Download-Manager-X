import 'package:flutter/services.dart';

enum WindowsWindowEffectMode {
  none('none'),
  blur('blur'),
  acrylic('acrylic'),
  micaMain('mica_main'),
  micaTransient('mica_transient');

  const WindowsWindowEffectMode(this.nativeName);

  final String nativeName;

  static WindowsWindowEffectMode fromName(String value) {
    return switch (value) {
      'none' => WindowsWindowEffectMode.none,
      'blur' => WindowsWindowEffectMode.blur,
      'acrylic' => WindowsWindowEffectMode.acrylic,
      'mica_main' => WindowsWindowEffectMode.micaMain,
      'mica_transient' => WindowsWindowEffectMode.micaTransient,
      _ => WindowsWindowEffectMode.none,
    };
  }
}

class WindowsWindowEffectRequest {
  const WindowsWindowEffectRequest({
    required this.mode,
    required this.alpha,
    required this.roundedCornersEnabled,
    required this.cornerRadius,
    required this.darkMode,
  });

  final WindowsWindowEffectMode mode;
  final int alpha;
  final bool roundedCornersEnabled;
  final int cornerRadius;
  final bool darkMode;

  Map<String, Object> toNativeArguments() {
    return <String, Object>{
      'mode': mode.nativeName,
      'alpha': alpha.clamp(0, 255),
      'roundedCornersEnabled': roundedCornersEnabled,
      'cornerRadius': cornerRadius.clamp(0, 32),
      'darkMode': darkMode,
    };
  }
}

class WindowsWindowEffectBridge {
  const WindowsWindowEffectBridge({
    MethodChannel channel = const MethodChannel('com.hanabi.download/window'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<void> applyEffect(WindowsWindowEffectRequest request) {
    return _channel.invokeMethod<void>(
      'setWindowEffect',
      request.toNativeArguments(),
    );
  }

  Future<void> setDragSuspend(bool enabled) {
    return _channel.invokeMethod<void>('setDragSuspend', <String, Object>{
      'enabled': enabled,
    });
  }
}
