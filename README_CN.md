# Hanabi Download Manager X

[English](README.md) | 中文
> [!NOTE]
> Hanabi Download Manager X 
> 一个现代化下载解决方案

> [!important]
> 再次明确声明
> - 本项目有AI参与
> - 并且很大一部分由AI参与共同完成
> - 若存在比较好笑的质量问题也请见谅
>  本README是人写的XD
> + `不建议`给本项目`提交PR`，有问题建议提交`ISSUE`，因为生活繁忙我没空合并
> + [官网地址](https://x.zzbuaoye.top) | [NOTICE](https://x.zzbuaoye.top/web-notices.html) | [RELEASE](https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases) | [开发文档](docs/Menu.md)

![Preview](readme_assets/image1.png)

---

## 快速开始
> [!important]
> 环境要求
> - Flutter SDK 3.0.0+
> - Windows 10/11
> - 本项目圆角和窗口效果对Win10/11都有适配

### 运行

```bash
git clone https://github.com/buaoyezz/hanabi-download-manager-x.git
cd hanabi-download-manager-x
flutter pub get
flutter run
```

```bash
dart run tool/sync_l10n.dart
```

> `app_en.arb` 现在可以从 `app_zh.arb` 自动同步；Windows 运行/构建脚本也会在启动前自动执行这一步 (为了方便我懒得改Eng arb)

> [!TIP]
> 其实可使用 `build_release.bat` 快速构建
> 注意`rhttp`可能存在的编译失败问题

## 构建

##### 自动化脚本:
```bash
build_release.bat 
```
##### 常规编译:

```bash
flutter build windows --release
```
> 这两个没有本质上的区别，按需选择，脚本之前是为了更方便打包内核和下载器本体，现在下载器和内核都是flutter了，可以直接指令编译
---

## DOCS
**[I目录](docs/Menu.md)**
#### 插件

- [插件市场设计方案](docs/plugin/PLUGIN_MARKET_DESIGN_CN.md)
- [插件 API 文档](docs/plugin/PLUGIN_API_CN.md)
- [插件发布流程](docs/plugin/PLUGIN_PUBLISH_FLOW_CN.md)
- [插件商店签名方案](docs/plugin/PLUGIN_STORE_SIGNATURE_CN.md)

#### 开发

- [添加新语言](docs/i18n/ADD_NEW_LANGUAGE_CN.md)
- [更新器构建](docs/UPDATER_BUILD_CN.md)
- [常见问题](docs/faq/FAQ.md)
## LINK
- [报告 Bug](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- [功能建议](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- [隐私政策](https://x.zzbuaoye.top/privacy)
- [服务条款](https://x.zzbuaoye.top/terms)
- [官方网站](https://x.zzbuaoye.top)
---

## 许可证

本项目采用双重授权协议：

- **核心应用**：[GNU General Public License v3.0](LICENSE)。
- **插件和 SDK（`plugins/` 目录）**：[MIT License](plugins/LICENSE)。

这意味着，只要您使用的是提供的采用 MIT 协议的插件 API，您就可以自由地为 Hanabi Download Manager X 开发开源或闭源（商业）插件，而不会受制于 GPLv3 的传染性要求。

Copyright © 2026 [ZZBuAoYe](https://github.com/buaoyezz/)
