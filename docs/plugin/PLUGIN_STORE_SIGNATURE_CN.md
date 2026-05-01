# Hanabi 插件商店签名约定

当前实现补的是“商店安装链路”的签名校验：

- 商店索引可以声明 `signingKeys`
- 每个插件条目可以声明 `signature + signingKeyId`
- 应用安装前会先做 `SHA-256` 校验，再做签名校验

本地目录安装和手动导入未在这一版强制要求签名。

## 1. 索引字段

索引根对象新增：

```json
{
  "channel": "stable",
  "signingKeys": [
    {
      "id": "hanabi-official",
      "algorithm": "ed25519",
      "publicKey": "base64:xxxxxxxx"
    }
  ],
  "plugins": [
    {
      "id": "hanabi.example.magnet_torrent",
      "name": "Example Magnet/Torrent Handler",
      "version": "0.1.0",
      "downloadUrl": "https://example.com/magnet_torrent.hanabi-plugin.zip",
      "hash": "sha256:xxxxxxxx",
      "signature": "base64:xxxxxxxx",
      "signingKeyId": "hanabi-official"
    }
  ]
}
```

说明：

- `algorithm` 当前只支持 `ed25519`
- `publicKey` 支持 `base64:...`、`hex:...`，也兼容去掉前缀的纯 base64/hex
- `signature` 的编码规则与 `publicKey` 相同

## 2. 签名 Payload

验签时不会直接签整个索引 JSON，而是签下面这段稳定字符串：

```text
hanabi-plugin-store-signature-v1
id=<plugin-id>
version=<plugin-version>
sha256=<package-sha256-lowercase>
minAppVersion=<min-app-version-if-present>
```

注意：

- `minAppVersion` 只有在条目里存在时才会拼进去
- 换行符使用 `\n`
- `sha256` 用实际下载包的哈希小写值

## 3. 安装行为

- `hash` 存在时，必须先通过哈希校验
- `signature` 和 `signingKeyId` 同时存在时，必须通过签名校验
- 找不到签名公钥、算法不支持、签名不匹配，安装会直接失败

## 4. 当前边界

这版解决的是“商店下载包在安装前可验签”。

还没覆盖的内容：

- 本地目录安装的强制签名策略
- 插件包内嵌签名清单
- 独立于商店索引的本地信任根管理
