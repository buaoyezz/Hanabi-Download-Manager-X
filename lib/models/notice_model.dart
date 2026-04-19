import 'dart:convert';

enum NoticeLevel { info, success, warning, critical }

enum NoticeStatus { draft, published, archived }

class NoticeLink {
  final String? label;
  final String? url;

  NoticeLink({this.label, this.url});

  factory NoticeLink.fromJson(Map<String, dynamic> json) {
    return NoticeLink(
      label: json['label'] as String?,
      url: json['url'] as String?,
    );
  }
}

class Notice {
  final String id;
  final String title;
  final String? summary;
  final String? content;
  final NoticeLevel level;
  final NoticeStatus status;
  final bool pinned;
  final List<String> audiences;
  final List<String> platforms;
  final List<String> channels;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NoticeLink? link;

  Notice({
    required this.id,
    required this.title,
    this.summary,
    this.content,
    required this.level,
    required this.status,
    this.pinned = false,
    this.audiences = const [],
    this.platforms = const [],
    this.channels = const [],
    this.startsAt,
    this.endsAt,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.link,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      content: json['content'] as String?,
      level: _parseLevel(json['level'] as String?),
      status: _parseStatus(json['status'] as String?),
      pinned: json['pinned'] as bool? ?? false,
      audiences: (json['audiences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      channels: (json['channels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      startsAt: _parseDateTime(json['startsAt']),
      endsAt: _parseDateTime(json['endsAt']),
      publishedAt: _parseDateTime(json['publishedAt']),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
      link: json['link'] != null
          ? NoticeLink.fromJson(json['link'] as Map<String, dynamic>)
          : null,
    );
  }

  static NoticeLevel _parseLevel(String? value) {
    switch (value?.toLowerCase()) {
      case 'success':
        return NoticeLevel.success;
      case 'warning':
        return NoticeLevel.warning;
      case 'critical':
        return NoticeLevel.critical;
      default:
        return NoticeLevel.info;
    }
  }

  static NoticeStatus _parseStatus(String? value) {
    switch (value?.toLowerCase()) {
      case 'draft':
        return NoticeStatus.draft;
      case 'archived':
        return NoticeStatus.archived;
      default:
        return NoticeStatus.published;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool get isActive {
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return status == NoticeStatus.published;
  }
}
