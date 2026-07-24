import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/tray_menu/tray_menu_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrayMenuLaunchData', () {
    test('parses presentation, positioning, and active-task payload', () {
      final data = TrayMenuLaunchData.fromArgs(const [
        '{"locale":"zh-CN","mouse_x":120.5,"mouse_y":640,'
            '"show_on_ready":false,"theme_mode":"dark",'
            '"classic_control_visuals":true,"active_tasks":['
            '{"id":"task-1","file_name":"archive.zip",'
            '"status":"downloading","progress":0.25}]}'
      ]);

      expect(data.localeTag, 'zh-CN');
      expect(data.mousePositionX, 120.5);
      expect(data.mousePositionY, 640);
      expect(data.showOnReady, isFalse);
      expect(data.themeMode, 'dark');
      expect(data.classicControlVisuals, isTrue);
      expect(data.activeTasks, hasLength(1));
      expect(data.activeTasks.single.fileName, 'archive.zip');
      expect(data.activeTasks.single.progress, 0.25);
    });

    test('uses safe defaults for malformed payload', () {
      final data = TrayMenuLaunchData.fromArgs(const ['not-json']);

      expect(data.localeTag, isNull);
      expect(data.mousePositionX, 0);
      expect(data.mousePositionY, 0);
      expect(data.showOnReady, isTrue);
      expect(data.activeTasks, isEmpty);
    });

    test('compares equivalent active-task payloads by value', () {
      final first = TrayMenuLaunchData.fromArgs(const [
        '{"locale":"en-US","mouse_x":1,"mouse_y":2,'
            '"active_tasks":[{"id":"a","file_name":"a.bin",'
            '"status":"pending","progress":0}]}'
      ]);
      final second = TrayMenuLaunchData.fromArgs(const [
        '{"locale":"en-US","mouse_x":1,"mouse_y":2,'
            '"active_tasks":[{"id":"a","file_name":"a.bin",'
            '"status":"pending","progress":0}]}'
      ]);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });

  test('window size reserves symmetric panel and shadow space', () {
    const contentSize = Size(156.2, 203.1);

    expect(
      calculateTrayMenuWindowSize(contentSize),
      const Size(181, 232),
    );
  });

  testWidgets('submenu hover is stable and Escape closes once', (tester) async {
    const channel = MethodChannel('com.hanabi.download/window');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      const TrayMenuApp(
        launchData: TrayMenuLaunchData(
          localeTag: 'en-US',
          mousePositionX: 0,
          mousePositionY: 0,
          showOnReady: false,
        ),
        locale: Locale('en', 'US'),
      ),
    );
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Open folders')));
    await tester.pump();
    expect(find.text('Downloads'), findsOneWidget);

    await mouse.moveTo(const Offset(760, 560));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 279));
    expect(find.text('Downloads'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.text('Downloads'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(calls.where((call) => call.method == 'closeWindow'), hasLength(1));
  });
}
