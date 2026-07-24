# 插件清单参考

每个插件根目录必须包含一个 UTF-8 编码的 `plugin.json`。清单声明插件身份、兼容范围、入口、能力、权限和 UI 扩展。

## 完整示例

```json
{
  "$schema": "https://x.zzbuaoye.net/schemas/hanabi/plugin-manifest-v1.schema.json",
  "manifestVersion": 1,
  "apiVersion": "1.0",
  "id": "hanabi.example.demo",
  "name": "Demo Plugin",
  "version": "1.2.0",
  "author": "Your Name",
  "description": "处理自定义下载链接。",
  "category": "download",
  "entry": "src/main.ts",
  "icon": "assets/icon.png",
  "homepage": "https://example.com/hanabi-demo",
  "repository": "https://github.com/example/hanabi-demo",
  "license": "MIT",
  "minAppVersion": "1.5.0",
  "maxAppVersion": "1.9.99",
  "capabilities": ["download:custom:demo"],
  "intentSchemes": ["hanabi+demo", "plugin+demo"],
  "priority": 10,
  "permissions": ["network", "file_write"],
  "runtime": {
    "executable": "deno",
    "arguments": ["run", "--allow-net", "--allow-write", "{entry}"],
    "environment": {"PLUGIN_MODE": "production"},
    "workingDirectory": "src",
    "timeoutSeconds": 45
  }
}
```

## 顶层字段

| 字段 | 类型 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `$schema` | string | 否 | - | JSON Schema 地址，仅供编辑器使用。 |
| `manifestVersion` | integer | 否 | `1` | 清单结构版本。当前只支持 `1`。 |
| `apiVersion` | string | 否 | `1.0` | JSON-RPC API 版本。当前支持 `1.x`。 |
| `id` | string | 是 | - | 全局唯一 ID，2 至 63 个小写字母、数字、点、短横线或下划线。 |
| `name` | string | 是 | - | 用户可见名称。 |
| `version` | string | 是 | - | 插件版本，推荐使用语义化版本。 |
| `author` | string | 是 | - | 作者或组织名称。 |
| `description` | string | 否 | 空字符串 | 市场和插件页简介。 |
| `category` | string | 否 | `other` | 市场分类。 |
| `entry` | string | 是 | - | 相对于插件根目录的入口文件。 |
| `icon` | string | 否 | - | 相对于插件根目录的图标。 |
| `homepage` | string | 否 | - | 产品主页。 |
| `repository` | string | 否 | - | 源代码或问题追踪仓库。 |
| `license` | string | 否 | - | 推荐使用 SPDX 标识，如 `MIT`。 |
| `minAppVersion` | string | 否 | - | 最低 Hanabi 版本，包含该版本。 |
| `maxAppVersion` | string | 否 | - | 最高 Hanabi 版本，包含该版本。 |
| `capabilities` | string[] | 是 | - | 插件提供的能力，至少一个。 |
| `intentSchemes` | string[] | 否 | `[]` | 插件精确处理的自定义 URI scheme。 |
| `priority` | integer | 否 | `0` | 多插件匹配时的优先级，范围 `-1000` 至 `1000`。 |
| `permissions` | string[] / object | 否 | `[]` | 安全能力声明。 |
| `runtime` | object | 否 | 自动检测 | 运行命令、参数、环境和超时。 |
| `ui_extensions` | object | 否 | - | 设置页和侧边栏贡献点。 |
| `theme_overrides` | object | 否 | - | 实验性主题覆盖。 |

## 路径规则

`entry`、`icon` 和 `runtime.workingDirectory` 必须是插件目录内的相对路径。以下写法会被拒绝：

