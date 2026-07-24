import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ffi' hide Size;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';
import 'dart:ui';
import '../../widgets/settings_components.dart';
import '../../widgets/smooth_scroll_wrapper.dart';
import '../../services/font_service.dart';
import '../../services/window_effect_service.dart';
import '../../services/client_config_service.dart';
import '../../services/notification_settings_service.dart';
import '../../services/performance_monitor_service.dart';
import '../../services/localization_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/animated_notifications.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;

final DynamicLibrary _fontPickerGdi32 = DynamicLibrary.open('gdi32.dll');

typedef _GetGlyphIndicesNative = Uint32 Function(
  IntPtr hdc,
  Pointer<Utf16> lpstr,
  Int32 c,
  Pointer<Uint16> pgi,
  Uint32 fl,
);
typedef _GetGlyphIndicesDart = int Function(
  int hdc,
  Pointer<Utf16> lpstr,
  int c,
  Pointer<Uint16> pgi,
  int fl,
);

final _GetGlyphIndicesDart _getGlyphIndices = _fontPickerGdi32.lookupFunction<
    _GetGlyphIndicesNative, _GetGlyphIndicesDart>('GetGlyphIndicesW');

const int _ggiMarkNonExistingGlyphs = 0x0001;
const int _gdiGlyphLookupFailed = 0xFFFFFFFF;
const String _fontRegistrySubKey =
    r'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts';
final Map<String, Set<_FontLanguageSupport>> _fontPickerSupportCache = {};

base class _MutableLogFont extends Struct {
  @Int32()
  external int lfHeight;

  @Int32()
  external int lfWidth;

  @Int32()
  external int lfEscapement;

  @Int32()
  external int lfOrientation;

  @Int32()
  external int lfWeight;

  @Uint8()
  external int lfItalic;

  @Uint8()
  external int lfUnderline;

  @Uint8()
  external int lfStrikeOut;

  @Uint8()
  external int lfCharSet;

  @Uint8()
  external int lfOutPrecision;

  @Uint8()
  external int lfClipPrecision;

  @Uint8()
  external int lfQuality;

  @Uint8()
  external int lfPitchAndFamily;

  @Array(LF_FACESIZE)
  external Array<Uint16> lfFaceName;
}

enum _FontLanguageSupport {
  latin(
    sampleText: 'AaBb123',
    searchKeywords: ['latin', 'english', 'western', '英文', '西文'],
  ),
  simplifiedChinese(
    sampleText: '简体中文',
    searchKeywords: ['中文', '简中', '简体', 'chinese', 'simplified chinese'],
  ),
  traditionalChinese(
    sampleText: '繁體漢字',
    searchKeywords: ['繁中', '繁体', 'traditional chinese', 'zh-hant'],
  ),
  japanese(
    sampleText: '日本語かな',
    searchKeywords: ['日文', '日语', 'japanese', 'nihongo', 'かな'],
  ),
  korean(
    sampleText: '한국어한글',
    searchKeywords: ['韩文', '韩语', 'korean', 'hangul', '한국어'],
  ),
  cyrillic(
    sampleText: 'Русский',
    searchKeywords: ['俄文', '俄语', 'cyrillic', 'russian', '西里尔'],
  ),
  greek(
    sampleText: 'Ελληνικά',
    searchKeywords: ['希腊文', 'greek'],
  ),
  arabic(
    sampleText: 'العربية',
    searchKeywords: ['阿拉伯文', 'arabic'],
  ),
  thai(
    sampleText: 'ไทย',
    searchKeywords: ['泰文', 'thai'],
  ),
  devanagari(
    sampleText: 'हिन्दी',
    searchKeywords: ['印地文', '天城文', 'hindi', 'devanagari'],
  ),
  emoji(
    sampleText: '😀✨👍',
    searchKeywords: ['emoji', '表情', '彩色表情'],
  );

  const _FontLanguageSupport({
    required this.sampleText,
    required this.searchKeywords,
  });

  final String sampleText;
  final List<String> searchKeywords;
}

class _FontPickerEntry {
  const _FontPickerEntry({
    required this.key,
    required this.displayName,
    required this.previewFontFamily,
    required this.isSystemAlias,
    required this.isCustom,
    this.supportedScripts = const <_FontLanguageSupport>{},
  });

  final String key;
  final String displayName;
  final String previewFontFamily;
  final bool isSystemAlias;
  final bool isCustom;
  final Set<_FontLanguageSupport> supportedScripts;

  _FontPickerEntry copyWith({
    Set<_FontLanguageSupport>? supportedScripts,
  }) {
    return _FontPickerEntry(
      key: key,
      displayName: displayName,
      previewFontFamily: previewFontFamily,
      isSystemAlias: isSystemAlias,
      isCustom: isCustom,
      supportedScripts: supportedScripts ?? this.supportedScripts,
    );
  }
}

extension on _FontLanguageSupport {
  String label(Locale locale) {
    final isZh = locale.languageCode.toLowerCase().startsWith('zh');
    switch (this) {
      case _FontLanguageSupport.latin:
        return 'Latin';
      case _FontLanguageSupport.simplifiedChinese:
        return isZh ? '简中' : 'Simplified Chinese';
      case _FontLanguageSupport.traditionalChinese:
        return isZh ? '繁中' : 'Traditional Chinese';
      case _FontLanguageSupport.japanese:
        return isZh ? '日文' : 'Japanese';
      case _FontLanguageSupport.korean:
        return isZh ? '韩文' : 'Korean';
      case _FontLanguageSupport.cyrillic:
        return isZh ? '西里尔' : 'Cyrillic';
      case _FontLanguageSupport.greek:
        return isZh ? '希腊文' : 'Greek';
      case _FontLanguageSupport.arabic:
        return isZh ? '阿拉伯文' : 'Arabic';
      case _FontLanguageSupport.thai:
        return isZh ? '泰文' : 'Thai';
      case _FontLanguageSupport.devanagari:
        return isZh ? '天城文' : 'Devanagari';
      case _FontLanguageSupport.emoji:
        return 'Emoji';
    }
  }
}

String _normalizeFontSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[\s\-_./\\]+'), '');
}

String _fontPickerLoadingLabel(Locale locale, int current, int total) {
  if (locale.languageCode.toLowerCase().startsWith('zh')) {
    return '语言支持检测中 $current/$total';
  }
  return 'Detecting language support $current/$total';
}

String _fontPickerCustomLabel(Locale locale) {
  return locale.languageCode.toLowerCase().startsWith('zh') ? '自定义' : 'Custom';
}

String _fontPickerSystemFallbackLabel(Locale locale) {
  return locale.languageCode.toLowerCase().startsWith('zh')
      ? 'Segoe UI'
      : 'Segoe UI';
}

String _fontUnsupportedTitle(Locale locale) {
  return locale.languageCode.toLowerCase().startsWith('zh')
      ? '字体不支持该语言'
      : 'Font unsupported for language';
}

String _fontUnsupportedMessage(
  Locale locale, {
  required String fontFamily,
  required String localeLabel,
  required String fallbackFont,
}) {
  if (locale.languageCode.toLowerCase().startsWith('zh')) {
    return '"$fontFamily" 不支持 $localeLabel，已回退为 $fallbackFont。';
  }
  return '"$fontFamily" does not support $localeLabel. Reverted to $fallbackFont.';
}

bool _shouldSkipFontLanguageProbe(String fontFamily) {
  if (fontFamily.isEmpty || fontFamily.startsWith('@')) {
    return true;
  }

  // Bitmap font aliases like "MS Sans Serif 8,10,12,14,18,24" are not useful
  // for Flutter font-family selection and are prone to noisy GDI probing.
  if (RegExp(r'\s+\d+(,\d+)+$').hasMatch(fontFamily)) {
    return true;
  }

  return false;
}

Set<_FontLanguageSupport> _detectFontSupportedScripts(String fontFamily) {
  if (!Platform.isWindows) {
    return const <_FontLanguageSupport>{};
  }

  final normalizedFontFamily = fontFamily.trim();
  if (_shouldSkipFontLanguageProbe(normalizedFontFamily)) {
    return const <_FontLanguageSupport>{};
  }

  final cachedSupport = _fontPickerSupportCache[normalizedFontFamily];
  if (cachedSupport != null) {
    return cachedSupport;
  }

  if (normalizedFontFamily.isEmpty) {
    return const <_FontLanguageSupport>{};
  }

  // GDI LOGFONT only accepts LF_FACESIZE (32) WCHARs including the null terminator.
  if (normalizedFontFamily.codeUnits.length >= LF_FACESIZE) {
    _fontPickerSupportCache[normalizedFontFamily] =
        const <_FontLanguageSupport>{};
    return const <_FontLanguageSupport>{};
  }

  final logFont = calloc<LOGFONT>();
  final mutableLogFont = logFont.cast<_MutableLogFont>();
  try {
    mutableLogFont.ref
      ..lfHeight = -16
      ..lfWeight = 400
      ..lfCharSet = DEFAULT_CHARSET
      ..lfQuality = CLEARTYPE_QUALITY;
    _copyLogFontFaceName(mutableLogFont.ref.lfFaceName, normalizedFontFamily);

    final hFont = CreateFontIndirect(logFont);
    if (hFont == 0) {
      return const <_FontLanguageSupport>{};
    }

    final hdc = CreateCompatibleDC(HDC(Pointer.fromAddress(0)));
    if (hdc.address == 0) {
      DeleteObject(HGDIOBJ(Pointer.fromAddress(hFont.address)));
      return const <_FontLanguageSupport>{};
    }

    final previousObject =
        SelectObject(hdc, HGDIOBJ(Pointer.fromAddress(hFont.address)));
    try {
      final supportedScripts = <_FontLanguageSupport>{};
      for (final script in _FontLanguageSupport.values) {
        if (_fontSupportsSample(hdc, script.sampleText)) {
          supportedScripts.add(script);
        }
      }
      _fontPickerSupportCache[normalizedFontFamily] = supportedScripts;
      return supportedScripts;
    } finally {
      if (previousObject.address != 0) {
        SelectObject(hdc, previousObject);
      }
      DeleteDC(hdc);
      DeleteObject(HGDIOBJ(Pointer.fromAddress(hFont.address)));
    }
  } catch (e) {
    debugPrint('Error detecting font language support for $fontFamily: $e');
    _fontPickerSupportCache[normalizedFontFamily] =
        const <_FontLanguageSupport>{};
    return const <_FontLanguageSupport>{};
  } finally {
    calloc.free(logFont);
  }
}

