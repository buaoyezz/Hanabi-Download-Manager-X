# Hanabi Download Manager X

[English](README.md) | 中文

![Preview](readme_assets/image1.png)

## 目录

- [项目简介](#项目简介)
- [技术架构](#技术架构)
- [核心特性](#核心特性)
- [快速开始](#快速开始)
- [架构设计](#架构设计)
- [内核协议](#内核协议)
- [贡献指南](#贡献指南)
- [许可证](#许可证)

---

## 项目简介

Hanabi Download Manager X 是一个基于 Flutter 开发的跨平台下载管理器，现已完全切换到 NSFX 下载内核，提供多线程并发下载、断点续传等功能。

### 技术栈迁移

从 Python + Flet 架构迁移至 Flutter，提升了跨平台兼容性和用户体验；旧版 Python 下载内核现已彻底移除。

---

## 技术架构

### 前端框架
- Flutter 3.0+ - 跨平台 UI 框架
- Fluent Design - 现代化设计语言
- 响应式布局 - 适配多种屏幕尺寸

### NSFX 架构
- **NSFX (Next Speed Force X)** - 新一代高性能下载内核 (v2.2.0)
- HTTP Range 支持 - 实现断点续传
- 动态分段算法 - 优化下载效率

---

## 核心特性

### 下载管理
- 多线程并发下载（最多 8 线程）
- 断点续传支持
- 动态分段技术
- 智能重试机制
- 实时进度跟踪

### 用户界面
- 平滑滚动动画（基于 scroll_animator）
- 深色/浅色主题切换
- 实时速度和进度显示
- 简洁直观的操作界面

### 性能优化
- 内存计数器优化
- 并发控制算法
- 网络连接复用
- 文件完整性验证

---

## 快速开始

### 系统要求

- Flutter SDK 3.0.0+
- Windows 10/11

### 开发环境配置

1. 克隆仓库

```bash
git clone https://github.com/buaoyezz/hanabi-download-manager-x.git
cd hanabi-download-manager-x
```

2. 安装依赖

```bash
flutter pub get
```

Windows 下如果 `flutter run` 卡在 `rhttp` 插件构建，先执行下面的补丁脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply-rhttp-windows-fix.ps1
```

该脚本会根据 `.dart_tool/package_config.json` 自动定位 Pub Cache 中实际解析到的 `rhttp` 包，并修补两个 Windows 构建脚本。建议在清理 Pub Cache 或重新执行 `flutter pub get` 后重跑一次。

3. 运行应用

```bash
flutter run
```

### 构建发布版本

Windows 平台快速构建：

```bash
build_release.bat
```

手动构建：

```bash
flutter build windows --release
```

构建产物位于 `build/windows/x64/runner/Release/` 目录。

---

## 架构设计

### 整体架构

```
UI 层 (Flutter)
    ↓
IntegratedDownloadService
    ↓
KernelManager (NSFX 运行时管理)
    ↓
HTTP + WebSocket API (127.0.0.1:9710)
    ↓
网络层 (HTTP/HTTPS)
```

### 核心组件

| 组件 | 职责 |
|------|------|
| `IntegratedDownloadService` | 统一下载任务管理、状态同步、进度追踪 |
| `KernelManager` | NSFX 生命周期管理、接口转发、事件流订阅 |
| `NsfxKernel` | 下载引擎、动态分段、实时进度推送 |

### 辅助服务

| 服务 | 职责 |
|------|------|
| `NetworkStatusService` | 网络状态监控 |
| `SystemTrayService` | 系统托盘集成 |
| `UpdateService` | 应用自动更新 |
| `WindowEffectService` | 窗口特效 (Mica/Acrylic) |
| `PipeListenerService` | 接收浏览器扩展请求 |
| `PopupProgressService` | 推送进度到弹窗 |
| `NotificationSettingsService` | 通知设置管理 |
| `LocalizationService` | 多语言支持 |
| `AppLoggerService` | 日志记录 |
| `ClientConfigService` | 配置管理 |

---

## 内核协议

Hanabi 现仅保留 NSFX 下载内核，本地服务默认监听 `127.0.0.1:9710`。

### REST API

- `POST /download/add` - 添加下载任务
- `POST /download/pause` - 暂停任务
- `POST /download/resume` - 恢复任务
- `POST /download/cancel` - 取消任务
- `GET /download/tasks` - 获取任务列表
- `GET /download/statistics` - 获取运行统计
- `GET /settings/download-config` - 获取下载配置
- `POST /settings/download-config` - 更新下载配置
- `GET /health` - 健康检查

### WebSocket

NSFX 使用 WebSocket 推送实时进度：

```
ws://127.0.0.1:9710/ws/progress
```

### 配置文件

客户端配置位于 `AppData/Roaming/hanabi_download_managerx/config.json`：

```json
{
  "kernel": {
    "threads": 8,
    "max_concurrent_tasks": 3
  },
  "download": {
    "default_path": "C:/Users/xxx/Downloads",
    "enable_dynamic_segments": true
  }
}
```

---

## 贡献指南

我们欢迎各种形式的贡献！请查看 [CONTRIBUTING_CN.md](CONTRIBUTING_CN.md) 了解详细的贡献指南。

快速链接：
- [报告 Bug](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- [功能建议](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- [提交 Pull Request](https://github.com/buaoyezz/hanabi-download-manager-x/pulls)
- [添加新语言翻译](docs/ADD_NEW_LANGUAGE_CN.md)

---

## 许可证

本项目采用 GNU General Public License v3.0 开源协议。

Copyright © 2026 ZZBuAoYe

相关文档：
- [隐私政策](https://x.zzbuaoye.top/privacy)
- [服务条款](https://x.zzbuaoye.top/terms)
