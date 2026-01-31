import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'app_logger_service.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;
  final _appLogger = AppLoggerService();
  
  Future<void> _ensureLogFile() async {
    if (_logFile != null) return;
    
    final directory = await getApplicationDocumentsDirectory();
    final logDir = Directory('${directory.path}/HanabiDownloadManagerX/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    
    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    _logFile = File('${logDir.path}/log_$timestamp.txt');
  }

  Future<void> _writeLog(String level, String message, LogLevel appLogLevel) async {
    await _ensureLogFile();
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [$level] $message\n';
    
    // 同步到 AppLoggerService 用于 UI 显示
    _appLogger.log(appLogLevel, 'Kernel', message);
    
    try {
      await _logFile!.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      // 避免递归调用，直接输出
      // ignore: avoid_print
      print('日志写入失败: $e');
    }
  }

  void info(String message) => _writeLog('INFO', message, LogLevel.info);
  void warning(String message) => _writeLog('WARNING', message, LogLevel.warning);
  void error(String message) => _writeLog('ERROR', message, LogLevel.error);
  void debug(String message) => _writeLog('DEBUG', message, LogLevel.debug);
}
