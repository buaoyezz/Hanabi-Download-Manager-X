import 'dart:io';
import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/kernel/kernel_manager.dart';
import '../../../services/kernel/kernel_interface.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/fluent_icons.dart';

/// 连接测试结果
class _ConnectionTestResult {
  final String url;
  final String localAddress;
  final String remoteAddress;
  final int remotePort;
  final bool connected;
  final int statusCode;
  final int contentLength;
  final int bytesReceived;
  final Duration elapsed;
  final String? error;
  final bool supportsRange;
  final String? proxyInfo;

  _ConnectionTestResult({
    required this.url,
    this.localAddress = '',
    this.remoteAddress = '',
    this.remotePort = 0,
    this.connected = false,
    this.statusCode = 0,
    this.contentLength = 0,
    this.bytesReceived = 0,
    this.elapsed = Duration.zero,
    this.error,
    this.supportsRange = false,
    this.proxyInfo,
  });
}

class ConnectionDebugPage extends StatefulWidget {
  const ConnectionDebugPage({super.key});

  @override
  State<ConnectionDebugPage> createState() => _ConnectionDebugPageState();
}

class _ConnectionDebugPageState extends State<ConnectionDebugPage> {
  final _urlController = TextEditingController(text: 'https://dl.google.com/chrome/install/latest/chrome_installer.exe');
  final List<_ConnectionTestResult> _results = [];
  bool _isTesting = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _urlController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    var url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
      _urlController.text = url;
    }

    setState(() => _isTesting = true);

    // 获取代理配置
    String? proxyInfo;
    ProxyConfig? proxyConfig;
    try {
      final kernelManager = context.read<KernelManager>();
      final config = await kernelManager.getConfig();
      if (config?.proxy != null && config!.proxy!.enabled) {
        proxyConfig = config.proxy;
        final host = proxyConfig!.host.isNotEmpty ? proxyConfig.host : '127.0.0.1';
        proxyInfo = '$host:${proxyConfig.port}';
      }
    } catch (_) {}

    final stopwatch = Stopwatch()..start();
    HttpClient? client;

    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      client.idleTimeout = const Duration(seconds: 10);
      client.badCertificateCallback = (cert, host, port) => true;

      // 应用代理
      if (proxyConfig != null && proxyConfig.enabled) {
        final host = proxyConfig.host.isNotEmpty ? proxyConfig.host : '127.0.0.1';
        client.findProxy = (_) => 'PROXY $host:${proxyConfig!.port}';
      }

      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'NSFX/2.0 Connection Debug');
      request.headers.set('Accept', '*/*');

      final response = await request.close().timeout(const Duration(seconds: 15));

      final statusCode = response.statusCode;
      final contentLength = response.contentLength;
      final acceptRanges = response.headers.value('accept-ranges');
      final supportsRange = acceptRanges?.toLowerCase() == 'bytes';

      // 获取连接信息
      final connectionInfo = response.connectionInfo;
      final localAddr = connectionInfo?.localPort != null
          ? '${_resolveLocalIp()}:${connectionInfo!.localPort}'
          : _resolveLocalIp();
      final remoteAddr = connectionInfo?.remoteAddress.address ?? uri.host;
      final remotePort = connectionInfo?.remotePort ?? (uri.scheme == 'https' ? 443 : 80);

      // 读取一小部分数据来测量传输
      int bytesReceived = 0;
      await for (final chunk in response) {
        bytesReceived += chunk.length;
        // 最多读 256KB 就够了，不需要下载整个文件
        if (bytesReceived >= 256 * 1024) break;
      }

      stopwatch.stop();
      client.close(force: true);
      client = null;

      final result = _ConnectionTestResult(
        url: url,
        localAddress: localAddr,
        remoteAddress: remoteAddr,
        remotePort: remotePort,
        connected: true,
        statusCode: statusCode,
        contentLength: contentLength,
        bytesReceived: bytesReceived,
        elapsed: stopwatch.elapsed,
        supportsRange: supportsRange,
        proxyInfo: proxyInfo,
      );

      setState(() {
        _results.insert(0, result);
        _isTesting = false;
      });
    } catch (e) {
      stopwatch.stop();
      client?.close(force: true);

      final uri = Uri.tryParse(url);
      final result = _ConnectionTestResult(
        url: url,
        localAddress: _resolveLocalIp(),
        remoteAddress: uri?.host ?? '',
        remotePort: uri?.scheme == 'https' ? 443 : 80,
        connected: false,
        elapsed: stopwatch.elapsed,
        error: e.toString(),
        proxyInfo: proxyInfo,
      );

      setState(() {
        _results.insert(0, result);
        _isTesting = false;
      });
    }
  }

  String _resolveLocalIp() {
    final t = AppLocalizations.of(context);
    return t?.connectionDebugLocalHost ?? 'Local';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  void _clearResults() {
    setState(() => _results.clear());
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
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                _buildInputSection(),
                const SizedBox(height: 16),
                if (_results.isNotEmpty) _buildResultsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final t = AppLocalizations.of(context)!;
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
            child: Icon(
              FluentIcons.plug_disconnected,
              size: 14,
              color: AppTheme.accentLight,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            t.connectionDebugTitle,
            style: FluentTheme.of(context).typography.body?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          if (_results.isNotEmpty)
            IconButton(
              icon: Icon(FluentIcons.delete, size: 14, color: AppTheme.textTertiary),
              onPressed: _clearResults,
            ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    final t = AppLocalizations.of(context)!;
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
            t.connectionDebugTestTitle,
            style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.connectionDebugTestSubtitle,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          TextBox(
            controller: _urlController,
            placeholder: 'https://example.com/file.zip',
            prefix: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(FluentIcons.link, size: 16),
            ),
            onSubmitted: (_) => _runTest(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _isTesting ? null : _runTest,
                child: _isTesting
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: ProgressRing(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(t.connectionDebugTesting),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.play, size: 14),
                          const SizedBox(width: 6),
                          Text(t.connectionDebugStartTest),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              // 快捷测试按钮
              Button(
                onPressed: _isTesting ? null : () {
                  _urlController.text = 'https://dl.google.com/chrome/install/latest/chrome_installer.exe';
                  _runTest();
                },
                child: const Text('Google'),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: _isTesting ? null : () {
                  _urlController.text = 'https://github.com';
                  _runTest();
                },
                child: const Text('GitHub'),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: _isTesting ? null : () {
                  _urlController.text = 'https://www.baidu.com';
                  _runTest();
                },
                child: const Text('Baidu'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    final t = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            t.connectionDebugResults(_results.length),
            style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        ..._results.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildResultCard(r),
        )),
      ],
    );
  }

  Widget _buildResultCard(_ConnectionTestResult result) {
    final t = AppLocalizations.of(context)!;
    final statusColor = result.connected ? AppTheme.statusSuccess : AppTheme.statusError;
    final statusText = result.connected ? t.connectionDebugSuccess : t.connectionDebugFailed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态行
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                  color: statusColor,
                  fontSize: 13,
                ),
              ),
              if (result.connected) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusCodeColor(result.statusCode).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                  ),
                  child: Text(
                    'HTTP ${result.statusCode}',
                    style: TextStyle(
                      color: _getStatusCodeColor(result.statusCode),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${result.elapsed.inMilliseconds}ms',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // URL
          Text(
            result.url,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // 连接路径可视化: 本机 -> [代理] -> 服务器
          _buildConnectionPath(result),

          if (result.connected) ...[
            const SizedBox(height: 12),
            // 详细信息网格
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildInfoChip(FluentIcons.arrow_download_20, t.connectionDebugReceived, _formatBytes(result.bytesReceived)),
                if (result.contentLength > 0)
                  _buildInfoChip(FluentIcons.hard_drive, t.connectionDebugFileSize, _formatBytes(result.contentLength)),
                _buildInfoChip(
                  FluentIcons.split,
                  'Range',
                  result.supportsRange ? t.connectionDebugRangeSupported : t.connectionDebugRangeNotSupported,
                  color: result.supportsRange ? AppTheme.statusSuccess : AppTheme.statusWarning,
                ),
              ],
            ),
          ],

          if (result.error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.statusError.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                result.error!,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.statusError,
                  fontSize: 11,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 连接路径可视化
  Widget _buildConnectionPath(_ConnectionTestResult result) {
    final t = AppLocalizations.of(context)!;
    final hasProxy = result.proxyInfo != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          // 本机
          _buildNodeBadge(
            icon: FluentIcons.desktop_20,
            label: result.localAddress,
            color: AppTheme.accentLight,
          ),
          // 箭头
          Expanded(child: _buildArrow(hasProxy ? t.connectionDebugProxy : null)),
          // 代理节点（如果有）
          if (hasProxy) ...[
            _buildNodeBadge(
              icon: FluentIcons.globe_shield_20,
              label: result.proxyInfo!,
              color: AppTheme.statusWarning,
            ),
            Expanded(child: _buildArrow(null)),
          ],
          // 服务器
          _buildNodeBadge(
            icon: FluentIcons.server,
            label: result.remoteAddress.isNotEmpty
                ? '${result.remoteAddress}:${result.remotePort}'
                : t.connectionDebugUnknown,
            color: result.connected ? AppTheme.statusSuccess : AppTheme.statusError,
          ),
        ],
      ),
    );
  }

  Widget _buildNodeBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 10,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildArrow(String? label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: AppTheme.borderDefault,
              ),
            ),
            Icon(FluentIcons.chevron_right_20, size: 12, color: AppTheme.textTertiary),
          ],
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 9,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color ?? AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getStatusCodeColor(int code) {
    if (code >= 200 && code < 300) return AppTheme.statusSuccess;
    if (code >= 300 && code < 400) return AppTheme.statusWarning;
    return AppTheme.statusError;
  }
}
