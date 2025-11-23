import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;
  
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

  Future<void> _writeLog(String level, String message) async {
    await _ensureLogFile();
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [$level] $message\n';
    
    print(logEntry.trim());
    
    try {
      await _logFile!.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      print('日志写入失败: $e');
    }
  }

  void info(String message) => _writeLog('INFO', message);
  void warning(String message) => _writeLog('WARNING', message);
  void error(String message) => _writeLog('ERROR', message);
  void debug(String message) => _writeLog('DEBUG', message);
}
