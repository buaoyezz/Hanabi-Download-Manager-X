import '../models/download_intent.dart';
import 'app_logger_service.dart';
import 'kernel/kernel_manager.dart';
import 'plugin_lifecycle_service.dart';
import 'plugin_process_runner.dart';

enum DownloadDispatchErrorCode {
  invalidIntent,
  unsupportedIntent,
  handlerUnavailable,
  kernelUnavailable,
  pluginUnavailable,
  pluginFailed,
}

class DownloadDispatchRequest {
  const DownloadDispatchRequest({
    required this.intent,
    required this.fileName,
    this.referer,
    this.userAgent,
    this.cookies,
    this.headers,
    this.saveDir,
    this.startPaused = false,
  });

  final DownloadIntent intent;
  final String fileName;
  final String? referer;
  final String? userAgent;
  final String? cookies;
  final Map<String, dynamic>? headers;
  final String? saveDir;
  final bool startPaused;

  Map<String, dynamic> toPluginJson() => {
        'intent': intent.toJson(),
        'fileName': fileName,
        if (referer != null && referer!.isNotEmpty) 'referer': referer,
        if (userAgent != null && userAgent!.isNotEmpty) 'userAgent': userAgent,
        if (cookies != null && cookies!.isNotEmpty) 'cookies': cookies,
        if (headers != null && headers!.isNotEmpty) 'headers': headers,
        if (saveDir != null && saveDir!.isNotEmpty) 'saveDir': saveDir,
        'startPaused': startPaused,
      };
}

class DownloadDispatchResult {
  const DownloadDispatchResult._({
    required this.accepted,
    required this.handlerId,
    required this.intent,
    this.metadata = const <String, dynamic>{},
    this.taskId,
    this.errorCode,
    this.message,
  });

  final bool accepted;
  final String handlerId;
  final DownloadIntent intent;
  final Map<String, dynamic> metadata;
  final String? taskId;
  final DownloadDispatchErrorCode? errorCode;
  final String? message;

  bool get failed => !accepted;

  factory DownloadDispatchResult.accepted({
    required String handlerId,
    required DownloadIntent intent,
    required String taskId,
    String? message,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) {
    return DownloadDispatchResult._(
      accepted: true,
      handlerId: handlerId,
      intent: intent,
      taskId: taskId,
      message: message,
      metadata: metadata,
    );
  }

  factory DownloadDispatchResult.rejected({
    required String handlerId,
    required DownloadIntent intent,
    required DownloadDispatchErrorCode errorCode,
    required String message,
  }) {
    return DownloadDispatchResult._(
      accepted: false,
      handlerId: handlerId,
      intent: intent,
      errorCode: errorCode,
      message: message,
    );
  }
}

abstract class DownloadIntentHandler {
  String get id;
  bool supports(DownloadIntent intent);
  Future<DownloadDispatchResult> handle(DownloadDispatchRequest request);
}

class BuiltinHttpDownloadHandler implements DownloadIntentHandler {
  BuiltinHttpDownloadHandler({
    required KernelManager kernelManager,
    AppLoggerService? logger,
  })  : _kernelManager = kernelManager,
        _logger = logger ?? AppLoggerService();

  final KernelManager _kernelManager;
  final AppLoggerService _logger;

  @override
  String get id => 'builtin-http';

  @override
  bool supports(DownloadIntent intent) =>
      intent.type == DownloadIntentType.http;

  @override
  Future<DownloadDispatchResult> handle(DownloadDispatchRequest request) async {
    if (!_kernelManager.isRunning) {
      return DownloadDispatchResult.rejected(
        handlerId: id,
        intent: request.intent,
        errorCode: DownloadDispatchErrorCode.kernelUnavailable,
        message: 'Kernel is not running',
      );
    }

    _logger.info(
      'App',
      'Dispatching HTTP download to builtin handler: ${request.fileName}',
    );

    final taskId = await _kernelManager.addDownload(
      request.intent.normalizedValue,
      request.fileName,
      referer: request.referer,
      userAgent: request.userAgent,
      cookies: request.cookies,
      headers: request.headers,
      saveDir: request.saveDir,
      startPaused: request.startPaused,
    );

    if (taskId == null) {
      return DownloadDispatchResult.rejected(
        handlerId: id,
        intent: request.intent,
        errorCode: DownloadDispatchErrorCode.handlerUnavailable,
        message: 'Built-in HTTP handler failed to create a task',
      );
    }

    return DownloadDispatchResult.accepted(
      handlerId: id,
      intent: request.intent,
      taskId: taskId,
    );
  }
}

class PluginDownloadIntentHandler implements DownloadIntentHandler {
  PluginDownloadIntentHandler({
    PluginLifecycleService? pluginService,
    PluginProcessRunner? runner,
    AppLoggerService? logger,
  })  : _pluginService = pluginService ?? PluginLifecycleService(),
        _runner = runner ?? PluginProcessRunner(),
        _logger = logger ?? AppLoggerService();

