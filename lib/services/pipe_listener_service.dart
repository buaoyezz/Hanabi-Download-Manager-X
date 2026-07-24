import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:flutter/foundation.dart';

int? _readPositiveInt(Object? raw) {
  final value = raw is num ? raw.toInt() : int.tryParse('$raw');
  return value != null && value > 0 ? value : null;
}

/// Download request received from the popup application
class PopupDownloadRequest {
  final String url;
  final String filename;
  final String savePath;
  final String? referer;
  final String? userAgent;
  final String? cookies;
  final Map<String, dynamic>? headers;
  final int? expectedSizeHint;

  PopupDownloadRequest({
    required this.url,
    required this.filename,
    required this.savePath,
    this.referer,
    this.userAgent,
    this.cookies,
    this.headers,
    this.expectedSizeHint,
  });

  factory PopupDownloadRequest.fromJson(Map<String, dynamic> json) {
    final headersRaw = json['headers'];
    return PopupDownloadRequest(
      url: json['url']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      savePath: json['save_path']?.toString() ?? '',
      referer: json['referer']?.toString(),
      userAgent: (json['user_agent'] ?? json['userAgent'])?.toString(),
      cookies: json['cookies']?.toString(),
      headers: headersRaw is Map
          ? headersRaw.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null,
      expectedSizeHint: _readPositiveInt(
        json['file_size'] ?? json['fileSize'] ?? json['total_bytes'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'filename': filename,
        'save_path': savePath,
        'referer': referer,
        'user_agent': userAgent,
        'cookies': cookies,
        'headers': headers,
        if (expectedSizeHint != null) 'file_size': expectedSizeHint,
      };

  @override
  String toString() =>
      'PopupDownloadRequest(url: $url, filename: $filename, savePath: $savePath)';
}

/// Service to listen for download requests from the Hanabi Popup application
/// via Windows Named Pipes
class PipeListenerService with ChangeNotifier {
  static const String pipeName = r'\\.\pipe\hanabi-download';
  static const int bufferSize = 4096;

  bool _isRunning = false;
  int _pipeHandleAddress = 0;
  Timer? _reconnectTimer;

  /// Callback when a download request is received
  FutureOr<void> Function(PopupDownloadRequest)? onDownloadRequest;

  /// Whether the pipe listener is currently running
  bool get isRunning => _isRunning;

  /// Start listening for download requests
  Future<void> start() async {
    if (_isRunning) {
      debugPrint('[PipeListener] Already running');
      return;
    }

    debugPrint('[PipeListener] Starting pipe listener...');
    _isRunning = true;
    notifyListeners();

    // Start the listening loop in an isolate-friendly way
    _startListening();
  }

  /// Stop listening for download requests
  Future<void> stop() async {
    debugPrint('[PipeListener] Stopping pipe listener...');
    _isRunning = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_pipeHandleAddress != 0 &&
        _pipeHandleAddress != INVALID_HANDLE_VALUE.address) {
      CloseHandle(HANDLE(Pointer.fromAddress(_pipeHandleAddress)));
      _pipeHandleAddress = 0;
    }

    notifyListeners();
  }

  void _startListening() {
    _createAndListenPipe();
  }

  void _createAndListenPipe() {
    if (!_isRunning) return;

    // Create the named pipe
    final pipeNamePtr = pipeName.toNativeUtf16();

    try {
      _pipeHandleAddress = CreateNamedPipe(
        PCWSTR(pipeNamePtr),
        PIPE_ACCESS_INBOUND, // Read-only from our side
        PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
        1, // Max instances
        bufferSize,
        bufferSize,
        0, // Default timeout
        nullptr, // Default security
      ).address;

      if (_pipeHandleAddress == 0 ||
          _pipeHandleAddress == INVALID_HANDLE_VALUE.address) {
        final error = GetLastError();
        debugPrint('[PipeListener] Failed to create pipe, error: $error');
        _scheduleReconnect();
        return;
      }

      debugPrint('[PipeListener] Pipe created, waiting for connection...');

      // Wait for client connection in a separate isolate/thread
      _waitForConnection();
    } finally {
      free(pipeNamePtr);
    }
  }

  void _waitForConnection() {
    // Use compute to avoid blocking the UI thread
    compute(_connectAndRead, _pipeHandleAddress).then((result) {
      if (result != null && _isRunning) {
        _handleMessage(result);
      }

      // Close current handle and create new pipe for next connection
      if (_pipeHandleAddress != 0 &&
          _pipeHandleAddress != INVALID_HANDLE_VALUE.address) {
        CloseHandle(HANDLE(Pointer.fromAddress(_pipeHandleAddress)));
        _pipeHandleAddress = 0;
      }

      // Continue listening if still running
      if (_isRunning) {
        _createAndListenPipe();
      }
    }).catchError((error) {
      debugPrint('[PipeListener] Error in pipe connection: $error');
      if (_isRunning) {
        _scheduleReconnect();
      }
    });
  }

  static String? _connectAndRead(int pipeHandleAddress) {
    // Wait for a client to connect
    final connected = ConnectNamedPipe(
        HANDLE(Pointer.fromAddress(pipeHandleAddress)), nullptr);
    final error = GetLastError();

    if (connected.value == false && error != ERROR_PIPE_CONNECTED) {
      return null;
    }

    // Read the message
    final buffer = calloc<Uint8>(bufferSize);
    final bytesRead = calloc<DWORD>();

    try {
      final success = ReadFile(
        HANDLE(Pointer.fromAddress(pipeHandleAddress)),
        buffer,
        bufferSize,
        bytesRead,
        nullptr,
      );

      if (success.value != false && bytesRead.value > 0) {
        final data = buffer.cast<Utf8>().toDartString(length: bytesRead.value);
        return data.trim();
      }
    } finally {
      free(buffer);
      free(bytesRead);
    }

    return null;
  }

  void _handleMessage(String message) {
    debugPrint('[PipeListener] Received message: $message');

    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final request = PopupDownloadRequest.fromJson(json);

      debugPrint('[PipeListener] Parsed request: $request');

      // Notify callback
      if (onDownloadRequest != null) {
        unawaited(Future.sync(() => onDownloadRequest!(request)));
      }
    } catch (e) {
      debugPrint('[PipeListener] Failed to parse message: $e');
    }
  }

  void _scheduleReconnect() {
    if (!_isRunning) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_isRunning) {
        debugPrint('[PipeListener] Reconnecting...');
        _createAndListenPipe();
      }
    });
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
