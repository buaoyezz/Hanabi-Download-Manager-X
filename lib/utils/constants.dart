import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  // App Information
  static const String appName = 'Hanabi Download ManagerX';
  static const String channel = 'alpha';
  static const String developer = 'ZZBuAoYe';

  static const String _versionFallback = '0.0.0';
  static String _version = _versionFallback;
  static bool _versionLoaded = false;

  static String get version => _version;

  static Future<void> initialize() async {
    if (_versionLoaded) return;

    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
    } catch (_) {
      _version = _versionFallback;
    } finally {
      _versionLoaded = true;
    }
  }

  // Kernel Information
  static const String kernelName = 'NextSpeedForceXKernel';
  static const String newKernelVersion = '2.5.0';
  static const String newKernelBuildNumber = 'b260417-nsfx-r';
  static const String newKernelFullName = 'NSFX (Next Speed Force X)';

  // // API Endpoints
  // static const String apiUrlMain = 'https://x.zzbuaoye.top/api/v1.json';
  // static const String apiUrlBack =
  //     'https://buaoyezz.github.io/hdmx_api_list/';

  // Contact & Links
  static const String officialUrl = 'https://x.zzbuaoye.top';
  static const String githubUrl =
      'https://github.com/buaoyezz/Hanabi-Download-Manager-X';
  static const String contactEmail = 'zzbuaoye@gmail.com';
}
