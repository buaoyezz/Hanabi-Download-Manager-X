const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const webpush = require('web-push');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3001;

// 配置
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key';
const VAPID_PUBLIC_KEY = process.env.VAPID_PUBLIC_KEY || 'your-vapid-public-key';
const VAPID_PRIVATE_KEY = process.env.VAPID_PRIVATE_KEY || 'your-vapid-private-key';
const VAPID_EMAIL = process.env.VAPID_EMAIL || 'mailto:your-email@domain.com';

// 配置Web Push
webpush.setVapidDetails(VAPID_EMAIL, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

// 中间件
app.use(helmet());
app.use(cors({
  origin: ['http://localhost:5173', 'http://localhost:3000'],
  credentials: true
}));
app.use(compression());
app.use(morgan('combined'));
app.use(express.json());

// 模拟数据存储
let announcements = [
  {
    id: '1',
    title: 'Hanabi Download Manager X v2.0 发布',
    content: '全新的 Hanabi Download Manager X v2.0 现已发布！采用 Flutter + Python 架构，带来更快的下载速度和更好的用户体验。',
    type: 'success',
    priority: 'high',
    createdAt: '2024-12-13T10:00:00Z',
    updatedAt: '2024-12-13T10:00:00Z',
    isActive: true,
    expiresAt: '2026-01-13T10:00:00Z',
    authorId: 'admin',
    authorName: 'Administrator',
    tags: ['release', 'update'],
    targetAudience: 'all',
    pushEnabled: true,
    readCount: 0
  },
  {
    id: '2',
    title: '系统维护通知',
    content: '我们将在 12月15日 02:00-04:00 进行系统维护，期间可能影响下载服务。',
    type: 'warning',
    priority: 'medium',
    createdAt: '2024-12-12T15:30:00Z',
    updatedAt: '2024-12-12T15:30:00Z',
    isActive: true,
    expiresAt: '2024-12-16T04:00:00Z',
    authorId: 'admin',
    authorName: 'Administrator',
    tags: ['maintenance'],
    targetAudience: 'all',
    pushEnabled: false,
    readCount: 5
  }
];

let adminUsers = [
  {
    id: 'admin',
    username: 'admin',
    email: 'admin@zzbuaoye.top',
    passwordHash: bcrypt.hashSync('admin123', 10), // 密码: admin123
    role: 'admin',
    createdAt: '2024-01-01T00:00:00Z',
    lastLogin: null
  }
];

let pushSubscriptions = [];

// 认证中间件
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ success: false, error: 'Invalid token' });
    }
    req.user = user;
    next();
  });
};

// 工具函数
const filterActiveAnnouncements = (announcements) => {
  return announcements.filter(announcement => {
    if (!announcement.isActive) return false;
    if (announcement.expiresAt) {
      return new Date(announcement.expiresAt) > new Date();
    }
    return true;
  });
};

