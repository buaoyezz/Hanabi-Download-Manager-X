import 'package:package_info_plus/package_info_plus.dart';

// Application Metadata
abstract class AppInfo {
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
}

// =============================================================================
// Download Kernels & Build Specifications
// (Build Number): b{YYMMDD}-{kernel_code}-{channel_code}
// - '-r' -> Release 
// - '-b' -> Beta
// - '-a' -> Alpha   
// =============================================================================
abstract class KernelConstants {
  // --- NSFX ---
  static const String nsfxName = 'NSFX';
  static const String nsfxVersion = '3.0.0';
  static const String nsfxBuildNumber = 'b260724-nsfx3-r';
  static const String nsfxFullName = 'Next Speed Force X';

  // --- NeoNSF ---
  static const String neoName = 'NeoNSF';
  static const String neoVersion = '1.0.0';
  static const String neoBuildNumber = 'b260724-nnsf-b';
  static const String neoFullName = 'Neo Next Speed Force';

  /// (-r -> Release, -b -> Beta, -a -> Alpha)
  static String parseChannel(String buildNumber) {
    final lower = buildNumber.trim().toLowerCase();
    if (lower.endsWith('-r')) return 'Release';
    if (lower.endsWith('-b')) return 'Beta';
    if (lower.endsWith('-a')) return 'Alpha';
    return 'Release';
  }

  /// NSFX：Next Speed Force X / 3.0.0 / Release · Build b260724-nsfx3-r
  static String get nsfxFormattedString {
    final ch = parseChannel(nsfxBuildNumber);
    return '$nsfxFullName / $nsfxVersion / $ch · Build $nsfxBuildNumber';
  }

  /// NeoNSF：Neo Next Speed Force / 1.0.0 / Beta · Build b260724-nnsf-b
  static String get neoFormattedString {
    final ch = parseChannel(neoBuildNumber);
    return '$neoFullName / $neoVersion / $ch · Build $neoBuildNumber';
  }
}

// Default Settings
abstract class DefaultSettings {
  static const String downloadFolder = 'Downloads';
  static const int browserBridgePort = 6800;
  static const int logRetentionDays = 7;
  static const int maxConcurrentDownloads = 5;
}

// LINK AND CONTACT
abstract class LinksConstants {
  static const String officialUrl = 'https://x.zzbuaoye.net';
  static const String githubUrl =
      'https://github.com/buaoyezz/Hanabi-Download-Manager-X';
  static const String contactEmail = 'zzbuaoye@gmail.com';
}

// Constant
abstract class AppConstants {
  // App Info
  static String get appName => AppInfo.appName;
  static String get channel => AppInfo.channel;
  static String get developer => AppInfo.developer;
  static String get version => AppInfo.version;
  static Future<void> initialize() => AppInfo.initialize();

  // NSFX Kernel
  static String get kernelName => KernelConstants.nsfxName;
  static String get newKernelVersion => KernelConstants.nsfxVersion;
  static String get newKernelBuildNumber => KernelConstants.nsfxBuildNumber;
  static String get newKernelFullName => KernelConstants.nsfxFullName;
  static String get newKernelFullVersion =>
      '${KernelConstants.nsfxVersion} (${KernelConstants.nsfxBuildNumber})';
  static String get nsfxKernelFormattedString =>
      KernelConstants.nsfxFormattedString;

  // NeoNSF Kernel
  static String get neoKernelName => KernelConstants.neoName;
  static String get neoKernelVersion => KernelConstants.neoVersion;
  static String get neoKernelBuildNumber => KernelConstants.neoBuildNumber;
  static String get neoKernelFullName => KernelConstants.neoFullName;
  static String get neoKernelFullVersion =>
      '${KernelConstants.neoVersion} (${KernelConstants.neoBuildNumber})';
  static String get neoKernelFormattedString =>
      KernelConstants.neoFormattedString;

  // Helpers
  static String parseKernelChannel(String buildNumber) =>
      KernelConstants.parseChannel(buildNumber);

  // Defaults
  static String get defaultDownloadsDirName => DefaultSettings.downloadFolder;
  static int get defaultBrowserBridgePort => DefaultSettings.browserBridgePort;
  static int get defaultLogRetentionDays => DefaultSettings.logRetentionDays;
  static int get defaultMaxConcurrentDownloads =>
      DefaultSettings.maxConcurrentDownloads;

  // Links
  static String get officialUrl => LinksConstants.officialUrl;
  static String get githubUrl => LinksConstants.githubUrl;
  static String get contactEmail => LinksConstants.contactEmail;
}
