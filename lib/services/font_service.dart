import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'localization_service.dart';

class FontStack {
  const FontStack({
    required this.primaryFamily,
    required this.fallbackFamilies,
  });

  final String primaryFamily;
  final List<String> fallbackFamilies;
}

class FontService extends ChangeNotifier {
  static const String englishLocaleTag = 'en';
  static const String chineseLocaleTag = 'zh';
  static const String traditionalChineseLocaleTag = 'zh_Hant';
  static const String defaultEnglishFontFamily = 'Segoe UI';
  static const String defaultChineseFontFamily = 'Noto Sans SC';
  static const List<String> defaultChineseBackupFamilies = [
    'Microsoft YaHei UI',
    'Microsoft YaHei',
  ];
  static const List<String> defaultTraditionalChineseBackupFamilies = [
    'Microsoft JhengHei UI',
    'Microsoft JhengHei',
  ];
  static const List<String> optionalLocaleTags = [
    traditionalChineseLocaleTag,
    'ja',
    'ko',
    'ru',
    'ar',
    'th',
    'hi',
  ];
  static const Map<String, String> _builtinSuggestedFonts = {
    traditionalChineseLocaleTag: 'Microsoft JhengHei UI',
    'ja': 'Yu Gothic UI',
    'ko': 'Malgun Gothic',
    'ru': 'Segoe UI',
    'ar': 'Segoe UI',
    'th': 'Leelawadee UI',
    'hi': 'Nirmala UI',
  };

  // Kept for compatibility with existing preview code paths.
  static const String systemFontFamily = defaultEnglishFontFamily;

  Map<String, String> _customFonts = {};
  Map<String, String> _localeFontOverrides = {};
  Set<String> _enabledLocaleTags = {
    englishLocaleTag,
    chineseLocaleTag,
  };
  Map<String, String> _languagePackDefaultFonts = {};
  Map<String, String> _languagePackEnglishDefaultFonts = {};
  Map<String, String> _languagePackFontLocaleTags = {};

  Map<String, String> get customFonts => Map.unmodifiable(_customFonts);
  Map<String, String> get localeFontOverrides =>
      Map.unmodifiable(_localeFontOverrides);
  Set<String> get enabledLocaleTags => Set.unmodifiable(_enabledLocaleTags);
  Set<String> get discoveredLocaleTags =>
      Set.unmodifiable(_languagePackFontLocaleTags.values.toSet());

  String? get fontFamily => primaryFontFamily;

  String get primaryFontFamily => effectiveFontForLocaleTag(englishLocaleTag);

  String primaryFontFamilyForLocale(Locale activeLocale) {
    return effectiveFontForLocaleTag(
      englishLocaleTag,
      activeLocale: activeLocale,
    );
  }

