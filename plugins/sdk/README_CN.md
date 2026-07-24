# Hanabi 插件 SDK

这里提供两个零依赖、单文件 SDK，用于处理 Hanabi API v1 的 JSON-RPC 协议外壳：

- `python/hanabi_plugin.py`：支持 Python 3.10 及以上版本。
- `javascript/hanabi-plugin.mjs`：支持 Node.js 18 及以上版本。

SDK 不需要安装。发布插件时，把对应文件复制到插件目录并随插件一起打包。

## Python

```python
from hanabi_plugin import HanabiPlugin

plugin = HanabiPlugin()


@plugin.method("hanabi.download.create")
def create(params, context):
    return {
        "accepted": True,
        "taskId": f"plugin:{context.plugin_id}:demo-1",
        "status": "pending",
    }


if __name__ == "__main__":
    raise SystemExit(plugin.run())
```

## JavaScript

```javascript
import { HanabiPlugin } from "./hanabi-plugin.mjs";

const plugin = new HanabiPlugin();

plugin.register("hanabi.download.create", async (params, context) => ({
  accepted: true,
  taskId: `plugin:${context.pluginId}:demo-1`,
  status: "pending",
}));

process.exitCode = await plugin.run();
```

业务日志必须写入 `stderr` 或 `HANABI_PLUGIN_LOG_DIR` 下的文件。`stdout` 由 SDK 专门用于 JSON-RPC 响应。