  final PluginLifecycleService _pluginService;
  final PluginProcessRunner _runner;
  final AppLoggerService _logger;

  @override
  String get id => 'plugin-download';

  @override
  bool supports(DownloadIntent intent) {
    return intent.isRecognized && intent.type != DownloadIntentType.http;
  }

  @override
  Future<DownloadDispatchResult> handle(DownloadDispatchRequest request) async {
    await _pluginService.ensureInitialized();
    final plugin = _pluginService.resolvePluginForIntent(request.intent);
    if (plugin == null) {
      final type = request.intent.type.wireName;
      return DownloadDispatchResult.rejected(
        handlerId: id,
        intent: request.intent,
        errorCode: DownloadDispatchErrorCode.pluginUnavailable,
        message:
            'No enabled plugin can handle $type. Install or enable a plugin with capability download:$type.',
      );
    }

    _logger.info(
      'Plugin',
      'Dispatching ${request.intent.type.wireName} intent to plugin ${plugin.id}',
    );

    final result = await _runner.invoke(
      plugin,
      method: 'hanabi.download.create',
      params: request.toPluginJson(),
    );

    if (!result.success) {
      return DownloadDispatchResult.rejected(
        handlerId: '$id:${plugin.id}',
        intent: request.intent,
        errorCode: DownloadDispatchErrorCode.pluginFailed,
        message: result.error ?? 'Plugin failed to create a task',
      );
    }

    final payload = result.result;
    String? taskId;
    if (payload is Map) {
      taskId = payload['taskId']?.toString() ?? payload['task_id']?.toString();
    }
    taskId ??= 'plugin:${plugin.id}:${DateTime.now().millisecondsSinceEpoch}';

    return DownloadDispatchResult.accepted(
      handlerId: '$id:${plugin.id}',
      intent: request.intent,
      taskId: taskId,
      metadata: {
        'pluginId': plugin.id,
        if (payload is Map)
          'pluginResult': payload.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
      },
    );
  }
}

class DownloadIntentDispatcher {
  DownloadIntentDispatcher({
    required KernelManager kernelManager,
    PluginLifecycleService? pluginService,
    AppLoggerService? logger,
  })  : _logger = logger ?? AppLoggerService(),
        _handlers = [
          BuiltinHttpDownloadHandler(
            kernelManager: kernelManager,
            logger: logger,
          ),
          PluginDownloadIntentHandler(
            pluginService: pluginService,
            logger: logger,
          ),
        ];

  final AppLoggerService _logger;
  final List<DownloadIntentHandler> _handlers;

  Future<DownloadDispatchResult> dispatch(
      DownloadDispatchRequest request) async {
    if (!request.intent.isRecognized) {
      return DownloadDispatchResult.rejected(
        handlerId: 'dispatcher',
        intent: request.intent,
        errorCode: DownloadDispatchErrorCode.invalidIntent,
        message: 'Unsupported or invalid download intent',
      );
    }

    for (final handler in _handlers) {
      if (!handler.supports(request.intent)) {
        continue;
      }

      final result = await handler.handle(request);
      if (result.accepted) {
        _logger.info(
          'App',
          'Download intent accepted by ${result.handlerId}: ${result.taskId}',
        );
      } else {
        _logger.warning(
          'App',
          'Download intent rejected by ${result.handlerId}: ${result.message}',
        );
      }
      return result;
    }

    return DownloadDispatchResult.rejected(
      handlerId: 'dispatcher',
      intent: request.intent,
      errorCode: DownloadDispatchErrorCode.unsupportedIntent,
      message: 'No handler registered for ${request.intent.type.wireName}',
    );
  }
}
