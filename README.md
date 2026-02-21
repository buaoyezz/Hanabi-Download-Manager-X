# Hanabi Download Manager X

English | [中文](README_CN.md)

![Preview](readme_assets/image1.png)

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Quick Start](#quick-start)
- [License](#license)

---

## Overview

Hanabi Download Manager X is a cross-platform download manager built with Flutter, powered by the NSFX download engine. It provides multi-threaded concurrent downloads, resume capability, and efficient download management.

### Technology Migration

Migrated from Python + Flet architecture to Flutter for improved cross-platform compatibility and user experience.

---

## Architecture

### Frontend
- Flutter 3.0+ - Cross-platform UI framework
- Fluent Design - Modern design language
- Responsive layout - Adapts to various screen sizes

### Download Engine
- NSFX kernel - Custom-built download core
- HTTP Range support - Enables resume capability
- Dynamic segmentation - Optimizes download efficiency

---

## Features

### Download Management
- Multi-threaded concurrent downloads (up to 8 threads)
- Resume capability support
- Dynamic segmentation technology
- Intelligent retry mechanism
- Real-time progress tracking

### User Interface
- Smooth scroll animations (powered by scroll_animator)
- Dark/light theme switching
- Real-time speed and progress display
- Clean and intuitive interface

### Performance Optimization
- Memory counter optimization
- Concurrent control algorithm
- Network connection reuse
- File integrity verification

---

## Quick Start

### System Requirements

- Flutter SDK 3.0.0+
- Python 3.12.6+
- Windows 10/11

### Development Setup

1. Clone the repository

```bash
git clone https://github.com/buaoyezz/hanabi-download-manager-x.git
cd hanabi-download-manager-x
```

2. Install dependencies

```bash
flutter pub get
```

3. Run the application

```bash
flutter run
```

### Building for Release

Quick build for Windows:

```bash
build_release.bat
```

Manual build:

```bash
flutter build windows --release
```

Build output is located in `build/windows/x64/runner/Release/` directory.

---

## License

This project is licensed under the GNU General Public License v3.0.

Copyright © 2026 ZZBuAoYe

Related documentation:
- [Privacy Policy](https://x.zzbuaoye.top/privacy)
- [Terms of Service](https://x.zzbuaoye.top/terms)
