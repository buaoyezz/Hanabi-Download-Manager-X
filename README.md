# Hanabi Download Manager X

English | [中文](README_CN.md)

![Preview](readme_assets/image1.png)

> [!NOTE]
> This project requires Windows 10/11 and Flutter SDK 3.0.0+.

## Overview

Hanabi Download Manager X is a download manager built with Flutter.

---

## Features

- Multi-threaded concurrent downloads (up to 8 threads)
- Resume capability
- Retry mechanism
- Progress tracking
- Dark/light theme
- Speed and progress display

---

## Quick Start

### Requirements

- Flutter SDK 3.0.0+
- Windows 10/11

### Run

```bash
git clone https://github.com/buaoyezz/hanabi-download-manager-x.git
cd hanabi-download-manager-x
flutter pub get
flutter run
```

```bash
dart run tool/sync_l10n.dart
```

> `app_en.arb` can now be auto-synced from `app_zh.arb`; the Windows run/build scripts invoke this step automatically before launch.

> [!TIP]
> Use `build_release.bat` for quick builds on Windows.

### Build

```bash
build_release.bat
```

Or:

```bash
flutter build windows --release
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- [Report Bug](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- [Request Feature](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- [Add Translation](docs/ADD_NEW_LANGUAGE.md)

---

## License

This project is dual-licensed:

- **Core Application**: [GNU General Public License v3.0](LICENSE).
- **Plugins and SDK (`plugins/` directory)**: [MIT License](plugins/LICENSE).

This means you are free to develop both open-source and closed-source (commercial) plugins for Hanabi Download Manager X without being subject to the GPLv3 viral requirements, as long as you use the provided MIT-licensed plugin APIs.

Copyright © 2026 ZZBuAoYe

- [Privacy Policy](https://x.zzbuaoye.net/privacy)
- [Terms of Service](https://x.zzbuaoye.net/terms)
