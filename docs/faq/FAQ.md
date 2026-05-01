# 技术 FAQ

本文档记录开发过程中遇到的技术问题、踩坑记录及解决方案。

## 目录

- [构建与编译](#构建与编译)
- [Flutter 相关](#flutter-相关)
- [NSFX 内核](#nsfx-内核)
- [网络与下载](#网络与下载)
- [UI 与主题](#ui-与主题)
- [性能优化](#性能优化)
- [跨平台兼容](#跨平台兼容)

---

## 构建与编译

### Windows 平台 rhttp 插件构建失败

**问题**：`flutter run` 时卡在 `rhttp` 插件构建步骤。

**原因**：`rhttp 0.15.1` 在 Windows 上有两个已知问题：
1. `resolve_symlinks.ps1` 使用 `Get-Item $realPath` 无法读取 AppData 隐藏目录
2. `run_build_tool.cmd` 未设置 `FLUTTER_ROOT` 时缺少 Dart fallback

**解决方案**：在 `flutter pub get` 后执行补丁脚本：
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply-rhttp-windows-fix.ps1
```

该脚本会：
- 将 `Get-Item $realPath` 改为 `Get-Item -Force $realPath`
- 在 `run_build_tool.cmd` 中添加 `SET DART=dart` fallback

建议在清理 Pub Cache 或重新执行 `flutter pub get` 后重跑一次。

### Pub Cache 缓存问题

**问题**：依赖版本不一致或插件构建残留导致编译失败。

**解决方案**：
```bash
flutter pub cache clean
flutter pub get
powershell -ExecutionPolicy Bypass -File .\scripts\apply-rhttp-windows-fix.ps1
```

### flutter_rust_bridge 版本冲突

**问题**：`rhttp` 依赖的 `flutter_rust_bridge` 版本与项目不兼容。

**解决方案**：在 `pubspec.yaml` 中使用 `dependency_overrides` 锁定版本：
```yaml
dependency_overrides:
  flutter_rust_bridge: 2.11.1
```

---

## Flutter 相关

### Provider 状态管理节流

**问题**：下载进度更新频繁，直接调用 `notifyListeners()` 会导致 UI 卡顿甚至 Windows 消息队列溢出。

**解决方案**：在 `IntegratedDownloadService` 中实现节流通知：
- 覆盖 `notifyListeners()` 实现 500ms 最小间隔
- 关键变化（状态/文件大小变更）通过 `notifyNow()` 立即发送
- 普通进度更新被合并，避免频繁刷新

```dart
@override
void notifyListeners() {
  // 500ms 节流
}

void notifyNow() {
  // 立即通知，用于关键状态变化
}
```

### ChangeNotifier 服务数量过多

**现状**：项目使用 13+ 个 `ChangeNotifier` 服务，包括：
- `KernelManager`、`IntegratedDownloadService`、`AppLoggerService`
- `DownloadFailureStatsService`、`NetworkStatusService`
- `ClientConfigService`、`FontService`、`LocalizationService` 等

**注意**：
- 使用 `ChangeNotifierProvider.value` 传递已创建的实例，避免重复创建
- 服务销毁时需手动调用 `dispose()` 取消 Stream 订阅

### bitsdojo_window 窗口大小 bug

**问题**：窗口初始化后大小不正确。

**Workaround**（`main.dart` 第 431 行）：
```dart
// bitsdojo_window 的 bug workaround
// 窗口显示后再次强制设置大小
```

---

## NSFX 内核

### NSFX 启动失败排查

**问题**：内核启动后无法响应 API 请求。

**排查步骤**：
1. 检查端口 9710 是否被占用
2. 查看 `KernelManager` 的 `_startupProgress` 和 `_startupStatus` 状态
3. 确认 NSFX 可执行文件路径正确

**架构说明**：
- `KernelManager` 采用单例模式，继承 `ChangeNotifier`
- 启动进度通过 Stream 向 UI 反馈（0-1 进度值）
- 启动时触发 `_immediateFirstLoad()` 快速重试机制（500ms * 10 次）

### WebSocket 端口冲突

**项目使用两个端口**：
- **9710**：NSFX HTTP Server（浏览器扩展 API）
- **19998**：Popup Progress WebSocket（弹窗进度推送）

**注意事项**：
- `PopupProgressService` 每 200ms 广播进度到所有已连接的 WebSocket 客户端
- 使用 `WebSocketTransformer.upgrade(request)` 处理 HTTP 升级请求
- 确保防火墙未拦截这两个端口

### 任务存储原子写入

**实现**：NSFX 使用原子写入机制防止数据损坏：
1. 先写入 `.tmp` 临时文件
2. 写入完成后 `rename` 为正式文件
3. 保留 `.bak` 备份用于恢复

**路径结构**：
```
.nsfx_temp/
└── {taskId}/
    └── 分段临时文件
```

取消下载时会自动清理该目录。

---

## 网络与下载

### HTTP 版本自适应降级

**实现**：`NsfxHttpClient` 支持 HTTP 版本自动降级链：
```
HTTP/3 → HTTP/2 → HTTP/1.1
```

**场景**：部分服务器不支持 HTTP/3 时自动降级，避免连接失败。

### 代理自适应与 Bad Proxy 缓存

**实现**：`NsfxProxyRuntime` 维护 bad proxy 缓存：
- 代理连接失败后自动加入缓存
- 后续请求自动切换直连
- 避免反复尝试无效代理

### 断点续传与 HTTP Range

**注意事项**：
- 并非所有服务器都支持 `Range` 请求头
- 服务器返回 `206 Partial Content` 时才支持断点续传
- 部分 CDN 配置可能导致 Range 请求失效

**调试方法**：检查 NSFX 日志中的 HTTP 响应状态码。

### 多线程并发数限制

**默认配置**：最多 8 线程并发下载。

**建议**：
- 小文件（<10MB）：单线程即可
- 中等文件（10MB-500MB）：4-8 线程
- 大文件（>500MB）：可适当增加到 16 线程（需服务器支持）

**注意**：线程数过多可能导致：
- 服务器封禁 IP
- 本地网络拥塞
- 内存占用增加

---

## UI 与主题

### Fluent Design 组件样式覆盖

**问题**：`fluent_ui` 组件默认样式不符合项目需求。

**解决方案**：
- 使用 `FluentTheme` 自定义主题色
- 通过 `style` 属性覆盖单个组件样式
- 部分组件需自行封装（如 `TextBox`、`ToggleButton`）

### 高分屏缩放问题

**注意事项**：
- Windows 高分屏（DPI > 100%）下可能出现 UI 错位
- `bitsdojo_window` 在高 DPI 下可能获取错误的窗口尺寸
- 建议使用 `isWindowMaximized()` (Win32 API) 检测最大化状态

---

## 性能优化

### 列表渲染优化

**实现**：日志页和下载列表使用优化策略：
- `SmoothListView.builder` 自定义封装
- `cacheExtent: 500` 控制预渲染范围
- `addAutomaticKeepAlives: false` 避免保持不可见项状态
- 每个列表项使用 `RepaintBoundary` 隔离重绘

**效果**：大量数据时保持流畅滚动。

### RepaintBoundary 使用

**现状**：项目中约 30+ 处使用 `RepaintBoundary`。

**适用场景**：
- 动画卡片（下载进度卡片）
- 页面过渡组件
- 玻璃特效卡片
- 频繁更新的独立组件

**注意**：过度使用可能增加内存，仅在必要时添加。

### Stream 订阅管理

**最佳实践**：
```dart
// 订阅
_progressSubscription = kernel.onProgress.listen(_handleProgress);

// 取消（在 dispose 或内核停止时）
await _progressSubscription?.cancel();
```

**内核层节流**：NSFX 进度推送有 100ms 最小间隔（`_minProgressEmitInterval`），通过 `_lastEmittedStatus` 和 `_lastEmittedTotalSize` 检测关键变化。

### 内存泄漏排查

**常见原因**：
1. Stream 订阅未取消
2. `ChangeNotifier` 未调用 `dispose()`
3. 定时器未取消

**排查工具**：
- Flutter DevTools Memory 面板
- `AppLoggerService` 记录服务生命周期

---

## 跨平台兼容

### Windows 路径处理

**问题**：Windows 文件路径包含非法字符或保留名称时会导致错误。

**实现**：文件名净化逻辑：
1. 过滤非法字符：`< > : " / \ | ? *`
2. 处理保留名称：`CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9`
3. 去除尾部点/空格
4. 路径规范化后转小写比较

```dart
p.normalize(task.filepath).toLowerCase()
```

### 平台检测

**现状**：代码中约 60 处使用 `Platform.isWindows` 检测。

**注意**：
- 几乎所有平台特定逻辑都有 guard
- 托盘、窗口管理、文件路径等均有平台差异

### 托盘实现与退出流程

**实现**：`SystemTrayService` 使用 `system_tray` 插件。

**退出流程**：
1. 销毁托盘图标
2. 停止内核（3 秒超时）
3. 调用原生关闭
4. `exit(0)` 兜底

**图标路径**：优先从 `data/flutter_assets/assets/logo/logo.ico` 加载。

### Windows Semantics Workaround

**问题**：Windows 平台上语义辅助功能可能导致 UI 异常。

**解决方案**：在 `main.dart` 和 `popup_window_bootstrap.dart` 中使用开关：
```dart
_disableWindowsSemanticsWorkaround = 
    kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
```

---

## 贡献

如有新的技术问题或解决方案，欢迎提交 Pull Request。
