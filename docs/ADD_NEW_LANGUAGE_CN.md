# 添加新语言翻译

[English Version](ADD_NEW_LANGUAGE.md)

本指南说明如何为 Hanabi Download Manager X 添加新的语言翻译。

---

## 目录

- [概述](#概述)
- [前置要求](#前置要求)
- [分步指南](#分步指南)
- [文件结构](#文件结构)
- [翻译键值](#翻译键值)
- [测试翻译](#测试翻译)
- [故障排除](#故障排除)

---

## 概述

Hanabi Download Manager X 使用 ARB (Application Resource Bundle) 文件进行国际化。每种语言在 `lang/` 目录中定义为单独的 `.arb` 文件。

应用程序支持：
- 内置语言：英语 (en)、中文 (zh)
- 自定义语言包：从 `lang/` 目录加载的任何语言

---

## 前置要求

开始之前，请确保您具备：
- 文本编辑器（VS Code、Sublime Text、Notepad++ 等）
- 基本的 JSON 格式理解
- 中文语言包（`lib/l10n/app_zh.arb`）作为参考

---

## 分步指南

### 步骤 1：创建语言包文件

1. 导航到项目根目录的 `lang/` 文件夹
2. 创建一个名为 `app_<locale>.arb` 的新文件
   - 日语：`app_ja.arb`
   - 韩语：`app_ko.arb`
   - 法语：`app_fr.arb`
   - 德语：`app_de.arb`

### 步骤 2：设置文件结构

打开新文件并添加以下必需字段：

```json
{
  "@@locale": "ja",
  "@@languageName": "日本語",
  "appTitle": "Hanabi Download Manager X"
}
```

**必需字段：**
- `@@locale`：区域代码（例如 `ja`、`ko`、`fr`、`de`）
- `@@languageName`：在语言选择器中显示的名称
- `lib/l10n/app_zh.arb` 中的所有其他翻译键

### 步骤 3：复制翻译键

1. 打开 `lib/l10n/app_zh.arb` 作为参考
2. 复制所有翻译键（除了以 `@@` 开头的）
3. 将它们粘贴到新语言文件中
4. 将每个值翻译为目标语言

**示例：**

```json
{
  "@@locale": "ja",
  "@@languageName": "日本語",
  "appTitle": "Hanabi Download Manager X",
  "aboutPageTitle": "について",
  "settingsTitle": "設定",
  "downloadEmptyTitle": "ダウンロードがありません",
  "downloadEmptySubtitle": "新規ボタンをクリックしてダウンロードタスクを追加"
}
```

### 步骤 4：处理占位符

某些翻译字符串包含格式为 `{variable}` 的占位符。保持这些占位符不变：

```json
{
  "aboutVersionLabel": "v{version}",
  "appearanceLanguageSwitchedTo": "已切换为 {language}",
  "updateAvailableMessage": "新版本 {newVersion} 可用"
}
```

### 步骤 5：保存并验证

1. 使用 UTF-8 编码保存文件
2. 确保 JSON 语法有效（如需要可使用 JSON 验证器）
3. 检查所有必需的键是否存在

---

## 文件结构

### 目录布局

```
project-root/
├── lang/                          # 自定义语言包
│   ├── app_ja.arb                # 日语
│   ├── app_ko.arb                # 韩语
│   └── app_fr.arb                # 法语
└── lib/
    └── l10n/                      # 内置语言
        ├── app_en.arb            # 英语（参考）
        └── app_zh.arb            # 中文（参考）
```

### ARB 文件格式

```json
{
  "@@locale": "locale_code",
  "@@languageName": "显示名称",
  "key1": "翻译 1",
  "key2": "翻译 2",
  "keyWithPlaceholder": "包含 {variable} 的文本"
}
```

---

## 翻译键值

### 键值分类

应用程序有大约 1,235 个翻译键，分为以下类别：

1. **通用界面**
   - `appTitle`、`aboutPageTitle`、`settingsTitle`
   
2. **导航**
   - `homeNavDownloading`、`homeNavCompleted`、`homeNavSettings`
   
3. **下载管理**
   - `downloadEmptyTitle`、`addDownloadTitle`、`fileName`、`speed`
   
4. **设置**
   - `settingsAutoStartTitle`、`settingsDownloadPathTitle`
   
5. **外观**
   - `appearanceLanguageTitle`、`appearanceWindowSizeSection`
   
6. **通知**
   - `settingsAutoStartEnabledTitle`、`updateAvailableTitle`

### 查找所有键

要查看所有可用的翻译键：
1. 打开 `lib/l10n/app_zh.arb`
2. 所有键（除了以 `@@` 开头的）都需要翻译

---

## 测试翻译

### 步骤 1：加载语言包

1. 启动 Hanabi Download Manager X
2. 导航至：**设置** → **界面设置** → **语言**
3. 点击 **刷新语言包** 按钮
4. 您的新语言应该出现在下拉列表中

### 步骤 2：切换语言

1. 从下拉列表中选择新语言
2. 应用程序将使用您的翻译重新加载
3. 验证所有文本是否正确显示

### 步骤 3：检查问题

查找：
- 缺失的翻译（显示英语回退）
- 不正确的占位符
- 文本溢出或布局问题
- 特殊字符未正确显示

---

## 故障排除

### 语言未出现

**问题：** 您的语言未在语言选择器中显示。

**解决方案：**
1. 验证文件位于 `lang/` 目录中
2. 检查文件名是否遵循 `app_<locale>.arb` 模式
3. 确保 `@@locale` 和 `@@languageName` 设置正确
4. 再次点击 **刷新语言包**

### JSON 语法错误

**问题：** 应用程序显示"加载语言包失败"错误。

**解决方案：**
1. 使用在线验证器验证 JSON 语法
2. 检查：
   - 条目之间缺少逗号
   - 字符串中未转义的引号（使用 `\"` 表示引号）
   - 缺少右花括号 `}`
3. 确保使用不带 BOM 的 UTF-8 编码

### 缺失翻译

**问题：** 某些文本显示为英语而不是您的语言。

**解决方案：**
1. 将您的文件与 `lib/l10n/app_zh.arb` 进行比较
2. 确保所有键都存在
3. 检查没有空字符串值

### 特殊字符未显示

**问题：** 中文、日文或阿拉伯文等字符未正确显示。

**解决方案：**
1. 使用 UTF-8 编码保存文件
2. 避免使用带 BOM 的 UTF-8
3. 先用简单字符测试

---

## 示例：创建日语翻译

### 1. 创建文件

创建 `lang/app_ja.arb`：

```json
{
  "@@locale": "ja",
  "@@languageName": "日本語",
  "appTitle": "Hanabi Download Manager X",
  "aboutPageTitle": "について",
  "settingsTitle": "設定",
  "homeNavDownloading": "ダウンロード中",
  "homeNavCompleted": "完了",
  "homeNavSettings": "設定",
  "downloadEmptyTitle": "ダウンロードがありません",
  "downloadEmptySubtitle": "新規ボタンをクリックしてダウンロードタスクを追加",
  "fileName": "ファイル名",
  "speed": "速度",
  "status": "状態"
}
```

### 2. 加载并测试

1. 打开应用程序
2. 转到 设置 → 界面设置 → 语言
3. 点击 **刷新语言包**
4. 从下拉列表中选择 **日本語**
5. 验证翻译

---

## 最佳实践

### 翻译指南

1. **一致性**：在整个翻译中使用一致的术语
2. **上下文**：翻译时考虑 UI 上下文
3. **长度**：保持翻译长度与原文相似，避免布局问题
4. **正式程度**：匹配原文的语气
5. **占位符**：永远不要翻译占位符名称，如 `{version}`

### 质量检查清单

- [ ] `app_zh.arb` 中的所有键都存在
- [ ] `@@locale` 和 `@@languageName` 设置正确
- [ ] JSON 语法有效
- [ ] 文件使用 UTF-8 编码保存
- [ ] 占位符保持不变
- [ ] 翻译在上下文中适当
- [ ] 没有空字符串值
- [ ] 在应用程序中测试过

---

## 贡献您的翻译

如果您想将翻译贡献给项目：

1. 在应用程序中彻底测试
2. 使用您的 `.arb` 文件创建拉取请求
3. 包含语言的简要说明
4. 提及任何特殊注意事项

详见 [CONTRIBUTING_CN.md](../CONTRIBUTING_CN.md)。

---

## 其他资源

- [Flutter 国际化](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [ARB 文件格式](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- [JSON 验证器](https://jsonlint.com/)
- [区域代码](https://www.iana.org/assignments/language-subtag-registry/language-subtag-registry)

---

## 支持

如果您遇到问题或有疑问：
- 在 GitHub 上开启 issue
- 查看现有翻译作为参考
- 参考 `lib/l10n/app_zh.arb` 作为完整键列表

---

**最后更新：** 2024-01-20
