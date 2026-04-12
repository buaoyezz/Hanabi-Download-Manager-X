# Hanabi Browser Extension Source

Single-source browser extension for Hanabi Download Manager X.

## Stack

- `WXT`
- `TypeScript`
- `React`
- `Fluent UI React`

## Commands

- `npm install`
- `npm run build:chrome`
- `npm run build:firefox`
- `npm run build:all`
- `npm run zip:chrome`
- `npm run zip:firefox`
- `npm run lint:firefox`
- `npm run verify`

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
- Both targets talk to the local Hanabi desktop service at `http://127.0.0.1:9710`.
