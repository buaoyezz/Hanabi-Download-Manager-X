# Hanabi 插件 API 文档（中文版）

本文档描述 Hanabi Download Manager X 当前实现中的插件接口，面向插件作者和插件市场维护者。

当前插件模型是“外部进程 + JSON-RPC”：

- 插件是一个独立目录，目录内必须有 `plugin.json`。
- 宿主安装插件后，会在需要时启动插件入口进程。
- 宿主通过标准输入发送一条 JSON-RPC 请求。
- 插件通过标准输出返回一条 JSON-RPC 响应。
- 下载类插件需要返回任务 ID，并实现状态查询、暂停、恢复、移除等方法。

> 说明：本文档按当前源码实现编写。`permissions`、`theme_overrides` 等字段已经能被解析，但并不都具备完整的运行时强制隔离或主题应用能力。插件作者应按本文约定声明，宿主后续可以在不破坏 manifest 的前提下增强运行时校验。

## 1. 插件目录结构

最小插件目录：

```text
my_plugin/
  plugin.json
  main.py
```

带资源文件的插件：

```text
my_plugin/
  plugin.json
  main.py
  assets/
  README.md
```

插件包可以是：

- `.zip`
- `.hanabi-plugin`
- `.hanabi-plugin.zip`

安装器会在包根目录或包内唯一一层子目录中查找 `plugin.json`。

## 2. plugin.json

最小示例：

```json
{
  "id": "hanabi.example.demo",
  "name": "Demo Plugin",
  "version": "0.1.0",
  "author": "Your Name",
  "description": "Describe what this plugin does.",
  "entry": "main.py",
  "capabilities": ["download:custom"],
  "permissions": ["network"],
  "minAppVersion": "1.3.2"
}
```

字段说明：

| 字段 | 必填 | 类型 | 说明 |
| --- | --- | --- | --- |
| `id` | 是 | string | 插件唯一 ID。必须匹配 `^[a-z0-9][a-z0-9._-]{1,62}$`。 |
| `name` | 是 | string | 展示名称。 |
| `version` | 是 | string | 插件版本。建议使用 `x.y.z`。 |
| `author` | 是 | string | 作者名称。 |
| `entry` | 是 | string | 入口文件或可执行文件路径，相对于插件目录。 |
| `capabilities` | 是 | string[] | 插件能力声明，用于宿主匹配下载意图和市场展示。 |
| `description` | 否 | string | 插件说明。 |
| `category` | 否 | string | 分类，默认 `other`。 |
| `minAppVersion` | 否 | string | 最低 Hanabi 版本。当前按数字段比较。 |
| `permissions` | 否 | string[] 或 object | 权限声明。当前主要用于展示、审核和未来安全策略。 |
| `theme_overrides` | 否 | object | 主题覆盖保留字段。当前 manifest 会解析，宿主不会自动完整应用。 |
| `ui_extensions` | 否 | object | 插件设置页、侧边栏等 UI 扩展声明。 |

`permissions` 支持的名称：

| 权限 | 说明 |
| --- | --- |
| `network` | 插件需要访问网络。 |
| `file_write` | 插件需要写入文件。 |
| `system_command` | 插件需要调用系统命令或外部程序。 |

`permissions` 也可以写成对象：

```json
{
  "permissions": {
    "network": true,
    "file_write": true,
    "system_command": false
  }
}
```

## 3. 入口文件运行规则

宿主会根据 `entry` 的扩展名选择启动方式：

| 扩展名 | 启动方式 |
| --- | --- |
| `.py` | `python <entry>` |
| `.js` / `.mjs` / `.cjs` | `node <entry>` |
| `.ps1` | `powershell -NoProfile -ExecutionPolicy Bypass -File <entry>` |
| `.bat` / `.cmd` | `cmd /c <entry>` |
| 其他 | 直接把 `entry` 当作可执行文件启动 |

每次调用插件方法时，宿主都会启动一次插件进程。插件进程应在处理完请求后退出。

