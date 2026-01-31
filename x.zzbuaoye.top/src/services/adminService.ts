import { httpClient } from '../utils/httpClient';
import { API_ENDPOINTS } from '../config/api';
import type { 
  AdminUser,
  LoginRequest,
  LoginResponse,
  Announcement,
  AnnouncementResponse,
  CreateAnnouncementRequest,
  UpdateAnnouncementRequest
} from '../types/announcement';

class AdminService {
  // 管理员登录
  async login(credentials: LoginRequest): Promise<LoginResponse> {
    try {
      const response = await httpClient.post<LoginResponse>(
        API_ENDPOINTS.ADMIN_LOGIN,
        credentials
      );

      if (response.success && response.data) {
        const { token } = response.data;
        
        if (token) {
          // 存储token
          httpClient.setStoredToken(token);
        }

        return response.data;
      } else {
        return {
          success: false,
          message: response.error || 'Login failed'
        };
      }
    } catch (error) {
      console.error('Login error:', error);
      return {
        success: false,
        message: 'Network error'
      };
    }
  }

  // 管理员登出
  async logout(): Promise<boolean> {
    try {
      await httpClient.post(API_ENDPOINTS.ADMIN_LOGOUT);
      httpClient.clearStoredToken();
      return true;
    } catch (error) {
      console.error('Logout error:', error);
      httpClient.clearStoredToken(); // 即使请求失败也清除本地token
      return false;
    }
  }

  // 刷新token
  async refreshToken(): Promise<boolean> {
    try {
      const response = await httpClient.post<{ token: string }>(
        API_ENDPOINTS.ADMIN_REFRESH
      );

      if (response.success && response.data?.token) {
        httpClient.setStoredToken(response.data.token);
        return true;
      }
      return false;
    } catch (error) {
      console.error('Token refresh error:', error);
      return false;
    }
  }

  // 获取管理员信息
  async getProfile(): Promise<AdminUser | null> {
    try {
      const response = await httpClient.get<AdminUser>(API_ENDPOINTS.ADMIN_PROFILE);
      
      if (response.success && response.data) {
        return response.data;
      }
      return null;
    } catch (error) {
      console.error('Failed to get admin profile:', error);
      return null;
    }
  }

  // 检查是否已登录
  isLoggedIn(): boolean {
    return !!httpClient.getStoredToken();
  }

  // 获取所有公告（管理员视图）
  async getAllAnnouncements(params?: {
    page?: number;
    limit?: number;
    type?: string;
    priority?: string;
    active?: boolean;
    search?: string;
  }): Promise<AnnouncementResponse> {
    try {
      const queryParams = new URLSearchParams();
      
      if (params) {
        Object.entries(params).forEach(([key, value]) => {
          if (value !== undefined) {
            queryParams.append(key, String(value));
          }
        });
      }

      const endpoint = `${API_ENDPOINTS.ADMIN_ANNOUNCEMENTS}?${queryParams.toString()}`;
      const response = await httpClient.get<AnnouncementResponse>(endpoint);

      if (response.success && response.data) {
        return response.data;
      } else {
        throw new Error(response.error || 'Failed to fetch announcements');
      }
    } catch (error) {
      console.error('Failed to fetch admin announcements:', error);
      return {
        announcements: [],
        hasActive: false,
        total: 0
      };
    }
  }

  // 创建公告
  async createAnnouncement(data: CreateAnnouncementRequest): Promise<Announcement | null> {
    try {
      const response = await httpClient.post<Announcement>(
        API_ENDPOINTS.ADMIN_CREATE_ANNOUNCEMENT,
        data
      );

      if (response.success && response.data) {
        return response.data;
      } else {
        throw new Error(response.error || 'Failed to create announcement');
      }
    } catch (error) {
      console.error('Failed to create announcement:', error);
      return null;
    }
  }

  // 更新公告
  async updateAnnouncement(data: UpdateAnnouncementRequest): Promise<Announcement | null> {
    try {
      const { id, ...updateData } = data;
      const response = await httpClient.put<Announcement>(
        API_ENDPOINTS.ADMIN_UPDATE_ANNOUNCEMENT(id),
        updateData
      );

      if (response.success && response.data) {
        return response.data;
      } else {
        throw new Error(response.error || 'Failed to update announcement');
      }
    } catch (error) {
      console.error('Failed to update announcement:', error);
      return null;
    }
  }

  // 删除公告
  async deleteAnnouncement(id: string): Promise<boolean> {
    try {
      const response = await httpClient.delete(
        API_ENDPOINTS.ADMIN_DELETE_ANNOUNCEMENT(id)
      );
      return response.success;
    } catch (error) {
      console.error('Failed to delete announcement:', error);
      return false;
    }
  }

  // 批量操作公告
  async batchUpdateAnnouncements(ids: string[], action: 'activate' | 'deactivate' | 'delete'): Promise<boolean> {
    try {
      const response = await httpClient.post(
        `${API_ENDPOINTS.ADMIN_ANNOUNCEMENTS}/batch`,
        { ids, action }
      );
      return response.success;
    } catch (error) {
      console.error('Failed to batch update announcements:', error);
      return false;
    }
  }

  // 发送推送通知
  async sendPushNotification(announcementId: string, options?: {
    title?: string;
    body?: string;
    targetAudience?: 'all' | 'desktop' | 'web';
  }): Promise<boolean> {
    try {
      const response = await httpClient.post(API_ENDPOINTS.PUSH_SEND, {
        announcementId,
        ...options
      });
      return response.success;
    } catch (error) {
      console.error('Failed to send push notification:', error);
      return false;
    }
  }

  // 获取统计数据
  async getStats(): Promise<{
    totalAnnouncements: number;
    activeAnnouncements: number;
    totalViews: number;
    pushSubscriptions: number;
  } | null> {
    try {
      const response = await httpClient.get(API_ENDPOINTS.STATS_ANNOUNCEMENTS);
      
      if (response.success && response.data) {
        return response.data;
      }
      return null;
    } catch (error) {
      console.error('Failed to get stats:', error);
      return null;
    }
  }
}

export const adminService = new AdminService();