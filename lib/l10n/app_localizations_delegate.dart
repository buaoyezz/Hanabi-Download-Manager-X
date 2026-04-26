import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import '../services/localization_service.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  AppLocalizationsDelegate(this.service) : revision = service.revision;

  final LocalizationService service;
  final int revision;

  @override
  bool isSupported(Locale locale) => service.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final resolvedLocale = service.resolveSupportedLocale(locale);
    final strings = service.getStringsFor(locale);
    if (strings != null && strings.isNotEmpty) {
      final fallback =
          lookupAppLocalizations(_normalizeBuiltin(resolvedLocale));
      return PluginAppLocalizations(
        resolvedLocale.toString(),
        strings,
        fallback,
      );
    }

    final effective = _normalizeBuiltin(resolvedLocale);
    return lookupAppLocalizations(effective);
  }

  @override
  bool shouldReload(covariant AppLocalizationsDelegate old) {
    return revision != old.revision;
  }

  Locale _normalizeBuiltin(Locale locale) {
    if (locale.languageCode == 'zh') {
      return const Locale('zh');
    }
    return const Locale('en');
  }
}

class PluginAppLocalizations extends AppLocalizations {
  PluginAppLocalizations(
    super.locale,
    this._strings,
    this._fallback,
  );

  final Map<String, String> _strings;
  final AppLocalizations _fallback;

