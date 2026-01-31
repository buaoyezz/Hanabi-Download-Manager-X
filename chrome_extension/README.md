# Hanabi Download ManagerX Browser Extension

Browser extension for Hanabi Download ManagerX - intercepts browser downloads and sends them to the desktop client.

## Features

- Intercepts browser downloads automatically
- Sends download tasks to Hanabi Download ManagerX
- Real-time connection status indicator
- Enable/disable extension on demand
- Dark mode support

## Installation

### Chrome/Edge

1. Open `chrome://extensions/` or `edge://extensions/`
2. Enable "Developer mode"
3. Click "Load unpacked"
4. Select the `chrome_extension` folder

### Firefox

1. Open `about:debugging#/runtime/this-firefox`
2. Click "Load Temporary Add-on"
3. Select the `manifest.json` file in `chrome_extension` folder

## Usage

1. Make sure Hanabi Download ManagerX is running
2. The extension will automatically connect to the client (port 9710)
3. When you download a file in the browser, it will be intercepted and sent to Hanabi
4. You can enable/disable the extension by clicking the extension icon

## Connection Status

- Green checkmark: Connected to Hanabi Download ManagerX
- Red X: Disconnected

## API Endpoint

The extension connects to: `http://127.0.0.1:9710`

Make sure the Hanabi Download ManagerX kernel is running on this port.

## Changes from Previous Version

- Changed from WebSocket (port 14370) to HTTP API (port 9710)
- Updated to work with Soda Speed Force Kernel
- Completely redesigned modern UI with gradient background
- Real-time connection status with animated indicator
- Simplified connection logic
- Added notification support
- Updated branding to Hanabi Download ManagerX

## Development

Files:
- `manifest.json` - Extension configuration
- `background.js` - Background service worker
- `popup.html` - Extension popup UI
- `popup.js` - Popup logic
- `icon*.png` - Extension icons

## Troubleshooting

If the extension shows "Disconnected":
1. Make sure Hanabi Download ManagerX is running
2. Check if the kernel server is running on port 9710
3. Try restarting the extension
4. Check browser console for errors

## Port Configuration

Default port: 9710

To change the port, edit `background.js`:
```javascript
const API_BASE_URL = "http://127.0.0.1:9710";
```
