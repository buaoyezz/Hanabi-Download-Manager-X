export const EXTENSION_DISPLAY_NAME = 'Hanabi Download Manager X';
export const EXTENSION_MANIFEST_NAME = `${EXTENSION_DISPLAY_NAME} Browser Extension`;
export const EXTENSION_DESCRIPTION = `${EXTENSION_DISPLAY_NAME} - Easy Beautiful Fast`;
export const EXTENSION_NOTIFICATION_TITLE = EXTENSION_DISPLAY_NAME;
export const HANABI_DESKTOP_SERVICE_LOOPBACK_HOST = '127.0.0.1';
export const DEFAULT_DESKTOP_SERVICE_PORT = 9701;
export const AUTO_SCAN_PORT_RANGE = 10;
export const FIREFOX_MIN_VERSION = '142.0';

export function normalizeDesktopServicePort(value: unknown) {
  const port = Number(value);
  if (!Number.isInteger(port) || port < 1024 || port > 65535) {
    return DEFAULT_DESKTOP_SERVICE_PORT;
  }

  return port;
}

export function getHanabiDesktopServiceHost(port: unknown = DEFAULT_DESKTOP_SERVICE_PORT) {
  return `${HANABI_DESKTOP_SERVICE_LOOPBACK_HOST}:${normalizeDesktopServicePort(port)}`;
}

export function getHanabiDesktopServiceUrl(port: unknown = DEFAULT_DESKTOP_SERVICE_PORT) {
  return `http://${getHanabiDesktopServiceHost(port)}`;
}

export function getAutoDiscoveryCandidatePorts(
  exclude: number[] = [],
): number[] {
  const excludeSet = new Set(exclude);
  const candidates: number[] = [];
  const low = Math.max(1024, DEFAULT_DESKTOP_SERVICE_PORT - AUTO_SCAN_PORT_RANGE);
  const high = Math.min(65535, DEFAULT_DESKTOP_SERVICE_PORT + AUTO_SCAN_PORT_RANGE);

  for (let port = low; port <= high; port++) {
    if (!excludeSet.has(port)) {
      candidates.push(port);
    }
  }

  return candidates;
}
