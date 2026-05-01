# Hanabi 插件最小发布流程

如果你的目标是“插件开发者本地写好 `plugin.json`，然后直接打包推送”，当前仓库已经足够支持这套模型。

不需要额外做一个远端 `plugin.json` 生成器。

## 最小原则

- `plugin.json` 以插件目录里的本地文件为准
- 宿主安装时只认插件包里的 `plugin.json`
- 商店侧只需要保存插件包地址和索引条目

也就是说，发布链路可以收敛成：

1. 在本地插件目录创建 `plugin.json`
2. 把插件目录打成 `.hanabi-plugin.zip`
3. 把压缩包上传到你的仓库、对象存储或 GitHub Release
4. 把商店索引 JSON 里的条目更新后推送上去

## 目录示例

```text
plugins/
  my_downloader/
    plugin.json
    main.py
    assets/
```

`plugin.json` 可以直接参考：

- [plugins/plugin.json.example](/e:/HanabiDownloadManagerX/Hanabi-Download-Manager-X/plugins/plugin.json.example)
- [plugins/examples/magnet_torrent/plugin.json](/e:/HanabiDownloadManagerX/Hanabi-Download-Manager-X/plugins/examples/magnet_torrent/plugin.json)

## 必填字段

当前宿主最少要求这些字段：

```json
{
  "id": "hanabi.example.demo",
  "name": "Demo Plugin",
  "version": "0.1.0",
  "author": "Your Name",
  "entry": "main.py",
  "capabilities": ["download:custom"]
}
```

常用可选字段：

- `description`
- `permissions`
- `minAppVersion`

## 本地打包

仓库里已经加了一个最小打包脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-plugin.ps1 -PluginDir .\plugins\examples\magnet_torrent
```

它会做三件事：

- 读取插件目录里的 `plugin.json`
- 输出 `.hanabi-plugin.zip`
- 计算 `SHA-256` 并打印一段可直接放进商店索引的 JSON 条目

如果你已经有固定下载前缀，可以一起传：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package-plugin.ps1 `
  -PluginDir .\plugins\examples\magnet_torrent `
  -BaseDownloadUrl https://example.com/hanabi/plugins
```

## 商店索引最小条目

脚本会生成类似这样的条目：

```json
{
  "id": "hanabi.example.demo",
  "name": "Demo Plugin",
  "version": "0.1.0",
  "description": "demo",
  "author": "Your Name",
  "downloadUrl": "https://example.com/hanabi/plugins/hanabi.example.demo-0.1.0.hanabi-plugin.zip",
  "hash": "sha256:xxxxxxxx",
  "channel": "stable",
  "capabilities": ["download:custom"],
  "reviewStatus": "published"
}
```

## 当前建议

如果你就是自己维护插件分发，建议先按下面这套做：

- `plugin.json` 本地手写
- 插件包本地打包
- 商店索引手动维护或用脚本生成
- 先不做复杂的远端插件元数据服务

这样开发和发布成本最低，而且和当前 Hanabi 宿主实现完全匹配。
