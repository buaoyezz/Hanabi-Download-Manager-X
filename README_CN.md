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

Hanabi Download Manager X 是一个基于 Flutter 开发的跨平台下载管理器，支持双内核架构（NSFX 和 Soda），提供多线程并发下载、断点续传等功能。

### 技术栈迁移

从 Python + Flet 架构迁移至 Flutter，提升了跨平台兼容性和用户体验。

---

## 技术架构

### 前端框架
- Flutter 3.0+ - 跨平台 UI 框架
- Fluent Design - 现代化设计语言
- 响应式布局 - 适配多种屏幕尺寸

### 双内核架构
- **NSFX (Next Speed Force X)** - 新一代高性能下载内核 (v2.2.0)
- **Soda Download Kernel** - 稳定的 Python 下载内核 (v1.5.9)
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
- Python 3.12.6+
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

### 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         用户界面层 (UI Layer)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  HomeScreen  │  │ SettingsPage │  │  LogViewer   │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
└─────────┼──────────────────┼──────────────────┼─────────────────┘
          │                  │                  │
┌─────────┼──────────────────┼──────────────────┼─────────────────┐
│         │         服务层 (Service Layer)       │                 │
│  ┌──────▼──────────────────▼──────────────────▼─────────┐       │
│  │         IntegratedDownloadService (统一下载服务)       │       │
│  │  - 任务管理  - 状态同步  - 进度追踪  - 错误处理        │       │
│  └──────┬────────────────────────────────────┬──────────┘       │
│         │                                    │                  │
│  ┌──────▼──────────┐              ┌─────────▼──────────┐        │
│  │  KernelService  │              │  KernelManager     │        │
│  │  (Legacy Soda)  │              │  (双内核管理器)     │        │
│  └──────┬──────────┘              └─────────┬──────────┘        │
│         │                                    │                  │
│         │                         ┌──────────┴──────────┐       │
│         │                         │                     │       │
│         │                  ┌──────▼──────┐      ┌──────▼──────┐│
│         │                  │ SodaKernel  │      │ NsfxKernel  ││
│         │                  │  (Legacy)   │      │   (Next)    ││
│         │                  └─────────────┘      └─────────────┘│
│         │                                                       │
│  ┌──────┴───────────────────────────────────────────────┐      │
│  │              辅助服务 (Helper Services)               │      │
│  │  • NetworkStatusService    • SystemTrayService       │      │
│  │  • UpdateService           • WindowEffectService     │      │
│  │  • PipeListenerService     • PopupProgressService    │      │
│  │  • NotificationSettings    • LocalizationService     │      │
│  └───────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────┼─────────────────────────────────┐
│                    内核层 (Kernel Layer)                       │
│  ┌──────────────────────────▼──────────────────────────┐      │
│  │         Soda Download Kernel (Python)               │      │
│  │         soda_bridge_server.py (HTTP API)            │      │
│  │  • HTTP/HTTPS 协议  • 多线程下载  • 断点续传         │      │
│  │  • 动态分段算法      • 智能重试    • 速度控制         │      │
│  └─────────────────────────────────────────────────────┘      │
│  ┌──────────────────────────────────────────────────────┐     │
│  │         NSFX Kernel (Next Generation)               │      │
│  │         WebSocket + HTTP API                        │      │
│  │  • 实时进度推送      • 更高性能    • 更低延迟         │      │
│  │  • 智能分段优化      • 内存优化    • 并发控制         │      │
│  └──────────────────────────┬──────────────────────────┘      │
└─────────────────────────────┼─────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   网络层 (Network) │
                    │   HTTP/HTTPS      │
                    └───────────────────┘
