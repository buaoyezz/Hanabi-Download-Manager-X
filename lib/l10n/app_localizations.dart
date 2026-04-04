import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'Hanabi Download Manager X'**
  String get appTitle;

  /// No description provided for @aboutEasterEggCongrats.
  ///
  /// In zh, this message translates to:
  /// **'恭喜你发现了这个彩蛋！'**
  String get aboutEasterEggCongrats;

  /// No description provided for @aboutEasterEggTitle.
  ///
  /// In zh, this message translates to:
  /// **'这个彩蛋没什么用'**
  String get aboutEasterEggTitle;

  /// No description provided for @aboutEasterEggMessage.
  ///
  /// In zh, this message translates to:
  /// **'但是感谢你使用 {appName}！\\n感谢你的支持\\n希望你可以给他一个 Star'**
  String aboutEasterEggMessage(Object appName);

  /// No description provided for @aboutEasterEggDismiss.
  ///
  /// In zh, this message translates to:
  /// **'假装不知道'**
  String get aboutEasterEggDismiss;

  /// No description provided for @aboutMadeBy.
  ///
  /// In zh, this message translates to:
  /// **'作者 {developer}'**
  String aboutMadeBy(Object developer);

  /// No description provided for @aboutEasterEggDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'嘿！'**
  String get aboutEasterEggDialogTitle;

  /// No description provided for @aboutPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutPageTitle;

  /// No description provided for @aboutSectionAppInfo.
  ///
  /// In zh, this message translates to:
  /// **'应用信息'**
  String get aboutSectionAppInfo;

  /// No description provided for @aboutTapHintRemaining.
  ///
  /// In zh, this message translates to:
  /// **'再点 {count} 次...'**
  String aboutTapHintRemaining(Object count);

  /// No description provided for @aboutVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'v{version}'**
  String aboutVersionLabel(Object version);

  /// No description provided for @aboutSectionDetails.
  ///
  /// In zh, this message translates to:
  /// **'详细信息'**
  String get aboutSectionDetails;

  /// No description provided for @aboutDetailDeveloperLabel.
  ///
  /// In zh, this message translates to:
  /// **'开发者'**
  String get aboutDetailDeveloperLabel;

  /// No description provided for @aboutDetailKernelLabel.
  ///
  /// In zh, this message translates to:
  /// **'下载核心'**
  String get aboutDetailKernelLabel;

  /// No description provided for @aboutDetailUiFrameworkLabel.
  ///
  /// In zh, this message translates to:
  /// **'UI 框架'**
  String get aboutDetailUiFrameworkLabel;

  /// No description provided for @aboutDetailUiFrameworkValue.
  ///
  /// In zh, this message translates to:
  /// **'Fluent UI for Flutter'**
  String get aboutDetailUiFrameworkValue;

  /// No description provided for @aboutSectionLinks.
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get aboutSectionLinks;

  /// No description provided for @aboutLinkOfficialTitle.
  ///
  /// In zh, this message translates to:
  /// **'官方网站'**
  String get aboutLinkOfficialTitle;

  /// No description provided for @aboutLinkOfficialSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'访问项目主页'**
  String get aboutLinkOfficialSubtitle;

  /// No description provided for @aboutLinkGithubTitle.
  ///
  /// In zh, this message translates to:
  /// **'GitHub'**
  String get aboutLinkGithubTitle;

  /// No description provided for @aboutLinkGithubSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看源代码和贡献'**
  String get aboutLinkGithubSubtitle;

  /// No description provided for @aboutLinkContactTitle.
  ///
  /// In zh, this message translates to:
  /// **'联系我们'**
  String get aboutLinkContactTitle;

  /// No description provided for @aboutCopyrightMessage.
  ///
  /// In zh, this message translates to:
  /// **'© {year} {developer}。保留所有权利。'**
  String aboutCopyrightMessage(Object year, Object developer);

  /// No description provided for @aboutOpenLinkErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get aboutOpenLinkErrorTitle;

  /// No description provided for @aboutOpenLinkErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'打开链接失败: {error}'**
  String aboutOpenLinkErrorMessage(Object error);

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsTabGeneral.
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get settingsTabGeneral;

  /// No description provided for @settingsTabDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get settingsTabDownload;

  /// No description provided for @settingsTabAppearance.
  ///
  /// In zh, this message translates to:
  /// **'界面'**
  String get settingsTabAppearance;

  /// No description provided for @settingsTabUpdate.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get settingsTabUpdate;

  /// No description provided for @settingsTabAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get settingsTabAdvanced;

  /// No description provided for @settingsTabDeveloper.
  ///
  /// In zh, this message translates to:
  /// **'开发者'**
  String get settingsTabDeveloper;

  /// No description provided for @appearanceSectionLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get appearanceSectionLanguage;

  /// No description provided for @appearanceLanguageTitle.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get appearanceLanguageTitle;

  /// No description provided for @appearanceLanguageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认跟随系统：系统将自动为您选择合适的界面语言'**
  String get appearanceLanguageSubtitle;

  /// No description provided for @appearanceLanguageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get appearanceLanguageSystem;

  /// No description provided for @appearanceLanguageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get appearanceLanguageChinese;

  /// No description provided for @appearanceLanguageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get appearanceLanguageEnglish;

  /// No description provided for @appearanceLanguageSwitchedTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言已切换'**
  String get appearanceLanguageSwitchedTitle;

  /// No description provided for @appearanceLanguageSwitchedSystem.
  ///
  /// In zh, this message translates to:
  /// **'将根据系统语言自动选择'**
  String get appearanceLanguageSwitchedSystem;

  /// No description provided for @appearanceLanguageSwitchedTo.
  ///
  /// In zh, this message translates to:
  /// **'已切换为 {language}'**
  String appearanceLanguageSwitchedTo(Object language);

  /// No description provided for @appearanceLanguagePacksTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言包'**
  String get appearanceLanguagePacksTitle;

  /// No description provided for @appearanceLanguagePacksSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'把 .json/.arb 放到 {path} 后点击刷新'**
  String appearanceLanguagePacksSubtitle(Object path);

  /// No description provided for @appearanceLanguagePacksRefreshedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已刷新语言包'**
  String get appearanceLanguagePacksRefreshedTitle;

  /// No description provided for @appearanceLanguagePacksRefreshedMessage.
  ///
  /// In zh, this message translates to:
  /// **'发现 {count} 个语言包'**
  String appearanceLanguagePacksRefreshedMessage(Object count);

  /// No description provided for @appearanceLanguageRefreshButton.
  ///
  /// In zh, this message translates to:
  /// **'刷新语言包'**
  String get appearanceLanguageRefreshButton;

  /// No description provided for @trayMenuShowWindowTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示窗口'**
  String get trayMenuShowWindowTitle;

  /// No description provided for @trayMenuShowWindowSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'打开主界面'**
  String get trayMenuShowWindowSubtitle;

  /// No description provided for @trayMenuKernelTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载内核'**
  String get trayMenuKernelTitle;

  /// No description provided for @trayMenuKernelSubtitleRunning.
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get trayMenuKernelSubtitleRunning;

  /// No description provided for @trayMenuKernelSubtitleStopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get trayMenuKernelSubtitleStopped;

  /// No description provided for @trayMenuExitTitle.
  ///
  /// In zh, this message translates to:
  /// **'退出应用'**
  String get trayMenuExitTitle;

  /// No description provided for @trayMenuExitSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭所有窗口'**
  String get trayMenuExitSubtitle;

  /// No description provided for @exitWithActiveDownloadsTitle.
  ///
  /// In zh, this message translates to:
  /// **'仍有下载正在进行'**
  String get exitWithActiveDownloadsTitle;

  /// No description provided for @exitWithActiveDownloadsMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前还有 {count} 个下载任务正在运行。现在退出会中断这些下载，确定要继续退出吗？'**
  String exitWithActiveDownloadsMessage(Object count);

  /// No description provided for @exitWithActiveDownloadsCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get exitWithActiveDownloadsCancelButton;

  /// No description provided for @exitWithActiveDownloadsConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'仍然退出'**
  String get exitWithActiveDownloadsConfirmButton;

  /// No description provided for @tempFilesDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理临时文件'**
  String get tempFilesDialogTitle;

  /// No description provided for @tempFilesDialogScanPath.
  ///
  /// In zh, this message translates to:
  /// **'扫描路径: {path}'**
  String tempFilesDialogScanPath(Object path);

  /// No description provided for @tempFilesStatFiles.
  ///
  /// In zh, this message translates to:
  /// **'文件数'**
  String get tempFilesStatFiles;

  /// No description provided for @tempFilesStatTotalSize.
  ///
  /// In zh, this message translates to:
  /// **'总大小'**
  String get tempFilesStatTotalSize;

  /// No description provided for @tempFilesStatSelected.
  ///
  /// In zh, this message translates to:
  /// **'已选'**
  String get tempFilesStatSelected;

  /// No description provided for @tempFilesSupportedFormats.
  ///
  /// In zh, this message translates to:
  /// **'支持格式: .temp, .tmp, .download, .partN (分段), .crdownload, .partial, .!ut'**
  String get tempFilesSupportedFormats;

  /// No description provided for @tempFilesSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get tempFilesSelectAll;

  /// No description provided for @tempFilesIncludeTempDirs.
  ///
  /// In zh, this message translates to:
  /// **'包含临时目录'**
  String get tempFilesIncludeTempDirs;

  /// No description provided for @tempFilesSortLabel.
  ///
  /// In zh, this message translates to:
  /// **'排序:'**
  String get tempFilesSortLabel;

  /// No description provided for @tempFilesSortName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get tempFilesSortName;

  /// No description provided for @tempFilesSortSize.
  ///
  /// In zh, this message translates to:
  /// **'大小'**
  String get tempFilesSortSize;

  /// No description provided for @tempFilesSortTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get tempFilesSortTime;

  /// No description provided for @tempFilesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到临时文件'**
  String get tempFilesEmpty;

  /// No description provided for @tempFilesCloseButton.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get tempFilesCloseButton;

  /// No description provided for @tempFilesDeleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'删除选中 ({count})'**
  String tempFilesDeleteSelected(Object count);

  /// No description provided for @tempFilesDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get tempFilesDeleteConfirmTitle;

  /// No description provided for @tempFilesDeleteConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 {count} 个临时文件吗？'**
  String tempFilesDeleteConfirmMessage(Object count);

  /// No description provided for @tempFilesDeleteTotalSize.
  ///
  /// In zh, this message translates to:
  /// **'总大小: {size}'**
  String tempFilesDeleteTotalSize(Object size);

  /// No description provided for @tempFilesDeleteWarning.
  ///
  /// In zh, this message translates to:
  /// **'此操作不可恢复'**
  String get tempFilesDeleteWarning;

  /// No description provided for @tempFilesCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get tempFilesCancelButton;

  /// No description provided for @tempFilesDeleteButton.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get tempFilesDeleteButton;

  /// No description provided for @tempFilesDeleteDoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除完成'**
  String get tempFilesDeleteDoneTitle;

  /// No description provided for @tempFilesDeleteDoneWithFailures.
  ///
  /// In zh, this message translates to:
  /// **'成功删除 {success} 个，失败 {failed} 个'**
  String tempFilesDeleteDoneWithFailures(Object success, Object failed);

  /// No description provided for @tempFilesDeleteDoneSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功删除 {success} 个临时文件'**
  String tempFilesDeleteDoneSuccess(Object success);

  /// No description provided for @homeNavDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载任务'**
  String get homeNavDownloading;

  /// No description provided for @homeNavCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get homeNavCompleted;

  /// No description provided for @homeNavLog.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get homeNavLog;

  /// No description provided for @homeNavStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get homeNavStatus;

  /// No description provided for @homeNavOnlineStats.
  ///
  /// In zh, this message translates to:
  /// **'在线统计'**
  String get homeNavOnlineStats;

  /// No description provided for @homeNavPerformance.
  ///
  /// In zh, this message translates to:
  /// **'性能监控'**
  String get homeNavPerformance;

  /// No description provided for @homeNavConnectionDebug.
  ///
  /// In zh, this message translates to:
  /// **'连接调试'**
  String get homeNavConnectionDebug;

  /// No description provided for @homeNavSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get homeNavSettings;

  /// No description provided for @homeNavAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get homeNavAbout;

  /// No description provided for @homeUpdateFoundTitle.
  ///
  /// In zh, this message translates to:
  /// **'检测到了新版本'**
  String get homeUpdateFoundTitle;

  /// No description provided for @homeUpdateFoundMessage.
  ///
  /// In zh, this message translates to:
  /// **'本次更新为 {currentVersion} -> {newVersion}\\n快去设置页面更新吧！'**
  String homeUpdateFoundMessage(Object currentVersion, Object newVersion);

  /// No description provided for @homeKernelStartingTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在启动下载内核...'**
  String get homeKernelStartingTitle;

  /// No description provided for @homeKernelStartingHint.
  ///
  /// In zh, this message translates to:
  /// **'请稍候，这可能需要几秒钟'**
  String get homeKernelStartingHint;

  /// No description provided for @homeViewLog.
  ///
  /// In zh, this message translates to:
  /// **'查看日志'**
  String get homeViewLog;

  /// No description provided for @homeRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get homeRetry;

  /// No description provided for @homeNewTask.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get homeNewTask;

  /// No description provided for @fileName.
  ///
  /// In zh, this message translates to:
  /// **'文件名'**
  String get fileName;

  /// No description provided for @id.
  ///
  /// In zh, this message translates to:
  /// **'ID'**
  String get id;

  /// No description provided for @name.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get name;

  /// No description provided for @segments.
  ///
  /// In zh, this message translates to:
  /// **'分段'**
  String get segments;

  /// No description provided for @speed.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get speed;

  /// No description provided for @status.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get status;

  /// No description provided for @url.
  ///
  /// In zh, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @settingsSectionSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统设置'**
  String get settingsSectionSystem;

  /// No description provided for @settingsAutoStartTitle.
  ///
  /// In zh, this message translates to:
  /// **'开机自启'**
  String get settingsAutoStartTitle;

  /// No description provided for @settingsAutoStartSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'系统启动时自动运行应用程序'**
  String get settingsAutoStartSubtitle;

  /// No description provided for @settingsAutoStartEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'开机自启已开启'**
  String get settingsAutoStartEnabledTitle;

  /// No description provided for @settingsAutoStartEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'软件将随系统启动自动运行'**
  String get settingsAutoStartEnabledMessage;

  /// No description provided for @settingsAutoStartDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'开机自启已关闭'**
  String get settingsAutoStartDisabledTitle;

  /// No description provided for @settingsAutoStartDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'软件将不会自动运行'**
  String get settingsAutoStartDisabledMessage;

  /// No description provided for @settingsAutoStartEnableFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法开启开机自启'**
  String get settingsAutoStartEnableFailed;

  /// No description provided for @settingsAutoStartDisableFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法关闭开机自启'**
  String get settingsAutoStartDisableFailed;

  /// No description provided for @settingsAutoStartFixedTitle.
  ///
  /// In zh, this message translates to:
  /// **'自启动已修复'**
  String get settingsAutoStartFixedTitle;

  /// No description provided for @settingsAutoStartFixedMessage.
  ///
  /// In zh, this message translates to:
  /// **'检测到旧版本的自启动注册，已自动更新为当前版本'**
  String get settingsAutoStartFixedMessage;

  /// No description provided for @settingsSectionBehavior.
  ///
  /// In zh, this message translates to:
  /// **'行为设置'**
  String get settingsSectionBehavior;

  /// No description provided for @settingsAutoDownloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动开始下载'**
  String get settingsAutoDownloadTitle;

  /// No description provided for @settingsAutoDownloadSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'新任务将自动开始下载'**
  String get settingsAutoDownloadSubtitle;

  /// No description provided for @settingsAutoDownloadEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动开始下载已开启'**
  String get settingsAutoDownloadEnabledTitle;

  /// No description provided for @settingsAutoDownloadEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'新任务将自动开始下载'**
  String get settingsAutoDownloadEnabledMessage;

  /// No description provided for @settingsAutoDownloadDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动下载已关闭'**
  String get settingsAutoDownloadDisabledTitle;

  /// No description provided for @settingsAutoDownloadDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'新任务将等待手动开始'**
  String get settingsAutoDownloadDisabledMessage;

  /// No description provided for @settingsPopupWindowTitle.
  ///
  /// In zh, this message translates to:
  /// **'浏览器下载弹窗'**
  String get settingsPopupWindowTitle;

  /// No description provided for @settingsPopupWindowSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'显示下载弹窗'**
  String get settingsPopupWindowSubtitle;

  /// No description provided for @settingsPopupEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'弹窗已开启'**
  String get settingsPopupEnabledTitle;

  /// No description provided for @settingsPopupEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'浏览器下载将弹出小窗确认'**
  String get settingsPopupEnabledMessage;

  /// No description provided for @settingsPopupDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'弹窗已关闭'**
  String get settingsPopupDisabledTitle;

  /// No description provided for @settingsPopupDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'弹窗已关闭'**
  String get settingsPopupDisabledMessage;

  /// No description provided for @settingsCompleteNotifyTitle.
  ///
  /// In zh, this message translates to:
  /// **'完成通知'**
  String get settingsCompleteNotifyTitle;

  /// No description provided for @settingsCompleteNotifySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'下载完成时通知'**
  String get settingsCompleteNotifySubtitle;

  /// No description provided for @settingsCompleteNotifyEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'完成通知已开启'**
  String get settingsCompleteNotifyEnabledTitle;

  /// No description provided for @settingsCompleteNotifyEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'下载完成时将发送通知'**
  String get settingsCompleteNotifyEnabledMessage;

  /// No description provided for @settingsCompleteNotifyDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'完成通知已关闭'**
  String get settingsCompleteNotifyDisabledTitle;

  /// No description provided for @settingsCompleteNotifyDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'下载完成时不再通知'**
  String get settingsCompleteNotifyDisabledMessage;

  /// No description provided for @settingsOnlineStatsTitle.
  ///
  /// In zh, this message translates to:
  /// **'参与在线统计'**
  String get settingsOnlineStatsTitle;

  /// No description provided for @settingsOnlineStatsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'参与在线用户统计'**
  String get settingsOnlineStatsSubtitle;

  /// No description provided for @settingsOnlineStatsEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'在线统计已启用'**
  String get settingsOnlineStatsEnabledTitle;

  /// No description provided for @settingsOnlineStatsEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'您的设备将参与在线用户统计，帮助我们了解软件使用情况'**
  String get settingsOnlineStatsEnabledMessage;

  /// No description provided for @settingsOnlineStatsDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'在线统计已禁用'**
  String get settingsOnlineStatsDisabledTitle;

  /// No description provided for @settingsOnlineStatsDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'您的设备将不再发送统计信息'**
  String get settingsOnlineStatsDisabledMessage;

  /// No description provided for @settingsTrayHintTitle.
  ///
  /// In zh, this message translates to:
  /// **'托盘提示'**
  String get settingsTrayHintTitle;

  /// No description provided for @settingsTrayHintSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'托盘提示显示运行状态'**
  String get settingsTrayHintSubtitle;

  /// No description provided for @settingsTrayHintEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'已开启后台运行提示'**
  String get settingsTrayHintEnabledTitle;

  /// No description provided for @settingsTrayHintEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'当窗口隐藏时，托盘图标将显示\"正在后台运行\"'**
  String get settingsTrayHintEnabledMessage;

  /// No description provided for @settingsTrayHintDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'后台运行提示已关闭'**
  String get settingsTrayHintDisabledTitle;

  /// No description provided for @settingsTrayHintDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'托盘图标将始终只显示应用名称'**
  String get settingsTrayHintDisabledMessage;

  /// No description provided for @settingsCloseBehaviorTitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭按钮行为'**
  String get settingsCloseBehaviorTitle;

  /// No description provided for @settingsCloseBehaviorMinimizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'最小化到托盘'**
  String get settingsCloseBehaviorMinimizeLabel;

  /// No description provided for @settingsCloseBehaviorExitLabel.
  ///
  /// In zh, this message translates to:
  /// **'退出应用'**
  String get settingsCloseBehaviorExitLabel;

  /// No description provided for @settingsCloseBehaviorMinimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化到系统托盘，保持后台运行'**
  String get settingsCloseBehaviorMinimize;

  /// No description provided for @settingsCloseBehaviorExit.
  ///
  /// In zh, this message translates to:
  /// **'完全退出应用程序'**
  String get settingsCloseBehaviorExit;

  /// No description provided for @settingsCloseBehaviorUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知行为'**
  String get settingsCloseBehaviorUnknown;

  /// No description provided for @settingsCloseBehaviorSavedMessage.
  ///
  /// In zh, this message translates to:
  /// **'关闭按钮行为已设为{behavior}'**
  String settingsCloseBehaviorSavedMessage(Object behavior);

  /// No description provided for @settingsSaveSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置已保存'**
  String get settingsSaveSuccessTitle;

  /// No description provided for @settingsSaveFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置失败'**
  String get settingsSaveFailedTitle;

  /// No description provided for @settingsSaveFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法保存设置: {error}'**
  String settingsSaveFailedMessage(Object error);

  /// No description provided for @settingsDownloadPathSection.
  ///
  /// In zh, this message translates to:
  /// **'下载路径'**
  String get settingsDownloadPathSection;

  /// No description provided for @settingsDownloadPathTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存位置'**
  String get settingsDownloadPathTitle;

  /// No description provided for @settingsDownloadPathChangeButton.
  ///
  /// In zh, this message translates to:
  /// **'更改'**
  String get settingsDownloadPathChangeButton;

  /// No description provided for @settingsDownloadPathDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置下载路径'**
  String get settingsDownloadPathDialogTitle;

  /// No description provided for @settingsDownloadPathDialogPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请输入或浏览选择下载保存路径:'**
  String get settingsDownloadPathDialogPrompt;

  /// No description provided for @settingsDownloadPathPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'C:\\\\Downloads'**
  String get settingsDownloadPathPlaceholder;

  /// No description provided for @settingsBrowseButton.
  ///
  /// In zh, this message translates to:
  /// **'浏览'**
  String get settingsBrowseButton;

  /// No description provided for @settingsDownloadPathHintTitle.
  ///
  /// In zh, this message translates to:
  /// **'提示:'**
  String get settingsDownloadPathHintTitle;

  /// No description provided for @settingsDownloadPathHintBody.
  ///
  /// In zh, this message translates to:
  /// **'• 可以直接输入完整的文件夹路径\\n• 点击\"浏览\"按钮可视化选择文件夹\\n• 示例: C:\\\\Users\\\\用户名\\\\Downloads'**
  String get settingsDownloadPathHintBody;

  /// No description provided for @settingsCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get settingsCancelButton;

  /// No description provided for @settingsConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get settingsConfirmButton;

  /// No description provided for @settingsDownloadPathChangedMessage.
  ///
  /// In zh, this message translates to:
  /// **'下载路径已更改为: {path}'**
  String settingsDownloadPathChangedMessage(Object path);

  /// No description provided for @settingsDownloadPathChangeFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法更改下载路径，请检查路径是否有效'**
  String get settingsDownloadPathChangeFailedMessage;

  /// No description provided for @settingsDownloadConfigSection.
  ///
  /// In zh, this message translates to:
  /// **'下载配置'**
  String get settingsDownloadConfigSection;

  /// No description provided for @settingsDownloadModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载模式'**
  String get settingsDownloadModeTitle;

  /// No description provided for @settingsDownloadModeAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get settingsDownloadModeAuto;

  /// No description provided for @settingsDownloadModeThreadsOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅线程'**
  String get settingsDownloadModeThreadsOnly;

  /// No description provided for @settingsDownloadModeSegmentsOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅分段'**
  String get settingsDownloadModeSegmentsOnly;

  /// No description provided for @settingsDownloadModeManual.
  ///
  /// In zh, this message translates to:
  /// **'手动'**
  String get settingsDownloadModeManual;

  /// No description provided for @settingsThreadsTitle.
  ///
  /// In zh, this message translates to:
  /// **'线程数'**
  String get settingsThreadsTitle;

  /// No description provided for @settingsThreadsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'下载线程数量'**
  String get settingsThreadsSubtitle;

  /// No description provided for @settingsSegmentsTitle.
  ///
  /// In zh, this message translates to:
  /// **'分段数'**
  String get settingsSegmentsTitle;

  /// No description provided for @settingsSegmentsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'每个任务的分段数量'**
  String get settingsSegmentsSubtitle;

  /// No description provided for @settingsDynamicSegmentsTitle.
  ///
  /// In zh, this message translates to:
  /// **'动态分段'**
  String get settingsDynamicSegmentsTitle;

  /// No description provided for @settingsDynamicSegmentsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'根据文件大小自动调整分段'**
  String get settingsDynamicSegmentsSubtitle;

  /// No description provided for @settingsDynamicSegmentsEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'动态分段已开启'**
  String get settingsDynamicSegmentsEnabledTitle;

  /// No description provided for @settingsDynamicSegmentsEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'分段数将自动调整'**
  String get settingsDynamicSegmentsEnabledMessage;

  /// No description provided for @settingsDynamicSegmentsDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'动态分段已关闭'**
  String get settingsDynamicSegmentsDisabledTitle;

  /// No description provided for @settingsDynamicSegmentsDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'分段数将保持固定'**
  String get settingsDynamicSegmentsDisabledMessage;

  /// No description provided for @settingsMaxConcurrentTitle.
  ///
  /// In zh, this message translates to:
  /// **'最大同时下载任务数'**
  String get settingsMaxConcurrentTitle;

  /// No description provided for @settingsMaxConcurrentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'限制并发下载任务数量'**
  String get settingsMaxConcurrentSubtitle;

  /// No description provided for @settingsSegmentSpeedLimitTitle.
  ///
  /// In zh, this message translates to:
  /// **'分段限速'**
  String get settingsSegmentSpeedLimitTitle;

  /// No description provided for @settingsSegmentSpeedLimitSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'限制单分段速度'**
  String get settingsSegmentSpeedLimitSubtitle;

  /// No description provided for @settingsGlobalSpeedLimitTitle.
  ///
  /// In zh, this message translates to:
  /// **'全局限速'**
  String get settingsGlobalSpeedLimitTitle;

  /// No description provided for @settingsGlobalSpeedLimitSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'限制总下载带宽'**
  String get settingsGlobalSpeedLimitSubtitle;

  /// No description provided for @settingsHttpVersionTitle.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 协议'**
  String get settingsHttpVersionTitle;

  /// No description provided for @settingsHttpVersionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'为 HTTPS 下载选择协议策略'**
  String get settingsHttpVersionSubtitle;

  /// No description provided for @settingsHttpVersionAuto.
  ///
  /// In zh, this message translates to:
  /// **'自动（优先 HTTP/1.1）'**
  String get settingsHttpVersionAuto;

  /// No description provided for @settingsHttpVersionHttp1Only.
  ///
  /// In zh, this message translates to:
  /// **'强制 HTTP/1.1'**
  String get settingsHttpVersionHttp1Only;

  /// No description provided for @settingsHttpVersionHttp2Only.
  ///
  /// In zh, this message translates to:
  /// **'强制 HTTP/2'**
  String get settingsHttpVersionHttp2Only;

  /// No description provided for @settingsHttpVersionHttp3Only.
  ///
  /// In zh, this message translates to:
  /// **'强制 HTTP/3（自动回退）'**
  String get settingsHttpVersionHttp3Only;

  /// No description provided for @settingsDownloadCardHttpBadgeTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载卡片协议徽标'**
  String get settingsDownloadCardHttpBadgeTitle;

  /// No description provided for @settingsDownloadCardHttpBadgeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在每个下载卡片显示 HTTP 版本和目标连通性'**
  String get settingsDownloadCardHttpBadgeSubtitle;

  /// No description provided for @settingsDefaultUserAgentTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认 User-Agent'**
  String get settingsDefaultUserAgentTitle;

  /// No description provided for @settingsDefaultUserAgentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'任务未提供 User-Agent 时使用'**
  String get settingsDefaultUserAgentSubtitle;

  /// No description provided for @settingsDefaultUserAgentPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'输入默认 User-Agent'**
  String get settingsDefaultUserAgentPlaceholder;

  /// No description provided for @settingsUaPresetTitle.
  ///
  /// In zh, this message translates to:
  /// **'User-Agent 预设'**
  String get settingsUaPresetTitle;

  /// No description provided for @settingsUaPresetSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'快速切换浏览器伪装、手动输入或自定义 UA 包'**
  String get settingsUaPresetSubtitle;

  /// No description provided for @settingsUaPresetManualOption.
  ///
  /// In zh, this message translates to:
  /// **'手动输入（保持当前值）'**
  String get settingsUaPresetManualOption;

  /// No description provided for @settingsUaPresetBuiltinOption.
  ///
  /// In zh, this message translates to:
  /// **'内置 - {name}'**
  String settingsUaPresetBuiltinOption(Object name);

  /// No description provided for @settingsUaPresetCustomOption.
  ///
  /// In zh, this message translates to:
  /// **'自定义 - {name}'**
  String settingsUaPresetCustomOption(Object name);

  /// No description provided for @settingsUaCustomCreateTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建自定义 UA 包'**
  String get settingsUaCustomCreateTitle;

  /// No description provided for @settingsUaCustomCreateSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'保存后可随时切换使用'**
  String get settingsUaCustomCreateSubtitle;

  /// No description provided for @settingsUaCustomNamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get settingsUaCustomNamePlaceholder;

  /// No description provided for @settingsUaCustomValuePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'User-Agent 字符串'**
  String get settingsUaCustomValuePlaceholder;

  /// No description provided for @settingsUaCustomAddButton.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get settingsUaCustomAddButton;

  /// No description provided for @settingsUaCustomListTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义 UA 包'**
  String get settingsUaCustomListTitle;

  /// No description provided for @settingsUaCustomListEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无自定义 UA 包'**
  String get settingsUaCustomListEmpty;

  /// No description provided for @settingsUaCustomListCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个，可应用或删除'**
  String settingsUaCustomListCount(Object count);

  /// No description provided for @settingsUaCustomListHint.
  ///
  /// In zh, this message translates to:
  /// **'先在上方创建一个 UA 包'**
  String get settingsUaCustomListHint;

  /// No description provided for @settingsUaCustomEnabledButton.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get settingsUaCustomEnabledButton;

  /// No description provided for @settingsUaCustomApplyButton.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get settingsUaCustomApplyButton;

  /// No description provided for @settingsSpeedUnlimited.
  ///
  /// In zh, this message translates to:
  /// **'不限速'**
  String get settingsSpeedUnlimited;

  /// No description provided for @settingsSpeedTotal.
  ///
  /// In zh, this message translates to:
  /// **'总: {speed} KB/s'**
  String settingsSpeedTotal(Object speed);

  /// No description provided for @settingsPopupSaveFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法保存弹窗设置: {error}'**
  String settingsPopupSaveFailedMessage(Object error);

  /// No description provided for @settingsProxySection.
  ///
  /// In zh, this message translates to:
  /// **'代理设置'**
  String get settingsProxySection;

  /// No description provided for @settingsProxyEnableTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用代理'**
  String get settingsProxyEnableTitle;

  /// No description provided for @settingsProxyEnableSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'为下载启用代理'**
  String get settingsProxyEnableSubtitle;

  /// No description provided for @settingsProxySavedTitle.
  ///
  /// In zh, this message translates to:
  /// **'代理设置已保存'**
  String get settingsProxySavedTitle;

  /// No description provided for @settingsProxyEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'已启用代理: {host}:{port}'**
  String settingsProxyEnabledMessage(Object host, Object port);

  /// No description provided for @settingsProxyEnabledSystemMessage.
  ///
  /// In zh, this message translates to:
  /// **'已启用代理：跟随系统设置'**
  String get settingsProxyEnabledSystemMessage;

  /// No description provided for @settingsProxyDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'已禁用代理'**
  String get settingsProxyDisabledMessage;

  /// No description provided for @settingsProxyTypeTitle.
  ///
  /// In zh, this message translates to:
  /// **'代理类型'**
  String get settingsProxyTypeTitle;

  /// No description provided for @settingsProxyTypeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择代理协议'**
  String get settingsProxyTypeSubtitle;

  /// No description provided for @settingsProxyTypeSystem.
  ///
  /// In zh, this message translates to:
  /// **'system'**
  String get settingsProxyTypeSystem;

  /// No description provided for @settingsProxyTypeHttp.
  ///
  /// In zh, this message translates to:
  /// **'HTTP'**
  String get settingsProxyTypeHttp;

  /// No description provided for @settingsProxyTypeSocks5.
  ///
  /// In zh, this message translates to:
  /// **'SOCKS5'**
  String get settingsProxyTypeSocks5;

  /// No description provided for @settingsProxyServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'代理服务器'**
  String get settingsProxyServerTitle;

  /// No description provided for @settingsProxyServerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址和端口'**
  String get settingsProxyServerSubtitle;

  /// No description provided for @settingsProxyHostPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'代理地址 (如: 127.0.0.1)'**
  String get settingsProxyHostPlaceholder;

  /// No description provided for @settingsProxyAuthTitle.
  ///
  /// In zh, this message translates to:
  /// **'代理认证'**
  String get settingsProxyAuthTitle;

  /// No description provided for @settingsProxyAuthSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'需要用户名和密码'**
  String get settingsProxyAuthSubtitle;

  /// No description provided for @settingsProxyUsernameTitle.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get settingsProxyUsernameTitle;

  /// No description provided for @settingsProxyUsernameSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'代理账号用户名'**
  String get settingsProxyUsernameSubtitle;

  /// No description provided for @settingsProxyUsernamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get settingsProxyUsernamePlaceholder;

  /// No description provided for @settingsProxyPasswordTitle.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get settingsProxyPasswordTitle;

  /// No description provided for @settingsProxyPasswordSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'代理账号密码'**
  String get settingsProxyPasswordSubtitle;

  /// No description provided for @settingsProxyPasswordPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get settingsProxyPasswordPlaceholder;

  /// No description provided for @settingsProxyTipsTitle.
  ///
  /// In zh, this message translates to:
  /// **'代理配置提示'**
  String get settingsProxyTipsTitle;

  /// No description provided for @settingsProxyTipsSystem.
  ///
  /// In zh, this message translates to:
  /// **'• 自动使用系统配置的代理设置\n• 支持 Windows、macOS 和 Linux 系统代理\n• 配置后将应用到所有新的下载任务\n• 正在进行的下载不会受到影响'**
  String get settingsProxyTipsSystem;

  /// No description provided for @settingsProxyTipsHttp.
  ///
  /// In zh, this message translates to:
  /// **'• 使用 HTTP/HTTPS 代理协议\n• 配置后将应用到所有新的下载任务\n• 正在进行的下载不会受到影响\n• 支持用户名密码认证'**
  String get settingsProxyTipsHttp;

  /// No description provided for @settingsProxyTipsSocks5.
  ///
  /// In zh, this message translates to:
  /// **'• 使用 SOCKS5 代理协议\n• 需要安装 aiohttp-socks 库支持\n• 配置后将应用到所有新的下载任务\n• 正在进行的下载不会受到影响'**
  String get settingsProxyTipsSocks5;

  /// No description provided for @settingsProxyTipsDefault.
  ///
  /// In zh, this message translates to:
  /// **'• 支持系统代理、HTTP/HTTPS 和 SOCKS5 代理\n• 配置后将应用到所有新的下载任务\n• 正在进行的下载不会受到影响'**
  String get settingsProxyTipsDefault;

  /// No description provided for @settingsProxyTestButton.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get settingsProxyTestButton;

  /// No description provided for @settingsProxyTestingTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在测试...'**
  String get settingsProxyTestingTitle;

  /// No description provided for @settingsProxyTestingMessage.
  ///
  /// In zh, this message translates to:
  /// **'请稍候'**
  String get settingsProxyTestingMessage;

  /// No description provided for @settingsProxyTestSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get settingsProxyTestSuccessTitle;

  /// No description provided for @settingsProxyTestSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'代理服务器连接正常，可以正常使用'**
  String get settingsProxyTestSuccessMessage;

  /// No description provided for @settingsProxyTestFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get settingsProxyTestFailedTitle;

  /// No description provided for @settingsProxyTestFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到代理服务器，请检查配置'**
  String get settingsProxyTestFailedMessage;

  /// No description provided for @settingsProxyTestErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试失败'**
  String get settingsProxyTestErrorTitle;

  /// No description provided for @settingsProxyTestErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'代理连接测试失败: {error}'**
  String settingsProxyTestErrorMessage(Object error);

  /// No description provided for @settingsProxyErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'配置错误'**
  String get settingsProxyErrorTitle;

  /// No description provided for @settingsProxyErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'请先输入代理服务器地址'**
  String get settingsProxyErrorMessage;

  /// No description provided for @settingsKernelSection.
  ///
  /// In zh, this message translates to:
  /// **'下载内核'**
  String get settingsKernelSection;

  /// No description provided for @settingsKernelCurrentTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前内核'**
  String get settingsKernelCurrentTitle;

  /// No description provided for @settingsKernelOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get settingsKernelOnline;

  /// No description provided for @settingsKernelOffline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get settingsKernelOffline;

  /// No description provided for @settingsKernelNsfxTitle.
  ///
  /// In zh, this message translates to:
  /// **'NSFX'**
  String get settingsKernelNsfxTitle;

  /// No description provided for @settingsKernelNsfxSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'切换到新内核'**
  String get settingsKernelNsfxSubtitle;

  /// No description provided for @settingsKernelNsfxHint.
  ///
  /// In zh, this message translates to:
  /// **'NSFX Kernel: 高效 | 简洁 | 新思路'**
  String get settingsKernelNsfxHint;

  /// No description provided for @settingsKernelSwitchedTitle.
  ///
  /// In zh, this message translates to:
  /// **'内核已切换'**
  String get settingsKernelSwitchedTitle;

  /// No description provided for @settingsKernelSwitchedMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前使用: {kernelName}'**
  String settingsKernelSwitchedMessage(Object kernelName);

  /// No description provided for @settingsKernelSwitchFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'切换失败'**
  String get settingsKernelSwitchFailedTitle;

  /// No description provided for @settingsKernelSwitchFailedNewMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法启动新内核，请稍后重试'**
  String get settingsKernelSwitchFailedNewMessage;

  /// No description provided for @settingsStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统状态'**
  String get settingsStatusTitle;

  /// No description provided for @settingsStatusKernelNsfx.
  ///
  /// In zh, this message translates to:
  /// **'NSFX Kernel'**
  String get settingsStatusKernelNsfx;

  /// No description provided for @settingsStatusBrowserExtension.
  ///
  /// In zh, this message translates to:
  /// **'Browser Extension'**
  String get settingsStatusBrowserExtension;

  /// No description provided for @settingsModeDescriptionAuto.
  ///
  /// In zh, this message translates to:
  /// **'智能动态分段，根据文件大小自动优化 (推荐)'**
  String get settingsModeDescriptionAuto;

  /// No description provided for @settingsModeDescriptionThreadsOnly.
  ///
  /// In zh, this message translates to:
  /// **'手动设置线程数，分段数自动计算'**
  String get settingsModeDescriptionThreadsOnly;

  /// No description provided for @settingsModeDescriptionSegmentsOnly.
  ///
  /// In zh, this message translates to:
  /// **'手动设置分段数，线程数自动计算'**
  String get settingsModeDescriptionSegmentsOnly;

  /// No description provided for @settingsModeDescriptionManual.
  ///
  /// In zh, this message translates to:
  /// **'完全手动控制，适合高级用户'**
  String get settingsModeDescriptionManual;

  /// No description provided for @settingsModeDescriptionUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知模式'**
  String get settingsModeDescriptionUnknown;

  /// No description provided for @settingsDeveloperSection.
  ///
  /// In zh, this message translates to:
  /// **'开发者选项'**
  String get settingsDeveloperSection;

  /// No description provided for @settingsDeveloperModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'开发者模式'**
  String get settingsDeveloperModeTitle;

  /// No description provided for @settingsDeveloperModeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启用调试和诊断功能'**
  String get settingsDeveloperModeSubtitle;

  /// No description provided for @settingsDeveloperModeHint.
  ///
  /// In zh, this message translates to:
  /// **'开发者模式已启用，请切换到\"开发者\"标签页进行详细配置'**
  String get settingsDeveloperModeHint;

  /// No description provided for @settingsDeveloperModeEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'开发者模式已开启'**
  String get settingsDeveloperModeEnabledTitle;

  /// No description provided for @settingsDeveloperModeEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'已启用高级调试功能'**
  String get settingsDeveloperModeEnabledMessage;

  /// No description provided for @settingsDeveloperModeDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'开发者模式已关闭'**
  String get settingsDeveloperModeDisabledTitle;

  /// No description provided for @settingsDeveloperModeDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'已禁用高级调试功能'**
  String get settingsDeveloperModeDisabledMessage;

  /// No description provided for @settingsDeveloperPageVisibilityTitle.
  ///
  /// In zh, this message translates to:
  /// **'调试页面显示设置'**
  String get settingsDeveloperPageVisibilityTitle;

  /// No description provided for @settingsDeveloperShowLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示日志页面'**
  String get settingsDeveloperShowLogTitle;

  /// No description provided for @settingsDeveloperShowLogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在导航栏显示日志查看器'**
  String get settingsDeveloperShowLogSubtitle;

  /// No description provided for @settingsDeveloperShowStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示状态页面'**
  String get settingsDeveloperShowStatusTitle;

  /// No description provided for @settingsDeveloperShowStatusSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在导航栏显示系统状态监控'**
  String get settingsDeveloperShowStatusSubtitle;

  /// No description provided for @settingsDeveloperShowOnlineStatsTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示在线统计页面'**
  String get settingsDeveloperShowOnlineStatsTitle;

  /// No description provided for @settingsDeveloperShowOnlineStatsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在导航栏显示在线用户统计'**
  String get settingsDeveloperShowOnlineStatsSubtitle;

  /// No description provided for @settingsDeveloperShowConnectionDebugTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示连接调试页面'**
  String get settingsDeveloperShowConnectionDebugTitle;

  /// No description provided for @settingsDeveloperShowConnectionDebugSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在导航栏显示连接诊断工具'**
  String get settingsDeveloperShowConnectionDebugSubtitle;

  /// No description provided for @settingsDeveloperPageHint.
  ///
  /// In zh, this message translates to:
  /// **'调试页面会占用系统资源，建议仅在需要时启用'**
  String get settingsDeveloperPageHint;

  /// No description provided for @settingsDangerCleanTempTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理临时文件'**
  String get settingsDangerCleanTempTitle;

  /// No description provided for @settingsDangerCleanTempSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描并删除下载目录中的 .temp 临时文件'**
  String get settingsDangerCleanTempSubtitle;

  /// No description provided for @settingsDangerCleanTempButton.
  ///
  /// In zh, this message translates to:
  /// **'清理临时文件'**
  String get settingsDangerCleanTempButton;

  /// No description provided for @settingsDangerClearDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除所有数据'**
  String get settingsDangerClearDataTitle;

  /// No description provided for @settingsDangerClearDataSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'删除所有下载任务和历史记录'**
  String get settingsDangerClearDataSubtitle;

  /// No description provided for @settingsDangerClearDataButton.
  ///
  /// In zh, this message translates to:
  /// **'清除数据'**
  String get settingsDangerClearDataButton;

  /// No description provided for @settingsDangerConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认清除'**
  String get settingsDangerConfirmTitle;

  /// No description provided for @settingsDangerConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要清除所有下载任务和历史记录吗？此操作不可恢复。'**
  String get settingsDangerConfirmMessage;

  /// No description provided for @settingsDangerConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'确认清除'**
  String get settingsDangerConfirmButton;

  /// No description provided for @settingsDangerClearingTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在清除...'**
  String get settingsDangerClearingTitle;

  /// No description provided for @settingsDangerClearingMessage.
  ///
  /// In zh, this message translates to:
  /// **'请稍候'**
  String get settingsDangerClearingMessage;

  /// No description provided for @settingsDangerClearedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已清除'**
  String get settingsDangerClearedTitle;

  /// No description provided for @settingsDangerClearedMessage.
  ///
  /// In zh, this message translates to:
  /// **'所有下载任务和历史记录已清除'**
  String get settingsDangerClearedMessage;

  /// No description provided for @settingsDangerClearFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'清除失败'**
  String get settingsDangerClearFailedTitle;

  /// No description provided for @settingsDangerClearFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法清除数据，请确保下载核心正在运行'**
  String get settingsDangerClearFailedMessage;

  /// No description provided for @settingsUserLoading.
  ///
  /// In zh, this message translates to:
  /// **'获取中...'**
  String get settingsUserLoading;

  /// No description provided for @settingsUserLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'获取失败'**
  String get settingsUserLoadFailed;

  /// No description provided for @settingsUserUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知用户'**
  String get settingsUserUnknown;

  /// No description provided for @appearanceWindowSizeSection.
  ///
  /// In zh, this message translates to:
  /// **'窗口大小'**
  String get appearanceWindowSizeSection;

  /// No description provided for @appearanceWindowRememberTitle.
  ///
  /// In zh, this message translates to:
  /// **'记忆窗口大小'**
  String get appearanceWindowRememberTitle;

  /// No description provided for @appearanceWindowRememberSubtitleOn.
  ///
  /// In zh, this message translates to:
  /// **'启动时使用上次关闭时的窗口大小'**
  String get appearanceWindowRememberSubtitleOn;

  /// No description provided for @appearanceWindowRememberSubtitleOff.
  ///
  /// In zh, this message translates to:
  /// **'启动时使用默认窗口大小'**
  String get appearanceWindowRememberSubtitleOff;

  /// No description provided for @appearanceWindowDefaultWidthTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认窗口宽度'**
  String get appearanceWindowDefaultWidthTitle;

  /// No description provided for @appearanceWindowDefaultWidthSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启动默认宽度 (600-{max})'**
  String appearanceWindowDefaultWidthSubtitle(Object max);

  /// No description provided for @appearanceWindowDefaultHeightTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认窗口高度'**
  String get appearanceWindowDefaultHeightTitle;

  /// No description provided for @appearanceWindowDefaultHeightSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启动默认高度 (400-{max})'**
  String appearanceWindowDefaultHeightSubtitle(Object max);

  /// No description provided for @appearanceWindowSaveTitle.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get appearanceWindowSaveTitle;

  /// No description provided for @appearanceWindowSaveMessage.
  ///
  /// In zh, this message translates to:
  /// **'已将当前窗口大小设为默认 ({width}×{height})'**
  String appearanceWindowSaveMessage(Object width, Object height);

  /// No description provided for @appearanceWindowSaveButton.
  ///
  /// In zh, this message translates to:
  /// **'使用当前大小 ({width}×{height})'**
  String appearanceWindowSaveButton(Object width, Object height);

  /// No description provided for @appearanceWindowResetTitle.
  ///
  /// In zh, this message translates to:
  /// **'已重置'**
  String get appearanceWindowResetTitle;

  /// No description provided for @appearanceWindowResetMessage.
  ///
  /// In zh, this message translates to:
  /// **'已重置默认窗口大小为 889×586'**
  String get appearanceWindowResetMessage;

  /// No description provided for @appearanceWindowResetButton.
  ///
  /// In zh, this message translates to:
  /// **'重置为默认'**
  String get appearanceWindowResetButton;

  /// No description provided for @appearanceWindowApplyTitle.
  ///
  /// In zh, this message translates to:
  /// **'已应用'**
  String get appearanceWindowApplyTitle;

  /// No description provided for @appearanceWindowApplyMessage.
  ///
  /// In zh, this message translates to:
  /// **'窗口大小已调整为 {width}×{height}'**
  String appearanceWindowApplyMessage(Object width, Object height);

  /// No description provided for @appearanceWindowApplyButton.
  ///
  /// In zh, this message translates to:
  /// **'立即应用默认大小 ({width}×{height})'**
  String appearanceWindowApplyButton(Object width, Object height);

  /// No description provided for @appearanceWindowRememberHintOn.
  ///
  /// In zh, this message translates to:
  /// **'当前启用记忆模式，应用会记住上次关闭时的窗口大小'**
  String get appearanceWindowRememberHintOn;

  /// No description provided for @appearanceWindowRememberHintOff.
  ///
  /// In zh, this message translates to:
  /// **'已启用默认大小模式，应用将使用设定尺寸'**
  String get appearanceWindowRememberHintOff;

  /// No description provided for @appearanceUiScaleSection.
  ///
  /// In zh, this message translates to:
  /// **'UI 缩放'**
  String get appearanceUiScaleSection;

  /// No description provided for @appearanceUiScaleTitle.
  ///
  /// In zh, this message translates to:
  /// **'界面缩放比例'**
  String get appearanceUiScaleTitle;

  /// No description provided for @appearanceUiScaleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'调整高分屏 UI 缩放比例 (50%-200%)'**
  String get appearanceUiScaleSubtitle;

  /// No description provided for @appearanceUiScaleResetTitle.
  ///
  /// In zh, this message translates to:
  /// **'已重置'**
  String get appearanceUiScaleResetTitle;

  /// No description provided for @appearanceUiScaleResetMessage.
  ///
  /// In zh, this message translates to:
  /// **'UI 缩放已重置为 100%'**
  String get appearanceUiScaleResetMessage;

  /// No description provided for @appearanceUiScaleResetButton.
  ///
  /// In zh, this message translates to:
  /// **'重置为100%'**
  String get appearanceUiScaleResetButton;

  /// No description provided for @appearanceUiScaleApplyTitle.
  ///
  /// In zh, this message translates to:
  /// **'已应用'**
  String get appearanceUiScaleApplyTitle;

  /// No description provided for @appearanceUiScaleApplyMessage.
  ///
  /// In zh, this message translates to:
  /// **'UI 缩放已设置为 125%（4K 推荐）'**
  String get appearanceUiScaleApplyMessage;

  /// No description provided for @appearanceUiScale4kButton.
  ///
  /// In zh, this message translates to:
  /// **'4K推荐 (125%)'**
  String get appearanceUiScale4kButton;

  /// No description provided for @appearanceUiScaleHint.
  ///
  /// In zh, this message translates to:
  /// **'调整此设置可以让应用在高分辨率屏幕上显示更清晰。4K屏幕推荐125%-150%'**
  String get appearanceUiScaleHint;

  /// No description provided for @appearanceFontSection.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get appearanceFontSection;

  /// No description provided for @appearanceFontTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用字体'**
  String get appearanceFontTitle;

  /// No description provided for @appearanceFontSystemSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用系统默认字体'**
  String get appearanceFontSystemSubtitle;

  /// No description provided for @appearanceFontCurrentSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前字体: {font}'**
  String appearanceFontCurrentSubtitle(Object font);

  /// No description provided for @appearanceFontSystemLabel.
  ///
  /// In zh, this message translates to:
  /// **'system'**
  String get appearanceFontSystemLabel;

  /// No description provided for @appearanceFontImportButton.
  ///
  /// In zh, this message translates to:
  /// **'导入字体'**
  String get appearanceFontImportButton;

  /// No description provided for @appearanceFontDeleteButton.
  ///
  /// In zh, this message translates to:
  /// **'删除当前字体'**
  String get appearanceFontDeleteButton;

  /// No description provided for @appearanceFontHint.
  ///
  /// In zh, this message translates to:
  /// **'支持导入 .ttf 和 .otf 格式的字体文件'**
  String get appearanceFontHint;

  /// No description provided for @appearanceFontChangedTitle.
  ///
  /// In zh, this message translates to:
  /// **'字体已更改'**
  String get appearanceFontChangedTitle;

  /// No description provided for @appearanceFontChangedMessage.
  ///
  /// In zh, this message translates to:
  /// **'字体已应用'**
  String get appearanceFontChangedMessage;

  /// No description provided for @appearanceFontImportDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择字体文件'**
  String get appearanceFontImportDialogTitle;

  /// No description provided for @appearanceFontImportingTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在导入字体...'**
  String get appearanceFontImportingTitle;

  /// No description provided for @appearanceFontImportingMessage.
  ///
  /// In zh, this message translates to:
  /// **'请稍候'**
  String get appearanceFontImportingMessage;

  /// No description provided for @appearanceFontImportSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入成功'**
  String get appearanceFontImportSuccessTitle;

  /// No description provided for @appearanceFontImportSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'字体导入成功'**
  String get appearanceFontImportSuccessMessage;

  /// No description provided for @appearanceFontImportFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get appearanceFontImportFailedTitle;

  /// No description provided for @appearanceFontImportFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法导入字体文件，请检查格式'**
  String get appearanceFontImportFailedMessage;

  /// No description provided for @appearanceFontImportFailedWithErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'导入失败: {error}'**
  String appearanceFontImportFailedWithErrorMessage(Object error);

  /// No description provided for @appearanceFontDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get appearanceFontDeleteConfirmTitle;

  /// No description provided for @appearanceFontDeleteConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除字体 \"{fontName}\" 吗？'**
  String appearanceFontDeleteConfirmMessage(Object fontName);

  /// No description provided for @appearanceFontDeleteCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get appearanceFontDeleteCancelButton;

  /// No description provided for @appearanceFontDeleteConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get appearanceFontDeleteConfirmButton;

  /// No description provided for @appearanceFontDeleteSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除成功'**
  String get appearanceFontDeleteSuccessTitle;

  /// No description provided for @appearanceFontDeleteSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'字体已删除'**
  String get appearanceFontDeleteSuccessMessage;

  /// No description provided for @appearanceFontDeleteFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get appearanceFontDeleteFailedTitle;

  /// No description provided for @appearanceFontDeleteFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法删除字体'**
  String get appearanceFontDeleteFailedMessage;

  /// No description provided for @appearanceFontPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择字体'**
  String get appearanceFontPickerTitle;

  /// No description provided for @appearanceFontPickerSearchPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'搜索字体...'**
  String get appearanceFontPickerSearchPlaceholder;

  /// No description provided for @appearanceFontPickerCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个字体'**
  String appearanceFontPickerCount(Object count);

  /// No description provided for @appearanceFontPickerFilteredLabel.
  ///
  /// In zh, this message translates to:
  /// **'(已过滤)'**
  String get appearanceFontPickerFilteredLabel;

  /// No description provided for @appearanceFontPickerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的字体'**
  String get appearanceFontPickerEmpty;

  /// No description provided for @appearanceFontPickerRecommended.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get appearanceFontPickerRecommended;

  /// No description provided for @appearanceFontPickerCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get appearanceFontPickerCancel;

  /// No description provided for @appearanceWindowEffectsSection.
  ///
  /// In zh, this message translates to:
  /// **'窗口效果'**
  String get appearanceWindowEffectsSection;

  /// No description provided for @appearanceWindowEffectsEnableTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用窗口特效'**
  String get appearanceWindowEffectsEnableTitle;

  /// No description provided for @appearanceWindowEffectsEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'已启用窗口特效'**
  String get appearanceWindowEffectsEnabledSubtitle;

  /// No description provided for @appearanceWindowEffectsDisabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'窗口特效已关闭（性能模式）'**
  String get appearanceWindowEffectsDisabledSubtitle;

  /// No description provided for @appearanceWindowEffectsEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'窗口特效已启用'**
  String get appearanceWindowEffectsEnabledTitle;

  /// No description provided for @appearanceWindowEffectsDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'窗口特效已关闭'**
  String get appearanceWindowEffectsDisabledTitle;

  /// No description provided for @appearanceWindowEffectsEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'窗口效果已开启'**
  String get appearanceWindowEffectsEnabledMessage;

  /// No description provided for @appearanceWindowEffectsDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'已切换为纯色背景以提升性能'**
  String get appearanceWindowEffectsDisabledMessage;

  /// No description provided for @appearanceWindowEffectsTypeTitle.
  ///
  /// In zh, this message translates to:
  /// **'效果类型'**
  String get appearanceWindowEffectsTypeTitle;

  /// No description provided for @appearanceWindowEffectSwitchedTitle.
  ///
  /// In zh, this message translates to:
  /// **'效果已切换'**
  String get appearanceWindowEffectSwitchedTitle;

  /// No description provided for @appearanceWindowEffectAcrylic.
  ///
  /// In zh, this message translates to:
  /// **'acrylic'**
  String get appearanceWindowEffectAcrylic;

  /// No description provided for @appearanceWindowEffectBlur.
  ///
  /// In zh, this message translates to:
  /// **'模糊'**
  String get appearanceWindowEffectBlur;

  /// No description provided for @appearanceWindowEffectMica.
  ///
  /// In zh, this message translates to:
  /// **'mica_main'**
  String get appearanceWindowEffectMica;

  /// No description provided for @appearanceWindowEffectMicaAlt.
  ///
  /// In zh, this message translates to:
  /// **'Mica Alt'**
  String get appearanceWindowEffectMicaAlt;

  /// No description provided for @appearanceWindowEffectsAcrylicOpacityTitle.
  ///
  /// In zh, this message translates to:
  /// **'亚克力透明度'**
  String get appearanceWindowEffectsAcrylicOpacityTitle;

  /// No description provided for @appearanceWindowEffectsAcrylicOpacityHint.
  ///
  /// In zh, this message translates to:
  /// **'调整背景不透明度 (0-255，越小越透明)'**
  String get appearanceWindowEffectsAcrylicOpacityHint;

  /// No description provided for @appearanceWindowEffectsAcrylicOpacityMicaHint.
  ///
  /// In zh, this message translates to:
  /// **'Mica 效果不支持调整透明度'**
  String get appearanceWindowEffectsAcrylicOpacityMicaHint;

  /// No description provided for @appearanceWindowEffectsDragSuspendTitle.
  ///
  /// In zh, this message translates to:
  /// **'拖动时禁用特效'**
  String get appearanceWindowEffectsDragSuspendTitle;

  /// No description provided for @appearanceWindowEffectsDragSuspendEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'拖动窗口时临时禁用特效，确保流畅拖动'**
  String get appearanceWindowEffectsDragSuspendEnabledSubtitle;

  /// No description provided for @appearanceWindowEffectsDragSuspendDisabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'拖动时保持特效（Win10 可能卡顿）'**
  String get appearanceWindowEffectsDragSuspendDisabledSubtitle;

  /// No description provided for @appearanceWindowEffectsRoundedCornersTitle.
  ///
  /// In zh, this message translates to:
  /// **'窗口圆角'**
  String get appearanceWindowEffectsRoundedCornersTitle;

  /// No description provided for @appearanceWindowEffectsRoundedCornersEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启用窗口圆角裁切（Win10 以及 Win11 的亚克力/模糊模式会使用自定义裁切）'**
  String get appearanceWindowEffectsRoundedCornersEnabledSubtitle;

  /// No description provided for @appearanceWindowEffectsRoundedCornersDisabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'使用直角窗口边缘'**
  String get appearanceWindowEffectsRoundedCornersDisabledSubtitle;

  /// No description provided for @appearanceWindowEffectsMicaHint.
  ///
  /// In zh, this message translates to:
  /// **'Mica 效果仅在 Windows 11 上可用，会自动采用系统主题色'**
  String get appearanceWindowEffectsMicaHint;

  /// No description provided for @appearanceWindowEffectsAcrylicHint.
  ///
  /// In zh, this message translates to:
  /// **'亚克力效果会消耗额外的GPU资源，如果感觉卡顿可以关闭此选项'**
  String get appearanceWindowEffectsAcrylicHint;

  /// No description provided for @appearanceWindowEffectsDisabledHint.
  ///
  /// In zh, this message translates to:
  /// **'为获得最佳性能已关闭特效'**
  String get appearanceWindowEffectsDisabledHint;

  /// No description provided for @appearanceEffectNone.
  ///
  /// In zh, this message translates to:
  /// **'无效果'**
  String get appearanceEffectNone;

  /// No description provided for @appearanceEffectBlur.
  ///
  /// In zh, this message translates to:
  /// **'模糊效果 - 简单的背景模糊'**
  String get appearanceEffectBlur;

  /// No description provided for @appearanceEffectAcrylic.
  ///
  /// In zh, this message translates to:
  /// **'亚克力效果 - 半透明模糊背景'**
  String get appearanceEffectAcrylic;

  /// No description provided for @appearanceEffectMica.
  ///
  /// In zh, this message translates to:
  /// **'Mica 效果 - Windows 11 原生云母效果'**
  String get appearanceEffectMica;

  /// No description provided for @appearanceEffectMicaAlt.
  ///
  /// In zh, this message translates to:
  /// **'Mica Alt 效果 - Windows 11 临时窗口云母效果'**
  String get appearanceEffectMicaAlt;

  /// No description provided for @appearanceEffectUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知效果'**
  String get appearanceEffectUnknown;

  /// No description provided for @appearanceSidebarSection.
  ///
  /// In zh, this message translates to:
  /// **'侧边栏'**
  String get appearanceSidebarSection;

  /// No description provided for @appearanceSidebarDefaultTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认展开状态'**
  String get appearanceSidebarDefaultTitle;

  /// No description provided for @appearanceSidebarDefaultSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启动时侧边栏默认状态'**
  String get appearanceSidebarDefaultSubtitle;

  /// No description provided for @appearanceSidebarExpandedLabel.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get appearanceSidebarExpandedLabel;

  /// No description provided for @appearanceSidebarCollapsedLabel.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get appearanceSidebarCollapsedLabel;

  /// No description provided for @appearanceSidebarSavedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get appearanceSidebarSavedTitle;

  /// No description provided for @appearanceSidebarSavedMessage.
  ///
  /// In zh, this message translates to:
  /// **'侧边栏默认状态已设为 {state}'**
  String appearanceSidebarSavedMessage(Object state);

  /// No description provided for @appearanceNotificationSection.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get appearanceNotificationSection;

  /// No description provided for @appearanceNotificationEnableTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用通知'**
  String get appearanceNotificationEnableTitle;

  /// No description provided for @appearanceNotificationEnableSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'显示下载完成和错误通知'**
  String get appearanceNotificationEnableSubtitle;

  /// No description provided for @appearanceNotificationSchemeTitle.
  ///
  /// In zh, this message translates to:
  /// **'配色方案'**
  String get appearanceNotificationSchemeTitle;

  /// No description provided for @appearanceNotificationSchemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随主题'**
  String get appearanceNotificationSchemeSystem;

  /// No description provided for @appearanceNotificationSchemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色系'**
  String get appearanceNotificationSchemeLight;

  /// No description provided for @appearanceNotificationSchemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色系'**
  String get appearanceNotificationSchemeDark;

  /// No description provided for @appearanceNotificationSchemeFluent2.
  ///
  /// In zh, this message translates to:
  /// **'Fluent 2 色系（推荐）'**
  String get appearanceNotificationSchemeFluent2;

  /// No description provided for @appearanceNotificationSchemeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get appearanceNotificationSchemeUnknown;

  /// No description provided for @appearanceNotificationSchemeDefaultOption.
  ///
  /// In zh, this message translates to:
  /// **'dark'**
  String get appearanceNotificationSchemeDefaultOption;

  /// No description provided for @appearanceNotificationSchemeLightOption.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get appearanceNotificationSchemeLightOption;

  /// No description provided for @appearanceNotificationSchemeDarkOption.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get appearanceNotificationSchemeDarkOption;

  /// No description provided for @appearanceNotificationSchemeFluent2Option.
  ///
  /// In zh, this message translates to:
  /// **'Fluent 2'**
  String get appearanceNotificationSchemeFluent2Option;

  /// No description provided for @appearanceNotificationPositionTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示位置'**
  String get appearanceNotificationPositionTitle;

  /// No description provided for @appearanceNotificationPositionTopRight.
  ///
  /// In zh, this message translates to:
  /// **'右上角（标题栏下方）'**
  String get appearanceNotificationPositionTopRight;

  /// No description provided for @appearanceNotificationPositionBottomRight.
  ///
  /// In zh, this message translates to:
  /// **'右下角'**
  String get appearanceNotificationPositionBottomRight;

  /// No description provided for @appearanceNotificationPositionUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get appearanceNotificationPositionUnknown;

  /// No description provided for @appearanceNotificationPositionTopRightOption.
  ///
  /// In zh, this message translates to:
  /// **'右上角'**
  String get appearanceNotificationPositionTopRightOption;

  /// No description provided for @appearanceNotificationPositionBottomRightOption.
  ///
  /// In zh, this message translates to:
  /// **'右下角'**
  String get appearanceNotificationPositionBottomRightOption;

  /// No description provided for @appearanceNotificationPerformanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'渲染性能模式'**
  String get appearanceNotificationPerformanceTitle;

  /// No description provided for @appearanceNotificationPerformanceOptionPerformance.
  ///
  /// In zh, this message translates to:
  /// **'balanced'**
  String get appearanceNotificationPerformanceOptionPerformance;

  /// No description provided for @appearanceNotificationPerformanceOptionBalanced.
  ///
  /// In zh, this message translates to:
  /// **'平衡'**
  String get appearanceNotificationPerformanceOptionBalanced;

  /// No description provided for @appearanceNotificationPerformanceOptionQuality.
  ///
  /// In zh, this message translates to:
  /// **'高质量'**
  String get appearanceNotificationPerformanceOptionQuality;

  /// No description provided for @appearanceNotificationPerformanceHint.
  ///
  /// In zh, this message translates to:
  /// **'毛玻璃效果会影响动画流畅度。如果感觉卡顿，建议选择\"性能优先\"模式'**
  String get appearanceNotificationPerformanceHint;

  /// No description provided for @appearanceNotificationPreviewButtonTitle.
  ///
  /// In zh, this message translates to:
  /// **'预览通知'**
  String get appearanceNotificationPreviewButtonTitle;

  /// No description provided for @appearanceNotificationPreviewButtonSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击预览当前配色'**
  String get appearanceNotificationPreviewButtonSubtitle;

  /// No description provided for @appearanceNotificationPreviewButton.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get appearanceNotificationPreviewButton;

  /// No description provided for @appearanceNotificationPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'配色预览'**
  String get appearanceNotificationPreviewTitle;

  /// No description provided for @appearanceNotificationPreviewSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'成功通知'**
  String get appearanceNotificationPreviewSuccessTitle;

  /// No description provided for @appearanceNotificationPreviewSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'操作成功完成'**
  String get appearanceNotificationPreviewSuccessMessage;

  /// No description provided for @appearanceNotificationPreviewWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'警告通知'**
  String get appearanceNotificationPreviewWarningTitle;

  /// No description provided for @appearanceNotificationPreviewWarningMessage.
  ///
  /// In zh, this message translates to:
  /// **'请注意此操作的影响'**
  String get appearanceNotificationPreviewWarningMessage;

  /// No description provided for @appearanceNotificationPreviewErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'错误通知'**
  String get appearanceNotificationPreviewErrorTitle;

  /// No description provided for @appearanceNotificationPreviewErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'操作失败，请重试'**
  String get appearanceNotificationPreviewErrorMessage;

  /// No description provided for @appearanceNotificationPreviewInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'信息通知'**
  String get appearanceNotificationPreviewInfoTitle;

  /// No description provided for @appearanceNotificationPreviewInfoMessage.
  ///
  /// In zh, this message translates to:
  /// **'这是一条提示信息'**
  String get appearanceNotificationPreviewInfoMessage;

  /// No description provided for @appearanceNotificationTestTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试通知'**
  String get appearanceNotificationTestTitle;

  /// No description provided for @appearanceNotificationTestMessage.
  ///
  /// In zh, this message translates to:
  /// **'这是一条测试通知'**
  String get appearanceNotificationTestMessage;

  /// No description provided for @appearancePerformanceModePerformance.
  ///
  /// In zh, this message translates to:
  /// **'性能优先（无毛玻璃，推荐）'**
  String get appearancePerformanceModePerformance;

  /// No description provided for @appearancePerformanceModeBalanced.
  ///
  /// In zh, this message translates to:
  /// **'平衡（轻度毛玻璃）'**
  String get appearancePerformanceModeBalanced;

  /// No description provided for @appearancePerformanceModeQuality.
  ///
  /// In zh, this message translates to:
  /// **'高质量（完整毛玻璃效果）'**
  String get appearancePerformanceModeQuality;

  /// No description provided for @appearancePerformanceModeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get appearancePerformanceModeUnknown;

  /// No description provided for @appearanceSegmentsModeTitle.
  ///
  /// In zh, this message translates to:
  /// **'分段进度显示模式'**
  String get appearanceSegmentsModeTitle;

  /// No description provided for @appearanceSegmentsModeNoneOption.
  ///
  /// In zh, this message translates to:
  /// **'merged'**
  String get appearanceSegmentsModeNoneOption;

  /// No description provided for @appearanceSegmentsModeMergedOption.
  ///
  /// In zh, this message translates to:
  /// **'合并条'**
  String get appearanceSegmentsModeMergedOption;

  /// No description provided for @appearanceSegmentsModeListOption.
  ///
  /// In zh, this message translates to:
  /// **'分段列表'**
  String get appearanceSegmentsModeListOption;

  /// No description provided for @appearanceSegmentsModeNoneDescription.
  ///
  /// In zh, this message translates to:
  /// **'简洁模式：不显示分段信息'**
  String get appearanceSegmentsModeNoneDescription;

  /// No description provided for @appearanceSegmentsModeMergedDescription.
  ///
  /// In zh, this message translates to:
  /// **'合并模式：所有分段合并在一个进度条中显示'**
  String get appearanceSegmentsModeMergedDescription;

  /// No description provided for @appearanceSegmentsModeListDescription.
  ///
  /// In zh, this message translates to:
  /// **'列表模式：每个分段单独一行显示'**
  String get appearanceSegmentsModeListDescription;

  /// No description provided for @appearanceSegmentsDefaultExpandedTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认展开分段信息'**
  String get appearanceSegmentsDefaultExpandedTitle;

  /// No description provided for @appearanceSegmentsDefaultExpandedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'默认展开显示分段详情'**
  String get appearanceSegmentsDefaultExpandedSubtitle;

  /// No description provided for @appearanceSegmentsMaxVisibleTitle.
  ///
  /// In zh, this message translates to:
  /// **'默认显示分段数量'**
  String get appearanceSegmentsMaxVisibleTitle;

  /// No description provided for @appearanceSegmentsMaxVisibleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'展开时显示分段数量 (1-32)'**
  String get appearanceSegmentsMaxVisibleSubtitle;

  /// No description provided for @appearanceDownloadListSection.
  ///
  /// In zh, this message translates to:
  /// **'下载列表显示'**
  String get appearanceDownloadListSection;

  /// No description provided for @appearanceSpeedChartTitle.
  ///
  /// In zh, this message translates to:
  /// **'速度曲线背景'**
  String get appearanceSpeedChartTitle;

  /// No description provided for @appearanceSpeedChartSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在下载卡片上显示实时速度曲线'**
  String get appearanceSpeedChartSubtitle;

  /// No description provided for @appearanceChartFrostTitle.
  ///
  /// In zh, this message translates to:
  /// **'曲线毛玻璃'**
  String get appearanceChartFrostTitle;

  /// No description provided for @appearanceChartFrostSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在曲线上方叠加毛玻璃效果'**
  String get appearanceChartFrostSubtitle;

  /// No description provided for @appearanceChartPositionTitle.
  ///
  /// In zh, this message translates to:
  /// **'曲线位置'**
  String get appearanceChartPositionTitle;

  /// No description provided for @appearanceChartPositionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'调整曲线在卡片中的高度'**
  String get appearanceChartPositionSubtitle;

  /// No description provided for @appearanceChartPositionLow.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get appearanceChartPositionLow;

  /// No description provided for @appearanceChartPositionMid.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get appearanceChartPositionMid;

  /// No description provided for @appearanceChartPositionHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get appearanceChartPositionHigh;

  /// No description provided for @appearanceChartColorTitle.
  ///
  /// In zh, this message translates to:
  /// **'曲线颜色'**
  String get appearanceChartColorTitle;

  /// No description provided for @appearanceChartColorSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义速度曲线的颜色'**
  String get appearanceChartColorSubtitle;

  /// No description provided for @appearanceChartColorBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝色'**
  String get appearanceChartColorBlue;

  /// No description provided for @appearanceChartColorCyan.
  ///
  /// In zh, this message translates to:
  /// **'青色'**
  String get appearanceChartColorCyan;

  /// No description provided for @appearanceChartColorPurple.
  ///
  /// In zh, this message translates to:
  /// **'紫色'**
  String get appearanceChartColorPurple;

  /// No description provided for @appearanceChartColorGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿色'**
  String get appearanceChartColorGreen;

  /// No description provided for @appearanceChartColorPink.
  ///
  /// In zh, this message translates to:
  /// **'粉色'**
  String get appearanceChartColorPink;

  /// No description provided for @appearanceChartColorOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙色'**
  String get appearanceChartColorOrange;

  /// No description provided for @developerSectionDebugTools.
  ///
  /// In zh, this message translates to:
  /// **'调试工具'**
  String get developerSectionDebugTools;

  /// No description provided for @developerSectionTestTools.
  ///
  /// In zh, this message translates to:
  /// **'测试工具'**
  String get developerSectionTestTools;

  /// No description provided for @developerModeEnabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'已启用调试功能'**
  String get developerModeEnabledSubtitle;

  /// No description provided for @developerModeDisabledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'启用后可访问调试工具'**
  String get developerModeDisabledSubtitle;

  /// No description provided for @developerToolLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志查看器'**
  String get developerToolLogTitle;

  /// No description provided for @developerToolLogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看运行日志'**
  String get developerToolLogSubtitle;

  /// No description provided for @developerToolLogShownTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志查看器已显示'**
  String get developerToolLogShownTitle;

  /// No description provided for @developerToolLogShownMessage.
  ///
  /// In zh, this message translates to:
  /// **'已在导航栏显示日志页面'**
  String get developerToolLogShownMessage;

  /// No description provided for @developerToolLogHiddenTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志页面已隐藏'**
  String get developerToolLogHiddenTitle;

  /// No description provided for @developerToolLogHiddenMessage.
  ///
  /// In zh, this message translates to:
  /// **'已从导航栏移除日志页面'**
  String get developerToolLogHiddenMessage;

  /// No description provided for @developerToolFullLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'FULL LOG 切换'**
  String get developerToolFullLogTitle;

  /// No description provided for @developerToolFullLogSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在日志页显示 FULL LOG 视图切换'**
  String get developerToolFullLogSubtitle;

  /// No description provided for @developerToolFullLogShownTitle.
  ///
  /// In zh, this message translates to:
  /// **'FULL LOG 切换已显示'**
  String get developerToolFullLogShownTitle;

  /// No description provided for @developerToolFullLogShownMessage.
  ///
  /// In zh, this message translates to:
  /// **'已在日志页显示 FULL LOG 视图切换'**
  String get developerToolFullLogShownMessage;

  /// No description provided for @developerToolFullLogHiddenTitle.
  ///
  /// In zh, this message translates to:
  /// **'FULL LOG 切换已隐藏'**
  String get developerToolFullLogHiddenTitle;

  /// No description provided for @developerToolFullLogHiddenMessage.
  ///
  /// In zh, this message translates to:
  /// **'已在日志页隐藏 FULL LOG 视图切换'**
  String get developerToolFullLogHiddenMessage;

  /// No description provided for @developerToolStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统状态'**
  String get developerToolStatusTitle;

  /// No description provided for @developerToolStatusSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'内核与扩展状态'**
  String get developerToolStatusSubtitle;

  /// No description provided for @developerToolStatusShownTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统状态已显示'**
  String get developerToolStatusShownTitle;

  /// No description provided for @developerToolStatusShownMessage.
  ///
  /// In zh, this message translates to:
  /// **'已在导航栏显示状态页面'**
  String get developerToolStatusShownMessage;

  /// No description provided for @developerToolStatusHiddenTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统状态已隐藏'**
  String get developerToolStatusHiddenTitle;

  /// No description provided for @developerToolStatusHiddenMessage.
  ///
  /// In zh, this message translates to:
  /// **'已从导航栏移除状态页面'**
  String get developerToolStatusHiddenMessage;

  /// No description provided for @developerToolOnlineStatsTitle.
  ///
  /// In zh, this message translates to:
  /// **'在线统计'**
  String get developerToolOnlineStatsTitle;

  /// No description provided for @developerToolOnlineStatsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在线用户数据'**
  String get developerToolOnlineStatsSubtitle;

  /// No description provided for @developerToolOnlineStatsShownTitle.
  ///
  /// In zh, this message translates to:
  /// **'在线统计已显示'**
  String get developerToolOnlineStatsShownTitle;

  /// No description provided for @developerToolOnlineStatsShownMessage.
  ///
  /// In zh, this message translates to:
  /// **'已在导航栏显示在线统计页面'**
  String get developerToolOnlineStatsShownMessage;

  /// No description provided for @developerToolOnlineStatsHiddenTitle.
  ///
  /// In zh, this message translates to:
  /// **'在线统计已隐藏'**
  String get developerToolOnlineStatsHiddenTitle;

  /// No description provided for @developerToolOnlineStatsHiddenMessage.
  ///
  /// In zh, this message translates to:
  /// **'已从导航栏移除在线统计页面'**
  String get developerToolOnlineStatsHiddenMessage;

  /// No description provided for @developerToolWebCheckTitle.
  ///
  /// In zh, this message translates to:
  /// **'Web 检测'**
  String get developerToolWebCheckTitle;

  /// No description provided for @developerToolWebCheckSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'网站诊断'**
  String get developerToolWebCheckSubtitle;

  /// No description provided for @developerToolWebCheckShownTitle.
  ///
  /// In zh, this message translates to:
  /// **'Web 检测已显示'**
  String get developerToolWebCheckShownTitle;

  /// No description provided for @developerToolWebCheckShownMessage.
  ///
  /// In zh, this message translates to:
  /// **'已在导航栏显示 Web 检测页面'**
  String get developerToolWebCheckShownMessage;

  /// No description provided for @developerToolWebCheckHiddenTitle.
  ///
  /// In zh, this message translates to:
  /// **'Web 检测已隐藏'**
  String get developerToolWebCheckHiddenTitle;

  /// No description provided for @developerToolWebCheckHiddenMessage.
  ///
  /// In zh, this message translates to:
  /// **'已从导航栏移除 Web 检测页面'**
  String get developerToolWebCheckHiddenMessage;

  /// No description provided for @developerToolPerformanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'性能监控'**
  String get developerToolPerformanceTitle;

  /// No description provided for @developerToolPerformanceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'FPS 与渲染'**
  String get developerToolPerformanceSubtitle;

  /// No description provided for @developerToolPerformanceShownTitle.
  ///
  /// In zh, this message translates to:
  /// **'性能监控已显示'**
  String get developerToolPerformanceShownTitle;

  /// No description provided for @developerToolPerformanceShownMessage.
  ///
  /// In zh, this message translates to:
  /// **'已在导航栏显示性能监控页面'**
  String get developerToolPerformanceShownMessage;

  /// No description provided for @developerToolPerformanceHiddenTitle.
  ///
  /// In zh, this message translates to:
  /// **'性能监控已隐藏'**
  String get developerToolPerformanceHiddenTitle;

  /// No description provided for @developerToolPerformanceHiddenMessage.
  ///
  /// In zh, this message translates to:
  /// **'已从导航栏移除性能监控页面'**
  String get developerToolPerformanceHiddenMessage;

  /// No description provided for @developerToolConnectionDebugTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接调试'**
  String get developerToolConnectionDebugTitle;

  /// No description provided for @developerToolConnectionDebugSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'网络连通性诊断'**
  String get developerToolConnectionDebugSubtitle;

  /// No description provided for @developerToolConnectionDebugShownTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接调试已显示'**
  String get developerToolConnectionDebugShownTitle;

  /// No description provided for @developerToolConnectionDebugShownMessage.
  ///
  /// In zh, this message translates to:
  /// **'已在导航栏显示连接调试页面'**
  String get developerToolConnectionDebugShownMessage;

  /// No description provided for @developerToolConnectionDebugHiddenTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接调试已隐藏'**
  String get developerToolConnectionDebugHiddenTitle;

  /// No description provided for @developerToolConnectionDebugHiddenMessage.
  ///
  /// In zh, this message translates to:
  /// **'已从导航栏移除连接调试页面'**
  String get developerToolConnectionDebugHiddenMessage;

  /// No description provided for @connectionDebugTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接调试'**
  String get connectionDebugTitle;

  /// No description provided for @connectionDebugTestTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试下载连接'**
  String get connectionDebugTestTitle;

  /// No description provided for @connectionDebugTestSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'输入下载链接，测试本机到服务器的连通性、代理状态和传输能力'**
  String get connectionDebugTestSubtitle;

  /// No description provided for @connectionDebugTesting.
  ///
  /// In zh, this message translates to:
  /// **'测试中...'**
  String get connectionDebugTesting;

  /// No description provided for @connectionDebugStartTest.
  ///
  /// In zh, this message translates to:
  /// **'开始测试'**
  String get connectionDebugStartTest;

  /// No description provided for @connectionDebugResults.
  ///
  /// In zh, this message translates to:
  /// **'测试结果 ({count})'**
  String connectionDebugResults(int count);

  /// No description provided for @connectionDebugSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get connectionDebugSuccess;

  /// No description provided for @connectionDebugFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get connectionDebugFailed;

  /// No description provided for @connectionDebugLocalHost.
  ///
  /// In zh, this message translates to:
  /// **'本机'**
  String get connectionDebugLocalHost;

  /// No description provided for @connectionDebugProxy.
  ///
  /// In zh, this message translates to:
  /// **'代理'**
  String get connectionDebugProxy;

  /// No description provided for @connectionDebugUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get connectionDebugUnknown;

  /// No description provided for @connectionDebugReceived.
  ///
  /// In zh, this message translates to:
  /// **'接收'**
  String get connectionDebugReceived;

  /// No description provided for @connectionDebugFileSize.
  ///
  /// In zh, this message translates to:
  /// **'文件大小'**
  String get connectionDebugFileSize;

  /// No description provided for @connectionDebugRangeSupported.
  ///
  /// In zh, this message translates to:
  /// **'支持'**
  String get connectionDebugRangeSupported;

  /// No description provided for @connectionDebugRangeNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'不支持'**
  String get connectionDebugRangeNotSupported;

  /// No description provided for @connectionDebugStrategyTitle.
  ///
  /// In zh, this message translates to:
  /// **'站点策略缓存'**
  String get connectionDebugStrategyTitle;

  /// No description provided for @connectionDebugStrategySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'观察每个 host 因历史下载失败而学到的协议降级和并发上限'**
  String get connectionDebugStrategySubtitle;

  /// No description provided for @connectionDebugStrategyRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get connectionDebugStrategyRefresh;

  /// No description provided for @connectionDebugStrategyClear.
  ///
  /// In zh, this message translates to:
  /// **'清空缓存'**
  String get connectionDebugStrategyClear;

  /// No description provided for @connectionDebugStrategyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前还没有站点策略缓存。某个 host 一旦触发协议回退或并发收敛，就会出现在这里。'**
  String get connectionDebugStrategyEmpty;

  /// No description provided for @connectionDebugStrategyCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条站点策略'**
  String connectionDebugStrategyCount(Object count);

  /// No description provided for @connectionDebugStrategyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'协议'**
  String get connectionDebugStrategyPolicy;

  /// No description provided for @connectionDebugStrategyConcurrency.
  ///
  /// In zh, this message translates to:
  /// **'并发'**
  String get connectionDebugStrategyConcurrency;

  /// No description provided for @connectionDebugStrategyTtl.
  ///
  /// In zh, this message translates to:
  /// **'剩余时间'**
  String get connectionDebugStrategyTtl;

  /// No description provided for @connectionDebugStrategyExpired.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get connectionDebugStrategyExpired;

  /// No description provided for @developerTestNotificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'通知测试'**
  String get developerTestNotificationTitle;

  /// No description provided for @developerTestNotificationTitlePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get developerTestNotificationTitlePlaceholder;

  /// No description provided for @developerTestNotificationMessagePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'内容（可选）'**
  String get developerTestNotificationMessagePlaceholder;

  /// No description provided for @developerTestNotificationTypeSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get developerTestNotificationTypeSuccess;

  /// No description provided for @developerTestNotificationTypeWarning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get developerTestNotificationTypeWarning;

  /// No description provided for @developerTestNotificationTypeError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get developerTestNotificationTypeError;

  /// No description provided for @developerTestNotificationTypeInfo.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get developerTestNotificationTypeInfo;

  /// No description provided for @developerTestNotificationTitleRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入标题'**
  String get developerTestNotificationTitleRequired;

  /// No description provided for @developerTestPopupTitle.
  ///
  /// In zh, this message translates to:
  /// **'弹窗测试'**
  String get developerTestPopupTitle;

  /// No description provided for @developerTestPopupButton.
  ///
  /// In zh, this message translates to:
  /// **'弹窗'**
  String get developerTestPopupButton;

  /// No description provided for @developerTestPopupTestingLabel.
  ///
  /// In zh, this message translates to:
  /// **'测试中'**
  String get developerTestPopupTestingLabel;

  /// No description provided for @developerTestPopupHint.
  ///
  /// In zh, this message translates to:
  /// **'独立弹窗使用 Tauri，Dialog 需要主窗口'**
  String get developerTestPopupHint;

  /// No description provided for @developerTestPopupResultSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功 · {time}!['**
  String developerTestPopupResultSuccess(Object time);

  /// No description provided for @developerTestPopupResultFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get developerTestPopupResultFailed;

  /// No description provided for @developerOpenL10nFolderTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言包文件夹'**
  String get developerOpenL10nFolderTitle;

  /// No description provided for @developerOpenL10nFolderSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在文件管理器中打开 l10n 文件夹'**
  String get developerOpenL10nFolderSubtitle;

  /// No description provided for @developerOpenL10nFolderSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'已打开文件夹'**
  String get developerOpenL10nFolderSuccessTitle;

  /// No description provided for @developerOpenL10nFolderSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'已在文件管理器中打开语言包文件夹'**
  String get developerOpenL10nFolderSuccessMessage;

  /// No description provided for @developerOpenL10nFolderFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开失败'**
  String get developerOpenL10nFolderFailedTitle;

  /// No description provided for @developerOpenL10nFolderFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法打开文件夹: {error}'**
  String developerOpenL10nFolderFailedMessage(Object error);

  /// No description provided for @updateCurrentVersionTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get updateCurrentVersionTitle;

  /// No description provided for @updateChangelogTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get updateChangelogTitle;

  /// No description provided for @updateChangelogViewFullButton.
  ///
  /// In zh, this message translates to:
  /// **'查看完整更新日志'**
  String get updateChangelogViewFullButton;

  /// No description provided for @updateChangelogDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'v{version} 更新日志'**
  String updateChangelogDialogTitle(Object version);

  /// No description provided for @updateCheckTitle.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get updateCheckTitle;

  /// No description provided for @updateStartButton.
  ///
  /// In zh, this message translates to:
  /// **'开始更新'**
  String get updateStartButton;

  /// No description provided for @updateCheckAgainButton.
  ///
  /// In zh, this message translates to:
  /// **'重新检查'**
  String get updateCheckAgainButton;

  /// No description provided for @updateCheckingStatus.
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新...'**
  String get updateCheckingStatus;

  /// No description provided for @updateCheckFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get updateCheckFailedTitle;

  /// No description provided for @updateLatestTitle.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get updateLatestTitle;

  /// No description provided for @updateLatestSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本'**
  String get updateLatestSubtitle;

  /// No description provided for @updateInitialHint.
  ///
  /// In zh, this message translates to:
  /// **'点击\"重新检查\"按钮检查最新版本'**
  String get updateInitialHint;

  /// No description provided for @updateUnreleasedTitle.
  ///
  /// In zh, this message translates to:
  /// **'未发布的版本'**
  String get updateUnreleasedTitle;

  /// No description provided for @updateUnreleasedSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当前版本 v{version} | 当前版本号不存在,或许为特殊版本或开发版'**
  String updateUnreleasedSubtitle(Object version);

  /// No description provided for @updateConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认更新'**
  String get updateConfirmTitle;

  /// No description provided for @updateConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'新版本已经准备好啦，为保障安装过程可以正常进行，本应用将会关闭！'**
  String get updateConfirmMessage;

  /// No description provided for @updateConfirmDetails.
  ///
  /// In zh, this message translates to:
  /// **'新版本: {newVersion}\\n当前版本: {currentVersion}\\n变更: {change}\\n渠道: {currentChannel} -> {targetChannel}\\n准备更新？'**
  String updateConfirmDetails(Object newVersion, Object currentVersion,
      Object change, Object currentChannel, Object targetChannel);

  /// No description provided for @updateConfirmCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get updateConfirmCancelButton;

  /// No description provided for @updateConfirmProceedButton.
  ///
  /// In zh, this message translates to:
  /// **'确认更新'**
  String get updateConfirmProceedButton;

  /// No description provided for @updateUnknownVersion.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get updateUnknownVersion;

  /// No description provided for @updateUnknownChannel.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get updateUnknownChannel;

  /// No description provided for @updateLauncherFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'启动更新器失败'**
  String get updateLauncherFailedTitle;

  /// No description provided for @updateLauncherFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法启动 Update.exe\\n排查步骤:\\n • 检查 Update.exe 是否被删除或移动\\n • 确认已安装 .NET 8\\n • 确认安装包完整\\n如果仍失败，请手动下载安装。'**
  String get updateLauncherFailedMessage;

  /// No description provided for @updateLauncherFailedCloseButton.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get updateLauncherFailedCloseButton;

  /// No description provided for @updateLauncherFailedManualDownloadButton.
  ///
  /// In zh, this message translates to:
  /// **'手动下载'**
  String get updateLauncherFailedManualDownloadButton;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现更新'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableChangelogTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新内容'**
  String get updateAvailableChangelogTitle;

  /// No description provided for @updateSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新设置'**
  String get updateSettingsTitle;

  /// No description provided for @updateDotNetMissingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'未安装 - 推荐安装以使用自动更新器'**
  String get updateDotNetMissingSubtitle;

  /// No description provided for @updateDotNetDownloadButton.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get updateDotNetDownloadButton;

  /// No description provided for @updateDotNetInstalledSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'已安装 - 可使用更新器'**
  String get updateDotNetInstalledSubtitle;

  /// No description provided for @updateDotNetRecheckButton.
  ///
  /// In zh, this message translates to:
  /// **'重新检测'**
  String get updateDotNetRecheckButton;

  /// No description provided for @updateDotNetRecommendTitle.
  ///
  /// In zh, this message translates to:
  /// **'推荐安装 .NET 8'**
  String get updateDotNetRecommendTitle;

  /// No description provided for @updateDotNetRecommendSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'安装 .NET 8 Desktop Runtime 后可使用更新器自动更新'**
  String get updateDotNetRecommendSubtitle;

  /// No description provided for @updateDotNetRecommendButton.
  ///
  /// In zh, this message translates to:
  /// **'下载 .NET 8'**
  String get updateDotNetRecommendButton;

  /// No description provided for @updateChannelTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前通道'**
  String get updateChannelTitle;

  /// No description provided for @updateChannelAlpha.
  ///
  /// In zh, this message translates to:
  /// **'Alpha（预览版）'**
  String get updateChannelAlpha;

  /// No description provided for @updateChannelBeta.
  ///
  /// In zh, this message translates to:
  /// **'Beta（公测版）'**
  String get updateChannelBeta;

  /// No description provided for @updateChannelRelease.
  ///
  /// In zh, this message translates to:
  /// **'Release（稳定版）'**
  String get updateChannelRelease;

  /// No description provided for @updateIntervalTitle.
  ///
  /// In zh, this message translates to:
  /// **'自动检查更新'**
  String get updateIntervalTitle;

  /// No description provided for @updateIntervalSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'设置检查更新的频率'**
  String get updateIntervalSubtitle;

  /// No description provided for @updateIntervalStartup.
  ///
  /// In zh, this message translates to:
  /// **'仅启动时'**
  String get updateIntervalStartup;

  /// No description provided for @updateIntervalHourly.
  ///
  /// In zh, this message translates to:
  /// **'每小时'**
  String get updateIntervalHourly;

  /// No description provided for @updateIntervalDaily.
  ///
  /// In zh, this message translates to:
  /// **'每天'**
  String get updateIntervalDaily;

  /// No description provided for @updateIntervalWeekly.
  ///
  /// In zh, this message translates to:
  /// **'每周'**
  String get updateIntervalWeekly;

  /// No description provided for @updateIntervalNever.
  ///
  /// In zh, this message translates to:
  /// **'从不'**
  String get updateIntervalNever;

  /// No description provided for @updateAllowBetaTitle.
  ///
  /// In zh, this message translates to:
  /// **'接收 Beta 更新'**
  String get updateAllowBetaTitle;

  /// No description provided for @updateAllowBetaSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'允许接收稳定的 Beta 版本'**
  String get updateAllowBetaSubtitle;

  /// No description provided for @updateAllowAlphaTitle.
  ///
  /// In zh, this message translates to:
  /// **'接收 Alpha 更新'**
  String get updateAllowAlphaTitle;

  /// No description provided for @updateAllowAlphaSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'允许接收最新的测试构建（可能不稳定）'**
  String get updateAllowAlphaSubtitle;

  /// No description provided for @updateLastCheckLabel.
  ///
  /// In zh, this message translates to:
  /// **'上次检查: {time}'**
  String updateLastCheckLabel(Object time);

  /// No description provided for @updateTimeJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get updateTimeJustNow;

  /// No description provided for @updateTimeMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟前'**
  String updateTimeMinutesAgo(Object minutes);

  /// No description provided for @updateTimeHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时前'**
  String updateTimeHoursAgo(Object hours);

  /// No description provided for @updateDialogCloseButton.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get updateDialogCloseButton;

  /// No description provided for @statusOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get statusOnline;

  /// No description provided for @statusOffline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get statusOffline;

  /// No description provided for @settingsDangerZoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'危险区域'**
  String get settingsDangerZoneTitle;

  /// No description provided for @popupDownloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建下载'**
  String get popupDownloadTitle;

  /// No description provided for @popupDownloadLinkLabel.
  ///
  /// In zh, this message translates to:
  /// **'下载链接'**
  String get popupDownloadLinkLabel;

  /// No description provided for @popupDownloadLinkPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'HTTP/HTTPS 链接'**
  String get popupDownloadLinkPlaceholder;

  /// No description provided for @popupDownloadFileNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'文件名'**
  String get popupDownloadFileNameLabel;

  /// No description provided for @popupDownloadFileNamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'保存为文件名'**
  String get popupDownloadFileNamePlaceholder;

  /// No description provided for @popupDownloadAutoStart.
  ///
  /// In zh, this message translates to:
  /// **'立即开始下载'**
  String get popupDownloadAutoStart;

  /// No description provided for @popupDownloadFeatureHint.
  ///
  /// In zh, this message translates to:
  /// **'支持多线程、断点续传和限速'**
  String get popupDownloadFeatureHint;

  /// No description provided for @popupDownloadCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get popupDownloadCancel;

  /// No description provided for @popupDownloadAdding.
  ///
  /// In zh, this message translates to:
  /// **'添加中...'**
  String get popupDownloadAdding;

  /// No description provided for @popupDownloadStart.
  ///
  /// In zh, this message translates to:
  /// **'开始下载'**
  String get popupDownloadStart;

  /// No description provided for @popupDownloadErrorMissingInfo.
  ///
  /// In zh, this message translates to:
  /// **'请填写完整信息'**
  String get popupDownloadErrorMissingInfo;

  /// No description provided for @popupDownloadErrorInvalidUrl.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 HTTP/HTTPS 链接'**
  String get popupDownloadErrorInvalidUrl;

  /// No description provided for @popupDownloadErrorAddFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加任务失败: {error}'**
  String popupDownloadErrorAddFailed(Object error);

  /// No description provided for @popupDownloadErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get popupDownloadErrorTitle;

  /// No description provided for @popupDownloadErrorConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get popupDownloadErrorConfirm;

  /// No description provided for @popupDownloadDefaultFileName.
  ///
  /// In zh, this message translates to:
  /// **'download'**
  String get popupDownloadDefaultFileName;

  /// No description provided for @addDownloadTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建下载'**
  String get addDownloadTitle;

  /// No description provided for @addDownloadSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'支持多线程下载和断点续传'**
  String get addDownloadSubtitle;

  /// No description provided for @addDownloadUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'下载链接'**
  String get addDownloadUrlLabel;

  /// No description provided for @addDownloadRequiredBadge.
  ///
  /// In zh, this message translates to:
  /// **'必填'**
  String get addDownloadRequiredBadge;

  /// No description provided for @addDownloadUrlPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'https://example.com/file.zip'**
  String get addDownloadUrlPlaceholder;

  /// No description provided for @addDownloadParsedFileNameTitle.
  ///
  /// In zh, this message translates to:
  /// **'已解析文件名'**
  String get addDownloadParsedFileNameTitle;

  /// No description provided for @addDownloadAdvancedToggle.
  ///
  /// In zh, this message translates to:
  /// **'高级选项'**
  String get addDownloadAdvancedToggle;

  /// No description provided for @addDownloadAdvancedCollapsedHint.
  ///
  /// In zh, this message translates to:
  /// **'自定义文件名'**
  String get addDownloadAdvancedCollapsedHint;

  /// No description provided for @addDownloadAdvancedExpandedHint.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get addDownloadAdvancedExpandedHint;

  /// No description provided for @addDownloadFileNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'自定义文件名'**
  String get addDownloadFileNameLabel;

  /// No description provided for @addDownloadOptionalBadge.
  ///
  /// In zh, this message translates to:
  /// **'可选'**
  String get addDownloadOptionalBadge;

  /// No description provided for @addDownloadFileNamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'留空则使用解析到的名称'**
  String get addDownloadFileNamePlaceholder;

  /// No description provided for @addDownloadFeatureTitle.
  ///
  /// In zh, this message translates to:
  /// **'智能下载特性'**
  String get addDownloadFeatureTitle;

  /// No description provided for @addDownloadFeature1Title.
  ///
  /// In zh, this message translates to:
  /// **'多线程分段'**
  String get addDownloadFeature1Title;

  /// No description provided for @addDownloadFeature1Desc.
  ///
  /// In zh, this message translates to:
  /// **'最大化下载速度'**
  String get addDownloadFeature1Desc;

  /// No description provided for @addDownloadFeature2Title.
  ///
  /// In zh, this message translates to:
  /// **'自动续传'**
  String get addDownloadFeature2Title;

  /// No description provided for @addDownloadFeature2Desc.
  ///
  /// In zh, this message translates to:
  /// **'网络中断后恢复'**
  String get addDownloadFeature2Desc;

  /// No description provided for @addDownloadFeature3Title.
  ///
  /// In zh, this message translates to:
  /// **'动态分段'**
  String get addDownloadFeature3Title;

  /// No description provided for @addDownloadFeature3Desc.
  ///
  /// In zh, this message translates to:
  /// **'自适应下载策略'**
  String get addDownloadFeature3Desc;

  /// No description provided for @addDownloadCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get addDownloadCancelButton;

  /// No description provided for @addDownloadAdding.
  ///
  /// In zh, this message translates to:
  /// **'添加中...'**
  String get addDownloadAdding;

  /// No description provided for @addDownloadStart.
  ///
  /// In zh, this message translates to:
  /// **'开始下载'**
  String get addDownloadStart;

  /// No description provided for @addDownloadErrorMissingUrl.
  ///
  /// In zh, this message translates to:
  /// **'请输入下载链接'**
  String get addDownloadErrorMissingUrl;

  /// No description provided for @addDownloadErrorInvalidUrl.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 HTTP/HTTPS 链接'**
  String get addDownloadErrorInvalidUrl;

  /// No description provided for @addDownloadErrorAddFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加任务失败: {error}'**
  String addDownloadErrorAddFailed(Object error);

  /// No description provided for @addDownloadErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get addDownloadErrorTitle;

  /// No description provided for @addDownloadErrorConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get addDownloadErrorConfirm;

  /// No description provided for @addDownloadSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'任务已添加'**
  String get addDownloadSuccessTitle;

  /// No description provided for @addDownloadSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'正在下载：{fileName}'**
  String addDownloadSuccessMessage(Object fileName);

  /// No description provided for @folderPickerErrorPathNotFound.
  ///
  /// In zh, this message translates to:
  /// **'路径不存在'**
  String get folderPickerErrorPathNotFound;

  /// No description provided for @folderPickerErrorAccessDenied.
  ///
  /// In zh, this message translates to:
  /// **'无法访问该路径（权限不足）'**
  String get folderPickerErrorAccessDenied;

  /// No description provided for @folderPickerErrorAccessFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法访问该路径：{error}'**
  String folderPickerErrorAccessFailed(Object error);

  /// No description provided for @folderPickerCreateTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建文件夹'**
  String get folderPickerCreateTitle;

  /// No description provided for @folderPickerCreatePrompt.
  ///
  /// In zh, this message translates to:
  /// **'在以下位置创建文件夹：'**
  String get folderPickerCreatePrompt;

  /// No description provided for @folderPickerCreatePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'文件夹名称'**
  String get folderPickerCreatePlaceholder;

  /// No description provided for @folderPickerCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get folderPickerCancelButton;

  /// No description provided for @folderPickerCreateButton.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get folderPickerCreateButton;

  /// No description provided for @folderPickerConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get folderPickerConfirmButton;

  /// No description provided for @folderPickerCreateExistsTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建已取消'**
  String get folderPickerCreateExistsTitle;

  /// No description provided for @folderPickerCreateExistsMessage.
  ///
  /// In zh, this message translates to:
  /// **'文件夹 \"{name}\" 已存在。\n已选中该文件夹。'**
  String folderPickerCreateExistsMessage(Object name);

  /// No description provided for @folderPickerCreateSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建成功'**
  String get folderPickerCreateSuccessTitle;

  /// No description provided for @folderPickerCreateSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'已创建并选中 \"{name}\" 文件夹'**
  String folderPickerCreateSuccessMessage(Object name);

  /// No description provided for @folderPickerCreateFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建失败'**
  String get folderPickerCreateFailedTitle;

  /// No description provided for @folderPickerCreateFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'创建文件夹失败：{error}'**
  String folderPickerCreateFailedMessage(Object error);

  /// No description provided for @folderPickerQuickPathAddTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加快捷路径'**
  String get folderPickerQuickPathAddTitle;

  /// No description provided for @folderPickerQuickPathAddPrompt.
  ///
  /// In zh, this message translates to:
  /// **'将当前路径添加到快捷路径：'**
  String get folderPickerQuickPathAddPrompt;

  /// No description provided for @folderPickerQuickPathAddNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'自定义名称（可选）：'**
  String get folderPickerQuickPathAddNameLabel;

  /// No description provided for @folderPickerQuickPathAddNamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如：我的项目'**
  String get folderPickerQuickPathAddNamePlaceholder;

  /// No description provided for @folderPickerQuickPathAddButton.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get folderPickerQuickPathAddButton;

  /// No description provided for @folderPickerQuickPathAddSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加成功'**
  String get folderPickerQuickPathAddSuccessTitle;

  /// No description provided for @folderPickerQuickPathAddFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加失败'**
  String get folderPickerQuickPathAddFailedTitle;

  /// No description provided for @folderPickerQuickPathAddSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'快捷路径已添加'**
  String get folderPickerQuickPathAddSuccessMessage;

  /// No description provided for @folderPickerQuickPathAddFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'路径已存在或无效'**
  String get folderPickerQuickPathAddFailedMessage;

  /// No description provided for @folderPickerQuickPathRemoveTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除快捷路径'**
  String get folderPickerQuickPathRemoveTitle;

  /// No description provided for @folderPickerQuickPathRemoveMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定移除该快捷路径？\n\n{path}'**
  String folderPickerQuickPathRemoveMessage(Object path);

  /// No description provided for @folderPickerQuickPathRemoveButton.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get folderPickerQuickPathRemoveButton;

  /// No description provided for @folderPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择文件夹'**
  String get folderPickerTitle;

  /// No description provided for @folderPickerNavUpTooltip.
  ///
  /// In zh, this message translates to:
  /// **'上级文件夹'**
  String get folderPickerNavUpTooltip;

  /// No description provided for @folderPickerPathPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'输入路径或在下方选择'**
  String get folderPickerPathPlaceholder;

  /// No description provided for @folderPickerRefreshTooltip.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get folderPickerRefreshTooltip;

  /// No description provided for @folderPickerNewFolderTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get folderPickerNewFolderTooltip;

  /// No description provided for @folderPickerAddQuickPathTooltip.
  ///
  /// In zh, this message translates to:
  /// **'将当前路径添加到快捷路径'**
  String get folderPickerAddQuickPathTooltip;

  /// No description provided for @folderPickerEmptyMessage.
  ///
  /// In zh, this message translates to:
  /// **'此文件夹为空'**
  String get folderPickerEmptyMessage;

  /// No description provided for @folderPickerSelectButton.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get folderPickerSelectButton;

  /// No description provided for @updateLatestVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'最新版本'**
  String get updateLatestVersionLabel;

  /// No description provided for @updateDialogLaterButton.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get updateDialogLaterButton;

  /// No description provided for @updateDialogDownloadNowButton.
  ///
  /// In zh, this message translates to:
  /// **'立即下载'**
  String get updateDialogDownloadNowButton;

  /// No description provided for @updateDialogCurrentInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前版本信息'**
  String get updateDialogCurrentInfoTitle;

  /// No description provided for @downloadStatusDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloadStatusDownloading;

  /// No description provided for @downloadStatusPaused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get downloadStatusPaused;

  /// No description provided for @downloadStatusPending.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get downloadStatusPending;

  /// No description provided for @downloadStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get downloadStatusFailed;

  /// No description provided for @downloadStatusMerging.
  ///
  /// In zh, this message translates to:
  /// **'合并中'**
  String get downloadStatusMerging;

  /// No description provided for @downloadStatusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get downloadStatusCompleted;

  /// No description provided for @downloadFilterTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get downloadFilterTitle;

  /// No description provided for @downloadFilterSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'按状态筛选下载任务'**
  String get downloadFilterSubtitle;

  /// No description provided for @downloadFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get downloadFilterAll;

  /// No description provided for @downloadDialogCloseButton.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get downloadDialogCloseButton;

  /// No description provided for @downloadSortTitle.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get downloadSortTitle;

  /// No description provided for @downloadSortSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择下载任务的排序方式'**
  String get downloadSortSubtitle;

  /// No description provided for @downloadSortNewest.
  ///
  /// In zh, this message translates to:
  /// **'最新'**
  String get downloadSortNewest;

  /// No description provided for @downloadSortOldest.
  ///
  /// In zh, this message translates to:
  /// **'最旧'**
  String get downloadSortOldest;

  /// No description provided for @downloadSortNewestDesc.
  ///
  /// In zh, this message translates to:
  /// **'按创建时间从新到旧'**
  String get downloadSortNewestDesc;

  /// No description provided for @downloadSortOldestDesc.
  ///
  /// In zh, this message translates to:
  /// **'按创建时间从旧到新'**
  String get downloadSortOldestDesc;

  /// No description provided for @downloadSearchPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'搜索下载任务...'**
  String get downloadSearchPlaceholder;

  /// No description provided for @downloadNoResultsTitle.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的任务'**
  String get downloadNoResultsTitle;

  /// No description provided for @downloadNoResultsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'尝试修改搜索条件'**
  String get downloadNoResultsSubtitle;

  /// No description provided for @downloadStatsActiveLabel.
  ///
  /// In zh, this message translates to:
  /// **'活动'**
  String get downloadStatsActiveLabel;

  /// No description provided for @downloadStatsSpeedLabel.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get downloadStatsSpeedLabel;

  /// No description provided for @downloadStatsSegmentsLabel.
  ///
  /// In zh, this message translates to:
  /// **'分段'**
  String get downloadStatsSegmentsLabel;

  /// No description provided for @downloadEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无下载任务'**
  String get downloadEmptyTitle;

  /// No description provided for @downloadEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击“新建”按钮添加下载任务'**
  String get downloadEmptySubtitle;

  /// No description provided for @downloadCopySuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'复制成功'**
  String get downloadCopySuccessTitle;

  /// No description provided for @loadingTasks.
  ///
  /// In zh, this message translates to:
  /// **'正在加载任务列表...'**
  String get loadingTasks;

  /// No description provided for @loadingTasksHint.
  ///
  /// In zh, this message translates to:
  /// **'正在连接下载引擎'**
  String get loadingTasksHint;

  /// No description provided for @downloadCopySuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'下载链接已复制'**
  String get downloadCopySuccessMessage;

  /// No description provided for @downloadCopyFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'复制失败'**
  String get downloadCopyFailedTitle;

  /// No description provided for @downloadCopyFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'复制失败: {error}'**
  String downloadCopyFailedMessage(Object error);

  /// No description provided for @downloadCopyTooltip.
  ///
  /// In zh, this message translates to:
  /// **'复制链接'**
  String get downloadCopyTooltip;

  /// No description provided for @downloadActionStart.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get downloadActionStart;

  /// No description provided for @downloadActionPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get downloadActionPause;

  /// No description provided for @downloadActionRetrySegments.
  ///
  /// In zh, this message translates to:
  /// **'重试失败分段'**
  String get downloadActionRetrySegments;

  /// No description provided for @downloadActionRetryAll.
  ///
  /// In zh, this message translates to:
  /// **'全部重试'**
  String get downloadActionRetryAll;

  /// No description provided for @downloadActionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get downloadActionDelete;

  /// No description provided for @downloadMergingStatus.
  ///
  /// In zh, this message translates to:
  /// **'下载完成，正在合并'**
  String get downloadMergingStatus;

  /// No description provided for @downloadCalculatingSize.
  ///
  /// In zh, this message translates to:
  /// **'正在计算大小...'**
  String get downloadCalculatingSize;

  /// No description provided for @downloadCalculating.
  ///
  /// In zh, this message translates to:
  /// **'计算中'**
  String get downloadCalculating;

  /// No description provided for @downloadMatchingHttpProtocol.
  ///
  /// In zh, this message translates to:
  /// **'正在匹配 HTTP 协议...'**
  String get downloadMatchingHttpProtocol;

  /// No description provided for @downloadMatchingHttpProtocolShort.
  ///
  /// In zh, this message translates to:
  /// **'匹配协议中'**
  String get downloadMatchingHttpProtocolShort;

  /// No description provided for @downloadSegmentsTitleWithCount.
  ///
  /// In zh, this message translates to:
  /// **'分段 ({count})'**
  String downloadSegmentsTitleWithCount(Object count);

  /// No description provided for @downloadSegmentsTitle.
  ///
  /// In zh, this message translates to:
  /// **'分段'**
  String get downloadSegmentsTitle;

  /// No description provided for @downloadSegmentsStatusCompleted.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get downloadSegmentsStatusCompleted;

  /// No description provided for @downloadSegmentsStatusDownloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloadSegmentsStatusDownloading;

  /// No description provided for @downloadSegmentsStatusFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get downloadSegmentsStatusFailed;

  /// No description provided for @downloadSegmentsSummary.
  ///
  /// In zh, this message translates to:
  /// **'共 {total} 段 · 已完成 {completed} · 下载中 {downloading}'**
  String downloadSegmentsSummary(
      Object total, Object completed, Object downloading);

  /// No description provided for @downloadSegmentsSummaryWithFailed.
  ///
  /// In zh, this message translates to:
  /// **'共 {total} 段 · 已完成 {completed} · 下载中 {downloading} · 失败 {failed}'**
  String downloadSegmentsSummaryWithFailed(
      Object total, Object completed, Object downloading, Object failed);

  /// No description provided for @downloadRetryButton.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get downloadRetryButton;

  /// No description provided for @downloadSegmentLabel.
  ///
  /// In zh, this message translates to:
  /// **'分段 {index}'**
  String downloadSegmentLabel(Object index);

  /// No description provided for @downloadSegmentRetryCount.
  ///
  /// In zh, this message translates to:
  /// **'重试{count}次'**
  String downloadSegmentRetryCount(Object count);

  /// No description provided for @downloadSegmentsCollapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get downloadSegmentsCollapse;

  /// No description provided for @downloadSegmentsShowAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部 {count} 个'**
  String downloadSegmentsShowAll(Object count);

  /// No description provided for @downloadSizeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'{downloaded} / 未知'**
  String downloadSizeUnknown(Object downloaded);

  /// No description provided for @downloadFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get downloadFailedTitle;

  /// No description provided for @downloadFailedSegmentsHint.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个分段失败，可重试'**
  String downloadFailedSegmentsHint(Object count);

  /// No description provided for @downloadConfirmDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get downloadConfirmDeleteTitle;

  /// No description provided for @downloadConfirmDeleteMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除任务 \"{fileName}\" 吗？'**
  String downloadConfirmDeleteMessage(Object fileName);

  /// No description provided for @downloadDeleteButton.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get downloadDeleteButton;

  /// No description provided for @completedCategoryAll.
  ///
  /// In zh, this message translates to:
  /// **'所有下载'**
  String get completedCategoryAll;

  /// No description provided for @completedCategoryVideo.
  ///
  /// In zh, this message translates to:
  /// **'视频'**
  String get completedCategoryVideo;

  /// No description provided for @completedCategoryAudio.
  ///
  /// In zh, this message translates to:
  /// **'音频'**
  String get completedCategoryAudio;

  /// No description provided for @completedCategoryArchive.
  ///
  /// In zh, this message translates to:
  /// **'压缩包'**
  String get completedCategoryArchive;

  /// No description provided for @completedCategoryDocument.
  ///
  /// In zh, this message translates to:
  /// **'文档'**
  String get completedCategoryDocument;

  /// No description provided for @completedCategoryProgram.
  ///
  /// In zh, this message translates to:
  /// **'程序'**
  String get completedCategoryProgram;

  /// No description provided for @completedCategoryOther.
  ///
  /// In zh, this message translates to:
  /// **'杂项'**
  String get completedCategoryOther;

  /// No description provided for @completedSearchPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'搜索已完成的文件...'**
  String get completedSearchPlaceholder;

  /// No description provided for @completedNoResultsTitle.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的文件'**
  String get completedNoResultsTitle;

  /// No description provided for @completedNoResultsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'尝试修改搜索条件'**
  String get completedNoResultsSubtitle;

  /// No description provided for @completedHeaderTitle.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get completedHeaderTitle;

  /// No description provided for @completedOpenFolderButton.
  ///
  /// In zh, this message translates to:
  /// **'打开文件夹'**
  String get completedOpenFolderButton;

  /// No description provided for @completedEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无已完成任务'**
  String get completedEmptyTitle;

  /// No description provided for @completedEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'完成的下载任务将显示在这里'**
  String get completedEmptySubtitle;

  /// No description provided for @completedStatsTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载统计'**
  String get completedStatsTitle;

  /// No description provided for @completedStatsPeakSpeed.
  ///
  /// In zh, this message translates to:
  /// **'峰值速度'**
  String get completedStatsPeakSpeed;

  /// No description provided for @completedStatsAverageSpeed.
  ///
  /// In zh, this message translates to:
  /// **'平均速度'**
  String get completedStatsAverageSpeed;

  /// No description provided for @completedStatsDuration.
  ///
  /// In zh, this message translates to:
  /// **'用时'**
  String get completedStatsDuration;

  /// No description provided for @completedStatsSegments.
  ///
  /// In zh, this message translates to:
  /// **'分段数'**
  String get completedStatsSegments;

  /// No description provided for @completedStatsThreads.
  ///
  /// In zh, this message translates to:
  /// **'线程数'**
  String get completedStatsThreads;

  /// No description provided for @completedStatsCore.
  ///
  /// In zh, this message translates to:
  /// **'下载核心'**
  String get completedStatsCore;

  /// No description provided for @completedActionRun.
  ///
  /// In zh, this message translates to:
  /// **'运行'**
  String get completedActionRun;

  /// No description provided for @completedActionLocation.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get completedActionLocation;

  /// No description provided for @completedTimeJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get completedTimeJustNow;

  /// No description provided for @completedTimeMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{minutes}分钟前'**
  String completedTimeMinutesAgo(Object minutes);

  /// No description provided for @completedTimeHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{hours}小时前'**
  String completedTimeHoursAgo(Object hours);

  /// No description provided for @completedTimeDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{days}天前'**
  String completedTimeDaysAgo(Object days);

  /// No description provided for @completedTimeMonthDay.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日'**
  String completedTimeMonthDay(Object month, Object day);

  /// No description provided for @completedFilePathMissingMessage.
  ///
  /// In zh, this message translates to:
  /// **'文件路径不存在'**
  String get completedFilePathMissingMessage;

  /// No description provided for @completedRunFileFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'运行文件失败: {error}'**
  String completedRunFileFailedMessage(Object error);

  /// No description provided for @completedOpenFileLocationFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'打开文件位置失败: {error}'**
  String completedOpenFileLocationFailedMessage(Object error);

  /// No description provided for @completedHintTitle.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get completedHintTitle;

  /// No description provided for @completedConfirmDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get completedConfirmDeleteTitle;

  /// No description provided for @completedDeleteTaskMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 \"{fileName}\" 吗？'**
  String completedDeleteTaskMessage(Object fileName);

  /// No description provided for @completedRemoveSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除成功'**
  String get completedRemoveSuccessTitle;

  /// No description provided for @completedRemoveSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'已从列表中移除任务'**
  String get completedRemoveSuccessMessage;

  /// No description provided for @completedDeleteSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除成功'**
  String get completedDeleteSuccessTitle;

  /// No description provided for @completedDeleteFileSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'已删除文件：{fileName}'**
  String completedDeleteFileSuccessMessage(Object fileName);

  /// No description provided for @completedFileNotFoundTitle.
  ///
  /// In zh, this message translates to:
  /// **'文件不存在'**
  String get completedFileNotFoundTitle;

  /// No description provided for @completedFileNotFoundMessage.
  ///
  /// In zh, this message translates to:
  /// **'文件可能已被移动或删除'**
  String get completedFileNotFoundMessage;

  /// No description provided for @completedDeleteFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除失败'**
  String get completedDeleteFailedTitle;

  /// No description provided for @completedDeleteFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法删除文件：{error}'**
  String completedDeleteFailedMessage(Object error);

  /// No description provided for @completedCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get completedCancelButton;

  /// No description provided for @completedRemoveButton.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get completedRemoveButton;

  /// No description provided for @completedDeleteButton.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get completedDeleteButton;

  /// No description provided for @completedCreateButton.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get completedCreateButton;

  /// No description provided for @completedCreateCategoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建自定义分类'**
  String get completedCreateCategoryTitle;

  /// No description provided for @completedCreateCategoryNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'分类名称'**
  String get completedCreateCategoryNameLabel;

  /// No description provided for @completedCreateCategoryNamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如：图片'**
  String get completedCreateCategoryNamePlaceholder;

  /// No description provided for @completedCreateCategoryExtensionsLabel.
  ///
  /// In zh, this message translates to:
  /// **'文件扩展名'**
  String get completedCreateCategoryExtensionsLabel;

  /// No description provided for @completedCreateCategoryExtensionsPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如：.jpg,.png,.gif（用逗号分隔）'**
  String get completedCreateCategoryExtensionsPlaceholder;

  /// No description provided for @completedCreateCategoryHint.
  ///
  /// In zh, this message translates to:
  /// **'提示：扩展名需要包含点号，多个扩展名用逗号分隔'**
  String get completedCreateCategoryHint;

  /// No description provided for @completedCreateCategoryInputErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'输入错误'**
  String get completedCreateCategoryInputErrorTitle;

  /// No description provided for @completedCreateCategoryInputErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'请填写完整信息'**
  String get completedCreateCategoryInputErrorMessage;

  /// No description provided for @completedCreateCategoryInvalidExtMessage.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的扩展名'**
  String get completedCreateCategoryInvalidExtMessage;

  /// No description provided for @completedCreateCategorySuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建成功'**
  String get completedCreateCategorySuccessTitle;

  /// No description provided for @completedCreateCategorySuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'已创建分类：{name}'**
  String completedCreateCategorySuccessMessage(Object name);

  /// No description provided for @completedDeleteCategoryMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除自定义分类 \"{name}\" 吗？'**
  String completedDeleteCategoryMessage(Object name);

  /// No description provided for @completedDeleteCategorySuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除成功'**
  String get completedDeleteCategorySuccessTitle;

  /// No description provided for @completedDeleteCategorySuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'已删除分类：{name}'**
  String completedDeleteCategorySuccessMessage(Object name);

  /// No description provided for @statusPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'系统状态'**
  String get statusPageTitle;

  /// No description provided for @statusPageRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get statusPageRefresh;

  /// No description provided for @statusPageTestApi.
  ///
  /// In zh, this message translates to:
  /// **'测试 API'**
  String get statusPageTestApi;

  /// No description provided for @statusPageClearLogs.
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get statusPageClearLogs;

  /// No description provided for @statusSectionKernel.
  ///
  /// In zh, this message translates to:
  /// **'下载核心状态'**
  String get statusSectionKernel;

  /// No description provided for @statusItemKernelRuntime.
  ///
  /// In zh, this message translates to:
  /// **'内核运行时'**
  String get statusItemKernelRuntime;

  /// No description provided for @statusValueRunning.
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get statusValueRunning;

  /// No description provided for @statusValueStopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get statusValueStopped;

  /// No description provided for @statusItemKernelCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前内核'**
  String get statusItemKernelCurrent;

  /// No description provided for @statusItemHttpService.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 服务'**
  String get statusItemHttpService;

  /// No description provided for @statusValueHealthy.
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get statusValueHealthy;

  /// No description provided for @statusValueBuiltIn.
  ///
  /// In zh, this message translates to:
  /// **'内置'**
  String get statusValueBuiltIn;

  /// No description provided for @statusValueUnhealthy.
  ///
  /// In zh, this message translates to:
  /// **'异常'**
  String get statusValueUnhealthy;

  /// No description provided for @statusItemServiceAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务地址'**
  String get statusItemServiceAddress;

  /// No description provided for @statusItemKernelVersion.
  ///
  /// In zh, this message translates to:
  /// **'核心版本'**
  String get statusItemKernelVersion;

  /// No description provided for @statusSectionNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络状态'**
  String get statusSectionNetwork;

  /// No description provided for @statusItemLocalNetwork.
  ///
  /// In zh, this message translates to:
  /// **'本地网络'**
  String get statusItemLocalNetwork;

  /// No description provided for @statusValueConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get statusValueConnected;

  /// No description provided for @statusValueDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get statusValueDisconnected;

  /// No description provided for @statusItemInternet.
  ///
  /// In zh, this message translates to:
  /// **'互联网'**
  String get statusItemInternet;

  /// No description provided for @statusValueReachable.
  ///
  /// In zh, this message translates to:
  /// **'可访问'**
  String get statusValueReachable;

  /// No description provided for @statusValueUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'不可访问'**
  String get statusValueUnreachable;

  /// No description provided for @statusItemLocalIp.
  ///
  /// In zh, this message translates to:
  /// **'本地 IP'**
  String get statusItemLocalIp;

  /// No description provided for @statusItemNetworkLatency.
  ///
  /// In zh, this message translates to:
  /// **'网络延迟'**
  String get statusItemNetworkLatency;

  /// No description provided for @statusNetworkLatencyMs.
  ///
  /// In zh, this message translates to:
  /// **'{ms} ms'**
  String statusNetworkLatencyMs(Object ms);

  /// No description provided for @statusItemConnectionType.
  ///
  /// In zh, this message translates to:
  /// **'连接类型'**
  String get statusItemConnectionType;

  /// No description provided for @statusSectionApiTests.
  ///
  /// In zh, this message translates to:
  /// **'API 测试结果'**
  String get statusSectionApiTests;

  /// No description provided for @statusValueFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get statusValueFailed;

  /// No description provided for @statusSectionSystemInfo.
  ///
  /// In zh, this message translates to:
  /// **'系统信息'**
  String get statusSectionSystemInfo;

  /// No description provided for @statusItemOs.
  ///
  /// In zh, this message translates to:
  /// **'操作系统'**
  String get statusItemOs;

  /// No description provided for @statusValueUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get statusValueUnknown;

  /// No description provided for @statusItemOsVersion.
  ///
  /// In zh, this message translates to:
  /// **'系统版本'**
  String get statusItemOsVersion;

  /// No description provided for @statusItemCpuCores.
  ///
  /// In zh, this message translates to:
  /// **'CPU 核心数'**
  String get statusItemCpuCores;

  /// No description provided for @statusSystemCpuCores.
  ///
  /// In zh, this message translates to:
  /// **'{count} 核'**
  String statusSystemCpuCores(Object count);

  /// No description provided for @statusItemDartVersion.
  ///
  /// In zh, this message translates to:
  /// **'Dart 版本'**
  String get statusItemDartVersion;

  /// No description provided for @statusSectionDownloadStats.
  ///
  /// In zh, this message translates to:
  /// **'下载统计'**
  String get statusSectionDownloadStats;

  /// No description provided for @statusItemTotalDownloads.
  ///
  /// In zh, this message translates to:
  /// **'总下载数'**
  String get statusItemTotalDownloads;

  /// No description provided for @statusItemActiveTasks.
  ///
  /// In zh, this message translates to:
  /// **'活跃任务'**
  String get statusItemActiveTasks;

  /// No description provided for @statusItemCompletedTasks.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get statusItemCompletedTasks;

  /// No description provided for @statusItemFailedTasks.
  ///
  /// In zh, this message translates to:
  /// **'失败任务'**
  String get statusItemFailedTasks;

  /// No description provided for @statusItemTotalDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'总下载量'**
  String get statusItemTotalDownloaded;

  /// No description provided for @statusSectionLogStats.
  ///
  /// In zh, this message translates to:
  /// **'日志统计'**
  String get statusSectionLogStats;

  /// No description provided for @statusItemLogCount.
  ///
  /// In zh, this message translates to:
  /// **'日志条数'**
  String get statusItemLogCount;

  /// No description provided for @statusItemErrorCount.
  ///
  /// In zh, this message translates to:
  /// **'错误数'**
  String get statusItemErrorCount;

  /// No description provided for @statusItemWarningCount.
  ///
  /// In zh, this message translates to:
  /// **'警告数'**
  String get statusItemWarningCount;

  /// No description provided for @statusSectionExtension.
  ///
  /// In zh, this message translates to:
  /// **'浏览器扩展'**
  String get statusSectionExtension;

  /// No description provided for @statusItemTip.
  ///
  /// In zh, this message translates to:
  /// **'提示'**
  String get statusItemTip;

  /// No description provided for @statusExtensionTip.
  ///
  /// In zh, this message translates to:
  /// **'感谢使用，现已支持软件内下载插件以及跳转至网页'**
  String get statusExtensionTip;

  /// No description provided for @statusExtensionDownloadButton.
  ///
  /// In zh, this message translates to:
  /// **'下载扩展插件'**
  String get statusExtensionDownloadButton;

  /// No description provided for @statusExtensionOpenStoreButton.
  ///
  /// In zh, this message translates to:
  /// **'打开商店页面'**
  String get statusExtensionOpenStoreButton;

  /// No description provided for @statusSectionAutoStart.
  ///
  /// In zh, this message translates to:
  /// **'开机自启动'**
  String get statusSectionAutoStart;

  /// No description provided for @statusItemPlatformSupport.
  ///
  /// In zh, this message translates to:
  /// **'平台支持'**
  String get statusItemPlatformSupport;

  /// No description provided for @statusAutoStartWindowsOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅支持 Windows 平台'**
  String get statusAutoStartWindowsOnly;

  /// No description provided for @statusItemAutoStartStatus.
  ///
  /// In zh, this message translates to:
  /// **'自启动状态'**
  String get statusItemAutoStartStatus;

  /// No description provided for @statusValueEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get statusValueEnabled;

  /// No description provided for @statusValueDisabled.
  ///
  /// In zh, this message translates to:
  /// **'未启用'**
  String get statusValueDisabled;

  /// No description provided for @statusItemRegistryPath.
  ///
  /// In zh, this message translates to:
  /// **'注册路径'**
  String get statusItemRegistryPath;

  /// No description provided for @statusValueCorrect.
  ///
  /// In zh, this message translates to:
  /// **'正确'**
  String get statusValueCorrect;

  /// No description provided for @statusValueNeedsUpdate.
  ///
  /// In zh, this message translates to:
  /// **'需要更新'**
  String get statusValueNeedsUpdate;

  /// No description provided for @statusItemCurrentRegistry.
  ///
  /// In zh, this message translates to:
  /// **'当前注册'**
  String get statusItemCurrentRegistry;

  /// No description provided for @statusItemCurrentPath.
  ///
  /// In zh, this message translates to:
  /// **'当前路径'**
  String get statusItemCurrentPath;

  /// No description provided for @statusAutoStartOldRegistryTitle.
  ///
  /// In zh, this message translates to:
  /// **'检测到旧版本的自启动注册'**
  String get statusAutoStartOldRegistryTitle;

  /// No description provided for @statusAutoStartOldRegistryMessage.
  ///
  /// In zh, this message translates to:
  /// **'注册的路径与当前可执行文件不匹配，可能是因为应用更新或移动了位置。点击下方按钮自动修复。'**
  String get statusAutoStartOldRegistryMessage;

  /// No description provided for @statusAutoStartFixButton.
  ///
  /// In zh, this message translates to:
  /// **'自动修复注册'**
  String get statusAutoStartFixButton;

  /// No description provided for @statusSectionPopupTest.
  ///
  /// In zh, this message translates to:
  /// **'弹窗窗口测试'**
  String get statusSectionPopupTest;

  /// No description provided for @statusItemDescription.
  ///
  /// In zh, this message translates to:
  /// **'说明'**
  String get statusItemDescription;

  /// No description provided for @statusPopupTestDescription.
  ///
  /// In zh, this message translates to:
  /// **'测试独立弹窗窗口功能（类似 IDM 风格）'**
  String get statusPopupTestDescription;

  /// No description provided for @statusItemTestResult.
  ///
  /// In zh, this message translates to:
  /// **'测试结果'**
  String get statusItemTestResult;

  /// No description provided for @statusPopupTestResultSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功 ({time}ms)'**
  String statusPopupTestResultSuccess(Object time);

  /// No description provided for @statusPopupTestResultFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败: {error}'**
  String statusPopupTestResultFailed(Object error);

  /// No description provided for @statusPopupTesting.
  ///
  /// In zh, this message translates to:
  /// **'创建中...'**
  String get statusPopupTesting;

  /// No description provided for @statusPopupTestButton.
  ///
  /// In zh, this message translates to:
  /// **'测试独立弹窗'**
  String get statusPopupTestButton;

  /// No description provided for @statusPopupDialogTestButton.
  ///
  /// In zh, this message translates to:
  /// **'测试 Dialog 弹窗'**
  String get statusPopupDialogTestButton;

  /// No description provided for @statusPopupTestInfoTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试说明'**
  String get statusPopupTestInfoTitle;

  /// No description provided for @statusPopupTestInfoBody.
  ///
  /// In zh, this message translates to:
  /// **'• 独立弹窗：使用 Tauri 创建独立窗口，不需要拉起主窗口\\n• Dialog 弹窗：传统方式，需要主窗口显示后才能弹出对话框\\n• 测试结果和耗时会记录到日志中'**
  String get statusPopupTestInfoBody;

  /// No description provided for @statusExtensionDownloadAddedTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载已添加'**
  String get statusExtensionDownloadAddedTitle;

  /// No description provided for @statusExtensionDownloadAddedMessage.
  ///
  /// In zh, this message translates to:
  /// **'浏览器扩展插件已添加到下载列表'**
  String get statusExtensionDownloadAddedMessage;

  /// No description provided for @statusExtensionDownloadFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get statusExtensionDownloadFailedTitle;

  /// No description provided for @statusExtensionDownloadFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法添加下载任务: {error}'**
  String statusExtensionDownloadFailedMessage(Object error);

  /// No description provided for @statusExtensionOpenLinkFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get statusExtensionOpenLinkFailed;

  /// No description provided for @statusExtensionOpenFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开失败'**
  String get statusExtensionOpenFailedTitle;

  /// No description provided for @statusExtensionOpenFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法打开浏览器: {error}'**
  String statusExtensionOpenFailedMessage(Object error);

  /// No description provided for @statusAutoStartFixSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'修复成功'**
  String get statusAutoStartFixSuccessTitle;

  /// No description provided for @statusAutoStartFixSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'自启动注册已更新为当前版本'**
  String get statusAutoStartFixSuccessMessage;

  /// No description provided for @statusAutoStartFixFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'修复失败'**
  String get statusAutoStartFixFailedTitle;

  /// No description provided for @statusAutoStartFixFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法更新自启动注册，请检查权限'**
  String get statusAutoStartFixFailedMessage;

  /// No description provided for @statusAutoStartFixErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'发生错误: {error}'**
  String statusAutoStartFixErrorMessage(Object error);

  /// No description provided for @statusPopupTestCreating.
  ///
  /// In zh, this message translates to:
  /// **'正在创建窗口...'**
  String get statusPopupTestCreating;

  /// No description provided for @statusPopupTestStartLog.
  ///
  /// In zh, this message translates to:
  /// **'开始测试弹窗窗口...'**
  String get statusPopupTestStartLog;

  /// No description provided for @statusPopupTestSuccessLog.
  ///
  /// In zh, this message translates to:
  /// **'弹窗窗口创建成功，耗时: {time}ms'**
  String statusPopupTestSuccessLog(Object time);

  /// No description provided for @statusPopupTestSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'窗口创建成功'**
  String get statusPopupTestSuccessMessage;

  /// No description provided for @statusPopupTestSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试成功'**
  String get statusPopupTestSuccessTitle;

  /// No description provided for @statusPopupTestSuccessToast.
  ///
  /// In zh, this message translates to:
  /// **'弹窗窗口创建成功，耗时 {time}ms'**
  String statusPopupTestSuccessToast(Object time);

  /// No description provided for @statusPopupTestFailedLog.
  ///
  /// In zh, this message translates to:
  /// **'弹窗窗口创建失败: {error}'**
  String statusPopupTestFailedLog(Object error);

  /// No description provided for @statusPopupTestFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'测试失败'**
  String get statusPopupTestFailedTitle;

  /// No description provided for @statusPopupTestFailedToast.
  ///
  /// In zh, this message translates to:
  /// **'弹窗窗口创建失败: {error}'**
  String statusPopupTestFailedToast(Object error);

  /// No description provided for @statusPopupDialogTestStartLog.
  ///
  /// In zh, this message translates to:
  /// **'开始测试 Dialog 弹窗...'**
  String get statusPopupDialogTestStartLog;

  /// No description provided for @statusPopupDialogTestCloseLog.
  ///
  /// In zh, this message translates to:
  /// **'Dialog 弹窗关闭，总耗时: {time}ms'**
  String statusPopupDialogTestCloseLog(Object time);

  /// No description provided for @statusPopupDialogTestFailedLog.
  ///
  /// In zh, this message translates to:
  /// **'Dialog 弹窗失败: {error}'**
  String statusPopupDialogTestFailedLog(Object error);

  /// No description provided for @statusApiTestHealthCheck.
  ///
  /// In zh, this message translates to:
  /// **'健康检查'**
  String get statusApiTestHealthCheck;

  /// No description provided for @statusApiTestGetTasks.
  ///
  /// In zh, this message translates to:
  /// **'获取任务'**
  String get statusApiTestGetTasks;

  /// No description provided for @statusApiTestGetStatistics.
  ///
  /// In zh, this message translates to:
  /// **'获取统计'**
  String get statusApiTestGetStatistics;

  /// No description provided for @statusApiTestGetConfig.
  ///
  /// In zh, this message translates to:
  /// **'获取配置'**
  String get statusApiTestGetConfig;

  /// No description provided for @onlineStatsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前与你同行的人'**
  String get onlineStatsPageTitle;

  /// No description provided for @onlineStatsCountUnit.
  ///
  /// In zh, this message translates to:
  /// **'位'**
  String get onlineStatsCountUnit;

  /// No description provided for @onlineStatsAloneMessage.
  ///
  /// In zh, this message translates to:
  /// **'暂时只有你在使用 Hanabi'**
  String get onlineStatsAloneMessage;

  /// No description provided for @onlineStatsOthersMessage.
  ///
  /// In zh, this message translates to:
  /// **'除了你，还有 {count} 位用户正在使用 Hanabi'**
  String onlineStatsOthersMessage(Object count);

  /// No description provided for @onlineStatsTotalMessage.
  ///
  /// In zh, this message translates to:
  /// **'（包括你在内共 {count} 位）'**
  String onlineStatsTotalMessage(Object count);

  /// No description provided for @onlineStatsMyStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前我的状态'**
  String get onlineStatsMyStatusTitle;

  /// No description provided for @onlineStatsDeviceIdLabel.
  ///
  /// In zh, this message translates to:
  /// **'设备 ID'**
  String get onlineStatsDeviceIdLabel;

  /// No description provided for @onlineStatsNotInitialized.
  ///
  /// In zh, this message translates to:
  /// **'未初始化'**
  String get onlineStatsNotInitialized;

  /// No description provided for @onlineStatsAppVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'应用版本'**
  String get onlineStatsAppVersionLabel;

  /// No description provided for @onlineStatsHeartbeatLabel.
  ///
  /// In zh, this message translates to:
  /// **'心跳间隔'**
  String get onlineStatsHeartbeatLabel;

  /// No description provided for @onlineStatsHeartbeatValue.
  ///
  /// In zh, this message translates to:
  /// **'每 5 分钟自动发送'**
  String get onlineStatsHeartbeatValue;

  /// No description provided for @onlineStatsServerLabel.
  ///
  /// In zh, this message translates to:
  /// **'统计服务器'**
  String get onlineStatsServerLabel;

  /// No description provided for @onlineStatsSending.
  ///
  /// In zh, this message translates to:
  /// **'发送中...'**
  String get onlineStatsSending;

  /// No description provided for @onlineStatsSendSignalButton.
  ///
  /// In zh, this message translates to:
  /// **'向服务器发送我的信号'**
  String get onlineStatsSendSignalButton;

  /// No description provided for @onlineStatsPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私条款'**
  String get onlineStatsPrivacyPolicy;

  /// No description provided for @onlineStatsTermsOfService.
  ///
  /// In zh, this message translates to:
  /// **'服务条款'**
  String get onlineStatsTermsOfService;

  /// No description provided for @onlineStatsOfficialSite.
  ///
  /// In zh, this message translates to:
  /// **'官网地址'**
  String get onlineStatsOfficialSite;

  /// No description provided for @onlineStatsSendSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'发送成功'**
  String get onlineStatsSendSuccessTitle;

  /// No description provided for @onlineStatsSendSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'您的信号已成功发送到服务器'**
  String get onlineStatsSendSuccessMessage;

  /// No description provided for @onlineStatsCooldownTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器已标记在线'**
  String get onlineStatsCooldownTitle;

  /// No description provided for @onlineStatsCooldownMessage.
  ///
  /// In zh, this message translates to:
  /// **'您的在线状态已被服务器记录，请在 {minutes} 分钟后再试'**
  String onlineStatsCooldownMessage(Object minutes);

  /// No description provided for @onlineStatsSendFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'发送失败'**
  String get onlineStatsSendFailedTitle;

  /// No description provided for @onlineStatsSendFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到统计服务器，请检查网络连接'**
  String get onlineStatsSendFailedMessage;

  /// No description provided for @onlineStatsOpenLinkFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get onlineStatsOpenLinkFailedTitle;

  /// No description provided for @onlineStatsOpenLinkFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'请手动在浏览器中访问：\\n{url}'**
  String onlineStatsOpenLinkFailedMessage(Object url);

  /// No description provided for @onlineStatsOpenFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开失败'**
  String get onlineStatsOpenFailedTitle;

  /// No description provided for @onlineStatsOpenFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'错误：{error}\\n\\n请手动在浏览器中访问：\\n{url}'**
  String onlineStatsOpenFailedMessage(Object error, Object url);

  /// No description provided for @onlineStatsDialogOk.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get onlineStatsDialogOk;

  /// No description provided for @logPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logPageTitle;

  /// No description provided for @logFilterLevelLabel.
  ///
  /// In zh, this message translates to:
  /// **'级别'**
  String get logFilterLevelLabel;

  /// No description provided for @logFilterTagCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个标签'**
  String logFilterTagCount(Object count);

  /// No description provided for @logFilterSourceLabel.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get logFilterSourceLabel;

  /// No description provided for @logFilterTimeSelectedLabel.
  ///
  /// In zh, this message translates to:
  /// **'时间 ✓'**
  String get logFilterTimeSelectedLabel;

  /// No description provided for @logFilterTimeLabel.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get logFilterTimeLabel;

  /// No description provided for @logRegexRulesButton.
  ///
  /// In zh, this message translates to:
  /// **'正则规则'**
  String get logRegexRulesButton;

  /// No description provided for @logAutoScrollOn.
  ///
  /// In zh, this message translates to:
  /// **'自动滚动: 开'**
  String get logAutoScrollOn;

  /// No description provided for @logAutoScrollOff.
  ///
  /// In zh, this message translates to:
  /// **'自动滚动: 关'**
  String get logAutoScrollOff;

  /// No description provided for @logStatsShow.
  ///
  /// In zh, this message translates to:
  /// **'统计: 显示'**
  String get logStatsShow;

  /// No description provided for @logStatsHide.
  ///
  /// In zh, this message translates to:
  /// **'统计: 隐藏'**
  String get logStatsHide;

  /// No description provided for @logFailureStatsShow.
  ///
  /// In zh, this message translates to:
  /// **'失败统计: 显示'**
  String get logFailureStatsShow;

  /// No description provided for @logFailureStatsHide.
  ///
  /// In zh, this message translates to:
  /// **'失败统计: 隐藏'**
  String get logFailureStatsHide;

  /// No description provided for @logExportLogsButton.
  ///
  /// In zh, this message translates to:
  /// **'导出日志'**
  String get logExportLogsButton;

  /// No description provided for @logExportDiagnosticsButton.
  ///
  /// In zh, this message translates to:
  /// **'导出诊断包'**
  String get logExportDiagnosticsButton;

  /// No description provided for @logArchiveButton.
  ///
  /// In zh, this message translates to:
  /// **'归档日志'**
  String get logArchiveButton;

  /// No description provided for @logClearButton.
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get logClearButton;

  /// No description provided for @logCurrentTabLabel.
  ///
  /// In zh, this message translates to:
  /// **'普通日志'**
  String get logCurrentTabLabel;

  /// No description provided for @logFullTabLabel.
  ///
  /// In zh, this message translates to:
  /// **'FULL LOG'**
  String get logFullTabLabel;

  /// No description provided for @logSearchPlaceholderRegex.
  ///
  /// In zh, this message translates to:
  /// **'输入正则表达式...'**
  String get logSearchPlaceholderRegex;

  /// No description provided for @logSearchPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'搜索日志...'**
  String get logSearchPlaceholder;

  /// No description provided for @logEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get logEmptyTitle;

  /// No description provided for @logEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'日志将在此处显示'**
  String get logEmptySubtitle;

  /// No description provided for @logStatTotal.
  ///
  /// In zh, this message translates to:
  /// **'总计'**
  String get logStatTotal;

  /// No description provided for @logGroupedCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 组'**
  String logGroupedCount(Object count);

  /// No description provided for @logClearFiltersButton.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get logClearFiltersButton;

  /// No description provided for @logFailureStatsTitle.
  ///
  /// In zh, this message translates to:
  /// **'下载失败统计'**
  String get logFailureStatsTitle;

  /// No description provided for @logFailureStatsTotal.
  ///
  /// In zh, this message translates to:
  /// **'总计 {count} 次'**
  String logFailureStatsTotal(Object count);

  /// No description provided for @logFailureStatsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无下载失败记录'**
  String get logFailureStatsEmpty;

  /// No description provided for @logFailureReasonUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get logFailureReasonUnknown;

  /// No description provided for @logFailureReasonAuth.
  ///
  /// In zh, this message translates to:
  /// **'鉴权失败（{code}）'**
  String logFailureReasonAuth(Object code);

  /// No description provided for @logFailureReasonNotFound.
  ///
  /// In zh, this message translates to:
  /// **'资源不存在（{code}）'**
  String logFailureReasonNotFound(Object code);

  /// No description provided for @logFailureReasonRange.
  ///
  /// In zh, this message translates to:
  /// **'Range 不支持'**
  String get logFailureReasonRange;

  /// No description provided for @logFailureReasonRangeWithCode.
  ///
  /// In zh, this message translates to:
  /// **'Range 不支持（{code}）'**
  String logFailureReasonRangeWithCode(Object code);

  /// No description provided for @logFailureReasonTooManyRequests.
  ///
  /// In zh, this message translates to:
  /// **'请求过快（{code}）'**
  String logFailureReasonTooManyRequests(Object code);

  /// No description provided for @logFailureReasonServerError.
  ///
  /// In zh, this message translates to:
  /// **'服务器错误（{code}）'**
  String logFailureReasonServerError(Object code);

  /// No description provided for @logFailureReasonHttpError.
  ///
  /// In zh, this message translates to:
  /// **'HTTP {code}'**
  String logFailureReasonHttpError(Object code);

  /// No description provided for @logFailureReasonTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时'**
  String get logFailureReasonTimeout;

  /// No description provided for @logFailureReasonConnection.
  ///
  /// In zh, this message translates to:
  /// **'连接中断'**
  String get logFailureReasonConnection;

  /// No description provided for @logFailureReasonDns.
  ///
  /// In zh, this message translates to:
  /// **'DNS 解析失败'**
  String get logFailureReasonDns;

  /// No description provided for @logFailureReasonSsl.
  ///
  /// In zh, this message translates to:
  /// **'SSL/证书错误'**
  String get logFailureReasonSsl;

  /// No description provided for @logFailureReasonChecksum.
  ///
  /// In zh, this message translates to:
  /// **'文件校验失败'**
  String get logFailureReasonChecksum;

  /// No description provided for @logFailureReasonDisk.
  ///
  /// In zh, this message translates to:
  /// **'磁盘/权限错误'**
  String get logFailureReasonDisk;

  /// No description provided for @logFailureReasonOther.
  ///
  /// In zh, this message translates to:
  /// **'其他错误'**
  String get logFailureReasonOther;

  /// No description provided for @logTimeRangeRecentMinutes.
  ///
  /// In zh, this message translates to:
  /// **'最近 {minutes} 分钟'**
  String logTimeRangeRecentMinutes(Object minutes);

  /// No description provided for @logTimeRangeRecentHours.
  ///
  /// In zh, this message translates to:
  /// **'最近 {hours} 小时'**
  String logTimeRangeRecentHours(Object hours);

  /// No description provided for @logTimeRangeLabel.
  ///
  /// In zh, this message translates to:
  /// **'时间范围'**
  String get logTimeRangeLabel;

  /// No description provided for @logStatCountUnit.
  ///
  /// In zh, this message translates to:
  /// **'条'**
  String get logStatCountUnit;

  /// No description provided for @logRepeatedCount.
  ///
  /// In zh, this message translates to:
  /// **'重复 {count} 次'**
  String logRepeatedCount(Object count);

  /// No description provided for @logRepeatedMore.
  ///
  /// In zh, this message translates to:
  /// **'... 还有 {count} 条'**
  String logRepeatedMore(Object count);

  /// No description provided for @logContextCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制日志'**
  String get logContextCopy;

  /// No description provided for @logContextRepeated.
  ///
  /// In zh, this message translates to:
  /// **'(重复 {count} 次)'**
  String logContextRepeated(Object count);

  /// No description provided for @logContextRemoveBookmark.
  ///
  /// In zh, this message translates to:
  /// **'取消书签'**
  String get logContextRemoveBookmark;

  /// No description provided for @logContextAddBookmark.
  ///
  /// In zh, this message translates to:
  /// **'添加书签'**
  String get logContextAddBookmark;

  /// No description provided for @logContextFilterLevel.
  ///
  /// In zh, this message translates to:
  /// **'筛选: {level}'**
  String logContextFilterLevel(Object level);

  /// No description provided for @logContextFilterSource.
  ///
  /// In zh, this message translates to:
  /// **'筛选: {source}'**
  String logContextFilterSource(Object source);

  /// No description provided for @logContextCopySingle.
  ///
  /// In zh, this message translates to:
  /// **'复制此条'**
  String get logContextCopySingle;

  /// No description provided for @logFilterLevelTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选日志级别'**
  String get logFilterLevelTitle;

  /// No description provided for @logFilterAllLabel.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get logFilterAllLabel;

  /// No description provided for @logDialogClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get logDialogClose;

  /// No description provided for @logSourceFilterTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选日志来源'**
  String get logSourceFilterTitle;

  /// No description provided for @logSourceTotalCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String logSourceTotalCount(Object count);

  /// No description provided for @logSourceCategoryKernel.
  ///
  /// In zh, this message translates to:
  /// **'Kernel'**
  String get logSourceCategoryKernel;

  /// No description provided for @logSourceKernelSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'下载核心 · {count} 个标签'**
  String logSourceKernelSubtitle(Object count);

  /// No description provided for @logSourceCategoryApp.
  ///
  /// In zh, this message translates to:
  /// **'App'**
  String get logSourceCategoryApp;

  /// No description provided for @logSourceAppSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'应用程序 · {count} 个标签'**
  String logSourceAppSubtitle(Object count);

  /// No description provided for @logSourceCategorySystem.
  ///
  /// In zh, this message translates to:
  /// **'System'**
  String get logSourceCategorySystem;

  /// No description provided for @logSourceSystemSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'系统 / 框架 · {count} 个标签'**
  String logSourceSystemSubtitle(Object count);

  /// No description provided for @logDialogOk.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get logDialogOk;

  /// No description provided for @logDialogCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get logDialogCancel;

  /// No description provided for @logTimeRangeTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间范围筛选'**
  String get logTimeRangeTitle;

  /// No description provided for @logTimeRangeQuickSelectLabel.
  ///
  /// In zh, this message translates to:
  /// **'快捷选择:'**
  String get logTimeRangeQuickSelectLabel;

  /// No description provided for @logTimeRangePreset1Hour.
  ///
  /// In zh, this message translates to:
  /// **'最近1小时'**
  String get logTimeRangePreset1Hour;

  /// No description provided for @logTimeRangePreset30Min.
  ///
  /// In zh, this message translates to:
  /// **'最近30分钟'**
  String get logTimeRangePreset30Min;

  /// No description provided for @logTimeRangePreset10Min.
  ///
  /// In zh, this message translates to:
  /// **'最近10分钟'**
  String get logTimeRangePreset10Min;

  /// No description provided for @logTimeRangePreset5Min.
  ///
  /// In zh, this message translates to:
  /// **'最近5分钟'**
  String get logTimeRangePreset5Min;

  /// No description provided for @logTimeRangeStartLabel.
  ///
  /// In zh, this message translates to:
  /// **'开始时间:'**
  String get logTimeRangeStartLabel;

  /// No description provided for @logTimeRangeEndLabel.
  ///
  /// In zh, this message translates to:
  /// **'结束时间:'**
  String get logTimeRangeEndLabel;

  /// No description provided for @logTimeRangeNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get logTimeRangeNotSet;

  /// No description provided for @logTimeRangeNow.
  ///
  /// In zh, this message translates to:
  /// **'现在'**
  String get logTimeRangeNow;

  /// No description provided for @logDialogClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get logDialogClear;

  /// No description provided for @logDialogApply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get logDialogApply;

  /// No description provided for @logRulesDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'高亮规则管理'**
  String get logRulesDialogTitle;

  /// No description provided for @logRulesBuiltinTitle.
  ///
  /// In zh, this message translates to:
  /// **'内置规则'**
  String get logRulesBuiltinTitle;

  /// No description provided for @logRulesCustomTitle.
  ///
  /// In zh, this message translates to:
  /// **'自定义规则'**
  String get logRulesCustomTitle;

  /// No description provided for @logRulesAddButton.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get logRulesAddButton;

  /// No description provided for @logRulesCustomEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无自定义规则'**
  String get logRulesCustomEmpty;

  /// No description provided for @logRulesLegendTitle.
  ///
  /// In zh, this message translates to:
  /// **'颜色图例'**
  String get logRulesLegendTitle;

  /// No description provided for @logRulesLegendUrl.
  ///
  /// In zh, this message translates to:
  /// **'URL'**
  String get logRulesLegendUrl;

  /// No description provided for @logRulesLegendPath.
  ///
  /// In zh, this message translates to:
  /// **'路径'**
  String get logRulesLegendPath;

  /// No description provided for @logRulesLegendIp.
  ///
  /// In zh, this message translates to:
  /// **'IP'**
  String get logRulesLegendIp;

  /// No description provided for @logRulesLegendNumber.
  ///
  /// In zh, this message translates to:
  /// **'数值'**
  String get logRulesLegendNumber;

  /// No description provided for @logRulesLegendError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get logRulesLegendError;

  /// No description provided for @logRulesLegendSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get logRulesLegendSuccess;

  /// No description provided for @logRulesLegendWarning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get logRulesLegendWarning;

  /// No description provided for @logRulesLegendHttp.
  ///
  /// In zh, this message translates to:
  /// **'HTTP'**
  String get logRulesLegendHttp;

  /// No description provided for @logRulesLegendStep.
  ///
  /// In zh, this message translates to:
  /// **'步骤'**
  String get logRulesLegendStep;

  /// No description provided for @logRulesLegendPid.
  ///
  /// In zh, this message translates to:
  /// **'PID'**
  String get logRulesLegendPid;

  /// No description provided for @logRulesLegendKeyValue.
  ///
  /// In zh, this message translates to:
  /// **'键值'**
  String get logRulesLegendKeyValue;

  /// No description provided for @logAddRuleTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加自定义规则'**
  String get logAddRuleTitle;

  /// No description provided for @logAddRuleNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'规则名称'**
  String get logAddRuleNameLabel;

  /// No description provided for @logAddRuleNamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如: 任务ID'**
  String get logAddRuleNamePlaceholder;

  /// No description provided for @logAddRulePatternLabel.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式'**
  String get logAddRulePatternLabel;

  /// No description provided for @logAddRulePatternPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如: \\b[a-f0-9]+\\b（16位）'**
  String get logAddRulePatternPlaceholder;

  /// No description provided for @logAddRuleColorLabel.
  ///
  /// In zh, this message translates to:
  /// **'高亮颜色'**
  String get logAddRuleColorLabel;

  /// No description provided for @logAddRuleInvalidTitle.
  ///
  /// In zh, this message translates to:
  /// **'正则表达式无效'**
  String get logAddRuleInvalidTitle;

  /// No description provided for @logAddRuleInvalidMessage.
  ///
  /// In zh, this message translates to:
  /// **'错误: {error}'**
  String logAddRuleInvalidMessage(Object error);

  /// No description provided for @logArchiveTitle.
  ///
  /// In zh, this message translates to:
  /// **'归档日志'**
  String get logArchiveTitle;

  /// No description provided for @logArchivePrompt.
  ///
  /// In zh, this message translates to:
  /// **'选择归档选项:'**
  String get logArchivePrompt;

  /// No description provided for @logArchiveExportAll.
  ///
  /// In zh, this message translates to:
  /// **'导出全部日志'**
  String get logArchiveExportAll;

  /// No description provided for @logArchiveExportFiltered.
  ///
  /// In zh, this message translates to:
  /// **'导出当前筛选结果'**
  String get logArchiveExportFiltered;

  /// No description provided for @logArchiveExportFull.
  ///
  /// In zh, this message translates to:
  /// **'导出 FULL LOG'**
  String get logArchiveExportFull;

  /// No description provided for @logArchiveExportBookmarked.
  ///
  /// In zh, this message translates to:
  /// **'导出书签日志 ({count})'**
  String logArchiveExportBookmarked(Object count);

  /// No description provided for @logClearConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认清空'**
  String get logClearConfirmTitle;

  /// No description provided for @logClearConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空所有日志吗？此操作不可撤销。'**
  String get logClearConfirmMessage;

  /// No description provided for @logClearConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get logClearConfirmButton;

  /// No description provided for @logExportSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出成功'**
  String get logExportSuccessTitle;

  /// No description provided for @logExportSavedMessage.
  ///
  /// In zh, this message translates to:
  /// **'日志已保存至:\\n{path}'**
  String logExportSavedMessage(Object path);

  /// No description provided for @logExportFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get logExportFailedTitle;

  /// No description provided for @logExportFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法保存日志: {error}'**
  String logExportFailedMessage(Object error);

  /// No description provided for @logDiagnosticsSavedMessage.
  ///
  /// In zh, this message translates to:
  /// **'诊断包已保存至:\\n{path}'**
  String logDiagnosticsSavedMessage(Object path);

  /// No description provided for @logDiagnosticsExportFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法导出诊断包: {error}'**
  String logDiagnosticsExportFailedMessage(Object error);

  /// No description provided for @logExportFileHeader.
  ///
  /// In zh, this message translates to:
  /// **'# 日志导出 - {time}'**
  String logExportFileHeader(Object time);

  /// No description provided for @logExportFileTotal.
  ///
  /// In zh, this message translates to:
  /// **'# 总计: {count} 条'**
  String logExportFileTotal(Object count);

  /// No description provided for @logExportSavedCountMessage.
  ///
  /// In zh, this message translates to:
  /// **'已保存 {count} 条日志至:\\n{path}'**
  String logExportSavedCountMessage(Object count, Object path);

  /// No description provided for @logExportErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'错误: {error}'**
  String logExportErrorMessage(Object error);

  /// No description provided for @logRuleUrl.
  ///
  /// In zh, this message translates to:
  /// **'URL'**
  String get logRuleUrl;

  /// No description provided for @logRuleFilePath.
  ///
  /// In zh, this message translates to:
  /// **'文件路径'**
  String get logRuleFilePath;

  /// No description provided for @logRuleIpAddress.
  ///
  /// In zh, this message translates to:
  /// **'IP地址'**
  String get logRuleIpAddress;

  /// No description provided for @logRuleNumber.
  ///
  /// In zh, this message translates to:
  /// **'数值'**
  String get logRuleNumber;

  /// No description provided for @logRuleIdHash.
  ///
  /// In zh, this message translates to:
  /// **'ID/Hash'**
  String get logRuleIdHash;

  /// No description provided for @logRuleError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get logRuleError;

  /// No description provided for @logRuleSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get logRuleSuccess;

  /// No description provided for @logRuleWarning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get logRuleWarning;

  /// No description provided for @logRuleHttpMethod.
  ///
  /// In zh, this message translates to:
  /// **'HTTP方法'**
  String get logRuleHttpMethod;

  /// No description provided for @logRuleHttpStatus.
  ///
  /// In zh, this message translates to:
  /// **'HTTP状态码'**
  String get logRuleHttpStatus;

  /// No description provided for @logRuleTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get logRuleTime;

  /// No description provided for @logRuleStep.
  ///
  /// In zh, this message translates to:
  /// **'步骤'**
  String get logRuleStep;

  /// No description provided for @logRulePid.
  ///
  /// In zh, this message translates to:
  /// **'PID'**
  String get logRulePid;

  /// No description provided for @logRuleKeyValue.
  ///
  /// In zh, this message translates to:
  /// **'键值对'**
  String get logRuleKeyValue;

  /// No description provided for @performanceMonitorTitle.
  ///
  /// In zh, this message translates to:
  /// **'性能监控'**
  String get performanceMonitorTitle;

  /// No description provided for @performanceMonitorStatusRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在监控中...'**
  String get performanceMonitorStatusRunning;

  /// No description provided for @performanceMonitorStatusIdle.
  ///
  /// In zh, this message translates to:
  /// **'点击开始监控以收集性能数据'**
  String get performanceMonitorStatusIdle;

  /// No description provided for @performanceMonitorButtonStop.
  ///
  /// In zh, this message translates to:
  /// **'停止监控'**
  String get performanceMonitorButtonStop;

  /// No description provided for @performanceMonitorButtonStart.
  ///
  /// In zh, this message translates to:
  /// **'开始监控'**
  String get performanceMonitorButtonStart;

  /// No description provided for @performanceMonitorRealtimeTitle.
  ///
  /// In zh, this message translates to:
  /// **'实时数据'**
  String get performanceMonitorRealtimeTitle;

  /// No description provided for @performanceMonitorJankBadge.
  ///
  /// In zh, this message translates to:
  /// **'JANK'**
  String get performanceMonitorJankBadge;

  /// No description provided for @performanceMonitorMetricFps.
  ///
  /// In zh, this message translates to:
  /// **'FPS'**
  String get performanceMonitorMetricFps;

  /// No description provided for @performanceMonitorMetricBuild.
  ///
  /// In zh, this message translates to:
  /// **'Build'**
  String get performanceMonitorMetricBuild;

  /// No description provided for @performanceMonitorMetricRaster.
  ///
  /// In zh, this message translates to:
  /// **'Raster'**
  String get performanceMonitorMetricRaster;

  /// No description provided for @performanceMonitorMetricTotal.
  ///
  /// In zh, this message translates to:
  /// **'Total'**
  String get performanceMonitorMetricTotal;

  /// No description provided for @performanceMonitorStatsTitle.
  ///
  /// In zh, this message translates to:
  /// **'统计摘要'**
  String get performanceMonitorStatsTitle;

  /// No description provided for @performanceMonitorStatTotalFrames.
  ///
  /// In zh, this message translates to:
  /// **'总帧数'**
  String get performanceMonitorStatTotalFrames;

  /// No description provided for @performanceMonitorStatJankFrames.
  ///
  /// In zh, this message translates to:
  /// **'卡顿帧数'**
  String get performanceMonitorStatJankFrames;

  /// No description provided for @performanceMonitorStatJankRate.
  ///
  /// In zh, this message translates to:
  /// **'卡顿率'**
  String get performanceMonitorStatJankRate;

  /// No description provided for @performanceMonitorStatAvgBuildTime.
  ///
  /// In zh, this message translates to:
  /// **'平均 Build 时间'**
  String get performanceMonitorStatAvgBuildTime;

  /// No description provided for @performanceMonitorStatAvgRasterTime.
  ///
  /// In zh, this message translates to:
  /// **'平均 Raster 时间'**
  String get performanceMonitorStatAvgRasterTime;

  /// No description provided for @performanceMonitorStatAvgTotalTime.
  ///
  /// In zh, this message translates to:
  /// **'平均 Total 时间'**
  String get performanceMonitorStatAvgTotalTime;

  /// No description provided for @performanceMonitorStatMaxBuildTime.
  ///
  /// In zh, this message translates to:
  /// **'最大 Build 时间'**
  String get performanceMonitorStatMaxBuildTime;

  /// No description provided for @performanceMonitorStatMaxRasterTime.
  ///
  /// In zh, this message translates to:
  /// **'最大 Raster 时间'**
  String get performanceMonitorStatMaxRasterTime;

  /// No description provided for @performanceMonitorStatMaxTotalTime.
  ///
  /// In zh, this message translates to:
  /// **'最大 Total 时间'**
  String get performanceMonitorStatMaxTotalTime;

  /// No description provided for @performanceMonitorRebuildTitle.
  ///
  /// In zh, this message translates to:
  /// **'Widget 重建统计'**
  String get performanceMonitorRebuildTitle;

  /// No description provided for @performanceMonitorRebuildTotal.
  ///
  /// In zh, this message translates to:
  /// **'总重建次数'**
  String get performanceMonitorRebuildTotal;

  /// No description provided for @performanceMonitorRebuildTracked.
  ///
  /// In zh, this message translates to:
  /// **'追踪的 Widget 数'**
  String get performanceMonitorRebuildTracked;

  /// No description provided for @performanceMonitorRebuildTopTitle.
  ///
  /// In zh, this message translates to:
  /// **'重建次数最多的 Widget'**
  String get performanceMonitorRebuildTopTitle;

  /// No description provided for @performanceMonitorRebuildEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无重建数据\\n在代码中调用 trackRebuild() 来追踪'**
  String get performanceMonitorRebuildEmpty;

  /// No description provided for @performanceMonitorFrameChartTitle.
  ///
  /// In zh, this message translates to:
  /// **'帧时间图表（最近 {count} 帧）'**
  String performanceMonitorFrameChartTitle(Object count);

  /// No description provided for @performanceMonitorFrameChartEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据，请开始监控'**
  String get performanceMonitorFrameChartEmpty;

  /// No description provided for @performanceMonitorLegendNormal.
  ///
  /// In zh, this message translates to:
  /// **'正常帧'**
  String get performanceMonitorLegendNormal;

  /// No description provided for @performanceMonitorLegendJankMs.
  ///
  /// In zh, this message translates to:
  /// **'卡顿帧 (> {ms} ms)'**
  String performanceMonitorLegendJankMs(Object ms);

  /// No description provided for @performanceMonitorLegendFpsThreshold.
  ///
  /// In zh, this message translates to:
  /// **'60fps 阈值'**
  String get performanceMonitorLegendFpsThreshold;

  /// No description provided for @performanceMonitorSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前渲染设置'**
  String get performanceMonitorSettingsTitle;

  /// No description provided for @performanceMonitorSettingsModeLabel.
  ///
  /// In zh, this message translates to:
  /// **'性能模式'**
  String get performanceMonitorSettingsModeLabel;

  /// No description provided for @performanceMonitorSettingsBlurLabel.
  ///
  /// In zh, this message translates to:
  /// **'模糊效果'**
  String get performanceMonitorSettingsBlurLabel;

  /// No description provided for @performanceMonitorSettingsBlurStrengthLabel.
  ///
  /// In zh, this message translates to:
  /// **'模糊强度'**
  String get performanceMonitorSettingsBlurStrengthLabel;

  /// No description provided for @performanceMonitorSettingsWindowEffectLabel.
  ///
  /// In zh, this message translates to:
  /// **'窗口特效'**
  String get performanceMonitorSettingsWindowEffectLabel;

  /// No description provided for @performanceMonitorSettingsAcrylicOpacityLabel.
  ///
  /// In zh, this message translates to:
  /// **'亚克力透明度'**
  String get performanceMonitorSettingsAcrylicOpacityLabel;

  /// No description provided for @performanceMonitorValueEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get performanceMonitorValueEnabled;

  /// No description provided for @performanceMonitorValueDisabled.
  ///
  /// In zh, this message translates to:
  /// **'禁用'**
  String get performanceMonitorValueDisabled;

  /// No description provided for @performanceMonitorWindowEffectEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用（{mode}）'**
  String performanceMonitorWindowEffectEnabled(Object mode);

  /// No description provided for @performanceMonitorWindowEffectHintEnabled.
  ///
  /// In zh, this message translates to:
  /// **'窗口特效已启用，可能影响性能。如果卡顿率较高，建议在“设置 → 界面 → 窗口效果”中关闭'**
  String get performanceMonitorWindowEffectHintEnabled;

  /// No description provided for @performanceMonitorWindowEffectHintDisabled.
  ///
  /// In zh, this message translates to:
  /// **'窗口特效已禁用，性能最佳。如需视觉效果可在“设置 → 界面 → 窗口效果”中开启'**
  String get performanceMonitorWindowEffectHintDisabled;

  /// No description provided for @performanceMonitorActionExport.
  ///
  /// In zh, this message translates to:
  /// **'导出日志'**
  String get performanceMonitorActionExport;

  /// No description provided for @performanceMonitorActionCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制到剪贴板'**
  String get performanceMonitorActionCopy;

  /// No description provided for @performanceMonitorActionClear.
  ///
  /// In zh, this message translates to:
  /// **'清空数据'**
  String get performanceMonitorActionClear;

  /// No description provided for @performanceMonitorToastClearedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已清空'**
  String get performanceMonitorToastClearedTitle;

  /// No description provided for @performanceMonitorToastClearedMessage.
  ///
  /// In zh, this message translates to:
  /// **'历史数据已清空'**
  String get performanceMonitorToastClearedMessage;

  /// No description provided for @performanceMonitorToastExportSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出成功'**
  String get performanceMonitorToastExportSuccessTitle;

  /// No description provided for @performanceMonitorToastExportSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'日志已保存到: {path}'**
  String performanceMonitorToastExportSuccessMessage(Object path);

  /// No description provided for @performanceMonitorToastExportFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出失败'**
  String get performanceMonitorToastExportFailedTitle;

  /// No description provided for @performanceMonitorToastExportFailedMessage.
  ///
  /// In zh, this message translates to:
  /// **'{error}'**
  String performanceMonitorToastExportFailedMessage(Object error);

  /// No description provided for @performanceMonitorToastCopiedTitle.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get performanceMonitorToastCopiedTitle;

  /// No description provided for @performanceMonitorToastCopiedMessage.
  ///
  /// In zh, this message translates to:
  /// **'性能日志已复制到剪贴板'**
  String get performanceMonitorToastCopiedMessage;

  /// No description provided for @performanceMonitorModeQuality.
  ///
  /// In zh, this message translates to:
  /// **'高质量'**
  String get performanceMonitorModeQuality;

  /// No description provided for @performanceMonitorModeBalanced.
  ///
  /// In zh, this message translates to:
  /// **'平衡'**
  String get performanceMonitorModeBalanced;

  /// No description provided for @performanceMonitorModePerformance.
  ///
  /// In zh, this message translates to:
  /// **'性能优先'**
  String get performanceMonitorModePerformance;

  /// No description provided for @tagActionLabel.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tagActionLabel;

  /// No description provided for @tagEditTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑标签'**
  String get tagEditTitle;

  /// No description provided for @tagEditSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'用逗号分隔标签'**
  String get tagEditSubtitle;

  /// No description provided for @tagEditPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'标签1, 标签2'**
  String get tagEditPlaceholder;

  /// No description provided for @tagFilterTitle.
  ///
  /// In zh, this message translates to:
  /// **'标签筛选'**
  String get tagFilterTitle;

  /// No description provided for @tagFilterEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用标签'**
  String get tagFilterEmpty;

  /// No description provided for @tagFilterSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择一个标签进行筛选：'**
  String get tagFilterSubtitle;

  /// No description provided for @tagFilterClearButton.
  ///
  /// In zh, this message translates to:
  /// **'清除标签筛选'**
  String get tagFilterClearButton;

  /// No description provided for @completedBatchActionsLabel.
  ///
  /// In zh, this message translates to:
  /// **'批量操作（{count} 项）'**
  String completedBatchActionsLabel(Object count);

  /// No description provided for @completedBatchRenameButton.
  ///
  /// In zh, this message translates to:
  /// **'批量重命名'**
  String get completedBatchRenameButton;

  /// No description provided for @completedBatchMoveButton.
  ///
  /// In zh, this message translates to:
  /// **'批量移动'**
  String get completedBatchMoveButton;

  /// No description provided for @completedBatchMoveSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量移动完成'**
  String get completedBatchMoveSuccessTitle;

  /// No description provided for @completedBatchMoveSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'已移动 {count} 个文件'**
  String completedBatchMoveSuccessMessage(Object count);

  /// No description provided for @completedBatchMovePartialMessage.
  ///
  /// In zh, this message translates to:
  /// **'成功 {success} 个，失败 {failed} 个'**
  String completedBatchMovePartialMessage(Object success, Object failed);

  /// No description provided for @completedBatchRenameTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量重命名'**
  String get completedBatchRenameTitle;

  /// No description provided for @completedBatchRenameHint.
  ///
  /// In zh, this message translates to:
  /// **'将前缀/后缀应用到当前列表中的文件名'**
  String get completedBatchRenameHint;

  /// No description provided for @completedBatchRenamePrefixLabel.
  ///
  /// In zh, this message translates to:
  /// **'前缀'**
  String get completedBatchRenamePrefixLabel;

  /// No description provided for @completedBatchRenamePrefixPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'prefix_'**
  String get completedBatchRenamePrefixPlaceholder;

  /// No description provided for @completedBatchRenameSuffixLabel.
  ///
  /// In zh, this message translates to:
  /// **'后缀'**
  String get completedBatchRenameSuffixLabel;

  /// No description provided for @completedBatchRenameSuffixPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'_suffix'**
  String get completedBatchRenameSuffixPlaceholder;

  /// No description provided for @completedBatchRenameEmptyWarningMessage.
  ///
  /// In zh, this message translates to:
  /// **'请至少填写前缀或后缀'**
  String get completedBatchRenameEmptyWarningMessage;

  /// No description provided for @completedBatchRenameSuccessTitle.
  ///
  /// In zh, this message translates to:
  /// **'批量重命名完成'**
  String get completedBatchRenameSuccessTitle;

  /// No description provided for @completedBatchRenameSuccessMessage.
  ///
  /// In zh, this message translates to:
  /// **'已重命名 {count} 个文件'**
  String completedBatchRenameSuccessMessage(Object count);

  /// No description provided for @completedBatchRenamePartialMessage.
  ///
  /// In zh, this message translates to:
  /// **'成功 {success} 个，失败 {failed} 个'**
  String completedBatchRenamePartialMessage(Object success, Object failed);

  /// No description provided for @settingsClipboardListenerTitle.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板监听'**
  String get settingsClipboardListenerTitle;

  /// No description provided for @settingsClipboardListenerSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'检测剪贴板中的链接并弹出新建下载'**
  String get settingsClipboardListenerSubtitle;

  /// No description provided for @settingsClipboardListenerEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板监听已开启'**
  String get settingsClipboardListenerEnabledTitle;

  /// No description provided for @settingsClipboardListenerEnabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'复制链接后会弹出新建下载窗口'**
  String get settingsClipboardListenerEnabledMessage;

  /// No description provided for @settingsClipboardListenerDisabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'剪贴板监听已关闭'**
  String get settingsClipboardListenerDisabledTitle;

  /// No description provided for @settingsClipboardListenerDisabledMessage.
  ///
  /// In zh, this message translates to:
  /// **'复制链接将不再弹窗提示'**
  String get settingsClipboardListenerDisabledMessage;

  /// No description provided for @clipboardListenerMuteSessionButton.
  ///
  /// In zh, this message translates to:
  /// **'本次静音'**
  String get clipboardListenerMuteSessionButton;

  /// No description provided for @clipboardListenerSessionMutedTitle.
  ///
  /// In zh, this message translates to:
  /// **'本次会话已静音'**
  String get clipboardListenerSessionMutedTitle;

  /// No description provided for @clipboardListenerSessionMutedMessage.
  ///
  /// In zh, this message translates to:
  /// **'自动抓取链接将暂停到你下次重新启动应用'**
  String get clipboardListenerSessionMutedMessage;

  /// No description provided for @downloadDuplicateTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现重复下载'**
  String get downloadDuplicateTitle;

  /// No description provided for @downloadDuplicateMessage.
  ///
  /// In zh, this message translates to:
  /// **'已存在相同链接的任务：{fileName}（{status}）。要如何处理？'**
  String downloadDuplicateMessage(Object fileName, Object status);

  /// No description provided for @downloadDuplicateUseExistingButton.
  ///
  /// In zh, this message translates to:
  /// **'使用已有'**
  String get downloadDuplicateUseExistingButton;

  /// No description provided for @downloadDuplicateAddNewButton.
  ///
  /// In zh, this message translates to:
  /// **'仍然新建'**
  String get downloadDuplicateAddNewButton;

  /// No description provided for @downloadDuplicateCancelButton.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get downloadDuplicateCancelButton;

  /// No description provided for @downloadBadgeHostHint.
  ///
  /// In zh, this message translates to:
  /// **'站点缓存'**
  String get downloadBadgeHostHint;

  /// No description provided for @downloadBadgePolicyFallback.
  ///
  /// In zh, this message translates to:
  /// **'已降级'**
  String get downloadBadgePolicyFallback;

  /// No description provided for @downloadBadgeConcurrencyCap.
  ///
  /// In zh, this message translates to:
  /// **'限并发 x{count}'**
  String downloadBadgeConcurrencyCap(Object count);

  /// No description provided for @downloadFailureHintAuth.
  ///
  /// In zh, this message translates to:
  /// **'可能需要登录或补充 Referer/Cookie，链接可能已过期。'**
  String get downloadFailureHintAuth;

  /// No description provided for @downloadFailureHintNotFound.
  ///
  /// In zh, this message translates to:
  /// **'资源不存在或已过期，尝试更新链接。'**
  String get downloadFailureHintNotFound;

  /// No description provided for @downloadFailureHintRange.
  ///
  /// In zh, this message translates to:
  /// **'服务器不支持断点续传，建议单线程或重新下载。'**
  String get downloadFailureHintRange;

  /// No description provided for @downloadFailureHintRateLimit.
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁，请稍后重试。'**
  String get downloadFailureHintRateLimit;

  /// No description provided for @downloadFailureHintServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器错误，请稍后重试。'**
  String get downloadFailureHintServer;

  /// No description provided for @downloadFailureHintHttp.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 错误，请检查链接或权限。'**
  String get downloadFailureHintHttp;

  /// No description provided for @downloadFailureHintTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接超时，检查网络后重试。'**
  String get downloadFailureHintTimeout;

  /// No description provided for @downloadFailureHintConnection.
  ///
  /// In zh, this message translates to:
  /// **'连接中断，检查网络或代理设置。'**
  String get downloadFailureHintConnection;

  /// No description provided for @downloadFailureHintDns.
  ///
  /// In zh, this message translates to:
  /// **'域名解析失败，检查网络或 DNS。'**
  String get downloadFailureHintDns;

  /// No description provided for @downloadFailureHintSsl.
  ///
  /// In zh, this message translates to:
  /// **'SSL 证书错误，尝试更换来源。'**
  String get downloadFailureHintSsl;

  /// No description provided for @downloadFailureHintChecksum.
  ///
  /// In zh, this message translates to:
  /// **'文件可能损坏，建议重新下载。'**
  String get downloadFailureHintChecksum;

  /// No description provided for @downloadFailureHintDisk.
  ///
  /// In zh, this message translates to:
  /// **'磁盘空间不足或权限不足，请检查保存目录。'**
  String get downloadFailureHintDisk;

  /// No description provided for @settingsConflictStrategyTitle.
  ///
  /// In zh, this message translates to:
  /// **'重名冲突策略'**
  String get settingsConflictStrategyTitle;

  /// No description provided for @settingsConflictStrategySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'当文件已存在时的处理方式'**
  String get settingsConflictStrategySubtitle;

  /// No description provided for @settingsConflictStrategyIncrement.
  ///
  /// In zh, this message translates to:
  /// **'自动加 (1)(2)'**
  String get settingsConflictStrategyIncrement;

  /// No description provided for @settingsConflictStrategyTimestamp.
  ///
  /// In zh, this message translates to:
  /// **'追加时间戳'**
  String get settingsConflictStrategyTimestamp;

  /// No description provided for @settingsConflictStrategyOverwrite.
  ///
  /// In zh, this message translates to:
  /// **'覆盖原文件'**
  String get settingsConflictStrategyOverwrite;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
