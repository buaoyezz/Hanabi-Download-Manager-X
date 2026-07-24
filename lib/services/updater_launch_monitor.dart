import 'dart:async';
import 'dart:io';

enum UpdaterLaunchStatus {
  ready,
  exitedEarly,
  timedOut,
}

class UpdaterLaunchResult {
  final UpdaterLaunchStatus status;
  final int? exitCode;

  const UpdaterLaunchResult(this.status, {this.exitCode});

  bool get isReady => status == UpdaterLaunchStatus.ready;
}

class UpdaterLaunchMonitor {
  const UpdaterLaunchMonitor._();

  static Future<UpdaterLaunchResult> waitForReady({
    required String readyFilePath,
    required Future<int> exitCode,
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 50),
  }) async {
    int? observedExitCode;
    var exitObserved = false;
    unawaited(
      exitCode.then(
        (code) {
          observedExitCode = code;
          exitObserved = true;
        },
        onError: (_) {
          observedExitCode = -1;
          exitObserved = true;
        },
      ),
    );

    final readyFile = File(readyFilePath);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await readyFile.exists()) {
        return const UpdaterLaunchResult(UpdaterLaunchStatus.ready);
      }
      if (exitObserved) {
        return UpdaterLaunchResult(
          UpdaterLaunchStatus.exitedEarly,
          exitCode: observedExitCode,
        );
      }
      await Future<void>.delayed(pollInterval);
    }

    if (await readyFile.exists()) {
      return const UpdaterLaunchResult(UpdaterLaunchStatus.ready);
    }
    if (exitObserved) {
      return UpdaterLaunchResult(
        UpdaterLaunchStatus.exitedEarly,
        exitCode: observedExitCode,
      );
    }
    return const UpdaterLaunchResult(UpdaterLaunchStatus.timedOut);
  }
}
