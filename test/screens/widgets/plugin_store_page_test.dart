import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/l10n/app_localizations.dart';
import 'package:hanabi_download_manager_x/screens/widgets/plugin_store_page.dart';
import 'package:hanabi_download_manager_x/services/plugin_lifecycle_service.dart';
import 'package:hanabi_download_manager_x/services/plugin_store_service.dart';
import 'package:hanabi_download_manager_x/services/quick_path_service.dart';
import 'package:hanabi_download_manager_x/theme/app_theme.dart';
import 'package:hanabi_download_manager_x/widgets/folder_picker_dialog.dart';
import 'package:provider/provider.dart';

Widget _buildTestApp() {
  final theme = AppTheme.themeDataForBrightness(Brightness.dark);
  AppTheme.applyFluentTheme(theme);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PluginLifecycleService>.value(
        value: PluginLifecycleService(),
      ),
      ChangeNotifierProvider<PluginStoreService>.value(
        value: PluginStoreService(),
      ),
      ChangeNotifierProvider<QuickPathService>.value(
        value: QuickPathService(),
      ),
    ],
    child: FluentApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        FluentLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: const PluginStorePage(),
    ),
  );
}

void main() {
  testWidgets('plugin package install opens the global multi-file picker',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_buildTestApp());
    await tester.pump();

    await tester.tap(find.text('安装包'));
    await tester.pump();

    expect(find.text('浏览'), findsOneWidget);
    expect(find.textContaining('.zip, .hanabi-plugin'), findsOneWidget);

    final installButton = find.widgetWithText(FilledButton, '安装');
    final pathInput = find.byType(TextFormBox);
    expect(tester.widget<FilledButton>(installButton).onPressed, isNull);
    await tester.enterText(pathInput, r'C:\Downloads\not-a-plugin.txt');
    await tester.pump();
    expect(tester.widget<FilledButton>(installButton).onPressed, isNull);
    await tester.enterText(pathInput, r'C:\Downloads\plugin.hanabi-plugin');
    await tester.pump();
    expect(tester.widget<FilledButton>(installButton).onPressed, isNotNull);
    await tester.enterText(pathInput, '');
    await tester.pump();

    await tester.tap(find.text('浏览'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('选择插件安装包'), findsOneWidget);
    expect(find.text('安装所选包 (0)'), findsOneWidget);
    expect(find.textContaining('.zip, .hanabi-plugin'), findsWidgets);
    expect(
      tester
          .widget<FolderPickerDialog>(find.byType(FolderPickerDialog))
          .allowMultiple,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
