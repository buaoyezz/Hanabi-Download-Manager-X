import { browser } from 'wxt/browser';
import { defineBackground } from 'wxt/utils/define-background';
import {
  getOnSendHeadersExtraInfoSpec,
  isFirefoxBrowser,
  supportsDownloadDeterminingFilename,
} from '@/lib/browser';
import {
  EXTENSION_NOTIFICATION_TITLE,
  HANABI_DESKTOP_SERVICE_URL,
} from '@/lib/extension-meta';
import { STORAGE_KEYS } from '@/lib/storage';

const API_BASE_URL = HANABI_DESKTOP_SERVICE_URL;
const HEARTBEAT_ALARM = 'hanabi-connection-heartbeat';
const HEADER_SNAPSHOT_TTL = 2 * 60 * 1000;
const HEADER_SNAPSHOT_LIMIT = 200;
const MENU_IDS = {
  link: 'hanabi-send-link',
  image: 'hanabi-send-image',
  audio: 'hanabi-send-audio',
  video: 'hanabi-send-video',
  page: 'hanabi-send-page',
} as const;
let initializePromise: Promise<void> | null = null;

type HeaderRecord = Record<string, string>;
type HeaderSnapshot = {
  headers: HeaderRecord;
  capturedAt: number;
  supportsRange: boolean;
};

type DownloadPayload = {
  url: string;
  filename: string;
  referer: string;
  user_agent: string;
  cookies: string;
  headers: HeaderRecord;
  from_browser: boolean;
  browser: string;
};

const requestHeadersByRequestId = new Map<string, HeaderSnapshot>();
const headerSnapshotsByUrl = new Map<string, HeaderSnapshot>();

function isSupportedUrl(url: string | undefined | null) {
  return typeof url === 'string' && /^https?:\/\//i.test(url);
}

function normalizeUrl(url: string | undefined | null) {
  const text = String(url ?? '').trim();
  if (!text) {
    return '';
  }

  try {
    const parsed = new URL(text);
    parsed.hash = '';
    return parsed.toString();
  } catch {
    return text.split('#', 1)[0] ?? text;
  }
}

