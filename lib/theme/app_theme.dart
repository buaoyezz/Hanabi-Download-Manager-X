import 'package:fluent_ui/fluent_ui.dart';

class AppTheme {
  static const Color primaryBg = Color(0xFF1a1a1a);
  static const Color secondaryBg = Color(0xFF242424);
  static const Color cardBg = Color(0xFF2d2d2d);
  static const Color hoverBg = Color(0xFF353535);
  static const Color accentBlue = Color(0xFF0078d4);
  static const Color accentBlueDark = Color(0xFF005a9e);
  
  static FluentThemeData get fluentDarkTheme {
    return FluentThemeData(
      brightness: Brightness.dark,
      accentColor: AccentColor.swatch(const {
        'normal': accentBlue,
        'dark': accentBlueDark,
        'darker': Color(0xFF004578),
        'darkest': Color(0xFF003050),
        'light': Color(0xFF1890ff),
        'lighter': Color(0xFF40a9ff),
        'lightest': Color(0xFF69c0ff),
      }),
      scaffoldBackgroundColor: primaryBg,
      micaBackgroundColor: secondaryBg,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      typography: Typography.fromBrightness(
        brightness: Brightness.dark,
      ),
      cardColor: cardBg,
      resources: const ResourceDictionary.dark(
        cardBackgroundFillColorDefault: cardBg,
        cardBackgroundFillColorSecondary: secondaryBg,
        subtleFillColorSecondary: hoverBg,
        dividerStrokeColorDefault: Color(0xFF404040),
        cardStrokeColorDefault: Color(0xFF404040),
      ),
    );
  }

  static FluentThemeData get fluentLightTheme {
    return FluentThemeData(
      brightness: Brightness.light,
      accentColor: Colors.blue,
      scaffoldBackgroundColor: const Color(0xFFF3F3F3),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      typography: Typography.fromBrightness(
        brightness: Brightness.light,
      ),
    );
  }
}
