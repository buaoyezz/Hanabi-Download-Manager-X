# Hanabi Download Manager
#### Code : X
[English](README.md) | [中文](README_CN.md)

![Promotional Image](readme_assets/image1.png)

---

## Table of Contents
- [Brand New Design](#brand-new-design)
- [Brand New Download Core](#brand-new-download-core)
- [Brand New Experience](#brand-new-experience)
- [Core Improvements](#core-improvements)
- [X Version Comparison Improvements](#x-version-comparison-improvements)
- [UI Design Attribution](#ui-design-attribution)
- [Quick Start](#quick-start)
- [License](#license)
---

<a name="brand-new-design"></a>
## Brand New Design
This time I have completely migrated HDMX from the Python + Flet technology stack to **Flutter** + **Python**
- **Flutter** as the frontend, providing smooth cross-platform experience
- **Python** as the backend, powerful download engine support

<a name="brand-new-download-core"></a>
## Brand New Download Core
**NSF** → **NSFX Download Kernel**

The NSFX download kernel brings more powerful download performance and stability.

<a name="brand-new-experience"></a>
## Brand New Experience
This complete refactoring solves many legacy issues, bringing you an unprecedented smooth experience.

---
## Still Continuing!

<a name="core-improvements"></a>
### Core Improvements
- More comprehensive kernel
- Refactored plugin code, more reliable and intelligent
- Solved communication instability issues
- Used HTTP client to protect client stability
- Fast connections won't cause excessive overhead

---

<a name="x-version-comparison-improvements"></a>


---

<a name="quick-start"></a>
## Quick Start

### Environment Requirements
- Flutter SDK (3.0.0 or higher)
- Python 3.12.6 (for NSFX download kernel)
- Windows 10/11 (primary platform)

### Installation Steps

1. Clone the repository
   ```bash
   git clone https://github.com/zzbuaoye/hanabi-download-manager-x.git
   cd hanabi-download-manager-x
   ```

2. Install Flutter dependencies
   ```bash
   flutter pub get
   ```

3. Run the application
   ```bash
   flutter run
   ```

### Building for Production

Use the quick build script (Windows):
```bash
quick_build.bat
```

Or build manually:
```bash
flutter build windows --release
```

The executable will be in `build/windows/x64/runner/Release/`

<a name="license"></a>
## License
##### GNU General Public License version 3<br>Copyright © ZZBuAoYe 2026
#### Other Legal
##### >[Privacy Policy](https://x.zzbuaoye.top/privacy)<br>>[Terms of Service](https://x.zzbuaoye.top/terms)

---

### If you like it, please give me a Star

[Chinese](./README_CN.md)
