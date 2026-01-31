import { getCurrentConfig, WS_EVENTS } from '../config/api';
import type { Announcement } from '../types/announcement';

export interface WebSocketMessage {
  type: string;
  data: any;
  timestamp: string;
}

class WebSocketService {
  private ws: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectInterval = 1000;
  private heartbeatInterval: number | null = null;
  private listeners: Map<string, Set<Function>> = new Map();

  // 连接WebSocket
  connect() {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      return;
    }

    const wsUrl = getCurrentConfig().wsUrl;
    
    try {
      this.ws = new WebSocket(wsUrl);
      
      this.ws.onopen = this.handleOpen.bind(this);
      this.ws.onmessage = this.handleMessage.bind(this);
      this.ws.onclose = this.handleClose.bind(this);
      this.ws.onerror = this.handleError.bind(this);
      
    } catch (error) {
      console.error('WebSocket connection failed:', error);
      this.scheduleReconnect();
    }
  }

  // 断开连接
  disconnect() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }

    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }

    this.reconnectAttempts = 0;
  }

  // 发送消息
  send(message: WebSocketMessage) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      console.warn('WebSocket is not connected');
    }
  }

  // 添加事件监听器
  on(event: string, callback: Function) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(callback);
  }

  // 移除事件监听器
  off(event: string, callback: Function) {
    const eventListeners = this.listeners.get(event);
    if (eventListeners) {
      eventListeners.delete(callback);
    }
  }

  // 触发事件
  private emit(event: string, data: any) {
    const eventListeners = this.listeners.get(event);
    if (eventListeners) {
      eventListeners.forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          console.error('WebSocket event callback error:', error);
        }
      });
    }
  }

  // 处理连接打开
  private handleOpen() {
    console.log('WebSocket connected');
    this.reconnectAttempts = 0;
    this.startHeartbeat();
    this.emit('connected', null);
  }

  // 处理消息接收
  private handleMessage(event: MessageEvent) {
    try {
      const message: WebSocketMessage = JSON.parse(event.data);
      
      // 处理心跳响应
      if (message.type === 'pong') {
        return;
      }

      // 触发对应事件
      this.emit(message.type, message.data);

      // 处理特定的公告事件
      switch (message.type) {
        case WS_EVENTS.ANNOUNCEMENT_CREATED:
          this.handleAnnouncementCreated(message.data);
          break;
        case WS_EVENTS.ANNOUNCEMENT_UPDATED:
          this.handleAnnouncementUpdated(message.data);
          break;
        case WS_EVENTS.ANNOUNCEMENT_DELETED:
          this.handleAnnouncementDeleted(message.data);
          break;
        case WS_EVENTS.PUSH_NOTIFICATION:
          this.handlePushNotification(message.data);
          break;
      }
    } catch (error) {
      console.error('Failed to parse WebSocket message:', error);
    }
  }

  // 处理连接关闭
  private handleClose(event: CloseEvent) {
    console.log('WebSocket disconnected:', event.code, event.reason);
    
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }

    this.emit('disconnected', { code: event.code, reason: event.reason });

    // 如果不是主动关闭，尝试重连
    if (event.code !== 1000) {
      this.scheduleReconnect();
    }
  }

  // 处理连接错误
  private handleError(error: Event) {
    console.error('WebSocket error:', error);
    this.emit('error', error);
  }

  // 安排重连
  private scheduleReconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectInterval * Math.pow(2, this.reconnectAttempts - 1);
    
    console.log(`Attempting to reconnect in ${delay}ms (attempt ${this.reconnectAttempts})`);
    
    setTimeout(() => {
      this.connect();
    }, delay);
  }

  // 开始心跳
  private startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.send({
          type: 'ping',
          data: null,
          timestamp: new Date().toISOString(),
        });
      }
    }, 30000); // 30秒心跳
  }

  // 处理公告创建事件
  private handleAnnouncementCreated(announcement: Announcement) {
    // 触发全局事件
    window.dispatchEvent(new CustomEvent('announcement:created', {
      detail: announcement
    }));
  }

  // 处理公告更新事件
  private handleAnnouncementUpdated(announcement: Announcement) {
    window.dispatchEvent(new CustomEvent('announcement:updated', {
      detail: announcement
    }));
  }

  // 处理公告删除事件
  private handleAnnouncementDeleted(announcementId: string) {
    window.dispatchEvent(new CustomEvent('announcement:deleted', {
      detail: { id: announcementId }
    }));
  }

  // 处理推送通知事件
  private handlePushNotification(notification: any) {
    window.dispatchEvent(new CustomEvent('push:notification', {
      detail: notification
    }));
  }

  // 获取连接状态
  get isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }
}

export const websocketService = new WebSocketService();