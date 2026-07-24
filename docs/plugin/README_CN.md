# Hanabi 插件开发文档

使用进程隔离的 JSON-RPC API，为 Hanabi Download Manager X 扩展下载协议、任务后端、设置面板、侧边栏页面和主题能力。

> [!NOTE]
> 当前稳定协议为 `manifestVersion: 1`、`apiVersion: "1.0"`。未声明这两个字段的旧插件会按 v1 解析。

## 开始使用

| 目标 | 文档 |
| --- | --- |
| 在 10 分钟内运行第一个插件 | [快速开始](QUICKSTART_CN.md) |
| 配置插件清单、能力和路由 | [清单参考](MANIFEST_REFERENCE_CN.md) |
| 了解进程启动和 JSON-RPC 协议 | [运行时与 JSON-RPC](RUNTIME_AND_RPC_CN.md) |
| 实现下载任务 | [下载 API](DOWNLOAD_API_CN.md) |
| 添加设置页或侧边栏 | [UI 扩展](UI_EXTENSIONS_CN.md) |
| 打包并部署到插件市场 | [发布指南](PLUGIN_PUBLISH_FLOW_CN.md) |
| 评估权限、签名和信任边界 | [安全模型](SECURITY_CN.md) |

## 插件模型

Hanabi 插件是包含 `plugin.json` 和入口文件的独立目录。宿主按需启动入口进程，通过标准输入发送一条 JSON-RPC 请求，并从标准输出读取一条响应。每次调用结束后，插件进程应退出。

```text
Hanabi
  -> 解析 plugin.json
  -> 按 capability 和 URI scheme 选择插件
  -> 启动插件进程
  -> stdin 发送 JSON-RPC 请求
  <- stdout 返回 JSON-RPC 响应
  -> 持久化任务状态和插件设置
```

这种模型允许插件使用 Python、Node.js、PowerShell、原生可执行文件或自定义运行时，不要求插件与 Flutter 使用同一种语言。

## 能力概览

| 扩展面 | 稳定性 | 说明 |
| --- | --- | --- |
| 下载意图与任务后端 | 稳定 | 支持磁力链接、Torrent、ED2K 文件链接、本地解析器和自定义 URI。 |
| 声明式设置页 | 稳定 | 宿主渲染开关、输入框、按钮、滑块和下拉框。 |
| 声明式侧边栏 | 稳定 | 插件可贡献一个宿主渲染的侧边栏页面。 |
| 自定义运行时 | 稳定 | 可声明命令、参数、环境变量、工作目录和超时。 |
| 商店哈希与 Ed25519 签名 | 稳定 | 安装前验证包完整性与发布来源。 |
| 主题颜色覆盖 | 实验性 | 当前仅支持 `colors.primary`，且同一时间只应用一个提供者。 |

## 版本与兼容性

- `manifestVersion` 控制 `plugin.json` 的结构。目前只支持主版本 `1`。
- `apiVersion` 控制宿主与插件之间的 JSON-RPC 契约。目前支持 `1.x`。
- `minAppVersion` 和 `maxAppVersion` 限定可运行的 Hanabi 版本。
- 新增的可选字段会保持向后兼容；不兼容变更会提升清单或 API 主版本。

## 运行时边界

插件进程以当前用户权限运行，当前版本不提供操作系统级沙箱。`permissions` 是展示与审核声明，不是权限强制器。只安装可信来源的插件，并在发布前阅读[安全模型](SECURITY_CN.md)。

## 开发工具

仓库提供以下工具：

| 工具 | 路径 | 用途 |
| --- | --- | --- |
| JSON Schema | `plugins/schema/plugin-manifest.schema.json` | 编辑器补全与静态校验。 |
| 校验命令 | `tool/validate_plugin.dart` | 检查清单、入口、路径和运行时。 |
| 打包命令 | `scripts/package-plugin.ps1` | 生成插件包、SHA-256 和商店条目。 |
| Python SDK | `plugins/sdk/python/hanabi_plugin.py` | 零依赖 JSON-RPC 分发器。 |
| JavaScript SDK | `plugins/sdk/javascript/hanabi-plugin.mjs` | Node.js ESM JSON-RPC 分发器。 |

## 获取帮助

- 查看[故障排查](TROUBLESHOOTING_CN.md)。
- 使用运行日志：`<Hanabi 数据目录>/plugins/logs/<pluginId>/runtime.log`。
- 提交问题时附上 `plugin.json`、最小复现请求、运行日志和 Hanabi 版本。

## 官方实现

- [Hanabi BitTorrent](../../plugins/official/bittorrent/README_CN.md)：磁力链接与 `.torrent` 文件下载。
- [Hanabi ED2K](../../plugins/official/ed2k/README_CN.md)：ED2K 文件链接下载。
