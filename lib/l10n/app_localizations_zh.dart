// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Hanabi Download Manager X';

  @override
  String get aboutEasterEggCongrats => '恭喜你发现了这个彩蛋！';

  @override
  String get aboutEasterEggTitle => '这个彩蛋没什么用';

  @override
  String aboutEasterEggMessage(Object appName) {
    return '但是感谢你使用 $appName！\\n感谢你的支持\\n希望你可以给他一个 Star';
  }

  @override
  String get aboutEasterEggDismiss => '假装不知道';

  @override
  String aboutMadeBy(Object developer) {
    return '作者 $developer';
  }

  @override
  String get aboutEasterEggDialogTitle => '嘿！';

  @override
  String get aboutPageTitle => '关于';

  @override
  String get aboutSectionAppInfo => '应用信息';

  @override
  String aboutTapHintRemaining(Object count) {
    return '再点 $count 次...';
  }

  @override
  String aboutVersionLabel(Object version) {
    return 'v$version';
  }

  @override
  String get aboutSectionDetails => '详细信息';

  @override
  String get aboutDetailDeveloperLabel => '开发者';

  @override
  String get aboutDetailKernelLabel => '下载核心';

  @override
  String get aboutDetailUiFrameworkLabel => 'UI 框架';

  @override
  String get aboutDetailUiFrameworkValue => 'Fluent UI for Flutter';

  @override
  String get aboutSectionLinks => '链接';

  @override
  String get aboutLinkOfficialTitle => '官方网站';

  @override
  String get aboutLinkOfficialSubtitle => '访问项目主页';

  @override
  String get aboutLinkGithubTitle => 'GitHub';

  @override
  String get aboutLinkGithubSubtitle => '查看源代码和贡献';

  @override
  String get aboutLinkContactTitle => '联系我们';

  @override
  String aboutCopyrightMessage(Object year, Object developer) {
    return '© $year $developer。保留所有权利。';
  }

  @override
  String get aboutOpenLinkErrorTitle => '错误';

  @override
  String aboutOpenLinkErrorMessage(Object error) {
    return '打开链接失败: $error';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsTabGeneral => '常规';

  @override
  String get settingsTabDownload => '下载';

  @override
  String get settingsTabAppearance => '界面';

  @override
  String get settingsTabUpdate => '更新';

  @override
  String get settingsTabAdvanced => '高级';

  @override
  String get settingsTabDeveloper => '开发者';

  @override
  String get appearanceSectionLanguage => '语言';

  @override
  String get appearanceLanguageTitle => '界面语言';

  @override
  String get appearanceLanguageSubtitle => '默认跟随系统：系统将自动为您选择合适的界面语言';

  @override
  String get appearanceLanguageSystem => '跟随系统';

  @override
  String get appearanceLanguageChinese => '中文';

  @override
  String get appearanceLanguageEnglish => 'English';

  @override
  String get appearanceLanguageSwitchedTitle => '语言已切换';

  @override
  String get appearanceLanguageSwitchedSystem => '将根据系统语言自动选择';

  @override
  String appearanceLanguageSwitchedTo(Object language) {
    return '已切换为 $language';
  }

  @override
  String get appearanceLanguagePacksTitle => '语言包';

  @override
  String appearanceLanguagePacksSubtitle(Object path) {
    return '把 .json/.arb 放到 $path 后点击刷新';
  }

  @override
  String get appearanceLanguagePacksRefreshedTitle => '已刷新语言包';

  @override
  String appearanceLanguagePacksRefreshedMessage(Object count) {
    return '发现 $count 个语言包';
  }

  @override
  String get appearanceLanguageRefreshButton => '刷新语言包';

  @override
  String get trayMenuShowWindowTitle => '显示窗口';

  @override
  String get trayMenuShowWindowSubtitle => '打开主界面';

  @override
  String get trayMenuKernelTitle => '下载内核';

  @override
  String get trayMenuKernelSubtitleRunning => '运行中';

  @override
  String get trayMenuKernelSubtitleStopped => '已停止';

  @override
  String get trayMenuExitTitle => '退出应用';

  @override
  String get trayMenuExitSubtitle => '关闭所有窗口';

  @override
  String get tempFilesDialogTitle => '清理临时文件';

  @override
  String tempFilesDialogScanPath(Object path) {
    return '扫描路径: $path';
  }

  @override
  String get tempFilesStatFiles => '文件数';

  @override
  String get tempFilesStatTotalSize => '总大小';

  @override
  String get tempFilesStatSelected => '已选';

  @override
  String get tempFilesSupportedFormats =>
      '支持格式: .temp, .tmp, .download, .partN (分段), .crdownload, .partial, .!ut';

  @override
  String get tempFilesSelectAll => '全选';

  @override
  String get tempFilesIncludeTempDirs => '包含临时目录';

  @override
  String get tempFilesSortLabel => '排序:';

  @override
  String get tempFilesSortName => '名称';

  @override
  String get tempFilesSortSize => '大小';

  @override
  String get tempFilesSortTime => '时间';

  @override
  String get tempFilesEmpty => '没有找到临时文件';

  @override
  String get tempFilesCloseButton => '关闭';

  @override
  String tempFilesDeleteSelected(Object count) {
    return '删除选中 ($count)';
  }

  @override
  String get tempFilesDeleteConfirmTitle => '确认删除';

  @override
  String tempFilesDeleteConfirmMessage(Object count) {
    return '确定要删除 $count 个临时文件吗？';
  }

  @override
  String tempFilesDeleteTotalSize(Object size) {
    return '总大小: $size';
  }

  @override
  String get tempFilesDeleteWarning => '此操作不可恢复';

  @override
  String get tempFilesCancelButton => '取消';

  @override
  String get tempFilesDeleteButton => '删除';

  @override
  String get tempFilesDeleteDoneTitle => '删除完成';

  @override
  String tempFilesDeleteDoneWithFailures(Object success, Object failed) {
    return '成功删除 $success 个，失败 $failed 个';
  }

  @override
  String tempFilesDeleteDoneSuccess(Object success) {
    return '成功删除 $success 个临时文件';
  }

  @override
  String get homeNavDownloading => '下载中';

  @override
  String get homeNavCompleted => '已完成';

  @override
  String get homeNavLog => '日志';

  @override
  String get homeNavStatus => '状态';

  @override
  String get homeNavWebCheck => 'Web检测';

  @override
  String get homeNavOnlineStats => '在线统计';

  @override
  String get homeNavPerformance => '性能监控';

  @override
  String get homeNavSettings => '设置';

  @override
  String get homeNavAbout => '关于';

  @override
  String get homeUpdateFoundTitle => '检测到了新版本';

  @override
  String homeUpdateFoundMessage(Object currentVersion, Object newVersion) {
    return '本次更新为 $currentVersion -> $newVersion\\n快去设置页面更新吧！';
  }

  @override
  String get homeKernelStartingTitle => '正在启动下载内核...';

  @override
  String get homeKernelStartingHint => '请稍候，这可能需要几秒钟';

  @override
  String get homeViewLog => '查看日志';

  @override
  String get homeRetry => '重试';

  @override
  String get homeNewTask => '新建';

  @override
  String get fileName => '文件名';

  @override
  String get id => 'ID';

  @override
  String get name => '名称';

  @override
  String get segments => '分段';

  @override
  String get speed => '速度';

  @override
  String get status => '状态';

  @override
  String get url => 'URL';

  @override
  String get settingsSectionSystem => '系统设置';

  @override
  String get settingsAutoStartTitle => '开机自启';

  @override
  String get settingsAutoStartSubtitle => '系统启动时自动运行应用程序';

  @override
  String get settingsAutoStartEnabledTitle => '开机自启已开启';

  @override
  String get settingsAutoStartEnabledMessage => '软件将随系统启动自动运行';

  @override
  String get settingsAutoStartDisabledTitle => '开机自启已关闭';

  @override
  String get settingsAutoStartDisabledMessage => '软件将不会自动运行';

  @override
  String get settingsAutoStartEnableFailed => '无法开启开机自启';

  @override
  String get settingsAutoStartDisableFailed => '无法关闭开机自启';

  @override
  String get settingsAutoStartFixedTitle => '自启动已修复';

  @override
  String get settingsAutoStartFixedMessage => '检测到旧版本的自启动注册，已自动更新为当前版本';

  @override
  String get settingsSectionBehavior => '行为设置';

  @override
  String get settingsAutoDownloadTitle => '自动开始下载';

  @override
  String get settingsAutoDownloadSubtitle => '新任务将自动开始下载';

  @override
  String get settingsAutoDownloadEnabledTitle => '自动开始下载已开启';

  @override
  String get settingsAutoDownloadEnabledMessage => '新任务将自动开始下载';

  @override
  String get settingsAutoDownloadDisabledTitle => '自动下载已关闭';

  @override
  String get settingsAutoDownloadDisabledMessage => '新任务将等待手动开始';

  @override
  String get settingsPopupWindowTitle => '浏览器下载弹窗';

  @override
  String get settingsPopupWindowSubtitle => '显示下载弹窗';

  @override
  String get settingsPopupEnabledTitle => '弹窗已开启';

  @override
  String get settingsPopupEnabledMessage => '浏览器下载将弹出小窗确认';

  @override
  String get settingsPopupDisabledTitle => '弹窗已关闭';

  @override
  String get settingsPopupDisabledMessage => '弹窗已关闭';

  @override
  String get settingsCompleteNotifyTitle => '完成通知';

  @override
  String get settingsCompleteNotifySubtitle => '下载完成时通知';

  @override
  String get settingsCompleteNotifyEnabledTitle => '完成通知已开启';

  @override
  String get settingsCompleteNotifyEnabledMessage => '下载完成时将发送通知';

  @override
  String get settingsCompleteNotifyDisabledTitle => '完成通知已关闭';

  @override
  String get settingsCompleteNotifyDisabledMessage => '下载完成时不再通知';

  @override
  String get settingsOnlineStatsTitle => '参与在线统计';

  @override
  String get settingsOnlineStatsSubtitle => '参与在线用户统计';

  @override
  String get settingsOnlineStatsEnabledTitle => '在线统计已启用';

  @override
  String get settingsOnlineStatsEnabledMessage => '您的设备将参与在线用户统计，帮助我们了解软件使用情况';

  @override
  String get settingsOnlineStatsDisabledTitle => '在线统计已禁用';

  @override
  String get settingsOnlineStatsDisabledMessage => '您的设备将不再发送统计信息';

  @override
  String get settingsTrayHintTitle => '托盘提示';

  @override
  String get settingsTrayHintSubtitle => '托盘提示显示运行状态';

  @override
  String get settingsTrayHintEnabledTitle => '已开启后台运行提示';

  @override
  String get settingsTrayHintEnabledMessage => '当窗口隐藏时，托盘图标将显示\"正在后台运行\"';

  @override
  String get settingsTrayHintDisabledTitle => '后台运行提示已关闭';

  @override
  String get settingsTrayHintDisabledMessage => '托盘图标将始终只显示应用名称';

  @override
  String get settingsCloseBehaviorTitle => '关闭按钮行为';

  @override
  String get settingsCloseBehaviorMinimizeLabel => 'minimize_to_tray';

  @override
  String get settingsCloseBehaviorExitLabel => '退出应用';

  @override
  String get settingsCloseBehaviorMinimize => '最小化到系统托盘，保持后台运行';

  @override
  String get settingsCloseBehaviorExit => '完全退出应用程序';

  @override
  String get settingsCloseBehaviorUnknown => '未知行为';

  @override
  String settingsCloseBehaviorSavedMessage(Object behavior) {
    return '关闭按钮行为已设为$behavior';
  }

  @override
  String get settingsSaveSuccessTitle => '设置已保存';

  @override
  String get settingsSaveFailedTitle => '设置失败';

  @override
  String settingsSaveFailedMessage(Object error) {
    return '无法保存设置: $error';
  }

  @override
  String get settingsDownloadPathSection => '下载路径';

  @override
  String get settingsDownloadPathTitle => '保存位置';

  @override
  String get settingsDownloadPathChangeButton => '更改';

  @override
  String get settingsDownloadPathDialogTitle => '设置下载路径';

  @override
  String get settingsDownloadPathDialogPrompt => '请输入或浏览选择下载保存路径:';

  @override
  String get settingsDownloadPathPlaceholder => 'C:\\\\Downloads';

  @override
  String get settingsBrowseButton => '浏览';

  @override
  String get settingsDownloadPathHintTitle => '提示:';

  @override
  String get settingsDownloadPathHintBody =>
      '• 可以直接输入完整的文件夹路径\\n• 点击\"浏览\"按钮可视化选择文件夹\\n• 示例: C:\\\\Users\\\\用户名\\\\Downloads';

  @override
  String get settingsCancelButton => '取消';

  @override
  String get settingsConfirmButton => '确定';

  @override
  String settingsDownloadPathChangedMessage(Object path) {
    return '下载路径已更改为: $path';
  }

  @override
  String get settingsDownloadPathChangeFailedMessage => '无法更改下载路径，请检查路径是否有效';

  @override
  String get settingsDownloadConfigSection => '下载配置';

  @override
  String get settingsDownloadModeTitle => '下载模式';

  @override
  String get settingsDownloadModeAuto => 'auto';

  @override
  String get settingsDownloadModeThreadsOnly => '仅线程';

  @override
  String get settingsDownloadModeSegmentsOnly => '仅分段';

  @override
  String get settingsDownloadModeManual => '手动';

  @override
  String get settingsThreadsTitle => '线程数';

  @override
  String get settingsThreadsSubtitle => '下载线程数量';

  @override
  String get settingsSegmentsTitle => '分段数';

  @override
  String get settingsSegmentsSubtitle => '每个任务的分段数量';

  @override
  String get settingsDynamicSegmentsTitle => '动态分段';

  @override
  String get settingsDynamicSegmentsSubtitle => '根据文件大小自动调整分段';

  @override
  String get settingsDynamicSegmentsEnabledTitle => '动态分段已开启';

  @override
  String get settingsDynamicSegmentsEnabledMessage => '分段数将自动调整';

  @override
  String get settingsDynamicSegmentsDisabledTitle => '动态分段已关闭';

  @override
  String get settingsDynamicSegmentsDisabledMessage => '分段数将保持固定';

  @override
  String get settingsMaxConcurrentTitle => '最大同时下载任务数';

  @override
  String get settingsMaxConcurrentSubtitle => '限制并发下载任务数量';

  @override
  String get settingsSegmentSpeedLimitTitle => '分段限速';

  @override
  String get settingsSegmentSpeedLimitSubtitle => '限制单分段速度';

  @override
  String get settingsSpeedUnlimited => '不限速';

  @override
  String settingsSpeedTotal(Object speed) {
    return '总: $speed KB/s';
  }

  @override
  String settingsPopupSaveFailedMessage(Object error) {
    return '无法保存弹窗设置: $error';
  }

  @override
  String get settingsProxySection => '代理设置';

  @override
  String get settingsProxyEnableTitle => '使用代理';

  @override
  String get settingsProxyEnableSubtitle => '为下载启用代理';

  @override
  String get settingsProxySavedTitle => '代理设置已保存';

  @override
  String settingsProxyEnabledMessage(Object host, Object port) {
    return '已启用代理: $host:$port';
  }

  @override
  String get settingsProxyDisabledMessage => '已禁用代理';

  @override
  String get settingsProxyTypeTitle => '代理类型';

  @override
  String get settingsProxyTypeSubtitle => '选择代理协议';

  @override
  String get settingsProxyTypeSystem => 'system';

  @override
  String get settingsProxyTypeHttp => 'HTTP';

  @override
  String get settingsProxyTypeSocks5 => 'SOCKS5';

  @override
  String get settingsProxyServerTitle => '代理服务器';

  @override
  String get settingsProxyServerSubtitle => '服务器地址和端口';

  @override
  String get settingsProxyHostPlaceholder => '代理地址 (如: 127.0.0.1)';

  @override
  String get settingsProxyAuthTitle => '代理认证';

  @override
  String get settingsProxyAuthSubtitle => '需要用户名和密码';

  @override
  String get settingsProxyUsernameTitle => '用户名';

  @override
  String get settingsProxyUsernameSubtitle => '代理账号用户名';

  @override
  String get settingsProxyUsernamePlaceholder => '用户名';

  @override
  String get settingsProxyPasswordTitle => '密码';

  @override
  String get settingsProxyPasswordSubtitle => '代理账号密码';

  @override
  String get settingsProxyPasswordPlaceholder => '密码';

  @override
  String get settingsProxyTipsTitle => '代理配置提示';

  @override
  String get settingsProxyTipsSystem =>
      '• 自动使用系统配置的代理设置\\n• 支持 Windows、macOS 和 Linux 系统代理\\n• 配置后将应用到所有新的下载任务\\n• 正在进行的下载不会受到影响';

  @override
  String get settingsProxyTipsHttp =>
      '• 使用 HTTP/HTTPS 代理协议\\n• 配置后将应用到所有新的下载任务\\n• 正在进行的下载不会受到影响\\n• 支持用户名密码认证';

  @override
  String get settingsProxyTipsSocks5 =>
      '• 使用 SOCKS5 代理协议\\n• 需要安装 aiohttp-socks 库支持\\n• 配置后将应用到所有新的下载任务\\n• 正在进行的下载不会受到影响';

  @override
  String get settingsProxyTipsDefault =>
      '• 支持系统代理、HTTP/HTTPS 和 SOCKS5 代理\\n• 配置后将应用到所有新的下载任务\\n• 正在进行的下载不会受到影响';

  @override
  String get settingsProxyTestButton => '测试连接';

  @override
  String get settingsProxyTestingTitle => '正在测试...';

  @override
  String get settingsProxyTestingMessage => '请稍候';

  @override
  String get settingsProxyTestSuccessTitle => '连接成功';

  @override
  String get settingsProxyTestSuccessMessage => '代理服务器连接正常，可以正常使用';

  @override
  String get settingsProxyTestFailedTitle => '连接失败';

  @override
  String get settingsProxyTestFailedMessage => '无法连接到代理服务器，请检查配置';

  @override
  String get settingsProxyTestErrorTitle => '测试失败';

  @override
  String settingsProxyTestErrorMessage(Object error) {
    return '代理连接测试失败: $error';
  }

  @override
  String get settingsProxyErrorTitle => '配置错误';

  @override
  String get settingsProxyErrorMessage => '请先输入代理服务器地址';

  @override
  String get settingsKernelSection => '下载内核';

  @override
  String get settingsKernelCurrentTitle => '当前内核';

  @override
  String get settingsKernelOnline => '在线';

  @override
  String get settingsKernelOffline => '离线';

  @override
  String get settingsKernelNsfxTitle => 'NSFX';

  @override
  String get settingsKernelNsfxSubtitle => '切换到新内核';

  @override
  String get settingsKernelNsfxHint => 'NSFX Kernel: 高效 | 简洁 | 新思路';

  @override
  String get settingsKernelSodaHint => '旧内核用于兼容性';

  @override
  String get settingsKernelSwitchedTitle => '内核已切换';

  @override
  String settingsKernelSwitchedMessage(Object kernelName) {
    return '当前使用: $kernelName';
  }

  @override
  String get settingsKernelSwitchedLegacyMessage => '已切换到旧内核';

  @override
  String get settingsKernelSwitchFailedTitle => '切换失败';

  @override
  String get settingsKernelSwitchFailedNewMessage => '无法启动新内核，请稍后重试';

  @override
  String get settingsKernelSwitchFailedLegacyMessage => '无法启动旧内核，请稍后重试';

  @override
  String get settingsStatusTitle => '系统状态';

  @override
  String get settingsStatusKernelNsfx => 'NSFX Kernel';

  @override
  String get settingsStatusKernelSoda => 'Soda 内核（旧版）';

  @override
  String get settingsStatusBrowserExtension => 'Browser Extension';

  @override
  String get settingsModeDescriptionAuto => '智能动态分段，根据文件大小自动优化 (推荐)';

  @override
  String get settingsModeDescriptionThreadsOnly => '手动设置线程数，分段数自动计算';

  @override
  String get settingsModeDescriptionSegmentsOnly => '手动设置分段数，线程数自动计算';

  @override
  String get settingsModeDescriptionManual => '完全手动控制，适合高级用户';

  @override
  String get settingsModeDescriptionUnknown => '未知模式';

  @override
  String get settingsDeveloperSection => '开发者选项';

  @override
  String get settingsDeveloperModeTitle => '开发者模式';

  @override
  String get settingsDeveloperModeSubtitle => '启用调试和诊断功能';

  @override
  String get settingsDeveloperModeHint => '开发者模式已启用，请切换到\"开发者\"标签页进行详细配置';

  @override
  String get settingsDeveloperModeEnabledTitle => '开发者模式已开启';

  @override
  String get settingsDeveloperModeEnabledMessage => '已启用高级调试功能';

  @override
  String get settingsDeveloperModeDisabledTitle => '开发者模式已关闭';

  @override
  String get settingsDeveloperModeDisabledMessage => '已禁用高级调试功能';

  @override
  String get settingsDeveloperPageVisibilityTitle => '调试页面显示设置';

  @override
  String get settingsDeveloperShowLogTitle => '显示日志页面';

  @override
  String get settingsDeveloperShowLogSubtitle => '在导航栏显示日志查看器';

  @override
  String get settingsDeveloperShowStatusTitle => '显示状态页面';

  @override
  String get settingsDeveloperShowStatusSubtitle => '在导航栏显示系统状态监控';

  @override
  String get settingsDeveloperShowOnlineStatsTitle => '显示在线统计页面';

  @override
  String get settingsDeveloperShowOnlineStatsSubtitle => '在导航栏显示在线用户统计';

  @override
  String get settingsDeveloperShowWebCheckTitle => '显示 Web 检测页面';

  @override
  String get settingsDeveloperShowWebCheckSubtitle => '在导航栏显示网站状态检测工具';

  @override
  String get settingsDeveloperPageHint => '调试页面会占用系统资源，建议仅在需要时启用';

  @override
  String get settingsDangerCleanTempTitle => '清理临时文件';

  @override
  String get settingsDangerCleanTempSubtitle => '扫描并删除下载目录中的 .temp 临时文件';

  @override
  String get settingsDangerCleanTempButton => '清理临时文件';

  @override
  String get settingsDangerClearDataTitle => '清除所有数据';

  @override
  String get settingsDangerClearDataSubtitle => '删除所有下载任务和历史记录';

  @override
  String get settingsDangerClearDataButton => '清除数据';

  @override
  String get settingsDangerConfirmTitle => '确认清除';

  @override
  String get settingsDangerConfirmMessage => '确定要清除所有下载任务和历史记录吗？此操作不可恢复。';

  @override
  String get settingsDangerConfirmButton => '确认清除';

  @override
  String get settingsDangerClearingTitle => '正在清除...';

  @override
  String get settingsDangerClearingMessage => '请稍候';

  @override
  String get settingsDangerClearedTitle => '已清除';

  @override
  String get settingsDangerClearedMessage => '所有下载任务和历史记录已清除';

  @override
  String get settingsDangerClearFailedTitle => '清除失败';

  @override
  String get settingsDangerClearFailedMessage => '无法清除数据，请确保下载核心正在运行';

  @override
  String get settingsUserLoading => '获取中...';

  @override
  String get settingsUserLoadFailed => '获取失败';

  @override
  String get settingsUserUnknown => '未知用户';

  @override
  String get appearanceWindowSizeSection => '窗口大小';

  @override
  String get appearanceWindowRememberTitle => '记忆窗口大小';

  @override
  String get appearanceWindowRememberSubtitleOn => '启动时使用上次关闭时的窗口大小';

  @override
  String get appearanceWindowRememberSubtitleOff => '启动时使用默认窗口大小';

  @override
  String get appearanceWindowDefaultWidthTitle => '默认窗口宽度';

  @override
  String appearanceWindowDefaultWidthSubtitle(Object max) {
    return '启动默认宽度 (600-$max)';
  }

  @override
  String get appearanceWindowDefaultHeightTitle => '默认窗口高度';

  @override
  String appearanceWindowDefaultHeightSubtitle(Object max) {
    return '启动默认高度 (400-$max)';
  }

  @override
  String get appearanceWindowSaveTitle => '已保存';

  @override
  String appearanceWindowSaveMessage(Object width, Object height) {
    return '已将当前窗口大小设为默认 ($width×$height)';
  }

  @override
  String appearanceWindowSaveButton(Object width, Object height) {
    return '使用当前大小 ($width×$height)';
  }

  @override
  String get appearanceWindowResetTitle => '已重置';

  @override
  String get appearanceWindowResetMessage => '已重置默认窗口大小为 889×586';

  @override
  String get appearanceWindowResetButton => '重置为默认';

  @override
  String get appearanceWindowApplyTitle => '已应用';

  @override
  String appearanceWindowApplyMessage(Object width, Object height) {
    return '窗口大小已调整为 $width×$height';
  }

  @override
  String appearanceWindowApplyButton(Object width, Object height) {
    return '立即应用默认大小 ($width×$height)';
  }

  @override
  String get appearanceWindowRememberHintOn => '当前启用记忆模式，应用会记住上次关闭时的窗口大小';

  @override
  String get appearanceWindowRememberHintOff => '已启用默认大小模式，应用将使用设定尺寸';

  @override
  String get appearanceUiScaleSection => 'UI 缩放';

  @override
  String get appearanceUiScaleTitle => '界面缩放比例';

  @override
  String get appearanceUiScaleSubtitle => '调整高分屏 UI 缩放比例 (50%-200%)';

  @override
  String get appearanceUiScaleResetTitle => '已重置';

  @override
  String get appearanceUiScaleResetMessage => 'UI 缩放已重置为 100%';

  @override
  String get appearanceUiScaleResetButton => '重置为100%';

  @override
  String get appearanceUiScaleApplyTitle => '已应用';

  @override
  String get appearanceUiScaleApplyMessage => 'UI 缩放已设置为 125%（4K 推荐）';

  @override
  String get appearanceUiScale4kButton => '4K推荐 (125%)';

  @override
  String get appearanceUiScaleHint => '调整此设置可以让应用在高分辨率屏幕上显示更清晰。4K屏幕推荐125%-150%';

  @override
  String get appearanceFontSection => '字体';

  @override
  String get appearanceFontTitle => '应用字体';

  @override
  String get appearanceFontSystemSubtitle => '使用系统默认字体';

  @override
  String appearanceFontCurrentSubtitle(Object font) {
    return '当前字体: $font';
  }

  @override
  String get appearanceFontSystemLabel => 'system';

  @override
  String get appearanceFontImportButton => '导入字体';

  @override
  String get appearanceFontDeleteButton => '删除当前字体';

  @override
  String get appearanceFontHint => '支持导入 .ttf 和 .otf 格式的字体文件';

  @override
  String get appearanceFontChangedTitle => '字体已更改';

  @override
  String get appearanceFontChangedMessage => '字体已应用';

  @override
  String get appearanceFontImportDialogTitle => '选择字体文件';

  @override
  String get appearanceFontImportingTitle => '正在导入字体...';

  @override
  String get appearanceFontImportingMessage => '请稍候';

  @override
  String get appearanceFontImportSuccessTitle => '导入成功';

  @override
  String get appearanceFontImportSuccessMessage => '字体导入成功';

  @override
  String get appearanceFontImportFailedTitle => '导入失败';

  @override
  String get appearanceFontImportFailedMessage => '无法导入字体文件，请检查格式';

  @override
  String appearanceFontImportFailedWithErrorMessage(Object error) {
    return '导入失败: $error';
  }

  @override
  String get appearanceFontDeleteConfirmTitle => '确认删除';

  @override
  String appearanceFontDeleteConfirmMessage(Object fontName) {
    return '确定删除字体 \"$fontName\" 吗？';
  }

  @override
  String get appearanceFontDeleteCancelButton => '取消';

  @override
  String get appearanceFontDeleteConfirmButton => '删除';

  @override
  String get appearanceFontDeleteSuccessTitle => '删除成功';

  @override
  String get appearanceFontDeleteSuccessMessage => '字体已删除';

  @override
  String get appearanceFontDeleteFailedTitle => '删除失败';

  @override
  String get appearanceFontDeleteFailedMessage => '无法删除字体';

  @override
  String get appearanceFontPickerTitle => '选择字体';

  @override
  String get appearanceFontPickerSearchPlaceholder => '搜索字体...';

  @override
  String appearanceFontPickerCount(Object count) {
    return '共 $count 个字体';
  }

  @override
  String get appearanceFontPickerFilteredLabel => '(已过滤)';

  @override
  String get appearanceFontPickerEmpty => '没有找到匹配的字体';

  @override
  String get appearanceFontPickerRecommended => '推荐';

  @override
  String get appearanceFontPickerCancel => '取消';

  @override
  String get appearanceWindowEffectsSection => '窗口效果';

  @override
  String get appearanceWindowEffectsEnableTitle => '启用窗口特效';

  @override
  String get appearanceWindowEffectsEnabledSubtitle => '已启用窗口特效';

  @override
  String get appearanceWindowEffectsDisabledSubtitle => '窗口特效已关闭（性能模式）';

  @override
  String get appearanceWindowEffectsEnabledTitle => '窗口特效已启用';

  @override
  String get appearanceWindowEffectsDisabledTitle => '窗口特效已关闭';

  @override
  String get appearanceWindowEffectsEnabledMessage => '窗口效果已开启';

  @override
  String get appearanceWindowEffectsDisabledMessage => '已切换为纯色背景以提升性能';

  @override
  String get appearanceWindowEffectsTypeTitle => '效果类型';

  @override
  String get appearanceWindowEffectSwitchedTitle => '效果已切换';

  @override
  String get appearanceWindowEffectAcrylic => 'acrylic';

  @override
  String get appearanceWindowEffectBlur => '模糊';

  @override
  String get appearanceWindowEffectMica => 'mica_main';

  @override
  String get appearanceWindowEffectMicaAlt => 'Mica Alt';

  @override
  String get appearanceWindowEffectsAcrylicOpacityTitle => '亚克力透明度';

  @override
  String get appearanceWindowEffectsAcrylicOpacityHint =>
      '调整背景不透明度 (0-255，越小越透明)';

  @override
  String get appearanceWindowEffectsAcrylicOpacityMicaHint => 'Mica 效果不支持调整透明度';

  @override
  String get appearanceWindowEffectsDragSuspendTitle => '拖动时禁用特效';

  @override
  String get appearanceWindowEffectsDragSuspendEnabledSubtitle =>
      '拖动窗口时临时禁用特效，确保流畅拖动';

  @override
  String get appearanceWindowEffectsDragSuspendDisabledSubtitle =>
      '拖动时保持特效（Win10 可能卡顿）';

  @override
  String get appearanceWindowEffectsMicaHint =>
      'Mica 效果仅在 Windows 11 上可用，会自动采用系统主题色';

  @override
  String get appearanceWindowEffectsAcrylicHint =>
      '亚克力效果会消耗额外的GPU资源，如果感觉卡顿可以关闭此选项';

  @override
  String get appearanceWindowEffectsDisabledHint => '为获得最佳性能已关闭特效';

  @override
  String get appearanceEffectNone => '无效果';

  @override
  String get appearanceEffectBlur => '模糊效果 - 简单的背景模糊';

  @override
  String get appearanceEffectAcrylic => '亚克力效果 - 半透明模糊背景';

  @override
  String get appearanceEffectMica => 'Mica 效果 - Windows 11 原生云母效果';

  @override
  String get appearanceEffectMicaAlt => 'Mica Alt 效果 - Windows 11 临时窗口云母效果';

  @override
  String get appearanceEffectUnknown => '未知效果';

  @override
  String get appearanceSidebarSection => '侧边栏';

  @override
  String get appearanceSidebarDefaultTitle => '默认展开状态';

  @override
  String get appearanceSidebarDefaultSubtitle => '启动时侧边栏默认状态';

  @override
  String get appearanceSidebarExpandedLabel => '展开';

  @override
  String get appearanceSidebarCollapsedLabel => '收起';

  @override
  String get appearanceSidebarSavedTitle => '已保存';

  @override
  String appearanceSidebarSavedMessage(Object state) {
    return '侧边栏默认状态已设为 $state';
  }

  @override
  String get appearanceNotificationSection => '通知';

  @override
  String get appearanceNotificationEnableTitle => '启用通知';

  @override
  String get appearanceNotificationEnableSubtitle => '显示下载完成和错误通知';

  @override
  String get appearanceNotificationSchemeTitle => '配色方案';

  @override
  String get appearanceNotificationSchemeSystem => '跟随主题';

  @override
  String get appearanceNotificationSchemeLight => '浅色系';

  @override
  String get appearanceNotificationSchemeDark => '深色系';

  @override
  String get appearanceNotificationSchemeFluent2 => 'Fluent 2 色系（推荐）';

  @override
  String get appearanceNotificationSchemeUnknown => '未知';

  @override
  String get appearanceNotificationSchemeDefaultOption => 'dark';

  @override
  String get appearanceNotificationSchemeLightOption => '浅色';

  @override
  String get appearanceNotificationSchemeDarkOption => '深色';

  @override
  String get appearanceNotificationSchemeFluent2Option => 'Fluent 2';

  @override
  String get appearanceNotificationPositionTitle => '显示位置';

  @override
  String get appearanceNotificationPositionTopRight => '右上角（标题栏下方）';

  @override
  String get appearanceNotificationPositionBottomRight => '右下角';

  @override
  String get appearanceNotificationPositionUnknown => '未知';

  @override
  String get appearanceNotificationPositionTopRightOption => 'topRight';

  @override
  String get appearanceNotificationPositionBottomRightOption => '右下角';

  @override
  String get appearanceNotificationPerformanceTitle => '渲染性能模式';

  @override
  String get appearanceNotificationPerformanceOptionPerformance => 'balanced';

  @override
  String get appearanceNotificationPerformanceOptionBalanced => '平衡';

  @override
  String get appearanceNotificationPerformanceOptionQuality => '高质量';

  @override
  String get appearanceNotificationPerformanceHint =>
      '毛玻璃效果会影响动画流畅度。如果感觉卡顿，建议选择\"性能优先\"模式';

  @override
  String get appearanceNotificationPreviewButtonTitle => '预览通知';

  @override
  String get appearanceNotificationPreviewButtonSubtitle => '点击预览当前配色';

  @override
  String get appearanceNotificationPreviewButton => '预览';

  @override
  String get appearanceNotificationPreviewTitle => '配色预览';

  @override
  String get appearanceNotificationPreviewSuccessTitle => '成功通知';

  @override
  String get appearanceNotificationPreviewSuccessMessage => '操作成功完成';

  @override
  String get appearanceNotificationPreviewWarningTitle => '警告通知';

  @override
  String get appearanceNotificationPreviewWarningMessage => '请注意此操作的影响';

  @override
  String get appearanceNotificationPreviewErrorTitle => '错误通知';

  @override
  String get appearanceNotificationPreviewErrorMessage => '操作失败，请重试';

  @override
  String get appearanceNotificationPreviewInfoTitle => '信息通知';

  @override
  String get appearanceNotificationPreviewInfoMessage => '这是一条提示信息';

  @override
  String get appearanceNotificationTestTitle => '测试通知';

  @override
  String get appearanceNotificationTestMessage => '这是一条测试通知';

  @override
  String get appearancePerformanceModePerformance => '性能优先（无毛玻璃，推荐）';

  @override
  String get appearancePerformanceModeBalanced => '平衡（轻度毛玻璃）';

  @override
  String get appearancePerformanceModeQuality => '高质量（完整毛玻璃效果）';

  @override
  String get appearancePerformanceModeUnknown => '未知';

  @override
  String get appearanceSegmentsModeTitle => '分段进度显示模式';

  @override
  String get appearanceSegmentsModeNoneOption => 'merged';

  @override
  String get appearanceSegmentsModeMergedOption => '合并条';

  @override
  String get appearanceSegmentsModeListOption => '分段列表';

  @override
  String get appearanceSegmentsModeNoneDescription => '简洁模式：不显示分段信息';

  @override
  String get appearanceSegmentsModeMergedDescription => '合并模式：所有分段合并在一个进度条中显示';

  @override
  String get appearanceSegmentsModeListDescription => '列表模式：每个分段单独一行显示';

  @override
  String get appearanceSegmentsDefaultExpandedTitle => '默认展开分段信息';

  @override
  String get appearanceSegmentsDefaultExpandedSubtitle => '默认展开显示分段详情';

  @override
  String get appearanceSegmentsMaxVisibleTitle => '默认显示分段数量';

  @override
  String get appearanceSegmentsMaxVisibleSubtitle => '展开时显示分段数量 (1-32)';

  @override
  String get appearanceDownloadListSection => '下载列表显示';

  @override
  String get developerSectionDebugTools => '调试工具';

  @override
  String get developerSectionTestTools => '测试工具';

  @override
  String get developerModeEnabledSubtitle => '已启用调试功能';

  @override
  String get developerModeDisabledSubtitle => '启用后可访问调试工具';

  @override
  String get developerToolLogTitle => '日志查看器';

  @override
  String get developerToolLogSubtitle => '查看运行日志';

  @override
  String get developerToolLogShownTitle => '日志查看器已显示';

  @override
  String get developerToolLogShownMessage => '已在导航栏显示日志页面';

  @override
  String get developerToolLogHiddenTitle => '日志页面已隐藏';

  @override
  String get developerToolLogHiddenMessage => '已从导航栏移除日志页面';

  @override
  String get developerToolStatusTitle => '系统状态';

  @override
  String get developerToolStatusSubtitle => '内核与扩展状态';

  @override
  String get developerToolStatusShownTitle => '系统状态已显示';

  @override
  String get developerToolStatusShownMessage => '已在导航栏显示状态页面';

  @override
  String get developerToolStatusHiddenTitle => '系统状态已隐藏';

  @override
  String get developerToolStatusHiddenMessage => '已从导航栏移除状态页面';

  @override
  String get developerToolOnlineStatsTitle => '在线统计';

  @override
  String get developerToolOnlineStatsSubtitle => '在线用户数据';

  @override
  String get developerToolOnlineStatsShownTitle => '在线统计已显示';

  @override
  String get developerToolOnlineStatsShownMessage => '已在导航栏显示在线统计页面';

  @override
  String get developerToolOnlineStatsHiddenTitle => '在线统计已隐藏';

  @override
  String get developerToolOnlineStatsHiddenMessage => '已从导航栏移除在线统计页面';

  @override
  String get developerToolWebCheckTitle => 'Web 检测';

  @override
  String get developerToolWebCheckSubtitle => '网站诊断';

  @override
  String get developerToolWebCheckShownTitle => 'Web 检测已显示';

  @override
  String get developerToolWebCheckShownMessage => '已在导航栏显示 Web 检测页面';

  @override
  String get developerToolWebCheckHiddenTitle => 'Web 检测已隐藏';

  @override
  String get developerToolWebCheckHiddenMessage => '已从导航栏移除 Web 检测页面';

  @override
  String get developerToolPerformanceTitle => '性能监控';

  @override
  String get developerToolPerformanceSubtitle => 'FPS 与渲染';

  @override
  String get developerToolPerformanceShownTitle => '性能监控已显示';

  @override
  String get developerToolPerformanceShownMessage => '已在导航栏显示性能监控页面';

  @override
  String get developerToolPerformanceHiddenTitle => '性能监控已隐藏';

  @override
  String get developerToolPerformanceHiddenMessage => '已从导航栏移除性能监控页面';

  @override
  String get developerTestNotificationTitle => '通知测试';

  @override
  String get developerTestNotificationTitlePlaceholder => '标题';

  @override
  String get developerTestNotificationMessagePlaceholder => '内容（可选）';

  @override
  String get developerTestNotificationTypeSuccess => '成功';

  @override
  String get developerTestNotificationTypeWarning => '警告';

  @override
  String get developerTestNotificationTypeError => '错误';

  @override
  String get developerTestNotificationTypeInfo => '信息';

  @override
  String get developerTestNotificationTitleRequired => '请输入标题';

  @override
  String get developerTestPopupTitle => '弹窗测试';

  @override
  String get developerTestPopupButton => '弹窗';

  @override
  String get developerTestPopupTestingLabel => '测试中';

  @override
  String get developerTestPopupHint => '独立弹窗使用 Tauri，Dialog 需要主窗口';

  @override
  String developerTestPopupResultSuccess(Object time) {
    return '成功 · $time![';
  }

  @override
  String get developerTestPopupResultFailed => '失败';

  @override
  String get updateCurrentVersionTitle => '当前版本';

  @override
  String get updateChangelogTitle => '更新日志';

  @override
  String get updateChangelogViewFullButton => '查看完整更新日志';

  @override
  String updateChangelogDialogTitle(Object version) {
    return 'v$version 更新日志';
  }

  @override
  String get updateCheckTitle => '检查更新';

  @override
  String get updateStartButton => '开始更新';

  @override
  String get updateCheckAgainButton => '重新检查';

  @override
  String get updateCheckingStatus => '正在检查更新...';

  @override
  String get updateCheckFailedTitle => '检查更新失败';

  @override
  String get updateLatestTitle => '已是最新版本';

  @override
  String get updateLatestSubtitle => '当前已是最新版本';

  @override
  String get updateInitialHint => '点击\"重新检查\"按钮检查最新版本';

  @override
  String get updateUnreleasedTitle => '未发布的版本';

  @override
  String updateUnreleasedSubtitle(Object version) {
    return '当前版本 v$version | 当前版本号不存在,或许为特殊版本或开发版';
  }

  @override
  String get updateConfirmTitle => '确认更新';

  @override
  String get updateConfirmMessage => '新版本已经准备好啦，为保障安装过程可以正常进行，本应用将会关闭！';

  @override
  String updateConfirmDetails(Object newVersion, Object currentVersion,
      Object change, Object currentChannel, Object targetChannel) {
    return '新版本: $newVersion\\n当前版本: $currentVersion\\n变更: $change\\n渠道: $currentChannel -> $targetChannel\\n准备更新？';
  }

  @override
  String get updateConfirmCancelButton => '取消';

  @override
  String get updateConfirmProceedButton => '确认更新';

  @override
  String get updateUnknownVersion => '未知';

  @override
  String get updateUnknownChannel => '未知';

  @override
  String get updateLauncherFailedTitle => '启动更新器失败';

  @override
  String get updateLauncherFailedMessage =>
      '无法启动 Update.exe\\n排查步骤:\\n • 检查 Update.exe 是否被删除或移动\\n • 确认已安装 .NET 8\\n • 确认安装包完整\\n如果仍失败，请手动下载安装。';

  @override
  String get updateLauncherFailedCloseButton => '关闭';

  @override
  String get updateLauncherFailedManualDownloadButton => '手动下载';

  @override
  String get updateAvailableTitle => '发现更新';

  @override
  String get updateAvailableChangelogTitle => '更新内容';

  @override
  String get updateSettingsTitle => '更新设置';

  @override
  String get updateDotNetMissingSubtitle => '未安装 - 推荐安装以使用自动更新器';

  @override
  String get updateDotNetDownloadButton => '下载';

  @override
  String get updateDotNetInstalledSubtitle => '已安装 - 可使用更新器';

  @override
  String get updateDotNetRecheckButton => '重新检测';

  @override
  String get updateDotNetRecommendTitle => '推荐安装 .NET 8';

  @override
  String get updateDotNetRecommendSubtitle =>
      '安装 .NET 8 Desktop Runtime 后可使用更新器自动更新';

  @override
  String get updateDotNetRecommendButton => '下载 .NET 8';

  @override
  String get updateChannelTitle => '当前通道';

  @override
  String get updateChannelAlpha => 'Alpha（预览版）';

  @override
  String get updateChannelBeta => 'Beta（公测版）';

  @override
  String get updateChannelRelease => 'Release（稳定版）';

  @override
  String get updateIntervalTitle => '自动检查更新';

  @override
  String get updateIntervalSubtitle => '设置检查更新的频率';

  @override
  String get updateIntervalStartup => '仅启动时';

  @override
  String get updateIntervalHourly => '每小时';

  @override
  String get updateIntervalDaily => '每天';

  @override
  String get updateIntervalWeekly => '每周';

  @override
  String get updateIntervalNever => '从不';

  @override
  String get updateAllowBetaTitle => '接收 Beta 更新';

  @override
  String get updateAllowBetaSubtitle => '允许接收稳定的 Beta 版本';

  @override
  String get updateAllowAlphaTitle => '接收 Alpha 更新';

  @override
  String get updateAllowAlphaSubtitle => '允许接收最新的测试构建（可能不稳定）';

  @override
  String updateLastCheckLabel(Object time) {
    return '上次检查: $time';
  }

  @override
  String get updateTimeJustNow => '刚刚';

  @override
  String updateTimeMinutesAgo(Object minutes) {
    return '$minutes 分钟前';
  }

  @override
  String updateTimeHoursAgo(Object hours) {
    return '$hours 小时前';
  }

  @override
  String get updateDialogCloseButton => '关闭';

  @override
  String get statusOnline => '在线';

  @override
  String get statusOffline => '离线';

  @override
  String get settingsDangerZoneTitle => '危险区域';

  @override
  String get popupDownloadTitle => '新建下载';

  @override
  String get popupDownloadLinkLabel => '下载链接';

  @override
  String get popupDownloadLinkPlaceholder => 'HTTP/HTTPS 链接';

  @override
  String get popupDownloadFileNameLabel => '文件名';

  @override
  String get popupDownloadFileNamePlaceholder => '保存为文件名';

  @override
  String get popupDownloadAutoStart => '立即开始下载';

  @override
  String get popupDownloadFeatureHint => '支持多线程、断点续传和限速';

  @override
  String get popupDownloadCancel => '取消';

  @override
  String get popupDownloadAdding => '添加中...';

  @override
  String get popupDownloadStart => '开始下载';

  @override
  String get popupDownloadErrorMissingInfo => '请填写完整信息';

  @override
  String get popupDownloadErrorInvalidUrl => '请输入有效的 HTTP/HTTPS 链接';

  @override
  String popupDownloadErrorAddFailed(Object error) {
    return '添加任务失败: $error';
  }

  @override
  String get popupDownloadErrorTitle => '错误';

  @override
  String get popupDownloadErrorConfirm => '确定';

  @override
  String get popupDownloadDefaultFileName => 'download';

  @override
  String get addDownloadTitle => '新建下载';

  @override
  String get addDownloadSubtitle => '支持多线程下载和断点续传';

  @override
  String get addDownloadUrlLabel => '下载链接';

  @override
  String get addDownloadRequiredBadge => '必填';

  @override
  String get addDownloadUrlPlaceholder => 'https://example.com/file.zip';

  @override
  String get addDownloadParsedFileNameTitle => '已解析文件名';

  @override
  String get addDownloadAdvancedToggle => '高级选项';

  @override
  String get addDownloadAdvancedCollapsedHint => '自定义文件名';

  @override
  String get addDownloadAdvancedExpandedHint => '收起';

  @override
  String get addDownloadFileNameLabel => '自定义文件名';

  @override
  String get addDownloadOptionalBadge => '可选';

  @override
  String get addDownloadFileNamePlaceholder => '留空则使用解析到的名称';

  @override
  String get addDownloadFeatureTitle => '智能下载特性';

  @override
  String get addDownloadFeature1Title => '多线程分段';

  @override
  String get addDownloadFeature1Desc => '最大化下载速度';

  @override
  String get addDownloadFeature2Title => '自动续传';

  @override
  String get addDownloadFeature2Desc => '网络中断后恢复';

  @override
  String get addDownloadFeature3Title => '动态分段';

  @override
  String get addDownloadFeature3Desc => '自适应下载策略';

  @override
  String get addDownloadCancelButton => '取消';

  @override
  String get addDownloadAdding => '添加中...';

  @override
  String get addDownloadStart => '开始下载';

  @override
  String get addDownloadErrorMissingUrl => '请输入下载链接';

  @override
  String get addDownloadErrorInvalidUrl => '请输入有效的 HTTP/HTTPS 链接';

  @override
  String addDownloadErrorAddFailed(Object error) {
    return '添加任务失败: $error';
  }

  @override
  String get addDownloadErrorTitle => '错误';

  @override
  String get addDownloadErrorConfirm => '确定';

  @override
  String get addDownloadSuccessTitle => '任务已添加';

  @override
  String addDownloadSuccessMessage(Object fileName) {
    return '正在下载：$fileName';
  }

  @override
  String get folderPickerErrorPathNotFound => '路径不存在';

  @override
  String get folderPickerErrorAccessDenied => '无法访问该路径（权限不足）';

  @override
  String folderPickerErrorAccessFailed(Object error) {
    return '无法访问该路径：$error';
  }

  @override
  String get folderPickerCreateTitle => '创建文件夹';

  @override
  String get folderPickerCreatePrompt => '在以下位置创建文件夹：';

  @override
  String get folderPickerCreatePlaceholder => '文件夹名称';

  @override
  String get folderPickerCancelButton => '取消';

  @override
  String get folderPickerCreateButton => '创建';

  @override
  String get folderPickerConfirmButton => '确定';

  @override
  String get folderPickerCreateExistsTitle => '创建已取消';

  @override
  String folderPickerCreateExistsMessage(Object name) {
    return '文件夹 \"$name\" 已存在。\n已选中该文件夹。';
  }

  @override
  String get folderPickerCreateSuccessTitle => '创建成功';

  @override
  String folderPickerCreateSuccessMessage(Object name) {
    return '已创建并选中 \"$name\" 文件夹';
  }

  @override
  String get folderPickerCreateFailedTitle => '创建失败';

  @override
  String folderPickerCreateFailedMessage(Object error) {
    return '创建文件夹失败：$error';
  }

  @override
  String get folderPickerQuickPathAddTitle => '添加快捷路径';

  @override
  String get folderPickerQuickPathAddPrompt => '将当前路径添加到快捷路径：';

  @override
  String get folderPickerQuickPathAddNameLabel => '自定义名称（可选）：';

  @override
  String get folderPickerQuickPathAddNamePlaceholder => '例如：我的项目';

  @override
  String get folderPickerQuickPathAddButton => '添加';

  @override
  String get folderPickerQuickPathAddSuccessTitle => '添加成功';

  @override
  String get folderPickerQuickPathAddFailedTitle => '添加失败';

  @override
  String get folderPickerQuickPathAddSuccessMessage => '快捷路径已添加';

  @override
  String get folderPickerQuickPathAddFailedMessage => '路径已存在或无效';

  @override
  String get folderPickerQuickPathRemoveTitle => '移除快捷路径';

  @override
  String folderPickerQuickPathRemoveMessage(Object path) {
    return '确定移除该快捷路径？\n\n$path';
  }

  @override
  String get folderPickerQuickPathRemoveButton => '移除';

  @override
  String get folderPickerTitle => '选择文件夹';

  @override
  String get folderPickerNavUpTooltip => '上级文件夹';

  @override
  String get folderPickerPathPlaceholder => '输入路径或在下方选择';

  @override
  String get folderPickerRefreshTooltip => '刷新';

  @override
  String get folderPickerNewFolderTooltip => '新建文件夹';

  @override
  String get folderPickerAddQuickPathTooltip => '将当前路径添加到快捷路径';

  @override
  String get folderPickerEmptyMessage => '此文件夹为空';

  @override
  String get folderPickerSelectButton => '选择';

  @override
  String get updateLatestVersionLabel => '最新版本';

  @override
  String get updateDialogLaterButton => '稍后';

  @override
  String get updateDialogDownloadNowButton => '立即下载';

  @override
  String get updateDialogCurrentInfoTitle => '当前版本信息';

  @override
  String get downloadStatusDownloading => '下载中';

  @override
  String get downloadStatusPaused => '已暂停';

  @override
  String get downloadStatusPending => '等待中';

  @override
  String get downloadStatusFailed => '失败';

  @override
  String get downloadStatusMerging => '合并中';

  @override
  String get downloadStatusCompleted => '已完成';

  @override
  String get downloadFilterTitle => '筛选';

  @override
  String get downloadFilterSubtitle => '按状态筛选下载任务';

  @override
  String get downloadFilterAll => '全部';

  @override
  String get downloadDialogCloseButton => '关闭';

  @override
  String get downloadSortTitle => '排序';

  @override
  String get downloadSortSubtitle => '选择下载任务的排序方式';

  @override
  String get downloadSortNewest => '最新';

  @override
  String get downloadSortOldest => '最旧';

  @override
  String get downloadSortNewestDesc => '按创建时间从新到旧';

  @override
  String get downloadSortOldestDesc => '按创建时间从旧到新';

  @override
  String get downloadSearchPlaceholder => '搜索下载任务...';

  @override
  String get downloadNoResultsTitle => '未找到匹配的任务';

  @override
  String get downloadNoResultsSubtitle => '尝试修改搜索条件';

  @override
  String get downloadStatsActiveLabel => '活动';

  @override
  String get downloadStatsSpeedLabel => '速度';

  @override
  String get downloadStatsSegmentsLabel => '分段';

  @override
  String get downloadEmptyTitle => '暂无下载任务';

  @override
  String get downloadEmptySubtitle => '点击“新建”按钮添加下载任务';

  @override
  String get downloadCopySuccessTitle => '复制成功';

  @override
  String get downloadCopySuccessMessage => '下载链接已复制';

  @override
  String get downloadCopyFailedTitle => '复制失败';

  @override
  String downloadCopyFailedMessage(Object error) {
    return '复制失败: $error';
  }

  @override
  String get downloadCopyTooltip => '复制链接';

  @override
  String get downloadActionStart => '开始';

  @override
  String get downloadActionPause => '暂停';

  @override
  String get downloadActionRetrySegments => '重试失败分段';

  @override
  String get downloadActionRetryAll => '全部重试';

  @override
  String get downloadActionDelete => '删除';

  @override
  String get downloadMergingStatus => '下载完成，正在合并';

  @override
  String get downloadCalculatingSize => '正在计算大小...';

  @override
  String get downloadCalculating => '计算中';

  @override
  String downloadSegmentsTitleWithCount(Object count) {
    return '分段 ($count)';
  }

  @override
  String get downloadSegmentsTitle => '分段';

  @override
  String get downloadSegmentsStatusCompleted => '完成';

  @override
  String get downloadSegmentsStatusDownloading => '下载中';

  @override
  String get downloadSegmentsStatusFailed => '失败';

  @override
  String downloadSegmentsSummary(
      Object total, Object completed, Object downloading) {
    return '共 $total 段 · 已完成 $completed · 下载中 $downloading';
  }

  @override
  String downloadSegmentsSummaryWithFailed(
      Object total, Object completed, Object downloading, Object failed) {
    return '共 $total 段 · 已完成 $completed · 下载中 $downloading · 失败 $failed';
  }

  @override
  String get downloadRetryButton => '重试';

  @override
  String downloadSegmentLabel(Object index) {
    return '分段 $index';
  }

  @override
  String downloadSegmentRetryCount(Object count) {
    return '重试$count次';
  }

  @override
  String get downloadSegmentsCollapse => '收起';

  @override
  String downloadSegmentsShowAll(Object count) {
    return '查看全部 $count 个';
  }

  @override
  String downloadSizeUnknown(Object downloaded) {
    return '$downloaded / 未知';
  }

  @override
  String get downloadFailedTitle => '下载失败';

  @override
  String downloadFailedSegmentsHint(Object count) {
    return '$count 个分段失败，可重试';
  }

  @override
  String get downloadConfirmDeleteTitle => '确认删除';

  @override
  String downloadConfirmDeleteMessage(Object fileName) {
    return '确定要删除任务 \"$fileName\" 吗？';
  }

  @override
  String get downloadDeleteButton => '删除';

  @override
  String get completedCategoryAll => '所有下载';

  @override
  String get completedCategoryVideo => '视频';

  @override
  String get completedCategoryAudio => '音频';

  @override
  String get completedCategoryArchive => '压缩包';

  @override
  String get completedCategoryDocument => '文档';

  @override
  String get completedCategoryProgram => '程序';

  @override
  String get completedCategoryOther => '杂项';

  @override
  String get completedSearchPlaceholder => '搜索已完成的文件...';

  @override
  String get completedNoResultsTitle => '未找到匹配的文件';

  @override
  String get completedNoResultsSubtitle => '尝试修改搜索条件';

  @override
  String get completedHeaderTitle => '已完成';

  @override
  String get completedOpenFolderButton => '打开文件夹';

  @override
  String get completedEmptyTitle => '暂无已完成任务';

  @override
  String get completedEmptySubtitle => '完成的下载任务将显示在这里';

  @override
  String get completedStatsTitle => '下载统计';

  @override
  String get completedStatsPeakSpeed => '峰值速度';

  @override
  String get completedStatsAverageSpeed => '平均速度';

  @override
  String get completedStatsDuration => '用时';

  @override
  String get completedStatsSegments => '分段数';

  @override
  String get completedStatsThreads => '线程数';

  @override
  String get completedStatsCore => '下载核心';

  @override
  String get completedActionRun => '运行';

  @override
  String get completedActionLocation => '位置';

  @override
  String get completedTimeJustNow => '刚刚';

  @override
  String completedTimeMinutesAgo(Object minutes) {
    return '$minutes分钟前';
  }

  @override
  String completedTimeHoursAgo(Object hours) {
    return '$hours小时前';
  }

  @override
  String completedTimeDaysAgo(Object days) {
    return '$days天前';
  }

  @override
  String completedTimeMonthDay(Object month, Object day) {
    return '$month月$day日';
  }

  @override
  String get completedFilePathMissingMessage => '文件路径不存在';

  @override
  String get completedFileNotFoundMessage => '文件可能已被移动或删除';

  @override
  String completedRunFileFailedMessage(Object error) {
    return '运行文件失败: $error';
  }

  @override
  String completedOpenFileLocationFailedMessage(Object error) {
    return '打开文件位置失败: $error';
  }

  @override
  String get completedHintTitle => '提示';

  @override
  String get completedConfirmDeleteTitle => '确认删除';

  @override
  String completedDeleteTaskMessage(Object fileName) {
    return '确定要删除 \"$fileName\" 吗？';
  }

  @override
  String get completedRemoveSuccessTitle => '删除成功';

  @override
  String get completedRemoveSuccessMessage => '已从列表中移除任务';

  @override
  String get completedDeleteSuccessTitle => '删除成功';

  @override
  String completedDeleteFileSuccessMessage(Object fileName) {
    return '已删除文件：$fileName';
  }

  @override
  String get completedFileNotFoundTitle => '文件不存在';

  @override
  String get completedDeleteFailedTitle => '删除失败';

  @override
  String completedDeleteFailedMessage(Object error) {
    return '无法删除文件：$error';
  }

  @override
  String get completedCancelButton => '取消';

  @override
  String get completedRemoveButton => '移除';

  @override
  String get completedDeleteButton => '删除';

  @override
  String get completedCreateButton => '创建';

  @override
  String get completedCreateCategoryTitle => '创建自定义分类';

  @override
  String get completedCreateCategoryNameLabel => '分类名称';

  @override
  String get completedCreateCategoryNamePlaceholder => '例如：图片';

  @override
  String get completedCreateCategoryExtensionsLabel => '文件扩展名';

  @override
  String get completedCreateCategoryExtensionsPlaceholder =>
      '例如：.jpg,.png,.gif（用逗号分隔）';

  @override
  String get completedCreateCategoryHint => '提示：扩展名需要包含点号，多个扩展名用逗号分隔';

  @override
  String get completedCreateCategoryInputErrorTitle => '输入错误';

  @override
  String get completedCreateCategoryInputErrorMessage => '请填写完整信息';

  @override
  String get completedCreateCategoryInvalidExtMessage => '请输入有效的扩展名';

  @override
  String get completedCreateCategorySuccessTitle => '创建成功';

  @override
  String completedCreateCategorySuccessMessage(Object name) {
    return '已创建分类：$name';
  }

  @override
  String completedDeleteCategoryMessage(Object name) {
    return '确定要删除自定义分类 \"$name\" 吗？';
  }

  @override
  String get completedDeleteCategorySuccessTitle => '删除成功';

  @override
  String completedDeleteCategorySuccessMessage(Object name) {
    return '已删除分类：$name';
  }

  @override
  String get webCheckHeaderTitle => 'Web 状态检测';

  @override
  String get webCheckInputTitle => '输入 URL';

  @override
  String get webCheckInputPlaceholder => 'example.com 或 https://example.com';

  @override
  String get webCheckInputHint => '提示：可以直接输入域名，会自动添加 https:// 前缀';

  @override
  String get webCheckStartButton => '开始检测';

  @override
  String get webCheckChecking => '检测中...';

  @override
  String get webCheckErrorEmptyUrl => '请输入 URL';

  @override
  String get webCheckErrorUnsupportedKernel => 'Web 检测功能暂不支持新版内核，请在设置中切换到旧版内核';

  @override
  String get webCheckErrorInvalidUrl => 'URL 格式无效';

  @override
  String webCheckErrorCheckFailed(Object error) {
    return '检测失败: $error';
  }

  @override
  String get webCheckErrorLanUnsupportedKernel =>
      '局域网扫描功能暂不支持新版内核，请在设置中切换到旧版内核';

  @override
  String webCheckErrorScanFailed(Object error) {
    return '扫描失败: $error';
  }

  @override
  String get webCheckErrorCardTitle => '检测失败';

  @override
  String webCheckDnsTime(Object ms) {
    return 'DNS: ${ms}ms';
  }

  @override
  String webCheckResponseTime(Object ms) {
    return '响应: ${ms}ms';
  }

  @override
  String get webCheckInfoHostname => '主机名';

  @override
  String get webCheckInfoIpAddress => 'IP 地址';

  @override
  String get webCheckInfoPort => '端口';

  @override
  String get webCheckInfoProtocol => '协议';

  @override
  String get webCheckInfoFinalUrl => '最终 URL';

  @override
  String get webCheckInfoContentType => 'Content-Type';

  @override
  String get webCheckInfoContentLength => 'Content-Length';

  @override
  String get webCheckInfoServer => 'Server';

  @override
  String webCheckRedirectHistoryTitle(Object count) {
    return '重定向历史 ($count)';
  }

  @override
  String webCheckRedirectFrom(Object url) {
    return '从: $url';
  }

  @override
  String webCheckRedirectTo(Object url) {
    return '到: $url';
  }

  @override
  String get webCheckHeadersTitle => '响应头';

  @override
  String get webCheckSslTitle => 'SSL/TLS 信息';

  @override
  String webCheckSslError(Object error) {
    return 'SSL 错误: $error';
  }

  @override
  String get webCheckSslVersion => '版本';

  @override
  String get webCheckSslCipher => '加密套件';

  @override
  String get webCheckSslSubject => '证书主体';

  @override
  String get webCheckSslIssuer => '证书颁发者';

  @override
  String get webCheckSslNotBefore => '有效期开始';

  @override
  String get webCheckSslNotAfter => '有效期结束';

  @override
  String webCheckCookiesTitle(Object count) {
    return 'Cookies ($count)';
  }

  @override
  String webCheckCookieDomain(Object domain) {
    return 'Domain: $domain';
  }

  @override
  String get webCheckLanScanTitle => '局域网扫描';

  @override
  String get webCheckAutoScan => '自动扫描';

  @override
  String get webCheckLanScanSubtitle => '扫描当前局域网中的所有在线设备';

  @override
  String get webCheckScanning => '扫描中...';

  @override
  String get webCheckScanStart => '开始扫描';

  @override
  String webCheckLanDevicesTitle(Object count) {
    return '发现 $count 台设备';
  }

  @override
  String webCheckLanNetworkLabel(Object network) {
    return '网段: $network';
  }

  @override
  String webCheckLanLocalIpLabel(Object ip) {
    return '本机 IP: $ip';
  }

  @override
  String get webCheckLanLocalBadge => '本机';

  @override
  String get webCheckStatusUnknown => '未知';

  @override
  String get webCheckStatusOk => 'OK';

  @override
  String get webCheckStatusMovedPermanently => '永久重定向';

  @override
  String get webCheckStatusFound => '已找到';

  @override
  String get webCheckStatusNotModified => '未修改';

  @override
  String get webCheckStatusBadRequest => '错误请求';

  @override
  String get webCheckStatusUnauthorized => '未授权';

  @override
  String get webCheckStatusForbidden => '禁止访问';

  @override
  String get webCheckStatusNotFound => '未找到';

  @override
  String get webCheckStatusInternalServerError => '服务器内部错误';

  @override
  String get webCheckStatusBadGateway => '错误网关';

  @override
  String get webCheckStatusServiceUnavailable => '服务不可用';

  @override
  String webCheckStatusWithCode(Object code) {
    return '状态 $code';
  }

  @override
  String get statusPageTitle => '系统状态';

  @override
  String get statusPageRefresh => '刷新';

  @override
  String get statusPageTestApi => '测试 API';

  @override
  String get statusPageClearLogs => '清空日志';

  @override
  String get statusSectionKernel => '下载核心状态';

  @override
  String get statusItemKernelService => '核心服务';

  @override
  String get statusValueRunning => '运行中';

  @override
  String get statusValueStopped => '已停止';

  @override
  String get statusItemKernelCurrent => '当前内核';

  @override
  String get statusKernelLegacyName => '旧版内核';

  @override
  String get statusItemHttpService => 'HTTP 服务';

  @override
  String get statusValueHealthy => '正常';

  @override
  String get statusValueBuiltIn => '内置';

  @override
  String get statusValueUnhealthy => '异常';

  @override
  String get statusItemServiceAddress => '服务地址';

  @override
  String get statusItemKernelVersion => '核心版本';

  @override
  String get statusSectionNetwork => '网络状态';

  @override
  String get statusItemLocalNetwork => '本地网络';

  @override
  String get statusValueConnected => '已连接';

  @override
  String get statusValueDisconnected => '未连接';

  @override
  String get statusItemInternet => '互联网';

  @override
  String get statusValueReachable => '可访问';

  @override
  String get statusValueUnreachable => '不可访问';

  @override
  String get statusItemLocalIp => '本地 IP';

  @override
  String get statusItemNetworkLatency => '网络延迟';

  @override
  String statusNetworkLatencyMs(Object ms) {
    return '$ms ms';
  }

  @override
  String get statusItemConnectionType => '连接类型';

  @override
  String get statusSectionApiTests => 'API 测试结果';

  @override
  String get statusValueFailed => '失败';

  @override
  String get statusSectionSystemInfo => '系统信息';

  @override
  String get statusItemOs => '操作系统';

  @override
  String get statusValueUnknown => '未知';

  @override
  String get statusItemOsVersion => '系统版本';

  @override
  String get statusItemCpuCores => 'CPU 核心数';

  @override
  String statusSystemCpuCores(Object count) {
    return '$count 核';
  }

  @override
  String get statusItemDartVersion => 'Dart 版本';

  @override
  String get statusSectionDownloadStats => '下载统计';

  @override
  String get statusItemTotalDownloads => '总下载数';

  @override
  String get statusItemActiveTasks => '活跃任务';

  @override
  String get statusItemCompletedTasks => '已完成';

  @override
  String get statusItemFailedTasks => '失败任务';

  @override
  String get statusItemTotalDownloaded => '总下载量';

  @override
  String get statusSectionLogStats => '日志统计';

  @override
  String get statusItemLogCount => '日志条数';

  @override
  String get statusItemErrorCount => '错误数';

  @override
  String get statusItemWarningCount => '警告数';

  @override
  String get statusSectionExtension => '浏览器扩展';

  @override
  String get statusItemTip => '提示';

  @override
  String get statusExtensionTip => '感谢使用，现已支持软件内下载插件以及跳转至网页';

  @override
  String get statusExtensionDownloadButton => '下载扩展插件';

  @override
  String get statusExtensionOpenStoreButton => '打开商店页面';

  @override
  String get statusSectionAutoStart => '开机自启动';

  @override
  String get statusItemPlatformSupport => '平台支持';

  @override
  String get statusAutoStartWindowsOnly => '仅支持 Windows 平台';

  @override
  String get statusItemAutoStartStatus => '自启动状态';

  @override
  String get statusValueEnabled => '已启用';

  @override
  String get statusValueDisabled => '未启用';

  @override
  String get statusItemRegistryPath => '注册路径';

  @override
  String get statusValueCorrect => '正确';

  @override
  String get statusValueNeedsUpdate => '需要更新';

  @override
  String get statusItemCurrentRegistry => '当前注册';

  @override
  String get statusItemCurrentPath => '当前路径';

  @override
  String get statusAutoStartOldRegistryTitle => '检测到旧版本的自启动注册';

  @override
  String get statusAutoStartOldRegistryMessage =>
      '注册的路径与当前可执行文件不匹配，可能是因为应用更新或移动了位置。点击下方按钮自动修复。';

  @override
  String get statusAutoStartFixButton => '自动修复注册';

  @override
  String get statusSectionPopupTest => '弹窗窗口测试';

  @override
  String get statusItemDescription => '说明';

  @override
  String get statusPopupTestDescription => '测试独立弹窗窗口功能（类似 IDM 风格）';

  @override
  String get statusItemTestResult => '测试结果';

  @override
  String statusPopupTestResultSuccess(Object time) {
    return '成功 (${time}ms)';
  }

  @override
  String statusPopupTestResultFailed(Object error) {
    return '失败: $error';
  }

  @override
  String get statusPopupTesting => '创建中...';

  @override
  String get statusPopupTestButton => '测试独立弹窗';

  @override
  String get statusPopupDialogTestButton => '测试 Dialog 弹窗';

  @override
  String get statusPopupTestInfoTitle => '测试说明';

  @override
  String get statusPopupTestInfoBody =>
      '• 独立弹窗：使用 Tauri 创建独立窗口，不需要拉起主窗口\\n• Dialog 弹窗：传统方式，需要主窗口显示后才能弹出对话框\\n• 测试结果和耗时会记录到日志中';

  @override
  String get statusExtensionDownloadAddedTitle => '下载已添加';

  @override
  String get statusExtensionDownloadAddedMessage => '浏览器扩展插件已添加到下载列表';

  @override
  String get statusExtensionDownloadFailedTitle => '下载失败';

  @override
  String statusExtensionDownloadFailedMessage(Object error) {
    return '无法添加下载任务: $error';
  }

  @override
  String get statusExtensionOpenLinkFailed => '无法打开链接';

  @override
  String get statusExtensionOpenFailedTitle => '打开失败';

  @override
  String statusExtensionOpenFailedMessage(Object error) {
    return '无法打开浏览器: $error';
  }

  @override
  String get statusAutoStartFixSuccessTitle => '修复成功';

  @override
  String get statusAutoStartFixSuccessMessage => '自启动注册已更新为当前版本';

  @override
  String get statusAutoStartFixFailedTitle => '修复失败';

  @override
  String get statusAutoStartFixFailedMessage => '无法更新自启动注册，请检查权限';

  @override
  String statusAutoStartFixErrorMessage(Object error) {
    return '发生错误: $error';
  }

  @override
  String get statusPopupTestCreating => '正在创建窗口...';

  @override
  String get statusPopupTestStartLog => '开始测试弹窗窗口...';

  @override
  String statusPopupTestSuccessLog(Object time) {
    return '弹窗窗口创建成功，耗时: ${time}ms';
  }

  @override
  String get statusPopupTestSuccessMessage => '窗口创建成功';

  @override
  String get statusPopupTestSuccessTitle => '测试成功';

  @override
  String statusPopupTestSuccessToast(Object time) {
    return '弹窗窗口创建成功，耗时 ${time}ms';
  }

  @override
  String statusPopupTestFailedLog(Object error) {
    return '弹窗窗口创建失败: $error';
  }

  @override
  String get statusPopupTestFailedTitle => '测试失败';

  @override
  String statusPopupTestFailedToast(Object error) {
    return '弹窗窗口创建失败: $error';
  }

  @override
  String get statusPopupDialogTestStartLog => '开始测试 Dialog 弹窗...';

  @override
  String statusPopupDialogTestCloseLog(Object time) {
    return 'Dialog 弹窗关闭，总耗时: ${time}ms';
  }

  @override
  String statusPopupDialogTestFailedLog(Object error) {
    return 'Dialog 弹窗失败: $error';
  }

  @override
  String get statusApiTestHealthCheck => '健康检查';

  @override
  String get statusApiTestGetTasks => '获取任务';

  @override
  String get statusApiTestGetStatistics => '获取统计';

  @override
  String get statusApiTestGetConfig => '获取配置';

  @override
  String get onlineStatsPageTitle => '当前与你同行的人';

  @override
  String get onlineStatsCountUnit => '位';

  @override
  String get onlineStatsAloneMessage => '暂时只有你在使用 Hanabi';

  @override
  String onlineStatsOthersMessage(Object count) {
    return '除了你，还有 $count 位用户正在使用 Hanabi';
  }

  @override
  String onlineStatsTotalMessage(Object count) {
    return '（包括你在内共 $count 位）';
  }

  @override
  String get onlineStatsMyStatusTitle => '当前我的状态';

  @override
  String get onlineStatsDeviceIdLabel => '设备 ID';

  @override
  String get onlineStatsNotInitialized => '未初始化';

  @override
  String get onlineStatsAppVersionLabel => '应用版本';

  @override
  String get onlineStatsHeartbeatLabel => '心跳间隔';

  @override
  String get onlineStatsHeartbeatValue => '每 5 分钟自动发送';

  @override
  String get onlineStatsServerLabel => '统计服务器';

  @override
  String get onlineStatsSending => '发送中...';

  @override
  String get onlineStatsSendSignalButton => '向服务器发送我的信号';

  @override
  String get onlineStatsPrivacyPolicy => '隐私条款';

  @override
  String get onlineStatsTermsOfService => '服务条款';

  @override
  String get onlineStatsOfficialSite => '官网地址';

  @override
  String get onlineStatsSendSuccessTitle => '发送成功';

  @override
  String get onlineStatsSendSuccessMessage => '您的信号已成功发送到服务器';

  @override
  String get onlineStatsCooldownTitle => '服务器已标记在线';

  @override
  String onlineStatsCooldownMessage(Object minutes) {
    return '您的在线状态已被服务器记录，请在 $minutes 分钟后再试';
  }

  @override
  String get onlineStatsSendFailedTitle => '发送失败';

  @override
  String get onlineStatsSendFailedMessage => '无法连接到统计服务器，请检查网络连接';

  @override
  String get onlineStatsOpenLinkFailedTitle => '无法打开链接';

  @override
  String onlineStatsOpenLinkFailedMessage(Object url) {
    return '请手动在浏览器中访问：\\n$url';
  }

  @override
  String get onlineStatsOpenFailedTitle => '打开失败';

  @override
  String onlineStatsOpenFailedMessage(Object error, Object url) {
    return '错误：$error\\n\\n请手动在浏览器中访问：\\n$url';
  }

  @override
  String get onlineStatsDialogOk => '确定';

  @override
  String get logPageTitle => '日志';

  @override
  String get logFilterLevelLabel => '级别';

  @override
  String logFilterTagCount(Object count) {
    return '$count 个标签';
  }

  @override
  String get logFilterSourceLabel => '来源';

  @override
  String get logFilterTimeSelectedLabel => '时间 ✓';

  @override
  String get logFilterTimeLabel => '时间';

  @override
  String get logRegexRulesButton => '正则规则';

  @override
  String get logAutoScrollOn => '自动滚动: 开';

  @override
  String get logAutoScrollOff => '自动滚动: 关';

  @override
  String get logStatsShow => '统计: 显示';

  @override
  String get logStatsHide => '统计: 隐藏';

  @override
  String get logFailureStatsShow => '失败统计: 显示';

  @override
  String get logFailureStatsHide => '失败统计: 隐藏';

  @override
  String get logExportLogsButton => '导出日志';

  @override
  String get logExportDiagnosticsButton => '导出诊断包';

  @override
  String get logArchiveButton => '归档日志';

  @override
  String get logClearButton => '清空日志';

  @override
  String get logSearchPlaceholderRegex => '输入正则表达式...';

  @override
  String get logSearchPlaceholder => '搜索日志...';

  @override
  String get logEmptyTitle => '暂无日志';

  @override
  String get logEmptySubtitle => '日志将在此处显示';

  @override
  String get logStatTotal => '总计';

  @override
  String logGroupedCount(Object count) {
    return '$count 组';
  }

  @override
  String get logClearFiltersButton => '清除';

  @override
  String get logFailureStatsTitle => '下载失败统计';

  @override
  String logFailureStatsTotal(Object count) {
    return '总计 $count 次';
  }

  @override
  String get logFailureStatsEmpty => '暂无下载失败记录';

  @override
  String get logFailureReasonUnknown => '未知错误';

  @override
  String logFailureReasonAuth(Object code) {
    return '鉴权失败（$code）';
  }

  @override
  String logFailureReasonNotFound(Object code) {
    return '资源不存在（$code）';
  }

  @override
  String get logFailureReasonRange => 'Range 不支持';

  @override
  String logFailureReasonRangeWithCode(Object code) {
    return 'Range 不支持（$code）';
  }

  @override
  String logFailureReasonTooManyRequests(Object code) {
    return '请求过快（$code）';
  }

  @override
  String logFailureReasonServerError(Object code) {
    return '服务器错误（$code）';
  }

  @override
  String logFailureReasonHttpError(Object code) {
    return 'HTTP $code';
  }

  @override
  String get logFailureReasonTimeout => '连接超时';

  @override
  String get logFailureReasonConnection => '连接中断';

  @override
  String get logFailureReasonDns => 'DNS 解析失败';

  @override
  String get logFailureReasonSsl => 'SSL/证书错误';

  @override
  String get logFailureReasonChecksum => '文件校验失败';

  @override
  String get logFailureReasonDisk => '磁盘/权限错误';

  @override
  String get logFailureReasonOther => '其他错误';

  @override
  String logTimeRangeRecentMinutes(Object minutes) {
    return '最近 $minutes 分钟';
  }

  @override
  String logTimeRangeRecentHours(Object hours) {
    return '最近 $hours 小时';
  }

  @override
  String get logTimeRangeLabel => '时间范围';

  @override
  String get logStatCountUnit => '条';

  @override
  String logRepeatedCount(Object count) {
    return '重复 $count 次';
  }

  @override
  String logRepeatedMore(Object count) {
    return '... 还有 $count 条';
  }

  @override
  String get logContextCopy => '复制日志';

  @override
  String logContextRepeated(Object count) {
    return '(重复 $count 次)';
  }

  @override
  String get logContextRemoveBookmark => '取消书签';

  @override
  String get logContextAddBookmark => '添加书签';

  @override
  String logContextFilterLevel(Object level) {
    return '筛选: $level';
  }

  @override
  String logContextFilterSource(Object source) {
    return '筛选: $source';
  }

  @override
  String get logContextCopySingle => '复制此条';

  @override
  String get logFilterLevelTitle => '筛选日志级别';

  @override
  String get logFilterAllLabel => '全部';

  @override
  String get logDialogClose => '关闭';

  @override
  String get logSourceFilterTitle => '筛选日志来源';

  @override
  String logSourceTotalCount(Object count) {
    return '$count 条';
  }

  @override
  String get logSourceCategoryKernel => 'Kernel';

  @override
  String logSourceKernelSubtitle(Object count) {
    return '下载核心 · $count 个标签';
  }

  @override
  String get logSourceCategoryApp => 'App';

  @override
  String logSourceAppSubtitle(Object count) {
    return '应用程序 · $count 个标签';
  }

  @override
  String get logSourceCategorySystem => 'System';

  @override
  String logSourceSystemSubtitle(Object count) {
    return '系统 / 框架 · $count 个标签';
  }

  @override
  String get logDialogOk => '确定';

  @override
  String get logDialogCancel => '取消';

  @override
  String get logTimeRangeTitle => '时间范围筛选';

  @override
  String get logTimeRangeQuickSelectLabel => '快捷选择:';

  @override
  String get logTimeRangePreset1Hour => '最近1小时';

  @override
  String get logTimeRangePreset30Min => '最近30分钟';

  @override
  String get logTimeRangePreset10Min => '最近10分钟';

  @override
  String get logTimeRangePreset5Min => '最近5分钟';

  @override
  String get logTimeRangeStartLabel => '开始时间:';

  @override
  String get logTimeRangeEndLabel => '结束时间:';

  @override
  String get logTimeRangeNotSet => '未设置';

  @override
  String get logTimeRangeNow => '现在';

  @override
  String get logDialogClear => '清除';

  @override
  String get logDialogApply => '应用';

  @override
  String get logRulesDialogTitle => '高亮规则管理';

  @override
  String get logRulesBuiltinTitle => '内置规则';

  @override
  String get logRulesCustomTitle => '自定义规则';

  @override
  String get logRulesAddButton => '添加';

  @override
  String get logRulesCustomEmpty => '暂无自定义规则';

  @override
  String get logRulesLegendTitle => '颜色图例';

  @override
  String get logRulesLegendUrl => 'URL';

  @override
  String get logRulesLegendPath => '路径';

  @override
  String get logRulesLegendIp => 'IP';

  @override
  String get logRulesLegendNumber => '数值';

  @override
  String get logRulesLegendError => '错误';

  @override
  String get logRulesLegendSuccess => '成功';

  @override
  String get logRulesLegendWarning => '警告';

  @override
  String get logRulesLegendHttp => 'HTTP';

  @override
  String get logRulesLegendStep => '步骤';

  @override
  String get logRulesLegendPid => 'PID';

  @override
  String get logRulesLegendKeyValue => '键值';

  @override
  String get logAddRuleTitle => '添加自定义规则';

  @override
  String get logAddRuleNameLabel => '规则名称';

  @override
  String get logAddRuleNamePlaceholder => '例如: 任务ID';

  @override
  String get logAddRulePatternLabel => '正则表达式';

  @override
  String get logAddRulePatternPlaceholder => '例如: \\b[a-f0-9]+\\b（16位）';

  @override
  String get logAddRuleColorLabel => '高亮颜色';

  @override
  String get logAddRuleInvalidTitle => '正则表达式无效';

  @override
  String logAddRuleInvalidMessage(Object error) {
    return '错误: $error';
  }

  @override
  String get logArchiveTitle => '归档日志';

  @override
  String get logArchivePrompt => '选择归档选项:';

  @override
  String get logArchiveExportAll => '导出全部日志';

  @override
  String get logArchiveExportFiltered => '导出当前筛选结果';

  @override
  String logArchiveExportBookmarked(Object count) {
    return '导出书签日志 ($count)';
  }

  @override
  String get logClearConfirmTitle => '确认清空';

  @override
  String get logClearConfirmMessage => '确定要清空所有日志吗？此操作不可撤销。';

  @override
  String get logClearConfirmButton => '清空';

  @override
  String get logExportSuccessTitle => '导出成功';

  @override
  String logExportSavedMessage(Object path) {
    return '日志已保存至:\\n$path';
  }

  @override
  String get logExportFailedTitle => '导出失败';

  @override
  String logExportFailedMessage(Object error) {
    return '无法保存日志: $error';
  }

  @override
  String logDiagnosticsSavedMessage(Object path) {
    return '诊断包已保存至:\\n$path';
  }

  @override
  String logDiagnosticsExportFailedMessage(Object error) {
    return '无法导出诊断包: $error';
  }

  @override
  String logExportFileHeader(Object time) {
    return '# 日志导出 - $time';
  }

  @override
  String logExportFileTotal(Object count) {
    return '# 总计: $count 条';
  }

  @override
  String logExportSavedCountMessage(Object count, Object path) {
    return '已保存 $count 条日志至:\\n$path';
  }

  @override
  String logExportErrorMessage(Object error) {
    return '错误: $error';
  }

  @override
  String get logRuleUrl => 'URL';

  @override
  String get logRuleFilePath => '文件路径';

  @override
  String get logRuleIpAddress => 'IP地址';

  @override
  String get logRuleNumber => '数值';

  @override
  String get logRuleIdHash => 'ID/Hash';

  @override
  String get logRuleError => '错误';

  @override
  String get logRuleSuccess => '成功';

  @override
  String get logRuleWarning => '警告';

  @override
  String get logRuleHttpMethod => 'HTTP方法';

  @override
  String get logRuleHttpStatus => 'HTTP状态码';

  @override
  String get logRuleTime => '时间';

  @override
  String get logRuleStep => '步骤';

  @override
  String get logRulePid => 'PID';

  @override
  String get logRuleKeyValue => '键值对';

  @override
  String get performanceMonitorTitle => '性能监控';

  @override
  String get performanceMonitorStatusRunning => '正在监控中...';

  @override
  String get performanceMonitorStatusIdle => '点击开始监控以收集性能数据';

  @override
  String get performanceMonitorButtonStop => '停止监控';

  @override
  String get performanceMonitorButtonStart => '开始监控';

  @override
  String get performanceMonitorRealtimeTitle => '实时数据';

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
  String get performanceMonitorStatsTitle => '统计摘要';

  @override
  String get performanceMonitorStatTotalFrames => '总帧数';

  @override
  String get performanceMonitorStatJankFrames => '卡顿帧数';

  @override
  String get performanceMonitorStatJankRate => '卡顿率';

  @override
  String get performanceMonitorStatAvgBuildTime => '平均 Build 时间';

  @override
  String get performanceMonitorStatAvgRasterTime => '平均 Raster 时间';

  @override
  String get performanceMonitorStatAvgTotalTime => '平均 Total 时间';

  @override
  String get performanceMonitorStatMaxBuildTime => '最大 Build 时间';

  @override
  String get performanceMonitorStatMaxRasterTime => '最大 Raster 时间';

  @override
  String get performanceMonitorStatMaxTotalTime => '最大 Total 时间';

  @override
  String get performanceMonitorRebuildTitle => 'Widget 重建统计';

  @override
  String get performanceMonitorRebuildTotal => '总重建次数';

  @override
  String get performanceMonitorRebuildTracked => '追踪的 Widget 数';

  @override
  String get performanceMonitorRebuildTopTitle => '重建次数最多的 Widget';

  @override
  String get performanceMonitorRebuildEmpty =>
      '暂无重建数据\\n在代码中调用 trackRebuild() 来追踪';

  @override
  String performanceMonitorFrameChartTitle(Object count) {
    return '帧时间图表（最近 $count 帧）';
  }

  @override
  String get performanceMonitorFrameChartEmpty => '暂无数据，请开始监控';

  @override
  String get performanceMonitorLegendNormal => '正常帧';

  @override
  String performanceMonitorLegendJankMs(Object ms) {
    return '卡顿帧 (> $ms ms)';
  }

  @override
  String get performanceMonitorLegendFpsThreshold => '60fps 阈值';

  @override
  String get performanceMonitorSettingsTitle => '当前渲染设置';

  @override
  String get performanceMonitorSettingsModeLabel => '性能模式';

  @override
  String get performanceMonitorSettingsBlurLabel => '模糊效果';

  @override
  String get performanceMonitorSettingsBlurStrengthLabel => '模糊强度';

  @override
  String get performanceMonitorSettingsWindowEffectLabel => '窗口特效';

  @override
  String get performanceMonitorSettingsAcrylicOpacityLabel => '亚克力透明度';

  @override
  String get performanceMonitorValueEnabled => '启用';

  @override
  String get performanceMonitorValueDisabled => '禁用';

  @override
  String performanceMonitorWindowEffectEnabled(Object mode) {
    return '启用（$mode）';
  }

  @override
  String get performanceMonitorWindowEffectHintEnabled =>
      '窗口特效已启用，可能影响性能。如果卡顿率较高，建议在“设置 → 界面 → 窗口效果”中关闭';

  @override
  String get performanceMonitorWindowEffectHintDisabled =>
      '窗口特效已禁用，性能最佳。如需视觉效果可在“设置 → 界面 → 窗口效果”中开启';

  @override
  String get performanceMonitorActionExport => '导出日志';

  @override
  String get performanceMonitorActionCopy => '复制到剪贴板';

  @override
  String get performanceMonitorActionClear => '清空数据';

  @override
  String get performanceMonitorToastClearedTitle => '已清空';

  @override
  String get performanceMonitorToastClearedMessage => '历史数据已清空';

  @override
  String get performanceMonitorToastExportSuccessTitle => '导出成功';

  @override
  String performanceMonitorToastExportSuccessMessage(Object path) {
    return '日志已保存到: $path';
  }

  @override
  String get performanceMonitorToastExportFailedTitle => '导出失败';

  @override
  String performanceMonitorToastExportFailedMessage(Object error) {
    return '$error';
  }

  @override
  String get performanceMonitorToastCopiedTitle => '已复制';

  @override
  String get performanceMonitorToastCopiedMessage => '性能日志已复制到剪贴板';

  @override
  String get performanceMonitorModeQuality => '高质量';

  @override
  String get performanceMonitorModeBalanced => '平衡';

  @override
  String get performanceMonitorModePerformance => '性能优先';
}
