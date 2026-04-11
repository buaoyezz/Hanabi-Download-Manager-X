// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hanabi Download ManagerX';

  @override
  String get aboutEasterEggCongrats => 'Congrats, you found the easter egg!';

  @override
  String get aboutEasterEggTitle => 'This easter egg doesn\'t do much.';

  @override
  String aboutEasterEggMessage(Object appName) {
    return 'Thanks for using $appName!\\nThanks for your support.\\nHope you can give it a star.';
  }

  @override
  String get aboutEasterEggDismiss => 'Pretend I didn\'t see it';

  @override
  String aboutMadeBy(Object developer) {
    return 'Made by $developer';
  }

  @override
  String get aboutEasterEggDialogTitle => 'Hey!';

  @override
  String get aboutPageTitle => 'About';

  @override
  String get aboutSectionAppInfo => 'App Info';

  @override
  String aboutTapHintRemaining(Object count) {
    return 'Tap $count more times...';
  }

  @override
  String aboutVersionLabel(Object version) {
    return 'v$version';
  }

  @override
  String get aboutSectionDetails => 'Details';

  @override
  String get aboutDetailDeveloperLabel => 'Developer';

  @override
  String get aboutDetailKernelLabel => 'Download core';

  @override
  String get aboutDetailUiFrameworkLabel => 'UI framework';

  @override
  String get aboutDetailUiFrameworkValue => 'Fluent UI for Flutter';

  @override
  String get aboutSectionLinks => 'Links';

  @override
  String get aboutLinkOfficialTitle => 'Official Website';

  @override
  String get aboutLinkOfficialSubtitle => 'Visit the project homepage';

  @override
  String get aboutLinkGithubTitle => 'GitHub';

  @override
  String get aboutLinkGithubSubtitle => 'View source code and contribute';

  @override
  String get aboutLinkContactTitle => 'Contact Us';

  @override
  String aboutCopyrightMessage(Object year, Object developer) {
    return '© $year $developer. All rights reserved.';
  }

  @override
  String get aboutOpenLinkErrorTitle => 'Error';

  @override
  String aboutOpenLinkErrorMessage(Object error) {
    return 'Failed to open link: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTabGeneral => 'General';

  @override
  String get settingsTabDownload => 'Downloads';

  @override
  String get settingsTabAppearance => 'Appearance';

  @override
  String get settingsTabUpdate => 'Updates';

  @override
  String get settingsTabAdvanced => 'Advanced';

  @override
  String get settingsTabDeveloper => 'Developer';

  @override
  String get appearanceSectionLanguage => 'Language';

  @override
  String get appearanceLanguageTitle => 'Interface Language';

  @override
  String get appearanceLanguageSubtitle =>
      'Follow system by default: the app will automatically choose the appropriate language for you';

  @override
  String get appearanceLanguageSystem => 'Follow system';

  @override
  String get appearanceLanguageChinese => 'Chinese';

  @override
  String get appearanceLanguageEnglish => 'English';

  @override
  String get appearanceLanguageSwitchedTitle => 'Language switched';

  @override
  String get appearanceLanguageSwitchedSystem =>
      'It will follow your system language';

  @override
  String appearanceLanguageSwitchedTo(Object language) {
    return 'Switched to $language';
  }

  @override
  String get appearanceLanguagePacksTitle => 'Language Packs';

  @override
  String appearanceLanguagePacksSubtitle(Object path) {
    return 'Put .json/.arb files into $path, then click refresh';
  }

  @override
  String get appearanceLanguagePacksRefreshedTitle =>
      'Language packs refreshed';

  @override
  String appearanceLanguagePacksRefreshedMessage(Object count) {
    return 'Found $count language pack(s)';
  }

  @override
  String get appearanceLanguageRefreshButton => 'Refresh language packs';

  @override
  String get trayMenuShowWindowTitle => 'Show Window';

  @override
  String get trayMenuShowWindowSubtitle => 'Open main window';

  @override
  String get trayMenuKernelTitle => 'Download Kernel';

  @override
  String get trayMenuKernelSubtitleRunning => 'Running';

  @override
  String get trayMenuKernelSubtitleStopped => 'Stopped';

  @override
  String get trayMenuExitTitle => 'Exit';

  @override
  String get trayMenuExitSubtitle => 'Close all windows';

  @override
  String get exitWithActiveDownloadsTitle => 'Active downloads in progress';

  @override
  String exitWithActiveDownloadsMessage(Object count) {
    return '$count download(s) are still running. Exiting now will stop them. Are you sure you want to quit?';
  }

  @override
  String get exitWithActiveDownloadsCancelButton => 'Cancel';

  @override
  String get exitWithActiveDownloadsConfirmButton => 'Exit anyway';

  @override
  String get tempFilesDialogTitle => 'Clean Temporary Files';

  @override
  String tempFilesDialogScanPath(Object path) {
    return 'Scan path: $path';
  }

  @override
  String get tempFilesStatFiles => 'Files';

  @override
  String get tempFilesStatTotalSize => 'Total size';

  @override
  String get tempFilesStatSelected => 'Selected';

  @override
  String get tempFilesSupportedFormats =>
      'Supported: .temp, .tmp, .download, .partN (segments), .crdownload, .partial, .!ut';

  @override
  String get tempFilesSelectAll => 'Select all';

  @override
  String get tempFilesIncludeTempDirs => 'Include temp folders';

  @override
  String get tempFilesSortLabel => 'Sort:';

  @override
  String get tempFilesSortName => 'Name';

  @override
  String get tempFilesSortSize => 'Size';

  @override
  String get tempFilesSortTime => 'Time';

  @override
  String get tempFilesEmpty => 'No temporary files found';

  @override
  String get tempFilesCloseButton => 'Close';

  @override
  String tempFilesDeleteSelected(Object count) {
    return 'Delete selected ($count)';
  }

  @override
  String get tempFilesDeleteConfirmTitle => 'Confirm deletion';

  @override
  String tempFilesDeleteConfirmMessage(Object count) {
    return 'Delete $count temporary files?';
  }

  @override
  String tempFilesDeleteTotalSize(Object size) {
    return 'Total size: $size';
  }

  @override
  String get tempFilesDeleteWarning => 'This action cannot be undone';

  @override
  String get tempFilesCancelButton => 'Cancel';

  @override
  String get tempFilesDeleteButton => 'Delete';

  @override
  String get tempFilesDeleteDoneTitle => 'Deletion complete';

  @override
  String tempFilesDeleteDoneWithFailures(Object success, Object failed) {
    return 'Deleted $success, failed $failed';
  }

  @override
  String tempFilesDeleteDoneSuccess(Object success) {
    return 'Deleted $success temporary files';
  }

  @override
  String get homeNavDownloading => 'Download Task';

  @override
  String get homeNavCompleted => 'Completed';

  @override
  String get homeNavLog => 'Logs';

  @override
  String get homeNavStatus => 'Status';

  @override
  String get homeNavOnlineStats => 'Online Stats';

  @override
  String get homeNavPerformance => 'Performance';

  @override
  String get homeNavConnectionDebug => 'Connection';

  @override
  String get homeNavSettings => 'Settings';

  @override
  String get homeNavAbout => 'About';

  @override
  String get homeUpdateFoundTitle => 'New version detected';

  @override
  String homeUpdateFoundMessage(Object currentVersion, Object newVersion) {
    return 'Update: $currentVersion -> $newVersion\\nGo to Settings to update.';
  }

  @override
  String get homeKernelStartingTitle => 'Starting download kernel...';

  @override
  String get homeKernelStartingHint =>
      'Please wait, this may take a few seconds';

  @override
  String get homeViewLog => 'View logs';

  @override
  String get homeRetry => 'Retry';

  @override
  String get homeNewTask => 'New';

  @override
  String get fileName => 'File name';

  @override
  String get id => 'ID';

  @override
  String get name => 'Name';

  @override
  String get segments => 'Segments';

  @override
  String get speed => 'Speed';

  @override
  String get status => 'Status';

  @override
  String get url => 'URL';

  @override
  String get settingsSectionSystem => 'System';

  @override
  String get settingsAutoStartTitle => 'Launch on startup';

  @override
  String get settingsAutoStartSubtitle =>
      'Start the app when the system starts';

  @override
  String get settingsAutoStartEnabledTitle => 'Auto start enabled';

  @override
  String get settingsAutoStartEnabledMessage =>
      'The app will launch on startup';

  @override
  String get settingsAutoStartDisabledTitle => 'Auto start disabled';

  @override
  String get settingsAutoStartDisabledMessage =>
      'The app will not launch on startup';

  @override
  String get settingsAutoStartEnableFailed => 'Failed to enable auto start';

  @override
  String get settingsAutoStartDisableFailed => 'Failed to disable auto start';

  @override
  String get settingsAutoStartFixedTitle => 'Auto start fixed';

  @override
  String get settingsAutoStartFixedMessage =>
      'Auto start path has been corrected';

  @override
  String get settingsSectionBehavior => 'Behavior';

  @override
  String get settingsAutoDownloadTitle => 'Auto start downloads';

  @override
  String get settingsAutoDownloadSubtitle => 'Start new tasks automatically';

  @override
  String get settingsAutoDownloadEnabledTitle => 'Auto download enabled';

  @override
  String get settingsAutoDownloadEnabledMessage =>
      'New tasks will start automatically';

  @override
  String get settingsAutoDownloadDisabledTitle => 'Auto download disabled';

  @override
  String get settingsAutoDownloadDisabledMessage =>
      'New tasks will wait until you start them';

  @override
  String get settingsPopupWindowTitle => 'Popup window';

  @override
  String get settingsPopupWindowSubtitle =>
      'Show downloads in a standalone popup window without bringing the main window forward';

  @override
  String get settingsPopupEnabledTitle => 'Popup enabled';

  @override
  String get settingsPopupEnabledMessage =>
      'Browser downloads will open the standalone popup window while the main window stays in the background';

  @override
  String get settingsPopupDisabledTitle => 'Popup disabled';

  @override
  String get settingsPopupDisabledMessage =>
      'Browser downloads will be accepted directly without opening the standalone popup window';

  @override
  String get settingsCompleteNotifyTitle => 'Completion notifications';

  @override
  String get settingsCompleteNotifySubtitle => 'Notify when downloads finish';

  @override
  String get settingsCompleteNotifyEnabledTitle => 'Notifications enabled';

  @override
  String get settingsCompleteNotifyEnabledMessage =>
      'You\'ll be notified on completion';

  @override
  String get settingsCompleteNotifyDisabledTitle => 'Notifications disabled';

  @override
  String get settingsCompleteNotifyDisabledMessage =>
      'No completion notifications';

  @override
  String get settingsOnlineStatsTitle => 'Online stats';

  @override
  String get settingsOnlineStatsSubtitle => 'Enable online user statistics';

  @override
  String get settingsOnlineStatsEnabledTitle => 'Online stats enabled';

  @override
  String get settingsOnlineStatsEnabledMessage =>
      'Online stats are now enabled';

  @override
  String get settingsOnlineStatsDisabledTitle => 'Online stats disabled';

  @override
  String get settingsOnlineStatsDisabledMessage =>
      'Online stats are now disabled';

  @override
  String get settingsTrayHintTitle => 'Tray running status';

  @override
  String get settingsTrayHintSubtitle => 'Show running status in tray tooltip';

  @override
  String get settingsTrayHintEnabledTitle => 'Tray hint enabled';

  @override
  String get settingsTrayHintEnabledMessage =>
      'Tray tooltip will show running status';

  @override
  String get settingsTrayHintDisabledTitle => 'Tray hint disabled';

  @override
  String get settingsTrayHintDisabledMessage =>
      'Tray tooltip will be simplified';

  @override
  String get settingsCloseBehaviorTitle => 'Close button behavior';

  @override
  String get settingsCloseBehaviorMinimizeLabel => 'Minimize to tray';

  @override
  String get settingsCloseBehaviorExitLabel => 'Exit app';

  @override
  String get settingsCloseBehaviorMinimize => 'Minimize to tray';

  @override
  String get settingsCloseBehaviorExit => 'Exit app';

  @override
  String get settingsCloseBehaviorUnknown => 'Unknown';

  @override
  String settingsCloseBehaviorSavedMessage(Object behavior) {
    return 'Close behavior set to $behavior';
  }

  @override
  String get settingsSaveSuccessTitle => 'Saved';

  @override
  String get settingsSaveFailedTitle => 'Save failed';

  @override
  String settingsSaveFailedMessage(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get settingsDownloadPathSection => 'Download path';

  @override
  String get settingsDownloadPathTitle => 'Download folder';

  @override
  String get settingsDownloadPathChangeButton => 'Change';

  @override
  String get settingsDownloadPathDialogTitle => 'Change download folder';

  @override
  String get settingsDownloadPathDialogPrompt =>
      'Please choose or input a download folder';

  @override
  String get settingsDownloadPathPlaceholder => 'Enter folder path';

  @override
  String get settingsBrowseButton => 'Browse';

  @override
  String get settingsDownloadPathHintTitle => 'Tip';

  @override
  String get settingsDownloadPathHintBody =>
      'Use a local disk folder for better performance';

  @override
  String get settingsCancelButton => 'Cancel';

  @override
  String get settingsConfirmButton => 'Confirm';

  @override
  String settingsDownloadPathChangedMessage(Object path) {
    return 'Download path updated to $path';
  }

  @override
  String get settingsDownloadPathChangeFailedMessage =>
      'Failed to update download path';

  @override
  String get settingsDownloadConfigSection => 'Download settings';

  @override
  String get settingsDownloadModeTitle => 'Download mode';

  @override
  String get settingsDownloadModeAuto => 'Auto';

  @override
  String get settingsDownloadModeThreadsOnly => 'Threads only';

  @override
  String get settingsDownloadModeSegmentsOnly => 'Segments only';

  @override
  String get settingsDownloadModeManual => 'Manual';

  @override
  String get settingsThreadsTitle => 'Threads';

  @override
  String get settingsThreadsSubtitle => 'Number of download threads';

  @override
  String get settingsSegmentsTitle => 'Segments';

  @override
  String get settingsSegmentsSubtitle => 'Number of segments per download';

  @override
  String get settingsDynamicSegmentsTitle => 'Dynamic segments';

  @override
  String get settingsDynamicSegmentsSubtitle =>
      'Adjust segments based on file size';

  @override
  String get settingsDynamicSegmentsEnabledTitle => 'Dynamic segments enabled';

  @override
  String get settingsDynamicSegmentsEnabledMessage =>
      'Segments will adjust automatically';

  @override
  String get settingsDynamicSegmentsDisabledTitle =>
      'Dynamic segments disabled';

  @override
  String get settingsDynamicSegmentsDisabledMessage =>
      'Segments will stay fixed';

  @override
  String get settingsMaxConcurrentTitle => 'Max concurrent tasks';

  @override
  String get settingsMaxConcurrentSubtitle => 'Limit concurrent downloads';

  @override
  String get settingsSegmentSpeedLimitTitle => 'Per-segment speed limit';

  @override
  String get settingsSegmentSpeedLimitSubtitle => 'Limit speed per segment';

  @override
  String get settingsGlobalSpeedLimitTitle => 'Global speed limit';

  @override
  String get settingsGlobalSpeedLimitSubtitle =>
      'Limit total download bandwidth';

  @override
  String get settingsHttpVersionTitle => 'HTTP protocol';

  @override
  String get settingsHttpVersionSubtitle =>
      'Choose protocol strategy for HTTPS downloads';

  @override
  String get settingsHttpVersionAuto => 'Auto (prefer HTTP/1.1)';

  @override
  String get settingsHttpVersionHttp1Only => 'Force HTTP/1.1';

  @override
  String get settingsHttpVersionHttp2Only => 'Force HTTP/2';

  @override
  String get settingsHttpVersionHttp3Only => 'Force HTTP/3 (fallback)';

  @override
  String get settingsDownloadCardHttpBadgeTitle => 'Card protocol badges';

  @override
  String get settingsDownloadCardHttpBadgeSubtitle =>
      'Show HTTP version and target connectivity on each download card';

  @override
  String get settingsDefaultUserAgentTitle => 'Default User-Agent';

  @override
  String get settingsDefaultUserAgentSubtitle =>
      'Used when a task does not provide User-Agent';

  @override
  String get settingsDefaultUserAgentPlaceholder => 'Enter default User-Agent';

  @override
  String get settingsUaPresetTitle => 'User-Agent presets';

  @override
  String get settingsUaPresetSubtitle =>
      'Quickly switch browser disguise, manual input, or custom UA packs';

  @override
  String get settingsUaPresetManualOption =>
      'Manual input (keep current value)';

  @override
  String settingsUaPresetBuiltinOption(Object name) {
    return 'Built-in - $name';
  }

  @override
  String settingsUaPresetCustomOption(Object name) {
    return 'Custom - $name';
  }

  @override
  String get settingsUaCustomCreateTitle => 'Create custom UA pack';

  @override
  String get settingsUaCustomCreateSubtitle => 'Save once and switch anytime';

  @override
  String get settingsUaCustomNamePlaceholder => 'Name';

  @override
  String get settingsUaCustomValuePlaceholder => 'User-Agent string';

  @override
  String get settingsUaCustomAddButton => 'Add';

  @override
  String get settingsUaCustomListTitle => 'Custom UA packs';

  @override
  String get settingsUaCustomListEmpty => 'No custom UA packs yet';

  @override
  String settingsUaCustomListCount(Object count) {
    return '$count packs, can apply or delete';
  }

  @override
  String get settingsUaCustomListHint =>
      'Create one custom UA pack above first';

  @override
  String get settingsUaCustomEnabledButton => 'Enabled';

  @override
  String get settingsUaCustomApplyButton => 'Apply';

  @override
  String get settingsSpeedUnlimited => 'Unlimited';

  @override
  String settingsSpeedTotal(Object speed) {
    return 'Total $speed KB/s';
  }

  @override
  String settingsPopupSaveFailedMessage(Object error) {
    return 'Failed to save: $error';
  }

  @override
  String get settingsProxySection => 'Proxy';

  @override
  String get settingsProxyEnableTitle => 'Enable proxy';

  @override
  String get settingsProxyEnableSubtitle => 'Use proxy for downloads';

  @override
  String get settingsProxySavedTitle => 'Proxy settings saved';

  @override
  String settingsProxyEnabledMessage(Object host, Object port) {
    return 'Proxy enabled: $host:$port';
  }

  @override
  String get settingsProxyEnabledSystemMessage =>
      'Proxy enabled: follow system settings';

  @override
  String get settingsProxyDisabledMessage => 'Proxy disabled';

  @override
  String get settingsProxyTypeTitle => 'Proxy type';

  @override
  String get settingsProxyTypeSubtitle => 'Choose proxy protocol';

  @override
  String get settingsProxyTypeSystem => 'System';

  @override
  String get settingsProxyTypeHttp => 'HTTP';

  @override
  String get settingsProxyTypeSocks5 => 'SOCKS5';

  @override
  String get settingsProxyServerTitle => 'Proxy server';

  @override
  String get settingsProxyServerSubtitle => 'Server address and port';

  @override
  String get settingsProxyHostPlaceholder => 'Host';

  @override
  String get settingsProxyAuthTitle => 'Authentication';

  @override
  String get settingsProxyAuthSubtitle => 'Requires username/password';

  @override
  String get settingsProxyUsernameTitle => 'Username';

  @override
  String get settingsProxyUsernameSubtitle => 'Proxy account username';

  @override
  String get settingsProxyUsernamePlaceholder => 'Enter username';

  @override
  String get settingsProxyPasswordTitle => 'Password';

  @override
  String get settingsProxyPasswordSubtitle => 'Proxy account password';

  @override
  String get settingsProxyPasswordPlaceholder => 'Enter password';

  @override
  String get settingsProxyTipsTitle => 'Proxy tips';

  @override
  String get settingsProxyTipsSystem => 'Use system proxy settings';

  @override
  String get settingsProxyTipsHttp => 'HTTP proxy format: host:port';

  @override
  String get settingsProxyTipsSocks5 => 'SOCKS5 proxy format: host:port';

  @override
  String get settingsProxyTipsDefault => 'Configure your proxy settings';

  @override
  String get settingsProxyTestButton => 'Test proxy';

  @override
  String get settingsProxyTestingTitle => 'Testing proxy...';

  @override
  String get settingsProxyTestingMessage => 'Please wait';

  @override
  String get settingsProxyTestSuccessTitle => 'Proxy works';

  @override
  String get settingsProxyTestSuccessMessage => 'Proxy connection successful';

  @override
  String get settingsProxyTestFailedTitle => 'Proxy failed';

  @override
  String get settingsProxyTestFailedMessage => 'Could not connect to proxy';

  @override
  String get settingsProxyTestErrorTitle => 'Proxy error';

  @override
  String settingsProxyTestErrorMessage(Object error) {
    return 'Test failed: $error';
  }

  @override
  String get settingsProxyErrorTitle => 'Proxy config error';

  @override
  String get settingsProxyErrorMessage => 'Please enter a proxy host';

  @override
  String get settingsKernelSection => 'Download kernel';

  @override
  String get settingsKernelCurrentTitle => 'Current kernel';

  @override
  String get settingsKernelOnline => 'Online';

  @override
  String get settingsKernelOffline => 'Offline';

  @override
  String get settingsKernelNsfxTitle => 'Use NSFX kernel';

  @override
  String get settingsKernelNsfxSubtitle => 'Switch to the new kernel';

  @override
  String get settingsKernelNsfxHint =>
      'NSFX provides better performance and stability';

  @override
  String get settingsKernelSwitchedTitle => 'Kernel switched';

  @override
  String settingsKernelSwitchedMessage(Object kernelName) {
    return 'Now using $kernelName';
  }

  @override
  String get settingsKernelSwitchFailedTitle => 'Kernel switch failed';

  @override
  String get settingsKernelSwitchFailedNewMessage =>
      'Failed to start new kernel';

  @override
  String get settingsStatusTitle => 'System status';

  @override
  String get settingsStatusKernelNsfx => 'NSFX Kernel';

  @override
  String get settingsStatusBrowserExtension => 'Browser extension';

  @override
  String get settingsModeDescriptionAuto =>
      'Automatically balance threads and segments';

  @override
  String get settingsModeDescriptionThreadsOnly => 'Use threads only';

  @override
  String get settingsModeDescriptionSegmentsOnly => 'Use segments only';

  @override
  String get settingsModeDescriptionManual =>
      'Manually control threads and segments';

  @override
  String get settingsModeDescriptionUnknown => 'Unknown mode';

  @override
  String get settingsDeveloperSection => 'Developer options';

  @override
  String get settingsDeveloperModeTitle => 'Developer mode';

  @override
  String get settingsDeveloperModeSubtitle =>
      'Enable debugging and diagnostics';

  @override
  String get settingsDeveloperModeHint =>
      'Developer features are for debugging only';

  @override
  String get settingsDeveloperModeEnabledTitle => 'Developer mode enabled';

  @override
  String get settingsDeveloperModeEnabledMessage =>
      'Advanced debugging is enabled';

  @override
  String get settingsDeveloperModeDisabledTitle => 'Developer mode disabled';

  @override
  String get settingsDeveloperModeDisabledMessage =>
      'Advanced debugging is disabled';

  @override
  String get settingsDeveloperPageVisibilityTitle => 'Debug page visibility';

  @override
  String get settingsDeveloperShowLogTitle => 'Show log page';

  @override
  String get settingsDeveloperShowLogSubtitle =>
      'Show log viewer in navigation';

  @override
  String get settingsDeveloperShowStatusTitle => 'Show status page';

  @override
  String get settingsDeveloperShowStatusSubtitle =>
      'Show system status in navigation';

  @override
  String get settingsDeveloperShowOnlineStatsTitle => 'Show online stats page';

  @override
  String get settingsDeveloperShowOnlineStatsSubtitle =>
      'Show online stats in navigation';

  @override
  String get settingsDeveloperShowConnectionDebugTitle =>
      'Show connection debug page';

  @override
  String get settingsDeveloperShowConnectionDebugSubtitle =>
      'Show connection diagnostics in navigation';

  @override
  String get settingsDeveloperPageHint =>
      'Debug pages may consume resources; enable only when needed';

  @override
  String get settingsDangerCleanTempTitle => 'Clean temporary files';

  @override
  String get settingsDangerCleanTempSubtitle =>
      'Scan and delete .temp files in the download folder';

  @override
  String get settingsDangerCleanTempButton => 'Clean temporary files';

  @override
  String get settingsDangerClearDataTitle => 'Clear all data';

  @override
  String get settingsDangerClearDataSubtitle =>
      'Delete all download tasks and history';

  @override
  String get settingsDangerClearDataButton => 'Clear data';

  @override
  String get settingsDangerConfirmTitle => 'Confirm clear';

  @override
  String get settingsDangerConfirmMessage =>
      'Clear all download tasks and history? This cannot be undone.';

  @override
  String get settingsDangerConfirmButton => 'Confirm';

  @override
  String get settingsDangerClearingTitle => 'Clearing...';

  @override
  String get settingsDangerClearingMessage => 'Please wait';

  @override
  String get settingsDangerClearedTitle => 'Cleared';

  @override
  String get settingsDangerClearedMessage =>
      'All download tasks and history have been cleared';

  @override
  String get settingsDangerClearFailedTitle => 'Clear failed';

  @override
  String get settingsDangerClearFailedMessage =>
      'Unable to clear data. Make sure the download kernel is running.';

  @override
  String get settingsUserLoading => 'Loading...';

  @override
  String get settingsUserLoadFailed => 'Failed to load';

  @override
  String get settingsUserUnknown => 'Unknown';

  @override
  String get appearanceWindowSizeSection => 'Window size';

  @override
  String get appearanceWindowRememberTitle => 'Remember window size';

  @override
  String get appearanceWindowRememberSubtitleOn =>
      'Use last window size on startup';

  @override
  String get appearanceWindowRememberSubtitleOff =>
      'Use default window size on startup';

  @override
  String get appearanceWindowDefaultWidthTitle => 'Default window width';

  @override
  String appearanceWindowDefaultWidthSubtitle(Object max) {
    return 'Default width on startup (600-$max)';
  }

  @override
  String get appearanceWindowDefaultHeightTitle => 'Default window height';

  @override
  String appearanceWindowDefaultHeightSubtitle(Object max) {
    return 'Default height on startup (400-$max)';
  }

  @override
  String get appearanceWindowSaveTitle => 'Saved';

  @override
  String appearanceWindowSaveMessage(Object width, Object height) {
    return 'Current window size set as default ($width?$height)';
  }

  @override
  String appearanceWindowSaveButton(Object width, Object height) {
    return 'Use current size ($width?$height)';
  }

  @override
  String get appearanceWindowResetTitle => 'Reset';

  @override
  String get appearanceWindowResetMessage =>
      'Default window size reset to 889?586';

  @override
  String get appearanceWindowResetButton => 'Reset to default';

  @override
  String get appearanceWindowApplyTitle => 'Applied';

  @override
  String appearanceWindowApplyMessage(Object width, Object height) {
    return 'Window size adjusted to $width?$height';
  }

  @override
  String appearanceWindowApplyButton(Object width, Object height) {
    return 'Apply default size ($width?$height)';
  }

  @override
  String get appearanceWindowRememberHintOn =>
      'Remember mode is enabled; the app will restore last window size';

  @override
  String get appearanceWindowRememberHintOff =>
      'Default size mode is enabled; the app will use the configured size';

  @override
  String get appearanceUiScaleSection => 'UI scale';

  @override
  String get appearanceUiScaleTitle => 'Interface scale';

  @override
  String get appearanceUiScaleSubtitle =>
      'Adjust UI scale for high-DPI screens (50%-200%)';

  @override
  String get appearanceUiScaleResetTitle => 'Reset';

  @override
  String get appearanceUiScaleResetMessage => 'UI scale reset to 100%';

  @override
  String get appearanceUiScaleResetButton => 'Reset to 100%';

  @override
  String get appearanceUiScaleApplyTitle => 'Applied';

  @override
  String get appearanceUiScaleApplyMessage =>
      'UI scale set to 125% (recommended for 4K)';

  @override
  String get appearanceUiScale4kButton => '4K recommended (125%)';

  @override
  String get appearanceUiScaleHint =>
      'Adjusting this helps on high-DPI screens. 4K recommended 125%-150%.';

  @override
  String get appearanceFontSection => 'Font';

  @override
  String get appearanceFontTitle => 'App font';

  @override
  String get appearanceFontSystemSubtitle => 'Use system default font';

  @override
  String appearanceFontCurrentSubtitle(Object font) {
    return 'Current font: $font';
  }

  @override
  String get appearanceFontSystemLabel => 'System default';

  @override
  String get appearanceFontImportButton => 'Import font';

  @override
  String get appearanceFontDeleteButton => 'Delete current font';

  @override
  String get appearanceFontHint => 'Supports .ttf and .otf font files';

  @override
  String get appearanceFontChangedTitle => 'Font changed';

  @override
  String get appearanceFontChangedMessage => 'The new font has been applied';

  @override
  String get appearanceFontImportDialogTitle => 'Select font file';

  @override
  String get appearanceFontImportingTitle => 'Importing font...';

  @override
  String get appearanceFontImportingMessage => 'Please wait';

  @override
  String get appearanceFontImportSuccessTitle => 'Import successful';

  @override
  String get appearanceFontImportSuccessMessage => 'Font imported successfully';

  @override
  String get appearanceFontImportFailedTitle => 'Import failed';

  @override
  String get appearanceFontImportFailedMessage =>
      'Unable to import font file, please check format';

  @override
  String appearanceFontImportFailedWithErrorMessage(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get appearanceFontDeleteConfirmTitle => 'Confirm deletion';

  @override
  String appearanceFontDeleteConfirmMessage(Object fontName) {
    return 'Delete font \"$fontName\"?';
  }

  @override
  String get appearanceFontDeleteCancelButton => 'Cancel';

  @override
  String get appearanceFontDeleteConfirmButton => 'Delete';

  @override
  String get appearanceFontDeleteSuccessTitle => 'Deleted';

  @override
  String get appearanceFontDeleteSuccessMessage => 'Font deleted';

  @override
  String get appearanceFontDeleteFailedTitle => 'Delete failed';

  @override
  String get appearanceFontDeleteFailedMessage => 'Unable to delete font';

  @override
  String get appearanceFontPickerTitle => 'Choose font';

  @override
  String get appearanceFontPickerSearchPlaceholder => 'Search fonts...';

  @override
  String appearanceFontPickerCount(Object count) {
    return '$count fonts';
  }

  @override
  String get appearanceFontPickerFilteredLabel => '(filtered)';

  @override
  String get appearanceFontPickerEmpty => 'No matching fonts found';

  @override
  String get appearanceFontPickerRecommended => 'Recommended';

  @override
  String get appearanceFontPickerCancel => 'Cancel';

  @override
  String get appearanceWindowEffectsSection => 'Window effects';

  @override
  String get appearanceWindowEffectsEnableTitle => 'Enable window effects';

  @override
  String get appearanceWindowEffectsEnabledSubtitle => 'Window effects enabled';

  @override
  String get appearanceWindowEffectsDisabledSubtitle =>
      'Window effects disabled (performance mode)';

  @override
  String get appearanceWindowEffectsEnabledTitle => 'Window effects enabled';

  @override
  String get appearanceWindowEffectsDisabledTitle => 'Window effects disabled';

  @override
  String get appearanceWindowEffectsEnabledMessage => 'Window effects are on';

  @override
  String get appearanceWindowEffectsDisabledMessage =>
      'Switched to solid background for performance';

  @override
  String get appearanceWindowEffectsTypeTitle => 'Effect type';

  @override
  String get appearanceWindowEffectSwitchedTitle => 'Effect switched';

  @override
  String get appearanceWindowEffectAcrylic => 'Acrylic';

  @override
  String get appearanceWindowEffectBlur => 'Blur';

  @override
  String get appearanceWindowEffectMica => 'Mica';

  @override
  String get appearanceWindowEffectMicaAlt => 'Mica Alt';

  @override
  String get appearanceWindowEffectsAcrylicOpacityTitle => 'Acrylic opacity';

  @override
  String get appearanceWindowEffectsAcrylicOpacityHint =>
      'Adjust background opacity (0-255, lower is more transparent)';

  @override
  String get appearanceWindowEffectsAcrylicOpacityMicaHint =>
      'Mica does not support opacity adjustments';

  @override
  String get appearanceWindowEffectsDragSuspendTitle =>
      'Disable effects while dragging';

  @override
  String get appearanceWindowEffectsDragSuspendEnabledSubtitle =>
      'Temporarily disable effects while dragging for smoothness';

  @override
  String get appearanceWindowEffectsDragSuspendDisabledSubtitle =>
      'Keep effects while dragging (may lag on Win10)';

  @override
  String get appearanceWindowEffectsRoundedCornersTitle => 'Rounded corners';

  @override
  String get appearanceWindowEffectsRoundedCornersEnabledSubtitle =>
      'Use rounded window clipping on Win10 and on Win11 Acrylic/Blur windows';

  @override
  String get appearanceWindowEffectsRoundedCornersDisabledSubtitle =>
      'Use square window edges';

  @override
  String get appearanceWindowEffectsMicaHint =>
      'Mica is only available on Windows 11 and follows system theme';

  @override
  String get appearanceWindowEffectsAcrylicHint =>
      'Acrylic uses extra GPU. Disable if it stutters.';

  @override
  String get appearanceWindowEffectsDisabledHint =>
      'Effects are off for best performance';

  @override
  String get appearanceEffectNone => 'No effect';

  @override
  String get appearanceEffectBlur => 'Blur - simple background blur';

  @override
  String get appearanceEffectAcrylic => 'Acrylic - translucent blur background';

  @override
  String get appearanceEffectMica => 'Mica - Windows 11 native effect';

  @override
  String get appearanceEffectMicaAlt =>
      'Mica Alt - Windows 11 transient effect';

  @override
  String get appearanceEffectUnknown => 'Unknown effect';

  @override
  String get appearanceSidebarSection => 'Sidebar';

  @override
  String get appearanceSidebarDefaultTitle => 'Default expanded';

  @override
  String get appearanceSidebarDefaultSubtitle =>
      'Default sidebar state on startup';

  @override
  String get appearanceSidebarExpandedLabel => 'Expanded';

  @override
  String get appearanceSidebarCollapsedLabel => 'Collapsed';

  @override
  String get appearanceSidebarSavedTitle => 'Saved';

  @override
  String appearanceSidebarSavedMessage(Object state) {
    return 'Sidebar default set to $state';
  }

  @override
  String get appearanceNotificationSection => 'Notifications';

  @override
  String get appearanceNotificationEnableTitle => 'Enable notifications';

  @override
  String get appearanceNotificationEnableSubtitle =>
      'Show download completion and error notifications';

  @override
  String get appearanceNotificationSchemeTitle => 'Color scheme';

  @override
  String get appearanceNotificationSchemeSystem => 'Follow theme';

  @override
  String get appearanceNotificationSchemeLight => 'Light';

  @override
  String get appearanceNotificationSchemeDark => 'Dark';

  @override
  String get appearanceNotificationSchemeFluent2 => 'Fluent 2 (Recommended)';

  @override
  String get appearanceNotificationSchemeUnknown => 'Unknown';

  @override
  String get appearanceNotificationSchemeDefaultOption => 'Default';

  @override
  String get appearanceNotificationSchemeLightOption => 'Light';

  @override
  String get appearanceNotificationSchemeDarkOption => 'Dark';

  @override
  String get appearanceNotificationSchemeFluent2Option => 'Fluent 2';

  @override
  String get appearanceNotificationPositionTitle => 'Position';

  @override
  String get appearanceNotificationPositionTopRight =>
      'Top right (below title bar)';

  @override
  String get appearanceNotificationPositionBottomRight => 'Bottom right';

  @override
  String get appearanceNotificationPositionUnknown => 'Unknown';

  @override
  String get appearanceNotificationPositionTopRightOption => 'Top right';

  @override
  String get appearanceNotificationPositionBottomRightOption => 'Bottom right';

  @override
  String get appearanceNotificationPerformanceTitle => 'Render performance';

  @override
  String get appearanceNotificationPerformanceOptionPerformance =>
      'Performance';

  @override
  String get appearanceNotificationPerformanceOptionBalanced => 'Balanced';

  @override
  String get appearanceNotificationPerformanceOptionQuality => 'Quality';

  @override
  String get appearanceNotificationPerformanceHint =>
      'Blur effects can impact smoothness. Choose Performance if stuttering.';

  @override
  String get appearanceNotificationPreviewButtonTitle =>
      'Preview notifications';

  @override
  String get appearanceNotificationPreviewButtonSubtitle =>
      'Click to preview current scheme';

  @override
  String get appearanceNotificationPreviewButton => 'Preview';

  @override
  String get appearanceNotificationPreviewTitle => 'Color preview';

  @override
  String get appearanceNotificationPreviewSuccessTitle => 'Success';

  @override
  String get appearanceNotificationPreviewSuccessMessage =>
      'Operation completed successfully';

  @override
  String get appearanceNotificationPreviewWarningTitle => 'Warning';

  @override
  String get appearanceNotificationPreviewWarningMessage =>
      'Please note the impact of this action';

  @override
  String get appearanceNotificationPreviewErrorTitle => 'Error';

  @override
  String get appearanceNotificationPreviewErrorMessage =>
      'Operation failed, please retry';

  @override
  String get appearanceNotificationPreviewInfoTitle => 'Info';

  @override
  String get appearanceNotificationPreviewInfoMessage =>
      'This is an informational message';

  @override
  String get appearanceNotificationTestTitle => 'Test notification';

  @override
  String get appearanceNotificationTestMessage =>
      'This is a test notification message';

  @override
  String get appearancePerformanceModePerformance =>
      'Performance (no blur, recommended)';

  @override
  String get appearancePerformanceModeBalanced => 'Balanced (light blur)';

  @override
  String get appearancePerformanceModeQuality => 'Quality (full blur)';

  @override
  String get appearancePerformanceModeUnknown => 'Unknown';

  @override
  String get appearanceSegmentsModeTitle => 'Segment progress display';

  @override
  String get appearanceSegmentsModeNoneOption => 'Compact';

  @override
  String get appearanceSegmentsModeMergedOption => 'Merged bar';

  @override
  String get appearanceSegmentsModeListOption => 'Segment list';

  @override
  String get appearanceSegmentsModeNoneDescription =>
      'Compact: hide segment details';

  @override
  String get appearanceSegmentsModeMergedDescription =>
      'Merged: show all segments in one bar';

  @override
  String get appearanceSegmentsModeListDescription =>
      'List: each segment in its own row';

  @override
  String get appearanceSegmentsDefaultExpandedTitle =>
      'Expand segments by default';

  @override
  String get appearanceSegmentsDefaultExpandedSubtitle =>
      'Show segment details expanded by default';

  @override
  String get appearanceSegmentsMaxVisibleTitle => 'Default visible segments';

  @override
  String get appearanceSegmentsMaxVisibleSubtitle =>
      'Number of segments shown when expanded (1-32)';

  @override
  String get appearanceDownloadListSection => 'Download list display';

  @override
  String get appearanceSpeedChartTitle => 'Speed chart background';

  @override
  String get appearanceSpeedChartSubtitle =>
      'Show real-time speed curve on download cards';

  @override
  String get appearanceChartFrostTitle => 'Chart frosted glass';

  @override
  String get appearanceChartFrostSubtitle =>
      'Apply frosted glass effect over the chart';

  @override
  String get appearanceChartPositionTitle => 'Chart position';

  @override
  String get appearanceChartPositionSubtitle =>
      'Adjust chart height within the card';

  @override
  String get appearanceChartPositionLow => 'Low';

  @override
  String get appearanceChartPositionMid => 'Mid';

  @override
  String get appearanceChartPositionHigh => 'High';

  @override
  String get appearanceChartColorTitle => 'Chart color';

  @override
  String get appearanceChartColorSubtitle => 'Customize speed chart line color';

  @override
  String get appearanceChartColorBlue => 'Blue';

  @override
  String get appearanceChartColorCyan => 'Cyan';

  @override
  String get appearanceChartColorPurple => 'Purple';

  @override
  String get appearanceChartColorGreen => 'Green';

  @override
  String get appearanceChartColorPink => 'Pink';

  @override
  String get appearanceChartColorOrange => 'Orange';

  @override
  String get developerSectionDebugTools => 'Debug tools';

  @override
  String get developerSectionTestTools => 'Test tools';

  @override
  String get developerModeEnabledSubtitle => 'Debug tools are enabled';

  @override
  String get developerModeDisabledSubtitle => 'Enable to access debug tools';

  @override
  String get developerToolLogTitle => 'Log viewer';

  @override
  String get developerToolLogSubtitle => 'View runtime logs';

  @override
  String get developerToolLogShownTitle => 'Log viewer shown';

  @override
  String get developerToolLogShownMessage => 'Log page added to navigation';

  @override
  String get developerToolLogHiddenTitle => 'Log viewer hidden';

  @override
  String get developerToolLogHiddenMessage =>
      'Log page removed from navigation';

  @override
  String get developerToolFullLogTitle => 'FULL LOG toggle';

  @override
  String get developerToolFullLogSubtitle =>
      'Show the FULL LOG view toggle on the log page';

  @override
  String get developerToolFullLogShownTitle => 'FULL LOG toggle shown';

  @override
  String get developerToolFullLogShownMessage =>
      'The FULL LOG view toggle is now visible on the log page';

  @override
  String get developerToolFullLogHiddenTitle => 'FULL LOG toggle hidden';

  @override
  String get developerToolFullLogHiddenMessage =>
      'The FULL LOG view toggle is now hidden on the log page';

  @override
  String get developerToolStatusTitle => 'System status';

  @override
  String get developerToolStatusSubtitle => 'Kernel & extension';

  @override
  String get developerToolStatusShownTitle => 'System status shown';

  @override
  String get developerToolStatusShownMessage =>
      'Status page added to navigation';

  @override
  String get developerToolStatusHiddenTitle => 'System status hidden';

  @override
  String get developerToolStatusHiddenMessage =>
      'Status page removed from navigation';

  @override
  String get developerToolOnlineStatsTitle => 'Online stats';

  @override
  String get developerToolOnlineStatsSubtitle => 'User data';

  @override
  String get developerToolOnlineStatsShownTitle => 'Online stats shown';

  @override
  String get developerToolOnlineStatsShownMessage =>
      'Online stats page added to navigation';

  @override
  String get developerToolOnlineStatsHiddenTitle => 'Online stats hidden';

  @override
  String get developerToolOnlineStatsHiddenMessage =>
      'Online stats page removed from navigation';

  @override
  String get developerToolWebCheckTitle => 'Web check';

  @override
  String get developerToolWebCheckSubtitle => 'Website diagnostics';

  @override
  String get developerToolWebCheckShownTitle => 'Web check shown';

  @override
  String get developerToolWebCheckShownMessage =>
      'Web check page added to navigation';

  @override
  String get developerToolWebCheckHiddenTitle => 'Web check hidden';

  @override
  String get developerToolWebCheckHiddenMessage =>
      'Web check page removed from navigation';

  @override
  String get developerToolPerformanceTitle => 'Performance monitor';

  @override
  String get developerToolPerformanceSubtitle => 'FPS & rendering';

  @override
  String get developerToolPerformanceShownTitle => 'Performance monitor shown';

  @override
  String get developerToolPerformanceShownMessage =>
      'Performance monitor page added to navigation';

  @override
  String get developerToolPerformanceHiddenTitle =>
      'Performance monitor hidden';

  @override
  String get developerToolPerformanceHiddenMessage =>
      'Performance monitor page removed from navigation';

  @override
  String get developerToolConnectionDebugTitle => 'Connection debug';

  @override
  String get developerToolConnectionDebugSubtitle =>
      'Network connectivity diagnostics';

  @override
  String get developerToolConnectionDebugShownTitle => 'Connection debug shown';

  @override
  String get developerToolConnectionDebugShownMessage =>
      'Connection debug page added to navigation';

  @override
  String get developerToolConnectionDebugHiddenTitle =>
      'Connection debug hidden';

  @override
  String get developerToolConnectionDebugHiddenMessage =>
      'Connection debug page removed from navigation';

  @override
  String get connectionDebugTitle => 'Connection Debug';

  @override
  String get connectionDebugTestTitle => 'Test Download Connection';

  @override
  String get connectionDebugTestSubtitle =>
      'Enter a download URL to test connectivity, proxy status, and transfer capability';

  @override
  String get connectionDebugTesting => 'Testing...';

  @override
  String get connectionDebugStartTest => 'Start Test';

  @override
  String connectionDebugResults(int count) {
    return 'Test Results ($count)';
  }

  @override
  String get connectionDebugSuccess => 'Connected';

  @override
  String get connectionDebugFailed => 'Connection Failed';

  @override
  String get connectionDebugLocalHost => 'Local';

  @override
  String get connectionDebugProxy => 'Proxy';

  @override
  String get connectionDebugUnknown => 'Unknown';

  @override
  String get connectionDebugReceived => 'Received';

  @override
  String get connectionDebugFileSize => 'File Size';

  @override
  String get connectionDebugRangeSupported => 'Supported';

  @override
  String get connectionDebugRangeNotSupported => 'Not Supported';

  @override
  String get connectionDebugStrategyTitle => 'Host Strategy Cache';

  @override
  String get connectionDebugStrategySubtitle =>
      'Observe protocol downgrade and concurrency caps learned per host from previous download failures';

  @override
  String get connectionDebugStrategyRefresh => 'Refresh';

  @override
  String get connectionDebugStrategyClear => 'Clear Cache';

  @override
  String get connectionDebugStrategyEmpty =>
      'No host strategy cache yet. Once a host triggers protocol fallback or concurrency throttling, it will appear here.';

  @override
  String connectionDebugStrategyCount(Object count) {
    return '$count host strategy entries';
  }

  @override
  String get connectionDebugStrategyPolicy => 'Policy';

  @override
  String get connectionDebugStrategyConcurrency => 'Concurrency';

  @override
  String get connectionDebugStrategyTtl => 'TTL';

  @override
  String get connectionDebugStrategyExpired => 'expired';

  @override
  String get developerTestNotificationTitle => 'Notification test';

  @override
  String get developerTestNotificationTitlePlaceholder => 'Title';

  @override
  String get developerTestNotificationMessagePlaceholder =>
      'Message (optional)';

  @override
  String get developerTestNotificationTypeSuccess => 'Success';

  @override
  String get developerTestNotificationTypeWarning => 'Warning';

  @override
  String get developerTestNotificationTypeError => 'Error';

  @override
  String get developerTestNotificationTypeInfo => 'Info';

  @override
  String get developerTestNotificationTitleRequired => 'Please enter a title';

  @override
  String get developerTestPopupTitle => 'Popup test';

  @override
  String get developerTestPopupButton => 'Test add-download dialog';

  @override
  String get developerTestPopupTestingLabel => 'Testing...';

  @override
  String get developerTestPopupHint =>
      'This test brings the main window to the front and opens the add-download dialog';

  @override
  String developerTestPopupResultSuccess(Object time) {
    return 'Success ? ${time}ms';
  }

  @override
  String get developerTestPopupResultFailed => 'Failed';

  @override
  String get developerOpenL10nFolderTitle => 'Language pack folder';

  @override
  String get developerOpenL10nFolderSubtitle =>
      'Open l10n folder in file manager';

  @override
  String get developerOpenL10nFolderSuccessTitle => 'Folder opened';

  @override
  String get developerOpenL10nFolderSuccessMessage =>
      'Language pack folder opened in file manager';

  @override
  String get developerOpenL10nFolderFailedTitle => 'Failed to open';

  @override
  String developerOpenL10nFolderFailedMessage(Object error) {
    return 'Could not open folder: $error';
  }

  @override
  String get updateCurrentVersionTitle => 'Current version';

  @override
  String get updateChangelogTitle => 'Changelog';

  @override
  String get updateChangelogViewFullButton => 'View full changelog';

  @override
  String updateChangelogDialogTitle(Object version) {
    return 'v$version Changelog';
  }

  @override
  String get updateCheckTitle => 'Check for updates';

  @override
  String get updateStartButton => 'Start update';

  @override
  String get updateCheckAgainButton => 'Check again';

  @override
  String get updateCheckingStatus => 'Checking for updates...';

  @override
  String get updateCheckFailedTitle => 'Update check failed';

  @override
  String get updateLatestTitle => 'You\'re up to date';

  @override
  String get updateLatestSubtitle => 'You are using the latest version';

  @override
  String get updateInitialHint => 'Click \"Check again\" to look for updates';

  @override
  String get updateUnreleasedTitle => 'Unreleased version';

  @override
  String updateUnreleasedSubtitle(Object version) {
    return 'Current version v$version | Version not found, possibly a special or dev build';
  }

  @override
  String get updateConfirmTitle => 'Confirm update';

  @override
  String get updateConfirmMessage =>
      'A new version is ready. The app will close to install it.';

  @override
  String updateConfirmDetails(Object newVersion, Object currentVersion,
      Object change, Object currentChannel, Object targetChannel) {
    return 'New version: $newVersion\nCurrent version: $currentVersion\nChange: $change\nChannel: $currentChannel ? $targetChannel\nReady to update?';
  }

  @override
  String get updateConfirmCancelButton => 'Cancel';

  @override
  String get updateConfirmProceedButton => 'Update now';

  @override
  String get updateUnknownVersion => 'Unknown';

  @override
  String get updateUnknownChannel => 'Unknown';

  @override
  String get updateLauncherFailedTitle => 'Failed to launch updater';

  @override
  String get updateLauncherFailedMessage =>
      'Unable to start Update.exe\nTroubleshooting:\n ?Check if Update.exe was removed or moved\n ?Ensure .NET 8 is installed\n ?Ensure the installer is intact\nIf still failing, download and install manually.';

  @override
  String get updateLauncherFailedCloseButton => 'Close';

  @override
  String get updateLauncherFailedManualDownloadButton => 'Manual download';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateAvailableChangelogTitle => 'What\'s new';

  @override
  String get updateSettingsTitle => 'Update settings';

  @override
  String get updateDotNetMissingSubtitle =>
      'Not installed - recommended for the updater';

  @override
  String get updateDotNetDownloadButton => 'Download';

  @override
  String get updateDotNetInstalledSubtitle => 'Installed - updater available';

  @override
  String get updateDotNetRecheckButton => 'Recheck';

  @override
  String get updateDotNetRecommendTitle => 'Recommended: .NET 8';

  @override
  String get updateDotNetRecommendSubtitle =>
      'Install .NET 8 Desktop Runtime to enable auto updates';

  @override
  String get updateDotNetRecommendButton => 'Download .NET 8';

  @override
  String get updateChannelTitle => 'Current channel';

  @override
  String get updateChannelAlpha => 'Alpha (preview)';

  @override
  String get updateChannelBeta => 'Beta (public)';

  @override
  String get updateChannelRelease => 'Release (stable)';

  @override
  String get updateIntervalTitle => 'Auto check updates';

  @override
  String get updateIntervalSubtitle => 'Set how often to check for updates';

  @override
  String get updateIntervalStartup => 'On startup only';

  @override
  String get updateIntervalHourly => 'Hourly';

  @override
  String get updateIntervalDaily => 'Daily';

  @override
  String get updateIntervalWeekly => 'Weekly';

  @override
  String get updateIntervalNever => 'Never';

  @override
  String get updateAllowBetaTitle => 'Receive Beta updates';

  @override
  String get updateAllowBetaSubtitle => 'Allow receiving stable beta releases';

  @override
  String get updateAllowAlphaTitle => 'Receive Alpha updates';

  @override
  String get updateAllowAlphaSubtitle =>
      'Allow receiving the latest test builds (may be unstable)';

  @override
  String updateLastCheckLabel(Object time) {
    return 'Last checked: $time';
  }

  @override
  String get updateTimeJustNow => 'Just now';

  @override
  String updateTimeMinutesAgo(Object minutes) {
    return '$minutes minutes ago';
  }

  @override
  String updateTimeHoursAgo(Object hours) {
    return '$hours hours ago';
  }

  @override
  String get updateDialogCloseButton => 'Close';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusOffline => 'Offline';

  @override
  String get settingsDangerZoneTitle => 'Danger Zone';

  @override
  String get popupDownloadTitle => 'New download';

  @override
  String get popupDownloadLinkLabel => 'Download URL';

  @override
  String get popupDownloadLinkPlaceholder => 'HTTP/HTTPS URL';

  @override
  String get popupDownloadFileNameLabel => 'File name';

  @override
  String get popupDownloadFileNamePlaceholder => 'Save as filename';

  @override
  String get popupDownloadSavePathLabel => 'Save to';

  @override
  String get popupDownloadSavePathPlaceholder => 'Download folder';

  @override
  String get popupDownloadAutoStart => 'Start download immediately';

  @override
  String get popupDownloadFeatureHint =>
      'Supports multi-threading, resume, and speed limits';

  @override
  String get popupDownloadCancel => 'Cancel';

  @override
  String get popupDownloadAdding => 'Adding...';

  @override
  String get popupDownloadStart => 'Start download';

  @override
  String get popupDownloadErrorMissingInfo => 'Please fill in all fields';

  @override
  String get popupDownloadErrorInvalidUrl =>
      'Please enter a valid HTTP/HTTPS URL';

  @override
  String popupDownloadErrorAddFailed(Object error) {
    return 'Failed to add task: $error';
  }

  @override
  String get popupDownloadErrorTitle => 'Error';

  @override
  String get popupDownloadErrorConfirm => 'OK';

  @override
  String get popupDownloadDefaultFileName => 'download';

  @override
  String get addDownloadTitle => 'New download';

  @override
  String get addDownloadSubtitle =>
      'Supports multi-threaded downloads and resume';

  @override
  String get addDownloadUrlLabel => 'Download URL';

  @override
  String get addDownloadRequiredBadge => 'Required';

  @override
  String get addDownloadUrlPlaceholder => 'https://example.com/file.zip';

  @override
  String get addDownloadParsedFileNameTitle => 'Filename detected';

  @override
  String get addDownloadAdvancedToggle => 'Advanced options';

  @override
  String get addDownloadAdvancedCollapsedHint => 'Custom filename';

  @override
  String get addDownloadAdvancedExpandedHint => 'Collapse';

  @override
  String get addDownloadFileNameLabel => 'Custom filename';

  @override
  String get addDownloadOptionalBadge => 'Optional';

  @override
  String get addDownloadFileNamePlaceholder =>
      'Leave blank to use detected name';

  @override
  String get addDownloadFeatureTitle => 'Smart download features';

  @override
  String get addDownloadFeature1Title => 'Multi-threaded segments';

  @override
  String get addDownloadFeature1Desc => 'Maximize download speed';

  @override
  String get addDownloadFeature2Title => 'Auto resume';

  @override
  String get addDownloadFeature2Desc => 'Recover after network interruption';

  @override
  String get addDownloadFeature3Title => 'Dynamic segmentation';

  @override
  String get addDownloadFeature3Desc => 'Adaptive download strategy';

  @override
  String get addDownloadCancelButton => 'Cancel';

  @override
  String get addDownloadAdding => 'Adding...';

  @override
  String get addDownloadStart => 'Start download';

  @override
  String get addDownloadErrorMissingUrl => 'Please enter a download URL';

  @override
  String get addDownloadErrorInvalidUrl =>
      'Please enter a valid HTTP/HTTPS URL';

  @override
  String addDownloadErrorAddFailed(Object error) {
    return 'Failed to add task: $error';
  }

  @override
  String get addDownloadErrorTitle => 'Error';

  @override
  String get addDownloadErrorConfirm => 'OK';

  @override
  String get addDownloadSuccessTitle => 'Task added';

  @override
  String addDownloadSuccessMessage(Object fileName) {
    return 'Downloading: $fileName';
  }

  @override
  String get folderPickerErrorPathNotFound => 'Path not found';

  @override
  String get folderPickerErrorAccessDenied =>
      'Unable to access this path (permission denied)';

  @override
  String folderPickerErrorAccessFailed(Object error) {
    return 'Unable to access this path: $error';
  }

  @override
  String get folderPickerCreateTitle => 'Create folder';

  @override
  String get folderPickerCreatePrompt => 'Create the folder in:';

  @override
  String get folderPickerCreatePlaceholder => 'Folder name';

  @override
  String get folderPickerCancelButton => 'Cancel';

  @override
  String get folderPickerCreateButton => 'Create';

  @override
  String get folderPickerConfirmButton => 'OK';

  @override
  String get folderPickerCreateExistsTitle => 'Creation canceled';

  @override
  String folderPickerCreateExistsMessage(Object name) {
    return 'Folder \"$name\" already exists.\nSelected that folder.';
  }

  @override
  String get folderPickerCreateSuccessTitle => 'Created';

  @override
  String folderPickerCreateSuccessMessage(Object name) {
    return 'Folder \"$name\" was created and selected';
  }

  @override
  String get folderPickerCreateFailedTitle => 'Creation failed';

  @override
  String folderPickerCreateFailedMessage(Object error) {
    return 'Failed to create folder: $error';
  }

  @override
  String get folderPickerQuickPathAddTitle => 'Add quick path';

  @override
  String get folderPickerQuickPathAddPrompt =>
      'Add current path to quick paths:';

  @override
  String get folderPickerQuickPathAddNameLabel => 'Custom name (optional):';

  @override
  String get folderPickerQuickPathAddNamePlaceholder => 'e.g. My Project';

  @override
  String get folderPickerQuickPathAddButton => 'Add';

  @override
  String get folderPickerQuickPathAddSuccessTitle => 'Added';

  @override
  String get folderPickerQuickPathAddFailedTitle => 'Add failed';

  @override
  String get folderPickerQuickPathAddSuccessMessage => 'Quick path added';

  @override
  String get folderPickerQuickPathAddFailedMessage =>
      'Path already exists or is invalid';

  @override
  String get folderPickerQuickPathRemoveTitle => 'Remove quick path';

  @override
  String folderPickerQuickPathRemoveMessage(Object path) {
    return 'Remove this quick path?\n\n$path';
  }

  @override
  String get folderPickerQuickPathRemoveButton => 'Remove';

  @override
  String get folderPickerTitle => 'Select folder';

  @override
  String get folderPickerNavUpTooltip => 'Parent folder';

  @override
  String get folderPickerPathPlaceholder => 'Enter a path or pick below';

  @override
  String get folderPickerRefreshTooltip => 'Refresh';

  @override
  String get folderPickerNewFolderTooltip => 'New folder';

  @override
  String get folderPickerAddQuickPathTooltip =>
      'Add current path to quick paths';

  @override
  String get folderPickerEmptyMessage => 'This folder is empty';

  @override
  String get folderPickerSelectButton => 'Select';

  @override
  String get updateLatestVersionLabel => 'Latest version';

  @override
  String get updateDialogLaterButton => 'Later';

  @override
  String get updateDialogDownloadNowButton => 'Download now';

  @override
  String get updateDialogCurrentInfoTitle => 'Current version info';

  @override
  String get downloadStatusDownloading => 'Downloading';

  @override
  String get downloadStatusPaused => 'Paused';

  @override
  String get downloadStatusPending => 'Pending';

  @override
  String get downloadStatusFailed => 'Failed';

  @override
  String get downloadStatusMerging => 'Merging';

  @override
  String get downloadStatusCompleted => 'Completed';

  @override
  String get downloadFilterTitle => 'Filter downloads';

  @override
  String get downloadFilterSubtitle => 'Select status to display:';

  @override
  String get downloadFilterAll => 'All';

  @override
  String get downloadDialogCloseButton => 'Close';

  @override
  String get downloadSortTitle => 'Sort order';

  @override
  String get downloadSortSubtitle => 'Choose task order:';

  @override
  String get downloadSortNewest => 'Newest first';

  @override
  String get downloadSortOldest => 'Oldest first';

  @override
  String get downloadSortNewestDesc => 'Newest tasks appear at the top';

  @override
  String get downloadSortOldestDesc => 'Oldest tasks appear at the top';

  @override
  String get downloadSearchPlaceholder => 'Search filename or URL...';

  @override
  String get downloadNoResultsTitle => 'No matching downloads';

  @override
  String get downloadNoResultsSubtitle =>
      'Try adjusting your search or filters';

  @override
  String get downloadStatsActiveLabel => 'Active';

  @override
  String get downloadStatsSpeedLabel => 'Total speed';

  @override
  String get downloadStatsSegmentsLabel => 'Active segments';

  @override
  String get downloadEmptyTitle => 'No downloads yet';

  @override
  String get downloadEmptySubtitle => 'Click \"New\" in the top right to start';

  @override
  String get downloadCopySuccessTitle => 'Copied';

  @override
  String get loadingTasks => 'Loading tasks...';

  @override
  String get loadingTasksHint => 'Connecting to download engine';

  @override
  String get downloadCopySuccessMessage => 'Link copied to clipboard';

  @override
  String get downloadCopyFailedTitle => 'Copy failed';

  @override
  String downloadCopyFailedMessage(Object error) {
    return 'Unable to copy link: $error';
  }

  @override
  String get downloadCopyTooltip => 'Click to copy link';

  @override
  String get downloadActionStart => 'Start';

  @override
  String get downloadActionPause => 'Pause';

  @override
  String get downloadActionRetrySegments => 'Retry failed segments';

  @override
  String get downloadActionRetryAll => 'Redownload';

  @override
  String get downloadActionDelete => 'Delete';

  @override
  String get downloadMergingStatus => 'Verifying and merging data';

  @override
  String get downloadCalculatingSize => 'Calculating file size...';

  @override
  String get downloadCalculating => 'Calculating';

  @override
  String get downloadMatchingHttpProtocol => 'Matching HTTP protocol...';

  @override
  String get downloadMatchingHttpProtocolShort => 'Matching protocol';

  @override
  String downloadSegmentsTitleWithCount(Object count) {
    return 'Segments ($count)';
  }

  @override
  String get downloadSegmentsTitle => 'Segments';

  @override
  String get downloadSegmentsStatusCompleted => 'Done';

  @override
  String get downloadSegmentsStatusDownloading => 'Downloading';

  @override
  String get downloadSegmentsStatusFailed => 'Failed';

  @override
  String downloadSegmentsSummary(
      Object total, Object completed, Object downloading) {
    return '$total segments ? $completed done ? $downloading downloading';
  }

  @override
  String downloadSegmentsSummaryWithFailed(
      Object total, Object completed, Object downloading, Object failed) {
    return '$total segments - $completed done - $downloading downloading - $failed failed';
  }

  @override
  String get downloadRetryButton => 'Retry';

  @override
  String downloadSegmentLabel(Object index) {
    return 'Segment $index';
  }

  @override
  String downloadSegmentRetryCount(Object count) {
    return 'Retry $count';
  }

  @override
  String get downloadSegmentsCollapse => 'Collapse';

  @override
  String downloadSegmentsShowAll(Object count) {
    return 'Show all $count';
  }

  @override
  String downloadSizeUnknown(Object downloaded) {
    return '$downloaded / Unknown';
  }

  @override
  String get downloadFailedTitle => 'Download failed';

  @override
  String downloadFailedSegmentsHint(Object count) {
    return '$count segments failed. Try re-downloading.';
  }

  @override
  String get downloadConfirmDeleteTitle => 'Confirm delete';

  @override
  String downloadConfirmDeleteMessage(Object fileName) {
    return 'Delete task \"$fileName\"?';
  }

  @override
  String get downloadDeleteButton => 'Delete';

  @override
  String get completedCategoryAll => 'All';

  @override
  String get completedCategoryVideo => 'Video';

  @override
  String get completedCategoryAudio => 'Audio';

  @override
  String get completedCategoryArchive => 'Archive';

  @override
  String get completedCategoryDocument => 'Document';

  @override
  String get completedCategoryProgram => 'Program';

  @override
  String get completedCategoryOther => 'Other';

  @override
  String get completedSearchPlaceholder => 'Search completed files...';

  @override
  String get completedNoResultsTitle => 'No matching files';

  @override
  String get completedNoResultsSubtitle => 'Try adjusting your search';

  @override
  String get completedHeaderTitle => 'Completed';

  @override
  String get completedOpenFolderButton => 'Open folder';

  @override
  String get completedEmptyTitle => 'No completed tasks yet';

  @override
  String get completedEmptySubtitle => 'Finished downloads will show up here';

  @override
  String get completedStatsTitle => 'Download stats';

  @override
  String get completedStatsPeakSpeed => 'Peak speed';

  @override
  String get completedStatsAverageSpeed => 'Average speed';

  @override
  String get completedStatsDuration => 'Duration';

  @override
  String get completedStatsSegments => 'Segments';

  @override
  String get completedStatsThreads => 'Threads';

  @override
  String get completedStatsCore => 'Download core';

  @override
  String get completedActionRun => 'Run';

  @override
  String get completedActionLocation => 'Location';

  @override
  String get completedTimeJustNow => 'Just now';

  @override
  String completedTimeMinutesAgo(Object minutes) {
    return '$minutes min ago';
  }

  @override
  String completedTimeHoursAgo(Object hours) {
    return '$hours hr ago';
  }

  @override
  String completedTimeDaysAgo(Object days) {
    return '$days days ago';
  }

  @override
  String completedTimeMonthDay(Object month, Object day) {
    return '$month/$day';
  }

  @override
  String get completedFilePathMissingMessage => 'File path not found';

  @override
  String completedRunFileFailedMessage(Object error) {
    return 'Failed to run file: $error';
  }

  @override
  String completedOpenFileLocationFailedMessage(Object error) {
    return 'Failed to open file location: $error';
  }

  @override
  String get completedHintTitle => 'Notice';

  @override
  String get completedConfirmDeleteTitle => 'Confirm deletion';

  @override
  String completedDeleteTaskMessage(Object fileName) {
    return 'Delete \"$fileName\"?';
  }

  @override
  String get completedRemoveSuccessTitle => 'Removed';

  @override
  String get completedRemoveSuccessMessage => 'Task removed from list';

  @override
  String get completedDeleteSuccessTitle => 'Deleted';

  @override
  String completedDeleteFileSuccessMessage(Object fileName) {
    return 'Deleted file: $fileName';
  }

  @override
  String get completedFileNotFoundTitle => 'File not found';

  @override
  String get completedFileNotFoundMessage =>
      'The file may have been moved or deleted';

  @override
  String get completedDeleteFailedTitle => 'Delete failed';

  @override
  String completedDeleteFailedMessage(Object error) {
    return 'Failed to delete file: $error';
  }

  @override
  String get completedCancelButton => 'Cancel';

  @override
  String get completedRemoveButton => 'Remove';

  @override
  String get completedDeleteButton => 'Delete';

  @override
  String get completedCreateButton => 'Create';

  @override
  String get completedCreateCategoryTitle => 'Create custom category';

  @override
  String get completedCreateCategoryNameLabel => 'Category name';

  @override
  String get completedCreateCategoryNamePlaceholder => 'e.g. Images';

  @override
  String get completedCreateCategoryExtensionsLabel => 'File extensions';

  @override
  String get completedCreateCategoryExtensionsPlaceholder =>
      'e.g. .jpg,.png,.gif (comma-separated)';

  @override
  String get completedCreateCategoryHint =>
      'Tip: extensions must include dot; separate with commas';

  @override
  String get completedCreateCategoryInputErrorTitle => 'Input error';

  @override
  String get completedCreateCategoryInputErrorMessage =>
      'Please fill in all fields';

  @override
  String get completedCreateCategoryInvalidExtMessage =>
      'Please enter valid extensions';

  @override
  String get completedCreateCategorySuccessTitle => 'Created';

  @override
  String completedCreateCategorySuccessMessage(Object name) {
    return 'Category created: $name';
  }

  @override
  String completedDeleteCategoryMessage(Object name) {
    return 'Delete custom category \"$name\"?';
  }

  @override
  String get completedDeleteCategorySuccessTitle => 'Deleted';

  @override
  String completedDeleteCategorySuccessMessage(Object name) {
    return 'Category deleted: $name';
  }

  @override
  String get statusPageTitle => 'System Status';

  @override
  String get statusPageRefresh => 'Refresh';

  @override
  String get statusPageTestApi => 'Test API';

  @override
  String get statusPageClearLogs => 'Clear logs';

  @override
  String get statusSectionKernel => 'Kernel status';

  @override
  String get statusItemKernelRuntime => 'Kernel runtime';

  @override
  String get statusValueRunning => 'Running';

  @override
  String get statusValueStopped => 'Stopped';

  @override
  String get statusItemKernelCurrent => 'Current kernel';

  @override
  String get statusItemHttpService => 'HTTP service';

  @override
  String get statusValueHealthy => 'Healthy';

  @override
  String get statusValueBuiltIn => 'Built-in';

  @override
  String get statusValueUnhealthy => 'Unhealthy';

  @override
  String get statusItemServiceAddress => 'Service address';

  @override
  String get statusItemKernelVersion => 'Kernel version';

  @override
  String get statusSectionNetwork => 'Network status';

  @override
  String get statusItemLocalNetwork => 'Local network';

  @override
  String get statusValueConnected => 'Connected';

  @override
  String get statusValueDisconnected => 'Disconnected';

  @override
  String get statusItemInternet => 'Internet';

  @override
  String get statusValueReachable => 'Reachable';

  @override
  String get statusValueUnreachable => 'Unreachable';

  @override
  String get statusItemLocalIp => 'Local IP';

  @override
  String get statusItemNetworkLatency => 'Network latency';

  @override
  String statusNetworkLatencyMs(Object ms) {
    return '$ms ms';
  }

  @override
  String get statusItemConnectionType => 'Connection type';

  @override
  String get statusSectionApiTests => 'API test results';

  @override
  String get statusValueFailed => 'Failed';

  @override
  String get statusSectionSystemInfo => 'System info';

  @override
  String get statusItemOs => 'Operating system';

  @override
  String get statusValueUnknown => 'Unknown';

  @override
  String get statusItemOsVersion => 'OS version';

  @override
  String get statusItemCpuCores => 'CPU cores';

  @override
  String statusSystemCpuCores(Object count) {
    return '$count cores';
  }

  @override
  String get statusItemDartVersion => 'Dart version';

  @override
  String get statusSectionDownloadStats => 'Download stats';

  @override
  String get statusItemTotalDownloads => 'Total downloads';

  @override
  String get statusItemActiveTasks => 'Active tasks';

  @override
  String get statusItemCompletedTasks => 'Completed';

  @override
  String get statusItemFailedTasks => 'Failed tasks';

  @override
  String get statusItemTotalDownloaded => 'Total downloaded';

  @override
  String get statusSectionLogStats => 'Log stats';

  @override
  String get statusItemLogCount => 'Log count';

  @override
  String get statusItemErrorCount => 'Error count';

  @override
  String get statusItemWarningCount => 'Warning count';

  @override
  String get statusSectionExtension => 'Browser extension';

  @override
  String get statusItemTip => 'Tip';

  @override
  String get statusExtensionTip =>
      'Thanks for using. In-app download plugin and store link are supported.';

  @override
  String get statusExtensionDownloadButton => 'Download extension';

  @override
  String get statusExtensionOpenStoreButton => 'Open store';

  @override
  String get statusSectionAutoStart => 'Auto start';

  @override
  String get statusItemPlatformSupport => 'Platform support';

  @override
  String get statusAutoStartWindowsOnly => 'Windows only';

  @override
  String get statusItemAutoStartStatus => 'Auto-start status';

  @override
  String get statusValueEnabled => 'Enabled';

  @override
  String get statusValueDisabled => 'Disabled';

  @override
  String get statusItemRegistryPath => 'Registry path';

  @override
  String get statusValueCorrect => 'Correct';

  @override
  String get statusValueNeedsUpdate => 'Needs update';

  @override
  String get statusItemCurrentRegistry => 'Current registry';

  @override
  String get statusItemCurrentPath => 'Current path';

  @override
  String get statusAutoStartOldRegistryTitle =>
      'Legacy auto-start entry detected';

  @override
  String get statusAutoStartOldRegistryMessage =>
      'Registry path doesn\'t match current executable (app updated or moved). Click below to fix automatically.';

  @override
  String get statusAutoStartFixButton => 'Fix auto-start';

  @override
  String get statusSectionPopupTest => 'Popup window test';

  @override
  String get statusItemDescription => 'Description';

  @override
  String get statusPopupTestDescription =>
      'Test whether browser-triggered downloads can open the standalone popup window';

  @override
  String get statusItemTestResult => 'Test result';

  @override
  String statusPopupTestResultSuccess(Object time) {
    return 'Success (${time}ms)';
  }

  @override
  String statusPopupTestResultFailed(Object error) {
    return 'Failed: $error';
  }

  @override
  String get statusPopupTesting => 'Creating...';

  @override
  String get statusPopupTestButton => 'Test add-download dialog';

  @override
  String get statusPopupDialogTestButton => 'Legacy dialog test';

  @override
  String get statusPopupTestInfoTitle => 'Test notes';

  @override
  String get statusPopupTestInfoBody =>
      '• Browser-triggered downloads open a standalone Flutter popup window\\n• The main window stays in the background and is not brought to the front\\n• Results and timing are recorded in logs';

  @override
  String get statusExtensionDownloadAddedTitle => 'Download added';

  @override
  String get statusExtensionDownloadAddedMessage =>
      'Browser extension added to download list';

  @override
  String get statusExtensionDownloadFailedTitle => 'Download failed';

  @override
  String statusExtensionDownloadFailedMessage(Object error) {
    return 'Failed to add download task: $error';
  }

  @override
  String get statusExtensionOpenLinkFailed => 'Unable to open link';

  @override
  String get statusExtensionOpenFailedTitle => 'Open failed';

  @override
  String statusExtensionOpenFailedMessage(Object error) {
    return 'Unable to open browser: $error';
  }

  @override
  String get statusAutoStartFixSuccessTitle => 'Fix succeeded';

  @override
  String get statusAutoStartFixSuccessMessage =>
      'Auto-start registry updated to current version';

  @override
  String get statusAutoStartFixFailedTitle => 'Fix failed';

  @override
  String get statusAutoStartFixFailedMessage =>
      'Unable to update auto-start registry. Check permissions.';

  @override
  String statusAutoStartFixErrorMessage(Object error) {
    return 'Error occurred: $error';
  }

  @override
  String get statusPopupTestCreating => 'Opening add-download dialog...';

  @override
  String get statusPopupTestStartLog =>
      'Starting standalone popup window test...';

  @override
  String statusPopupTestSuccessLog(Object time) {
    return 'Standalone popup window opened in ${time}ms';
  }

  @override
  String get statusPopupTestSuccessMessage =>
      'Add-download dialog opened successfully';

  @override
  String get statusPopupTestSuccessTitle => 'Test succeeded';

  @override
  String statusPopupTestSuccessToast(Object time) {
    return 'Add-download dialog opened in ${time}ms';
  }

  @override
  String statusPopupTestFailedLog(Object error) {
    return 'Standalone popup window failed: $error';
  }

  @override
  String get statusPopupTestFailedTitle => 'Test failed';

  @override
  String statusPopupTestFailedToast(Object error) {
    return 'Add-download dialog failed: $error';
  }

  @override
  String get statusPopupDialogTestStartLog => 'Starting Dialog popup test...';

  @override
  String statusPopupDialogTestCloseLog(Object time) {
    return 'Dialog popup closed in ${time}ms';
  }

  @override
  String statusPopupDialogTestFailedLog(Object error) {
    return 'Dialog popup failed: $error';
  }

  @override
  String get statusApiTestHealthCheck => 'Health Check';

  @override
  String get statusApiTestGetTasks => 'Get Tasks';

  @override
  String get statusApiTestGetStatistics => 'Get Statistics';

  @override
  String get statusApiTestGetConfig => 'Get Config';

  @override
  String get onlineStatsPageTitle => 'Who\'s online with you';

  @override
  String get onlineStatsCountUnit => 'people';

  @override
  String get onlineStatsAloneMessage =>
      'You\'re the only one using Hanabi right now';

  @override
  String onlineStatsOthersMessage(Object count) {
    return 'Besides you, $count users are using Hanabi';
  }

  @override
  String onlineStatsTotalMessage(Object count) {
    return '(Including you, $count total)';
  }

  @override
  String get onlineStatsMyStatusTitle => 'My status';

  @override
  String get onlineStatsDeviceIdLabel => 'Device ID';

  @override
  String get onlineStatsNotInitialized => 'Not initialized';

  @override
  String get onlineStatsAppVersionLabel => 'App version';

  @override
  String get onlineStatsHeartbeatLabel => 'Heartbeat interval';

  @override
  String get onlineStatsHeartbeatValue => 'Auto-send every 5 minutes';

  @override
  String get onlineStatsServerLabel => 'Stats server';

  @override
  String get onlineStatsSending => 'Sending...';

  @override
  String get onlineStatsSendSignalButton => 'Send my signal to server';

  @override
  String get onlineStatsPrivacyPolicy => 'Privacy policy';

  @override
  String get onlineStatsTermsOfService => 'Terms of service';

  @override
  String get onlineStatsOfficialSite => 'Official website';

  @override
  String get onlineStatsSendSuccessTitle => 'Sent';

  @override
  String get onlineStatsSendSuccessMessage =>
      'Your signal was sent to the server';

  @override
  String get onlineStatsCooldownTitle => 'Server marked online';

  @override
  String onlineStatsCooldownMessage(Object minutes) {
    return 'Your status was recorded. Try again in $minutes minutes.';
  }

  @override
  String get onlineStatsSendFailedTitle => 'Send failed';

  @override
  String get onlineStatsSendFailedMessage =>
      'Unable to reach stats server. Check your network connection.';

  @override
  String get onlineStatsOpenLinkFailedTitle => 'Unable to open link';

  @override
  String onlineStatsOpenLinkFailedMessage(Object url) {
    return 'Please open in your browser manually:\\n$url';
  }

  @override
  String get onlineStatsOpenFailedTitle => 'Open failed';

  @override
  String onlineStatsOpenFailedMessage(Object error, Object url) {
    return 'Error: $error\\n\\nPlease open in your browser manually:\\n$url';
  }

  @override
  String get onlineStatsDialogOk => 'OK';

  @override
  String get logPageTitle => 'Logs';

  @override
  String get logFilterLevelLabel => 'Level';

  @override
  String logFilterTagCount(Object count) {
    return '$count tags';
  }

  @override
  String get logFilterSourceLabel => 'Source';

  @override
  String get logFilterTimeSelectedLabel => 'Time ✓';

  @override
  String get logFilterTimeLabel => 'Time';

  @override
  String get logRegexRulesButton => 'Regex rules';

  @override
  String get logAutoScrollOn => 'Auto scroll: On';

  @override
  String get logAutoScrollOff => 'Auto scroll: Off';

  @override
  String get logStatsShow => 'Stats: Show';

  @override
  String get logStatsHide => 'Stats: Hide';

  @override
  String get logFailureStatsShow => 'Failure stats: Show';

  @override
  String get logFailureStatsHide => 'Failure stats: Hide';

  @override
  String get logExportLogsButton => 'Export logs';

  @override
  String get logExportDiagnosticsButton => 'Export diagnostics';

  @override
  String get logArchiveButton => 'Archive logs';

  @override
  String get logClearButton => 'Clear logs';

  @override
  String get logCurrentTabLabel => 'Current';

  @override
  String get logFullTabLabel => 'FULL LOG';

  @override
  String get logSearchPlaceholderRegex => 'Enter regex...';

  @override
  String get logSearchPlaceholder => 'Search logs...';

  @override
  String get logEmptyTitle => 'No logs';

  @override
  String get logEmptySubtitle => 'Logs will appear here';

  @override
  String get logStatTotal => 'Total';

  @override
  String logGroupedCount(Object count) {
    return '$count groups';
  }

  @override
  String get logClearFiltersButton => 'Clear';

  @override
  String get logFailureStatsTitle => 'Download failure stats';

  @override
  String logFailureStatsTotal(Object count) {
    return 'Total $count times';
  }

  @override
  String get logFailureStatsEmpty => 'No download failure records';

  @override
  String get logFailureReasonUnknown => 'Unknown error';

  @override
  String logFailureReasonAuth(Object code) {
    return 'Authorization failed ($code)';
  }

  @override
  String logFailureReasonNotFound(Object code) {
    return 'Resource not found ($code)';
  }

  @override
  String get logFailureReasonRange => 'Range not supported';

  @override
  String logFailureReasonRangeWithCode(Object code) {
    return 'Range not supported ($code)';
  }

  @override
  String logFailureReasonTooManyRequests(Object code) {
    return 'Too many requests ($code)';
  }

  @override
  String logFailureReasonServerError(Object code) {
    return 'Server error ($code)';
  }

  @override
  String logFailureReasonHttpError(Object code) {
    return 'HTTP $code';
  }

  @override
  String get logFailureReasonTimeout => 'Connection timed out';

  @override
  String get logFailureReasonConnection => 'Connection interrupted';

  @override
  String get logFailureReasonDns => 'DNS lookup failed';

  @override
  String get logFailureReasonSsl => 'SSL/Certificate error';

  @override
  String get logFailureReasonChecksum => 'File checksum failed';

  @override
  String get logFailureReasonDisk => 'Disk/Permission error';

  @override
  String get logFailureReasonOther => 'Other error';

  @override
  String logTimeRangeRecentMinutes(Object minutes) {
    return 'Last $minutes minutes';
  }

  @override
  String logTimeRangeRecentHours(Object hours) {
    return 'Last $hours hours';
  }

  @override
  String get logTimeRangeLabel => 'Time range';

  @override
  String get logStatCountUnit => 'items';

  @override
  String logRepeatedCount(Object count) {
    return 'Repeated $count times';
  }

  @override
  String logRepeatedMore(Object count) {
    return '... $count more';
  }

  @override
  String get logContextCopy => 'Copy logs';

  @override
  String logContextRepeated(Object count) {
    return '(Repeated $count times)';
  }

  @override
  String get logContextRemoveBookmark => 'Remove bookmark';

  @override
  String get logContextAddBookmark => 'Add bookmark';

  @override
  String logContextFilterLevel(Object level) {
    return 'Filter: $level';
  }

  @override
  String logContextFilterSource(Object source) {
    return 'Filter: $source';
  }

  @override
  String get logContextCopySingle => 'Copy this entry';

  @override
  String get logFilterLevelTitle => 'Filter log level';

  @override
  String get logFilterAllLabel => 'All';

  @override
  String get logDialogClose => 'Close';

  @override
  String get logSourceFilterTitle => 'Filter log source';

  @override
  String logSourceTotalCount(Object count) {
    return '$count items';
  }

  @override
  String get logSourceCategoryKernel => 'Kernel';

  @override
  String logSourceKernelSubtitle(Object count) {
    return 'Kernel · $count tags';
  }

  @override
  String get logSourceCategoryApp => 'App';

  @override
  String logSourceAppSubtitle(Object count) {
    return 'App · $count tags';
  }

  @override
  String get logSourceCategorySystem => 'System';

  @override
  String logSourceSystemSubtitle(Object count) {
    return 'System / Framework · $count tags';
  }

  @override
  String get logDialogOk => 'OK';

  @override
  String get logDialogCancel => 'Cancel';

  @override
  String get logTimeRangeTitle => 'Time range filter';

  @override
  String get logTimeRangeQuickSelectLabel => 'Quick select:';

  @override
  String get logTimeRangePreset1Hour => 'Last 1 hour';

  @override
  String get logTimeRangePreset30Min => 'Last 30 minutes';

  @override
  String get logTimeRangePreset10Min => 'Last 10 minutes';

  @override
  String get logTimeRangePreset5Min => 'Last 5 minutes';

  @override
  String get logTimeRangeStartLabel => 'Start time:';

  @override
  String get logTimeRangeEndLabel => 'End time:';

  @override
  String get logTimeRangeNotSet => 'Not set';

  @override
  String get logTimeRangeNow => 'Now';

  @override
  String get logDialogClear => 'Clear';

  @override
  String get logDialogApply => 'Apply';

  @override
  String get logRulesDialogTitle => 'Highlight rules';

  @override
  String get logRulesBuiltinTitle => 'Built-in rules';

  @override
  String get logRulesCustomTitle => 'Custom rules';

  @override
  String get logRulesAddButton => 'Add';

  @override
  String get logRulesCustomEmpty => 'No custom rules';

  @override
  String get logRulesLegendTitle => 'Color legend';

  @override
  String get logRulesLegendUrl => 'URL';

  @override
  String get logRulesLegendPath => 'Path';

  @override
  String get logRulesLegendIp => 'IP';

  @override
  String get logRulesLegendNumber => 'Number';

  @override
  String get logRulesLegendError => 'Error';

  @override
  String get logRulesLegendSuccess => 'Success';

  @override
  String get logRulesLegendWarning => 'Warning';

  @override
  String get logRulesLegendHttp => 'HTTP';

  @override
  String get logRulesLegendStep => 'Step';

  @override
  String get logRulesLegendPid => 'PID';

  @override
  String get logRulesLegendKeyValue => 'Key/Value';

  @override
  String get logAddRuleTitle => 'Add custom rule';

  @override
  String get logAddRuleNameLabel => 'Rule name';

  @override
  String get logAddRuleNamePlaceholder => 'e.g. Task ID';

  @override
  String get logAddRulePatternLabel => 'Regex pattern';

  @override
  String get logAddRulePatternPlaceholder => 'e.g. \\b[a-f0-9]+\\b (16 chars)';

  @override
  String get logAddRuleColorLabel => 'Highlight color';

  @override
  String get logAddRuleInvalidTitle => 'Invalid regex';

  @override
  String logAddRuleInvalidMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get logArchiveTitle => 'Archive logs';

  @override
  String get logArchivePrompt => 'Choose archive option:';

  @override
  String get logArchiveExportAll => 'Export all logs';

  @override
  String get logArchiveExportFiltered => 'Export current filter';

  @override
  String get logArchiveExportFull => 'Export FULL LOG';

  @override
  String logArchiveExportBookmarked(Object count) {
    return 'Export bookmarked logs ($count)';
  }

  @override
  String get logClearConfirmTitle => 'Confirm clear';

  @override
  String get logClearConfirmMessage =>
      'Clear all logs? This action cannot be undone.';

  @override
  String get logClearConfirmButton => 'Clear';

  @override
  String get logExportSuccessTitle => 'Export successful';

  @override
  String logExportSavedMessage(Object path) {
    return 'Logs saved to:\\n$path';
  }

  @override
  String get logExportFailedTitle => 'Export failed';

  @override
  String logExportFailedMessage(Object error) {
    return 'Failed to save logs: $error';
  }

  @override
  String logDiagnosticsSavedMessage(Object path) {
    return 'Diagnostics saved to:\\n$path';
  }

  @override
  String logDiagnosticsExportFailedMessage(Object error) {
    return 'Failed to export diagnostics: $error';
  }

  @override
  String logExportFileHeader(Object time) {
    return '# Log Export - $time';
  }

  @override
  String logExportFileTotal(Object count) {
    return '# Total: $count items';
  }

  @override
  String logExportSavedCountMessage(Object count, Object path) {
    return 'Saved $count logs to:\\n$path';
  }

  @override
  String logExportErrorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get logRuleUrl => 'URL';

  @override
  String get logRuleFilePath => 'File path';

  @override
  String get logRuleIpAddress => 'IP address';

  @override
  String get logRuleNumber => 'Number';

  @override
  String get logRuleIdHash => 'ID/Hash';

  @override
  String get logRuleError => 'Error';

  @override
  String get logRuleSuccess => 'Success';

  @override
  String get logRuleWarning => 'Warning';

  @override
  String get logRuleHttpMethod => 'HTTP method';

  @override
  String get logRuleHttpStatus => 'HTTP status';

  @override
  String get logRuleTime => 'Time';

  @override
  String get logRuleStep => 'Step';

  @override
  String get logRulePid => 'PID';

  @override
  String get logRuleKeyValue => 'Key/Value';

  @override
  String get performanceMonitorTitle => 'Performance Monitor';

  @override
  String get performanceMonitorStatusRunning => 'Monitoring...';

  @override
  String get performanceMonitorStatusIdle =>
      'Click start to collect performance data';

  @override
  String get performanceMonitorButtonStop => 'Stop monitoring';

  @override
  String get performanceMonitorButtonStart => 'Start monitoring';

  @override
  String get performanceMonitorRealtimeTitle => 'Realtime';

  @override
  String get performanceMonitorJankBadge => 'JANK';

  @override
  String get performanceMonitorMetricFps => 'FPS';

  @override
  String get performanceMonitorMetricBuild => 'Build';

  @override
  String get performanceMonitorMetricRaster => 'Raster';

  @override
  String get performanceMonitorMetricTotal => 'Total';

  @override
  String get performanceMonitorStatsTitle => 'Summary';

  @override
  String get performanceMonitorStatTotalFrames => 'Total frames';

  @override
  String get performanceMonitorStatJankFrames => 'Jank frames';

  @override
  String get performanceMonitorStatJankRate => 'Jank rate';

  @override
  String get performanceMonitorStatAvgBuildTime => 'Avg Build time';

  @override
  String get performanceMonitorStatAvgRasterTime => 'Avg Raster time';

  @override
  String get performanceMonitorStatAvgTotalTime => 'Avg Total time';

  @override
  String get performanceMonitorStatMaxBuildTime => 'Max Build time';

  @override
  String get performanceMonitorStatMaxRasterTime => 'Max Raster time';

  @override
  String get performanceMonitorStatMaxTotalTime => 'Max Total time';

  @override
  String get performanceMonitorRebuildTitle => 'Widget rebuilds';

  @override
  String get performanceMonitorRebuildTotal => 'Total rebuilds';

  @override
  String get performanceMonitorRebuildTracked => 'Tracked widgets';

  @override
  String get performanceMonitorRebuildTopTitle => 'Top rebuild widgets';

  @override
  String get performanceMonitorRebuildEmpty =>
      'No rebuild data yet\\nCall trackRebuild() in code to track';

  @override
  String performanceMonitorFrameChartTitle(Object count) {
    return 'Frame time chart (last $count frames)';
  }

  @override
  String get performanceMonitorFrameChartEmpty =>
      'No data yet. Start monitoring.';

  @override
  String get performanceMonitorLegendNormal => 'Normal frame';

  @override
  String performanceMonitorLegendJankMs(Object ms) {
    return 'Jank frame (> $ms ms)';
  }

  @override
  String get performanceMonitorLegendFpsThreshold => '60fps threshold';

  @override
  String get performanceMonitorSettingsTitle => 'Render settings';

  @override
  String get performanceMonitorSettingsModeLabel => 'Performance mode';

  @override
  String get performanceMonitorSettingsBlurLabel => 'Blur effect';

  @override
  String get performanceMonitorSettingsBlurStrengthLabel => 'Blur strength';

  @override
  String get performanceMonitorSettingsWindowEffectLabel => 'Window effects';

  @override
  String get performanceMonitorSettingsAcrylicOpacityLabel => 'Acrylic opacity';

  @override
  String get performanceMonitorValueEnabled => 'Enabled';

  @override
  String get performanceMonitorValueDisabled => 'Disabled';

  @override
  String performanceMonitorWindowEffectEnabled(Object mode) {
    return 'Enabled ($mode)';
  }

  @override
  String get performanceMonitorWindowEffectHintEnabled =>
      'Window effects are enabled and may impact performance. If jank is high, disable them in Settings → Appearance → Window effects.';

  @override
  String get performanceMonitorWindowEffectHintDisabled =>
      'Window effects are disabled for best performance. You can enable them in Settings → Appearance → Window effects.';

  @override
  String get performanceMonitorActionExport => 'Export log';

  @override
  String get performanceMonitorActionCopy => 'Copy to clipboard';

  @override
  String get performanceMonitorActionClear => 'Clear data';

  @override
  String get performanceMonitorToastClearedTitle => 'Cleared';

  @override
  String get performanceMonitorToastClearedMessage =>
      'History has been cleared';

  @override
  String get performanceMonitorToastExportSuccessTitle => 'Export successful';

  @override
  String performanceMonitorToastExportSuccessMessage(Object path) {
    return 'Log saved to: $path';
  }

  @override
  String get performanceMonitorToastExportFailedTitle => 'Export failed';

  @override
  String performanceMonitorToastExportFailedMessage(Object error) {
    return '$error';
  }

  @override
  String get performanceMonitorToastCopiedTitle => 'Copied';

  @override
  String get performanceMonitorToastCopiedMessage =>
      'Performance log copied to clipboard';

  @override
  String get performanceMonitorModeQuality => 'Quality';

  @override
  String get performanceMonitorModeBalanced => 'Balanced';

  @override
  String get performanceMonitorModePerformance => 'Performance';

  @override
  String get tagActionLabel => 'Tag';

  @override
  String get tagEditTitle => 'Edit tags';

  @override
  String get tagEditSubtitle => 'Separate tags with commas';

  @override
  String get tagEditPlaceholder => 'tag1, tag2';

  @override
  String get tagFilterTitle => 'Tag filter';

  @override
  String get tagFilterEmpty => 'No tags available';

  @override
  String get tagFilterSubtitle => 'Select a tag to filter:';

  @override
  String get tagFilterClearButton => 'Clear tag filter';

  @override
  String completedBatchActionsLabel(Object count) {
    return 'Batch actions ($count)';
  }

  @override
  String get completedBatchRenameButton => 'Batch rename';

  @override
  String get completedBatchMoveButton => 'Batch move';

  @override
  String get completedBatchMoveSuccessTitle => 'Batch move complete';

  @override
  String completedBatchMoveSuccessMessage(Object count) {
    return 'Moved $count files';
  }

  @override
  String completedBatchMovePartialMessage(Object success, Object failed) {
    return 'Success $success, failed $failed';
  }

  @override
  String get completedBatchRenameTitle => 'Batch rename';

  @override
  String get completedBatchRenameHint =>
      'Apply prefix/suffix to file names in the current list';

  @override
  String get completedBatchRenamePrefixLabel => 'Prefix';

  @override
  String get completedBatchRenamePrefixPlaceholder => 'prefix_';

  @override
  String get completedBatchRenameSuffixLabel => 'Suffix';

  @override
  String get completedBatchRenameSuffixPlaceholder => '_suffix';

  @override
  String get completedBatchRenameEmptyWarningMessage =>
      'Please enter a prefix or suffix';

  @override
  String get completedBatchRenameSuccessTitle => 'Batch rename complete';

  @override
  String completedBatchRenameSuccessMessage(Object count) {
    return 'Renamed $count files';
  }

  @override
  String completedBatchRenamePartialMessage(Object success, Object failed) {
    return 'Success $success, failed $failed';
  }

  @override
  String get settingsClipboardListenerTitle => 'Clipboard listener';

  @override
  String get settingsClipboardListenerSubtitle =>
      'Detect URLs from clipboard and show the add-download dialog';

  @override
  String get settingsClipboardListenerEnabledTitle =>
      'Clipboard listener enabled';

  @override
  String get settingsClipboardListenerEnabledMessage =>
      'URLs copied to clipboard will trigger a download prompt';

  @override
  String get settingsClipboardListenerDisabledTitle =>
      'Clipboard listener disabled';

  @override
  String get settingsClipboardListenerDisabledMessage =>
      'Clipboard URLs will no longer trigger a prompt';

  @override
  String get clipboardListenerMuteSessionButton => 'Mute This Session';

  @override
  String get clipboardListenerSessionMutedTitle => 'Muted for this session';

  @override
  String get clipboardListenerSessionMutedMessage =>
      'Automatic clipboard prompts are paused until the app restarts';

  @override
  String get downloadDuplicateTitle => 'Duplicate download detected';

  @override
  String downloadDuplicateMessage(Object fileName, Object status) {
    return 'A task with the same URL already exists: $fileName ($status). What would you like to do?';
  }

  @override
  String get downloadDuplicateUseExistingButton => 'Use existing';

  @override
  String get downloadDuplicateAddNewButton => 'Add new';

  @override
  String get downloadDuplicateCancelButton => 'Cancel';

  @override
  String get downloadBadgeHostHint => 'Host hint';

  @override
  String get downloadBadgePolicyFallback => 'Fallback';

  @override
  String downloadBadgeConcurrencyCap(Object count) {
    return 'Cap x$count';
  }

  @override
  String get downloadFailureHintAuth =>
      'Check login or add Referer/Cookie; the link may have expired.';

  @override
  String get downloadFailureHintNotFound =>
      'The file may be removed or the link is invalid.';

  @override
  String get downloadFailureHintRange =>
      'Server may not support resume; try single-thread or restart.';

  @override
  String get downloadFailureHintRateLimit =>
      'Too many requests. Try again later.';

  @override
  String get downloadFailureHintServer => 'Server error. Try again later.';

  @override
  String get downloadFailureHintHttp =>
      'HTTP error. Check the URL or permissions.';

  @override
  String get downloadFailureHintTimeout =>
      'Connection timed out. Check network or retry.';

  @override
  String get downloadFailureHintConnection =>
      'Connection dropped. Check network or proxy.';

  @override
  String get downloadFailureHintDns =>
      'DNS lookup failed. Check network or DNS settings.';

  @override
  String get downloadFailureHintSsl =>
      'SSL error. Try another source or adjust certificate settings.';

  @override
  String get downloadFailureHintChecksum =>
      'File may be corrupted. Try re-downloading.';

  @override
  String get downloadFailureHintDisk =>
      'Disk full or permission issue. Check the save location.';

  @override
  String get settingsConflictStrategyTitle => 'Name conflict strategy';

  @override
  String get settingsConflictStrategySubtitle =>
      'How to handle existing files with the same name';

  @override
  String get settingsConflictStrategyIncrement => 'Add (1), (2)...';

  @override
  String get settingsConflictStrategyTimestamp => 'Append timestamp';

  @override
  String get settingsConflictStrategyOverwrite => 'Overwrite existing';
}
