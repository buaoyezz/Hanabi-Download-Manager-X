import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/constants.dart';
import '../../theme/app_theme.dart';
import '../../services/performance_monitor_service.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/smooth_scroll_wrapper.dart';

import '../../widgets/animated_notifications.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage>
    with SingleTickerProviderStateMixin {
  int _logoTapCount = 0;
  bool _easterEggActivated = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  AppLocalizations get t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onLogoTap() {
    setState(() {
      _logoTapCount++;

      if (_logoTapCount >= 10 && !_easterEggActivated) {
        _easterEggActivated = true;
        _showEasterEgg();
      } else if (_logoTapCount < 10) {
        // 摇晃动画
        _shakeController.forward(from: 0);
      }
    });
  }

  void _showEasterEgg() {
    showDialog(
      context: context,
      builder: (ctx) {
        final t = AppLocalizations.of(ctx)!;
        return ContentDialog(
          title: Row(
            children: [
              const Icon(FluentIcons.emoji2,
                  size: 24, color: Color(0xFFFFB900)),
              const SizedBox(width: 12),
              Text(t.aboutEasterEggDialogTitle),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 动画 Logo
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Transform.rotate(
                        angle: value * 6.28, // 360度旋转
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Transform.scale(
                              scale: 1.0,
                              child: const AppLogo(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  t.aboutEasterEggCongrats,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accentPrimary.withValues(alpha: 0.2),
                        AppTheme.accentPrimary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t.aboutEasterEggTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.aboutEasterEggMessage(t.appTitle),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.statusSuccess.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusRound),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(FluentIcons.heart_fill,
                                size: 14, color: Color(0xFFFF6B6B)),
                            const SizedBox(width: 6),
                            Text(
                              t.aboutMadeBy(AppConstants.developer),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 统计信息
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  // children: [
                  //   _buildStatItem('版本', AppConstants.version, FluentIcons.code),
                  //   _buildStatItem('点击', '$_logoTapCount', FluentIcons.touch),
                  //   _buildStatItem('内核', 'NSFX', FluentIcons.processing),
                  // ],
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _logoTapCount = 0;
                  _easterEggActivated = false;
                });
              },
              child: Text(t.aboutEasterEggDismiss),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
    } catch (e) {
      if (context.mounted) {
        final t = AppLocalizations.of(context)!;
        NotificationManager.of(context)?.showError(
          t.aboutOpenLinkErrorTitle,
          message: t.aboutOpenLinkErrorMessage(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    PerformanceMonitorService().trackRebuild('AboutPage');

    return ScaffoldPage(
      header: _buildHeader(context),
      content: SmoothSingleChildScrollView(
        config: SmoothScrollConfig.fast,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1040;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(context, wide: wide),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildLinksSection(context),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 3,
                        child: _buildCopyrightSection(context),
                      ),
                    ],
                  )
                else ...[
                  _buildLinksSection(context),
                  const SizedBox(height: 20),
                  _buildCopyrightSection(context),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return PageHeader(
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
            child: Icon(
              FluentIcons.info,
              size: 18,
              color: AppTheme.accentLight,
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              t.aboutPageTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, {required bool wide}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppTheme.accentPrimary.withValues(alpha: 0.2),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceCard.withValues(alpha: 0.88),
            AppTheme.bgLayer2.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -40,
              child: _AccentGlow(
                size: 220,
                color: AppTheme.accentPrimary.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -30,
              child: _AccentGlow(
                size: 180,
                color: AppTheme.accentLight.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildHeroMain(context, wide: true)),
                        const SizedBox(width: 20),
                        SizedBox(
                          width: 300,
                          child: _buildHeroHighlights(context),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroMain(context, wide: false),
                        const SizedBox(height: 18),
                        _buildHeroHighlights(context),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMain(BuildContext context, {required bool wide}) {
    final titleStyle = FluentTheme.of(context).typography.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: wide ? 30 : 26,
          height: 1.1,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            border: Border.all(
              color: AppTheme.accentPrimary.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            t.aboutSectionAppInfo,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.accentLight,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 18),
        wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInteractiveLogo(),
                  const SizedBox(width: 24),
                  Expanded(child: _buildHeroCopy(context, titleStyle)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInteractiveLogo(),
                  const SizedBox(height: 22),
                  _buildHeroCopy(context, titleStyle),
                ],
              ),
      ],
    );
  }

  Widget _buildHeroCopy(BuildContext context, TextStyle? titleStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.appTitle, style: titleStyle),
        const SizedBox(height: 10),
        Text(
          t.aboutMadeBy(AppConstants.developer),
          style: FluentTheme.of(context).typography.body?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MetaPill(
              icon: FluentIcons.code,
              label: t.aboutVersionLabel(AppConstants.version),
            ),
            _MetaPill(
              icon: FluentIcons.processing,
              label: 'NSFX ${AppConstants.newKernelVersion}',
            ),
            _MetaPill(
              icon: FluentIcons.app_icon_default,
              label: t.aboutDetailUiFrameworkValue,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _HeroActionButton(
              icon: FluentIcons.globe,
              label: t.aboutLinkOfficialTitle,
              emphasized: true,
              onPressed: () => _launchUrl(context, AppConstants.officialUrl),
            ),
            _HeroActionButton(
              icon: FluentIcons.open_source,
              label: t.aboutLinkGithubTitle,
              onPressed: () => _launchUrl(context, AppConstants.githubUrl),
            ),
            _HeroActionButton(
              icon: FluentIcons.mail,
              label: t.aboutLinkContactTitle,
              onPressed: () => _launchUrl(
                context,
                'mailto:${AppConstants.contactEmail}',
              ),
            ),
          ],
        ),
        if (_logoTapCount >= 5 && _logoTapCount < 10) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.statusWarning.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppTheme.radiusRound),
              border: Border.all(
                color: AppTheme.statusWarning.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              t.aboutTapHintRemaining(10 - _logoTapCount),
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.statusWarning,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInteractiveLogo() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _shakeAnimation.value * (_logoTapCount.isEven ? 1 : -1),
            0,
          ),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _onLogoTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                child: _AccentGlow(
                  size: _logoTapCount > 5 ? 220 : 190,
                  color: AppTheme.statusSuccess.withValues(
                    alpha: _logoTapCount > 5 ? 0.16 : 0.1,
                  ),
                ),
              ),
              Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Transform.scale(
                    scale: 1.0,
                    child: const AppLogo(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHighlights(BuildContext context) {
    return Column(
      children: [
        _HeroMetricCard(
          icon: FluentIcons.developer_tools,
          label: t.aboutDetailDeveloperLabel,
          value: AppConstants.developer,
          tone: AppTheme.accentPrimary,
        ),
        const SizedBox(height: 12),
        _HeroMetricCard(
          icon: FluentIcons.processing,
          label: t.aboutDetailKernelLabel,
          value:
              '${AppConstants.newKernelFullName}\n${AppConstants.newKernelVersion}',
          tone: AppTheme.statusInfo,
        ),
        const SizedBox(height: 12),
        _HeroMetricCard(
          icon: FluentIcons.code,
          label: t.aboutDetailUiFrameworkLabel,
          value: t.aboutDetailUiFrameworkValue,
          tone: AppTheme.statusSuccess,
        ),
      ],
    );
  }

  Widget _buildLinksSection(BuildContext context) {
    return _SectionCard(
      title: t.aboutSectionLinks,
      icon: FluentIcons.link,
      child: Column(
        children: [
          _LinkButton(
            icon: FluentIcons.globe,
            title: t.aboutLinkOfficialTitle,
            subtitle: t.aboutLinkOfficialSubtitle,
            meta: _linkMeta(AppConstants.officialUrl),
            onPressed: () => _launchUrl(context, AppConstants.officialUrl),
          ),
          const SizedBox(height: 12),
          _LinkButton(
            icon: FluentIcons.open_source,
            title: t.aboutLinkGithubTitle,
            subtitle: t.aboutLinkGithubSubtitle,
            meta: _linkMeta(AppConstants.githubUrl),
            onPressed: () => _launchUrl(context, AppConstants.githubUrl),
          ),
          const SizedBox(height: 12),
          _LinkButton(
            icon: FluentIcons.mail,
            title: t.aboutLinkContactTitle,
            subtitle: AppConstants.contactEmail,
            meta: AppConstants.contactEmail,
            onPressed: () =>
                _launchUrl(context, 'mailto:${AppConstants.contactEmail}'),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyrightSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.bgLayer2.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              FluentIcons.info,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.aboutCopyrightMessage(
                DateTime.now().year,
                AppConstants.developer,
              ),
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _linkMeta(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return value;
    }
    return uri.host.replaceFirst('www.', '');
  }
}

/// 区块卡片组件 - Fluent Design 风格
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.56),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.bgLayer2.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.accentLight),
          const SizedBox(width: 6),
          Text(
            label,
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool emphasized;
  final VoidCallback onPressed;

  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.emphasized
        ? AppTheme.accentPrimary.withValues(alpha: _hovered ? 0.24 : 0.18)
        : AppTheme.bgLayer2.withValues(alpha: _hovered ? 0.78 : 0.62);
    final borderColor = widget.emphasized
        ? AppTheme.accentPrimary.withValues(alpha: _hovered ? 0.55 : 0.38)
        : AppTheme.borderStrong.withValues(alpha: _hovered ? 0.7 : 0.45);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: AppTheme.accentLight),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  const _HeroMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer1.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: FluentTheme.of(context).typography.body?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onPressed;

  const _LinkButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onPressed,
  });

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppTheme.bgLayer2.withValues(alpha: 0.86)
                : AppTheme.bgLayer1.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: _isHovered
                  ? AppTheme.accentPrimary.withValues(alpha: 0.3)
                  : AppTheme.borderSubtle.withValues(alpha: 0.75),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentPrimary
                          .withValues(alpha: _isHovered ? 0.24 : 0.16),
                      AppTheme.accentPrimary
                          .withValues(alpha: _isHovered ? 0.12 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: AppTheme.accentLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: FluentTheme.of(context)
                                .typography
                                .bodyStrong
                                ?.copyWith(
                                  color: _isHovered
                                      ? AppTheme.accentLight
                                      : AppTheme.textPrimary,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.bgLayer2.withValues(alpha: 0.8),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusRound),
                          ),
                          child: Text(
                            widget.meta,
                            style: FluentTheme.of(context)
                                .typography
                                .caption
                                ?.copyWith(
                                  color: AppTheme.textTertiary,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                height: 1.35,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? AppTheme.accentPrimary.withValues(alpha: 0.12)
                      : AppTheme.bgLayer2.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                ),
                child: Icon(
                  FluentIcons.chevron_right,
                  size: 12,
                  color:
                      _isHovered ? AppTheme.accentLight : AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _AccentGlow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
