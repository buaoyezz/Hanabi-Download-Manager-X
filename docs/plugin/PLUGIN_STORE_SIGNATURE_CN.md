# 插件商店签名约定

Hanabi 商店使用 SHA-256 验证包内容，使用 Ed25519 验证发布者签名。签名覆盖稳定 payload，而不是整个索引 JSON。

## 索引格式

```json
{
  "channel": "stable",
  "signingKeys": [
    {
      "id": "hanabi-official-2026",
      "name": "Hanabi Official 2026",
      "algorithm": "ed25519",
      "publicKey": "base64:xxxxxxxx"
    }
  ],
  "plugins": [
    {
      "id": "hanabi.example.demo",
      "version": "1.2.0",
      "downloadUrl": "https://plugins.example.com/hanabi.example.demo-1.2.0.hanabi-plugin.zip",
      "hash": "sha256:0123456789abcdef...",
      "minAppVersion": "1.5.0",
      "signature": "base64:xxxxxxxx",
      "signingKeyId": "hanabi-official-2026",
      "reviewStatus": "published"
    }
  ]
}
```

## 支持的编码

`publicKey` 和 `signature` 支持：

- `base64:<value>`；
- `hex:<value>`；
- 无前缀的标准 Base64；
- 无前缀的十六进制。

算法名称当前只支持小写 `ed25519`。

## 签名 payload

签名输入是 UTF-8 编码的以下字符串：

```text
hanabi-plugin-store-signature-v1
id=<plugin-id>
version=<plugin-version>
sha256=<package-sha256-lowercase>
minAppVersion=<min-app-version-if-present>
```

规则：

- 行分隔符固定为 `\n`；
- 最后一行后不追加额外空行；
- `sha256` 只写 64 位小写十六进制，不含 `sha256:` 前缀；
- 只有索引存在 `minAppVersion` 时才添加对应行；
- 字段值按索引原值使用，不做 Unicode 规范化或空白修剪之外的隐式变换。

示例：

```text
hanabi-plugin-store-signature-v1
id=hanabi.example.demo
version=1.2.0
sha256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
minAppVersion=1.5.0
```

## 客户端验证顺序

1. 下载包到本地缓存；
2. 计算实际 SHA-256；
3. 索引有 `hash` 时，比较声明哈希；
4. 索引同时有 `signature` 和 `signingKeyId` 时，查找公钥；
5. 使用实际包哈希构造 payload；
6. 执行 Ed25519 验签；
7. 通过后解压并校验包内 `plugin.json`；
8. 安装插件。

以下情况会停止安装：

- 哈希格式错误或不匹配；
- 只有签名或只有密钥 ID；
- 找不到签名密钥；
- 算法不支持；
- 公钥或签名编码错误；
- Ed25519 验证失败。

## 签名覆盖范围

签名通过包哈希间接覆盖插件包内的全部文件，包括 `plugin.json`、入口、SDK 和资源。索引中的名称、描述、下载 URL 等展示字段不在 v1 payload 中。

因此：

- 客户端运行时以包内清单为准；
- 索引仍必须通过 HTTPS 和受控发布流程保护；
- 市场不能把签名当作整个索引的真实性证明。

未来如需签名完整索引，应定义独立的索引签名版本，不能静默改变 v1 payload。

## 密钥管理

- 私钥存放在 CI 密钥服务、硬件安全模块或离线签名环境；
- 每把密钥使用唯一且不可复用的 `id`；
- 构建日志不得输出私钥、种子或完整签名命令环境；
- 定期演练密钥轮换和已泄露密钥撤销；
- 公钥可以随索引分发，但高安全部署应由客户端固定可信根或验证索引本身。

## 密钥轮换

推荐步骤：

1. 生成新 Ed25519 密钥和新 `signingKeyId`；
2. 在索引 `signingKeys` 中同时发布新旧公钥；
3. 新版本改用新密钥签名；
4. 为仍需分发的可信旧包生成新签名条目；
5. 等待客户端获取新公钥；
6. 从活动索引移除旧密钥和受影响签名。

如果旧私钥泄露，不能继续信任旧签名。应同时撤回可疑版本并通过独立渠道发布安全公告。

## 当前边界

- 本地目录安装和手动导入不强制签名；
- v1 没有包内嵌签名文件；
- v1 不提供完整索引签名；
- 当前索引中的公钥不是客户端内置的独立信任根。

更完整的风险说明见[安全模型](SECURITY_CN.md)。
