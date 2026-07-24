import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../models/notice_model.dart';
import '../../services/client_config_service.dart';
import '../../services/notice_service.dart';
import '../../services/performance_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;
import '../../widgets/animated_notifications.dart';
import '../../widgets/smooth_scroll_wrapper.dart';
import '../../widgets/interactive_animations.dart';

String _normalizeNoticeMarkdown(String source) {
  return source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAllMapped(
        RegExp(r'(\*\*[^*\n]*?)\s*[:：]\s+\*\*\s+\*\s+'),
        (match) => '${match.group(1)}：** ',
      );
}

MarkdownStyleSheet _noticeMarkdownStyleSheet(
  BuildContext context, {
  required bool compact,
}) {
  final isDark = AppTheme.isDarkContext(context);
  final bodyColor = compact ? AppTheme.textSecondary : AppTheme.textPrimary;
  final secondaryColor =
      compact ? AppTheme.textTertiary : AppTheme.textSecondary;
  final accentColor = isDark ? AppTheme.accentLight : AppTheme.accentPrimary;
  final baseTextStyle = FluentTheme.of(context).typography.body?.copyWith(
        fontSize: compact ? 13 : 14,
        height: compact ? 1.55 : 1.65,
        color: bodyColor,
      );

  return MarkdownStyleSheet(
    p: baseTextStyle,
    pPadding: EdgeInsets.only(bottom: compact ? 8 : 10),
    strong: baseTextStyle?.copyWith(
      color: AppTheme.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    em: baseTextStyle?.copyWith(
      color: secondaryColor,
      fontStyle: FontStyle.italic,
    ),
    h1: FluentTheme.of(context).typography.title?.copyWith(
          fontSize: compact ? 20 : 23,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          height: 1.25,
        ),
    h1Padding: const EdgeInsets.only(bottom: 14),
    h2: FluentTheme.of(context).typography.subtitle?.copyWith(
          fontSize: compact ? 18 : 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          height: 1.3,
        ),
    h2Padding: const EdgeInsets.only(top: 4, bottom: 12),
    h3: FluentTheme.of(context).typography.bodyLarge?.copyWith(
          fontSize: compact ? 15 : 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
          height: 1.35,
        ),
    h3Padding: const EdgeInsets.only(top: 8, bottom: 8),
    a: baseTextStyle?.copyWith(
      color: accentColor,
      decoration: TextDecoration.underline,
      decorationColor: accentColor.withValues(alpha: 0.65),
    ),
    listIndent: compact ? 22 : 26,
    listBullet: baseTextStyle?.copyWith(
      color: accentColor,
      fontWeight: FontWeight.w700,
    ),
    listBulletPadding: const EdgeInsets.only(right: 8),
    blockSpacing: compact ? 8 : 10,
    blockquote: baseTextStyle?.copyWith(
      color: secondaryColor,
      height: compact ? 1.55 : 1.65,
    ),
    blockquotePadding: EdgeInsets.fromLTRB(
      compact ? 12 : 14,
      compact ? 8 : 10,
      compact ? 12 : 14,
      compact ? 8 : 10,
    ),
    blockquoteDecoration: BoxDecoration(
      color: AppTheme.bgLayer2.withValues(alpha: isDark ? 0.34 : 0.58),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      border: Border(
        left: BorderSide(
          color: accentColor.withValues(alpha: 0.9),
          width: 3,
        ),
      ),
    ),
    code: baseTextStyle?.copyWith(
      fontSize: compact ? 12 : 13,
      fontFamily: 'Consolas',
      backgroundColor: AppTheme.bgLayer2.withValues(alpha: 0.82),
      color: accentColor,
    ),
    codeblockPadding: const EdgeInsets.all(12),
    codeblockDecoration: BoxDecoration(
      color: AppTheme.bgLayer2.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      border: Border.all(
        color: AppTheme.borderSubtle.withValues(alpha: 0.6),
      ),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: AppTheme.borderSubtle.withValues(alpha: 0.62),
        ),
      ),
    ),
  );
}