// 公告相关路由
app.get('/api/announcements', (req, res) => {
  try {
    const { page = 1, limit = 10, type, priority, active } = req.query;
    
    let filteredAnnouncements = [...announcements];
    
    // 过滤条件
    if (type) {
      filteredAnnouncements = filteredAnnouncements.filter(a => a.type === type);
    }
    if (priority) {
      filteredAnnouncements = filteredAnnouncements.filter(a => a.priority === priority);
    }
    if (active !== undefined) {
      if (active === 'true') {
        filteredAnnouncements = filterActiveAnnouncements(filteredAnnouncements);
      }
    } else {
      // 默认只返回活跃公告
      filteredAnnouncements = filterActiveAnnouncements(filteredAnnouncements);
    }
    
    // 分页
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + parseInt(limit);
    const paginatedAnnouncements = filteredAnnouncements.slice(startIndex, endIndex);
    
    const hasActive = filterActiveAnnouncements(announcements).length > 0;
    
    res.json({
      success: true,
      data: {
        announcements: paginatedAnnouncements,
        hasActive,
        total: filteredAnnouncements.length,
        unreadCount: filteredAnnouncements.length // 简化实现
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/announcements/active', (req, res) => {
  try {
    const activeAnnouncements = filterActiveAnnouncements(announcements);
    res.json({
      success: true,
      data: {
        hasActive: activeAnnouncements.length > 0
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/announcements/:id', (req, res) => {
  try {
    const announcement = announcements.find(a => a.id === req.params.id);
    if (!announcement) {
      return res.status(404).json({ success: false, error: 'Announcement not found' });
    }
    res.json({ success: true, data: announcement });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.patch('/api/announcements/:id/read', (req, res) => {
  try {
    const announcement = announcements.find(a => a.id === req.params.id);
    if (!announcement) {
      return res.status(404).json({ success: false, error: 'Announcement not found' });
    }
    announcement.readCount = (announcement.readCount || 0) + 1;
    res.json({ success: true, message: 'Announcement marked as read' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 管理员认证路由
app.post('/api/admin/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    if (!username || !password) {
      return res.status(400).json({ success: false, error: 'Username and password required' });
    }
    
    const user = adminUsers.find(u => u.username === username);
    if (!user || !bcrypt.compareSync(password, user.passwordHash)) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }
    
    // 更新最后登录时间
    user.lastLogin = new Date().toISOString();
    
    // 生成JWT token
    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          role: user.role,
          createdAt: user.createdAt,
          lastLogin: user.lastLogin
        }
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/admin/logout', authenticateToken, (req, res) => {
  res.json({ success: true, message: 'Logged out successfully' });
});

app.get('/api/admin/profile', authenticateToken, (req, res) => {
  try {
    const user = adminUsers.find(u => u.id === req.user.id);
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    
    res.json({
      success: true,
      data: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        createdAt: user.createdAt,
        lastLogin: user.lastLogin
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 管理员公告操作路由
app.get('/api/admin/announcements', authenticateToken, (req, res) => {
  try {
    const { page = 1, limit = 10, type, priority, active, search } = req.query;
    
    let filteredAnnouncements = [...announcements];
    
    // 搜索
    if (search) {
      const searchLower = search.toLowerCase();
      filteredAnnouncements = filteredAnnouncements.filter(a => 
        a.title.toLowerCase().includes(searchLower) || 
        a.content.toLowerCase().includes(searchLower)
      );
    }
    
    // 过滤条件
    if (type) {
      filteredAnnouncements = filteredAnnouncements.filter(a => a.type === type);
    }
    if (priority) {
      filteredAnnouncements = filteredAnnouncements.filter(a => a.priority === priority);
    }
    if (active !== undefined) {
      const isActive = active === 'true';
      filteredAnnouncements = filteredAnnouncements.filter(a => a.isActive === isActive);
    }
    
    // 分页
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + parseInt(limit);
    const paginatedAnnouncements = filteredAnnouncements.slice(startIndex, endIndex);
    
    const hasActive = filterActiveAnnouncements(announcements).length > 0;
    
    res.json({
      success: true,
      data: {
        announcements: paginatedAnnouncements,
        hasActive,
        total: filteredAnnouncements.length
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/admin/announcements', authenticateToken, (req, res) => {
  try {
    const {
      title,
      content,
      type,
      priority,
      isActive,
      expiresAt,
      tags,
      targetAudience,
      pushEnabled
    } = req.body;
    
    if (!title || !content || !type || !priority) {
      return res.status(400).json({ success: false, error: 'Missing required fields' });
    }
    
    const newAnnouncement = {
      id: uuidv4(),
      title,
      content,
      type,
      priority,
      isActive: isActive !== false,
      expiresAt: expiresAt || null,
      authorId: req.user.id,
      authorName: req.user.username,
      tags: tags || [],
      targetAudience: targetAudience || 'all',
      pushEnabled: pushEnabled || false,
      readCount: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    
    announcements.unshift(newAnnouncement);
    
    // 广播WebSocket事件
    broadcastToClients('announcement:created', newAnnouncement);
    
    res.status(201).json({ success: true, data: newAnnouncement });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/admin/announcements/:id', authenticateToken, (req, res) => {
  try {
    const announcementIndex = announcements.findIndex(a => a.id === req.params.id);
    if (announcementIndex === -1) {
      return res.status(404).json({ success: false, error: 'Announcement not found' });
    }
    
    const updatedAnnouncement = {
      ...announcements[announcementIndex],
      ...req.body,
      updatedAt: new Date().toISOString()
    };
    
    announcements[announcementIndex] = updatedAnnouncement;
    
    // 广播WebSocket事件
    broadcastToClients('announcement:updated', updatedAnnouncement);
    
    res.json({ success: true, data: updatedAnnouncement });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.delete('/api/admin/announcements/:id', authenticateToken, (req, res) => {
  try {
    const announcementIndex = announcements.findIndex(a => a.id === req.params.id);
    if (announcementIndex === -1) {
      return res.status(404).json({ success: false, error: 'Announcement not found' });
    }
    
    announcements.splice(announcementIndex, 1);
    
    // 广播WebSocket事件
    broadcastToClients('announcement:deleted', { id: req.params.id });
    
    res.json({ success: true, message: 'Announcement deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 推送通知路由
app.post('/api/push/subscribe', (req, res) => {
  try {
    const { endpoint, keys, userAgent } = req.body;
    
    if (!endpoint || !keys || !keys.p256dh || !keys.auth) {
      return res.status(400).json({ success: false, error: 'Invalid subscription data' });
    }
    
    const subscription = {
      id: uuidv4(),
      endpoint,
      keys,
      userAgent: userAgent || '',
      createdAt: new Date().toISOString()
    };
    
    // 检查是否已存在
    const existingIndex = pushSubscriptions.findIndex(s => s.endpoint === endpoint);
    if (existingIndex !== -1) {
      pushSubscriptions[existingIndex] = subscription;
    } else {
      pushSubscriptions.push(subscription);
    }
    
    res.json({ success: true, message: 'Subscription saved successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/push/unsubscribe', (req, res) => {
  try {
    const { endpoint } = req.body;
    
    const index = pushSubscriptions.findIndex(s => s.endpoint === endpoint);
    if (index !== -1) {
      pushSubscriptions.splice(index, 1);
    }
    
    res.json({ success: true, message: 'Unsubscribed successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.post('/api/push/send', authenticateToken, async (req, res) => {
  try {
    const { announcementId, title, body, targetAudience = 'all' } = req.body;
    
    let announcement = null;
    if (announcementId) {
      announcement = announcements.find(a => a.id === announcementId);
      if (!announcement) {
        return res.status(404).json({ success: false, error: 'Announcement not found' });
      }
    }
    
    const payload = JSON.stringify({
      title: title || announcement?.title || 'New Announcement',
      body: body || announcement?.content || 'You have a new announcement',
      icon: '/logo.png',
      badge: '/badge.png',
      data: {
        url: '/announcements',
        announcementId: announcementId
      }
    });
    
    let sentCount = 0;
    let failedCount = 0;
    
    for (const subscription of pushSubscriptions) {
      try {
        await webpush.sendNotification({
          endpoint: subscription.endpoint,
          keys: subscription.keys
        }, payload);
        sentCount++;
      } catch (error) {
        console.error('Push notification failed:', error);
        failedCount++;
      }
    }
    
    res.json({
      success: true,
      data: {
        sent: sentCount,
        failed: failedCount,
        total: pushSubscriptions.length
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 统计路由
app.get('/api/stats/announcements', authenticateToken, (req, res) => {
  try {
    const activeAnnouncements = filterActiveAnnouncements(announcements);
    const totalViews = announcements.reduce((sum, a) => sum + (a.readCount || 0), 0);
    
    res.json({
      success: true,
      data: {
        totalAnnouncements: announcements.length,
        activeAnnouncements: activeAnnouncements.length,
        totalViews,
        pushSubscriptions: pushSubscriptions.length
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// WebSocket服务器
const server = require('http').createServer(app);
const wss = new WebSocket.Server({ server });

const clients = new Set();

wss.on('connection', (ws) => {
  console.log('WebSocket client connected');
  clients.add(ws);
  
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      if (data.type === 'ping') {
        ws.send(JSON.stringify({ type: 'pong', timestamp: new Date().toISOString() }));
      }
    } catch (error) {
      console.error('WebSocket message error:', error);
    }
  });
  
  ws.on('close', () => {
    console.log('WebSocket client disconnected');
    clients.delete(ws);
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
    clients.delete(ws);
  });
});

// 广播函数
function broadcastToClients(type, data) {
  const message = JSON.stringify({
    type,
    data,
    timestamp: new Date().toISOString()
  });
  
  clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
}

// 错误处理
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, error: 'Internal server error' });
});

// 404处理
app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Not found' });
});

// 启动服务器
server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 WebSocket server ready`);
  console.log(`👤 Admin credentials: admin / admin123`);
});