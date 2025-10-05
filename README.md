# HDM-X 下载管理器

> **Hanabi Download Manager X** - 重新定义下载体验，性能与优雅并存

![HDM-X Logo](https://img.shields.io/badge/HDM--X-Download%20Manager-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/Version-1.0.0[X]-green?style=for-the-badge)
![Python](https://img.shields.io/badge/Powered%20by-NSF--X%20Python-orange?style=for-the-badge)

## ✨ 特性亮点

- 🚀 **NSF-X引擎**: 基于Python的高性能下载引擎，支持SSL自动回退
- ⚡ **极致性能**: 优化的HTTP下载器，智能处理网络异常
- 🔄 **断点续传**: 智能恢复中断的下载任务
- 🎯 **多线程下载**: 自动分段下载，充分利用带宽
- 🎨 **现代UI**: 基于Flet的精美用户界面
- 🌐 **浏览器集成**: 支持Chrome/Firefox扩展
- 📊 **实时监控**: 详细的下载进度和统计信息
- 🛡️ **稳定可靠**: 错误处理和恢复机制

## 🎯 快速开始

### 快速启动

1. **安装依赖**
   ```bash
   pip install -r requirements.txt
   ```

2. **启动应用**
   ```bash
   python main.py
   ```

### 依赖修复 (遇到问题时)

如果遇到依赖问题：
```bash
python install_deps.py
```

## 🏗️ 系统要求

- **Python**: 3.8+
- **操作系统**: Windows 10+, macOS 10.15+, Linux
- **内存**: 最低256MB，推荐512MB+
- **磁盘**: 50MB可用空间

## 📋 NSF-X 引擎特性

| 特性 | 支持情况 | 说明 |
|------|----------|------|
| 下载速度 | ⭐⭐⭐⭐⭐ | 优化的HTTP客户端 |
| SSL处理 | ⭐⭐⭐⭐⭐ | 自动SSL回退机制 |
| 断点续传 | ⭐⭐⭐⭐⭐ | 智能Range请求处理 |
| 内存使用 | ⭐⭐⭐⭐ | 流式下载，低内存占用 |
| 稳定性 | ⭐⭐⭐⭐⭐ | 完善的错误处理 |
| 部署简单 | ⭐⭐⭐⭐⭐ | 纯Python实现，无需编译 |

## 🔧 高级功能

### 浏览器扩展
1. 打开Chrome扩展管理页面
2. 启用开发者模式
3. 加载 `src/hdm_x/extensions/browser_extension` 目录
4. 在网页上右键选择"使用HDM-X下载"

### WebSocket API
HDM-X提供WebSocket API供第三方应用集成：
```javascript
const ws = new WebSocket('ws://localhost:9721');
ws.send(JSON.stringify({
    action: 'add_download',
    url: 'https://example.com/file.zip'
}));
```

### SSL证书处理
NSF-X引擎具备智能SSL处理能力：
1. 优先尝试安全SSL连接
2. 检测SSL证书问题时自动回退
3. 支持过期证书的测试下载

### 测试工具
```bash
# 安装项目依赖
python install_deps.py

# 测试NSF-X核心下载功能
python testFile/testNsfXCoreDownload.py

# 测试SSL回退机制
python testFile/testNsf416Fallback.py

# 测试进度刷新
python testFile/testProgressRefresh.py
```

## 📊 性能基准

基于1MB测试文件下载 (100Mbps网络):

| 指标 | NSF-X引擎 | 说明 |
|------|-----------|------|
| 下载速度 | 接近带宽上限 | 优化的HTTP客户端 |
| 内存使用 | < 50MB | 流式处理 |
| CPU使用 | < 10% | 异步I/O |
| SSL回退 | < 1秒 | 自动检测和切换 |
| 启动时间 | < 3秒 | 纯Python实现 |

## 🛠️ 开发指南

### 项目结构
```
HDM-X/
├── src/hdm_x/              # 核心代码
│   ├── core/
│   │   ├── nsfXCore/       # NSF-X下载引擎
│   │   ├── managers/       # 核心管理器
│   │   └── models/         # 数据模型
│   ├── ui/                 # 用户界面
│   ├── utils/              # 工具函数
│   └── assets/             # 资源文件
├── browser_extension/      # 浏览器扩展
├── testFile/              # 测试文件
├── main.py                # 主启动器
└── README.md              # 本文件
```

### 贡献代码
1. Fork项目
2. 创建特性分支: `git checkout -b feature/amazing-feature`
3. 提交更改: `git commit -m 'Add amazing feature'`
4. 推送分支: `git push origin feature/amazing-feature`
5. 创建Pull Request

## 🐛 故障排除

### 常见问题

**Q: Python依赖错误**
```bash
# 升级pip
python -m pip install --upgrade pip

# 重新安装依赖
pip install --force-reinstall -r requirements.txt
```

**Q: SSL证书错误**
- NSF-X引擎会自动处理SSL证书问题
- 支持过期证书的自动回退下载
- 无需手动配置

**Q: 下载速度慢**
- 检查网络连接
- NSF-X引擎已优化性能
- 支持断点续传和多线程下载

### 获取帮助
- 📖 查看清理总结: [CLEANUP_SUMMARY.md](CLEANUP_SUMMARY.md)
- 🔍 运行依赖安装: `python install_deps.py`
- 🧪 运行测试: `python testFile/testNsfXCoreDownload.py`
- 💬 提交Issue到GitHub

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- [Python](https://www.python.org/) - 编程语言
- [Flet](https://flet.dev/) - Python UI框架
- [aiohttp](https://docs.aiohttp.org/) - 异步HTTP客户端
- [aiofiles](https://github.com/Tinche/aiofiles) - 异步文件操作

## 🌟 Star History

如果这个项目对你有帮助，请给我们一个Star ⭐

---

**HDM-X** - 让下载变得简单而强大 | Made with ❤️ by ZZBUAOYE