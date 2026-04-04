import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'app_logger_service.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;
  final _appLogger = AppLoggerService();

  // 批量写入缓冲
  final StringBuffer _buffer = StringBuffer();
  Timer? _flushTimer;
  bool _flushing = false;

  Future<void> _ensureLogFile() async {
    if (_logFile != null) return;

    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/HanabiDownloadManagerX/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    _logFile = File('${logDir.path}/log_$timestamp.log');
  }

  void _writeLog(String level, String message, LogLevel appLogLevel,
      {String source = 'Kernel'}) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [$level] [$source] $message\n';

    // 同步到 AppLoggerService 用于 UI 显示（立即生效）
    _appLogger.log(appLogLevel, source, message, toConsole: false);

    // 追加到缓冲区，延迟批量写入磁盘
    _buffer.write(logEntry);
    _scheduleFlush();
  }

  /// 调度延迟刷盘，500ms 内的日志合并为一次写入
  void _scheduleFlush() {
    if (_flushTimer != null) return;
    _flushTimer = Timer(const Duration(milliseconds: 500), () {
      _flushTimer = null;
      _flush();
    });
  }

  /// 将缓冲区内容一次性写入磁盘
  Future<void> _flush() async {
    if (_flushing || _buffer.isEmpty) return;
    _flushing = true;

    // 取出当前缓冲内容并清空
    final content = _buffer.toString();
    _buffer.clear();

    try {
      await _ensureLogFile();
      await _logFile!.writeAsString(content, mode: FileMode.append);
    } catch (e) {
      // 避免递归调用，直接输出
      // ignore: avoid_print
      print('日志写入失败: $e');
    } finally {
      _flushing = false;
      // 如果刷盘期间又有新日志进来，继续调度
      if (_buffer.isNotEmpty) {
        _scheduleFlush();
      }
    }
  }

  void info(String message, {String source = 'Kernel'}) =>
      _writeLog('INFO', message, LogLevel.info, source: source);
  void warning(String message, {String source = 'Kernel'}) =>
      _writeLog('WARNING', message, LogLevel.warning, source: source);
  void error(String message, {String source = 'Kernel'}) =>
      _writeLog('ERROR', message, LogLevel.error, source: source);
  void debug(String message, {String source = 'Kernel'}) =>
      _writeLog('DEBUG', message, LogLevel.debug, source: source);
}
