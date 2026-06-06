import { browser } from 'wxt/browser';
import { EXTENSION_DISPLAY_NAME } from '@/lib/extension-meta';

export type PopupLocale = 'en' | 'zh';

export type PopupMessages = {
  back: string;
  desktopLink: string;
  desktopReachable: string;
  desktopOffline: string;
  connected: string;
  disconnected: string;
  browser: string;
  mode: string;
  observedRelayMenu: string;
  automaticIntercept: string;
  port: string;
  version: string;
  extensionState: string;
  extensionStateHint: string;
  settings: string;
  automaticHandoff: string;
  automaticHandoffHint: string;
  contextMenus: string;
  contextMenusHint: string;
  notifications: string;
  notificationsHint: string;
  connectionBadge: string;
  connectionBadgeHint: string;
  enabled: string;
  disabled: string;
  openSettings: string;
  refresh: string;
  checking: string;
  footerFirefox: string;
  footerChromium: string;
  title: string;
  manualPort: string;
  manualPortHint: string;
  portModeLabel: string;
  portModeAuto: string;
  portModeManual: string;
  portModeAutoHint: string;
  portModeManualHint: string;
};

const MESSAGES: Record<PopupLocale, PopupMessages> = {
  en: {
    back: 'Back',
    desktopLink: 'Desktop Link',
    desktopReachable: 'Hanabi desktop service is reachable',
    desktopOffline: 'Desktop service is offline',
    connected: 'Connected',
    disconnected: 'Disconnected',
    browser: 'Browser',
    mode: 'Mode',
    observedRelayMenu: 'Auto',
    automaticIntercept: 'Automatic intercept',
    port: 'Port',
    version: 'Version',
    extensionState: 'Extension State',
    extensionStateHint:
      'Keep the bridge enabled so Hanabi can intercept or relay browser downloads.',
    settings: 'Settings',
    automaticHandoff: 'Automatic takeover',
    automaticHandoffHint:
      'Let Hanabi automatically receive supported browser downloads. Turn this off to keep only manual actions.',
    contextMenus: 'Context menus',
    contextMenusHint: 'Show right-click send-to-Hanabi entries for links, media, and pages.',
    notifications: 'Desktop notifications',
    notificationsHint: 'Show success and failure notifications after sending tasks to Hanabi.',
    connectionBadge: 'Toolbar badge',
    connectionBadgeHint: 'Display the current desktop connection state on the extension icon.',
    enabled: 'Enabled',
    disabled: 'Disabled',
    openSettings: 'Open settings',
    refresh: 'Refresh',
    checking: 'Checking...',
    footerFirefox:
      'Firefox relays observed downloads and falls back to explicit Hanabi actions when needed.',
    footerChromium:
      'Chromium intercepts downloads before they enter the default browser flow.',
    title: EXTENSION_DISPLAY_NAME,
    manualPort: 'Desktop Service Port',
    manualPortHint: 'Auto mode scans ports 9700–9720. Change only if the service runs outside that range.',
    portModeLabel: 'Port Mode',
    portModeAuto: 'Auto',
    portModeManual: 'Manual',
    portModeAutoHint: 'Automatically scan ports 9700–9720 to find the running desktop service.',
    portModeManualHint: 'Connect only to the manually specified port below.',
  },
  zh: {
    back: '返回',
    desktopLink: '桌面端连接',
    desktopReachable: 'Hanabi 桌面服务已连接',
    desktopOffline: '桌面服务未连接',
    connected: '已连接',
    disconnected: '未连接',
    browser: '浏览器',
    mode: '模式',
    observedRelayMenu: 'Auto',
    automaticIntercept: '自动拦截',
    port: '端口',
    version: '版本',
    extensionState: '扩展状态',
    extensionStateHint: '保持桥接启用，让 Hanabi 可以接管或转发浏览器下载任务。',
    settings: '扩展设置',
    automaticHandoff: '自动接管',
    automaticHandoffHint:
      '让 Hanabi 自动接收支持的浏览器下载。关闭后仅保留手动发送操作。',
    contextMenus: '右键菜单',
    contextMenusHint: '为链接、媒体和页面显示“发送到 Hanabi”的右键操作。',
    notifications: '桌面通知',
    notificationsHint: '发送任务到 Hanabi 后显示成功或失败通知。',
    connectionBadge: '工具栏徽标',
    connectionBadgeHint: '在扩展图标上显示当前桌面端连接状态。',
    enabled: '已启用',
    disabled: '已禁用',
    openSettings: '进入设置',
    refresh: '刷新',
    checking: '检查中...',
    footerFirefox: 'Firefox 会转发已观察到的下载，并在需要时回退到 Hanabi 显式操作。',
    footerChromium: 'Chromium 会在浏览器默认下载流程开始前直接拦截。',
    title: EXTENSION_DISPLAY_NAME,
    manualPort: '桌面端服务端口',
    manualPortHint: '自动模式会扫描 9700–9720 端口，仅在服务运行在该范围外时才需要手动修改。',
    portModeLabel: '端口模式',
    portModeAuto: '自动',
    portModeManual: '手动',
    portModeAutoHint: '自动扫描 9700–9720 端口范围，寻找运行中的桌面端服务。',
    portModeManualHint: '仅连接下方手动指定的端口。',
  },
};

export function normalizePopupLocale(value: string | undefined | null): PopupLocale {
  const normalized = String(value ?? '')
    .trim()
    .toLowerCase()
    .replaceAll('_', '-');

  return normalized.startsWith('zh') ? 'zh' : 'en';
}

export function getFallbackPopupLocale(): PopupLocale {
  const browserLocale =
    browser.i18n?.getUILanguage?.() ??
    globalThis.navigator?.language ??
    'en';

  return normalizePopupLocale(browserLocale);
}

export function getPopupMessages(locale: PopupLocale) {
  return MESSAGES[locale];
}