```

### 服务层架构

#### 核心服务

| 服务 | 职责 | 依赖 |
|------|------|------|
| `IntegratedDownloadService` | 统一下载任务管理、状态同步、进度追踪 | KernelService, KernelManager |
| `KernelService` | Legacy Soda 内核管理 (Python) | - |
| `KernelManager` | 双内核管理器，支持动态切换 | SodaKernel, NsfxKernel |
| `SodaKernel` | Soda 内核接口实现 | - |
| `NsfxKernel` | NSFX 内核接口实现 | - |

#### 辅助服务

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

### 数据流

```
用户操作 → UI 组件 → IntegratedDownloadService
                              ↓
                    读取配置 (kernel.use_new_kernel)
                              ↓
              ┌───────────────┴───────────────┐
              ↓                               ↓
      KernelManager                   KernelService (Legacy)
      (NsfxKernel/SodaKernel)                ↓
              ↓                          HTTP API (9710)
         WebSocket + HTTP API                ↓
              ↓                          Python 内核
         实时进度推送                         ↓
              ↓                          轮询更新
              ↓                               ↓
         进度回调 ←──────────────────────────┘
              ↓
    IntegratedDownloadService (状态更新)
              ↓
         UI 更新 (进度条、速度、状态)
```

---

## 内核协议

### 双内核架构说明

Hanabi 支持两种下载内核，可在设置中动态切换：

1. **Soda Download Kernel (Legacy)** - Python 实现，稳定可靠
2. **NSFX Kernel (Next Generation)** - 新一代内核，性能更优

两种内核都通过 **HTTP REST API** 进行通信，NSFX 额外支持 **WebSocket** 实时推送。

### Soda 内核通信协议 (端口 9710)

#### 1. REST API 端点

所有内核共享相同的 API 接口设计，确保无缝切换。

##### 1.1 添加下载任务

```http
POST /download/add
Content-Type: application/json

{
  "url": "https://example.com/file.zip",
  "filename": "file.zip",
  "save_path": "C:/Downloads",
  "threads": 8,
  "headers": {
    "User-Agent": "Hanabi/1.0"
  }
}
```

响应：
```json
{
  "success": true,
  "data": {
    "id": "uuid-string"
  }
}
```

##### 1.2 暂停/恢复/取消任务

```http
POST /download/pause
POST /download/resume
POST /download/cancel
Content-Type: application/json

{
  "id": "task-id"
}
```

##### 1.3 获取任务列表

```http
GET /download/tasks
```

响应：
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid-string",
      "url": "https://example.com/file.zip",
      "filename": "file.zip",
      "filepath": "C:/Downloads/file.zip",
      "status": "downloading",
      "progress": 45.5,
      "speed": 1048576,
      "downloadedSize": 47185920,
      "totalSize": 104857600,
      "threadCount": 8,
      "segments": [...]
    }
  ]
}
```

##### 1.4 配置管理

```http
GET /settings/download-config
POST /settings/download-config
Content-Type: application/json

{
  "threads": 8,
  "segments": 8,
  "mode": "auto",
  "max_concurrent_tasks": 3,
  "segment_speed_limit": 0,
  "enable_dynamic_segments": true,
  "proxy": {
    "enabled": false,
    "type": "http",
    "host": "",
    "port": 8080
  }
}
```

#### 2. NSFX 内核特性 (WebSocket 推送)

NSFX 内核在 Soda 基础上增加了 WebSocket 实时推送功能：

```
连接地址：ws://localhost:9710/ws/progress
```

推送消息格式：
```json
{
  "type": "progress",
  "task": {
    "id": "uuid-string",
    "progress": 45.5,
    "speed": 1048576,
    "downloadedSize": 47185920,
    "totalSize": 104857600
  }
}
```

#### 3. 内核启动流程

##### Soda 内核 (Legacy)

1. 检查 Python 环境
2. 启动 `soda_bridge_server.py` (开发模式) 或 `soda_bridge_server.exe` (生产模式)
3. 监听端口 9710
4. 健康检查：`GET /health`

##### NSFX 内核 (Next)

1. 通过 KernelManager 启动
2. 建立 WebSocket 连接
3. 订阅进度和完成事件流
4. 实时推送更新到 UI

#### 4. 断点续传机制

两种内核都使用 HTTP Range 请求实现断点续传：

1. **HEAD 请求**获取文件大小和是否支持 Range
2. **动态分段**：根据文件大小和线程数计算分段
3. **并发下载**：每个分段独立下载
4. **进度持久化**：保存到本地数据库
5. **智能重试**：失败分段自动重试
6. **文件合并**：所有分段完成后合并

#### 5. 配置文件

客户端配置位于 `AppData/Roaming/hanabi_download_managerx/config.json`：

```json
{
  "kernel": {
    "use_new_kernel": true,
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
