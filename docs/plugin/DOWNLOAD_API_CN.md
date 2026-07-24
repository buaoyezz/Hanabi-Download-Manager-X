# 下载 API

下载插件把磁力链接、Torrent、ED2K 文件链接、自定义 URI 或解析器请求转换成 Hanabi 可跟踪的任务。宿主负责展示和持久化任务，插件负责实际后端操作。

## 方法列表

| 方法 | 必需 | 说明 |
| --- | --- | --- |
| `hanabi.download.create` | 是 | 创建任务并返回稳定任务 ID。 |
| `hanabi.download.status` | 是 | 返回最新状态、进度和速度。 |
| `hanabi.download.pause` | 推荐 | 暂停任务。 |
| `hanabi.download.resume` | 推荐 | 恢复任务。 |
| `hanabi.download.remove` | 推荐 | 从插件后端移除任务。 |

## 创建任务

### `hanabi.download.create`

请求参数：

```json
{
  "intent": {
    "rawValue": "magnet:?xt=urn:btih:...",
    "normalizedValue": "magnet:?xt=urn:btih:...",
    "type": "magnet",
    "uri": "magnet:?xt=urn:btih:...",
    "pluginHint": "hanabi.example.magnet"
  },
  "fileName": "Ubuntu ISO",
  "referer": "https://example.com",
  "userAgent": "Hanabi/1.0",
  "cookies": "session=...",
  "headers": {"X-Token": "..."},
  "saveDir": "D:\\Downloads",
  "startPaused": false
}
```

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `intent` | object | 已规范化的下载意图。 |
| `intent.type` | string | `magnet`、`torrent_file`、`ed2k`、`resolver` 或 `custom`。 |
| `intent.normalizedValue` | string | 插件应优先使用的规范化值。 |
| `fileName` | string | 宿主建议的文件名。 |
| `referer` | string | 可选来源页。 |
| `userAgent` | string | 可选 User-Agent。 |
| `cookies` | string | 可选 Cookie 字符串，按敏感数据处理。 |
| `headers` | object | 可选请求头。 |
| `saveDir` | string | 可选保存目录。 |
| `startPaused` | boolean | 是否以暂停状态创建。 |

响应：

```json
{
  "accepted": true,
  "taskId": "plugin:hanabi.example.magnet:2089b05ecca3d829",
  "status": "pending",
  "fileName": "Ubuntu ISO",
  "pluginData": {
    "backendId": "2089b05ecca3d829"
  }
}
```

`taskId` 也兼容 `task_id`。如果省略，宿主会生成临时 ID，但插件应始终返回稳定且全局唯一的 ID。推荐格式：

```text
plugin:<pluginId>:<backendId>
```

`create` 应尽快返回。实际下载在独立后端执行，后续由 `status` 查询。

## 查询状态

### `hanabi.download.status`

宿主会传入持久化的任务记录：

```json
{
  "taskId": "plugin:hanabi.example.magnet:2089b05ecca3d829",
  "pluginId": "hanabi.example.magnet",
  "url": "magnet:?xt=urn:btih:...",
  "fileName": "Ubuntu ISO",
  "saveDir": "D:\\Downloads",
  "filePath": "D:\\Downloads\\ubuntu.iso",
  "pluginData": {
    "backendId": "2089b05ecca3d829"
  }
}
```

响应：

```json
{
  "status": "downloading",
  "totalSize": 5368709120,
  "downloadedSize": 2684354560,
  "speed": 10485760,
  "progress": 0.5,
  "filePath": "D:\\Downloads\\ubuntu.iso",
  "pluginData": {
    "backendId": "2089b05ecca3d829",
    "lastPeerCount": 42
  }
}
```

| 返回字段 | 兼容别名 | 单位与行为 |
| --- | --- | --- |
| `status` | - | 任务状态字符串。 |
| `filePath` | `file_path` | 最终或当前文件路径。 |
| `error` | - | 任务失败原因。 |
| `totalSize` | `total_size` | 字节。 |
| `downloadedSize` | `downloaded_size` | 字节。 |
| `speed` | `downloadSpeed`、`download_speed` | 字节/秒。 |
| `progress` | - | 推荐 `0.0` 至 `1.0`；大于 `1` 时按百分比处理。 |
| `pluginData` | `plugin_data` | 与已有数据合并后持久化。 |

## 控制任务

### `hanabi.download.pause`

请求参数与 `status` 相同。响应示例：

```json
{
  "status": "paused",
  "pluginData": {"backendId": "2089b05ecca3d829"}
}
```

### `hanabi.download.resume`

```json
{
  "status": "pending",
  "pluginData": {"backendId": "2089b05ecca3d829"}
}
```

### `hanabi.download.remove`

```json
{
  "status": "removed"
}
```

宿主调用 `remove` 后会移除本地插件任务记录。插件应自行清理后端任务；是否删除已下载文件由插件产品行为决定，并应在文档中明确。

## 状态映射

| 插件状态 | Hanabi 状态 |
| --- | --- |
| `active`、`downloading`、`seeding` | 下载中 |
| `paused`、`stopped` | 已暂停 |
| `complete`、`completed` | 已完成 |
| `checking`、`verifying`、`merging` | 合并或校验中 |
| `failed`、`error`、`removed` | 失败 |
| `waiting`、`pending` 或未知值 | 等待中 |

`removed` 当前映射为失败状态；正常移除后宿主通常会直接删除记录，因此不会长期展示。

## `pluginData` 设计

`pluginData` 是宿主持久化的插件私有 JSON 对象。适合保存：

- 后端任务 ID；
- RPC 地址或实例标识；
- 恢复查询所需的少量游标；
- 与任务绑定的插件版本信息。

不要保存密钥、大块二进制数据或持续增长的日志。宿主会把新响应中的 `pluginData` 与旧对象浅合并。

## 可靠性建议

- `create` 应具备幂等策略，避免宿主重试时重复创建任务。
- `status` 不要改变任务状态之外的外部资源。
- `pause`、`resume`、`remove` 对重复调用应尽量安全。
- 后端暂时不可用时返回结构化错误，不要伪造 `completed`。
- 所有大小使用字节，速度使用字节/秒，时间使用 ISO 8601 或 Unix 毫秒并在字段名中明确。
