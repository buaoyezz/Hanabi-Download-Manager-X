import 'dart:ui' show PlatformDispatcher;

import 'package:fluent_ui/fluent_ui.dart';

enum AppThemeMode { system, light, dark }

extension AppThemeModeStorage on AppThemeMode {
  String get storageValue {
    return switch (this) {
      AppThemeMode.system => 'system',
      AppThemeMode.light => 'light',
      AppThemeMode.dark => 'dark',
    };
  }

  static AppThemeMode fromStorageValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
  }
}

class AppThemePalette {
  const AppThemePalette({
    required this.brightness,
    required this.accentLight,
    required this.accentDark,
    required this.bgSolid,
    required this.bgBase,
    required this.bgLayer1,
    required this.bgLayer2,
    required this.bgLayer3,
    required this.micaBase,
    required this.micaLayer,
    required this.surfaceCard,
    required this.surfaceCardHover,
    required this.surfaceCardPressed,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.shadowBase,
  });

  final Brightness brightness;
  final Color accentLight;
  final Color accentDark;
  final Color bgSolid;
  final Color bgBase;
  final Color bgLayer1;
  final Color bgLayer2;
  final Color bgLayer3;
  final Color micaBase;
  final Color micaLayer;
  final Color surfaceCard;
  final Color surfaceCardHover;
  final Color surfaceCardPressed;
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color shadowBase;

  static AppThemePalette lerp(
    AppThemePalette begin,
    AppThemePalette end,
    double t,
  ) {
    final progress = t.clamp(0.0, 1.0);
    Color color(Color a, Color b) => Color.lerp(a, b, progress)!;

    return AppThemePalette(
      brightness: progress < 0.5 ? begin.brightness : end.brightness,
      accentLight: color(begin.accentLight, end.accentLight),
      accentDark: color(begin.accentDark, end.accentDark),
      bgSolid: color(begin.bgSolid, end.bgSolid),
      bgBase: color(begin.bgBase, end.bgBase),
      bgLayer1: color(begin.bgLayer1, end.bgLayer1),
      bgLayer2: color(begin.bgLayer2, end.bgLayer2),
      bgLayer3: color(begin.bgLayer3, end.bgLayer3),
      micaBase: color(begin.micaBase, end.micaBase),
      micaLayer: color(begin.micaLayer, end.micaLayer),
      surfaceCard: color(begin.surfaceCard, end.surfaceCard),
      surfaceCardHover: color(begin.surfaceCardHover, end.surfaceCardHover),
      surfaceCardPressed:
          color(begin.surfaceCardPressed, end.surfaceCardPressed),
      borderSubtle: color(begin.borderSubtle, end.borderSubtle),
      borderDefault: color(begin.borderDefault, end.borderDefault),
      borderStrong: color(begin.borderStrong, end.borderStrong),
      textPrimary: color(begin.textPrimary, end.textPrimary),
      textSecondary: color(begin.textSecondary, end.textSecondary),
      textTertiary: color(begin.textTertiary, end.textTertiary),
      textDisabled: color(begin.textDisabled, end.textDisabled),
      shadowBase: color(begin.shadowBase, end.shadowBase),
    );
  }
}

/// Hanabi Download Manager X 主题配置
/// Dev By ZZBuAoYe
/// 基于 Fluent Design 2 设计语言，优化 Mica 效果和一体化视觉
class AppTheme {
  // ============ 核心颜色系统 ============

  // 主色调 - Fluent 2 更克制的蓝色
  static Color accentPrimary = const Color(0xFF0F6CBD);
  static const Color _originalAccentPrimary = Color(0xFF0F6CBD);

  static const Color statusSuccess = Color(0xFF6CCB5F);
  static const Color statusWarning = Color(0xFFFFB900);
  static const Color statusError = Color(0xFFFF6B6B);
  static const Color statusInfo = Color(0xFF60CDFF);

