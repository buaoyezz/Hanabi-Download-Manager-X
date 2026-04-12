import { browser } from 'wxt/browser';

export const STORAGE_KEYS = {
  isConnected: 'isConnected',
  popupLocale: 'popupLocale',
  shouldDisableExtension: 'shouldDisableExtension',
} as const;

export async function readPopupStorageState() {
  const values = await browser.storage.local.get({
    [STORAGE_KEYS.isConnected]: false,
    [STORAGE_KEYS.popupLocale]: 'en',
    [STORAGE_KEYS.shouldDisableExtension]: false,
  });

  return {
    isConnected: values[STORAGE_KEYS.isConnected] === true,
    popupLocale: String(values[STORAGE_KEYS.popupLocale] ?? 'en'),
    shouldDisableExtension: values[STORAGE_KEYS.shouldDisableExtension] === true,
  };
}
