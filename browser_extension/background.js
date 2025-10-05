// HDM-X Browser Extension Background Script
class HDMXBackground {
    constructor() {
        this.socket = null;
        this.isConnected = false;
        this.currentSpeed = 0;
        this.clientVersion = 'Unknown';
        this.heartbeatInterval = null;
        this.requestHeadersMap = new Map(); // 存储请求头信息
        this.shouldDisableProxy = false; // 代理下载开关
        
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.setupContextMenus();
        this.setupDownloadProxy(); // 设置代理下载
        this.startClientConnection();
        this.loadStoredData();
    }

    setupEventListeners() {
        // Handle extension installation
        chrome.runtime.onInstalled.addListener((details) => {
            this.handleInstallation(details);
        });

        // Handle messages from popup and content scripts
        chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
            this.handleMessage(message, sender, sendResponse);
            return true; // Keep message channel open for async responses
        });

        // Handle web request events for download detection
        chrome.webRequest.onBeforeRequest.addListener(
            (details) => this.handleWebRequest(details),
            { urls: ["<all_urls>"] },
            ["requestBody"]
        );

        // Handle download events
        chrome.downloads.onCreated.addListener((downloadItem) => {
            this.handleDownloadCreated(downloadItem);
        });

        chrome.downloads.onChanged.addListener((delta) => {
            this.handleDownloadChanged(delta);
        });
    }

    setupContextMenus() {
        chrome.contextMenus.create({
            id: 'hdmx-download-link',
            title: '使用 HDM-X 下载',
            contexts: ['link']
        });

        chrome.contextMenus.create({
            id: 'hdmx-download-page',
            title: '下载当前页面',
            contexts: ['page']
        });

        chrome.contextMenus.onClicked.addListener((info, tab) => {
            this.handleContextMenuClick(info, tab);
        });
    }

    async handleInstallation(details) {
        if (details.reason === 'install') {
            // Set default settings
            await chrome.storage.local.set({
                autoCapture: true,
                smartCategory: true,
                currentSpeed: 0,
                isConnected: false
            });

            // Show welcome page
            chrome.tabs.create({ url: 'welcome.html' });
        } else if (details.reason === 'update') {
            // Handle extension update
            console.log('HDM-X Extension updated to version', chrome.runtime.getManifest().version);
        }
    }

    async handleMessage(message, sender, sendResponse) {
        try {
            switch (message.action) {
                case 'addDownload':
                    await this.addDownload(message.data);
                    sendResponse({ success: true });
                    break;

                case 'sendToClient':
                    const response = await this.sendToClient(message.message);
                    sendResponse(response);
                    break;

                case 'openManager':
                    await this.openManagerViaProtocol();
                    sendResponse({ success: true });
                    break;

                case 'settingChanged':
                    await this.handleSettingChange(message.key, message.value);
                    sendResponse({ success: true });
                    break;

                case 'toggleProxy':
                    await this.toggleDownloadProxy(message.enabled);
                    sendResponse({ success: true });
                    break;

                case 'getStats':
                    sendResponse({
                        currentSpeed: this.currentSpeed,
                        isConnected: this.isConnected
                    });
                    break;

                case 'findDownloadLinks':
                    // This will be handled by content script
                    break;

                default:
                    sendResponse({ error: 'Unknown action' });
            }
        } catch (error) {
            console.error('Error handling message:', error);
            sendResponse({ error: error.message });
        }
    }

    handleWebRequest(details) {
        // Check if this is a potential download request
        if (this.isDownloadRequest(details)) {
            this.detectDownload(details);
        }
    }

    isDownloadRequest(details) {
        const url = details.url.toLowerCase();
        const downloadExtensions = [
            '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2',
            '.exe', '.msi', '.dmg', '.pkg', '.deb', '.rpm',
            '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm',
            '.mp3', '.wav', '.flac', '.aac', '.ogg', '.m4a',
            '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
            '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg', '.webp'
        ];

        return downloadExtensions.some(ext => url.includes(ext)) ||
               details.method === 'POST' && this.hasDownloadHeaders(details);
    }

    hasDownloadHeaders(details) {
        // Check for download-related headers
        const headers = details.requestHeaders || [];
        return headers.some(header => 
            header.name.toLowerCase() === 'content-disposition' ||
            (header.name.toLowerCase() === 'content-type' && 
             header.value.includes('application/octet-stream'))
        );
    }

    async detectDownload(details) {
        try {
            const settings = await chrome.storage.local.get(['autoCapture']);
            
            if (settings.autoCapture !== false) {
                const downloadData = {
                    url: details.url,
                    filename: this.extractFilenameFromUrl(details.url),
                    timestamp: Date.now(),
                    source: 'auto_capture',
                    tabId: details.tabId
                };

                await this.addDownload(downloadData);
            }
        } catch (error) {
            console.error('Error in download detection:', error);
        }
    }

    async addDownload(downloadData) {
        try {
            // Send to HDM-X client if connected
            if (this.isConnected) {
                await this.sendToClient({
                    action: 'addDownload',
                    data: downloadData
                });
            } else {
                // Store for later when client connects
                const pendingDownloads = await this.getPendingDownloads();
                pendingDownloads.push(downloadData);
                await chrome.storage.local.set({ pendingDownloads });
            }

            // Notify popup if open
            this.notifyPopup('downloadAdded', downloadData);

            console.log('Download added:', downloadData);
        } catch (error) {
            console.error('Error adding download:', error);
        }
    }

    async sendToClient(message) {
        return new Promise((resolve) => {
            if (!this.isConnected || !this.socket || this.socket.readyState !== WebSocket.OPEN) {
                resolve({ success: false, error: 'Client not connected' });
                return;
            }

            try {
                this.socket.send(JSON.stringify(message));
                resolve({ success: true });
            } catch (error) {
                console.error("HDM-X: Error sending message to client:", error);
                resolve({ success: false, error: error.message });
            }
        });
    }

    startClientConnection() {
        // Try to connect to HDM-X client via WebSocket
        this.connectWebSocket();
        
        // Retry connection every 10 seconds if not connected
        setInterval(() => {
            if (!this.isConnected) {
                this.connectWebSocket();
            }
        }, 10000);
    }

    connectWebSocket() {
        try {
            console.log('HDM-X: Attempting WebSocket connection to localhost:8080');
            this.socket = new WebSocket("ws://localhost:8080/ws");

            this.socket.onopen = () => {
                console.log("HDM-X: WebSocket connection opened");
                this.updateConnectionStatus(true);
                this.startHeartbeat();
            };

            this.socket.onmessage = (event) => {
                try {
                    const message = JSON.parse(event.data);
                    console.log("HDM-X: Received message:", message);
                    
                    if (message.type === "version") {
                        this.clientVersion = message.clientVersion || 'Unknown';
                        chrome.storage.local.set({ 
                            clientVersion: this.clientVersion 
                        });
                    } else if (message.type === "pong") {
                        console.log("HDM-X: Heartbeat response received");
                    }
                } catch (error) {
                    console.error("HDM-X: Error parsing message:", error);
                }
            };

            this.socket.onerror = (error) => {
                console.log("HDM-X: WebSocket error:", error);
                this.updateConnectionStatus(false);
                this.stopHeartbeat();
            };

            this.socket.onclose = () => {
                console.log("HDM-X: WebSocket connection closed, retrying in 5 seconds");
                this.updateConnectionStatus(false);
                this.stopHeartbeat();
                
                if (!this.shouldDisableProxy) {
                    setTimeout(() => this.connectWebSocket(), 5000);
                }
            };
        } catch (error) {
            console.error("HDM-X: Exception in WebSocket connection:", error);
            setTimeout(() => this.connectWebSocket(), 5000);
        }
    }

    updateConnectionStatus(connected) {
        this.isConnected = connected;
        this.updateBadge(connected ? "connected" : "disconnected");
        chrome.storage.local.set({ isConnected: connected });
        
        // Notify popup about connection change
        this.notifyPopup('connectionChanged', { connected });
    }

    updateBadge(status) {
        const badgeColor = (status === "connected") ? "#50fa7b" : "#ff5555";
        const badgeText = (status === "connected") ? "✓" : "✗";
        chrome.action.setBadgeBackgroundColor({ color: badgeColor });
        chrome.action.setBadgeText({ text: badgeText });
    }

    startHeartbeat() {
        if (!this.heartbeatInterval) {
            this.heartbeatInterval = setInterval(() => {
                if (this.socket && this.socket.readyState === WebSocket.OPEN) {
                    try {
                        this.socket.send(JSON.stringify({ 
                            type: 'ping', 
                            timestamp: Date.now() 
                        }));
                        console.log("HDM-X: Heartbeat sent");
                    } catch (error) {
                        console.error("HDM-X: Error sending heartbeat:", error);
                    }
                }
            }, 10000); // 每10秒发送一次心跳
        }
    }

    stopHeartbeat() {
        if (this.heartbeatInterval) {
            clearInterval(this.heartbeatInterval);
            this.heartbeatInterval = null;
        }
    }

    setupDownloadProxy() {
        // 监听下载开始事件并拦截下载
        chrome.downloads.onDeterminingFilename.addListener((downloadItem) => {
            if (downloadItem.state === "in_progress") {
                chrome.storage.local.get(["shouldDisableProxy"], (result) => {
                    if (!result.shouldDisableProxy && this.isConnected && 
                        this.socket && this.socket.readyState === WebSocket.OPEN) {
                        
                        console.log("HDM-X: Download intercepted:", downloadItem);
                        
                        if (downloadItem.finalUrl && downloadItem.finalUrl.startsWith("http")) {
                            // 取消浏览器下载
                            chrome.downloads.cancel(downloadItem.id);

                            // 从映射表中获取对应的请求头
                            const requestHeaders = this.requestHeadersMap.get(downloadItem.finalUrl) || {};

                            // 构造完整的请求信息
                            const downloadInfo = {
                                type: 'download',
                                url: downloadItem.finalUrl,
                                filename: downloadItem.filename || this.extractFilenameFromUrl(downloadItem.finalUrl),
                                referer: downloadItem.referrer || "",
                                headers: requestHeaders,
                                fileSize: downloadItem.fileSize === -1 ? 0 : downloadItem.fileSize,
                                timestamp: Date.now(),
                                source: 'browser_proxy'
                            };

                            console.log("HDM-X: Sending download info to client:", downloadInfo);

                            // 将请求信息发送到 WebSocket
                            this.sendToClient(downloadInfo);

                            // 清空对应的请求头信息
                            this.requestHeadersMap.delete(downloadItem.finalUrl);
                            
                            // 显示通知
                            this.showNotification('下载已转发到 HDM-X', 'success');
                        }
                    }
                });
            }
        });

        // 监听请求头信息
        chrome.webRequest.onBeforeSendHeaders.addListener(
            (details) => {
                // 将请求头数组转换为字典
                const requestHeadersDict = details.requestHeaders.reduce((acc, header) => {
                    acc[header.name.toLowerCase()] = header.value;
                    return acc;
                }, {});

                // 存储请求头信息
                this.requestHeadersMap.set(details.url, requestHeadersDict);
                
                // 清理过期的请求头信息（避免内存泄漏）
                if (this.requestHeadersMap.size > 1000) {
                    const firstKey = this.requestHeadersMap.keys().next().value;
                    this.requestHeadersMap.delete(firstKey);
                }
            },
            {
                urls: ["<all_urls>"],
                types: ["main_frame", "sub_frame", "xmlhttprequest", "other"]
            },
            ["requestHeaders", "extraHeaders"]
        );
    }

    showNotification(message, type = 'info') {
        chrome.notifications.create({
            type: 'basic',
            iconUrl: 'icon48.png',
            title: 'HDM-X',
            message: message
        });
    }

    // 移除旧的检查方法，现在使用WebSocket连接

    // 移除旧的ping方法，现在使用WebSocket心跳

    async processPendingDownloads() {
        try {
            const result = await chrome.storage.local.get(['pendingDownloads']);
            const pendingDownloads = result.pendingDownloads || [];

            for (const download of pendingDownloads) {
                await this.sendToClient({
                    action: 'addDownload',
                    data: download
                });
            }

            // Clear pending downloads
            await chrome.storage.local.set({ pendingDownloads: [] });
        } catch (error) {
            console.error('Error processing pending downloads:', error);
        }
    }

    async getPendingDownloads() {
        const result = await chrome.storage.local.get(['pendingDownloads']);
        return result.pendingDownloads || [];
    }

    async handleSettingChange(key, value) {
        await chrome.storage.local.set({ [key]: value });
        
        // Send setting change to client
        if (this.isConnected) {
            await this.sendToClient({
                action: 'updateSetting',
                key: key,
                value: value
            });
        }
    }

    handleDownloadCreated(downloadItem) {
        console.log('Download created:', downloadItem);
        
        // Update stats
        this.updateDownloadStats();
    }

    handleDownloadChanged(delta) {
        if (delta.state && delta.state.current === 'in_progress') {
            // Update download speed if available
            if (delta.bytesReceived) {
                this.updateDownloadSpeed(delta);
            }
        }
    }

    async updateDownloadStats() {
        try {
            // Stats updated but download count not tracked
            this.notifyPopup('statsUpdated', {});
        } catch (error) {
            console.error('Error updating download stats:', error);
        }
    }

    updateDownloadSpeed(delta) {
        // Calculate approximate speed (this is simplified)
        if (delta.bytesReceived && delta.bytesReceived.current > 0) {
            const speed = delta.bytesReceived.current / 1024; // KB/s approximation
            this.currentSpeed = speed;
            
            chrome.storage.local.set({ currentSpeed: speed });
            this.notifyPopup('statsUpdated', { currentSpeed: speed });
        }
    }

    notifyPopup(action, data) {
        // Send message to popup if it's open
        chrome.runtime.sendMessage({
            action: action,
            data: data
        }).catch(() => {
            // Popup is not open, ignore error
        });
    }

    async handleContextMenuClick(info, tab) {
        try {
            let downloadUrl = '';
            let filename = '';

            if (info.menuItemId === 'hdmx-download-link') {
                downloadUrl = info.linkUrl;
                filename = this.extractFilenameFromUrl(downloadUrl);
            } else if (info.menuItemId === 'hdmx-download-page') {
                downloadUrl = tab.url;
                filename = tab.title || 'webpage';
            }

            if (downloadUrl) {
                await this.addDownload({
                    url: downloadUrl,
                    filename: filename,
                    timestamp: Date.now(),
                    source: 'context_menu',
                    tabId: tab.id
                });

                // Show notification
                chrome.notifications.create({
                    type: 'basic',
                    iconUrl: 'icon48.png',
                    title: 'HDM-X',
                    message: '下载任务已添加'
                });
            }
        } catch (error) {
            console.error('Error handling context menu click:', error);
        }
    }

    extractFilenameFromUrl(url) {
        try {
            const urlObj = new URL(url);
            const pathname = decodeURIComponent(urlObj.pathname);
            const filename = pathname.split('/').pop();
            
            if (filename && filename.includes('.')) {
                return filename;
            }
            
            return `download_${Date.now()}`;
        } catch (error) {
            return `download_${Date.now()}`;
        }
    }

    async openManagerViaProtocol() {
        try {
            // Try to open HDM-X via protocol
            const protocolUrl = 'hdmx://open';
            
            // Create a tab with the protocol URL
            await chrome.tabs.create({ 
                url: protocolUrl,
                active: false  // Don't focus the tab
            });
            
            // Close the tab after a short delay (it should have triggered the protocol)
            setTimeout(async () => {
                try {
                    const tabs = await chrome.tabs.query({ url: protocolUrl });
                    for (const tab of tabs) {
                        await chrome.tabs.remove(tab.id);
                    }
                } catch (e) {
                    console.log('Could not close protocol tab:', e);
                }
            }, 2000);
            
            return true;
        } catch (error) {
            console.error('Failed to open manager via protocol:', error);
            return false;
        }
    }

    async loadStoredData() {
        try {
            const result = await chrome.storage.local.get([
                'currentSpeed',
                'isConnected',
                'clientVersion',
                'shouldDisableProxy'
            ]);

            this.currentSpeed = result.currentSpeed || 0;
            this.isConnected = result.isConnected || false;
            this.clientVersion = result.clientVersion || 'Unknown';
            this.shouldDisableProxy = result.shouldDisableProxy || false;
            
            console.log('HDM-X: Loaded settings:', {
                isConnected: this.isConnected,
                shouldDisableProxy: this.shouldDisableProxy
            });
        } catch (error) {
            console.error('Error loading stored data:', error);
        }
    }

    async toggleDownloadProxy(enabled) {
        this.shouldDisableProxy = !enabled;
        await chrome.storage.local.set({ shouldDisableProxy: this.shouldDisableProxy });
        
        console.log('HDM-X: Download proxy', enabled ? 'enabled' : 'disabled');
        
        // 通知popup更新状态
        this.notifyPopup('proxyToggled', { enabled });
    }
}

// Initialize background script
new HDMXBackground();