# 插件发布指南

本指南说明如何校验、打包、签名并把插件部署到静态文件服务器或 Hanabi 插件市场。

## 发布产物

一个正式版本通常包含：

```text
dist/
  plugins/
    hanabi.example.demo-1.2.0.hanabi-plugin.zip
  store_index.json
```

插件包内包含唯一的插件目录或直接包含 `plugin.json`。推荐包结构：

```text
hanabi.example.demo/
  plugin.json
  main.py
  hanabi_plugin.py
  assets/
  README.md
  LICENSE
```

## 1. 发布前检查

更新清单：

- 提升 `version`，推荐语义化版本；
- 确认 `minAppVersion`、`maxAppVersion` 和 `apiVersion`；
- 声明实际使用的 `permissions`；
- 填写 `description`、`repository` 和 `license`；
- 确认入口与 SDK、资源、许可证一起打包；
- 不包含密钥、Cookie、本机配置、缓存和测试下载文件。

运行校验：

```powershell
dart run tool/validate_plugin.dart .\path\to\plugin
```

CI 使用 JSON 输出：

```powershell
dart run tool/validate_plugin.dart .\path\to\plugin --json
```

## 2. 本地打包

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-plugin.ps1 `
  -PluginDir .\path\to\plugin `
  -BaseDownloadUrl https://plugins.example.com/packages
```

默认输出：

```text
dist/plugins/<pluginId>-<version>.hanabi-plugin.zip
```

脚本会：

1. 在 Dart 可用时执行完整校验；
2. 执行基础必填字段和入口检查；
3. 把插件目录压缩为版本化包；
4. 计算 SHA-256；
5. 输出商店索引条目。

不要在相同插件版本下重新发布不同内容。需要修改包时提升版本号。

## 3. 商店索引

最小索引：

```json
{
  "channel": "stable",
  "generatedAt": "2026-07-19T12:00:00.000Z",
  "plugins": [
    {
      "manifestVersion": 1,
      "apiVersion": "1.0",
      "id": "hanabi.example.demo",
      "name": "Demo Plugin",
      "version": "1.2.0",
      "description": "处理自定义下载链接。",
      "author": "Your Name",
      "downloadUrl": "https://plugins.example.com/packages/hanabi.example.demo-1.2.0.hanabi-plugin.zip",
      "hash": "sha256:0123456789abcdef...",
      "minAppVersion": "1.5.0",
      "channel": "stable",
      "capabilities": ["download:custom:demo"],
      "intentSchemes": ["hanabi+demo"],
      "permissions": ["network"],
      "reviewStatus": "published"
    }
  ]
}
```

### 条目字段

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id`、`name`、`version`、`author` | 是 | 必须与包内清单一致。 |
| `description` | 推荐 | 市场摘要。 |
| `downloadUrl` | 是 | HTTPS 包地址；本地调试也支持文件 URL 和路径。 |
| `hash` | 强烈推荐 | `sha256:<lowercase-hex>`。 |
| `manifestVersion`、`apiVersion` | 推荐 | 允许客户端在下载前筛选协议。 |
| `minAppVersion`、`maxAppVersion` | 否 | 应与包内清单一致。 |
| `capabilities` | 推荐 | 市场展示和筛选。 |
| `intentSchemes`、`permissions` | 否 | 扩展路由和安全信息。 |
| `channel` | 否 | 默认 `stable`。 |
| `reviewStatus` | 否 | `published` 才可安装；也可使用 `draft`、`removed`。 |
| `signature`、`signingKeyId` | 推荐 | Ed25519 包签名。 |

客户端最终以包内 `plugin.json` 为运行依据。索引元数据用于展示、预筛选和完整性校验。

## 4. 来源仓库模式

官方市场推荐提交源码来源，不直接接收作者上传的二进制包。来源声明：

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

构建链路：

```text
plugins-list/*.json
  -> scripts/sync-plugin-sources.ps1
  -> scripts/package-plugin-sources.ps1
  -> tool/generate_plugin_market_index.dart
  -> plugins/packages/*.hanabi-plugin.zip
  -> plugins/store_index.json
```

这使市场可以审计源码、复现构建、统一签名和撤回版本。架构说明见[插件市场设计](PLUGIN_MARKET_DESIGN_CN.md)。

## 5. 签名

正式市场应在可信 CI 中：

1. 从审核后的源码构建包；
2. 计算包 SHA-256；
3. 使用离线或 CI 密钥服务签名稳定 payload；
4. 把公钥与签名写入索引；
5. 发布索引和不可变包。

具体 payload 与密钥轮换见[商店签名约定](PLUGIN_STORE_SIGNATURE_CN.md)。

## 6. 部署到服务器

推荐 URL：

```text
https://plugins.example.com/store_index.json
https://plugins.example.com/packages/<pluginId>-<version>.hanabi-plugin.zip
```

部署检查：

- 全部使用 HTTPS；
- `store_index.json` 使用 UTF-8；
- 包 URL 含固定版本且内容不可变；
- 先上传包，确认可下载和哈希正确，再原子替换索引；
- 索引使用短缓存，版本包使用长缓存；
- 保留旧版本用于回滚；
- 服务器返回正确 `Content-Type` 和 `X-Content-Type-Options: nosniff`。

发布顺序错误会导致客户端读到尚未上传的包，因此索引必须最后更新。

## 7. 更新与下架

发布更新：

1. 提升插件版本；
2. 重新校验与构建；
3. 上传新版本包；
4. 验证哈希和签名；
5. 更新索引条目；
6. 保留旧包一段回滚窗口。

下架时不要删除审核记录，把 `reviewStatus` 改为 `removed`。遇到已知恶意版本时，应同时撤回条目、发布公告并评估签名密钥是否需要轮换。

## 发布检查表

- [ ] 清单和入口通过校验
- [ ] 版本号已提升且包不可变
- [ ] 许可证、README 和运行依赖完整
- [ ] 权限与实际行为一致
- [ ] 不含凭据、缓存或本机数据
- [ ] Windows 干净环境完成冒烟测试
- [ ] SHA-256 与服务器文件一致
- [ ] 正式渠道签名验证通过
- [ ] 包先上传，索引后发布
- [ ] 旧版本和下架流程可回滚
