import { httpClient } from '../utils/httpClient';
import { API_ENDPOINTS } from '../config/api';
import type { 
  Announcement, 
  AnnouncementResponse
} from '../types/announcement';

class AnnouncementService {
  // 获取所有公告
  async getAnnouncements(params?: {
    page?: number;
    limit?: number;
    type?: string;
    priority?: string;
    active?: boolean;
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

      const endpoint = `${API_ENDPOINTS.ANNOUNCEMENTS}?${queryParams.toString()}`;
      const response = await httpClient.get<AnnouncementResponse>(endpoint);

      if (response.success && response.data) {
        return response.data;
      } else {
        throw new Error(response.error || 'Failed to fetch announcements');
      }
    } catch (error) {
      console.error('Failed to fetch announcements:', error);
      return {
        announcements: [],
        hasActive: false,
        total: 0,
        unreadCount: 0
      };
    }
  }

  // 检查是否有活跃公告
  async hasActiveAnnouncements(): Promise<boolean> {
    try {
      const response = await httpClient.get<{ hasActive: boolean }>(
        API_ENDPOINTS.ACTIVE_ANNOUNCEMENTS
      );

      if (response.success && response.data) {
        return response.data.hasActive;
      }
      return false;
    } catch (error) {
      console.error('Failed to check active announcements:', error);
      return false;
    }
  }

  // 根据ID获取单个公告
  async getAnnouncementById(id: string): Promise<Announcement | null> {
    try {
      const response = await httpClient.get<Announcement>(
        API_ENDPOINTS.ANNOUNCEMENT_BY_ID(id)
      );

      if (response.success && response.data) {
        return response.data;
      }
      return null;
    } catch (error) {
      console.error('Failed to fetch announcement by ID:', error);
      return null;
    }
  }

  // 标记公告为已读
  async markAsRead(id: string): Promise<boolean> {
    try {
      const response = await httpClient.patch(
        `${API_ENDPOINTS.ANNOUNCEMENT_BY_ID(id)}/read`
      );
      return response.success;
    } catch (error) {
      console.error('Failed to mark announcement as read:', error);
      return false;
    }
  }

  // 获取未读公告数量
  async getUnreadCount(): Promise<number> {
    try {
      const response = await httpClient.get<{ count: number }>(
        `${API_ENDPOINTS.ANNOUNCEMENTS}/unread-count`
      );

      if (response.success && response.data) {
        return response.data.count;
      }
      return 0;
    } catch (error) {
      console.error('Failed to get unread count:', error);
      return 0;
    }
  }
}

export const announcementService = new AnnouncementService();