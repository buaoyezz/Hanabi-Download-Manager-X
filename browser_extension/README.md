# Hanabi Browser Extensions

This directory contains the browser extension source for Hanabi Download Manager X.

## Structure

- `app/`: single-source WXT + TypeScript + React project
- `chrome_extension/`: local generated Chrome / Edge bundle, ignored by git
- `firefox_extension/`: local generated Firefox bundle, ignored by git

`app/` is the only source directory. `chrome_extension/` and `firefox_extension/`
are local build outputs, should not be edited by hand, and are not committed.

## Build

Run builds from `browser_extension/app`:

- `npm run build:chrome`
- `npm run build:firefox`
- `npm run build:all`

All three commands go through the same script:

- `app/scripts/build.mjs`

That script clears the old bundle directory and regenerates the local target output:

- Chrome / Edge -> `browser_extension/chrome_extension`
- Firefox -> `browser_extension/firefox_extension`

## Chrome / Edge

1. Open `chrome://extensions/` or `edge://extensions/`
2. Enable Developer mode
3. Click Load unpacked
4. Select `browser_extension/chrome_extension`

Behavior:

- Automatically intercepts browser downloads
- Sends them to the Hanabi desktop client on the configured local bridge port (default `http://127.0.0.1:9710`)

## Firefox

1. Open `about:debugging#/runtime/this-firefox`
2. Click Load Temporary Add-on
3. Select `browser_extension/firefox_extension/manifest.json`

Behavior:

- Relays observed downloads to Hanabi where Firefox allows it
- Keeps right-click context menu items for links, images, audio, video, and the current page as fallback
- Shows connection state in the toolbar popup
- Requires Firefox `142.0+`

## Notes

- Make sure Hanabi Download Manager X is running before using either extension.
- Source of truth lives in `app/`; do not hand-edit the generated bundle folders.
- Build outputs are intentionally ignored by git. Run `npm run build:chrome`,
  `npm run build:firefox`, or `npm run build:all` before loading the unpacked extension.
