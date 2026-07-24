import 'package:flutter_test/flutter_test.dart';

import '../../tool/download_architecture_benchmark.dart';

void main() {
  final nativeRuntimeAvailable =
      isArchitectureBenchmarkNativeRuntimeAvailable();

  test(
    'prints the local small-file architecture benchmark',
    runDownloadArchitectureBenchmark,
    timeout: const Timeout(Duration(minutes: 3)),
    skip: nativeRuntimeAvailable
        ? false
        : 'rhttp.dll must be available in PATH for this benchmark',
  );
}
