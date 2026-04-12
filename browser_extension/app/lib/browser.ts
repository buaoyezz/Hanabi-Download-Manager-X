type OnSendHeadersExtraInfoSpec = Array<'requestHeaders' | 'extraHeaders'>;

export function isFirefoxBrowser() {
  return import.meta.env.BROWSER === 'firefox';
}

export function getBrowserLabel() {
  return isFirefoxBrowser() ? 'Firefox' : 'Chromium';
}

export function getOnSendHeadersExtraInfoSpec(): OnSendHeadersExtraInfoSpec {
  return isFirefoxBrowser()
    ? ['requestHeaders']
    : ['requestHeaders', 'extraHeaders'];
}

export function supportsDownloadDeterminingFilename() {
  return !isFirefoxBrowser();
}
