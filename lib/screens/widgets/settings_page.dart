import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';
import '../../services/integrated_download_service.dart';
import '../../services/kernel_service.dart';
import '../../services/developer_mode_service.dart';
import '../../services/client_config_service.dart';
import '../../widgets/folder_picker_dialog.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/temp_files_dialog.dart';
import '../../services/auto_start_service.dart';
import '../../theme/app_theme.dart';
import 'appearance_settings_page.dart';
import 'update_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class GetUserName extends StatelessWidget {
  const GetUserName({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUserName(),
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
  
  Future<String> _getUserName() async {
    try {
      // 首先尝试从系统环境变量获取用户名
      final userName = Platform.environment['USERNAME'] ?? Platform.environment['USER'];
      if (userName != null && userName.isNotEmpty) {
        return userName;
    }
      
      // 如果环境变量获取失败，尝试从SharedPreferences获取
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_name') ?? '用户';
    } catch (e) {
      return '用户';
  }
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
  bool _loadingConfig = true;
  
  bool _autoStart = true;
  bool _openOnStartup = false;
  final _autoStartService = AutoStartService();
  bool _notifyOnComplete = true;
  String _downloadPath = '';
  String _closeButtonBehavior = 'minimize_to_tray';
  
  // Status monitoring
  bool _kernelOnline = false;
  bool _browserConnected = false;
  Timer? _statusTimer;
  


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
      _loadDownloadPath();
      _startStatusMonitoring();
      _loadAutoStartSettings();
      _loadBehaviorSettings();
    });
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
      
      if (mounted) {
        setState(() {
          _closeButtonBehavior = closeButtonBehavior;
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
        displayInfoBar(
          context,
          builder: (context, close) => const InfoBar(
            title: Text('自启动已修复'),
            content: Text('检测到旧版本的自启动注册，已自动更新为当前版本'),
            severity: InfoBarSeverity.success,
          ),
          duration: const Duration(seconds: 4),
        );
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
    } else if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('设置失败'),
          content: Text(value ? '无法开启开机自启' : '无法关闭开机自启'),
          severity: InfoBarSeverity.error,
        ),
      );
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
        
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('设置已保存'),
            content: Text('关闭按钮行为已设为${_getCloseButtonBehaviorDescription(behavior)}'),
            severity: InfoBarSeverity.success,
          ),
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('设置失败'),
            content: Text('无法保存设置: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
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
    super.dispose();
  }
  
  void _startStatusMonitoring() {
    _checkStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkStatus();
    });
  }
  
  Future<void> _checkStatus() async {
    if (!mounted) return;
    
    final kernelService = context.read<KernelService>();
    final kernelOnline = kernelService.isRunning;
    
    // Check browser connection by checking if extension is sending data
    // For now, we'll assume browser is connected if kernel is running
    // You can enhance this by adding a specific endpoint to check extension status
    final browserConnected = kernelOnline; // Placeholder logic
    
    if (mounted) {
      setState(() {
        _kernelOnline = kernelOnline;
        _browserConnected = browserConnected;
      });
    }
  }
  
  Future<void> _loadDownloadPath() async {
    if (!mounted) return;
    
    try {
      final kernelService = context.read<KernelService>();
      final path = await kernelService.getDownloadDir();
      
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
      final kernelService = context.read<KernelService>();
      final success = await kernelService.setDownloadDir(result);

      if (success && mounted) {
        setState(() {
          _downloadPath = result;
        });

        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('设置成功'),
              content: Text('下载路径已更改为: $result'),
              severity: InfoBarSeverity.success,
            ),
          );
        }
      } else {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (context, close) => const InfoBar(
              title: Text('设置失败'),
              content: Text('无法更改下载路径，请检查路径是否有效'),
              severity: InfoBarSeverity.error,
            ),
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

  Future<void> _updateConfig({int? threads, int? segments, String? mode, int? maxConcurrentTasks, int? segmentSpeedLimit}) async {
    final service = context.read<IntegratedDownloadService>();
    
    // Optimistic update
    setState(() {
      if (threads != null) _threads = threads;
      if (segments != null) _segments = segments;
      if (mode != null) _mode = mode;
      if (maxConcurrentTasks != null) _maxConcurrentTasks = maxConcurrentTasks;
      if (segmentSpeedLimit != null) _segmentSpeedLimit = segmentSpeedLimit;
    });
    
    await service.setDownloadConfig(
      threads: threads ?? _threads,
      segments: segments ?? _segments,
      mode: mode ?? _mode,
      maxConcurrentTasks: maxConcurrentTasks ?? _maxConcurrentTasks,
      segmentSpeedLimit: segmentSpeedLimit ?? _segmentSpeedLimit,
    );
    
    // Reload to ensure sync
    await _loadConfig();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.scrollable(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsPageHeader(title: '设置', icon: FluentIcons.settings),
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
                  icon: FluentIcons.settings,
                  title: '常规',
                  index: 0,
                ),
                const SizedBox(width: 4),
                _buildTabButton(
                  context,
                  icon: FluentIcons.download,
                  title: '下载',
                  index: 1,
                ),
                const SizedBox(width: 4),
                _buildTabButton(
                  context,
                  icon: FluentIcons.color,
                  title: '界面',
                  index: 2,
                ),
                const SizedBox(width: 4),
                _buildTabButton(
                  context,
                  icon: FluentIcons.update_restore,
                  title: '更新',
                  index: 3,
                ),
                const SizedBox(width: 4),
                _buildTabButton(
                  context,
                  icon: FluentIcons.developer_tools,
                  title: '高级',
                  index: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      children: [
        if (_currentTabIndex == 0) ..._buildGeneralTab(context),
        if (_currentTabIndex == 1) ..._buildDownloadTab(context),
        if (_currentTabIndex == 2) const AppearanceSettingsPage(),
        if (_currentTabIndex == 3) const UpdatePage(),
        if (_currentTabIndex == 4) ..._buildAdvancedTab(context),
        const SizedBox(height: 40),
      ],
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
          icon: FluentIcons.power_button,
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
        icon: FluentIcons.processing,
        children: [
          _buildSettingItem(
            context,
            title: '自动开始下载',
            subtitle: '添加任务后立即开始下载',
            trailing: ToggleSwitch(
              checked: _autoStart,
              onChanged: (value) => setState(() => _autoStart = value),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            context,
            title: '完成通知',
            subtitle: '下载完成后显示系统通知',
            trailing: ToggleSwitch(
              checked: _notifyOnComplete,
              onChanged: (value) => setState(() => _notifyOnComplete = value),
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
        icon: FluentIcons.folder_open,
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
        icon: FluentIcons.settings,
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
    ];
  }

  // 高级标签页
  List<Widget> _buildAdvancedTab(BuildContext context) {
    return [
      // 开发者模式
      _buildDeveloperSection(context),
      const SizedBox(height: 24),
      
      _buildDangerZone(context),
    ];
  }

  Widget _buildStatusSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FluentTheme.of(context).resources.cardStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.status_circle_inner, size: 16),
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
                  title: 'NSFX Download Kernel',
                  isOnline: _kernelOnline,
                  icon: FluentIcons.server,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusIndicator(
                  context,
                  title: 'NSFX Browser Extension',
                  isOnline: _browserConnected,
                  icon: FluentIcons.edge_logo,
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
          icon: FluentIcons.developer_tools,
          children: [
            _buildSettingItem(
              context,
              title: '开发者模式',
              subtitle: '启用调试和诊断功能',
              trailing: ToggleSwitch(
                checked: devMode.developerMode,
                onChanged: (value) => devMode.setDeveloperMode(value),
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
                          FluentIcons.info,
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
                      FluentIcons.warning,
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
                displayInfoBar(
                  context,
                  builder: (context, close) => const InfoBar(
                    title: Text('正在清除...'),
                    content: Text('请稍候'),
                    severity: InfoBarSeverity.info,
                  ),
                );
              }
              
              // 调用清除API
              final kernelService = context.read<KernelService>();
              final success = await kernelService.clearAllData();
              
              if (mounted) {
                if (success) {
                  displayInfoBar(
                    context,
                    builder: (context, close) => const InfoBar(
                      title: Text('已清除'),
                      content: Text('所有下载任务和历史记录已清除'),
                      severity: InfoBarSeverity.success,
                    ),
                  );
                } else {
                  displayInfoBar(
                    context,
                    builder: (context, close) => const InfoBar(
                      title: Text('清除失败'),
                      content: Text('无法清除数据，请确保下载核心正在运行'),
                      severity: InfoBarSeverity.error,
                    ),
                  );
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
