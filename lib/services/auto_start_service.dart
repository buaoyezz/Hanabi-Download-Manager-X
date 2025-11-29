import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'logger_service.dart';

class AutoStartService {
  static const String _appName = 'SudaDownloadManager';
  final _logger = LoggerService();

  Future<bool> isAutoStartEnabled() async {
    if (!Platform.isWindows) return false;

    try {
      final result = await Process.run(
        'reg',
        ['query', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run', '/v', _appName],
      );
      return result.exitCode == 0;
    } catch (e) {
      _logger.error('Failed to check auto-start status: $e');
      return false;
    }
  }

  Future<bool> enableAutoStart() async {
    if (!Platform.isWindows) return false;

    try {
      String exePath = Platform.resolvedExecutable;
      
      // 如果是开发环境，可能需要特殊处理，但在 IDE 中运行通常指向 flutter 工具
      // 这里主要为了打包后的 exe 服务
      
      final result = await Process.run(
        'reg',
        [
          'add',
          'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
          '/v',
          _appName,
          '/t',
          'REG_SZ',
          '/d',
          exePath,
          '/f'
        ],
      );

      if (result.exitCode == 0) {
        _logger.info('Auto-start enabled for: $exePath');
        return true;
      } else {
        _logger.error('Failed to enable auto-start: ${result.stderr}');
        return false;
      }
    } catch (e) {
      _logger.error('Error enabling auto-start: $e');
      return false;
    }
  }

  Future<bool> disableAutoStart() async {
    if (!Platform.isWindows) return false;

    try {
      final result = await Process.run(
        'reg',
        [
          'delete',
          'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
          '/v',
          _appName,
          '/f'
        ],
      );

      if (result.exitCode == 0) {
        _logger.info('Auto-start disabled');
        return true;
      } else {
        // 如果 key 不存在，也认为是禁用成功
        if (result.stderr.toString().contains('The system was unable to find the specified registry key or value')) {
             return true;
        }
        _logger.error('Failed to disable auto-start: ${result.stderr}');
        return false;
      }
    } catch (e) {
      _logger.error('Error disabling auto-start: $e');
      return false;
    }
  }
}
