import 'dart:io';
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

  /// 获取当前注册的自启动路径
  Future<String?> getRegisteredPath() async {
    if (!Platform.isWindows) return null;

    try {
      final result = await Process.run(
        'reg',
        ['query', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run', '/v', _appName],
      );
      
      if (result.exitCode == 0) {
        // 解析输出获取路径
        final output = result.stdout.toString();
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains(_appName) && line.contains('REG_SZ')) {
            // 格式: "    SudaDownloadManager    REG_SZ    C:\path\to\app.exe"
            final parts = line.split('REG_SZ');
            if (parts.length > 1) {
              return parts[1].trim();
            }
          }
        }
      }
      return null;
    } catch (e) {
      _logger.error('Failed to get registered path: $e');
      return null;
    }
  }

  /// 检查注册的路径是否正确（是否指向当前可执行文件）
  Future<bool> isRegisteredPathCorrect() async {
    if (!Platform.isWindows) return true;

    try {
      final registeredPath = await getRegisteredPath();
      if (registeredPath == null) return false;

      final currentPath = Platform.resolvedExecutable;
      final expectedCommand = '"$currentPath" --autostart';
      
      // 移除注册路径中的引号和多余空格进行比较
      final cleanRegistered = registeredPath.replaceAll('"', '').trim().toLowerCase();
      final cleanExpected = expectedCommand.replaceAll('"', '').trim().toLowerCase();
      
      // 规范化路径
      final normalizedRegistered = path.normalize(cleanRegistered);
      final normalizedExpected = path.normalize(cleanExpected);
      
      return normalizedRegistered == normalizedExpected;
    } catch (e) {
      _logger.error('Failed to check registered path: $e');
      return false;
    }
  }

  /// verify auto-start registration and fix if necessary
  Future<bool> verifyAndFixAutoStart() async {
    if (!Platform.isWindows) return true;

    try {
      final isEnabled = await isAutoStartEnabled();
      if (!isEnabled) {
        // 未启用，无需修复
        return true;
      }

      final isCorrect = await isRegisteredPathCorrect();
      if (isCorrect) {
        _logger.info('Auto-start registration is correct');
        return true;
      }

      // 路径不正确，重新注册
      _logger.warning('Auto-start path is incorrect, fixing...');
      final oldPath = await getRegisteredPath();
      _logger.info('Old path: $oldPath');
      _logger.info('New path: ${Platform.resolvedExecutable}');
      
      final success = await enableAutoStart();
      if (success) {
        _logger.info('Auto-start registration fixed successfully');
      } else {
        _logger.error('Failed to fix auto-start registration');
      }
      return success;
    } catch (e) {
      _logger.error('Error verifying/fixing auto-start: $e');
      return false;
    }
  }

  Future<bool> enableAutoStart() async {
    if (!Platform.isWindows) return false;

    try {
      String exePath = Platform.resolvedExecutable;
      
      // 添加 --autostart 参数，让其支持特殊的最小化启动，不影响其他启动方式
      // 准备新增一个彩蛋参数（rainbow egg xD）
      String command = '"$exePath" --autostart';
      
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
          command,
          '/f'
        ],
      );

      if (result.exitCode == 0) {
        _logger.info('Auto-start enabled for: $command');
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