如果插件需要长期运行的后端，例如 aria2 RPC、独立下载器、代理服务，应由插件自己启动或连接该后端，然后在 JSON-RPC 方法中做轻量控制。

宿主传入的环境变量：

| 变量 | 说明 |
| --- | --- |
| `HANABI_PLUGIN_ID` | 当前插件 ID。 |
| `HANABI_PLUGIN_DIR` | 当前插件安装目录。 |
| `HANABI_PLUGIN_LOG_DIR` | 当前插件日志目录。 |

日志建议写入 `stderr` 或插件自己的日志文件。宿主会从 `stdout` 的最后一条非空 JSON 行解析响应，所以不要把普通日志作为最后一行输出到 `stdout`。

## 4. JSON-RPC 通信协议

请求格式：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000000",
  "method": "hanabi.download.create",
  "params": {}
}
```

成功响应：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000000",
  "result": {
    "taskId": "plugin:hanabi.example.demo:task-1"
  }
}
```

失败响应：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000000",
  "error": {
    "code": -32000,
    "message": "Unsupported intent type"
  }
}
```

宿主当前只读取响应中的 `result` 或 `error.message`。`code` 可以保留，方便后续扩展。

当前默认超时：

| 方法 | 超时 |
| --- | --- |
| `hanabi.download.create` | 30 秒 |
| `hanabi.download.status` | 10 秒 |
| `hanabi.download.pause` | 15 秒 |
| `hanabi.download.resume` | 15 秒 |
| `hanabi.download.remove` | 15 秒 |

插件 UI 动作和设置变更使用默认 30 秒超时。

## 5. 下载意图与能力匹配

Hanabi 会先把用户输入解析成 `DownloadIntent`。

当前意图类型：

| 类型 | 来源示例 | 说明 |
| --- | --- | --- |
| `http` | `https://example.com/a.zip` | 内置 HTTP 下载器优先处理。 |
| `magnet` | `magnet:?xt=urn:btih:...` | 交给声明对应能力的插件。 |
| `torrent_file` | `D:\test\a.torrent` 或 `file:///D:/test/a.torrent` | 交给声明对应能力的插件。 |
| `resolver` | `resolver://...` 或 `hanabi-resolver://...` | 解析器类插件。 |
| `custom` | `hanabi+xxx://...` 或 `plugin+xxx://...` | 自定义协议插件。 |

能力匹配规则：

| 意图类型 | 可匹配能力 |
| --- | --- |
| `http` | `download:http`、`intent:http`，但当前内置 HTTP 处理器优先。 |
| `magnet` | `download:magnet`、`intent:magnet` |
| `torrent_file` | `download:torrent_file`、`intent:torrent_file` |
| `resolver` | `resolver`、`intent:resolver` |
| `custom` | `custom`、`intent:custom`、`download:custom` |

插件选择规则：

1. 只选择已启用且状态正常的插件。
2. 插件必须声明对应 `capabilities`。
3. 如果意图里带有 `plugin` 或 `pluginHint`，优先匹配插件 `id` 或 `name`。
4. 没有 hint 时，使用第一个匹配插件。

自定义 URI 示例：

```text
hanabi+demo://open?name=test&plugin=hanabi.example.demo
plugin+demo://download?filename=a.bin&pluginHint=hanabi.example.demo
```

## 6. 下载插件方法

### 6.1 hanabi.download.create

创建下载任务。

