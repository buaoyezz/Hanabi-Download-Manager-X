import { httpClient } from '../utils/httpClient';
import { API_ENDPOINTS } from '../config/api';

class PushService {
  private swRegistration: ServiceWorkerRegistration | null = null;
  private vapidPublicKey = 'YOUR_VAPID_PUBLIC_KEY'; // 需要配置VAPID密钥

  // 初始化推送服务
  async initialize() {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      console.warn('Push messaging is not supported');
      return false;
    }

    try {
      // 注册Service Worker
      this.swRegistration = await navigator.serviceWorker.register('/sw.js');
      console.log('Service Worker registered successfully');

      // 监听推送消息
      navigator.serviceWorker.addEventListener('message', this.handleServiceWorkerMessage);

      return true;
    } catch (error) {
      console.error('Service Worker registration failed:', error);
      return false;
    }
  }

  // 处理Service Worker消息
  private handleServiceWorkerMessage = (event: MessageEvent) => {
    if (event.data && event.data.type === 'PUSH_RECEIVED') {
      // 处理推送消息接收事件
      this.onPushReceived(event.data.payload);
    }
  };

  // 推送消息接收回调
  private onPushReceived(payload: any) {
    // 可以在这里处理推送消息，比如更新UI
    window.dispatchEvent(new CustomEvent('push:received', { detail: payload }));
  }

  // 检查推送权限
  async checkPermission(): Promise<NotificationPermission> {
    if (!('Notification' in window)) {
      return 'denied';
    }
    return Notification.permission;
  }

  // 请求推送权限
  async requestPermission(): Promise<boolean> {
    const permission = await Notification.requestPermission();
    return permission === 'granted';
  }

  // 订阅推送
  async subscribe(): Promise<boolean> {
    if (!this.swRegistration) {
      console.error('Service Worker not registered');
      return false;
    }

    try {
      // 检查权限
      const hasPermission = await this.requestPermission();
      if (!hasPermission) {
        console.warn('Push notification permission denied');
        return false;
      }

      // 获取推送订阅
      const subscription = await this.swRegistration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKey) as BufferSource,
      });

      // 发送订阅信息到服务器
      const response = await httpClient.post(API_ENDPOINTS.PUSH_SUBSCRIBE, {
        endpoint: subscription.endpoint,
        keys: {
          p256dh: this.arrayBufferToBase64(subscription.getKey('p256dh')!),
          auth: this.arrayBufferToBase64(subscription.getKey('auth')!),
        },
        userAgent: navigator.userAgent,
      });

      if (response.success) {
        localStorage.setItem('push_subscribed', 'true');
        console.log('Push subscription successful');
        return true;
      } else {
        console.error('Failed to save push subscription:', response.error);
        return false;
      }
    } catch (error) {
      console.error('Push subscription failed:', error);
      return false;
    }
  }

  // 取消订阅推送
  async unsubscribe(): Promise<boolean> {
    if (!this.swRegistration) {
      return false;
    }

    try {
      const subscription = await this.swRegistration.pushManager.getSubscription();
      if (subscription) {
        await subscription.unsubscribe();
        
        // 通知服务器取消订阅
        await httpClient.post(API_ENDPOINTS.PUSH_UNSUBSCRIBE, {
          endpoint: subscription.endpoint,
        });
      }

      localStorage.removeItem('push_subscribed');
      console.log('Push unsubscription successful');
      return true;
    } catch (error) {
      console.error('Push unsubscription failed:', error);
      return false;
    }
  }

  // 检查是否已订阅
  async isSubscribed(): Promise<boolean> {
    if (!this.swRegistration) {
      return false;
    }

    try {
      const subscription = await this.swRegistration.pushManager.getSubscription();
      return subscription !== null;
    } catch (error) {
      return false;
    }
  }

  // 显示本地通知
  async showNotification(title: string, options: NotificationOptions = {}) {
    if (!this.swRegistration) {
      return;
    }

    const permission = await this.checkPermission();
    if (permission !== 'granted') {
      return;
    }

    await this.swRegistration.showNotification(title, {
      icon: '/logo.png',
      badge: '/badge.png',
      ...options,
    });
  }

  // 工具方法：将VAPID密钥转换为Uint8Array
  private urlBase64ToUint8Array(base64String: string): Uint8Array {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding)
      .replace(/-/g, '+')
      .replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  }

  // 工具方法：将ArrayBuffer转换为Base64
  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return window.btoa(binary);
  }
}

export const pushService = new PushService();