  static const AppThemePalette _darkPalette = AppThemePalette(
    brightness: Brightness.dark,
    accentLight: Color(0xFF60CDFF),
    accentDark: Color(0xFF005A9E),
    bgSolid: Color(0xFF202020),
    bgBase: Color(0xFF202020),
    bgLayer1: Color(0xFF2C2C2C),
    bgLayer2: Color(0xFF323232),
    bgLayer3: Color(0xFF3B3B3B),
    micaBase: Color(0xFF202020),
    micaLayer: Color(0x0DFFFFFF),
    surfaceCard: Color(0x0DFFFFFF),
    surfaceCardHover: Color(0x12FFFFFF),
    surfaceCardPressed: Color(0x08FFFFFF),
    borderSubtle: Color(0x0FFFFFFF),
    borderDefault: Color(0x12FFFFFF),
    borderStrong: Color(0x1AFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xC5FFFFFF),
    textTertiary: Color(0x8AFFFFFF),
    textDisabled: Color(0x5CFFFFFF),
    shadowBase: Color(0xFF000000),
  );

  static const AppThemePalette _classicDarkPalette = AppThemePalette(
    brightness: Brightness.dark,
    accentLight: Color(0xFF60CDFF),
    accentDark: Color(0xFF005A9E),
    bgSolid: Color(0xFF202020),
    bgBase: Color(0xFF1A1A1A),
    bgLayer1: Color(0xFF2B2B2B),
    bgLayer2: Color(0xFF323232),
    bgLayer3: Color(0xFF3B3B3B),
    micaBase: Color(0xFF202020),
    micaLayer: Color(0xFF2B2B2B),
    surfaceCard: Color(0xFF2B2B2B),
    surfaceCardHover: Color(0xFF323232),
    surfaceCardPressed: Color(0xFF3B3B3B),
    borderSubtle: Color(0xFF3A3A3A),
    borderDefault: Color(0xFF4A4A4A),
    borderStrong: Color(0xFF5A5A5A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFAAAAAA),
    textTertiary: Color(0xFF808080),
    textDisabled: Color(0xFF5C5C5C),
    shadowBase: Color(0xFF000000),
  );

  static const AppThemePalette _lightPalette = AppThemePalette(
    brightness: Brightness.light,
    accentLight: Color(0xFF115EA3),
    accentDark: Color(0xFF0B4F8C),
    bgSolid: Color(0xFFF3F8FC),
    bgBase: Color(0xFFF8FBFE),
    bgLayer1: Color(0xFFFFFFFF),
    bgLayer2: Color(0xFFEAF1F6),
    bgLayer3: Color(0xFFDDE7EF),
    micaBase: Color(0xFFF3F8FC),
    micaLayer: Color(0x80FFFFFF),
    surfaceCard: Color(0xB3FFFFFF),
    surfaceCardHover: Color(0x80FFFFFF),
    surfaceCardPressed: Color(0x4DFFFFFF),
    borderSubtle: Color(0x0F000000),
    borderDefault: Color(0x1A000000),
    borderStrong: Color(0x29000000),
    textPrimary: Color(0xE4000000),
    textSecondary: Color(0x9A000000),
    textTertiary: Color(0x73000000),
    textDisabled: Color(0x5C000000),
    shadowBase: Color(0xFF000000),
  );

  static AppThemePalette _activePalette = _darkPalette;
  static double _activeLightProgress = 0.0;
  static bool _classicControlVisuals = false;

  static const Color _lightShellBackground = Color(0xFFF3F8FC);
  static const Color _lightShellHoverBackground = Color(0xFFEAF1F6);
  static const Color _lightShellSelectedBackground = Color(0xFFDDE7EF);

  // ============ 间距系统 ============
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXxl = 24.0;

  // ============ 圆角系统 ============
  static const double radiusSm = 4.0;
  static const double radiusMd = 6.0;
  static const double radiusLg = 8.0;
  static const double radiusXl = 8.0;
  static const double radiusRound = 999.0;

  static bool get classicControlVisuals => _classicControlVisuals;

