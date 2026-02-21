import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart'; // Import appWindow

import 'package:provider/provider.dart';
import '../../main.dart'; // Import systemTrayService
import '../../services/integrated_download_service.dart';
import '../../services/kernel_service.dart';
import '../../services/kernel/kernel_manager.dart';
import '../../services/developer_mode_service.dart';
import '../../services/client_config_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/performance_monitor_service.dart';
import '../../widgets/folder_picker_dialog.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/temp_files_dialog.dart';
import '../../widgets/smooth_scroll_wrapper.dart';
import '../../services/auto_start_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;
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
      final userName = Platform.environment['USERNAME'] ?? Platform.environment['USER'];
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

class _SettingsPageState extends State<SettingsPage> {
  AppLocalizations get t => AppLocalizations.of(context)!;

  // Tab state
  int _currentTabIndex = 0;
  final ScrollController _tabScrollController = ScrollController();
  
  // Download configuration state
  int _threads = 8;
  int _segments = 8;
  String _mode = 'auto'; // auto, threads_only, segments_only, manual
  int _maxConcurrentTasks = 3;
  int _segmentSpeedLimit = 0;
  bool _enableDynamicSegments = true; // 动态分段开关
  bool _loadingConfig = true;
  
  // Proxy configuration state
  bool _useProxy = false;
  String _proxyType = 'system'; // system, http, socks5
  String _proxyHost = '';
  int _proxyPort = 8080;
  String _proxyUsername = '';
  String _proxyPassword = '';
  bool _proxyRequiresAuth = false;
  
  bool _autoStart = true;
  bool _openOnStartup = false;
  final _autoStartService = AutoStartService();
  bool _notifyOnComplete = true;
  bool _enableOnlineStats = true; // 在线统计开关
  String _downloadPath = '';
  String _closeButtonBehavior = 'minimize_to_tray';
  bool _showTrayRunningStatus = false;
  bool _enablePopupWindow = true;
  
  // Status monitoring
  bool _kernelOnline = false;
  bool _browserConnected = false;
  Timer? _statusTimer;
  
  // 新内核相关
  bool _useNewKernel = true;
  String _currentKernelName = 'NSFX (Next Speed Force X)';
  bool _switchingKernel = false;
  
  // 开发者模式服务引用
  DeveloperModeService? _devModeService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
      _loadDownloadPath();
      _startStatusMonitoring();
      _loadAutoStartSettings();
      _loadBehaviorSettings();
      _loadKernelSettings();
      _loadOnlineStatsSettings();
      
