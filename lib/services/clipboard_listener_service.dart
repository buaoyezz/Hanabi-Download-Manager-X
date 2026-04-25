import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../models/download_intent.dart';
import '../screens/widgets/add_download_dialog.dart';
import 'client_config_service.dart';
import 'app_logger_service.dart';
import '../main.dart';

class ClipboardDownloadUrlHeuristics {
  static const Set<String> _knownExts = <String>{
    'zip',
    '7z',
    'rar',
    'tar',
    'gz',
    'bz2',
    'xz',
    'exe',
    'msi',
    'apk',
    'jar',
    'war',
    'ipa',
    'dmg',
    'pkg',
    'deb',
    'rpm',
    'iso',
    'img',
    'bin',
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'mp3',
    'flac',
    'wav',
    'aac',
    'ogg',
    'pdf',
    'epub',
    'mobi',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'json',
    'xml',
  };

  static const Set<String> _downloadMimeHints = <String>{
    'application/octet-stream',
    'application/java-archive',
    'application/java-archive-diff',
    'application/zip',
    'application/x-zip-compressed',
    'application/x-7z-compressed',
    'application/x-rar-compressed',
    'application/x-tar',
    'application/gzip',
    'application/pdf',
    'application/vnd.android.package-archive',
  };

  static const Set<String> _strongQueryKeys = <String>{
    'filename',
    'file_name',
    'attachment',
    'download',
    'attname',
    'response-content-disposition',
    'response-content-type',
  };

  static const Set<String> _pathHintSegments = <String>{
    'download',
    'downloads',
    'attachment',
    'attachments',
    'dl',
  };

  static final RegExp _contentDispositionFilenamePattern = RegExp(
    r'''filename\*?=(?:utf-8''|UTF-8''|"?)([^";]+)''',
    caseSensitive: false,
  );

  static String? extractUrl(String text) {
    final trimmed = text.trim();
    final regex =
        RegExp(r'(https?://[^\s]+|magnet:\?[^\s]+)', caseSensitive: false);
    final matches = regex.allMatches(trimmed).toList();
    if (matches.length != 1) {
      return null;
    }

    final raw = matches.first.group(0);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final normalized = normalizeExtractedUrl(raw);
    if (!_isStandaloneCandidateText(trimmed, raw, normalized)) {
      return null;
    }

    return normalized;
  }

  static String normalizeExtractedUrl(String raw) {
    var url = raw.trim();
    if (url.startsWith('<') && url.endsWith('>') && url.length > 2) {
      url = url.substring(1, url.length - 1);
    }

    while (url.isNotEmpty &&
        const {'.', ',', ';', ':', ')', ']', '}', '>', '"', '\''}
            .contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }

    return url;
  }

  static String signatureFor(String url) {
    final normalized = normalizeExtractedUrl(url).trim();
    final intent = DownloadIntent.parse(normalized);
    if (intent.isHttp) {
      return intent.normalizedValue;
    }
    if (intent.isMagnet) {
      return intent.normalizedValue.toLowerCase();
    }
    return normalized.toLowerCase();
  }

  static bool looksLikeDownloadUrl(String url) {
    final intent = DownloadIntent.parse(url);
    if (intent.isMagnet) {
      return true;
    }
    if (!intent.isHttp) {
      return false;
    }

    final uri = intent.uri;
    if (uri == null) return false;
    if (uri.host.isEmpty || !uri.host.contains('.')) return false;

    final lastSegment =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last.toLowerCase() : '';
    final ext = _extractKnownExtension(lastSegment);
    if (ext != null) return true;

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment.toLowerCase())
        .toList();
    final hasPathHint =
        segments.any((segment) => _pathHintSegments.contains(segment));

    if (uri.queryParameters.isNotEmpty) {
      for (final entry in uri.queryParameters.entries) {
        final key = entry.key.toLowerCase();
        final value = entry.value.toLowerCase();
        final valueExt = _extractKnownExtension(value);

        if (valueExt != null) return true;
        if (_valueCarriesDownloadMetadata(entry.value)) return true;
        if (_strongQueryKeys.contains(key)) {
          if (value.contains('attachment') ||
              value.contains('download') ||
              _looksLikeDownloadMime(value) ||
              value.isEmpty) {
            return true;
          }
          if (_extractKnownExtension(value) != null) {
            return true;
          }
        }
      }
    }

    if (hasPathHint && uri.queryParameters.isNotEmpty) {
      final queryValues = uri.queryParameters.values
          .map((value) => value.toLowerCase())
          .join(' ');
      if (queryValues.contains('download') ||
          queryValues.contains('attachment')) {
        return true;
      }
    }