  static void applyBrightness(
    Brightness brightness, {
    bool? classicControlVisuals,
  }) {
    if (classicControlVisuals != null) {
      _classicControlVisuals = classicControlVisuals;
    }
    _activePalette = paletteFor(
      brightness,
      classicControlVisuals: _classicControlVisuals,
    );
    _activeLightProgress = brightness == Brightness.light ? 1.0 : 0.0;
  }

  static void applyPluginOverrides(Map<String, dynamic>? overrides) {
    if (overrides == null || overrides.isEmpty) {
      // Reset to original
      accentPrimary = _originalAccentPrimary;
      // You can add more resets here as needed
      return;
    }

    final colors = overrides['colors'];
    if (colors is Map) {
      final primaryStr = colors['primary']?.toString();
      if (primaryStr != null && primaryStr.isNotEmpty) {
        accentPrimary = _parseColor(primaryStr) ?? _originalAccentPrimary;
      }
    }
  }

  static Color? _parseColor(String colorStr) {
    var hexColor = colorStr.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    if (hexColor.length == 8) {
      return Color(int.parse(hexColor, radix: 16));
    }
    return null;
  }

  static void applyFluentTheme(
    FluentThemeData theme, {
    bool? classicControlVisuals,
  }) {
    if (classicControlVisuals != null) {
      _classicControlVisuals = classicControlVisuals;
    }
    if (_classicControlVisuals && theme.brightness == Brightness.dark) {
      _activeLightProgress = 0.0;
      _activePalette = _classicDarkPalette;
      return;
    }
    if (theme.brightness == Brightness.light) {
      _activeLightProgress = 1.0;
      _activePalette = _lightPalette;
      return;
    }
    _activeLightProgress = _lightProgressForFluentTheme(theme);
    _activePalette = AppThemePalette.lerp(
      _darkPalette,
      _lightPalette,
      _activeLightProgress,
    );
  }

  static double _lightProgressForFluentTheme(FluentThemeData theme) {
    final darkAlpha = _darkPalette.surfaceCard.a;
    final lightAlpha = _lightPalette.surfaceCard.a;
    final alphaRange = lightAlpha - darkAlpha;
    if (alphaRange.abs() < 0.001) {
      return theme.brightness == Brightness.light ? 1.0 : 0.0;
    }
    return ((theme.cardColor.a - darkAlpha) / alphaRange).clamp(0.0, 1.0);
  }

  static AppThemePalette paletteFor(
    Brightness brightness, {
    bool? classicControlVisuals,
  }) {
    final useClassic = classicControlVisuals ?? _classicControlVisuals;
    if (brightness == Brightness.dark && useClassic) {
      return _classicDarkPalette;
    }
    return brightness == Brightness.dark ? _darkPalette : _lightPalette;
  }

  static AppThemePalette of(BuildContext context) {
    return paletteFor(FluentTheme.of(context).brightness);
  }

  static bool isDarkContext(BuildContext context) {
    return FluentTheme.of(context).brightness == Brightness.dark;
  }

  static Brightness resolveBrightness(
    AppThemeMode mode, {
    Brightness? platformBrightness,
  }) {
    return switch (mode) {
      AppThemeMode.light => Brightness.light,
      AppThemeMode.dark => Brightness.dark,
      AppThemeMode.system =>
        platformBrightness ?? PlatformDispatcher.instance.platformBrightness,
    };
  }

  static FluentThemeData themeDataForMode(
    AppThemeMode mode, {
    Brightness? platformBrightness,
    bool? classicControlVisuals,
  }) {
    return themeDataForBrightness(
      resolveBrightness(mode, platformBrightness: platformBrightness),
      classicControlVisuals: classicControlVisuals,
    );
  }

  static FluentThemeData themeDataForBrightness(
    Brightness brightness, {
    bool? classicControlVisuals,
  }) {
    if (classicControlVisuals != null) {
      _classicControlVisuals = classicControlVisuals;
    }
    return _buildFluentTheme(
      paletteFor(
        brightness,
        classicControlVisuals: classicControlVisuals,
      ),
    );
  }