宿主请求：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000000",
  "method": "hanabi.download.create",
  "params": {
    "intent": {
      "rawValue": "magnet:?xt=urn:btih:...",
      "normalizedValue": "magnet:?xt=urn:btih:...",
      "type": "magnet",
      "uri": "magnet:?xt=urn:btih:..."
    },
    "fileName": "Ubuntu ISO",
    "referer": "https://example.com",
    "userAgent": "Hanabi/1.0",
    "cookies": "a=b",
    "headers": {
      "X-Token": "demo"
    },
    "saveDir": "D:\\Downloads",
    "startPaused": false
  }
}
```

`params` 字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `intent` | object | 下载意图。 |
| `fileName` | string | 宿主建议的文件名。 |
| `referer` | string | 可选来源页。 |
| `userAgent` | string | 可选 UA。 |
| `cookies` | string | 可选 Cookie 字符串。 |
| `headers` | object | 可选请求头。 |
| `saveDir` | string | 可选保存目录。 |
| `startPaused` | boolean | 是否以暂停状态创建。插件应尽量支持。 |

插件成功响应：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000000",
  "result": {
    "accepted": true,
    "taskId": "plugin:hanabi.example.magnet_torrent:2089b05ecca3d829",
    "status": "pending",
    "fileName": "Ubuntu ISO",
    "pluginData": {
      "gid": "2089b05ecca3d829"
    }
  }
}
```

`taskId` 也可以写成 `task_id`。如果插件不返回任务 ID，宿主会生成一个 `plugin:<pluginId>:<timestamp>` 格式的 ID。

建议始终返回稳定 `taskId`，并把插件后端需要的内部 ID 放进 `pluginData`。

### 6.2 hanabi.download.status

刷新任务状态。

宿主请求：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000001",
  "method": "hanabi.download.status",
  "params": {
    "taskId": "plugin:hanabi.example.demo:task-1",
    "pluginId": "hanabi.example.demo",
    "url": "magnet:?xt=urn:btih:...",
    "fileName": "Ubuntu ISO",
    "saveDir": "D:\\Downloads",
    "filePath": "D:\\Downloads\\ubuntu.iso",
    "pluginData": {
      "gid": "2089b05ecca3d829"
    }
  }
}
```

插件响应：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000001",
  "result": {
    "status": "downloading",
    "totalSize": 5368709120,
    "downloadedSize": 2684354560,
    "speed": 10485760,
    "progress": 0.5,
    "filePath": "D:\\Downloads\\ubuntu.iso",
    "pluginData": {
      "gid": "2089b05ecca3d829"
    }
  }
}
```

可返回字段：

| 字段 | 兼容别名 | 说明 |
| --- | --- | --- |
| `status` | 无 | 任务状态。 |
| `filePath` | `file_path` | 文件路径。 |
| `error` | 无 | 错误信息。 |
| `totalSize` | `total_size` | 总大小，字节。 |
| `downloadedSize` | `downloaded_size` | 已下载大小，字节。 |
| `speed` | `downloadSpeed`、`download_speed` | 下载速度，字节/秒。 |
| `progress` | 无 | 进度，`0.0` 到 `1.0`。如果大于 `1`，宿主会按百分比除以 `100`。 |
| `pluginData` | `plugin_data` | 插件私有状态，会合并保存。 |

状态映射：

| 插件返回状态 | Hanabi 展示状态 |
| --- | --- |
| `active`、`downloading`、`seeding` | 下载中 |
| `paused`、`stopped` | 已暂停 |
| `complete`、`completed` | 已完成 |
| `checking`、`verifying`、`merging` | 合并/校验中 |
| `failed`、`error`、`removed` | 失败 |
| `waiting`、`pending` 或其他值 | 等待中 |

### 6.3 hanabi.download.pause

暂停任务。

请求参数与 `hanabi.download.status` 相同。

响应示例：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000002",
  "result": {
    "status": "paused",
    "pluginData": {
      "gid": "2089b05ecca3d829"
    }
  }
}
```

### 6.4 hanabi.download.resume

恢复任务。

请求参数与 `hanabi.download.status` 相同。

响应示例：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000003",
  "result": {
    "status": "pending",
    "pluginData": {
      "gid": "2089b05ecca3d829"
    }
  }
}
```

### 6.5 hanabi.download.remove

移除任务。

请求参数与 `hanabi.download.status` 相同。宿主调用后会移除本地插件任务记录。