  Future<void> loadFont() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _loadCustomFontsFromPrefs(prefs);
      _loadLocaleFontStateFromPrefs(prefs);
      _migrateLegacySingleFontSetting(prefs);
      _dropDeletedCustomFontBindings();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading font settings: $e');
    }
  }

  void updateLanguagePackDefaults(Iterable<LanguagePack> packs) {
    final nextDefaults = <String, String>{};
    final nextEnglishDefaults = <String, String>{};
    final nextFontLocaleTags = <String, String>{};

    for (final pack in packs) {
      final packLocaleTag = _canonicalizeLocaleTag(
        normalizeLocaleTag(pack.localeTag),
      );
      final declaredFontLocaleTag = pack.fontLocaleTag?.trim();
      final fontLocaleTag = declaredFontLocaleTag == null ||
              declaredFontLocaleTag.isEmpty
          ? packLocaleTag
          : _canonicalizeLocaleTag(normalizeLocaleTag(declaredFontLocaleTag));

      nextFontLocaleTags[packLocaleTag] = fontLocaleTag;

      final defaultFont = pack.defaultFontFamily?.trim();
      if (defaultFont != null && defaultFont.isNotEmpty) {
        nextDefaults[packLocaleTag] = defaultFont;
      }

      final defaultEnglishFont = pack.defaultEnglishFontFamily?.trim();
      if (defaultEnglishFont != null && defaultEnglishFont.isNotEmpty) {
        nextEnglishDefaults[packLocaleTag] = defaultEnglishFont;
      }
    }

    if (mapEquals(_languagePackDefaultFonts, nextDefaults) &&
        mapEquals(_languagePackEnglishDefaultFonts, nextEnglishDefaults) &&
        mapEquals(_languagePackFontLocaleTags, nextFontLocaleTags)) {
      return;
    }

    _languagePackDefaultFonts = nextDefaults;
    _languagePackEnglishDefaultFonts = nextEnglishDefaults;
    _languagePackFontLocaleTags = nextFontLocaleTags;
    notifyListeners();
  }

  String normalizeLocaleTag(String tag) {
    return tag.replaceAll('-', '_').trim();
  }

  String resolveFontLocaleTag(String localeTag) {
    final normalizedTag = _canonicalizeLocaleTag(normalizeLocaleTag(localeTag));
    if (normalizedTag.isEmpty) {
      return englishLocaleTag;
    }

    final visitedTags = <String>{};
    var currentTag = normalizedTag;

    while (visitedTags.add(currentTag)) {
      final mappedTag = _languagePackFontLocaleTags[currentTag];
      if (mappedTag == null || mappedTag.isEmpty) {
        break;
      }

      final normalizedMappedTag =
          _canonicalizeLocaleTag(normalizeLocaleTag(mappedTag));
      if (normalizedMappedTag == currentTag) {
        break;
      }

      currentTag = normalizedMappedTag;
    }

    return currentTag;
  }

  String localeTagFor(Locale locale) {
    final buffer = StringBuffer(locale.languageCode);
    final script = locale.scriptCode;
    final country = locale.countryCode;
    if (script != null && script.isNotEmpty) {
      buffer.write('_$script');
    }
    if (country != null && country.isNotEmpty) {
      buffer.write('_$country');
    }
    return normalizeLocaleTag(buffer.toString());
  }

  List<String> orderedEnabledLocaleTags({Locale? activeLocale}) {
    final tags = <String>{
      englishLocaleTag,
      chineseLocaleTag,
      ..._localeFontOverrides.keys.map(resolveFontLocaleTag),
    };

    if (activeLocale != null) {
      final activeTag = resolveFontLocaleTag(localeTagFor(activeLocale));
      if (activeTag != englishLocaleTag && activeTag != chineseLocaleTag) {
        tags.add(activeTag);
      }
    }

    final extras = tags
        .where(
          (tag) => tag != englishLocaleTag && tag != chineseLocaleTag,
        )
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return [
      englishLocaleTag,
      chineseLocaleTag,
      ...extras,
    ];
  }

  FontStack resolveFontStack(Locale activeLocale) {
    final primary = primaryFontFamilyForLocale(activeLocale);
    final activeTag = resolveFontLocaleTag(localeTagFor(activeLocale));
    final seen = <String>{primary};
    final fallbacks = <String>[];

    void addFont(String? font) {
      if (font == null || font.isEmpty) {
        return;
      }
      if (seen.add(font)) {
        fallbacks.add(font);
      }
    }

    if (activeTag != englishLocaleTag) {
      _appendLocaleFonts(activeTag, addFont, activeLocale: activeLocale);
    }

    _appendLocaleFonts(chineseLocaleTag, addFont, activeLocale: activeLocale);

    for (final localeTag
        in orderedEnabledLocaleTags(activeLocale: activeLocale)) {
      if (localeTag == englishLocaleTag ||
          localeTag == chineseLocaleTag ||
          localeTag == activeTag) {
        continue;
      }
      _appendLocaleFonts(localeTag, addFont, activeLocale: activeLocale);
    }

    return FontStack(
      primaryFamily: primary,
      fallbackFamilies: fallbacks,
    );
  }

  String effectiveFontForLocaleTag(
    String localeTag, {
    Locale? activeLocale,
  }) {
    final normalizedTag = resolveFontLocaleTag(localeTag);
    final override = _localeFontOverrides[normalizedTag];
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }

    final defaultFont = suggestedFontForLocaleTag(
      normalizedTag,
      activeLocale: activeLocale,
    );
    if (defaultFont != null && defaultFont.trim().isNotEmpty) {
      return defaultFont.trim();
    }

    return defaultEnglishFontFamily;
  }

  String? suggestedFontForLocaleTag(
    String localeTag, {
    Locale? activeLocale,
  }) {
    final normalizedTag = resolveFontLocaleTag(localeTag);
    final activeLocaleTag =
        activeLocale == null ? null : _activeLocaleContextTag(activeLocale);

    if (normalizedTag == englishLocaleTag) {
      if (activeLocaleTag != null) {
        final activeEnglishDefault =
            _languagePackEnglishDefaultFonts[activeLocaleTag];
        if (activeEnglishDefault != null &&
            activeEnglishDefault.trim().isNotEmpty) {
          return activeEnglishDefault.trim();
        }
      }
      return defaultEnglishFontFamily;
    }

    if (activeLocaleTag != null) {
      final activeFontLocaleTag = resolveFontLocaleTag(activeLocaleTag);
      if (normalizedTag == activeFontLocaleTag) {
        final activeLocaleDefault = _languagePackDefaultFonts[activeLocaleTag];
        if (activeLocaleDefault != null &&
            activeLocaleDefault.trim().isNotEmpty) {
          return activeLocaleDefault.trim();
        }
      }
    }

    if (normalizedTag == chineseLocaleTag) {
      return defaultChineseFontFamily;
    }
    return _builtinSuggestedFonts[normalizedTag];
  }

  List<String> _backupFontsForLocale(String localeTag) {
    final normalizedTag = resolveFontLocaleTag(localeTag);
    if (normalizedTag == chineseLocaleTag) {
      return defaultChineseBackupFamilies;
    }
    if (normalizedTag == traditionalChineseLocaleTag) {
      return defaultTraditionalChineseBackupFamilies;
    }
    return const <String>[];
  }

  void _appendLocaleFonts(String localeTag, void Function(String? font) addFont,
      {Locale? activeLocale}) {
    final effectiveFont =
        effectiveFontForLocaleTag(localeTag, activeLocale: activeLocale);
    final suggestedFont =
        suggestedFontForLocaleTag(localeTag, activeLocale: activeLocale);

    addFont(effectiveFont);

    if (suggestedFont != null && suggestedFont != effectiveFont) {
      addFont(suggestedFont);
    }

    for (final fallbackFont in _backupFontsForLocale(localeTag)) {
      addFont(fallbackFont);
    }
  }

  bool hasFontOverrideForLocale(String localeTag) {
    return _localeFontOverrides.containsKey(resolveFontLocaleTag(localeTag));
  }

  bool isLocaleFontEnabled(String localeTag) {
    final normalizedTag = resolveFontLocaleTag(localeTag);
    return normalizedTag == englishLocaleTag ||
        normalizedTag == chineseLocaleTag ||
        _enabledLocaleTags.contains(normalizedTag);
  }

  bool canRemoveLocaleFont(String localeTag) {
    final normalizedTag = resolveFontLocaleTag(localeTag);
    return normalizedTag != englishLocaleTag &&
        normalizedTag != chineseLocaleTag;
  }

  Future<void> enableLocaleFont(String localeTag) async {
    final normalizedTag = resolveFontLocaleTag(localeTag);
    if (!canRemoveLocaleFont(normalizedTag)) {
      return;
    }

    if (_enabledLocaleTags.add(normalizedTag)) {
      await _saveLocaleFontState();
      notifyListeners();
    }
  }

  Future<void> disableLocaleFont(String localeTag) async {
    final normalizedTag = resolveFontLocaleTag(localeTag);
    if (!canRemoveLocaleFont(normalizedTag)) {
      return;
    }

    final removedEnabled = _enabledLocaleTags.remove(normalizedTag);
    final removedOverride = _localeFontOverrides.remove(normalizedTag) != null;
    if (removedEnabled || removedOverride) {
      await _saveLocaleFontState();
      notifyListeners();
    }
  }

  Future<void> setFontForLocale(String localeTag, String fontFamily) async {
    final normalizedTag = resolveFontLocaleTag(localeTag);
    final normalizedFont = fontFamily.trim();
    if (normalizedFont.isEmpty) {
      return;
    }

    _localeFontOverrides[normalizedTag] = normalizedFont;
    await _saveLocaleFontState();
    notifyListeners();
  }

  Future<void> resetFontForLocale(String localeTag) async {
    final normalizedTag = resolveFontLocaleTag(localeTag);
    final removedOverride = _localeFontOverrides.remove(normalizedTag) != null;
    final removedEnabled = _enabledLocaleTags.remove(normalizedTag);
    if (removedOverride || removedEnabled) {
      await _saveLocaleFontState();
      notifyListeners();
    }
  }

  Future<bool> addCustomFont(String fontPath) async {
    try {
      final file = File(fontPath);
      if (!await file.exists()) {
        return false;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final fontsDir = Directory(path.join(appDir.path, 'hanabi_fonts'));
      if (!await fontsDir.exists()) {
        await fontsDir.create(recursive: true);
      }

      final fileName = path.basename(fontPath);
      final targetPath = path.join(fontsDir.path, fileName);
      await file.copy(targetPath);

      final fontName = path.basenameWithoutExtension(fileName);
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

      final fontPath = _customFonts[fontName]!;
      final file = File(fontPath);
      if (await file.exists()) {
        await file.delete();
      }

      _customFonts.remove(fontName);

      _localeFontOverrides.removeWhere((_, value) => value == fontName);

      await _saveCustomFonts();
      await _saveLocaleFontState();

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error removing custom font: $e');
      return false;
    }
  }

  bool isCustomFont(String fontName) {
    return _customFonts.containsKey(fontName);
  }

  void _loadCustomFontsFromPrefs(SharedPreferences prefs) {
    final customFontsJson = prefs.getStringList('custom_fonts') ?? [];
    _customFonts = {};
    for (final entry in customFontsJson) {
      final parts = entry.split('|');
      if (parts.length == 2) {
        _customFonts[parts[0]] = parts[1];
      }
    }
  }

  void _loadLocaleFontStateFromPrefs(SharedPreferences prefs) {
    final localeFontsJson = prefs.getStringList('app_locale_fonts') ?? [];
    final enabledLocaleTags = prefs.getStringList('app_enabled_locale_fonts');

    _localeFontOverrides = {};
    for (final entry in localeFontsJson) {
      final parts = entry.split('|');
      if (parts.length != 2) {
        continue;
      }

      final localeTag = normalizeLocaleTag(parts[0]);
      final canonicalLocaleTag = _canonicalizeLocaleTag(localeTag);
      final fontFamily = parts[1].trim();
      if (canonicalLocaleTag.isNotEmpty && fontFamily.isNotEmpty) {
        _localeFontOverrides[canonicalLocaleTag] = fontFamily;
      }
    }

    _enabledLocaleTags = {
      englishLocaleTag,
      chineseLocaleTag,
      ...(enabledLocaleTags ?? const <String>[])
          .map(normalizeLocaleTag)
          .map(_canonicalizeLocaleTag)
          .where((tag) => tag.isNotEmpty),
    };
  }

  void _migrateLegacySingleFontSetting(SharedPreferences prefs) {
    if (_localeFontOverrides.isNotEmpty) {
      return;
    }

    final legacySelectedFont = prefs.getString('app_font');
    if (legacySelectedFont == null ||
        legacySelectedFont.isEmpty ||
        legacySelectedFont == 'system') {
      return;
    }

    _localeFontOverrides = {
      englishLocaleTag: legacySelectedFont,
      chineseLocaleTag: legacySelectedFont,
    };
  }

  void _dropDeletedCustomFontBindings() {
    // Keep locale bindings intact. At load time we can't reliably distinguish
    // a missing imported font from a system-installed font with the same family.
  }

  Future<void> _saveCustomFonts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customFontsJson =
          _customFonts.entries.map((e) => '${e.key}|${e.value}').toList();
      await prefs.setStringList('custom_fonts', customFontsJson);
    } catch (e) {
      debugPrint('Error saving custom fonts: $e');
    }
  }

  Future<void> _saveLocaleFontState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeFontsJson = _localeFontOverrides.entries
          .map((entry) => '${entry.key}|${entry.value}')
          .toList();
      final enabledLocaleTags = _localeFontOverrides.keys
          .where(
            (localeTag) =>
                localeTag != englishLocaleTag && localeTag != chineseLocaleTag,
          )
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      await prefs.setStringList('app_locale_fonts', localeFontsJson);
      await prefs.setStringList('app_enabled_locale_fonts', enabledLocaleTags);
    } catch (e) {
      debugPrint('Error saving locale font settings: $e');
    }
  }

  String _activeLocaleContextTag(Locale activeLocale) {
    return _canonicalizeLocaleTag(localeTagFor(activeLocale));
  }

  String _canonicalizeLocaleTag(String localeTag) {
    final normalizedTag = normalizeLocaleTag(localeTag);
    if (normalizedTag.isEmpty) {
      return normalizedTag;
    }

    final parts =
        normalizedTag.split('_').where((part) => part.isNotEmpty).toList();
    final lowerParts = parts.map((part) => part.toLowerCase()).toList();
    final upperParts = parts.map((part) => part.toUpperCase()).toList();
    final languageCode = lowerParts.first;

    if (languageCode == 'en') {
      return englishLocaleTag;
    }

    if (languageCode == 'zh') {
      if (lowerParts.contains('hant') ||
          upperParts.contains('TW') ||
          upperParts.contains('HK') ||
          upperParts.contains('MO')) {
        return traditionalChineseLocaleTag;
      }
      return chineseLocaleTag;
    }

    if (optionalLocaleTags.contains(languageCode)) {
      return languageCode;
    }

    return normalizedTag;
  }
}
