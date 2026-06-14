import { browser } from 'wxt/browser';
import { defineBackground } from 'wxt/utils/define-background';
import {
  getOnSendHeadersExtraInfoSpec,
  isFirefoxBrowser,
  supportsDownloadDeterminingFilename,
} from '@/lib/browser';
import {
  DEFAULT_DESKTOP_SERVICE_PORT,
  EXTENSION_NOTIFICATION_TITLE,
  getAutoDiscoveryCandidatePorts,
  getHanabiDesktopServiceUrl,
  normalizeDesktopServicePort,
} from '@/lib/extension-meta';
import {
  DEFAULT_BROWSER_SMALL_FILE_THRESHOLD,
  STORAGE_DEFAULTS,
  STORAGE_KEYS,
  normalizeBrowserDownloadHandlingMode,
  normalizePortMode,
  type BrowserDownloadHandlingMode,
} from '@/lib/storage';

const HEARTBEAT_ALARM = 'hanabi-connection-heartbeat';
const DESKTOP_REQUEST_TIMEOUT = 3000;
const DESKTOP_HEALTH_REQUEST_TIMEOUT = 750;
const CONNECTED_CHECK_CACHE_TTL = 30 * 1000;
const DISCONNECTED_CHECK_CACHE_TTL = 30 * 1000;
const HEARTBEAT_MIN_INTERVAL = 3 * 60 * 1000;
const HEARTBEAT_ALARM_INTERVAL_MINUTES = 3;
const HEADER_SNAPSHOT_TTL = 45 * 1000;
const HEADER_SNAPSHOT_LIMIT = 80;
const MAX_HEADER_VALUE_LENGTH = 8192;
const MAX_HEADER_TOTAL_CHARS = 24 * 1024;
const NOTIFICATION_DEDUP_TTL = 4000;
const AUTO_HANDOFF_DEDUP_TTL = 4000;
const AUTO_HANDOFF_ID_DEDUP_TTL = 6000;
const CAPTURED_HEADER_NAMES = new Set([
  'accept',
  'accept-language',
  'authorization',
  'cookie',
  'referer',
  'user-agent',
]);
const HEADER_CAPTURE_FILTER = {
  urls: ['http://*/*', 'https://*/*'],
  types: ['main_frame', 'sub_frame', 'object', 'other'],
} satisfies Parameters<
  typeof browser.webRequest.onSendHeaders.addListener
>[1];
type PortScanMode = 'primary' | 'nearby' | 'full';
const MENU_IDS = {
  link: 'hanabi-send-link',
  image: 'hanabi-send-image',
  audio: 'hanabi-send-audio',
  video: 'hanabi-send-video',
  page: 'hanabi-send-page',
} as const;
let initializePromise: Promise<void> | null = null;
let contextMenuSyncPromise: Promise<void> = Promise.resolve();
let connectionCheckPromise: Promise<boolean> | null = null;
let lastConnectionCheck:
  | {
      checkedAt: number;
      connected: boolean;
    }
  | null = null;
let lastHeartbeatAt = 0;
let lastPersistedConnectionStatus: boolean | null = null;
let lastPersistedPopupLocale: string | null = null;
let lastDesktopHandoffPolicy: DesktopHandoffPolicy = {
  mode: 'smart',
  smallFileThreshold: DEFAULT_BROWSER_SMALL_FILE_THRESHOLD,
};
let headerCaptureEnabled = false;

type HeaderRecord = Record<string, string>;
type HeaderSnapshot = {
  headers: HeaderRecord;
  capturedAt: number;
  supportsRange: boolean;
};

type DesktopBridgeResponse = {
  api_port?: number;
  connected_port?: number;
  requires_port_switch?: boolean;
  service_host?: string;
};

type DesktopHealthResponse = DesktopBridgeResponse & {
  status?: string;
  locale?: string;
  browser_download_handling_mode?: string;
  browser_download_small_file_threshold?: number;
};

type HeartbeatResponse = DesktopBridgeResponse & {
  success?: boolean;
};

