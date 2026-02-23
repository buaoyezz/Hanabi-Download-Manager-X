import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../screens/widgets/add_download_dialog.dart';
import 'client_config_service.dart';
import 'app_logger_service.dart';

class ClipboardListenerService {
  ClipboardListenerService(this.context);

  final BuildContext context;
  final _logger = AppLoggerService();

  Timer? _pollTimer;
  bool _isShowing = false;
  String? _lastUrl;
  DateTime? _lastPromptAt;

  static const _pollInterval = Duration(milliseconds: 900);
  static const _promptCooldown = Duration(seconds: 2);

  void start() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkClipboard());
    _logger.info('Clipboard', 'Clipboard listener started');
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isShowing = false;
    _logger.info('Clipboard', 'Clipboard listener stopped');
  }

  Future<void> _checkClipboard() async {
    if (!context.mounted) return;
    if (_isShowing) return;

    final config = Provider.of<ClientConfigService>(context, listen: false);
    if (!config.getEnableClipboardListener()) return;

    if (!appWindow.isVisible) return;
    if (Navigator.of(context).canPop()) return;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final rawText = data?.text?.trim();
      if (rawText == null || rawText.isEmpty) return;

      final url = _extractUrl(rawText);
      if (url == null || url.isEmpty) return;

      if (_lastUrl == url) return;
      final now = DateTime.now();
      if (_lastPromptAt != null && now.difference(_lastPromptAt!) < _promptCooldown) return;

      _lastUrl = url;
      _lastPromptAt = now;

      _isShowing = true;
      await showDialog(
        context: context,
        builder: (context) => AddDownloadDialog(initialUrl: url),
      );
    } catch (e) {
      _logger.warning('Clipboard', 'Failed to read clipboard: $e');
    } finally {
      _isShowing = false;
    }
  }

  String? _extractUrl(String text) {
    final regex = RegExp(r'(https?://[^\s]+|magnet:\?[^\s]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(0);
  }
}
