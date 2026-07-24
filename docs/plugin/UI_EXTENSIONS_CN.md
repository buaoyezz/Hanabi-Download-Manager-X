# UI 扩展

插件可以通过 `ui_extensions` 声明设置页和侧边栏。控件由 Hanabi 渲染，插件不能注入 Flutter 代码。

## 挂载点

| 挂载点 | 说明 |
| --- | --- |
| `settings` | 插件管理页中的设置对话框。 |
| `sidebar` | 插件启用后出现的独立侧边栏页面。 |

## 设置页示例

```json
{
  "ui_extensions": {
    "settings": [
      {
        "type": "switch",
        "id": "auto_catch",
        "label": "自动接管",
        "description": "自动处理支持的下载链接。",
        "default": true,
        "icon": "fluent:settings"
      },
      {
        "type": "text_input",
        "id": "endpoint",
        "label": "服务地址",
        "placeholder": "http://127.0.0.1:6800"
      },
      {
        "type": "slider",
        "id": "connections",
        "label": "最大连接数",
        "min": 1,
        "max": 16,
        "divisions": 15,
        "default": 8
      },
      {
        "type": "dropdown",
        "id": "profile",
        "label": "下载策略",
        "default": "balanced",
        "options": [
          {"label": "节能", "value": "eco"},
          {"label": "均衡", "value": "balanced"},
          {"label": "性能", "value": "performance"}
        ]
      },
      {
        "type": "button",
        "id": "test_connection",
        "label": "测试连接",
        "action": "plugin.connection.test"
      }
    ]
  }
}
```

## 侧边栏示例

数组写法使用默认的底部位置：

```json
{
  "ui_extensions": {
    "sidebar": [
      {
        "type": "text",
        "id": "overview",
        "label": "远程下载",
        "description": "管理远程下载服务。"
      }
    ]
  }
}
```

对象写法可以指定导航位置：

```json
{
  "ui_extensions": {
    "sidebar": {
      "placement": "top",
      "controls": [
        {
          "type": "button",
          "id": "refresh",
          "label": "刷新",
          "action": "plugin.sidebar.refresh"
        }
      ]
    }
  }
}
```

| `placement` | 位置 |
| --- | --- |
| `top` | 下载中、已完成等主导航区域。 |
| `bottom` | 插件、设置、关于等工具区域。默认值。 |

## 控件类型

| `type` | 用途 | 关键字段 | 状态值 |
| --- | --- | --- | --- |
| `switch` | 布尔设置 | `default` | boolean |
| `text_input` | 单行文本 | `placeholder`、`default` | string |
| `button` | 执行命令 | `action` | 不写入状态 |
| `text` | 标题与说明 | `description` | 不写入状态 |
| `slider` | 数值范围 | `min`、`max`、`divisions` | number |
| `dropdown` | 单选列表 | `options`、`default` | 任意 JSON 标量 |

所有控件都支持：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 同一挂载点内唯一，不能为空。 |
| `label` | string | 用户可见标签，不能为空。 |
| `description` | string | 可选辅助说明。 |
| `default` | any | 首次显示时的默认值。 |
| `icon` | string | Fluent 图标名称，可带 `fluent:` 前缀。 |

## 状态变更方法

用户修改设置页后，宿主会保存完整状态并调用：

```text
onSettingsChanged
```

`params` 是设置页的完整状态对象：

```json
{
  "auto_catch": true,
  "endpoint": "http://127.0.0.1:6800",
  "connections": 8,
  "profile": "balanced"
}
```

侧边栏状态变化调用：

```text
onSidebarStateChanged
```

这两个通知当前为异步触发。宿主已经先保存状态，不会因为插件返回错误而回滚 UI。

## 按钮动作

按钮点击时，宿主调用 `action` 指定的方法，并把当前挂载点的完整状态作为 `params`：

```json
{
  "type": "button",
  "id": "test_connection",
  "label": "测试连接",
  "action": "plugin.connection.test"
}
```

方法名属于插件私有命名空间，建议采用 `<plugin-domain>.<resource>.<verb>` 风格，避免与 `hanabi.*` 宿主保留方法混淆。

当前 UI 不会自动把按钮返回的 `result` 合并到控件状态，也不会直接显示响应消息。需要更新展示时，应写入持久数据并在后续版本的 UI API 中接入；不要依赖未声明行为。

## 状态持久化

- 设置页状态由宿主按插件 ID 保存。
- 侧边栏状态使用独立命名空间保存。
- 插件升级后，同名控件 ID 会继续使用原值。
- 删除控件不会立即清理旧键；插件应忽略未知字段。
- 更改控件 ID 等同于创建新设置项。

## 主题覆盖（实验性）

声明 `theme_provider` 能力后可以提供：

```json
{
  "capabilities": ["theme_provider"],
  "theme_overrides": {
    "colors": {
      "primary": "#22C55E"
    }
  }
}
```

当前仅应用 `colors.primary`。多个启用的主题插件同时存在时，不保证用户可控的冲突顺序，因此一个安装环境中应只启用一个主题提供者。

## 限制

- 不支持任意 HTML、WebView 或 Flutter Widget 注入。
- 不支持控件条件显示、动态列表或运行时修改 Schema。
- 不支持插件自定义页面路由。
- 不支持把动作结果自动转换成通知或表单校验错误。

这些限制保证插件 UI 可控、可升级，并与宿主主题和无障碍能力一致。
