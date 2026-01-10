import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../../services/kernel_service.dart';
import '../../../services/kernel/kernel_manager.dart';
import '../../../services/client_config_service.dart';
import '../../../theme/app_theme.dart';

class WebCheckPage extends StatefulWidget {
  const WebCheckPage({super.key});

  @override
  State<WebCheckPage> createState() => _WebCheckPageState();
}

class _WebCheckPageState extends State<WebCheckPage> {
  final _urlController = TextEditingController();
  bool _isChecking = false;
  Map<String, dynamic>? _result;
  
  // 局域网扫描
  bool _isScanning = false;
  Map<String, dynamic>? _scanResult;
  bool _autoScanEnabled = false;

  @override
  void initState() {
    super.initState();
    // 自动扫描局域网
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _autoScanEnabled) {
        _scanLan();
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkUrl() async {
    var url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('请输入 URL');
      return;
    }

    // 检查是否使用新内核
    final config = context.read<ClientConfigService>();
    final useNewKernel = config.getBool('kernel.use_new_kernel', defaultValue: true);
    if (useNewKernel) {
      _showError('Web 检测功能暂不支持新版内核，请在设置中切换到旧版内核');
      return;
    }

    // 自动添加协议
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
      _urlController.text = url;
    }

    // 基本URL验证
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      _showError('URL 格式无效');
      return;
    }

    setState(() {
      _isChecking = true;
      _result = null;
    });

    try {
      final kernelService = context.read<KernelService>();
      final result = await kernelService.checkUrlStatus(url);

      if (mounted) {
        setState(() {
          _result = result;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isChecking = false);
        _showError('检测失败: $e');
      }
    }
  }

  Future<void> _scanLan() async {
    // 检查是否使用新内核
    final config = context.read<ClientConfigService>();
    final useNewKernel = config.getBool('kernel.use_new_kernel', defaultValue: true);
    if (useNewKernel) {
      _showError('局域网扫描功能暂不支持新版内核，请在设置中切换到旧版内核');
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResult = null;
    });

    try {
      final kernelService = context.read<KernelService>();
      final result = await kernelService.scanLan();

      if (mounted) {
        setState(() {
          _scanResult = result;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        _showError('扫描失败: $e');
      }
    }
  }

  void _showError(String message) {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('错误'),
        content: Text(message),
        severity: InfoBarSeverity.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildInputSection(),
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _buildResultSection(),
                ],
                const SizedBox(height: 20),
                _buildLanScanSection(),
                if (_scanResult != null) ...[
                  const SizedBox(height: 20),
                  _buildLanDevicesSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.accentPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              FluentIcons.globe,
              size: 14,
              color: AppTheme.accentLight,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Web 状态检测',
            style: FluentTheme.of(context).typography.body?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '输入 URL',
            style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextBox(
            controller: _urlController,
            placeholder: 'example.com 或 https://example.com',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(FluentIcons.link, size: 16),
            ),
            onSubmitted: (_) => _checkUrl(),
          ),
          const SizedBox(height: 8),
          Text(
            '提示：可以直接输入域名，会自动添加 https:// 前缀',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isChecking ? null : _checkUrl,
            child: _isChecking
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('检测中...'),
                    ],
                  )
                : const Text('开始检测'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    if (_result == null) return const SizedBox.shrink();

    final error = _result!['error'];
    if (error != null) {
      return _buildErrorCard(error);
    }

    return Column(
      children: [
        _buildStatusCard(),
        if (_result!['ssl_info'] != null) ...[
          const SizedBox(height: 16),
          _buildSSLCard(),
        ],
        if (_result!['redirects'] != null && (_result!['redirects'] as List).isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildRedirectsCard(),
        ],
        if (_result!['cookies'] != null && (_result!['cookies'] as List).isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildCookiesCard(),
        ],
        const SizedBox(height: 16),
        _buildHeadersCard(),
      ],
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            FluentIcons.error_badge,
            color: AppTheme.statusError,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '检测失败',
                  style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                    color: AppTheme.statusError,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusCode = _result!['status_code'];
    final finalUrl = _result!['final_url'];
    final contentType = _result!['content_type'] ?? '';
    final contentLength = _result!['content_length'] ?? '';
    final server = _result!['server'] ?? '';
    final responseTime = _result!['response_time'];
    final dnsTime = _result!['dns_time'];
    final ipAddress = _result!['ip_address'] ?? '';
    final hostname = _result!['hostname'] ?? '';
    final port = _result!['port'];
    final protocol = _result!['protocol'] ?? '';

    final statusColor = _getStatusColor(statusCode);
    final statusText = _getStatusText(statusCode);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                ),
                child: Text(
                  '$statusCode',
                  style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                    color: statusColor,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                statusText,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 性能指标
          if (responseTime != null || dnsTime != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  if (dnsTime != null) ...[
                    const Icon(FluentIcons.server, size: 16, color: AppTheme.accentLight),
                    const SizedBox(width: 8),
                    Text(
                      'DNS: ${dnsTime}ms',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                  if (responseTime != null) ...[
                    const Icon(FluentIcons.lightning_bolt, size: 16, color: AppTheme.accentLight),
                    const SizedBox(width: 8),
                    Text(
                      '响应: ${responseTime}ms',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // 连接信息
          if (hostname.isNotEmpty) _buildInfoRow('主机名', hostname),
          if (ipAddress.isNotEmpty) _buildInfoRow('IP 地址', ipAddress),
          if (port != null) _buildInfoRow('端口', '$port'),
          if (protocol.isNotEmpty) _buildInfoRow('协议', protocol.toUpperCase()),
          _buildInfoRow('最终 URL', finalUrl),
          if (contentType.isNotEmpty) _buildInfoRow('Content-Type', contentType),
          if (contentLength.isNotEmpty) _buildInfoRow('Content-Length', _formatBytes(contentLength)),
          if (server.isNotEmpty) _buildInfoRow('Server', server),
        ],
      ),
    );
  }

  Widget _buildRedirectsCard() {
    final redirects = _result!['redirects'] as List;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                FluentIcons.forward,
                size: 16,
                color: AppTheme.statusWarning,
              ),
              const SizedBox(width: 8),
              Text(
                '重定向历史 (${redirects.length})',
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...redirects.asMap().entries.map((entry) {
            final index = entry.key;
            final redirect = entry.value;
            return _buildRedirectItem(index + 1, redirect);
          }),
        ],
      ),
    );
  }

  Widget _buildRedirectItem(int step, Map<String, dynamic> redirect) {
    final statusCode = redirect['status_code'];
    final url = redirect['url'];
    final location = redirect['location'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.bgLayer2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppTheme.statusWarning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$step',
                      style: const TextStyle(
                        color: AppTheme.statusWarning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.statusWarning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                  ),
                  child: Text(
                    '$statusCode',
                    style: const TextStyle(
                      color: AppTheme.statusWarning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '从: $url',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '到: $location',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeadersCard() {
    final headers = _result!['headers'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '响应头',
            style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...headers.entries.map((entry) {
            return _buildInfoRow(entry.key, entry.value.toString());
          }),
        ],
      ),
    );
  }

  Widget _buildSSLCard() {
    final sslInfo = _result!['ssl_info'];
    if (sslInfo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.lock, size: 16, color: AppTheme.statusSuccess),
              const SizedBox(width: 8),
              Text(
                'SSL/TLS 信息',
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sslInfo['error'] != null)
            Text(
              'SSL 错误: ${sslInfo['error']}',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.statusError,
              ),
            )
          else ...[
            if (sslInfo['version'] != null) _buildInfoRow('版本', sslInfo['version']),
            if (sslInfo['cipher'] != null) _buildInfoRow('加密套件', sslInfo['cipher']),
            if (sslInfo['subject'] != null && sslInfo['subject']['commonName'] != null)
              _buildInfoRow('证书主体', sslInfo['subject']['commonName']),
            if (sslInfo['issuer'] != null && sslInfo['issuer']['commonName'] != null)
              _buildInfoRow('证书颁发者', sslInfo['issuer']['commonName']),
            if (sslInfo['not_before'] != null) _buildInfoRow('有效期开始', sslInfo['not_before']),
            if (sslInfo['not_after'] != null) _buildInfoRow('有效期结束', sslInfo['not_after']),
          ],
        ],
      ),
    );
  }

  Widget _buildCookiesCard() {
    final cookies = _result!['cookies'] as List?;
    if (cookies == null || cookies.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.database, size: 16, color: AppTheme.statusWarning),
              const SizedBox(width: 8),
              Text(
                'Cookies (${cookies.length})',
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...cookies.map((cookie) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgLayer2.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cookie['name'] ?? '',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cookie['value'] ?? '',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cookie['domain'] != null && cookie['domain'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Domain: ${cookie['domain']}',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLanScanSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.network_tower, size: 16, color: AppTheme.accentLight),
              const SizedBox(width: 8),
              Text(
                '局域网扫描',
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              ToggleSwitch(
                checked: _autoScanEnabled,
                onChanged: (value) {
                  setState(() => _autoScanEnabled = value);
                  if (value && _scanResult == null) {
                    _scanLan();
                  }
                },
                content: const Text('自动扫描'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '扫描当前局域网中的所有在线设备',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isScanning ? null : _scanLan,
            child: _isScanning
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('扫描中...'),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.search, size: 16),
                      SizedBox(width: 8),
                      Text('开始扫描'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanDevicesSection() {
    if (_scanResult == null) return const SizedBox.shrink();

    final devices = _scanResult!['devices'] as List;
    final localIp = _scanResult!['local_ip'] ?? '';
    final network = _scanResult!['network'] ?? '';
    final total = _scanResult!['total'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.devices3, size: 16, color: AppTheme.statusSuccess),
              const SizedBox(width: 8),
              Text(
                '发现 $total 台设备',
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '网段: $network',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          Text(
            '本机 IP: $localIp',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: devices.map((device) => _buildDeviceCard(device)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final ip = device['ip'] ?? '';
    final hostname = device['hostname'];
    final isLocal = device['is_local'] ?? false;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLocal 
            ? AppTheme.accentPrimary.withValues(alpha: 0.15)
            : AppTheme.bgLayer2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: isLocal 
              ? AppTheme.accentPrimary.withValues(alpha: 0.3)
              : AppTheme.borderSubtle.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isLocal ? FluentIcons.pc1 : FluentIcons.device_run,
                size: 20,
                color: isLocal ? AppTheme.accentLight : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              if (isLocal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                  ),
                  child: Text(
                    '本机',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.accentLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ip,
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hostname != null) ...[
            const SizedBox(height: 4),
            Text(
              hostname,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: FluentTheme.of(context).typography.caption?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(int? statusCode) {
    if (statusCode == null) return AppTheme.textTertiary;
    if (statusCode >= 200 && statusCode < 300) return AppTheme.statusSuccess;
    if (statusCode >= 300 && statusCode < 400) return AppTheme.statusWarning;
    if (statusCode >= 400 && statusCode < 500) return AppTheme.statusError;
    if (statusCode >= 500) return AppTheme.statusError;
    return AppTheme.textTertiary;
  }

  String _getStatusText(int? statusCode) {
    if (statusCode == null) return 'Unknown';
    if (statusCode == 200) return 'OK';
    if (statusCode == 301) return 'Moved Permanently';
    if (statusCode == 302) return 'Found';
    if (statusCode == 304) return 'Not Modified';
    if (statusCode == 400) return 'Bad Request';
    if (statusCode == 401) return 'Unauthorized';
    if (statusCode == 403) return 'Forbidden';
    if (statusCode == 404) return 'Not Found';
    if (statusCode == 500) return 'Internal Server Error';
    if (statusCode == 502) return 'Bad Gateway';
    if (statusCode == 503) return 'Service Unavailable';
    return 'Status $statusCode';
  }

  String _formatBytes(String bytes) {
    try {
      final size = int.parse(bytes);
      if (size < 1024) return '$size B';
      if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
      if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (e) {
      return bytes;
    }
  }
}
