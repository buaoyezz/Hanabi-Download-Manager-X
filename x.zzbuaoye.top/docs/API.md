# 公告系统 API 文档

## 概述

本文档描述了公告系统的后端API接口。所有API都使用JSON格式进行数据交换。

## 基础信息

- **Base URL**: `https://api.zzbuaoye.top` (生产环境)
- **Base URL**: `http://localhost:3001` (开发环境)
- **Content-Type**: `application/json`
- **认证方式**: Bearer Token

## 通用响应格式

```json
{
  "success": boolean,
  "data": any,
  "message": string,
  "error": string,
  "code": number
}
```

## 公告相关接口

### 1. 获取公告列表

```http
GET /api/announcements
```

**查询参数**:
- `page` (number, optional): 页码，默认为1
- `limit` (number, optional): 每页数量，默认为10
- `type` (string, optional): 公告类型 (info|warning|success|error)
- `priority` (string, optional): 优先级 (low|medium|high)
- `active` (boolean, optional): 是否只获取活跃公告

**响应**:
```json
{
  "success": true,
  "data": {
    "announcements": [
      {
        "id": "string",
        "title": "string",
        "content": "string",
        "type": "info|warning|success|error",
        "priority": "low|medium|high",
        "createdAt": "string",
        "updatedAt": "string",
        "isActive": boolean,
        "expiresAt": "string",
        "authorId": "string",
        "authorName": "string",
        "tags": ["string"],
        "targetAudience": "all|desktop|web",
        "pushEnabled": boolean,
        "readCount": number
      }
    ],
    "hasActive": boolean,
    "total": number,
    "unreadCount": number
  }
}
```

### 2. 检查活跃公告

```http
GET /api/announcements/active
```

**响应**:
```json
{
  "success": true,
  "data": {
    "hasActive": boolean
  }
}
```

### 3. 根据ID获取公告

```http
GET /api/announcements/:id
```

**响应**:
```json
{
  "success": true,
  "data": {
    // Announcement object
  }
}
```

### 4. 标记公告为已读

```http
PATCH /api/announcements/:id/read
```

**响应**:
```json
{
  "success": true,
  "message": "Announcement marked as read"
}
```

### 5. 获取未读公告数量

```http
GET /api/announcements/unread-count
```

**响应**:
```json
{
  "success": true,
  "data": {
    "count": number
  }
}
```

## 管理员认证接口

### 1. 管理员登录

```http
POST /api/admin/login
```

**请求体**:
```json
{
  "username": "string",
  "password": "string"
}
```

**响应**:
```json
{
  "success": true,
  "data": {
    "token": "string",
    "user": {
      "id": "string",
      "username": "string",
      "email": "string",
      "role": "admin|moderator",
      "createdAt": "string",
      "lastLogin": "string"
    }
  }
}
```

### 2. 管理员登出

```http
POST /api/admin/logout
```

**Headers**: `Authorization: Bearer <token>`

**响应**:
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

### 3. 刷新Token

```http
POST /api/admin/refresh
```

**Headers**: `Authorization: Bearer <token>`

**响应**:
```json
{
  "success": true,
  "data": {
    "token": "string"
  }
}
```

### 4. 获取管理员信息

```http
GET /api/admin/profile
```

**Headers**: `Authorization: Bearer <token>`

**响应**:
```json
{
  "success": true,
  "data": {
    // AdminUser object
  }
}
```

## 管理员公告操作接口

### 1. 获取所有公告（管理员视图）

```http
GET /api/admin/announcements
```

**Headers**: `Authorization: Bearer <token>`

**查询参数**: 同公告列表接口，额外支持:
- `search` (string, optional): 搜索关键词

### 2. 创建公告

```http
POST /api/admin/announcements
```

**Headers**: `Authorization: Bearer <token>`

**请求体**:
```json
{
  "title": "string",
  "content": "string",
  "type": "info|warning|success|error",
  "priority": "low|medium|high",
  "isActive": boolean,
  "expiresAt": "string",
  "tags": ["string"],
  "targetAudience": "all|desktop|web",
  "pushEnabled": boolean
}
```

### 3. 更新公告

```http
PUT /api/admin/announcements/:id
```

**Headers**: `Authorization: Bearer <token>`

**请求体**: 同创建公告，所有字段可选

### 4. 删除公告

```http
DELETE /api/admin/announcements/:id
```

**Headers**: `Authorization: Bearer <token>`

### 5. 批量操作公告

```http
POST /api/admin/announcements/batch
```

**Headers**: `Authorization: Bearer <token>`

**请求体**:
```json
{
  "ids": ["string"],
  "action": "activate|deactivate|delete"
}
```

## 推送通知接口

### 1. 订阅推送

```http
POST /api/push/subscribe
```

**请求体**:
```json
{
  "endpoint": "string",
  "keys": {
    "p256dh": "string",
    "auth": "string"
  },
  "userAgent": "string"
}
```

### 2. 取消订阅推送

```http
POST /api/push/unsubscribe
```

**请求体**:
```json
{
  "endpoint": "string"
}
```

### 3. 发送推送通知

```http
POST /api/push/send
```

**Headers**: `Authorization: Bearer <token>`

**请求体**:
```json
{
  "announcementId": "string",
  "title": "string",
  "body": "string",
  "targetAudience": "all|desktop|web"
}
```

## 统计接口

### 1. 获取公告统计

```http
GET /api/stats/announcements
```

**Headers**: `Authorization: Bearer <token>`

**响应**:
```json
{
  "success": true,
  "data": {
    "totalAnnouncements": number,
    "activeAnnouncements": number,
    "totalViews": number,
    "pushSubscriptions": number
  }
}
```

### 2. 获取推送统计

```http
GET /api/stats/push
```

**Headers**: `Authorization: Bearer <token>`

**响应**:
```json
{
  "success": true,
  "data": {
    "totalSent": number,
    "totalDelivered": number,
    "totalFailed": number,
    "subscriptions": number
  }
}
```

## WebSocket 事件

WebSocket连接地址: `wss://api.zzbuaoye.top` (生产环境)

### 客户端事件

- `ping`: 心跳检测

### 服务端事件

- `pong`: 心跳响应
- `announcement:created`: 公告创建
- `announcement:updated`: 公告更新
- `announcement:deleted`: 公告删除
- `push:notification`: 推送通知

### 事件数据格式

```json
{
  "type": "string",
  "data": any,
  "timestamp": "string"
}
```

## 错误码

- `400`: 请求参数错误
- `401`: 未授权或token无效
- `403`: 权限不足
- `404`: 资源不存在
- `409`: 资源冲突
- `422`: 数据验证失败
- `429`: 请求频率限制
- `500`: 服务器内部错误

## 示例代码

### JavaScript/TypeScript

```typescript
// 获取公告列表
const response = await fetch('/api/announcements');
const data = await response.json();

// 管理员登录
const loginResponse = await fetch('/api/admin/login', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    username: 'admin',
    password: 'password'
  })
});

// 创建公告
const createResponse = await fetch('/api/admin/announcements', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    title: '新公告',
    content: '公告内容',
    type: 'info',
    priority: 'medium',
    isActive: true
  })
});
```

### cURL

```bash
# 获取公告列表
curl -X GET "https://api.zzbuaoye.top/api/announcements"

# 管理员登录
curl -X POST "https://api.zzbuaoye.top/api/admin/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password"}'

# 创建公告
curl -X POST "https://api.zzbuaoye.top/api/admin/announcements" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"title":"新公告","content":"公告内容","type":"info","priority":"medium","isActive":true}'
```