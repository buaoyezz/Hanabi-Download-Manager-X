import 'dart:async';

import 'app_logger_service.dart';
import 'integrated_download_service.dart';
import 'pipe_listener_service.dart';
import 'popup_progress_service.dart';

class PopupBridgeService {
  PopupBridgeService(IntegratedDownloadService downloadService)
      : _downloadService = downloadService,
        _popupProgressService = PopupProgressService(downloadService);

  final IntegratedDownloadService _downloadService;
  final PopupProgressService _popupProgressService;
  final PipeListenerService _pipeListenerService = PipeListenerService();
  final AppLoggerService _logger = AppLoggerService();

  bool _started = false;

  Future<void> start() async {
    if (_started) return;

    await _popupProgressService.start();
    _pipeListenerService.onDownloadRequest = (request) {
      unawaited(_handleDownloadRequest(request));
    };
    await _pipeListenerService.start();

    _started = true;
    _logger.info('PopupBridge', 'Popup bridge started');
  }

  Future<void> stop() async {
    if (!_started) return;

    _pipeListenerService.onDownloadRequest = null;
    await _pipeListenerService.stop();
    await _popupProgressService.stop();

    _started = false;
    _logger.info('PopupBridge', 'Popup bridge stopped');
  }

  Future<void> _handleDownloadRequest(PopupDownloadRequest request) async {
    try {
      _logger.info(
        'PopupBridge',
        'Received popup download request: ${request.filename}',
      );

      final saveDir = request.savePath.trim();
      final taskId = await _downloadService.addTask(
        request.url,
        request.filename,
        referer: request.referer,
        userAgent: request.userAgent,
        cookies: request.cookies,
        headers: request.headers,
        saveDir: saveDir.isEmpty ? null : saveDir,
      );

      if (taskId == null) {
        _logger.error(
          'PopupBridge',
          'Failed to create popup download task: '
              '${_downloadService.lastAddTaskError ?? request.filename}',
        );
        return;
      }

      _popupProgressService.setActiveTask(taskId);
      _logger.info('PopupBridge', 'Popup download task ready: $taskId');
    } catch (e) {
      _logger.error('PopupBridge', 'Popup download request failed: $e');
    }
  }
}
