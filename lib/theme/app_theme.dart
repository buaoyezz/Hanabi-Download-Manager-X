import 'package:fluent_ui/fluent_ui.dart';

/// Hanabi Download Manager X 主题配置
/// Dev By ZZBuAoYe
/// 基于 Fluent Design 2 设计语言，优化 Mica 效果和一体化视觉
class AppTheme {
  // ============ 核心颜色系统 ============
  
  // 主色调 - Windows 11 风格蓝色
  static const Color accentPrimary = Color(0xFF0078D4);
  static const Color accentLight = Color(0xFF60CDFF);
  static const Color accentDark = Color(0xFF005A9E);
  
  // 背景色系 - 优化透明度以配合 Mica
  static const Color bgSolid = Color(0xFF202020);
  static const Color bgBase = Color(0xFF1A1A1A);  // 内容区基础背景色
  static const Color bgLayer1 = Color(0xFF2B2B2B);
  static const Color bgLayer2 = Color(0xFF323232);
  static const Color bgLayer3 = Color(0xFF3B3B3B);
  
  // Mica 效果专用色
  static const Color micaBase = Color(0xFF202020);
  static const Color micaLayer = Color(0xFF2B2B2B);
  
  // 表面色 - 卡片和容器（带透明度）
  static const Color surfaceCard = Color(0xFF2B2B2B);
  static const Color surfaceCardHover = Color(0xFF323232);
  static const Color surfaceCardPressed = Color(0xFF3B3B3B);
  
  // 边框色 - 更细腻的分隔
  static const Color borderSubtle = Color(0xFF3A3A3A);
  static const Color borderDefault = Color(0xFF4A4A4A);
  static const Color borderStrong = Color(0xFF5A5A5A);
  
  // 文字色
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textTertiary = Color(0xFF808080);
  static const Color textDisabled = Color(0xFF5C5C5C);
  
  // 状态色 - 更柔和的色调
  static const Color statusSuccess = Color(0xFF6CCB5F);
  static const Color statusWarning = Color(0xFFFFB900);
  static const Color statusError = Color(0xFFFF6B6B);
  static const Color statusInfo = Color(0xFF60CDFF);
  
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
  static const double radiusXl = 12.0;
  static const double radiusRound = 999.0;
  
  // ============ 阴影系统 ============
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.12),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.16),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.20),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowAccent(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ============ 主题数据 ============
  static FluentThemeData get fluentDarkTheme {
    return FluentThemeData(
      brightness: Brightness.dark,
      accentColor: AccentColor.swatch(const {
        'normal': accentPrimary,
        'dark': accentDark,
        'darker': Color(0xFF004578),
        'darkest': Color(0xFF003050),
        'light': Color(0xFF1890FF),
        'lighter': accentLight,
        'lightest': Color(0xFF99DCFF),
      }),
      scaffoldBackgroundColor: Colors.transparent,
      micaBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      typography: _buildTypography(),
      cardColor: surfaceCard,
      resources: const ResourceDictionary.dark(
        cardBackgroundFillColorDefault: surfaceCard,
        cardBackgroundFillColorSecondary: bgLayer1,
        subtleFillColorSecondary: surfaceCardHover,
        subtleFillColorTertiary: surfaceCardPressed,
        dividerStrokeColorDefault: borderSubtle,
        cardStrokeColorDefault: borderDefault,
        textFillColorPrimary: textPrimary,
        textFillColorSecondary: textSecondary,
        textFillColorTertiary: textTertiary,
        textFillColorDisabled: textDisabled,
      ),
      // 按钮样式
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
      // 切换开关样式
      toggleSwitchTheme: ToggleSwitchThemeData(
        checkedDecoration: WidgetStateProperty.all(
          BoxDecoration(
            color: accentPrimary,
            borderRadius: BorderRadius.circular(radiusRound),
          ),
        ),
        uncheckedDecoration: WidgetStateProperty.all(
          BoxDecoration(
            color: bgLayer3,
            borderRadius: BorderRadius.circular(radiusRound),
            border: Border.all(color: borderDefault),
          ),
        ),
      ),
      // 滑块样式
      sliderTheme: SliderThemeData(
        activeColor: WidgetStateProperty.all(accentPrimary),
        inactiveColor: WidgetStateProperty.all(bgLayer2),
        thumbColor: WidgetStateProperty.all(textPrimary),
      ),
      // 对话框样式
      dialogTheme: ContentDialogThemeData(
        decoration: BoxDecoration(
          color: bgLayer1.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(radiusLg),
          border: Border.all(color: borderSubtle),
          boxShadow: shadowLg,
        ),
        padding: const EdgeInsets.all(spacingXl),
      ),
      // 信息栏样式
      infoBarTheme: InfoBarThemeData(
        decoration: (severity) => BoxDecoration(
          color: _getInfoBarColor(severity),
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: _getInfoBarBorderColor(severity)),
        ),
      ),
    );
  }

  static FluentThemeData get fluentLightTheme {
    return FluentThemeData(
      brightness: Brightness.light,
      accentColor: Colors.blue,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      visualDensity: VisualDensity.standard,
      typography: _buildTypography(),
    );
  }
  
  static Typography _buildTypography() {
    return Typography.fromBrightness(
      brightness: Brightness.dark,
      color: textPrimary,
    );
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
  static BoxDecoration standard(BuildContext context, {bool isHovered = false}) {
    return BoxDecoration(
      color: isHovered ? AppTheme.surfaceCardHover : AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(
        color: isHovered ? AppTheme.borderStrong : AppTheme.borderSubtle,
        width: 1,
      ),
    );
  }
  
  static BoxDecoration elevated(BuildContext context, {bool isHovered = false}) {
    return BoxDecoration(
      color: isHovered ? AppTheme.surfaceCardHover : AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      border: Border.all(
        color: isHovered ? AppTheme.accentPrimary.withValues(alpha: 0.5) : AppTheme.borderSubtle,
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
