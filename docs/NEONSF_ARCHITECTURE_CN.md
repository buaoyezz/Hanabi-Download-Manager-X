# NeoNSFX 架构与迁移边界

状态：NeoNSFX 0.1.0  
日期：2026-07-19

## 1. 产品边界

- NSFX 继续作为默认、稳定和长期兜底内核。
- Auto 是双内核自动路由模式；NSFX 与 NeoNSFX 也都可以被单独指定。
- NeoNSFX 是并行开发的新内核，初始版本为 `0.1.0`。
- 切换只影响新任务；任务创建后由不可变 `kernelId` 绑定原内核。
- 不在运行中迁移任务，不让两个内核同时写同一个目标文件。
- 只有 Auto 可以在 NeoNSFX 接收任务前回退 NSFX；显式选择 NeoNSFX
  时不静默换核。原生侧确认接收后任何模式都不再自动换核。

## 2. 技术选择

NeoNSFX 使用常驻 `.NET 8 NativeAOT` 侧车，而不是在 Dart 中继续堆叠
isolate，也不自研高复杂度网络协议栈。

- `HttpClient` / `SocketsHttpHandler`：连接池、TLS、HTTP/1.1、HTTP/2、
  HTTP/3、系统代理和显式代理。
- 原生异步 `FileStream` / `RandomAccess.WriteAsync`：直连和并行 Range
  字节直接写入 `.neonsf.partial`，不经过 Dart 数据面。
- JSONL stdin/stdout：Dart 只传控制命令并消费增量事件。
- NativeAOT：发布为单个 `HanabiNeoNSF.exe`，不要求用户安装 .NET。
- 传输实现保持 provider 边界，未来可以接入经过基准和维护性验证的库，
  不需要替换任务控制面与持久化协议。

## 3. 当前执行范围

NeoNSFX 0.1.0 接收所有 HTTP/HTTPS 大小范围：

- 已知且小于 8 MiB 的任务直接发起真实 GET，避免小文件元数据预探测。
- 大文件和未知大小任务先用 HEAD 解析长度、Range 能力和验证器。
- 大于等于 8 MiB 且支持 Range 时，按 4 MiB 最小分段规划最多 16 路并发。
- Range 不可用或服务端拒绝分段时收敛为单连接顺序下载。
- 并行路径预分配 partial 文件，并用 `.neonsf.state` 保存分段进度、
  ETag、Last-Modified 和总长度。
- 支持暂停/恢复、取消、失败重试、代理、HTTP 版本策略、Referer、Cookie、
  User-Agent 和自定义 Header。

## 4. 双内核路由

`KernelManager` 是永久双内核路由器：

1. NSFX 始终启动，并持有唯一的浏览器扩展 HTTP 监听器。
2. NeoNSFX 在 Auto/NeoNSFX 被选择或检测到 Neo 历史任务时启动；NSFX
   模式下也可在切到 Auto 时无重启启动。
3. 浏览器 API、UI 和系统服务都通过 `KernelManager` 发命令。
4. 暂停、续传、取消、重命名和移动按任务 `kernelId` 返回原内核。
5. 任务列表、进度事件、完成事件和统计在路由层聚合。

NeoNSFX 使用独立目录：`~/.hdmx/kernel/neo_nsf/`。存储 ID 保持不变以兼容
已有数据。任务状态和恢复所需的
请求 Header 一起持久化；重启时活动任务恢复为暂停，不会被 NSFX 误读。

## 5. 速度口径

速度只在原生接收并写入响应 body 的位置计算：

- `rawInstantBps`：单个采样区间的原始速度。
- `windowBps` / `instantBps`：250 ms 采样后的 EWMA 显示速度。
- `averageBps`：累计 wire bytes / active transfer time。
- `activeTicks`：不包含暂停和重试退避的活动传输时钟。

小文件在第一个显示窗口前完成时不伪造瞬时速度，只在完成事件提供真实
平均速度。

## 6. 稳定性规则

- partial 文件关闭后才原子替换最终文件。
- Range 响应的起点、终点或资源总长度不匹配时永久失败，禁止拼接错误数据。
- 并行恢复必须通过 ETag 或 Last-Modified 验证；验证器变化时从零重建。
- 连接中断、读取超时、HTTP 408/429/5xx 可以退避重试。
- 暂停、取消和重试退避共用请求级取消句柄，不销毁连接池。
- 失败、完成和取消的原生任务立即释放，允许同 ID 显式重试。
- 直连、系统代理和显式 HTTP/SOCKS 代理使用不同连接池键。

## 7. 非复制原则

IDM、Ghost Downloader 3 和其他下载器只用于黑盒行为、公开协议事实和性能
方法论参考。NeoNSFX 不复制它们的源码、类结构、调度器、任务格式、文件格式、
界面或命名。任何实现都必须由本项目自行设计，并可通过本仓库测试解释其行为。

## 8. 后续迁移顺序

1. 增加跨任务全局/主机并发预算和自适应降并发历史。
2. 为并行 checkpoint 增加显式格式版本、批量刷盘节流和崩溃注入测试。
3. 加入动态分段、慢连接拆分和公网性能回归，但不改变任务归属规则。
4. 继续改进 NSFX，确保它始终是独立可用的稳定内核。
5. 只有当长期稳定性、恢复正确性和性能门槛都通过后，才讨论默认内核变更；
   当前默认仍为 NSFX。
