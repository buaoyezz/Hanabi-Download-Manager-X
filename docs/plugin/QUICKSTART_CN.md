# 快速开始

本指南使用 Python 创建一个处理 `hanabi+demo://` URI 的最小插件。完成后，你将能校验、手动调用并打包插件。

## 前置条件

- Windows 10 或 Windows 11
- Hanabi Download Manager X 1.5.0 或更高版本
- Python 3.10 或更高版本
- Flutter/Dart SDK，仅校验和仓库内打包时需要

## 1. 创建目录

```text
hanabi-demo/
  plugin.json
  main.py
  hanabi_plugin.py
```

从仓库的 `plugins/sdk/python/hanabi_plugin.py` 复制 SDK 文件到插件目录。SDK 是单文件、零依赖实现，必须和插件一起打包。

## 2. 编写清单

创建 `plugin.json`：

```json
{
  "$schema": "https://x.zzbuaoye.net/schemas/hanabi/plugin-manifest-v1.schema.json",
  "manifestVersion": 1,
  "apiVersion": "1.0",
  "id": "hanabi.example.demo",
  "name": "Demo 协议插件",
  "version": "0.1.0",
  "author": "Your Name",
  "description": "处理 hanabi+demo 自定义下载链接。",
  "entry": "main.py",
  "license": "MIT",
  "capabilities": ["download:custom:demo"],
  "intentSchemes": ["hanabi+demo"],
  "permissions": []
}
```

`download:custom:demo` 和 `intentSchemes` 让 Hanabi 在多个自定义协议插件之间进行精确路由。

## 3. 实现入口

创建 `main.py`：

```python
import time

from hanabi_plugin import HanabiPlugin, JsonRpcError


plugin = HanabiPlugin()


@plugin.method("hanabi.download.create")
def create_download(params, context):
    intent = params.get("intent") or {}
    value = intent.get("normalizedValue")
    if not value:
        raise JsonRpcError(-32602, "intent.normalizedValue is required")

    task_id = f"plugin:{context.plugin_id}:{int(time.time() * 1000)}"
    return {
        "accepted": True,
        "taskId": task_id,
        "status": "completed",
        "fileName": params.get("fileName") or "demo-result.txt",
        "progress": 1.0,
        "pluginData": {"source": value},
    }


@plugin.method("hanabi.download.status")
def download_status(params, context):
    return {
        "status": "completed",
        "progress": 1.0,
        "pluginData": params.get("pluginData") or {},
    }


@plugin.method("hanabi.download.pause")
def pause_download(params, context):
    return {"status": "paused"}


@plugin.method("hanabi.download.resume")
def resume_download(params, context):
    return {"status": "completed", "progress": 1.0}


@plugin.method("hanabi.download.remove")
def remove_download(params, context):
    return {"status": "removed"}


if __name__ == "__main__":
    raise SystemExit(plugin.run())
```

## 4. 校验插件

在 Hanabi 仓库根目录运行：

```powershell
dart run tool/validate_plugin.dart C:\path\to\hanabi-demo
```

用于 CI 时可以获取结构化结果：

```powershell
dart run tool/validate_plugin.dart C:\path\to\hanabi-demo --json
```

校验器会检查：

- 清单版本、ID、能力和 UI 结构；
- 入口、图标、工作目录和插件内运行文件；
- 目录穿越与保留环境变量覆盖；
- 推荐的许可证、仓库和描述元数据。

## 5. 手动调用

PowerShell 示例：

```powershell
'{"jsonrpc":"2.0","id":"1","method":"hanabi.download.create","params":{"intent":{"normalizedValue":"hanabi+demo://hello","type":"custom"},"fileName":"hello.txt"}}' |
  python .\main.py
```

预期响应包含：

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {
    "accepted": true,
    "taskId": "plugin:hanabi.example.demo:...",
    "status": "completed",
    "progress": 1.0
  }
}
```

## 6. 安装和调试

在 Hanabi 的插件页面选择本地目录进行安装。插件默认会被启用，然后可以提交：

```text
hanabi+demo://hello?plugin=hanabi.example.demo
```

宿主运行日志位于：

```text
<Hanabi 数据目录>/plugins/logs/hanabi.example.demo/runtime.log
```

插件持久数据目录位于：

```text
<Hanabi 数据目录>/plugins/data/hanabi.example.demo/
```

## 7. 打包

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-plugin.ps1 `
  -PluginDir C:\path\to\hanabi-demo `
  -BaseDownloadUrl https://plugins.example.com/packages
```

命令会再次校验插件，并输出 `.hanabi-plugin.zip`、SHA-256 和可放入商店索引的 JSON 条目。

## 下一步

- 阅读[清单参考](MANIFEST_REFERENCE_CN.md)，配置兼容性、自定义运行时和路由。
- 阅读[下载 API](DOWNLOAD_API_CN.md)，正确实现长时间下载任务。
- 阅读[发布指南](PLUGIN_PUBLISH_FLOW_CN.md)，部署插件包与商店索引。