type DownloadPayload = {
  url: string;
  filename: string;
  referer: string;
  user_agent: string;
  cookies: string;
  headers: HeaderRecord;
  file_size?: number;
  total_bytes?: number;
  mime?: string;
  danger?: string;
  from_browser: boolean;
  browser: string;
};

type ConnectionCheckOptions = {
  force?: boolean;
  sendHeartbeat?: boolean;
  portScan?: PortScanMode;
};

type DesktopHandoffPolicy = {
  mode: BrowserDownloadHandlingMode;
  smallFileThreshold: number;
};

const browserKind = isFirefoxBrowser() ? 'firefox' : 'chromium';
const browserDisplayName = isFirefoxBrowser() ? 'Firefox' : 'Chromium';
const sessionId = `${browserKind}-${browser.runtime.id}-${Date.now()}-${Math.random()
  .toString(36)
  .slice(2)}`;

const headerSnapshotsByUrl = new Map<string, HeaderSnapshot>();
const requestHeadersByRequestId = new Map<string, HeaderSnapshot>();
const recentNotifications = new Map<string, number>();
const recentAutomaticHandoffs = new Map<string, number>();
const recentAutomaticDownloadIds = new Map<string, number>();

function pruneRecentEntries(cache: Map<string, number>, now = Date.now()) {
  for (const [key, expiresAt] of cache.entries()) {
    if (expiresAt <= now) {
      cache.delete(key);
    }
  }
}

function buildAutomaticHandoffSignature(downloadItem: Record<string, any>) {
  const url = String(downloadItem.finalUrl || downloadItem.url || '').trim();
  const filename = String(downloadItem.filename || '').trim();
  const referer = String(downloadItem.referrer || '').trim();
  return `${url}::${filename}::${referer}`;
}

function dedupePorts(ports: Array<number | undefined>) {
  return [...new Set(ports.map((port) => normalizeDesktopServicePort(port)))];
}

async function getStoredDesktopServicePort() {
  const values = await browser.storage.local.get({
    [STORAGE_KEYS.desktopServicePort]:
      STORAGE_DEFAULTS[STORAGE_KEYS.desktopServicePort],
  });

  return normalizeDesktopServicePort(values[STORAGE_KEYS.desktopServicePort]);
}

async function getPortMode() {
  const values = await browser.storage.local.get({
    [STORAGE_KEYS.portMode]: STORAGE_DEFAULTS[STORAGE_KEYS.portMode],
  });
  return normalizePortMode(values[STORAGE_KEYS.portMode]);
}

async function persistDesktopServicePort(port: number) {
  // In 'fixed' or 'manual' mode, do not auto-update the stored port
  const mode = await getPortMode();
  if (mode === 'fixed' || mode === 'manual') {
    return normalizeDesktopServicePort(port);
  }
  const normalizedPort = normalizeDesktopServicePort(port);
  await browser.storage.local.set({
    [STORAGE_KEYS.desktopServicePort]: normalizedPort,
  });
  return normalizedPort;
}

async function resolveDesktopServicePorts(preferredPort?: number) {
  const mode = await getPortMode();

  // 'fixed' mode: always use the compiled default bridge port only
  if (mode === 'fixed') {
    return dedupePorts([DEFAULT_DESKTOP_SERVICE_PORT]);
  }

  const storedPort =
    preferredPort === undefined
      ? await getStoredDesktopServicePort()
      : normalizeDesktopServicePort(preferredPort);

  // 'manual' mode: only try the user-specified stored port, no fallback probing
  if (mode === 'manual') {
    return dedupePorts([storedPort]);
  }

  // 'auto' mode: try stored port first, then the default, then scan nearby ports
  const primaryPorts = dedupePorts([storedPort, DEFAULT_DESKTOP_SERVICE_PORT]);
  const scanPorts = getAutoDiscoveryCandidatePorts(primaryPorts);
  return [...primaryPorts, ...scanPorts];
}

