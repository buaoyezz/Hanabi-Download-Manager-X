import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../../../services/user_profile_service.dart';
import '../../../services/online_stats_service.dart';
import '../../../widgets/animated_notifications.dart';

class OnlineStatsPage extends StatefulWidget {
  const OnlineStatsPage({super.key});

  @override
  State<OnlineStatsPage> createState() => _OnlineStatsPageState();
}

class _OnlineStatsPageState extends State<OnlineStatsPage> {
  final _statsService = OnlineStatsService();
  final _userProfile = UserProfileService();
  bool _isSendingHeartbeat = false;
  
  @override
  void initState() {
    super.initState();
    _statsService.startFetching();
  }
  
  @override
  void dispose() {
    _statsService.stopFetching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(FluentIcons.people, size: 18, color: AppTheme.accentLight),
            ),
            const SizedBox(width: 14),
            const Text('当前与你同行的人'),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                // 在线人数统计卡片
                StreamBuilder<Map<String, dynamic>>(
                  stream: _statsService.statsStream,
                  builder: (context, snapshot) {
                    final stats = snapshot.data;
                    final totalOnline = stats?['online_count'] ?? 0;
                    final othersOnline = totalOnline > 0 ? totalOnline - 1 : 0;
                    final isLoading = !snapshot.hasData;
                    
                    return Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.accentPrimary.withValues(alpha: 0.15),
                            AppTheme.accentLight.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                        border: Border.all(
                          color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // 图标
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.accentLight.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              FluentIcons.people,
                              size: 40,
                              color: AppTheme.accentLight,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // 数字
                          if (isLoading)
                            const SizedBox(
                              height: 80,
                              child: Center(child: ProgressRing()),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$othersOnline',
                                  style: FluentTheme.of(context).typography.display?.copyWith(
                                    fontSize: 72,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentLight,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '位',
                                  style: FluentTheme.of(context).typography.title?.copyWith(
                                    fontSize: 24,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // 说明文字
                          Text(
                            othersOnline == 0 ? '暂时只有你在使用 Hanabi' : '除了你，还有 $othersOnline 位用户正在使用 Hanabi',
                            style: FluentTheme.of(context).typography.body?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          if (!isLoading && totalOnline > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              '（包括你在内共 $totalOnline 位）',
                              style: FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // 当前我的状态
                Container(
                  padding: const EdgeInsets.all(24),
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
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '当前我的状态',
                            style: FluentTheme.of(context).typography.subtitle?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildInfoRow(context, '设备 ID', _userProfile.deviceId ?? '未初始化'),
                      const SizedBox(height: 12),
                      _buildInfoRow(context, '应用版本', _userProfile.appVersion),
                      const SizedBox(height: 12),
                      _buildInfoRow(context, '心跳间隔', '每 5 分钟自动发送'),
                      const SizedBox(height: 12),
                      _buildInfoRow(context, '统计服务器', 'zzbuaoye.top'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 手动发送心跳按钮
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSendingHeartbeat ? null : _sendHeartbeatManually,
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    child: _isSendingHeartbeat
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: ProgressRing(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '发送中...',
                                style: FluentTheme.of(context).typography.body?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(FluentIcons.sync, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                '向服务器发送我的信号',
                                style: FluentTheme.of(context).typography.body?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 隐私和服务条款
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    HyperlinkButton(
                      onPressed: () => _openUrl('https://x.zzbuaoye.top/privacy'),
                      child: Text(
                        '隐私条款',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.accentLight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '·',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    HyperlinkButton(
                      onPressed: () => _openUrl('https://x.zzbuaoye.top/terms'),
                      child: Text(
                        '服务条款',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.accentLight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '·',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    HyperlinkButton(
                      onPressed: () => _openUrl('https://x.zzbuaoye.top'),
                      child: Text(
                        '官网地址',
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.accentLight,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: AppTheme.textSecondary,
              fontFamily: value.contains('.') || value.length > 20 ? 'monospace' : null,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _sendHeartbeatManually() async {
    setState(() => _isSendingHeartbeat = true);
    
    try {
      final result = await _userProfile.sendHeartbeatManually();
      
      if (mounted) {
        if (result['success'] == true) {
          NotificationManager.of(context)?.showSuccess('发送成功', message: '您的信号已成功发送到服务器');
        } else if (result['message'] == 'cooldown') {
          final remainingMinutes = result['remaining_minutes'] ?? 5;
          NotificationManager.of(context)?.showInfo('服务器已标记在线', message: '您的在线状态已被服务器记录，请在 $remainingMinutes 分钟后再试');
        } else {
          NotificationManager.of(context)?.showError('发送失败', message: result['message'] ?? '无法连接到统计服务器，请检查网络连接');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingHeartbeat = false);
      }
    }
  }
  
  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => ContentDialog(
              title: const Text('无法打开链接'),
              content: Text('请手动在浏览器中访问：\n$urlString'),
              actions: [
                FilledButton(
                  child: const Text('确定'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('打开失败'),
            content: Text('错误：$e\n\n请手动在浏览器中访问：\n$urlString'),
            actions: [
              FilledButton(
                child: const Text('确定'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }
}
