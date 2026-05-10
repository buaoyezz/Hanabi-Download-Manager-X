import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/client_config_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/fluent_icons.dart' as custom_icons;

Future<void> showHanabiOobeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _HanabiOobeDialog(),
  );
}

class _HanabiOobeDialog extends StatefulWidget {
  const _HanabiOobeDialog();

  @override
  State<_HanabiOobeDialog> createState() => _HanabiOobeDialogState();
}

class _HanabiOobeDialogState extends State<_HanabiOobeDialog> {
  int _page = 0;
  bool _saving = false;
  bool _initialized = false;
  bool _acceptedAgreements = false;
  bool _termsRead = false;
  bool _privacyRead = false;
  int _termsReadCountdown = 0;
  int _privacyReadCountdown = 0;
  Timer? _termsReadTimer;
  Timer? _privacyReadTimer;

  bool _autoStartDownload = true;
  bool _notifyOnComplete = true;
  bool _enablePopupWindow = true;
  bool _enableClipboardListener = true;
  bool _enableOnlineStats = true;

  late bool _initialAutoStartDownload;
  late bool _initialNotifyOnComplete;
  late bool _initialEnablePopupWindow;
  late bool _initialEnableClipboardListener;
  late bool _initialEnableOnlineStats;

  bool get _isLastPage => _page == 2;
  bool get _termsReading => _termsReadCountdown > 0;
  bool get _privacyReading => _privacyReadCountdown > 0;
  bool get _readRequiredAgreements => _termsRead && _privacyRead;
  bool get _canGoNext =>
      !_isLastPage || (_readRequiredAgreements && _acceptedAgreements);

  bool get _isZh =>
      Localizations.maybeLocaleOf(context)?.languageCode.toLowerCase() == 'zh';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final config = context.read<ClientConfigService>();
    _autoStartDownload = config.getAutoStartDownload();
    _notifyOnComplete = config.getNotifyOnComplete();
    _enablePopupWindow = config.getEnablePopupWindow();
    _enableClipboardListener = config.getEnableClipboardListener();
    _enableOnlineStats = config.getEnableOnlineStats();

    _initialAutoStartDownload = _autoStartDownload;
    _initialNotifyOnComplete = _notifyOnComplete;
    _initialEnablePopupWindow = _enablePopupWindow;
    _initialEnableClipboardListener = _enableClipboardListener;
    _initialEnableOnlineStats = _enableOnlineStats;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final dialogHeight = (MediaQuery.sizeOf(context).height - 150)
        .clamp(320.0, 500.0)
        .toDouble();

