import { readFileSync } from 'node:fs';
import { defineConfig } from 'wxt';
import {
  EXTENSION_DESCRIPTION,
  EXTENSION_DISPLAY_NAME,
  EXTENSION_MANIFEST_NAME,
  FIREFOX_MIN_VERSION,
} from './lib/extension-meta';

const packageJson = JSON.parse(
  readFileSync(new URL('./package.json', import.meta.url), 'utf8'),
) as { version?: string };

const extensionVersion = String(packageJson.version ?? '0.0.0');

export default defineConfig({
  modules: ['@wxt-dev/module-react'],
  manifestVersion: 3,
  outDir: '..',
  outDirTemplate: '{{browser}}_extension',
  manifest: ({ browser }) => ({
    name: EXTENSION_MANIFEST_NAME,
    description: EXTENSION_DESCRIPTION,
    version: extensionVersion,
    permissions: [
      'alarms',
      'contextMenus',
      'cookies',
      'downloads',
      'notifications',
      'storage',
      'webRequest',
    ],
    host_permissions: ['<all_urls>'],
    icons: {
      '16': 'icon/16.png',
      '32': 'icon/32.png',
      '48': 'icon/48.png',
      '128': 'icon/128.png',
    },
    action: {
      default_title: EXTENSION_DISPLAY_NAME,
      default_icon: {
        '16': 'icon/16.png',
        '32': 'icon/32.png',
        '48': 'icon/48.png',
        '128': 'icon/128.png',
      },
    },
    browser_specific_settings:
      browser === 'firefox'
        ? {
            gecko: {
              id: 'hanabi-download-manager-x@buaozze.dev',
              strict_min_version: FIREFOX_MIN_VERSION,
              data_collection_permissions: {
                required: ['authenticationInfo', 'websiteActivity'],
              },
            },
          }
        : undefined,
  }),
});