function sanitizeFilename(value: string | undefined | null) {
  return String(value ?? '')
    .replace(/[<>:"/\\|?*\u0000-\u001F]/g, '_')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 160);
}

function basename(value: string | undefined | null) {
  const text = String(value ?? '').trim();
  if (!text) {
    return '';
  }

  const normalized = text.replace(/\\/g, '/');
  const lastSegment = normalized.split('/').filter(Boolean).pop() ?? normalized;
  return sanitizeFilename(lastSegment);
}

function inferFilenameFromUrl(url: string, fallback = 'download') {
  try {
    const parsed = new URL(url);
    const lastSegment = parsed.pathname.split('/').filter(Boolean).pop();
    if (lastSegment) {
      return basename(decodeURIComponent(lastSegment)) || fallback;
    }
  } catch {
    // Ignore invalid URL parsing.
  }

  return sanitizeFilename(fallback) || 'download';
}

function inferPageFilename(url: string, title: string) {
  const safeTitle = sanitizeFilename(title);
  if (safeTitle) {
    return `${safeTitle}.html`;
  }
  return `${inferFilenameFromUrl(url, 'page')}.html`;
}

function normalizeHeaders(headers: Array<{ name?: string; value?: string }> | undefined) {
  const result: HeaderRecord = {};

  for (const header of headers ?? []) {
    const name = String(header.name ?? '').trim().toLowerCase();
    if (!name) {
      continue;
    }

    const value = String(header.value ?? '').trim();
    if (!value) {
      continue;
    }

    result[name] = value;
  }

  return result;
}

function pruneHeaderSnapshots() {
  const now = Date.now();

  for (const [url, snapshot] of headerSnapshotsByUrl) {
    if (now - snapshot.capturedAt > HEADER_SNAPSHOT_TTL) {
      headerSnapshotsByUrl.delete(url);
    }
  }

  while (headerSnapshotsByUrl.size > HEADER_SNAPSHOT_LIMIT) {
    const firstKey = headerSnapshotsByUrl.keys().next().value as string | undefined;
    if (!firstKey) {
      break;
    }
    headerSnapshotsByUrl.delete(firstKey);
  }
}

function rememberHeaderSnapshot(
  url: string,
  headers: HeaderRecord,
  supportsRange: boolean,
) {
  const normalizedUrl = normalizeUrl(url);
  if (!normalizedUrl) {
    return;
  }

  headerSnapshotsByUrl.set(normalizedUrl, {
    headers,
    capturedAt: Date.now(),
    supportsRange,
  });
  pruneHeaderSnapshots();
}

function resolveHeadersForUrl(url: string) {
  const normalizedUrl = normalizeUrl(url);
  if (!normalizedUrl) {
    return { headers: {}, supportsRange: false };
  }

  const snapshot = headerSnapshotsByUrl.get(normalizedUrl);
  if (!snapshot) {
    return { headers: {}, supportsRange: false };
  }

  if (Date.now() - snapshot.capturedAt > HEADER_SNAPSHOT_TTL) {
    headerSnapshotsByUrl.delete(normalizedUrl);
    return { headers: {}, supportsRange: false };
  }

  return {
    headers: { ...snapshot.headers },
    supportsRange: snapshot.supportsRange,
  };
}

async function getDisableState() {
  const values = await browser.storage.local.get({
    [STORAGE_KEYS.shouldDisableExtension]: false,
  });

  return values[STORAGE_KEYS.shouldDisableExtension] === true;
}

async function updateConnectionStatus(connected: boolean) {
  await browser.action.setBadgeBackgroundColor({
    color: connected ? '#6CCB5F' : '#FF6B6B',
  });
  await browser.action.setBadgeText({ text: connected ? '√' : '×' });
  await browser.storage.local.set({
    [STORAGE_KEYS.isConnected]: connected,
  });
}

async function checkConnection() {
  try {
    const response = await fetch(`${API_BASE_URL}/health`);
    const data = (await response.json()) as { status?: string; locale?: string };
    const connected = data.status === 'ok';
    await updateConnectionStatus(connected);
    if (data.locale) {
      await browser.storage.local.set({
        [STORAGE_KEYS.popupLocale]: data.locale,
      });
    }
    return connected;
  } catch (error) {
    console.warn('Connection check failed', error);
    await updateConnectionStatus(false);
    return false;
  }
}

async function createNotification(message: string) {
  try {
    await browser.notifications.create({
      type: 'basic',
      iconUrl: browser.runtime.getURL('/icon/128.png'),
      title: EXTENSION_NOTIFICATION_TITLE,
      message,
    });
  } catch (error) {
    console.warn('Notification failed', error);
  }
}

function buildPayloadFromHeaders(
  url: string,
  filename: string,
  headers: HeaderRecord,
  referer = '',
): DownloadPayload {
  const normalizedReferer = isSupportedUrl(referer)
    ? referer
    : headers.referer ?? '';

  return {
    url,
    filename: sanitizeFilename(filename) || inferFilenameFromUrl(url),
    referer: normalizedReferer,
    user_agent: headers['user-agent'] ?? '',
    cookies: headers.cookie ?? '',
    headers,
    from_browser: true,
    browser: isFirefoxBrowser() ? 'firefox' : 'chromium',
  };
}

async function sendDownloadToHanabi(payload: DownloadPayload) {
  const connected = await checkConnection();
  if (!connected) {
    await createNotification('Hanabi desktop client is disconnected.');
    return { success: false, error: 'disconnected' };
  }

  try {
    const response = await fetch(`${API_BASE_URL}/download/add`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const data = (await response.json()) as { success?: boolean; error?: string };
    if (data.success) {
      await createNotification('Download task added successfully.');
      return { success: true };
    }

    await createNotification(`Failed to add download: ${data.error ?? 'Unknown error'}`);
    return { success: false, error: data.error ?? 'unknown_error' };
  } catch (error) {
    await createNotification(`Error sending download: ${String(error)}`);
    return { success: false, error: String(error) };
  }
}

function shouldHandleAutomaticDownload(
  downloadItem: Record<string, any>,
  disabled: boolean,
  connected: boolean,
) {
  const downloadUrl = String(downloadItem.finalUrl || downloadItem.url || '');

  if (disabled || !connected || !isSupportedUrl(downloadUrl)) {
    return false;
  }

  if (downloadItem.byExtensionId && downloadItem.byExtensionId === browser.runtime.id) {
    return false;
  }

  return true;
}

async function handoffAutomaticDownload(
  downloadItem: Record<string, any>,
  options: { eraseFromHistory?: boolean } = {},
) {
  const disabled = await getDisableState();
  const connected = await checkConnection();
  if (!shouldHandleAutomaticDownload(downloadItem, disabled, connected)) {
    return;
  }

  const downloadUrl = String(downloadItem.finalUrl || downloadItem.url || '');
  const filename =
    basename(downloadItem.filename) ||
    inferFilenameFromUrl(
      downloadUrl,
      downloadItem.id ? `download-${downloadItem.id}` : 'download',
    );
  const resolved = resolveHeadersForUrl(downloadUrl);
  const headers = resolved.headers;

  if (!headers.referer && downloadItem.referrer) {
    headers.referer = downloadItem.referrer;
  }

  try {
    await browser.downloads.cancel(downloadItem.id);
  } catch (error) {
    console.warn('Download cancellation failed', error);
    return;
  }

  if (options.eraseFromHistory) {
    try {
      await browser.downloads.erase({ id: downloadItem.id });
    } catch (error) {
      console.warn('Failed to erase browser download history item', error);
    }
  }

  await sendDownloadToHanabi(
    buildPayloadFromHeaders(downloadUrl, filename, headers, downloadItem.referrer ?? ''),
  );
}

async function getCookieHeader(url: string) {
  try {
    const cookies = await browser.cookies.getAll({ url });
    return cookies.map((cookie) => `${cookie.name}=${cookie.value}`).join('; ');
  } catch (error) {
    console.warn('Failed to read cookies', error);
    return '';
  }
}

async function buildContextPayload(info: Record<string, any>, tab?: Record<string, any>) {
  let url = '';
  let filename = '';

  switch (info.menuItemId) {
    case MENU_IDS.link:
      url = info.linkUrl ?? '';
      filename = inferFilenameFromUrl(url);
      break;
    case MENU_IDS.image:
    case MENU_IDS.audio:
    case MENU_IDS.video:
      url = info.srcUrl ?? '';
      filename = inferFilenameFromUrl(url, 'media');
      break;
    case MENU_IDS.page:
      url = info.pageUrl ?? tab?.url ?? '';
      filename = inferPageFilename(url, tab?.title ?? '');
      break;
    default:
      return null;
  }

  if (!isSupportedUrl(url)) {
    return null;
  }

  const referer = info.pageUrl ?? info.frameUrl ?? tab?.url ?? '';
  const cookies = await getCookieHeader(url);
  const headers: HeaderRecord = {
    ...resolveHeadersForUrl(url).headers,
  };

  if (isSupportedUrl(referer)) {
    headers.referer = referer;
  }
  if (cookies) {
    headers.cookie = cookies;
  }

  return buildPayloadFromHeaders(url, filename, headers, referer);
}

async function handleContextMenuAction(info: Record<string, any>, tab?: Record<string, any>) {
  if (await getDisableState()) {
    await createNotification('Extension is disabled.');
    return;
  }

  const payload = await buildContextPayload(info, tab);
  if (!payload) {
    await createNotification('Only HTTP and HTTPS resources can be sent to Hanabi.');
    return;
  }

  await sendDownloadToHanabi(payload);
}

async function ensureContextMenus() {
  try {
    await browser.contextMenus.removeAll();
  } catch (error) {
    console.warn('Failed to clear context menus', error);
  }

  const menuItems = [
    {
      id: MENU_IDS.link,
      title: 'Download link with Hanabi',
      contexts: ['link'] as ['link'],
    },
    {
      id: MENU_IDS.image,
      title: 'Download image with Hanabi',
      contexts: ['image'] as ['image'],
    },
    {
      id: MENU_IDS.audio,
      title: 'Download audio with Hanabi',
      contexts: ['audio'] as ['audio'],
    },
    {
      id: MENU_IDS.video,
      title: 'Download video with Hanabi',
      contexts: ['video'] as ['video'],
    },
    {
      id: MENU_IDS.page,
      title: 'Download current page with Hanabi',
      contexts: ['page'] as ['page'],
    },
  ] satisfies Array<Parameters<typeof browser.contextMenus.create>[0]>;

  for (const item of menuItems) {
    try {
      await browser.contextMenus.create(item);
    } catch (error) {
      console.warn('Failed to create context menu', error);
    }
  }
}

function handleRequestHeaders(details: Record<string, any>) {
  const headers = normalizeHeaders(details.requestHeaders);
  const supportsRange = (details.requestHeaders ?? []).some((header: Record<string, any>) => {
    return String(header.name ?? '').toLowerCase() === 'range';
  });

  const snapshot: HeaderSnapshot = {
    headers,
    capturedAt: Date.now(),
    supportsRange,
  };

  requestHeadersByRequestId.set(details.requestId, snapshot);
  rememberHeaderSnapshot(details.url, headers, supportsRange);
}

function clearRequestHeaders(requestId: string) {
  requestHeadersByRequestId.delete(requestId);
}

async function initialize() {
  const state = await browser.storage.local.get({
    [STORAGE_KEYS.shouldDisableExtension]: false,
  });

  if (typeof state[STORAGE_KEYS.shouldDisableExtension] !== 'boolean') {
    await browser.storage.local.set({
      [STORAGE_KEYS.shouldDisableExtension]: false,
    });
  }

  await ensureContextMenus();
  await checkConnection();
  await browser.alarms.create(HEARTBEAT_ALARM, { periodInMinutes: 1 });
}

function scheduleInitialize() {
  if (initializePromise) {
    return initializePromise;
  }

  initializePromise = initialize().finally(() => {
    initializePromise = null;
  });

  return initializePromise;
}

export default defineBackground(() => {
  browser.contextMenus.onClicked.addListener((info, tab) => {
    void handleContextMenuAction(info as Record<string, any>, tab as Record<string, any>);
  });

  browser.alarms.onAlarm.addListener((alarm) => {
    if (alarm.name === HEARTBEAT_ALARM) {
      void checkConnection();
    }
  });

  browser.webRequest.onSendHeaders.addListener(
    (details) => {
      handleRequestHeaders(details as Record<string, any>);
    },
    { urls: ['<all_urls>'] },
    getOnSendHeadersExtraInfoSpec(),
  );

  browser.webRequest.onCompleted.addListener(
    (details) => {
      clearRequestHeaders(String((details as Record<string, any>).requestId ?? ''));
    },
    { urls: ['<all_urls>'] },
  );

  browser.webRequest.onErrorOccurred.addListener(
    (details) => {
      clearRequestHeaders(String((details as Record<string, any>).requestId ?? ''));
    },
    { urls: ['<all_urls>'] },
  );

  if (supportsDownloadDeterminingFilename()) {
    browser.downloads.onDeterminingFilename.addListener((downloadItem, suggest) => {
      suggest();
      void handoffAutomaticDownload(downloadItem as Record<string, any>);
    });
  } else {
    browser.downloads.onCreated.addListener((downloadItem) => {
      void handoffAutomaticDownload(downloadItem as Record<string, any>, {
        eraseFromHistory: true,
      });
    });
  }

  browser.runtime.onInstalled.addListener(() => {
    void scheduleInitialize();
  });

  browser.runtime.onStartup.addListener(() => {
    void scheduleInitialize();
  });

  browser.runtime.onMessage.addListener((message: unknown) => {
    if (!message || typeof message !== 'object') {
      return false;
    }

    const action = (message as { action?: string }).action;
    if (action === 'checkConnection') {
      return checkConnection().then((connected) => ({
        status: connected ? 'connected' : 'disconnected',
      }));
    }

    return false;
  });

  void scheduleInitialize();
});
