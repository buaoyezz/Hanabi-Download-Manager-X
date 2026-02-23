type Locale = 'zh' | 'en';

const STRINGS = {
  zh: {
    appTitle: 'Hanabi Download Pop',
    downloadFailed: '下载失败',
    errorConnectMainApp: '无法连接到主程序，请确保 Hanabi 下载管理器正在运行',
    selectSavePathTitle: '选择保存位置',
    labelDownloadLink: '下载链接',
    placeholderDownloadLink: '输入或粘贴下载链接...',
    labelFileName: '文件名',
    placeholderFileName: '文件名将自动解析...',
    labelSaveTo: '保存到',
    ariaSelectFolder: '选择文件夹',
    actionCancel: '取消',
    actionSending: '发送中...',
    actionStartDownload: '开始下载',
    statSpeed: '速度',
    statDownloaded: '已下载',
    statTotal: '总大小',
    statRemaining: '剩余',
    statusPaused: '已暂停',
    statusDownloading: '下载中...',
    segmentTooltip: '分段 {index}: {percent}%',
    segmentCount: '{count} 个分段',
    segmentCompletedCount: '{count} 已完成',
    actionOpenMainApp: '打开主程序',
    actionBackgroundDownload: '后台下载',
    actionResume: '继续',
    actionPause: '暂停',
    completedTitle: '下载完成',
    completedFileSize: '文件大小',
    completedSavePath: '保存位置',
    actionClose: '关闭',
    actionOpenFolder: '打开文件夹',
    actionOpenFile: '打开文件',
    errorUnknown: '未知错误',
    actionRetry: '重试',
    titleCompleted: '下载完成',
    titlebarMinimize: '最小化',
    titlebarClose: '关闭',
  },
  en: {
    appTitle: 'Hanabi Download Pop',
    downloadFailed: 'Download failed',
    errorConnectMainApp: 'Unable to connect to the main app. Please make sure Hanabi Download Manager is running.',
    selectSavePathTitle: 'Select save location',
    labelDownloadLink: 'Download URL',
    placeholderDownloadLink: 'Paste or type download URL...',
    labelFileName: 'File name',
    placeholderFileName: 'Filename will be parsed automatically...',
    labelSaveTo: 'Save to',
    ariaSelectFolder: 'Select folder',
    actionCancel: 'Cancel',
    actionSending: 'Sending...',
    actionStartDownload: 'Start download',
    statSpeed: 'Speed',
    statDownloaded: 'Downloaded',
    statTotal: 'Total size',
    statRemaining: 'Remaining',
    statusPaused: 'Paused',
    statusDownloading: 'Downloading...',
    segmentTooltip: 'Segment {index}: {percent}%',
    segmentCount: '{count} segments',
    segmentCompletedCount: '{count} completed',
    actionOpenMainApp: 'Open main app',
    actionBackgroundDownload: 'Background download',
    actionResume: 'Resume',
    actionPause: 'Pause',
    completedTitle: 'Download complete',
    completedFileSize: 'File size',
    completedSavePath: 'Save location',
    actionClose: 'Close',
    actionOpenFolder: 'Open folder',
    actionOpenFile: 'Open file',
    errorUnknown: 'Unknown error',
    actionRetry: 'Retry',
    titleCompleted: 'Download complete',
    titlebarMinimize: 'Minimize',
    titlebarClose: 'Close',
  },
} as const;

export type I18nKey = keyof typeof STRINGS.en;

const resolveLocale = (): Locale => {
  const lang = (navigator.language || 'en').toLowerCase();
  if (lang.startsWith('zh')) return 'zh';
  return 'en';
};

let currentLocale: Locale = resolveLocale();

const formatTemplate = (template: string, params?: Record<string, string | number>): string => {
  if (!params) return template;
  return template.replace(/\{(\w+)\}/g, (_, key) => {
    const value = params[key];
    return value === undefined ? `{${key}}` : String(value);
  });
};

export const t = (key: I18nKey, params?: Record<string, string | number>): string => {
  const dict = STRINGS[currentLocale] ?? STRINGS.en;
  const template = dict[key] ?? STRINGS.en[key] ?? String(key);
  return formatTemplate(template, params);
};

export const setLocale = (value?: string | null): void => {
  if (!value || value.trim() === '' || value === 'system') {
    currentLocale = resolveLocale();
    return;
  }
  const normalized = value.toLowerCase().replace('_', '-');
  if (normalized.startsWith('zh')) {
    currentLocale = 'zh';
    return;
  }
  if (normalized.startsWith('en')) {
    currentLocale = 'en';
    return;
  }
  currentLocale = resolveLocale();
};

export const getLocale = (): Locale => currentLocale;
