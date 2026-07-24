import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/platform/windows/window_state_bridge.dart';

void main() {
  test('parses the normal restore size independently of presentation state',
      () {
    final placement = WindowsWindowPlacement.fromMap(const {
      'normalWidth': 889.0,
      'normalHeight': 586.0,
      'isMaximized': true,
      'isMinimized': false,
      'isVisible': true,
    });

    expect(placement.normalSize, const Size(889, 586));
    expect(placement.isMaximized, isTrue);
    expect(placement.isMinimized, isFalse);
    expect(placement.isVisible, isTrue);
  });

  test('rejects an incomplete native placement payload', () {
    expect(
      () => WindowsWindowPlacement.fromMap(const {
        'normalWidth': 889.0,
      }),
      throwsFormatException,
    );
  });
}
