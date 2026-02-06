import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/developer_mode_service.dart';
import '../../services/popup_window_service.dart';
import '../../services/app_logger_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;
import '../../widgets/animated_notifications.dart';

/// 开发者设置页面 - Fluent 2 简约设计
class DeveloperSettingsPage extends StatefulWidget {
  const DeveloperSettingsPage({super.key});

  @override
  State<DeveloperSettingsPage> createState() => _DeveloperSettingsPageState();
}

class _DeveloperSettingsPageState extends State<DeveloperSettingsPage>
    with SingleTickerProviderStateMixin {
  late DeveloperModeService _devMode;
  final TextEditingController _customTitleController = TextEditingController();
  final TextEditingController _customMessageController = TextEditingController();
  late AnimationController _animController;

  bool _testingPopupWindow = false;
  Map<String, dynamic>? _popupWindowTestResult;

  @override
  void initState() {
    super.initState();
    _devMode = Provider.of<DeveloperModeService>(context, listen: false);
    _devMode.addListener(_onDevModeChanged);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    _customMessageController.dispose();
    _devMode.removeListener(_onDevModeChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onDevModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOut,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.01),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutCubic,
            )),
            child: _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 开发者模式开关
          _buildMasterSwitch(),

          // 开启后显示调试工具
          if (_devMode.developerMode) ...[
            const SizedBox(height: 32),
            _buildSectionTitle('调试工具'),
            const SizedBox(height: 12),
            _buildDebugToolsGrid(),
            const SizedBox(height: 32),
            _buildSectionTitle('测试工具'),
            const SizedBox(height: 12),
            _buildTestToolsRow(),
          ],
        ],
      ),
    );
  }

  /// 区块标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
        color: AppTheme.textSecondary,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    );
  }

  /// 开发者模式主开关
  Widget _buildMasterSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          // 图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _devMode.developerMode
                  ? AppTheme.accentPrimary.withValues(alpha: 0.1)
                  : AppTheme.bgLayer2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              CustomIcons.FluentIcons.developer_tools,
              size: 20,
              color: _devMode.developerMode
                  ? AppTheme.accentPrimary
                  : AppTheme.textTertiary,
            ),
          ),
          const SizedBox(width: 16),

          // 文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开发者模式',
                  style: FluentTheme.of(context).typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _devMode.developerMode ? '已启用调试功能' : '开启后可使用调试工具',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 开关
          ToggleSwitch(
            checked: _devMode.developerMode,
            onChanged: (value) {
              _devMode.setDeveloperMode(value);
              if (mounted) {
                NotificationManager.of(context)?.showSuccess(
                  value ? '开发者模式已开启' : '开发者模式已关闭',
                  message: value ? '已启用高级调试功能' : '已禁用高级调试功能',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// 调试工具网格
  Widget _buildDebugToolsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                icon: CustomIcons.FluentIcons.text_document,
                title: '日志查看器',
                subtitle: '查看运行日志',
                isEnabled: _devMode.showLogPage,
                onChanged: (v) {
                  _devMode.setShowLogPage(v);
                  if (mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      v ? '日志查看器已显示' : '日志查看器已隐藏',
                      message: v ? '已在导航栏添加日志页面' : '已从导航栏移除日志页面',
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToolCard(
                icon: CustomIcons.FluentIcons.health,
                title: '系统状态',
                subtitle: '内核与扩展',
                isEnabled: _devMode.showStatusPage,
                onChanged: (v) {
                  _devMode.setShowStatusPage(v);
                  if (mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      v ? '系统状态已显示' : '系统状态已隐藏',
                      message: v ? '已在导航栏添加状态页面' : '已从导航栏移除状态页面',
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                icon: CustomIcons.FluentIcons.people,
                title: '在线统计',
                subtitle: '用户数据',
                isEnabled: _devMode.showOnlineStatsPage,
                onChanged: (v) {
                  _devMode.setShowOnlineStatsPage(v);
                  if (mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      v ? '在线统计已显示' : '在线统计已隐藏',
                      message: v ? '已在导航栏添加在线统计页面' : '已从导航栏移除在线统计页面',
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToolCard(
                icon: CustomIcons.FluentIcons.globe,
                title: 'Web 检测',
                subtitle: '网站诊断',
                isEnabled: _devMode.showWebCheckPage,
                onChanged: (v) {
                  _devMode.setShowWebCheckPage(v);
                  if (mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      v ? 'Web 检测已显示' : 'Web 检测已隐藏',
                      message: v ? '已在导航栏添加 Web 检测页面' : '已从导航栏移除 Web 检测页面',
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildToolCard(
                icon: CustomIcons.FluentIcons.speed_high,
                title: '性能监控',
                subtitle: '帧率与渲染',
                isEnabled: _devMode.showPerformanceMonitorPage,
                onChanged: (v) {
                  _devMode.setShowPerformanceMonitorPage(v);
                  if (mounted) {
                    NotificationManager.of(context)?.showSuccess(
                      v ? '性能监控已显示' : '性能监控已隐藏',
                      message: v ? '已在导航栏添加性能监控页面' : '已从导航栏移除性能监控页面',
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()), // 占位
          ],
        ),
      ],
    );
  }

  /// 工具卡片 - Fluent 2 简约风格
  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!isEnabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEnabled
              ? AppTheme.accentPrimary.withValues(alpha: 0.08)
              : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isEnabled
                ? AppTheme.accentPrimary.withValues(alpha: 0.3)
                : AppTheme.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isEnabled
                    ? AppTheme.accentPrimary.withValues(alpha: 0.15)
                    : AppTheme.bgLayer2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isEnabled ? AppTheme.accentPrimary : AppTheme.textTertiary,
              ),
            ),
            const SizedBox(width: 12),

            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: FluentTheme.of(context).typography.body?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // 状态点
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEnabled ? AppTheme.statusSuccess : AppTheme.bgLayer3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 测试工具行
  Widget _buildTestToolsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildNotificationTestCard()),
        const SizedBox(width: 12),
        Expanded(child: _buildPopupTestCard()),
      ],
    );
  }

  /// 通知测试卡片
  Widget _buildNotificationTestCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                CustomIcons.FluentIcons.ringer,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '通知测试',
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 输入框
          TextBox(
            controller: _customTitleController,
            placeholder: '标题',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextBox(
            controller: _customMessageController,
            placeholder: '内容（可选）',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),

          // 按钮组
          Row(
            children: [
              _buildTypeButton('成功', AppTheme.statusSuccess, NotificationType.success),
              const SizedBox(width: 6),
              _buildTypeButton('警告', AppTheme.statusWarning, NotificationType.warning),
              const SizedBox(width: 6),
              _buildTypeButton('错误', AppTheme.statusError, NotificationType.error),
              const SizedBox(width: 6),
              _buildTypeButton('信息', AppTheme.accentPrimary, NotificationType.info),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, Color color, NotificationType type) {
    return Expanded(
      child: Button(
        onPressed: () {
          final title = _customTitleController.text.trim();
          if (title.isEmpty) {
            NotificationManager.of(context)?.showWarning('请输入标题');
            return;
          }
          final message = _customMessageController.text.trim();
          NotificationManager.of(context)?.showNotification(
            title: title,
            message: message.isEmpty ? null : message,
            type: type,
          );
        },
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.isHovered) return color.withValues(alpha: 0.12);
            return Colors.transparent;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: color.withValues(alpha: 0.4)),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 弹窗测试卡片
  Widget _buildPopupTestCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                CustomIcons.FluentIcons.side_panel,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '弹窗测试',
                style: FluentTheme.of(context).typography.body?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 测试结果
          if (_popupWindowTestResult != null) ...[
            _buildTestResult(),
            const SizedBox(height: 12),
          ],

          // 按钮
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _testingPopupWindow ? null : _testPopupWindow,
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_testingPopupWindow)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      else
                        const Icon(FluentIcons.open_pane, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _testingPopupWindow ? '测试中' : '独立弹窗',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Button(
                  onPressed: _testDialogPopup,
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FluentIcons.comment, size: 14),
                      SizedBox(width: 6),
                      Text('Dialog', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 说明
          Text(
            '独立弹窗使用 Tauri，Dialog 需要主窗口',
            style: FluentTheme.of(context).typography.caption?.copyWith(
              color: AppTheme.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResult() {
    final success = _popupWindowTestResult!['success'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: success
            ? AppTheme.statusSuccess.withValues(alpha: 0.08)
            : AppTheme.statusError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            success ? FluentIcons.completed : FluentIcons.error_badge,
            size: 14,
            color: success ? AppTheme.statusSuccess : AppTheme.statusError,
          ),
          const SizedBox(width: 8),
          Text(
            success ? '成功 · ${_popupWindowTestResult!['time']}ms' : '失败',
            style: TextStyle(
              color: success ? AppTheme.statusSuccess : AppTheme.statusError,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testPopupWindow() async {
    if (_testingPopupWindow) return;

    final appLogger = context.read<AppLoggerService>();

    setState(() {
      _testingPopupWindow = true;
      _popupWindowTestResult = null;
    });

    final stopwatch = Stopwatch()..start();
    appLogger.info('PopupTest', '开始测试弹窗窗口...');

    try {
      await PopupWindowService.showPopupDownloadWindow(
        url: 'https://example.com/test-file.zip',
        suggestedFilename: 'test-file.zip',
        isFromBrowser: false,
      );

      stopwatch.stop();
      appLogger.info('PopupTest', '弹窗窗口创建成功，耗时: ${stopwatch.elapsedMilliseconds}ms');

      if (!mounted) return;
      setState(() {
        _popupWindowTestResult = {
          'success': true,
          'time': stopwatch.elapsedMilliseconds,
        };
      });
    } catch (e) {
      stopwatch.stop();
      appLogger.error('PopupTest', '弹窗窗口创建失败: $e');

      if (!mounted) return;
      setState(() {
        _popupWindowTestResult = {
          'success': false,
          'error': e.toString(),
        };
      });
    } finally {
      if (mounted) {
        setState(() {
          _testingPopupWindow = false;
        });
      }
    }
  }

  Future<void> _testDialogPopup() async {
    final appLogger = context.read<AppLoggerService>();

    final stopwatch = Stopwatch()..start();
    appLogger.info('PopupTest', '开始测试 Dialog 弹窗...');

    try {
      await PopupWindowService.showPopupDownload(
        context,
        url: 'https://example.com/test-file.zip',
        suggestedFilename: 'test-dialog-file.zip',
        isFromBrowser: false,
      );

      stopwatch.stop();
      appLogger.info('PopupTest', 'Dialog 弹窗关闭，总耗时: ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      stopwatch.stop();
      appLogger.error('PopupTest', 'Dialog 弹窗失败: $e');
    }
  }
}
