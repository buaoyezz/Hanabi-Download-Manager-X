import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../screens/widgets/add_download_dialog.dart';
import 'client_config_service.dart';
import 'app_logger_service.dart';
import '../main.dart';

class ClipboardListenerService {
  ClipboardListenerService(this.context);

  final BuildContext context;
  final _logger = AppLoggerService();

  Timer? _pollTimer;
  bool _isShowing = false;
  bool _isChecking = false;
  String? _lastPromptedText;

  static const _pollInterval = Duration(milliseconds: 900);

  void start() {
    _pollTimer?.cancel();
    _isChecking = false;
    _isShowing = false;
    _lastPromptedText = null;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkClipboard());
    _logger.info('Clipboard', 'Clipboard listener started');
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isShowing = false;
    _isChecking = false;
    _logger.info('Clipboard', 'Clipboard listener stopped');
  }

  Future<void> _checkClipboard() async {
    if (!context.mounted) return;
    if (_isShowing || _isChecking) return;
    _isChecking = true;

    try {
      final config = Provider.of<ClientConfigService>(context, listen: false);
      if (!config.getEnableClipboardListener()) return;

      if (!appWindow.isVisible) return;
      final navContext = navigatorKey.currentContext;
      if (navContext == null) return;
      final navigator = navigatorKey.currentState;
      if (navigator != null && navigator.canPop()) return;

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final rawText = data?.text?.trim();
      if (rawText == null || rawText.isEmpty) return;
      if (_lastPromptedText == rawText) return;

      final url = _extractUrl(rawText);
      if (url == null || url.isEmpty) return;
      if (!_looksLikeDownloadUrl(url)) return;

      _isShowing = true;
      await showDialog(
        context: navContext,
        builder: (context) => AddDownloadDialog(initialUrl: url),
      );
      _lastPromptedText = rawText;
    } catch (e) {
      _logger.warning('Clipboard', 'Failed to read clipboard: $e');
    } finally {
      _isShowing = false;
      _isChecking = false;
    }
  }

  String? _extractUrl(String text) {
    final regex = RegExp(r'(https?://[^\s]+|magnet:\?[^\s]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(0);
  }

  bool _looksLikeDownloadUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.startsWith('magnet:?')) return true;

    Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return false;
    }

    if (!(uri.scheme == 'http' || uri.scheme == 'https')) return false;
    if (uri.host.isEmpty || !uri.host.contains('.')) return false;

    final path = uri.path.toLowerCase();
    final lastSegment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.toLowerCase() : '';
    final ext = lastSegment.contains('.') ? lastSegment.split('.').last : '';

    const knownExts = <String>{
      'zip', '7z', 'rar', 'tar', 'gz', 'bz2', 'xz',
      'exe', 'msi', 'apk', 'ipa', 'dmg', 'pkg', 'deb', 'rpm',
      'iso', 'img', 'bin',
      'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
      'mp3', 'flac', 'wav', 'aac', 'ogg',
      'pdf', 'epub', 'mobi',
      'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
      'txt', 'csv', 'json', 'xml',
    };
    if (ext.isNotEmpty && knownExts.contains(ext)) return true;

    const pathHints = <String>[
      '/download', '/downloads', '/file', '/files', '/get', '/dl',
      '/attachment', '/attachments', '/media', '/video', '/audio',
    ];
    for (final hint in pathHints) {
      if (path.contains(hint)) return true;
    }

    if (uri.queryParameters.isNotEmpty) {
      for (final entry in uri.queryParameters.entries) {
        final key = entry.key.toLowerCase();
        final value = entry.value.toLowerCase();
        if (key.contains('filename') || key.contains('file') || key.contains('download') || key.contains('attachment')) {
          return true;
        }
        if (value.contains('.') && knownExts.contains(value.split('.').last)) {
          return true;
        }
        if (value.contains('attachment')) return true;
      }
    }

    return false;
  }
}