Widget _buildNoticeMarkdown(
  BuildContext context, {
  required String content,
  required bool compact,
  required Future<void> Function(String url) onLinkTap,
}) {
  return material.Material(
    color: material.Colors.transparent,
    child: MarkdownBody(
      data: _normalizeNoticeMarkdown(content),
      selectable: true,
      styleSheet: _noticeMarkdownStyleSheet(context, compact: compact),
      onTapLink: (text, href, title) {
        if (href != null) {
          onLinkTap(href);
        }
      },
    ),
  );
}

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  Notice? _selectedNotice;
  bool _useSplitView = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<NoticeService>();
      if (service.notices.isEmpty) {
        service.fetchNotices();
      }
      if (mounted) {
        setState(() {
          _useSplitView =
              context.read<ClientConfigService>().getNoticeUseSplitView();
        });
      }
    });
  }

  AppLocalizations get t => AppLocalizations.of(context)!;

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri == null || !uri.hasScheme) {
        throw ArgumentError('Invalid URL: $url');
      }
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('No application is registered to open: $url');
      }
    } catch (e) {
      if (mounted) {
        NotificationManager.of(context)?.showError(
          t.aboutOpenLinkErrorTitle,
          message: t.aboutOpenLinkErrorMessage(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    PerformanceMonitorService().trackRebuild('NoticePage');
    final isDark = AppTheme.isDarkContext(context);

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
                    AppTheme.accentPrimary
                        .withValues(alpha: isDark ? 0.2 : 0.14),
                    AppTheme.accentPrimary
                        .withValues(alpha: isDark ? 0.1 : 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppTheme.accentPrimary
                      .withValues(alpha: isDark ? 0.3 : 0.18),
                ),
              ),
              child: Icon(
                CustomIcons.FluentIcons.alert_20,
                size: 18,
                color: isDark ? AppTheme.accentLight : AppTheme.accentPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                t.noticePageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: Icon(
                _useSplitView ? FluentIcons.list : FluentIcons.stop_solid,
              ),
              label: Text(_useSplitView ? '切换到卡片视图' : '切换到分栏视图'),
              onPressed: () {
                setState(() {
                  _useSplitView = !_useSplitView;
                });
                context
                    .read<ClientConfigService>()
                    .setNoticeUseSplitView(_useSplitView);
              },
            ),
          ],
        ),
      ),
      content: Consumer<NoticeService>(
        builder: (context, service, _) {
          if (service.isLoading && service.notices.isEmpty) {
            return const Center(child: ProgressRing());
          }

          if (service.error != null && service.notices.isEmpty) {
            return _buildErrorState(service);
          }

          final notices = service.activeNotices;

          if (notices.isEmpty) {
            return _buildEmptyState();
          }

          if (_useSplitView) {
            return _buildSplitViewPane(notices, service);
          } else {
            return _buildFlowCardsPane(notices, service);
          }
        },
      ),
    );
  }

  Widget _buildSplitViewPane(List<Notice> notices, NoticeService service) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 24, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧主列表 (Master)
          Expanded(
            flex: _selectedNotice == null ? 1 : 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSyncInfo(service),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground(
                          darkAlpha: 0.4, lightAlpha: 0.6),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: AppTheme.borderSubtle.withValues(alpha: 0.5),
                      ),
                    ),
                    child: SmoothListView.builder(
                      config: SmoothScrollConfig.fast,
                      padding: const EdgeInsets.all(8),
                      itemCount: notices.length,
                      itemBuilder: (context, index) {
                        final notice = notices[index];
                        final isSelected = _selectedNotice?.id == notice.id;
                        return StaggeredEntrance(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _NoticeListTile(
                              notice: notice,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() => _selectedNotice = notice);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedNotice != null) ...[
            const SizedBox(width: 24),
            // 右侧内容区 (Detail)
            Expanded(
              flex: 7,
              child: Container(
                margin: const EdgeInsets.only(top: 26),
                decoration: BoxDecoration(
                  color:
                      AppTheme.cardBackground(darkAlpha: 0.6, lightAlpha: 0.8),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(
                    color: AppTheme.borderSubtle.withValues(alpha: 0.8),
                  ),
                  boxShadow: AppTheme.shadowSm,
                ),
                clipBehavior: Clip.antiAlias,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.02, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        )),
                        child: child,
                      ),
                    );
                  },
                  child: _NoticeDetailPane(
                    key: ValueKey(_selectedNotice!.id),
                    notice: _selectedNotice!,
                    onLinkTap: _launchUrl,
                    onClose: () => setState(() => _selectedNotice = null),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlowCardsPane(List<Notice> notices, NoticeService service) {
    return SmoothSingleChildScrollView(
      config: SmoothScrollConfig.fast,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSyncInfo(service),
          const SizedBox(height: 16),
          ...notices.asMap().entries.map((entry) {
            final index = entry.key;
            final notice = entry.value;
            return StaggeredEntrance(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ModernNoticeCard(
                  notice: notice,
                  onLinkTap: _launchUrl,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSyncInfo(NoticeService service) {
    if (service.lastFetchTime == null) return const SizedBox.shrink();

    final elapsed = DateTime.now().difference(service.lastFetchTime!);
    String timeAgo;
    if (elapsed.inMinutes < 1) {
      timeAgo = t.noticeJustNow;
    } else if (elapsed.inMinutes < 60) {
      timeAgo = t.noticeMinutesAgo(elapsed.inMinutes);
    } else if (elapsed.inHours < 24) {
      timeAgo = t.noticeHoursAgo(elapsed.inHours);
    } else {
      timeAgo = t.noticeDaysAgo(elapsed.inDays);
    }

    return Row(
      children: [
        Icon(FluentIcons.sync, size: 12, color: AppTheme.textTertiary),
        const SizedBox(width: 6),
        Text(
          t.noticeLastSynced(timeAgo),
          style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
        ),
        const Spacer(),
        if (service.isLoading)
          const SizedBox(
            width: 14,
            height: 14,
            child: ProgressRing(strokeWidth: 2),
          ),
        if (!service.isLoading)
          IconButton(
            icon: Icon(FluentIcons.refresh,
                size: 14, color: AppTheme.textTertiary),
            onPressed: () => service.fetchNotices(force: true),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: StaggeredEntrance(
        index: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CustomIcons.FluentIcons.getIcon('alert_off_20'),
              size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            t.noticeEmpty,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () =>
                context.read<NoticeService>().fetchNotices(force: true),
            child: Text(t.noticeRefresh),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildErrorState(NoticeService service) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.error, size: 48, color: AppTheme.statusError),
          const SizedBox(height: 16),
          Text(
            t.noticeLoadError,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            service.error ?? '',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => service.fetchNotices(force: true),
            child: Text(t.noticeRetry),
          ),
        ],
      ),
    );
  }
}

class _NoticeListTile extends StatelessWidget {
  final Notice notice;
  final bool isSelected;
  final VoidCallback onTap;

  const _NoticeListTile({
    required this.notice,
    required this.isSelected,
    required this.onTap,
  });

  Color _levelColor(NoticeLevel level) {
    switch (level) {
      case NoticeLevel.info:
        return AppTheme.statusInfo;
      case NoticeLevel.success:
        return AppTheme.statusSuccess;
      case NoticeLevel.warning:
        return AppTheme.statusWarning;
      case NoticeLevel.critical:
        return AppTheme.statusError;
    }
  }

  IconData _levelIcon(NoticeLevel level) {
    switch (level) {
      case NoticeLevel.info:
        return FluentIcons.info;
      case NoticeLevel.success:
        return FluentIcons.completed;
      case NoticeLevel.warning:
        return FluentIcons.warning;
      case NoticeLevel.critical:
        return FluentIcons.error_badge;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(notice.level);
    final isDark = AppTheme.isDarkContext(context);

    return AnimatedPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentPrimary.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accentPrimary.withValues(alpha: isDark ? 0.4 : 0.2)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: levelColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  _levelIcon(notice.level),
                  size: 14,
                  color: levelColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (notice.pinned) ...[
                          Icon(FluentIcons.pin,
                              size: 10, color: AppTheme.accentPrimary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            notice.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (notice.summary != null && notice.summary!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          notice.summary!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(notice.publishedAt ?? notice.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textTertiary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

class _NoticeDetailPane extends StatelessWidget {
  final Notice notice;
  final Future<void> Function(String url) onLinkTap;
  final VoidCallback? onClose;

  const _NoticeDetailPane({
    super.key,
    required this.notice,
    required this.onLinkTap,
    this.onClose,
  });

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkContext(context);
    final t = AppLocalizations.of(context)!;

    return SmoothSingleChildScrollView(
      config: SmoothScrollConfig.fast,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notice.pinned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPrimary
                              .withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(
                            color: AppTheme.accentPrimary
                                .withValues(alpha: isDark ? 0.4 : 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.pin,
                                size: 10,
                                color: isDark
                                    ? AppTheme.accentLight
                                    : AppTheme.accentPrimary),
                            const SizedBox(width: 6),
                            Text(
                              t.noticePinned,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.accentLight
                                    : AppTheme.accentPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      notice.title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null) ...[
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(FluentIcons.cancel, size: 14),
                  onPressed: onClose,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.clock,
                      size: 12, color: AppTheme.textTertiary),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(notice.publishedAt ?? notice.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
              if (notice.link != null && notice.link!.url != null)
                FilledButton(
                  onPressed: () => onLinkTap(notice.link!.url!),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.globe, size: 14),
                      const SizedBox(width: 8),
                      Text(notice.link?.label ?? t.noticeOpenLink),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 1,
            color: AppTheme.borderSubtle.withValues(alpha: 0.6),
            margin: const EdgeInsets.only(bottom: 24),
          ),
          _buildNoticeMarkdown(
            context,
            content: notice.content ?? '',
            compact: false,
            onLinkTap: onLinkTap,
          ),
        ],
      ),
    );
  }
}

class _ModernNoticeCard extends StatefulWidget {
  final Notice notice;
  final Future<void> Function(String url) onLinkTap;

  const _ModernNoticeCard({required this.notice, required this.onLinkTap});

  @override
  State<_ModernNoticeCard> createState() => _ModernNoticeCardState();
}

class _ModernNoticeCardState extends State<_ModernNoticeCard> {
  bool _isExpanded = false;
  bool _isHovered = false;

  Color _levelColor(NoticeLevel level) {
    switch (level) {
      case NoticeLevel.info:
        return AppTheme.statusInfo;
      case NoticeLevel.success:
        return AppTheme.statusSuccess;
      case NoticeLevel.warning:
        return AppTheme.statusWarning;
      case NoticeLevel.critical:
        return AppTheme.statusError;
    }
  }

  IconData _levelIcon(NoticeLevel level) {
    switch (level) {
      case NoticeLevel.info:
        return FluentIcons.info;
      case NoticeLevel.success:
        return FluentIcons.completed;
      case NoticeLevel.warning:
        return FluentIcons.warning;
      case NoticeLevel.critical:
        return FluentIcons.error_badge;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final levelColor = _levelColor(notice.level);
    final isDark = AppTheme.isDarkContext(context);
    final t = AppLocalizations.of(context)!;

    return AnimatedPressable(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      enableHoverScale: true,
      hoverScale: 1.01,
      pressScale: 0.98,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered
                ? AppTheme.cardBackground(darkAlpha: 0.7, lightAlpha: 0.9)
                : AppTheme.cardBackground(darkAlpha: 0.5, lightAlpha: 0.7),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: _isHovered
                  ? levelColor.withValues(alpha: 0.5)
                  : AppTheme.borderSubtle,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: _isHovered ? AppTheme.shadowSm : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: levelColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        _levelIcon(notice.level),
                        size: 18,
                        color: levelColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (notice.pinned) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentPrimary
                                        .withValues(alpha: isDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusRound),
                                    border: Border.all(
                                      color: AppTheme.accentPrimary.withValues(
                                          alpha: isDark ? 0.4 : 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(FluentIcons.pin,
                                          size: 10,
                                          color: isDark
                                              ? AppTheme.accentLight
                                              : AppTheme.accentPrimary),
                                      const SizedBox(width: 4),
                                      Text(
                                        t.noticePinned,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppTheme.accentLight
                                              : AppTheme.accentPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  notice.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isExpanded
                                    ? FluentIcons.chevron_up
                                    : FluentIcons.chevron_down,
                                size: 14,
                                color: AppTheme.textTertiary,
                              ),
                            ],
                          ),
                          if (notice.summary != null &&
                              notice.summary!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              notice.summary!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                              maxLines: _isExpanded ? null : 2,
                              overflow:
                                  _isExpanded ? null : TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(FluentIcons.clock,
                                  size: 11, color: AppTheme.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(
                                    notice.publishedAt ?? notice.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: notice.content != null
                    ? _buildExpandedContent(notice, isDark, t)
                    : const SizedBox(width: double.infinity, height: 0),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(Notice notice, bool isDark, AppLocalizations t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(76, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            color: AppTheme.borderSubtle.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(bottom: 16),
          ),
          _buildNoticeMarkdown(
            context,
            content: notice.content ?? '',
            compact: true,
            onLinkTap: widget.onLinkTap,
          ),
          if (notice.link != null && notice.link!.url != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => widget.onLinkTap(notice.link!.url!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.globe, size: 14),
                  const SizedBox(width: 8),
                  Text(notice.link?.label ?? t.noticeOpenLink),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
