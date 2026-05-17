import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

/// Best-effort process working-set trimming for Windows background mode.
///
/// This does not reduce Dart heap commitments by itself; it asks Windows to
/// drop pages that can be faulted back later. That matches Task Manager's
/// working-set style memory columns.
class ProcessMemoryTrimService {
  ProcessMemoryTrimService._();

  static bool _isTrimming = false;

  static bool trimCurrentProcessWorkingSet({String reason = 'background'}) {
    if (!Platform.isWindows || _isTrimming) {
      return false;
    }

    _isTrimming = true;
    try {
      final beforeMb = _currentRssMb();
      final processHandle = GetCurrentProcess();
      var succeeded = EmptyWorkingSet(processHandle) != 0;
      var lastError = succeeded ? 0 : GetLastError();

      if (!succeeded) {
        succeeded = SetProcessWorkingSetSize(processHandle, -1, -1) != 0;
        lastError = succeeded ? 0 : GetLastError();
      }

      final afterMb = _currentRssMb();
      if (succeeded) {
        debugPrint(
          '[MemoryTrim] $reason: ${beforeMb.toStringAsFixed(1)} MB -> '
          '${afterMb.toStringAsFixed(1)} MB',
        );
      } else {
        debugPrint('[MemoryTrim] $reason failed: Win32 error $lastError');
      }
      return succeeded;
    } catch (error) {
      debugPrint('[MemoryTrim] $reason failed: $error');
      return false;
    } finally {
      _isTrimming = false;
    }
  }

  static double _currentRssMb() => ProcessInfo.currentRss / (1024 * 1024);
}
