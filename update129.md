## V1.2.9 Release Notes

### Core Performance Enhancements:
[+] Implemented comprehensive performance monitoring system with frame rate tracking and rebuild statistics
[+] Optimized HomeScreen rendering using context.select to avoid unnecessary widget rebuilds
[+] Added notification performance mode settings (Quality/Balanced/Performance)
[+] Replaced Timer-based progress animation with AnimationController for vsync synchronization
[+] Enhanced notification system with smooth animations and reduced jank

### User Interface Improvements:
[+] Redesigned developer settings page with Fluent 2 minimalist design language
[+] Added performance mode selector in appearance settings (Quality/Balanced/Performance Priority)
[+] Enhanced status page with popup window testing functionality
[+] Improved notification cards with click interaction support (tap callbacks and actions)
[+] Unified notification system across all pages replacing legacy InfoBar components

### New Features:
[+] Introduced Hanabi Popup - Independent Tauri-based download popup window application
[+] Added Windows Named Pipe communication for popup-to-main-app download requests
[+] Implemented popup progress push service for real-time download status updates
[+] Added automatic update check on startup with notification display
[+] Introduced performance monitor page for real-time frame analysis (Beta)
[+] Added pipe listener service for inter-process communication

### Bug Fixes and Stability:
[+] Fixed notification animation timing issues with proper vsync synchronization
[+] Fixed potential memory leaks in notification progress timer
[+] Fixed developer settings page animation controller disposal
[+] Improved error handling in popup window service with fallback mechanisms
[+] Enhanced task storage reliability with better error recovery

### Developer Features:
[+] Added performance monitor page toggle in developer settings (Beta)
[+] Implemented frame data tracking with jank detection (>16.67ms threshold) (Beta)
[+] Added widget rebuild counter for performance debugging (Beta)
[+] Introduced popup window connectivity testing tools (Beta)
[+] Enhanced logging for pipe listener and popup progress services (Beta)

> The (Beta) designation indicates that this feature is not yet fully developed or thoroughly tested for bugs.

---
### File :
>[HanabiDownloadManagerX_Release_Latest.zip](https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.2.9/HanabiDownloadManagerX_Release_Latest.zip)
sha256:TBD
>[chrome_extension.zip](https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.0.0/chrome_extension.zip)
sha256:766d08b523e616cd9dde4ec079519a6720e6defd3b95ebecee6aef161612ff55
### Extension:
>[Hanabi Download Manager X Browser Extension - Edge](https://microsoftedge.microsoft.com/addons/detail/hanabi-download-managerx-/nifalaonnaeobogcnhfoeaklpihcaeia)

Official Website: https://x.zzbuaoye.top
**Full Changelog**: https://github.com/buaoyezz/Hanabi-Download-Manager-X/compare/V1.2.8...V1.2.9
