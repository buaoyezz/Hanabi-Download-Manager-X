# Hanabi 官方插件

这里存放由 Hanabi Download Manager X 团队维护、可独立校验和打包的官方插件源码。

| 插件 | ID | 说明 |
| --- | --- | --- |
| [Hanabi BitTorrent](bittorrent/README_CN.md) | `hanabi.official.bittorrent` | 支持磁力链接与 `.torrent` 文件下载。 |
| [Hanabi ED2K](ed2k/README_CN.md) | `hanabi.official.ed2k` | 支持 ED2K 文件链接下载。 |

每个子目录都是完整插件根目录，不依赖仓库中的相对源码路径。市场 CI 通过 `plugins-list/` 中的来源声明独立打包。
