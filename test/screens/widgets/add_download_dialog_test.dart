import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/l10n/app_localizations.dart';
import 'package:hanabi_download_manager_x/screens/widgets/add_download_dialog.dart';
import 'package:hanabi_download_manager_x/theme/app_theme.dart';

Widget _buildTestApp({
  String? initialUrl,
  VoidCallback? onMuteClipboardForSession,
}) {
  final theme = AppTheme.themeDataForBrightness(Brightness.dark);
  AppTheme.applyFluentTheme(theme);

  return FluentApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      FluentLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: ColoredBox(
      color: AppTheme.bgSolid,
      child: AddDownloadDialog(
        initialUrl: initialUrl,
        onMuteClipboardForSession: onMuteClipboardForSession,
      ),
    ),
  );
}

void main() {
  testWidgets('shows an inline error for an empty download URL',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('\u65b0\u5efa\u4e0b\u8f7d'), findsOneWidget);
    expect(find.byType(TextBox), findsNWidgets(2));

    await tester.tap(find.text('\u5f00\u59cb\u4e0b\u8f7d'));
    await tester.pumpAndSettle();

    expect(
      find.text('\u8bf7\u8f93\u5165\u4e0b\u8f7d\u94fe\u63a5'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the parsed file name and expands advanced options',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        initialUrl: 'https://example.com/releases/hanabi.zip',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('\u5df2\u89e3\u6790\u6587\u4ef6\u540d:'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'hanabi.zip',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('\u9ad8\u7ea7\u9009\u9879'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('\u81ea\u5b9a\u4e49\u6587\u4ef6\u540d'),
      findsOneWidget,
    );
    expect(find.byType(TextBox), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps all actions usable in a narrow window', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        initialUrl: 'https://example.com/releases/hanabi.zip',
        onMuteClipboardForSession: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\u672c\u6b21\u9759\u97f3'), findsOneWidget);
    expect(find.text('\u53d6\u6d88'), findsOneWidget);
    expect(find.text('\u5f00\u59cb\u4e0b\u8f7d'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
