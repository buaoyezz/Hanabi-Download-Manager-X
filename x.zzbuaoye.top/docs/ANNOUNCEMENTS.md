# 公告系统使用说明

## 概述

公告系统允许管理员发布重要通知，用户可以在网站上查看这些公告。系统支持不同类型和优先级的公告，并且只有在有活跃公告时才会显示公告按钮。

## 功能特性

- ✅ 动态显示/隐藏公告按钮
- ✅ 支持多种公告类型（信息、警告、成功、错误）
- ✅ 支持优先级设置（低、中、高）
- ✅ 公告过期时间管理
- ✅ 响应式设计
- ✅ 国际化支持（中英文）
- ✅ 平滑动画效果

## 文件结构

```
src/
├── types/
│   └── announcement.ts          # 公告数据类型定义
├── services/
│   └── announcementService.ts   # 公告服务（包含模拟数据）
├── hooks/
│   └── useAnnouncements.ts      # 公告状态管理Hook
├── pages/
│   └── Announcements.tsx       # 公告页面组件
├── api/
│   └── announcements.ts        # API端点配置和真实API示例
└── components/
    └── Header.tsx              # 更新的Header组件（包含公告按钮）
```

## API接口

### 1. 获取公告列表
```typescript
GET /api/announcements
```

响应格式：
```json
{
  "announcements": [
    {
      "id": "1",
      "title": "公告标题",
      "content": "公告内容",
      "type": "info|warning|success|error",
      "priority": "low|medium|high",
      "createdAt": "2024-12-13T10:00:00Z",
      "updatedAt": "2024-12-13T10:00:00Z",
      "isActive": true,
      "expiresAt": "2026-01-13T10:00:00Z"
    }
  ],
  "hasActive": true,
  "total": 1
}
```

### 2. 检查活跃公告
```typescript
GET /api/announcements/active
```

响应格式：
```json
{
  "hasActive": true
}
```

### 3. 根据ID获取公告
```typescript
GET /api/announcements/:id
```

## 使用方法

### 1. 在组件中使用公告Hook

```typescript
import { useAnnouncements } from '../hooks/useAnnouncements';

const MyComponent = () => {
  const { hasActiveAnnouncements, loading, refresh } = useAnnouncements();
  
  return (
    <div>
      {!loading && hasActiveAnnouncements && (
        <Button onClick={() => navigate('/announcements')}>
          查看公告
        </Button>
      )}
    </div>
  );
};
```

### 2. 直接使用公告服务

```typescript
import { announcementService } from '../services/announcementService';

// 获取所有公告
const announcements = await announcementService.getAnnouncements();

// 检查是否有活跃公告
const hasActive = await announcementService.hasActiveAnnouncements();

// 根据ID获取公告
const announcement = await announcementService.getAnnouncementById('1');
```

## 配置真实API

当前使用模拟数据，要连接真实API，请：

1. 更新 `src/services/announcementService.ts` 中的 `baseUrl`
2. 替换模拟数据逻辑为真实的fetch调用
3. 参考 `src/api/announcements.ts` 中的API类实现

示例：
```typescript
// 在 announcementService.ts 中
private baseUrl = 'https://your-api-domain.com/api/announcements';

async getAnnouncements(): Promise<AnnouncementResponse> {
  const response = await fetch(this.baseUrl);
  if (!response.ok) {
    throw new Error('Failed to fetch announcements');
  }
  return response.json();
}
```

## 自定义样式

公告系统使用 Fluent UI 组件，可以通过修改 `makeStyles` 来自定义样式：

```typescript
const useStyles = makeStyles({
  announcementCard: {
    marginBottom: '16px',
    // 添加自定义样式
    border: '2px solid red',
  },
});
```

## 国际化

添加新语言支持：

1. 在 `src/i18n/locales/` 目录下创建新的语言文件
2. 添加公告相关的翻译键值对
3. 在 `src/components/Header.tsx` 中添加语言选项

## 注意事项

- 公告按钮只在有活跃公告时显示
- 过期的公告会自动被过滤掉
- 系统支持优雅降级，API失败时不会影响主要功能
- 所有日期时间都使用ISO 8601格式