    return false;
  }

  static bool _isStandaloneCandidateText(
    String originalText,
    String rawMatch,
    String normalizedUrl,
  ) {
    final trimmed = originalText.trim();
    if (trimmed == rawMatch || trimmed == normalizedUrl) {
      return true;
    }

    final wrappedVariants = <String>{
      '<$rawMatch>',
      '<$normalizedUrl>',
      '"$rawMatch"',
      '"$normalizedUrl"',
      "'$rawMatch'",
      "'$normalizedUrl'",
      '($rawMatch)',
      '($normalizedUrl)',
      '[$rawMatch]',
      '[$normalizedUrl]',
    };

    if (wrappedVariants.contains(trimmed)) {
      return true;
    }

    final lines = trimmed
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length == 1) {
      final singleLine = lines.first;
      return singleLine == rawMatch ||
          singleLine == normalizedUrl ||
          wrappedVariants.contains(singleLine);
    }

    return false;
  }

  static String? _extractKnownExtension(String value) {
    if (!value.contains('.')) return null;
    final ext = value.split('.').last;
    if (_knownExts.contains(ext)) {
      return ext;
    }
    return null;
  }

  static bool _valueCarriesDownloadMetadata(String value) {
    final lower = value.toLowerCase();

    if (_looksLikeDownloadMime(lower)) {
      return true;
    }

    final filename = _extractFilenameFromMetadataValue(value);
    if (filename != null &&
        _extractKnownExtension(filename.toLowerCase()) != null) {
      return true;
    }

    if (lower.contains('attachment;') && lower.contains('filename=')) {
      return true;
    }

    return false;
  }

  static String? _extractFilenameFromMetadataValue(String value) {
    final match = _contentDispositionFilenamePattern.firstMatch(value);
    final filename = match?.group(1)?.trim();
    if (filename == null || filename.isEmpty) {
      return null;
    }
    return Uri.decodeComponent(filename);
  }

  static bool _looksLikeDownloadMime(String value) {
    if (_downloadMimeHints.contains(value)) {
      return true;
    }

    return value.startsWith('audio/') || value.startsWith('video/');
  }
}

class ClipboardListenerService {
  ClipboardListenerService(this.context);

  static ClipboardListenerService? activeInstance;

  final BuildContext context;
  final _logger = AppLoggerService();

  Timer? _pollTimer;
  bool _isShowing = false;
  bool _isChecking = false;
  bool _isMutedForSession = false;
  String? _lastObservedClipboardText;
  DateTime? _globalDismissCooldownUntil;
  final Map<String, DateTime> _dismissedCandidateCooldowns = {};

  static const _pollInterval = Duration(milliseconds: 900);
  static const _dismissCooldown = Duration(minutes: 30);
  static const _globalDismissCooldown = Duration(minutes: 5);
  static const _textPreviewLimit = 96;
  static const _urlPreviewLimit = 180;

