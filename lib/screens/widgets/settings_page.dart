import 'package:fluent_ui/fluent_ui.dart';
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
      return prefs.getString('user_name') ?? '用户';
    } catch (e) {
      return '用户';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _userNameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('获取中...');
        }
        
        if (snapshot.hasError) {
          return const Text('获取失败');
        }
        
        return Text(snapshot.data ?? '未知用户');
      },
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  // Tab state
  int _currentTabIndex = 0;
  
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
    final userProfile = UserProfileService();
    await userProfile.setStatsEnabled(value);
    
    if (mounted) {
      setState(() {
        _enableOnlineStats = value;
      });
      
      NotificationManager.of(context)?.showSuccess(value ? '在线统计已启用' : '在线统计已禁用', message: value 
              ? '您的设备将参与在线用户统计，帮助我们了解软件使用情况' 
              : '您的设备将不再发送统计信息');
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
      
      if (useNew) {
        // 切换到新内核：先停止旧内核，再启动新内核
        await kernelService.stopKernel();
        final success = await kernelManager.start(type: KernelType.next);
        
        if (success) {
          await config.setBool('kernel.use_new_kernel', true);
          
          if (mounted) {
            setState(() {
              _useNewKernel = true;
              _currentKernelName = kernelManager.kernelName;
            });
            
            NotificationManager.of(context)?.showSuccess('内核已切换', message: '当前使用: ${kernelManager.kernelName}');
          }
        } else {
          if (mounted) {
            NotificationManager.of(context)?.showError('切换失败', message: '无法启动新内核，请稍后重试');
          }
        }
      } else {
        // 切换到旧内核：先停止新内核，再启动旧内核
        await kernelManager.stop();
        final success = await kernelService.startKernel();
        
        if (success) {
          await config.setBool('kernel.use_new_kernel', false);
          
          if (mounted) {
            setState(() {
              _useNewKernel = false;
              _currentKernelName = 'Soda Speed Force (Legacy)';
            });
            
            NotificationManager.of(context)?.showSuccess('内核已切换', message: '当前使用: Soda Speed Force (Legacy)');
          }
        } else {
          if (mounted) {
            NotificationManager.of(context)?.showError('切换失败', message: '无法启动旧内核，请稍后重试');
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
      
      if (mounted) {
        setState(() {
          _closeButtonBehavior = closeButtonBehavior;
          _showTrayRunningStatus = showTrayRunningStatus;
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
        NotificationManager.of(context)?.showSuccess('自启动已修复', message: '检测到旧版本的自启动注册，已自动更新为当前版本');
      }
    }
  }

  Future<void> _toggleOpenOnStartup(bool value) async {
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
        value ? '开机自启已开启' : '开机自启已关闭',
        message: value ? '软件将随系统启动自动运行' : '软件将不会自动运行',
      );
    } else if (mounted) {
      NotificationManager.of(context)?.showError('设置失败', message: value ? '无法开启开机自启' : '无法关闭开机自启');
    }
  }
  
  Future<void> _saveShowTrayRunningStatus(bool value) async {
    try {
      final config = Provider.of<ClientConfigService>(context, listen: false);
      await config.setShowTrayRunningStatus(value);
      
      if (mounted) {
        setState(() {
          _showTrayRunningStatus = value;
        });
        
        // 立即更新托盘状态
        systemTrayService.updateToolTip(!appWindow.isVisible);
        
        NotificationManager.of(context)?.showSuccess(
          value ? '已开启后台运行提示' : '已关闭后台运行提示',
          message: value 
              ? '当窗口隐藏时，托盘图标将显示"正在后台运行"'
              : '托盘图标将始终只显示应用名称',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError('设置失败', message: '无法保存设置: $e');
      }
    }
  }

  Future<void> _saveCloseButtonBehavior(String behavior) async {
    try {
      final config = Provider.of<ClientConfigService>(context, listen: false);
      await config.setCloseButtonBehavior(behavior);
      
      if (mounted) {
        setState(() {
          _closeButtonBehavior = behavior;
        });
        
        NotificationManager.of(context)?.showSuccess('设置已保存', message: '关闭按钮行为已设为${_getCloseButtonBehaviorDescription(behavior)}');
      }
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError('设置失败', message: '无法保存设置: $e');
      }
    }
  }
  
  String _getCloseButtonBehaviorDescription(String behavior) {
    switch (behavior) {
      case 'minimize_to_tray':
        return '最小化到系统托盘，保持后台运行';
      case 'exit_app':
        return '完全退出应用程序';
      default:
        return '未知行为';
    }
  }
  
  
  @override
  void dispose() {
    _statusTimer?.cancel();
    // 移除开发者模式监听器
    _devModeService?.removeListener(_onDeveloperModeChanged);
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

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => ContentDialog(
        title: const Text('设置下载路径'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('请输入或浏览选择下载保存路径:'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: controller,
                    placeholder: 'C:\\Downloads',
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
                  child: const Text('浏览'),
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
                    '提示:',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: FluentTheme.of(context).accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• 可以直接输入完整的文件夹路径\n• 点击"浏览"按钮可视化选择文件夹\n• 示例: C:\\Users\\用户名\\Downloads',
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
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('确定'),
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
          NotificationManager.of(context)?.showSuccess('设置成功', message: '下载路径已更改为: $result');
        }
      } else {
        if (mounted) {
          NotificationManager.of(context)?.showError('设置失败', message: '无法更改下载路径，请检查路径是否有效');
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
      NotificationManager.of(context)?.showSuccess('代理设置已保存', message: _useProxy ? '已启用代理: $_proxyHost:$_proxyPort' : '已禁用代理');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 追踪重建
    PerformanceMonitorService().trackRebuild('SettingsPage');

    // 优化：使用 Selector 只监听 developerMode 布尔值，而非整个 DeveloperModeService
    final isDeveloperMode = context.select<DeveloperModeService, bool>((s) => s.developerMode);
    
    return ScaffoldPage(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsPageHeader(title: '设置', icon: CustomIcons.FluentIcons.settings),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabButton(
                      context,
                      icon: CustomIcons.FluentIcons.settings,
                      title: '常规',
                      index: 0,
                    ),
                    const SizedBox(width: 4),
                    _buildTabButton(
                      context,
                      icon: CustomIcons.FluentIcons.download,
                      title: '下载',
                      index: 1,
                    ),
                    const SizedBox(width: 4),
                    _buildTabButton(
                      context,
                      icon: CustomIcons.FluentIcons.color,
                      title: '界面',
                      index: 2,
                    ),
                    const SizedBox(width: 4),
                    _buildTabButton(
                      context,
                      icon: CustomIcons.FluentIcons.update_restore,
                      title: '更新',
                      index: 3,
                    ),
                    const SizedBox(width: 4),
                    _buildTabButton(
                      context,
                      icon: CustomIcons.FluentIcons.developer_tools,
                      title: '高级',
                      index: 4,
                    ),
                    // 开发者标签 - 仅在开发者模式启用时显示
                    if (isDeveloperMode) ...[
                      const SizedBox(width: 4),
                      _buildTabButton(
                        context,
                        icon: CustomIcons.FluentIcons.code,
                        title: '开发者',
                        index: 5,
                      ),
                    ],
                  ],
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
    return [
      // 系统状态
      _buildStatusSection(context),
      const SizedBox(height: 24),
      
      // 系统设置
      if (Platform.isWindows) ...[
        _buildSection(
          context,
          title: '系统设置',
          icon: CustomIcons.FluentIcons.power_button,
          children: [
            _buildSettingItem(
              context,
              title: '开机自启',
              subtitle: '随系统启动自动运行',
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
        title: '行为设置',
        icon: CustomIcons.FluentIcons.processing,
        children: [
          _buildSettingItem(
            context,
            title: '自动开始下载',
            subtitle: '添加任务后立即开始下载',
            trailing: ToggleSwitch(
              checked: _autoStart,
              onChanged: (value) {
                setState(() => _autoStart = value);
                if (mounted) {
                  NotificationManager.of(context)?.showSuccess(
                    value ? '自动开始下载已开启' : '自动开始下载已关闭',
                    message: value ? '添加任务后将自动开始' : '添加任务后需手动开始',
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: '完成通知',
            subtitle: '下载完成后显示系统通知',
            trailing: ToggleSwitch(
              checked: _notifyOnComplete,
              onChanged: (value) {
                setState(() => _notifyOnComplete = value);
                if (mounted) {
                  NotificationManager.of(context)?.showSuccess(
                    value ? '完成通知已开启' : '完成通知已关闭',
                    message: value ? '下载完成后将收到通知' : '下载完成后不再通知',
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: '参与在线统计',
            subtitle: '帮助我们了解软件使用情况（匿名统计）',
            trailing: ToggleSwitch(
              checked: _enableOnlineStats,
              onChanged: _toggleOnlineStats,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: '托盘提示',
            subtitle: '在系统托盘提示中显示后台运行状态',
            trailing: ToggleSwitch(
              checked: _showTrayRunningStatus,
              onChanged: _saveShowTrayRunningStatus,
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: '关闭按钮行为',
            subtitle: _getCloseButtonBehaviorDescription(_closeButtonBehavior),
            trailing: ComboBox<String>(
              value: _closeButtonBehavior,
              items: const [
                ComboBoxItem(value: 'minimize_to_tray', child: Text('最小化到托盘')),
                ComboBoxItem(value: 'exit_app', child: Text('退出软件')),
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
    return [
      _buildSection(
        context,
        title: '下载路径',
        icon: CustomIcons.FluentIcons.folder_open,
        children: [
          _buildSettingItem(
            context,
            title: '保存位置',
            subtitle: _downloadPath,
            trailing: Button(
              onPressed: _kernelOnline ? _changeDownloadPath : null,
              child: const Text('更改'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      
      _buildSection(
        context,
        title: '下载配置',
        icon: CustomIcons.FluentIcons.settings,
        children: [
          // 模式选择
          _buildSettingItem(
            context,
            title: '下载模式',
            subtitle: _getModeDescription(_mode),
            trailing: _loadingConfig
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : ComboBox<String>(
                    value: _mode,
                    items: const [
                      ComboBoxItem(value: 'auto', child: Text('全自动 (推荐)')),
                      ComboBoxItem(value: 'threads_only', child: Text('仅设置线程')),
                      ComboBoxItem(value: 'segments_only', child: Text('仅设置分段')),
                      ComboBoxItem(value: 'manual', child: Text('手动配置')),
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
                title: '线程数',
                subtitle: '每个任务使用的下载线程数量 (1-32)',
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
                title: '分段数',
                subtitle: '每个文件分割的块数 (1-32)',
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
            title: '动态分段',
            subtitle: '自动分割慢速分段以提升下载速度 (推荐开启)',
            trailing: ToggleSwitch(
              checked: _enableDynamicSegments,
              onChanged: (value) {
                _updateConfig(enableDynamicSegments: value);
                if (mounted) {
                  NotificationManager.of(context)?.showSuccess(
                    value ? '动态分段已开启' : '动态分段已关闭',
                    message: value ? '将根据网络状况自动调整分段' : '将使用固定分段数',
                  );
                }
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 最大同时下载任务数
          _buildSettingItem(
            context,
            title: '最大同时下载任务数',
            subtitle: '同时进行的下载任务数量 (1-10)',
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
            title: '分段限速',
            subtitle: '限制每个分段的下载速度 (0表示不限速)\n提示：总速度 = 分段限速 × 分段数',
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
                              ? '不限速' 
                              : '${(_segmentSpeedLimit / 1024).toStringAsFixed(0)} KB/s',
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                        if (_segmentSpeedLimit > 0 && _segments > 1)
                          Text(
                            '总: ${(_segmentSpeedLimit * _segments / 1024).toStringAsFixed(0)} KB/s',
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
        title: '代理设置',
        icon: CustomIcons.FluentIcons.network_tower,
        children: [
          _buildSettingItem(
            context,
            title: '使用代理',
            subtitle: '通过代理服务器进行下载',
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
              title: '代理类型',
              subtitle: '选择代理协议类型',
              trailing: ComboBox<String>(
                value: _proxyType,
                items: const [
                  ComboBoxItem(value: 'system', child: Text('跟随系统')),
                  ComboBoxItem(value: 'http', child: Text('HTTP/HTTPS')),
                  ComboBoxItem(value: 'socks5', child: Text('SOCKS5')),
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
                title: '代理服务器',
                subtitle: '代理服务器的地址和端口',
                trailing: SizedBox(
                  width: 300,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextBox(
                          placeholder: '代理地址 (如: 127.0.0.1)',
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
                title: '代理认证',
                subtitle: '代理服务器需要用户名和密码',
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
                  title: '用户名',
                  subtitle: '代理服务器的用户名',
                  trailing: SizedBox(
                    width: 200,
                    child: TextBox(
                      placeholder: '用户名',
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
                  title: '密码',
                  subtitle: '代理服务器的密码',
                  trailing: SizedBox(
                    width: 200,
                    child: PasswordBox(
                      placeholder: '密码',
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
                          '代理配置提示',
                          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.accentLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getProxyConfigTips(),
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
                    child: const Text('测试连接'),
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
    // 对于非系统代理，检查主机地址是否为空
    if (_proxyType != 'system' && _proxyHost.isEmpty) {
      NotificationManager.of(context)?.showError('配置错误', message: '请先输入代理服务器地址');
      return;
    }

    // 显示测试中的提示
    NotificationManager.of(context)?.showInfo('正在测试...', message: '正在测试代理连接，请稍候');

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
          NotificationManager.of(context)?.showSuccess('连接成功', message: '代理服务器连接正常，可以正常使用');
        } else {
          NotificationManager.of(context)?.showError('连接失败', message: '无法连接到代理服务器，请检查配置');
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError('测试失败', message: '代理连接测试失败: $e');
      }
    }
  }

  String _getProxyConfigTips() {
    switch (_proxyType) {
      case 'system':
        return '• 自动使用系统配置的代理设置\n• 支持 Windows、macOS 和 Linux 系统代理\n• 配置后将应用到所有新的下载任务\n• 正在进行的下载不会受到影响';
      case 'http':
        return '• 使用 HTTP/HTTPS 代理协议\n• 配置后将应用到所有新的下载任务\n• 正在进行的下载不会受到影响\n• 支持用户名密码认证';
      case 'socks5':
        return '• 使用 SOCKS5 代理协议\n• 需要安装 aiohttp-socks 库支持\n• 配置后将应用到所有新的下载任务\n• 正在进行的下载不会受到影响';
      default:
        return '• 支持系统代理、HTTP/HTTPS 和 SOCKS5 代理\n• 配置后将应用到所有新的下载任务\n• 正在进行的下载不会受到影响';
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
    return Consumer<DeveloperModeService>(
      builder: (context, devMode, child) {
        return _buildSection(
          context,
          title: '开发者选项',
          icon: CustomIcons.FluentIcons.developer_tools,
          children: [
            _buildSettingItem(
              context,
              title: '开发者模式',
              subtitle: '启用后将显示"开发者"标签页，可配置调试和诊断功能',
              trailing: ToggleSwitch(
                checked: devMode.developerMode,
                onChanged: (value) {
                  devMode.setDeveloperMode(value);
                  if (context.mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      value ? '开发者模式已开启' : '开发者模式已关闭',
                      message: value ? '已启用高级调试功能' : '已禁用高级调试功能',
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
                        '开发者模式已启用，请切换到"开发者"标签页进行详细配置',
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
    return _buildSection(
      context,
      title: '下载内核',
      icon: CustomIcons.FluentIcons.processing,
      children: [
        _buildSettingItem(
          context,
          title: '当前内核',
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
                    _kernelOnline ? '在线' : '离线',
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
          title: 'NSFX',
          subtitle: 'NSFX - NEXT SPEED FORCE X KERNEL',
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
                      ? 'NSFX Kernel: 高效 | 简洁 | 新思路'
                      : 'Soda Kernel: 稳定 | 兼容 | 问题少 ',
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
    final kernelDisplayName = _useNewKernel ? 'NSFX Kernel' : 'Soda Kernel (Legacy)';
    
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
                '系统状态',
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
                  title: 'Browser Extension',
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
  
  String _getModeDescription(String mode) {
    switch (mode) {
      case 'auto':
        return '智能动态分段，根据文件大小自动优化 (推荐)';
      case 'threads_only':
        return '手动设置线程数，分段数自动计算';
      case 'segments_only':
        return '手动设置分段数，线程数自动计算';
      case 'manual':
        return '完全手动控制，适合高级用户';
      default:
        return '未知模式';
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
    return Consumer<DeveloperModeService>(
      builder: (context, devMode, child) {
        return _buildSection(
          context,
          title: '开发者选项',
          icon: CustomIcons.FluentIcons.developer_tools,
          children: [
            _buildSettingItem(
              context,
              title: '开发者模式',
              subtitle: '启用调试和诊断功能',
              trailing: ToggleSwitch(
                checked: devMode.developerMode,
                onChanged: (value) {
                  devMode.setDeveloperMode(value);
                  if (context.mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      value ? '开发者模式已开启' : '开发者模式已关闭',
                      message: value ? '已启用高级调试功能' : '已禁用高级调试功能',
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
                          '调试页面显示设置',
                          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.accentLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    _buildSettingItem(
                      context,
                      title: '显示日志页面',
                      subtitle: '在导航栏显示日志查看器',
                      trailing: ToggleSwitch(
                        checked: devMode.showLogPage,
                        onChanged: (value) => devMode.setShowLogPage(value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _buildSettingItem(
                      context,
                      title: '显示状态页面',
                      subtitle: '在导航栏显示系统状态监控',
                      trailing: ToggleSwitch(
                        checked: devMode.showStatusPage,
                        onChanged: (value) => devMode.setShowStatusPage(value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _buildSettingItem(
                      context,
                      title: '显示在线统计页面',
                      subtitle: '在导航栏显示在线用户统计',
                      trailing: ToggleSwitch(
                        checked: devMode.showOnlineStatsPage,
                        onChanged: (value) => devMode.setShowOnlineStatsPage(value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    _buildSettingItem(
                      context,
                      title: '显示 Web 检测页面',
                      subtitle: '在导航栏显示网站状态检测工具',
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
                        '调试页面会占用系统资源，建议仅在需要时启用',
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
    return DangerZone(
      children: [
        SettingsItem(
          title: '清理临时文件',
          subtitle: '扫描并删除下载目录中的 .temp 临时文件',
          trailing: Button(
            onPressed: _downloadPath.isEmpty ? null : _showTempFilesDialog,
            child: const Text('清理临时文件'),
          ),
        ),
        const SizedBox(height: 12),
        SettingsItem(
          title: '清除所有数据',
          subtitle: '删除所有下载任务和历史记录',
          trailing: FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppTheme.statusError),
            ),
            onPressed: _confirmClearData,
            child: const Text('清除数据'),
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
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清除所有下载任务和历史记录吗？此操作不可恢复。'),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // 显示加载提示
              if (mounted) {
                NotificationManager.of(context)?.showInfo('正在清除...', message: '请稍候');
              }
              
              // 调用清除API
              final kernelService = context.read<KernelService>();
              final success = await kernelService.clearAllData();
              
              if (mounted) {
                if (success) {
                  NotificationManager.of(context)?.showSuccess('已清除', message: '所有下载任务和历史记录已清除');
                } else {
                  NotificationManager.of(context)?.showError('清除失败', message: '无法清除数据，请确保下载核心正在运行');
                }
              }
            },
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }
}
