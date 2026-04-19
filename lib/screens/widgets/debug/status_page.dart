import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/kernel/kernel_manager.dart';
import '../../../services/network_status_service.dart';
import '../../../services/app_logger_service.dart';
import '../../../services/auto_start_service.dart';
import '../../../services/integrated_download_service.dart';
import '../../../services/client_config_service.dart';
import '../../../services/popup_window_service.dart';
import '../../../models/download_task.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/constants.dart';
import '../../../widgets/animated_notifications.dart';
import '../../../widgets/safe_command_bar_button.dart';
import '../../../widgets/smooth_scroll_wrapper.dart';

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

  // 弹窗窗口测试
  bool _testingPopupWindow = false;
  Map<String, dynamic>? _popupWindowTestResult;

  AppLocalizations get t => AppLocalizations.of(context)!;
  bool get _isChinese =>
      Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
            'zh',
          );

  String _browserBridgeBaseUrl() {
    return context.read<ClientConfigService>().getBrowserExtensionBaseUrl();
  }

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
    const extensionUrl =
        'https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.0.0/chrome_extension.zip';

    try {
      final downloadService = context.read<IntegratedDownloadService>();
      await downloadService.addTask(extensionUrl, 'chrome_extension.zip');

      if (mounted) {
        NotificationManager.of(context)?.showSuccess(
          t.statusExtensionDownloadAddedTitle,
          message: t.statusExtensionDownloadAddedMessage,
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError(
          t.statusExtensionDownloadFailedTitle,
          message: t.statusExtensionDownloadFailedMessage(e),
        );
      }
    }
  }

  /// 打开浏览器扩展商店页面
  Future<void> _openExtensionStore() async {
    const storeUrl =
        'https://microsoftedge.microsoft.com/addons/detail/nifalaonnaeobogcnhfoeaklpihcaeia';

    try {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception(t.statusExtensionOpenLinkFailed);
      }
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError(
          t.statusExtensionOpenFailedTitle,
          message: t.statusExtensionOpenFailedMessage(e),
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
        NotificationManager.of(context)?.showSuccess(
          t.statusAutoStartFixSuccessTitle,
          message: t.statusAutoStartFixSuccessMessage,
        );

        // 重新检测状态
        await _checkAutoStartStatus();
      } else {
        NotificationManager.of(context)?.showError(
          t.statusAutoStartFixFailedTitle,
          message: t.statusAutoStartFixFailedMessage,
        );
      }
    } catch (e) {
      if (!mounted) return;
      NotificationManager.of(context)?.showError(
        t.statusAutoStartFixFailedTitle,
        message: t.statusAutoStartFixErrorMessage(e),
      );
    }
  }

  String _popupPreviewLabel(PopupWindowPreviewStage stage) {
    return switch (stage) {
      PopupWindowPreviewStage.compose => t.popupDownloadTitle,
      PopupWindowPreviewStage.progress => t.popupDownloadProgressTitle,
      PopupWindowPreviewStage.completed => t.popupDownloadCompletedTitle,
    };
  }

  String _popupPreviewOpeningLabel(PopupWindowPreviewStage stage) {
    final stageLabel = _popupPreviewLabel(stage);
    return _isChinese
        ? '正在创建$stageLabel预览弹窗'
        : 'Creating $stageLabel popup preview';
  }

  /// 测试弹窗窗口功能
  Future<void> _testPopupWindow(PopupWindowPreviewStage stage) async {
    if (_testingPopupWindow) return;

    final appLogger = context.read<AppLoggerService>();
    final t = AppLocalizations.of(context)!;
    final stageLabel = _popupPreviewLabel(stage);

    setState(() {
      _testingPopupWindow = true;
      _popupWindowTestResult = {
        'stage': stageLabel,
        'status': _popupPreviewOpeningLabel(stage),
      };
    });

    final stopwatch = Stopwatch()..start();
    appLogger.info(
        'PopupTest', '${t.statusPopupTestStartLog} stage=$stageLabel');

    try {
      await PopupWindowService.showPopupPreviewWindow(stage: stage);

      stopwatch.stop();
      appLogger.info('PopupTest',
          '${t.statusPopupTestSuccessLog(stopwatch.elapsedMilliseconds)} stage=$stageLabel');

      if (!mounted) return;
      setState(() {
        _popupWindowTestResult = {
          'success': true,
          'stage': stageLabel,
          'time': stopwatch.elapsedMilliseconds,
          'message': t.statusPopupTestSuccessMessage,
        };
      });

      NotificationManager.of(context)?.showSuccess(
        t.statusPopupTestSuccessTitle,
        message:
            '$stageLabel · ${t.statusPopupTestSuccessToast(stopwatch.elapsedMilliseconds)}',
      );
    } catch (e) {
      stopwatch.stop();
      appLogger.error(
          'PopupTest', '${t.statusPopupTestFailedLog(e)} stage=$stageLabel');

      if (!mounted) return;
      setState(() {
        _popupWindowTestResult = {
          'success': false,
          'stage': stageLabel,
          'time': stopwatch.elapsedMilliseconds,
          'error': e.toString(),
        };
      });

      NotificationManager.of(context)?.showError(
        t.statusPopupTestFailedTitle,
        message: '$stageLabel · ${t.statusPopupTestFailedToast(e)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _testingPopupWindow = false;
        });
      }
    }
  }

  Future<void> _loadKernelStats() async {
    try {
      // 优先从 IntegratedDownloadService 获取真实数据
      final downloadService = context.read<IntegratedDownloadService>();
      final tasks = downloadService.tasks;

      // 统计各状态的任务
      int totalDownloads = tasks.length;
      int activeTasks = tasks
          .where((t) =>
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.pending)
          .length;
      int completedTasks =
          tasks.where((t) => t.status == DownloadStatus.completed).length;
      int failedTasks =
          tasks.where((t) => t.status == DownloadStatus.failed).length;

      // 计算总下载量
      int totalDownloadedBytes = 0;
      for (final task in tasks) {
        if (task.status == DownloadStatus.completed && task.fileSize != null) {
          totalDownloadedBytes += task.fileSize!;
        } else if (task.status == DownloadStatus.downloading &&
            task.downloadedSize != null) {
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

      try {
        final response = await http
            .get(
              Uri.parse('${_browserBridgeBaseUrl()}/download/statistics'),
            )
            .timeout(const Duration(seconds: 2));

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

    try {
      final response = await http
          .get(
            Uri.parse('${_browserBridgeBaseUrl()}/health'),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _kernelHealthy = true;
          _kernelVersion = result['version'] ?? AppConstants.newKernelVersion;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _kernelHealthy = false;
          _kernelVersion = AppConstants.newKernelVersion;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kernelHealthy = false;
        _kernelVersion = AppConstants.newKernelVersion;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingKernel = false;
        });
      }
    }
  }

  Future<void> _testAllApis() async {
    if (!mounted) return;
    final t = AppLocalizations.of(context)!;
    setState(() {
      _testingApi = true;
      _apiTestResults = {};
    });

    final tests = <MapEntry<String, String>>[
      MapEntry(t.statusApiTestHealthCheck, '${_browserBridgeBaseUrl()}/health'),
      MapEntry(
          t.statusApiTestGetTasks, '${_browserBridgeBaseUrl()}/download/tasks'),
      MapEntry(t.statusApiTestGetStatistics,
          '${_browserBridgeBaseUrl()}/download/statistics'),
      MapEntry(t.statusApiTestGetConfig,
          '${_browserBridgeBaseUrl()}/settings/download-config'),
    ];

    for (final entry in tests) {
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
    final kernelManager = context.watch<KernelManager>();
    final networkService = context.watch<NetworkStatusService>();
    final appLogger = context.watch<AppLoggerService>();

    final kernelRunning = kernelManager.isRunning;
    final kernelName = kernelManager.kernelName;

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
              child: const Icon(
                FluentIcons.health,
                size: 18,
                color: AppTheme.accentLight,
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                t.statusPageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            SafeCommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: Text(t.statusPageRefresh),
              onPressed: () {
                _checkKernelHealth();
                _loadKernelStats();
                _loadSystemInfo();
                networkService.startMonitoring();
              },
            ),
            SafeCommandBarButton(
              icon: const Icon(FluentIcons.test_case),
              label: Text(t.statusPageTestApi),
              onPressed: _testingApi ? null : _testAllApis,
            ),
            SafeCommandBarButton(
              icon: const Icon(FluentIcons.clear),
              label: Text(t.statusPageClearLogs),
              onPressed: () {
                appLogger.clear();
              },
            ),
          ],
        ),
      ),
      content: SmoothSingleChildScrollView(
        config: SmoothScrollConfig.fast,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 下载核心状态
            _buildSection(
              context,
              title: t.statusSectionKernel,
              icon: FluentIcons.server,
              children: [
                _buildStatusItem(
                  context,
                  label: t.statusItemKernelRuntime,
                  value: kernelRunning
                      ? t.statusValueRunning
                      : t.statusValueStopped,
                  isOnline: kernelRunning,
                ),
                _buildStatusItem(
                  context,
                  label: t.statusItemKernelCurrent,
                  value: kernelName,
                  isInfo: true,
                ),
                _buildStatusItem(
                  context,
                  label: t.statusItemHttpService,
                  value: _kernelHealthy
                      ? t.statusValueHealthy
                      : t.statusValueUnhealthy,
                  isOnline: _kernelHealthy,
                ),
                _buildStatusItem(
                  context,
                  label: t.statusItemServiceAddress,
                  value: _browserBridgeBaseUrl(),
                  isInfo: true,
                ),
                if (_kernelVersion != null)
                  _buildStatusItem(
                    context,
                    label: t.statusItemKernelVersion,
                    value: _kernelVersion!,
                    isInfo: true,
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // 网络状态
            _buildSection(
              context,
              title: t.statusSectionNetwork,
              icon: FluentIcons.network_tower,
              children: [
                _buildStatusItem(
                  context,
                  label: t.statusItemLocalNetwork,
                  value: networkService.networkInfo.isConnected
                      ? t.statusValueConnected
                      : t.statusValueDisconnected,
                  isOnline: networkService.networkInfo.isConnected,
                ),
                _buildStatusItem(
                  context,
                  label: t.statusItemInternet,
                  value: networkService.networkInfo.hasInternet
                      ? t.statusValueReachable
                      : t.statusValueUnreachable,
                  isOnline: networkService.networkInfo.hasInternet,
                ),
                if (networkService.networkInfo.localIP != null)
                  _buildStatusItem(
                    context,
                    label: t.statusItemLocalIp,
                    value: networkService.networkInfo.localIP!,
                    isInfo: true,
                  ),
                if (networkService.networkInfo.ping != null) ...[
                  Builder(builder: (context) {
                    final ping = networkService.networkInfo.ping;
                    if (ping == null) return const SizedBox.shrink();
                    return _buildStatusItem(
                      context,
                      label: t.statusItemNetworkLatency,
                      value: t.statusNetworkLatencyMs(ping),
                      isInfo: true,
                    );
                  }),
                ],
                _buildStatusItem(
                  context,
                  label: t.statusItemConnectionType,
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
                title: t.statusSectionApiTests,
                icon: FluentIcons.test_case,
                children: _apiTestResults!.entries.map((entry) {
                  final result = entry.value;
                  final success = result['success'] as bool;

                  String value;
                  if (success) {
                    value = '${result['status']} (${result['time']}ms)';
                  } else {
                    value = result['error'] ?? t.statusValueFailed;
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
                title: t.statusSectionSystemInfo,
                icon: FluentIcons.system,
                children: [
                  _buildStatusItem(
                    context,
                    label: t.statusItemOs,
                    value: _systemInfo!['platform'] ?? t.statusValueUnknown,
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: t.statusItemOsVersion,
                    value: _systemInfo!['version'] ?? t.statusValueUnknown,
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: t.statusItemCpuCores,
                    value: t.statusSystemCpuCores(_systemInfo!['processors']),
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: t.statusItemDartVersion,
                    value: _systemInfo!['dart_version'] ?? t.statusValueUnknown,
                    isInfo: true,
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // 下载统计
            if (_kernelStats != null)
              _buildSection(
                context,
                title: t.statusSectionDownloadStats,
                icon: FluentIcons.chart,
                children: [
                  _buildStatusItem(
                    context,
                    label: t.statusItemTotalDownloads,
                    value: '${_kernelStats!['total_downloads'] ?? 0}',
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: t.statusItemActiveTasks,
                    value: '${_kernelStats!['active_tasks'] ?? 0}',
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: t.statusItemCompletedTasks,
                    value: '${_kernelStats!['completed_tasks'] ?? 0}',
                    isInfo: true,
                  ),
                  _buildStatusItem(
                    context,
                    label: t.statusItemFailedTasks,
                    value: '${_kernelStats!['failed_tasks'] ?? 0}',
                    isInfo: true,
                  ),
                  if (_kernelStats!['total_downloaded_bytes'] != null)
                    _buildStatusItem(
                      context,
                      label: t.statusItemTotalDownloaded,
                      value:
                          _formatBytes(_kernelStats!['total_downloaded_bytes']),
                      isInfo: true,
                    ),
                ],
              ),

            const SizedBox(height: 24),

            // 日志统计
            _buildSection(
              context,
              title: t.statusSectionLogStats,
              icon: FluentIcons.text_document,
              children: [
                _buildStatusItem(
                  context,
                  label: t.statusItemLogCount,
                  value: '${appLogger.logs.length}',
                  isInfo: true,
                ),
                _buildStatusItem(
                  context,
                  label: t.statusItemErrorCount,
                  value:
                      '${appLogger.logs.where((log) => log.level == LogLevel.error).length}',
                  isInfo: true,
                ),
                _buildStatusItem(
                  context,
                  label: t.statusItemWarningCount,
                  value:
                      '${appLogger.logs.where((log) => log.level == LogLevel.warning).length}',
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
              title: t.statusSectionExtension,
              icon: FluentIcons.edge_logo,
              children: [
                _buildStatusItem(
                  context,
                  label: t.statusItemTip,
                  value: t.statusExtensionTip,
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
                            const Icon(FluentIcons.download, size: 16),
                            const SizedBox(width: 8),
                            Text(t.statusExtensionDownloadButton),
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
                            const Icon(FluentIcons.edge_logo, size: 16),
                            const SizedBox(width: 8),
                            Text(t.statusExtensionOpenStoreButton),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 弹窗窗口测试
            _buildPopupWindowTestSection(context),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _buildAutoStartSection(BuildContext context) {
    if (!Platform.isWindows) {
      return _buildSection(
        context,
        title: t.statusSectionAutoStart,
        icon: FluentIcons.power_button,
        children: [
          _buildStatusItem(
            context,
            label: t.statusItemPlatformSupport,
            value: t.statusAutoStartWindowsOnly,
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
          label: t.statusItemAutoStartStatus,
          value: _autoStartEnabled == true
              ? t.statusValueEnabled
              : t.statusValueDisabled,
          isOnline: _autoStartEnabled == true,
        ),
      );

      if (_autoStartEnabled == true) {
        // 路径正确性
        children.add(
          _buildStatusItem(
            context,
            label: t.statusItemRegistryPath,
            value: _autoStartPathCorrect == true
                ? t.statusValueCorrect
                : t.statusValueNeedsUpdate,
            isOnline: _autoStartPathCorrect == true,
          ),
        );

        // 显示注册的路径
        if (_registeredPath != null) {
          children.add(
            _buildStatusItem(
              context,
              label: t.statusItemCurrentRegistry,
              value: _registeredPath!,
              isInfo: true,
            ),
          );
        }

        // 显示当前路径
        children.add(
          _buildStatusItem(
            context,
            label: t.statusItemCurrentPath,
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
                      const Icon(
                        FluentIcons.warning,
                        size: 16,
                        color: AppTheme.statusWarning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.statusAutoStartOldRegistryTitle,
                          style:
                              FluentTheme.of(context).typography.body?.copyWith(
                                    color: AppTheme.statusWarning,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.statusAutoStartOldRegistryMessage,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _fixAutoStart,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.repair, size: 14),
                        const SizedBox(width: 6),
                        Text(t.statusAutoStartFixButton),
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
      title: t.statusSectionAutoStart,
      icon: FluentIcons.power_button,
      children: children,
    );
  }

  /// 弹窗窗口测试部分
  Widget _buildPopupWindowTestSection(BuildContext context) {
    return _buildSection(
      context,
      title: t.statusSectionPopupTest,
      icon: FluentIcons.open_pane,
      children: [
        _buildStatusItem(
          context,
          label: t.statusItemDescription,
          value: t.statusPopupTestDescription,
          isInfo: true,
        ),
        if (_popupWindowTestResult != null) ...[
          _buildStatusItem(
            context,
            label: t.statusItemTestResult,
            value: _popupWindowTestResult!['success'] == true
                ? '${_popupWindowTestResult!['stage']} · ${t.statusPopupTestResultSuccess(_popupWindowTestResult!['time'])}'
                : _popupWindowTestResult!['status']?.toString() ??
                    '${_popupWindowTestResult!['stage'] ?? t.statusValueUnknown} · ${t.statusPopupTestResultFailed(_popupWindowTestResult!['error'] ?? t.statusValueUnknown)}',
            isOnline: _popupWindowTestResult!['success'] == true,
            isInfo: _popupWindowTestResult!['success'] == null,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _testingPopupWindow
                  ? null
                  : () => _testPopupWindow(PopupWindowPreviewStage.compose),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_testingPopupWindow)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  else
                    const Icon(FluentIcons.open_pane, size: 16),
                  const SizedBox(width: 8),
                  Text(_popupPreviewLabel(PopupWindowPreviewStage.compose)),
                ],
              ),
            ),
            Button(
              onPressed: _testingPopupWindow
                  ? null
                  : () => _testPopupWindow(PopupWindowPreviewStage.progress),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.open_pane, size: 16),
                  const SizedBox(width: 8),
                  Text(_popupPreviewLabel(PopupWindowPreviewStage.progress)),
                ],
              ),
            ),
            Button(
              onPressed: _testingPopupWindow
                  ? null
                  : () => _testPopupWindow(PopupWindowPreviewStage.completed),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.open_pane, size: 16),
                  const SizedBox(width: 8),
                  Text(_popupPreviewLabel(PopupWindowPreviewStage.completed)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.accentPrimary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    FluentIcons.info,
                    size: 14,
                    color: AppTheme.accentLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.statusPopupTestInfoTitle,
                    style: FluentTheme.of(context).typography.body?.copyWith(
                          color: AppTheme.accentLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                t.statusPopupTestInfoBody,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ],
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
