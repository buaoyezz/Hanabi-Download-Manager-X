// API端点配置
export const API_ENDPOINTS = {
  // 获取所有活跃公告
  GET_ANNOUNCEMENTS: '/api/announcements',
  
  // 检查是否有活跃公告
  CHECK_ACTIVE: '/api/announcements/active',
  
  // 根据ID获取公告
  GET_BY_ID: (id: string) => `/api/announcements/${id}`,
};

// API响应类型
export interface ApiResponse<T> {
  success: boolean;
  data: T;
  message?: string;
  error?: string;
}

// 实际项目中的API调用示例
export class AnnouncementAPI {
  private baseUrl: string;

  constructor(baseUrl: string = '') {
    this.baseUrl = baseUrl;
  }

  // 获取公告列表
  async getAnnouncements() {
    const response = await fetch(`${this.baseUrl}${API_ENDPOINTS.GET_ANNOUNCEMENTS}`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  }

  // 检查活跃公告
  async checkActiveAnnouncements() {
    const response = await fetch(`${this.baseUrl}${API_ENDPOINTS.CHECK_ACTIVE}`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  }

  // 根据ID获取公告
  async getAnnouncementById(id: string) {
    const response = await fetch(`${this.baseUrl}${API_ENDPOINTS.GET_BY_ID(id)}`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  }
}

// 使用示例：
// const api = new AnnouncementAPI('https://your-api-domain.com');
// const announcements = await api.getAnnouncements();