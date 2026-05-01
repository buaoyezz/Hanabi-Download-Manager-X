import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:flutter/material.dart' show Material;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart';
import '../../widgets/smooth_scroll_wrapper.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final _changelogScrollController = ScrollController();
  final _updateScrollController = ScrollController();

  String _getChannelDisplayName(VersionChannel channel, AppLocalizations t) {
    switch (channel) {
      case VersionChannel.alpha:
        return t.updateChannelAlpha;
      case VersionChannel.release:
        return t.updateChannelRelease;
    }
  }

  String _getCheckIntervalLabel(
      UpdateCheckInterval interval, AppLocalizations t) {
    switch (interval) {
      case UpdateCheckInterval.startup:
        return t.updateIntervalStartup;
      case UpdateCheckInterval.hourly:
        return t.updateIntervalHourly;
      case UpdateCheckInterval.daily:
        return t.updateIntervalDaily;
      case UpdateCheckInterval.weekly:
        return t.updateIntervalWeekly;
      case UpdateCheckInterval.never:
        return t.updateIntervalNever;
    }
  }

  bool _isChineseLocale(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'zh';

  String _getUrgencyLabel(BuildContext context, UpdateUrgency urgency) {
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

  String _getUrgencyHint(BuildContext context, UpdateInfo info) {
    final zh = _isChineseLocale(context);
    switch (info.urgency) {
      case UpdateUrgency.forced:
        if (info.minSupportedVersion != null) {
          return zh
              ? '最低支持版本：v${info.minSupportedVersion!.versionString}。当前版本过低，必须更新。'
              : 'Minimum supported version is v${info.minSupportedVersion!.versionString}. Your version is too old and must be updated.';
        }
        return zh ? '该版本为强制更新，必须更新后继续使用。' : 'This is a mandatory update.';
      case UpdateUrgency.recommended:
        return zh
            ? '该版本包含重要修复与改进，建议尽快更新。'
            : 'Includes important fixes and improvements. Updating is recommended.';
      case UpdateUrgency.normal:
        return zh ? '可按需更新。' : 'Optional update.';
    }
  }

  String _getUpdateActionLabel(BuildContext context, UpdateUrgency urgency) {
    final zh = _isChineseLocale(context);
    if (urgency == UpdateUrgency.forced) {
      return zh ? '立即更新' : 'Update Now';
    }
    return AppLocalizations.of(context)!.updateStartButton;
  }

  String _normalizeLocalizedMessage(String value) {
    return value.replaceAll(r'\n', '\n');
  }

  String _buildLauncherFailureMessage(
    BuildContext context,
    AppLocalizations t,
    UpdateService updateService,
  ) {
    final message = _normalizeLocalizedMessage(t.updateLauncherFailedMessage);
    final error = updateService.downloadError;
    if (error == null || error.trim().isEmpty) {
      return message;
    }
    return '$message\n\n${_isChineseLocale(context) ? '错误详情' : 'Details'}: $error';
  }

  Color _getUrgencyColor(UpdateUrgency urgency) {
    switch (urgency) {
      case UpdateUrgency.forced:
        return AppTheme.statusError;
      case UpdateUrgency.recommended:
        return AppTheme.statusWarning;
      case UpdateUrgency.normal:
        return AppTheme.accentLight;
    }
  }

  IconData _getUrgencyIcon(UpdateUrgency urgency) {
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
  void initState() {
    super.initState();
    // 页面加载时自动检查更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final updateService = context.read<UpdateService>();
      updateService.checkForUpdates();
    });
  }

  @override
  void dispose() {
    _changelogScrollController.dispose();
    _updateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    // 返回Column而不是ScaffoldPage，因为这个页面会被嵌入到settings_page的ScaffoldPage.scrollable中
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        // 判断是否有更新
        final hasUpdate = updateService.hasUpdate();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUpdateCheckSection(context, t),
            const SizedBox(height: 24),
            // 只有在没有更新时才显示当前版本信息
            if (!hasUpdate) ...[
              _buildCurrentVersionSection(context, t),
              const SizedBox(height: 24),
            ],
            _buildUpdateSettingsSection(context, t),
          ],
        );
      },
    );
  }

  Widget _buildCurrentVersionSection(BuildContext context, AppLocalizations t) {
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FluentTheme.of(context)
                .resources
                .cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: FluentTheme.of(context).resources.cardStrokeColorDefault,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FluentIcons.info,
                    size: 20,
                    color: AppTheme.accentLight,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t.updateCurrentVersionTitle,
                    style:
                        FluentTheme.of(context).typography.subtitle?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                  children: [
                    Icon(
                      FluentIcons.completed_solid,
                      color: AppTheme.accentLight,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'v${updateService.currentVersion}',
                          style: FluentTheme.of(context)
                              .typography
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentLight,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.appTitle,
                          style:
                              FluentTheme.of(context).typography.body?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t.updateChangelogTitle,
                style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    width: double.infinity,
                    height: 150, // 固定高度用于预览
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgLayer1.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: AppTheme.borderSubtle.withValues(alpha: 0.4),
                      ),
                    ),
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: const [
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: _buildMarkdownContent(
                            context, updateService.getCurrentChangelog()),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Button(
                onPressed: () => _showChangelogDialog(
                  context,
                  t.updateChangelogDialogTitle(updateService.currentVersion),
                  updateService.getCurrentChangelog(),
                ),
                child: Text(t.updateChangelogViewFullButton),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpdateCheckSection(BuildContext context, AppLocalizations t) {
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        final activeUpdate =
            updateService.availableUpdate ?? updateService.latestRelease;
        final urgency = activeUpdate?.urgency ?? UpdateUrgency.normal;
        final isForced = urgency == UpdateUrgency.forced;
        final isAlpha =
            activeUpdate?.versionInfo.channel == VersionChannel.alpha;
        final sectionAccentColor =
            isAlpha ? AppTheme.statusError : AppTheme.accentLight;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isAlpha
                ? AppTheme.statusError.withValues(alpha: 0.08)
                : FluentTheme.of(context)
                    .resources
                    .cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: isAlpha
                  ? AppTheme.statusError.withValues(alpha: 0.4)
                  : FluentTheme.of(context).resources.cardStrokeColorDefault,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        FluentIcons.update_restore,
                        size: 20,
                        color: sectionAccentColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        t.updateCheckTitle,
                        style: FluentTheme.of(context)
                            .typography
                            .subtitle
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // 如果有更新，显示"开始更新"按钮
                      if (!updateService.isChecking &&
                          updateService.hasUpdate()) ...[
                        FilledButton(
                          onPressed: () async {
                            final release = updateService.availableUpdate ??
                                updateService.latestRelease;
                            if (release == null) return;

                            // 先弹出确认对话框
                            final confirmed = await showDialog<bool>(
                              context: context,
                              barrierDismissible: !isForced,
                              builder: (context) {
                                final isAlphaTarget =
                                    release.versionInfo.channel ==
                                        VersionChannel.alpha;
                                final dialogAccentColor = isAlphaTarget
                                    ? AppTheme.statusError
                                    : _getUrgencyColor(urgency);
                                return ContentDialog(
                                  title: Text(
                                    isForced
                                        ? (_isChineseLocale(context)
                                            ? '强制更新'
                                            : 'Mandatory Update')
                                        : t.updateConfirmTitle,
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isForced
                                            ? (_isChineseLocale(context)
                                                ? '当前版本必须更新后才能继续获得支持，请立即更新。'
                                                : 'This version must be updated to continue receiving support.')
                                            : t.updateConfirmMessage,
                                        style: FluentTheme.of(context)
                                            .typography
                                            .body,
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: dialogAccentColor.withValues(
                                              alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                              AppTheme.radiusMd),
                                          border: Border.all(
                                            color: dialogAccentColor.withValues(
                                                alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _getUrgencyIcon(urgency),
                                              size: 16,
                                              color: dialogAccentColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                t.updateConfirmDetails(
                                                  release.version,
                                                  updateService.currentVersion,
                                                  '${updateService.currentVersion} → ${release.version}',
                                                  _getChannelDisplayName(
                                                      updateService
                                                          .currentChannel,
                                                      t),
                                                  _getChannelDisplayName(
                                                    release.versionInfo.channel,
                                                    t,
                                                  ),
                                                ),
                                                style: FluentTheme.of(context)
                                                    .typography
                                                    .caption
                                                    ?.copyWith(
                                                      color: AppTheme
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    if (!isForced)
                                      Button(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child:
                                            Text(t.updateConfirmCancelButton),
                                      ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        isForced
                                            ? _getUpdateActionLabel(
                                                context,
                                                urgency,
                                              )
                                            : t.updateConfirmProceedButton,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirmed != true) return;

                            // 用户确认后开始更新
                            final success = await updateService.startUpdate();
                            if (!success && context.mounted) {
                              await showDialog(
                                context: context,
                                builder: (context) => ContentDialog(
                                  title: Text(t.updateLauncherFailedTitle),
                                  content: Text(
                                    _buildLauncherFailureMessage(
                                      context,
                                      t,
                                      updateService,
                                    ),
                                  ),
                                  actions: [
                                    Button(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                          t.updateLauncherFailedCloseButton),
                                    ),
                                    FilledButton(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        if (release.downloadUrl.isNotEmpty) {
                                          final uri =
                                              Uri.parse(release.downloadUrl);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri,
                                                mode: LaunchMode
                                                    .externalApplication);
                                          }
                                        }
                                      },
                                      child: Text(t
                                          .updateLauncherFailedManualDownloadButton),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.download, size: 14),
                              const SizedBox(width: 6),
                              Text(_getUpdateActionLabel(context, urgency)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // 检查中显示进度环，否则显示重新检查按钮
                      if (updateService.isChecking)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: ProgressRing(strokeWidth: 2),
                        )
                      else
                        Button(
                          onPressed: () async {
                            await updateService.checkForUpdates();
                          },
                          child: Text(t.updateCheckAgainButton),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (updateService.isChecking)
                _buildCheckingState(context, t)
              else if (updateService.error != null)
                _buildErrorState(context, updateService.error!, t)
              else if (updateService.isVersionNewer)
                _buildVersionNewerState(context, updateService, t)
              else if (updateService.hasUpdate())
                _buildUpdateAvailable(context, updateService, t)
              else if (updateService.lastCheckTime != null)
                _buildNoUpdate(context, t)
              else
                _buildInitialState(context, t),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckingState(BuildContext context, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusInfo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusInfo.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              t.updateCheckingStatus,
              style: FluentTheme.of(context).typography.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, String error, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.statusError.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.error,
            color: AppTheme.statusError,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.updateCheckFailedTitle,
                  style:
                      FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.statusError,
                          ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoUpdate(BuildContext context, AppLocalizations t) {
    return Container(
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.updateLatestTitle,
                  style:
                      FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.statusSuccess,
                          ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.updateLatestSubtitle,
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(BuildContext context, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgLayer2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.info,
            color: AppTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              t.updateInitialHint,
              style: FluentTheme.of(context).typography.body?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(BuildContext context, String content) {
    return Material(
      color: Colors.transparent,
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: FluentTheme.of(context).typography.body?.copyWith(
                height: 1.6,
                color: AppTheme.textPrimary,
              ),
          h1: FluentTheme.of(context).typography.title?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
          h2: FluentTheme.of(context).typography.subtitle?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
          h3: FluentTheme.of(context).typography.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
          listBullet: FluentTheme.of(context).typography.body?.copyWith(
                color: AppTheme.textPrimary,
              ),
          code: FluentTheme.of(context).typography.body?.copyWith(
                fontFamily: 'Consolas',
                backgroundColor: AppTheme.bgLayer2,
                color: AppTheme.accentLight,
              ),
          codeblockDecoration: BoxDecoration(
            color: AppTheme.bgLayer2,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          blockquoteDecoration: BoxDecoration(
            color: AppTheme.bgLayer2,
            border: Border(
              left: BorderSide(
                color: AppTheme.accentPrimary,
                width: 3,
              ),
            ),
          ),
          a: FluentTheme.of(context).typography.body?.copyWith(
                color: AppTheme.accentLight,
                decoration: TextDecoration.underline,
              ),
        ),
        onTapLink: (text, href, title) async {
          if (href != null) {
            final uri = Uri.parse(href);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      ),
    );
  }

  Widget _buildVersionNewerState(
    BuildContext context,
    UpdateService updateService,
    AppLocalizations t,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.accentPrimary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.product_release,
            color: AppTheme.accentLight,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.updateUnreleasedTitle,
                  style:
                      FluentTheme.of(context).typography.bodyStrong?.copyWith(
                            color: AppTheme.accentLight,
                          ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.updateUnreleasedSubtitle(updateService.currentVersion),
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChangelogDialog(
      BuildContext context, String title, String content) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) {
        final theme = FluentTheme.of(context);
        final t = AppLocalizations.of(context)!;
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                width: 585,
                height: 362,
                decoration: BoxDecoration(
                  color: AppTheme.bgLayer1.withValues(alpha: 0.5),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Text(
                        title,
                        style: theme.typography.subtitle?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: const [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.03, 0.92, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SmoothSingleChildScrollView(
                            config: SmoothScrollConfig.fast,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: _buildMarkdownContent(context, content),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Button(
                            onPressed: () => Navigator.pop(context),
                            child: Text(t.updateDialogCloseButton),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpdateSettingsSection(BuildContext context, AppLocalizations t) {
    return Consumer<UpdateService>(
      builder: (context, updateService, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FluentTheme.of(context)
                .resources
                .cardBackgroundFillColorDefault,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: FluentTheme.of(context).resources.cardStrokeColorDefault,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    FluentIcons.settings,
                    size: 20,
                    color: AppTheme.accentLight,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t.updateSettingsTitle,
                    style:
                        FluentTheme.of(context).typography.subtitle?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (updateService.isForcedUpdate &&
                  updateService.availableUpdate != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.statusError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.statusError.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FluentIcons.warning,
                        color: AppTheme.statusError,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _getUrgencyHint(
                            context,
                            updateService.availableUpdate!,
                          ),
                          style: FluentTheme.of(context)
                              .typography
                              .caption
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 当前通道显示
              _buildSettingRow(
                context,
                title: t.updateChannelTitle,
                subtitle:
                    _getChannelDisplayName(updateService.currentChannel, t),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getChannelColor(updateService.currentChannel)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    updateService.currentChannel.name.toUpperCase(),
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: _getChannelColor(updateService.currentChannel),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 自动检查间隔
              _buildSettingRow(
                context,
                title: t.updateIntervalTitle,
                subtitle: t.updateIntervalSubtitle,
                trailing: ComboBox<UpdateCheckInterval>(
                  value: updateService.checkInterval,
                  items: UpdateCheckInterval.values.map((interval) {
                    return ComboBoxItem(
                      value: interval,
                      child: Text(_getCheckIntervalLabel(interval, t)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      updateService.setCheckInterval(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              // 允许 Alpha 更新
              _buildSettingRow(
                context,
                title: t.updateAllowAlphaTitle,
                subtitle: t.updateAllowAlphaSubtitle,
                trailing: ToggleSwitch(
                  checked: updateService.allowAlpha,
                  onChanged: (value) => updateService.setAllowAlpha(value),
                ),
              ),
              if (updateService.lastCheckTime != null) ...[
                const SizedBox(height: 16),
                Text(
                  t.updateLastCheckLabel(
                      _formatDateTime(updateService.lastCheckTime!, t)),
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FluentTheme.of(context).typography.body?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: FluentTheme.of(context).typography.caption?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Color _getChannelColor(VersionChannel channel) {
    switch (channel) {
      case VersionChannel.alpha:
        return AppTheme.statusError;
      case VersionChannel.release:
        return AppTheme.statusSuccess;
    }
  }

  String _formatDateTime(DateTime dateTime, AppLocalizations t) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return t.updateTimeJustNow;
    } else if (diff.inHours < 1) {
      return t.updateTimeMinutesAgo(diff.inMinutes);
    } else if (diff.inDays < 1) {
      return t.updateTimeHoursAgo(diff.inHours);
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildUpdateAvailable(
    BuildContext context,
    UpdateService updateService,
    AppLocalizations t,
  ) {
    final release =
        updateService.availableUpdate ?? updateService.latestRelease!;
    final urgency = release.urgency;
    final isAlphaTarget = release.versionInfo.channel == VersionChannel.alpha;
    final urgencyColor =
        isAlphaTarget ? AppTheme.statusError : _getUrgencyColor(urgency);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: urgencyColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: urgencyColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getUrgencyIcon(urgency),
                color: urgencyColor,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.updateAvailableTitle,
                            style: FluentTheme.of(context)
                                .typography
                                .bodyStrong
                                ?.copyWith(
                                  color: urgencyColor,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isAlphaTarget
                                ? (_isChineseLocale(context)
                                    ? '内测更新'
                                    : 'Alpha Update')
                                : _getUrgencyLabel(context, urgency),
                            style: FluentTheme.of(context)
                                .typography
                                .caption
                                ?.copyWith(
                                  color: urgencyColor,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v${updateService.currentVersion} → v${release.version}',
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getUrgencyHint(context, release),
                      style:
                          FluentTheme.of(context).typography.caption?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (urgency == UpdateUrgency.forced &&
            release.minSupportedVersion != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.statusError.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: AppTheme.statusError.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  FluentIcons.warning,
                  size: 16,
                  color: AppTheme.statusError,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isChineseLocale(context)
                        ? '最低支持版本：v${release.minSupportedVersion!.versionString}，请立即更新。'
                        : 'Minimum supported version: v${release.minSupportedVersion!.versionString}. Please update immediately.',
                    style: FluentTheme.of(context).typography.caption?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          t.updateAvailableChangelogTitle,
          style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: double.infinity,
              height: 150,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgLayer1.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppTheme.borderSubtle.withValues(alpha: 0.4),
                ),
              ),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildMarkdownContent(
                      context, updateService.getLatestChangelog()),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Button(
          onPressed: () => _showChangelogDialog(
            context,
            t.updateChangelogDialogTitle(release.version),
            updateService.getLatestChangelog(),
          ),
          child: Text(t.updateChangelogViewFullButton),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