async function fetchDesktopJson<T extends DesktopBridgeResponse>(
  path: string,
  init?: RequestInit,
  preferredPort?: number,
) {
  const candidatePorts = await resolveDesktopServicePorts(preferredPort);
  let lastError: unknown = null;

  for (const candidatePort of candidatePorts) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => {
      controller.abort();
    }, DESKTOP_REQUEST_TIMEOUT);

    try {
      const response = await fetch(
        `${getHanabiDesktopServiceUrl(candidatePort)}${path}`,
        {
          ...init,
          signal: controller.signal,
        },
      );
      if (!response.ok) {
        lastError = new Error(`HTTP ${response.status}`);
        continue;
      }

      const data = (await response.json()) as T;
      const resolvedPort = normalizeDesktopServicePort(
        data.api_port ?? candidatePort,
      );

      if (resolvedPort !== candidatePort || resolvedPort !== candidatePorts[0]) {
        await persistDesktopServicePort(resolvedPort);
      }

      return {
        data,
        port: resolvedPort,
      };
    } catch (error) {
      lastError = error;
    } finally {
      clearTimeout(timeoutId);
    }
  }

  throw lastError ?? new Error(`Failed to reach Hanabi desktop service: ${path}`);
}

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

let lastPruneTime = 0;
const PRUNE_INTERVAL = 10000; // 10 seconds

function pruneHeaderSnapshots() {
  const now = Date.now();

  if (now - lastPruneTime > PRUNE_INTERVAL) {
    for (const [url, snapshot] of headerSnapshotsByUrl) {
      if (now - snapshot.capturedAt > HEADER_SNAPSHOT_TTL) {
        headerSnapshotsByUrl.delete(url);
      }
    }
    lastPruneTime = now;
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
    [STORAGE_KEYS.shouldDisableExtension]: STORAGE_DEFAULTS[STORAGE_KEYS.shouldDisableExtension],
  });

  return values[STORAGE_KEYS.shouldDisableExtension] === true;
}

async function getAutomaticHandoffState() {
  const values = await browser.storage.local.get({
    [STORAGE_KEYS.enableAutomaticHandoff]:
      STORAGE_DEFAULTS[STORAGE_KEYS.enableAutomaticHandoff],
  });

  return values[STORAGE_KEYS.enableAutomaticHandoff] !== false;
}

async function shouldShowNotifications() {
  const values = await browser.storage.local.get({
    [STORAGE_KEYS.showNotifications]: STORAGE_DEFAULTS[STORAGE_KEYS.showNotifications],
  });

  return values[STORAGE_KEYS.showNotifications] !== false;
}

async function syncConnectionBadge() {
  const values = await browser.storage.local.get({
    [STORAGE_KEYS.isConnected]: STORAGE_DEFAULTS[STORAGE_KEYS.isConnected],
    [STORAGE_KEYS.showConnectionBadge]:
      STORAGE_DEFAULTS[STORAGE_KEYS.showConnectionBadge],
  });

  if (values[STORAGE_KEYS.showConnectionBadge] === false) {
    await browser.action.setBadgeText({ text: '' });
    return;
  }

  const connected = values[STORAGE_KEYS.isConnected] === true;
  await browser.action.setBadgeBackgroundColor({
    color: connected ? '#6CCB5F' : '#FF6B6B',
  });
  await browser.action.setBadgeText({ text: connected ? '√' : '×' });
}

async function updateConnectionStatus(connected: boolean) {
  if (lastPersistedConnectionStatus === connected) {
    return;
  }

  lastPersistedConnectionStatus = connected;
  await browser.storage.local.set({
    [STORAGE_KEYS.isConnected]: connected,
  });
  await syncConnectionBadge();
}

async function persistPopupLocale(locale: string | undefined) {
  if (!locale || lastPersistedPopupLocale === locale) {
    return;
  }

  lastPersistedPopupLocale = locale;
  await browser.storage.local.set({
    [STORAGE_KEYS.popupLocale]: locale,
  });
}

function normalizeSmallFileThreshold(value: unknown) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return DEFAULT_BROWSER_SMALL_FILE_THRESHOLD;
  }
  return Math.min(
    Math.max(Math.trunc(parsed), 1024 * 1024),
    512 * 1024 * 1024,
  );
}

