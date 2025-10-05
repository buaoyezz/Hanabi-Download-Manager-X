// HDM X 浏览器扩展后台脚本
const HDM_WEBSOCKET_URL = 'ws://127.0.0.1:9721';
let websocket = null;
let isConnected = false;

// 创建右键菜单
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'hdm-download-link',
    title: '使用HDM X下载',
    contexts: ['link']
  });
  
  chrome.contextMenus.create({
    id: 'hdm-download-video',
    title: '使用HDM X下载视频',
    contexts: ['video']
  });
  
  chrome.contextMenus.create({
    id: 'hdm-download-image',
    title: '使用HDM X下载图片',
    contexts: ['image']
  });
});

// 处理右键菜单点击
chrome.contextMenus.onClicked.addListener((info, tab) => {
  let downloadUrl = '';
  let filename = '';
  
  switch (info.menuItemId) {
    case 'hdm-download-link':
      downloadUrl = info.linkUrl;
      filename = extractFilenameFromUrl(downloadUrl);
      break;
    case 'hdm-download-video':
      downloadUrl = info.srcUrl;
      filename = extractFilenameFromUrl(downloadUrl) || 'video';
      break;
    case 'hdm-download-image':
      downloadUrl = info.srcUrl;
      filename = extractFilenameFromUrl(downloadUrl) || 'image';
      break;
  }
  
  if (downloadUrl) {
    sendDownloadRequest(downloadUrl, filename, tab.url);
  }
});

// 监听来自content script和popup的消息
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'download') {
    sendDownloadRequest(message.url, message.filename, message.referer)
      .then(result => sendResponse(result))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true; // 保持消息通道开放
  }
  
  if (message.action === 'batch_download') {
    handleBatchDownload(message.urls, message.referer)
      .then(result => sendResponse(result))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true;
  }
});

// WebSocket连接管理
function connectWebSocket() {
  if (websocket && websocket.readyState === WebSocket.OPEN) {
    return Promise.resolve();
  }
  
  return new Promise((resolve, reject) => {
    websocket = new WebSocket(HDM_WEBSOCKET_URL);
    
    websocket.onopen = () => {
      isConnected = true;
      console.log('HDM X WebSocket连接成功');
      chrome.storage.local.set({ hdm_connected: true });
      resolve();
    };
    
    websocket.onclose = () => {
      isConnected = false;
      console.log('HDM X WebSocket连接断开');
      chrome.storage.local.set({ hdm_connected: false });
      // 5秒后重连
      setTimeout(connectWebSocket, 5000);
    };
    
    websocket.onerror = (error) => {
      isConnected = false;
      console.error('HDM X WebSocket连接错误:', error);
      chrome.storage.local.set({ hdm_connected: false });
      reject(error);
    };
    
    // 连接超时
    setTimeout(() => {
      if (websocket.readyState !== WebSocket.OPEN) {
        websocket.close();
        reject(new Error('连接超时'));
      }
    }, 5000);
  });
}

// 发送下载请求到HDM X
async function sendDownloadRequest(url, filename, referer) {
  try {
    await connectWebSocket();
    
    const message = {
      action: 'add_download',
      data: {
        url: url,
        filename: filename,
        referer: referer,
        timestamp: Date.now(),
        user_agent: navigator.userAgent
      }
    };
    
    return new Promise((resolve, reject) => {
      const messageId = Date.now().toString();
      
      const responseHandler = (event) => {
        try {
          const response = JSON.parse(event.data);
          if (response.messageId === messageId) {
            websocket.removeEventListener('message', responseHandler);
            if (response.success) {
              resolve(response);
            } else {
              reject(new Error(response.error || '下载添加失败'));
            }
          }
        } catch (e) {
          console.error('解析响应失败:', e);
        }
      };
      
      websocket.addEventListener('message', responseHandler);
      
      // 添加消息ID用于响应匹配
      message.messageId = messageId;
      websocket.send(JSON.stringify(message));
      
      // 请求超时
      setTimeout(() => {
        websocket.removeEventListener('message', responseHandler);
        reject(new Error('请求超时'));
      }, 10000);
    });
    
  } catch (error) {
    throw new Error('HDM X连接失败，请确保HDM X正在运行');
  }
}

// 批量下载处理
async function handleBatchDownload(urls, referer) {
  const results = [];
  for (const url of urls) {
    try {
      const filename = extractFilenameFromUrl(url);
      const result = await sendDownloadRequest(url, filename, referer);
      results.push({ url, success: true, result });
    } catch (error) {
      results.push({ url, success: false, error: error.message });
    }
  }
  return { success: true, results };
}

// 从URL提取文件名
function extractFilenameFromUrl(url) {
  try {
    const urlObj = new URL(url);
    const pathname = urlObj.pathname;
    const filename = pathname.split('/').pop();
    return filename && filename.includes('.') ? filename : '';
  } catch (e) {
    return '';
  }
}

// 检查HDM X连接状态
async function checkHDMConnection() {
  try {
    await connectWebSocket();
    
    return new Promise((resolve) => {
      const messageId = Date.now().toString();
      
      const responseHandler = (event) => {
        try {
          const response = JSON.parse(event.data);
          if (response.messageId === messageId) {
            websocket.removeEventListener('message', responseHandler);
            resolve(response.success === true);
          }
        } catch (e) {
          resolve(false);
        }
      };
      
      websocket.addEventListener('message', responseHandler);
      websocket.send(JSON.stringify({ action: 'ping', messageId }));
      
      // 超时处理
      setTimeout(() => {
        websocket.removeEventListener('message', responseHandler);
        resolve(false);
      }, 3000);
    });
    
  } catch (error) {
    return false;
  }
}

// 启动时连接WebSocket
connectWebSocket().catch(console.error);

// 定期检查连接状态
setInterval(async () => {
  if (!isConnected) {
    try {
      await connectWebSocket();
    } catch (error) {
      console.log('重连失败，将在5秒后重试');
    }
  }
}, 10000);