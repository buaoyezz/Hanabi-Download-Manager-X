# Hanabi ED2K 官方插件

`hanabi.official.ed2k` 为 Hanabi Download Manager X 提供独立的 ED2K 文件下载能力。插件通过 Hanabi API v1 接收任务，使用隔离的 aMule 后端执行下载，并把进度与控制操作映射回 Hanabi。

> [!IMPORTANT]
> 插件只接受 `ed2k://|file|...|/` 文件链接，不处理服务器、服务器列表或搜索链接。请只下载你有权获取或分发的内容。

## 功能

- 解析 ED2K 文件名、字节大小和 128 位文件哈希；
- 以 ED2K 哈希生成稳定任务 ID，宿主重试不会重复添加任务；
- 支持创建、查询、暂停、继续和移除任务；
- 使用 aMule 的临时文件恢复未完成下载；
- 下载完成后安全移动到 Hanabi 指定的 `saveDir`；
- 私有 aMule External Connections 仅绑定 `127.0.0.1`，并使用随机密码；
- Windows x64/ARM64 首次运行时可自动下载并校验 aMule 3.0.0；
- 支持包内 aMule、本机 aMule 和外部 aMule EC 三种运行方式。

## 安装

推荐从 Hanabi 官方插件市场安装“Hanabi ED2K”。也可以在仓库根目录独立校验和打包：

```powershell
dart run tool/validate_plugin.dart .\plugins\official\ed2k

powershell -ExecutionPolicy Bypass -File .\scripts\package-plugin.ps1 `
  -PluginDir .\plugins\official\ed2k
```

宿主当前通过 `python` 启动 Python 插件，因此系统需要 Python 3.10 或更高版本。插件业务代码不依赖第三方 Python 包。

## aMule 后端

未配置外部 EC 时，插件按以下顺序寻找后端：

1. `AMULED_PATH` 与 `AMULECMD_PATH` 指定的程序；
2. `AMULE_HOME` 或 `config.json` 中的 `amuleHome`；
3. 插件包内的 `bin/` 或 `amule/`；
4. 插件数据目录中已校验安装的引擎；
5. 系统 `PATH` 中的 `amuled` 与 `amulecmd`；
6. Windows x64/ARM64 上从 aMule 官方 GitHub Release 下载固定版本。

自动安装资产固定为 aMule 3.0.0，并同时校验归档大小和 SHA-256。中断的归档下载会从已有字节继续。引擎、运行配置、临时文件和完成前的下载内容位于：

```text
<Hanabi 数据目录>/plugins/data/hanabi.official.ed2k/
```

aMule 运行日志位于：

```text
<Hanabi 数据目录>/plugins/logs/hanabi.official.ed2k/amule.log
```

## 配置

默认无需配置。高级配置文件路径为：

```text
<插件数据目录>/config.json
```

私有后端示例：

```json
{
  "autoInstallEngine": true,
  "amuleHome": "C:\\Tools\\aMule",
  "autoConnect": true,
  "startupTimeoutSeconds": 20
}
```

外部 aMule EC 示例：

```json
{
  "amuleHost": "127.0.0.1",
  "amulePort": 4712,
  "amulePassword": "replace-with-your-ec-password",
  "amulecmdPath": "C:\\Tools\\aMule\\bin\\amulecmd.exe",
  "externalIncomingDir": "D:\\aMule\\Incoming"
}
```

环境变量优先于 `config.json`：

| 环境变量 | 说明 |
| --- | --- |
| `AMULE_HOME` | 包含 `amuled` 与 `amulecmd` 的目录或其上级目录。 |
| `AMULED_PATH` | `amuled` 可执行文件路径。 |
| `AMULECMD_PATH` | `amulecmd` 可执行文件路径。 |
| `AMULE_AUTO_INSTALL` | `true`/`false`，控制缺少后端时是否自动安装固定版本。 |
| `AMULE_AUTO_CONNECT` | `true`/`false`，控制私有后端是否自动连接 ED2K/Kad 网络。 |
| `AMULE_HOST` | 启用外部 EC 模式并指定主机。 |
| `AMULE_PORT` | 外部 EC 端口，默认 `4712`。 |
| `AMULE_PASSWORD` | 外部 EC 明文密码。 |
| `AMULE_INCOMING_DIR` | 外部 aMule 的完成目录，用于发现并移动文件。 |

外部模式由用户负责 aMule 的访问控制、进程生命周期和下载目录配置。不要把未受保护的 EC 端口暴露到公网。

## 任务行为

- `startPaused` 会在添加任务后立即调用 aMule 暂停命令；
- 队列短暂不可见时保留 30 秒宽限期，避免守护进程恢复期间误报失败；
- aMule 队列只提供百分比而不提供稳定的瞬时速度，因此当前 `speed` 返回 `0`；
- 完成文件与目标目录中的同名文件冲突时，会保留既有文件，并在新文件名后附加 ED2K 哈希前缀；
- 从 Hanabi 移除未完成任务会取消 aMule 任务并清理对应的 part 文件；
- 已完成并移动到目标目录的文件不会因移除 Hanabi 任务而删除；
- `pluginData` 只保存哈希、文件信息和恢复所需路径，不保存 EC 密码。

## 已知限制

- 当前仅支持单文件 ED2K 文件链接，不支持服务器链接、搜索、集合或逐文件选择；
- ED2K 网络的可用性、来源数量和速度由 aMule、服务器与 Kad 网络决定；
- 非 Windows 平台不自动安装 aMule，需要提供本机程序或外部 EC；
- 外部模式若不配置 `externalIncomingDir`，插件无法自动确认和移动已完成文件；
- 当前插件不提供服务器列表、Kad 状态、限速和连接参数 UI。

## 开发与测试

```powershell
$env:PYTHONDONTWRITEBYTECODE = '1'
python -m unittest discover `
  -s .\plugins\official\ed2k\tests `
  -p "test_*.py" -v
```

插件目录中的 `hanabi_plugin.py` 是 API v1 单文件 Python SDK 的随包副本，使该目录可以脱离主仓库独立打包。

## 许可证与第三方组件

插件自身源码使用 MIT License。自动安装的 aMule 来自 [aMule 3.0.0 官方 GitHub Release](https://github.com/amule-project/amule/releases/tag/3.0.0)，aMule 及其随包组件适用其各自许可证；上游归档中的许可证文件会随引擎保存在插件数据目录。
