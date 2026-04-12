import { browser } from 'wxt/browser';
import { EXTENSION_DISPLAY_NAME } from '@/lib/extension-meta';

export type PopupLocale = 'en' | 'zh';

export type PopupMessages = {
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
  enabled: string;
  disabled: string;
  bridgeHint: string;
  refresh: string;
  checking: string;
  footerFirefox: string;
  footerChromium: string;
  title: string;
};

const MESSAGES: Record<PopupLocale, PopupMessages> = {
  en: {
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
    enabled: 'Enabled',
    disabled: 'Disabled',
    bridgeHint:
      'Keep the browser bridge enabled and fall back to explicit Hanabi actions when Firefox limits the API path.',
    refresh: 'Refresh',
    checking: 'Checking...',
    footerFirefox:
      'Firefox relays observed downloads and falls back to explicit Hanabi actions when needed.',
    footerChromium:
      'Chromium intercepts downloads before they enter the default browser flow.',
    title: EXTENSION_DISPLAY_NAME,
  },
  zh: {
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
    enabled: '已启用',
    disabled: '已禁用',
    bridgeHint: '保持浏览器桥接启用；当 Firefox API 受限时，回退到 Hanabi 显式操作。',
    refresh: '刷新',
    checking: '检查中...',
    footerFirefox: 'Firefox 会转发已观察到的下载，并在需要时回退到 Hanabi 显式操作。',
    footerChromium: 'Chromium 会在浏览器默认下载流程开始前直接拦截。',
    title: EXTENSION_DISPLAY_NAME,
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
