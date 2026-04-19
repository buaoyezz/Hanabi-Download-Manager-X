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
                CustomIcons.FluentIcons.alert_20,
                size: 18,
                color: AppTheme.accentLight,
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

          return SmoothSingleChildScrollView(
            config: SmoothScrollConfig.fast,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSyncInfo(service),
                const SizedBox(height: 16),
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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color:
                _isHovered ? AppTheme.surfaceCardHover : AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: _isHovered
                  ? levelColor.withValues(alpha: 0.4)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: levelColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        _levelIcon(notice.level),
                        size: 16,
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
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusRound),
                                    border: Border.all(
                                      color: AppTheme.accentPrimary
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(FluentIcons.pin,
                                          size: 10,
                                          color: AppTheme.accentLight),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context)!
                                            .noticePinned,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.accentLight,
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
                                  style: const TextStyle(
                                    fontSize: 15,
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
                                size: 12,
                                color: AppTheme.textTertiary,
                              ),
                            ],
                          ),
                          if (notice.summary != null &&
                              notice.summary!.isNotEmpty) ...[
                            const SizedBox(height: 6),
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(FluentIcons.clock,
                                  size: 11, color: AppTheme.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(
                                    notice.publishedAt ?? notice.createdAt),
                                style: TextStyle(
                                  fontSize: 11,
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
              if (_isExpanded && notice.content != null)
                _buildExpandedContent(notice, levelColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(Notice notice, Color levelColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(72, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            color: AppTheme.borderSubtle.withValues(alpha: 0.5),
            margin: const EdgeInsets.only(bottom: 16),
          ),
          MarkdownBody(
            data: notice.content ?? '',
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
              h2: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              h3: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              a: TextStyle(
                color: AppTheme.accentLight,
                decoration: TextDecoration.underline,
              ),
              listBullet: TextStyle(color: AppTheme.textSecondary),
              code: TextStyle(
                fontSize: 12,
                backgroundColor: AppTheme.bgLayer2,
                color: AppTheme.accentLight,
              ),
            ),
            onTapLink: (text, href, title) {
              if (href != null) {
                widget.onLinkTap(href);
              }
            },
          ),
          if (notice.link != null && notice.link!.url != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => widget.onLinkTap(notice.link!.url!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.open_in_new_tab, size: 14),
                  const SizedBox(width: 8),
                  Text(notice.link?.label ??
                      AppLocalizations.of(context)!.noticeOpenLink),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
