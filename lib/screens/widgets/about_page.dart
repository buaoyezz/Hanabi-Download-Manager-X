import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/animated_notifications.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/settings_components.dart';
import '../../widgets/smooth_scroll_wrapper.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const double _maxContentWidth = 840;

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
    final t = AppLocalizations.of(context)!;

    return ScaffoldPage(
      header: SettingsPageHeader(
        title: t.aboutPageTitle,
        icon: FluentIcons.info,
      ),
      content: SmoothSingleChildScrollView(
        config: SmoothScrollConfig.fast,
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 40),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AppSummary(
                  appName: t.appTitle,
                  version: t.aboutVersionLabel(AppConstants.version),
                  developer: t.aboutMadeBy(AppConstants.developer),
                ),
                const SizedBox(height: 24),
                SettingsSection(
                  title: t.aboutSectionAppInfo,
                  icon: FluentIcons.info,
                  margin: EdgeInsets.zero,
                  children: [
                    SettingsItem(
                      title: t.aboutDetailDeveloperLabel,
                      subtitle: AppConstants.developer,
                      trailing: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    SettingsItem(
                      title: t.aboutDetailKernelLabel,
                      subtitle:
                          '${AppConstants.nsfxKernelFormattedString} / ${AppConstants.neoKernelFormattedString}',
                      trailing: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    SettingsItem(
                      title: t.aboutDetailUiFrameworkLabel,
                      subtitle: t.aboutDetailUiFrameworkValue,
                      trailing: const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SettingsSection(
                  title: t.aboutSectionLinks,
                  icon: FluentIcons.link,
                  margin: EdgeInsets.zero,
                  children: [
                    _AboutLinkItem(
                      title: t.aboutLinkOfficialTitle,
                      subtitle: t.aboutLinkOfficialSubtitle,
                      onPressed: () =>
                          _launchUrl(context, AppConstants.officialUrl),
                    ),
                    const SizedBox(height: 12),
                    _AboutLinkItem(
                      title: t.aboutLinkGithubTitle,
                      subtitle: t.aboutLinkGithubSubtitle,
                      onPressed: () =>
                          _launchUrl(context, AppConstants.githubUrl),
                    ),
                    const SizedBox(height: 12),
                    _AboutLinkItem(
                      title: t.aboutLinkContactTitle,
                      subtitle: AppConstants.contactEmail,
                      onPressed: () => _launchUrl(
                        context,
                        'mailto:${AppConstants.contactEmail}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  t.aboutCopyrightMessage(
                    DateTime.now().year,
                    AppConstants.developer,
                  ),
                  style: FluentTheme.of(context)
                      .typography
                      .caption
                      ?.copyWith(color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppSummary extends StatelessWidget {
  const _AppSummary({
    required this.appName,
    required this.version,
    required this.developer,
  });

  final String appName;
  final String version;
  final String developer;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: AppLogo(),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typography.title?.copyWith(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  version,
                  style: typography.body?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  developer,
                  style: typography.caption?.copyWith(
                    color: AppTheme.textTertiary,
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

class _AboutLinkItem extends StatelessWidget {
  const _AboutLinkItem({
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HoverButton(
      cursor: SystemMouseCursors.click,
      onPressed: onPressed,
      builder: (context, states) {
        final background = states.isPressed
            ? AppTheme.surfaceCardPressed
            : states.isHovered
                ? AppTheme.surfaceCardHover
                : Colors.transparent;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: FluentTheme.of(context).typography.body?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                fontSize: 12,
                                height: 1.25,
                                color: AppTheme.textTertiary,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                FluentIcons.chevron_right,
                size: 12,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        );
      },
    );
  }
}
