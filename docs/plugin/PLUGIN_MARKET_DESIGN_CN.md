# HDMX 插件市场方案

目标是：
- 对插件作者足够简单
- 对官方市场足够可控

## 1. 设计结论

HDMX 官方市场不接受“客户端直接上传 zip 包”。

官方推荐流程改成：

1. 插件作者在自己的 GitHub 仓库维护插件源码
2. 插件目录内包含 `plugin.json`
3. 作者在 HDMX 官方插件市场仓库提交插件来源
4. 审核通过后，CI 自动拉取插件源码
5. CI 自动打包 `.hdmx-plugin.zip`
6. CI 自动生成官方 `plugins.json`
7. HDMX 客户端只消费官方索引和官方打包产物

## 2. 为什么不用客户端直接上传

直接上传二进制包的问题很明确：

- 包内容不可审计
- manifest 来源不稳定
- 难做重建和复现
- 下架、回滚、重打包都很麻烦
- 后续签名体系会越来越复杂

所以客户端应当是：

- 浏览器
- 安装器
- 更新器

而不是发布器。

## 4. 中心仓库建议结构

官方插件市场仓库建议长这样：

```text
.github/
  ISSUE_TEMPLATE/
    plugin-market-submit.yml
  workflows/
    plugin-market-build.yml
plugins-list/
  plugin-source.example.json
  <plugin-id>.json
tool/
  generate_plugin_market_index.dart
scripts/
  sync-plugin-sources.ps1
  package-plugin-sources.ps1
dist/
  plugins/
  plugin-market-index.json
```

说明：

- `plugins-list/` 存“来源声明”，不是插件源码
- 插件源码始终在作者自己的仓库
- `dist/plugins/` 和索引是 CI 构建产物

## 5. 来源声明文件

每个已收录插件在 `plugins-list/` 下对应一个 JSON 文件。

示例见：

- [plugins-list/plugin-source.example.json](/e:/HDMXDownloadManagerX/HDMX-Download-Manager-X/plugins-list/plugin-source.example.json)

建议字段：

```json
{
  "id": "hdmx.example.demo",
  "repo": "https://github.com/example/hdmx-plugin-demo",
  "branch": "main",
  "pluginPath": ".",
  "channel": "stable",
  "reviewStatus": "draft",
  "submitter": "github:example",
  "notes": "Optional review notes"
}
```

字段约定：

- `id` 必须和插件仓库中的 `plugin.json.id` 一致
- `repo` 当前优先支持 GitHub 仓库地址
- `branch` 默认 `main`
- `pluginPath` 表示插件在仓库内的相对目录，默认 `.`
- `reviewStatus` 允许 `draft`、`published`、`removed`

## 6. 插件作者仓库要求

作者仓库至少要满足：

- 插件目录里存在 `plugin.json`
- `plugin.json` 满足 HDMX 宿主校验规则
- `entry` 指向实际入口文件
- 仓库是公开可访问的

本地 `plugin.json` 模板见：

- [plugins/plugin.json.example](/e:/HDMXDownloadManagerX/HDMX-Download-Manager-X/plugins/plugin.json.example)

## 7. 审核流

推荐流程：

1. 作者提交 Issue
2. 维护者检查仓库地址、许可证、`plugin.json`、基本功能说明
3. 通过后在 `plugins-list/` 新增或更新一个来源声明 JSON
4. 合并后触发 CI
5. CI 生成包和索引
6. 客户端读取最新索引后可安装

如果插件需要下架：

- 不删除历史记录
- 只把 `reviewStatus` 改成 `removed`

## 8. CI 流程

建议 CI 分三步：

1. `sync`
   拉取 `plugins-list` 指向的源码仓库，把插件目录同步到临时工作区

2. `package`
   对每个同步到的插件目录执行打包，生成 `.hdmx-plugin.zip`

3. `index`
   读取同步后的 `plugin.json` 和打包结果，生成官方 `plugins.json`

本仓库已提供对应骨架：

- [scripts/sync-plugin-sources.ps1](/e:/HDMXDownloadManagerX/HDMX-Download-Manager-X/scripts/sync-plugin-sources.ps1)
- [scripts/package-plugin-sources.ps1](/e:/HDMXDownloadManagerX/HDMX-Download-Manager-X/scripts/package-plugin-sources.ps1)
- [tool/generate_plugin_market_index.dart](/e:/HDMXDownloadManagerX/HDMX-Download-Manager-X/tool/generate_plugin_market_index.dart)
- [plugin-market-build.yml](/e:/HDMXDownloadManagerX/HDMX-Download-Manager-X/.github/workflows/plugin-market-build.yml)

## 9. 客户端职责

HDMX 客户端只做这些事：

- 拉取官方 `plugins.json`
- 展示插件列表
- 下载官方打包产物
- 安装、更新、卸载插件

客户端不负责：

- 审核
- 直接上传二进制插件包
- 直接信任第三方仓库里的任意压缩包

## 10. 安全边界

当前推荐边界：

- 官方市场只安装官方 CI 产出的包
- `plugin.json` 以作者仓库中的源码版本为准
- 商店索引可以继续配合哈希和签名使用

以后如果继续增强：

- 可对官方打包产物统一签名
- 可增加自动化审查和风险扫描
- 可增加来源仓库白名单和维护者信誉规则

## 11. 适合 HDMX 的原因

这套方案比“客户端上传 zip”更适合 HDMX，因为：

- 你已经有 `plugin.json` 和本地打包逻辑
- 你已经有插件商店索引模型
- 你现在差的是“官方市场仓库工作流”
- 这套方案正好补的是发布治理，不会推翻现有宿主代码

## 12. 最终结论

HDMX 应采用：

- `AstrBot` 的提交入口
- `BNCM` 的审核、打包、索引发布链路

也就是：

`提交仓库地址，不提交 zip；官方 CI 统一打包，客户端只消费官方产物。`