      // 监听开发者模式变化，如果关闭时正在查看开发者标签，自动切换回高级标签
      _devModeService = Provider.of<DeveloperModeService>(context, listen: false);
      _devModeService?.addListener(_onDeveloperModeChanged);
    });
  }
  
  void _onDeveloperModeChanged() {
    // 如果开发者模式被关闭且当前在开发者标签页，切换回高级标签
    if (_devModeService != null && !_devModeService!.developerMode && _currentTabIndex == 5) {
      setState(() {
        _currentTabIndex = 4; // 切换到高级标签
      });
    }
  }

  Future<void> _loadOnlineStatsSettings() async {
    final userProfile = UserProfileService();
    if (mounted) {
      setState(() {
        _enableOnlineStats = userProfile.statsEnabled;
      });
    }
  }

  Future<void> _toggleOnlineStats(bool value) async {
    final t = AppLocalizations.of(context)!;
    final userProfile = UserProfileService();
    await userProfile.setStatsEnabled(value);
    
    if (mounted) {
      setState(() {
        _enableOnlineStats = value;
      });
      
      NotificationManager.of(context)?.showSuccess(
        value ? t.settingsOnlineStatsEnabledTitle : t.settingsOnlineStatsDisabledTitle,
        message: value
            ? t.settingsOnlineStatsEnabledMessage
            : t.settingsOnlineStatsDisabledMessage,
      );
    }
  }

  Future<void> _loadKernelSettings() async {
    final config = Provider.of<ClientConfigService>(context, listen: false);
    final kernelManager = KernelManager();
    
    if (mounted) {
      setState(() {
        _useNewKernel = config.getBool('kernel.use_new_kernel', defaultValue: true);
        _currentKernelName = kernelManager.kernelName;
      });
    }
  }

  Future<void> _switchKernel(bool useNew) async {
    if (_switchingKernel) return;
    
    setState(() => _switchingKernel = true);
    
    try {
      final config = Provider.of<ClientConfigService>(context, listen: false);
      final kernelManager = Provider.of<KernelManager>(context, listen: false);
      final kernelService = Provider.of<KernelService>(context, listen: false);
      final downloadService = Provider.of<IntegratedDownloadService>(context, listen: false);
      
      if (useNew) {
        // 切换到新内核：先停止旧内核，再启动新内核
        await kernelService.stopKernel();
        final success = await kernelManager.start(type: KernelType.next);
        
        if (success) {
          await config.setBool('kernel.use_new_kernel', true);
          await downloadService.resetTasksAndReload();
          
          if (mounted) {
            setState(() {
              _useNewKernel = true;
              _currentKernelName = kernelManager.kernelName;
            });
            
            NotificationManager.of(context)?.showSuccess(
              t.settingsKernelSwitchedTitle,
              message: t.settingsKernelSwitchedMessage(kernelManager.kernelName),
            );
          }
        } else {
          if (mounted) {
            NotificationManager.of(context)?.showError(
              t.settingsKernelSwitchFailedTitle,
              message: t.settingsKernelSwitchFailedNewMessage,
            );
          }
        }
      } else {
        // 切换到旧内核：先停止新内核，再启动旧内核
        await kernelManager.stop();
        final success = await kernelService.startKernel();
        
        if (success) {
          await config.setBool('kernel.use_new_kernel', false);
          await downloadService.resetTasksAndReload();
          
          if (mounted) {
            setState(() {
              _useNewKernel = false;
              _currentKernelName = 'Soda Speed Force (Legacy)';
            });
            
            NotificationManager.of(context)?.showSuccess(
              t.settingsKernelSwitchedTitle,
              message: t.settingsKernelSwitchedLegacyMessage,
            );
          }
        } else {
          if (mounted) {
            NotificationManager.of(context)?.showError(
              t.settingsKernelSwitchFailedTitle,
              message: t.settingsKernelSwitchFailedLegacyMessage,
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _switchingKernel = false);
      }
    }
  }
  
  Future<void> _loadAutoStartSettings() async {
    if (!Platform.isWindows) return;
    
    final enabled = await _autoStartService.isAutoStartEnabled();
    if (mounted) {
      setState(() {
        _openOnStartup = enabled;
      });
      
      // 如果启用了自启动，检查路径是否正确
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
      
      if (mounted) {
        setState(() {
          _closeButtonBehavior = closeButtonBehavior;
          _showTrayRunningStatus = showTrayRunningStatus;
          _enablePopupWindow = enablePopupWindow;
        });
      }
    } catch (e) {
      debugPrint('Error loading behavior settings: $e');
    }
  }
  
  Future<void> _verifyAutoStartPath() async {
    final isCorrect = await _autoStartService.isRegisteredPathCorrect();
    if (!isCorrect && mounted) {
      // 路径不正确，自动修复
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
        value ? t.settingsAutoStartEnabledTitle : t.settingsAutoStartDisabledTitle,
        message: value ? t.settingsAutoStartEnabledMessage : t.settingsAutoStartDisabledMessage,
      );
    } else if (mounted) {
      NotificationManager.of(context)?.showError(
        t.settingsSaveFailedTitle,
        message: value ? t.settingsAutoStartEnableFailed : t.settingsAutoStartDisableFailed,
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
        
        // 立即更新托盘状态
        systemTrayService.updateToolTip(!appWindow.isVisible);
        
        NotificationManager.of(context)?.showSuccess(
          value ? t.settingsTrayHintEnabledTitle : t.settingsTrayHintDisabledTitle,
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
  
  String _getCloseButtonBehaviorDescription(String behavior, AppLocalizations t) {
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
    // 移除开发者模式监听器
    _devModeService?.removeListener(_onDeveloperModeChanged);
    _tabScrollController.dispose();
    super.dispose();
  }
  
  void _startStatusMonitoring() {
    _checkStatus();
    // 优化：状态检查间隔从 5 秒提升到 10 秒，减少不必要的轮询
    // 内核状态变化不频繁，10 秒足够
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkStatus();
    });
  }
  
  Future<void> _checkStatus() async {
    if (!mounted) return;

    final kernelManager = KernelManager();
    final legacyKernelService = context.read<KernelService>();

    // 检查新内核或旧内核的运行状态
    final newKernelOnline = _useNewKernel
        ? kernelManager.isRunning
        : legacyKernelService.isRunning;

    // 浏览器连接状态（暂时与内核状态一致）
    final newBrowserConnected = newKernelOnline;
    final newKernelName = kernelManager.kernelName;

    // 优化：只在状态真正变化时才 setState，避免不必要的重建
    if (mounted && (newKernelOnline != _kernelOnline ||
        newBrowserConnected != _browserConnected ||
        newKernelName != _currentKernelName)) {
      setState(() {
        _kernelOnline = newKernelOnline;
        _browserConnected = newBrowserConnected;
        _currentKernelName = newKernelName;
      });
    }
  }
  
  Future<void> _loadDownloadPath() async {
    if (!mounted) return;
    
    try {
      final clientConfig = context.read<ClientConfigService>();
      final useNewKernel = clientConfig.getBool('kernel.use_new_kernel', defaultValue: true);
      
      String? path;
      if (useNewKernel) {
        final kernelManager = context.read<KernelManager>();
        path = await kernelManager.getDownloadDir();
      } else {
        final kernelService = context.read<KernelService>();
        path = await kernelService.getDownloadDir();
      }
      
      if (path != null && mounted) {
        setState(() {
          _downloadPath = path!;
        });
      }
    } catch (e) {
      debugPrint('Error loading download path: $e');
    }
  }
  
  Future<void> _changeDownloadPath() async {
    // 直接显示手动输入对话框，避免 file_picker 在 Windows 上的卡顿问题
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
                    // 打开自定义文件夹选择器
                    final selectedPath = await showDialog<String>(
                      context: context,
                      barrierDismissible: true,
                      builder: (context) => FolderPickerDialog(
                        initialPath: controller.text.isNotEmpty ? controller.text : _downloadPath,
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
                color: FluentTheme.of(context).accentColor.withValues(alpha: 0.1),
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
      final clientConfig = context.read<ClientConfigService>();
      final useNewKernel = clientConfig.getBool('kernel.use_new_kernel', defaultValue: true);
      
      bool success;
      if (useNewKernel) {
        final kernelManager = context.read<KernelManager>();
        success = await kernelManager.setDownloadDir(result);
      } else {
        final kernelService = context.read<KernelService>();
        success = await kernelService.setDownloadDir(result);
      }

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

  Future<void> _loadConfig() async {
    if (!mounted) return;
    
    setState(() => _loadingConfig = true);
    try {
      final service = context.read<IntegratedDownloadService>();
      final config = await service.getDownloadConfig();
      
      if (config != null && mounted) {
        setState(() {
          _threads = config['threads'] ?? 8;
          _segments = config['segments'] ?? 8;
          _mode = config['mode'] ?? 'auto';
          _maxConcurrentTasks = config['max_concurrent_tasks'] ?? 3;
          _segmentSpeedLimit = config['segment_speed_limit'] ?? 0;
          _enableDynamicSegments = config['enable_dynamic_segments'] ?? true;
          
          // Load proxy configuration
          final proxyConfig = config['proxy'] as Map<String, dynamic>?;
          if (proxyConfig != null) {
            _useProxy = proxyConfig['enabled'] ?? false;
            _proxyType = proxyConfig['type'] ?? 'http';
            _proxyHost = proxyConfig['host'] ?? '';
            _proxyPort = proxyConfig['port'] ?? 8080;
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
    bool? enableDynamicSegments,
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
      if (enableDynamicSegments != null) _enableDynamicSegments = enableDynamicSegments;
    });
    
    await service.setDownloadConfig(
      threads: threads ?? _threads,
      segments: segments ?? _segments,
      mode: mode ?? _mode,
      maxConcurrentTasks: maxConcurrentTasks ?? _maxConcurrentTasks,
      segmentSpeedLimit: segmentSpeedLimit ?? _segmentSpeedLimit,
      enableDynamicSegments: enableDynamicSegments ?? _enableDynamicSegments,
      proxyConfig: proxyConfig,
    );
    
    // Reload to ensure sync
    await _loadConfig();
  }

  Future<void> _updateProxyConfig() async {
    final t = AppLocalizations.of(context)!;
    final proxyConfig = {
      'enabled': _useProxy,
      'type': _proxyType,
      'host': _proxyHost,
      'port': _proxyPort,
      'username': _proxyUsername,
      'password': _proxyPassword,
      'requires_auth': _proxyRequiresAuth,
    };
    
    await _updateConfig(proxyConfig: proxyConfig);
    
    if (mounted) {
      NotificationManager.of(context)?.showSuccess(
        t.settingsProxySavedTitle,
        message: _useProxy
            ? t.settingsProxyEnabledMessage(_proxyHost, _proxyPort)
            : t.settingsProxyDisabledMessage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 追踪重建
    PerformanceMonitorService().trackRebuild('SettingsPage');

    // 优化：使用 Selector 只监听 developerMode 布尔值，而非整个 DeveloperModeService
    final isDeveloperMode = context.select<DeveloperModeService, bool>((s) => s.developerMode);
    final t = AppLocalizations.of(context)!;
    
    return ScaffoldPage(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsPageHeader(title: t.settingsTitle, icon: CustomIcons.FluentIcons.settings),
              const SizedBox(height: 12),
              // 顶部标签栏
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
                      final maxExtent = _tabScrollController.position.maxScrollExtent;
                      if (maxExtent <= 0) return;
                      final next = (_tabScrollController.offset + signal.scrollDelta.dy)
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
                    child: SingleChildScrollView(
                      controller: _tabScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTabButton(
                            context,
                            icon: CustomIcons.FluentIcons.settings,
                            title: t.settingsTabGeneral,
                            index: 0,
                          ),
                          const SizedBox(width: 4),
                          _buildTabButton(
                            context,
                            icon: CustomIcons.FluentIcons.download,
                            title: t.settingsTabDownload,
                            index: 1,
                          ),
                          const SizedBox(width: 4),
                          _buildTabButton(
                            context,
                            icon: CustomIcons.FluentIcons.color,
                            title: t.settingsTabAppearance,
                            index: 2,
                          ),
                          const SizedBox(width: 4),
                          _buildTabButton(
                            context,
                            icon: CustomIcons.FluentIcons.update_restore,
                            title: t.settingsTabUpdate,
                            index: 3,
                          ),
                          const SizedBox(width: 4),
                          _buildTabButton(
                            context,
                            icon: CustomIcons.FluentIcons.developer_tools,
                            title: t.settingsTabAdvanced,
                            index: 4,
                          ),
                          // 开发者标签 - 仅在开发者模式启用时显示
                          if (isDeveloperMode) ...[
                            const SizedBox(width: 4),
                            _buildTabButton(
                              context,
                              icon: CustomIcons.FluentIcons.code,
                              title: t.settingsTabDeveloper,
                              index: 5,
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
                if (_currentTabIndex == 5 && isDeveloperMode) const DeveloperSettingsPage(),
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
                color: isSelected ? AppTheme.accentLight : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  color: isSelected ? AppTheme.accentLight : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 常规标签页
  List<Widget> _buildGeneralTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      // 系统状态
      _buildStatusSection(context),
      const SizedBox(height: 24),
      
      // 系统设置
      if (Platform.isWindows) ...[
        _buildSection(
          context,
          title: t.settingsSectionSystem,
          icon: CustomIcons.FluentIcons.power_button,
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
      
      // 行为设置
      _buildSection(
        context,
        title: t.settingsSectionBehavior,
        icon: CustomIcons.FluentIcons.processing,
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
                    value ? t.settingsAutoDownloadEnabledTitle : t.settingsAutoDownloadDisabledTitle,
                    message: value ? t.settingsAutoDownloadEnabledMessage : t.settingsAutoDownloadDisabledMessage,
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
            title: t.settingsCompleteNotifyTitle,
            subtitle: t.settingsCompleteNotifySubtitle,
            trailing: ToggleSwitch(
              checked: _notifyOnComplete,
              onChanged: (value) {
                setState(() => _notifyOnComplete = value);
                if (mounted) {
                  NotificationManager.of(context)?.showSuccess(
                    value ? t.settingsCompleteNotifyEnabledTitle : t.settingsCompleteNotifyDisabledTitle,
                    message: value ? t.settingsCompleteNotifyEnabledMessage : t.settingsCompleteNotifyDisabledMessage,
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: t.settingsOnlineStatsTitle,
            subtitle: t.settingsOnlineStatsSubtitle,
            trailing: ToggleSwitch(
              checked: _enableOnlineStats,
              onChanged: _toggleOnlineStats,
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
            subtitle: _getCloseButtonBehaviorDescription(_closeButtonBehavior, t),
            trailing: ComboBox<String>(
              value: _closeButtonBehavior,
              items: [
                ComboBoxItem(value: 'minimize_to_tray', child: Text(t.settingsCloseBehaviorMinimizeLabel)),
                ComboBoxItem(value: 'exit_app', child: Text(t.settingsCloseBehaviorExitLabel)),
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

  // 下载标签页
  List<Widget> _buildDownloadTab(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      _buildSection(
        context,
        title: t.settingsDownloadPathSection,
        icon: CustomIcons.FluentIcons.folder_open,
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
        icon: CustomIcons.FluentIcons.settings,
        children: [
          // 模式选择
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
                      ComboBoxItem(value: 'auto', child: Text(t.settingsDownloadModeAuto)),
                      ComboBoxItem(value: 'threads_only', child: Text(t.settingsDownloadModeThreadsOnly)),
                      ComboBoxItem(value: 'segments_only', child: Text(t.settingsDownloadModeSegmentsOnly)),
                      ComboBoxItem(value: 'manual', child: Text(t.settingsDownloadModeManual)),
                    ],
                    onChanged: (value) {
                      if (value != null) _updateConfig(mode: value);
                    },
                  ),
          ),
          
          const SizedBox(height: 12),
          
          // 线程设置
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
          
          // 分段设置
          Opacity(
            opacity: (_mode == 'manual' || _mode == 'segments_only') ? 1.0 : 0.5,
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
          
          // 动态分段开关
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
                    value ? t.settingsDynamicSegmentsEnabledTitle : t.settingsDynamicSegmentsDisabledTitle,
                    message: value ? t.settingsDynamicSegmentsEnabledMessage : t.settingsDynamicSegmentsDisabledMessage,
                  );
                }
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 最大同时下载任务数
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
          
          // 分段限速
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
                      value: (_segmentSpeedLimit / 1024).clamp(0, 20480).toDouble(),
                      min: 0,
                      max: 20480, // 20 MB/s
                      divisions: 200,
                      onChanged: (value) {
                        _updateConfig(segmentSpeedLimit: (value * 1024).toInt());
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
                              (_segmentSpeedLimit * _segments / 1024).toStringAsFixed(0),
                            ),
                            style: FluentTheme.of(context).typography.caption?.copyWith(
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
        ],
      ),
      const SizedBox(height: 24),
      
      // 代理设置
      _buildSection(
        context,
        title: t.settingsProxySection,
        icon: CustomIcons.FluentIcons.network_tower,
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
            
            // 代理类型
            _buildSettingItem(
              context,
              title: t.settingsProxyTypeTitle,
              subtitle: t.settingsProxyTypeSubtitle,
              trailing: ComboBox<String>(
                value: _proxyType,
                items: [
                  ComboBoxItem(value: 'system', child: Text(t.settingsProxyTypeSystem)),
                  ComboBoxItem(value: 'http', child: Text(t.settingsProxyTypeHttp)),
                  ComboBoxItem(value: 'socks5', child: Text(t.settingsProxyTypeSocks5)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _proxyType = value);
                    _updateProxyConfig();
                  }
                },
              ),
            ),
            
            
            // 只有非系统代理才显示手动配置
            if (_proxyType != 'system') ...[
              const SizedBox(height: 12),
              
              // 代理服务器地址
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
            
              // 代理认证
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
                
                // 用户名
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
                
                // 密码
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
            
            // 代理配置提示
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
                    CustomIcons.FluentIcons.info,
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
                          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.accentLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getProxyConfigTips(t),
                          style: FluentTheme.of(context).typography.caption?.copyWith(
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
    // 对于非系统代理，检查主机地址是否为空
    if (_proxyType != 'system' && _proxyHost.isEmpty) {
      NotificationManager.of(context)?.showError(
        t.settingsProxyErrorTitle,
        message: t.settingsProxyErrorMessage,
      );
      return;
    }

    // 显示测试中的提示
    NotificationManager.of(context)?.showInfo(
      t.settingsProxyTestingTitle,
      message: t.settingsProxyTestingMessage,
    );

    try {
      final service = context.read<IntegratedDownloadService>();
      
      // 对于系统代理，使用特殊的参数
      String testHost = _proxyHost;
      int testPort = _proxyPort;
      
      if (_proxyType == 'system') {
        // 系统代理不需要手动指定主机和端口
        testHost = 'system'; // 使用特殊标识
        testPort = 0; // 端口设为0表示系统代理
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

  // 高级标签页
  List<Widget> _buildAdvancedTab(BuildContext context) {
    return [
      // 内核切换
      _buildKernelSection(context),
      const SizedBox(height: 24),
      
      // 开发者模式开关
      _buildDeveloperModeToggle(context),
      const SizedBox(height: 24),
      
      _buildDangerZone(context),
    ];
  }
  
  Widget _buildDeveloperModeToggle(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Consumer<DeveloperModeService>(
      builder: (context, devMode, child) {
        return _buildSection(
          context,
          title: t.settingsDeveloperSection,
          icon: CustomIcons.FluentIcons.developer_tools,
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
                      value ? t.settingsDeveloperModeEnabledTitle : t.settingsDeveloperModeDisabledTitle,
                      message: value ? t.settingsDeveloperModeEnabledMessage : t.settingsDeveloperModeDisabledMessage,
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
                      CustomIcons.FluentIcons.info,
                      size: 16,
                      color: AppTheme.accentLight,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.settingsDeveloperModeHint,
                        style: FluentTheme.of(context).typography.caption?.copyWith(
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
      icon: CustomIcons.FluentIcons.processing,
      children: [
        _buildSettingItem(
          context,
          title: t.settingsKernelCurrentTitle,
          subtitle: _useNewKernel 
              ? '${AppConstants.newKernelFullName} | ${AppConstants.newKernelVersion} | ${AppConstants.newKernelBuildNumber}'
              : '${AppConstants.kernelFullName} | ${AppConstants.kernelVersion} | ${AppConstants.kernelBuildNumber}',
          trailing: _switchingKernel
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Container(
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
                      color: _kernelOnline ? AppTheme.statusSuccess : AppTheme.statusError,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _buildSettingItem(
          context,
          title: t.settingsKernelNsfxTitle,
          subtitle: t.settingsKernelNsfxSubtitle,
          trailing: ToggleSwitch(
            checked: _useNewKernel,
            onChanged: _switchingKernel ? null : _switchKernel,
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
                CustomIcons.FluentIcons.info,
                size: 16,
                color: AppTheme.accentLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _useNewKernel
                      ? t.settingsKernelNsfxHint
                      : t.settingsKernelSodaHint,
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
    final kernelDisplayName = _useNewKernel ? t.settingsStatusKernelNsfx : t.settingsStatusKernelSoda;
    
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
              Icon(CustomIcons.FluentIcons.status_circle_inner, size: 16),
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
          Row(
            children: [
              Expanded(
                child: _buildStatusIndicator(
                  context,
                  title: kernelDisplayName,
                  isOnline: _kernelOnline,
                  icon: CustomIcons.FluentIcons.server,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusIndicator(
                  context,
                  title: t.settingsStatusBrowserExtension,
                  isOnline: _browserConnected,
                  icon: CustomIcons.FluentIcons.edge_logo,
                ),
              ),
            ],
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

  Widget _buildDeveloperSection(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Consumer<DeveloperModeService>(
      builder: (context, devMode, child) {
        return _buildSection(
          context,
          title: t.settingsDeveloperSection,
          icon: CustomIcons.FluentIcons.developer_tools,
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
                      value ? t.settingsDeveloperModeEnabledTitle : t.settingsDeveloperModeDisabledTitle,
                      message: value ? t.settingsDeveloperModeEnabledMessage : t.settingsDeveloperModeDisabledMessage,
                    );
                  }
                },
              ),
            ),
            
            // 只有开启开发者模式才显示下面的选项
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CustomIcons.FluentIcons.info,
                          size: 16,
                          color: AppTheme.accentLight,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t.settingsDeveloperPageVisibilityTitle,
                          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.accentLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    _buildSettingItem(
                      context,
                      title: t.settingsDeveloperShowLogTitle,
                      subtitle: t.settingsDeveloperShowLogSubtitle,
                      trailing: ToggleSwitch(
                        checked: devMode.showLogPage,
                        onChanged: (value) => devMode.setShowLogPage(value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _buildSettingItem(
                      context,
                      title: t.settingsDeveloperShowStatusTitle,
                      subtitle: t.settingsDeveloperShowStatusSubtitle,
                      trailing: ToggleSwitch(
                        checked: devMode.showStatusPage,
                        onChanged: (value) => devMode.setShowStatusPage(value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _buildSettingItem(
                      context,
                      title: t.settingsDeveloperShowOnlineStatsTitle,
                      subtitle: t.settingsDeveloperShowOnlineStatsSubtitle,
                      trailing: ToggleSwitch(
                        checked: devMode.showOnlineStatsPage,
                        onChanged: (value) => devMode.setShowOnlineStatsPage(value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _buildSettingItem(
                      context,
                      title: t.settingsDeveloperShowWebCheckTitle,
                      subtitle: t.settingsDeveloperShowWebCheckSubtitle,
                      trailing: ToggleSwitch(
                        checked: devMode.showWebCheckPage,
                        onChanged: (value) => devMode.setShowWebCheckPage(value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // 提示信息
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.statusWarning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.statusWarning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      CustomIcons.FluentIcons.warning,
                      size: 16,
                      color: AppTheme.statusWarning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        t.settingsDeveloperPageHint,
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.statusWarning,
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
      builder: (context) => ContentDialog(
        title: Text(t.settingsDangerConfirmTitle),
        content: Text(t.settingsDangerConfirmMessage),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: Text(t.settingsCancelButton),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 显示加载提示
              if (mounted) {
                NotificationManager.of(context)?.showInfo(
                  t.settingsDangerClearingTitle,
                  message: t.settingsDangerClearingMessage,
                );
              }
              
              // 调用清除API
              final kernelService = context.read<KernelService>();
              final success = await kernelService.clearAllData();
              
              if (mounted) {
                if (success) {
                  NotificationManager.of(context)?.showSuccess(
                    t.settingsDangerClearedTitle,
                    message: t.settingsDangerClearedMessage,
                  );
                } else {
                  NotificationManager.of(context)?.showError(
                    t.settingsDangerClearFailedTitle,
                    message: t.settingsDangerClearFailedMessage,
                  );
                }
              }
            },
            child: Text(t.settingsDangerConfirmButton),
          ),
        ],
      ),
    );
  }
}
