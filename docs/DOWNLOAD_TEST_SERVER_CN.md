# HDMX 本地下载测试服务器

该工具用于在完全可控的本地网络环境中测试 NSFX 下载核心。服务器默认只监听
`127.0.0.1`，测试文件按偏移实时生成，不占用仓库和磁盘空间，并且支持任意 Range
的逐字节一致性校验。

## 启动

```powershell
.\scripts\start-download-test-server.ps1
```

也可以直接运行：

```powershell
dart run tool/download_test_server.dart --host 127.0.0.1 --port 18080
```

端口被占用时可指定其他端口；`0` 会自动选择空闲端口：

```powershell
.\scripts\start-download-test-server.ps1 -Port 0
```

默认禁止绑定到非回环地址。如确实需要局域网设备参与测试，必须同时传入
`-AllowRemote`。控制 API 没有身份认证，不建议暴露到公网。

## 快速验证

服务器启动后，在另一个 PowerShell 窗口运行：

```powershell
.\scripts\smoke-test-download-server.ps1
```

也可以把以下地址直接交给 Hanabi Download Manager X：

```text
http://127.0.0.1:18080/download/normal/64m.bin
```

## 下载场景

下载地址格式：

```text
/download/{scenario}/{size}.bin
```

`size` 支持纯字节数或 `k`、`m`、`g` 后缀，例如 `524288`、`512k`、`64m`、
`1g`。单个逻辑资源最大 16 GiB，但内容不会一次性进入内存。

| 场景 | 行为 |
| --- | --- |
| `normal` | 正确支持 HEAD、GET 和单一 Byte Range |
| `slow` | 每个输出块之间延迟，用于低速和 ETA 测试 |
| `no-range` | 忽略 Range 并返回完整 HTTP 200 |
| `disconnect-once` | 第一次真实传输只发送部分内容后断开 |
| `stall-once` | 第一次传输中途停顿，用于读超时测试 |
| `flaky-503` | 前 N 次真实传输返回 HTTP 503 |
| `bad-content-range` | 返回错位的 Content-Range |
| `truncated` | 每次都在响应体完成前断开 |
| `changing` | 由控制 API 改变 ETag 和确定性内容版本 |
| `status` | 返回 `code` 参数指定的 HTTP 状态码 |

常用查询参数：

```text
seed=7
chunkBytes=65536
delayMs=25
failAfterBytes=262144
stallMs=6000
failures=2
code=503
resource=my-file
```

示例：

```text
http://127.0.0.1:18080/download/slow/128m.bin?chunkBytes=32768&delayMs=40
http://127.0.0.1:18080/download/disconnect-once/32m.bin?failAfterBytes=1048576
http://127.0.0.1:18080/download/flaky-503/8m.bin?failures=2
http://127.0.0.1:18080/download/status/1m.bin?code=404
```

服务器会把 `Range: bytes=0-0` 识别为元数据探测，不消耗一次故障注入机会。

## 测试服务 API

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/health` | 健康状态和运行时间 |
| GET | `/api/v1/capabilities` | 服务能力和参数说明 |
| GET | `/api/v1/scenarios` | 场景列表和示例 URL |
| GET | `/api/v1/stats` | 请求数、并发数、Range、字节数和最近请求 |
| POST | `/api/v1/stats/reset` | 清空统计，保留故障尝试和资源版本 |
| POST | `/api/v1/control/reset` | 清空统计、故障尝试和资源版本 |
| GET | `/api/v1/resources` | 当前逻辑资源版本 |
| POST | `/api/v1/resources/version` | 修改逻辑资源版本 |

修改资源版本：

```powershell
$body = @{ resource = 'release'; version = 2 } | ConvertTo-Json
Invoke-RestMethod `
  -Method Post `
  -Uri http://127.0.0.1:18080/api/v1/resources/version `
  -ContentType application/json `
  -Body $body
```

之后访问：

```text
http://127.0.0.1:18080/download/changing/64m.bin?resource=release
```

将得到新的强 ETag 和不同但仍可复现的内容，用于验证 `If-Range` 和资源变化保护。

## 自动化测试

仅运行服务器与下载核心集成测试：

```powershell
flutter test test/services/kernel/nsfx_local_server_integration_test.dart
```

运行服务器自身的 API/协议测试：

```powershell
flutter test test/tool/download_test_server_test.dart
```

运行所有测试：

```powershell
flutter test
```