  void start() {
    _pollTimer?.cancel();
    _isChecking = false;
    _isShowing = false;
    activeInstance = this;
    _primeClipboardSnapshot();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkClipboard());
    _logger.info('Clipboard', 'Clipboard listener started');
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isShowing = false;
    _isChecking = false;
    if (identical(activeInstance, this)) {
      activeInstance = null;
    }
    _logger.info('Clipboard', 'Clipboard listener stopped');
  }

  void muteForSession() {
    _isMutedForSession = true;
    _logger.info('Clipboard', 'Clipboard listener muted for current session');
  }

  Future<void> promptFromCurrentClipboard() async {
    _logger.info(
      'Clipboard',
      'Manual clipboard re-check requested from current clipboard contents',
    );
    await _checkClipboard(force: true, ignoreNavigatorState: true);
  }

  Future<void> _primeClipboardSnapshot() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      _lastObservedClipboardText = data?.text?.trim();
    } catch (_) {
      _lastObservedClipboardText = null;
    }
  }

  Future<void> _checkClipboard({
    bool force = false,
    bool ignoreNavigatorState = false,
  }) async {
    if (!context.mounted) return;
    if (_isShowing || _isChecking) return;
    _isChecking = true;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!context.mounted) return;

      final rawText = data?.text?.trim();
      if (rawText == null || rawText.isEmpty) {
        if (_lastObservedClipboardText == '') {
          return;
        }
        _lastObservedClipboardText = '';
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'empty_clipboard',
          force: force,
        );
        return;
      }
      if (!force && _lastObservedClipboardText == rawText) {
        return;
      }
      _lastObservedClipboardText = rawText;

      final url = ClipboardDownloadUrlHeuristics.extractUrl(rawText);
      final looksLikeDownload = url != null &&
          url.isNotEmpty &&
          ClipboardDownloadUrlHeuristics.looksLikeDownloadUrl(url);

      _logClipboardDecision(
        stage: 'observed',
        reason: 'clipboard_changed',
        force: force,
        rawText: rawText,
        url: url,
        looksLikeDownload: looksLikeDownload,
      );

      final config = Provider.of<ClientConfigService>(context, listen: false);
      if (!config.getEnableClipboardListener()) {
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'listener_disabled',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: looksLikeDownload,
        );
        return;
      }
      if (_isMutedForSession) {
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'muted_for_session',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: looksLikeDownload,
        );
        return;
      }

      if (!appWindow.isVisible) {
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'window_hidden',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: looksLikeDownload,
        );
        return;
      }
      final navigator = navigatorKey.currentState;
      if (!ignoreNavigatorState && navigator != null && navigator.canPop()) {
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'modal_already_open',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: looksLikeDownload,
        );
        return;
      }

      if (url == null || url.isEmpty) {
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'no_standalone_url',
          force: force,
          rawText: rawText,
        );
        return;
      }
      if (!looksLikeDownload) {
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'not_download_like',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: false,
        );
        return;
      }

      _cleanupExpiredCooldowns();
      if (_globalDismissCooldownUntil != null &&
          _globalDismissCooldownUntil!.isAfter(DateTime.now())) {
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'global_cooldown',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: true,
          extra:
              'suppressedUntil=${_globalDismissCooldownUntil!.toIso8601String()}',
        );
        return;
      }

      final signature = ClipboardDownloadUrlHeuristics.signatureFor(url);
      final suppressedUntil = _dismissedCandidateCooldowns[signature];
      if (suppressedUntil != null && suppressedUntil.isAfter(DateTime.now())) {
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'url_cooldown',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: true,
          extra: 'suppressedUntil=${suppressedUntil.toIso8601String()}',
        );
        return;
      }

      final navContext = navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) {
        _logClipboardDecision(
          stage: 'skipped',
          reason: 'navigator_context_unavailable',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: true,
        );
        return;
      }

      _logClipboardDecision(
        stage: 'opened',
        reason: 'show_dialog',
        force: force,
        rawText: rawText,
        url: url,
        looksLikeDownload: true,
      );

      _isShowing = true;
      final accepted = await showDialog<bool>(
        context: navContext,
        builder: (context) => AddDownloadDialog(
          initialUrl: url,
          onMuteClipboardForSession: muteForSession,
        ),
      );
      if (accepted != true) {
        _globalDismissCooldownUntil =
            DateTime.now().add(_globalDismissCooldown);
        _dismissedCandidateCooldowns[signature] =
            DateTime.now().add(_dismissCooldown);
        _logClipboardDecision(
          stage: 'dismissed',
          reason: 'dialog_closed_without_accept',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: true,
          extra:
              'globalCooldownUntil=${_globalDismissCooldownUntil!.toIso8601String()}',
        );
      } else {
        _logClipboardDecision(
          stage: 'accepted',
          reason: 'dialog_confirmed',
          force: force,
          rawText: rawText,
          url: url,
          looksLikeDownload: true,
        );
      }
    } catch (e) {
      _logger.warning('Clipboard', 'Failed to read clipboard: $e');
    } finally {
      _isShowing = false;
      _isChecking = false;
    }
  }

  void _cleanupExpiredCooldowns() {
    final now = DateTime.now();
    if (_globalDismissCooldownUntil != null &&
        !_globalDismissCooldownUntil!.isAfter(now)) {
      _globalDismissCooldownUntil = null;
    }
    _dismissedCandidateCooldowns.removeWhere(
      (_, expiresAt) => !expiresAt.isAfter(now),
    );
  }

  void _logClipboardDecision({
    required String stage,
    required String reason,
    required bool force,
    String? rawText,
    String? url,
    bool? looksLikeDownload,
    String? extra,
  }) {
    final parts = <String>[
      'stage=$stage',
      'reason=$reason',
      'force=$force',
    ];

    if (rawText != null) {
      parts.add('text="${_preview(rawText, _textPreviewLimit)}"');
    }
    if (url != null && url.isNotEmpty) {
      parts.add('url="${_preview(url, _urlPreviewLimit)}"');
    }
    if (looksLikeDownload != null) {
      parts.add('downloadLike=$looksLikeDownload');
    }
    if (extra != null && extra.isNotEmpty) {
      parts.add(extra);
    }

    _logger.info('Clipboard', parts.join(', '));
  }

  String _preview(String value, int maxLength) {
    final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= maxLength) {
      return singleLine;
    }
    return '${singleLine.substring(0, maxLength)}...';
  }
}