响应示例：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000004",
  "result": {
    "status": "removed"
  }
}
```

## 7. UI 扩展

插件可以通过 `ui_extensions` 声明宿主渲染的简单 UI。

当前支持两个挂载点：

| 挂载点 | 说明 |
| --- | --- |
| `settings` | 插件商店中该插件卡片会显示“设置”按钮，点击后打开设置弹窗。 |
| `sidebar` | 插件启用后，主侧边栏会新增一个插件页面。默认显示在侧边栏下半边。 |

示例：

```json
{
  "ui_extensions": {
    "settings": [
      {
        "type": "switch",
        "id": "enable_auto_catch",
        "label": "全局自动嗅探",
        "description": "开启后将自动接管系统下载请求",
        "default": true
      },
      {
        "type": "text_input",
        "id": "proxy_url",
        "label": "代理节点地址",
        "placeholder": "socks5://127.0.0.1:1080"
      },
      {
        "type": "slider",
        "id": "performance_level",
        "label": "性能加速级别",
        "min": 1,
        "max": 5,
        "divisions": 4,
        "default": 3
      },
      {
        "type": "dropdown",
        "id": "theme_style",
        "label": "面板风格",
        "default": "dark",
        "options": [
          {"label": "暗色", "value": "dark"},
          {"label": "亮色", "value": "light"}
        ]
      },
      {
        "type": "button",
        "id": "sync_now",
        "label": "立即同步",
        "action": "forceSync"
      }
    ],
    "sidebar": [
      {
        "type": "text",
        "id": "overview",
        "label": "插件面板",
        "description": "这里显示插件自定义信息。"
      }
    ]
  }
}
```

`sidebar` 也可以写成对象来选择导航位置：

```json
{
  "ui_extensions": {
    "sidebar": {
      "placement": "top",
      "controls": [
        {
          "type": "text",
          "id": "overview",
          "label": "插件面板"
        }
      ]
    }
  }
}
```

`placement` 支持：

| 值 | 说明 |
| --- | --- |
| `top` | 显示在侧边栏上半边，跟下载中、已完成等主导航放在一起。 |
| `bottom` | 显示在侧边栏下半边，跟插件、设置、关于等工具入口放在一起。默认值。 |

元素字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `type` | string | 控件类型。 |
| `id` | string | 状态字段名。`button` 也建议写，便于未来扩展。 |
| `label` | string | 显示文本。 |
| `description` | string | 可选说明。 |
| `default` | any | 默认值。 |
| `action` | string | 按钮点击时调用的插件方法名。 |
| `placeholder` | string | 文本输入占位符。 |
| `options` | array | 下拉框选项。 |
| `min` / `max` | number | 滑块范围。 |
| `divisions` | number | 滑块分段数。 |
| `icon` | string | 保留字段，当前渲染器暂未使用。 |

控件类型：

| `type` | 说明 |
| --- | --- |
| `switch` | 开关。 |
| `text_input` | 文本输入。 |
| `button` | 按钮。 |
| `text` | 只读文本。 |
| `slider` | 滑块。 |
| `dropdown` | 下拉选择。 |

设置弹窗状态变更时，宿主会：

1. 保存状态到插件状态文件。
2. 调用插件方法 `onSettingsChanged`，参数是完整状态对象。

侧边栏状态变更时，宿主会：

1. 保存状态到插件状态文件，键名为 `<pluginId>_sidebar`。
2. 调用插件方法 `onSidebarStateChanged`，参数是完整状态对象。

按钮点击时，宿主会调用 `action` 指定的方法名，参数是当前 UI 状态对象。

示例请求：

```json
{
  "jsonrpc": "2.0",
  "id": "1740000000000010",
  "method": "forceSync",
  "params": {
    "enable_auto_catch": true,
    "proxy_url": "socks5://127.0.0.1:1080"
  }
}
```

## 8. 最小 Python 插件示例

```python
import json
import hashlib
import sys


