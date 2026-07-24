# 故障排查

本页按“安装、启动、协议、路由、任务、UI”分类列出常见问题。

## 首先收集信息

准备以下内容：

- Hanabi 版本；
- 插件 ID 和版本；
- `plugin.json`；
- 能稳定复现问题的一条 JSON-RPC 请求；
- `<Hanabi 数据目录>/plugins/logs/<pluginId>/runtime.log`；
- 插件自己的日志，注意移除 Cookie、Token 和本机隐私路径。

运行校验器：

```powershell
dart run tool/validate_plugin.dart .\path\to\plugin
```

## 插件无法安装

### `plugin.json not found in package root`

安装器只接受以下两种结构：

```text
plugin.json
main.py
```

或唯一一层目录：

```text
hanabi.example.demo/
  plugin.json
  main.py
```

压缩包根目录包含多个各自带 `plugin.json` 的目录会被拒绝。

### `entry does not exist`

`entry` 相对于 `plugin.json` 所在目录。注意 Windows 文件名大小写在其他构建环境中可能敏感，发布时必须保持完全一致。

### `manifestVersion ... is not supported`

当前宿主只支持 `manifestVersion: 1`。不要通过删除字段绕过新格式校验；按对应主版本文档迁移。

### `apiVersion ... is not supported`

当前支持 `apiVersion: "1.x"`。清单未写 `apiVersion` 时按 `1.0` 处理。

## 插件无法启动

### 找不到 `python`、`node` 或自定义命令

默认运行时要求对应命令位于用户 `PATH`。可以：

- 在插件 README 中声明运行时依赖；
- 使用 `runtime.executable` 指定另一个 `PATH` 命令；
- 把可再分发的运行文件放入插件目录并使用相对路径；
- 发布原生单文件可执行入口。

避免写死开发机绝对路径。

### 工作目录不存在

`runtime.workingDirectory` 必须随包发布，并位于插件根目录内。它不会在安装时自动创建。

### 调用超时

检查：

- 插件是否读取到 EOF，而不是持续等待下一行；
- 响应后是否退出；
- 是否把完整下载放在 `create` 中等待；
- 外部 RPC 是否设置自己的更短超时；
- `runtime.timeoutSeconds` 是否适合 UI 动作或创建操作。

任务状态方法的 10 秒超时不能由清单覆盖，应保持轻量。

## 宿主提示没有 JSON-RPC 响应

确认：

- 响应写入 `stdout`，不是 `stderr`；
- JSON 位于最后一条非空输出行；
- 根对象包含 `result` 或 `error`；
- 响应已刷新缓冲区；
- 入口进程以退出码 `0` 结束。

推荐使用官方 SDK，避免协议外壳差异。

## 响应 ID 不匹配

插件必须把请求中的 `id` 原样复制到响应。不要自行生成 ID，也不要把数字和字符串强制互转。

## 自定义链接路由到错误插件

依次检查：

1. URI scheme 是否以 `hanabi+` 或 `plugin+` 开头；
2. `intentSchemes` 是否小写并精确匹配；
3. 是否声明 `download:custom:<name>`；
4. 查询参数 `plugin` 是否是完整插件 ID；
5. 多插件的 `priority` 是否符合预期。

推荐链接：

```text
hanabi+demo://download/123?plugin=hanabi.example.demo
```

## 任务一直等待

- `status` 返回值是否是 JSON 对象；
- 状态字段是否使用支持的名称；
- `pluginData` 是否包含查询后端所需 ID；
- 插件是否在重启后仍能连接原后端；
- 后端返回的数字字符串是否可解析。

## 设置没有生效

- 设置保存后调用的方法是 `onSettingsChanged`；
- 侧边栏使用 `onSidebarStateChanged`；
- 方法参数是完整状态对象，不是 `{settings: ...}`；
- 状态通知失败不会让宿主回滚 UI；
- 按钮动作返回值当前不会自动写回控件。

## 日志出现乱码

插件请求和响应统一使用 UTF-8。Python 使用 `json.dumps(..., ensure_ascii=False)` 时，确认终端输出编码仍为 UTF-8。PowerShell 入口建议输出压缩 JSON，并避免依赖控制台代码页。

## 最小手动测试

```powershell
'{"jsonrpc":"2.0","id":"debug-1","method":"hanabi.download.status","params":{"taskId":"plugin:demo:1","pluginData":{}}}' |
  python .\main.py
```

先让入口在命令行下稳定返回，再通过 Hanabi 安装调试。
