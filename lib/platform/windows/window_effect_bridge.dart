import 'package:flutter/services.dart';

enum WindowsWindowEffectMode {
  none('none'),
  blur('blur'),
  acrylic('acrylic'),
  micaMain('mica_main'),
  micaAlt('mica_transient');

  const WindowsWindowEffectMode(this.nativeName);

  final String nativeName;

  static WindowsWindowEffectMode fromName(String value) {
    return switch (value) {
      'none' => WindowsWindowEffectMode.none,
      'blur' => WindowsWindowEffectMode.blur,
      'acrylic' => WindowsWindowEffectMode.acrylic,
      'mica_main' => WindowsWindowEffectMode.micaMain,
      'mica_transient' => WindowsWindowEffectMode.micaAlt,
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
    this.force = false,
  });

  final WindowsWindowEffectMode mode;
  final int alpha;
  final bool roundedCornersEnabled;
  final int cornerRadius;
  final bool darkMode;
  final bool force;

  Map<String, Object> toNativeArguments() {
    return <String, Object>{
      'mode': mode.nativeName,
      'alpha': alpha.clamp(0, 255),
      'roundedCornersEnabled': roundedCornersEnabled,
      'cornerRadius': cornerRadius.clamp(0, 32),
      'darkMode': darkMode,
      'force': force,
    };
  }
}

class WindowsWindowCapabilities {
  const WindowsWindowCapabilities({
    required this.windowsBuild,
    required this.isWindows11,
    required this.supportsSystemBackdrop,
    required this.compositionEnabled,
    required this.transparencyEnabled,
    required this.highContrast,
  });

  factory WindowsWindowCapabilities.fromMap(Map<Object?, Object?> map) {
    return WindowsWindowCapabilities(
      windowsBuild: (map['windowsBuild'] as num?)?.toInt() ?? 0,
      isWindows11: map['isWindows11'] == true,
      supportsSystemBackdrop: map['supportsSystemBackdrop'] == true,
      compositionEnabled: map['compositionEnabled'] == true,
      transparencyEnabled: map['transparencyEnabled'] == true,
      highContrast: map['highContrast'] == true,
    );
  }

  final int windowsBuild;
  final bool isWindows11;
  final bool supportsSystemBackdrop;
  final bool compositionEnabled;
  final bool transparencyEnabled;
  final bool highContrast;
}

class WindowsWindowEffectResult {
  const WindowsWindowEffectResult({
    required this.requestedMode,
    required this.appliedMode,
    required this.usedFallback,
    required this.hresult,
    required this.windowsBuild,
    required this.transparencyEnabled,
  });

  factory WindowsWindowEffectResult.fromMap(Map<Object?, Object?> map) {
    return WindowsWindowEffectResult(
      requestedMode: WindowsWindowEffectMode.fromName(
        map['requestedMode']?.toString() ?? 'none',
      ),
      appliedMode: WindowsWindowEffectMode.fromName(
        map['appliedMode']?.toString() ?? 'none',
      ),
      usedFallback: map['usedFallback'] == true,
      hresult: (map['hresult'] as num?)?.toInt() ?? 0,
      windowsBuild: (map['windowsBuild'] as num?)?.toInt() ?? 0,
      transparencyEnabled: map['transparencyEnabled'] == true,
    );
  }

  final WindowsWindowEffectMode requestedMode;
  final WindowsWindowEffectMode appliedMode;
  final bool usedFallback;
  final int hresult;
  final int windowsBuild;
  final bool transparencyEnabled;

  bool get succeeded => hresult >= 0;
}

class WindowsWindowEffectBridge {
  const WindowsWindowEffectBridge({
    MethodChannel channel = const MethodChannel('com.hanabi.download/window'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<WindowsWindowCapabilities> getCapabilities() async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getWindowCapabilities',
    );
    return WindowsWindowCapabilities.fromMap(result ?? const {});
  }

  Future<WindowsWindowEffectResult> applyEffect(
    WindowsWindowEffectRequest request,
  ) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'setWindowEffect',
      request.toNativeArguments(),
    );
    return WindowsWindowEffectResult.fromMap(result ?? const {});
  }

  Future<void> setDragSuspend(bool enabled) {
    return _channel.invokeMethod<void>('setDragSuspend', <String, Object>{
      'enabled': enabled,
    });
  }
}
