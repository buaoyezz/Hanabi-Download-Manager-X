// Service Worker for Push Notifications
const CACHE_NAME = 'hanabi-announcements-v1';
const urlsToCache = [
  '/',
  '/static/js/bundle.js',
  '/static/css/main.css',
  '/logo.png',
  '/badge.png'
];

// 安装事件
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        return cache.addAll(urlsToCache);
      })
  );
});

// 激活事件
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});

// 推送事件
self.addEventListener('push', (event) => {
  console.log('Push event received:', event);

  let notificationData = {
    title: 'Hanabi Download Manager X',
    body: '您有新的公告',
    icon: '/logo.png',
    badge: '/badge.png',
    tag: 'announcement',
    requireInteraction: true,
    actions: [
      {
        action: 'view',
        title: '查看详情',
        icon: '/icons/view.png'
      },
      {
        action: 'dismiss',
        title: '忽略',
        icon: '/icons/dismiss.png'
      }
    ],
    data: {
      url: '/announcements',
      timestamp: Date.now()
    }
  };

  // 如果推送包含数据，解析并使用
  if (event.data) {
    try {
      const pushData = event.data.json();
      notificationData = {
        ...notificationData,
        ...pushData,
        data: {
          ...notificationData.data,
          ...pushData.data
        }
      };
    } catch (error) {
      console.error('Failed to parse push data:', error);
    }
  }

  const promiseChain = self.registration.showNotification(
    notificationData.title,
    notificationData
  );

  event.waitUntil(promiseChain);

  // 向主线程发送消息
  event.waitUntil(
    self.clients.matchAll().then((clients) => {
      clients.forEach((client) => {
        client.postMessage({
          type: 'PUSH_RECEIVED',
          payload: notificationData
        });
      });
    })
  );
});

// 通知点击事件
self.addEventListener('notificationclick', (event) => {
  console.log('Notification click received:', event);

  event.notification.close();

  const action = event.action;
  const notificationData = event.notification.data || {};

  if (action === 'dismiss') {
    return;
  }

  // 默认行为或点击"查看详情"
  const urlToOpen = action === 'view' 
    ? notificationData.url || '/announcements'
    : '/announcements';

  event.waitUntil(
    self.clients.matchAll({ type: 'window' }).then((clientList) => {
      // 查找已打开的窗口
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          // 如果找到已打开的窗口，聚焦并导航
          client.navigate(urlToOpen);
          return client.focus();
        }
      }
      
      // 如果没有找到已打开的窗口，打开新窗口
      if (self.clients.openWindow) {
        return self.clients.openWindow(urlToOpen);
      }
    })
  );
});

// 通知关闭事件
self.addEventListener('notificationclose', (event) => {
  console.log('Notification closed:', event);
  
  // 可以在这里记录通知关闭的统计信息
  const notificationData = event.notification.data || {};
  
  // 向服务器发送统计信息（如果需要）
  if (notificationData.trackingId) {
    fetch('/api/notifications/close', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        trackingId: notificationData.trackingId,
        closedAt: new Date().toISOString()
      })
    }).catch(error => {
      console.error('Failed to track notification close:', error);
    });
  }
});

// 获取请求事件（缓存策略）
self.addEventListener('fetch', (event) => {
  // 只缓存GET请求
  if (event.request.method !== 'GET') {
    return;
  }

  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // 如果在缓存中找到，返回缓存的版本
        if (response) {
          return response;
        }

        // 否则从网络获取
        return fetch(event.request).then((response) => {
          // 检查是否是有效的响应
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }

          // 克隆响应
          const responseToCache = response.clone();

          caches.open(CACHE_NAME)
            .then((cache) => {
              cache.put(event.request, responseToCache);
            });

          return response;
        });
      })
  );
});

// 后台同步事件（如果支持）
self.addEventListener('sync', (event) => {
  if (event.tag === 'background-sync') {
    event.waitUntil(
      // 执行后台同步任务
      syncAnnouncements()
    );
  }
});

// 后台同步函数
async function syncAnnouncements() {
  try {
    // 获取最新的公告数据
    const response = await fetch('/api/announcements/active');
    const data = await response.json();
    
    // 向主线程发送更新消息
    const clients = await self.clients.matchAll();
    clients.forEach(client => {
      client.postMessage({
        type: 'ANNOUNCEMENTS_UPDATED',
        payload: data
      });
    });
  } catch (error) {
    console.error('Background sync failed:', error);
  }
}