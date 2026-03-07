import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import '../../services/developer_mode_service.dart';
import '../../services/popup_window_service.dart';
import '../../services/app_logger_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;
import '../../widgets/animated_notifications.dart';
import '../../widgets/smooth_scroll_wrapper.dart';

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
  final TextEditingController _customMessageController =
      TextEditingController();
  late AnimationController _animController;

  AppLocalizations get _t => AppLocalizations.of(context)!;

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
    final t = _t;
    return SmoothSingleChildScrollView(
      config: SmoothScrollConfig.fast,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 开发者模式开关
          _buildMasterSwitch(),

          // 开启后显示调试工具
          if (_devMode.developerMode) ...[
            const SizedBox(height: 28),
            _buildSectionTitle(t.developerSectionDebugTools),
            const SizedBox(height: 12),
            _buildDebugToolsGrid(),
            const SizedBox(height: 28),
            _buildSectionTitle(t.developerSectionTestTools),
            const SizedBox(height: 12),
            _buildTestToolsRow(),
          ],
        ],
      ),
    );
  }

  /// 区块标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title,
        style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  /// 开发者模式主开关
  Widget _buildMasterSwitch() {
    final t = _t;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.settingsDeveloperModeTitle,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _devMode.developerMode
                      ? t.developerModeEnabledSubtitle
                      : t.developerModeDisabledSubtitle,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          ToggleSwitch(
            checked: _devMode.developerMode,
            onChanged: (value) {
              _devMode.setDeveloperMode(value);
              if (mounted) {
                NotificationManager.of(context)?.showSuccess(
                  value
                      ? t.settingsDeveloperModeEnabledTitle
                      : t.settingsDeveloperModeDisabledTitle,
                  message: value
                      ? t.settingsDeveloperModeEnabledMessage
                      : t.settingsDeveloperModeDisabledMessage,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// 调试工具网格 — 3列自适应布局
  Widget _buildDebugToolsGrid() {
    final tools = _getDebugTools();
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度决定列数：窄屏2列，宽屏3列
        final columns = constraints.maxWidth >= 680 ? 3 : 2;
        final spacing = 10.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tools
              .map((tool) => SizedBox(
                    width: cardWidth,
                    child: _buildToolCard(
                      icon: tool.icon,
                      title: tool.title,
                      subtitle: tool.subtitle,
                      isEnabled: tool.isEnabled,
                      onChanged: tool.onChanged,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  List<_ToolItem> _getDebugTools() {
    final t = _t;
    return [
      _ToolItem(
        icon: CustomIcons.FluentIcons.text_document,
        title: t.developerToolLogTitle,
        subtitle: t.developerToolLogSubtitle,
        isEnabled: _devMode.showLogPage,
        onChanged: (v) {
          _devMode.setShowLogPage(v);
          if (mounted) {
            NotificationManager.of(context)?.showSuccess(
              v ? t.developerToolLogShownTitle : t.developerToolLogHiddenTitle,
              message: v
                  ? t.developerToolLogShownMessage
                  : t.developerToolLogHiddenMessage,
            );
          }
        },
      ),
      _ToolItem(
        icon: CustomIcons.FluentIcons.health,
        title: t.developerToolStatusTitle,
        subtitle: t.developerToolStatusSubtitle,
        isEnabled: _devMode.showStatusPage,
        onChanged: (v) {
          _devMode.setShowStatusPage(v);
          if (mounted) {
            NotificationManager.of(context)?.showSuccess(
              v
                  ? t.developerToolStatusShownTitle
                  : t.developerToolStatusHiddenTitle,
              message: v
                  ? t.developerToolStatusShownMessage
                  : t.developerToolStatusHiddenMessage,
            );
          }
        },
      ),
      _ToolItem(
        icon: CustomIcons.FluentIcons.globe,
        title: t.developerToolWebCheckTitle,
        subtitle: t.developerToolWebCheckSubtitle,
        isEnabled: _devMode.showWebCheckPage,
        onChanged: (v) {
          _devMode.setShowWebCheckPage(v);
          if (mounted) {
            NotificationManager.of(context)?.showSuccess(
              v
                  ? t.developerToolWebCheckShownTitle
                  : t.developerToolWebCheckHiddenTitle,
              message: v
                  ? t.developerToolWebCheckShownMessage
                  : t.developerToolWebCheckHiddenMessage,
            );
          }
        },
      ),
      _ToolItem(
        icon: CustomIcons.FluentIcons.speed_high,
        title: t.developerToolPerformanceTitle,
        subtitle: t.developerToolPerformanceSubtitle,
        isEnabled: _devMode.showPerformanceMonitorPage,
        onChanged: (v) {
          _devMode.setShowPerformanceMonitorPage(v);
          if (mounted) {
            NotificationManager.of(context)?.showSuccess(
              v
                  ? t.developerToolPerformanceShownTitle
                  : t.developerToolPerformanceHiddenTitle,
              message: v
                  ? t.developerToolPerformanceShownMessage
                  : t.developerToolPerformanceHiddenMessage,
            );
          }
        },
      ),
      _ToolItem(
        icon: CustomIcons.FluentIcons.plug_disconnected,
        title: t.developerToolConnectionDebugTitle,
        subtitle: t.developerToolConnectionDebugSubtitle,
        isEnabled: _devMode.showConnectionDebugPage,
        onChanged: (v) {
          _devMode.setShowConnectionDebugPage(v);
          if (mounted) {
            NotificationManager.of(context)?.showSuccess(
              v
                  ? t.developerToolConnectionDebugShownTitle
                  : t.developerToolConnectionDebugHiddenTitle,
              message: v
                  ? t.developerToolConnectionDebugShownMessage
                  : t.developerToolConnectionDebugHiddenMessage,
            );
          }
        },
      ),
    ];
  }

  /// 工具卡片 - Fluent 2 简约风格
  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required ValueChanged<bool> onChanged,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!isEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? AppTheme.accentPrimary.withValues(alpha: 0.15)
                      : AppTheme.bgLayer2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: isEnabled
                      ? AppTheme.accentPrimary
                      : AppTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FluentTheme.of(context).typography.body?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isEnabled
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textTertiary,
                                fontSize: 11,
                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
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
      ),
    );
  }

  /// 测试工具行
  Widget _buildTestToolsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildNotificationTestCard()),
        const SizedBox(width: 10),
        Expanded(child: _buildPopupTestCard()),
      ],
    );
  }

  /// 通知测试卡片
  Widget _buildNotificationTestCard() {
    final t = _t;
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
          Row(
            children: [
              Icon(
                CustomIcons.FluentIcons.ringer,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                t.developerTestNotificationTitle,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextBox(
            controller: _customTitleController,
            placeholder: t.developerTestNotificationTitlePlaceholder,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextBox(
            controller: _customMessageController,
            placeholder: t.developerTestNotificationMessagePlaceholder,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTypeButton(
                t.developerTestNotificationTypeSuccess,
                AppTheme.statusSuccess,
                NotificationType.success,
              ),
              const SizedBox(width: 6),
              _buildTypeButton(
                t.developerTestNotificationTypeWarning,
                AppTheme.statusWarning,
                NotificationType.warning,
              ),
              const SizedBox(width: 6),
              _buildTypeButton(
                t.developerTestNotificationTypeError,
                AppTheme.statusError,
                NotificationType.error,
              ),
              const SizedBox(width: 6),
              _buildTypeButton(
                t.developerTestNotificationTypeInfo,
                AppTheme.accentPrimary,
                NotificationType.info,
              ),
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
            NotificationManager.of(context)?.showWarning(
              _t.developerTestNotificationTitleRequired,
            );
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
    final t = _t;
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
          Row(
            children: [
              Icon(
                CustomIcons.FluentIcons.side_panel,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                t.developerTestPopupTitle,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_popupWindowTestResult != null) ...[
            _buildTestResult(),
            const SizedBox(height: 12),
          ],
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
                        _testingPopupWindow
                            ? t.developerTestPopupTestingLabel
                            : t.developerTestPopupButton,
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
          Text(
            t.developerTestPopupHint,
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
    final t = _t;
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
            success
                ? t.developerTestPopupResultSuccess(
                    _popupWindowTestResult!['time'])
                : t.developerTestPopupResultFailed,
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
      appLogger.info(
          'PopupTest', '弹窗窗口创建成功，耗时: ${stopwatch.elapsedMilliseconds}ms');

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
      appLogger.info(
          'PopupTest', 'Dialog 弹窗关闭，总耗时: ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      stopwatch.stop();
      appLogger.error('PopupTest', 'Dialog 弹窗失败: $e');
    }
  }
}

/// 工具项数据模型
class _ToolItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _ToolItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    required this.onChanged,
  });
}
