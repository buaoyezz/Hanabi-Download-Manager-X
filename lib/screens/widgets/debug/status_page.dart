import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../../../services/kernel_service.dart';
import '../../../services/network_status_service.dart';

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

  @override
  void initState() {
    super.initState();
    _checkKernelHealth();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkKernelHealth();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkKernelHealth() async {
    if (_checkingKernel) return;
    
    setState(() {
      _checkingKernel = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:9710/health'),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() {
          _kernelHealthy = true;
          _kernelVersion = '1.0.0'; // 可以从响应中解析
        });
      } else {
        setState(() {
          _kernelHealthy = false;
        });
      }
    } catch (e) {
      setState(() {
        _kernelHealthy = false;
      });
    } finally {
      setState(() {
        _checkingKernel = false;
      });
    }
  }

  Future<void> _testAllApis() async {
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

        setState(() {
          _apiTestResults![entry.key] = {
            'success': response.statusCode == 200,
            'status': response.statusCode,
            'time': stopwatch.elapsedMilliseconds,
          };
        });
      } catch (e) {
        setState(() {
          _apiTestResults![entry.key] = {
            'success': false,
            'error': e.toString(),
          };
        });
      }
    }

    setState(() {
      _testingApi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kernelService = context.watch<KernelService>();
    final networkService = context.watch<NetworkStatusService>();

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: FluentTheme.of(context).accentColor.withOpacity(0.15),
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
                networkService.startMonitoring();
              },
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.test_case),
              label: const Text('测试 API'),
              onPressed: _testingApi ? null : _testAllApis,
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
                    color: Colors.white.withOpacity(0.7),
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: isInfo ? Colors.white.withOpacity(0.9) : statusColor,
                    fontWeight: isInfo ? FontWeight.normal : FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