def respond(request_id, result=None, error=None):
    payload = {"jsonrpc": "2.0", "id": request_id}
    if error is not None:
        payload["error"] = {"code": -32000, "message": str(error)}
    else:
        payload["result"] = result or {}
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def create_task(params):
    intent = params.get("intent") or {}
    value = intent.get("normalizedValue") or intent.get("rawValue")
    if not value:
        raise RuntimeError("Empty intent value")

    stable_id = hashlib.sha256(value.encode("utf-8")).hexdigest()[:16]
    task_id = f"plugin:hanabi.example.demo:{stable_id}"
    return {
        "accepted": True,
        "taskId": task_id,
        "status": "completed",
        "progress": 1,
        "pluginData": {"source": value},
    }


def main():
    raw = sys.stdin.read().strip()
    request = json.loads(raw) if raw else {}
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}

    try:
        if method == "hanabi.download.create":
            respond(request_id, create_task(params))
        elif method == "hanabi.download.status":
            respond(request_id, {"status": "completed", "progress": 1})
        elif method == "hanabi.download.pause":
            respond(request_id, {"status": "paused"})
        elif method == "hanabi.download.resume":
            respond(request_id, {"status": "pending"})
        elif method == "hanabi.download.remove":
            respond(request_id, {"status": "removed"})
        elif method == "onSettingsChanged":
            respond(request_id, {"ok": True})
        else:
            respond(request_id, error=f"Unsupported method: {method}")
    except Exception as exc:
        respond(request_id, error=exc)


if __name__ == "__main__":
    main()
```

## 9. 本地安装与调试

推荐本地流程：

1. 在插件目录编写 `plugin.json` 和入口文件。
2. 确保入口运行时已安装，例如 Python 或 Node。
3. 通过插件管理 UI 选择本地目录或插件包安装。
4. 在插件日志目录查看 `runtime.log`。

插件运行日志位置：

```text
<用户主目录>/.hdmx/plugins/logs/<pluginId>/runtime.log
```

插件安装目录：

```text
<用户主目录>/.hdmx/plugins/installed/<pluginId>/
```

插件任务状态：

```text
<用户主目录>/.hdmx/plugins/plugin_tasks.json
```

插件启用状态与 UI 设置：

```text
<用户主目录>/.hdmx/plugins/plugins_state.json
```

如果手动调试插件，可以模拟宿主请求：

```powershell
'{"jsonrpc":"2.0","id":"1","method":"hanabi.download.create","params":{"intent":{"rawValue":"hanabi+demo://test","normalizedValue":"hanabi+demo://test","type":"custom"},"fileName":"test.bin","startPaused":false}}' | python .\main.py
```

## 10. 打包

仓库提供了本地打包脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-plugin.ps1 `
  -PluginDir .\plugins\examples\magnet_torrent
```

默认输出：

```text
dist/plugins/<pluginId>-<version>.hanabi-plugin.zip
```

带下载 URL 前缀：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-plugin.ps1 `
  -PluginDir .\plugins\examples\magnet_torrent `
  -BaseDownloadUrl https://example.com/hanabi/plugins
```

脚本会输出：

- 插件包路径
- SHA-256
- 可放入插件商店索引的 JSON 条目

## 11. 插件商店索引

商店索引示例：

```json
{
  "channel": "stable",
  "generatedAt": "2026-04-25T13:15:56.744769Z",
  "plugins": [
    {
      "id": "hanabi.example.demo",
      "name": "Demo Plugin",
      "version": "0.1.0",
      "description": "demo",
      "author": "Your Name",
      "downloadUrl": "https://example.com/hanabi/plugins/hanabi.example.demo-0.1.0.hanabi-plugin.zip",
      "hash": "sha256:xxxxxxxx",
      "minAppVersion": "1.3.2",
      "channel": "stable",
      "capabilities": ["download:custom"],
      "reviewStatus": "published"
    }
  ]
}
```

