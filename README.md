# Hanabi Download Manager X

English | [中文](README_CN.md)

![Preview](readme_assets/image1.png)

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Quick Start](#quick-start)
- [Architecture Design](#architecture-design)
- [Kernel Protocol](#kernel-protocol)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Hanabi Download Manager X is a cross-platform download manager built with Flutter, featuring dual-kernel architecture (NSFX and Soda) with multi-threaded concurrent downloads and resume capability.

### Technology Migration

Migrated from Python + Flet architecture to Flutter for improved cross-platform compatibility and user experience.

---

## Architecture

### Frontend
- Flutter 3.0+ - Cross-platform UI framework
- Fluent Design - Modern design language
- Responsive layout - Adapts to various screen sizes

### Dual-Kernel Architecture
- **NSFX (Next Speed Force X)** - Next-generation high-performance download kernel (v2.2.0)
- **Soda Download Kernel** - Stable Python-based download kernel (v1.5.9)
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

## Architecture Design

See [ARCHITECTURE_CN.md](ARCHITECTURE_CN.md) for detailed architecture documentation (Chinese).

### System Overview

```
UI Layer (Flutter) 
    ↓
Service Layer (IntegratedDownloadService)
    ↓
Kernel Manager (Dual-kernel support)
    ├─→ Soda Kernel (Python, Legacy)
    └─→ NSFX Kernel (Next-gen, WebSocket)
    ↓
Network Layer (HTTP/HTTPS)
```

### Key Components

- **IntegratedDownloadService**: Unified download task management
- **KernelManager**: Dual-kernel manager with dynamic switching
- **SodaKernel**: Legacy Python kernel implementation
- **NsfxKernel**: Next-generation kernel with WebSocket support

---

## Kernel Protocol

### Communication Protocol

Both kernels share the same REST API design (port 9710):

- `POST /download/add` - Add download task
- `POST /download/pause` - Pause task
- `POST /download/resume` - Resume task
- `POST /download/cancel` - Cancel task
- `GET /download/tasks` - Get task list
- `GET /settings/download-config` - Get configuration
- `POST /settings/download-config` - Update configuration

### NSFX Kernel Features

- WebSocket real-time progress updates
- Lower latency and higher performance
- Intelligent segment optimization
- Memory optimization

---

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Quick links:
- [Report Bug](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- [Request Feature](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- [Submit Pull Request](https://github.com/buaoyezz/hanabi-download-manager-x/pulls)

---

## License

This project is licensed under the GNU General Public License v3.0.

Copyright © 2026 ZZBuAoYe

Related documentation:
- [Privacy Policy](https://x.zzbuaoye.top/privacy)
- [Terms of Service](https://x.zzbuaoye.top/terms)
