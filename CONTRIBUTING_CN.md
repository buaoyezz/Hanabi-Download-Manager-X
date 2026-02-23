# 贡献指南

[English](CONTRIBUTING.md) | 中文

感谢你对 Hanabi Download Manager X 的关注！我们欢迎各种形式的贡献。

## 贡献方式

- 报告 Bug
- 提出新功能建议
- 改进文档
- 提交代码修复或新功能
- 翻译文档或界面

## 开发环境设置

### 前置要求

- Flutter SDK 3.0.0+
- Dart SDK 3.0.0+
- Python 3.12.6+ (用于旧内核)
- Git
- Visual Studio Code (推荐) 或 Android Studio

### 克隆仓库

```bash
git clone https://github.com/buaoyezz/hanabi-download-manager-x.git
cd hanabi-download-manager-x
```

### 安装依赖

```bash
flutter pub get
```

### 运行开发版本

```bash
flutter run -d windows
```

## 代码规范

### Dart 代码风格

遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 规范：

- 使用 `lowerCamelCase` 命名变量和方法
- 使用 `UpperCamelCase` 命名类和枚举
- 使用 `snake_case` 命名库和文件
- 每行代码不超过 80 字符（建议）
- 使用 `dartfmt` 格式化代码

### 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<type>(<scope>): <subject>

<body>

<footer>
```

类型 (type)：
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `perf`: 性能优化
- `test`: 测试相关
- `chore`: 构建/工具链更新

示例：
```
feat(download): 添加多线程下载支持

- 实现动态分段算法
- 添加线程数配置选项
- 优化内存使用

Closes #123
```

## 提交 Pull Request

### 1. Fork 仓库

点击右上角 "Fork" 按钮，将仓库 fork 到你的账号下。

### 2. 创建分支

```bash
git checkout -b feature/your-feature-name
```

分支命名规范：
- `feature/xxx` - 新功能
- `fix/xxx` - Bug 修复
- `docs/xxx` - 文档更新
- `refactor/xxx` - 代码重构

### 3. 提交代码

```bash
git add .
git commit -m "feat: 添加新功能"
git push origin feature/your-feature-name
```

### 4. 创建 Pull Request

1. 访问你的 fork 仓库
2. 点击 "New Pull Request"
3. 填写 PR 标题和描述
4. 等待代码审查

## PR 检查清单

提交 PR 前请确认：

- [ ] 代码遵循项目规范
- [ ] 通过所有测试
- [ ] 添加必要的注释
- [ ] 更新相关文档
- [ ] 提交信息清晰明确
- [ ] 没有合并冲突

## 报告 Bug

使用 [GitHub Issues](https://github.com/buaoyezz/hanabi-download-manager-x/issues) 报告 Bug。

请提供以下信息：

- 操作系统版本
- Flutter 版本
- 应用版本
- 复现步骤
- 预期行为
- 实际行为
- 错误日志（如有）
- 截图（如有）

## 功能建议

使用 [GitHub Issues](https://github.com/buaoyezz/hanabi-download-manager-x/issues) 提出功能建议。

请描述：

- 功能描述
- 使用场景
- 预期效果
- 可能的实现方案（可选）

## 文档贡献

文档位于以下位置：

- `README.md` - 英文文档
- `README_CN.md` - 中文文档
- `HowToUse.md` - 使用指南
- `lib/l10n/` - 多语言翻译

## 社区准则

- 尊重他人，友善交流
- 建设性地提出意见
- 接受不同观点
- 专注于项目本身

## 许可证声明

提交代码即表示你同意将代码以 GPL-3.0 协议开源。

## 联系方式

- GitHub Issues: [提交问题](https://github.com/buaoyezz/hanabi-download-manager-x/issues)
- Email: [联系作者](mailto:support@zzbuaoye.top)
