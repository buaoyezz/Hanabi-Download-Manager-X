import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final String currentVersion;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return ContentDialog(
      title: Row(
        children: [
          Icon(
            FluentIcons.download,
            color: AppTheme.accentLight,
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
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v$currentVersion',
                        style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
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
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v${updateInfo.version}',
                        style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
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
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: AppTheme.bgLayer1,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  updateInfo.changelog,
                  style: FluentTheme.of(context).typography.body,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
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
          child: Text(t.updateDialogDownloadNowButton),
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
                        style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v$currentVersion',
                        style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
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
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: AppTheme.bgLayer1,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  changelog,
                  style: FluentTheme.of(context).typography.body,
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
                    style: FluentTheme.of(context).typography.bodyLarge?.copyWith(
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