  static Color get accentLight => _activePalette.accentLight;
  static Color get accentDark => _activePalette.accentDark;
  static Color get bgSolid => _activePalette.bgSolid;
  static Color get bgBase => _activePalette.bgBase;
  static Color get bgLayer1 => _activePalette.bgLayer1;
  static Color get bgLayer2 => _activePalette.bgLayer2;
  static Color get bgLayer3 => _activePalette.bgLayer3;
  static Color get micaBase => _activePalette.micaBase;
  static Color get micaLayer => _activePalette.micaLayer;
  static Color get surfaceCard => _activePalette.surfaceCard;
  static Color get surfaceCardHover => _activePalette.surfaceCardHover;
  static Color get surfaceCardPressed => _activePalette.surfaceCardPressed;
  static Color get borderSubtle => _activePalette.borderSubtle;
  static Color get borderDefault => _activePalette.borderDefault;
  static Color get borderStrong => _activePalette.borderStrong;
  static Color get textPrimary => _activePalette.textPrimary;
  static Color get textSecondary => _activePalette.textSecondary;
  static Color get textTertiary => _activePalette.textTertiary;
  static Color get textDisabled => _activePalette.textDisabled;
  static double get lightProgress => _activeLightProgress;
  static Color get shellBackground => Color.lerp(
        _activeDarkPalette.bgSolid,
        _lightShellBackground,
        _activeLightProgress,
      )!;

  static Color get shellHoverBackground => Color.lerp(
        _activeDarkPalette.bgLayer2,
        _lightShellHoverBackground,
        _activeLightProgress,
      )!;

  static AppThemePalette get _activeDarkPalette =>
      _classicControlVisuals ? _classicDarkPalette : _darkPalette;

  static Color shellNavItemBackground({
    required double hoverValue,
    required double selectedValue,
  }) {
    final darkAlpha =
        (selectedValue * 0.8 + hoverValue * 0.4 * (1 - selectedValue))
            .clamp(0.0, 0.8);
    final lightAlpha =
        (selectedValue + hoverValue * (1 - selectedValue)).clamp(0.0, 1.0);
    final lightColor = Color.lerp(
      _lightShellHoverBackground,
      _lightShellSelectedBackground,
      selectedValue.clamp(0.0, 1.0),
    )!;

    return Color.lerp(
      _activeDarkPalette.bgLayer2.withValues(alpha: darkAlpha),
      lightColor.withValues(alpha: lightAlpha),
      _activeLightProgress,
    )!;
  }

  static Color cardBackground({
    double darkAlpha = 0.76,
    double lightAlpha = 0.86,
  }) {
    return Color.lerp(
      _activeDarkPalette.bgLayer1.withValues(alpha: darkAlpha),
      _lightPalette.surfaceCard.withValues(alpha: lightAlpha),
      _activeLightProgress,
    )!;
  }

  static Color cardHoverBackground({
    double darkAlpha = 0.86,
    double lightAlpha = 0.95,
  }) {
    return Color.lerp(
      _activeDarkPalette.bgLayer2.withValues(alpha: darkAlpha),
      _lightPalette.surfaceCard.withValues(alpha: lightAlpha),
      _activeLightProgress,
    )!;
  }

  // ============ 阴影系统 ============
  static List<BoxShadow> get shadowSm => _shadowSm(_activePalette);

  static List<BoxShadow> get shadowMd => _shadowMd(_activePalette);

  static List<BoxShadow> get shadowLg => _shadowLg(_activePalette);

