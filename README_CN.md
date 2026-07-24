<div align="left">

# Hanabi Download Manager X
[![Release](https://img.shields.io/github/v/release/buaoyezz/Hanabi-Download-Manager-X?label=Release&style=flat-square&color=orange)](https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases)
![Downloads](https://img.shields.io/github/downloads/buaoyezz/Hanabi-Download-Manager-X/total?label=Downloads&style=flat-square&color=gold)
[![Website](https://img.shields.io/badge/Website-x.zzbuaoye.net-2ea44f?style=for-the-badge)](https://x.zzbuaoye.net)
[![Notice](https://img.shields.io/badge/Notice-Web%20Notices-0ea5e9?style=for-the-badge)](https://x.zzbuaoye.net/web-notices.html)
[![Releases](https://img.shields.io/badge/Releases-GitHub-orange?style=for-the-badge&logo=github)](https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases)
[![Docs](https://img.shields.io/badge/Docs-Menu-7c3aed?style=for-the-badge)](docs/Menu.md)
[![Homepage](https://img.shields.io/badge/Homepage-zzbuaoye.net-blue?style=for-the-badge)](https://zzbuaoye.net)

中文 | [English](README.md)

</div>

![Preview](readme_assets/image1.png)

## 简介

Hanabi Download Manager X 是一个使用 Flutter 构建的桌面下载管理器，重点关注多线程下载、断点续传、清晰的任务状态展示和现代化 Windows 桌面体验

> [!NOTE]
> + 当前项目主要面向 Windows 10/11(其他系统暂无适配预期)圆角、窗口效果和托盘行为都围绕 Windows 桌面环境做了适配
> + 但是由于Win11和Win10有些API差异，可能存在一些异常，反馈到issue就行

> [!IMPORTANT]
> + 本项目有大量 AI 参与开发，并且相当一部分代码由 AI 协助完成,如果遇到比较好笑的质量问题，请直接提 Issue 感谢,`无法接受的请勿使用`
>
> + 由于个人时间有限，不建议直接提交 PR；更推荐通过 Issue 反馈问题和建议

## 快速开始

### 环境要求

- Flutter SDK 3.0.0+
- Windows 10/11
- Git

### 运行项目

```bash
git clone https://github.com/buaoyezz/hanabi-download-manager-x.git
cd hanabi-download-manager-x
flutter pub get
flutter run
```

### 同步本地化

```bash
dart run tool/sync_l10n.dart
```

`app_en.arb` 可以从 `app_zh.arb` 自动同步；Windows 运行和构建脚本也会在启动前自动执行这一步，但是极度`不推荐`使用，这个机翻很不准，参考性很低

## 构建

推荐使用发布脚本：

```bash
build_release.bat
```

也可以直接使用 Flutter 构建：

```bash
flutter build windows --release
```

> [!TIP]
> 如果只是快速打包正式版，优先使用 `build_release.bat`<br>它会处理本项目额外的 Windows 构建步骤和资源复制

## 文档 DOCS

| 分类 | 文档 |
| --- | --- |
| 总目录 | [文档目录](docs/Menu.md) |
| 插件 | [插件开发文档](docs/plugin/README_CN.md) |
| 插件 | [快速开始](docs/plugin/QUICKSTART_CN.md) |
| 插件 | [插件 API 参考](docs/plugin/PLUGIN_API_CN.md) |
| 插件 | [发布与市场](docs/plugin/PLUGIN_PUBLISH_FLOW_CN.md) |
| 插件 | [安全模型](docs/plugin/SECURITY_CN.md) |
| 开发 | [添加新语言](docs/i18n/ADD_NEW_LANGUAGE_CN.md) |
| 开发 | [更新器构建](docs/UPDATER_BUILD_CN.md) |
| 开发 | [常见问题](docs/faq/FAQ.md) |

## 链接

| 入口 | 地址 |
| --- | --- |
| 官方网站 | [x.zzbuaoye.net](https://x.zzbuaoye.net) |
| 项目公告 | [Web Notices](https://x.zzbuaoye.net/web-notices.html) |
| 版本发布 | [GitHub Releases](https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases) |
| 问题反馈 | [GitHub Issues](https://github.com/buaoyezz/hanabi-download-manager-x/issues) |
| 功能建议 | [GitHub Issues](https://github.com/buaoyezz/hanabi-download-manager-x/issues) |
| 隐私政策 | [Privacy Policy](https://x.zzbuaoye.net/privacy) |
| 服务条款 | [Terms of Service](https://x.zzbuaoye.net/terms) |
| 个人主页 | [zzbuaoye.net](https://zzbuaoye.net) |

## 许可证

本项目采用双重授权协议：

- **核心应用**：[GNU General Public License v3.0](LICENSE)
- **插件和 SDK（`plugins/` 目录）**：[MIT License](plugins/LICENSE)
>[!IMPORTANT]
> + 只要使用的是提供的 MIT 协议插件 API<br>你可以自由开发开源或闭源插件<br>`不会受` GPLv3 传染性要求影响

Copyright © 2026 [ZZBuAoYe](https://zzbuaoye.net)
