import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hanabi_download_manager_x/l10n/app_localizations.dart';
import 'package:hanabi_download_manager_x/services/quick_path_service.dart';
import 'package:hanabi_download_manager_x/theme/app_theme.dart';
import 'package:hanabi_download_manager_x/widgets/folder_picker_dialog.dart';
import 'package:provider/provider.dart';

Widget _buildTestApp(Widget child) {
  final theme = AppTheme.themeDataForBrightness(Brightness.dark);
  AppTheme.applyFluentTheme(theme);

  return ChangeNotifierProvider<QuickPathService>.value(
    value: QuickPathService(),
    child: FluentApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        FluentLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      home: child,
    ),
  );
}

void main() {
  testWidgets('file mode filters files and remains single-select by default',
      (tester) async {
    final temporary = await Directory.systemTemp.createTemp('hanabi-picker-');
    addTearDown(() => temporary.delete(recursive: true));
    final zipFile =
        File('${temporary.path}${Platform.pathSeparator}plugin.zip');
    final packageFile = File(
      '${temporary.path}${Platform.pathSeparator}plugin.hanabi-plugin',
    );
    final ignoredFile =
        File('${temporary.path}${Platform.pathSeparator}notes.txt');
    await zipFile.writeAsString('zip');
    await packageFile.writeAsString('package');
    await ignoredFile.writeAsString('ignored');
    await Directory('${temporary.path}${Platform.pathSeparator}nested')
        .create();

    await tester.binding.setSurfaceSize(const Size(960, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildTestApp(
        FolderPickerDialog(
          initialPath: temporary.path,
          mode: FileSystemPickerMode.file,
          allowedExtensions: const <String>['zip', 'hanabi-plugin'],
          title: '选择插件安装包',
          selectButtonLabel: '使用此文件',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('plugin.zip'), findsOneWidget);
    expect(find.text('plugin.hanabi-plugin'), findsOneWidget);
    expect(find.text('notes.txt'), findsNothing);
    expect(find.text('nested'), findsOneWidget);
    expect(find.text('快速访问'), findsOneWidget);
    expect(find.text('名称'), findsOneWidget);
    expect(find.text('类型'), findsOneWidget);
    expect(find.textContaining('.zip, .hanabi-plugin'), findsOneWidget);

    final selectButton = find.widgetWithText(FilledButton, '使用此文件');
    expect(tester.widget<FilledButton>(selectButton).onPressed, isNull);

    await tester.tap(find.text('plugin.zip'));
    await tester.pump();

    expect(tester.widget<FilledButton>(selectButton).onPressed, isNotNull);
    expect(find.text(zipFile.absolute.path), findsOneWidget);

    await tester.tap(find.text('plugin.hanabi-plugin'));
    await tester.pump();

    expect(find.text(packageFile.absolute.path), findsOneWidget);
    expect(find.text(zipFile.absolute.path), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('allowMultiple selects and deselects several visible files',
      (tester) async {
    final temporary = await Directory.systemTemp.createTemp('hanabi-multi-');
    addTearDown(() => temporary.delete(recursive: true));
    await File('${temporary.path}${Platform.pathSeparator}first.zip')
        .writeAsString('first');
    await File(
      '${temporary.path}${Platform.pathSeparator}second.hanabi-plugin',
    ).writeAsString('second');

    await tester.binding.setSurfaceSize(const Size(960, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildTestApp(
        FolderPickerDialog(
          initialPath: temporary.path,
          mode: FileSystemPickerMode.file,
          allowMultiple: true,
          allowedExtensions: const <String>['zip', 'hanabi-plugin'],
          selectButtonLabel: '使用所选文件',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(Checkbox), findsNWidgets(2));
    final selectButton = find.widgetWithText(FilledButton, '使用所选文件 (0)');
    expect(tester.widget<FilledButton>(selectButton).onPressed, isNull);

    await tester.tap(find.text('first.zip'));
    await tester.tap(find.text('second.hanabi-plugin'));
    await tester.pump();

    expect(find.text('已选择 2 个文件'), findsOneWidget);
    final selectedButton = find.widgetWithText(FilledButton, '使用所选文件 (2)');
    expect(tester.widget<FilledButton>(selectedButton).onPressed, isNotNull);

    await tester.tap(find.text('first.zip'));
    await tester.pump();

    expect(find.text('已选择 1 个文件'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '使用所选文件 (1)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('directory mode remains backward compatible', (tester) async {
    final temporary = await Directory.systemTemp.createTemp('hanabi-folder-');
    addTearDown(() => temporary.delete(recursive: true));
    await File('${temporary.path}${Platform.pathSeparator}hidden.zip')
        .writeAsString('zip');
    await Directory('${temporary.path}${Platform.pathSeparator}visible')
        .create();

    await tester.binding.setSurfaceSize(const Size(960, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildTestApp(FolderPickerDialog(initialPath: temporary.path)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('visible'), findsOneWidget);
    expect(find.text('hidden.zip'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, '选择'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact layout collapses the navigation rail without overflow',
      (tester) async {
    final temporary = await Directory.systemTemp.createTemp('hanabi-compact-');
    addTearDown(() => temporary.delete(recursive: true));
    await Directory('${temporary.path}${Platform.pathSeparator}visible')
        .create();

    await tester.binding.setSurfaceSize(const Size(640, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _buildTestApp(FolderPickerDialog(initialPath: temporary.path)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('visible'), findsOneWidget);
    expect(find.text('快速访问'), findsNothing);
    expect(find.text('类型'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
