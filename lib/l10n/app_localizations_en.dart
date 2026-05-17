// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Hanabi Download Manager X';

  @override
  String get aboutEasterEggCongrats =>
      'Congratulations on discovering this easter egg!';

  @override
  String get aboutEasterEggTitle => 'This easter egg is useless';

  @override
  String aboutEasterEggMessage(Object appName) {
    return 'But thanks for using $appName! \\nThank you for your support\\nI hope you can give him a Star';
  }

  @override
  String get aboutEasterEggDismiss => 'Pretend not to know';

  @override
  String aboutMadeBy(Object developer) {
    return 'Author $developer';
  }

  @override
  String get aboutEasterEggDialogTitle => 'Hey!';

  @override
  String get aboutPageTitle => 'About';

  @override
  String get aboutSectionAppInfo => 'Application information';

  @override
  String aboutTapHintRemaining(Object count) {
    return 'Click $count more times...';
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
  String get aboutDetailKernelLabel => 'Download Engine';

  @override
  String get aboutDetailUiFrameworkLabel => 'UI framework';

  @override
  String get aboutDetailUiFrameworkValue => 'Fluent UI for Flutter';

  @override
  String get aboutSectionLinks => 'Links';

  @override
  String get aboutLinkOfficialTitle => 'Official website';

  @override
  String get aboutLinkOfficialSubtitle => 'Visit the project homepage';

  @override
  String get aboutLinkGithubTitle => 'GitHub';

  @override
  String get aboutLinkGithubSubtitle => 'View source code and contributions';

  @override
  String get aboutLinkContactTitle => 'Contact us';

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
  String get settingsTabDownload => 'Download';

  @override
  String get settingsTabAppearance => 'Interface';

  @override
  String get settingsTabUpdate => 'Update';

  @override
  String get settingsTabAdvanced => 'Advanced';

  @override
  String get settingsTabDeveloper => 'Developer';

  @override
  String get appearanceThemeSection => 'Theme';

  @override
  String get appearanceThemeModeTitle => 'Theme mode';

  @override
  String get appearanceThemeModeSubtitle =>
      'The main window switches immediately. Tray and popup windows follow the new theme next time they open.';

  @override
  String get appearanceThemeModeSystem => 'Follow system';

  @override
  String get appearanceThemeModeLight => 'Light';

  @override
  String get appearanceThemeModeDark => 'Dark';

  @override
  String get appearanceThemeSavedTitle => 'Theme updated';

  @override
  String appearanceThemeSavedMessage(Object mode) {
    return 'Current theme mode: $mode';
  }

  @override
  String get appearanceClassicControlVisualsTitle => 'Classic control visuals';

  @override
  String get appearanceClassicControlVisualsSubtitle =>
      'Use the older gray control borders in dark mode to reduce the bright Fluent 2 outline.';

  @override
  String get appearanceClassicControlVisualsSavedTitle =>
      'Control visuals updated';

  @override
  String get appearanceClassicControlVisualsEnabledMessage =>
      'Classic control visuals are enabled';

  @override
  String get appearanceClassicControlVisualsDisabledMessage =>
      'Fluent 2 control visuals are enabled';

  @override
  String get appearanceSectionLanguage => 'Language';

  @override
  String get appearanceLanguageTitle => 'Interface language';

  @override
  String get appearanceLanguageSubtitle =>
      'Follow the system by default: the system will automatically select the appropriate interface language for you';

  @override
  String get appearanceLanguageSystem => 'Follow the system';

  @override
  String get appearanceLanguageChinese => 'Chinese';

  @override
  String get appearanceLanguageEnglish => 'English';

  @override
  String get appearanceLanguageSwitchedTitle => 'Language has been switched';

  @override
  String get appearanceLanguageSwitchedSystem =>
      'Will follow the system language';

  @override
  String appearanceLanguageSwitchedTo(Object language) {
    return 'Switched to $language';
  }

  @override
  String get appearanceLanguagePacksTitle => 'Language pack';

  @override
  String appearanceLanguagePacksSubtitle(Object path) {
    return 'Put .json/.arb into $path and click refresh';
  }

  @override
  String get appearanceLanguagePacksRefreshedTitle => 'Language pack refreshed';

  @override
  String appearanceLanguagePacksRefreshedMessage(Object count) {
    return 'Found $count language packs';
  }

  @override
  String get appearanceLanguageRefreshButton => 'Refresh language pack';

  @override
  String get trayMenuShowWindowTitle => 'Show window';

  @override
  String get trayMenuShowWindowSubtitle => 'Open the main interface';

  @override
  String get trayMenuKernelTitle => 'Download kernel';

  @override
  String get trayMenuKernelSubtitleRunning => 'Running';

  @override
  String get trayMenuKernelSubtitleStopped => 'Stopped';

  @override
  String get trayMenuExitTitle => 'Exit app';

  @override
  String get trayMenuExitSubtitle => 'Close all windows';

  @override
  String get exitWithActiveDownloadsTitle =>
      'There is still downloading in progress';

  @override
  String exitWithActiveDownloadsMessage(Object count) {
    return 'There are currently $count download tasks running. Exiting now will interrupt these downloads. Are you sure you want to continue exiting?';
  }

  @override
  String get exitWithActiveDownloadsCancelButton => 'Cancel';

  @override
  String get exitWithActiveDownloadsConfirmButton => 'Exit anyway';

  @override
  String get tempFilesDialogTitle => 'Clean temporary files';

  @override
  String tempFilesDialogScanPath(Object path) {
    return 'Scan path: $path';
  }

  @override
  String get tempFilesStatFiles => 'Number of files';

  @override
  String get tempFilesStatTotalSize => 'Total size';

  @override
  String get tempFilesStatSelected => 'Selected';

  @override
  String get tempFilesSupportedFormats =>
      'Supported formats: .temp, .tmp, .download, .partN (partitioned), .crdownload, .partial, .!ut';

  @override
  String get tempFilesSelectAll => 'Select all';

  @override
  String get tempFilesIncludeTempDirs => 'Contains temporary directory';

  @override
  String get tempFilesSortLabel => 'Sort by:';

  @override
  String get tempFilesSortName => 'Name';

  @override
  String get tempFilesSortSize => 'Size';

  @override
  String get tempFilesSortTime => 'Time';

  @override
  String get tempFilesEmpty => 'Temporary file not found';

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
    return 'Are you sure you want to delete $count temporary files?';
  }

  @override
  String tempFilesDeleteTotalSize(Object size) {
    return 'Total size: $size';
  }

  @override
  String get tempFilesDeleteWarning => 'This operation is irreversible';

  @override
  String get tempFilesCancelButton => 'Cancel';

  @override
  String get tempFilesDeleteButton => 'Delete';

  @override
  String get tempFilesDeleteDoneTitle => 'Deletion completed';

  @override
  String tempFilesDeleteDoneWithFailures(Object success, Object failed) {
    return 'Successfully deleted $success items, failed $failed items';
  }

  @override
  String tempFilesDeleteDoneSuccess(Object success) {
    return 'Successfully deleted $success temporary files';
  }

  @override
  String get homeNavDownloading => 'Download task';

  @override
  String get homeNavCompleted => 'Completed';

  @override
  String get homeNavLog => 'Logs';

  @override
  String get homeNavStatus => 'Status';

  @override
  String get homeNavOnlineStats => 'Online statistics';

  @override
  String get homeNavPerformance => 'Performance monitoring';

  @override
  String get homeNavConnectionDebug => 'Connection debugging';

  @override
  String get homeNavSettings => 'Settings';

  @override
  String get homeNavNotice => 'Notifications';

  @override
  String get homeNavAbout => 'About';

  @override
  String get homeUpdateFoundTitle => 'New version detected';

  @override
  String homeUpdateFoundMessage(Object currentVersion, Object newVersion) {
    return 'This update is $currentVersion -> $newVersion\\nGo to the settings page to update!';
  }

  @override
  String get homeKernelStartingTitle => 'Starting to download kernel...';

  @override
  String get homeKernelStartingHint =>
      'Please wait, this may take a few seconds';

  @override
  String get homeViewLog => 'View log';

  @override
  String get homeRetry => 'Try again';

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
  String get settingsSectionSystem => 'System settings';

  @override
  String get settingsAutoStartTitle => 'Start at login';

  @override
  String get settingsAutoStartSubtitle => 'Run the app when the system starts';

  @override
  String get settingsAutoStartEnabledTitle => 'Startup enabled';

  @override
  String get settingsAutoStartEnabledMessage =>
      'The app will run when the system starts';

  @override
  String get settingsAutoStartDisabledTitle => 'Startup disabled';

  @override
  String get settingsAutoStartDisabledMessage =>
      'The app will not run automatically';

  @override
  String get settingsAutoStartEnableFailed =>
      'Unable to enable auto-start at boot';

  @override
  String get settingsAutoStartDisableFailed =>
      'Unable to turn off auto-start at boot';

  @override
  String get settingsAutoStartFixedTitle => 'Autostart has been fixed';

  @override
  String get settingsAutoStartFixedMessage =>
      'An older startup entry was detected and updated to the current version.';

  @override
  String get settingsSectionBehavior => 'Behavior settings';

  @override
  String get settingsAutoDownloadTitle => 'Auto-start downloads';

  @override
  String get settingsAutoDownloadSubtitle =>
      'New tasks will automatically start downloading';

  @override
  String get settingsAutoDownloadEnabledTitle => 'Auto-start downloads enabled';

  @override
  String get settingsAutoDownloadEnabledMessage =>
      'New tasks will automatically start downloading';

  @override
  String get settingsAutoDownloadDisabledTitle =>
      'Auto-start downloads disabled';

  @override
  String get settingsAutoDownloadDisabledMessage =>
      'New tasks will wait to be started manually';

  @override
  String get settingsPopupWindowTitle => 'Browser download pop-up window';

  @override
  String get settingsPopupWindowSubtitle =>
      'When the browser downloads, it displays an independent popup window and does not open the main window.';

  @override
  String get settingsPopupEnabledTitle => 'Pop-up window is open';

  @override
  String get settingsPopupEnabledMessage =>
      'Browser downloads will open a separate popup window while the main window stays in the background.';

  @override
  String get settingsPopupDisabledTitle => 'Pop-up window has been closed';

  @override
  String get settingsPopupDisabledMessage =>
      'Browser downloads will be added directly to tasks without opening a separate popup window.';

  @override
  String get settingsCompleteNotifyTitle => 'Completion notification';

  @override
  String get settingsCompleteNotifySubtitle =>
      'Notify when download is complete';

  @override
  String get settingsCompleteNotifyEnabledTitle =>
      'Completion notification is on';

  @override
  String get settingsCompleteNotifyEnabledMessage =>
      'A notification will be sent when a download completes';

  @override
  String get settingsCompleteNotifyDisabledTitle =>
      'Completion notification is closed';

  @override
  String get settingsCompleteNotifyDisabledMessage =>
      'No more notifications when download is complete';

  @override
  String get settingsOnlineStatsTitle => 'Participate in online statistics';

  @override
  String get settingsOnlineStatsSubtitle =>
      'Participate in anonymous online population and activity statistics without uploading UA, fingerprints, downloaded content or original local identification';

  @override
  String get settingsOnlineStatsEnabledTitle => 'Online statistics is enabled';

  @override
  String get settingsOnlineStatsEnabledMessage =>
      'Anonymous online heartbeats and anonymous statistical tokens derived by period will be sent, only used for aggregating the number of online people and active deduplication.';

  @override
  String get settingsOnlineStatsDisabledTitle => 'Online statistics disabled';

  @override
  String get settingsOnlineStatsDisabledMessage =>
      'Online heartbeats will stop being sent and the online status will automatically expire within a short period of time.';

  @override
  String get settingsTrayHintTitle => 'Tray tip';

  @override
  String get settingsTrayHintSubtitle => 'Tray prompt shows running status';

  @override
  String get settingsTrayHintEnabledTitle =>
      'Background running prompt has been turned on';

  @override
  String get settingsTrayHintEnabledMessage =>
      'When the window is hidden, the tray icon will say \"Running in the background\"';

  @override
  String get settingsTrayHintDisabledTitle =>
      'Background running prompt has been closed';

  @override
  String get settingsTrayHintDisabledMessage =>
      'The tray icon will always show only the app name';

  @override
  String get settingsCloseBehaviorTitle => 'Close button behavior';

  @override
  String get settingsCloseBehaviorMinimizeLabel => 'Minimize to tray';

  @override
  String get settingsCloseBehaviorExitLabel => 'Exit app';

  @override
  String get settingsCloseBehaviorMinimize =>
      'Minimize to system tray and keep running in the background';

  @override
  String get settingsCloseBehaviorExit => 'Exit the app completely';

  @override
  String get settingsCloseBehaviorUnknown => 'Unknown behavior';

  @override
  String settingsCloseBehaviorSavedMessage(Object behavior) {
    return 'Close button behavior has been set to $behavior';
  }

  @override
  String get settingsSaveSuccessTitle => 'Settings saved';

  @override
  String get settingsSaveFailedTitle => 'Settings failed';

  @override
  String settingsSaveFailedMessage(Object error) {
    return 'Unable to save settings: $error';
  }

  @override
  String get settingsBrowserExtensionPortTitle => 'Browser bridge port';

  @override
  String settingsBrowserExtensionPortSubtitle(Object port) {
    return 'Current local API: http://127.0.0.1:$port | The extension will migrate automatically after changes';
  }

  @override
  String get settingsBrowserExtensionPortChangeButton => 'Change';

  @override
  String get settingsBrowserExtensionPortDialogTitle =>
      'Change browser bridge port';

  @override
  String get settingsBrowserExtensionPortDialogPrompt =>
      'Please enter the local API port used by the browser extension bridge';

  @override
  String get settingsBrowserExtensionPortPlaceholder => '1024-65535';

  @override
  String get settingsBrowserExtensionPortHintBody =>
      'Hanabi will switch the local bridge to the new port immediately and keep the old port as a compatibility endpoint during migration. The browser extension will switch automatically.';

  @override
  String get settingsBrowserExtensionPortInvalidTitle => 'Invalid port';

  @override
  String settingsBrowserExtensionPortInvalidMessage(Object min, Object max) {
    return 'Invalid port number.\nEnter a port between $min and $max.';
  }

  @override
  String settingsBrowserExtensionPortSavedMessage(Object port) {
    return 'Browser bridge port switched to $port. The extension will update automatically.';
  }

  @override
  String settingsBrowserExtensionPortSaveFailedMessage(Object error) {
    return 'Failed to switch browser bridge port: $error';
  }

  @override
  String get settingsDownloadPathSection => 'Download path';

  @override
  String get settingsDownloadPathTitle => 'Save location';

  @override
  String get settingsDownloadPathChangeButton => 'Change';

  @override
  String get settingsDownloadPathDialogTitle => 'Set download path';

  @override
  String get settingsDownloadPathDialogPrompt =>
      'Enter or browse for the download save path:';

  @override
  String get settingsDownloadPathPlaceholder => 'C:\\\\Downloads';

  @override
  String get settingsBrowseButton => 'Browse';

  @override
  String get settingsDownloadPathHintTitle => 'Tip:';

  @override
  String get settingsDownloadPathHintBody =>
      '• You can enter the complete folder path directly\\n• Click the \"Browse\" button to visually select the folder\\n• Example: C:\\\\Users\\\\username\\\\Downloads';

  @override
  String get settingsCancelButton => 'Cancel';

  @override
  String get settingsConfirmButton => 'Sure';

  @override
  String settingsDownloadPathChangedMessage(Object path) {
    return 'The download path has been changed to: $path';
  }

  @override
  String get settingsDownloadPathChangeFailedMessage =>
      'Unable to change download path, please check if the path is valid';

  @override
  String get settingsDownloadConfigSection => 'Download configuration';

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
  String get settingsThreadsTitle => 'Number of threads';

  @override
  String get settingsThreadsSubtitle => 'Number of download threads';

  @override
  String get settingsSegmentsTitle => 'Number of segments';

  @override
  String get settingsSegmentsSubtitle => 'Number of segments per task';

  @override
  String get settingsDynamicSegmentsTitle => 'Dynamic segments';

  @override
  String get settingsDynamicSegmentsSubtitle =>
      'Adjust segment count automatically based on file size';

  @override
  String get settingsDynamicSegmentsEnabledTitle =>
      'Dynamic segmentation is on';

  @override
  String get settingsDynamicSegmentsEnabledMessage =>
      'The number of segments will automatically adjust';

  @override
  String get settingsDynamicSegmentsDisabledTitle =>
      'Dynamic segmentation is turned off';

  @override
  String get settingsDynamicSegmentsDisabledMessage =>
      'The number of segments will remain fixed';

  @override
  String get settingsMaxConcurrentTitle =>
      'Maximum number of simultaneous download tasks';

  @override
  String get settingsMaxConcurrentSubtitle =>
      'Limit the number of concurrent download tasks';

  @override
  String get settingsSegmentSpeedLimitTitle => 'Sectional speed limit';

  @override
  String get settingsSegmentSpeedLimitSubtitle => 'Limit single segment speed';

  @override
  String get settingsGlobalSpeedLimitTitle => 'Global speed limit';

  @override
  String get settingsGlobalSpeedLimitSubtitle =>
      'Limit total download bandwidth';

  @override
  String get settingsHttpVersionTitle => 'HTTP protocol';

  @override
  String get settingsHttpVersionSubtitle =>
      'Select a protocol policy for HTTPS downloads';

  @override
  String get settingsHttpVersionAuto => 'Automatic (HTTP/1.1 preferred)';

  @override
  String get settingsHttpVersionHttp1Only => 'Force HTTP/1.1';

  @override
  String get settingsHttpVersionHttp2Only => 'Force HTTP/2';

  @override
  String get settingsHttpVersionHttp3Only =>
      'Force HTTP/3 (automatic fallback)';

  @override
  String get settingsDownloadCardHttpBadgeTitle =>
      'Download Card Agreement Logo';

  @override
  String get settingsDownloadCardHttpBadgeSubtitle =>
      'Show HTTP version and target connectivity on each download card';

  @override
  String get settingsDefaultUserAgentTitle => 'Default User-Agent';

  @override
  String get settingsDefaultUserAgentSubtitle =>
      'Used when the task does not provide User-Agent';

  @override
  String get settingsDefaultUserAgentPlaceholder =>
      'Enter the default User-Agent';

  @override
  String get settingsUaPresetTitle => 'User-Agent default';

  @override
  String get settingsUaPresetSubtitle =>
      'Quickly switch between browser cloaking, manual input or custom UA packages';

  @override
  String get settingsUaPresetManualOption =>
      'Manual entry (keep current value)';

  @override
  String settingsUaPresetBuiltinOption(Object name) {
    return 'Built-in - $name';
  }

  @override
  String settingsUaPresetCustomOption(Object name) {
    return 'Custom - $name';
  }

  @override
  String get settingsUaCustomCreateTitle => 'Create a custom UA package';

  @override
  String get settingsUaCustomCreateSubtitle =>
      'You can switch to use it at any time after saving.';

  @override
  String get settingsUaCustomNamePlaceholder => 'Name';

  @override
  String get settingsUaCustomValuePlaceholder => 'User-Agent string';

  @override
  String get settingsUaCustomAddButton => 'Add to';

  @override
  String get settingsUaCustomListTitle => 'Custom UA package';

  @override
  String get settingsUaCustomListEmpty => 'No custom UA package yet';

  @override
  String settingsUaCustomListCount(Object count) {
    return 'Total $count, can be applied or deleted';
  }

  @override
  String get settingsUaCustomListHint => 'First create a UA package above';

  @override
  String get settingsUaCustomEnabledButton => 'Enabled';

  @override
  String get settingsUaCustomApplyButton => 'Apply';

  @override
  String get settingsSpeedUnlimited => 'Unlimited';

  @override
  String settingsSpeedTotal(Object speed) {
    return 'Total: $speed KB/s';
  }

  @override
  String settingsPopupSaveFailedMessage(Object error) {
    return 'Unable to save popup settings: $error';
  }

  @override
  String get settingsProxySection => 'Proxy settings';

  @override
  String get settingsProxyEnableTitle => 'Use a proxy';

  @override
  String get settingsProxyEnableSubtitle => 'Enable proxy for downloads';

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
  String get settingsProxyTypeTitle => 'Agent type';

  @override
  String get settingsProxyTypeSubtitle => 'Select agency agreement';

  @override
  String get settingsProxyTypeSystem => 'System proxy';

  @override
  String get settingsProxyTypeHttp => 'HTTP';

  @override
  String get settingsProxyTypeSocks5 => 'SOCKS5';

  @override
  String get settingsProxyServerTitle => 'Proxy server';

  @override
  String get settingsProxyServerSubtitle => 'Server address and port';

  @override
  String get settingsProxyHostPlaceholder => 'Proxy address (eg: 127.0.0.1)';

  @override
  String get settingsProxyAuthTitle => 'Agency certification';

  @override
  String get settingsProxyAuthSubtitle => 'Username and password required';

  @override
  String get settingsProxyUsernameTitle => 'Username';

  @override
  String get settingsProxyUsernameSubtitle => 'Agent account username';

  @override
  String get settingsProxyUsernamePlaceholder => 'Username';

  @override
  String get settingsProxyPasswordTitle => 'Password';

  @override
  String get settingsProxyPasswordSubtitle => 'Agent account password';

  @override
  String get settingsProxyPasswordPlaceholder => 'Password';

  @override
  String get settingsProxyTipsTitle => 'Agent configuration tips';

  @override
  String get settingsProxyTipsSystem =>
      '• Automatically uses system configured proxy settings \n • Supports Windows, macOS and Linux system proxies \n • Once configured will be applied to all new download tasks \n • In-progress downloads will not be affected';

  @override
  String get settingsProxyTipsHttp =>
      '• Use HTTP/HTTPS proxy protocol \n • Once configured, it will be applied to all new download tasks \n • Ongoing downloads will not be affected \n • Support username and password authentication';

  @override
  String get settingsProxyTipsSocks5 =>
      '• Uses SOCKS5 proxy protocol \n • Requires installation of aiohttp-socks library support \n • Once configured will be applied to all new download tasks \n • Ongoing downloads will not be affected';

  @override
  String get settingsProxyTipsDefault =>
      '• Supports system proxies, HTTP/HTTPS and SOCKS5 proxies \n • Once configured will be applied to all new download tasks \n • In-progress downloads will not be affected';

  @override
  String get settingsProxyTestButton => 'Test connection';

  @override
  String get settingsProxyTestingTitle => 'Testing...';

  @override
  String get settingsProxyTestingMessage => 'Please wait';

  @override
  String get settingsProxyTestSuccessTitle => 'Connection successful';

  @override
  String get settingsProxyTestSuccessMessage =>
      'Proxy server connection is working.';

  @override
  String get settingsProxyTestFailedTitle => 'Connection failed';

  @override
  String get settingsProxyTestFailedMessage =>
      'Unable to connect to proxy server, please check configuration';

  @override
  String get settingsProxyTestErrorTitle => 'Test failed';

  @override
  String settingsProxyTestErrorMessage(Object error) {
    return 'Proxy connection test failed: $error';
  }

  @override
  String get settingsProxyErrorTitle => 'Configuration error';

  @override
  String get settingsProxyErrorMessage =>
      'Please enter the proxy server address first';

  @override
  String get settingsKernelSection => 'Download kernel';

  @override
  String get settingsKernelCurrentTitle => 'Current kernel';

  @override
  String get settingsKernelOnline => 'Online';

  @override
  String get settingsKernelOffline => 'Offline';

  @override
  String get settingsKernelNsfxTitle => 'NSFX';

  @override
  String get settingsKernelNsfxSubtitle => 'Switch to new kernel';

  @override
  String get settingsKernelNsfxHint =>
      'NSFX Kernel: Efficient | Simple | New ideas';

  @override
  String get settingsKernelSwitchedTitle => 'Kernel switched';

  @override
  String settingsKernelSwitchedMessage(Object kernelName) {
    return 'Currently using: $kernelName';
  }

  @override
  String get settingsKernelSwitchFailedTitle => 'Switch failed';

  @override
  String get settingsKernelSwitchFailedNewMessage =>
      'Unable to start the new engine. Try again later.';

  @override
  String get settingsStatusTitle => 'System status';

  @override
  String get settingsStatusKernelNsfx => 'NSFX Kernel';

  @override
  String get settingsStatusBrowserExtension => 'Browser Extension';

  @override
  String get settingsModeDescriptionAuto =>
      'Dynamic segments, automatically optimized by file size (recommended)';

  @override
  String get settingsModeDescriptionThreadsOnly =>
      'Manually set the number of threads and automatically calculate the number of segments';

  @override
  String get settingsModeDescriptionSegmentsOnly =>
      'Manually set the number of segments and automatically calculate the number of threads';

  @override
  String get settingsModeDescriptionManual =>
      'Full manual control for advanced users';

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
      'Developer mode is enabled, please switch to the \"Developer\" tab for detailed configuration';

  @override
  String get settingsDeveloperModeEnabledTitle => 'Developer mode is on';

  @override
  String get settingsDeveloperModeEnabledMessage =>
      'Advanced debugging enabled';

  @override
  String get settingsDeveloperModeDisabledTitle =>
      'Developer mode is turned off';

  @override
  String get settingsDeveloperModeDisabledMessage =>
      'Advanced debugging features disabled';

  @override
  String get settingsDeveloperPageVisibilityTitle =>
      'Debug page display settings';

  @override
  String get settingsDeveloperShowLogTitle => 'Show log page';

  @override
  String get settingsDeveloperShowLogSubtitle =>
      'Show log viewer in navigation bar';

  @override
  String get settingsDeveloperShowStatusTitle => 'Show status page';

  @override
  String get settingsDeveloperShowStatusSubtitle =>
      'Display system status monitoring in the navigation bar';

  @override
  String get settingsDeveloperShowOnlineStatsTitle =>
      'Show online statistics page';

  @override
  String get settingsDeveloperShowOnlineStatsSubtitle =>
      'Display online user statistics in the navigation bar';

  @override
  String get settingsDeveloperShowConnectionDebugTitle =>
      'Show connection debugging page';

  @override
  String get settingsDeveloperShowConnectionDebugSubtitle =>
      'Show connection diagnostic tool in navigation bar';

  @override
  String get settingsDeveloperPageHint =>
      'The debugging page will occupy system resources. It is recommended to enable it only when needed.';

  @override
  String get settingsDangerCleanTempTitle => 'Clean temporary files';

  @override
  String get settingsDangerCleanTempSubtitle =>
      'Scan and delete temporary .temp files in the download directory';

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
      'Are you sure you want to clear all download tasks and history? This operation is irreversible.';

  @override
  String get settingsDangerConfirmButton => 'Confirm clear';

  @override
  String get settingsDangerClearingTitle => 'Clearing...';

  @override
  String get settingsDangerClearingMessage => 'Please wait';

  @override
  String get settingsDangerClearedTitle => 'Cleared';

  @override
  String get settingsDangerClearedMessage =>
      'All download tasks and history cleared';

  @override
  String get settingsDangerClearFailedTitle => 'Clear failed';

  @override
  String get settingsDangerClearFailedMessage =>
      'Unable to clear data. Make sure the download engine is running.';

  @override
  String get settingsUserLoading => 'Getting...';

  @override
  String get settingsUserLoadFailed => 'Failed to obtain';

  @override
  String get settingsUserUnknown => 'Unknown user';

  @override
  String get appearanceWindowSizeSection => 'Window size';

  @override
  String get appearanceWindowRememberTitle => 'Remember window size';

  @override
  String get appearanceWindowRememberSubtitleOn =>
      'Start using the last window size when it was closed';

  @override
  String get appearanceWindowRememberSubtitleOff =>
      'Use default window size on startup';

  @override
  String get appearanceWindowDefaultWidthTitle => 'Default window width';

  @override
  String appearanceWindowDefaultWidthSubtitle(Object max) {
    return 'Start default width (600-$max)';
  }

  @override
  String get appearanceWindowDefaultHeightTitle => 'Default window height';

  @override
  String appearanceWindowDefaultHeightSubtitle(Object max) {
    return 'Start default height (400-$max)';
  }

  @override
  String get appearanceWindowSaveTitle => 'Saved';

  @override
  String appearanceWindowSaveMessage(Object width, Object height) {
    return 'Current window size has been set to default ($width×$height)';
  }

  @override
  String appearanceWindowSaveButton(Object width, Object height) {
    return 'Use current size ($width×$height)';
  }

  @override
  String get appearanceWindowResetTitle => 'Reset';

  @override
  String get appearanceWindowResetMessage =>
      'Default window size reset to 889×586';

  @override
  String get appearanceWindowResetButton => 'Reset to default';

  @override
  String get appearanceWindowApplyTitle => 'Applied';

  @override
  String appearanceWindowApplyMessage(Object width, Object height) {
    return 'Window resized to $width×$height';
  }

  @override
  String appearanceWindowApplyButton(Object width, Object height) {
    return 'Apply the default size immediately ($width×$height)';
  }

  @override
  String get appearanceWindowRememberHintOn =>
      'Memory mode is currently enabled, the app will remember the window size when it was last closed';

  @override
  String get appearanceWindowRememberHintOff =>
      'Default size mode is enabled, the app will use the set dimensions';

  @override
  String get appearanceUiScaleSection => 'UI scaling';

  @override
  String get appearanceUiScaleTitle => 'Interface scaling';

  @override
  String get appearanceUiScaleSubtitle =>
      'Adjust high-resolution screen UI scaling (50%-200%)';

  @override
  String get appearanceUiScaleResetTitle => 'Reset';

  @override
  String get appearanceUiScaleResetMessage =>
      'UI scaling has been reset to 100%';

  @override
  String get appearanceUiScaleResetButton => 'Reset to 100%';

  @override
  String get appearanceUiScaleApplyTitle => 'Applied';

  @override
  String get appearanceUiScaleApplyMessage =>
      'UI scaling set to 125% (4K recommended)';

  @override
  String get appearanceUiScale4kButton => '4K recommended (125%)';

  @override
  String get appearanceUiScaleHint =>
      'Adjust this setting to make your app appear clearer on high-resolution screens. 4K screen recommended 125%-150%';

  @override
  String get appearanceFontSection => 'Fonts';

  @override
  String get appearanceFontTitle => 'Font';

  @override
  String get appearanceFontSystemSubtitle => 'Use system default font';

  @override
  String appearanceFontCurrentSubtitle(Object font) {
    return 'Current font: $font';
  }

  @override
  String get appearanceFontSystemLabel => 'System';

  @override
  String get appearanceFontImportButton => 'Import fonts';

  @override
  String get appearanceFontDeleteButton => 'Delete current font';

  @override
  String get appearanceFontHint =>
      'Supports importing font files in .ttf and .otf formats';

  @override
  String get appearanceFontChangedTitle => 'Font changed';

  @override
  String get appearanceFontChangedMessage => 'Font has been applied';

  @override
  String get appearanceFontImportDialogTitle => 'Select font file';

  @override
  String get appearanceFontImportingTitle => 'Importing fonts...';

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
      'Unable to import font file, please check the format';

  @override
  String appearanceFontImportFailedWithErrorMessage(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get appearanceFontDeleteConfirmTitle => 'Confirm deletion';

  @override
  String appearanceFontDeleteConfirmMessage(Object fontName) {
    return 'Are you sure you want to delete the font \"$fontName\"?';
  }

  @override
  String get appearanceFontDeleteCancelButton => 'Cancel';

  @override
  String get appearanceFontDeleteConfirmButton => 'Delete';

  @override
  String get appearanceFontDeleteSuccessTitle => 'Delete successfully';

  @override
  String get appearanceFontDeleteSuccessMessage => 'Font removed';

  @override
  String get appearanceFontDeleteFailedTitle => 'Delete failed';

  @override
  String get appearanceFontDeleteFailedMessage => 'Unable to delete font';

  @override
  String get appearanceFontPickerTitle => 'Select font';

  @override
  String get appearanceFontPickerSearchPlaceholder => 'Search fonts...';

  @override
  String appearanceFontPickerCount(Object count) {
    return 'Total $count fonts';
  }

  @override
  String get appearanceFontPickerFilteredLabel => '(filtered)';

  @override
  String get appearanceFontPickerEmpty => 'No matching font found';

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
      'Window effects are turned off (performance mode)';

  @override
  String get appearanceWindowEffectsEnabledTitle =>
      'Window effects are enabled';

  @override
  String get appearanceWindowEffectsDisabledTitle =>
      'Window effects are turned off';

  @override
  String get appearanceWindowEffectsEnabledMessage => 'Window effect is on';

  @override
  String get appearanceWindowEffectsDisabledMessage =>
      'Switched to solid color background to improve performance';

  @override
  String get appearanceWindowEffectsTypeTitle => 'Effect type';

  @override
  String get appearanceWindowEffectSwitchedTitle =>
      'The effect has been switched';

  @override
  String get appearanceWindowEffectAcrylic => 'Acrylic';

  @override
  String get appearanceWindowEffectBlur => 'Blur';

  @override
  String get appearanceWindowEffectMica => 'Mica';

  @override
  String get appearanceWindowEffectMicaAlt => 'Mica Alt';

  @override
  String get appearanceWindowEffectsAcrylicOpacityTitle =>
      'Acrylic transparency';

  @override
  String get appearanceWindowEffectsAcrylicOpacityHint =>
      'Adjust background opacity (0-255, the smaller the value, the more transparent)';

  @override
  String get appearanceWindowEffectsAcrylicOpacityMicaHint =>
      'Mica effect does not support adjusting transparency';

  @override
  String get appearanceWindowEffectsDragSuspendTitle =>
      'Disable effects while dragging';

  @override
  String get appearanceWindowEffectsDragSuspendEnabledSubtitle =>
      'Temporarily disable special effects when dragging the window to ensure smooth dragging';

  @override
  String get appearanceWindowEffectsDragSuspendDisabledSubtitle =>
      'Maintain special effects when dragging (Win10 may freeze)';

  @override
  String get appearanceWindowEffectsRoundedCornersTitle =>
      'Rounded window corners';

  @override
  String get appearanceWindowEffectsRoundedCornersEnabledSubtitle =>
      'Enable window rounded corner cropping (Win10 and Win11 Acrylic/Blur mode will use custom cropping)';

  @override
  String get appearanceWindowEffectsRoundedCornersDisabledSubtitle =>
      'Use right-angled window edges';

  @override
  String get appearanceWindowEffectsMicaHint =>
      'The Mica effect is only available on Windows 11 and automatically adopts the system theme color';

  @override
  String get appearanceWindowEffectsAcrylicHint =>
      'Acrylic effects will consume additional GPU resources. If you feel stuck, you can turn off this option.';

  @override
  String get appearanceWindowEffectsDisabledHint =>
      'Special effects turned off for best performance';

  @override
  String get appearanceEffectNone => 'No effect';

  @override
  String get appearanceEffectBlur => 'Blur Effect - Simple background blur';

  @override
  String get appearanceEffectAcrylic =>
      'Acrylic Effect - Semi-Transparent Blurred Background';

  @override
  String get appearanceEffectMica =>
      'Mica Effect - Windows 11 native mica effect';

  @override
  String get appearanceEffectMicaAlt =>
      'Mica Alt Effect - Windows 11 Temporary Window Mica Effect';

  @override
  String get appearanceEffectUnknown => 'Unknown effect';

  @override
  String get appearanceSidebarSection => 'Sidebar';

  @override
  String get appearanceSidebarDefaultTitle => 'Default expanded state';

  @override
  String get appearanceSidebarDefaultSubtitle =>
      'The default state of the sidebar at startup';

  @override
  String get appearanceSidebarExpandedLabel => 'Expand';

  @override
  String get appearanceSidebarCollapsedLabel => 'Collapsed';

  @override
  String get appearanceSidebarSavedTitle => 'Saved';

  @override
  String appearanceSidebarSavedMessage(Object state) {
    return 'The sidebar default state is set to $state';
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
  String get appearanceNotificationSchemeLight => 'Light colors';

  @override
  String get appearanceNotificationSchemeDark => 'Dark colors';

  @override
  String get appearanceNotificationSchemeFluent2 =>
      'Fluent 2 color series (recommended)';

  @override
  String get appearanceNotificationSchemeUnknown => 'Unknown';

  @override
  String get appearanceNotificationSchemeDefaultOption => 'Dark';

  @override
  String get appearanceNotificationSchemeLightOption => 'Light';

  @override
  String get appearanceNotificationSchemeDarkOption => 'Dark';

  @override
  String get appearanceNotificationSchemeFluent2Option => 'Fluent 2';

  @override
  String get appearanceNotificationPositionTitle => 'Display position';

  @override
  String get appearanceNotificationPositionTopRight =>
      'Top right, below the title bar';

  @override
  String get appearanceNotificationPositionBottomRight => 'Bottom right';

  @override
  String get appearanceNotificationPositionUnknown => 'Unknown';

  @override
  String get appearanceNotificationPositionTopRightOption => 'Top right';

  @override
  String get appearanceNotificationPositionBottomRightOption => 'Bottom right';

  @override
  String get appearanceNotificationPerformanceTitle =>
      'Rendering performance mode';

  @override
  String get appearanceNotificationPerformanceOptionPerformance =>
      'Performance';

  @override
  String get appearanceNotificationPerformanceOptionBalanced => 'Balanced';

  @override
  String get appearanceNotificationPerformanceOptionQuality => 'Quality';

  @override
  String get appearanceNotificationPerformanceHint =>
      'The frosted glass effect will affect the smoothness of the animation. If you feel stuck, it is recommended to select \"Performance Priority\" mode';

  @override
  String get appearanceNotificationPreviewButtonTitle => 'Preview notification';

  @override
  String get appearanceNotificationPreviewButtonSubtitle =>
      'Click to preview the current color scheme';

  @override
  String get appearanceNotificationPreviewButton => 'Preview';

  @override
  String get appearanceNotificationPreviewTitle => 'Color preview';

  @override
  String get appearanceNotificationPreviewSuccessTitle =>
      'Success notification';

  @override
  String get appearanceNotificationPreviewSuccessMessage =>
      'Operation completed successfully';

  @override
  String get appearanceNotificationPreviewWarningTitle =>
      'Warning notification';

  @override
  String get appearanceNotificationPreviewWarningMessage =>
      'Please note the impact of this operation';

  @override
  String get appearanceNotificationPreviewErrorTitle => 'Error notification';

  @override
  String get appearanceNotificationPreviewErrorMessage =>
      'Operation failed, please try again';

  @override
  String get appearanceNotificationPreviewInfoTitle =>
      'Information notification';

  @override
  String get appearanceNotificationPreviewInfoMessage =>
      'This is a prompt message';

  @override
  String get appearanceNotificationTestTitle => 'Test notification';

  @override
  String get appearanceNotificationTestMessage => 'This is a test notification';

  @override
  String get appearancePerformanceModePerformance =>
      'Performance first (frost-free glass, recommended)';

  @override
  String get appearancePerformanceModeBalanced =>
      'Balanced (lightly frosted glass)';

  @override
  String get appearancePerformanceModeQuality =>
      'High quality (complete frosted glass effect)';

  @override
  String get appearancePerformanceModeUnknown => 'Unknown';

  @override
  String get appearanceSegmentsModeTitle => 'Segmented progress display mode';

  @override
  String get appearanceSegmentsModeNoneOption => 'Combined';

  @override
  String get appearanceSegmentsModeMergedOption => 'Merged bar';

  @override
  String get appearanceSegmentsModeListOption => 'Segmented list';

  @override
  String get appearanceSegmentsModeNoneDescription =>
      'Simple mode: do not display segmentation information';

  @override
  String get appearanceSegmentsModeMergedDescription =>
      'Merge mode: All segments are merged and displayed in a progress bar';

  @override
  String get appearanceSegmentsModeListDescription =>
      'List mode: Each segment is displayed on a separate line';

  @override
  String get appearanceSegmentsDefaultExpandedTitle =>
      'Expand segment information by default';

  @override
  String get appearanceSegmentsDefaultExpandedSubtitle =>
      'Expand to show segment details by default';

  @override
  String get appearanceSegmentsMaxVisibleTitle =>
      'The number of segments is displayed by default';

  @override
  String get appearanceSegmentsMaxVisibleSubtitle =>
      'Show number of segments when expanded (1-32)';

  @override
  String get appearanceDownloadListSection => 'Download list display';

  @override
  String get appearanceSpeedChartTitle => 'Speed curve background';

  @override
  String get appearanceSpeedChartSubtitle =>
      'Display real-time speed curve on download card';

  @override
  String get appearanceChartFrostTitle => 'Frosted Curve';

  @override
  String get appearanceChartFrostSubtitle =>
      'Overlay a frosted glass effect above the curve';

  @override
  String get appearanceChartPositionTitle => 'Curve position';

  @override
  String get appearanceChartPositionSubtitle =>
      'Adjust the height of the curve in the card';

  @override
  String get appearanceChartPositionLow => 'Low';

  @override
  String get appearanceChartPositionMid => 'Middle';

  @override
  String get appearanceChartPositionHigh => 'High';

  @override
  String get appearanceChartColorTitle => 'Curve color';

  @override
  String get appearanceChartColorSubtitle =>
      'Customize the color of the speed curve';

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
  String get developerSectionDebugTools => 'Debugging tools';

  @override
  String get developerSectionTestTools => 'Test tools';

  @override
  String get developerModeEnabledSubtitle => 'Debugging enabled';

  @override
  String get developerModeDisabledSubtitle =>
      'Enables access to debugging tools';

  @override
  String get developerToolLogTitle => 'Log viewer';

  @override
  String get developerToolLogSubtitle => 'View running log';

  @override
  String get developerToolLogShownTitle => 'Log viewer is shown';

  @override
  String get developerToolLogShownMessage =>
      'The log page has been displayed in the navigation bar';

  @override
  String get developerToolLogHiddenTitle => 'Log page has been hidden';

  @override
  String get developerToolLogHiddenMessage =>
      'Log page removed from navigation bar';

  @override
  String get developerToolFullLogTitle => 'FULL LOG switch';

  @override
  String get developerToolFullLogSubtitle =>
      'Display FULL LOG view switch on log page';

  @override
  String get developerToolFullLogShownTitle => 'FULL LOG toggle is shown';

  @override
  String get developerToolFullLogShownMessage =>
      'FULL LOG view switch has been displayed on the log page';

  @override
  String get developerToolFullLogHiddenTitle => 'FULL LOG toggle hidden';

  @override
  String get developerToolFullLogHiddenMessage =>
      'FULL LOG view switch has been hidden on the log page';

  @override
  String get developerToolStatusTitle => 'System status';

  @override
  String get developerToolStatusSubtitle => 'Kernel and extension status';

  @override
  String get developerToolStatusShownTitle => 'System status is shown';

  @override
  String get developerToolStatusShownMessage =>
      'The status page is displayed in the navigation bar';

  @override
  String get developerToolStatusHiddenTitle => 'System status is hidden';

  @override
  String get developerToolStatusHiddenMessage =>
      'Status page removed from navigation bar';

  @override
  String get developerToolOnlineStatsTitle => 'Online statistics';

  @override
  String get developerToolOnlineStatsSubtitle => 'Online user data';

  @override
  String get developerToolOnlineStatsShownTitle =>
      'Online statistics are shown';

  @override
  String get developerToolOnlineStatsShownMessage =>
      'The online statistics page has been displayed in the navigation bar';

  @override
  String get developerToolOnlineStatsHiddenTitle =>
      'Online statistics are hidden';

  @override
  String get developerToolOnlineStatsHiddenMessage =>
      'The online statistics page has been removed from the navigation bar';

  @override
  String get developerToolWebCheckTitle => 'Web detection';

  @override
  String get developerToolWebCheckSubtitle => 'Website diagnostics';

  @override
  String get developerToolWebCheckShownTitle => 'Web detection shown';

  @override
  String get developerToolWebCheckShownMessage =>
      'The Web detection page is displayed in the navigation bar';

  @override
  String get developerToolWebCheckHiddenTitle => 'Web detection is hidden';

  @override
  String get developerToolWebCheckHiddenMessage =>
      'Web detection page removed from navigation bar';

  @override
  String get developerToolPerformanceTitle => 'Performance monitoring';

  @override
  String get developerToolPerformanceSubtitle => 'FPS and Rendering';

  @override
  String get developerToolPerformanceShownTitle =>
      'Performance monitoring is shown';

  @override
  String get developerToolPerformanceShownMessage =>
      'The performance monitoring page has been displayed in the navigation bar';

  @override
  String get developerToolPerformanceHiddenTitle =>
      'Performance monitoring is hidden';

  @override
  String get developerToolPerformanceHiddenMessage =>
      'The performance monitoring page has been removed from the navigation bar';

  @override
  String get developerToolConnectionDebugTitle => 'Connection debugging';

  @override
  String get developerToolConnectionDebugSubtitle =>
      'Network connectivity diagnostics';

  @override
  String get developerToolConnectionDebugShownTitle =>
      'Connection debugging is shown';

  @override
  String get developerToolConnectionDebugShownMessage =>
      'The connection debugging page has been displayed in the navigation bar';

  @override
  String get developerToolConnectionDebugHiddenTitle =>
      'Connection debugging is hidden';

  @override
  String get developerToolConnectionDebugHiddenMessage =>
      'The connection debug page has been removed from the navigation bar';

  @override
  String get connectionDebugTitle => 'Connection debugging';

  @override
  String get connectionDebugTestTitle => 'Test download connection';

  @override
  String get connectionDebugTestSubtitle =>
      'Enter the download link to test the connectivity, proxy status, and transmission capabilities from the local machine to the server.';

  @override
  String get connectionDebugTesting => 'Testing...';

  @override
  String get connectionDebugStartTest => 'Start testing';

  @override
  String connectionDebugResults(int count) {
    return 'Test results ($count)';
  }

  @override
  String get connectionDebugSuccess => 'Connection successful';

  @override
  String get connectionDebugFailed => 'Connection failed';

  @override
  String get connectionDebugLocalHost => 'Local host';

  @override
  String get connectionDebugProxy => 'Proxy';

  @override
  String get connectionDebugUnknown => 'Unknown';

  @override
  String get connectionDebugReceived => 'Received';

  @override
  String get connectionDebugFileSize => 'File size';

  @override
  String get connectionDebugRangeSupported => 'Supported';

  @override
  String get connectionDebugRangeNotSupported => 'Not supported';

  @override
  String get connectionDebugStrategyTitle => 'Site policy cache';

  @override
  String get connectionDebugStrategySubtitle =>
      'Observe the protocol degradation and concurrency limit learned by each host due to historical download failures';

  @override
  String get connectionDebugStrategyRefresh => 'Refresh';

  @override
  String get connectionDebugStrategyClear => 'Clear cache';

  @override
  String get connectionDebugStrategyEmpty =>
      'There is currently no site policy cache. Once a host triggers protocol rollback or concurrent convergence, it will appear here.';

  @override
  String connectionDebugStrategyCount(Object count) {
    return 'Total $count site policies';
  }

  @override
  String get connectionDebugStrategyPolicy => 'Protocol';

  @override
  String get connectionDebugStrategyConcurrency => 'Concurrency';

  @override
  String get connectionDebugStrategyTtl => 'Time left';

  @override
  String get connectionDebugStrategyExpired => 'Expired';

  @override
  String get developerTestNotificationTitle => 'Notification test';

  @override
  String get developerTestNotificationTitlePlaceholder => 'Title';

  @override
  String get developerTestNotificationMessagePlaceholder =>
      'Content (optional)';

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
  String get developerTestPopupTitle => 'Pop-up window test';

  @override
  String get developerTestPopupButton => 'Test the new download box';

  @override
  String get developerTestPopupTestingLabel => 'Under test';

  @override
  String get developerTestPopupHint =>
      'The current version will bring up the main window and display the new download dialog box';

  @override
  String developerTestPopupResultSuccess(Object time) {
    return 'Success · $time![';
  }

  @override
  String get developerTestPopupResultFailed => 'Failed';

  @override
  String get developerOpenL10nFolderTitle => 'Language pack folder';

  @override
  String get developerOpenL10nFolderSubtitle =>
      'Open the l10n folder in a file manager';

  @override
  String get developerOpenL10nFolderSuccessTitle => 'Folder opened';

  @override
  String get developerOpenL10nFolderSuccessMessage =>
      'Language pack folder opened in file manager';

  @override
  String get developerOpenL10nFolderFailedTitle => 'Open failed';

  @override
  String developerOpenL10nFolderFailedMessage(Object error) {
    return 'Unable to open folder: $error';
  }

  @override
  String get updateCurrentVersionTitle => 'Current version';

  @override
  String get updateChangelogTitle => 'Change log';

  @override
  String get updateChangelogViewFullButton => 'View full changelog';

  @override
  String updateChangelogDialogTitle(Object version) {
    return 'v$version Changelog';
  }

  @override
  String get updateCheckTitle => 'Check for updates';

  @override
  String get updateStartButton => 'Start updating';

  @override
  String get updateCheckAgainButton => 'Check again';

  @override
  String get updateCheckingStatus => 'Checking for updates...';

  @override
  String get updateCheckFailedTitle => 'Check for updates failed';

  @override
  String get updateLatestTitle => 'Already the latest version';

  @override
  String get updateLatestSubtitle => 'Currently the latest version';

  @override
  String get updateInitialHint =>
      'Click the \"Recheck\" button to check for the latest version';

  @override
  String get updateUnreleasedTitle => 'Unreleased version';

  @override
  String updateUnreleasedSubtitle(Object version) {
    return 'Current version v$version | The current version number does not exist, maybe it is a special version or development version';
  }

  @override
  String get updateConfirmTitle => 'Confirm update';

  @override
  String get updateConfirmMessage =>
      'The new version is ready. The app will close so installation can proceed normally.';

  @override
  String updateConfirmDetails(Object newVersion, Object currentVersion,
      Object change, Object currentChannel, Object targetChannel) {
    return 'New version: $newVersion\nCurrent version: $currentVersion\nChange: $change\nChannel: $currentChannel -> $targetChannel\nReady to update?';
  }

  @override
  String get updateConfirmCancelButton => 'Cancel';

  @override
  String get updateConfirmProceedButton => 'Confirm update';

  @override
  String get updateUnknownVersion => 'Unknown';

  @override
  String get updateUnknownChannel => 'Unknown';

  @override
  String get updateLauncherFailedTitle => 'Failed to start updater';

  @override
  String get updateLauncherFailedMessage =>
      'Unable to start updater\nTroubleshooting steps:\n • Check whether HanabiUpdater.exe has been deleted or moved\n • Confirm that the installation package is complete\n • Try running as administrator\nIf it still fails, please download and install it manually.';

  @override
  String get updateLauncherFailedCloseButton => 'Close';

  @override
  String get updateLauncherFailedManualDownloadButton => 'Manual download';

  @override
  String get updateAvailableTitle => 'Discover updates';

  @override
  String get updateAvailableChangelogTitle => 'Update content';

  @override
  String get updateSettingsTitle => 'Update settings';

  @override
  String get updateDotNetMissingSubtitle =>
      'Not installed - recommended to use the automatic updater';

  @override
  String get updateDotNetDownloadButton => 'Download';

  @override
  String get updateDotNetInstalledSubtitle => 'Installed - Updater available';

  @override
  String get updateDotNetRecheckButton => 'Retest';

  @override
  String get updateDotNetRecommendTitle =>
      'It is recommended to install .NET 8';

  @override
  String get updateDotNetRecommendSubtitle =>
      'Automatically update using the updater after installing .NET 8 Desktop Runtime';

  @override
  String get updateDotNetRecommendButton => 'Download .NET 8';

  @override
  String get updateChannelTitle => 'Current channel';

  @override
  String get updateChannelAlpha => 'Alpha (Preview)';

  @override
  String get updateChannelRelease => 'Release (stable version)';

  @override
  String get updateIntervalTitle => 'Automatically check for updates';

  @override
  String get updateIntervalSubtitle => 'Set how often to check for updates';

  @override
  String get updateIntervalStartup => 'Only on startup';

  @override
  String get updateIntervalHourly => 'Hourly';

  @override
  String get updateIntervalDaily => 'Daily';

  @override
  String get updateIntervalWeekly => 'Weekly';

  @override
  String get updateIntervalNever => 'Never';

  @override
  String get updateAllowAlphaTitle => 'Receive Alpha updates';

  @override
  String get updateAllowAlphaSubtitle =>
      'Allow receiving the latest test build (may be unstable)';

  @override
  String updateLastCheckLabel(Object time) {
    return 'Last check: $time';
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
  String get settingsDangerZoneTitle => 'Danger area';

  @override
  String get popupDownloadTitle => 'New download';

  @override
  String get popupDownloadLinkLabel => 'Download link';

  @override
  String get popupDownloadLinkPlaceholder => 'HTTP/HTTPS link';

  @override
  String get popupDownloadFileNameLabel => 'File name';

  @override
  String get popupDownloadFileNamePlaceholder => 'Save as filename';

  @override
  String get popupDownloadSavePathLabel => 'Save to';

  @override
  String get popupDownloadSavePathPlaceholder => 'Download catalog';

  @override
  String get popupDownloadAutoStart => 'Start downloading now';

  @override
  String get popupDownloadFeatureHint =>
      'Supports multi-threading, breakpoint resume and speed limit';

  @override
  String get popupDownloadCancel => 'Cancel';

  @override
  String get popupDownloadAdding => 'Adding...';

  @override
  String get popupDownloadStart => 'Start downloading';

  @override
  String get popupDownloadErrorMissingInfo =>
      'Please fill in complete information';

  @override
  String get popupDownloadErrorInvalidUrl =>
      'Please enter a valid download link';

  @override
  String popupDownloadErrorAddFailed(Object error) {
    return 'Failed to add task: $error';
  }

  @override
  String get popupDownloadErrorTitle => 'Error';

  @override
  String get popupDownloadErrorConfirm => 'Sure';

  @override
  String get popupDownloadDefaultFileName => 'download';

  @override
  String get popupDownloadProgressTitle => 'Downloading';

  @override
  String get popupDownloadCompletedTitle => 'Download complete';

  @override
  String get popupDownloadProgressHint =>
      'Live speed, remaining time and segment state stay visible here';

  @override
  String get popupDownloadCompletedHint =>
      'The file is saved and ready to open from the file or its folder';

  @override
  String get popupDownloadStatusPending => 'Pending';

  @override
  String get popupDownloadStatusDownloading => 'Downloading';

  @override
  String get popupDownloadStatusPaused => 'Paused';

  @override
  String get popupDownloadStatusMerging => 'Merging';

  @override
  String get popupDownloadStatusCompleted => 'Done';

  @override
  String get popupDownloadStatusFailed => 'Failed';

  @override
  String get popupDownloadStatusUnknown => 'Waiting';

  @override
  String get popupDownloadMetricProgress => 'Progress';

  @override
  String get popupDownloadMetricDownloaded => 'Downloaded';

  @override
  String get popupDownloadMetricTotalSize => 'Size';

  @override
  String get popupDownloadMetricSpeed => 'Speed';

  @override
  String get popupDownloadMetricEta => 'ETA';

  @override
  String get popupDownloadMetricSegments => 'Segments';

  @override
  String get popupDownloadMetricStatus => 'Status';

  @override
  String get popupDownloadMetricSaveTo => 'Saved to';

  @override
  String get popupDownloadMetricHost => 'Host';

  @override
  String get popupDownloadProgressLiveLabel => 'Live transfer';

  @override
  String get popupDownloadProgressSegmentTitle => 'Segment progress';

  @override
  String get popupDownloadProgressWaiting =>
      'Preparing the connection and resolving file details';

  @override
  String get popupDownloadProgressCompletedMessage =>
      'The download is complete and ready in the target folder';

  @override
  String get popupDownloadActionBackground => 'Run in background';

  @override
  String get popupDownloadActionPause => 'Pause';

  @override
  String get popupDownloadActionResume => 'Resume';

  @override
  String get popupDownloadActionOpenFile => 'Open file';

  @override
  String get popupDownloadActionOpenFolder => 'Open folder';

  @override
  String get popupDownloadActionClose => 'Close';

  @override
  String popupDownloadErrorOpenFileFailed(Object error) {
    return 'Failed to open file: $error';
  }

  @override
  String popupDownloadErrorOpenFolderFailed(Object error) {
    return 'Failed to open folder: $error';
  }

  @override
  String get addDownloadTitle => 'New download';

  @override
  String get addDownloadSubtitle =>
      'Support multi-threaded downloads and breakpoint resume downloads';

  @override
  String get addDownloadUrlLabel => 'Download URL';

  @override
  String get addDownloadRequiredBadge => 'Required';

  @override
  String get addDownloadUrlPlaceholder => 'https://example.com/file.zip';

  @override
  String get addDownloadParsedFileNameTitle => 'Parsed file name';

  @override
  String get addDownloadAdvancedToggle => 'Advanced options';

  @override
  String get addDownloadAdvancedCollapsedHint => 'Custom file name';

  @override
  String get addDownloadAdvancedExpandedHint => 'Collapse';

  @override
  String get addDownloadFileNameLabel => 'Custom file name';

  @override
  String get addDownloadOptionalBadge => 'Optional';

  @override
  String get addDownloadFileNamePlaceholder =>
      'Leave blank to use the resolved name';

  @override
  String get addDownloadFeatureTitle => 'Smart download features';

  @override
  String get addDownloadFeature1Title => 'Multi-threaded Segments';

  @override
  String get addDownloadFeature1Desc => 'Maximize download speed';

  @override
  String get addDownloadFeature2Title => 'Auto Resume';

  @override
  String get addDownloadFeature2Desc => 'Recovering after a network outage';

  @override
  String get addDownloadFeature3Title => 'Dynamic Segments';

  @override
  String get addDownloadFeature3Desc => 'Adaptive download strategy';

  @override
  String get addDownloadCancelButton => 'Cancel';

  @override
  String get addDownloadAdding => 'Adding...';

  @override
  String get addDownloadStart => 'Start downloading';

  @override
  String get addDownloadErrorMissingUrl => 'Please enter download link';

  @override
  String get addDownloadErrorInvalidUrl => 'Please enter a valid download link';

  @override
  String get downloadIntentTypeUnknown => 'Unknown link';

  @override
  String get downloadIntentTypeHttp => 'HTTP/HTTPS link';

  @override
  String get downloadIntentTypeMagnet => 'Magnet link';

  @override
  String downloadIntentUnsupportedType(Object type) {
    return 'It has been identified as $type, but the current version does not support direct download.';
  }

  @override
  String addDownloadErrorAddFailed(Object error) {
    return 'Failed to add task: $error';
  }

  @override
  String get addDownloadErrorTitle => 'Error';

  @override
  String get addDownloadErrorConfirm => 'Sure';

  @override
  String get addDownloadSuccessTitle => 'Task has been added';

  @override
  String addDownloadSuccessMessage(Object fileName) {
    return 'Downloading: $fileName';
  }

  @override
  String get folderPickerErrorPathNotFound => 'Path does not exist';

  @override
  String get folderPickerErrorAccessDenied =>
      'The path cannot be accessed (insufficient permissions)';

  @override
  String folderPickerErrorAccessFailed(Object error) {
    return 'The path cannot be accessed: $error';
  }

  @override
  String get folderPickerCreateTitle => 'Create folder';

  @override
  String get folderPickerCreatePrompt => 'Create folders in:';

  @override
  String get folderPickerCreatePlaceholder => 'Folder name';

  @override
  String get folderPickerCancelButton => 'Cancel';

  @override
  String get folderPickerCreateButton => 'Create';

  @override
  String get folderPickerConfirmButton => 'Sure';

  @override
  String get folderPickerCreateExistsTitle => 'Creation canceled';

  @override
  String folderPickerCreateExistsMessage(Object name) {
    return 'The folder \"$name\" already exists. \nThe folder is selected.';
  }

  @override
  String get folderPickerCreateSuccessTitle => 'Created successfully';

  @override
  String folderPickerCreateSuccessMessage(Object name) {
    return 'The \"$name\" folder has been created and selected';
  }

  @override
  String get folderPickerCreateFailedTitle => 'Creation failed';

  @override
  String folderPickerCreateFailedMessage(Object error) {
    return 'Failed to create folder: $error';
  }

  @override
  String get folderPickerQuickPathAddTitle => 'Add shortcut path';

  @override
  String get folderPickerQuickPathAddPrompt =>
      'Add the current path to the shortcut path:';

  @override
  String get folderPickerQuickPathAddNameLabel => 'Custom name (optional):';

  @override
  String get folderPickerQuickPathAddNamePlaceholder =>
      'For example: my project';

  @override
  String get folderPickerQuickPathAddButton => 'Add to';

  @override
  String get folderPickerQuickPathAddSuccessTitle => 'Added successfully';

  @override
  String get folderPickerQuickPathAddFailedTitle => 'Add failed';

  @override
  String get folderPickerQuickPathAddSuccessMessage =>
      'Shortcut path has been added';

  @override
  String get folderPickerQuickPathAddFailedMessage =>
      'Path already exists or is invalid';

  @override
  String get folderPickerQuickPathRemoveTitle => 'Remove shortcut';

  @override
  String folderPickerQuickPathRemoveMessage(Object path) {
    return 'Are you sure you want to remove this shortcut? \n\n$path';
  }

  @override
  String get folderPickerQuickPathRemoveButton => 'Remove';

  @override
  String get folderPickerTitle => 'Select folder';

  @override
  String get folderPickerNavUpTooltip => 'Parent folder';

  @override
  String get folderPickerPathPlaceholder => 'Enter path or select below';

  @override
  String get folderPickerRefreshTooltip => 'Refresh';

  @override
  String get folderPickerNewFolderTooltip => 'Create new folder';

  @override
  String get folderPickerAddQuickPathTooltip =>
      'Add current path to shortcut path';

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
  String get updateDialogCurrentInfoTitle => 'Current version information';

  @override
  String get downloadStatusDownloading => 'Downloading';

  @override
  String get downloadStatusPaused => 'Suspended';

  @override
  String get downloadStatusPending => 'Waiting';

  @override
  String get downloadStatusFailed => 'Failed';

  @override
  String get downloadStatusMerging => 'Merging';

  @override
  String get downloadStatusCompleted => 'Completed';

  @override
  String get downloadFilterTitle => 'Filter';

  @override
  String get downloadFilterSubtitle => 'Filter download tasks by status';

  @override
  String get downloadFilterAll => 'All';

  @override
  String get downloadDialogCloseButton => 'Close';

  @override
  String get downloadSortTitle => 'Sort';

  @override
  String get downloadSortSubtitle => 'Choose how to sort download tasks';

  @override
  String get downloadSortNewest => 'Newest';

  @override
  String get downloadSortOldest => 'Oldest';

  @override
  String get downloadSortNewestDesc =>
      'Sort by creation time from newest to oldest';

  @override
  String get downloadSortOldestDesc =>
      'Sort by creation time from oldest to newest';

  @override
  String get downloadSearchPlaceholder => 'Search download tasks...';

  @override
  String get downloadNoResultsTitle => 'No matching tasks found';

  @override
  String get downloadNoResultsSubtitle => 'Try modifying your search criteria';

  @override
  String get downloadStatsActiveLabel => 'Activity';

  @override
  String get downloadStatsSpeedLabel => 'Speed';

  @override
  String get downloadStatsSegmentsLabel => 'Segments';

  @override
  String get downloadEmptyTitle => 'No download tasks yet';

  @override
  String get downloadEmptySubtitle =>
      'Click the \"New\" button to add a download task';

  @override
  String get downloadCopySuccessTitle => 'Copied successfully';

  @override
  String get loadingTasks => 'Loading task list...';

  @override
  String get loadingTasksHint => 'Connecting to download engine';

  @override
  String get downloadCopySuccessMessage => 'Download link copied';

  @override
  String get downloadCopyFailedTitle => 'Copy failed';

  @override
  String downloadCopyFailedMessage(Object error) {
    return 'Copy failed: $error';
  }

  @override
  String get downloadCopyTooltip => 'Copy link';

  @override
  String get downloadActionStart => 'Start';

  @override
  String get downloadActionPause => 'Pause';

  @override
  String get downloadActionRetrySegments => 'Retry failed segments';

  @override
  String get downloadActionRetryAll => 'Retry all';

  @override
  String get downloadActionDelete => 'Delete';

  @override
  String get downloadMergingStatus => 'Download completed and merging';

  @override
  String get downloadCalculatingSize => 'Calculating size...';

  @override
  String get downloadCalculating => 'Calculating';

  @override
  String get downloadMatchingHttpProtocol => 'Matching HTTP protocol...';

  @override
  String get downloadMatchingHttpProtocolShort => 'Matching protocol';

  @override
  String downloadSegmentsTitleWithCount(Object count) {
    return 'Segmentation ($count)';
  }

  @override
  String get downloadSegmentsTitle => 'Segments';

  @override
  String get downloadSegmentsStatusCompleted => 'Finish';

  @override
  String get downloadSegmentsStatusDownloading => 'Downloading';

  @override
  String get downloadSegmentsStatusFailed => 'Failed';

  @override
  String downloadSegmentsSummary(
      Object total, Object completed, Object downloading) {
    return 'Total $total segments · Completed $completed · Downloading $downloading';
  }

  @override
  String downloadSegmentsSummaryWithFailed(
      Object total, Object completed, Object downloading, Object failed) {
    return 'Total $total segments · Completed $completed · Downloading $downloading · Failed $failed';
  }

  @override
  String get downloadRetryButton => 'Try again';

  @override
  String downloadSegmentLabel(Object index) {
    return 'Segment $index';
  }

  @override
  String downloadSegmentRetryCount(Object count) {
    return 'Retry $count times';
  }

  @override
  String get downloadSegmentsCollapse => 'Collapse';

  @override
  String downloadSegmentsShowAll(Object count) {
    return 'View all $count';
  }

  @override
  String downloadSizeUnknown(Object downloaded) {
    return '$downloaded / Unknown';
  }

  @override
  String get downloadFailedTitle => 'Download failed';

  @override
  String downloadFailedSegmentsHint(Object count) {
    return '$count segments failed, please try again';
  }

  @override
  String get downloadConfirmDeleteTitle => 'Confirm deletion';

  @override
  String downloadConfirmDeleteMessage(Object fileName) {
    return 'Are you sure you want to delete task \"$fileName\"?';
  }

  @override
  String get downloadDeleteButton => 'Delete';

  @override
  String get completedCategoryAll => 'All downloads';

  @override
  String get completedCategoryVideo => 'Videos';

  @override
  String get completedCategoryAudio => 'Audio';

  @override
  String get completedCategoryArchive => 'Compressed package';

  @override
  String get completedCategoryDocument => 'Documents';

  @override
  String get completedCategoryProgram => 'Programs';

  @override
  String get completedCategoryOther => 'Miscellaneous';

  @override
  String get completedSearchPlaceholder => 'Search for completed files...';

  @override
  String get completedNoResultsTitle => 'No matching file found';

  @override
  String get completedNoResultsSubtitle => 'Try modifying your search criteria';

  @override
  String get completedHeaderTitle => 'Completed';

  @override
  String get completedOpenFolderButton => 'Open folder';

  @override
  String get completedEmptyTitle => 'No completed tasks yet';

  @override
  String get completedEmptySubtitle =>
      'Completed download tasks will appear here';

  @override
  String get completedStatsTitle => 'Download statistics';

  @override
  String get completedStatsPeakSpeed => 'Peak speed';

  @override
  String get completedStatsAverageSpeed => 'Average speed';

  @override
  String get completedStatsDuration => 'Duration';

  @override
  String get completedStatsSegments => 'Number of segments';

  @override
  String get completedStatsThreads => 'Number of threads';

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
    return '$minutes minutes ago';
  }

  @override
  String completedTimeHoursAgo(Object hours) {
    return '$hours hours ago';
  }

  @override
  String completedTimeDaysAgo(Object days) {
    return '$days days ago';
  }

  @override
  String completedTimeMonthDay(Object month, Object day) {
    return '${month}month${day}day';
  }

  @override
  String get completedFilePathMissingMessage => 'File path does not exist';

  @override
  String completedRunFileFailedMessage(Object error) {
    return 'Failed to run file: $error';
  }

  @override
  String completedOpenFileLocationFailedMessage(Object error) {
    return 'Failed to open file location: $error';
  }

  @override
  String get completedHintTitle => 'Tip';

  @override
  String get completedConfirmDeleteTitle => 'Confirm deletion';

  @override
  String completedDeleteTaskMessage(Object fileName) {
    return 'Are you sure you want to delete \"$fileName\"?';
  }

  @override
  String get completedRemoveSuccessTitle => 'Delete successfully';

  @override
  String get completedRemoveSuccessMessage => 'Task removed from list';

  @override
  String get completedDeleteSuccessTitle => 'Delete successfully';

  @override
  String completedDeleteFileSuccessMessage(Object fileName) {
    return 'Deleted file: $fileName';
  }

  @override
  String get completedFileNotFoundTitle => 'File does not exist';

  @override
  String get completedFileNotFoundMessage =>
      'The file may have been moved or deleted';

  @override
  String get completedDeleteFailedTitle => 'Delete failed';

  @override
  String completedDeleteFailedMessage(Object error) {
    return 'Unable to delete file: $error';
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
  String get completedCreateCategoryTitle => 'Create custom categories';

  @override
  String get completedCreateCategoryNameLabel => 'Category name';

  @override
  String get completedCreateCategoryNamePlaceholder => 'For example: picture';

  @override
  String get completedCreateCategoryExtensionsLabel => 'File extensions';

  @override
  String get completedCreateCategoryExtensionsPlaceholder =>
      'For example: .jpg, .png, .gif (separate with commas)';

  @override
  String get completedCreateCategoryHint =>
      'Tip: The extension needs to contain a period, and multiple extensions should be separated by commas';

  @override
  String get completedCreateCategoryInputErrorTitle => 'Input error';

  @override
  String get completedCreateCategoryInputErrorMessage =>
      'Please fill in complete information';

  @override
  String get completedCreateCategoryInvalidExtMessage =>
      'Please enter a valid extension';

  @override
  String get completedCreateCategorySuccessTitle => 'Created successfully';

  @override
  String completedCreateCategorySuccessMessage(Object name) {
    return 'Category created: $name';
  }

  @override
  String completedDeleteCategoryMessage(Object name) {
    return 'Are you sure you want to delete the custom classification \"$name\"?';
  }

  @override
  String get completedDeleteCategorySuccessTitle => 'Delete successfully';

  @override
  String completedDeleteCategorySuccessMessage(Object name) {
    return 'Deleted category: $name';
  }

  @override
  String get statusPageTitle => 'System status';

  @override
  String get statusPageRefresh => 'Refresh';

  @override
  String get statusPageTestApi => 'Test API';

  @override
  String get statusPageClearLogs => 'Clear log';

  @override
  String get statusSectionKernel => 'Download core status';

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
  String get statusValueDisconnected => 'Not connected';

  @override
  String get statusItemInternet => 'Internet';

  @override
  String get statusValueReachable => 'Reachable';

  @override
  String get statusValueUnreachable => 'Not accessible';

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
  String get statusSectionSystemInfo => 'System information';

  @override
  String get statusItemOs => 'Operating system';

  @override
  String get statusValueUnknown => 'Unknown';

  @override
  String get statusItemOsVersion => 'System version';

  @override
  String get statusItemCpuCores => 'Number of CPU cores';

  @override
  String statusSystemCpuCores(Object count) {
    return '$count core';
  }

  @override
  String get statusItemDartVersion => 'Dart version';

  @override
  String get statusSectionDownloadStats => 'Download statistics';

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
  String get statusSectionLogStats => 'Log statistics';

  @override
  String get statusItemLogCount => 'Number of log entries';

  @override
  String get statusItemErrorCount => 'Number of errors';

  @override
  String get statusItemWarningCount => 'Warnings';

  @override
  String get statusSectionExtension => 'Browser extension';

  @override
  String get statusItemTip => 'Tip';

  @override
  String get statusExtensionTip =>
      'Thanks for using it. It now supports downloading plug-ins within the software and jumping to web pages.';

  @override
  String get statusExtensionDownloadButton => 'Download extension';

  @override
  String get statusExtensionOpenStoreButton => 'Open store page';

  @override
  String get statusSectionAutoStart => 'Start automatically at boot';

  @override
  String get statusItemPlatformSupport => 'Platform support';

  @override
  String get statusAutoStartWindowsOnly => 'Only supports Windows platform';

  @override
  String get statusItemAutoStartStatus => 'Startup status';

  @override
  String get statusValueEnabled => 'Enabled';

  @override
  String get statusValueDisabled => 'Not enabled';

  @override
  String get statusItemRegistryPath => 'Registration path';

  @override
  String get statusValueCorrect => 'Correct';

  @override
  String get statusValueNeedsUpdate => 'Need to update';

  @override
  String get statusItemCurrentRegistry => 'Current registration';

  @override
  String get statusItemCurrentPath => 'Current path';

  @override
  String get statusAutoStartOldRegistryTitle => 'Older startup entry detected';

  @override
  String get statusAutoStartOldRegistryMessage =>
      'The registered path does not match the current executable, possibly because the app has been updated or moved. Click the button below to fix it automatically.';

  @override
  String get statusAutoStartFixButton => 'Automatic repair registration';

  @override
  String get statusSectionPopupTest => 'Pop-up window testing';

  @override
  String get statusItemDescription => 'Description';

  @override
  String get statusPopupTestDescription =>
      'Test whether an independent popup window can be opened when the browser triggers a download.';

  @override
  String get statusItemTestResult => 'Test results';

  @override
  String statusPopupTestResultSuccess(Object time) {
    return 'Success (${time}ms)';
  }

  @override
  String statusPopupTestResultFailed(Object error) {
    return 'Failure: $error';
  }

  @override
  String get statusPopupTesting => 'Creating...';

  @override
  String get statusPopupTestButton => 'Test the new download box';

  @override
  String get statusPopupDialogTestButton => 'Old Dialog test';

  @override
  String get statusPopupTestInfoTitle => 'Test instructions';

  @override
  String get statusPopupTestInfoBody =>
      '• When the browser triggers a download, a separate Flutter popup window will open\\n• The main window will remain in the background and will not be pulled to the foreground\\n• The test results and time consumption will be recorded in the log';

  @override
  String get statusExtensionDownloadAddedTitle => 'Download added';

  @override
  String get statusExtensionDownloadAddedMessage =>
      'Browser extension added to download list';

  @override
  String get statusExtensionDownloadFailedTitle => 'Download failed';

  @override
  String statusExtensionDownloadFailedMessage(Object error) {
    return 'Unable to add download task: $error';
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
  String get statusAutoStartFixSuccessTitle => 'Repair successful';

  @override
  String get statusAutoStartFixSuccessMessage =>
      'Self-startup registration has been updated to the current version';

  @override
  String get statusAutoStartFixFailedTitle => 'Repair failed';

  @override
  String get statusAutoStartFixFailedMessage =>
      'Unable to update auto-start registration, please check permissions';

  @override
  String statusAutoStartFixErrorMessage(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get statusPopupTestCreating => 'Opening new download dialog...';

  @override
  String get statusPopupTestStartLog =>
      'Start testing standalone popup windows...';

  @override
  String statusPopupTestSuccessLog(Object time) {
    return 'The independent popup window has been opened, taking: ${time}ms';
  }

  @override
  String get statusPopupTestSuccessMessage =>
      'The new download dialog box has been opened successfully';

  @override
  String get statusPopupTestSuccessTitle => 'Test successful';

  @override
  String statusPopupTestSuccessToast(Object time) {
    return 'The new download dialog box has been opened, taking ${time}ms';
  }

  @override
  String statusPopupTestFailedLog(Object error) {
    return 'Failed to open independent popup window: $error';
  }

  @override
  String get statusPopupTestFailedTitle => 'Test failed';

  @override
  String statusPopupTestFailedToast(Object error) {
    return 'Failed to open new download dialog box: $error';
  }

  @override
  String get statusPopupDialogTestStartLog =>
      'Start testing the Dialog popup...';

  @override
  String statusPopupDialogTestCloseLog(Object time) {
    return 'Dialog pop-up window is closed, total time taken: ${time}ms';
  }

  @override
  String statusPopupDialogTestFailedLog(Object error) {
    return 'Dialog popup failed: $error';
  }

  @override
  String get statusApiTestHealthCheck => 'Health check';

  @override
  String get statusApiTestGetTasks => 'Get tasks';

  @override
  String get statusApiTestGetStatistics => 'Get statistics';

  @override
  String get statusApiTestGetConfig => 'Get configuration';

  @override
  String get onlineStatsPageTitle => 'People currently traveling with you';

  @override
  String get onlineStatsCountUnit => 'Bit';

  @override
  String get onlineStatsAloneMessage =>
      'You are the only one using Hanabi for now';

  @override
  String onlineStatsOthersMessage(Object count) {
    return 'Besides you, $count other users are using Hanabi';
  }

  @override
  String onlineStatsTotalMessage(Object count) {
    return '(A total of $count including you)';
  }

  @override
  String get onlineStatsMyStatusTitle => 'My current status';

  @override
  String get onlineStatsDeviceIdLabel => 'Device ID';

  @override
  String get onlineStatsNotInitialized => 'Not initialized';

  @override
  String get onlineStatsAppVersionLabel => 'Application version';

  @override
  String get onlineStatsHeartbeatLabel => 'Heartbeat interval';

  @override
  String get onlineStatsHeartbeatValue => 'Automatically sent every 5 minutes';

  @override
  String get onlineStatsServerLabel => 'Statistics server';

  @override
  String get onlineStatsSending => 'Sending...';

  @override
  String get onlineStatsSendSignalButton => 'Send my signal to the server';

  @override
  String get onlineStatsPrivacyPolicy => 'Privacy Policy';

  @override
  String get onlineStatsTermsOfService => 'Terms of Service';

  @override
  String get onlineStatsOfficialSite => 'Official website address';

  @override
  String get onlineStatsSendSuccessTitle => 'Sent successfully';

  @override
  String get onlineStatsSendSuccessMessage =>
      'Your signal was successfully sent to the server';

  @override
  String get onlineStatsCooldownTitle => 'Server marked online';

  @override
  String onlineStatsCooldownMessage(Object minutes) {
    return 'Your online status has been recorded by the server, please try again in $minutes minutes';
  }

  @override
  String get onlineStatsSendFailedTitle => 'Sending failed';

  @override
  String get onlineStatsSendFailedMessage =>
      'Unable to connect to statistics server, please check network connection';

  @override
  String get onlineStatsOpenLinkFailedTitle => 'Unable to open link';

  @override
  String onlineStatsOpenLinkFailedMessage(Object url) {
    return 'Please manually access in the browser:\\n$url';
  }

  @override
  String get onlineStatsOpenFailedTitle => 'Open failed';

  @override
  String onlineStatsOpenFailedMessage(Object error, Object url) {
    return 'Error: $error\\n\\nPlease manually access in the browser:\\n$url';
  }

  @override
  String get onlineStatsDialogOk => 'Sure';

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
  String get logAutoScrollOn => 'Autoscroll: On';

  @override
  String get logAutoScrollOff => 'Autoscroll: Off';

  @override
  String get logStatsShow => 'Statistics: Show';

  @override
  String get logStatsHide => 'Statistics: hidden';

  @override
  String get logFailureStatsShow => 'Failure Statistics: Show';

  @override
  String get logFailureStatsHide => 'Failure statistics: hidden';

  @override
  String get logExportLogsButton => 'Export log';

  @override
  String get logExportDiagnosticsButton => 'Export diagnostic package';

  @override
  String get logArchiveButton => 'Archive logs';

  @override
  String get logClearButton => 'Clear log';

  @override
  String get logCurrentTabLabel => 'Ordinary log';

  @override
  String get logFullTabLabel => 'FULL LOG';

  @override
  String get logSearchPlaceholderRegex => 'Enter regular expression...';

  @override
  String get logSearchPlaceholder => 'Search logs...';

  @override
  String get logEmptyTitle => 'No logs yet';

  @override
  String get logEmptySubtitle => 'The log will appear here';

  @override
  String get logStatTotal => 'Total';

  @override
  String logGroupedCount(Object count) {
    return '$count group';
  }

  @override
  String get logClearFiltersButton => 'Clear';

  @override
  String get logFailureStatsTitle => 'Download failure statistics';

  @override
  String logFailureStatsTotal(Object count) {
    return 'Total $count times';
  }

  @override
  String get logFailureStatsEmpty => 'No download failure record yet';

  @override
  String get logFailureReasonUnknown => 'Unknown error';

  @override
  String logFailureReasonAuth(Object code) {
    return 'Authentication failed ($code)';
  }

  @override
  String logFailureReasonNotFound(Object code) {
    return 'Resource does not exist ($code)';
  }

  @override
  String get logFailureReasonRange => 'Range is not supported';

  @override
  String logFailureReasonRangeWithCode(Object code) {
    return 'Range is not supported ($code)';
  }

  @override
  String logFailureReasonTooManyRequests(Object code) {
    return 'Request too fast ($code)';
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
  String get logFailureReasonTimeout => 'Connection timeout';

  @override
  String get logFailureReasonConnection => 'Connection interrupted';

  @override
  String get logFailureReasonDns => 'DNS resolution failed';

  @override
  String get logFailureReasonSsl => 'SSL/Certificate Error';

  @override
  String get logFailureReasonChecksum => 'File verification failed';

  @override
  String get logFailureReasonDisk => 'Disk/permissions error';

  @override
  String get logFailureReasonOther => 'Other errors';

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
    return 'Repeat $count times';
  }

  @override
  String logRepeatedMore(Object count) {
    return '... and $count more';
  }

  @override
  String get logContextCopy => 'Copy log';

  @override
  String logContextRepeated(Object count) {
    return '(Repeat $count times)';
  }

  @override
  String get logContextRemoveBookmark => 'Unbookmark';

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
  String get logContextCopySingle => 'Copy this article';

  @override
  String get logFilterLevelTitle => 'Filter log level';

  @override
  String get logFilterAllLabel => 'All';

  @override
  String get logDialogClose => 'Close';

  @override
  String get logSourceFilterTitle => 'Filter log sources';

  @override
  String logSourceTotalCount(Object count) {
    return '$count items';
  }

  @override
  String get logSourceCategoryKernel => 'Kernel';

  @override
  String logSourceKernelSubtitle(Object count) {
    return 'Download core · $count tags';
  }

  @override
  String get logSourceCategoryApp => 'App';

  @override
  String logSourceAppSubtitle(Object count) {
    return 'Applications · $count tags';
  }

  @override
  String get logSourceCategorySystem => 'System';

  @override
  String logSourceSystemSubtitle(Object count) {
    return 'System/Framework · $count tags';
  }

  @override
  String get logDialogOk => 'Sure';

  @override
  String get logDialogCancel => 'Cancel';

  @override
  String get logTimeRangeTitle => 'Time range filter';

  @override
  String get logTimeRangeQuickSelectLabel => 'Quick selection:';

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
  String get logRulesDialogTitle => 'Highlight rule management';

  @override
  String get logRulesBuiltinTitle => 'Built-in rules';

  @override
  String get logRulesCustomTitle => 'Custom rules';

  @override
  String get logRulesAddButton => 'Add to';

  @override
  String get logRulesCustomEmpty => 'No custom rules yet';

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
  String get logRulesLegendKeyValue => 'Key-value';

  @override
  String get logAddRuleTitle => 'Add custom rules';

  @override
  String get logAddRuleNameLabel => 'Rule name';

  @override
  String get logAddRuleNamePlaceholder => 'For example: task ID';

  @override
  String get logAddRulePatternLabel => 'Regular expression';

  @override
  String get logAddRulePatternPlaceholder =>
      'For example: \\b[a-f0-9]+\\b (16 bits)';

  @override
  String get logAddRuleColorLabel => 'Highlight color';

  @override
  String get logAddRuleInvalidTitle => 'Invalid regular expression';

  @override
  String logAddRuleInvalidMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get logArchiveTitle => 'Archive logs';

  @override
  String get logArchivePrompt => 'Select archiving options:';

  @override
  String get logArchiveExportAll => 'Export all logs';

  @override
  String get logArchiveExportFiltered => 'Export current filter results';

  @override
  String get logArchiveExportFull => 'Export FULL LOG';

  @override
  String logArchiveExportBookmarked(Object count) {
    return 'Export bookmark logs ($count)';
  }

  @override
  String get logClearConfirmTitle => 'Confirm clearing';

  @override
  String get logClearConfirmMessage =>
      'Are you sure you want to clear all logs? This action cannot be undone.';

  @override
  String get logClearConfirmButton => 'Clear';

  @override
  String get logExportSuccessTitle => 'Export successful';

  @override
  String logExportSavedMessage(Object path) {
    return 'The log has been saved to:\\n$path';
  }

  @override
  String get logExportFailedTitle => 'Export failed';

  @override
  String logExportFailedMessage(Object error) {
    return 'Unable to save log: $error';
  }

  @override
  String logDiagnosticsSavedMessage(Object path) {
    return 'Diagnostic package saved to:\\n$path';
  }

  @override
  String logDiagnosticsExportFailedMessage(Object error) {
    return 'Unable to export diagnostic package: $error';
  }

  @override
  String logExportFileHeader(Object time) {
    return '# Log export - $time';
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
  String get logRuleHttpStatus => 'HTTP status code';

  @override
  String get logRuleTime => 'Time';

  @override
  String get logRuleStep => 'Step';

  @override
  String get logRulePid => 'PID';

  @override
  String get logRuleKeyValue => 'Key-value pair';

  @override
  String get performanceMonitorTitle => 'Performance monitoring';

  @override
  String get performanceMonitorStatusRunning => 'Monitoring...';

  @override
  String get performanceMonitorStatusIdle =>
      'Click Start Monitoring to collect performance data';

  @override
  String get performanceMonitorButtonStop => 'Stop monitoring';

  @override
  String get performanceMonitorButtonStart => 'Start monitoring';

  @override
  String get performanceMonitorRealtimeTitle => 'Real-time data';

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
  String get performanceMonitorStatsTitle => 'Statistical summary';

  @override
  String get performanceMonitorStatTotalFrames => 'Total frames';

  @override
  String get performanceMonitorStatJankFrames => 'Janky frames';

  @override
  String get performanceMonitorStatJankRate => 'Jank rate';

  @override
  String get performanceMonitorStatAvgBuildTime => 'Average build time';

  @override
  String get performanceMonitorStatAvgRasterTime => 'Average Raster Time';

  @override
  String get performanceMonitorStatAvgTotalTime => 'Average Total time';

  @override
  String get performanceMonitorStatMaxBuildTime => 'Maximum build time';

  @override
  String get performanceMonitorStatMaxRasterTime => 'Maximum Raster Time';

  @override
  String get performanceMonitorStatMaxTotalTime => 'Maximum Total time';

  @override
  String get performanceMonitorRebuildTitle =>
      'Widget reconstruction statistics';

  @override
  String get performanceMonitorRebuildTotal => 'Total number of rebuilds';

  @override
  String get performanceMonitorRebuildTracked => 'Number of Widgets tracked';

  @override
  String get performanceMonitorRebuildTopTitle =>
      'Widgets with the most rebuilds';

  @override
  String get performanceMonitorRebuildEmpty =>
      'There is no reconstruction data yet\\nCall trackRebuild() in the code to track';

  @override
  String performanceMonitorFrameChartTitle(Object count) {
    return 'Frame time graph (most recent $count frames)';
  }

  @override
  String get performanceMonitorFrameChartEmpty =>
      'No data yet, please start monitoring';

  @override
  String get performanceMonitorLegendNormal => 'Normal frame';

  @override
  String performanceMonitorLegendJankMs(Object ms) {
    return 'Stuttering frame (> $ms ms)';
  }

  @override
  String get performanceMonitorLegendFpsThreshold => '60fps threshold';

  @override
  String get performanceMonitorSettingsTitle => 'Current rendering settings';

  @override
  String get performanceMonitorSettingsModeLabel => 'Performance mode';

  @override
  String get performanceMonitorSettingsBlurLabel => 'Blur effect';

  @override
  String get performanceMonitorSettingsBlurStrengthLabel => 'Blur intensity';

  @override
  String get performanceMonitorSettingsWindowEffectLabel => 'Window effects';

  @override
  String get performanceMonitorSettingsAcrylicOpacityLabel =>
      'Acrylic transparency';

  @override
  String get performanceMonitorValueEnabled => 'Enabled';

  @override
  String get performanceMonitorValueDisabled => 'Disable';

  @override
  String performanceMonitorWindowEffectEnabled(Object mode) {
    return 'Enable ($mode)';
  }

  @override
  String get performanceMonitorWindowEffectHintEnabled =>
      'Window effects are enabled and may affect performance. If the freezing rate is high, it is recommended to turn it off in \"Settings → Interface → Window Effects\"';

  @override
  String get performanceMonitorWindowEffectHintDisabled =>
      'Window effects are disabled for optimal performance. If you need visual effects, you can turn them on in \"Settings → Interface → Window Effects\"';

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
      'Historical data has been cleared';

  @override
  String get performanceMonitorToastExportSuccessTitle => 'Export successful';

  @override
  String performanceMonitorToastExportSuccessMessage(Object path) {
    return 'The log has been saved to: $path';
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
  String get performanceMonitorModeQuality => 'High quality';

  @override
  String get performanceMonitorModeBalanced => 'Balanced';

  @override
  String get performanceMonitorModePerformance => 'Performance first';

  @override
  String get tagActionLabel => 'Label';

  @override
  String get tagEditTitle => 'Edit tag';

  @override
  String get tagEditSubtitle => 'Separate tags with commas';

  @override
  String get tagEditPlaceholder => 'tag 1, tag 2';

  @override
  String get tagFilterTitle => 'Tag filter';

  @override
  String get tagFilterEmpty => 'No tags available yet';

  @override
  String get tagFilterSubtitle => 'Select a tag to filter by:';

  @override
  String get tagFilterClearButton => 'Clear tag filter';

  @override
  String completedBatchActionsLabel(Object count) {
    return 'Batch operations ($count items)';
  }

  @override
  String get completedBatchRenameButton => 'Batch rename';

  @override
  String get completedBatchMoveButton => 'Batch move';

  @override
  String get completedBatchMoveSuccessTitle => 'Batch move completed';

  @override
  String completedBatchMoveSuccessMessage(Object count) {
    return '$count files moved';
  }

  @override
  String completedBatchMovePartialMessage(Object success, Object failed) {
    return '$success succeeded, $failed failed';
  }

  @override
  String get completedBatchRenameTitle => 'Batch rename';

  @override
  String get completedBatchRenameHint =>
      'Applies prefix/suffix to filenames in current list';

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
      'Please fill in at least prefix or suffix';

  @override
  String get completedBatchRenameSuccessTitle => 'Batch rename completed';

  @override
  String completedBatchRenameSuccessMessage(Object count) {
    return '$count files renamed';
  }

  @override
  String completedBatchRenamePartialMessage(Object success, Object failed) {
    return '$success succeeded, $failed failed';
  }

  @override
  String get settingsClipboardListenerTitle => 'Clipboard monitoring';

  @override
  String get settingsClipboardListenerSubtitle =>
      'Detect links in clipboard and pop up new download';

  @override
  String get settingsClipboardListenerEnabledTitle =>
      'Clipboard monitoring is enabled';

  @override
  String get settingsClipboardListenerEnabledMessage =>
      'After copying the link, a new download window will pop up.';

  @override
  String get settingsClipboardListenerDisabledTitle =>
      'Clipboard listening is turned off';

  @override
  String get settingsClipboardListenerDisabledMessage =>
      'Copying the link will no longer prompt the pop-up window';

  @override
  String get clipboardListenerMuteSessionButton => 'Mute this time';

  @override
  String get clipboardListenerSessionMutedTitle =>
      'This conversation has been muted';

  @override
  String get clipboardListenerSessionMutedMessage =>
      'Automatically fetching links will be paused until the next time you restart the app';

  @override
  String get downloadDuplicateTitle => 'Duplicate downloads found';

  @override
  String downloadDuplicateMessage(Object fileName, Object status) {
    return 'A task with the same link already exists: $fileName ($status). How to deal with it?';
  }

  @override
  String get downloadDuplicateUseExistingButton => 'Use existing';

  @override
  String get downloadDuplicateAddNewButton => 'Still new';

  @override
  String get downloadDuplicateCancelButton => 'Cancel';

  @override
  String get downloadBadgeHostHint => 'Site cache';

  @override
  String get downloadBadgePolicyFallback => 'Downgraded';

  @override
  String downloadBadgeConcurrencyCap(Object count) {
    return 'Limited concurrency x$count';
  }

  @override
  String get downloadFailureHintAuth =>
      'Login or Referer/Cookie replenishment may be required, and the link may have expired.';

  @override
  String get downloadFailureHintNotFound =>
      'The resource does not exist or has expired. Try updating the link.';

  @override
  String get downloadFailureHintRange =>
      'The server does not support resumable downloading. It is recommended to use a single thread or re-download.';

  @override
  String get downloadFailureHintRateLimit =>
      'The request is too frequent, please try again later.';

  @override
  String get downloadFailureHintServer =>
      'Server error, please try again later.';

  @override
  String get downloadFailureHintHttp =>
      'HTTP error, please check the link or permissions.';

  @override
  String get downloadFailureHintTimeout =>
      'The connection timed out, check the network and try again.';

  @override
  String get downloadFailureHintConnection =>
      'Connection lost, check network or proxy settings.';

  @override
  String get downloadFailureHintDns =>
      'Domain name resolution failed, check network or DNS.';

  @override
  String get downloadFailureHintSsl =>
      'SSL certificate error, try changing the source.';

  @override
  String get downloadFailureHintChecksum =>
      'The file may be damaged, it is recommended to download it again.';

  @override
  String get downloadFailureHintDisk =>
      'Insufficient disk space or insufficient permissions, please check the save directory.';

  @override
  String get settingsConflictStrategyTitle =>
      'Duplicate name conflict strategy';

  @override
  String get settingsConflictStrategySubtitle =>
      'What to do when the file already exists';

  @override
  String get settingsConflictStrategyIncrement => 'Automatic addition (1)(2)';

  @override
  String get settingsConflictStrategyTimestamp => 'Append timestamp';

  @override
  String get settingsConflictStrategyOverwrite => 'Overwrite original file';

  @override
  String get noticePageTitle => 'Notifications';

  @override
  String get noticePinned => 'Pin to top';

  @override
  String get noticeEmpty => 'No notification yet';

  @override
  String get noticeRefresh => 'Refresh';

  @override
  String get noticeRetry => 'Try again';

  @override
  String get noticeLoadError => 'Failed to load notification';

  @override
  String noticeLastSynced(Object timeAgo) {
    return 'Synced $timeAgo';
  }

  @override
  String get noticeJustNow => 'Just now';

  @override
  String noticeMinutesAgo(Object count) {
    return '$count minutes ago';
  }

  @override
  String noticeHoursAgo(Object count) {
    return '$count hours ago';
  }

  @override
  String noticeDaysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get noticeOpenLink => 'Open link';

  @override
  String get settingsLogManagementSection => 'Log management';

  @override
  String get settingsLogClearTitle => 'Clear log';

  @override
  String get settingsLogClearSubtitle => 'Delete all logging and log files';

  @override
  String get settingsLogClearButton => 'Clear';

  @override
  String get settingsLogClearConfirmTitle => 'Confirm to clear logs';

  @override
  String get settingsLogClearConfirmMessage =>
      'Are you sure you want to delete all log records and log files? This action cannot be undone.';

  @override
  String get settingsLogClearConfirmButton => 'Confirm clearing';

  @override
  String get settingsLogClearSuccessTitle => 'Logs cleared';

  @override
  String get settingsLogClearSuccessMessage =>
      'All log records and files deleted';

  @override
  String get settingsLogOpenDirTitle => 'Open log directory';

  @override
  String get settingsLogOpenDirSubtitle => 'View log files in File Explorer';

  @override
  String get settingsLogOpenDirButton => 'Open';

  @override
  String get settingsLogOpenDirNotFound => 'Log directory does not exist';

  @override
  String get settingsLogOpenDirError => 'Unable to open log directory';

  @override
  String get settingsLogRetentionTitle => 'Automatic cleaning';

  @override
  String settingsLogRetentionSubtitle(Object days) {
    return 'Automatically delete logs older than $days days';
  }

  @override
  String get settingsLogRetentionDays => 'days';

  @override
  String get settingsLogRetentionSaved => 'Log cleaning settings saved';
}
