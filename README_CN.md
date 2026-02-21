# Hanabi Download Manager X

[English](README.md) | 中文

![Preview](readme_assets/image1.png)

## 目录

- [项目简介](#项目简介)
- [技术架构](#技术架构)
- [核心特性](#核心特性)
- [快速开始](#快速开始)
- [许可证](#许可证)

---

## 项目简介

Hanabi Download Manager X 是一个基于 Flutter 开发的跨平台下载管理器，采用 NSFX 下载内核，提供多线程并发下载、断点续传等功能。

### 技术栈迁移

从 Python + Flet 架构迁移至 Flutter，提升了跨平台兼容性和用户体验。

---

## 技术架构

### 前端框架
- Flutter 3.0+ - 跨平台 UI 框架
- Fluent Design - 现代化设计语言
- 响应式布局 - 适配多种屏幕尺寸

### 下载引擎
- NSFX 内核 - 自研下载核心
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

## 许可证

本项目采用 GNU General Public License v3.0 开源协议。

Copyright © 2026 ZZBuAoYe

相关文档：
- [隐私政策](https://x.zzbuaoye.top/privacy)
- [服务条款](https://x.zzbuaoye.top/terms)
