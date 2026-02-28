import 'dart:io';
import 'dart:ffi';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/foundation.dart' show Uint8List;

class FileIconService {
  static final FileIconService _instance = FileIconService._internal();
  factory FileIconService() => _instance;
  FileIconService._internal();

  final Map<String, Uint8List> _iconCache = {};

  /// 根据文件扩展名获取系统图标
  Future<Uint8List?> getIconByExtension(String extension) async {
    if (!Platform.isWindows) {
      return null;
    }

    final ext = extension.toLowerCase();
    if (ext.isEmpty) return null;

    // 检查缓存
    if (_iconCache.containsKey(ext)) {
      return _iconCache[ext];
    }

    try {
      // 在后台提取图标
      final iconData = await _extractIconByExtension(ext);
      if (iconData != null) {
        _iconCache[ext] = iconData;
      }
      return iconData;
    } catch (e) {
      debugPrint('提取图标失败: $e');
      return null;
    }
  }

  /// 根据文件路径获取系统图标
  Future<Uint8List?> getIconFromFile(String filePath) async {
    if (!Platform.isWindows) {
      return null;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        // 文件不存在，尝试从扩展名获取
        final ext = _getExtension(filePath);
        return await getIconByExtension(ext);
      }

      // 从实际文件提取图标
      return await _extractIconFromFile(filePath);
    } catch (e) {
      debugPrint('从文件提取图标失败: $e');
      return null;
    }
  }

  String _getExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  /// 清除缓存
  void clearCache() {
    _iconCache.clear();
  }

  /// 从扩展名提取图标
  Future<Uint8List?> _extractIconByExtension(String extension) async {
    return _extractIcon('.${extension}');
  }

  /// 从文件路径提取图标
  Future<Uint8List?> _extractIconFromFile(String filePath) async {
    return _extractIcon(filePath);
  }

  /// 提取图标的核心方法
  Future<Uint8List?> _extractIcon(String path) async {
    try {
      final pathPtr = path.toNativeUtf16();
      final shFileInfo = calloc<SHFILEINFO>();

      try {
        // 获取文件信息和图标
        final result = SHGetFileInfo(
          pathPtr,
          FILE_ATTRIBUTE_NORMAL,
          shFileInfo,
          sizeOf<SHFILEINFO>(),
          SHGFI_ICON | SHGFI_LARGEICON | SHGFI_USEFILEATTRIBUTES,
        );

        if (result == 0) {
          return null;
        }

        final hIcon = shFileInfo.ref.hIcon;
        if (hIcon == 0) {
          return null;
        }

        // 获取图标信息
        final iconInfo = calloc<ICONINFO>();
        if (GetIconInfo(hIcon, iconInfo) == 0) {
          DestroyIcon(hIcon);
          return null;
        }

        // 获取位图句柄
        final hBitmap = iconInfo.ref.hbmColor;
        if (hBitmap == 0) {
          if (iconInfo.ref.hbmMask != 0) {
            DeleteObject(iconInfo.ref.hbmMask);
          }
          DestroyIcon(hIcon);
          calloc.free(iconInfo);
          return null;
        }

        // 获取位图信息
        final bitmap = calloc<BITMAP>();
        if (GetObject(hBitmap, sizeOf<BITMAP>(), bitmap) == 0) {
          if (iconInfo.ref.hbmColor != 0) DeleteObject(iconInfo.ref.hbmColor);
          if (iconInfo.ref.hbmMask != 0) DeleteObject(iconInfo.ref.hbmMask);
          DestroyIcon(hIcon);
          calloc.free(iconInfo);
          calloc.free(bitmap);
          return null;
        }

        final width = bitmap.ref.bmWidth;
        final height = bitmap.ref.bmHeight;

        if (width <= 0 || height <= 0) {
          if (iconInfo.ref.hbmColor != 0) DeleteObject(iconInfo.ref.hbmColor);
          if (iconInfo.ref.hbmMask != 0) DeleteObject(iconInfo.ref.hbmMask);
          DestroyIcon(hIcon);
          calloc.free(iconInfo);
          calloc.free(bitmap);
          return null;
        }

        // 创建设备上下文
        final hdcScreen = GetDC(NULL);
        final hdcMem = CreateCompatibleDC(hdcScreen);

        // 创建 DIB Section
        final bmi = calloc<BITMAPINFO>();
        bmi.ref.bmiHeader.biSize = sizeOf<BITMAPINFOHEADER>();
        bmi.ref.bmiHeader.biWidth = width;
        bmi.ref.bmiHeader.biHeight = -height; // 负值表示自顶向下
        bmi.ref.bmiHeader.biPlanes = 1;
        bmi.ref.bmiHeader.biBitCount = 32;
        bmi.ref.bmiHeader.biCompression = BI_RGB;

        final ppvBits = calloc<Pointer<Uint32>>();
        final hDib = CreateDIBSection(
          hdcMem,
          bmi,
          DIB_RGB_COLORS,
          ppvBits.cast(),
          NULL,
          0,
        );

        if (hDib == 0) {
          ReleaseDC(NULL, hdcScreen);
          DeleteDC(hdcMem);
          if (iconInfo.ref.hbmColor != 0) DeleteObject(iconInfo.ref.hbmColor);
          if (iconInfo.ref.hbmMask != 0) DeleteObject(iconInfo.ref.hbmMask);
          DestroyIcon(hIcon);
          calloc.free(bmi);
          calloc.free(ppvBits);
          calloc.free(iconInfo);
          calloc.free(bitmap);
          return null;
        }

        final hOldBitmap = SelectObject(hdcMem, hDib);

        // 绘制图标到 DIB
        DrawIcon(hdcMem, 0, 0, hIcon);

        // 读取像素数据
        final pixelCount = width * height;
        final pixelData = Uint8List(pixelCount * 4);

        final pixels = ppvBits.value;
        for (var i = 0; i < pixelCount; i++) {
          final pixel = pixels[i];
          final offset = i * 4;
          // BGRA -> RGBA
          pixelData[offset + 0] = (pixel >> 16) & 0xFF; // R
          pixelData[offset + 1] = (pixel >> 8) & 0xFF;  // G
          pixelData[offset + 2] = pixel & 0xFF;         // B
          pixelData[offset + 3] = (pixel >> 24) & 0xFF; // A
        }

        // 清理资源
        SelectObject(hdcMem, hOldBitmap);
        DeleteObject(hDib);
        DeleteDC(hdcMem);
        ReleaseDC(NULL, hdcScreen);
        if (iconInfo.ref.hbmColor != 0) DeleteObject(iconInfo.ref.hbmColor);
        if (iconInfo.ref.hbmMask != 0) DeleteObject(iconInfo.ref.hbmMask);
        DestroyIcon(hIcon);
        calloc.free(bmi);
        calloc.free(ppvBits);
        calloc.free(iconInfo);
        calloc.free(bitmap);

        // 将 RGBA 数据编码为 PNG
        return _encodeToPng(pixelData, width, height);
      } finally {
        calloc.free(pathPtr);
        calloc.free(shFileInfo);
      }
    } catch (e) {
      debugPrint('提取图标异常: $e');
      return null;
    }
  }

  /// 将 RGBA 数据编码为 PNG
  Future<Uint8List?> _encodeToPng(Uint8List rgba, int width, int height) async {
    try {
      // 使用 Flutter 的 ui.decodeImageFromPixels 来创建图像
      final completer = Completer<ui.Image>();
      
      ui.decodeImageFromPixels(
        rgba,
        width,
        height,
        ui.PixelFormat.rgba8888,
        (ui.Image image) {
          completer.complete(image);
        },
      );
      
      final image = await completer.future;
      
      // 将图像编码为 PNG
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
      
      return null;
    } catch (e) {
      debugPrint('编码 PNG 失败: $e');
      return null;
    }
  }

  void debugPrint(String message) {
    if (Platform.isWindows) {
      print('[FileIconService] $message');
    }
  }
}
