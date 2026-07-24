# 插件市场设计

Hanabi 官方插件市场采用“作者维护源码、市场 CI 统一构建、客户端只消费签名产物”的分发模型。

## 设计目标

- 插件作者只维护自己的仓库和 `plugin.json`；
- 市场维护者可以审计来源、权限和构建过程；
- 相同源码可以重复构建和回滚；
- 客户端只负责浏览、下载、验证、安装和更新；
- 静态文件服务器即可承载索引与插件包。

## 架构

```text
作者仓库
  -> 来源声明 PR
  -> 市场审核
  -> CI 拉取源码
  -> 校验 plugin.json
  -> 构建 .hanabi-plugin.zip
  -> 计算 SHA-256 / Ed25519 签名
  -> 生成 store_index.json
  -> 发布到静态服务器
  -> Hanabi 客户端验证并安装
```

## 为什么不直接接收 ZIP

直接上传二进制包会带来：

- 源码与发布物无法对应；
- 难以审计新增二进制和依赖；
- 无法稳定重建、撤回和回滚；
- 作者私钥、市场签名和包哈希难以统一治理；
- 同版本包可能被静默替换。

因此官方市场接受“来源声明”，由可信 CI 生成正式包。自建市场仍可使用本地打包脚本，但应遵守相同的不可变版本原则。

## 仓库结构

```text
.github/
  workflows/
    plugin-market-build.yml
plugins-list/
  plugin-source.example.json
  <plugin-id>.json
scripts/
  sync-plugin-sources.ps1
  package-plugin-sources.ps1
  package-plugin.ps1
tool/
  validate_plugin.dart
  generate_plugin_market_index.dart
plugins/
  packages/
  store_index.json
```

`plugins-list/` 只保存来源和审核状态，不复制第三方插件源码。

## 来源声明

```json
{
  "id": "hanabi.example.demo",
  "repo": "https://github.com/example/hanabi-plugin-demo",
  "branch": "main",
  "pluginPath": ".",
  "channel": "stable",
  "reviewStatus": "draft",
  "submitter": "github:example",
  "notes": "Initial review"
}
```

| 字段 | 说明 |
| --- | --- |
| `id` | 必须与来源目录中的 `plugin.json.id` 一致。 |
| `repo` | 可公开读取的源码仓库。 |
| `branch` | 构建分支，默认 `main`。正式系统建议扩展为固定 commit。 |
| `pluginPath` | 插件目录相对于仓库根目录的位置。 |
| `channel` | `stable`、`beta` 等发布通道。 |
| `reviewStatus` | `draft`、`published` 或 `removed`。 |
| `submitter` | 提交者身份。 |
| `notes` | 审核记录或构建备注。 |

## 审核流程

### 自动检查

- JSON Schema 与宿主校验器通过；
- 插件 ID、来源声明和目录一致；
- 入口、图标、SDK 和许可证文件存在；
- 版本号没有倒退或复用；
- 不包含路径穿越、凭据和异常大文件；
- `permissions` 与静态扫描结果没有明显冲突；
- 构建产物 SHA-256 可复现。

### 人工检查

- 插件用途、作者和仓库可信；
- 网络、文件和命令行为与说明一致；
- 外部下载地址和更新机制不会绕过市场；
- UI 文案不会冒充 Hanabi 系统提示；
- 第三方许可证允许再分发；
- 错误处理不会泄露凭据或用户数据。

通过后把 `reviewStatus` 改为 `published`。需要撤回时改为 `removed`，保留历史记录。

## CI 阶段

### 1. Sync

读取 `plugins-list/*.json`，拉取来源仓库并复制 `pluginPath` 到隔离工作区。

### 2. Validate

对每个目录执行：

```powershell
dart run tool/validate_plugin.dart <plugin-directory> --json
```

错误阻止发布；警告进入审核报告。

### 3. Package

生成：

```text
<plugin-id>-<version>.hanabi-plugin.zip
```

包名、清单版本和来源 commit 应写入构建溯源记录。

### 4. Sign

计算 SHA-256，使用市场 Ed25519 密钥签名。私钥不进入源码仓库和普通构建日志。

### 5. Index

从已校验的包内清单生成索引，而不是信任作者单独提交的市场元数据。

### 6. Publish

先发布不可变插件包，最后原子替换索引。失败时旧索引继续可用。

## 客户端职责

Hanabi 客户端负责：

- 从官方或用户选择的镜像加载索引；
- 只展示 `published` 条目；
- 下载包并验证哈希和签名；
- 校验包内清单并执行带回滚的安装；
- 比较版本并提供更新；
- 保留本地日志和插件设置。

客户端不负责审核源码、上传包或替市场生成元数据。

## 通道与镜像

索引根级 `channel` 表示索引通道，条目也可以单独声明通道。正式部署建议不同通道使用不同 URL：

```text
/stable/store_index.json
/beta/store_index.json
```

镜像必须同步相同字节的包和索引。签名验证允许客户端在不信任镜像传输层的情况下发现篡改，但仍应使用 HTTPS。

## 撤回与密钥轮换

- 普通下架：条目标记 `removed`，保留包和审核记录。
- 恶意版本：立即从索引移除，发布公告，必要时阻断包下载。
- 私钥泄露：新增签名密钥 ID、用新密钥重签可信版本、撤销旧密钥并发布客户端信任策略更新。
- 哈希冲突或包不一致：停止发布流水线，不能通过重新上传同版本包修复。

签名技术细节见[商店签名约定](PLUGIN_STORE_SIGNATURE_CN.md)，操作步骤见[发布指南](PLUGIN_PUBLISH_FLOW_CN.md)。
