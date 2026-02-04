# Hanabi Download Manager
#### Code : X
[English](README.md) | [中文](README_CN.md)

![宣传图](readme_assets/image1.png)

---

## 目录
- [全新的设计](#全新的设计)
- [全新的下载核心](#全新的下载核心)
- [全新的体验](#全新的体验)
- [核心改进](#核心改进)
- [X版本对比改进](#x版本对比改进)
- [UI 设计归属](#ui-设计归属)
- [快速开始](#快速开始)
- [许可证](#许可证)

---

<a name="全新的设计"></a>
## 全新的设计
这次我给 HDMX 全面从 Python + Flet 的技术栈完整的迁移到了 **Flutter** + **Python** (现已基本不在有Python，老内核已被停更)
- **Flutter** 作为前端，提供流畅的跨平台体验
- **Python** 为后端，强大的下载引擎支持

<a name="全新的下载核心"></a>
## 全新的下载核心
**NSF** → **NSFX [Soda Kernel]**

全新的 Soda Kernel 带来更强大的下载性能和稳定性。

<a name="全新的体验"></a>
## 全新的体验
本次的完全重构解决了诸多历史遗留问题，为您带来前所未有的流畅体验。

---
## 正在继续！

<a name="核心改进"></a>
### 核心改进
- 更加完善的内核
- 重构了插件代码，更加可靠智能
- 解决了通讯不稳定的问题
- 使用 HTTP 客户端保护了客户端的稳定性
- 快速链接不会带来过多的损耗

---

<a name="快速开始"></a>
## 快速开始

### 环境要求
- Flutter SDK (3.0.0 或更高版本)
- Python 3.12.6 (用于 Soda 内核)
- Windows 10/11 (主要平台)

### 安装步骤

1. 克隆仓库
   ```bash
   git clone https://github.com/zzbuaoye/hanabi-download-manager-x.git
   cd hanabi-download-manager-x
   ```

2. 安装 Flutter 依赖
   ```bash
   flutter pub get
   ```

3. 运行应用
   ```bash
   flutter run
   ```

### 生产环境构建

使用快速构建脚本 (Windows):
```bash
quick_build.bat
```

或手动构建:
```bash
flutter build windows --release`
```

可执行文件将在 `build/windows/x64/runner/Release/` 目录中
<a name="许可证"></a>
## 许可证
##### GNU General Public License version 3<br>Copyright © ZZBuAoYe 2026
#### 其他许可证
##### >[隐私政策](https://x.zzbuaoye.top/privacy)
##### >[服务条款](https://x.zzbuaoye.top/terms)
如果你访问不了他们，那就是服务器死了

---

### 若喜欢请给我一个Star
