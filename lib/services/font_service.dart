import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FontService extends ChangeNotifier {
  String _selectedFont = 'system';
  Map<String, String> _customFonts = {}; // fontName -> fontPath
  
  String get selectedFont => _selectedFont;
  Map<String, String> get customFonts => Map.unmodifiable(_customFonts);
  
  Future<void> loadFont() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedFont = prefs.getString('app_font') ?? 'system';
      
      // 加载自定义字体列表
      final customFontsJson = prefs.getStringList('custom_fonts') ?? [];
      _customFonts = {};
      for (final entry in customFontsJson) {
        final parts = entry.split('|');
        if (parts.length == 2) {
          _customFonts[parts[0]] = parts[1];
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading font: $e');
    }
  }
  
  Future<void> setFont(String font) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_font', font);
      _selectedFont = font;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving font: $e');
    }
  }
  
  Future<bool> addCustomFont(String fontPath) async {
    try {
      final file = File(fontPath);
      if (!await file.exists()) {
        return false;
      }
      
      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final fontsDir = Directory(path.join(appDir.path, 'hanabi_fonts'));
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }
      
      // 复制字体文件到应用目录
      final fileName = path.basename(fontPath);
      final targetPath = path.join(fontsDir.path, fileName);
      await file.copy(targetPath);
      
      // 提取字体名称（去掉扩展名）
      final fontName = path.basenameWithoutExtension(fileName);
      
      // 保存到自定义字体列表
      _customFonts[fontName] = targetPath;
      await _saveCustomFonts();
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding custom font: $e');
      return false;
    }
  }
  
  Future<bool> removeCustomFont(String fontName) async {
    try {
      if (!_customFonts.containsKey(fontName)) {
        return false;
      }
      
      // 删除字体文件
      final fontPath = _customFonts[fontName]!;
      final file = File(fontPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // 从列表中移除
      _customFonts.remove(fontName);
      await _saveCustomFonts();
      
      // 如果当前选中的是被删除的字体，切换回系统字体
      if (_selectedFont == fontName) {
        await setFont('system');
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error removing custom font: $e');
      return false;
    }
  }
  
  Future<void> _saveCustomFonts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customFontsJson = _customFonts.entries
          .map((e) => '${e.key}|${e.value}')
          .toList();
      await prefs.setStringList('custom_fonts', customFontsJson);
    } catch (e) {
      debugPrint('Error saving custom fonts: $e');
    }
  }
  
  String? get fontFamily {
    if (_selectedFont == 'system') {
      return null; // 使用系统默认字体
    }
    return _selectedFont;
  }
  
  bool isCustomFont(String fontName) {
    return _customFonts.containsKey(fontName);
  }
}
