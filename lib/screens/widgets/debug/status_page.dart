import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../services/kernel_service.dart';
import '../../../services/network_status_service.dart';
import '../../../services/app_logger_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSystemInfo();
    _checkKernelHealth();
    _loadKernelStats();
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
  
  Future<void> _loadKernelStats() async {
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:9710/download/statistics'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          if (!mounted) return;
          setState(() {
            _kernelStats = result['data'];
          });
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

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:9710/health'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          _kernelHealthy = true;
          _kernelVersion = result['version'] ?? '1.0.0';
        });
      } else {
        if (!mounted) return;
        setState(() {
          _kernelHealthy = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _kernelHealthy = false;
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
    final networkService = context.watch<NetworkStatusService>();
    final appLogger = context.watch<AppLoggerService>();

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: FluentTheme.of(context).accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                FluentIcons.health,
                size: 16,
                color: FluentTheme.of(context).accentColor,
              ),
            ),
            const SizedBox(width: 12),
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
                  value: kernelService.isRunning ? '运行中' : '已停止',
                  isOnline: kernelService.isRunning,
                ),
                _buildStatusItem(
                  context,
                  label: 'HTTP 服务',
                  value: _kernelHealthy ? '正常' : '异常',
                  isOnline: _kernelHealthy,
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

            // 浏览器扩展状态
            _buildSection(
              context,
              title: '浏览器扩展',
              icon: FluentIcons.edge_logo,
              children: [
                _buildStatusItem(
                  context,
                  label: '扩展状态',
                  value: '未知',
                  isInfo: true,
                ),
                _buildStatusItem(
                  context,
                  label: '提示',
                  value: '请在浏览器中安装扩展以启用下载拦截功能',
                  isInfo: true,
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

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
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
      statusColor = Colors.grey;
      statusIcon = FluentIcons.info;
    } else if (isOnline) {
      statusColor = Colors.green;
      statusIcon = FluentIcons.completed;
    } else {
      statusColor = Colors.red;
      statusIcon = FluentIcons.status_error_full;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            statusIcon,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: isInfo ? Colors.white.withValues(alpha: 0.9) : statusColor,
                    fontWeight: isInfo ? FontWeight.normal : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
