# 公告系统后端API示例

这是一个使用Node.js + Express构建的公告系统后端API示例，提供完整的功能演示。

## 功能特性

- ✅ 完整的REST API
- ✅ JWT认证
- ✅ WebSocket实时通信
- ✅ Web Push推送通知
- ✅ CORS支持
- ✅ 安全中间件
- ✅ 内存数据存储（演示用）

## 快速开始

### 1. 安装依赖

```bash
cd backend-example
npm install
```

### 2. 配置环境变量

创建 `.env` 文件：

```env
PORT=3001
JWT_SECRET=your-super-secret-jwt-key-here
VAPID_PUBLIC_KEY=your-vapid-public-key
VAPID_PRIVATE_KEY=your-vapid-private-key
VAPID_EMAIL=mailto:your-email@domain.com
```

### 3. 生成VAPID密钥

```bash
npm install -g web-push
web-push generate-vapid-keys
```

将生成的密钥添加到环境变量中。

### 4. 启动服务器

```bash
# 开发模式
npm run dev

# 生产模式
npm start
```

服务器将在 http://localhost:3001 启动。

## 默认账户

- **用户名**: admin
- **密码**: admin123

## API端点

### 公告相关
- `GET /api/announcements` - 获取公告列表
- `GET /api/announcements/active` - 检查活跃公告
- `GET /api/announcements/:id` - 获取单个公告
- `PATCH /api/announcements/:id/read` - 标记已读

### 管理员认证
- `POST /api/admin/login` - 管理员登录
- `POST /api/admin/logout` - 管理员登出
- `GET /api/admin/profile` - 获取管理员信息

### 管理员公告操作
- `GET /api/admin/announcements` - 获取所有公告
- `POST /api/admin/announcements` - 创建公告
- `PUT /api/admin/announcements/:id` - 更新公告
- `DELETE /api/admin/announcements/:id` - 删除公告

### 推送通知
- `POST /api/push/subscribe` - 订阅推送
- `POST /api/push/unsubscribe` - 取消订阅
- `POST /api/push/send` - 发送推送

### 统计
- `GET /api/stats/announcements` - 获取统计数据

## WebSocket事件

连接地址: `ws://localhost:3001`

### 客户端事件
- `ping` - 心跳检测

### 服务端事件
- `pong` - 心跳响应
- `announcement:created` - 公告创建
- `announcement:updated` - 公告更新
- `announcement:deleted` - 公告删除

## 测试API

### 登录获取Token

```bash
curl -X POST http://localhost:3001/api/admin/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### 创建公告

```bash
curl -X POST http://localhost:3001/api/admin/announcements \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "title": "测试公告",
    "content": "这是一个测试公告",
    "type": "info",
    "priority": "medium",
    "isActive": true
  }'
```

### 获取公告列表

```bash
curl http://localhost:3001/api/announcements
```

## 数据结构

### 公告对象
```json
{
  "id": "string",
  "title": "string",
  "content": "string",
  "type": "info|warning|success|error",
  "priority": "low|medium|high",
  "isActive": boolean,
  "expiresAt": "string|null",
  "authorId": "string",
  "authorName": "string",
  "tags": ["string"],
  "targetAudience": "all|desktop|web",
  "pushEnabled": boolean,
  "readCount": number,
  "createdAt": "string",
  "updatedAt": "string"
}
```

## 部署到生产环境

### 1. 使用PM2

```bash
npm install -g pm2
pm2 start server.js --name "announcement-api"
pm2 startup
pm2 save
```

### 2. 使用Docker

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3001
CMD ["npm", "start"]
```

### 3. 使用Nginx反向代理

```nginx
server {
    listen 80;
    server_name api.your-domain.com;
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## 注意事项

1. **数据存储**: 当前使用内存存储，生产环境请使用数据库（PostgreSQL、MongoDB等）
2. **安全性**: 请更改默认的JWT密钥和管理员密码
3. **HTTPS**: 推送通知需要HTTPS环境
4. **日志**: 建议添加日志记录系统
5. **监控**: 建议添加性能监控和错误追踪

## 扩展功能

可以考虑添加以下功能：

- 数据库集成（PostgreSQL、MongoDB）
- Redis缓存
- 文件上传支持
- 邮件通知
- 短信通知
- 用户权限管理
- API限流
- 数据备份
- 健康检查端点

## 许可证

MIT License