function rememberDesktopHandoffPolicy(data: DesktopHealthResponse | undefined) {
  lastDesktopHandoffPolicy = {
    mode: normalizeBrowserDownloadHandlingMode(
      data?.browser_download_handling_mode,
    ),
    smallFileThreshold: normalizeSmallFileThreshold(
      data?.browser_download_small_file_threshold,
    ),
  };
}

function getDeviceInfo() {
  return {
    browser: browserDisplayName,
    browserKind,
    extensionId: browser.runtime.id,
    extensionVersion: browser.runtime.getManifest().version,
    os: globalThis.navigator?.platform ?? 'unknown',
    userAgent: globalThis.navigator?.userAgent ?? '',
    deviceType: 'browser_extension',
  };
}

async function sendDesktopHeartbeat() {
  return fetchDesktopJson<HeartbeatResponse>('/stats/heartbeat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      session_id: sessionId,
      device_fingerprint: `${browserKind}:${browser.runtime.id}`,
      device_info: getDeviceInfo(),
    }),
  });
}

async function maybeSendDesktopHeartbeat(force = false) {
  const now = Date.now();
  if (!force && now - lastHeartbeatAt < HEARTBEAT_MIN_INTERVAL) {
    return;
  }

  await sendDesktopHeartbeat();
  lastHeartbeatAt = Date.now();
}

async function checkConnection(options: ConnectionCheckOptions = {}) {
  const now = Date.now();
  const cacheTtl = lastConnectionCheck?.connected
    ? CONNECTED_CHECK_CACHE_TTL
    : DISCONNECTED_CHECK_CACHE_TTL;
  if (
    !options.force &&
    lastConnectionCheck &&
    now - lastConnectionCheck.checkedAt < cacheTtl
  ) {
    return lastConnectionCheck.connected;
  }

  if (connectionCheckPromise) {
    return connectionCheckPromise;
  }

  connectionCheckPromise = (async () => {
    const checkedAt = Date.now();

    try {
      const { data } = await fetchDesktopJson<DesktopHealthResponse>('/health');
      const connected = data.status === 'ok';
      lastConnectionCheck = { checkedAt, connected };
      if (connected) {
        rememberDesktopHandoffPolicy(data);
      }
      if (connected && options.sendHeartbeat) {
        await maybeSendDesktopHeartbeat();
      }
      await updateConnectionStatus(connected);
      await persistPopupLocale(data.locale);
      return connected;
    } catch (error) {
      console.warn('Connection check failed', error);
      lastConnectionCheck = { checkedAt, connected: false };
      await updateConnectionStatus(false);
      return false;
    } finally {
      connectionCheckPromise = null;
    }
  })();

  return connectionCheckPromise;
}

async function getConnectionSnapshot() {
  const connected = await checkConnection({ force: true }).catch(() => false);
  const desktopServicePort = await getStoredDesktopServicePort();
  const values = await browser.storage.local.get({
    [STORAGE_KEYS.popupLocale]: STORAGE_DEFAULTS[STORAGE_KEYS.popupLocale],
  });
  return {
    status: connected ? 'connected' : 'disconnected',
    apiPort: desktopServicePort,
    locale: String(values[STORAGE_KEYS.popupLocale] ?? 'en'),
    browserDownloadHandlingMode: lastDesktopHandoffPolicy.mode,
    browserDownloadSmallFileThreshold:
      lastDesktopHandoffPolicy.smallFileThreshold,
  };
}

async function createNotification(message: string) {
  if (!(await shouldShowNotifications())) {
    return;
  }

  const now = Date.now();
  pruneRecentEntries(recentNotifications, now);
  const cacheKey = message.trim();
  if (cacheKey) {
    const duplicateUntil = recentNotifications.get(cacheKey);
    if (duplicateUntil && duplicateUntil > now) {
      return;
    }
    recentNotifications.set(cacheKey, now + NOTIFICATION_DEDUP_TTL);
  }

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
    browser: browserKind,
  };
}

function readPositiveNumber(value: unknown) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return undefined;
  }
  return Math.trunc(parsed);
}

