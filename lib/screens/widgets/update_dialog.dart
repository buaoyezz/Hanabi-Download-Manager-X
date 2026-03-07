import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/smooth_scroll_wrapper.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final String currentVersion;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
  });

  bool _isChineseLocale(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh';

  String _urgencyLabel(BuildContext context, UpdateUrgency urgency) {
    final zh = _isChineseLocale(context);
    switch (urgency) {
      case UpdateUrgency.forced:
        return zh ? '强制更新' : 'Forced Update';
      case UpdateUrgency.recommended:
        return zh ? '推荐更新' : 'Recommended Update';
      case UpdateUrgency.normal:
        return zh ? '普通更新' : 'Normal Update';
    }
  }

  String _urgencyHint(BuildContext context, UpdateInfo info) {
    final zh = _isChineseLocale(context);
    if (info.urgency == UpdateUrgency.forced) {
      if (info.minSupportedVersion != null) {
        return zh
            ? '当前版本低于最低支持版本 v${info.minSupportedVersion!.versionString}，请立即更新。'
            : 'Current version is below minimum supported v${info.minSupportedVersion!.versionString}. Update is required.';
      }
      return zh
          ? '该版本为强制更新，请立即安装。'
          : 'This release is mandatory. Please update now.';
    }
    if (info.urgency == UpdateUrgency.recommended) {
      return zh
          ? '该版本包含重要改进，建议尽快更新。'
          : 'This release includes important improvements and is recommended.';
    }
    return zh ? '检测到新版本，可按需更新。' : 'A newer version is available.';
  }

  Color _urgencyColor(UpdateUrgency urgency) {
    switch (urgency) {
      case UpdateUrgency.forced:
        return AppTheme.statusError;
      case UpdateUrgency.recommended:
        return AppTheme.statusWarning;
      case UpdateUrgency.normal:
        return AppTheme.accentLight;
    }
  }

  IconData _urgencyIcon(UpdateUrgency urgency) {
    switch (urgency) {
      case UpdateUrgency.forced:
        return FluentIcons.warning;
      case UpdateUrgency.recommended:
        return FluentIcons.info;
      case UpdateUrgency.normal:
        return FluentIcons.download;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final urgencyColor = _urgencyColor(updateInfo.urgency);
    final isForced = updateInfo.urgency == UpdateUrgency.forced;
    return ContentDialog(
      title: Row(
        children: [
          Icon(
            _urgencyIcon(updateInfo.urgency),
            color: urgencyColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(t.updateAvailableTitle),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: urgencyColor.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _urgencyLabel(context, updateInfo.urgency),
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: urgencyColor,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _urgencyHint(context, updateInfo),
                      style: FluentTheme.of(context)
                          .typography
                          .caption
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 版本信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.updateCurrentVersionTitle,
                        style: FluentTheme.of(context)
                            .typography
                            .caption
                            ?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v$currentVersion',
                        style: FluentTheme.of(context)
                            .typography
                            .bodyLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  Icon(
                    FluentIcons.forward,
                    color: AppTheme.accentLight,
                    size: 24,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        t.updateLatestVersionLabel,
                        style: FluentTheme.of(context)
                            .typography
                            .caption
                            ?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v${updateInfo.version}',
                        style: FluentTheme.of(context)
                            .typography
                            .bodyLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentLight,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 更新日志
            Text(
              t.updateAvailableChangelogTitle,
              style: FluentTheme.of(context).typography.subtitle?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLayer1.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.borderSubtle.withValues(alpha: 0.4),
                    ),
                  ),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      physics: const BouncingScrollPhysics(),
                    ),
                    child: SmoothSingleChildScrollView(
                      config: SmoothScrollConfig.fast,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        updateInfo.changelog,
                        style: FluentTheme.of(context).typography.body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!isForced)
          Button(
            onPressed: () => Navigator.pop(context),
            child: Text(t.updateDialogLaterButton),
          ),
        FilledButton(
          onPressed: () async {
            if (updateInfo.downloadUrl.isNotEmpty) {
              final uri = Uri.parse(updateInfo.downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: Text(
            isForced
                ? (_isChineseLocale(context) ? '立即更新' : 'Update Now')
                : t.updateDialogDownloadNowButton,
          ),
        ),
      ],
    );
  }
}

class CurrentVersionDialog extends StatelessWidget {
  final String currentVersion;
  final String changelog;

  const CurrentVersionDialog({
    super.key,
    required this.currentVersion,
    required this.changelog,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ContentDialog(
      title: Row(
        children: [
          Icon(
            FluentIcons.info,
            color: AppTheme.accentLight,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(t.updateDialogCurrentInfoTitle),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 版本信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.statusSuccess.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.statusSuccess.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.check_mark,
                    color: AppTheme.statusSuccess,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.updateCurrentVersionTitle,
                        style: FluentTheme.of(context)
                            .typography
                            .caption
                            ?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v$currentVersion',
                        style: FluentTheme.of(context)
                            .typography
                            .bodyLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.statusSuccess,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 更新日志
            Text(
              t.updateChangelogTitle,
              style: FluentTheme.of(context).typography.subtitle?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLayer1.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.borderSubtle.withValues(alpha: 0.4),
                    ),
                  ),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      physics: const BouncingScrollPhysics(),
                    ),
                    child: SmoothSingleChildScrollView(
                      config: SmoothScrollConfig.fast,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        changelog,
                        style: FluentTheme.of(context).typography.body,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.updateDialogCloseButton),
        ),
      ],
    );
  }
}

class NoUpdateDialog extends StatelessWidget {
  final String currentVersion;

  const NoUpdateDialog({
    super.key,
    required this.currentVersion,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ContentDialog(
      title: Row(
        children: [
          Icon(
            FluentIcons.check_mark,
            color: AppTheme.statusSuccess,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(t.updateLatestTitle),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.statusSuccess.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.statusSuccess.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              FluentIcons.completed_solid,
              color: AppTheme.statusSuccess,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${t.updateCurrentVersionTitle}: v$currentVersion',
                    style:
                        FluentTheme.of(context).typography.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.updateLatestSubtitle,
                    style: FluentTheme.of(context).typography.body?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.updateDialogCloseButton),
        ),
      ],
    );
  }
}
