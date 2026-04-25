import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart'; // Import appWindow

import 'package:provider/provider.dart';
import '../../main.dart'; // Import systemTrayService
import '../../services/integrated_download_service.dart';
import '../../services/kernel/kernel_manager.dart';
import '../../services/developer_mode_service.dart';
import '../../services/client_config_service.dart';
import '../../services/clipboard_listener_service.dart';
import '../../services/font_service.dart';
import '../../services/performance_monitor_service.dart';
import '../../services/app_logger_service.dart';
import '../../widgets/folder_picker_dialog.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/temp_files_dialog.dart';
import '../../widgets/smooth_scroll_wrapper.dart';
import '../../services/auto_start_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as custom_icons;
import '../../utils/constants.dart';
import '../../l10n/app_localizations.dart';
import 'appearance_settings_page.dart';
import 'developer_settings_page.dart';
import 'update_page.dart';
import '../../widgets/animated_notifications.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class GetUserName extends StatefulWidget {
  const GetUserName({super.key});

  @override
  State<GetUserName> createState() => _GetUserNameState();
}

class _GetUserNameState extends State<GetUserName> {
  late final Future<String> _userNameFuture;

  @override
  void initState() {
    super.initState();
    _userNameFuture = _getUserName();
  }

  Future<String> _getUserName() async {
    try {
      final userName =
          Platform.environment['USERNAME'] ?? Platform.environment['USER'];
      if (userName != null && userName.isNotEmpty) {
        return userName;
      }
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_name') ?? '';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return FutureBuilder<String>(
      future: _userNameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(t.settingsUserLoading);
        }

        if (snapshot.hasError) {
          return Text(t.settingsUserLoadFailed);
        }

        final value = snapshot.data ?? '';
        return Text(value.isNotEmpty ? value : t.settingsUserUnknown);
      },
    );
  }
}

class _UaPack {
  final String id;
  final String name;
  final String userAgent;
  final bool builtIn;

  const _UaPack({
    required this.id,
    required this.name,
    required this.userAgent,
    this.builtIn = false,
  });
}

class _SettingsPageState extends State<SettingsPage> {
  AppLocalizations get t => AppLocalizations.of(context)!;

  // Tab state
  int _currentTabIndex = 0;
  final ScrollController _tabScrollController =
      createSmoothScrollController(config: SmoothScrollConfig.fast);

  // Download configuration state
  int _threads = 8;
  int _segments = 8;
  String _mode = 'auto'; // auto, threads_only, segments_only, manual
  int _maxConcurrentTasks = 3;
  int _segmentSpeedLimit = 0;
  int _globalSpeedLimit = 0;
  String _conflictStrategy = 'increment'; // increment | timestamp | overwrite
  bool _enableDynamicSegments = true;
  bool _showHttpConnectivityBadges = false;
  bool _loadingConfig = true;

  // Proxy configuration state
  bool _useProxy = false;
  String _proxyType = 'system'; // system, http, socks5
  String _proxyHost = '';
  int _proxyPort = 7897;
  String _proxyUsername = '';
  String _proxyPassword = '';
  bool _proxyRequiresAuth = false;

  String _defaultUserAgent = 'NSFX/2.0 (Next Speed Force X)';
  String _manualDefaultUserAgent = 'NSFX/2.0 (Next Speed Force X)';
  String _httpVersionPolicy = 'auto';
  final TextEditingController _defaultUserAgentController =
      TextEditingController();
  final TextEditingController _uaPackNameController = TextEditingController();
  final TextEditingController _uaPackValueController = TextEditingController();

  static const String _manualUaPackId = 'manual';
  static const List<_UaPack> _builtinUaPacks = [
    _UaPack(
      id: 'hanabi_nsfx',
      name: 'Hanabi / NSFX',
      userAgent: 'NSFX/2.0 (Next Speed Force X)',
      builtIn: true,
    ),
    _UaPack(
      id: 'chrome_win',
      name: 'Chrome (Windows)',
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36',
      builtIn: true,
    ),
    _UaPack(
      id: 'edge_win',
      name: 'Edge (Windows)',
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36 Edg/134.0.0.0',
      builtIn: true,
    ),
    _UaPack(
      id: 'firefox_win',
      name: 'Firefox (Windows)',
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0',
      builtIn: true,
    ),
    _UaPack(
      id: 'safari_mac',
      name: 'Safari (macOS)',
      userAgent:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_6_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15',
      builtIn: true,
    ),
  ];
  List<_UaPack> _customUaPacks = const [];
  String _selectedUaPackId = _manualUaPackId;

  bool _autoStart = true;
  bool _openOnStartup = false;
  final _autoStartService = AutoStartService();
  bool _notifyOnComplete = true;
  String _downloadPath = '';
  String _closeButtonBehavior = 'minimize_to_tray';
  bool _showTrayRunningStatus = false;
  bool _enablePopupWindow = true;
  bool _enableClipboardListener = true;
  int _browserExtensionPort = ClientConfigService.defaultBrowserExtensionPort;

  // Status monitoring
  bool _kernelOnline = false;
  List<_BrowserExtensionStatus> _browserExtensionStatuses = const [];
  Timer? _statusTimer;

  String _currentKernelName = 'NSFX (Next Speed Force X)';

  DeveloperModeService? _devModeService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
      _loadUaPacks();
      _loadDownloadPath();
      _startStatusMonitoring();
      _loadAutoStartSettings();
      _loadBehaviorSettings();
      _loadKernelSettings();