  static List<BoxShadow> shadowAccent(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ============ 主题数据 ============
  static FluentThemeData get fluentDarkTheme =>
      themeDataForBrightness(Brightness.dark);

  static FluentThemeData get fluentLightTheme =>
      themeDataForBrightness(Brightness.light);

  static FluentThemeData _buildFluentTheme(AppThemePalette colors) {
    final accentColor = AccentColor.swatch(
      {
        'normal': accentPrimary,
        'dark': colors.accentDark,
        'darker': colors.brightness == Brightness.dark
            ? const Color(0xFF004578)
            : const Color(0xFF073B69),
        'darkest': colors.brightness == Brightness.dark
            ? const Color(0xFF003050)
            : const Color(0xFF052C4F),
        'light': colors.brightness == Brightness.dark
            ? const Color(0xFF1890FF)
            : const Color(0xFF2A7FD1),
        'lighter': colors.brightness == Brightness.dark
            ? colors.accentLight
            : const Color(0xFF479EF5),
        'lightest': colors.brightness == Brightness.dark
            ? const Color(0xFF99DCFF)
            : const Color(0xFFEBF3FC),
      },
    );

    final resources = colors.brightness == Brightness.dark
        ? ResourceDictionary.dark(
            cardBackgroundFillColorDefault: colors.surfaceCard,
            cardBackgroundFillColorSecondary: colors.bgLayer1,
            subtleFillColorSecondary: colors.surfaceCardHover,
            subtleFillColorTertiary: colors.surfaceCardPressed,
            dividerStrokeColorDefault: colors.borderSubtle,
            cardStrokeColorDefault: colors.borderDefault,
            textFillColorPrimary: colors.textPrimary,
            textFillColorSecondary: colors.textSecondary,
            textFillColorTertiary: colors.textTertiary,
            textFillColorDisabled: colors.textDisabled,
          )
        : ResourceDictionary.light(
            cardBackgroundFillColorDefault: colors.surfaceCard,
            cardBackgroundFillColorSecondary: colors.bgLayer1,
            subtleFillColorSecondary: colors.surfaceCardHover,
            subtleFillColorTertiary: colors.surfaceCardPressed,
            dividerStrokeColorDefault: colors.borderSubtle,
            cardStrokeColorDefault: colors.borderDefault,
            textFillColorPrimary: colors.textPrimary,
            textFillColorSecondary: colors.textSecondary,
            textFillColorTertiary: colors.textTertiary,
            textFillColorDisabled: colors.textDisabled,
          );

    return FluentThemeData(
      brightness: colors.brightness,
      accentColor: accentColor,
      scaffoldBackgroundColor: Colors.transparent,
      micaBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      typography: _buildTypography(colors),
      cardColor: colors.surfaceCard,
      resources: resources,
      buttonTheme: ButtonThemeData(
        defaultButtonStyle: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
        filledButtonStyle: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ),
        ),
      ),
      toggleSwitchTheme: ToggleSwitchThemeData(
        checkedDecoration: WidgetStateProperty.all(
          BoxDecoration(
            color: accentPrimary,
            borderRadius: BorderRadius.circular(radiusRound),
          ),
        ),
        uncheckedDecoration: WidgetStateProperty.all(
          BoxDecoration(
            color: colors.bgLayer3,
            borderRadius: BorderRadius.circular(radiusRound),
            border: Border.all(color: colors.borderDefault),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeColor: WidgetStateProperty.all(accentPrimary),
        inactiveColor: WidgetStateProperty.all(colors.bgLayer2),
        thumbColor: WidgetStateProperty.all(
          colors.brightness == Brightness.dark
              ? colors.textPrimary
              : colors.bgLayer1,
        ),
      ),
      dialogTheme: ContentDialogThemeData(
        decoration: BoxDecoration(
          color: colors.bgLayer1,
          borderRadius: BorderRadius.circular(radiusLg),
          border: Border.all(color: colors.borderSubtle),
          boxShadow: colors.brightness == Brightness.dark
              ? _shadowLg(colors)
              : _shadowMd(colors),
        ),
        padding: const EdgeInsets.all(spacingXl),
      ),
      infoBarTheme: InfoBarThemeData(
        decoration: (severity) => BoxDecoration(
          color: _getInfoBarColor(severity),
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: _getInfoBarBorderColor(severity)),
        ),
      ),
    );
  }

