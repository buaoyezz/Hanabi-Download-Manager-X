# Hanabi Browser Extension Source

Single-source browser extension for Hanabi Download Manager X.

## Stack

- `WXT`
- `TypeScript`
- `React`
- `Fluent UI React`

## Environment

- Operating systems: Windows 10/11, macOS, or Linux
- Tested locally on Windows 11 with PowerShell
- Node.js: `24.14.0` or compatible `24.x`
- npm: `11.13.0` or compatible `11.x`

## Setup

From `browser_extension/app`:

- `npm install`

The install step runs the package `postinstall` hook automatically:

- `wxt prepare`

## Commands

- `npm install`
- `npm run build:chrome`
- `npm run build:firefox`
- `npm run build:all`
- `npm run zip:chrome`
- `npm run zip:firefox`
- `npm run lint:firefox`
- `npm run verify`

Firefox reviewer build:

- `npm run build:firefox`

Firefox reviewer output:

- `../firefox_extension`
- `../firefox_extension.zip`

## Output

Build artifacts are written to sibling bundle directories:

- `../chrome_extension`
- `../firefox_extension`

All build commands route through a single script:

- `./scripts/build.mjs`

The script accepts `chrome`, `firefox`, or `all`, clears the previous generated
bundle, and rebuilds the target output.

## Notes

- Chrome and Edge use automatic download interception.
- Firefox uses observed download relay plus explicit Hanabi context-menu actions.
- Both targets talk to the local Hanabi desktop service on the configured bridge port (default `http://127.0.0.1:9701`).
- `entrypoints/`, `lib/`, `public/`, and `scripts/` contain the editable extension source.
- Generated bundles in `../chrome_extension` and `../firefox_extension` are not the source of truth.
