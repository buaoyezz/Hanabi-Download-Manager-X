## V1.3.0 更新日志

### Tips:
> 全新1.3.0来袭，包含大量核心引擎优化、代理支持、UI 改进和新功能
> 强烈推荐所有用户更新到此版本

### 核心引擎优化 (NSFX):
[+] 重写 auto 模式分段/线程算法，保守稳定策略，避免过多连接 (commit: 1a73782)
[+] 动态检查间隔自适应文件大小（大文件10s/中文件5s/小文件3s） (commit: 1a73782)
[+] 进度漂移校准阈值改为文件大小的 0.1%，最小 256KB (commit: 1a73782)
[+] 新增 24 小时下载超时保护，防止服务器不可用时无限卡住 (commit: 1a73782)
[+] 新增全局带宽限速器，支持设置全局速度上限 (commit: d207a02)
[+] 速度历史记录持久化到 JSON 文件，重启后保留 (commit: d207a02)

### 代理支持:
[+] 新增系统代理支持（默认 system 模式，Clash Verge 7897 端口） (commit: 4ae0b4a, ffa7f12)
[+] 代理设置 UI：支持 system/http/socks5 类型切换、认证配置 (commit: 4ae0b4a)
[+] 代理自动降级：代理不可达时自动切换直连，下次任务重新尝试代理 (commit: 2b887b0)
[+] 三层代理 fallback：探测阶段/Isolate 下载/单线程下载均检测 502/503/504/407 并自动直连 (commit: aae7f3c)

### 界面与交互改进:
[+] 更新日志弹窗 glassmorphism 毛玻璃效果 + ShaderMask 渐隐滚动 (commit: cf0ae7e)
[+] 弹窗窗口 CSS 完全重写，与主程序 AppTheme 设计系统对齐 (commit: 7b2671e)
[+] 弹窗窗口自动根据内容高度伸缩（200~500px） (commit: 06b8f7f)
[+] 弹窗窗口弹出时自动置顶获取焦点，但不永久置顶 (commit: 06b8f7f)
[+] 窗口最大化/最小化卡顿优化 (commit: 04c4172)
[+] 下载列表/已完成列表加载动画 (commit: 7906911)
[+] 速度图表嵌入下载卡片背景，曲线宽度与下载进度同步 (commit: 7906911)
[+] 重写开发者设置页面布局 (commit: 2977a9d)

### 新功能:
[+] 新增速度图表组件（霜冻/位置/颜色可配置） (commit: d207a02, d684d6e)
[+] 新增外观设置页面：图表霜冻效果、位置、颜色选项 (commit: d684d6e)
[+] 新增连接调试页面，网络诊断工具 (commit: 7148cae)
[+] 新增 6 语言完整国际化（图表、代理、调试、外观相关） (commit: fc53337)

### Bug 修复与稳定性:
[+] 修复代理开启时访问本地地址返回 502 不触发 fallback 的问题 (commit: aae7f3c)
[+] 修复 Isolate 下载遇到代理错误时无限重试 500 次的问题 (commit: aae7f3c)

### 清理:
[+] 移除未使用的 settings_page_old.dart (commit: 9f06183)
[+] 更新构建脚本 (commit: a8d0889)

### 自定义语言包支持:
[+] 新增自定义语言包系统，支持用户创建和使用自定义语言 (commit: 1971d80)
[+] 优先读取 @@languageName 作为语言包名称，避免与翻译键冲突 (commit: 1971d80)
[+] 优化语言选择器显示，移除 localeTag 后缀，添加文本溢出处理 (commit: 31ffc07)
[+] 添加喵喵语(中文)作为自定义语言包示例 (commit: 523ed99)
[+] 添加自定义语言包文档（中英文）和模板文件 (commit: 88ebe23)
[+] 集成 LocalizationService 和 FallbackLocalizationsDelegate 到主应用 (commit: 34ee887)

---
### 文件:
>[HanabiDownloadManagerX_V1.3.0.zip](https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.3.0/HanabiDownloadManagerX_V1.3.0.zip)
sha256:TBD
>[chrome_extension.zip](https://github.com/buaoyezz/Hanabi-Download-Manager-X/releases/download/V1.0.0/chrome_extension.zip)
sha256:766d08b523e616cd9dde4ec079519a6720e6defd3b95ebecee6aef161612ff55
### 扩展:
>[Hanabi Download Manager X Browser Extension - Edge](https://microsoftedge.microsoft.com/addons/detail/hanabi-download-managerx-/nifalaonnaeobogcnhfoeaklpihcaeia)

Official Website: [https://x.zzbuaoye.top](https://x.zzbuaoye.top)
**Full Changelog**: [https://github.com/buaoyezz/Hanabi-Download-Manager-X/compare/V1.2.11...V1.3.0](https://github.com/buaoyezz/Hanabi-Download-Manager-X/compare/V1.2.11...V1.3.0)