  String _string(String key, String fallback) {
    final value = _strings[key];
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  String _format(String key, Map<String, Object> params, String fallback) {
    final template = _strings[key];
    if (template == null || template.isEmpty) return fallback;

    var result = template;
    params.forEach((param, value) {
      result = result.replaceAll('{$param}', value.toString());
    });
    return result;
  }

  @override
  String get appTitle => _string('appTitle', _fallback.appTitle);

  @override
  String get aboutEasterEggCongrats =>
      _string('aboutEasterEggCongrats', _fallback.aboutEasterEggCongrats);

  @override
  String get aboutEasterEggTitle =>
      _string('aboutEasterEggTitle', _fallback.aboutEasterEggTitle);

  @override
  String aboutEasterEggMessage(Object appName) => _format(
      'aboutEasterEggMessage',
      {'appName': appName},
      _fallback.aboutEasterEggMessage(appName));

  @override
  String get aboutEasterEggDismiss =>
      _string('aboutEasterEggDismiss', _fallback.aboutEasterEggDismiss);

  @override
  String aboutMadeBy(Object developer) => _format('aboutMadeBy',
      {'developer': developer}, _fallback.aboutMadeBy(developer));

  @override
  String get aboutEasterEggDialogTitle =>
      _string('aboutEasterEggDialogTitle', _fallback.aboutEasterEggDialogTitle);

  @override
  String get aboutPageTitle =>
      _string('aboutPageTitle', _fallback.aboutPageTitle);

  @override
  String get aboutSectionAppInfo =>
      _string('aboutSectionAppInfo', _fallback.aboutSectionAppInfo);

  @override
  String aboutTapHintRemaining(Object count) => _format('aboutTapHintRemaining',
      {'count': count}, _fallback.aboutTapHintRemaining(count));

  @override
  String aboutVersionLabel(Object version) => _format('aboutVersionLabel',
      {'version': version}, _fallback.aboutVersionLabel(version));

  @override
  String get aboutSectionDetails =>
      _string('aboutSectionDetails', _fallback.aboutSectionDetails);

  @override
  String get aboutDetailDeveloperLabel =>
      _string('aboutDetailDeveloperLabel', _fallback.aboutDetailDeveloperLabel);

  @override
  String get aboutDetailKernelLabel =>
      _string('aboutDetailKernelLabel', _fallback.aboutDetailKernelLabel);

  @override
  String get aboutDetailUiFrameworkLabel => _string(
      'aboutDetailUiFrameworkLabel', _fallback.aboutDetailUiFrameworkLabel);

  @override
  String get aboutDetailUiFrameworkValue => _string(
      'aboutDetailUiFrameworkValue', _fallback.aboutDetailUiFrameworkValue);

  @override
  String get aboutSectionLinks =>
      _string('aboutSectionLinks', _fallback.aboutSectionLinks);

  @override
  String get aboutLinkOfficialTitle =>
      _string('aboutLinkOfficialTitle', _fallback.aboutLinkOfficialTitle);

  @override
  String get aboutLinkOfficialSubtitle =>
      _string('aboutLinkOfficialSubtitle', _fallback.aboutLinkOfficialSubtitle);

  @override
  String get aboutLinkGithubTitle =>
      _string('aboutLinkGithubTitle', _fallback.aboutLinkGithubTitle);

  @override
  String get aboutLinkGithubSubtitle =>
      _string('aboutLinkGithubSubtitle', _fallback.aboutLinkGithubSubtitle);

  @override
  String get aboutLinkContactTitle =>
      _string('aboutLinkContactTitle', _fallback.aboutLinkContactTitle);

  @override
  String aboutCopyrightMessage(Object year, Object developer) => _format(
      'aboutCopyrightMessage',
      {'year': year, 'developer': developer},
      _fallback.aboutCopyrightMessage(year, developer));

  @override
  String get aboutOpenLinkErrorTitle =>
      _string('aboutOpenLinkErrorTitle', _fallback.aboutOpenLinkErrorTitle);

  @override
  String aboutOpenLinkErrorMessage(Object error) => _format(
      'aboutOpenLinkErrorMessage',
      {'error': error},
      _fallback.aboutOpenLinkErrorMessage(error));

  @override
  String get settingsTitle => _string('settingsTitle', _fallback.settingsTitle);

  @override
  String get settingsTabGeneral =>
      _string('settingsTabGeneral', _fallback.settingsTabGeneral);

  @override
  String get settingsTabDownload =>
      _string('settingsTabDownload', _fallback.settingsTabDownload);

  @override
  String get settingsTabAppearance =>
      _string('settingsTabAppearance', _fallback.settingsTabAppearance);

  @override
  String get settingsTabUpdate =>
      _string('settingsTabUpdate', _fallback.settingsTabUpdate);

  @override
  String get settingsTabAdvanced =>
      _string('settingsTabAdvanced', _fallback.settingsTabAdvanced);

  @override
  String get settingsTabDeveloper =>
      _string('settingsTabDeveloper', _fallback.settingsTabDeveloper);

  @override
  String get appearanceThemeSection =>
      _string('appearanceThemeSection', _fallback.appearanceThemeSection);

  @override
  String get appearanceThemeModeTitle =>
      _string('appearanceThemeModeTitle', _fallback.appearanceThemeModeTitle);

  @override
  String get appearanceThemeModeSubtitle => _string(
      'appearanceThemeModeSubtitle', _fallback.appearanceThemeModeSubtitle);

  @override
  String get appearanceThemeModeSystem =>
      _string('appearanceThemeModeSystem', _fallback.appearanceThemeModeSystem);

  @override
  String get appearanceThemeModeLight =>
      _string('appearanceThemeModeLight', _fallback.appearanceThemeModeLight);

  @override
  String get appearanceThemeModeDark =>
      _string('appearanceThemeModeDark', _fallback.appearanceThemeModeDark);

  @override
  String get appearanceThemeSavedTitle =>
      _string('appearanceThemeSavedTitle', _fallback.appearanceThemeSavedTitle);

  @override
  String appearanceThemeSavedMessage(Object mode) => _format(
      'appearanceThemeSavedMessage',
      {'mode': mode},
      _fallback.appearanceThemeSavedMessage(mode));

  @override
  String get appearanceSectionLanguage =>
      _string('appearanceSectionLanguage', _fallback.appearanceSectionLanguage);

  @override
  String get appearanceLanguageTitle =>
      _string('appearanceLanguageTitle', _fallback.appearanceLanguageTitle);

  @override
  String get appearanceLanguageSubtitle => _string(
      'appearanceLanguageSubtitle', _fallback.appearanceLanguageSubtitle);

  @override
  String get appearanceLanguageSystem =>
      _string('appearanceLanguageSystem', _fallback.appearanceLanguageSystem);

  @override
  String get appearanceLanguageChinese =>
      _string('appearanceLanguageChinese', _fallback.appearanceLanguageChinese);

  @override
  String get appearanceLanguageEnglish =>
      _string('appearanceLanguageEnglish', _fallback.appearanceLanguageEnglish);

  @override
  String get appearanceLanguageSwitchedTitle => _string(
      'appearanceLanguageSwitchedTitle',
      _fallback.appearanceLanguageSwitchedTitle);

  @override
  String get appearanceLanguageSwitchedSystem => _string(
      'appearanceLanguageSwitchedSystem',
      _fallback.appearanceLanguageSwitchedSystem);

  @override
  String appearanceLanguageSwitchedTo(Object language) => _format(
      'appearanceLanguageSwitchedTo',
      {'language': language},
      _fallback.appearanceLanguageSwitchedTo(language));

  @override
  String get appearanceLanguagePacksTitle => _string(
      'appearanceLanguagePacksTitle', _fallback.appearanceLanguagePacksTitle);

  @override
  String appearanceLanguagePacksSubtitle(Object path) => _format(
      'appearanceLanguagePacksSubtitle',
      {'path': path},
      _fallback.appearanceLanguagePacksSubtitle(path));

  @override
  String get appearanceLanguagePacksRefreshedTitle => _string(
      'appearanceLanguagePacksRefreshedTitle',
      _fallback.appearanceLanguagePacksRefreshedTitle);

  @override
  String appearanceLanguagePacksRefreshedMessage(Object count) => _format(
      'appearanceLanguagePacksRefreshedMessage',
      {'count': count},
      _fallback.appearanceLanguagePacksRefreshedMessage(count));

  @override
  String get appearanceLanguageRefreshButton => _string(
      'appearanceLanguageRefreshButton',
      _fallback.appearanceLanguageRefreshButton);

  @override
  String get trayMenuShowWindowTitle =>
      _string('trayMenuShowWindowTitle', _fallback.trayMenuShowWindowTitle);

  @override
  String get trayMenuShowWindowSubtitle => _string(
      'trayMenuShowWindowSubtitle', _fallback.trayMenuShowWindowSubtitle);

  @override
  String get trayMenuKernelTitle =>
      _string('trayMenuKernelTitle', _fallback.trayMenuKernelTitle);

  @override
  String get trayMenuKernelSubtitleRunning => _string(
      'trayMenuKernelSubtitleRunning', _fallback.trayMenuKernelSubtitleRunning);

  @override
  String get trayMenuKernelSubtitleStopped => _string(
      'trayMenuKernelSubtitleStopped', _fallback.trayMenuKernelSubtitleStopped);

  @override
  String get trayMenuExitTitle =>
      _string('trayMenuExitTitle', _fallback.trayMenuExitTitle);

  @override
  String get trayMenuExitSubtitle =>
      _string('trayMenuExitSubtitle', _fallback.trayMenuExitSubtitle);

  @override
  String get exitWithActiveDownloadsTitle => _string(
      'exitWithActiveDownloadsTitle', _fallback.exitWithActiveDownloadsTitle);

  @override
  String exitWithActiveDownloadsMessage(Object count) => _format(
      'exitWithActiveDownloadsMessage',
      {'count': count},
      _fallback.exitWithActiveDownloadsMessage(count));

  @override
  String get exitWithActiveDownloadsCancelButton => _string(
      'exitWithActiveDownloadsCancelButton',
      _fallback.exitWithActiveDownloadsCancelButton);

  @override
  String get exitWithActiveDownloadsConfirmButton => _string(
      'exitWithActiveDownloadsConfirmButton',
      _fallback.exitWithActiveDownloadsConfirmButton);

  @override
  String get tempFilesDialogTitle =>
      _string('tempFilesDialogTitle', _fallback.tempFilesDialogTitle);

  @override
  String tempFilesDialogScanPath(Object path) => _format(
      'tempFilesDialogScanPath',
      {'path': path},
      _fallback.tempFilesDialogScanPath(path));

  @override
  String get tempFilesStatFiles =>
      _string('tempFilesStatFiles', _fallback.tempFilesStatFiles);

  @override
  String get tempFilesStatTotalSize =>
      _string('tempFilesStatTotalSize', _fallback.tempFilesStatTotalSize);

  @override
  String get tempFilesStatSelected =>
      _string('tempFilesStatSelected', _fallback.tempFilesStatSelected);

  @override
  String get tempFilesSupportedFormats =>
      _string('tempFilesSupportedFormats', _fallback.tempFilesSupportedFormats);

  @override
  String get tempFilesSelectAll =>
      _string('tempFilesSelectAll', _fallback.tempFilesSelectAll);

  @override
  String get tempFilesIncludeTempDirs =>
      _string('tempFilesIncludeTempDirs', _fallback.tempFilesIncludeTempDirs);

  @override
  String get tempFilesSortLabel =>
      _string('tempFilesSortLabel', _fallback.tempFilesSortLabel);

  @override
  String get tempFilesSortName =>
      _string('tempFilesSortName', _fallback.tempFilesSortName);

  @override
  String get tempFilesSortSize =>
      _string('tempFilesSortSize', _fallback.tempFilesSortSize);

  @override
  String get tempFilesSortTime =>
      _string('tempFilesSortTime', _fallback.tempFilesSortTime);

  @override
  String get tempFilesEmpty =>
      _string('tempFilesEmpty', _fallback.tempFilesEmpty);

  @override
  String get tempFilesCloseButton =>
      _string('tempFilesCloseButton', _fallback.tempFilesCloseButton);

  @override
  String tempFilesDeleteSelected(Object count) => _format(
      'tempFilesDeleteSelected',
      {'count': count},
      _fallback.tempFilesDeleteSelected(count));

  @override
  String get tempFilesDeleteConfirmTitle => _string(
      'tempFilesDeleteConfirmTitle', _fallback.tempFilesDeleteConfirmTitle);

  @override
  String tempFilesDeleteConfirmMessage(Object count) => _format(
      'tempFilesDeleteConfirmMessage',
      {'count': count},
      _fallback.tempFilesDeleteConfirmMessage(count));

  @override
  String tempFilesDeleteTotalSize(Object size) => _format(
      'tempFilesDeleteTotalSize',
      {'size': size},
      _fallback.tempFilesDeleteTotalSize(size));

  @override
  String get tempFilesDeleteWarning =>
      _string('tempFilesDeleteWarning', _fallback.tempFilesDeleteWarning);

  @override
  String get tempFilesCancelButton =>
      _string('tempFilesCancelButton', _fallback.tempFilesCancelButton);

  @override
  String get tempFilesDeleteButton =>
      _string('tempFilesDeleteButton', _fallback.tempFilesDeleteButton);

  @override
  String get tempFilesDeleteDoneTitle =>
      _string('tempFilesDeleteDoneTitle', _fallback.tempFilesDeleteDoneTitle);

  @override
  String tempFilesDeleteDoneWithFailures(Object success, Object failed) =>
      _format(
          'tempFilesDeleteDoneWithFailures',
          {'success': success, 'failed': failed},
          _fallback.tempFilesDeleteDoneWithFailures(success, failed));

  @override
  String tempFilesDeleteDoneSuccess(Object success) => _format(
      'tempFilesDeleteDoneSuccess',
      {'success': success},
      _fallback.tempFilesDeleteDoneSuccess(success));

  @override
  String get homeNavDownloading =>
      _string('homeNavDownloading', _fallback.homeNavDownloading);

  @override
  String get homeNavCompleted =>
      _string('homeNavCompleted', _fallback.homeNavCompleted);

  @override
  String get homeNavLog => _string('homeNavLog', _fallback.homeNavLog);

  @override
  String get homeNavStatus => _string('homeNavStatus', _fallback.homeNavStatus);

  @override
  String get homeNavOnlineStats =>
      _string('homeNavOnlineStats', _fallback.homeNavOnlineStats);

  @override
  String get homeNavPerformance =>
      _string('homeNavPerformance', _fallback.homeNavPerformance);

  @override
  String get homeNavConnectionDebug =>
      _string('homeNavConnectionDebug', _fallback.homeNavConnectionDebug);

  @override
  String get homeNavSettings =>
      _string('homeNavSettings', _fallback.homeNavSettings);

  @override
  String get homeNavNotice => _string('homeNavNotice', _fallback.homeNavNotice);

  @override
  String get homeNavAbout => _string('homeNavAbout', _fallback.homeNavAbout);

  @override
  String get homeUpdateFoundTitle =>
      _string('homeUpdateFoundTitle', _fallback.homeUpdateFoundTitle);

  @override
  String homeUpdateFoundMessage(Object currentVersion, Object newVersion) =>
      _format(
          'homeUpdateFoundMessage',
          {'currentVersion': currentVersion, 'newVersion': newVersion},
          _fallback.homeUpdateFoundMessage(currentVersion, newVersion));

  @override
  String get homeKernelStartingTitle =>
      _string('homeKernelStartingTitle', _fallback.homeKernelStartingTitle);

  @override
  String get homeKernelStartingHint =>
      _string('homeKernelStartingHint', _fallback.homeKernelStartingHint);

  @override
  String get homeViewLog => _string('homeViewLog', _fallback.homeViewLog);

  @override
  String get homeRetry => _string('homeRetry', _fallback.homeRetry);

  @override
  String get homeNewTask => _string('homeNewTask', _fallback.homeNewTask);

  @override
  String get fileName => _string('fileName', _fallback.fileName);

  @override
  String get id => _string('id', _fallback.id);

  @override
  String get name => _string('name', _fallback.name);

  @override
  String get segments => _string('segments', _fallback.segments);

  @override
  String get speed => _string('speed', _fallback.speed);

  @override
  String get status => _string('status', _fallback.status);

  @override
  String get url => _string('url', _fallback.url);

  @override
  String get settingsSectionSystem =>
      _string('settingsSectionSystem', _fallback.settingsSectionSystem);

  @override
  String get settingsAutoStartTitle =>
      _string('settingsAutoStartTitle', _fallback.settingsAutoStartTitle);

  @override
  String get settingsAutoStartSubtitle =>
      _string('settingsAutoStartSubtitle', _fallback.settingsAutoStartSubtitle);

  @override
  String get settingsAutoStartEnabledTitle => _string(
      'settingsAutoStartEnabledTitle', _fallback.settingsAutoStartEnabledTitle);

  @override
  String get settingsAutoStartEnabledMessage => _string(
      'settingsAutoStartEnabledMessage',
      _fallback.settingsAutoStartEnabledMessage);

  @override
  String get settingsAutoStartDisabledTitle => _string(
      'settingsAutoStartDisabledTitle',
      _fallback.settingsAutoStartDisabledTitle);

  @override
  String get settingsAutoStartDisabledMessage => _string(
      'settingsAutoStartDisabledMessage',
      _fallback.settingsAutoStartDisabledMessage);

  @override
  String get settingsAutoStartEnableFailed => _string(
      'settingsAutoStartEnableFailed', _fallback.settingsAutoStartEnableFailed);

  @override
  String get settingsAutoStartDisableFailed => _string(
      'settingsAutoStartDisableFailed',
      _fallback.settingsAutoStartDisableFailed);

  @override
  String get settingsAutoStartFixedTitle => _string(
      'settingsAutoStartFixedTitle', _fallback.settingsAutoStartFixedTitle);

  @override
  String get settingsAutoStartFixedMessage => _string(
      'settingsAutoStartFixedMessage', _fallback.settingsAutoStartFixedMessage);

  @override
  String get settingsSectionBehavior =>
      _string('settingsSectionBehavior', _fallback.settingsSectionBehavior);

  @override
  String get settingsAutoDownloadTitle =>
      _string('settingsAutoDownloadTitle', _fallback.settingsAutoDownloadTitle);

  @override
  String get settingsAutoDownloadSubtitle => _string(
      'settingsAutoDownloadSubtitle', _fallback.settingsAutoDownloadSubtitle);

  @override
  String get settingsAutoDownloadEnabledTitle => _string(
      'settingsAutoDownloadEnabledTitle',
      _fallback.settingsAutoDownloadEnabledTitle);

  @override
  String get settingsAutoDownloadEnabledMessage => _string(
      'settingsAutoDownloadEnabledMessage',
      _fallback.settingsAutoDownloadEnabledMessage);

  @override
  String get settingsAutoDownloadDisabledTitle => _string(
      'settingsAutoDownloadDisabledTitle',
      _fallback.settingsAutoDownloadDisabledTitle);

  @override
  String get settingsAutoDownloadDisabledMessage => _string(
      'settingsAutoDownloadDisabledMessage',
      _fallback.settingsAutoDownloadDisabledMessage);

  @override
  String get settingsPopupWindowTitle =>
      _string('settingsPopupWindowTitle', _fallback.settingsPopupWindowTitle);

  @override
  String get settingsPopupWindowSubtitle => _string(
      'settingsPopupWindowSubtitle', _fallback.settingsPopupWindowSubtitle);

  @override
  String get settingsPopupEnabledTitle =>
      _string('settingsPopupEnabledTitle', _fallback.settingsPopupEnabledTitle);

  @override
  String get settingsPopupEnabledMessage => _string(
      'settingsPopupEnabledMessage', _fallback.settingsPopupEnabledMessage);

  @override
  String get settingsPopupDisabledTitle => _string(
      'settingsPopupDisabledTitle', _fallback.settingsPopupDisabledTitle);

  @override
  String get settingsPopupDisabledMessage => _string(
      'settingsPopupDisabledMessage', _fallback.settingsPopupDisabledMessage);

  @override
  String get settingsCompleteNotifyTitle => _string(
      'settingsCompleteNotifyTitle', _fallback.settingsCompleteNotifyTitle);

  @override
  String get settingsCompleteNotifySubtitle => _string(
      'settingsCompleteNotifySubtitle',
      _fallback.settingsCompleteNotifySubtitle);

  @override
  String get settingsCompleteNotifyEnabledTitle => _string(
      'settingsCompleteNotifyEnabledTitle',
      _fallback.settingsCompleteNotifyEnabledTitle);

  @override
  String get settingsCompleteNotifyEnabledMessage => _string(
      'settingsCompleteNotifyEnabledMessage',
      _fallback.settingsCompleteNotifyEnabledMessage);

  @override
  String get settingsCompleteNotifyDisabledTitle => _string(
      'settingsCompleteNotifyDisabledTitle',
      _fallback.settingsCompleteNotifyDisabledTitle);

  @override
  String get settingsCompleteNotifyDisabledMessage => _string(
      'settingsCompleteNotifyDisabledMessage',
      _fallback.settingsCompleteNotifyDisabledMessage);

  @override
  String get settingsOnlineStatsTitle =>
      _string('settingsOnlineStatsTitle', _fallback.settingsOnlineStatsTitle);

  @override
  String get settingsOnlineStatsSubtitle => _string(
      'settingsOnlineStatsSubtitle', _fallback.settingsOnlineStatsSubtitle);

  @override
  String get settingsOnlineStatsEnabledTitle => _string(
      'settingsOnlineStatsEnabledTitle',
      _fallback.settingsOnlineStatsEnabledTitle);

  @override
  String get settingsOnlineStatsEnabledMessage => _string(
      'settingsOnlineStatsEnabledMessage',
      _fallback.settingsOnlineStatsEnabledMessage);

  @override
  String get settingsOnlineStatsDisabledTitle => _string(
      'settingsOnlineStatsDisabledTitle',
      _fallback.settingsOnlineStatsDisabledTitle);

  @override
  String get settingsOnlineStatsDisabledMessage => _string(
      'settingsOnlineStatsDisabledMessage',
      _fallback.settingsOnlineStatsDisabledMessage);

  @override
  String get settingsTrayHintTitle =>
      _string('settingsTrayHintTitle', _fallback.settingsTrayHintTitle);

  @override
  String get settingsTrayHintSubtitle =>
      _string('settingsTrayHintSubtitle', _fallback.settingsTrayHintSubtitle);

  @override
  String get settingsTrayHintEnabledTitle => _string(
      'settingsTrayHintEnabledTitle', _fallback.settingsTrayHintEnabledTitle);

  @override
  String get settingsTrayHintEnabledMessage => _string(
      'settingsTrayHintEnabledMessage',
      _fallback.settingsTrayHintEnabledMessage);

  @override
  String get settingsTrayHintDisabledTitle => _string(
      'settingsTrayHintDisabledTitle', _fallback.settingsTrayHintDisabledTitle);

  @override
  String get settingsTrayHintDisabledMessage => _string(
      'settingsTrayHintDisabledMessage',
      _fallback.settingsTrayHintDisabledMessage);

  @override
  String get settingsCloseBehaviorTitle => _string(
      'settingsCloseBehaviorTitle', _fallback.settingsCloseBehaviorTitle);

  @override
  String get settingsCloseBehaviorMinimizeLabel => _string(
      'settingsCloseBehaviorMinimizeLabel',
      _fallback.settingsCloseBehaviorMinimizeLabel);

  @override
  String get settingsCloseBehaviorExitLabel => _string(
      'settingsCloseBehaviorExitLabel',
      _fallback.settingsCloseBehaviorExitLabel);

  @override
  String get settingsCloseBehaviorMinimize => _string(
      'settingsCloseBehaviorMinimize', _fallback.settingsCloseBehaviorMinimize);

  @override
  String get settingsCloseBehaviorExit =>
      _string('settingsCloseBehaviorExit', _fallback.settingsCloseBehaviorExit);

  @override
  String get settingsCloseBehaviorUnknown => _string(
      'settingsCloseBehaviorUnknown', _fallback.settingsCloseBehaviorUnknown);

  @override
  String settingsCloseBehaviorSavedMessage(Object behavior) => _format(
      'settingsCloseBehaviorSavedMessage',
      {'behavior': behavior},
      _fallback.settingsCloseBehaviorSavedMessage(behavior));

  @override
  String get settingsSaveSuccessTitle =>
      _string('settingsSaveSuccessTitle', _fallback.settingsSaveSuccessTitle);

  @override
  String get settingsSaveFailedTitle =>
      _string('settingsSaveFailedTitle', _fallback.settingsSaveFailedTitle);

  @override
  String settingsSaveFailedMessage(Object error) => _format(
      'settingsSaveFailedMessage',
      {'error': error},
      _fallback.settingsSaveFailedMessage(error));

  @override
  String get settingsBrowserExtensionPortTitle => _string(
      'settingsBrowserExtensionPortTitle',
      _fallback.settingsBrowserExtensionPortTitle);

  @override
  String settingsBrowserExtensionPortSubtitle(Object port) => _format(
      'settingsBrowserExtensionPortSubtitle',
      {'port': port},
      _fallback.settingsBrowserExtensionPortSubtitle(port));

  @override
  String get settingsBrowserExtensionPortChangeButton => _string(
      'settingsBrowserExtensionPortChangeButton',
      _fallback.settingsBrowserExtensionPortChangeButton);

  @override
  String get settingsBrowserExtensionPortDialogTitle => _string(
      'settingsBrowserExtensionPortDialogTitle',
      _fallback.settingsBrowserExtensionPortDialogTitle);

  @override
  String get settingsBrowserExtensionPortDialogPrompt => _string(
      'settingsBrowserExtensionPortDialogPrompt',
      _fallback.settingsBrowserExtensionPortDialogPrompt);

  @override
  String get settingsBrowserExtensionPortPlaceholder => _string(
      'settingsBrowserExtensionPortPlaceholder',
      _fallback.settingsBrowserExtensionPortPlaceholder);

  @override
  String get settingsBrowserExtensionPortHintBody => _string(
      'settingsBrowserExtensionPortHintBody',
      _fallback.settingsBrowserExtensionPortHintBody);

  @override
  String get settingsBrowserExtensionPortInvalidTitle => _string(
      'settingsBrowserExtensionPortInvalidTitle',
      _fallback.settingsBrowserExtensionPortInvalidTitle);

  @override
  String settingsBrowserExtensionPortInvalidMessage(Object min, Object max) =>
      _format(
          'settingsBrowserExtensionPortInvalidMessage',
          {'min': min, 'max': max},
          _fallback.settingsBrowserExtensionPortInvalidMessage(min, max));

  @override
  String settingsBrowserExtensionPortSavedMessage(Object port) => _format(
      'settingsBrowserExtensionPortSavedMessage',
      {'port': port},
      _fallback.settingsBrowserExtensionPortSavedMessage(port));

  @override
  String settingsBrowserExtensionPortSaveFailedMessage(Object error) => _format(
      'settingsBrowserExtensionPortSaveFailedMessage',
      {'error': error},
      _fallback.settingsBrowserExtensionPortSaveFailedMessage(error));

  @override
  String get settingsDownloadPathSection => _string(
      'settingsDownloadPathSection', _fallback.settingsDownloadPathSection);

  @override
  String get settingsDownloadPathTitle =>
      _string('settingsDownloadPathTitle', _fallback.settingsDownloadPathTitle);

  @override
  String get settingsDownloadPathChangeButton => _string(
      'settingsDownloadPathChangeButton',
      _fallback.settingsDownloadPathChangeButton);

  @override
  String get settingsDownloadPathDialogTitle => _string(
      'settingsDownloadPathDialogTitle',
      _fallback.settingsDownloadPathDialogTitle);

  @override
  String get settingsDownloadPathDialogPrompt => _string(
      'settingsDownloadPathDialogPrompt',
      _fallback.settingsDownloadPathDialogPrompt);

  @override
  String get settingsDownloadPathPlaceholder => _string(
      'settingsDownloadPathPlaceholder',
      _fallback.settingsDownloadPathPlaceholder);

  @override
  String get settingsBrowseButton =>
      _string('settingsBrowseButton', _fallback.settingsBrowseButton);

  @override
  String get settingsDownloadPathHintTitle => _string(
      'settingsDownloadPathHintTitle', _fallback.settingsDownloadPathHintTitle);

  @override
  String get settingsDownloadPathHintBody => _string(
      'settingsDownloadPathHintBody', _fallback.settingsDownloadPathHintBody);

  @override
  String get settingsCancelButton =>
      _string('settingsCancelButton', _fallback.settingsCancelButton);

  @override
  String get settingsConfirmButton =>
      _string('settingsConfirmButton', _fallback.settingsConfirmButton);

  @override
  String settingsDownloadPathChangedMessage(Object path) => _format(
      'settingsDownloadPathChangedMessage',
      {'path': path},
      _fallback.settingsDownloadPathChangedMessage(path));

  @override
  String get settingsDownloadPathChangeFailedMessage => _string(
      'settingsDownloadPathChangeFailedMessage',
      _fallback.settingsDownloadPathChangeFailedMessage);

  @override
  String get settingsDownloadConfigSection => _string(
      'settingsDownloadConfigSection', _fallback.settingsDownloadConfigSection);

  @override
  String get settingsDownloadModeTitle =>
      _string('settingsDownloadModeTitle', _fallback.settingsDownloadModeTitle);

  @override
  String get settingsDownloadModeAuto =>
      _string('settingsDownloadModeAuto', _fallback.settingsDownloadModeAuto);

  @override
  String get settingsDownloadModeThreadsOnly => _string(
      'settingsDownloadModeThreadsOnly',
      _fallback.settingsDownloadModeThreadsOnly);

  @override
  String get settingsDownloadModeSegmentsOnly => _string(
      'settingsDownloadModeSegmentsOnly',
      _fallback.settingsDownloadModeSegmentsOnly);

  @override
  String get settingsDownloadModeManual => _string(
      'settingsDownloadModeManual', _fallback.settingsDownloadModeManual);

  @override
  String get settingsThreadsTitle =>
      _string('settingsThreadsTitle', _fallback.settingsThreadsTitle);

  @override
  String get settingsThreadsSubtitle =>
      _string('settingsThreadsSubtitle', _fallback.settingsThreadsSubtitle);

  @override
  String get settingsSegmentsTitle =>
      _string('settingsSegmentsTitle', _fallback.settingsSegmentsTitle);

  @override
  String get settingsSegmentsSubtitle =>
      _string('settingsSegmentsSubtitle', _fallback.settingsSegmentsSubtitle);

  @override
  String get settingsDynamicSegmentsTitle => _string(
      'settingsDynamicSegmentsTitle', _fallback.settingsDynamicSegmentsTitle);

  @override
  String get settingsDynamicSegmentsSubtitle => _string(
      'settingsDynamicSegmentsSubtitle',
      _fallback.settingsDynamicSegmentsSubtitle);

  @override
  String get settingsDynamicSegmentsEnabledTitle => _string(
      'settingsDynamicSegmentsEnabledTitle',
      _fallback.settingsDynamicSegmentsEnabledTitle);

  @override
  String get settingsDynamicSegmentsEnabledMessage => _string(
      'settingsDynamicSegmentsEnabledMessage',
      _fallback.settingsDynamicSegmentsEnabledMessage);

  @override
  String get settingsDynamicSegmentsDisabledTitle => _string(
      'settingsDynamicSegmentsDisabledTitle',
      _fallback.settingsDynamicSegmentsDisabledTitle);

  @override
  String get settingsDynamicSegmentsDisabledMessage => _string(
      'settingsDynamicSegmentsDisabledMessage',
      _fallback.settingsDynamicSegmentsDisabledMessage);

  @override
  String get settingsMaxConcurrentTitle => _string(
      'settingsMaxConcurrentTitle', _fallback.settingsMaxConcurrentTitle);

  @override
  String get settingsMaxConcurrentSubtitle => _string(
      'settingsMaxConcurrentSubtitle', _fallback.settingsMaxConcurrentSubtitle);

  @override
  String get settingsSegmentSpeedLimitTitle => _string(
      'settingsSegmentSpeedLimitTitle',
      _fallback.settingsSegmentSpeedLimitTitle);

  @override
  String get settingsSegmentSpeedLimitSubtitle => _string(
      'settingsSegmentSpeedLimitSubtitle',
      _fallback.settingsSegmentSpeedLimitSubtitle);

  @override
  String get settingsGlobalSpeedLimitTitle => _string(
      'settingsGlobalSpeedLimitTitle', _fallback.settingsGlobalSpeedLimitTitle);

  @override
  String get settingsGlobalSpeedLimitSubtitle => _string(
      'settingsGlobalSpeedLimitSubtitle',
      _fallback.settingsGlobalSpeedLimitSubtitle);

  @override
  String get settingsHttpVersionTitle =>
      _string('settingsHttpVersionTitle', _fallback.settingsHttpVersionTitle);

  @override
  String get settingsHttpVersionSubtitle => _string(
      'settingsHttpVersionSubtitle', _fallback.settingsHttpVersionSubtitle);

  @override
  String get settingsHttpVersionAuto =>
      _string('settingsHttpVersionAuto', _fallback.settingsHttpVersionAuto);

  @override
  String get settingsHttpVersionHttp1Only => _string(
      'settingsHttpVersionHttp1Only', _fallback.settingsHttpVersionHttp1Only);

  @override
  String get settingsHttpVersionHttp2Only => _string(
      'settingsHttpVersionHttp2Only', _fallback.settingsHttpVersionHttp2Only);

  @override
  String get settingsHttpVersionHttp3Only => _string(
      'settingsHttpVersionHttp3Only', _fallback.settingsHttpVersionHttp3Only);

  @override
  String get settingsDownloadCardHttpBadgeTitle => _string(
      'settingsDownloadCardHttpBadgeTitle',
      _fallback.settingsDownloadCardHttpBadgeTitle);

  @override
  String get settingsDownloadCardHttpBadgeSubtitle => _string(
      'settingsDownloadCardHttpBadgeSubtitle',
      _fallback.settingsDownloadCardHttpBadgeSubtitle);

  @override
  String get settingsDefaultUserAgentTitle => _string(
      'settingsDefaultUserAgentTitle', _fallback.settingsDefaultUserAgentTitle);

  @override
  String get settingsDefaultUserAgentSubtitle => _string(
      'settingsDefaultUserAgentSubtitle',
      _fallback.settingsDefaultUserAgentSubtitle);

  @override
  String get settingsDefaultUserAgentPlaceholder => _string(
      'settingsDefaultUserAgentPlaceholder',
      _fallback.settingsDefaultUserAgentPlaceholder);

  @override
  String get settingsUaPresetTitle =>
      _string('settingsUaPresetTitle', _fallback.settingsUaPresetTitle);

  @override
  String get settingsUaPresetSubtitle =>
      _string('settingsUaPresetSubtitle', _fallback.settingsUaPresetSubtitle);

  @override
  String get settingsUaPresetManualOption => _string(
      'settingsUaPresetManualOption', _fallback.settingsUaPresetManualOption);

  @override
  String settingsUaPresetBuiltinOption(Object name) => _format(
      'settingsUaPresetBuiltinOption',
      {'name': name},
      _fallback.settingsUaPresetBuiltinOption(name));

  @override
  String settingsUaPresetCustomOption(Object name) => _format(
      'settingsUaPresetCustomOption',
      {'name': name},
      _fallback.settingsUaPresetCustomOption(name));

  @override
  String get settingsUaCustomCreateTitle => _string(
      'settingsUaCustomCreateTitle', _fallback.settingsUaCustomCreateTitle);

  @override
  String get settingsUaCustomCreateSubtitle => _string(
      'settingsUaCustomCreateSubtitle',
      _fallback.settingsUaCustomCreateSubtitle);

  @override
  String get settingsUaCustomNamePlaceholder => _string(
      'settingsUaCustomNamePlaceholder',
      _fallback.settingsUaCustomNamePlaceholder);

  @override
  String get settingsUaCustomValuePlaceholder => _string(
      'settingsUaCustomValuePlaceholder',
      _fallback.settingsUaCustomValuePlaceholder);

  @override
  String get settingsUaCustomAddButton =>
      _string('settingsUaCustomAddButton', _fallback.settingsUaCustomAddButton);

  @override
  String get settingsUaCustomListTitle =>
      _string('settingsUaCustomListTitle', _fallback.settingsUaCustomListTitle);

  @override
  String get settingsUaCustomListEmpty =>
      _string('settingsUaCustomListEmpty', _fallback.settingsUaCustomListEmpty);

  @override
  String settingsUaCustomListCount(Object count) => _format(
      'settingsUaCustomListCount',
      {'count': count},
      _fallback.settingsUaCustomListCount(count));

  @override
  String get settingsUaCustomListHint =>
      _string('settingsUaCustomListHint', _fallback.settingsUaCustomListHint);

  @override
  String get settingsUaCustomEnabledButton => _string(
      'settingsUaCustomEnabledButton', _fallback.settingsUaCustomEnabledButton);

  @override
  String get settingsUaCustomApplyButton => _string(
      'settingsUaCustomApplyButton', _fallback.settingsUaCustomApplyButton);

  @override
  String get settingsSpeedUnlimited =>
      _string('settingsSpeedUnlimited', _fallback.settingsSpeedUnlimited);

  @override
  String settingsSpeedTotal(Object speed) => _format('settingsSpeedTotal',
      {'speed': speed}, _fallback.settingsSpeedTotal(speed));

  @override
  String settingsPopupSaveFailedMessage(Object error) => _format(
      'settingsPopupSaveFailedMessage',
      {'error': error},
      _fallback.settingsPopupSaveFailedMessage(error));

  @override
  String get settingsProxySection =>
      _string('settingsProxySection', _fallback.settingsProxySection);

  @override
  String get settingsProxyEnableTitle =>
      _string('settingsProxyEnableTitle', _fallback.settingsProxyEnableTitle);

  @override
  String get settingsProxyEnableSubtitle => _string(
      'settingsProxyEnableSubtitle', _fallback.settingsProxyEnableSubtitle);

  @override
  String get settingsProxySavedTitle =>
      _string('settingsProxySavedTitle', _fallback.settingsProxySavedTitle);

  @override
  String settingsProxyEnabledMessage(Object host, Object port) => _format(
      'settingsProxyEnabledMessage',
      {'host': host, 'port': port},
      _fallback.settingsProxyEnabledMessage(host, port));

  @override
  String get settingsProxyEnabledSystemMessage => _string(
      'settingsProxyEnabledSystemMessage',
      _fallback.settingsProxyEnabledSystemMessage);

  @override
  String get settingsProxyDisabledMessage => _string(
      'settingsProxyDisabledMessage', _fallback.settingsProxyDisabledMessage);

  @override
  String get settingsProxyTypeTitle =>
      _string('settingsProxyTypeTitle', _fallback.settingsProxyTypeTitle);

  @override
  String get settingsProxyTypeSubtitle =>
      _string('settingsProxyTypeSubtitle', _fallback.settingsProxyTypeSubtitle);

  @override
  String get settingsProxyTypeSystem =>
      _string('settingsProxyTypeSystem', _fallback.settingsProxyTypeSystem);

  @override
  String get settingsProxyTypeHttp =>
      _string('settingsProxyTypeHttp', _fallback.settingsProxyTypeHttp);

  @override
  String get settingsProxyTypeSocks5 =>
      _string('settingsProxyTypeSocks5', _fallback.settingsProxyTypeSocks5);

  @override
  String get settingsProxyServerTitle =>
      _string('settingsProxyServerTitle', _fallback.settingsProxyServerTitle);

  @override
  String get settingsProxyServerSubtitle => _string(
      'settingsProxyServerSubtitle', _fallback.settingsProxyServerSubtitle);

  @override
  String get settingsProxyHostPlaceholder => _string(
      'settingsProxyHostPlaceholder', _fallback.settingsProxyHostPlaceholder);

  @override
  String get settingsProxyAuthTitle =>
      _string('settingsProxyAuthTitle', _fallback.settingsProxyAuthTitle);

  @override
  String get settingsProxyAuthSubtitle =>
      _string('settingsProxyAuthSubtitle', _fallback.settingsProxyAuthSubtitle);

  @override
  String get settingsProxyUsernameTitle => _string(
      'settingsProxyUsernameTitle', _fallback.settingsProxyUsernameTitle);

  @override
  String get settingsProxyUsernameSubtitle => _string(
      'settingsProxyUsernameSubtitle', _fallback.settingsProxyUsernameSubtitle);

  @override
  String get settingsProxyUsernamePlaceholder => _string(
      'settingsProxyUsernamePlaceholder',
      _fallback.settingsProxyUsernamePlaceholder);

  @override
  String get settingsProxyPasswordTitle => _string(
      'settingsProxyPasswordTitle', _fallback.settingsProxyPasswordTitle);

  @override
  String get settingsProxyPasswordSubtitle => _string(
      'settingsProxyPasswordSubtitle', _fallback.settingsProxyPasswordSubtitle);

  @override
  String get settingsProxyPasswordPlaceholder => _string(
      'settingsProxyPasswordPlaceholder',
      _fallback.settingsProxyPasswordPlaceholder);

  @override
  String get settingsProxyTipsTitle =>
      _string('settingsProxyTipsTitle', _fallback.settingsProxyTipsTitle);

  @override
  String get settingsProxyTipsSystem =>
      _string('settingsProxyTipsSystem', _fallback.settingsProxyTipsSystem);

  @override
  String get settingsProxyTipsHttp =>
      _string('settingsProxyTipsHttp', _fallback.settingsProxyTipsHttp);

  @override
  String get settingsProxyTipsSocks5 =>
      _string('settingsProxyTipsSocks5', _fallback.settingsProxyTipsSocks5);

  @override
  String get settingsProxyTipsDefault =>
      _string('settingsProxyTipsDefault', _fallback.settingsProxyTipsDefault);

  @override
  String get settingsProxyTestButton =>
      _string('settingsProxyTestButton', _fallback.settingsProxyTestButton);

  @override
  String get settingsProxyTestingTitle =>
      _string('settingsProxyTestingTitle', _fallback.settingsProxyTestingTitle);

  @override
  String get settingsProxyTestingMessage => _string(
      'settingsProxyTestingMessage', _fallback.settingsProxyTestingMessage);

  @override
  String get settingsProxyTestSuccessTitle => _string(
      'settingsProxyTestSuccessTitle', _fallback.settingsProxyTestSuccessTitle);

  @override
  String get settingsProxyTestSuccessMessage => _string(
      'settingsProxyTestSuccessMessage',
      _fallback.settingsProxyTestSuccessMessage);

  @override
  String get settingsProxyTestFailedTitle => _string(
      'settingsProxyTestFailedTitle', _fallback.settingsProxyTestFailedTitle);

  @override
  String get settingsProxyTestFailedMessage => _string(
      'settingsProxyTestFailedMessage',
      _fallback.settingsProxyTestFailedMessage);

  @override
  String get settingsProxyTestErrorTitle => _string(
      'settingsProxyTestErrorTitle', _fallback.settingsProxyTestErrorTitle);

  @override
  String settingsProxyTestErrorMessage(Object error) => _format(
      'settingsProxyTestErrorMessage',
      {'error': error},
      _fallback.settingsProxyTestErrorMessage(error));

  @override
  String get settingsProxyErrorTitle =>
      _string('settingsProxyErrorTitle', _fallback.settingsProxyErrorTitle);

  @override
  String get settingsProxyErrorMessage =>
      _string('settingsProxyErrorMessage', _fallback.settingsProxyErrorMessage);

  @override
  String get settingsKernelSection =>
      _string('settingsKernelSection', _fallback.settingsKernelSection);

  @override
  String get settingsKernelCurrentTitle => _string(
      'settingsKernelCurrentTitle', _fallback.settingsKernelCurrentTitle);

  @override
  String get settingsKernelOnline =>
      _string('settingsKernelOnline', _fallback.settingsKernelOnline);

  @override
  String get settingsKernelOffline =>
      _string('settingsKernelOffline', _fallback.settingsKernelOffline);

  @override
  String get settingsKernelNsfxTitle =>
      _string('settingsKernelNsfxTitle', _fallback.settingsKernelNsfxTitle);

  @override
  String get settingsKernelNsfxSubtitle => _string(
      'settingsKernelNsfxSubtitle', _fallback.settingsKernelNsfxSubtitle);

  @override
  String get settingsKernelNsfxHint =>
      _string('settingsKernelNsfxHint', _fallback.settingsKernelNsfxHint);

  @override
  String get settingsKernelSwitchedTitle => _string(
      'settingsKernelSwitchedTitle', _fallback.settingsKernelSwitchedTitle);

  @override
  String settingsKernelSwitchedMessage(Object kernelName) => _format(
      'settingsKernelSwitchedMessage',
      {'kernelName': kernelName},
      _fallback.settingsKernelSwitchedMessage(kernelName));

  @override
  String get settingsKernelSwitchFailedTitle => _string(
      'settingsKernelSwitchFailedTitle',
      _fallback.settingsKernelSwitchFailedTitle);

  @override
  String get settingsKernelSwitchFailedNewMessage => _string(
      'settingsKernelSwitchFailedNewMessage',
      _fallback.settingsKernelSwitchFailedNewMessage);

  @override
  String get settingsStatusTitle =>
      _string('settingsStatusTitle', _fallback.settingsStatusTitle);

  @override
  String get settingsStatusKernelNsfx =>
      _string('settingsStatusKernelNsfx', _fallback.settingsStatusKernelNsfx);

  @override
  String get settingsStatusBrowserExtension => _string(
      'settingsStatusBrowserExtension',
      _fallback.settingsStatusBrowserExtension);

  @override
  String get settingsModeDescriptionAuto => _string(
      'settingsModeDescriptionAuto', _fallback.settingsModeDescriptionAuto);

  @override
  String get settingsModeDescriptionThreadsOnly => _string(
      'settingsModeDescriptionThreadsOnly',
      _fallback.settingsModeDescriptionThreadsOnly);

  @override
  String get settingsModeDescriptionSegmentsOnly => _string(
      'settingsModeDescriptionSegmentsOnly',
      _fallback.settingsModeDescriptionSegmentsOnly);

  @override
  String get settingsModeDescriptionManual => _string(
      'settingsModeDescriptionManual', _fallback.settingsModeDescriptionManual);

  @override
  String get settingsModeDescriptionUnknown => _string(
      'settingsModeDescriptionUnknown',
      _fallback.settingsModeDescriptionUnknown);

  @override
  String get settingsDeveloperSection =>
      _string('settingsDeveloperSection', _fallback.settingsDeveloperSection);

  @override
  String get settingsDeveloperModeTitle => _string(
      'settingsDeveloperModeTitle', _fallback.settingsDeveloperModeTitle);

  @override
  String get settingsDeveloperModeSubtitle => _string(
      'settingsDeveloperModeSubtitle', _fallback.settingsDeveloperModeSubtitle);

  @override
  String get settingsDeveloperModeHint =>
      _string('settingsDeveloperModeHint', _fallback.settingsDeveloperModeHint);

  @override
  String get settingsDeveloperModeEnabledTitle => _string(
      'settingsDeveloperModeEnabledTitle',
      _fallback.settingsDeveloperModeEnabledTitle);

  @override
  String get settingsDeveloperModeEnabledMessage => _string(
      'settingsDeveloperModeEnabledMessage',
      _fallback.settingsDeveloperModeEnabledMessage);

  @override
  String get settingsDeveloperModeDisabledTitle => _string(
      'settingsDeveloperModeDisabledTitle',
      _fallback.settingsDeveloperModeDisabledTitle);

  @override
  String get settingsDeveloperModeDisabledMessage => _string(
      'settingsDeveloperModeDisabledMessage',
      _fallback.settingsDeveloperModeDisabledMessage);

  @override
  String get settingsDeveloperPageVisibilityTitle => _string(
      'settingsDeveloperPageVisibilityTitle',
      _fallback.settingsDeveloperPageVisibilityTitle);

  @override
  String get settingsDeveloperShowLogTitle => _string(
      'settingsDeveloperShowLogTitle', _fallback.settingsDeveloperShowLogTitle);

  @override
  String get settingsDeveloperShowLogSubtitle => _string(
      'settingsDeveloperShowLogSubtitle',
      _fallback.settingsDeveloperShowLogSubtitle);

  @override
  String get settingsDeveloperShowStatusTitle => _string(
      'settingsDeveloperShowStatusTitle',
      _fallback.settingsDeveloperShowStatusTitle);

  @override
  String get settingsDeveloperShowStatusSubtitle => _string(
      'settingsDeveloperShowStatusSubtitle',
      _fallback.settingsDeveloperShowStatusSubtitle);

  @override
  String get settingsDeveloperShowOnlineStatsTitle => _string(
      'settingsDeveloperShowOnlineStatsTitle',
      _fallback.settingsDeveloperShowOnlineStatsTitle);

  @override
  String get settingsDeveloperShowOnlineStatsSubtitle => _string(
      'settingsDeveloperShowOnlineStatsSubtitle',
      _fallback.settingsDeveloperShowOnlineStatsSubtitle);

  @override
  String get settingsDeveloperShowConnectionDebugTitle => _string(
      'settingsDeveloperShowConnectionDebugTitle',
      _fallback.settingsDeveloperShowConnectionDebugTitle);

  @override
  String get settingsDeveloperShowConnectionDebugSubtitle => _string(
      'settingsDeveloperShowConnectionDebugSubtitle',
      _fallback.settingsDeveloperShowConnectionDebugSubtitle);

  @override
  String get settingsDeveloperPageHint =>
      _string('settingsDeveloperPageHint', _fallback.settingsDeveloperPageHint);

  @override
  String get settingsDangerCleanTempTitle => _string(
      'settingsDangerCleanTempTitle', _fallback.settingsDangerCleanTempTitle);

  @override
  String get settingsDangerCleanTempSubtitle => _string(
      'settingsDangerCleanTempSubtitle',
      _fallback.settingsDangerCleanTempSubtitle);

  @override
  String get settingsDangerCleanTempButton => _string(
      'settingsDangerCleanTempButton', _fallback.settingsDangerCleanTempButton);

  @override
  String get settingsDangerClearDataTitle => _string(
      'settingsDangerClearDataTitle', _fallback.settingsDangerClearDataTitle);

  @override
  String get settingsDangerClearDataSubtitle => _string(
      'settingsDangerClearDataSubtitle',
      _fallback.settingsDangerClearDataSubtitle);

  @override
  String get settingsDangerClearDataButton => _string(
      'settingsDangerClearDataButton', _fallback.settingsDangerClearDataButton);

  @override
  String get settingsDangerConfirmTitle => _string(
      'settingsDangerConfirmTitle', _fallback.settingsDangerConfirmTitle);

  @override
  String get settingsDangerConfirmMessage => _string(
      'settingsDangerConfirmMessage', _fallback.settingsDangerConfirmMessage);

  @override
  String get settingsDangerConfirmButton => _string(
      'settingsDangerConfirmButton', _fallback.settingsDangerConfirmButton);

  @override
  String get settingsDangerClearingTitle => _string(
      'settingsDangerClearingTitle', _fallback.settingsDangerClearingTitle);

  @override
  String get settingsDangerClearingMessage => _string(
      'settingsDangerClearingMessage', _fallback.settingsDangerClearingMessage);

  @override
  String get settingsDangerClearedTitle => _string(
      'settingsDangerClearedTitle', _fallback.settingsDangerClearedTitle);

  @override
  String get settingsDangerClearedMessage => _string(
      'settingsDangerClearedMessage', _fallback.settingsDangerClearedMessage);

  @override
  String get settingsDangerClearFailedTitle => _string(
      'settingsDangerClearFailedTitle',
      _fallback.settingsDangerClearFailedTitle);

  @override
  String get settingsDangerClearFailedMessage => _string(
      'settingsDangerClearFailedMessage',
      _fallback.settingsDangerClearFailedMessage);

  @override
  String get settingsUserLoading =>
      _string('settingsUserLoading', _fallback.settingsUserLoading);

  @override
  String get settingsUserLoadFailed =>
      _string('settingsUserLoadFailed', _fallback.settingsUserLoadFailed);

  @override
  String get settingsUserUnknown =>
      _string('settingsUserUnknown', _fallback.settingsUserUnknown);

  @override
  String get appearanceWindowSizeSection => _string(
      'appearanceWindowSizeSection', _fallback.appearanceWindowSizeSection);

  @override
  String get appearanceWindowRememberTitle => _string(
      'appearanceWindowRememberTitle', _fallback.appearanceWindowRememberTitle);

  @override
  String get appearanceWindowRememberSubtitleOn => _string(
      'appearanceWindowRememberSubtitleOn',
      _fallback.appearanceWindowRememberSubtitleOn);

  @override
  String get appearanceWindowRememberSubtitleOff => _string(
      'appearanceWindowRememberSubtitleOff',
      _fallback.appearanceWindowRememberSubtitleOff);

  @override
  String get appearanceWindowDefaultWidthTitle => _string(
      'appearanceWindowDefaultWidthTitle',
      _fallback.appearanceWindowDefaultWidthTitle);

  @override
  String appearanceWindowDefaultWidthSubtitle(Object max) => _format(
      'appearanceWindowDefaultWidthSubtitle',
      {'max': max},
      _fallback.appearanceWindowDefaultWidthSubtitle(max));

  @override
  String get appearanceWindowDefaultHeightTitle => _string(
      'appearanceWindowDefaultHeightTitle',
      _fallback.appearanceWindowDefaultHeightTitle);

  @override
  String appearanceWindowDefaultHeightSubtitle(Object max) => _format(
      'appearanceWindowDefaultHeightSubtitle',
      {'max': max},
      _fallback.appearanceWindowDefaultHeightSubtitle(max));

  @override
  String get appearanceWindowSaveTitle =>
      _string('appearanceWindowSaveTitle', _fallback.appearanceWindowSaveTitle);

  @override
  String appearanceWindowSaveMessage(Object width, Object height) => _format(
      'appearanceWindowSaveMessage',
      {'width': width, 'height': height},
      _fallback.appearanceWindowSaveMessage(width, height));

  @override
  String appearanceWindowSaveButton(Object width, Object height) => _format(
      'appearanceWindowSaveButton',
      {'width': width, 'height': height},
      _fallback.appearanceWindowSaveButton(width, height));

  @override
  String get appearanceWindowResetTitle => _string(
      'appearanceWindowResetTitle', _fallback.appearanceWindowResetTitle);

  @override
  String get appearanceWindowResetMessage => _string(
      'appearanceWindowResetMessage', _fallback.appearanceWindowResetMessage);

  @override
  String get appearanceWindowResetButton => _string(
      'appearanceWindowResetButton', _fallback.appearanceWindowResetButton);

  @override
  String get appearanceWindowApplyTitle => _string(
      'appearanceWindowApplyTitle', _fallback.appearanceWindowApplyTitle);

  @override
  String appearanceWindowApplyMessage(Object width, Object height) => _format(
      'appearanceWindowApplyMessage',
      {'width': width, 'height': height},
      _fallback.appearanceWindowApplyMessage(width, height));

  @override
  String appearanceWindowApplyButton(Object width, Object height) => _format(
      'appearanceWindowApplyButton',
      {'width': width, 'height': height},
      _fallback.appearanceWindowApplyButton(width, height));

  @override
  String get appearanceWindowRememberHintOn => _string(
      'appearanceWindowRememberHintOn',
      _fallback.appearanceWindowRememberHintOn);

  @override
  String get appearanceWindowRememberHintOff => _string(
      'appearanceWindowRememberHintOff',
      _fallback.appearanceWindowRememberHintOff);

  @override
  String get appearanceUiScaleSection =>
      _string('appearanceUiScaleSection', _fallback.appearanceUiScaleSection);

  @override
  String get appearanceUiScaleTitle =>
      _string('appearanceUiScaleTitle', _fallback.appearanceUiScaleTitle);

  @override
  String get appearanceUiScaleSubtitle =>
      _string('appearanceUiScaleSubtitle', _fallback.appearanceUiScaleSubtitle);

  @override
  String get appearanceUiScaleResetTitle => _string(
      'appearanceUiScaleResetTitle', _fallback.appearanceUiScaleResetTitle);

  @override
  String get appearanceUiScaleResetMessage => _string(
      'appearanceUiScaleResetMessage', _fallback.appearanceUiScaleResetMessage);

  @override
  String get appearanceUiScaleResetButton => _string(
      'appearanceUiScaleResetButton', _fallback.appearanceUiScaleResetButton);

  @override
  String get appearanceUiScaleApplyTitle => _string(
      'appearanceUiScaleApplyTitle', _fallback.appearanceUiScaleApplyTitle);

  @override
  String get appearanceUiScaleApplyMessage => _string(
      'appearanceUiScaleApplyMessage', _fallback.appearanceUiScaleApplyMessage);

  @override
  String get appearanceUiScale4kButton =>
      _string('appearanceUiScale4kButton', _fallback.appearanceUiScale4kButton);

  @override
  String get appearanceUiScaleHint =>
      _string('appearanceUiScaleHint', _fallback.appearanceUiScaleHint);

  @override
  String get appearanceFontSection =>
      _string('appearanceFontSection', _fallback.appearanceFontSection);

  @override
  String get appearanceFontTitle =>
      _string('appearanceFontTitle', _fallback.appearanceFontTitle);

  @override
  String get appearanceFontSystemSubtitle => _string(
      'appearanceFontSystemSubtitle', _fallback.appearanceFontSystemSubtitle);

  @override
  String appearanceFontCurrentSubtitle(Object font) => _format(
      'appearanceFontCurrentSubtitle',
      {'font': font},
      _fallback.appearanceFontCurrentSubtitle(font));

  @override
  String get appearanceFontSystemLabel =>
      _string('appearanceFontSystemLabel', _fallback.appearanceFontSystemLabel);

  @override
  String get appearanceFontImportButton => _string(
      'appearanceFontImportButton', _fallback.appearanceFontImportButton);

  @override
  String get appearanceFontDeleteButton => _string(
      'appearanceFontDeleteButton', _fallback.appearanceFontDeleteButton);

  @override
  String get appearanceFontHint =>
      _string('appearanceFontHint', _fallback.appearanceFontHint);

  @override
  String get appearanceFontChangedTitle => _string(
      'appearanceFontChangedTitle', _fallback.appearanceFontChangedTitle);

  @override
  String get appearanceFontChangedMessage => _string(
      'appearanceFontChangedMessage', _fallback.appearanceFontChangedMessage);

  @override
  String get appearanceFontImportDialogTitle => _string(
      'appearanceFontImportDialogTitle',
      _fallback.appearanceFontImportDialogTitle);

  @override
  String get appearanceFontImportingTitle => _string(
      'appearanceFontImportingTitle', _fallback.appearanceFontImportingTitle);

  @override
  String get appearanceFontImportingMessage => _string(
      'appearanceFontImportingMessage',
      _fallback.appearanceFontImportingMessage);

  @override
  String get appearanceFontImportSuccessTitle => _string(
      'appearanceFontImportSuccessTitle',
      _fallback.appearanceFontImportSuccessTitle);

  @override
  String get appearanceFontImportSuccessMessage => _string(
      'appearanceFontImportSuccessMessage',
      _fallback.appearanceFontImportSuccessMessage);

  @override
  String get appearanceFontImportFailedTitle => _string(
      'appearanceFontImportFailedTitle',
      _fallback.appearanceFontImportFailedTitle);

  @override
  String get appearanceFontImportFailedMessage => _string(
      'appearanceFontImportFailedMessage',
      _fallback.appearanceFontImportFailedMessage);

  @override
  String appearanceFontImportFailedWithErrorMessage(Object error) => _format(
      'appearanceFontImportFailedWithErrorMessage',
      {'error': error},
      _fallback.appearanceFontImportFailedWithErrorMessage(error));

  @override
  String get appearanceFontDeleteConfirmTitle => _string(
      'appearanceFontDeleteConfirmTitle',
      _fallback.appearanceFontDeleteConfirmTitle);

  @override
  String appearanceFontDeleteConfirmMessage(Object fontName) => _format(
      'appearanceFontDeleteConfirmMessage',
      {'fontName': fontName},
      _fallback.appearanceFontDeleteConfirmMessage(fontName));

  @override
  String get appearanceFontDeleteCancelButton => _string(
      'appearanceFontDeleteCancelButton',
      _fallback.appearanceFontDeleteCancelButton);

  @override
  String get appearanceFontDeleteConfirmButton => _string(
      'appearanceFontDeleteConfirmButton',
      _fallback.appearanceFontDeleteConfirmButton);

  @override
  String get appearanceFontDeleteSuccessTitle => _string(
      'appearanceFontDeleteSuccessTitle',
      _fallback.appearanceFontDeleteSuccessTitle);

  @override
  String get appearanceFontDeleteSuccessMessage => _string(
      'appearanceFontDeleteSuccessMessage',
      _fallback.appearanceFontDeleteSuccessMessage);

  @override
  String get appearanceFontDeleteFailedTitle => _string(
      'appearanceFontDeleteFailedTitle',
      _fallback.appearanceFontDeleteFailedTitle);

  @override
  String get appearanceFontDeleteFailedMessage => _string(
      'appearanceFontDeleteFailedMessage',
      _fallback.appearanceFontDeleteFailedMessage);

  @override
  String get appearanceFontPickerTitle =>
      _string('appearanceFontPickerTitle', _fallback.appearanceFontPickerTitle);

  @override
  String get appearanceFontPickerSearchPlaceholder => _string(
      'appearanceFontPickerSearchPlaceholder',
      _fallback.appearanceFontPickerSearchPlaceholder);

  @override
  String appearanceFontPickerCount(Object count) => _format(
      'appearanceFontPickerCount',
      {'count': count},
      _fallback.appearanceFontPickerCount(count));

  @override
  String get appearanceFontPickerFilteredLabel => _string(
      'appearanceFontPickerFilteredLabel',
      _fallback.appearanceFontPickerFilteredLabel);

  @override
  String get appearanceFontPickerEmpty =>
      _string('appearanceFontPickerEmpty', _fallback.appearanceFontPickerEmpty);

  @override
  String get appearanceFontPickerRecommended => _string(
      'appearanceFontPickerRecommended',
      _fallback.appearanceFontPickerRecommended);

  @override
  String get appearanceFontPickerCancel => _string(
      'appearanceFontPickerCancel', _fallback.appearanceFontPickerCancel);

  @override
  String get appearanceWindowEffectsSection => _string(
      'appearanceWindowEffectsSection',
      _fallback.appearanceWindowEffectsSection);

  @override
  String get appearanceWindowEffectsEnableTitle => _string(
      'appearanceWindowEffectsEnableTitle',
      _fallback.appearanceWindowEffectsEnableTitle);

  @override
  String get appearanceWindowEffectsEnabledSubtitle => _string(
      'appearanceWindowEffectsEnabledSubtitle',
      _fallback.appearanceWindowEffectsEnabledSubtitle);

  @override
  String get appearanceWindowEffectsDisabledSubtitle => _string(
      'appearanceWindowEffectsDisabledSubtitle',
      _fallback.appearanceWindowEffectsDisabledSubtitle);

  @override
  String get appearanceWindowEffectsEnabledTitle => _string(
      'appearanceWindowEffectsEnabledTitle',
      _fallback.appearanceWindowEffectsEnabledTitle);

  @override
  String get appearanceWindowEffectsDisabledTitle => _string(
      'appearanceWindowEffectsDisabledTitle',
      _fallback.appearanceWindowEffectsDisabledTitle);

  @override
  String get appearanceWindowEffectsEnabledMessage => _string(
      'appearanceWindowEffectsEnabledMessage',
      _fallback.appearanceWindowEffectsEnabledMessage);

  @override
  String get appearanceWindowEffectsDisabledMessage => _string(
      'appearanceWindowEffectsDisabledMessage',
      _fallback.appearanceWindowEffectsDisabledMessage);

  @override
  String get appearanceWindowEffectsTypeTitle => _string(
      'appearanceWindowEffectsTypeTitle',
      _fallback.appearanceWindowEffectsTypeTitle);

  @override
  String get appearanceWindowEffectSwitchedTitle => _string(
      'appearanceWindowEffectSwitchedTitle',
      _fallback.appearanceWindowEffectSwitchedTitle);

  @override
  String get appearanceWindowEffectAcrylic => _string(
      'appearanceWindowEffectAcrylic', _fallback.appearanceWindowEffectAcrylic);

  @override
  String get appearanceWindowEffectBlur => _string(
      'appearanceWindowEffectBlur', _fallback.appearanceWindowEffectBlur);

  @override
  String get appearanceWindowEffectMica => _string(
      'appearanceWindowEffectMica', _fallback.appearanceWindowEffectMica);

  @override
  String get appearanceWindowEffectMicaAlt => _string(
      'appearanceWindowEffectMicaAlt', _fallback.appearanceWindowEffectMicaAlt);

  @override
  String get appearanceWindowEffectsAcrylicOpacityTitle => _string(
      'appearanceWindowEffectsAcrylicOpacityTitle',
      _fallback.appearanceWindowEffectsAcrylicOpacityTitle);

  @override
  String get appearanceWindowEffectsAcrylicOpacityHint => _string(
      'appearanceWindowEffectsAcrylicOpacityHint',
      _fallback.appearanceWindowEffectsAcrylicOpacityHint);

  @override
  String get appearanceWindowEffectsAcrylicOpacityMicaHint => _string(
      'appearanceWindowEffectsAcrylicOpacityMicaHint',
      _fallback.appearanceWindowEffectsAcrylicOpacityMicaHint);

  @override
  String get appearanceWindowEffectsDragSuspendTitle => _string(
      'appearanceWindowEffectsDragSuspendTitle',
      _fallback.appearanceWindowEffectsDragSuspendTitle);

  @override
  String get appearanceWindowEffectsDragSuspendEnabledSubtitle => _string(
      'appearanceWindowEffectsDragSuspendEnabledSubtitle',
      _fallback.appearanceWindowEffectsDragSuspendEnabledSubtitle);

  @override
  String get appearanceWindowEffectsDragSuspendDisabledSubtitle => _string(
      'appearanceWindowEffectsDragSuspendDisabledSubtitle',
      _fallback.appearanceWindowEffectsDragSuspendDisabledSubtitle);

  @override
  String get appearanceWindowEffectsRoundedCornersTitle => _string(
      'appearanceWindowEffectsRoundedCornersTitle',
      _fallback.appearanceWindowEffectsRoundedCornersTitle);

  @override
  String get appearanceWindowEffectsRoundedCornersEnabledSubtitle => _string(
      'appearanceWindowEffectsRoundedCornersEnabledSubtitle',
      _fallback.appearanceWindowEffectsRoundedCornersEnabledSubtitle);

  @override
  String get appearanceWindowEffectsRoundedCornersDisabledSubtitle => _string(
      'appearanceWindowEffectsRoundedCornersDisabledSubtitle',
      _fallback.appearanceWindowEffectsRoundedCornersDisabledSubtitle);

  @override
  String get appearanceWindowEffectsMicaHint => _string(
      'appearanceWindowEffectsMicaHint',
      _fallback.appearanceWindowEffectsMicaHint);

  @override
  String get appearanceWindowEffectsAcrylicHint => _string(
      'appearanceWindowEffectsAcrylicHint',
      _fallback.appearanceWindowEffectsAcrylicHint);

  @override
  String get appearanceWindowEffectsDisabledHint => _string(
      'appearanceWindowEffectsDisabledHint',
      _fallback.appearanceWindowEffectsDisabledHint);

  @override
  String get appearanceEffectNone =>
      _string('appearanceEffectNone', _fallback.appearanceEffectNone);

  @override
  String get appearanceEffectBlur =>
      _string('appearanceEffectBlur', _fallback.appearanceEffectBlur);

  @override
  String get appearanceEffectAcrylic =>
      _string('appearanceEffectAcrylic', _fallback.appearanceEffectAcrylic);

  @override
  String get appearanceEffectMica =>
      _string('appearanceEffectMica', _fallback.appearanceEffectMica);

  @override
  String get appearanceEffectMicaAlt =>
      _string('appearanceEffectMicaAlt', _fallback.appearanceEffectMicaAlt);

  @override
  String get appearanceEffectUnknown =>
      _string('appearanceEffectUnknown', _fallback.appearanceEffectUnknown);

  @override
  String get appearanceSidebarSection =>
      _string('appearanceSidebarSection', _fallback.appearanceSidebarSection);

  @override
  String get appearanceSidebarDefaultTitle => _string(
      'appearanceSidebarDefaultTitle', _fallback.appearanceSidebarDefaultTitle);

  @override
  String get appearanceSidebarDefaultSubtitle => _string(
      'appearanceSidebarDefaultSubtitle',
      _fallback.appearanceSidebarDefaultSubtitle);

  @override
  String get appearanceSidebarExpandedLabel => _string(
      'appearanceSidebarExpandedLabel',
      _fallback.appearanceSidebarExpandedLabel);

  @override
  String get appearanceSidebarCollapsedLabel => _string(
      'appearanceSidebarCollapsedLabel',
      _fallback.appearanceSidebarCollapsedLabel);

  @override
  String get appearanceSidebarSavedTitle => _string(
      'appearanceSidebarSavedTitle', _fallback.appearanceSidebarSavedTitle);

  @override
  String appearanceSidebarSavedMessage(Object state) => _format(
      'appearanceSidebarSavedMessage',
      {'state': state},
      _fallback.appearanceSidebarSavedMessage(state));

  @override
  String get appearanceNotificationSection => _string(
      'appearanceNotificationSection', _fallback.appearanceNotificationSection);

  @override
  String get appearanceNotificationEnableTitle => _string(
      'appearanceNotificationEnableTitle',
      _fallback.appearanceNotificationEnableTitle);

  @override
  String get appearanceNotificationEnableSubtitle => _string(
      'appearanceNotificationEnableSubtitle',
      _fallback.appearanceNotificationEnableSubtitle);

  @override
  String get appearanceNotificationSchemeTitle => _string(
      'appearanceNotificationSchemeTitle',
      _fallback.appearanceNotificationSchemeTitle);

  @override
  String get appearanceNotificationSchemeSystem => _string(
      'appearanceNotificationSchemeSystem',
      _fallback.appearanceNotificationSchemeSystem);

  @override
  String get appearanceNotificationSchemeLight => _string(
      'appearanceNotificationSchemeLight',
      _fallback.appearanceNotificationSchemeLight);

  @override
  String get appearanceNotificationSchemeDark => _string(
      'appearanceNotificationSchemeDark',
      _fallback.appearanceNotificationSchemeDark);

  @override
  String get appearanceNotificationSchemeFluent2 => _string(
      'appearanceNotificationSchemeFluent2',
      _fallback.appearanceNotificationSchemeFluent2);

  @override
  String get appearanceNotificationSchemeUnknown => _string(
      'appearanceNotificationSchemeUnknown',
      _fallback.appearanceNotificationSchemeUnknown);

  @override
  String get appearanceNotificationSchemeDefaultOption => _string(
      'appearanceNotificationSchemeDefaultOption',
      _fallback.appearanceNotificationSchemeDefaultOption);

  @override
  String get appearanceNotificationSchemeLightOption => _string(
      'appearanceNotificationSchemeLightOption',
      _fallback.appearanceNotificationSchemeLightOption);

  @override
  String get appearanceNotificationSchemeDarkOption => _string(
      'appearanceNotificationSchemeDarkOption',
      _fallback.appearanceNotificationSchemeDarkOption);

  @override
  String get appearanceNotificationSchemeFluent2Option => _string(
      'appearanceNotificationSchemeFluent2Option',
      _fallback.appearanceNotificationSchemeFluent2Option);

  @override
  String get appearanceNotificationPositionTitle => _string(
      'appearanceNotificationPositionTitle',
      _fallback.appearanceNotificationPositionTitle);

  @override
  String get appearanceNotificationPositionTopRight => _string(
      'appearanceNotificationPositionTopRight',
      _fallback.appearanceNotificationPositionTopRight);

  @override
  String get appearanceNotificationPositionBottomRight => _string(
      'appearanceNotificationPositionBottomRight',
      _fallback.appearanceNotificationPositionBottomRight);

  @override
  String get appearanceNotificationPositionUnknown => _string(
      'appearanceNotificationPositionUnknown',
      _fallback.appearanceNotificationPositionUnknown);

  @override
  String get appearanceNotificationPositionTopRightOption => _string(
      'appearanceNotificationPositionTopRightOption',
      _fallback.appearanceNotificationPositionTopRightOption);

  @override
  String get appearanceNotificationPositionBottomRightOption => _string(
      'appearanceNotificationPositionBottomRightOption',
      _fallback.appearanceNotificationPositionBottomRightOption);

  @override
  String get appearanceNotificationPerformanceTitle => _string(
      'appearanceNotificationPerformanceTitle',
      _fallback.appearanceNotificationPerformanceTitle);

  @override
  String get appearanceNotificationPerformanceOptionPerformance => _string(
      'appearanceNotificationPerformanceOptionPerformance',
      _fallback.appearanceNotificationPerformanceOptionPerformance);

  @override
  String get appearanceNotificationPerformanceOptionBalanced => _string(
      'appearanceNotificationPerformanceOptionBalanced',
      _fallback.appearanceNotificationPerformanceOptionBalanced);

  @override
  String get appearanceNotificationPerformanceOptionQuality => _string(
      'appearanceNotificationPerformanceOptionQuality',
      _fallback.appearanceNotificationPerformanceOptionQuality);

  @override
  String get appearanceNotificationPerformanceHint => _string(
      'appearanceNotificationPerformanceHint',
      _fallback.appearanceNotificationPerformanceHint);

  @override
  String get appearanceNotificationPreviewButtonTitle => _string(
      'appearanceNotificationPreviewButtonTitle',
      _fallback.appearanceNotificationPreviewButtonTitle);

  @override
  String get appearanceNotificationPreviewButtonSubtitle => _string(
      'appearanceNotificationPreviewButtonSubtitle',
      _fallback.appearanceNotificationPreviewButtonSubtitle);

  @override
  String get appearanceNotificationPreviewButton => _string(
      'appearanceNotificationPreviewButton',
      _fallback.appearanceNotificationPreviewButton);

  @override
  String get appearanceNotificationPreviewTitle => _string(
      'appearanceNotificationPreviewTitle',
      _fallback.appearanceNotificationPreviewTitle);

  @override
  String get appearanceNotificationPreviewSuccessTitle => _string(
      'appearanceNotificationPreviewSuccessTitle',
      _fallback.appearanceNotificationPreviewSuccessTitle);

  @override
  String get appearanceNotificationPreviewSuccessMessage => _string(
      'appearanceNotificationPreviewSuccessMessage',
      _fallback.appearanceNotificationPreviewSuccessMessage);

  @override
  String get appearanceNotificationPreviewWarningTitle => _string(
      'appearanceNotificationPreviewWarningTitle',
      _fallback.appearanceNotificationPreviewWarningTitle);

  @override
  String get appearanceNotificationPreviewWarningMessage => _string(
      'appearanceNotificationPreviewWarningMessage',
      _fallback.appearanceNotificationPreviewWarningMessage);

  @override
  String get appearanceNotificationPreviewErrorTitle => _string(
      'appearanceNotificationPreviewErrorTitle',
      _fallback.appearanceNotificationPreviewErrorTitle);

  @override
  String get appearanceNotificationPreviewErrorMessage => _string(
      'appearanceNotificationPreviewErrorMessage',
      _fallback.appearanceNotificationPreviewErrorMessage);

  @override
  String get appearanceNotificationPreviewInfoTitle => _string(
      'appearanceNotificationPreviewInfoTitle',
      _fallback.appearanceNotificationPreviewInfoTitle);

  @override
  String get appearanceNotificationPreviewInfoMessage => _string(
      'appearanceNotificationPreviewInfoMessage',
      _fallback.appearanceNotificationPreviewInfoMessage);

  @override
  String get appearanceNotificationTestTitle => _string(
      'appearanceNotificationTestTitle',
      _fallback.appearanceNotificationTestTitle);

  @override
  String get appearanceNotificationTestMessage => _string(
      'appearanceNotificationTestMessage',
      _fallback.appearanceNotificationTestMessage);

  @override
  String get appearancePerformanceModePerformance => _string(
      'appearancePerformanceModePerformance',
      _fallback.appearancePerformanceModePerformance);

  @override
  String get appearancePerformanceModeBalanced => _string(
      'appearancePerformanceModeBalanced',
      _fallback.appearancePerformanceModeBalanced);

  @override
  String get appearancePerformanceModeQuality => _string(
      'appearancePerformanceModeQuality',
      _fallback.appearancePerformanceModeQuality);

  @override
  String get appearancePerformanceModeUnknown => _string(
      'appearancePerformanceModeUnknown',
      _fallback.appearancePerformanceModeUnknown);

  @override
  String get appearanceSegmentsModeTitle => _string(
      'appearanceSegmentsModeTitle', _fallback.appearanceSegmentsModeTitle);

  @override
  String get appearanceSegmentsModeNoneOption => _string(
      'appearanceSegmentsModeNoneOption',
      _fallback.appearanceSegmentsModeNoneOption);

  @override
  String get appearanceSegmentsModeMergedOption => _string(
      'appearanceSegmentsModeMergedOption',
      _fallback.appearanceSegmentsModeMergedOption);

  @override
  String get appearanceSegmentsModeListOption => _string(
      'appearanceSegmentsModeListOption',
      _fallback.appearanceSegmentsModeListOption);

  @override
  String get appearanceSegmentsModeNoneDescription => _string(
      'appearanceSegmentsModeNoneDescription',
      _fallback.appearanceSegmentsModeNoneDescription);

  @override
  String get appearanceSegmentsModeMergedDescription => _string(
      'appearanceSegmentsModeMergedDescription',
      _fallback.appearanceSegmentsModeMergedDescription);

  @override
  String get appearanceSegmentsModeListDescription => _string(
      'appearanceSegmentsModeListDescription',
      _fallback.appearanceSegmentsModeListDescription);

  @override
  String get appearanceSegmentsDefaultExpandedTitle => _string(
      'appearanceSegmentsDefaultExpandedTitle',
      _fallback.appearanceSegmentsDefaultExpandedTitle);

  @override
  String get appearanceSegmentsDefaultExpandedSubtitle => _string(
      'appearanceSegmentsDefaultExpandedSubtitle',
      _fallback.appearanceSegmentsDefaultExpandedSubtitle);

  @override
  String get appearanceSegmentsMaxVisibleTitle => _string(
      'appearanceSegmentsMaxVisibleTitle',
      _fallback.appearanceSegmentsMaxVisibleTitle);

  @override
  String get appearanceSegmentsMaxVisibleSubtitle => _string(
      'appearanceSegmentsMaxVisibleSubtitle',
      _fallback.appearanceSegmentsMaxVisibleSubtitle);

  @override
  String get appearanceDownloadListSection => _string(
      'appearanceDownloadListSection', _fallback.appearanceDownloadListSection);

  @override
  String get appearanceSpeedChartTitle =>
      _string('appearanceSpeedChartTitle', _fallback.appearanceSpeedChartTitle);

  @override
  String get appearanceSpeedChartSubtitle => _string(
      'appearanceSpeedChartSubtitle', _fallback.appearanceSpeedChartSubtitle);

  @override
  String get appearanceChartFrostTitle =>
      _string('appearanceChartFrostTitle', _fallback.appearanceChartFrostTitle);

  @override
  String get appearanceChartFrostSubtitle => _string(
      'appearanceChartFrostSubtitle', _fallback.appearanceChartFrostSubtitle);

  @override
  String get appearanceChartPositionTitle => _string(
      'appearanceChartPositionTitle', _fallback.appearanceChartPositionTitle);

  @override
  String get appearanceChartPositionSubtitle => _string(
      'appearanceChartPositionSubtitle',
      _fallback.appearanceChartPositionSubtitle);

  @override
  String get appearanceChartPositionLow => _string(
      'appearanceChartPositionLow', _fallback.appearanceChartPositionLow);

  @override
  String get appearanceChartPositionMid => _string(
      'appearanceChartPositionMid', _fallback.appearanceChartPositionMid);

  @override
  String get appearanceChartPositionHigh => _string(
      'appearanceChartPositionHigh', _fallback.appearanceChartPositionHigh);

  @override
  String get appearanceChartColorTitle =>
      _string('appearanceChartColorTitle', _fallback.appearanceChartColorTitle);

  @override
  String get appearanceChartColorSubtitle => _string(
      'appearanceChartColorSubtitle', _fallback.appearanceChartColorSubtitle);

  @override
  String get appearanceChartColorBlue =>
      _string('appearanceChartColorBlue', _fallback.appearanceChartColorBlue);

  @override
  String get appearanceChartColorCyan =>
      _string('appearanceChartColorCyan', _fallback.appearanceChartColorCyan);

  @override
  String get appearanceChartColorPurple => _string(
      'appearanceChartColorPurple', _fallback.appearanceChartColorPurple);

  @override
  String get appearanceChartColorGreen =>
      _string('appearanceChartColorGreen', _fallback.appearanceChartColorGreen);

  @override
  String get appearanceChartColorPink =>
      _string('appearanceChartColorPink', _fallback.appearanceChartColorPink);

  @override
  String get appearanceChartColorOrange => _string(
      'appearanceChartColorOrange', _fallback.appearanceChartColorOrange);

  @override
  String get developerSectionDebugTools => _string(
      'developerSectionDebugTools', _fallback.developerSectionDebugTools);

  @override
  String get developerSectionTestTools =>
      _string('developerSectionTestTools', _fallback.developerSectionTestTools);

  @override
  String get developerModeEnabledSubtitle => _string(
      'developerModeEnabledSubtitle', _fallback.developerModeEnabledSubtitle);

  @override
  String get developerModeDisabledSubtitle => _string(
      'developerModeDisabledSubtitle', _fallback.developerModeDisabledSubtitle);

  @override
  String get developerToolLogTitle =>
      _string('developerToolLogTitle', _fallback.developerToolLogTitle);

  @override
  String get developerToolLogSubtitle =>
      _string('developerToolLogSubtitle', _fallback.developerToolLogSubtitle);

  @override
  String get developerToolLogShownTitle => _string(
      'developerToolLogShownTitle', _fallback.developerToolLogShownTitle);

  @override
  String get developerToolLogShownMessage => _string(
      'developerToolLogShownMessage', _fallback.developerToolLogShownMessage);

  @override
  String get developerToolLogHiddenTitle => _string(
      'developerToolLogHiddenTitle', _fallback.developerToolLogHiddenTitle);

  @override
  String get developerToolLogHiddenMessage => _string(
      'developerToolLogHiddenMessage', _fallback.developerToolLogHiddenMessage);

  @override
  String get developerToolFullLogTitle =>
      _string('developerToolFullLogTitle', _fallback.developerToolFullLogTitle);

  @override
  String get developerToolFullLogSubtitle => _string(
      'developerToolFullLogSubtitle', _fallback.developerToolFullLogSubtitle);

  @override
  String get developerToolFullLogShownTitle => _string(
      'developerToolFullLogShownTitle',
      _fallback.developerToolFullLogShownTitle);

  @override
  String get developerToolFullLogShownMessage => _string(
      'developerToolFullLogShownMessage',
      _fallback.developerToolFullLogShownMessage);

  @override
  String get developerToolFullLogHiddenTitle => _string(
      'developerToolFullLogHiddenTitle',
      _fallback.developerToolFullLogHiddenTitle);

  @override
  String get developerToolFullLogHiddenMessage => _string(
      'developerToolFullLogHiddenMessage',
      _fallback.developerToolFullLogHiddenMessage);

  @override
  String get developerToolStatusTitle =>
      _string('developerToolStatusTitle', _fallback.developerToolStatusTitle);

  @override
  String get developerToolStatusSubtitle => _string(
      'developerToolStatusSubtitle', _fallback.developerToolStatusSubtitle);

  @override
  String get developerToolStatusShownTitle => _string(
      'developerToolStatusShownTitle', _fallback.developerToolStatusShownTitle);

  @override
  String get developerToolStatusShownMessage => _string(
      'developerToolStatusShownMessage',
      _fallback.developerToolStatusShownMessage);

  @override
  String get developerToolStatusHiddenTitle => _string(
      'developerToolStatusHiddenTitle',
      _fallback.developerToolStatusHiddenTitle);

  @override
  String get developerToolStatusHiddenMessage => _string(
      'developerToolStatusHiddenMessage',
      _fallback.developerToolStatusHiddenMessage);

  @override
  String get developerToolOnlineStatsTitle => _string(
      'developerToolOnlineStatsTitle', _fallback.developerToolOnlineStatsTitle);

  @override
  String get developerToolOnlineStatsSubtitle => _string(
      'developerToolOnlineStatsSubtitle',
      _fallback.developerToolOnlineStatsSubtitle);

  @override
  String get developerToolOnlineStatsShownTitle => _string(
      'developerToolOnlineStatsShownTitle',
      _fallback.developerToolOnlineStatsShownTitle);

  @override
  String get developerToolOnlineStatsShownMessage => _string(
      'developerToolOnlineStatsShownMessage',
      _fallback.developerToolOnlineStatsShownMessage);

  @override
  String get developerToolOnlineStatsHiddenTitle => _string(
      'developerToolOnlineStatsHiddenTitle',
      _fallback.developerToolOnlineStatsHiddenTitle);

  @override
  String get developerToolOnlineStatsHiddenMessage => _string(
      'developerToolOnlineStatsHiddenMessage',
      _fallback.developerToolOnlineStatsHiddenMessage);

  @override
  String get developerToolWebCheckTitle => _string(
      'developerToolWebCheckTitle', _fallback.developerToolWebCheckTitle);

  @override
  String get developerToolWebCheckSubtitle => _string(
      'developerToolWebCheckSubtitle', _fallback.developerToolWebCheckSubtitle);

  @override
  String get developerToolWebCheckShownTitle => _string(
      'developerToolWebCheckShownTitle',
      _fallback.developerToolWebCheckShownTitle);

  @override
  String get developerToolWebCheckShownMessage => _string(
      'developerToolWebCheckShownMessage',
      _fallback.developerToolWebCheckShownMessage);

  @override
  String get developerToolWebCheckHiddenTitle => _string(
      'developerToolWebCheckHiddenTitle',
      _fallback.developerToolWebCheckHiddenTitle);

  @override
  String get developerToolWebCheckHiddenMessage => _string(
      'developerToolWebCheckHiddenMessage',
      _fallback.developerToolWebCheckHiddenMessage);

  @override
  String get developerToolPerformanceTitle => _string(
      'developerToolPerformanceTitle', _fallback.developerToolPerformanceTitle);

  @override
  String get developerToolPerformanceSubtitle => _string(
      'developerToolPerformanceSubtitle',
      _fallback.developerToolPerformanceSubtitle);

  @override
  String get developerToolPerformanceShownTitle => _string(
      'developerToolPerformanceShownTitle',
      _fallback.developerToolPerformanceShownTitle);

  @override
  String get developerToolPerformanceShownMessage => _string(
      'developerToolPerformanceShownMessage',
      _fallback.developerToolPerformanceShownMessage);

  @override
  String get developerToolPerformanceHiddenTitle => _string(
      'developerToolPerformanceHiddenTitle',
      _fallback.developerToolPerformanceHiddenTitle);

  @override
  String get developerToolPerformanceHiddenMessage => _string(
      'developerToolPerformanceHiddenMessage',
      _fallback.developerToolPerformanceHiddenMessage);

  @override
  String get developerToolConnectionDebugTitle => _string(
      'developerToolConnectionDebugTitle',
      _fallback.developerToolConnectionDebugTitle);

  @override
  String get developerToolConnectionDebugSubtitle => _string(
      'developerToolConnectionDebugSubtitle',
      _fallback.developerToolConnectionDebugSubtitle);

  @override
  String get developerToolConnectionDebugShownTitle => _string(
      'developerToolConnectionDebugShownTitle',
      _fallback.developerToolConnectionDebugShownTitle);

  @override
  String get developerToolConnectionDebugShownMessage => _string(
      'developerToolConnectionDebugShownMessage',
      _fallback.developerToolConnectionDebugShownMessage);

  @override
  String get developerToolConnectionDebugHiddenTitle => _string(
      'developerToolConnectionDebugHiddenTitle',
      _fallback.developerToolConnectionDebugHiddenTitle);

  @override
  String get developerToolConnectionDebugHiddenMessage => _string(
      'developerToolConnectionDebugHiddenMessage',
      _fallback.developerToolConnectionDebugHiddenMessage);

  @override
  String get connectionDebugTitle =>
      _string('connectionDebugTitle', _fallback.connectionDebugTitle);

  @override
  String get connectionDebugTestTitle =>
      _string('connectionDebugTestTitle', _fallback.connectionDebugTestTitle);

  @override
  String get connectionDebugTestSubtitle => _string(
      'connectionDebugTestSubtitle', _fallback.connectionDebugTestSubtitle);

  @override
  String get connectionDebugTesting =>
      _string('connectionDebugTesting', _fallback.connectionDebugTesting);

  @override
  String get connectionDebugStartTest =>
      _string('connectionDebugStartTest', _fallback.connectionDebugStartTest);

  @override
  String connectionDebugResults(int count) => _format('connectionDebugResults',
      {'count': count}, _fallback.connectionDebugResults(count));

  @override
  String get connectionDebugSuccess =>
      _string('connectionDebugSuccess', _fallback.connectionDebugSuccess);

  @override
  String get connectionDebugFailed =>
      _string('connectionDebugFailed', _fallback.connectionDebugFailed);

  @override
  String get connectionDebugLocalHost =>
      _string('connectionDebugLocalHost', _fallback.connectionDebugLocalHost);

  @override
  String get connectionDebugProxy =>
      _string('connectionDebugProxy', _fallback.connectionDebugProxy);

  @override
  String get connectionDebugUnknown =>
      _string('connectionDebugUnknown', _fallback.connectionDebugUnknown);

  @override
  String get connectionDebugReceived =>
      _string('connectionDebugReceived', _fallback.connectionDebugReceived);

  @override
  String get connectionDebugFileSize =>
      _string('connectionDebugFileSize', _fallback.connectionDebugFileSize);

  @override
  String get connectionDebugStrategyTitle => _string(
      'connectionDebugStrategyTitle', _fallback.connectionDebugStrategyTitle);

  @override
  String get connectionDebugStrategySubtitle => _string(
      'connectionDebugStrategySubtitle',
      _fallback.connectionDebugStrategySubtitle);

  @override
  String get connectionDebugStrategyRefresh => _string(
      'connectionDebugStrategyRefresh',
      _fallback.connectionDebugStrategyRefresh);

  @override
  String get connectionDebugStrategyClear => _string(
      'connectionDebugStrategyClear', _fallback.connectionDebugStrategyClear);

  @override
  String get connectionDebugStrategyEmpty => _string(
      'connectionDebugStrategyEmpty', _fallback.connectionDebugStrategyEmpty);

  @override
  String connectionDebugStrategyCount(Object count) => _format(
      'connectionDebugStrategyCount',
      {'count': count},
      _fallback.connectionDebugStrategyCount(count));

  @override
  String get connectionDebugStrategyPolicy => _string(
      'connectionDebugStrategyPolicy', _fallback.connectionDebugStrategyPolicy);

  @override
  String get connectionDebugStrategyConcurrency => _string(
      'connectionDebugStrategyConcurrency',
      _fallback.connectionDebugStrategyConcurrency);

  @override
  String get connectionDebugStrategyTtl => _string(
      'connectionDebugStrategyTtl', _fallback.connectionDebugStrategyTtl);

  @override
  String get connectionDebugStrategyExpired => _string(
      'connectionDebugStrategyExpired',
      _fallback.connectionDebugStrategyExpired);

  @override
  String get connectionDebugRangeSupported => _string(
      'connectionDebugRangeSupported', _fallback.connectionDebugRangeSupported);

  @override
  String get connectionDebugRangeNotSupported => _string(
      'connectionDebugRangeNotSupported',
      _fallback.connectionDebugRangeNotSupported);

  @override
  String get developerTestNotificationTitle => _string(
      'developerTestNotificationTitle',
      _fallback.developerTestNotificationTitle);

  @override
  String get developerTestNotificationTitlePlaceholder => _string(
      'developerTestNotificationTitlePlaceholder',
      _fallback.developerTestNotificationTitlePlaceholder);

  @override
  String get developerTestNotificationMessagePlaceholder => _string(
      'developerTestNotificationMessagePlaceholder',
      _fallback.developerTestNotificationMessagePlaceholder);

  @override
  String get developerTestNotificationTypeSuccess => _string(
      'developerTestNotificationTypeSuccess',
      _fallback.developerTestNotificationTypeSuccess);

  @override
  String get developerTestNotificationTypeWarning => _string(
      'developerTestNotificationTypeWarning',
      _fallback.developerTestNotificationTypeWarning);

  @override
  String get developerTestNotificationTypeError => _string(
      'developerTestNotificationTypeError',
      _fallback.developerTestNotificationTypeError);

  @override
  String get developerTestNotificationTypeInfo => _string(
      'developerTestNotificationTypeInfo',
      _fallback.developerTestNotificationTypeInfo);

  @override
  String get developerTestNotificationTitleRequired => _string(
      'developerTestNotificationTitleRequired',
      _fallback.developerTestNotificationTitleRequired);

  @override
  String get developerTestPopupTitle =>
      _string('developerTestPopupTitle', _fallback.developerTestPopupTitle);

  @override
  String get developerTestPopupButton =>
      _string('developerTestPopupButton', _fallback.developerTestPopupButton);

  @override
  String get developerTestPopupTestingLabel => _string(
      'developerTestPopupTestingLabel',
      _fallback.developerTestPopupTestingLabel);

  @override
  String get developerTestPopupHint =>
      _string('developerTestPopupHint', _fallback.developerTestPopupHint);

  @override
  String developerTestPopupResultSuccess(Object time) => _format(
      'developerTestPopupResultSuccess',
      {'time': time},
      _fallback.developerTestPopupResultSuccess(time));

  @override
  String get developerTestPopupResultFailed => _string(
      'developerTestPopupResultFailed',
      _fallback.developerTestPopupResultFailed);

  @override
  String get developerOpenL10nFolderTitle => _string(
      'developerOpenL10nFolderTitle', _fallback.developerOpenL10nFolderTitle);

  @override
  String get developerOpenL10nFolderSubtitle => _string(
      'developerOpenL10nFolderSubtitle',
      _fallback.developerOpenL10nFolderSubtitle);

  @override
  String get developerOpenL10nFolderSuccessTitle => _string(
      'developerOpenL10nFolderSuccessTitle',
      _fallback.developerOpenL10nFolderSuccessTitle);

  @override
  String get developerOpenL10nFolderSuccessMessage => _string(
      'developerOpenL10nFolderSuccessMessage',
      _fallback.developerOpenL10nFolderSuccessMessage);

  @override
  String get developerOpenL10nFolderFailedTitle => _string(
      'developerOpenL10nFolderFailedTitle',
      _fallback.developerOpenL10nFolderFailedTitle);

  @override
  String developerOpenL10nFolderFailedMessage(Object error) => _format(
      'developerOpenL10nFolderFailedMessage',
      {'error': error},
      _fallback.developerOpenL10nFolderFailedMessage(error));

  @override
  String get updateCurrentVersionTitle =>
      _string('updateCurrentVersionTitle', _fallback.updateCurrentVersionTitle);

  @override
  String get updateChangelogTitle =>
      _string('updateChangelogTitle', _fallback.updateChangelogTitle);

  @override
  String get updateChangelogViewFullButton => _string(
      'updateChangelogViewFullButton', _fallback.updateChangelogViewFullButton);

  @override
  String updateChangelogDialogTitle(Object version) => _format(
      'updateChangelogDialogTitle',
      {'version': version},
      _fallback.updateChangelogDialogTitle(version));

  @override
  String get updateCheckTitle =>
      _string('updateCheckTitle', _fallback.updateCheckTitle);

  @override
  String get updateStartButton =>
      _string('updateStartButton', _fallback.updateStartButton);

  @override
  String get updateCheckAgainButton =>
      _string('updateCheckAgainButton', _fallback.updateCheckAgainButton);

  @override
  String get updateCheckingStatus =>
      _string('updateCheckingStatus', _fallback.updateCheckingStatus);

  @override
  String get updateCheckFailedTitle =>
      _string('updateCheckFailedTitle', _fallback.updateCheckFailedTitle);

  @override
  String get updateLatestTitle =>
      _string('updateLatestTitle', _fallback.updateLatestTitle);

  @override
  String get updateLatestSubtitle =>
      _string('updateLatestSubtitle', _fallback.updateLatestSubtitle);

  @override
  String get updateInitialHint =>
      _string('updateInitialHint', _fallback.updateInitialHint);

  @override
  String get updateUnreleasedTitle =>
      _string('updateUnreleasedTitle', _fallback.updateUnreleasedTitle);

  @override
  String updateUnreleasedSubtitle(Object version) => _format(
      'updateUnreleasedSubtitle',
      {'version': version},
      _fallback.updateUnreleasedSubtitle(version));

  @override
  String get updateConfirmTitle =>
      _string('updateConfirmTitle', _fallback.updateConfirmTitle);

  @override
  String get updateConfirmMessage =>
      _string('updateConfirmMessage', _fallback.updateConfirmMessage);

  @override
  String updateConfirmDetails(Object newVersion, Object currentVersion,
          Object change, Object currentChannel, Object targetChannel) =>
      _format(
        'updateConfirmDetails',
        {
          'newVersion': newVersion,
          'currentVersion': currentVersion,
          'change': change,
          'currentChannel': currentChannel,
          'targetChannel': targetChannel,
        },
        _fallback.updateConfirmDetails(
            newVersion, currentVersion, change, currentChannel, targetChannel),
      );

  @override
  String get updateConfirmCancelButton =>
      _string('updateConfirmCancelButton', _fallback.updateConfirmCancelButton);

  @override
  String get updateConfirmProceedButton => _string(
      'updateConfirmProceedButton', _fallback.updateConfirmProceedButton);

  @override
  String get updateUnknownVersion =>
      _string('updateUnknownVersion', _fallback.updateUnknownVersion);

  @override
  String get updateUnknownChannel =>
      _string('updateUnknownChannel', _fallback.updateUnknownChannel);

  @override
  String get updateLauncherFailedTitle =>
      _string('updateLauncherFailedTitle', _fallback.updateLauncherFailedTitle);

  @override
  String get updateLauncherFailedMessage => _string(
      'updateLauncherFailedMessage', _fallback.updateLauncherFailedMessage);

  @override
  String get updateLauncherFailedCloseButton => _string(
      'updateLauncherFailedCloseButton',
      _fallback.updateLauncherFailedCloseButton);

  @override
  String get updateLauncherFailedManualDownloadButton => _string(
      'updateLauncherFailedManualDownloadButton',
      _fallback.updateLauncherFailedManualDownloadButton);

  @override
  String get updateAvailableTitle =>
      _string('updateAvailableTitle', _fallback.updateAvailableTitle);

  @override
  String get updateAvailableChangelogTitle => _string(
      'updateAvailableChangelogTitle', _fallback.updateAvailableChangelogTitle);

  @override
  String get updateSettingsTitle =>
      _string('updateSettingsTitle', _fallback.updateSettingsTitle);

  @override
  String get updateDotNetMissingSubtitle => _string(
      'updateDotNetMissingSubtitle', _fallback.updateDotNetMissingSubtitle);

  @override
  String get updateDotNetDownloadButton => _string(
      'updateDotNetDownloadButton', _fallback.updateDotNetDownloadButton);

  @override
  String get updateDotNetInstalledSubtitle => _string(
      'updateDotNetInstalledSubtitle', _fallback.updateDotNetInstalledSubtitle);

  @override
  String get updateDotNetRecheckButton =>
      _string('updateDotNetRecheckButton', _fallback.updateDotNetRecheckButton);

  @override
  String get updateDotNetRecommendTitle => _string(
      'updateDotNetRecommendTitle', _fallback.updateDotNetRecommendTitle);

  @override
  String get updateDotNetRecommendSubtitle => _string(
      'updateDotNetRecommendSubtitle', _fallback.updateDotNetRecommendSubtitle);

  @override
  String get updateDotNetRecommendButton => _string(
      'updateDotNetRecommendButton', _fallback.updateDotNetRecommendButton);

  @override
  String get updateChannelTitle =>
      _string('updateChannelTitle', _fallback.updateChannelTitle);

  @override
  String get updateChannelAlpha =>
      _string('updateChannelAlpha', _fallback.updateChannelAlpha);

  @override
  String get updateChannelBeta =>
      _string('updateChannelBeta', _fallback.updateChannelBeta);

  @override
  String get updateChannelRelease =>
      _string('updateChannelRelease', _fallback.updateChannelRelease);

  @override
  String get updateIntervalTitle =>
      _string('updateIntervalTitle', _fallback.updateIntervalTitle);

  @override
  String get updateIntervalSubtitle =>
      _string('updateIntervalSubtitle', _fallback.updateIntervalSubtitle);

  @override
  String get updateIntervalStartup =>
      _string('updateIntervalStartup', _fallback.updateIntervalStartup);

  @override
  String get updateIntervalHourly =>
      _string('updateIntervalHourly', _fallback.updateIntervalHourly);

  @override
  String get updateIntervalDaily =>
      _string('updateIntervalDaily', _fallback.updateIntervalDaily);

  @override
  String get updateIntervalWeekly =>
      _string('updateIntervalWeekly', _fallback.updateIntervalWeekly);

  @override
  String get updateIntervalNever =>
      _string('updateIntervalNever', _fallback.updateIntervalNever);

  @override
  String get updateAllowBetaTitle =>
      _string('updateAllowBetaTitle', _fallback.updateAllowBetaTitle);

  @override
  String get updateAllowBetaSubtitle =>
      _string('updateAllowBetaSubtitle', _fallback.updateAllowBetaSubtitle);

  @override
  String get updateAllowAlphaTitle =>
      _string('updateAllowAlphaTitle', _fallback.updateAllowAlphaTitle);

  @override
  String get updateAllowAlphaSubtitle =>
      _string('updateAllowAlphaSubtitle', _fallback.updateAllowAlphaSubtitle);

  @override
  String updateLastCheckLabel(Object time) => _format('updateLastCheckLabel',
      {'time': time}, _fallback.updateLastCheckLabel(time));

  @override
  String get updateTimeJustNow =>
      _string('updateTimeJustNow', _fallback.updateTimeJustNow);

  @override
  String updateTimeMinutesAgo(Object minutes) => _format('updateTimeMinutesAgo',
      {'minutes': minutes}, _fallback.updateTimeMinutesAgo(minutes));

  @override
  String updateTimeHoursAgo(Object hours) => _format('updateTimeHoursAgo',
      {'hours': hours}, _fallback.updateTimeHoursAgo(hours));

  @override
  String get updateDialogCloseButton =>
      _string('updateDialogCloseButton', _fallback.updateDialogCloseButton);

  @override
  String get statusOnline => _string('statusOnline', _fallback.statusOnline);

  @override
  String get statusOffline => _string('statusOffline', _fallback.statusOffline);

  @override
  String get settingsDangerZoneTitle =>
      _string('settingsDangerZoneTitle', _fallback.settingsDangerZoneTitle);

  @override
  String get popupDownloadTitle =>
      _string('popupDownloadTitle', _fallback.popupDownloadTitle);

  @override
  String get popupDownloadLinkLabel =>
      _string('popupDownloadLinkLabel', _fallback.popupDownloadLinkLabel);

  @override
  String get popupDownloadLinkPlaceholder => _string(
      'popupDownloadLinkPlaceholder', _fallback.popupDownloadLinkPlaceholder);

  @override
  String get popupDownloadFileNameLabel => _string(
      'popupDownloadFileNameLabel', _fallback.popupDownloadFileNameLabel);

  @override
  String get popupDownloadFileNamePlaceholder => _string(
      'popupDownloadFileNamePlaceholder',
      _fallback.popupDownloadFileNamePlaceholder);

  @override
  String get popupDownloadSavePathLabel => _string(
      'popupDownloadSavePathLabel', _fallback.popupDownloadSavePathLabel);

  @override
  String get popupDownloadSavePathPlaceholder => _string(
      'popupDownloadSavePathPlaceholder',
      _fallback.popupDownloadSavePathPlaceholder);

  @override
  String get popupDownloadAutoStart =>
      _string('popupDownloadAutoStart', _fallback.popupDownloadAutoStart);

  @override
  String get popupDownloadFeatureHint =>
      _string('popupDownloadFeatureHint', _fallback.popupDownloadFeatureHint);

  @override
  String get popupDownloadCancel =>
      _string('popupDownloadCancel', _fallback.popupDownloadCancel);

  @override
  String get popupDownloadAdding =>
      _string('popupDownloadAdding', _fallback.popupDownloadAdding);

  @override
  String get popupDownloadStart =>
      _string('popupDownloadStart', _fallback.popupDownloadStart);

  @override
  String get popupDownloadErrorMissingInfo => _string(
      'popupDownloadErrorMissingInfo', _fallback.popupDownloadErrorMissingInfo);

  @override
  String get popupDownloadErrorInvalidUrl => _string(
      'popupDownloadErrorInvalidUrl', _fallback.popupDownloadErrorInvalidUrl);

  @override
  String popupDownloadErrorAddFailed(Object error) => _format(
      'popupDownloadErrorAddFailed',
      {'error': error},
      _fallback.popupDownloadErrorAddFailed(error));

  @override
  String get popupDownloadErrorTitle =>
      _string('popupDownloadErrorTitle', _fallback.popupDownloadErrorTitle);

  @override
  String get popupDownloadErrorConfirm =>
      _string('popupDownloadErrorConfirm', _fallback.popupDownloadErrorConfirm);

  @override
  String get popupDownloadDefaultFileName => _string(
      'popupDownloadDefaultFileName', _fallback.popupDownloadDefaultFileName);

  @override
  String get popupDownloadProgressTitle => _string(
      'popupDownloadProgressTitle', _fallback.popupDownloadProgressTitle);

  @override
  String get popupDownloadCompletedTitle => _string(
      'popupDownloadCompletedTitle', _fallback.popupDownloadCompletedTitle);

  @override
  String get popupDownloadProgressHint =>
      _string('popupDownloadProgressHint', _fallback.popupDownloadProgressHint);

  @override
  String get popupDownloadCompletedHint => _string(
      'popupDownloadCompletedHint', _fallback.popupDownloadCompletedHint);

  @override
  String get popupDownloadStatusPending => _string(
      'popupDownloadStatusPending', _fallback.popupDownloadStatusPending);

  @override
  String get popupDownloadStatusDownloading => _string(
      'popupDownloadStatusDownloading',
      _fallback.popupDownloadStatusDownloading);

  @override
  String get popupDownloadStatusPaused =>
      _string('popupDownloadStatusPaused', _fallback.popupDownloadStatusPaused);

  @override
  String get popupDownloadStatusMerging => _string(
      'popupDownloadStatusMerging', _fallback.popupDownloadStatusMerging);

  @override
  String get popupDownloadStatusCompleted => _string(
      'popupDownloadStatusCompleted', _fallback.popupDownloadStatusCompleted);

  @override
  String get popupDownloadStatusFailed =>
      _string('popupDownloadStatusFailed', _fallback.popupDownloadStatusFailed);

  @override
  String get popupDownloadStatusUnknown => _string(
      'popupDownloadStatusUnknown', _fallback.popupDownloadStatusUnknown);

  @override
  String get popupDownloadMetricProgress => _string(
      'popupDownloadMetricProgress', _fallback.popupDownloadMetricProgress);

  @override
  String get popupDownloadMetricDownloaded => _string(
      'popupDownloadMetricDownloaded', _fallback.popupDownloadMetricDownloaded);

  @override
  String get popupDownloadMetricTotalSize => _string(
      'popupDownloadMetricTotalSize', _fallback.popupDownloadMetricTotalSize);

  @override
  String get popupDownloadMetricSpeed =>
      _string('popupDownloadMetricSpeed', _fallback.popupDownloadMetricSpeed);

  @override
  String get popupDownloadMetricEta =>
      _string('popupDownloadMetricEta', _fallback.popupDownloadMetricEta);

  @override
  String get popupDownloadMetricSegments => _string(
      'popupDownloadMetricSegments', _fallback.popupDownloadMetricSegments);

  @override
  String get popupDownloadMetricStatus =>
      _string('popupDownloadMetricStatus', _fallback.popupDownloadMetricStatus);

  @override
  String get popupDownloadMetricSaveTo =>
      _string('popupDownloadMetricSaveTo', _fallback.popupDownloadMetricSaveTo);

  @override
  String get popupDownloadMetricHost =>
      _string('popupDownloadMetricHost', _fallback.popupDownloadMetricHost);

  @override
  String get popupDownloadProgressLiveLabel => _string(
      'popupDownloadProgressLiveLabel',
      _fallback.popupDownloadProgressLiveLabel);

  @override
  String get popupDownloadProgressSegmentTitle => _string(
      'popupDownloadProgressSegmentTitle',
      _fallback.popupDownloadProgressSegmentTitle);

  @override
  String get popupDownloadProgressWaiting => _string(
      'popupDownloadProgressWaiting', _fallback.popupDownloadProgressWaiting);

  @override
  String get popupDownloadProgressCompletedMessage => _string(
      'popupDownloadProgressCompletedMessage',
      _fallback.popupDownloadProgressCompletedMessage);

  @override
  String get popupDownloadActionBackground => _string(
      'popupDownloadActionBackground', _fallback.popupDownloadActionBackground);

  @override
  String get popupDownloadActionPause =>
      _string('popupDownloadActionPause', _fallback.popupDownloadActionPause);

  @override
  String get popupDownloadActionResume =>
      _string('popupDownloadActionResume', _fallback.popupDownloadActionResume);

  @override
  String get popupDownloadActionOpenFolder => _string(
      'popupDownloadActionOpenFolder', _fallback.popupDownloadActionOpenFolder);

  @override
  String get popupDownloadActionOpenFile => _string(
      'popupDownloadActionOpenFile', _fallback.popupDownloadActionOpenFile);

  @override
  String get popupDownloadActionClose =>
      _string('popupDownloadActionClose', _fallback.popupDownloadActionClose);

  @override
  String popupDownloadErrorOpenFileFailed(Object error) => _format(
      'popupDownloadErrorOpenFileFailed',
      {'error': error},
      _fallback.popupDownloadErrorOpenFileFailed(error));

  @override
  String popupDownloadErrorOpenFolderFailed(Object error) => _format(
      'popupDownloadErrorOpenFolderFailed',
      {'error': error},
      _fallback.popupDownloadErrorOpenFolderFailed(error));

  @override
  String get addDownloadTitle =>
      _string('addDownloadTitle', _fallback.addDownloadTitle);

  @override
  String get addDownloadSubtitle =>
      _string('addDownloadSubtitle', _fallback.addDownloadSubtitle);

  @override
  String get addDownloadUrlLabel =>
      _string('addDownloadUrlLabel', _fallback.addDownloadUrlLabel);

  @override
  String get addDownloadRequiredBadge =>
      _string('addDownloadRequiredBadge', _fallback.addDownloadRequiredBadge);

  @override
  String get addDownloadUrlPlaceholder =>
      _string('addDownloadUrlPlaceholder', _fallback.addDownloadUrlPlaceholder);

  @override
  String get addDownloadParsedFileNameTitle => _string(
      'addDownloadParsedFileNameTitle',
      _fallback.addDownloadParsedFileNameTitle);

  @override
  String get addDownloadAdvancedToggle =>
      _string('addDownloadAdvancedToggle', _fallback.addDownloadAdvancedToggle);

  @override
  String get addDownloadAdvancedCollapsedHint => _string(
      'addDownloadAdvancedCollapsedHint',
      _fallback.addDownloadAdvancedCollapsedHint);

  @override
  String get addDownloadAdvancedExpandedHint => _string(
      'addDownloadAdvancedExpandedHint',
      _fallback.addDownloadAdvancedExpandedHint);

  @override
  String get addDownloadFileNameLabel =>
      _string('addDownloadFileNameLabel', _fallback.addDownloadFileNameLabel);

  @override
  String get addDownloadOptionalBadge =>
      _string('addDownloadOptionalBadge', _fallback.addDownloadOptionalBadge);

  @override
  String get addDownloadFileNamePlaceholder => _string(
      'addDownloadFileNamePlaceholder',
      _fallback.addDownloadFileNamePlaceholder);

  @override
  String get addDownloadFeatureTitle =>
      _string('addDownloadFeatureTitle', _fallback.addDownloadFeatureTitle);

  @override
  String get addDownloadFeature1Title =>
      _string('addDownloadFeature1Title', _fallback.addDownloadFeature1Title);

  @override
  String get addDownloadFeature1Desc =>
      _string('addDownloadFeature1Desc', _fallback.addDownloadFeature1Desc);

  @override
  String get addDownloadFeature2Title =>
      _string('addDownloadFeature2Title', _fallback.addDownloadFeature2Title);

  @override
  String get addDownloadFeature2Desc =>
      _string('addDownloadFeature2Desc', _fallback.addDownloadFeature2Desc);

  @override
  String get addDownloadFeature3Title =>
      _string('addDownloadFeature3Title', _fallback.addDownloadFeature3Title);

  @override
  String get addDownloadFeature3Desc =>
      _string('addDownloadFeature3Desc', _fallback.addDownloadFeature3Desc);

  @override
  String get addDownloadCancelButton =>
      _string('addDownloadCancelButton', _fallback.addDownloadCancelButton);

  @override
  String get addDownloadAdding =>
      _string('addDownloadAdding', _fallback.addDownloadAdding);

  @override
  String get addDownloadStart =>
      _string('addDownloadStart', _fallback.addDownloadStart);

  @override
  String get addDownloadErrorMissingUrl => _string(
      'addDownloadErrorMissingUrl', _fallback.addDownloadErrorMissingUrl);

  @override
  String get addDownloadErrorInvalidUrl => _string(
      'addDownloadErrorInvalidUrl', _fallback.addDownloadErrorInvalidUrl);

  @override
  String get downloadIntentTypeUnknown =>
      _string('downloadIntentTypeUnknown', _fallback.downloadIntentTypeUnknown);

  @override
  String get downloadIntentTypeHttp =>
      _string('downloadIntentTypeHttp', _fallback.downloadIntentTypeHttp);

  @override
  String get downloadIntentTypeMagnet =>
      _string('downloadIntentTypeMagnet', _fallback.downloadIntentTypeMagnet);

  @override
  String downloadIntentUnsupportedType(Object type) => _format(
      'downloadIntentUnsupportedType',
      {'type': type},
      _fallback.downloadIntentUnsupportedType(type));

  @override
  String addDownloadErrorAddFailed(Object error) => _format(
      'addDownloadErrorAddFailed',
      {'error': error},
      _fallback.addDownloadErrorAddFailed(error));

  @override
  String get addDownloadErrorTitle =>
      _string('addDownloadErrorTitle', _fallback.addDownloadErrorTitle);

  @override
  String get addDownloadErrorConfirm =>
      _string('addDownloadErrorConfirm', _fallback.addDownloadErrorConfirm);

  @override
  String get addDownloadSuccessTitle =>
      _string('addDownloadSuccessTitle', _fallback.addDownloadSuccessTitle);

  @override
  String addDownloadSuccessMessage(Object fileName) => _format(
      'addDownloadSuccessMessage',
      {'fileName': fileName},
      _fallback.addDownloadSuccessMessage(fileName));

  @override
  String get folderPickerErrorPathNotFound => _string(
      'folderPickerErrorPathNotFound', _fallback.folderPickerErrorPathNotFound);

  @override
  String get folderPickerErrorAccessDenied => _string(
      'folderPickerErrorAccessDenied', _fallback.folderPickerErrorAccessDenied);

  @override
  String folderPickerErrorAccessFailed(Object error) => _format(
      'folderPickerErrorAccessFailed',
      {'error': error},
      _fallback.folderPickerErrorAccessFailed(error));

  @override
  String get folderPickerCreateTitle =>
      _string('folderPickerCreateTitle', _fallback.folderPickerCreateTitle);

  @override
  String get folderPickerCreatePrompt =>
      _string('folderPickerCreatePrompt', _fallback.folderPickerCreatePrompt);

  @override
  String get folderPickerCreatePlaceholder => _string(
      'folderPickerCreatePlaceholder', _fallback.folderPickerCreatePlaceholder);

  @override
  String get folderPickerCancelButton =>
      _string('folderPickerCancelButton', _fallback.folderPickerCancelButton);

  @override
  String get folderPickerCreateButton =>
      _string('folderPickerCreateButton', _fallback.folderPickerCreateButton);

  @override
  String get folderPickerConfirmButton =>
      _string('folderPickerConfirmButton', _fallback.folderPickerConfirmButton);

  @override
  String get folderPickerCreateExistsTitle => _string(
      'folderPickerCreateExistsTitle', _fallback.folderPickerCreateExistsTitle);

  @override
  String folderPickerCreateExistsMessage(Object name) => _format(
      'folderPickerCreateExistsMessage',
      {'name': name},
      _fallback.folderPickerCreateExistsMessage(name));

  @override
  String get folderPickerCreateSuccessTitle => _string(
      'folderPickerCreateSuccessTitle',
      _fallback.folderPickerCreateSuccessTitle);

  @override
  String folderPickerCreateSuccessMessage(Object name) => _format(
      'folderPickerCreateSuccessMessage',
      {'name': name},
      _fallback.folderPickerCreateSuccessMessage(name));

  @override
  String get folderPickerCreateFailedTitle => _string(
      'folderPickerCreateFailedTitle', _fallback.folderPickerCreateFailedTitle);

  @override
  String folderPickerCreateFailedMessage(Object error) => _format(
      'folderPickerCreateFailedMessage',
      {'error': error},
      _fallback.folderPickerCreateFailedMessage(error));

  @override
  String get folderPickerQuickPathAddTitle => _string(
      'folderPickerQuickPathAddTitle', _fallback.folderPickerQuickPathAddTitle);

  @override
  String get folderPickerQuickPathAddPrompt => _string(
      'folderPickerQuickPathAddPrompt',
      _fallback.folderPickerQuickPathAddPrompt);

  @override
  String get folderPickerQuickPathAddNameLabel => _string(
      'folderPickerQuickPathAddNameLabel',
      _fallback.folderPickerQuickPathAddNameLabel);

  @override
  String get folderPickerQuickPathAddNamePlaceholder => _string(
      'folderPickerQuickPathAddNamePlaceholder',
      _fallback.folderPickerQuickPathAddNamePlaceholder);

  @override
  String get folderPickerQuickPathAddButton => _string(
      'folderPickerQuickPathAddButton',
      _fallback.folderPickerQuickPathAddButton);

  @override
  String get folderPickerQuickPathAddSuccessTitle => _string(
      'folderPickerQuickPathAddSuccessTitle',
      _fallback.folderPickerQuickPathAddSuccessTitle);

  @override
  String get folderPickerQuickPathAddFailedTitle => _string(
      'folderPickerQuickPathAddFailedTitle',
      _fallback.folderPickerQuickPathAddFailedTitle);

  @override
  String get folderPickerQuickPathAddSuccessMessage => _string(
      'folderPickerQuickPathAddSuccessMessage',
      _fallback.folderPickerQuickPathAddSuccessMessage);

  @override
  String get folderPickerQuickPathAddFailedMessage => _string(
      'folderPickerQuickPathAddFailedMessage',
      _fallback.folderPickerQuickPathAddFailedMessage);

  @override
  String get folderPickerQuickPathRemoveTitle => _string(
      'folderPickerQuickPathRemoveTitle',
      _fallback.folderPickerQuickPathRemoveTitle);

  @override
  String folderPickerQuickPathRemoveMessage(Object path) => _format(
      'folderPickerQuickPathRemoveMessage',
      {'path': path},
      _fallback.folderPickerQuickPathRemoveMessage(path));

  @override
  String get folderPickerQuickPathRemoveButton => _string(
      'folderPickerQuickPathRemoveButton',
      _fallback.folderPickerQuickPathRemoveButton);

  @override
  String get folderPickerTitle =>
      _string('folderPickerTitle', _fallback.folderPickerTitle);

  @override
  String get folderPickerNavUpTooltip =>
      _string('folderPickerNavUpTooltip', _fallback.folderPickerNavUpTooltip);

  @override
  String get folderPickerPathPlaceholder => _string(
      'folderPickerPathPlaceholder', _fallback.folderPickerPathPlaceholder);

  @override
  String get folderPickerRefreshTooltip => _string(
      'folderPickerRefreshTooltip', _fallback.folderPickerRefreshTooltip);

  @override
  String get folderPickerNewFolderTooltip => _string(
      'folderPickerNewFolderTooltip', _fallback.folderPickerNewFolderTooltip);

  @override
  String get folderPickerAddQuickPathTooltip => _string(
      'folderPickerAddQuickPathTooltip',
      _fallback.folderPickerAddQuickPathTooltip);

  @override
  String get folderPickerEmptyMessage =>
      _string('folderPickerEmptyMessage', _fallback.folderPickerEmptyMessage);

  @override
  String get folderPickerSelectButton =>
      _string('folderPickerSelectButton', _fallback.folderPickerSelectButton);

  @override
  String get updateLatestVersionLabel =>
      _string('updateLatestVersionLabel', _fallback.updateLatestVersionLabel);

  @override
  String get updateDialogLaterButton =>
      _string('updateDialogLaterButton', _fallback.updateDialogLaterButton);

  @override
  String get updateDialogDownloadNowButton => _string(
      'updateDialogDownloadNowButton', _fallback.updateDialogDownloadNowButton);

  @override
  String get updateDialogCurrentInfoTitle => _string(
      'updateDialogCurrentInfoTitle', _fallback.updateDialogCurrentInfoTitle);

  @override
  String get downloadStatusDownloading =>
      _string('downloadStatusDownloading', _fallback.downloadStatusDownloading);

  @override
  String get downloadStatusPaused =>
      _string('downloadStatusPaused', _fallback.downloadStatusPaused);

  @override
  String get downloadStatusPending =>
      _string('downloadStatusPending', _fallback.downloadStatusPending);

  @override
  String get downloadStatusFailed =>
      _string('downloadStatusFailed', _fallback.downloadStatusFailed);

  @override
  String get downloadStatusMerging =>
      _string('downloadStatusMerging', _fallback.downloadStatusMerging);

  @override
  String get downloadStatusCompleted =>
      _string('downloadStatusCompleted', _fallback.downloadStatusCompleted);

  @override
  String get downloadFilterTitle =>
      _string('downloadFilterTitle', _fallback.downloadFilterTitle);

  @override
  String get downloadFilterSubtitle =>
      _string('downloadFilterSubtitle', _fallback.downloadFilterSubtitle);

  @override
  String get downloadFilterAll =>
      _string('downloadFilterAll', _fallback.downloadFilterAll);

  @override
  String get downloadDialogCloseButton =>
      _string('downloadDialogCloseButton', _fallback.downloadDialogCloseButton);

  @override
  String get downloadSortTitle =>
      _string('downloadSortTitle', _fallback.downloadSortTitle);

  @override
  String get downloadSortSubtitle =>
      _string('downloadSortSubtitle', _fallback.downloadSortSubtitle);

  @override
  String get downloadSortNewest =>
      _string('downloadSortNewest', _fallback.downloadSortNewest);

  @override
  String get downloadSortOldest =>
      _string('downloadSortOldest', _fallback.downloadSortOldest);

  @override
  String get downloadSortNewestDesc =>
      _string('downloadSortNewestDesc', _fallback.downloadSortNewestDesc);

  @override
  String get downloadSortOldestDesc =>
      _string('downloadSortOldestDesc', _fallback.downloadSortOldestDesc);

  @override
  String get downloadSearchPlaceholder =>
      _string('downloadSearchPlaceholder', _fallback.downloadSearchPlaceholder);

  @override
  String get downloadNoResultsTitle =>
      _string('downloadNoResultsTitle', _fallback.downloadNoResultsTitle);

  @override
  String get downloadNoResultsSubtitle =>
      _string('downloadNoResultsSubtitle', _fallback.downloadNoResultsSubtitle);

  @override
  String get downloadStatsActiveLabel =>
      _string('downloadStatsActiveLabel', _fallback.downloadStatsActiveLabel);

  @override
  String get downloadStatsSpeedLabel =>
      _string('downloadStatsSpeedLabel', _fallback.downloadStatsSpeedLabel);

  @override
  String get downloadStatsSegmentsLabel => _string(
      'downloadStatsSegmentsLabel', _fallback.downloadStatsSegmentsLabel);

  @override
  String get downloadEmptyTitle =>
      _string('downloadEmptyTitle', _fallback.downloadEmptyTitle);

  @override
  String get downloadEmptySubtitle =>
      _string('downloadEmptySubtitle', _fallback.downloadEmptySubtitle);

  @override
  String get loadingTasks => _string('loadingTasks', _fallback.loadingTasks);

  @override
  String get loadingTasksHint =>
      _string('loadingTasksHint', _fallback.loadingTasksHint);

  @override
  String get downloadCopySuccessTitle =>
      _string('downloadCopySuccessTitle', _fallback.downloadCopySuccessTitle);

  @override
  String get downloadCopySuccessMessage => _string(
      'downloadCopySuccessMessage', _fallback.downloadCopySuccessMessage);

  @override
  String get downloadCopyFailedTitle =>
      _string('downloadCopyFailedTitle', _fallback.downloadCopyFailedTitle);

  @override
  String downloadCopyFailedMessage(Object error) => _format(
      'downloadCopyFailedMessage',
      {'error': error},
      _fallback.downloadCopyFailedMessage(error));

  @override
  String get downloadCopyTooltip =>
      _string('downloadCopyTooltip', _fallback.downloadCopyTooltip);

  @override
  String get downloadActionStart =>
      _string('downloadActionStart', _fallback.downloadActionStart);

  @override
  String get downloadActionPause =>
      _string('downloadActionPause', _fallback.downloadActionPause);

  @override
  String get downloadActionRetrySegments => _string(
      'downloadActionRetrySegments', _fallback.downloadActionRetrySegments);

  @override
  String get downloadActionRetryAll =>
      _string('downloadActionRetryAll', _fallback.downloadActionRetryAll);

  @override
  String get downloadActionDelete =>
      _string('downloadActionDelete', _fallback.downloadActionDelete);

  @override
  String get downloadMergingStatus =>
      _string('downloadMergingStatus', _fallback.downloadMergingStatus);

  @override
  String get downloadCalculatingSize =>
      _string('downloadCalculatingSize', _fallback.downloadCalculatingSize);

  @override
  String get downloadCalculating =>
      _string('downloadCalculating', _fallback.downloadCalculating);

  @override
  String get downloadMatchingHttpProtocol => _string(
      'downloadMatchingHttpProtocol', _fallback.downloadMatchingHttpProtocol);

  @override
  String get downloadMatchingHttpProtocolShort => _string(
      'downloadMatchingHttpProtocolShort',
      _fallback.downloadMatchingHttpProtocolShort);

  @override
  String downloadSegmentsTitleWithCount(Object count) => _format(
      'downloadSegmentsTitleWithCount',
      {'count': count},
      _fallback.downloadSegmentsTitleWithCount(count));

  @override
  String get downloadSegmentsTitle =>
      _string('downloadSegmentsTitle', _fallback.downloadSegmentsTitle);

  @override
  String get downloadSegmentsStatusCompleted => _string(
      'downloadSegmentsStatusCompleted',
      _fallback.downloadSegmentsStatusCompleted);

  @override
  String get downloadSegmentsStatusDownloading => _string(
      'downloadSegmentsStatusDownloading',
      _fallback.downloadSegmentsStatusDownloading);

  @override
  String get downloadSegmentsStatusFailed => _string(
      'downloadSegmentsStatusFailed', _fallback.downloadSegmentsStatusFailed);

  @override
  String downloadSegmentsSummary(
          Object total, Object completed, Object downloading) =>
      _format(
        'downloadSegmentsSummary',
        {
          'total': total,
          'completed': completed,
          'downloading': downloading,
        },
        _fallback.downloadSegmentsSummary(total, completed, downloading),
      );

  @override
  String downloadSegmentsSummaryWithFailed(
          Object total, Object completed, Object downloading, Object failed) =>
      _format(
        'downloadSegmentsSummaryWithFailed',
        {
          'total': total,
          'completed': completed,
          'downloading': downloading,
          'failed': failed,
        },
        _fallback.downloadSegmentsSummaryWithFailed(
            total, completed, downloading, failed),
      );

  @override
  String get downloadRetryButton =>
      _string('downloadRetryButton', _fallback.downloadRetryButton);

  @override
  String downloadSegmentLabel(Object index) => _format('downloadSegmentLabel',
      {'index': index}, _fallback.downloadSegmentLabel(index));

  @override
  String downloadSegmentRetryCount(Object count) => _format(
      'downloadSegmentRetryCount',
      {'count': count},
      _fallback.downloadSegmentRetryCount(count));

  @override
  String get downloadSegmentsCollapse =>
      _string('downloadSegmentsCollapse', _fallback.downloadSegmentsCollapse);

  @override
  String downloadSegmentsShowAll(Object count) => _format(
      'downloadSegmentsShowAll',
      {'count': count},
      _fallback.downloadSegmentsShowAll(count));

  @override
  String downloadSizeUnknown(Object downloaded) => _format(
      'downloadSizeUnknown',
      {'downloaded': downloaded},
      _fallback.downloadSizeUnknown(downloaded));

  @override
  String get downloadFailedTitle =>
      _string('downloadFailedTitle', _fallback.downloadFailedTitle);

  @override
  String downloadFailedSegmentsHint(Object count) => _format(
      'downloadFailedSegmentsHint',
      {'count': count},
      _fallback.downloadFailedSegmentsHint(count));

  @override
  String get downloadConfirmDeleteTitle => _string(
      'downloadConfirmDeleteTitle', _fallback.downloadConfirmDeleteTitle);

  @override
  String downloadConfirmDeleteMessage(Object fileName) => _format(
      'downloadConfirmDeleteMessage',
      {'fileName': fileName},
      _fallback.downloadConfirmDeleteMessage(fileName));

  @override
  String get downloadDeleteButton =>
      _string('downloadDeleteButton', _fallback.downloadDeleteButton);

  @override
  String get completedCategoryAll =>
      _string('completedCategoryAll', _fallback.completedCategoryAll);

  @override
  String get completedCategoryVideo =>
      _string('completedCategoryVideo', _fallback.completedCategoryVideo);

  @override
  String get completedCategoryAudio =>
      _string('completedCategoryAudio', _fallback.completedCategoryAudio);

  @override
  String get completedCategoryArchive =>
      _string('completedCategoryArchive', _fallback.completedCategoryArchive);

  @override
  String get completedCategoryDocument =>
      _string('completedCategoryDocument', _fallback.completedCategoryDocument);

  @override
  String get completedCategoryProgram =>
      _string('completedCategoryProgram', _fallback.completedCategoryProgram);

  @override
  String get completedCategoryOther =>
      _string('completedCategoryOther', _fallback.completedCategoryOther);

  @override
  String get completedSearchPlaceholder => _string(
      'completedSearchPlaceholder', _fallback.completedSearchPlaceholder);

  @override
  String get completedNoResultsTitle =>
      _string('completedNoResultsTitle', _fallback.completedNoResultsTitle);

  @override
  String get completedNoResultsSubtitle => _string(
      'completedNoResultsSubtitle', _fallback.completedNoResultsSubtitle);

  @override
  String get completedHeaderTitle =>
      _string('completedHeaderTitle', _fallback.completedHeaderTitle);

  @override
  String get completedOpenFolderButton =>
      _string('completedOpenFolderButton', _fallback.completedOpenFolderButton);

  @override
  String get completedEmptyTitle =>
      _string('completedEmptyTitle', _fallback.completedEmptyTitle);

  @override
  String get completedEmptySubtitle =>
      _string('completedEmptySubtitle', _fallback.completedEmptySubtitle);

  @override
  String get completedStatsTitle =>
      _string('completedStatsTitle', _fallback.completedStatsTitle);

  @override
  String get completedStatsPeakSpeed =>
      _string('completedStatsPeakSpeed', _fallback.completedStatsPeakSpeed);

  @override
  String get completedStatsAverageSpeed => _string(
      'completedStatsAverageSpeed', _fallback.completedStatsAverageSpeed);

  @override
  String get completedStatsDuration =>
      _string('completedStatsDuration', _fallback.completedStatsDuration);

  @override
  String get completedStatsSegments =>
      _string('completedStatsSegments', _fallback.completedStatsSegments);

  @override
  String get completedStatsThreads =>
      _string('completedStatsThreads', _fallback.completedStatsThreads);

  @override
  String get completedStatsCore =>
      _string('completedStatsCore', _fallback.completedStatsCore);

  @override
  String get completedActionRun =>
      _string('completedActionRun', _fallback.completedActionRun);

  @override
  String get completedActionLocation =>
      _string('completedActionLocation', _fallback.completedActionLocation);

  @override
  String get completedTimeJustNow =>
      _string('completedTimeJustNow', _fallback.completedTimeJustNow);

  @override
  String completedTimeMinutesAgo(Object minutes) => _format(
      'completedTimeMinutesAgo',
      {'minutes': minutes},
      _fallback.completedTimeMinutesAgo(minutes));

  @override
  String completedTimeHoursAgo(Object hours) => _format('completedTimeHoursAgo',
      {'hours': hours}, _fallback.completedTimeHoursAgo(hours));

  @override
  String completedTimeDaysAgo(Object days) => _format('completedTimeDaysAgo',
      {'days': days}, _fallback.completedTimeDaysAgo(days));

  @override
  String completedTimeMonthDay(Object month, Object day) => _format(
      'completedTimeMonthDay',
      {'month': month, 'day': day},
      _fallback.completedTimeMonthDay(month, day));

  @override
  String get completedFilePathMissingMessage => _string(
      'completedFilePathMissingMessage',
      _fallback.completedFilePathMissingMessage);

  @override
  String get completedFileNotFoundMessage => _string(
      'completedFileNotFoundMessage', _fallback.completedFileNotFoundMessage);

  @override
  String completedRunFileFailedMessage(Object error) => _format(
      'completedRunFileFailedMessage',
      {'error': error},
      _fallback.completedRunFileFailedMessage(error));

  @override
  String completedOpenFileLocationFailedMessage(Object error) => _format(
      'completedOpenFileLocationFailedMessage',
      {'error': error},
      _fallback.completedOpenFileLocationFailedMessage(error));

  @override
  String get completedHintTitle =>
      _string('completedHintTitle', _fallback.completedHintTitle);

  @override
  String get completedConfirmDeleteTitle => _string(
      'completedConfirmDeleteTitle', _fallback.completedConfirmDeleteTitle);

  @override
  String completedDeleteTaskMessage(Object fileName) => _format(
      'completedDeleteTaskMessage',
      {'fileName': fileName},
      _fallback.completedDeleteTaskMessage(fileName));

  @override
  String get completedRemoveSuccessTitle => _string(
      'completedRemoveSuccessTitle', _fallback.completedRemoveSuccessTitle);

  @override
  String get completedRemoveSuccessMessage => _string(
      'completedRemoveSuccessMessage', _fallback.completedRemoveSuccessMessage);

  @override
  String get completedDeleteSuccessTitle => _string(
      'completedDeleteSuccessTitle', _fallback.completedDeleteSuccessTitle);

  @override
  String completedDeleteFileSuccessMessage(Object fileName) => _format(
      'completedDeleteFileSuccessMessage',
      {'fileName': fileName},
      _fallback.completedDeleteFileSuccessMessage(fileName));

  @override
  String get completedFileNotFoundTitle => _string(
      'completedFileNotFoundTitle', _fallback.completedFileNotFoundTitle);

  @override
  String get completedDeleteFailedTitle => _string(
      'completedDeleteFailedTitle', _fallback.completedDeleteFailedTitle);

  @override
  String completedDeleteFailedMessage(Object error) => _format(
      'completedDeleteFailedMessage',
      {'error': error},
      _fallback.completedDeleteFailedMessage(error));

  @override
  String get completedCancelButton =>
      _string('completedCancelButton', _fallback.completedCancelButton);

  @override
  String get completedRemoveButton =>
      _string('completedRemoveButton', _fallback.completedRemoveButton);

  @override
  String get completedDeleteButton =>
      _string('completedDeleteButton', _fallback.completedDeleteButton);

  @override
  String get completedCreateButton =>
      _string('completedCreateButton', _fallback.completedCreateButton);

  @override
  String get completedCreateCategoryTitle => _string(
      'completedCreateCategoryTitle', _fallback.completedCreateCategoryTitle);

  @override
  String get completedCreateCategoryNameLabel => _string(
      'completedCreateCategoryNameLabel',
      _fallback.completedCreateCategoryNameLabel);

  @override
  String get completedCreateCategoryNamePlaceholder => _string(
      'completedCreateCategoryNamePlaceholder',
      _fallback.completedCreateCategoryNamePlaceholder);

  @override
  String get completedCreateCategoryExtensionsLabel => _string(
      'completedCreateCategoryExtensionsLabel',
      _fallback.completedCreateCategoryExtensionsLabel);

  @override
  String get completedCreateCategoryExtensionsPlaceholder => _string(
      'completedCreateCategoryExtensionsPlaceholder',
      _fallback.completedCreateCategoryExtensionsPlaceholder);

  @override
  String get completedCreateCategoryHint => _string(
      'completedCreateCategoryHint', _fallback.completedCreateCategoryHint);

  @override
  String get completedCreateCategoryInputErrorTitle => _string(
      'completedCreateCategoryInputErrorTitle',
      _fallback.completedCreateCategoryInputErrorTitle);

  @override
  String get completedCreateCategoryInputErrorMessage => _string(
      'completedCreateCategoryInputErrorMessage',
      _fallback.completedCreateCategoryInputErrorMessage);

  @override
  String get completedCreateCategoryInvalidExtMessage => _string(
      'completedCreateCategoryInvalidExtMessage',
      _fallback.completedCreateCategoryInvalidExtMessage);

  @override
  String get completedCreateCategorySuccessTitle => _string(
      'completedCreateCategorySuccessTitle',
      _fallback.completedCreateCategorySuccessTitle);

  @override
  String completedCreateCategorySuccessMessage(Object name) => _format(
      'completedCreateCategorySuccessMessage',
      {'name': name},
      _fallback.completedCreateCategorySuccessMessage(name));

  @override
  String completedDeleteCategoryMessage(Object name) => _format(
      'completedDeleteCategoryMessage',
      {'name': name},
      _fallback.completedDeleteCategoryMessage(name));

  @override
  String get completedDeleteCategorySuccessTitle => _string(
      'completedDeleteCategorySuccessTitle',
      _fallback.completedDeleteCategorySuccessTitle);

  @override
  String completedDeleteCategorySuccessMessage(Object name) => _format(
      'completedDeleteCategorySuccessMessage',
      {'name': name},
      _fallback.completedDeleteCategorySuccessMessage(name));

  @override
  String get statusPageTitle =>
      _string('statusPageTitle', _fallback.statusPageTitle);

  @override
  String get statusPageRefresh =>
      _string('statusPageRefresh', _fallback.statusPageRefresh);

  @override
  String get statusPageTestApi =>
      _string('statusPageTestApi', _fallback.statusPageTestApi);

  @override
  String get statusPageClearLogs =>
      _string('statusPageClearLogs', _fallback.statusPageClearLogs);

  @override
  String get statusSectionKernel =>
      _string('statusSectionKernel', _fallback.statusSectionKernel);

  @override
  String get statusItemKernelRuntime =>
      _string('statusItemKernelRuntime', _fallback.statusItemKernelRuntime);

  @override
  String get statusValueRunning =>
      _string('statusValueRunning', _fallback.statusValueRunning);

  @override
  String get statusValueStopped =>
      _string('statusValueStopped', _fallback.statusValueStopped);

  @override
  String get statusItemKernelCurrent =>
      _string('statusItemKernelCurrent', _fallback.statusItemKernelCurrent);

  @override
  String get statusItemHttpService =>
      _string('statusItemHttpService', _fallback.statusItemHttpService);

  @override
  String get statusValueHealthy =>
      _string('statusValueHealthy', _fallback.statusValueHealthy);

  @override
  String get statusValueBuiltIn =>
      _string('statusValueBuiltIn', _fallback.statusValueBuiltIn);

  @override
  String get statusValueUnhealthy =>
      _string('statusValueUnhealthy', _fallback.statusValueUnhealthy);

  @override
  String get statusItemServiceAddress =>
      _string('statusItemServiceAddress', _fallback.statusItemServiceAddress);

  @override
  String get statusItemKernelVersion =>
      _string('statusItemKernelVersion', _fallback.statusItemKernelVersion);

  @override
  String get statusSectionNetwork =>
      _string('statusSectionNetwork', _fallback.statusSectionNetwork);

  @override
  String get statusItemLocalNetwork =>
      _string('statusItemLocalNetwork', _fallback.statusItemLocalNetwork);

  @override
  String get statusValueConnected =>
      _string('statusValueConnected', _fallback.statusValueConnected);

  @override
  String get statusValueDisconnected =>
      _string('statusValueDisconnected', _fallback.statusValueDisconnected);

  @override
  String get statusItemInternet =>
      _string('statusItemInternet', _fallback.statusItemInternet);

  @override
  String get statusValueReachable =>
      _string('statusValueReachable', _fallback.statusValueReachable);

  @override
  String get statusValueUnreachable =>
      _string('statusValueUnreachable', _fallback.statusValueUnreachable);

  @override
  String get statusItemLocalIp =>
      _string('statusItemLocalIp', _fallback.statusItemLocalIp);

  @override
  String get statusItemNetworkLatency =>
      _string('statusItemNetworkLatency', _fallback.statusItemNetworkLatency);

  @override
  String statusNetworkLatencyMs(Object ms) => _format('statusNetworkLatencyMs',
      {'ms': ms}, _fallback.statusNetworkLatencyMs(ms));

  @override
  String get statusItemConnectionType =>
      _string('statusItemConnectionType', _fallback.statusItemConnectionType);

  @override
  String get statusSectionApiTests =>
      _string('statusSectionApiTests', _fallback.statusSectionApiTests);

  @override
  String get statusValueFailed =>
      _string('statusValueFailed', _fallback.statusValueFailed);

  @override
  String get statusSectionSystemInfo =>
      _string('statusSectionSystemInfo', _fallback.statusSectionSystemInfo);

  @override
  String get statusItemOs => _string('statusItemOs', _fallback.statusItemOs);

  @override
  String get statusValueUnknown =>
      _string('statusValueUnknown', _fallback.statusValueUnknown);

  @override
  String get statusItemOsVersion =>
      _string('statusItemOsVersion', _fallback.statusItemOsVersion);

  @override
  String get statusItemCpuCores =>
      _string('statusItemCpuCores', _fallback.statusItemCpuCores);

  @override
  String statusSystemCpuCores(Object count) => _format('statusSystemCpuCores',
      {'count': count}, _fallback.statusSystemCpuCores(count));

  @override
  String get statusItemDartVersion =>
      _string('statusItemDartVersion', _fallback.statusItemDartVersion);

  @override
  String get statusSectionDownloadStats => _string(
      'statusSectionDownloadStats', _fallback.statusSectionDownloadStats);

  @override
  String get statusItemTotalDownloads =>
      _string('statusItemTotalDownloads', _fallback.statusItemTotalDownloads);

  @override
  String get statusItemActiveTasks =>
      _string('statusItemActiveTasks', _fallback.statusItemActiveTasks);

  @override
  String get statusItemCompletedTasks =>
      _string('statusItemCompletedTasks', _fallback.statusItemCompletedTasks);

  @override
  String get statusItemFailedTasks =>
      _string('statusItemFailedTasks', _fallback.statusItemFailedTasks);

  @override
  String get statusItemTotalDownloaded =>
      _string('statusItemTotalDownloaded', _fallback.statusItemTotalDownloaded);

  @override
  String get statusSectionLogStats =>
      _string('statusSectionLogStats', _fallback.statusSectionLogStats);

  @override
  String get statusItemLogCount =>
      _string('statusItemLogCount', _fallback.statusItemLogCount);

  @override
  String get statusItemErrorCount =>
      _string('statusItemErrorCount', _fallback.statusItemErrorCount);

  @override
  String get statusItemWarningCount =>
      _string('statusItemWarningCount', _fallback.statusItemWarningCount);

  @override
  String get statusSectionExtension =>
      _string('statusSectionExtension', _fallback.statusSectionExtension);

  @override
  String get statusItemTip => _string('statusItemTip', _fallback.statusItemTip);

  @override
  String get statusExtensionTip =>
      _string('statusExtensionTip', _fallback.statusExtensionTip);

  @override
  String get statusExtensionDownloadButton => _string(
      'statusExtensionDownloadButton', _fallback.statusExtensionDownloadButton);

  @override
  String get statusExtensionOpenStoreButton => _string(
      'statusExtensionOpenStoreButton',
      _fallback.statusExtensionOpenStoreButton);

  @override
  String get statusSectionAutoStart =>
      _string('statusSectionAutoStart', _fallback.statusSectionAutoStart);

  @override
  String get statusItemPlatformSupport =>
      _string('statusItemPlatformSupport', _fallback.statusItemPlatformSupport);

  @override
  String get statusAutoStartWindowsOnly => _string(
      'statusAutoStartWindowsOnly', _fallback.statusAutoStartWindowsOnly);

  @override
  String get statusItemAutoStartStatus =>
      _string('statusItemAutoStartStatus', _fallback.statusItemAutoStartStatus);

  @override
  String get statusValueEnabled =>
      _string('statusValueEnabled', _fallback.statusValueEnabled);

  @override
  String get statusValueDisabled =>
      _string('statusValueDisabled', _fallback.statusValueDisabled);

  @override
  String get statusItemRegistryPath =>
      _string('statusItemRegistryPath', _fallback.statusItemRegistryPath);

  @override
  String get statusValueCorrect =>
      _string('statusValueCorrect', _fallback.statusValueCorrect);

  @override
  String get statusValueNeedsUpdate =>
      _string('statusValueNeedsUpdate', _fallback.statusValueNeedsUpdate);

  @override
  String get statusItemCurrentRegistry =>
      _string('statusItemCurrentRegistry', _fallback.statusItemCurrentRegistry);

  @override
  String get statusItemCurrentPath =>
      _string('statusItemCurrentPath', _fallback.statusItemCurrentPath);

  @override
  String get statusAutoStartOldRegistryTitle => _string(
      'statusAutoStartOldRegistryTitle',
      _fallback.statusAutoStartOldRegistryTitle);

  @override
  String get statusAutoStartOldRegistryMessage => _string(
      'statusAutoStartOldRegistryMessage',
      _fallback.statusAutoStartOldRegistryMessage);

  @override
  String get statusAutoStartFixButton =>
      _string('statusAutoStartFixButton', _fallback.statusAutoStartFixButton);

  @override
  String get statusSectionPopupTest =>
      _string('statusSectionPopupTest', _fallback.statusSectionPopupTest);

  @override
  String get statusItemDescription =>
      _string('statusItemDescription', _fallback.statusItemDescription);

  @override
  String get statusPopupTestDescription => _string(
      'statusPopupTestDescription', _fallback.statusPopupTestDescription);

  @override
  String get statusItemTestResult =>
      _string('statusItemTestResult', _fallback.statusItemTestResult);

  @override
  String statusPopupTestResultSuccess(Object time) => _format(
      'statusPopupTestResultSuccess',
      {'time': time},
      _fallback.statusPopupTestResultSuccess(time));

  @override
  String statusPopupTestResultFailed(Object error) => _format(
      'statusPopupTestResultFailed',
      {'error': error},
      _fallback.statusPopupTestResultFailed(error));

  @override
  String get statusPopupTesting =>
      _string('statusPopupTesting', _fallback.statusPopupTesting);

  @override
  String get statusPopupTestButton =>
      _string('statusPopupTestButton', _fallback.statusPopupTestButton);

  @override
  String get statusPopupDialogTestButton => _string(
      'statusPopupDialogTestButton', _fallback.statusPopupDialogTestButton);

  @override
  String get statusPopupTestInfoTitle =>
      _string('statusPopupTestInfoTitle', _fallback.statusPopupTestInfoTitle);

  @override
  String get statusPopupTestInfoBody =>
      _string('statusPopupTestInfoBody', _fallback.statusPopupTestInfoBody);

  @override
  String get statusExtensionDownloadAddedTitle => _string(
      'statusExtensionDownloadAddedTitle',
      _fallback.statusExtensionDownloadAddedTitle);

  @override
  String get statusExtensionDownloadAddedMessage => _string(
      'statusExtensionDownloadAddedMessage',
      _fallback.statusExtensionDownloadAddedMessage);

  @override
  String get statusExtensionDownloadFailedTitle => _string(
      'statusExtensionDownloadFailedTitle',
      _fallback.statusExtensionDownloadFailedTitle);

  @override
  String statusExtensionDownloadFailedMessage(Object error) => _format(
      'statusExtensionDownloadFailedMessage',
      {'error': error},
      _fallback.statusExtensionDownloadFailedMessage(error));

  @override
  String get statusExtensionOpenLinkFailed => _string(
      'statusExtensionOpenLinkFailed', _fallback.statusExtensionOpenLinkFailed);

  @override
  String get statusExtensionOpenFailedTitle => _string(
      'statusExtensionOpenFailedTitle',
      _fallback.statusExtensionOpenFailedTitle);

  @override
  String statusExtensionOpenFailedMessage(Object error) => _format(
      'statusExtensionOpenFailedMessage',
      {'error': error},
      _fallback.statusExtensionOpenFailedMessage(error));

  @override
  String get statusAutoStartFixSuccessTitle => _string(
      'statusAutoStartFixSuccessTitle',
      _fallback.statusAutoStartFixSuccessTitle);

  @override
  String get statusAutoStartFixSuccessMessage => _string(
      'statusAutoStartFixSuccessMessage',
      _fallback.statusAutoStartFixSuccessMessage);

  @override
  String get statusAutoStartFixFailedTitle => _string(
      'statusAutoStartFixFailedTitle', _fallback.statusAutoStartFixFailedTitle);

  @override
  String get statusAutoStartFixFailedMessage => _string(
      'statusAutoStartFixFailedMessage',
      _fallback.statusAutoStartFixFailedMessage);

  @override
  String statusAutoStartFixErrorMessage(Object error) => _format(
      'statusAutoStartFixErrorMessage',
      {'error': error},
      _fallback.statusAutoStartFixErrorMessage(error));

  @override
  String get statusPopupTestCreating =>
      _string('statusPopupTestCreating', _fallback.statusPopupTestCreating);

  @override
  String get statusPopupTestStartLog =>
      _string('statusPopupTestStartLog', _fallback.statusPopupTestStartLog);

  @override
  String statusPopupTestSuccessLog(Object time) => _format(
      'statusPopupTestSuccessLog',
      {'time': time},
      _fallback.statusPopupTestSuccessLog(time));

  @override
  String get statusPopupTestSuccessMessage => _string(
      'statusPopupTestSuccessMessage', _fallback.statusPopupTestSuccessMessage);

  @override
  String get statusPopupTestSuccessTitle => _string(
      'statusPopupTestSuccessTitle', _fallback.statusPopupTestSuccessTitle);

  @override
  String statusPopupTestSuccessToast(Object time) => _format(
      'statusPopupTestSuccessToast',
      {'time': time},
      _fallback.statusPopupTestSuccessToast(time));

  @override
  String statusPopupTestFailedLog(Object error) => _format(
      'statusPopupTestFailedLog',
      {'error': error},
      _fallback.statusPopupTestFailedLog(error));

  @override
  String get statusPopupTestFailedTitle => _string(
      'statusPopupTestFailedTitle', _fallback.statusPopupTestFailedTitle);

  @override
  String statusPopupTestFailedToast(Object error) => _format(
      'statusPopupTestFailedToast',
      {'error': error},
      _fallback.statusPopupTestFailedToast(error));

  @override
  String get statusPopupDialogTestStartLog => _string(
      'statusPopupDialogTestStartLog', _fallback.statusPopupDialogTestStartLog);

  @override
  String statusPopupDialogTestCloseLog(Object time) => _format(
      'statusPopupDialogTestCloseLog',
      {'time': time},
      _fallback.statusPopupDialogTestCloseLog(time));

  @override
  String statusPopupDialogTestFailedLog(Object error) => _format(
      'statusPopupDialogTestFailedLog',
      {'error': error},
      _fallback.statusPopupDialogTestFailedLog(error));

  @override
  String get statusApiTestHealthCheck =>
      _string('statusApiTestHealthCheck', _fallback.statusApiTestHealthCheck);

  @override
  String get statusApiTestGetTasks =>
      _string('statusApiTestGetTasks', _fallback.statusApiTestGetTasks);

  @override
  String get statusApiTestGetStatistics => _string(
      'statusApiTestGetStatistics', _fallback.statusApiTestGetStatistics);

  @override
  String get statusApiTestGetConfig =>
      _string('statusApiTestGetConfig', _fallback.statusApiTestGetConfig);

  @override
  String get onlineStatsPageTitle =>
      _string('onlineStatsPageTitle', _fallback.onlineStatsPageTitle);

  @override
  String get onlineStatsCountUnit =>
      _string('onlineStatsCountUnit', _fallback.onlineStatsCountUnit);

  @override
  String get onlineStatsAloneMessage =>
      _string('onlineStatsAloneMessage', _fallback.onlineStatsAloneMessage);

  @override
  String onlineStatsOthersMessage(Object count) => _format(
      'onlineStatsOthersMessage',
      {'count': count},
      _fallback.onlineStatsOthersMessage(count));

  @override
  String onlineStatsTotalMessage(Object count) => _format(
      'onlineStatsTotalMessage',
      {'count': count},
      _fallback.onlineStatsTotalMessage(count));

  @override
  String get onlineStatsMyStatusTitle =>
      _string('onlineStatsMyStatusTitle', _fallback.onlineStatsMyStatusTitle);

  @override
  String get onlineStatsDeviceIdLabel =>
      _string('onlineStatsDeviceIdLabel', _fallback.onlineStatsDeviceIdLabel);

  @override
  String get onlineStatsNotInitialized =>
      _string('onlineStatsNotInitialized', _fallback.onlineStatsNotInitialized);

  @override
  String get onlineStatsAppVersionLabel => _string(
      'onlineStatsAppVersionLabel', _fallback.onlineStatsAppVersionLabel);

  @override
  String get onlineStatsHeartbeatLabel =>
      _string('onlineStatsHeartbeatLabel', _fallback.onlineStatsHeartbeatLabel);

  @override
  String get onlineStatsHeartbeatValue =>
      _string('onlineStatsHeartbeatValue', _fallback.onlineStatsHeartbeatValue);

  @override
  String get onlineStatsServerLabel =>
      _string('onlineStatsServerLabel', _fallback.onlineStatsServerLabel);

  @override
  String get onlineStatsSending =>
      _string('onlineStatsSending', _fallback.onlineStatsSending);

  @override
  String get onlineStatsSendSignalButton => _string(
      'onlineStatsSendSignalButton', _fallback.onlineStatsSendSignalButton);

  @override
  String get onlineStatsPrivacyPolicy =>
      _string('onlineStatsPrivacyPolicy', _fallback.onlineStatsPrivacyPolicy);

  @override
  String get onlineStatsTermsOfService =>
      _string('onlineStatsTermsOfService', _fallback.onlineStatsTermsOfService);

  @override
  String get onlineStatsOfficialSite =>
      _string('onlineStatsOfficialSite', _fallback.onlineStatsOfficialSite);

  @override
  String get onlineStatsSendSuccessTitle => _string(
      'onlineStatsSendSuccessTitle', _fallback.onlineStatsSendSuccessTitle);

  @override
  String get onlineStatsSendSuccessMessage => _string(
      'onlineStatsSendSuccessMessage', _fallback.onlineStatsSendSuccessMessage);

  @override
  String get onlineStatsCooldownTitle =>
      _string('onlineStatsCooldownTitle', _fallback.onlineStatsCooldownTitle);

  @override
  String onlineStatsCooldownMessage(Object minutes) => _format(
      'onlineStatsCooldownMessage',
      {'minutes': minutes},
      _fallback.onlineStatsCooldownMessage(minutes));

  @override
  String get onlineStatsSendFailedTitle => _string(
      'onlineStatsSendFailedTitle', _fallback.onlineStatsSendFailedTitle);

  @override
  String get onlineStatsSendFailedMessage => _string(
      'onlineStatsSendFailedMessage', _fallback.onlineStatsSendFailedMessage);

  @override
  String get onlineStatsOpenLinkFailedTitle => _string(
      'onlineStatsOpenLinkFailedTitle',
      _fallback.onlineStatsOpenLinkFailedTitle);

  @override
  String onlineStatsOpenLinkFailedMessage(Object url) => _format(
      'onlineStatsOpenLinkFailedMessage',
      {'url': url},
      _fallback.onlineStatsOpenLinkFailedMessage(url));

  @override
  String get onlineStatsOpenFailedTitle => _string(
      'onlineStatsOpenFailedTitle', _fallback.onlineStatsOpenFailedTitle);

  @override
  String onlineStatsOpenFailedMessage(Object error, Object url) => _format(
      'onlineStatsOpenFailedMessage',
      {'error': error, 'url': url},
      _fallback.onlineStatsOpenFailedMessage(error, url));

  @override
  String get onlineStatsDialogOk =>
      _string('onlineStatsDialogOk', _fallback.onlineStatsDialogOk);

  @override
  String get logPageTitle => _string('logPageTitle', _fallback.logPageTitle);

  @override
  String get logFilterLevelLabel =>
      _string('logFilterLevelLabel', _fallback.logFilterLevelLabel);

  @override
  String logFilterTagCount(Object count) => _format('logFilterTagCount',
      {'count': count}, _fallback.logFilterTagCount(count));

  @override
  String get logFilterSourceLabel =>
      _string('logFilterSourceLabel', _fallback.logFilterSourceLabel);

  @override
  String get logFilterTimeSelectedLabel => _string(
      'logFilterTimeSelectedLabel', _fallback.logFilterTimeSelectedLabel);

  @override
  String get logFilterTimeLabel =>
      _string('logFilterTimeLabel', _fallback.logFilterTimeLabel);

  @override
  String get logRegexRulesButton =>
      _string('logRegexRulesButton', _fallback.logRegexRulesButton);

  @override
  String get logAutoScrollOn =>
      _string('logAutoScrollOn', _fallback.logAutoScrollOn);

  @override
  String get logAutoScrollOff =>
      _string('logAutoScrollOff', _fallback.logAutoScrollOff);

  @override
  String get logStatsShow => _string('logStatsShow', _fallback.logStatsShow);

  @override
  String get logStatsHide => _string('logStatsHide', _fallback.logStatsHide);

  @override
  String get logFailureStatsShow =>
      _string('logFailureStatsShow', _fallback.logFailureStatsShow);

  @override
  String get logFailureStatsHide =>
      _string('logFailureStatsHide', _fallback.logFailureStatsHide);

  @override
  String get logExportLogsButton =>
      _string('logExportLogsButton', _fallback.logExportLogsButton);

  @override
  String get logExportDiagnosticsButton => _string(
      'logExportDiagnosticsButton', _fallback.logExportDiagnosticsButton);

  @override
  String get logArchiveButton =>
      _string('logArchiveButton', _fallback.logArchiveButton);

  @override
  String get logClearButton =>
      _string('logClearButton', _fallback.logClearButton);

  @override
  String get logCurrentTabLabel =>
      _string('logCurrentTabLabel', _fallback.logCurrentTabLabel);

  @override
  String get logFullTabLabel =>
      _string('logFullTabLabel', _fallback.logFullTabLabel);

  @override
  String get logSearchPlaceholderRegex =>
      _string('logSearchPlaceholderRegex', _fallback.logSearchPlaceholderRegex);

  @override
  String get logSearchPlaceholder =>
      _string('logSearchPlaceholder', _fallback.logSearchPlaceholder);

  @override
  String get logEmptyTitle => _string('logEmptyTitle', _fallback.logEmptyTitle);

  @override
  String get logEmptySubtitle =>
      _string('logEmptySubtitle', _fallback.logEmptySubtitle);

  @override
  String get logStatTotal => _string('logStatTotal', _fallback.logStatTotal);

  @override
  String logGroupedCount(Object count) => _format(
      'logGroupedCount', {'count': count}, _fallback.logGroupedCount(count));

  @override
  String get logClearFiltersButton =>
      _string('logClearFiltersButton', _fallback.logClearFiltersButton);

  @override
  String get logFailureStatsTitle =>
      _string('logFailureStatsTitle', _fallback.logFailureStatsTitle);

  @override
  String logFailureStatsTotal(Object count) => _format('logFailureStatsTotal',
      {'count': count}, _fallback.logFailureStatsTotal(count));

  @override
  String get logFailureStatsEmpty =>
      _string('logFailureStatsEmpty', _fallback.logFailureStatsEmpty);

  @override
  String get logFailureReasonUnknown =>
      _string('logFailureReasonUnknown', _fallback.logFailureReasonUnknown);

  @override
  String logFailureReasonAuth(Object code) => _format('logFailureReasonAuth',
      {'code': code}, _fallback.logFailureReasonAuth(code));

  @override
  String logFailureReasonNotFound(Object code) => _format(
      'logFailureReasonNotFound',
      {'code': code},
      _fallback.logFailureReasonNotFound(code));

  @override
  String get logFailureReasonRange =>
      _string('logFailureReasonRange', _fallback.logFailureReasonRange);

  @override
  String logFailureReasonRangeWithCode(Object code) => _format(
      'logFailureReasonRangeWithCode',
      {'code': code},
      _fallback.logFailureReasonRangeWithCode(code));

  @override
  String logFailureReasonTooManyRequests(Object code) => _format(
      'logFailureReasonTooManyRequests',
      {'code': code},
      _fallback.logFailureReasonTooManyRequests(code));

  @override
  String logFailureReasonServerError(Object code) => _format(
      'logFailureReasonServerError',
      {'code': code},
      _fallback.logFailureReasonServerError(code));

  @override
  String logFailureReasonHttpError(Object code) => _format(
      'logFailureReasonHttpError',
      {'code': code},
      _fallback.logFailureReasonHttpError(code));

  @override
  String get logFailureReasonTimeout =>
      _string('logFailureReasonTimeout', _fallback.logFailureReasonTimeout);

  @override
  String get logFailureReasonConnection => _string(
      'logFailureReasonConnection', _fallback.logFailureReasonConnection);

  @override
  String get logFailureReasonDns =>
      _string('logFailureReasonDns', _fallback.logFailureReasonDns);

  @override
  String get logFailureReasonSsl =>
      _string('logFailureReasonSsl', _fallback.logFailureReasonSsl);

  @override
  String get logFailureReasonChecksum =>
      _string('logFailureReasonChecksum', _fallback.logFailureReasonChecksum);

  @override
  String get logFailureReasonDisk =>
      _string('logFailureReasonDisk', _fallback.logFailureReasonDisk);

  @override
  String get logFailureReasonOther =>
      _string('logFailureReasonOther', _fallback.logFailureReasonOther);

  @override
  String logTimeRangeRecentMinutes(Object minutes) => _format(
      'logTimeRangeRecentMinutes',
      {'minutes': minutes},
      _fallback.logTimeRangeRecentMinutes(minutes));

  @override
  String logTimeRangeRecentHours(Object hours) => _format(
      'logTimeRangeRecentHours',
      {'hours': hours},
      _fallback.logTimeRangeRecentHours(hours));

  @override
  String get logTimeRangeLabel =>
      _string('logTimeRangeLabel', _fallback.logTimeRangeLabel);

  @override
  String get logStatCountUnit =>
      _string('logStatCountUnit', _fallback.logStatCountUnit);

  @override
  String logRepeatedCount(Object count) => _format(
      'logRepeatedCount', {'count': count}, _fallback.logRepeatedCount(count));

  @override
  String logRepeatedMore(Object count) => _format(
      'logRepeatedMore', {'count': count}, _fallback.logRepeatedMore(count));

  @override
  String get logContextCopy =>
      _string('logContextCopy', _fallback.logContextCopy);

  @override
  String logContextRepeated(Object count) => _format('logContextRepeated',
      {'count': count}, _fallback.logContextRepeated(count));

  @override
  String get logContextRemoveBookmark =>
      _string('logContextRemoveBookmark', _fallback.logContextRemoveBookmark);

  @override
  String get logContextAddBookmark =>
      _string('logContextAddBookmark', _fallback.logContextAddBookmark);

  @override
  String logContextFilterLevel(Object level) => _format('logContextFilterLevel',
      {'level': level}, _fallback.logContextFilterLevel(level));

  @override
  String logContextFilterSource(Object source) => _format(
      'logContextFilterSource',
      {'source': source},
      _fallback.logContextFilterSource(source));

  @override
  String get logContextCopySingle =>
      _string('logContextCopySingle', _fallback.logContextCopySingle);

  @override
  String get logFilterLevelTitle =>
      _string('logFilterLevelTitle', _fallback.logFilterLevelTitle);

  @override
  String get logFilterAllLabel =>
      _string('logFilterAllLabel', _fallback.logFilterAllLabel);

  @override
  String get logDialogClose =>
      _string('logDialogClose', _fallback.logDialogClose);

  @override
  String get logSourceFilterTitle =>
      _string('logSourceFilterTitle', _fallback.logSourceFilterTitle);

  @override
  String logSourceTotalCount(Object count) => _format('logSourceTotalCount',
      {'count': count}, _fallback.logSourceTotalCount(count));

  @override
  String get logSourceCategoryKernel =>
      _string('logSourceCategoryKernel', _fallback.logSourceCategoryKernel);

  @override
  String logSourceKernelSubtitle(Object count) => _format(
      'logSourceKernelSubtitle',
      {'count': count},
      _fallback.logSourceKernelSubtitle(count));

  @override
  String get logSourceCategoryApp =>
      _string('logSourceCategoryApp', _fallback.logSourceCategoryApp);

  @override
  String logSourceAppSubtitle(Object count) => _format('logSourceAppSubtitle',
      {'count': count}, _fallback.logSourceAppSubtitle(count));

  @override
  String get logSourceCategorySystem =>
      _string('logSourceCategorySystem', _fallback.logSourceCategorySystem);

  @override
  String logSourceSystemSubtitle(Object count) => _format(
      'logSourceSystemSubtitle',
      {'count': count},
      _fallback.logSourceSystemSubtitle(count));

  @override
  String get logDialogOk => _string('logDialogOk', _fallback.logDialogOk);

  @override
  String get logDialogCancel =>
      _string('logDialogCancel', _fallback.logDialogCancel);

  @override
  String get logTimeRangeTitle =>
      _string('logTimeRangeTitle', _fallback.logTimeRangeTitle);

  @override
  String get logTimeRangeQuickSelectLabel => _string(
      'logTimeRangeQuickSelectLabel', _fallback.logTimeRangeQuickSelectLabel);

  @override
  String get logTimeRangePreset1Hour =>
      _string('logTimeRangePreset1Hour', _fallback.logTimeRangePreset1Hour);

  @override
  String get logTimeRangePreset30Min =>
      _string('logTimeRangePreset30Min', _fallback.logTimeRangePreset30Min);

  @override
  String get logTimeRangePreset10Min =>
      _string('logTimeRangePreset10Min', _fallback.logTimeRangePreset10Min);

  @override
  String get logTimeRangePreset5Min =>
      _string('logTimeRangePreset5Min', _fallback.logTimeRangePreset5Min);

  @override
  String get logTimeRangeStartLabel =>
      _string('logTimeRangeStartLabel', _fallback.logTimeRangeStartLabel);

  @override
  String get logTimeRangeEndLabel =>
      _string('logTimeRangeEndLabel', _fallback.logTimeRangeEndLabel);

  @override
  String get logTimeRangeNotSet =>
      _string('logTimeRangeNotSet', _fallback.logTimeRangeNotSet);

  @override
  String get logTimeRangeNow =>
      _string('logTimeRangeNow', _fallback.logTimeRangeNow);

  @override
  String get logDialogClear =>
      _string('logDialogClear', _fallback.logDialogClear);

  @override
  String get logDialogApply =>
      _string('logDialogApply', _fallback.logDialogApply);

  @override
  String get logRulesDialogTitle =>
      _string('logRulesDialogTitle', _fallback.logRulesDialogTitle);

  @override
  String get logRulesBuiltinTitle =>
      _string('logRulesBuiltinTitle', _fallback.logRulesBuiltinTitle);

  @override
  String get logRulesCustomTitle =>
      _string('logRulesCustomTitle', _fallback.logRulesCustomTitle);

  @override
  String get logRulesAddButton =>
      _string('logRulesAddButton', _fallback.logRulesAddButton);

  @override
  String get logRulesCustomEmpty =>
      _string('logRulesCustomEmpty', _fallback.logRulesCustomEmpty);

  @override
  String get logRulesLegendTitle =>
      _string('logRulesLegendTitle', _fallback.logRulesLegendTitle);

  @override
  String get logRulesLegendUrl =>
      _string('logRulesLegendUrl', _fallback.logRulesLegendUrl);

  @override
  String get logRulesLegendPath =>
      _string('logRulesLegendPath', _fallback.logRulesLegendPath);

  @override
  String get logRulesLegendIp =>
      _string('logRulesLegendIp', _fallback.logRulesLegendIp);

  @override
  String get logRulesLegendNumber =>
      _string('logRulesLegendNumber', _fallback.logRulesLegendNumber);

  @override
  String get logRulesLegendError =>
      _string('logRulesLegendError', _fallback.logRulesLegendError);

  @override
  String get logRulesLegendSuccess =>
      _string('logRulesLegendSuccess', _fallback.logRulesLegendSuccess);

  @override
  String get logRulesLegendWarning =>
      _string('logRulesLegendWarning', _fallback.logRulesLegendWarning);

  @override
  String get logRulesLegendHttp =>
      _string('logRulesLegendHttp', _fallback.logRulesLegendHttp);

  @override
  String get logRulesLegendStep =>
      _string('logRulesLegendStep', _fallback.logRulesLegendStep);

  @override
  String get logRulesLegendPid =>
      _string('logRulesLegendPid', _fallback.logRulesLegendPid);

  @override
  String get logRulesLegendKeyValue =>
      _string('logRulesLegendKeyValue', _fallback.logRulesLegendKeyValue);

  @override
  String get logAddRuleTitle =>
      _string('logAddRuleTitle', _fallback.logAddRuleTitle);

  @override
  String get logAddRuleNameLabel =>
      _string('logAddRuleNameLabel', _fallback.logAddRuleNameLabel);

  @override
  String get logAddRuleNamePlaceholder =>
      _string('logAddRuleNamePlaceholder', _fallback.logAddRuleNamePlaceholder);

  @override
  String get logAddRulePatternLabel =>
      _string('logAddRulePatternLabel', _fallback.logAddRulePatternLabel);

  @override
  String get logAddRulePatternPlaceholder => _string(
      'logAddRulePatternPlaceholder', _fallback.logAddRulePatternPlaceholder);

  @override
  String get logAddRuleColorLabel =>
      _string('logAddRuleColorLabel', _fallback.logAddRuleColorLabel);

  @override
  String get logAddRuleInvalidTitle =>
      _string('logAddRuleInvalidTitle', _fallback.logAddRuleInvalidTitle);

  @override
  String logAddRuleInvalidMessage(Object error) => _format(
      'logAddRuleInvalidMessage',
      {'error': error},
      _fallback.logAddRuleInvalidMessage(error));

  @override
  String get logArchiveTitle =>
      _string('logArchiveTitle', _fallback.logArchiveTitle);

  @override
  String get logArchivePrompt =>
      _string('logArchivePrompt', _fallback.logArchivePrompt);

  @override
  String get logArchiveExportAll =>
      _string('logArchiveExportAll', _fallback.logArchiveExportAll);

  @override
  String get logArchiveExportFiltered =>
      _string('logArchiveExportFiltered', _fallback.logArchiveExportFiltered);

  @override
  String get logArchiveExportFull =>
      _string('logArchiveExportFull', _fallback.logArchiveExportFull);

  @override
  String logArchiveExportBookmarked(Object count) => _format(
      'logArchiveExportBookmarked',
      {'count': count},
      _fallback.logArchiveExportBookmarked(count));

  @override
  String get logClearConfirmTitle =>
      _string('logClearConfirmTitle', _fallback.logClearConfirmTitle);

  @override
  String get logClearConfirmMessage =>
      _string('logClearConfirmMessage', _fallback.logClearConfirmMessage);

  @override
  String get logClearConfirmButton =>
      _string('logClearConfirmButton', _fallback.logClearConfirmButton);

  @override
  String get logExportSuccessTitle =>
      _string('logExportSuccessTitle', _fallback.logExportSuccessTitle);

  @override
  String logExportSavedMessage(Object path) => _format('logExportSavedMessage',
      {'path': path}, _fallback.logExportSavedMessage(path));

  @override
  String get logExportFailedTitle =>
      _string('logExportFailedTitle', _fallback.logExportFailedTitle);

  @override
  String logExportFailedMessage(Object error) => _format(
      'logExportFailedMessage',
      {'error': error},
      _fallback.logExportFailedMessage(error));

  @override
  String logDiagnosticsSavedMessage(Object path) => _format(
      'logDiagnosticsSavedMessage',
      {'path': path},
      _fallback.logDiagnosticsSavedMessage(path));

  @override
  String logDiagnosticsExportFailedMessage(Object error) => _format(
      'logDiagnosticsExportFailedMessage',
      {'error': error},
      _fallback.logDiagnosticsExportFailedMessage(error));

  @override
  String logExportFileHeader(Object time) => _format('logExportFileHeader',
      {'time': time}, _fallback.logExportFileHeader(time));

  @override
  String logExportFileTotal(Object count) => _format('logExportFileTotal',
      {'count': count}, _fallback.logExportFileTotal(count));

  @override
  String logExportSavedCountMessage(Object count, Object path) => _format(
      'logExportSavedCountMessage',
      {'count': count, 'path': path},
      _fallback.logExportSavedCountMessage(count, path));

  @override
  String logExportErrorMessage(Object error) => _format('logExportErrorMessage',
      {'error': error}, _fallback.logExportErrorMessage(error));

  @override
  String get logRuleUrl => _string('logRuleUrl', _fallback.logRuleUrl);

  @override
  String get logRuleFilePath =>
      _string('logRuleFilePath', _fallback.logRuleFilePath);

  @override
  String get logRuleIpAddress =>
      _string('logRuleIpAddress', _fallback.logRuleIpAddress);

  @override
  String get logRuleNumber => _string('logRuleNumber', _fallback.logRuleNumber);

  @override
  String get logRuleIdHash => _string('logRuleIdHash', _fallback.logRuleIdHash);

  @override
  String get logRuleError => _string('logRuleError', _fallback.logRuleError);

  @override
  String get logRuleSuccess =>
      _string('logRuleSuccess', _fallback.logRuleSuccess);

  @override
  String get logRuleWarning =>
      _string('logRuleWarning', _fallback.logRuleWarning);

  @override
  String get logRuleHttpMethod =>
      _string('logRuleHttpMethod', _fallback.logRuleHttpMethod);

  @override
  String get logRuleHttpStatus =>
      _string('logRuleHttpStatus', _fallback.logRuleHttpStatus);

  @override
  String get logRuleTime => _string('logRuleTime', _fallback.logRuleTime);

  @override
  String get logRuleStep => _string('logRuleStep', _fallback.logRuleStep);

  @override
  String get logRulePid => _string('logRulePid', _fallback.logRulePid);

  @override
  String get logRuleKeyValue =>
      _string('logRuleKeyValue', _fallback.logRuleKeyValue);

  @override
  String get performanceMonitorTitle =>
      _string('performanceMonitorTitle', _fallback.performanceMonitorTitle);

  @override
  String get performanceMonitorStatusRunning => _string(
      'performanceMonitorStatusRunning',
      _fallback.performanceMonitorStatusRunning);

  @override
  String get performanceMonitorStatusIdle => _string(
      'performanceMonitorStatusIdle', _fallback.performanceMonitorStatusIdle);

  @override
  String get performanceMonitorButtonStop => _string(
      'performanceMonitorButtonStop', _fallback.performanceMonitorButtonStop);

  @override
  String get performanceMonitorButtonStart => _string(
      'performanceMonitorButtonStart', _fallback.performanceMonitorButtonStart);

  @override
  String get performanceMonitorRealtimeTitle => _string(
      'performanceMonitorRealtimeTitle',
      _fallback.performanceMonitorRealtimeTitle);

  @override
  String get performanceMonitorJankBadge => _string(
      'performanceMonitorJankBadge', _fallback.performanceMonitorJankBadge);

  @override
  String get performanceMonitorMetricFps => _string(
      'performanceMonitorMetricFps', _fallback.performanceMonitorMetricFps);

  @override
  String get performanceMonitorMetricBuild => _string(
      'performanceMonitorMetricBuild', _fallback.performanceMonitorMetricBuild);

  @override
  String get performanceMonitorMetricRaster => _string(
      'performanceMonitorMetricRaster',
      _fallback.performanceMonitorMetricRaster);

  @override
  String get performanceMonitorMetricTotal => _string(
      'performanceMonitorMetricTotal', _fallback.performanceMonitorMetricTotal);

  @override
  String get performanceMonitorStatsTitle => _string(
      'performanceMonitorStatsTitle', _fallback.performanceMonitorStatsTitle);

  @override
  String get performanceMonitorStatTotalFrames => _string(
      'performanceMonitorStatTotalFrames',
      _fallback.performanceMonitorStatTotalFrames);

  @override
  String get performanceMonitorStatJankFrames => _string(
      'performanceMonitorStatJankFrames',
      _fallback.performanceMonitorStatJankFrames);

  @override
  String get performanceMonitorStatJankRate => _string(
      'performanceMonitorStatJankRate',
      _fallback.performanceMonitorStatJankRate);

  @override
  String get performanceMonitorStatAvgBuildTime => _string(
      'performanceMonitorStatAvgBuildTime',
      _fallback.performanceMonitorStatAvgBuildTime);

  @override
  String get performanceMonitorStatAvgRasterTime => _string(
      'performanceMonitorStatAvgRasterTime',
      _fallback.performanceMonitorStatAvgRasterTime);

  @override
  String get performanceMonitorStatAvgTotalTime => _string(
      'performanceMonitorStatAvgTotalTime',
      _fallback.performanceMonitorStatAvgTotalTime);

  @override
  String get performanceMonitorStatMaxBuildTime => _string(
      'performanceMonitorStatMaxBuildTime',
      _fallback.performanceMonitorStatMaxBuildTime);

  @override
  String get performanceMonitorStatMaxRasterTime => _string(
      'performanceMonitorStatMaxRasterTime',
      _fallback.performanceMonitorStatMaxRasterTime);

  @override
  String get performanceMonitorStatMaxTotalTime => _string(
      'performanceMonitorStatMaxTotalTime',
      _fallback.performanceMonitorStatMaxTotalTime);

  @override
  String get performanceMonitorRebuildTitle => _string(
      'performanceMonitorRebuildTitle',
      _fallback.performanceMonitorRebuildTitle);

  @override
  String get performanceMonitorRebuildTotal => _string(
      'performanceMonitorRebuildTotal',
      _fallback.performanceMonitorRebuildTotal);

  @override
  String get performanceMonitorRebuildTracked => _string(
      'performanceMonitorRebuildTracked',
      _fallback.performanceMonitorRebuildTracked);

  @override
  String get performanceMonitorRebuildTopTitle => _string(
      'performanceMonitorRebuildTopTitle',
      _fallback.performanceMonitorRebuildTopTitle);

  @override
  String get performanceMonitorRebuildEmpty => _string(
      'performanceMonitorRebuildEmpty',
      _fallback.performanceMonitorRebuildEmpty);

  @override
  String performanceMonitorFrameChartTitle(Object count) => _format(
      'performanceMonitorFrameChartTitle',
      {'count': count},
      _fallback.performanceMonitorFrameChartTitle(count));

  @override
  String get performanceMonitorFrameChartEmpty => _string(
      'performanceMonitorFrameChartEmpty',
      _fallback.performanceMonitorFrameChartEmpty);

  @override
  String get performanceMonitorLegendNormal => _string(
      'performanceMonitorLegendNormal',
      _fallback.performanceMonitorLegendNormal);

  @override
  String performanceMonitorLegendJankMs(Object ms) => _format(
      'performanceMonitorLegendJankMs',
      {'ms': ms},
      _fallback.performanceMonitorLegendJankMs(ms));

  @override
  String get performanceMonitorLegendFpsThreshold => _string(
      'performanceMonitorLegendFpsThreshold',
      _fallback.performanceMonitorLegendFpsThreshold);

  @override
  String get performanceMonitorSettingsTitle => _string(
      'performanceMonitorSettingsTitle',
      _fallback.performanceMonitorSettingsTitle);

  @override
  String get performanceMonitorSettingsModeLabel => _string(
      'performanceMonitorSettingsModeLabel',
      _fallback.performanceMonitorSettingsModeLabel);

  @override
  String get performanceMonitorSettingsBlurLabel => _string(
      'performanceMonitorSettingsBlurLabel',
      _fallback.performanceMonitorSettingsBlurLabel);

  @override
  String get performanceMonitorSettingsBlurStrengthLabel => _string(
      'performanceMonitorSettingsBlurStrengthLabel',
      _fallback.performanceMonitorSettingsBlurStrengthLabel);

  @override
  String get performanceMonitorSettingsWindowEffectLabel => _string(
      'performanceMonitorSettingsWindowEffectLabel',
      _fallback.performanceMonitorSettingsWindowEffectLabel);

  @override
  String get performanceMonitorSettingsAcrylicOpacityLabel => _string(
      'performanceMonitorSettingsAcrylicOpacityLabel',
      _fallback.performanceMonitorSettingsAcrylicOpacityLabel);

  @override
  String get performanceMonitorValueEnabled => _string(
      'performanceMonitorValueEnabled',
      _fallback.performanceMonitorValueEnabled);

  @override
  String get performanceMonitorValueDisabled => _string(
      'performanceMonitorValueDisabled',
      _fallback.performanceMonitorValueDisabled);

  @override
  String performanceMonitorWindowEffectEnabled(Object mode) => _format(
      'performanceMonitorWindowEffectEnabled',
      {'mode': mode},
      _fallback.performanceMonitorWindowEffectEnabled(mode));

  @override
  String get performanceMonitorWindowEffectHintEnabled => _string(
      'performanceMonitorWindowEffectHintEnabled',
      _fallback.performanceMonitorWindowEffectHintEnabled);

  @override
  String get performanceMonitorWindowEffectHintDisabled => _string(
      'performanceMonitorWindowEffectHintDisabled',
      _fallback.performanceMonitorWindowEffectHintDisabled);

  @override
  String get performanceMonitorActionExport => _string(
      'performanceMonitorActionExport',
      _fallback.performanceMonitorActionExport);

  @override
  String get performanceMonitorActionCopy => _string(
      'performanceMonitorActionCopy', _fallback.performanceMonitorActionCopy);

  @override
  String get performanceMonitorActionClear => _string(
      'performanceMonitorActionClear', _fallback.performanceMonitorActionClear);

  @override
  String get performanceMonitorToastClearedTitle => _string(
      'performanceMonitorToastClearedTitle',
      _fallback.performanceMonitorToastClearedTitle);

  @override
  String get performanceMonitorToastClearedMessage => _string(
      'performanceMonitorToastClearedMessage',
      _fallback.performanceMonitorToastClearedMessage);

  @override
  String get performanceMonitorToastExportSuccessTitle => _string(
      'performanceMonitorToastExportSuccessTitle',
      _fallback.performanceMonitorToastExportSuccessTitle);

  @override
  String performanceMonitorToastExportSuccessMessage(Object path) => _format(
      'performanceMonitorToastExportSuccessMessage',
      {'path': path},
      _fallback.performanceMonitorToastExportSuccessMessage(path));

  @override
  String get performanceMonitorToastExportFailedTitle => _string(
      'performanceMonitorToastExportFailedTitle',
      _fallback.performanceMonitorToastExportFailedTitle);

  @override
  String performanceMonitorToastExportFailedMessage(Object error) => _format(
      'performanceMonitorToastExportFailedMessage',
      {'error': error},
      _fallback.performanceMonitorToastExportFailedMessage(error));

  @override
  String get performanceMonitorToastCopiedTitle => _string(
      'performanceMonitorToastCopiedTitle',
      _fallback.performanceMonitorToastCopiedTitle);

  @override
  String get performanceMonitorToastCopiedMessage => _string(
      'performanceMonitorToastCopiedMessage',
      _fallback.performanceMonitorToastCopiedMessage);

  @override
  String get performanceMonitorModeQuality => _string(
      'performanceMonitorModeQuality', _fallback.performanceMonitorModeQuality);

  @override
  String get performanceMonitorModeBalanced => _string(
      'performanceMonitorModeBalanced',
      _fallback.performanceMonitorModeBalanced);

  @override
  String get performanceMonitorModePerformance => _string(
      'performanceMonitorModePerformance',
      _fallback.performanceMonitorModePerformance);

  @override
  String get tagActionLabel =>
      _string('tagActionLabel', _fallback.tagActionLabel);

  @override
  String get tagEditTitle => _string('tagEditTitle', _fallback.tagEditTitle);

  @override
  String get tagEditSubtitle =>
      _string('tagEditSubtitle', _fallback.tagEditSubtitle);

  @override
  String get tagEditPlaceholder =>
      _string('tagEditPlaceholder', _fallback.tagEditPlaceholder);

  @override
  String get tagFilterTitle =>
      _string('tagFilterTitle', _fallback.tagFilterTitle);

  @override
  String get tagFilterEmpty =>
      _string('tagFilterEmpty', _fallback.tagFilterEmpty);

  @override
  String get tagFilterSubtitle =>
      _string('tagFilterSubtitle', _fallback.tagFilterSubtitle);

  @override
  String get tagFilterClearButton =>
      _string('tagFilterClearButton', _fallback.tagFilterClearButton);

  @override
  String completedBatchActionsLabel(Object count) => _format(
      'completedBatchActionsLabel',
      {'count': count},
      _fallback.completedBatchActionsLabel(count));

  @override
  String get completedBatchRenameButton => _string(
      'completedBatchRenameButton', _fallback.completedBatchRenameButton);

  @override
  String get completedBatchMoveButton =>
      _string('completedBatchMoveButton', _fallback.completedBatchMoveButton);

  @override
  String get completedBatchMoveSuccessTitle => _string(
      'completedBatchMoveSuccessTitle',
      _fallback.completedBatchMoveSuccessTitle);

  @override
  String completedBatchMoveSuccessMessage(Object count) => _format(
      'completedBatchMoveSuccessMessage',
      {'count': count},
      _fallback.completedBatchMoveSuccessMessage(count));

  @override
  String completedBatchMovePartialMessage(Object success, Object failed) =>
      _format(
          'completedBatchMovePartialMessage',
          {'success': success, 'failed': failed},
          _fallback.completedBatchMovePartialMessage(success, failed));

  @override
  String get completedBatchRenameTitle =>
      _string('completedBatchRenameTitle', _fallback.completedBatchRenameTitle);

  @override
  String get completedBatchRenameHint =>
      _string('completedBatchRenameHint', _fallback.completedBatchRenameHint);

  @override
  String get completedBatchRenamePrefixLabel => _string(
      'completedBatchRenamePrefixLabel',
      _fallback.completedBatchRenamePrefixLabel);

  @override
  String get completedBatchRenamePrefixPlaceholder => _string(
      'completedBatchRenamePrefixPlaceholder',
      _fallback.completedBatchRenamePrefixPlaceholder);

  @override
  String get completedBatchRenameSuffixLabel => _string(
      'completedBatchRenameSuffixLabel',
      _fallback.completedBatchRenameSuffixLabel);

  @override
  String get completedBatchRenameSuffixPlaceholder => _string(
      'completedBatchRenameSuffixPlaceholder',
      _fallback.completedBatchRenameSuffixPlaceholder);

  @override
  String get completedBatchRenameEmptyWarningMessage => _string(
      'completedBatchRenameEmptyWarningMessage',
      _fallback.completedBatchRenameEmptyWarningMessage);

  @override
  String get completedBatchRenameSuccessTitle => _string(
      'completedBatchRenameSuccessTitle',
      _fallback.completedBatchRenameSuccessTitle);

  @override
  String completedBatchRenameSuccessMessage(Object count) => _format(
      'completedBatchRenameSuccessMessage',
      {'count': count},
      _fallback.completedBatchRenameSuccessMessage(count));

  @override
  String completedBatchRenamePartialMessage(Object success, Object failed) =>
      _format(
          'completedBatchRenamePartialMessage',
          {'success': success, 'failed': failed},
          _fallback.completedBatchRenamePartialMessage(success, failed));

  @override
  String get settingsClipboardListenerTitle => _string(
      'settingsClipboardListenerTitle',
      _fallback.settingsClipboardListenerTitle);

  @override
  String get settingsClipboardListenerSubtitle => _string(
      'settingsClipboardListenerSubtitle',
      _fallback.settingsClipboardListenerSubtitle);

  @override
  String get settingsClipboardListenerEnabledTitle => _string(
      'settingsClipboardListenerEnabledTitle',
      _fallback.settingsClipboardListenerEnabledTitle);

  @override
  String get settingsClipboardListenerEnabledMessage => _string(
      'settingsClipboardListenerEnabledMessage',
      _fallback.settingsClipboardListenerEnabledMessage);

  @override
  String get settingsClipboardListenerDisabledTitle => _string(
      'settingsClipboardListenerDisabledTitle',
      _fallback.settingsClipboardListenerDisabledTitle);

  @override
  String get settingsClipboardListenerDisabledMessage => _string(
      'settingsClipboardListenerDisabledMessage',
      _fallback.settingsClipboardListenerDisabledMessage);

  @override
  String get clipboardListenerMuteSessionButton => _string(
      'clipboardListenerMuteSessionButton',
      _fallback.clipboardListenerMuteSessionButton);

  @override
  String get clipboardListenerSessionMutedTitle => _string(
      'clipboardListenerSessionMutedTitle',
      _fallback.clipboardListenerSessionMutedTitle);

  @override
  String get clipboardListenerSessionMutedMessage => _string(
      'clipboardListenerSessionMutedMessage',
      _fallback.clipboardListenerSessionMutedMessage);

  @override
  String get downloadDuplicateTitle =>
      _string('downloadDuplicateTitle', _fallback.downloadDuplicateTitle);

  @override
  String downloadDuplicateMessage(Object fileName, Object status) => _format(
      'downloadDuplicateMessage',
      {'fileName': fileName, 'status': status},
      _fallback.downloadDuplicateMessage(fileName, status));

  @override
  String get downloadDuplicateUseExistingButton => _string(
      'downloadDuplicateUseExistingButton',
      _fallback.downloadDuplicateUseExistingButton);

  @override
  String get downloadDuplicateAddNewButton => _string(
      'downloadDuplicateAddNewButton', _fallback.downloadDuplicateAddNewButton);

  @override
  String get downloadDuplicateCancelButton => _string(
      'downloadDuplicateCancelButton', _fallback.downloadDuplicateCancelButton);

  @override
  String get downloadBadgeHostHint =>
      _string('downloadBadgeHostHint', _fallback.downloadBadgeHostHint);

  @override
  String get downloadBadgePolicyFallback => _string(
      'downloadBadgePolicyFallback', _fallback.downloadBadgePolicyFallback);

  @override
  String downloadBadgeConcurrencyCap(Object count) => _format(
      'downloadBadgeConcurrencyCap',
      {'count': count},
      _fallback.downloadBadgeConcurrencyCap(count));

  @override
  String get downloadFailureHintAuth =>
      _string('downloadFailureHintAuth', _fallback.downloadFailureHintAuth);

  @override
  String get downloadFailureHintNotFound => _string(
      'downloadFailureHintNotFound', _fallback.downloadFailureHintNotFound);

  @override
  String get downloadFailureHintRange =>
      _string('downloadFailureHintRange', _fallback.downloadFailureHintRange);

  @override
  String get downloadFailureHintRateLimit => _string(
      'downloadFailureHintRateLimit', _fallback.downloadFailureHintRateLimit);

  @override
  String get downloadFailureHintServer =>
      _string('downloadFailureHintServer', _fallback.downloadFailureHintServer);

  @override
  String get downloadFailureHintHttp =>
      _string('downloadFailureHintHttp', _fallback.downloadFailureHintHttp);

  @override
  String get downloadFailureHintTimeout => _string(
      'downloadFailureHintTimeout', _fallback.downloadFailureHintTimeout);

  @override
  String get downloadFailureHintConnection => _string(
      'downloadFailureHintConnection', _fallback.downloadFailureHintConnection);

  @override
  String get downloadFailureHintDns =>
      _string('downloadFailureHintDns', _fallback.downloadFailureHintDns);

  @override
  String get downloadFailureHintSsl =>
      _string('downloadFailureHintSsl', _fallback.downloadFailureHintSsl);

  @override
  String get downloadFailureHintChecksum => _string(
      'downloadFailureHintChecksum', _fallback.downloadFailureHintChecksum);

  @override
  String get downloadFailureHintDisk =>
      _string('downloadFailureHintDisk', _fallback.downloadFailureHintDisk);

  @override
  String get settingsConflictStrategyTitle => _string(
      'settingsConflictStrategyTitle', _fallback.settingsConflictStrategyTitle);

  @override
  String get settingsConflictStrategySubtitle => _string(
      'settingsConflictStrategySubtitle',
      _fallback.settingsConflictStrategySubtitle);

  @override
  String get settingsConflictStrategyIncrement => _string(
      'settingsConflictStrategyIncrement',
      _fallback.settingsConflictStrategyIncrement);

  @override
  String get settingsConflictStrategyTimestamp => _string(
      'settingsConflictStrategyTimestamp',
      _fallback.settingsConflictStrategyTimestamp);

  @override
  String get settingsConflictStrategyOverwrite => _string(
      'settingsConflictStrategyOverwrite',
      _fallback.settingsConflictStrategyOverwrite);

  @override
  String get noticePageTitle =>
      _string('noticePageTitle', _fallback.noticePageTitle);

  @override
  String get noticePinned => _string('noticePinned', _fallback.noticePinned);

  @override
  String get noticeEmpty => _string('noticeEmpty', _fallback.noticeEmpty);

  @override
  String get noticeRefresh => _string('noticeRefresh', _fallback.noticeRefresh);

  @override
  String get noticeRetry => _string('noticeRetry', _fallback.noticeRetry);

  @override
  String get noticeLoadError =>
      _string('noticeLoadError', _fallback.noticeLoadError);

  @override
  String noticeLastSynced(Object timeAgo) =>
      _string('noticeLastSynced', _fallback.noticeLastSynced(timeAgo));

  @override
  String get noticeJustNow => _string('noticeJustNow', _fallback.noticeJustNow);

  @override
  String noticeMinutesAgo(Object count) =>
      _string('noticeMinutesAgo', _fallback.noticeMinutesAgo(count));

  @override
  String noticeHoursAgo(Object count) =>
      _string('noticeHoursAgo', _fallback.noticeHoursAgo(count));

  @override
  String noticeDaysAgo(Object count) =>
      _string('noticeDaysAgo', _fallback.noticeDaysAgo(count));

  @override
  String get noticeOpenLink =>
      _string('noticeOpenLink', _fallback.noticeOpenLink);

  @override
  String get settingsLogManagementSection => _string(
      'settingsLogManagementSection', _fallback.settingsLogManagementSection);

  @override
  String get settingsLogClearTitle =>
      _string('settingsLogClearTitle', _fallback.settingsLogClearTitle);

  @override
  String get settingsLogClearSubtitle =>
      _string('settingsLogClearSubtitle', _fallback.settingsLogClearSubtitle);

  @override
  String get settingsLogClearButton =>
      _string('settingsLogClearButton', _fallback.settingsLogClearButton);

  @override
  String get settingsLogClearConfirmTitle => _string(
      'settingsLogClearConfirmTitle', _fallback.settingsLogClearConfirmTitle);

  @override
  String get settingsLogClearConfirmMessage => _string(
      'settingsLogClearConfirmMessage',
      _fallback.settingsLogClearConfirmMessage);

  @override
  String get settingsLogClearConfirmButton => _string(
      'settingsLogClearConfirmButton', _fallback.settingsLogClearConfirmButton);

  @override
  String get settingsLogClearSuccessTitle => _string(
      'settingsLogClearSuccessTitle', _fallback.settingsLogClearSuccessTitle);

  @override
  String get settingsLogClearSuccessMessage => _string(
      'settingsLogClearSuccessMessage',
      _fallback.settingsLogClearSuccessMessage);

  @override
  String get settingsLogOpenDirTitle =>
      _string('settingsLogOpenDirTitle', _fallback.settingsLogOpenDirTitle);

  @override
  String get settingsLogOpenDirSubtitle => _string(
      'settingsLogOpenDirSubtitle', _fallback.settingsLogOpenDirSubtitle);

  @override
  String get settingsLogOpenDirButton =>
      _string('settingsLogOpenDirButton', _fallback.settingsLogOpenDirButton);

  @override
  String get settingsLogOpenDirNotFound => _string(
      'settingsLogOpenDirNotFound', _fallback.settingsLogOpenDirNotFound);

  @override
  String get settingsLogOpenDirError =>
      _string('settingsLogOpenDirError', _fallback.settingsLogOpenDirError);

  @override
  String get settingsLogRetentionTitle =>
      _string('settingsLogRetentionTitle', _fallback.settingsLogRetentionTitle);

  @override
  String settingsLogRetentionSubtitle(Object days) => _string(
      'settingsLogRetentionSubtitle',
      _fallback.settingsLogRetentionSubtitle(days));

  @override
  String get settingsLogRetentionDays =>
      _string('settingsLogRetentionDays', _fallback.settingsLogRetentionDays);

  @override
  String get settingsLogRetentionSaved =>
      _string('settingsLogRetentionSaved', _fallback.settingsLogRetentionSaved);
}
