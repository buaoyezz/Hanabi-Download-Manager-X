import 'package:flutter/widgets.dart';

class AppLogoAssets {
  const AppLogoAssets._();

  static const main = 'assets/logo/logo.svg';
  static const blue = 'assets/logo/color_logo/blue_logo.svg';
  static const green = 'assets/logo/color_logo/green_logo.svg';
  static const orange = 'assets/logo/color_logo/orange_logo.svg';
  static const fallbackPng = 'assets/logo/logo.png';
}

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppLogoAssets.fallbackPng,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      semanticLabel: 'Hanabi Download ManagerX logo',
      errorBuilder: (_, __, ___) {
        return SizedBox(width: width, height: height);
      },
    );
  }
}