function readDownloadItemSize(downloadItem: Record<string, any>) {
  const fileSize = readPositiveNumber(downloadItem.fileSize);
  const totalBytes = readPositiveNumber(downloadItem.totalBytes);
  return {
    fileSize,
    totalBytes,
    bestSize: fileSize ?? totalBytes,
  };
}

function isBrowserDangerSafe(downloadItem: Record<string, any>) {
  const danger = String(downloadItem.danger ?? '').trim().toLowerCase();
  return (
    danger === '' ||
    danger === 'safe' ||
    danger === 'accepted' ||
    danger === 'allowlistedbypolicy'
  );
}

function shouldLetBrowserKeepDownload(
  downloadItem: Record<string, any>,
  policy: DesktopHandoffPolicy,
) {
  if (!isBrowserDangerSafe(downloadItem)) {
    return true;
  }

  if (policy.mode !== 'small_files_to_browser') {
    return false;
  }

  const { bestSize } = readDownloadItemSize(downloadItem);
  return bestSize !== undefined && bestSize <= policy.smallFileThreshold;
}

function attachDownloadMetadata(
  payload: DownloadPayload,
  downloadItem: Record<string, any>,
) {
  const { fileSize, totalBytes } = readDownloadItemSize(downloadItem);
  if (fileSize !== undefined) {
    payload.file_size = fileSize;
  }
  if (totalBytes !== undefined) {
    payload.total_bytes = totalBytes;
  }

  const mime = String(downloadItem.mime ?? '').trim();
  if (mime) {
    payload.mime = mime;
  }

  const danger = String(downloadItem.danger ?? '').trim();
  if (danger) {
    payload.danger = danger;
  }

  return payload;
}

