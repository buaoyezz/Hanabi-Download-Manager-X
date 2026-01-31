// API配置
export const API_CONFIG = {
  // 开发环境
  development: {
    baseUrl: 'http://localhost:3001',
    wsUrl: 'ws://localhost:3001',
  },
  // 生产环境
  production: {
    baseUrl: 'https://api.zzbuaoye.top',
    wsUrl: 'wss://api.zzbuaoye.top',
  },
  // 测试环境
  test: {
    baseUrl: 'https://test-api.zzbuaoye.top',
    wsUrl: 'wss://test-api.zzbuaoye.top',
  }
};

// 获取当前环境配置
export const getCurrentConfig = () => {
  const env = import.meta.env.MODE || 'development';
  return API_CONFIG[env as keyof typeof API_CONFIG] || API_CONFIG.development;
};

// API端点
export const API_ENDPOINTS = {
  // 公告相关
  ANNOUNCEMENTS: '/api/announcements',
  ANNOUNCEMENT_BY_ID: (id: string) => `/api/announcements/${id}`,
  ACTIVE_ANNOUNCEMENTS: '/api/announcements/active',
  
  // 管理员相关
  ADMIN_LOGIN: '/api/admin/login',
  ADMIN_LOGOUT: '/api/admin/logout',
  ADMIN_REFRESH: '/api/admin/refresh',
  ADMIN_PROFILE: '/api/admin/profile',
  
  // 管理员公告操作
  ADMIN_ANNOUNCEMENTS: '/api/admin/announcements',
  ADMIN_CREATE_ANNOUNCEMENT: '/api/admin/announcements',
  ADMIN_UPDATE_ANNOUNCEMENT: (id: string) => `/api/admin/announcements/${id}`,
  ADMIN_DELETE_ANNOUNCEMENT: (id: string) => `/api/admin/announcements/${id}`,
  
  // 推送相关
  PUSH_SUBSCRIBE: '/api/push/subscribe',
  PUSH_UNSUBSCRIBE: '/api/push/unsubscribe',
  PUSH_SEND: '/api/push/send',
  
  // 统计相关
  STATS_ANNOUNCEMENTS: '/api/stats/announcements',
  STATS_PUSH: '/api/stats/push',
};

// 请求配置
export const REQUEST_CONFIG = {
  timeout: 10000,
  retries: 3,
  retryDelay: 1000,
};

// WebSocket事件
export const WS_EVENTS = {
  ANNOUNCEMENT_CREATED: 'announcement:created',
  ANNOUNCEMENT_UPDATED: 'announcement:updated',
  ANNOUNCEMENT_DELETED: 'announcement:deleted',
  PUSH_NOTIFICATION: 'push:notification',
};