      _devModeService =
          Provider.of<DeveloperModeService>(context, listen: false);
      _devModeService?.addListener(_onDeveloperModeChanged);
    });
  }

  void _onDeveloperModeChanged() {
    if (_devModeService != null &&
        !_devModeService!.developerMode &&
        _currentTabIndex == 5) {
      setState(() {
        _currentTabIndex = 4;
      });
    }
  }

  Future<void> _loadKernelSettings() async {
    final kernelManager = KernelManager();

    if (mounted) {
      setState(() {
        _currentKernelName = kernelManager.kernelName;
      });
    }
  }

  Future<void> _loadAutoStartSettings() async {
    if (!Platform.isWindows) return;

    final enabled = await _autoStartService.isAutoStartEnabled();
    if (mounted) {
      setState(() {
        _openOnStartup = enabled;
      });

      if (enabled) {
        _verifyAutoStartPath();
      }
    }
  }

  Future<void> _loadBehaviorSettings() async {
    try {
      final config = Provider.of<ClientConfigService>(context, listen: false);
      final closeButtonBehavior = config.getCloseButtonBehavior();
      final showTrayRunningStatus = config.getShowTrayRunningStatus();
      final enablePopupWindow = config.getEnablePopupWindow();
      final enableClipboardListener = config.getEnableClipboardListener();
      final browserExtensionPort = config.getBrowserExtensionPort();

      if (mounted) {
        setState(() {
          _closeButtonBehavior = closeButtonBehavior;
          _showTrayRunningStatus = showTrayRunningStatus;
          _enablePopupWindow = enablePopupWindow;
          _enableClipboardListener = enableClipboardListener;
          _browserExtensionPort = browserExtensionPort;
        });
      }
    } catch (e) {
      debugPrint('Error loading behavior settings: $e');
    }
  }

  Future<void> _verifyAutoStartPath() async {
    final isCorrect = await _autoStartService.isRegisteredPathCorrect();
    if (!isCorrect && mounted) {
      // 路径不正确，尝试自动修复
      final fixed = await _autoStartService.verifyAndFixAutoStart();
      if (fixed && mounted) {
        final t = AppLocalizations.of(context)!;
        NotificationManager.of(context)?.showSuccess(
          t.settingsAutoStartFixedTitle,
          message: t.settingsAutoStartFixedMessage,
        );
      }
    }
  }

  Future<void> _toggleOpenOnStartup(bool value) async {
    final t = AppLocalizations.of(context)!;
    if (!Platform.isWindows) return;

    bool success;
    if (value) {
      success = await _autoStartService.enableAutoStart();
    } else {
      success = await _autoStartService.disableAutoStart();
    }

    if (success && mounted) {
      setState(() {
        _openOnStartup = value;
      });
      NotificationManager.of(context)?.showSuccess(
        value
            ? t.settingsAutoStartEnabledTitle
            : t.settingsAutoStartDisabledTitle,
        message: value
            ? t.settingsAutoStartEnabledMessage
            : t.settingsAutoStartDisabledMessage,
      );
    } else if (mounted) {
      NotificationManager.of(context)?.showError(
        t.settingsSaveFailedTitle,
        message: value
            ? t.settingsAutoStartEnableFailed
            : t.settingsAutoStartDisableFailed,
      );
    }
  }

  Future<void> _saveShowTrayRunningStatus(bool value) async {
    try {
      final t = AppLocalizations.of(context)!;
      final config = Provider.of<ClientConfigService>(context, listen: false);
      await config.setShowTrayRunningStatus(value);

      if (mounted) {
        setState(() {
          _showTrayRunningStatus = value;
        });

        systemTrayService.updateToolTip(!appWindow.isVisible);

        NotificationManager.of(context)?.showSuccess(
          value
              ? t.settingsTrayHintEnabledTitle
              : t.settingsTrayHintDisabledTitle,
          message: value
              ? t.settingsTrayHintEnabledMessage
              : t.settingsTrayHintDisabledMessage,
        );
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        NotificationManager.of(context)?.showError(
          t.settingsSaveFailedTitle,
          message: t.settingsSaveFailedMessage(e.toString()),
        );
      }
    }
  }

  Future<void> _saveEnablePopupWindow(bool value) async {
    try {
      final t = AppLocalizations.of(context)!;
      final config = Provider.of<ClientConfigService>(context, listen: false);
      await config.setEnablePopupWindow(value);

      if (mounted) {
        setState(() {
          _enablePopupWindow = value;
        });

        NotificationManager.of(context)?.showSuccess(
          value ? t.settingsPopupEnabledTitle : t.settingsPopupDisabledTitle,
          message: value
              ? t.settingsPopupEnabledMessage
              : t.settingsPopupDisabledMessage,
        );
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        NotificationManager.of(context)?.showError(
          t.settingsSaveFailedTitle,
          message: t.settingsPopupSaveFailedMessage(e.toString()),
        );
      }
    }
  }

  Future<void> _saveEnableClipboardListener(bool value) async {
    try {
      final t = AppLocalizations.of(context)!;
      final config = Provider.of<ClientConfigService>(context, listen: false);
      await config.setEnableClipboardListener(value);

      if (mounted) {
        setState(() {
          _enableClipboardListener = value;
        });

        NotificationManager.of(context)?.showSuccess(
          value
              ? t.settingsClipboardListenerEnabledTitle
              : t.settingsClipboardListenerDisabledTitle,
          message: value
              ? t.settingsClipboardListenerEnabledMessage
              : t.settingsClipboardListenerDisabledMessage,
        );

        if (value) {
          unawaited(
            ClipboardListenerService.activeInstance
                ?.promptFromCurrentClipboard(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        NotificationManager.of(context)?.showError(
          t.settingsSaveFailedTitle,
          message: t.settingsSaveFailedMessage(e.toString()),
        );
      }
    }
  }

  Future<void> _saveCloseButtonBehavior(String behavior) async {
    try {
      final t = AppLocalizations.of(context)!;
      final config = Provider.of<ClientConfigService>(context, listen: false);
      await config.setCloseButtonBehavior(behavior);

      if (mounted) {
        setState(() {
          _closeButtonBehavior = behavior;
        });

        NotificationManager.of(context)?.showSuccess(
          t.settingsSaveSuccessTitle,
          message: t.settingsCloseBehaviorSavedMessage(
            _getCloseButtonBehaviorDescription(behavior, t),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final t = AppLocalizations.of(context)!;
        NotificationManager.of(context)?.showError(
          t.settingsSaveFailedTitle,
          message: t.settingsSaveFailedMessage(e.toString()),
        );
      }
    }
  }

  Future<void> _showBrowserExtensionPortDialog() async {
    final controller =
        TextEditingController(text: _browserExtensionPort.toString());
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => ContentDialog(
        title: Text(t.settingsBrowserExtensionPortDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.settingsBrowserExtensionPortDialogPrompt),
            const SizedBox(height: 12),
            TextBox(
              controller: controller,
              placeholder: t.settingsBrowserExtensionPortPlaceholder,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                t.settingsBrowserExtensionPortHintBody,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.settingsCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(t.settingsConfirmButton),
          ),
        ],
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final parsed = int.tryParse(result.trim());
    if (parsed == null ||
        !ClientConfigService.isValidBrowserExtensionPortValue(parsed)) {
      NotificationManager.of(context)?.showError(
        t.settingsBrowserExtensionPortInvalidTitle,
        message: t.settingsBrowserExtensionPortInvalidMessage(
          ClientConfigService.minBrowserExtensionPort,
          ClientConfigService.maxBrowserExtensionPort,
        ),
      );
      return;
    }

    await _saveBrowserExtensionPort(parsed);
  }

  Future<void> _saveBrowserExtensionPort(int value) async {
    final normalized = ClientConfigService.normalizeBrowserExtensionPortValue(
      value,
    );
    final config = Provider.of<ClientConfigService>(context, listen: false);
    final kernelManager = Provider.of<KernelManager>(context, listen: false);
    final currentPort = config.getBrowserExtensionPort();

    if (normalized == currentPort) {
      if (mounted) {
        setState(() {
          _browserExtensionPort = normalized;
        });
      }
      return;
    }

    try {
      final rebound = await kernelManager.updateBrowserBridgePort(
        normalized,
        compatibilityPorts: [
          currentPort,
          ...config.getBrowserExtensionCompatibilityPorts(),
        ],
      );

      if (!rebound) {
        throw Exception('bridge_rebind_failed');
      }

      await config.setBrowserExtensionPort(normalized);

      if (mounted) {
        setState(() {
          _browserExtensionPort = normalized;
        });
      }

      NotificationManager.of(context)?.showSuccess(
        t.settingsSaveSuccessTitle,
        message: t.settingsBrowserExtensionPortSavedMessage(normalized),
      );
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError(
          t.settingsSaveFailedTitle,
          message:
              t.settingsBrowserExtensionPortSaveFailedMessage(e.toString()),
        );
      }
    }
  }

  String _getCloseButtonBehaviorDescription(
      String behavior, AppLocalizations t) {
    switch (behavior) {
      case 'minimize_to_tray':
        return t.settingsCloseBehaviorMinimize;
      case 'exit_app':
        return t.settingsCloseBehaviorExit;
      default:
        return t.settingsCloseBehaviorUnknown;
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();

    _devModeService?.removeListener(_onDeveloperModeChanged);
    _tabScrollController.dispose();
    _defaultUserAgentController.dispose();
    _uaPackNameController.dispose();
    _uaPackValueController.dispose();
    super.dispose();
  }

  void _startStatusMonitoring() {
    _checkStatus();

    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;

    final kernelManager = KernelManager();
    final newKernelName = kernelManager.kernelName;
    var newKernelOnline = false;
    var newBrowserExtensionStatuses = const <_BrowserExtensionStatus>[];

    if (kernelManager.isRunning) {
      final status = await _fetchBrowserBridgeStatus();
      newKernelOnline = status.kernelOnline;
      newBrowserExtensionStatuses = status.browserExtensions;
    }

    if (mounted &&
        (newKernelOnline != _kernelOnline ||
            !_browserExtensionStatusesEqual(
              newBrowserExtensionStatuses,
              _browserExtensionStatuses,
            ) ||
            newKernelName != _currentKernelName)) {
      setState(() {
        _kernelOnline = newKernelOnline;
        _browserExtensionStatuses = newBrowserExtensionStatuses;
        _currentKernelName = newKernelName;
      });
    }
  }

  bool _browserExtensionStatusesEqual(
    List<_BrowserExtensionStatus> a,
    List<_BrowserExtensionStatus> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].title != b[i].title) {
        return false;
      }
    }
    return true;
  }

  Future<_BrowserBridgeStatus> _fetchBrowserBridgeStatus() async {
    final port = context.read<ClientConfigService>().getBrowserExtensionPort();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);

    try {
      final healthRequest = await client
          .getUrl(Uri.parse('http://127.0.0.1:$port/health'))
          .timeout(const Duration(seconds: 2));
      final healthResponse = await healthRequest.close().timeout(
            const Duration(seconds: 2),
          );
      final healthBody = await healthResponse.transform(utf8.decoder).join();
      final healthJson = jsonDecode(healthBody);
      final kernelOnline = healthResponse.statusCode == 200 &&
          healthJson is Map &&
          healthJson['status'] == 'ok' &&
          healthJson['running'] == true;

      if (!kernelOnline) {
        return const _BrowserBridgeStatus(kernelOnline: false);
      }

      final statsPort = _resolveBrowserBridgeStatsPort(
        healthJson,
        fallbackPort: port,
      );
      final browserExtensions = <String, _BrowserExtensionStatus>{};
      try {
        final statsRequest = await client
            .getUrl(Uri.parse('http://127.0.0.1:$statsPort/stats/online'))
            .timeout(const Duration(seconds: 2));
        final statsResponse = await statsRequest.close().timeout(
              const Duration(seconds: 2),
            );
        final statsBody = await statsResponse.transform(utf8.decoder).join();
        final statsJson = jsonDecode(statsBody);

        if (statsResponse.statusCode == 200 && statsJson is Map) {
          final data = statsJson['data'];
          final devices = data is Map ? data['devices'] : null;
          if (devices is List) {
            for (final device in devices) {
              if (device is! Map) continue;
              final browserStatus = _browserExtensionStatusFromDevice(device);
              if (browserStatus != null) {
                browserExtensions[browserStatus.id] = browserStatus;
              }
            }
          }
        }
      } catch (_) {
        // Keep the kernel status from /health even if the optional extension
        // activity endpoint is temporarily unavailable.
      }
      final sortedBrowserExtensions = browserExtensions.values.toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      return _BrowserBridgeStatus(
        kernelOnline: true,
        browserExtensions: List.unmodifiable(sortedBrowserExtensions),
      );
    } catch (_) {
      return const _BrowserBridgeStatus(kernelOnline: false);
    } finally {
      client.close(force: true);
    }
  }

  int _resolveBrowserBridgeStatsPort(
    Object? healthJson, {
    required int fallbackPort,
  }) {
    if (healthJson is! Map) return fallbackPort;

    final apiPort = int.tryParse('${healthJson['api_port'] ?? ''}');
    if (apiPort != null &&
        ClientConfigService.isValidBrowserExtensionPortValue(apiPort)) {
      return apiPort;
    }

    return fallbackPort;
  }

  _BrowserExtensionStatus? _browserExtensionStatusFromDevice(
    Map<dynamic, dynamic> device,
  ) {
    final rawDeviceInfo = device['device_info'];
    final deviceInfo = rawDeviceInfo is Map ? rawDeviceInfo : const {};
    final deviceType = deviceInfo['deviceType']?.toString().toLowerCase();
    final summary = device['device_summary']?.toString() ?? '';

    if (deviceType != null &&
        deviceType.isNotEmpty &&
        deviceType != 'browser_extension') {
      return null;
    }

    final browserKind = deviceInfo['browserKind']?.toString() ?? '';
    final browser = deviceInfo['browser']?.toString() ?? '';
    final userAgent = deviceInfo['userAgent']?.toString() ?? '';
    final probe = '$browserKind $browser $userAgent $summary'.toLowerCase();

    if (probe.contains('firefox')) {
      return const _BrowserExtensionStatus(
        id: 'firefox',
        title: 'Firefox Extension',
        sortOrder: 30,
      );
    }
    if (probe.contains(' edg/') ||
        probe.contains(' edga/') ||
        probe.contains(' edgios/') ||
        probe.contains('edge')) {
      return const _BrowserExtensionStatus(
        id: 'edge',
        title: 'Edge Extension',
        sortOrder: 20,
      );
    }
    if (probe.contains('chrome')) {
      return const _BrowserExtensionStatus(
        id: 'chrome',
        title: 'Chrome Extension',
        sortOrder: 10,
      );
    }
    if (probe.contains('chromium')) {
      return const _BrowserExtensionStatus(
        id: 'chromium',
        title: 'Chromium Extension',
        sortOrder: 15,
      );
    }

    final fallbackName = browser.trim().isNotEmpty
        ? browser.trim()
        : summary.trim().isNotEmpty
            ? summary.trim().split(' on ').first
            : '';
    if (fallbackName.isEmpty) return null;

    return _BrowserExtensionStatus(
      id: fallbackName.toLowerCase(),
      title: '$fallbackName Extension',
      sortOrder: 100,
    );
  }

  Future<void> _loadDownloadPath() async {
    if (!mounted) return;

    try {
      final kernelManager = context.read<KernelManager>();
      final path = await kernelManager.getDownloadDir();

      if (path != null && mounted) {
        setState(() {
          _downloadPath = path;
        });
      }
    } catch (e) {
      debugPrint('Error loading download path: $e');
    }
  }

  Future<void> _changeDownloadPath() async {
    await _showManualPathInput();
  }

  Future<void> _showManualPathInput() async {
    final controller = TextEditingController(text: _downloadPath);
    final t = AppLocalizations.of(context)!;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => ContentDialog(
        title: Text(t.settingsDownloadPathDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.settingsDownloadPathDialogPrompt),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: controller,
                    placeholder: t.settingsDownloadPathPlaceholder,
                  ),
                ),
                const SizedBox(width: 8),
                Button(
                  onPressed: () async {
                    final selectedPath = await showDialog<String>(
                      context: context,
                      barrierDismissible: true,
                      builder: (context) => FolderPickerDialog(
                        initialPath: controller.text.isNotEmpty
                            ? controller.text
                            : _downloadPath,
                      ),
                    );

                    if (selectedPath != null && selectedPath.isNotEmpty) {
                      controller.text = selectedPath;
                    }
                  },
                  child: Text(t.settingsBrowseButton),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.settingsDownloadPathHintTitle,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: FluentTheme.of(context).accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.settingsDownloadPathHintBody,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.settingsCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(t.settingsConfirmButton),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final kernelManager = context.read<KernelManager>();
      final success = await kernelManager.setDownloadDir(result);

      if (success && mounted) {
        setState(() {
          _downloadPath = result;
        });

        if (mounted) {
          NotificationManager.of(context)?.showSuccess(
            t.settingsSaveSuccessTitle,
            message: t.settingsDownloadPathChangedMessage(result),
          );
        }
      } else {
        if (mounted) {
          NotificationManager.of(context)?.showError(
            t.settingsSaveFailedTitle,
            message: t.settingsDownloadPathChangeFailedMessage,
          );
        }
      }
    }

    controller.dispose();
  }

  List<_UaPack> get _allUaPacks => [..._builtinUaPacks, ..._customUaPacks];

  String get _resolvedSelectedUaPackId {
    if (_selectedUaPackId == _manualUaPackId) {
      return _manualUaPackId;
    }
    return _findUaPackById(_selectedUaPackId) == null
        ? _manualUaPackId
        : _selectedUaPackId;
  }

  _UaPack? _findUaPackById(String id) {
    for (final pack in _allUaPacks) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  void _syncSelectedUaPackInState() {
    if (_selectedUaPackId == _manualUaPackId) {
      return;
    }

    final selected = _findUaPackById(_selectedUaPackId);
    if (selected != null && selected.userAgent == _defaultUserAgent) {
      return;
    }

    for (final pack in _allUaPacks) {
      if (pack.userAgent == _defaultUserAgent) {
        _selectedUaPackId = pack.id;
        return;
      }
    }
    _selectedUaPackId = _manualUaPackId;
  }

  bool get _hasCustomUaInput => _uaPackValueController.text.trim().isNotEmpty;

  bool get _isCustomUaInputValid {
    if (!_hasCustomUaInput) return true;
    return _isLikelyValidUserAgent(_uaPackValueController.text);
  }

  bool get _isChineseLocale =>
      Localizations.localeOf(context).languageCode == 'zh';

  String get _invalidUaFormatTitle => _isChineseLocale
      ? 'UA\u683C\u5F0F\u4E0D\u6B63\u786E'
      : 'Invalid UA Format';

  String get _invalidUaFormatMessage => _isChineseLocale
      ? '\u8BF7\u68C0\u67E5 UA \u5B57\u7B26\u4E32\u683C\u5F0F\u3002'
      : 'Please review the UA string format.';

  String get _uaPreviewLabel => _isChineseLocale ? '\u9884\u89C8' : 'Preview';

  String get _uaEditLabel => _isChineseLocale ? '\u4FEE\u6539' : 'Edit';

  String get _uaEditDialogTitle => _isChineseLocale
      ? '\u4FEE\u6539\u81EA\u5B9A\u4E49 UA \u5305'
      : 'Edit Custom UA Pack';

  String get _uaPreviewDialogTitle =>
      _isChineseLocale ? '\u9884\u89C8 UA \u5305' : 'UA Pack Preview';

  String get _uaNameExistsMessage => _isChineseLocale
      ? '\u540D\u79F0\u5DF2\u5B58\u5728\uFF0C\u8BF7\u66F4\u6362'
      : 'Name already exists. Please choose another name.';

  String get _uaEditSavedTitle =>
      _isChineseLocale ? 'UA \u5305\u5DF2\u4FEE\u6539' : 'UA Pack Updated';

  String get _uaFormatValidLabel =>
      _isChineseLocale ? '\u683C\u5F0F\u6B63\u786E' : 'Format valid';

  String get _uaFormatInvalidLabel =>
      _isChineseLocale ? '\u683C\u5F0F\u9519\u8BEF' : 'Format invalid';

  Widget _buildCustomUaValidationIcon() {
    if (!_hasCustomUaInput) {
      return const SizedBox.shrink();
    }

    final isValid = _isCustomUaInputValid;
    return Icon(
      isValid ? FluentIcons.check_mark : FluentIcons.error_badge,
      size: 16,
      color: isValid ? AppTheme.statusSuccess : AppTheme.statusError,
    );
  }

  bool _isLikelyValidUserAgent(String input) {
    final ua = input.trim();
    if (ua.isEmpty || ua.length < 6 || ua.length > 512) return false;
    if (RegExp(r'[\r\n\t]').hasMatch(ua)) return false;

    // Most UA strings include at least one token like Product/Version.
    final tokenPattern =
        RegExp(r'[A-Za-z][A-Za-z0-9._-]*/[0-9A-Za-z][0-9A-Za-z._-]*');
    if (!tokenPattern.hasMatch(ua)) return false;

    // Basic parenthesis balance check to catch malformed comments.
    var balance = 0;
    for (final rune in ua.runes) {
      if (rune == 40) {
        balance++;
      } else if (rune == 41) {
        balance--;
        if (balance < 0) return false;
      }
    }
    return balance == 0;
  }

  bool _uaNeedsPreview({
    required BuildContext context,
    required String ua,
    required TextStyle? style,
    required double maxWidth,
  }) {
    final value = ua.trim();
    if (value.isEmpty) return false;
    final width = (maxWidth.isFinite && maxWidth > 0) ? maxWidth : 320.0;
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      maxLines: 1,
      ellipsis: '...',
      textDirection: Directionality.of(context),
    )..layout(maxWidth: width);
    return painter.didExceedMaxLines;
  }

  Future<void> _loadUaPacks() async {
    if (!mounted) return;

    final clientConfig = context.read<ClientConfigService>();
    final customRaw = clientConfig.getCustomUaPacks();
    final selectedId = clientConfig.getSelectedUaPackId();
    final customPacks = <_UaPack>[];

    for (final item in customRaw) {
      final id = item['id']?.toString().trim() ?? '';
      final name = item['name']?.toString().trim() ?? '';
      final userAgent = item['user_agent']?.toString().trim() ?? '';
      if (id.isEmpty || name.isEmpty || userAgent.isEmpty) continue;
      customPacks.add(
        _UaPack(
          id: id,
          name: name,
          userAgent: userAgent,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _customUaPacks = customPacks;
      _selectedUaPackId =
          selectedId.trim().isEmpty ? _manualUaPackId : selectedId;
      _syncSelectedUaPackInState();
    });
  }

  Future<void> _persistCustomUaPacks(List<_UaPack> packs) async {
    final clientConfig = context.read<ClientConfigService>();
    final payload = packs
        .map(
          (pack) => <String, dynamic>{
            'id': pack.id,
            'name': pack.name,
            'user_agent': pack.userAgent,
          },
        )
        .toList();
    await clientConfig.saveCustomUaPacks(payload);
  }

  Future<void> _selectUaPack(String id) async {
    final clientConfig = context.read<ClientConfigService>();
    if (id == _manualUaPackId) {
      final manualUa = _manualDefaultUserAgent.trim().isEmpty
          ? 'NSFX/2.0 (Next Speed Force X)'
          : _manualDefaultUserAgent.trim();
      await clientConfig.setSelectedUaPackId(_manualUaPackId);
      if (mounted) {
        setState(() {
          _selectedUaPackId = _manualUaPackId;
          _defaultUserAgentController.text = manualUa;
        });
      }
      await _updateConfig(defaultUserAgent: manualUa);
      return;
    }

    final pack = _findUaPackById(id);
    if (pack == null) return;

    final currentManualUa = _defaultUserAgentController.text.trim();
    if (currentManualUa.isNotEmpty) {
      _manualDefaultUserAgent = currentManualUa;
      await clientConfig.setManualUaValue(currentManualUa);
    }

    await clientConfig.setSelectedUaPackId(id);
    if (mounted) {
      setState(() {
        _selectedUaPackId = id;
      });
    }
    await _updateConfig(defaultUserAgent: pack.userAgent);
  }

  Future<void> _addCustomUaPack() async {
    final name = _uaPackNameController.text.trim();
    final rawUserAgent = _uaPackValueController.text.trim();
    if (name.isEmpty || rawUserAgent.isEmpty) return;

    if (!_isLikelyValidUserAgent(rawUserAgent)) {
      NotificationManager.of(context)?.showError(
        _invalidUaFormatTitle,
        message: _invalidUaFormatMessage,
      );
      return;
    }

    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    final next = [
      ..._customUaPacks.where((p) => p.name != name),
      _UaPack(id: id, name: name, userAgent: rawUserAgent),
    ];
    await _persistCustomUaPacks(next);

    if (!mounted) return;
    setState(() {
      _customUaPacks = next;
      _uaPackNameController.clear();
      _uaPackValueController.clear();
    });
    await _selectUaPack(id);
  }

  Future<void> _removeCustomUaPack(String id) async {
    final next = _customUaPacks.where((p) => p.id != id).toList();
    final removedSelected = _selectedUaPackId == id;
    final clientConfig = context.read<ClientConfigService>();
    await _persistCustomUaPacks(next);

    if (removedSelected) {
      await clientConfig.setSelectedUaPackId(_manualUaPackId);
    }

    if (!mounted) return;
    setState(() {
      _customUaPacks = next;
      if (removedSelected) {
        _selectedUaPackId = _manualUaPackId;
      }
    });
  }

  void _previewCustomUaPack(_UaPack pack) {
    final valid = _isLikelyValidUserAgent(pack.userAgent);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return ContentDialog(
          title: Text(_uaPreviewDialogTitle),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.name,
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      valid ? FluentIcons.check_mark : FluentIcons.error_badge,
                      size: 14,
                      color:
                          valid ? AppTheme.statusSuccess : AppTheme.statusError,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      valid ? _uaFormatValidLabel : _uaFormatInvalidLabel,
                      style: FluentTheme.of(context).typography.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLayer2.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: AppTheme.borderSubtle.withValues(alpha: 0.55),
                    ),
                  ),
                  child: SelectableText(
                    pack.userAgent,
                    style: FluentTheme.of(context).typography.caption,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context)!.settingsCancelButton),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editCustomUaPack(_UaPack pack) async {
    final t = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: pack.name);
    final uaController = TextEditingController(text: pack.userAgent);
    String? errorText;

    final updated = await showDialog<_UaPack>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final uaInput = uaController.text.trim();
            final hasUaInput = uaInput.isNotEmpty;
            final uaValid = !hasUaInput || _isLikelyValidUserAgent(uaInput);

            return ContentDialog(
              title: Text(_uaEditDialogTitle),
              content: SizedBox(
                width: 540,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextBox(
                      controller: nameController,
                      placeholder: t.settingsUaCustomNamePlaceholder,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextBox(
                            controller: uaController,
                            placeholder: t.settingsUaCustomValuePlaceholder,
                            onChanged: (_) {
                              setDialogState(() {
                                errorText = null;
                              });
                            },
                          ),
                        ),
                        if (hasUaInput) ...[
                          const SizedBox(width: 8),
                          Icon(
                            uaValid
                                ? FluentIcons.check_mark
                                : FluentIcons.error_badge,
                            size: 16,
                            color: uaValid
                                ? AppTheme.statusSuccess
                                : AppTheme.statusError,
                          ),
                        ],
                      ],
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: FluentTheme.of(context)
                            .typography
                            .caption
                            ?.copyWith(color: AppTheme.statusError),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t.settingsCancelButton),
                ),
                FilledButton(
                  onPressed: () {
                    final newName = nameController.text.trim();
                    final newUa = uaController.text.trim();

                    if (newName.isEmpty || newUa.isEmpty) {
                      setDialogState(() {
                        errorText = _invalidUaFormatMessage;
                      });
                      return;
                    }
                    if (!uaValid) {
                      setDialogState(() {
                        errorText = _invalidUaFormatMessage;
                      });
                      return;
                    }

                    final duplicated = _customUaPacks
                        .any((p) => p.id != pack.id && p.name == newName);
                    if (duplicated) {
                      setDialogState(() {
                        errorText = _uaNameExistsMessage;
                      });
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      _UaPack(
                        id: pack.id,
                        name: newName,
                        userAgent: newUa,
                      ),
                    );
                  },
                  child: Text(t.settingsConfirmButton),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    uaController.dispose();

    if (updated == null) return;

    final next = _customUaPacks
        .map((p) => p.id == updated.id ? updated : p)
        .toList(growable: false);
    await _persistCustomUaPacks(next);

    if (!mounted) return;
    setState(() {
      _customUaPacks = next;
    });

    if (_selectedUaPackId == updated.id) {
      await _selectUaPack(updated.id);
    }

    if (mounted) {
      NotificationManager.of(context)?.showSuccess(
        _uaEditSavedTitle,
        message: updated.name,
      );
    }
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;

    setState(() => _loadingConfig = true);
    try {
      final service = context.read<IntegratedDownloadService>();
      final clientConfig = context.read<ClientConfigService>();
      final config = await service.getDownloadConfig();

      if (config != null && mounted) {
        setState(() {
          _threads = config['threads'] ?? 8;
          _segments = config['segments'] ?? 8;
          _mode = config['mode'] ?? 'auto';
          _maxConcurrentTasks = config['max_concurrent_tasks'] ?? 3;
          _segmentSpeedLimit = config['segment_speed_limit'] ?? 0;
          _globalSpeedLimit = config['global_speed_limit'] ?? 0;
          _enableDynamicSegments = config['enable_dynamic_segments'] ?? true;
          _conflictStrategy = config['conflict_strategy'] ?? 'increment';
          final configuredUserAgent =
              (config['default_user_agent'] ?? '').toString().trim();
          _defaultUserAgent = configuredUserAgent.isEmpty
              ? 'NSFX/2.0 (Next Speed Force X)'
              : configuredUserAgent;
          final selectedUaPackId = clientConfig.getSelectedUaPackId().trim();
          final cachedManualUa = clientConfig.getManualUaValue().trim();
          _manualDefaultUserAgent = cachedManualUa.isNotEmpty
              ? cachedManualUa
              : (selectedUaPackId == _manualUaPackId
                  ? _defaultUserAgent
                  : 'NSFX/2.0 (Next Speed Force X)');
          _httpVersionPolicy =
              (config['http_version_policy'] ?? 'auto').toString();
          if (_httpVersionPolicy != 'http1_only' &&
              _httpVersionPolicy != 'http2_only' &&
              _httpVersionPolicy != 'http3_only' &&
              _httpVersionPolicy != 'auto') {
            _httpVersionPolicy = 'auto';
          }
          _defaultUserAgentController.text = _manualDefaultUserAgent;
          _syncSelectedUaPackInState();
          _showHttpConnectivityBadges = clientConfig.getBool(
            'download.show_http_connectivity_badges',
            defaultValue: false,
          );

          // Load proxy configuration
          final proxyConfig = config['proxy'] as Map<String, dynamic>?;
          if (proxyConfig != null) {
            _useProxy = proxyConfig['enabled'] ?? false;
            _proxyType = proxyConfig['type'] ?? 'system';
            _proxyHost = proxyConfig['host'] ?? '';
            _proxyPort = proxyConfig['port'] ?? 7897;
            _proxyUsername = proxyConfig['username'] ?? '';
            _proxyPassword = proxyConfig['password'] ?? '';
            _proxyRequiresAuth = proxyConfig['requires_auth'] ?? false;
          }

          _loadingConfig = false;
        });
      } else {
        if (mounted) setState(() => _loadingConfig = false);
      }
    } catch (e) {
      debugPrint('Error loading config: $e');
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _updateConfig({
    int? threads,
    int? segments,
    String? mode,
    int? maxConcurrentTasks,
    int? segmentSpeedLimit,
    int? globalSpeedLimit,
    bool? enableDynamicSegments,
    String? conflictStrategy,
    String? defaultUserAgent,
    String? httpVersionPolicy,
    Map<String, dynamic>? proxyConfig,
  }) async {
    final service = context.read<IntegratedDownloadService>();

    // Optimistic update
    setState(() {
      if (threads != null) _threads = threads;
      if (segments != null) _segments = segments;
      if (mode != null) _mode = mode;
      if (maxConcurrentTasks != null) _maxConcurrentTasks = maxConcurrentTasks;
      if (segmentSpeedLimit != null) _segmentSpeedLimit = segmentSpeedLimit;
      if (globalSpeedLimit != null) _globalSpeedLimit = globalSpeedLimit;
      if (enableDynamicSegments != null) {
        _enableDynamicSegments = enableDynamicSegments;
      }
      if (conflictStrategy != null) _conflictStrategy = conflictStrategy;
      if (defaultUserAgent != null) {
        _defaultUserAgent = defaultUserAgent;
        _syncSelectedUaPackInState();
      }
      if (httpVersionPolicy != null) {
        _httpVersionPolicy = httpVersionPolicy;
      }
    });

    await service.setDownloadConfig(
      threads: threads ?? _threads,
      segments: segments ?? _segments,
      mode: mode ?? _mode,
      maxConcurrentTasks: maxConcurrentTasks ?? _maxConcurrentTasks,
      segmentSpeedLimit: segmentSpeedLimit ?? _segmentSpeedLimit,
      globalSpeedLimit: globalSpeedLimit ?? _globalSpeedLimit,
      enableDynamicSegments: enableDynamicSegments ?? _enableDynamicSegments,
      conflictStrategy: conflictStrategy ?? _conflictStrategy,
      defaultUserAgent: defaultUserAgent ?? _defaultUserAgent,
      httpVersionPolicy: httpVersionPolicy ?? _httpVersionPolicy,
      proxyConfig: proxyConfig,
    );

    // Reload to ensure sync
    await _loadConfig();
  }

  Future<void> _updateProxyConfig() async {
    final t = AppLocalizations.of(context)!;

    final useSystemProxy = _proxyType == 'system';
    final effectiveHost = useSystemProxy ? '' : _proxyHost;
    final proxyConfig = {
      'enabled': _useProxy,
      'type': _proxyType,
      'host': effectiveHost,
      'port': _proxyPort,
      'username': _proxyUsername,
      'password': _proxyPassword,
      'requires_auth': _proxyRequiresAuth,
    };

    await _updateConfig(proxyConfig: proxyConfig);

    if (mounted) {
      NotificationManager.of(context)?.showSuccess(
        t.settingsProxySavedTitle,
        message: !_useProxy
            ? t.settingsProxyDisabledMessage
            : (useSystemProxy
                ? t.settingsProxyEnabledSystemMessage
                : t.settingsProxyEnabledMessage(effectiveHost, _proxyPort)),
      );
    }
  }

  Future<void> _setShowHttpConnectivityBadges(bool value) async {
    final clientConfig = context.read<ClientConfigService>();
    await clientConfig.setBool('download.show_http_connectivity_badges', value);
    if (!mounted) return;
    setState(() => _showHttpConnectivityBadges = value);
  }

  Future<void> _saveDefaultUserAgent() async {
    final value = _defaultUserAgentController.text.trim();
    final normalized = value.isEmpty ? 'NSFX/2.0 (Next Speed Force X)' : value;
    final clientConfig = context.read<ClientConfigService>();
    await clientConfig.setManualUaValue(normalized);
    await clientConfig.setSelectedUaPackId(_manualUaPackId);
    if (mounted) {
      setState(() {
        _selectedUaPackId = _manualUaPackId;
        _manualDefaultUserAgent = normalized;
      });
    }
    await _updateConfig(defaultUserAgent: normalized);
  }

  @override
  Widget build(BuildContext context) {
    PerformanceMonitorService().trackRebuild('SettingsPage');

    final isDeveloperMode =
        context.select<DeveloperModeService, bool>((s) => s.developerMode);
    final fontService = context.watch<FontService>();
    final fontStack =
        fontService.resolveFontStack(Localizations.localeOf(context));
    final t = AppLocalizations.of(context)!;

    return ScaffoldPage(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsPageHeader(
              title: t.settingsTitle, icon: custom_icons.FluentIcons.settings),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.bgLayer1.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.borderSubtle.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Listener(
              onPointerSignal: (signal) {
                if (signal is PointerScrollEvent) {
                  if (!_tabScrollController.hasClients) return;
                  final maxExtent =
                      _tabScrollController.position.maxScrollExtent;
                  if (maxExtent <= 0) return;
                  final next =
                      (_tabScrollController.offset + signal.scrollDelta.dy)
                          .clamp(0.0, maxExtent);
                  if (next != _tabScrollController.offset) {
                    _tabScrollController.jumpTo(next);
                  }
                }
              },
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                  dragDevices: {
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.touch,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: SmoothSingleChildScrollView(
                  config: SmoothScrollConfig.fast,
                  controller: _tabScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabButton(
                        context,
                        icon: custom_icons.FluentIcons.settings,
                        title: t.settingsTabGeneral,
                        index: 0,
                        fontFamily: fontStack.primaryFamily,
                        fontFamilyFallback: fontStack.fallbackFamilies,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        context,
                        icon: custom_icons.FluentIcons.download,
                        title: t.settingsTabDownload,
                        index: 1,
                        fontFamily: fontStack.primaryFamily,
                        fontFamilyFallback: fontStack.fallbackFamilies,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        context,
                        icon: custom_icons.FluentIcons.color,
                        title: t.settingsTabAppearance,
                        index: 2,
                        fontFamily: fontStack.primaryFamily,
                        fontFamilyFallback: fontStack.fallbackFamilies,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        context,
                        icon: custom_icons.FluentIcons.update_restore,
                        title: t.settingsTabUpdate,
                        index: 3,
                        fontFamily: fontStack.primaryFamily,
                        fontFamilyFallback: fontStack.fallbackFamilies,
                      ),
                      const SizedBox(width: 4),
                      _buildTabButton(
                        context,
                        icon: custom_icons.FluentIcons.developer_tools,
                        title: t.settingsTabAdvanced,
                        index: 4,
                        fontFamily: fontStack.primaryFamily,
                        fontFamilyFallback: fontStack.fallbackFamilies,
                      ),
                      if (isDeveloperMode) ...[
                        const SizedBox(width: 4),
                        _buildTabButton(
                          context,
                          icon: custom_icons.FluentIcons.code,
                          title: t.settingsTabDeveloper,
                          index: 5,
                          fontFamily: fontStack.primaryFamily,
                          fontFamilyFallback: fontStack.fallbackFamilies,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      content: SmoothSingleChildScrollView(
        config: SmoothScrollConfig.fast,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentTabIndex == 0) ..._buildGeneralTab(context),
            if (_currentTabIndex == 1) ..._buildDownloadTab(context),
            if (_currentTabIndex == 2) const AppearanceSettingsPage(),
            if (_currentTabIndex == 3) const UpdatePage(),
            if (_currentTabIndex == 4) ..._buildAdvancedTab(context),
            if (_currentTabIndex == 5 && isDeveloperMode)
              const DeveloperSettingsPage(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    required String? fontFamily,
    required List<String> fontFamilyFallback,
  }) {
    final isSelected = _currentTabIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _currentTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentPrimary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentPrimary.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color:
                    isSelected ? AppTheme.accentLight : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      fontFamily: fontFamily,
                      fontFamilyFallback: fontFamilyFallback,
                      color: isSelected
                          ? AppTheme.accentLight
                          : AppTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 通用设置
  List<Widget> _buildGeneralTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      _buildStatusSection(context),
      const SizedBox(height: 24),

      if (Platform.isWindows) ...[
        _buildSection(
          context,
          title: t.settingsSectionSystem,
          icon: custom_icons.FluentIcons.power_button,
          children: [
            _buildSettingItem(
              context,
              title: t.settingsAutoStartTitle,
              subtitle: t.settingsAutoStartSubtitle,
              trailing: ToggleSwitch(
                checked: _openOnStartup,
                onChanged: _toggleOpenOnStartup,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],

      // 鐞涘奔璐熺拋鍓х枂
      _buildSection(
        context,
        title: t.settingsSectionBehavior,
        icon: custom_icons.FluentIcons.processing,
        children: [
          _buildSettingItem(
            context,
            title: t.settingsAutoDownloadTitle,
            subtitle: t.settingsAutoDownloadSubtitle,
            trailing: ToggleSwitch(
              checked: _autoStart,
              onChanged: (value) {
                setState(() => _autoStart = value);
                if (mounted) {
                  NotificationManager.of(context)?.showSuccess(
                    value
                        ? t.settingsAutoDownloadEnabledTitle
                        : t.settingsAutoDownloadDisabledTitle,
                    message: value
                        ? t.settingsAutoDownloadEnabledMessage
                        : t.settingsAutoDownloadDisabledMessage,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsPopupWindowTitle,
            subtitle: t.settingsPopupWindowSubtitle,
            trailing: ToggleSwitch(
              checked: _enablePopupWindow,
              onChanged: _saveEnablePopupWindow,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsClipboardListenerTitle,
            subtitle: t.settingsClipboardListenerSubtitle,
            trailing: ToggleSwitch(
              checked: _enableClipboardListener,
              onChanged: _saveEnableClipboardListener,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsCompleteNotifyTitle,
            subtitle: t.settingsCompleteNotifySubtitle,
            trailing: ToggleSwitch(
              checked: _notifyOnComplete,
              onChanged: (value) {
                setState(() => _notifyOnComplete = value);
                if (mounted) {
                  NotificationManager.of(context)?.showSuccess(
                    value
                        ? t.settingsCompleteNotifyEnabledTitle
                        : t.settingsCompleteNotifyDisabledTitle,
                    message: value
                        ? t.settingsCompleteNotifyEnabledMessage
                        : t.settingsCompleteNotifyDisabledMessage,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsTrayHintTitle,
            subtitle: t.settingsTrayHintSubtitle,
            trailing: ToggleSwitch(
              checked: _showTrayRunningStatus,
              onChanged: _saveShowTrayRunningStatus,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsCloseBehaviorTitle,
            subtitle:
                _getCloseButtonBehaviorDescription(_closeButtonBehavior, t),
            trailing: ComboBox<String>(
              value: _closeButtonBehavior,
              items: [
                ComboBoxItem(
                    value: 'minimize_to_tray',
                    child: Text(t.settingsCloseBehaviorMinimizeLabel)),
                ComboBoxItem(
                    value: 'exit_app',
                    child: Text(t.settingsCloseBehaviorExitLabel)),
              ],
              onChanged: (value) {
                if (value != null) _saveCloseButtonBehavior(value);
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildDownloadTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      _buildSection(
        context,
        title: t.settingsDownloadPathSection,
        icon: custom_icons.FluentIcons.folder_open,
        children: [
          _buildSettingItem(
            context,
            title: t.settingsDownloadPathTitle,
            subtitle: _downloadPath,
            trailing: Button(
              onPressed: _kernelOnline ? _changeDownloadPath : null,
              child: Text(t.settingsDownloadPathChangeButton),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildSection(
        context,
        title: t.settingsDownloadConfigSection,
        icon: custom_icons.FluentIcons.settings,
        children: [
          _buildSettingItem(
            context,
            title: t.settingsDownloadModeTitle,
            subtitle: _getModeDescription(_mode, t),
            trailing: _loadingConfig
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : ComboBox<String>(
                    value: _mode,
                    items: [
                      ComboBoxItem(
                          value: 'auto',
                          child: Text(t.settingsDownloadModeAuto)),
                      ComboBoxItem(
                          value: 'threads_only',
                          child: Text(t.settingsDownloadModeThreadsOnly)),
                      ComboBoxItem(
                          value: 'segments_only',
                          child: Text(t.settingsDownloadModeSegmentsOnly)),
                      ComboBoxItem(
                          value: 'manual',
                          child: Text(t.settingsDownloadModeManual)),
                    ],
                    onChanged: (value) {
                      if (value != null) _updateConfig(mode: value);
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: (_mode == 'manual' || _mode == 'threads_only') ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !(_mode == 'manual' || _mode == 'threads_only'),
              child: _buildSettingItem(
                context,
                title: t.settingsThreadsTitle,
                subtitle: t.settingsThreadsSubtitle,
                trailing: SizedBox(
                  width: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _threads.toDouble(),
                          min: 1,
                          max: 32,
                          divisions: 31,
                          label: _threads.toString(),
                          onChanged: (value) {
                            _updateConfig(threads: value.toInt());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$_threads',
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity:
                (_mode == 'manual' || _mode == 'segments_only') ? 1.0 : 0.5,
            child: IgnorePointer(
              ignoring: !(_mode == 'manual' || _mode == 'segments_only'),
              child: _buildSettingItem(
                context,
                title: t.settingsSegmentsTitle,
                subtitle: t.settingsSegmentsSubtitle,
                trailing: SizedBox(
                  width: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _segments.toDouble(),
                          min: 1,
                          max: 32,
                          divisions: 31,
                          label: _segments.toString(),
                          onChanged: (value) {
                            _updateConfig(segments: value.toInt());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$_segments',
                          style: FluentTheme.of(context).typography.bodyStrong,
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
            title: t.settingsDynamicSegmentsTitle,
            subtitle: t.settingsDynamicSegmentsSubtitle,
            trailing: ToggleSwitch(
              checked: _enableDynamicSegments,
              onChanged: (value) {
                _updateConfig(enableDynamicSegments: value);
                if (mounted) {
                  NotificationManager.of(context)?.showSuccess(
                    value
                        ? t.settingsDynamicSegmentsEnabledTitle
                        : t.settingsDynamicSegmentsDisabledTitle,
                    message: value
                        ? t.settingsDynamicSegmentsEnabledMessage
                        : t.settingsDynamicSegmentsDisabledMessage,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsMaxConcurrentTitle,
            subtitle: t.settingsMaxConcurrentSubtitle,
            trailing: SizedBox(
              width: 200,
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _maxConcurrentTasks.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: (value) {
                        _updateConfig(maxConcurrentTasks: value.toInt());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$_maxConcurrentTasks',
                      style: FluentTheme.of(context).typography.bodyStrong,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsSegmentSpeedLimitTitle,
            subtitle: t.settingsSegmentSpeedLimitSubtitle,
            trailing: SizedBox(
              width: 200,
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: (_segmentSpeedLimit / 1024)
                          .clamp(0, 20480)
                          .toDouble(),
                      min: 0,
                      max: 20480, // 20 MB/s
                      divisions: 200,
                      onChanged: (value) {
                        _updateConfig(
                            segmentSpeedLimit: (value * 1024).toInt());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _segmentSpeedLimit == 0
                              ? t.settingsSpeedUnlimited
                              : '${(_segmentSpeedLimit / 1024).toStringAsFixed(0)} KB/s',
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                        if (_segmentSpeedLimit > 0 && _segments > 1)
                          Text(
                            t.settingsSpeedTotal(
                              (_segmentSpeedLimit * _segments / 1024)
                                  .toStringAsFixed(0),
                            ),
                            style: FluentTheme.of(context)
                                .typography
                                .caption
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsGlobalSpeedLimitTitle,
            subtitle: t.settingsGlobalSpeedLimitSubtitle,
            trailing: SizedBox(
              width: 200,
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: (_globalSpeedLimit / 1024)
                          .clamp(0, 102400)
                          .toDouble(),
                      min: 0,
                      max: 102400, // 100 MB/s
                      divisions: 200,
                      onChanged: (value) {
                        _updateConfig(globalSpeedLimit: (value * 1024).toInt());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Text(
                      _globalSpeedLimit == 0
                          ? t.settingsSpeedUnlimited
                          : _globalSpeedLimit >= 1024 * 1024
                              ? '${(_globalSpeedLimit / 1024 / 1024).toStringAsFixed(1)} MB/s'
                              : '${(_globalSpeedLimit / 1024).toStringAsFixed(0)} KB/s',
                      style: FluentTheme.of(context).typography.bodyStrong,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsConflictStrategyTitle,
            subtitle: t.settingsConflictStrategySubtitle,
            trailing: ComboBox<String>(
              value: _conflictStrategy,
              items: [
                ComboBoxItem(
                    value: 'increment',
                    child: Text(t.settingsConflictStrategyIncrement)),
                ComboBoxItem(
                    value: 'timestamp',
                    child: Text(t.settingsConflictStrategyTimestamp)),
                ComboBoxItem(
                    value: 'overwrite',
                    child: Text(t.settingsConflictStrategyOverwrite)),
              ],
              onChanged: (value) {
                if (value != null) _updateConfig(conflictStrategy: value);
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsHttpVersionTitle,
            subtitle: t.settingsHttpVersionSubtitle,
            trailing: ComboBox<String>(
              value: _httpVersionPolicy,
              items: [
                ComboBoxItem(
                    value: 'auto', child: Text(t.settingsHttpVersionAuto)),
                ComboBoxItem(
                    value: 'http1_only',
                    child: Text(t.settingsHttpVersionHttp1Only)),
                ComboBoxItem(
                    value: 'http2_only',
                    child: Text(t.settingsHttpVersionHttp2Only)),
                ComboBoxItem(
                    value: 'http3_only',
                    child: Text(t.settingsHttpVersionHttp3Only)),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updateConfig(httpVersionPolicy: value);
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsDownloadCardHttpBadgeTitle,
            subtitle: t.settingsDownloadCardHttpBadgeSubtitle,
            trailing: ToggleSwitch(
              checked: _showHttpConnectivityBadges,
              onChanged: _setShowHttpConnectivityBadges,
            ),
          ),
          const SizedBox(height: 12),
          _buildUaSettingItem(
            context,
            title: t.settingsDefaultUserAgentTitle,
            subtitle: t.settingsDefaultUserAgentSubtitle,
            trailing: SizedBox(
              width: 420,
              child: Row(
                children: [
                  Expanded(
                    child: TextBox(
                      controller: _defaultUserAgentController,
                      placeholder: t.settingsDefaultUserAgentPlaceholder,
                      onSubmitted: (_) => _saveDefaultUserAgent(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: _saveDefaultUserAgent,
                    child: Text(t.settingsConfirmButton),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildUaSettingItem(
            context,
            title: t.settingsUaPresetTitle,
            subtitle: t.settingsUaPresetSubtitle,
            trailing: SizedBox(
              width: 420,
              child: ComboBox<String>(
                value: _resolvedSelectedUaPackId,
                items: [
                  ComboBoxItem<String>(
                    value: _manualUaPackId,
                    child: Text(t.settingsUaPresetManualOption),
                  ),
                  ..._builtinUaPacks.map(
                    (pack) => ComboBoxItem<String>(
                      value: pack.id,
                      child: Text(t.settingsUaPresetBuiltinOption(pack.name)),
                    ),
                  ),
                  ..._customUaPacks.map(
                    (pack) => ComboBoxItem<String>(
                      value: pack.id,
                      child: Text(t.settingsUaPresetCustomOption(pack.name)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _selectUaPack(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildUaSettingItem(
            context,
            title: t.settingsUaCustomCreateTitle,
            subtitle: t.settingsUaCustomCreateSubtitle,
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 460;

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextBox(
                          controller: _uaPackNameController,
                          placeholder: t.settingsUaCustomNamePlaceholder,
                          onSubmitted: (_) => _addCustomUaPack(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextBox(
                                controller: _uaPackValueController,
                                placeholder: t.settingsUaCustomValuePlaceholder,
                                onSubmitted: (_) => _addCustomUaPack(),
                                onChanged: (_) {
                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                            if (_hasCustomUaInput) ...[
                              const SizedBox(width: 8),
                              _buildCustomUaValidationIcon(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Button(
                              onPressed: _addCustomUaPack,
                              child: Text(t.settingsUaCustomAddButton),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextBox(
                          controller: _uaPackNameController,
                          placeholder: t.settingsUaCustomNamePlaceholder,
                          onSubmitted: (_) => _addCustomUaPack(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextBox(
                                controller: _uaPackValueController,
                                placeholder: t.settingsUaCustomValuePlaceholder,
                                onSubmitted: (_) => _addCustomUaPack(),
                                onChanged: (_) {
                                  if (mounted) setState(() {});
                                },
                              ),
                            ),
                            if (_hasCustomUaInput) ...[
                              const SizedBox(width: 8),
                              _buildCustomUaValidationIcon(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: _addCustomUaPack,
                        child: Text(t.settingsUaCustomAddButton),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildUaSettingItem(
            context,
            title: t.settingsUaCustomListTitle,
            subtitle: _customUaPacks.isEmpty
                ? t.settingsUaCustomListEmpty
                : t.settingsUaCustomListCount(_customUaPacks.length),
            trailing: SizedBox(
              width: 500,
              child: _customUaPacks.isEmpty
                  ? Text(
                      t.settingsUaCustomListHint,
                      style: FluentTheme.of(context).typography.caption,
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SmoothSingleChildScrollView(
                        config: SmoothScrollConfig.fast,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final pack in _customUaPacks)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgLayer2
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusSm),
                                    border: Border.all(
                                      color: (_selectedUaPackId == pack.id
                                              ? AppTheme.accentPrimary
                                              : AppTheme.borderSubtle)
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final uaTextStyle =
                                          FluentTheme.of(context)
                                              .typography
                                              .caption
                                              ?.copyWith(
                                                color: AppTheme.textSecondary,
                                              );
                                      final showPreviewButton = _uaNeedsPreview(
                                        context: context,
                                        ua: pack.userAgent,
                                        style: uaTextStyle,
                                        maxWidth: constraints.maxWidth - 16,
                                      );
                                      final uaValid = _isLikelyValidUserAgent(
                                          pack.userAgent);
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        pack.name,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Tooltip(
                                                      message: uaValid
                                                          ? _uaFormatValidLabel
                                                          : _uaFormatInvalidLabel,
                                                      child: Icon(
                                                        uaValid
                                                            ? FluentIcons
                                                                .check_mark
                                                            : FluentIcons
                                                                .error_badge,
                                                        size: 14,
                                                        color: uaValid
                                                            ? AppTheme
                                                                .statusSuccess
                                                            : AppTheme
                                                                .statusError,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  pack.userAgent,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: uaTextStyle,
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: [
                                                    if (showPreviewButton)
                                                      Button(
                                                        onPressed: () =>
                                                            _previewCustomUaPack(
                                                                pack),
                                                        child: Text(
                                                            _uaPreviewLabel),
                                                      ),
                                                    Button(
                                                      onPressed: () =>
                                                          _editCustomUaPack(
                                                              pack),
                                                      child: Text(_uaEditLabel),
                                                    ),
                                                    Button(
                                                      onPressed: () =>
                                                          _selectUaPack(
                                                              pack.id),
                                                      child: Text(
                                                        _selectedUaPackId ==
                                                                pack.id
                                                            ? t.settingsUaCustomEnabledButton
                                                            : t.settingsUaCustomApplyButton,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          FluentIcons.delete),
                                                      onPressed: () =>
                                                          _removeCustomUaPack(
                                                              pack.id),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildSection(
        context,
        title: t.settingsProxySection,
        icon: custom_icons.FluentIcons.network_tower,
        children: [
          _buildSettingItem(
            context,
            title: t.settingsProxyEnableTitle,
            subtitle: t.settingsProxyEnableSubtitle,
            trailing: ToggleSwitch(
              checked: _useProxy,
              onChanged: (value) {
                setState(() => _useProxy = value);
                _updateProxyConfig();
              },
            ),
          ),
          if (_useProxy) ...[
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              title: t.settingsProxyTypeTitle,
              subtitle: t.settingsProxyTypeSubtitle,
              trailing: ComboBox<String>(
                value: _proxyType,
                items: [
                  ComboBoxItem(
                      value: 'system', child: Text(t.settingsProxyTypeSystem)),
                  ComboBoxItem(
                      value: 'http', child: Text(t.settingsProxyTypeHttp)),
                  ComboBoxItem(
                      value: 'socks5', child: Text(t.settingsProxyTypeSocks5)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _proxyType = value;
                      if (_proxyType != 'system') {
                        if (_proxyHost.trim().isEmpty) {
                          _proxyHost = '127.0.0.1';
                        }
                        if (_proxyPort <= 0) {
                          _proxyPort = 7897;
                        }
                      }
                    });
                    _updateProxyConfig();
                  }
                },
              ),
            ),
            if (_proxyType != 'system') ...[
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                title: t.settingsProxyServerTitle,
                subtitle: t.settingsProxyServerSubtitle,
                trailing: SizedBox(
                  width: 300,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextBox(
                          placeholder: t.settingsProxyHostPlaceholder,
                          controller: TextEditingController(text: _proxyHost)
                            ..selection = TextSelection.fromPosition(
                              TextPosition(offset: _proxyHost.length),
                            ),
                          onChanged: (value) => _proxyHost = value,
                          onSubmitted: (_) => _updateProxyConfig(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(':'),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: NumberBox<int>(
                          value: _proxyPort,
                          min: 1,
                          max: 65535,
                          mode: SpinButtonPlacementMode.none,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _proxyPort = value);
                              _updateProxyConfig();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildSettingItem(
                context,
                title: t.settingsProxyAuthTitle,
                subtitle: t.settingsProxyAuthSubtitle,
                trailing: ToggleSwitch(
                  checked: _proxyRequiresAuth,
                  onChanged: (value) {
                    setState(() => _proxyRequiresAuth = value);
                    _updateProxyConfig();
                  },
                ),
              ),
              if (_proxyRequiresAuth) ...[
                const SizedBox(height: 12),

                // 认证信息
                _buildSettingItem(
                  context,
                  title: t.settingsProxyUsernameTitle,
                  subtitle: t.settingsProxyUsernameSubtitle,
                  trailing: SizedBox(
                    width: 200,
                    child: TextBox(
                      placeholder: t.settingsProxyUsernamePlaceholder,
                      controller: TextEditingController(text: _proxyUsername)
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: _proxyUsername.length),
                        ),
                      onChanged: (value) => _proxyUsername = value,
                      onSubmitted: (_) => _updateProxyConfig(),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _buildSettingItem(
                  context,
                  title: t.settingsProxyPasswordTitle,
                  subtitle: t.settingsProxyPasswordSubtitle,
                  trailing: SizedBox(
                    width: 200,
                    child: PasswordBox(
                      placeholder: t.settingsProxyPasswordPlaceholder,
                      controller: TextEditingController(text: _proxyPassword)
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: _proxyPassword.length),
                        ),
                      onChanged: (value) => _proxyPassword = value,
                      onSubmitted: (_) => _updateProxyConfig(),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    custom_icons.FluentIcons.info,
                    size: 16,
                    color: AppTheme.accentLight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.settingsProxyTipsTitle,
                          style: FluentTheme.of(context)
                              .typography
                              .bodyStrong
                              ?.copyWith(
                                color: AppTheme.accentLight,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getProxyConfigTips(t),
                          style: FluentTheme.of(context)
                              .typography
                              .caption
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Button(
                    onPressed: _testProxyConnection,
                    child: Text(t.settingsProxyTestButton),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ];
  }

  Future<void> _testProxyConnection() async {
    final t = AppLocalizations.of(context)!;

    if (_proxyType != 'system' && _proxyHost.isEmpty) {
      NotificationManager.of(context)?.showError(
        t.settingsProxyErrorTitle,
        message: t.settingsProxyErrorMessage,
      );
      return;
    }

    NotificationManager.of(context)?.showInfo(
      t.settingsProxyTestingTitle,
      message: t.settingsProxyTestingMessage,
    );

    try {
      final service = context.read<IntegratedDownloadService>();

      String testHost = _proxyHost;
      int testPort = _proxyPort;

      if (_proxyType == 'system') {
        testHost = '127.0.0.1';
      }

      final result = await service.testProxyConnection(
        type: _proxyType,
        host: testHost,
        port: testPort,
        username: _proxyRequiresAuth ? _proxyUsername : null,
        password: _proxyRequiresAuth ? _proxyPassword : null,
      );

      if (mounted) {
        if (result) {
          NotificationManager.of(context)?.showSuccess(
            t.settingsProxyTestSuccessTitle,
            message: t.settingsProxyTestSuccessMessage,
          );
        } else {
          NotificationManager.of(context)?.showError(
            t.settingsProxyTestFailedTitle,
            message: t.settingsProxyTestFailedMessage,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError(
          t.settingsProxyTestErrorTitle,
          message: t.settingsProxyTestErrorMessage(e.toString()),
        );
      }
    }
  }

  String _getProxyConfigTips(AppLocalizations t) {
    switch (_proxyType) {
      case 'system':
        return t.settingsProxyTipsSystem;
      case 'http':
        return t.settingsProxyTipsHttp;
      case 'socks5':
        return t.settingsProxyTipsSocks5;
      default:
        return t.settingsProxyTipsDefault;
    }
  }

  // 高级设置
  List<Widget> _buildAdvancedTab(BuildContext context) {
    return [
      _buildKernelSection(context),
      const SizedBox(height: 24),
      _buildLogManagementSection(context),
      const SizedBox(height: 24),
      _buildDeveloperModeToggle(context),
      const SizedBox(height: 24),
      _buildDangerZone(context),
    ];
  }

  Widget _buildLogManagementSection(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final logger = AppLoggerService();
    final retentionDays = logger.logRetention.inDays;

    return _buildSection(
      context,
      title: t.settingsLogManagementSection,
      icon: custom_icons.FluentIcons.text_document,
      children: [
        _buildSettingItem(
          context,
          title: t.settingsLogClearTitle,
          subtitle: t.settingsLogClearSubtitle,
          trailing: Button(
            onPressed: () => _confirmClearLogs(context),
            child: Text(t.settingsLogClearButton),
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingItem(
          context,
          title: t.settingsLogOpenDirTitle,
          subtitle: t.settingsLogOpenDirSubtitle,
          trailing: Button(
            onPressed: () => _openLogDirectory(context),
            child: Text(t.settingsLogOpenDirButton),
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingItem(
          context,
          title: t.settingsLogRetentionTitle,
          subtitle: t.settingsLogRetentionSubtitle(retentionDays),
          trailing: ComboBox<int>(
            value: retentionDays,
            items: [3, 7, 14, 30, 60]
                .map((d) => ComboBoxItem<int>(
                      value: d,
                      child: Text('$d ${t.settingsLogRetentionDays}'),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                logger.logRetention = Duration(days: value);
                _saveLogRetention(value);
                setState(() {});
                NotificationManager.of(context)?.showSuccess(
                  t.settingsLogRetentionSaved,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearLogs(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(t.settingsLogClearConfirmTitle),
        content: Text(t.settingsLogClearConfirmMessage),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.settingsCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.settingsLogClearConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final logger = AppLoggerService();
    logger.clear();
    await logger.deleteAllLogFiles();

    if (mounted) {
      NotificationManager.of(context)?.showSuccess(
        t.settingsLogClearSuccessTitle,
        message: t.settingsLogClearSuccessMessage,
      );
    }
  }

  Future<void> _openLogDirectory(BuildContext context) async {
    final t = AppLocalizations.of(context)!;
    try {
      final logger = AppLoggerService();
      final dir = await logger.getLogDirectory();
      if (await dir.exists()) {
        Process.start(
          'explorer',
          [dir.path.replaceAll('/', '\\')],
          mode: ProcessStartMode.detached,
        );
      } else {
        if (mounted) {
          NotificationManager.of(context)?.showError(
            t.settingsLogOpenDirNotFound,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError(
          t.settingsLogOpenDirError,
          message: e.toString(),
        );
      }
    }
  }

  Future<void> _saveLogRetention(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('log_retention_days', days);
  }

  Widget _buildDeveloperModeToggle(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Consumer<DeveloperModeService>(
      builder: (context, devMode, child) {
        return _buildSection(
          context,
          title: t.settingsDeveloperSection,
          icon: custom_icons.FluentIcons.developer_tools,
          children: [
            _buildSettingItem(
              context,
              title: t.settingsDeveloperModeTitle,
              subtitle: t.settingsDeveloperModeSubtitle,
              trailing: ToggleSwitch(
                checked: devMode.developerMode,
                onChanged: (value) {
                  devMode.setDeveloperMode(value);
                  if (context.mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      value
                          ? t.settingsDeveloperModeEnabledTitle
                          : t.settingsDeveloperModeDisabledTitle,
                      message: value
                          ? t.settingsDeveloperModeEnabledMessage
                          : t.settingsDeveloperModeDisabledMessage,
                    );
                  }
                },
              ),
            ),
            if (devMode.developerMode) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      custom_icons.FluentIcons.info,
                      size: 16,
                      color: AppTheme.accentLight,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.settingsDeveloperModeHint,
                        style: FluentTheme.of(context)
                            .typography
                            .caption
                            ?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildKernelSection(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return _buildSection(
      context,
      title: t.settingsKernelSection,
      icon: custom_icons.FluentIcons.processing,
      children: [
        _buildSettingItem(
          context,
          title: t.settingsKernelCurrentTitle,
          subtitle:
              '${AppConstants.newKernelFullName} | ${AppConstants.newKernelVersion} | ${AppConstants.newKernelBuildNumber}',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kernelOnline
                  ? AppTheme.statusSuccess.withValues(alpha: 0.2)
                  : AppTheme.statusError.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _kernelOnline ? t.settingsKernelOnline : t.settingsKernelOffline,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: _kernelOnline
                        ? AppTheme.statusSuccess
                        : AppTheme.statusError,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingItem(
          context,
          title: t.settingsBrowserExtensionPortTitle,
          subtitle: t.settingsBrowserExtensionPortSubtitle(
            _browserExtensionPort,
          ),
          trailing: Button(
            onPressed: _showBrowserExtensionPortDialog,
            child: Text(t.settingsBrowserExtensionPortChangeButton),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.accentPrimary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                custom_icons.FluentIcons.info,
                size: 16,
                color: AppTheme.accentLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.settingsKernelNsfxHint,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final kernelDisplayName = t.settingsStatusKernelNsfx;
    final statusIndicators = [
      _StatusIndicatorData(
        title: kernelDisplayName,
        isOnline: _kernelOnline,
        icon: custom_icons.FluentIcons.server,
      ),
      for (final status in _browserExtensionStatuses)
        _StatusIndicatorData(
          title: status.title,
          isOnline: true,
          icon: custom_icons.FluentIcons.globe,
        ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(custom_icons.FluentIcons.status_circle_inner, size: 16),
              const SizedBox(width: 8),
              Text(
                t.settingsStatusTitle,
                style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 16.0;
              final columnCount =
                  constraints.maxWidth < 620 ? 1 : statusIndicators.length;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columnCount - 1)) /
                      columnCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final item in statusIndicators)
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatusIndicator(
                        context,
                        title: item.title,
                        isOnline: item.isOnline,
                        icon: item.icon,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context, {
    required String title,
    required bool isOnline,
    required IconData icon,
  }) {
    return StatusIndicator(
      title: title,
      isOnline: isOnline,
      icon: icon,
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return SettingsSection(
      title: title,
      icon: icon,
      children: children,
    );
  }

  String _getModeDescription(String mode, AppLocalizations t) {
    switch (mode) {
      case 'auto':
        return t.settingsModeDescriptionAuto;
      case 'threads_only':
        return t.settingsModeDescriptionThreadsOnly;
      case 'segments_only':
        return t.settingsModeDescriptionSegmentsOnly;
      case 'manual':
        return t.settingsModeDescriptionManual;
      default:
        return t.settingsModeDescriptionUnknown;
    }
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return SettingsItem(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }

  Widget _buildUaSettingItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return SettingsItem(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      stackOnNarrow: true,
      narrowBreakpoint: 760,
      stackedTrailingAlignment: Alignment.centerLeft,
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return DangerZone(
      children: [
        SettingsItem(
          title: t.settingsDangerCleanTempTitle,
          subtitle: t.settingsDangerCleanTempSubtitle,
          trailing: Button(
            onPressed: _downloadPath.isEmpty ? null : _showTempFilesDialog,
            child: Text(t.settingsDangerCleanTempButton),
          ),
        ),
        const SizedBox(height: 12),
        SettingsItem(
          title: t.settingsDangerClearDataTitle,
          subtitle: t.settingsDangerClearDataSubtitle,
          trailing: FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
            ),
            onPressed: _confirmClearData,
            child: Text(t.settingsDangerClearDataButton),
          ),
        ),
      ],
    );
  }

  void _showTempFilesDialog() {
    showDialog(
      context: context,
      builder: (context) => TempFilesDialog(
        downloadPath: _downloadPath,
      ),
    );
  }

  void _confirmClearData() {
    final t = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(t.settingsDangerConfirmTitle),
        content: Text(t.settingsDangerConfirmMessage),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.settingsCancelButton),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              if (!mounted) return;

              final notifier = NotificationManager.of(context);
              notifier?.showInfo(
                t.settingsDangerClearingTitle,
                message: t.settingsDangerClearingMessage,
              );

              final kernelManager = context.read<KernelManager>();
              final success = await kernelManager.clearAllData();
              if (!mounted) return;

              if (success) {
                notifier?.showSuccess(
                  t.settingsDangerClearedTitle,
                  message: t.settingsDangerClearedMessage,
                );
              } else {
                notifier?.showError(
                  t.settingsDangerClearFailedTitle,
                  message: t.settingsDangerClearFailedMessage,
                );
              }
            },
            child: Text(t.settingsDangerConfirmButton),
          ),
        ],
      ),
    );
  }
}

class _BrowserBridgeStatus {
  const _BrowserBridgeStatus({
    required this.kernelOnline,
    this.browserExtensions = const [],
  });

  final bool kernelOnline;
  final List<_BrowserExtensionStatus> browserExtensions;
}

class _BrowserExtensionStatus {
  const _BrowserExtensionStatus({
    required this.id,
    required this.title,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final int sortOrder;
}

class _StatusIndicatorData {
  const _StatusIndicatorData({
    required this.title,
    required this.isOnline,
    required this.icon,
  });

  final String title;
  final bool isOnline;
  final IconData icon;
}
