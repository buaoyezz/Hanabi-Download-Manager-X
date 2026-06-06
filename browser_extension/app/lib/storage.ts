import { browser } from 'wxt/browser';
import {
  DEFAULT_DESKTOP_SERVICE_PORT,
  normalizeDesktopServicePort,
} from '@/lib/extension-meta';

export type PortMode = 'auto' | 'manual' | 'fixed';
export type BrowserDownloadHandlingMode =
  | 'smart'
  | 'always_ask'
  | 'silent_takeover'
  | 'small_files_to_browser';

export const DEFAULT_BROWSER_SMALL_FILE_THRESHOLD = 8 * 1024 * 1024;

export const STORAGE_KEYS = {
  isConnected: 'isConnected',
  popupLocale: 'popupLocale',
  shouldDisableExtension: 'shouldDisableExtension',
  enableAutomaticHandoff: 'enableAutomaticHandoff',
  enableContextMenus: 'enableContextMenus',
  showNotifications: 'showNotifications',
  showConnectionBadge: 'showConnectionBadge',
  desktopServicePort: 'desktopServicePort',
  portMode: 'portMode',
} as const;

export const STORAGE_DEFAULTS = {
  [STORAGE_KEYS.isConnected]: false,
  [STORAGE_KEYS.popupLocale]: 'en',
  [STORAGE_KEYS.shouldDisableExtension]: false,
  [STORAGE_KEYS.enableAutomaticHandoff]: true,
  [STORAGE_KEYS.enableContextMenus]: true,
  [STORAGE_KEYS.showNotifications]: true,
  [STORAGE_KEYS.showConnectionBadge]: true,
  [STORAGE_KEYS.desktopServicePort]: DEFAULT_DESKTOP_SERVICE_PORT,
  [STORAGE_KEYS.portMode]: 'auto' as PortMode,
} as const;

export function normalizePortMode(value: unknown): PortMode {
  if (value === 'manual' || value === 'fixed') return value;
  return 'auto';
}

export function normalizeBrowserDownloadHandlingMode(
  value: unknown,
): BrowserDownloadHandlingMode {
  if (
    value === 'always_ask' ||
    value === 'silent_takeover' ||
    value === 'small_files_to_browser'
  ) {
    return value;
  }
  return 'smart';
}

export async function readPopupStorageState() {
  const values = await browser.storage.local.get(STORAGE_DEFAULTS);

  return {
    isConnected: values[STORAGE_KEYS.isConnected] === true,
    popupLocale: String(values[STORAGE_KEYS.popupLocale] ?? 'en'),
    shouldDisableExtension: values[STORAGE_KEYS.shouldDisableExtension] === true,
    enableAutomaticHandoff:
      values[STORAGE_KEYS.enableAutomaticHandoff] !== false,
    enableContextMenus: values[STORAGE_KEYS.enableContextMenus] !== false,
    showNotifications: values[STORAGE_KEYS.showNotifications] !== false,
    showConnectionBadge: values[STORAGE_KEYS.showConnectionBadge] !== false,
    desktopServicePort: normalizeDesktopServicePort(
      values[STORAGE_KEYS.desktopServicePort],
    ),
    portMode: normalizePortMode(values[STORAGE_KEYS.portMode]),
  };
}