字段说明：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 插件 ID。 |
| `name` | 是 | 展示名称。 |
| `version` | 是 | 插件版本。 |
| `description` | 是 | 插件说明。 |
| `author` | 是 | 作者。 |
| `downloadUrl` | 是 | 插件包下载地址。支持 `http(s)`、`file://` 和本地路径。 |
| `hash` | 建议 | 插件包 SHA-256，格式可为 `sha256:<hash>`。 |
| `iconUrl` | 否 | 图标 URL。 |
| `category` | 否 | 分类。 |
| `minAppVersion` | 否 | 最低应用版本。 |
| `channel` | 否 | 发布通道，默认 `stable`。 |
| `capabilities` | 否 | 能力列表。 |
| `changelog` | 否 | 更新日志。 |
| `reviewStatus` | 否 | 审核状态，默认 `published`。只有 `published` 可安装。 |
| `signature` | 否 | 插件包签名。 |
| `signingKeyId` | 否 | 签名公钥 ID。 |

宿主安装商店插件时会：

1. 下载插件包。
2. 如果有 `hash`，校验 SHA-256。
3. 如果有 `signature` 和 `signingKeyId`，校验签名。
4. 解压并按本地插件安装规则安装。

签名格式见 [PLUGIN_STORE_SIGNATURE_CN.md](PLUGIN_STORE_SIGNATURE_CN.md)。

## 12. 官方市场来源声明

官方市场推荐收录“源码来源声明”，而不是手动上传 zip。

`plugins-list/<plugin-id>.json` 示例：

```json
{
  "id": "hanabi.example.demo",
  "repo": "https://github.com/example/hanabi-plugin-demo",
  "branch": "main",
  "pluginPath": ".",
  "channel": "stable",
  "reviewStatus": "draft",
  "submitter": "github:example",
  "notes": "Optional review notes"
}
```

字段说明：

| 字段 | 说明 |
| --- | --- |
| `id` | 必须和插件仓库内 `plugin.json.id` 一致。 |
| `repo` | 插件源码仓库。当前优先支持 GitHub。 |
| `branch` | 分支，默认 `main`。 |
| `pluginPath` | 插件目录相对路径，默认 `.`。 |
| `channel` | 发布通道，默认 `stable`。 |
| `reviewStatus` | 审核状态，默认 `draft`。 |
| `submitter` | 提交者标识。 |
| `notes` | 审核备注。 |

本仓库已有生成链路：

```text
plugins-list/*.json
  -> scripts/sync-plugin-sources.ps1
  -> scripts/package-plugin-sources.ps1
  -> tool/generate_plugin_market_index.dart
  -> plugins/packages/*.hanabi-plugin.zip
  -> plugins/store_index.json
```

更完整的发布说明见：

- [PLUGIN_PUBLISH_FLOW_CN.md](PLUGIN_PUBLISH_FLOW_CN.md)
- [PLUGIN_MARKET_HYBRID_MODEL_CN.md](PLUGIN_MARKET_HYBRID_MODEL_CN.md)

## 13. 兼容性与边界

当前实现边界：

- 插件进程不是沙箱。`permissions` 目前是声明和审核提示，不是完整安全隔离。
- 插件每次方法调用都会被重新启动，不适合把长期状态只放在进程内存里。
- 需要保留状态时，建议使用插件自己的文件，或通过 `pluginData` 让宿主持久化任务级状态。
- `theme_overrides` 已被 manifest 解析，但宿主当前没有完整主题覆盖运行时。
- UI 扩展是宿主渲染的简单表单，不支持插件直接注入 Flutter 代码。
- 商店签名当前覆盖“从商店安装”的包，本地目录安装不强制签名。

建议插件作者遵循：

- `stdout` 只输出 JSON-RPC 响应，日志写 `stderr`。
- `create` 方法尽快返回，不要在里面等待完整下载结束。
- `taskId` 稳定且全局唯一，推荐 `plugin:<pluginId>:<backendId>`。
- 大小单位统一使用字节，速度统一使用字节/秒。
- `progress` 优先返回 `0.0` 到 `1.0`。
- 所有外部依赖写入 README，并在错误信息中明确提示缺失依赖。
