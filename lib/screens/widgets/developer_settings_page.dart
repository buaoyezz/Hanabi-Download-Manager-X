import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/developer_mode_service.dart';
import '../../services/notification_settings_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/animated_notifications.dart';
import 'dart:ui';

class DeveloperSettingsPage extends StatefulWidget {
  const DeveloperSettingsPage({super.key});

  @override
  State<DeveloperSettingsPage> createState() => _DeveloperSettingsPageState();
}

class _DeveloperSettingsPageState extends State<DeveloperSettingsPage> {
  late DeveloperModeService _devMode;
  final TextEditingController _customTitleController = TextEditingController();
  final TextEditingController _customMessageController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _devMode = Provider.of<DeveloperModeService>(context, listen: false);
    _devMode.addListener(_onDevModeChanged);
  }
  
  @override
  void dispose() {
    _customTitleController.dispose();
    _customMessageController.dispose();
    _devMode.removeListener(_onDevModeChanged);
    super.dispose();
  }
  
  void _onDevModeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 开发者模式总开关
        _buildSection(
          context,
          title: '开发者模式',
          icon: FluentIcons.developer_tools,
          children: [
            _buildSettingItem(
              context,
              title: '启用开发者模式',
              subtitle: '开启后可使用调试和诊断功能',
              trailing: ToggleSwitch(
                checked: _devMode.developerMode,
                onChanged: (value) => _devMode.setDeveloperMode(value),
              ),
            ),
            const SizedBox(height: 12),
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
                      '开发者模式包含高级功能，可能影响应用稳定性。关闭后将自动隐藏所有调试页面。',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.statusWarning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // 只有开启开发者模式才显示下面的选项
        if (_devMode.developerMode) ...[
          const SizedBox(height: 24),
          
          // 调试页面设置
          _buildSection(
            context,
            title: '调试页面',
            icon: FluentIcons.page,
            subtitle: '选择要在侧边栏显示的调试页面',
            children: [
              _buildDebugPageCard(
                context,
                icon: FluentIcons.text_document,
                title: '日志查看器',
                description: '实时查看应用运行日志，包括调试、信息、警告和错误信息',
                features: [
                  '实时日志流',
                  '日志级别筛选',
                  '搜索和过滤',
                  '导出日志文件',
                ],
                isEnabled: _devMode.showLogPage,
                onChanged: (value) => _devMode.setShowLogPage(value),
              ),
              const SizedBox(height: 12),
              
              _buildDebugPageCard(
                context,
                icon: FluentIcons.health,
                title: '系统状态监控',
                description: '监控下载内核、浏览器扩展和系统资源的运行状态',
                features: [
                  '内核状态检测',
                  '扩展连接状态',
                  '系统资源监控',
                  '性能指标统计',
                ],
                isEnabled: _devMode.showStatusPage,
                onChanged: (value) => _devMode.setShowStatusPage(value),
              ),
              const SizedBox(height: 12),
              
              _buildDebugPageCard(
                context,
                icon: FluentIcons.people,
                title: '在线统计',
                description: '查看全球用户在线统计数据和设备分布情况',
                features: [
                  '实时在线用户数',
                  '设备类型分布',
                  '版本使用统计',
                  '地理位置分布',
                ],
                isEnabled: _devMode.showOnlineStatsPage,
                onChanged: (value) => _devMode.setShowOnlineStatsPage(value),
              ),
              const SizedBox(height: 12),
              
              _buildDebugPageCard(
                context,
                icon: FluentIcons.globe,
                title: 'Web 检测工具',
                description: '检测网站可访问性和连接状态，诊断网络问题',
                features: [
                  'HTTP 状态检测',
                  '响应时间测试',
                  'DNS 解析检查',
                  'SSL 证书验证',
                ],
                isEnabled: _devMode.showWebCheckPage,
                onChanged: (value) => _devMode.setShowWebCheckPage(value),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 通知系统测试
          _buildSection(
            context,
            title: '通知系统测试',
            icon: FluentIcons.ringer,
            subtitle: '测试各种通知类型和自定义通知',
            children: [
              _buildTestButtonsGrid(context),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 性能提示
          _buildSection(
            context,
            title: '性能提示',
            icon: FluentIcons.speed_high,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                          FluentIcons.lightbulb,
                          size: 18,
                          color: AppTheme.accentLight,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '优化建议',
                          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.accentLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      context,
                      '调试页面会占用额外的系统资源和内存',
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      context,
                      '日志查看器会持续记录日志，建议仅在需要时启用',
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      context,
                      '在线统计页面会定期请求服务器数据',
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem(
                      context,
                      '不使用时建议关闭调试页面以获得最佳性能',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.accentLight),
              const SizedBox(width: 10),
              Text(
                title,
                style: FluentTheme.of(context).typography.subtitle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                subtitle,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(
                color: AppTheme.borderSubtle.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildDebugPageCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppTheme.accentPrimary.withValues(alpha: 0.08)
            : AppTheme.bgLayer2.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isEnabled
              ? AppTheme.accentPrimary.withValues(alpha: 0.4)
              : AppTheme.borderSubtle.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? AppTheme.accentPrimary.withValues(alpha: 0.2)
                      : AppTheme.bgLayer3.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isEnabled ? AppTheme.accentLight : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                        color: isEnabled ? AppTheme.accentLight : AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ToggleSwitch(
                checked: isEnabled,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.bgLayer1.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '功能特性:',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                ...features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? AppTheme.accentLight
                              : AppTheme.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        feature,
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.accentLight,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestButtonsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 自定义通知输入
        Text(
          '自定义通知',
          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgLayer2.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: AppTheme.borderSubtle.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextBox(
                controller: _customTitleController,
                placeholder: '通知标题',
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              TextBox(
                controller: _customMessageController,
                placeholder: '通知内容（可选）',
                maxLines: 2,
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildQuickTestButton(
                    context,
                    label: '成功',
                    icon: FluentIcons.completed_solid,
                    color: AppTheme.statusSuccess,
                    type: NotificationType.success,
                  ),
                  _buildQuickTestButton(
                    context,
                    label: '警告',
                    icon: FluentIcons.warning,
                    color: AppTheme.statusWarning,
                    type: NotificationType.warning,
                  ),
                  _buildQuickTestButton(
                    context,
                    label: '错误',
                    icon: FluentIcons.status_error_full,
                    color: AppTheme.statusError,
                    type: NotificationType.error,
                  ),
                  _buildQuickTestButton(
                    context,
                    label: '信息',
                    icon: FluentIcons.info,
                    color: AppTheme.accentLight,
                    type: NotificationType.info,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 预设通知示例
        Text(
          '预设示例',
          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildPresetButton(
              context,
              label: '下载完成',
              icon: FluentIcons.download,
              color: const Color(0xFF10B981),
              title: '下载完成',
              message: 'video.mp4 已成功下载',
            ),
            _buildPresetButton(
              context,
              label: '新消息',
              icon: FluentIcons.mail,
              color: const Color(0xFF8B5CF6),
              title: '收到新消息',
              message: '您有 3 条未读消息',
            ),
            _buildPresetButton(
              context,
              label: '更新',
              icon: FluentIcons.system,
              color: const Color(0xFF3B82F6),
              title: '系统更新可用',
              message: '发现新版本 v2.1.0',
            ),
            _buildPresetButton(
              context,
              label: '网络',
              icon: FluentIcons.plug_disconnected,
              color: const Color(0xFFF59E0B),
              title: '网络不稳定',
              message: '检测到网络波动',
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 提示信息
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppTheme.accentPrimary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(
                FluentIcons.info,
                size: 12,
                color: AppTheme.accentLight,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '通知会在右上角显示，最多同时显示 4 条。鼠标悬停可暂停自动关闭。',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickTestButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required NotificationType type,
  }) {
    return Button(
      onPressed: () {
        final title = _customTitleController.text.trim();
        final message = _customMessageController.text.trim();
        
        if (title.isEmpty) {
          // 如果没有输入标题，显示提示
          final notificationManager = NotificationManager.of(context);
          notificationManager?.showWarning(
            '请输入标题',
            message: '请在上方输入框中输入通知标题',
          );
          return;
        }
        
        final notificationManager = NotificationManager.of(context);
        notificationManager?.showNotification(
          title: title,
          message: message.isEmpty ? null : message,
          type: type,
        );
      },
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.isPressed) {
            return color.withValues(alpha: 0.2);
          }
          if (states.isHovered) {
            return color.withValues(alpha: 0.12);
          }
          return color.withValues(alpha: 0.08);
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Button(
      onPressed: () {
        final notificationManager = NotificationManager.of(context);
        notificationManager?.showCustom(
          title: title,
          message: message,
          icon: icon,
          color: color,
        );
      },
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.isPressed) {
            return color.withValues(alpha: 0.2);
          }
          if (states.isHovered) {
            return color.withValues(alpha: 0.12);
          }
          return color.withValues(alpha: 0.08);
        }),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