- 绝对路径，例如 `C:\tools\main.py`；
- 以 `/` 或 `\` 开头的路径；
- 包含 `..` 的目录穿越路径；
- 指向不存在入口文件或工作目录的路径。

`runtime.executable` 可以是 `PATH` 中的命令，也可以是插件内相对路径。绝对路径虽然可运行，但校验器会发出可移植性警告。

## 能力

能力决定宿主是否把一个下载意图交给插件。

| 能力 | 匹配的意图 |
| --- | --- |
| `download:http`、`intent:http` | HTTP/HTTPS。当前内置下载器优先。 |
| `download:magnet`、`intent:magnet` | `magnet:` URI。 |
| `download:torrent_file`、`intent:torrent_file` | `.torrent` 文件。 |
| `download:ed2k`、`intent:ed2k` | `ed2k://|file|...|/` 文件链接。 |
| `resolver`、`intent:resolver` | `resolver:` 或 `hanabi-resolver:` URI。 |
| `custom`、`intent:custom`、`download:custom` | 任意 Hanabi 自定义 URI。 |
| `intent:custom:<name>`、`download:custom:<name>` | `hanabi+<name>:` 或 `plugin+<name>:`。 |
| `theme_provider` | 实验性主题提供者。 |

能力名称必须使用小写命名空间格式。插件可以声明宿主尚未识别的能力，用于市场展示或未来扩展；未知能力不会自动触发调用。

## 自定义 URI 路由

Hanabi 仅将 `hanabi+...:` 和 `plugin+...:` 识别为自定义插件 URI。例如：

```text
hanabi+cloud://download/123?plugin=hanabi.example.cloud
plugin+cloud://download/123
```

选择顺序如下：

1. 查询参数 `plugin` 或 `pluginHint` 明确指定的插件 ID/名称；
2. `intentSchemes` 精确匹配；
3. `download:custom:<name>` 或 `intent:custom:<name>` 精确匹配；
4. `priority` 数值更高的插件；
5. 插件 ID 的字典序。

为了得到确定路由，推荐同时声明具体能力和 `intentSchemes`，不要仅依赖 `priority`。

## 权限

数组格式：

```json
{
  "permissions": ["network", "file_write"]
}
```

对象格式：

```json
{
  "permissions": {
    "network": true,
    "file_write": true,
    "system_command": false
  }
}
```

| 权限 | 何时声明 |
| --- | --- |
| `network` | 访问互联网、局域网或本机网络服务。 |
| `file_write` | 写入下载文件、配置或插件数据。 |
| `system_command` | 启动外部进程、脚本或系统命令。 |

> [!WARNING]
> 当前版本不会在操作系统层强制这些权限。它们用于用户提示、市场审核和未来策略。完整边界见[安全模型](SECURITY_CN.md)。

## 运行时

`runtime` 字段用于不受默认扩展名规则覆盖的语言和命令：

```json
{
  "runtime": {
    "executable": "deno",
    "arguments": ["run", "--allow-net", "{entry}"],
    "environment": {"PLUGIN_MODE": "production"},
    "workingDirectory": "src",
    "timeoutSeconds": 45
  }
}
```

| 字段 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `executable` | string | 自动检测 | `PATH` 命令、插件内可执行文件或绝对路径。 |
| `arguments` | string[] | `[]` | 参数；支持 `{entry}` 和 `{pluginDir}`。 |
| `environment` | object | `{}` | 追加环境变量，不得使用 `HANABI_` 前缀。 |
| `workingDirectory` | string | 插件根目录 | 插件内相对工作目录。 |
| `timeoutSeconds` | integer | `30` | 默认调用超时，范围 1 至 300 秒。 |

完整启动规则见[运行时与 JSON-RPC](RUNTIME_AND_RPC_CN.md)。

## UI 扩展

`ui_extensions` 支持 `settings` 和 `sidebar` 两个挂载点。宿主只渲染声明式控件，不会加载插件提供的 Flutter 代码。字段与事件见[UI 扩展](UI_EXTENSIONS_CN.md)。

## 编辑器 Schema

仓库中的 Schema：

```text
plugins/schema/plugin-manifest.schema.json
```

开发时可以把 `$schema` 指向本地文件或部署后的公开 URL。`$schema` 不参与宿主运行，也不会改变安装行为。

## 校验

```powershell
dart run tool/validate_plugin.dart .\path\to\plugin
```

打包脚本会在 Dart SDK 可用时自动执行同一校验器。
