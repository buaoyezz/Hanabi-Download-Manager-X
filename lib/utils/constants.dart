import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  // App Information
  static const String appName = 'Hanabi Download ManagerX';
  static const String channel = 'release';
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
  static const String kernelName2 = 'SodaDownloadKernel';
    // Kernel -Version
  static const String newKernelVersion = '2.2.1';
  static const String kernelVersion = '1.5.9';
    // Kernel -BuildNumber
  static const String newKernelBuildNumber = 'b260223-2-nsfx-r';
  static const String kernelBuildNumber = 'b260110-soda-r';
    // Kernel - FullName
  static const String newKernelFullName = 'NSFX (Next Speed Force X)';
  static const String kernelFullName = 'Soda Download Kernel';

  // API Endpoints
  static const String apiUrlMain = 'https://x.zzbuaoye.top/api/v1.json';
  static const String apiUrlBack = 'https://buaoyezz.github.io/hdmx_api_list/api_v1.json';

  // Contact & Links
  static const String officialUrl = 'https://x.zzbuaoye.top';
  static const String githubUrl = 'https://github.com/buaoyezz/Hanabi-Download-Manager-X';
  static const String contactEmail = 'zzbuaoye@gmail.com';
}