    return PopScope(
      canPop: false,
      child: ContentDialog(
        constraints: const BoxConstraints(maxWidth: 760),
        content: SizedBox(
          width: 720,
          height: dialogHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
              _buildStepBar(),
              const SizedBox(height: 22),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final offset = Tween<Offset>(
                      begin: const Offset(0.025, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_page),
                    child: switch (_page) {
                      0 => _buildWelcomePage(),
                      1 => _buildSettingsPage(),
                      _ => _buildAgreementsPage(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_page > 0)
            Button(
              onPressed: _saving ? null : () => setState(() => _page -= 1),
              child: Text(_isZh ? '上一步' : 'Back'),
            ),
          FilledButton(
            onPressed: _saving || !_canGoNext ? null : _handlePrimaryAction,
            child: _saving
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ProgressRing(strokeWidth: 3),
                      const SizedBox(width: 10),
                      Text(_isZh ? '正在保存' : 'Saving'),
                    ],
                  )
                : Text(_isLastPage
                    ? (_isZh ? '完成设置' : 'Finish')
                    : (_isZh ? '继续' : 'Continue')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _termsReadTimer?.cancel();
    _privacyReadTimer?.cancel();
    super.dispose();
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Image.asset(
            'assets/logo/logo.png',
            width: 42,
            height: 42,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hanabi Download ManagerX',
                style: FluentTheme.of(context).typography.subtitle?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                _isZh ? '首次配置向导' : 'First-run setup',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Text(
            AppConstants.version,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepBar() {
    final labels = _isZh
        ? const ['欢迎', '初始设置', '协议']
        : const ['Welcome', 'Setup', 'Agreements'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              decoration: BoxDecoration(
                color: index <= _page
                    ? AppTheme.accentPrimary
                    : AppTheme.borderSubtle,
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
              ),
            ),
          ),
          if (index != labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildWelcomePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isZh ? '先确认几项基础配置' : 'Confirm a few defaults',
          style: FluentTheme.of(context).typography.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          _isZh
              ? '此新手向导只会出现一次,将不会擅自改动你现在已有的设置'
              : 'This setup appears once, stays in a window, and does not silently overwrite existing preferences. Changes are saved only when you finish.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 28),
        _buildIntroRow(
          icon: custom_icons.FluentIcons.settings_24,
          title: _isZh ? '保留你的现有配置' : 'Keep existing preferences',
          body: _isZh
              ? '老用户的下载、弹窗、剪贴板和通知设置会作为默认值显示'
              : 'Download, popup, clipboard, and notification preferences are loaded as-is.',
        ),
        _buildIntroRow(
          icon: custom_icons.FluentIcons.globe_shield_24,
          title: _isZh ? '在线统计默认开启' : 'Online count defaults on',
          body: _isZh
              ? '只发送匿名在线心跳和按周期派生的匿名统计 token，不上传 IP、UA、指纹、下载内容或原始本地标识；引导完成前不会发送统计数据'
              : 'Only anonymous online heartbeats and period-based stats tokens are sent, never IP, UA, fingerprints, downloads, or the local source identifier.',
        ),
        _buildIntroRow(
          icon: custom_icons.FluentIcons.document_24,
          title: _isZh ? '软件协议内容' : 'Review agreements',
          body: _isZh
              ? '最后一步会展示服务条款和隐私政策，你需要打开并阅读两份内容后才能完成向导'
              : 'The last step shows the service terms and privacy policy. You must open both before continuing.',
        ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isZh ? '初始设置' : 'Initial settings',
            style: FluentTheme.of(context).typography.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _isZh
                ? '请配置你的设置项,后续你依旧可以在设置里重新修改他们'
                : 'You can change these later in Settings.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),
          _buildSettingSwitch(
            icon: custom_icons.FluentIcons.arrow_download_24,
            title: _isZh ? '添加任务后自动开始下载' : 'Start downloads automatically',
            subtitle: _isZh
                ? '打开此选项,新任务创建后将会直接进入下载流程'
                : 'New tasks start as soon as they are created.',
            value: _autoStartDownload,
            onChanged: (value) => setState(() => _autoStartDownload = value),
          ),
          _buildSettingSwitch(
            icon: custom_icons.FluentIcons.info_24,
            title: _isZh ? '下载完成通知' : 'Completion notifications',
            subtitle: _isZh
                ? '任务完成后显示系统通知'
                : 'Show a system notification when a task finishes.',
            value: _notifyOnComplete,
            onChanged: (value) => setState(() => _notifyOnComplete = value),
          ),
          _buildSettingSwitch(
            icon: custom_icons.FluentIcons.window_20,
            title: _isZh ? '浏览器下载弹窗' : 'Browser download popup',
            subtitle: _isZh
                ? '此选项为浏览器扩展与客户端的联动桥,浏览器扩展唤起下载时显示轻量确认窗口'
                : 'Show a compact confirmation window for browser-extension downloads.',
            value: _enablePopupWindow,
            onChanged: (value) => setState(() => _enablePopupWindow = value),
          ),
          _buildSettingSwitch(
            icon: custom_icons.FluentIcons.document_24,
            title: _isZh ? '剪贴板链接监听' : 'Clipboard link detection',
            subtitle: _isZh
                ? '开启后软件会自动检测剪贴板里的下载链接(我们只会检测链接,不会收集或上传剪贴板内容,一切行为皆在本地进行)，并在识别到下载链接时弹出创建任务窗口'
                : 'Detect downloadable links from the clipboard.',
            value: _enableClipboardListener,
            onChanged: (value) =>
                setState(() => _enableClipboardListener = value),
          ),
          _buildSettingSwitch(
            icon: custom_icons.FluentIcons.people_24,
            title: _isZh ? '参与实时在线人数统计' : 'Join live online count',
            subtitle: _isZh
                ? '默认开启(荐),用于匿名在线人数和活跃去重统计，不上传 UA、指纹、下载内容或原始本地标识'
                : 'On by default for anonymous online count and active-user dedupe; no UA, fingerprints, downloads, or local source identifier.',
            value: _enableOnlineStats,
            onChanged: (value) => setState(() => _enableOnlineStats = value),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isZh ? '协议与隐私' : 'Terms and privacy',
          style: FluentTheme.of(context).typography.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          _isZh
              ? '继续使用前，请先打开并阅读服务条款和隐私政策'
              : 'Open and read the service terms and privacy policy before continuing.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildLegalPanel(
                  title: _isZh ? '服务条款' : 'Service terms',
                  icon: custom_icons.FluentIcons.checkmark_circle_24,
                  points: _isZh
                      ? const [
                          '本软件遵循以下服务条款',
                          '你需要打开下面提供的链接阅读完整内容，阅读后才能继续完成向导',
                          '使用本软件即表示同意这些条款，如果你不同意，请勿使用本软件',
                        ]
                      : const [
                          'This software follows the service terms linked below.',
                          'You need to open the links and read the full content before you can continue.',
                          'By using this software, you agree to these terms. If you do not agree, please do not use this software.',
                        ],
                  actions: [
                    _LegalAction(
                      label: _termsRead
                          ? (_isZh ? '已阅读服务条款' : 'Service terms read')
                          : _termsReading
                              ? (_isZh
                                  ? '阅读中 ${_termsReadCountdown}s'
                                  : 'Reading ${_termsReadCountdown}s')
                              : (_isZh ? '打开服务条款' : 'Open service terms'),
                      url: '${AppConstants.officialUrl}/terms/',
                      isRead: _termsRead,
                      isPending: _termsReading,
                      onOpened: _startTermsReadTimer,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLegalPanel(
                  title: _isZh ? '隐私政策' : 'Privacy policy',
                  icon: custom_icons.FluentIcons.globe_shield_24,
                  points: _isZh
                      ? const [
                          '本软件遵循以下隐私政策',
                          '若隐私政策中提到的某些数据收集或使用行为你无法接受，请勿使用本软件',
                          '使用本软件即表示同意隐私政策中提到的各项内容，如果你不同意，请勿使用本软件',
                        ]
                      : const [
                          'This software follows the privacy policy linked below.',
                          'If you do not agree with any part of the privacy policy, please do not use this software.',
                          'By using this software, you agree to the terms of the privacy policy.',
                        ],
                  actions: [
                    _LegalAction(
                      label: _privacyRead
                          ? (_isZh ? '已阅读隐私政策' : 'Privacy policy read')
                          : _privacyReading
                              ? (_isZh
                                  ? '阅读中 ${_privacyReadCountdown}s'
                                  : 'Reading ${_privacyReadCountdown}s')
                              : (_isZh ? '打开隐私政策' : 'Open privacy policy'),
                      url: '${AppConstants.officialUrl}/privacy/',
                      isRead: _privacyRead,
                      isPending: _privacyReading,
                      onOpened: _startPrivacyReadTimer,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Checkbox(
            checked: _acceptedAgreements,
            onChanged: _readRequiredAgreements
                ? (value) {
                    setState(() => _acceptedAgreements = value ?? false);
                  }
                : null,
            content: Text(
              _isZh
                  ? '我已阅读并同意服务条款和隐私政策'
                  : 'I have read and agree to the service terms and privacy policy',
            ),
          ),
        ),
        if (!_readRequiredAgreements) ...[
          const SizedBox(height: 8),
          Text(
            _isZh
                ? '请先打开服务条款和隐私政策，阅读后才能勾选同意。'
                : 'Open both documents before checking this box.',
            style: TextStyle(color: AppTheme.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildIntroRow({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconBubble(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          _buildIconBubble(icon, compact: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ToggleSwitch(
            checked: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildLegalPanel({
    required String title,
    required IconData icon,
    required List<String> points,
    required List<_LegalAction> actions,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              _buildIconBubble(icon, compact: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final point in points)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 7),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPrimary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              point,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                height: 1.42,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                Button(
                  onPressed: () => _openLegalAction(action),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        action.isRead
                            ? custom_icons.FluentIcons.checkmark_20
                            : action.isPending
                                ? custom_icons.FluentIcons.clock_20
                                : custom_icons.FluentIcons.link_20,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(action.label),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconBubble(IconData icon, {bool compact = false}) {
    final size = compact ? 30.0 : 38.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.accentPrimary.withValues(alpha: 0.24),
        ),
      ),
      child: Icon(
        icon,
        size: compact ? 17 : 20,
        color: AppTheme.accentPrimary,
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (!_isLastPage) {
      setState(() => _page += 1);
      return;
    }

    await _finish();
  }

  Future<void> _finish() async {
    if (_saving || !_acceptedAgreements) return;

    setState(() => _saving = true);
    final config = context.read<ClientConfigService>();

    try {
      if (_autoStartDownload != _initialAutoStartDownload) {
        await config.setAutoStartDownload(_autoStartDownload);
      }
      if (_notifyOnComplete != _initialNotifyOnComplete) {
        await config.setNotifyOnComplete(_notifyOnComplete);
      }
      if (_enablePopupWindow != _initialEnablePopupWindow) {
        await config.setEnablePopupWindow(_enablePopupWindow);
      }
      if (_enableClipboardListener != _initialEnableClipboardListener) {
        await config.setEnableClipboardListener(_enableClipboardListener);
      }
      if (_enableOnlineStats != _initialEnableOnlineStats) {
        await config.setEnableOnlineStats(_enableOnlineStats);
      }

      await config.markOobeCompleted();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openLegalAction(_LegalAction action) async {
    final opened = await launchUrl(
      Uri.parse(action.url),
      mode: LaunchMode.externalApplication,
    );
    if (opened && mounted) {
      action.onOpened();
    }
  }

  void _startTermsReadTimer() {
    if (_termsRead || _termsReading) return;
    setState(() => _termsReadCountdown = 5);
    _termsReadTimer?.cancel();
    _termsReadTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_termsReadCountdown <= 1) {
        timer.cancel();
        setState(() {
          _termsReadCountdown = 0;
          _termsRead = true;
        });
      } else {
        setState(() => _termsReadCountdown -= 1);
      }
    });
  }

  void _startPrivacyReadTimer() {
    if (_privacyRead || _privacyReading) return;
    setState(() => _privacyReadCountdown = 5);
    _privacyReadTimer?.cancel();
    _privacyReadTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_privacyReadCountdown <= 1) {
        timer.cancel();
        setState(() {
          _privacyReadCountdown = 0;
          _privacyRead = true;
        });
      } else {
        setState(() => _privacyReadCountdown -= 1);
      }
    });
  }
}

class _LegalAction {
  final String label;
  final String url;
  final bool isRead;
  final bool isPending;
  final VoidCallback onOpened;

  const _LegalAction({
    required this.label,
    required this.url,
    required this.isRead,
    required this.isPending,
    required this.onOpened,
  });
}
