# Hanabi 插件来源声明

这个目录不是插件源码目录。

这里放的是“官方市场收录的插件来源声明”，也就是：

- 插件来自哪个 GitHub 仓库
- 插件位于仓库的哪个目录
- 当前审核状态是什么

官方 CI 会读取这些 JSON：

1. 拉取作者仓库
2. 找到插件目录中的 `plugin.json`
3. 自动打包
4. 自动生成官方插件索引

最小示例见：

- [plugin-source.example.json](plugin-source.example.json)

完整的审核、构建与部署流程见：

- [插件市场设计](../docs/plugin/PLUGIN_MARKET_DESIGN_CN.md)
- [插件发布指南](../docs/plugin/PLUGIN_PUBLISH_FLOW_CN.md)