async function sendDownloadToHanabi(
  payload: DownloadPayload,
  options: { notifyOnSuccess?: boolean; skipConnectionCheck?: boolean } = {},
) {
  const _notifyOnSuccess = options.notifyOnSuccess ?? false;
  void _notifyOnSuccess;

  if (!options.skipConnectionCheck) {
    const connected = await checkConnection();
    if (!connected) {
      await createNotification('Hanabi desktop client is disconnected.');
      return { success: false, error: 'disconnected' };
    }
  }

  try {
    const { data } = await fetchDesktopJson<DesktopBridgeResponse & {
      success?: boolean;
      error?: string;
    }>('/download/add', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
    if (data.success) {
      // Suppress success toast to avoid duplicate Windows notifications
      // under repeated browser download event emissions.
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
  automaticHandoffEnabled: boolean,
) {
  const downloadUrl = String(downloadItem.finalUrl || downloadItem.url || '');

  if (
    disabled ||
    !connected ||
    !automaticHandoffEnabled ||
    !isSupportedUrl(downloadUrl)
  ) {
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
  const now = Date.now();
  pruneRecentEntries(recentAutomaticHandoffs, now);
  pruneRecentEntries(recentAutomaticDownloadIds, now);

  const downloadId = String(downloadItem.id ?? '').trim();
  if (downloadId) {
    const duplicateIdUntil = recentAutomaticDownloadIds.get(downloadId);
    if (duplicateIdUntil && duplicateIdUntil > now) {
      return;
    }
    recentAutomaticDownloadIds.set(downloadId, now + AUTO_HANDOFF_ID_DEDUP_TTL);
  }

  const handoffSignature = buildAutomaticHandoffSignature(downloadItem);
  const duplicateUntil = recentAutomaticHandoffs.get(handoffSignature);
  if (duplicateUntil && duplicateUntil > now) {
    return;
  }
  recentAutomaticHandoffs.set(handoffSignature, now + AUTO_HANDOFF_DEDUP_TTL);

  const disabled = await getDisableState();
  const connected = await checkConnection({
    force: lastConnectionCheck?.connected === true,
  });
  const automaticHandoffEnabled = await getAutomaticHandoffState();
  if (
    !shouldHandleAutomaticDownload(
      downloadItem,
      disabled,
      connected,
      automaticHandoffEnabled,
    )
  ) {
    return;
  }

  if (shouldLetBrowserKeepDownload(downloadItem, lastDesktopHandoffPolicy)) {
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
    attachDownloadMetadata(
      buildPayloadFromHeaders(
        downloadUrl,
        filename,
        headers,
        downloadItem.referrer ?? '',
      ),
      downloadItem,
    ),
    { skipConnectionCheck: true },
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

  await sendDownloadToHanabi(payload, { notifyOnSuccess: true });
}

async function ensureContextMenus() {
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

async function removeContextMenus() {
  try {
    await browser.contextMenus.removeAll();
  } catch (error) {
    console.warn('Failed to clear context menus', error);
  }
}

async function syncContextMenusNow() {
  const values = await browser.storage.local.get({
    [STORAGE_KEYS.enableContextMenus]: STORAGE_DEFAULTS[STORAGE_KEYS.enableContextMenus],
  });

  await removeContextMenus();

  if (values[STORAGE_KEYS.enableContextMenus] === false) {
    return;
  }

  await ensureContextMenus();
}

function scheduleContextMenuSync() {
  contextMenuSyncPromise = contextMenuSyncPromise
    .catch(() => undefined)
    .then(() => syncContextMenusNow());

  return contextMenuSyncPromise;
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

  // Prune requestHeadersByRequestId to prevent memory leaks
  const now = Date.now();
  if (now % 10 === 0) { // Prune roughly 10% of the time to save CPU
    for (const [id, snap] of requestHeadersByRequestId) {
      if (now - snap.capturedAt > 5 * 60 * 1000) { // 5 minutes TTL
        requestHeadersByRequestId.delete(id);
      }
    }
  }

  requestHeadersByRequestId.set(details.requestId, snapshot);
  rememberHeaderSnapshot(details.url, headers, supportsRange);
}

function clearRequestHeaders(requestId: string) {
  requestHeadersByRequestId.delete(requestId);
}

async function initialize() {
  const state = await browser.storage.local.get(STORAGE_DEFAULTS);
  const pendingDefaults: Record<string, boolean | string | number> = {};

  for (const [key, value] of Object.entries(STORAGE_DEFAULTS)) {
    if (typeof state[key] !== typeof value) {
      pendingDefaults[key] = value;
    }
  }

  if (Object.keys(pendingDefaults).length > 0) {
    await browser.storage.local.set(pendingDefaults);
  }

  await scheduleContextMenuSync();
  await syncConnectionBadge();
  await checkConnection({ force: true, sendHeartbeat: true });
  await browser.alarms.create(HEARTBEAT_ALARM, { periodInMinutes: HEARTBEAT_ALARM_INTERVAL_MINUTES });
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
      void checkConnection({ force: true, sendHeartbeat: true });
    }
  });

  browser.webRequest.onSendHeaders.addListener(
    (details) => {
      handleRequestHeaders(details as Record<string, any>);
    },
    HEADER_CAPTURE_FILTER,
    getOnSendHeadersExtraInfoSpec(),
  );

  browser.webRequest.onCompleted.addListener(
    (details) => {
      clearRequestHeaders(String((details as Record<string, any>).requestId ?? ''));
    },
    HEADER_CAPTURE_FILTER,
  );

  browser.webRequest.onErrorOccurred.addListener(
    (details) => {
      clearRequestHeaders(String((details as Record<string, any>).requestId ?? ''));
    },
    HEADER_CAPTURE_FILTER,
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
      return getConnectionSnapshot();
    }

    return false;
  });

  browser.storage.onChanged.addListener((changes, areaName) => {
    if (areaName !== 'local') {
      return;
    }

    if (STORAGE_KEYS.enableContextMenus in changes) {
      void scheduleContextMenuSync();
    }

    if (
      STORAGE_KEYS.desktopServicePort in changes ||
      STORAGE_KEYS.portMode in changes
    ) {
      lastConnectionCheck = null;
      void checkConnection({ force: true });
    }

    if (
      STORAGE_KEYS.showConnectionBadge in changes ||
      STORAGE_KEYS.isConnected in changes
    ) {
      void syncConnectionBadge();
    }
  });

  void scheduleInitialize();
});
