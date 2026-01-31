export interface Announcement {
  id: string;
  title: string;
  content: string;
  type: 'info' | 'warning' | 'success' | 'error';
  priority: 'low' | 'medium' | 'high';
  createdAt: string;
  updatedAt: string;
  isActive: boolean;
  expiresAt?: string;
  authorId?: string;
  authorName?: string;
  tags?: string[];
  targetAudience?: 'all' | 'desktop' | 'web';
  pushEnabled?: boolean;
  readCount?: number;
}

export interface AnnouncementResponse {
  announcements: Announcement[];
  hasActive: boolean;
  total: number;
  unreadCount?: number;
}

export interface CreateAnnouncementRequest {
  title: string;
  content: string;
  type: 'info' | 'warning' | 'success' | 'error';
  priority: 'low' | 'medium' | 'high';
  isActive: boolean;
  expiresAt?: string;
  tags?: string[];
  targetAudience?: 'all' | 'desktop' | 'web';
  pushEnabled?: boolean;
}

export interface UpdateAnnouncementRequest extends Partial<CreateAnnouncementRequest> {
  id: string;
}

export interface AdminUser {
  id: string;
  username: string;
  email: string;
  role: 'admin' | 'moderator';
  createdAt: string;
  lastLogin?: string;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  success: boolean;
  token?: string;
  user?: AdminUser;
  message?: string;
}

export interface PushNotification {
  id: string;
  announcementId: string;
  title: string;
  body: string;
  icon?: string;
  badge?: string;
  data?: Record<string, any>;
  sentAt: string;
  deliveryStatus: 'pending' | 'sent' | 'failed';
}

export interface PushSubscription {
  id: string;
  endpoint: string;
  keys: {
    p256dh: string;
    auth: string;
  };
  userAgent?: string;
  createdAt: string;
}