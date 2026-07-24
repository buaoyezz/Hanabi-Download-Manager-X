# 运行时与 JSON-RPC

Hanabi API v1 使用“单次进程 + 单次 JSON-RPC 请求”模型。每次调用都会启动一个新进程，发送一条请求，读取一条响应，然后等待进程退出。

## 进程生命周期

```text
宿主选择插件
  -> 创建日志与数据目录
  -> 解析 executable、arguments、workingDirectory
  -> 启动进程并注入 HANABI_* 环境变量
  -> stdin 写入一条 UTF-8 JSON 请求并关闭
  <- stdout 读取响应
  <- stderr 收集诊断信息
  -> 校验退出码、JSON-RPC 版本和响应 ID
  -> 写入 runtime.log
```

插件必须在返回响应后主动退出。需要长期运行的下载引擎应作为独立后端运行，插件入口只负责轻量控制。

## 默认启动规则

未声明 `runtime.executable` 时，宿主按 `entry` 扩展名选择运行方式：

| 入口扩展名 | 命令 |
| --- | --- |
| `.py` | `python <entry> [...arguments]` |
| `.js`、`.mjs`、`.cjs` | `node <entry> [...arguments]` |
| `.ps1` | `powershell -NoProfile -ExecutionPolicy Bypass -File <entry> [...arguments]` |
| `.bat`、`.cmd` | `cmd /c <entry> [...arguments]` |
| 其他 | 直接执行 `<entry> [...arguments]` |

默认工作目录是插件根目录。

## 自定义命令

下面的清单使用 Deno 运行 TypeScript：

```json
{
  "entry": "src/main.ts",
  "runtime": {
    "executable": "deno",
    "arguments": ["run", "--allow-net", "{entry}"],
    "workingDirectory": "src",
    "timeoutSeconds": 45
  }
}
```

参数支持两个占位符：

| 占位符 | 值 |
| --- | --- |
| `{entry}` | 入口文件的规范化绝对路径。 |
| `{pluginDir}` | 插件安装目录。 |

当 `runtime.executable` 存在时：

- `arguments` 包含 `{entry}`：宿主按声明的顺序原样替换参数。
- `arguments` 不包含 `{entry}`：宿主自动把入口绝对路径放在参数最前面。

## 环境变量

每次调用都会注入以下变量：

| 变量 | 说明 |
| --- | --- |
| `HANABI_PLUGIN_ID` | 插件 ID。 |
| `HANABI_PLUGIN_DIR` | 插件安装目录。升级时内容可能被替换。 |
| `HANABI_PLUGIN_DATA_DIR` | 插件持久数据目录。升级插件不会删除。 |
| `HANABI_PLUGIN_LOG_DIR` | 插件日志目录。 |
| `HANABI_API_VERSION` | 当前插件声明的 API 版本。 |
| `HANABI_APP_VERSION` | Hanabi 应用版本。 |
| `HANABI_REQUEST_ID` | 本次 JSON-RPC 请求 ID。 |
| `HANABI_REQUEST_METHOD` | 本次调用的方法名。 |

`runtime.environment` 会先写入，随后宿主写入保留变量。因此插件不能伪造 `HANABI_*` 值，清单校验也会拒绝这类键。

## 请求

宿主发送 UTF-8 编码的 JSON 对象：

```json
{
  "jsonrpc": "2.0",
  "id": "1780000000000000",
  "method": "hanabi.download.create",
  "params": {
    "fileName": "example.zip"
  },
  "meta": {
    "apiVersion": "1.0",
    "host": {
      "name": "Hanabi Download Manager X",
      "version": "1.5.0",
      "platform": "windows"
    },
    "plugin": {
      "id": "hanabi.example.demo",
      "version": "1.2.0"
    },
    "invocation": {
      "method": "hanabi.download.create",
      "requestedAt": "2026-07-19T12:00:00.000Z",
      "timeoutMs": 30000
    },
    "paths": {
      "plugin": "C:\\...\\plugins\\installed\\hanabi.example.demo",
      "data": "C:\\...\\plugins\\data\\hanabi.example.demo",
      "logs": "C:\\...\\plugins\\logs\\hanabi.example.demo"
    }
  }
}
```

`meta` 是宿主上下文，不属于业务参数。插件应从 `params` 读取方法输入，从 `meta` 或环境变量读取运行上下文。

## 成功响应

```json
{
  "jsonrpc": "2.0",
  "id": "1780000000000000",
  "result": {
    "ok": true
  }
}
```

宿主要求最后一条非空 JSON 行满足：

- 根值是 JSON 对象；
- `jsonrpc` 若存在，必须为 `2.0`；
- `id` 若存在，必须与请求 ID 相同；
- 必须包含 `result` 或 `error`。

为了避免未来版本收紧校验，插件应始终返回完整的 `jsonrpc` 和 `id`。

## 错误响应

```json
{
  "jsonrpc": "2.0",
  "id": "1780000000000000",
  "error": {
    "code": -32602,
    "message": "intent.normalizedValue is required",
    "data": {
      "field": "intent.normalizedValue",
      "retryable": false
    }
  }
}
```

宿主保留 `error.code` 和 `error.data`，并将 `error.message` 展示或记录为主要错误。

推荐错误码：

| 错误码 | 名称 | 何时使用 |
| --- | --- | --- |
| `-32700` | Parse error | 请求 JSON 无法解析。 |
| `-32600` | Invalid Request | 请求结构错误。 |
| `-32601` | Method not found | 插件未实现该方法。 |
| `-32602` | Invalid params | 参数缺失或类型错误。 |
| `-32603` | Internal error | 未分类的插件内部错误。 |
| `-32000` 至 `-32099` | Server error | 插件自定义运行错误。 |

## 超时

`runtime.timeoutSeconds` 是未显式指定超时时的方法默认值，默认 30 秒。下载任务方法由宿主使用更具体的超时：

| 方法 | 超时 |
| --- | --- |
| `hanabi.download.create` | 清单默认值，默认 30 秒 |
| `hanabi.download.status` | 10 秒 |
| `hanabi.download.pause` | 15 秒 |
| `hanabi.download.resume` | 15 秒 |
| `hanabi.download.remove` | 15 秒 |
| UI 动作与状态变更 | 清单默认值，默认 30 秒 |

超时后宿主会终止当前插件进程并返回失败。不要在 `create` 中等待完整下载完成。

## 输出与日志

- `stdout` 仅用于 JSON-RPC 响应。
- 诊断日志写入 `stderr`。
- 长期日志写入 `HANABI_PLUGIN_LOG_DIR`。
- 宿主会把退出码、`stdout` 和 `stderr` 追加到 `runtime.log`。
- 宿主从 `stdout` 的最后一条非空 JSON 行解析响应；前面的普通输出虽然可能兼容，但不应依赖。

## 持久状态

插件进程不会跨调用保留内存状态。使用以下方式持久化：

- 任务级状态：返回 `pluginData`，宿主会随任务保存并在后续方法中传回。
- 插件级状态：写入 `HANABI_PLUGIN_DATA_DIR`。
- UI 设置：由宿主保存，并通过状态变更方法传给插件。

不要把持久文件写入 `HANABI_PLUGIN_DIR`。升级时安装目录会被替换。

## SDK

官方单文件 SDK 位于 `plugins/sdk/`，负责方法分发和错误序列化。SDK 不是运行时依赖，发布时需要随插件一起打包。
