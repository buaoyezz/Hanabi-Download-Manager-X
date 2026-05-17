import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/notice_model.dart';
import '../../services/notice_service.dart';
import '../../services/performance_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/fluent_icons.dart' as CustomIcons;
import '../../widgets/animated_notifications.dart';
import '../../widgets/smooth_scroll_wrapper.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<NoticeService>();
      if (service.notices.isEmpty) {
        service.fetchNotices();
      }
    });
  }

  AppLocalizations get t => AppLocalizations.of(context)!;

  Future<void> _launchUrl(String url) async {
    try {
      await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary
                    .withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                CustomIcons.FluentIcons.getIcon('megaphone_loud_20'),
                size: 20,
                color: isDark ? AppTheme.accentLight : AppTheme.accentPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                t.noticePageTitle,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
            return _buildEmptyState(service);
          }

          return SmoothSingleChildScrollView(
            config: SmoothScrollConfig.fast,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSyncInfo(service),
                const SizedBox(height: 20),
                ...notices.map((notice) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _NoticeCard(
                        notice: notice,
                        onLinkTap: _launchUrl,
                      ),
                    )),
              ],
            ),
          );
        },
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
        Icon(FluentIcons.history, size: 12, color: AppTheme.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t.noticeLastSynced(timeAgo),
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Button(
          onPressed: service.isLoading
              ? null
              : () => service.fetchNotices(force: true),
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              service.isLoading
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : Icon(CustomIcons.FluentIcons.arrow_sync_20,
                      size: 13, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                t.noticeRefresh,
                style: TextStyle(
                  fontSize: 12,
                  color: service.isLoading
                      ? AppTheme.textTertiary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(NoticeService service) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.bgLayer2,
              shape: BoxShape.circle,
            ),
            child: Icon(CustomIcons.FluentIcons.getIcon('alert_off_20'),
                size: 48, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 24),
          Text(
            t.noticeEmpty,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            t.noticeLastSynced(t.noticeJustNow), // Placeholder for aesthetic
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: service.isLoading
                ? null
                : () => service.fetchNotices(force: true),
            child: service.isLoading
                ? const SizedBox(
                    width: 14, height: 14, child: ProgressRing(strokeWidth: 2))
                : Text(t.noticeRefresh),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(NoticeService service) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.statusError.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(FluentIcons.error_badge,
                size: 48, color: AppTheme.statusError),
          ),
          const SizedBox(height: 24),
          Text(
            t.noticeLoadError,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Text(
              service.error ?? '',
              style: TextStyle(fontSize: 13, color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: service.isLoading
                ? null
                : () => service.fetchNotices(force: true),
            child: service.isLoading
                ? const SizedBox(
                    width: 14, height: 14, child: ProgressRing(strokeWidth: 2))
                : Text(t.noticeRetry),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatefulWidget {
  final Notice notice;
  final Future<void> Function(String url) onLinkTap;

  const _NoticeCard({required this.notice, required this.onLinkTap});

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
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
        return CustomIcons.FluentIcons.getIcon('megaphone_loud_20');
      case NoticeLevel.success:
        return CustomIcons.FluentIcons.checkmark_circle_20;
      case NoticeLevel.warning:
        return CustomIcons.FluentIcons.warning_20;
      case NoticeLevel.critical:
        return CustomIcons.FluentIcons.getIcon('important_20');
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
    final summary = notice.summary?.trim();
    final hasSummary = summary != null && summary.isNotEmpty;
    final hasContent = notice.content?.trim().isNotEmpty ?? false;
    final hasLink = notice.link?.url?.trim().isNotEmpty ?? false;
    final hasDetails = hasContent || hasLink;
    final borderColor = _isHovered
        ? levelColor.withValues(alpha: isDark ? 0.42 : 0.34)
        : AppTheme.borderSubtle.withValues(alpha: isDark ? 0.7 : 0.9);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: hasDetails ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: hasDetails
            ? () => setState(() => _isExpanded = !_isExpanded)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color:
                _isHovered ? AppTheme.surfaceCardHover : AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: borderColor),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 3,
                    color: levelColor.withValues(
                      alpha: _isHovered || notice.pinned ? 0.9 : 0.55,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NoticeSignalIcon(
                        icon: _levelIcon(notice.level),
                        color: levelColor,
                        pinned: notice.pinned,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    notice.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                      height: 1.32,
                                    ),
                                    maxLines: _isExpanded ? null : 2,
                                    overflow: _isExpanded
                                        ? null
                                        : TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasDetails) ...[
                                  const SizedBox(width: 12),
                                  _NoticeExpandIndicator(
                                    expanded: _isExpanded,
                                    hovered: _isHovered,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (notice.pinned)
                                  _NoticePinnedBadge(
                                    color: isDark
                                        ? AppTheme.accentLight
                                        : AppTheme.accentPrimary,
                                    label: AppLocalizations.of(context)!
                                        .noticePinned,
                                  ),
                                _NoticeMetaItem(
                                  icon: CustomIcons.FluentIcons.getIcon(
                                      'calendar_clock_20'),
                                  text: _formatDate(
                                      notice.publishedAt ?? notice.createdAt),
                                ),
                              ],
                            ),
                            if (hasSummary) ...[
                              const SizedBox(height: 12),
                              Text(
                                summary,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  height: 1.48,
                                ),
                                maxLines: _isExpanded ? null : 2,
                                overflow:
                                    _isExpanded ? null : TextOverflow.ellipsis,
                              ),
                            ],
                            AnimatedSize(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topCenter,
                              child: hasDetails && _isExpanded
                                  ? _buildExpandedContent(notice)
                                  : const SizedBox(width: double.infinity),
                            ),
                          ],
                        ),
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
  }

  Widget _buildExpandedContent(Notice notice) {
    final isDark = AppTheme.isDarkContext(context);
    final content = notice.content?.trim();
    final hasContent = content != null && content.isNotEmpty;
    final linkUrl = notice.link?.url?.trim();
    final hasLink = linkUrl != null && linkUrl.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: AppTheme.borderSubtle.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(bottom: 16),
          ),
          if (hasContent)
            MarkdownBody(
              data: content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.62,
                ),
                h2: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  height: 1.45,
                ),
                h3: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  height: 1.45,
                ),
                a: TextStyle(
                  color: isDark ? AppTheme.accentLight : AppTheme.accentPrimary,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
                listBullet:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                code: TextStyle(
                  fontSize: 12,
                  backgroundColor: isDark
                      ? const Color(0xFF2D2D2D)
                      : const Color(0xFFF3F3F3),
                  color: isDark ? AppTheme.accentLight : AppTheme.accentPrimary,
                ),
                codeblockDecoration: BoxDecoration(
                  color: AppTheme.bgLayer2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
              ),
              onTapLink: (text, href, title) {
                if (href != null) {
                  widget.onLinkTap(href);
                }
              },
            ),
          if (hasLink) ...[
            SizedBox(height: hasContent ? 20 : 0),
            Button(
              onPressed: () => widget.onLinkTap(linkUrl),
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CustomIcons.FluentIcons.getIcon('open_20'),
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    notice.link?.label ??
                        AppLocalizations.of(context)!.noticeOpenLink,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoticeSignalIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool pinned;

  const _NoticeSignalIcon({
    required this.icon,
    required this.color,
    required this.pinned,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkContext(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
                color: color.withValues(alpha: isDark ? 0.22 : 0.18)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        if (pinned)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.bgLayer2 : AppTheme.bgLayer1,
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Icon(
                CustomIcons.FluentIcons.getIcon('pin_12'),
                size: 10,
                color: isDark ? AppTheme.accentLight : AppTheme.accentPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

class _NoticePinnedBadge extends StatelessWidget {
  final Color color;
  final String label;

  const _NoticePinnedBadge({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CustomIcons.FluentIcons.getIcon('pin_12'),
              size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeMetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoticeMetaItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textTertiary),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiary,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _NoticeExpandIndicator extends StatelessWidget {
  final bool expanded;
  final bool hovered;

  const _NoticeExpandIndicator({
    required this.expanded,
    required this.hovered,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0.5 : 0.0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: hovered
              ? AppTheme.bgLayer2.withValues(alpha: 0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(
          CustomIcons.FluentIcons.chevron_down_20,
          size: 16,
          color: hovered ? AppTheme.textSecondary : AppTheme.textTertiary,
        ),
      ),
    );
  }
}
