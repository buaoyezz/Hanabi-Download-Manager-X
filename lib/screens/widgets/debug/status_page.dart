import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/kernel_service.dart';
import '../../../services/kernel/kernel_manager.dart';
import '../../../services/network_status_service.dart';
import '../../../services/app_logger_service.dart';
import '../../../services/auto_start_service.dart';
import '../../../services/client_config_service.dart';
import '../../../services/integrated_download_service.dart';
import '../../../models/download_task.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/settings_components.dart';
import '../../../utils/constants.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  Timer? _refreshTimer;
  bool _kernelHealthy = false;
  String? _kernelVersion;
  bool _checkingKernel = false;
  
  Map<String, dynamic>? _apiTestResults;
  bool _testingApi = false;
  
  // 系统信息
  Map<String, dynamic>? _systemInfo;
  Map<String, dynamic>? _kernelStats;
  
  // 自启动状态
  bool? _autoStartEnabled;
  bool? _autoStartPathCorrect;
  String? _registeredPath;
  bool _checkingAutoStart = false;

  @override
  void initState() {
    super.initState();
    _loadSystemInfo();
    _checkKernelHealth();
    _loadKernelStats();
    _checkAutoStartStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkKernelHealth();
      _loadKernelStats();
    });
  }
  
  Future<void> _loadSystemInfo() async {
    final info = <String, dynamic>{};
    info['platform'] = Platform.operatingSystem;
    info['version'] = Platform.operatingSystemVersion;
    info['processors'] = Platform.numberOfProcessors;
    info['dart_version'] = Platform.version.split(' ').first;
    
    if (!mounted) return;
    setState(() {
      _systemInfo = info;
    });
  }
  
  Future<void> _checkAutoStartStatus() async {
    if (!Platform.isWindows) return;
    
    if (!mounted) return;
    setState(() {
      _checkingAutoStart = true;
    });
    
    try {
      final autoStartService = AutoStartService();
      final enabled = await autoStartService.isAutoStartEnabled();
      final pathCorrect = await autoStartService.isRegisteredPathCorrect();
      final registeredPath = await autoStartService.getRegisteredPath();
      
      if (!mounted) return;
      setState(() {
        _autoStartEnabled = enabled;
        _autoStartPathCorrect = pathCorrect;
        _registeredPath = registeredPath;
        _checkingAutoStart = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingAutoStart = false;
      });
    }
  }
  
  /// 下载浏览器扩展插件
  Future<void> _downloadExtension() async {
    const extensionUrl = 'https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.0.0/chrome_extension.zip';
    
    try {
      final downloadService = context.read<IntegratedDownloadService>();
      await downloadService.addTask(extensionUrl, 'chrome_extension.zip');
      
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => const InfoBar(
            title: Text('下载已添加'),
            content: Text('浏览器扩展插件已添加到下载列表'),
            severity: InfoBarSeverity.success,
          ),
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('下载失败'),
            content: Text('无法添加下载任务: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }
  
  /// 打开浏览器扩展商店页面
  Future<void> _openExtensionStore() async {
    const storeUrl = 'https://microsoftedge.microsoft.com/addons/detail/nifalaonnaeobogcnhfoeaklpihcaeia';
    
    try {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('无法打开链接');
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('打开失败'),
            content: Text('无法打开浏览器: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }
  
  Future<void> _fixAutoStart() async {
    if (!Platform.isWindows) return;
    
    try {
      final autoStartService = AutoStartService();
      final success = await autoStartService.verifyAndFixAutoStart();
      
      if (!mounted) return;
      
      if (success) {
        displayInfoBar(
          context,
          builder: (context, close) => const InfoBar(
            title: Text('修复成功'),
            content: Text('自启动注册已更新为当前版本'),
            severity: InfoBarSeverity.success,
          ),
          duration: const Duration(seconds: 3),
        );
        
        // 重新检测状态
        await _checkAutoStartStatus();
      } else {
        displayInfoBar(
          context,
          builder: (context, close) => const InfoBar(
            title: Text('修复失败'),
            content: Text('无法更新自启动注册，请检查权限'),
            severity: InfoBarSeverity.error,
          ),
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (!mounted) return;
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('修复失败'),
          content: Text('发生错误: $e'),
          severity: InfoBarSeverity.error,
        ),
        duration: const Duration(seconds: 3),
      );
    }
  }
  
  Future<void> _loadKernelStats() async {
    try {
      // 优先从 IntegratedDownloadService 获取真实数据
      final downloadService = context.read<IntegratedDownloadService>();
      final tasks = downloadService.tasks;
      
      // 统计各状态的任务
      int totalDownloads = tasks.length;
      int activeTasks = tasks.where((t) => 
        t.status == DownloadStatus.downloading || 
        t.status == DownloadStatus.pending
      ).length;
      int completedTasks = tasks.where((t) => t.status == DownloadStatus.completed).length;
      int failedTasks = tasks.where((t) => t.status == DownloadStatus.failed).length;
      
      // 计算总下载量
      int totalDownloadedBytes = 0;
      for (final task in tasks) {
        if (task.status == DownloadStatus.completed && task.fileSize != null) {
          totalDownloadedBytes += task.fileSize!;
        } else if (task.status == DownloadStatus.downloading && task.downloadedSize != null) {
          totalDownloadedBytes += task.downloadedSize!;
        }
      }
      
      if (!mounted) return;
      setState(() {
        _kernelStats = {
          'total_downloads': totalDownloads,
          'active_tasks': activeTasks,
          'completed_tasks': completedTasks,
          'failed_tasks': failedTasks,
          'total_downloaded_bytes': totalDownloadedBytes,
        };
      });
      
      // 如果是旧内核，尝试从 HTTP API 获取（作为备用）
      final clientConfig = context.read<ClientConfigService>();
      final useNewKernel = clientConfig.getBool('kernel.use_new_kernel', defaultValue: true);
      
      if (!useNewKernel) {
        try {
          final response = await http.get(
            Uri.parse('http://127.0.0.1:9710/download/statistics'),
          ).timeout(const Duration(seconds: 2));

          if (response.statusCode == 200) {
            final result = jsonDecode(response.body);
            if (result['success'] && result['data'] != null) {
              if (!mounted) return;
              setState(() {
                _kernelStats = result['data'];
              });
            }
          }
        } catch (e) {
          // 使用已经从 IntegratedDownloadService 获取的数据
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkKernelHealth() async {
    if (_checkingKernel) return;
    
    if (!mounted) return;
    setState(() {
      _checkingKernel = true;
    });

    final clientConfig = context.read<ClientConfigService>();
    final useNewKernel = clientConfig.getBool('kernel.use_new_kernel', defaultValue: true);

    if (useNewKernel) {
      // 新内核：直接从 KernelManager 获取状态
      final kernelManager = context.read<KernelManager>();
      if (!mounted) return;
      setState(() {
        _kernelHealthy = kernelManager.isRunning;
        _kernelVersion = AppConstants.newKernelVersion;
        _checkingKernel = false;
      });
      return;
    }

    // 旧内核：通过 HTTP API 检查
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:9710/health'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _kernelHealthy = true;
          _kernelVersion = result['version'] ?? AppConstants.kernelVersion;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _kernelHealthy = false;
          _kernelVersion = AppConstants.kernelVersion;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kernelHealthy = false;
        _kernelVersion = AppConstants.kernelVersion;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _checkingKernel = false;
      });
    }
  }

  Future<void> _testAllApis() async {
    if (!mounted) return;
    setState(() {
      _testingApi = true;
      _apiTestResults = {};
    });

    final tests = {
      'Health Check': 'http://127.0.0.1:9710/health',
      'Get Tasks': 'http://127.0.0.1:9710/download/tasks',
      'Get Statistics': 'http://127.0.0.1:9710/download/statistics',
      'Get Config': 'http://127.0.0.1:9710/settings/download-config',
    };

    for (var entry in tests.entries) {
      try {
        final stopwatch = Stopwatch()..start();
        final response = await http.get(Uri.parse(entry.value)).timeout(
          const Duration(seconds: 3),
        );
        stopwatch.stop();

        if (!mounted) return;
        setState(() {
          _apiTestResults![entry.key] = {
            'success': response.statusCode == 200,
            'status': response.statusCode,
            'time': stopwatch.elapsedMilliseconds,
          };
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _apiTestResults![entry.key] = {
            'success': false,
            'error': e.toString(),
          };
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _testingApi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kernelService = context.watch<KernelService>();
    final kernelManager = context.watch<KernelManager>();
    final clientConfig = context.watch<ClientConfigService>();
    final networkService = context.watch<NetworkStatusService>();
    final appLogger = context.watch<AppLoggerService>();
    
    // 判断内核
    final useNewKernel = clientConfig.getBool('kernel.use_new_kernel', defaultValue: true);
    final kernelRunning = useNewKernel ? kernelManager.isRunning : kernelService.isRunning;
    final kernelName = useNewKernel ? kernelManager.kernelName : 'Soda Kernel (Legacy)';

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentPrimary.withValues(alpha: 0.2),
                    AppTheme.accentPrimary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(FluentIcons.health, size: 18, color: AppTheme.accentLight),
            ),
            const SizedBox(width: 14),
            const Text('系统状态'),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('刷新'),
              onPressed: () {
                _checkKernelHealth();
                _loadKernelStats();
                _loadSystemInfo();
                networkService.startMonitoring();
              },
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.test_case),
              label: const Text('测试 API'),
              onPressed: _testingApi ? null : _testAllApis,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.clear),
              label: const Text('清空日志'),
              onPressed: () {
                appLogger.clear();
              },
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 下载核心状态
            _buildSection(
              context,
              title: '下载核心状态',
              icon: FluentIcons.server,
              children: [
                _buildStatusItem(
                  context,
                  label: '核心服务',
                  value: kernelRunning ? '运行中' : '已停止',
                  isOnline: kernelRunning,
                ),
                _buildStatusItem(
                  context,
                  label: '当前内核',
                  value: kernelName,
                  isInfo: true,
                ),
                _buildStatusItem(
                  context,
                  label: 'HTTP 服务',
                  value: _kernelHealthy ? '正常' : (useNewKernel ? '内置' : '异常'),
                  isOnline: useNewKernel ? kernelRunning : _kernelHealthy,
                ),
                _buildStatusItem(
                  context,
                  label: '服务地址',
                  value: 'http://127.0.0.1:9710',
                  isInfo: true,
                ),
                if (_kernelVersion != null)
                  _buildStatusItem(
                    context,
                    label: '核心版本',
                    value: _kernelVersion!,
                    isInfo: true,
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // 网络状态
            _buildSection(
              context,
              title: '网络状态',
              icon: FluentIcons.network_tower,
              children: [
                _buildStatusItem(
                  context,
                  label: '本地网络',
                  value: networkService.networkInfo.isConnected ? '已连接' : '未连接',
                  isOnline: networkService.networkInfo.isConnected,
                ),
                _buildStatusItem(
                  context,
                  label: '互联网',
                  value: networkService.networkInfo.hasInternet ? '可访问' : '不可访问',
                  isOnline: networkService.networkInfo.hasInternet,
                ),
                if (networkService.networkInfo.localIP != null)
                  _buildStatusItem(
                    context,
                    label: '本地 IP',
                    value: networkService.networkInfo.localIP!,
                    isInfo: true,
                  ),
                if (networkService.networkInfo.ping != null)
                  _buildStatusItem(
                    context,
                    label: '网络延迟',
                    value: '${networkService.networkInfo.ping} ms',
                    isInfo: true,
                  ),
                _buildStatusItem(
                  context,
                  label: '连接类型',
                  value: networkService.networkInfo.connectionType,
                  isInfo: true,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // API 测试结果
            if (_apiTestResults != null) ...[
              _buildSection(
                context,
                title: 'API 测试结果',
                icon: FluentIcons.test_case,
                children: _apiTestResults!.entries.map((entry) {
                  final result = entry.value;
                  final success = result['success'] as bool;
                  
                  String value;
                  if (success) {
                    value = '${result['status']} (${result['time']}ms)';
                  } else {
                    value = result['error'] ?? '失败';
                  }

                  return _buildStatusItem(
                    context,
                    label: entry.key,
                    value: value,
                    isOnline: success,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // 系统信息
            if (_systemInfo != null)
              _buildSection(
                context,
                title: '系统信息',
                icon: FluentIcons.system,
                children: [
                  _buildStatusItem(
                    context,
                    label: '操作系统',
                    value: _systemInfo!['platform'] ?? 'Unknown',
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: '系统版本',
                    value: _systemInfo!['version'] ?? 'Unknown',
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: 'CPU 核心数',
                    value: '${_systemInfo!['processors']} 核',
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: 'Dart 版本',
                    value: _systemInfo!['dart_version'] ?? 'Unknown',
                    isInfo: true,
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // 下载统计
            if (_kernelStats != null)
              _buildSection(
                context,
                title: '下载统计',
                icon: FluentIcons.chart,
                children: [
                  _buildStatusItem(
                    context,
                    label: '总下载数',
                    value: '${_kernelStats!['total_downloads'] ?? 0}',
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: '活跃任务',
                    value: '${_kernelStats!['active_tasks'] ?? 0}',
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: '已完成',
                    value: '${_kernelStats!['completed_tasks'] ?? 0}',
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: '失败任务',
                    value: '${_kernelStats!['failed_tasks'] ?? 0}',
                    isInfo: true,
                  ),
                  if (_kernelStats!['total_downloaded_bytes'] != null)
                    _buildStatusItem(
                      context,
                      label: '总下载量',
                      value: _formatBytes(_kernelStats!['total_downloaded_bytes']),
                      isInfo: true,
                    ),
                ],
              ),

            const SizedBox(height: 24),

            // 日志统计
            _buildSection(
              context,
              title: '日志统计',
              icon: FluentIcons.text_document,
              children: [
                _buildStatusItem(
                  context,
                  label: '日志条数',
                  value: '${appLogger.logs.length}',
                  isInfo: true,
                ),
                _buildStatusItem(
                  context,
                  label: '错误数',
                  value: '${appLogger.logs.where((log) => log.level == 'ERROR').length}',
                  isInfo: true,
                ),
                _buildStatusItem(
                  context,
                  label: '警告数',
                  value: '${appLogger.logs.where((log) => log.level == 'WARNING').length}',
                  isInfo: true,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 开机自启动状态
            _buildAutoStartSection(context),

            const SizedBox(height: 24),

            // 浏览器扩展状态
            _buildSection(
              context,
              title: '浏览器扩展',
              icon: FluentIcons.edge_logo,
              children: [
                _buildStatusItem(
                  context,
                  label: '提示',
                  value: '感谢使用，现已支持软件内下载插件以及跳转至网页',
                  isInfo: true,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _downloadExtension,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.download, size: 16),
                            SizedBox(width: 8),
                            Text('下载扩展插件'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Button(
                        onPressed: _openExtensionStore,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.edge_logo, size: 16),
                            SizedBox(width: 8),
                            Text('打开商店页面'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  
  Widget _buildAutoStartSection(BuildContext context) {
    if (!Platform.isWindows) {
      return _buildSection(
        context,
        title: '开机自启动',
        icon: FluentIcons.power_button,
        children: [
          _buildStatusItem(
            context,
            label: '平台支持',
            value: '仅支持 Windows 平台',
            isInfo: true,
          ),
        ],
      );
    }
    
    final children = <Widget>[];
    
    if (_checkingAutoStart) {
      children.add(
        Container(
          padding: const EdgeInsets.all(20),
          child: const Center(
            child: ProgressRing(),
          ),
        ),
      );
    } else {
      // 启用状态
      children.add(
        _buildStatusItem(
          context,
          label: '自启动状态',
          value: _autoStartEnabled == true ? '已启用' : '未启用',
          isOnline: _autoStartEnabled == true,
        ),
      );
      
      if (_autoStartEnabled == true) {
        // 路径正确性
        children.add(
          _buildStatusItem(
            context,
            label: '注册路径',
            value: _autoStartPathCorrect == true ? '正确' : '需要更新',
            isOnline: _autoStartPathCorrect == true,
          ),
        );
        
        // 显示注册的路径
        if (_registeredPath != null) {
          children.add(
            _buildStatusItem(
              context,
              label: '当前注册',
              value: _registeredPath!,
              isInfo: true,
            ),
          );
        }
        
        // 显示当前路径
        children.add(
          _buildStatusItem(
            context,
            label: '当前路径',
            value: '"${Platform.resolvedExecutable}" --autostart',
            isInfo: true,
          ),
        );
        
        // 如果路径不正确，显示修复按钮
        if (_autoStartPathCorrect == false) {
          children.add(const SizedBox(height: 12));
          children.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusWarning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.statusWarning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        FluentIcons.warning,
                        size: 16,
                        color: AppTheme.statusWarning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '检测到旧版本的自启动注册',
                          style: FluentTheme.of(context).typography.body?.copyWith(
                            color: AppTheme.statusWarning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '注册的路径与当前可执行文件不匹配，可能是因为应用更新或移动了位置。点击下方按钮自动修复。',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _fixAutoStart,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.repair, size: 14),
                        SizedBox(width: 6),
                        Text('自动修复注册'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
    
    return _buildSection(
      context,
      title: '开机自启动',
      icon: FluentIcons.power_button,
      children: children,
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: AppTheme.accentLight),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context, {
    required String label,
    required String value,
    bool isOnline = false,
    bool isInfo = false,
  }) {
    Color statusColor;
    IconData statusIcon;

    if (isInfo) {
      statusColor = AppTheme.textTertiary;
      statusIcon = FluentIcons.info;
    } else if (isOnline) {
      statusColor = AppTheme.statusSuccess;
      statusIcon = FluentIcons.completed;
    } else {
      statusColor = AppTheme.statusError;
      statusIcon = FluentIcons.status_error_full;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(statusIcon, size: 12, color: statusColor),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: FluentTheme.of(context).typography.body?.copyWith(
                color: isInfo ? AppTheme.textPrimary : statusColor,
                fontWeight: isInfo ? FontWeight.normal : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
