import 'app_logger_service.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final AppLoggerService _appLogger = AppLoggerService();

  Future<void> initialize() => _appLogger.initialize();

  Future<void> flush() => _appLogger.flushFullLog();

  void _writeLog(
    LogLevel level,
    String message, {
    String source = 'Kernel',
  }) {
    _appLogger.log(
      level,
      source,
      message,
      toConsole: false,
      immediateFlush: level == LogLevel.warning || level == LogLevel.error,
    );
  }

  void info(String message, {String source = 'Kernel'}) =>
      _writeLog(LogLevel.info, message, source: source);

  void warning(String message, {String source = 'Kernel'}) =>
      _writeLog(LogLevel.warning, message, source: source);

  void error(String message, {String source = 'Kernel'}) =>
      _writeLog(LogLevel.error, message, source: source);

  void debug(String message, {String source = 'Kernel'}) =>
      _writeLog(LogLevel.debug, message, source: source);
}