  static Typography _buildTypography(AppThemePalette colors) {
    return Typography.fromBrightness(
      brightness: colors.brightness,
      color: colors.textPrimary,
    );
  }

  static List<BoxShadow> _shadowSm(AppThemePalette colors) {
    return [
      BoxShadow(
        color: colors.shadowBase.withValues(
          alpha: colors.brightness == Brightness.dark ? 0.12 : 0.06,
        ),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> _shadowMd(AppThemePalette colors) {
    return [
      BoxShadow(
        color: colors.shadowBase.withValues(
          alpha: colors.brightness == Brightness.dark ? 0.16 : 0.08,
        ),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];
  }

  static List<BoxShadow> _shadowLg(AppThemePalette colors) {
    return [
      BoxShadow(
        color: colors.shadowBase.withValues(
          alpha: colors.brightness == Brightness.dark ? 0.20 : 0.10,
        ),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ];
  }

  static Color _getInfoBarColor(InfoBarSeverity severity) {
    switch (severity) {
      case InfoBarSeverity.info:
        return statusInfo.withValues(alpha: 0.15);
      case InfoBarSeverity.warning:
        return statusWarning.withValues(alpha: 0.15);
      case InfoBarSeverity.error:
        return statusError.withValues(alpha: 0.15);
      case InfoBarSeverity.success:
        return statusSuccess.withValues(alpha: 0.15);
    }
  }

  static Color _getInfoBarBorderColor(InfoBarSeverity severity) {
    switch (severity) {
      case InfoBarSeverity.info:
        return statusInfo.withValues(alpha: 0.3);
      case InfoBarSeverity.warning:
        return statusWarning.withValues(alpha: 0.3);
      case InfoBarSeverity.error:
        return statusError.withValues(alpha: 0.3);
      case InfoBarSeverity.success:
        return statusSuccess.withValues(alpha: 0.3);
    }
  }
}

/// 通用卡片装饰
class AppCardDecoration {
  static BoxDecoration standard(BuildContext context,
      {bool isHovered = false}) {
    final isDark = AppTheme.isDarkContext(context);
    return BoxDecoration(
      color: isHovered ? AppTheme.surfaceCardHover : AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(
        color: isDark
            ? (isHovered ? AppTheme.borderStrong : AppTheme.borderSubtle)
            : (isHovered ? AppTheme.borderDefault : AppTheme.borderSubtle),
        width: 1,
      ),
      boxShadow: isDark ? null : (isHovered ? AppTheme.shadowSm : null),
    );
  }

  static BoxDecoration elevated(BuildContext context,
      {bool isHovered = false}) {
    final isDark = AppTheme.isDarkContext(context);
    return BoxDecoration(
      color: isHovered ? AppTheme.surfaceCardHover : AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(
        color: isHovered
            ? AppTheme.accentPrimary.withValues(alpha: isDark ? 0.5 : 0.20)
            : (isDark
                ? AppTheme.borderSubtle
                : AppTheme.borderSubtle.withValues(alpha: 0.88)),
        width: isHovered ? 1.5 : 1,
      ),
      boxShadow: isHovered ? AppTheme.shadowMd : AppTheme.shadowSm,
    );
  }

  static BoxDecoration accent(BuildContext context, {double opacity = 0.15}) {
    return BoxDecoration(
      color: AppTheme.accentPrimary.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(
        color: AppTheme.accentPrimary.withValues(alpha: 0.3),
      ),
    );
  }
}

/// 状态指示器颜色
class StatusColors {
  static Color forStatus(String status) {
    switch (status.toLowerCase()) {
      case 'downloading':
      case '下载中':
        return AppTheme.accentPrimary;
      case 'completed':
      case '已完成':
        return AppTheme.statusSuccess;
      case 'paused':
      case '已暂停':
        return AppTheme.textTertiary;
      case 'pending':
      case '等待中':
        return AppTheme.statusWarning;
      case 'failed':
      case '失败':
        return AppTheme.statusError;
      default:
        return AppTheme.textSecondary;
    }
  }
}