void _copyLogFontFaceName(Array<Uint16> target, String value) {
  const capacity = LF_FACESIZE;
  final units = value.codeUnits;
  const maxCopyLength = capacity - 1;
  var index = 0;
  while (index < maxCopyLength && index < units.length) {
    target[index] = units[index];
    index++;
  }
  while (index < capacity) {
    target[index] = 0;
    index++;
  }
}

bool _fontSupportsSample(HDC hdc, String sampleText) {
  final normalizedSample = sampleText.replaceAll(' ', '');
  if (normalizedSample.isEmpty) {
    return false;
  }

  final textPtr = normalizedSample.toNativeUtf16();
  final glyphsPtr = calloc<Uint16>(normalizedSample.length);

  try {
    final result = _getGlyphIndices(
      hdc.address,
      textPtr,
      normalizedSample.length,
      glyphsPtr,
      _ggiMarkNonExistingGlyphs,
    );

    if (result == _gdiGlyphLookupFailed) {
      return false;
    }

    var supportedGlyphs = 0;
    for (var i = 0; i < normalizedSample.length; i++) {
      if (glyphsPtr[i] != 0xFFFF) {
        supportedGlyphs++;
      }
    }

    return supportedGlyphs * 10 >= normalizedSample.length * 6;
  } finally {
    calloc.free(textPtr);
    calloc.free(glyphsPtr);
  }
}

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  // 字体设置
  List<String> _availableFonts = [];
  bool _loadingFonts = true;

  // UI 设置
  bool _segmentsDefaultExpanded = false;
  int _segmentsMaxVisible = 5;
  String _segmentsDisplayMode = 'merged'; // 'merged' (合并) 或 'list' (列表)
  bool _showSpeedChart = true;
  bool _showChartFrost = true;
  String _chartPosition = 'mid'; // 'low' | 'mid' | 'high'
  String _chartColor = 'blue';

  // 通知设置
  bool _notificationEnabled = true;
  String _notificationColorScheme = 'fluent2';
  String _notificationPosition = 'topRight';
  String _performanceMode = 'performance'; // 性能模式

  // 屏幕尺寸
  double _screenWidth = 1920.0;
  double _screenHeight = 1080.0;
  bool _loadingScreenSize = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAvailableFonts();
    _loadScreenSize();
  }

  Future<void> _loadScreenSize() async {
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      if (mounted) {
        setState(() {
          _screenWidth = primaryDisplay.size.width;
          _screenHeight = primaryDisplay.size.height;
          _loadingScreenSize = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading screen size: $e');
      if (mounted) {
        setState(() {
          _loadingScreenSize = false;
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationSettings = NotificationSettingsService();

    if (mounted) {
      setState(() {
        _segmentsDefaultExpanded =
            prefs.getBool('segments_default_expanded') ?? false;
        _segmentsMaxVisible = prefs.getInt('segments_max_visible') ?? 5;
        _segmentsDisplayMode =
            prefs.getString('segments_display_mode') ?? 'merged';
        _showSpeedChart = prefs.getBool('show_speed_chart') ?? true;
        _showChartFrost = prefs.getBool('show_chart_frost') ?? true;
        _chartPosition = prefs.getString('chart_position') ?? 'mid';
        _chartColor = prefs.getString('chart_color') ?? 'blue';

        // 加载通知设置
        _notificationEnabled = notificationSettings.enabled;
        _notificationColorScheme = notificationSettings.colorScheme.name;
        _notificationPosition = notificationSettings.position.name;
        _performanceMode = notificationSettings.performanceMode.name;
      });
    }
  }

  Future<void> _loadAvailableFonts() async {
    setState(() => _loadingFonts = true);

    try {
      // 获取系统字体列表
      final systemFonts = await _getSystemFonts();

      // 获取自定义字体列表
      final fontService = context.read<FontService>();
      final customFonts = fontService.customFonts.keys.toList();
      final languagePackFonts = context
          .read<LocalizationService>()
          .languagePacks
          .expand(
            (pack) => [
              pack.defaultFontFamily?.trim(),
              pack.defaultEnglishFontFamily?.trim(),
            ],
          )
          .whereType<String>()
          .where((font) => font.isNotEmpty)
          .toList();

      if (mounted) {
        final mergedFonts = <String>{
          ...systemFonts,
          ...customFonts,
          ...languagePackFonts,
          FontService.defaultEnglishFontFamily,
          FontService.defaultChineseFontFamily,
        };
        final sortedFonts = mergedFonts.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        setState(() {
          _availableFonts = sortedFonts;
          _loadingFonts = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading fonts: $e');
      if (mounted) {
        setState(() {
          _availableFonts = [];
          _loadingFonts = false;
        });
      }
    }
  }

  Future<List<String>> _getSystemFonts() async {
    if (!Platform.isWindows) {
      return [];
    }

    try {
      final fontNames = <String>{};
      _collectFontsFromRegistry(
          HKEY_LOCAL_MACHINE, _fontRegistrySubKey, fontNames);
      _collectFontsFromRegistry(
          HKEY_CURRENT_USER, _fontRegistrySubKey, fontNames);

      // 转换为列表并排序
      final sortedFonts = fontNames.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      return sortedFonts;
    } catch (e) {
      debugPrint('Error reading system fonts: $e');
      // 如果读取失败，返回常见字体列表
      return [
        'Microsoft YaHei',
        'Microsoft YaHei UI',
        'SimSun',
        'SimHei',
        'KaiTi',
        'FangSong',
        'Arial',
        'Segoe UI',
        'Calibri',
        'Consolas',
        'Courier New',
        'Times New Roman',
        'Verdana',
        'Tahoma',
        'Georgia',
      ];
    }
  }

  void _collectFontsFromRegistry(
    HKEY rootKey,
    String subKey,
    Set<String> fontNames,
  ) {
    final phkResult = calloc<IntPtr>();
    final subKeyPtr = PCWSTR(subKey.toNativeUtf16());

    try {
      final result = RegOpenKeyEx(
        rootKey,
        subKeyPtr,
        0,
        KEY_READ,
        phkResult.cast(),
      );

      if (result != ERROR_SUCCESS) {
        return;
      }

      final hKey = HKEY(Pointer.fromAddress(phkResult.value));
      try {
        var index = 0;
        while (true) {
          const valueNameCapacity = 1024;
          final valueName = wsalloc(valueNameCapacity);
          final valueNameSize = calloc<DWORD>()..value = valueNameCapacity;

          try {
            final enumResult = RegEnumValue(
              hKey,
              index,
              valueName,
              valueNameSize,
              nullptr,
              nullptr,
              nullptr,
            );

            if (enumResult == ERROR_NO_MORE_ITEMS) {
              break;
            }

            if (enumResult == ERROR_SUCCESS) {
              _addRegistryFontNames(fontNames, valueName.toDartString());
            }

            index++;
          } finally {
            calloc.free(valueName);
            calloc.free(valueNameSize);
          }
        }
      } finally {
        RegCloseKey(hKey);
      }
    } finally {
      calloc.free(subKeyPtr);
      calloc.free(phkResult);
    }
  }

  void _addRegistryFontNames(Set<String> fontNames, String registryValueName) {
    final cleanedValueName = registryValueName
        .replaceAll(RegExp(r'\s*\(TrueType\)$'), '')
        .replaceAll(RegExp(r'\s*\(OpenType\)$'), '')
        .replaceAll(RegExp(r'\s*\(All res\)$'), '')
        .trim();

    for (final part in cleanedValueName.split(RegExp(r'\s*&\s*'))) {
      final candidate = _normalizeRegistryFontName(part);
      if (candidate != null) {
        fontNames.add(candidate);
      }
    }
  }

  String? _normalizeRegistryFontName(String registryValueName) {
    final candidate = registryValueName.trim();
    if (candidate.isEmpty || candidate.startsWith('@')) {
      return null;
    }

    if (RegExp(r'\s+\d+(,\d+)+$').hasMatch(candidate)) {
      return null;
    }

    return candidate;
  }

  bool _isZhUi(Locale locale) {
    return locale.languageCode.toLowerCase().startsWith('zh');
  }

  String _fontSectionHint(Locale locale) {
    if (_isZhUi(locale)) {
      return '默认只显示英文和中文。当前界面语言如果实际归属到别的字体类别，会临时补出对应设置；基于中英的第三方语言包则继续复用原有设置。';
    }
    return 'Only English and Chinese stay visible by default. If the current UI language resolves to another font category, that category appears automatically; third-party packs based on English or Chinese keep reusing those existing rows.';
  }

  String _fontLocaleDefaultSubtitle(Locale locale, String fontFamily) {
    if (_isZhUi(locale)) {
      return '默认字体: $fontFamily';
    }
    return 'Default font: $fontFamily';
  }

  String _fontLocaleInheritedSubtitle(Locale locale, String fontFamily) {
    if (_isZhUi(locale)) {
      return '未单独设置，当前跟随 $fontFamily';
    }
    return 'Not overridden, currently inherits $fontFamily';
  }

  String _fontLocaleOverrideSubtitle(Locale locale, String fontFamily) {
    if (_isZhUi(locale)) {
      return '当前字体: $fontFamily';
    }
    return 'Current font: $fontFamily';
  }

  String _fontLocaleCustomFontsTitle(Locale locale) {
    return _isZhUi(locale) ? '导入字体' : 'Imported fonts';
  }

  String _fontLocaleNoCustomFonts(Locale locale) {
    return _isZhUi(locale)
        ? '还没有导入字体,导入的字体无需安装到系统,您安装在系统的字体可以直接通过软件内字体设置莱调整！'
        : 'Fonts have not been imported yet. Imported fonts do not need to be installed in the system. Fonts installed in your system can be directly adjusted through the software\'s font settings!';
  }

  String _fontLocaleResetTooltip(Locale locale) {
    return _isZhUi(locale) ? '恢复默认字体' : 'Reset to default';
  }

  String? _builtinFontLocaleLabel(Locale locale, String localeTag) {
    final normalizedTag = localeTag.replaceAll('-', '_').trim();
    final isZh = _isZhUi(locale);
    switch (normalizedTag) {
      case FontService.traditionalChineseLocaleTag:
        return isZh ? '繁体中文' : 'Traditional Chinese';
      case 'ja':
        return isZh ? '日语' : 'Japanese';
      case 'ko':
        return isZh ? '韩语' : 'Korean';
      case 'ru':
        return isZh ? '俄语' : 'Russian';
      case 'ar':
        return isZh ? '阿拉伯语' : 'Arabic';
      case 'th':
        return isZh ? '泰语' : 'Thai';
      case 'hi':
        return isZh ? '印地语' : 'Hindi';
    }
    return null;
  }

  String _displayLanguageLabel(
    String localeTag,
    Map<String, String> languageLabels,
    Locale? uiLocale,
  ) {
    final normalizedTag = localeTag.replaceAll('-', '_').trim();
    final builtinLabel = uiLocale == null
        ? null
        : _builtinFontLocaleLabel(uiLocale, normalizedTag);
    return builtinLabel ?? languageLabels[normalizedTag] ?? normalizedTag;
  }

  String _fontLocaleTitle(
    Locale uiLocale,
    String localeTag,
    String localeLabel,
  ) {
    final normalizedTag = localeTag.replaceAll('-', '_').trim();
    if (normalizedTag == FontService.englishLocaleTag ||
        normalizedTag == FontService.chineseLocaleTag ||
        _builtinFontLocaleLabel(uiLocale, normalizedTag) != null ||
        localeLabel == normalizedTag) {
      return localeLabel;
    }
    return '$localeLabel ($normalizedTag)';
  }

  String _localeFontSubtitle(
    Locale uiLocale,
    FontService fontService,
    String localeTag,
    Locale activeLocale,
  ) {
    if (fontService.hasFontOverrideForLocale(localeTag)) {
      return _fontLocaleOverrideSubtitle(
        uiLocale,
        fontService.effectiveFontForLocaleTag(
          localeTag,
          activeLocale: activeLocale,
        ),
      );
    }

    final defaultFont = fontService.suggestedFontForLocaleTag(
      localeTag,
      activeLocale: activeLocale,
    );
    if (defaultFont != null && defaultFont.isNotEmpty) {
      return _fontLocaleDefaultSubtitle(uiLocale, defaultFont);
    }

    return _fontLocaleInheritedSubtitle(
      uiLocale,
      fontService.primaryFontFamilyForLocale(activeLocale),
    );
  }

  Set<_FontLanguageSupport> _requiredScriptsForLocaleTag(String localeTag) {
    final normalizedTag = localeTag.replaceAll('-', '_').trim();
    if (normalizedTag.isEmpty) {
      return const <_FontLanguageSupport>{};
    }

    final parts =
        normalizedTag.split('_').where((part) => part.isNotEmpty).toList();
    final lowerParts = parts.map((part) => part.toLowerCase()).toList();
    final upperParts = parts.map((part) => part.toUpperCase()).toList();
    final languageCode = lowerParts.first;

    switch (languageCode) {
      case 'en':
        return const {_FontLanguageSupport.latin};
      case 'zh':
        if (lowerParts.contains('hant') ||
            upperParts.contains('TW') ||
            upperParts.contains('HK') ||
            upperParts.contains('MO')) {
          return const {_FontLanguageSupport.traditionalChinese};
        }
        return const {_FontLanguageSupport.simplifiedChinese};
      case 'ja':
        return const {_FontLanguageSupport.japanese};
      case 'ko':
        return const {_FontLanguageSupport.korean};
      case 'ru':
      case 'uk':
      case 'bg':
      case 'sr':
      case 'mk':
      case 'mn':
      case 'be':
      case 'kk':
      case 'ky':
      case 'tg':
        return const {_FontLanguageSupport.cyrillic};
      case 'el':
        return const {_FontLanguageSupport.greek};
      case 'ar':
      case 'fa':
      case 'ur':
      case 'ps':
        return const {_FontLanguageSupport.arabic};
      case 'th':
        return const {_FontLanguageSupport.thai};
      case 'hi':
      case 'mr':
      case 'ne':
        return const {_FontLanguageSupport.devanagari};
    }

    const latinLanguages = <String>{
      'af',
      'ca',
      'cs',
      'da',
      'de',
      'es',
      'et',
      'fi',
      'fr',
      'hr',
      'hu',
      'id',
      'is',
      'it',
      'lt',
      'lv',
      'ms',
      'nl',
      'no',
      'pl',
      'pt',
      'ro',
      'sk',
      'sl',
      'sq',
      'sv',
      'tl',
      'tr',
      'vi',
    };

    if (latinLanguages.contains(languageCode)) {
      return const {_FontLanguageSupport.latin};
    }

    return const <_FontLanguageSupport>{};
  }

  bool _fontSupportsLocale(
    String localeTag,
    String fontFamily, {
    required bool isCustomFont,
  }) {
    if (!Platform.isWindows || isCustomFont) {
      return true;
    }

    final requiredScripts = _requiredScriptsForLocaleTag(localeTag);
    if (requiredScripts.isEmpty) {
      return true;
    }

    final supportedScripts = _detectFontSupportedScripts(fontFamily);
    if (supportedScripts.isEmpty) {
      return true;
    }

    return requiredScripts.every(supportedScripts.contains);
  }

  Future<void> _saveLocaleFontSetting(
    String localeTag,
    String fontFamily, {
    required String localeLabel,
    required String fallbackFont,
  }) async {
    final fontService = context.read<FontService>();
    if (!_fontSupportsLocale(
      localeTag,
      fontFamily,
      isCustomFont: fontService.isCustomFont(fontFamily),
    )) {
      if (!mounted) {
        return;
      }

      final locale = Localizations.localeOf(context);
      NotificationManager.of(context)?.showWarning(
        _fontUnsupportedTitle(locale),
        message: _fontUnsupportedMessage(
          locale,
          fontFamily: fontFamily,
          localeLabel: localeLabel,
          fallbackFont: fallbackFont,
        ),
      );
      return;
    }

    await fontService.setFontForLocale(localeTag, fontFamily);

    if (!mounted) {
      return;
    }

    final t = AppLocalizations.of(context)!;
    NotificationManager.of(context)?.showSuccess(
      t.appearanceFontChangedTitle,
      message: t.appearanceFontChangedMessage,
    );
  }

  Future<void> _resetLocaleFont(String localeTag) async {
    final fontService = context.read<FontService>();
    await fontService.resetFontForLocale(localeTag);

    if (!mounted) {
      return;
    }

    final t = AppLocalizations.of(context)!;
    NotificationManager.of(context)?.showSuccess(
      t.appearanceFontChangedTitle,
      message: t.appearanceFontChangedMessage,
    );
  }

  Future<void> _showLocaleFontPickerDialog(
    BuildContext context, {
    required String localeTag,
    required String localeLabel,
    required String currentFont,
  }) async {
    final t = AppLocalizations.of(context)!;
    final customFonts = context.read<FontService>().customFonts.keys.toSet();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _FontPickerDialog(
        availableFonts: _availableFonts,
        selectedFont: currentFont,
        customFonts: customFonts,
        t: t,
      ),
    );

    if (result != null && result != currentFont) {
      await _saveLocaleFontSetting(
        localeTag,
        result,
        localeLabel: localeLabel,
        fallbackFont: currentFont,
      );
    }
  }

  Future<void> _saveSegmentsExpandedSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('segments_default_expanded', value);
    setState(() => _segmentsDefaultExpanded = value);
  }

  Future<void> _saveSegmentsMaxVisibleSetting(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('segments_max_visible', value);
    setState(() => _segmentsMaxVisible = value);
  }

  Future<void> _saveSegmentsDisplayMode(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('segments_display_mode', value);
    setState(() => _segmentsDisplayMode = value);
  }

  Future<void> _saveShowSpeedChart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_speed_chart', value);
    setState(() => _showSpeedChart = value);
  }

  Future<void> _saveShowChartFrost(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_chart_frost', value);
    setState(() => _showChartFrost = value);
  }

  Future<void> _saveChartPosition(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chart_position', value);
    setState(() => _chartPosition = value);
  }

  Future<void> _saveChartColor(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chart_color', value);
    setState(() => _chartColor = value);
  }

  // 通知设置保存方法
  Future<void> _saveNotificationEnabled(bool value) async {
    final notificationSettings = NotificationSettingsService();
    await notificationSettings.setEnabled(value);
    setState(() => _notificationEnabled = value);
  }

  Future<void> _saveNotificationColorScheme(String value) async {
    final notificationSettings = NotificationSettingsService();
    final scheme = NotificationColorScheme.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationColorScheme.fluent2,
    );
    await notificationSettings.setColorScheme(scheme);
    setState(() => _notificationColorScheme = value);
  }

  Future<void> _saveNotificationPosition(String value) async {
    final notificationSettings = NotificationSettingsService();
    final position = NotificationPosition.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationPosition.topRight,
    );
    await notificationSettings.setPosition(position);
    setState(() => _notificationPosition = value);
  }

  Future<void> _savePerformanceMode(String value) async {
    final notificationSettings = NotificationSettingsService();
    final mode = NotificationPerformanceMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationPerformanceMode.performance,
    );
    await notificationSettings.setPerformanceMode(mode);
    setState(() => _performanceMode = value);
  }

  String _getNotificationColorSchemeName(String scheme, AppLocalizations t) {
    switch (scheme) {
      case 'defaultScheme':
        return t.appearanceNotificationSchemeSystem;
      case 'light':
        return t.appearanceNotificationSchemeLight;
      case 'dark':
        return t.appearanceNotificationSchemeDark;
      case 'fluent2':
        return t.appearanceNotificationSchemeFluent2;
      default:
        return t.appearanceNotificationSchemeUnknown;
    }
  }

  String _getThemeModeName(String mode, AppLocalizations t) {
    switch (mode) {
      case 'light':
        return t.appearanceThemeModeLight;
      case 'dark':
        return t.appearanceThemeModeDark;
      case 'system':
      default:
        return t.appearanceThemeModeSystem;
    }
  }

  String _getNotificationPositionName(String position, AppLocalizations t) {
    switch (position) {
      case 'topRight':
        return t.appearanceNotificationPositionTopRight;
      case 'bottomRight':
        return t.appearanceNotificationPositionBottomRight;
      default:
        return t.appearanceNotificationPositionUnknown;
    }
  }

  String _getPerformanceModeName(String mode, AppLocalizations t) {
    switch (mode) {
      case 'quality':
        return t.appearancePerformanceModeQuality;
      case 'balanced':
        return t.appearancePerformanceModeBalanced;
      case 'performance':
        return t.appearancePerformanceModePerformance;
      default:
        return t.appearancePerformanceModeUnknown;
    }
  }

  void _showTestNotification() {
    final notificationManager = NotificationManager.of(context);
    if (notificationManager != null) {
      final t = AppLocalizations.of(context)!;
      notificationManager.showSuccess(
        t.appearanceNotificationTestTitle,
        message: t.appearanceNotificationTestMessage,
      );
    }
  }

  // 通知配色预览框
  Widget _buildNotificationPreview(BuildContext context) {
    final notificationSettings = NotificationSettingsService();
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              CustomIcons.FluentIcons.preview,
              size: 14,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              t.appearanceNotificationPreviewTitle,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgLayer1.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: AppTheme.borderSubtle.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              _buildPreviewNotificationCard(
                context,
                title: t.appearanceNotificationPreviewSuccessTitle,
                message: t.appearanceNotificationPreviewSuccessMessage,
                icon: CustomIcons.FluentIcons.completed_solid,
                color: notificationSettings.getSuccessColor(isDark),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPreviewNotificationCard(
                context,
                title: t.appearanceNotificationPreviewWarningTitle,
                message: t.appearanceNotificationPreviewWarningMessage,
                icon: CustomIcons.FluentIcons.warning,
                color: notificationSettings.getWarningColor(isDark),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPreviewNotificationCard(
                context,
                title: t.appearanceNotificationPreviewErrorTitle,
                message: t.appearanceNotificationPreviewErrorMessage,
                icon: CustomIcons.FluentIcons.status_error_full,
                color: notificationSettings.getErrorColor(isDark),
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildPreviewNotificationCard(
                context,
                title: t.appearanceNotificationPreviewInfoTitle,
                message: t.appearanceNotificationPreviewInfoMessage,
                icon: CustomIcons.FluentIcons.info,
                color: notificationSettings.getInfoColor(isDark),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 预览通知卡片（静态展示）
  Widget _buildPreviewNotificationCard(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final notificationSettings = NotificationSettingsService();
    final cardColor = notificationSettings.getCardColor(isDark);
    final textPrimary = notificationSettings.getTextPrimaryColor(isDark);
    final textSecondary = notificationSettings.getTextSecondaryColor(isDark);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: color.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 图标
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          icon,
                          size: 14,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 内容
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: FluentTheme.of(context)
                                  .typography
                                  .bodyStrong
                                  ?.copyWith(
                                    color: textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    letterSpacing: -0.2,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message,
                              style: FluentTheme.of(context)
                                  .typography
                                  .body
                                  ?.copyWith(
                                    color: textSecondary,
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 关闭按钮
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.bgLayer2.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          CustomIcons.FluentIcons.chrome_close,
                          size: 10,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 进度条
                Container(
                  height: 2,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.6, // 静态显示 60% 进度
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importCustomFont() async {
    try {
      final t = AppLocalizations.of(context)!;
      final result = await openFile(
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: t.appearanceFontImportDialogTitle,
            extensions: const <String>['ttf', 'otf'],
          ),
        ],
      );

      if (result != null) {
        final fontPath = result.path;

        if (mounted) {
          // 显示加载提示
          NotificationManager.of(context)?.showInfo(
            t.appearanceFontImportingTitle,
            message: t.appearanceFontImportingMessage,
          );
        }

        final fontService = context.read<FontService>();
        final success = await fontService.addCustomFont(fontPath);

        if (mounted) {
          if (success) {
            // 重新加载字体列表
            await _loadAvailableFonts();

            NotificationManager.of(context)?.showSuccess(
              t.appearanceFontImportSuccessTitle,
              message: t.appearanceFontImportSuccessMessage,
            );
          } else {
            NotificationManager.of(context)?.showError(
              t.appearanceFontImportFailedTitle,
              message: t.appearanceFontImportFailedMessage,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error importing font: $e');
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        NotificationManager.of(context)?.showError(
          t.appearanceFontImportFailedTitle,
          message: t.appearanceFontImportFailedWithErrorMessage(e.toString()),
        );
        Clipboard.setData(ClipboardData(text: e.toString()));
      }
    }
  }

  Future<void> _removeCustomFont(String fontName) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(t.appearanceFontDeleteConfirmTitle),
        content: Text(t.appearanceFontDeleteConfirmMessage(fontName)),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.appearanceFontDeleteCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.appearanceFontDeleteConfirmButton),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final fontService = context.read<FontService>();
      final success = await fontService.removeCustomFont(fontName);

      if (mounted) {
        if (success) {
          await _loadAvailableFonts();
          NotificationManager.of(context)?.showSuccess(
            t.appearanceFontDeleteSuccessTitle,
            message: t.appearanceFontDeleteSuccessMessage,
          );
        } else {
          NotificationManager.of(context)?.showError(
            t.appearanceFontDeleteFailedTitle,
            message: t.appearanceFontDeleteFailedMessage,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 追踪重建
    PerformanceMonitorService().trackRebuild('AppearanceSettingsPage');

    final windowEffect = context.watch<WindowEffectService>();
    final clientConfig = context.watch<ClientConfigService>();
    final localizationService = context.watch<LocalizationService>();
    final fontService = context.watch<FontService>();
    final t = AppLocalizations.of(context)!;
    final uiLocale = Localizations.localeOf(context);
    final isChinese = uiLocale.languageCode.toLowerCase() == 'zh';
    final nativeResult = windowEffect.lastApplyResult;
    final effectStatusColor = !windowEffect.effectEnabled
        ? AppTheme.textTertiary
        : windowEffect.nativeMaterialReady
            ? AppTheme.statusSuccess
            : AppTheme.statusError;
    final effectStatusText = !windowEffect.effectEnabled
        ? (isChinese ? '窗口材质已关闭' : 'Window material is off')
        : nativeResult == null
            ? (isChinese ? '正在应用原生窗口材质' : 'Applying native material')
            : windowEffect.nativeMaterialReady
                ? (isChinese
                    ? '原生材质已应用 · Windows ${nativeResult.windowsBuild} · ${nativeResult.appliedMode.nativeName}'
                    : 'Native material active · Windows ${nativeResult.windowsBuild} · ${nativeResult.appliedMode.nativeName}')
                : (isChinese
                    ? '原生材质未生效，界面已回退为纯色'
                    : 'Native material failed; using the solid fallback');

    final packs = [...localizationService.languagePacks]
      ..sort((a, b) => a.localeTag.compareTo(b.localeTag));
    final languageLabels = <String, String>{
      'system': t.appearanceLanguageSystem,
      'zh': t.appearanceLanguageChinese,
      'en': t.appearanceLanguageEnglish,
    };
    for (final pack in packs) {
      final normalizedLocaleTag =
          fontService.normalizeLocaleTag(pack.localeTag);
      if (languageLabels.containsKey(normalizedLocaleTag)) continue;
      final name = (pack.name ?? '').trim();
      final label = name.isEmpty ? normalizedLocaleTag : name;
      languageLabels[normalizedLocaleTag] = label;
    }
    final languagePreference = localizationService.languagePreference;
    final normalizedLanguagePreference = languagePreference == 'system'
        ? 'system'
        : fontService.normalizeLocaleTag(languagePreference);
    final selectedLanguage =
        languageLabels.containsKey(normalizedLanguagePreference)
            ? normalizedLanguagePreference
            : 'system';
    final selectedThemeMode = clientConfig.getThemeMode();
    final langDir = '${clientConfig.baseDir}${Platform.pathSeparator}lang';
    final visibleLocaleTags = fontService.orderedEnabledLocaleTags(
      activeLocale: localizationService.effectiveLocale,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // 窗口大小设置
        _buildSection(
          context,
          searchId: 'appearanceWindowSize',
          title: t.appearanceWindowSizeSection,
          icon: CustomIcons.FluentIcons.full_screen,
          children: [
            _buildWindowSizeSettings(context, clientConfig),
          ],
        ),
        const SizedBox(height: 24),

        // UI 缩放设置
        _buildSection(
          context,
          searchId: 'appearanceUiScale',
          title: t.appearanceUiScaleSection,
          icon: CustomIcons.FluentIcons.font_size,
          children: [
            _buildSettingItem(
              context,
              searchId: 'appearanceUiScale',
              title: t.appearanceUiScaleTitle,
              subtitle: t.appearanceUiScaleSubtitle,
              trailing: SizedBox(
                width: 250,
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: clientConfig.getWindowScaleFactor(),
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        label:
                            '${(clientConfig.getWindowScaleFactor() * 100).toInt()}%',
                        onChanged: (value) async {
                          await clientConfig.setWindowScaleFactor(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${(clientConfig.getWindowScaleFactor() * 100).toInt()}%',
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Button(
                    onPressed: () async {
                      await clientConfig.setWindowScaleFactor(1.0);
                      if (mounted) {
                        NotificationManager.of(context)?.showInfo(
                          t.appearanceUiScaleResetTitle,
                          message: t.appearanceUiScaleResetMessage,
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.refresh, size: 14),
                        SizedBox(width: 6),
                        Text(t.appearanceUiScaleResetButton),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Button(
                    onPressed: () async {
                      await clientConfig.setWindowScaleFactor(1.25);
                      if (mounted) {
                        NotificationManager.of(context)?.showSuccess(
                          t.appearanceUiScaleApplyTitle,
                          message: t.appearanceUiScaleApplyMessage,
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.full_screen, size: 14),
                        SizedBox(width: 6),
                        Text(t.appearanceUiScale4kButton),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: FluentTheme.of(context)
                      .accentColor
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CustomIcons.FluentIcons.info,
                    size: 16,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.appearanceUiScaleHint,
                      style: FluentTheme.of(context)
                          .typography
                          .caption
                          ?.copyWith(
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.92),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 主题设置
        _buildSection(
          context,
          searchId: 'appearanceTheme',
          title: t.appearanceThemeSection,
          icon: CustomIcons.FluentIcons.color,
          children: [
            _buildSettingItem(
              context,
              searchId: 'appearanceThemeMode',
              title: t.appearanceThemeModeTitle,
              subtitle: t.appearanceThemeModeSubtitle,
              trailing: SizedBox(
                width: 250,
                child: ComboBox<String>(
                  value: selectedThemeMode,
                  items: [
                    ComboBoxItem(
                      value: 'system',
                      child: Text(t.appearanceThemeModeSystem),
                    ),
                    ComboBoxItem(
                      value: 'light',
                      child: Text(t.appearanceThemeModeLight),
                    ),
                    ComboBoxItem(
                      value: 'dark',
                      child: Text(t.appearanceThemeModeDark),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    await clientConfig.setThemeMode(value);
                    if (!mounted) {
                      return;
                    }
                    NotificationManager.of(context)?.showSuccess(
                      t.appearanceThemeSavedTitle,
                      message: t.appearanceThemeSavedMessage(
                          _getThemeModeName(value, t)),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              searchId: 'appearanceClassicControlVisuals',
              title: t.appearanceClassicControlVisualsTitle,
              subtitle: t.appearanceClassicControlVisualsSubtitle,
              trailing: ToggleSwitch(
                checked: clientConfig.getClassicControlVisuals(),
                onChanged: (value) async {
                  final notificationManager = NotificationManager.of(context);
                  final message = value
                      ? t.appearanceClassicControlVisualsEnabledMessage
                      : t.appearanceClassicControlVisualsDisabledMessage;
                  await clientConfig.setClassicControlVisuals(value);
                  if (!mounted) {
                    return;
                  }
                  notificationManager?.showSuccess(
                    t.appearanceClassicControlVisualsSavedTitle,
                    message: message,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 语言设置
        _buildSection(
          context,
          searchId: 'appearanceSectionLanguage',
          title: t.appearanceSectionLanguage,
          icon: CustomIcons.FluentIcons.globe,
          children: [
            _buildSettingItem(
              context,
              searchId: 'appearanceLanguage',
              title: t.appearanceLanguageTitle,
              subtitle: t.appearanceLanguageSubtitle,
              trailing: SizedBox(
                width: 250,
                child: ComboBox<String>(
                  value: selectedLanguage,
                  items: languageLabels.entries
                      .map(
                        (entry) => ComboBoxItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    await localizationService.setLanguagePreference(value);
                    if (mounted) {
                      // Wait for the next frame to ensure the new locale is applied
                      await Future.delayed(const Duration(milliseconds: 100));
                      if (!mounted) return;

                      // Get the new localization after language switch
                      final newT = AppLocalizations.of(context)!;
                      NotificationManager.of(context)?.showSuccess(
                        newT.appearanceLanguageSwitchedTitle,
                        message: value == 'system'
                            ? newT.appearanceLanguageSwitchedSystem
                            : newT.appearanceLanguageSwitchedTo(
                                languageLabels[value] ?? value),
                      );
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              searchId: 'appearanceLanguagePacks',
              title: t.appearanceLanguagePacksTitle,
              subtitle: t.appearanceLanguagePacksSubtitle(langDir),
              trailing: SizedBox(
                width: 250,
                child: Button(
                  onPressed: () async {
                    await localizationService.reloadLanguagePacks();
                    context.read<FontService>().updateLanguagePackDefaults(
                        localizationService.languagePacks);
                    await _loadAvailableFonts();
                    if (mounted) {
                      NotificationManager.of(context)?.showSuccess(
                        t.appearanceLanguagePacksRefreshedTitle,
                        message: t.appearanceLanguagePacksRefreshedMessage(
                          localizationService.languagePacks.length,
                        ),
                      );
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CustomIcons.FluentIcons.refresh, size: 14),
                      const SizedBox(width: 6),
                      Text(t.appearanceLanguageRefreshButton),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              searchId: 'developerOpenL10nFolder',
              title: t.developerOpenL10nFolderTitle,
              subtitle: t.developerOpenL10nFolderSubtitle,
              trailing: SizedBox(
                width: 250,
                child: Button(
                  onPressed: () async {
                    try {
                      final dir = Directory(langDir);
                      if (!await dir.exists()) {
                        await dir.create(recursive: true);
                      }
                      await Process.run('explorer', [langDir]);
                    } catch (e) {
                      if (mounted) {
                        NotificationManager.of(context)?.showError(
                          t.developerOpenL10nFolderFailedTitle,
                          message: t.developerOpenL10nFolderFailedMessage(
                              e.toString()),
                        );
                      }
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CustomIcons.FluentIcons.folder_open, size: 14),
                      const SizedBox(width: 6),
                      Text(t.developerOpenL10nFolderTitle),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 字体设置
        _buildSection(
          context,
          searchId: 'appearanceFont',
          title: t.appearanceFontSection,
          icon: CustomIcons.FluentIcons.font,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: FluentTheme.of(context)
                      .accentColor
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CustomIcons.FluentIcons.info,
                    size: 16,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _fontSectionHint(uiLocale),
                      style: FluentTheme.of(context)
                          .typography
                          .caption
                          ?.copyWith(
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.92),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final localeTag in visibleLocaleTags) ...[
              Builder(
                builder: (context) {
                  final activeLocale = localizationService.effectiveLocale;
                  final currentFont = fontService.effectiveFontForLocaleTag(
                    localeTag,
                    activeLocale: activeLocale,
                  );
                  final localeLabel = _displayLanguageLabel(
                      localeTag, languageLabels, uiLocale);
                  final title =
                      _fontLocaleTitle(uiLocale, localeTag, localeLabel);
                  final hasOverride =
                      fontService.hasFontOverrideForLocale(localeTag);

                  return _buildSettingItem(
                    context,
                    title: title,
                    subtitle: _localeFontSubtitle(
                      uiLocale,
                      fontService,
                      localeTag,
                      activeLocale,
                    ),
                    trailing: _loadingFonts
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        : SizedBox(
                            width: 340,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Button(
                                    onPressed: () =>
                                        _showLocaleFontPickerDialog(
                                      context,
                                      localeTag: localeTag,
                                      localeLabel: localeLabel,
                                      currentFont: currentFont,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            currentFont,
                                            style: TextStyle(
                                              fontFamily: currentFont,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          CustomIcons.FluentIcons.chevron_down,
                                          size: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (hasOverride) ...[
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: _fontLocaleResetTooltip(uiLocale),
                                    child: IconButton(
                                      icon: Icon(
                                        CustomIcons.FluentIcons.refresh,
                                        size: 14,
                                      ),
                                      onPressed: () => _resetLocaleFont(
                                        localeTag,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: Button(
                onPressed: _importCustomFont,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CustomIcons.FluentIcons.add, size: 14),
                    const SizedBox(width: 6),
                    Text(t.appearanceFontImportButton),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: FluentTheme.of(context)
                      .accentColor
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CustomIcons.FluentIcons.info,
                    size: 16,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fontLocaleCustomFontsTitle(uiLocale),
                          style: FluentTheme.of(context)
                              .typography
                              .bodyStrong
                              ?.copyWith(
                                color: AppTheme.textPrimary
                                    .withValues(alpha: 0.94),
                              ),
                        ),
                        const SizedBox(height: 6),
                        if (fontService.customFonts.isEmpty)
                          Text(
                            _fontLocaleNoCustomFonts(uiLocale),
                            style: FluentTheme.of(context)
                                .typography
                                .caption
                                ?.copyWith(
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.92),
                                ),
                          )
                        else
                          Column(
                            children: [
                              for (final fontName
                                  in (fontService.customFonts.keys.toList()
                                    ..sort((a, b) => a.toLowerCase().compareTo(
                                          b.toLowerCase(),
                                        ))))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fontName,
                                          style: TextStyle(
                                            fontFamily: fontName,
                                            color: AppTheme.textPrimary
                                                .withValues(alpha: 0.9),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Button(
                                        onPressed: () =>
                                            _removeCustomFont(fontName),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              CustomIcons.FluentIcons.delete,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              t.appearanceFontDeleteConfirmButton,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 窗口效果
        _buildSection(
          context,
          searchId: 'appearanceWindowEffects',
          title: t.appearanceWindowEffectsSection,
          icon: CustomIcons.FluentIcons.color,
          children: [
            _buildSettingItem(
              context,
              searchId: 'appearanceWindowEffects',
              title: t.appearanceWindowEffectsEnableTitle,
              subtitle: windowEffect.effectEnabled
                  ? t.appearanceWindowEffectsEnabledSubtitle
                  : t.appearanceWindowEffectsDisabledSubtitle,
              trailing: ToggleSwitch(
                checked: windowEffect.effectEnabled,
                onChanged: windowEffect.windowEffectsAvailable
                    ? (value) async {
                        await windowEffect.setEffectEnabled(value);
                        if (mounted) {
                          NotificationManager.of(context)?.showSuccess(
                            value
                                ? t.appearanceWindowEffectsEnabledTitle
                                : t.appearanceWindowEffectsDisabledTitle,
                            message: value
                                ? t.appearanceWindowEffectsEnabledMessage
                                : t.appearanceWindowEffectsDisabledMessage,
                          );
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: windowEffect.effectEnabled ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: !windowEffect.effectEnabled,
                child: _buildSettingItem(
                  context,
                  searchId: 'appearanceWindowEffectsType',
                  title: t.appearanceWindowEffectsTypeTitle,
                  subtitle:
                      _getEffectModeDescription(windowEffect.effectMode, t),
                  trailing: ComboBox<String>(
                    value: windowEffect.effectMode,
                    items: [
                      if (!windowEffect.isWindows11 ||
                          windowEffect.supportsWin11Acrylic)
                        ComboBoxItem(
                          value: 'acrylic',
                          child: Text(t.appearanceWindowEffectAcrylic),
                        ),
                      if (!windowEffect.isWindows11)
                        ComboBoxItem(
                          value: 'blur',
                          child: Text(t.appearanceWindowEffectBlur),
                        ),
                      // Mica 选项仅在 Win11 上显示
                      if (windowEffect.isWindows11) ...[
                        ComboBoxItem(
                          value: 'mica_main',
                          child: Text(t.appearanceWindowEffectMica),
                        ),
                        if (windowEffect.supportsMicaAlt)
                          ComboBoxItem(
                            value: 'mica_transient',
                            child: Text(t.appearanceWindowEffectMicaAlt),
                          ),
                      ],
                    ],
                    onChanged: (value) async {
                      if (value == null) return;

                      await windowEffect.setEffectMode(value);
                      if (mounted) {
                        NotificationManager.of(context)?.showSuccess(
                          t.appearanceWindowEffectSwitchedTitle,
                          message: _getEffectModeDescription(value, t),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
            // Acrylic / Mica / Mica Alt: fixed transparency — no slider.
            // Only Win10 Blur exposes adjustable tint alpha.
            if (windowEffect.supportsUserAlpha) ...[
              const SizedBox(height: 12),
              Opacity(
                opacity: windowEffect.effectEnabled ? 1.0 : 0.5,
                child: IgnorePointer(
                  ignoring: !windowEffect.effectEnabled,
                  child: _buildSettingItem(
                    context,
                    searchId: 'appearanceWindowEffectsAcrylicOpacity',
                    title: t.appearanceWindowEffectsAcrylicOpacityTitle,
                    subtitle: t.appearanceWindowEffectsAcrylicOpacityHint,
                    trailing: SizedBox(
                      width: 250,
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: windowEffect.blurAlpha.toDouble(),
                              min: 32,
                              max: 200,
                              divisions: 168,
                              label: windowEffect.blurAlpha.toString(),
                              onChanged: (v) async {
                                await windowEffect.setAlpha(v.toInt());
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${windowEffect.blurAlpha}',
                              style:
                                  FluentTheme.of(context).typography.bodyStrong,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            // Win10: suspend effect during drag (acrylic/blur lag while moving)
            if (!windowEffect.isWindows11 && windowEffect.effectEnabled) ...[
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                searchId: 'appearanceWindowEffectsDragSuspend',
                title: t.appearanceWindowEffectsDragSuspendTitle,
                subtitle: windowEffect.dragSuspend
                    ? t.appearanceWindowEffectsDragSuspendEnabledSubtitle
                    : t.appearanceWindowEffectsDragSuspendDisabledSubtitle,
                trailing: ToggleSwitch(
                  checked: windowEffect.dragSuspend,
                  onChanged: (value) async {
                    await windowEffect.setDragSuspend(value);
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              searchId: 'appearanceWindowEffectsRoundedCorners',
              title: t.appearanceWindowEffectsRoundedCornersTitle,
              subtitle: windowEffect.roundedCornersEnabled
                  ? t.appearanceWindowEffectsRoundedCornersEnabledSubtitle
                  : t.appearanceWindowEffectsRoundedCornersDisabledSubtitle,
              trailing: ToggleSwitch(
                checked: windowEffect.roundedCornersEnabled,
                onChanged: (value) async {
                  await windowEffect.setRoundedCornersEnabled(value);
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: effectStatusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: effectStatusColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    windowEffect.effectEnabled &&
                            windowEffect.nativeMaterialReady
                        ? CustomIcons.FluentIcons.completed_solid
                        : windowEffect.effectEnabled
                            ? CustomIcons.FluentIcons.error_badge
                            : CustomIcons.FluentIcons.info,
                    size: 16,
                    color: effectStatusColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      effectStatusText,
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: effectStatusColor,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 侧边栏设置
        _buildSection(
          context,
          searchId: 'appearanceSidebar',
          title: t.appearanceSidebarSection,
          icon: CustomIcons.FluentIcons.side_panel,
          children: [
            _buildSettingItem(
              context,
              searchId: 'appearanceSidebar',
              title: t.appearanceSidebarDefaultTitle,
              subtitle: t.appearanceSidebarDefaultSubtitle,
              trailing: ComboBox<bool>(
                value: clientConfig.getSidebarDefaultExpanded(),
                items: [
                  ComboBoxItem(
                      value: true,
                      child: Text(t.appearanceSidebarExpandedLabel)),
                  ComboBoxItem(
                      value: false,
                      child: Text(t.appearanceSidebarCollapsedLabel)),
                ],
                onChanged: (value) async {
                  if (value != null) {
                    await clientConfig.setSidebarDefaultExpanded(value);
                    if (mounted) {
                      final label = value
                          ? t.appearanceSidebarExpandedLabel
                          : t.appearanceSidebarCollapsedLabel;
                      NotificationManager.of(context)?.showSuccess(
                        t.appearanceSidebarSavedTitle,
                        message: t.appearanceSidebarSavedMessage(label),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 通知设置
        _buildSection(
          context,
          searchId: 'appearanceNotification',
          title: t.appearanceNotificationSection,
          icon: CustomIcons.FluentIcons.ringer,
          children: [
            _buildSettingItem(
              context,
              searchId: 'appearanceNotification',
              title: t.appearanceNotificationEnableTitle,
              subtitle: t.appearanceNotificationEnableSubtitle,
              trailing: ToggleSwitch(
                checked: _notificationEnabled,
                onChanged: (value) => _saveNotificationEnabled(value),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              searchId: 'appearanceNotificationScheme',
              title: t.appearanceNotificationSchemeTitle,
              subtitle:
                  _getNotificationColorSchemeName(_notificationColorScheme, t),
              trailing: ComboBox<String>(
                value: _notificationColorScheme,
                items: [
                  ComboBoxItem(
                    value: 'defaultScheme',
                    child: Text(t.appearanceNotificationSchemeDefaultOption),
                  ),
                  ComboBoxItem(
                    value: 'light',
                    child: Text(t.appearanceNotificationSchemeLightOption),
                  ),
                  ComboBoxItem(
                    value: 'dark',
                    child: Text(t.appearanceNotificationSchemeDarkOption),
                  ),
                  ComboBoxItem(
                    value: 'fluent2',
                    child: Text(t.appearanceNotificationSchemeFluent2Option),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _saveNotificationColorScheme(value);
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              searchId: 'appearanceNotificationPosition',
              title: t.appearanceNotificationPositionTitle,
              subtitle: _getNotificationPositionName(_notificationPosition, t),
              trailing: ComboBox<String>(
                value: _notificationPosition,
                items: [
                  ComboBoxItem(
                    value: 'topRight',
                    child: Text(t.appearanceNotificationPositionTopRightOption),
                  ),
                  ComboBoxItem(
                    value: 'bottomRight',
                    child:
                        Text(t.appearanceNotificationPositionBottomRightOption),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _saveNotificationPosition(value);
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              searchId: 'appearanceNotificationPerformance',
              title: t.appearanceNotificationPerformanceTitle,
              subtitle: _getPerformanceModeName(_performanceMode, t),
              trailing: ComboBox<String>(
                value: _performanceMode,
                items: [
                  ComboBoxItem(
                    value: 'performance',
                    child: Text(
                        t.appearanceNotificationPerformanceOptionPerformance),
                  ),
                  ComboBoxItem(
                    value: 'balanced',
                    child:
                        Text(t.appearanceNotificationPerformanceOptionBalanced),
                  ),
                  ComboBoxItem(
                    value: 'quality',
                    child:
                        Text(t.appearanceNotificationPerformanceOptionQuality),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _savePerformanceMode(value);
                },
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: FluentTheme.of(context)
                      .accentColor
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    CustomIcons.FluentIcons.info,
                    size: 16,
                    color: FluentTheme.of(context).accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.appearanceNotificationPerformanceHint,
                      style: FluentTheme.of(context)
                          .typography
                          .caption
                          ?.copyWith(
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.92),
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: t.appearanceNotificationPreviewButtonTitle,
              subtitle: t.appearanceNotificationPreviewButtonSubtitle,
              trailing: Button(
                onPressed: _showTestNotification,
                child: Text(t.appearanceNotificationPreviewButton),
              ),
            ),
            const SizedBox(height: 16),
            // 配色预览框
            _buildNotificationPreview(context),
          ],
        ),
        const SizedBox(height: 24),

        // 下载列表显示
        _buildSection(
          context,
          searchId: 'appearanceDownloadList',
          title: t.appearanceDownloadListSection,
          icon: CustomIcons.FluentIcons.list,
          children: [
            _buildSettingItem(
              context,
              searchId: 'appearanceSegmentsMode',
              title: t.appearanceSegmentsModeTitle,
              subtitle:
                  _getSegmentsDisplayModeDescription(_segmentsDisplayMode, t),
              trailing: ComboBox<String>(
                value: _segmentsDisplayMode,
                items: [
                  ComboBoxItem(
                    value: 'none',
                    child: Text(t.appearanceSegmentsModeNoneOption),
                  ),
                  ComboBoxItem(
                    value: 'merged',
                    child: Text(t.appearanceSegmentsModeMergedOption),
                  ),
                  ComboBoxItem(
                    value: 'list',
                    child: Text(t.appearanceSegmentsModeListOption),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _saveSegmentsDisplayMode(value);
                },
              ),
            ),
            const SizedBox(height: 12),
            // 列表模式的额外设置
            Opacity(
              opacity: _segmentsDisplayMode == 'list' ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: _segmentsDisplayMode != 'list',
                child: _buildSettingItem(
                  context,
                  searchId: 'appearanceSegmentsDefaultExpanded',
                  title: t.appearanceSegmentsDefaultExpandedTitle,
                  subtitle: t.appearanceSegmentsDefaultExpandedSubtitle,
                  trailing: ToggleSwitch(
                    checked: _segmentsDefaultExpanded,
                    onChanged: (value) => _saveSegmentsExpandedSetting(value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: _segmentsDisplayMode == 'list' ? 1.0 : 0.5,
              child: IgnorePointer(
                ignoring: _segmentsDisplayMode != 'list',
                child: _buildSettingItem(
                  context,
                  searchId: 'appearanceSegmentsMaxVisible',
                  title: t.appearanceSegmentsMaxVisibleTitle,
                  subtitle: t.appearanceSegmentsMaxVisibleSubtitle,
                  trailing: SizedBox(
                    width: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _segmentsMaxVisible.toDouble(),
                            min: 1,
                            max: 32,
                            divisions: 31,
                            label: _segmentsMaxVisible.toString(),
                            onChanged: (value) {
                              _saveSegmentsMaxVisibleSetting(value.toInt());
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '$_segmentsMaxVisible',
                            style:
                                FluentTheme.of(context).typography.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              searchId: 'appearanceSpeedChart',
              title: t.appearanceSpeedChartTitle,
              subtitle: t.appearanceSpeedChartSubtitle,
              trailing: ToggleSwitch(
                checked: _showSpeedChart,
                onChanged: (value) => _saveShowSpeedChart(value),
              ),
            ),
            // 速度曲线子设置（仅在开启时显示）
            if (_showSpeedChart) ...[
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                searchId: 'appearanceChartFrost',
                title: t.appearanceChartFrostTitle,
                subtitle: t.appearanceChartFrostSubtitle,
                trailing: ToggleSwitch(
                  checked: _showChartFrost,
                  onChanged: (value) => _saveShowChartFrost(value),
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                searchId: 'appearanceChartPosition',
                title: t.appearanceChartPositionTitle,
                subtitle: t.appearanceChartPositionSubtitle,
                trailing: ComboBox<String>(
                  value: _chartPosition,
                  items: [
                    ComboBoxItem(
                        value: 'low',
                        child: Text(t.appearanceChartPositionLow)),
                    ComboBoxItem(
                        value: 'mid',
                        child: Text(t.appearanceChartPositionMid)),
                    ComboBoxItem(
                        value: 'high',
                        child: Text(t.appearanceChartPositionHigh)),
                  ],
                  onChanged: (value) {
                    if (value != null) _saveChartPosition(value);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                searchId: 'appearanceChartColor',
                title: t.appearanceChartColorTitle,
                subtitle: t.appearanceChartColorSubtitle,
                trailing: ComboBox<String>(
                  value: _chartColor,
                  items: [
                    ComboBoxItem(
                        value: 'blue',
                        child: _buildColorOption(const Color(0xFF0078D4),
                            t.appearanceChartColorBlue)),
                    ComboBoxItem(
                        value: 'cyan',
                        child: _buildColorOption(const Color(0xFF60CDFF),
                            t.appearanceChartColorCyan)),
                    ComboBoxItem(
                        value: 'purple',
                        child: _buildColorOption(const Color(0xFF8B5CF6),
                            t.appearanceChartColorPurple)),
                    ComboBoxItem(
                        value: 'green',
                        child: _buildColorOption(const Color(0xFF10B981),
                            t.appearanceChartColorGreen)),
                    ComboBoxItem(
                        value: 'pink',
                        child: _buildColorOption(const Color(0xFFEC4899),
                            t.appearanceChartColorPink)),
                    ComboBoxItem(
                        value: 'orange',
                        child: _buildColorOption(const Color(0xFFF97316),
                            t.appearanceChartColorOrange)),
                  ],
                  onChanged: (value) {
                    if (value != null) _saveChartColor(value);
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildWindowSizeSettings(
      BuildContext context, ClientConfigService config) {
    final t = AppLocalizations.of(context)!;
    final rememberSize = config.getWindowRememberSize();
    final defaultWidth = config.getWindowDefaultWidth();
    final defaultHeight = config.getWindowDefaultHeight();
    // 直接获取当前窗口大小（每次构建时都获取最新值）
    final currentWidth = MediaQuery.of(context).size.width;
    final currentHeight = MediaQuery.of(context).size.height;

    // 使用缓存的屏幕尺寸
    final maxWidth = _screenWidth;
    final maxHeight = _screenHeight;

    // 确保默认值不超过屏幕大小
    final safeDefaultWidth = defaultWidth.clamp(600.0, maxWidth);
    final safeDefaultHeight = defaultHeight.clamp(400.0, maxHeight);

    // 如果还在加载屏幕尺寸，显示加载指示器
    if (_loadingScreenSize) {
      return const Center(
        child: ProgressRing(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingItem(
          context,
          searchId: 'appearanceWindowRemember',
          title: t.appearanceWindowRememberTitle,
          subtitle: rememberSize
              ? t.appearanceWindowRememberSubtitleOn
              : t.appearanceWindowRememberSubtitleOff,
          trailing: ToggleSwitch(
            checked: rememberSize,
            onChanged: (value) async {
              await config.setWindowRememberSize(value);
            },
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: rememberSize ? 0.5 : 1.0,
          child: IgnorePointer(
            ignoring: rememberSize,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingItem(
                  context,
                  searchId: 'appearanceWindowDefaultWidth',
                  title: t.appearanceWindowDefaultWidthTitle,
                  subtitle:
                      t.appearanceWindowDefaultWidthSubtitle(maxWidth.toInt()),
                  trailing: SizedBox(
                    width: 250,
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: safeDefaultWidth,
                            min: 600,
                            max: maxWidth,
                            divisions: ((maxWidth - 600) / 10).toInt(),
                            label: safeDefaultWidth.toInt().toString(),
                            onChanged: (value) async {
                              await config.setWindowDefaultWidth(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${safeDefaultWidth.toInt()}',
                            style:
                                FluentTheme.of(context).typography.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSettingItem(
                  context,
                  searchId: 'appearanceWindowDefaultHeight',
                  title: t.appearanceWindowDefaultHeightTitle,
                  subtitle: t
                      .appearanceWindowDefaultHeightSubtitle(maxHeight.toInt()),
                  trailing: SizedBox(
                    width: 250,
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: safeDefaultHeight,
                            min: 400,
                            max: maxHeight,
                            divisions: ((maxHeight - 400) / 10).toInt(),
                            label: safeDefaultHeight.toInt().toString(),
                            onChanged: (value) async {
                              await config.setWindowDefaultHeight(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${safeDefaultHeight.toInt()}',
                            style:
                                FluentTheme.of(context).typography.bodyStrong,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        onPressed: () async {
                          // 确保不超过屏幕大小
                          final safeWidth = currentWidth.clamp(600.0, maxWidth);
                          final safeHeight =
                              currentHeight.clamp(400.0, maxHeight);

                          // 同时更新默认大小和当前保存的大小
                          await config.setWindowDefaultWidth(safeWidth);
                          await config.setWindowDefaultHeight(safeHeight);
                          await config.setWindowSize(safeWidth, safeHeight);

                          if (mounted) {
                            NotificationManager.of(context)?.showSuccess(
                              t.appearanceWindowSaveTitle,
                              message: t.appearanceWindowSaveMessage(
                                safeWidth.toInt(),
                                safeHeight.toInt(),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CustomIcons.FluentIcons.save, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              t.appearanceWindowSaveButton(
                                currentWidth.toInt(),
                                currentHeight.toInt(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Button(
                        onPressed: () async {
                          // 同时重置默认大小和当前保存的大小
                          await config.setWindowDefaultWidth(889.0);
                          await config.setWindowDefaultHeight(586.0);
                          await config.setWindowSize(889.0, 586.0);

                          if (mounted) {
                            NotificationManager.of(context)?.showInfo(
                              t.appearanceWindowResetTitle,
                              message: t.appearanceWindowResetMessage,
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CustomIcons.FluentIcons.refresh, size: 14),
                            SizedBox(width: 6),
                            Text(t.appearanceWindowResetButton),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 立即应用默认大小按钮
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final targetWidth =
                          safeDefaultWidth.clamp(600.0, maxWidth);
                      final targetHeight =
                          safeDefaultHeight.clamp(400.0, maxHeight);
                      windowManager.setSize(Size(targetWidth, targetHeight));
                      NotificationManager.of(context)?.showSuccess(
                        t.appearanceWindowApplyTitle,
                        message: t.appearanceWindowApplyMessage(
                          targetWidth.toInt(),
                          targetHeight.toInt(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.full_screen, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          t.appearanceWindowApplyButton(
                            safeDefaultWidth.toInt(),
                            safeDefaultHeight.toInt(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: FluentTheme.of(context).accentColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                CustomIcons.FluentIcons.info,
                size: 16,
                color: FluentTheme.of(context).accentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rememberSize
                      ? t.appearanceWindowRememberHintOn
                      : t.appearanceWindowRememberHintOff,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary.withValues(alpha: 0.92),
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getSegmentsDisplayModeDescription(String mode, AppLocalizations t) {
    switch (mode) {
      case 'none':
        return t.appearanceSegmentsModeNoneDescription;
      case 'merged':
        return t.appearanceSegmentsModeMergedDescription;
      case 'list':
        return t.appearanceSegmentsModeListDescription;
      default:
        return '';
    }
  }

  String _getEffectModeDescription(String mode, AppLocalizations t) {
    switch (mode) {
      case 'none':
        return t.appearanceEffectNone;
      case 'blur':
        return t.appearanceEffectBlur;
      case 'acrylic':
        return t.appearanceEffectAcrylic;
      case 'mica_main':
        return t.appearanceEffectMica;
      case 'mica_transient':
        return t.appearanceEffectMicaAlt;
      default:
        return t.appearanceEffectUnknown;
    }
  }

  Widget _buildSection(
    BuildContext context, {
    String? searchId,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return SettingsSection(
      searchId: searchId,
      title: title,
      icon: icon,
      children: children,
    );
  }

  Widget _buildColorOption(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    String? searchId,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return SettingsItem(
      searchId: searchId,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

/// 字体选择对话框（带搜索功能）
class _FontPickerDialog extends StatefulWidget {
  final List<String> availableFonts;
  final String selectedFont;
  final Set<String> customFonts;
  final AppLocalizations t;

  const _FontPickerDialog({
    required this.availableFonts,
    required this.selectedFont,
    required this.customFonts,
    required this.t,
  });

  @override
  State<_FontPickerDialog> createState() => _FontPickerDialogState();
}

class _FontPickerDialogState extends State<_FontPickerDialog> {
  final _searchController = TextEditingController();
  late final List<_FontPickerEntry> _allFonts;
  late List<_FontPickerEntry> _filteredFonts;
  String? _hoveredFont;
  int _processedFonts = 0;
  bool _loadingSupportInfo = false;

  @override
  void initState() {
    super.initState();
    _allFonts = widget.availableFonts
        .map(
          (font) => _FontPickerEntry(
            key: font,
            displayName:
                font == 'system' ? widget.t.appearanceFontSystemLabel : font,
            previewFontFamily:
                font == 'system' ? FontService.systemFontFamily : font,
            isSystemAlias: font == 'system',
            isCustom: widget.customFonts.contains(font),
          ),
        )
        .toList();
    _filteredFonts = List<_FontPickerEntry>.from(_allFonts);
    _loadFontSupportInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFonts(String query) {
    final normalizedQuery = _normalizeFontSearchText(query);
    setState(() {
      if (normalizedQuery.isEmpty) {
        _filteredFonts = List<_FontPickerEntry>.from(_allFonts);
      } else {
        _filteredFonts = _allFonts
            .where((font) => _matchesQuery(font, normalizedQuery))
            .toList();
      }
    });
  }

  Future<void> _loadFontSupportInfo() async {
    if (!Platform.isWindows) {
      return;
    }

    setState(() {
      _loadingSupportInfo = true;
      _processedFonts = 0;
    });

    for (var i = 0; i < _allFonts.length; i++) {
      final entry = _allFonts[i];
      if (!entry.isCustom) {
        _allFonts[i] = entry.copyWith(
          supportedScripts:
              _detectFontSupportedScripts(entry.previewFontFamily),
        );
      }

      if (!mounted) {
        return;
      }

      final shouldRefresh =
          i == _allFonts.length - 1 || (i + 1) % 12 == 0 || i < 8;
      if (shouldRefresh) {
        setState(() {
          _processedFonts = i + 1;
        });
        _filterFonts(_searchController.text);
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loadingSupportInfo = false;
      _processedFonts = _allFonts.length;
    });
    _filterFonts(_searchController.text);
  }

  bool _matchesQuery(_FontPickerEntry entry, String normalizedQuery) {
    for (final token in _searchTokensForEntry(entry)) {
      if (_normalizeFontSearchText(token).contains(normalizedQuery)) {
        return true;
      }
    }
    return false;
  }

  Iterable<String> _searchTokensForEntry(_FontPickerEntry entry) sync* {
    yield entry.key;
    yield entry.displayName;
    yield entry.previewFontFamily;

    if (entry.isSystemAlias) {
      yield 'system';
      yield 'default';
      yield 'recommended';
      yield '系统字体';
      yield '默认字体';
      yield '推荐';
      yield 'segoe ui';
    }

    if (entry.isCustom) {
      yield 'custom';
      yield 'imported';
      yield '自定义';
      yield '导入';
    }

    for (final script in entry.supportedScripts) {
      for (final keyword in script.searchKeywords) {
        yield keyword;
      }
    }
  }

  List<String> _buildTags(_FontPickerEntry entry, Locale locale) {
    final tags = <String>[];

    if (entry.isSystemAlias) {
      tags.add(_fontPickerSystemFallbackLabel(locale));
    }

    if (entry.isCustom) {
      tags.add(_fontPickerCustomLabel(locale));
    }

    for (final script in entry.supportedScripts) {
      tags.add(script.label(locale));
    }

    return tags;
  }

  Widget _buildSupportTag(
    BuildContext context,
    String label, {
    required bool isSelected,
  }) {
    final theme = FluentTheme.of(context);
    final foregroundColor = isSelected
        ? theme.accentColor
        : theme.typography.caption?.color?.withValues(alpha: 0.88);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.accentColor.withValues(alpha: 0.12)
            : AppTheme.bgLayer2.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isSelected
              ? theme.accentColor.withValues(alpha: 0.3)
              : AppTheme.borderSubtle.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: theme.typography.caption?.copyWith(
          fontSize: 10,
          color: foregroundColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final dialogWidth = (mediaSize.width * 0.82).clamp(360.0, 440.0).toDouble();
    final dialogHeight =
        (mediaSize.height * 0.76).clamp(400.0, 520.0).toDouble();

    return ContentDialog(
      title: Text(widget.t.appearanceFontPickerTitle),
      constraints: BoxConstraints(
        maxWidth: dialogWidth,
        maxHeight: dialogHeight,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 搜索框
          TextBox(
            controller: _searchController,
            placeholder: widget.t.appearanceFontPickerSearchPlaceholder,
            prefix: Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(CustomIcons.FluentIcons.searchIcon, size: 16),
            ),
            suffix: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(CustomIcons.FluentIcons.clear, size: 14),
                    onPressed: () {
                      _searchController.clear();
                      _filterFonts('');
                    },
                  )
                : null,
            onChanged: _filterFonts,
          ),
          const SizedBox(height: 12),
          // 字体数量提示
          Row(
            children: [
              Text(
                widget.t.appearanceFontPickerCount(_filteredFonts.length),
                style: FluentTheme.of(context).typography.caption,
              ),
              const Spacer(),
              if (_loadingSupportInfo)
                Text(
                  _fontPickerLoadingLabel(
                    locale,
                    _processedFonts.clamp(0, _allFonts.length),
                    _allFonts.length,
                  ),
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: FluentTheme.of(context)
                            .accentColor
                            .withValues(alpha: 0.9),
                      ),
                ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  widget.t.appearanceFontPickerFilteredLabel,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: FluentTheme.of(context).accentColor,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // 字体列表
          Expanded(
            child: _filteredFonts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CustomIcons.FluentIcons.searchIcon,
                            size: 48, color: AppTheme.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          widget.t.appearanceFontPickerEmpty,
                          style: FluentTheme.of(context).typography.body,
                        ),
                      ],
                    ),
                  )
                : SmoothListView.builder(
                    config: SmoothScrollConfig.smooth,
                    itemCount: _filteredFonts.length,
                    itemBuilder: (context, index) {
                      final font = _filteredFonts[index];
                      final isSelected = font.key == widget.selectedFont;
                      final isHovered = font.key == _hoveredFont;
                      final tags = _buildTags(font, locale);

                      return MouseRegion(
                        onEnter: (_) => setState(() => _hoveredFont = font.key),
                        onExit: (_) => setState(() => _hoveredFont = null),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, font.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? FluentTheme.of(context)
                                      .accentColor
                                      .withValues(alpha: 0.2)
                                  : isHovered
                                      ? FluentTheme.of(context)
                                          .accentColor
                                          .withValues(alpha: 0.1)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: isSelected
                                  ? Border.all(
                                      color: FluentTheme.of(context)
                                          .accentColor
                                          .withValues(alpha: 0.5),
                                    )
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: 10,
                                      top: 2,
                                    ),
                                    child: Icon(
                                      CustomIcons.FluentIcons.check_mark,
                                      size: 14,
                                      color:
                                          FluentTheme.of(context).accentColor,
                                    ),
                                  ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        font.displayName,
                                        style: FluentTheme.of(context)
                                            .typography
                                            .body
                                            ?.copyWith(
                                              fontFamily:
                                                  font.previewFontFamily,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (tags.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            for (final tag in tags)
                                              _buildSupportTag(
                                                context,
                                                tag,
                                                isSelected: isSelected,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (font.isSystemAlias)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FluentTheme.of(context)
                                          .accentColor
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      widget.t.appearanceFontPickerRecommended,
                                      style: FluentTheme.of(context)
                                          .typography
                                          .caption
                                          ?.copyWith(
                                            color: FluentTheme.of(context)
                                                .accentColor,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.t.appearanceFontPickerCancel),
        ),
      ],
    );
  }
}
