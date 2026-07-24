# 插件 API 参考

本页是 Hanabi 插件 API v1 的参考入口。协议细节按主题拆分，便于开发和版本维护。

> [!NOTE]
> 稳定版本：`manifestVersion: 1`、`apiVersion: "1.0"`。旧清单未声明版本时按这两个值处理。

## 参考导航

| 主题 | 文档 |
| --- | --- |
| 清单字段、能力、路由和权限 | [插件清单参考](MANIFEST_REFERENCE_CN.md) |
| 进程命令、环境变量和 JSON-RPC | [运行时与 JSON-RPC](RUNTIME_AND_RPC_CN.md) |
| 创建、查询和控制下载任务 | [下载 API](DOWNLOAD_API_CN.md) |
| 设置页、侧边栏和主题 | [UI 扩展](UI_EXTENSIONS_CN.md) |
| 商店索引、打包和部署 | [发布指南](PLUGIN_PUBLISH_FLOW_CN.md) |
| 哈希、签名与运行权限 | [安全模型](SECURITY_CN.md) |

## 基础协议

Hanabi 启动插件入口进程，通过 `stdin` 发送一条 UTF-8 JSON-RPC 请求，并从 `stdout` 最后一条非空 JSON 行读取响应。

请求：

```json
{
  "jsonrpc": "2.0",
  "id": "1780000000000000",
  "method": "hanabi.download.status",
  "params": {},
  "meta": {
    "apiVersion": "1.0",
    "host": {},
    "plugin": {},
    "invocation": {},
    "paths": {}
  }
}
```

成功响应：

```json
{
  "jsonrpc": "2.0",
  "id": "1780000000000000",
  "result": {}
}
```

错误响应：

```json
{
  "jsonrpc": "2.0",
  "id": "1780000000000000",
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": {}
  }
}
```

## 宿主方法

| 方法 | 调用方 | 说明 |
| --- | --- | --- |
| `hanabi.download.create` | Hanabi | 创建下载任务。 |
| `hanabi.download.status` | Hanabi | 刷新任务状态。 |
| `hanabi.download.pause` | Hanabi | 暂停任务。 |
| `hanabi.download.resume` | Hanabi | 恢复任务。 |
| `hanabi.download.remove` | Hanabi | 移除任务。 |
| `onSettingsChanged` | Hanabi UI | 设置页完整状态发生变化。 |
| `onSidebarStateChanged` | Hanabi UI | 侧边栏完整状态发生变化。 |
| 清单中的自定义 `action` | Hanabi UI | 用户点击声明式按钮。 |

`hanabi.*` 是宿主保留命名空间。插件私有动作应使用自己的命名空间。

## 兼容别名

宿主为早期插件保留少量字段别名：

| 标准字段 | 兼容字段 |
| --- | --- |
| `taskId` | `task_id` |
| `filePath` | `file_path` |
| `totalSize` | `total_size` |
| `downloadedSize` | `downloaded_size` |
| `speed` | `downloadSpeed`、`download_speed` |
| `pluginData` | `plugin_data` |
| `ui_extensions` | `uiExtensions` |
| `theme_overrides` | `themeOverrides` |

新插件应只写标准字段。别名用于读取兼容，不代表长期推荐格式。

## 版本策略

- 增加可选字段或新方法：保持 API 主版本不变。
- 改变已有字段含义、删除字段或收紧必需行为：提升 API 主版本。
- 改变 `plugin.json` 结构且无法向后兼容：提升 `manifestVersion`。
- API v1 插件应忽略未知请求字段，并允许 `pluginData` 中存在旧版本键。

## SDK 与 Schema

- Python SDK：`plugins/sdk/python/hanabi_plugin.py`
- JavaScript SDK：`plugins/sdk/javascript/hanabi-plugin.mjs`
- JSON Schema：`plugins/schema/plugin-manifest.schema.json`
- 校验器：`dart run tool/validate_plugin.dart <插件目录>`

首次开发建议从[快速开始](QUICKSTART_CN.md)开始。
