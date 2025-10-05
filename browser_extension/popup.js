// HDM-X Browser Extension Popup Script
class HDMXPopup {
    constructor() {
        this.isConnected = false;
        // Download count removed
        this.currentSpeed = 0;
        this.clientVersion = 'Unknown';
        this.extensionVersion = chrome.runtime.getManifest().version;
        this.linkCount = 0;
        this.isScanning = false;
        
        this.init();
    }

    async init() {
        await this.loadSettings();
        this.setupEventListeners();
        this.updateUI();
        this.startStatusCheck();
        this.animateStats();
        this.startLinkDetection();
    }

    async loadSettings() {
        try {
            const result = await chrome.storage.local.get([
                'isConnected',
                'currentSpeed',
                'clientVersion',
                'enableDetection',
                'smartCategory',
                'allowedExtensions',
                'whitelistDomains',
                'shouldDisableProxy'
            ]);

            this.isConnected = result.isConnected || false;
            this.currentSpeed = result.currentSpeed || 0;
            this.clientVersion = result.clientVersion || 'Unknown';
            
            // Update toggle states
            document.getElementById('enable-detection').checked = result.enableDetection !== false;
            document.getElementById('smart-category').checked = result.smartCategory !== false;
            
            // Update proxy toggle state
            const proxyToggle = document.getElementById('enable-proxy');
            if (proxyToggle) {
                proxyToggle.checked = !result.shouldDisableProxy; // 注意逻辑反转
            }
            
            // Store settings for modal use
            this.allowedExtensions = result.allowedExtensions || [];
            this.whitelistDomains = result.whitelistDomains || [];
        } catch (error) {
            console.error('Failed to load settings:', error);
        }
    }

    setupEventListeners() {
        // Quick download button
        document.getElementById('quick-download').addEventListener('click', () => {
            this.handleQuickDownload();
        });

        // Open manager button
        document.getElementById('open-manager').addEventListener('click', () => {
            this.openManager();
        });

        // Enable detection toggle
        document.getElementById('enable-detection').addEventListener('change', (e) => {
            this.updateSetting('enableDetection', e.target.checked);
        });

        // Smart category toggle
        document.getElementById('smart-category').addEventListener('change', (e) => {
            this.updateSetting('smartCategory', e.target.checked);
        });

        // Proxy download toggle
        const proxyToggle = document.getElementById('enable-proxy');
        if (proxyToggle) {
            proxyToggle.addEventListener('change', (e) => {
                this.toggleProxy(e.target.checked);
            });
        }

        // Settings buttons
        document.getElementById('extensions-setting').addEventListener('click', () => {
            this.showExtensionsSettings();
        });

        document.getElementById('domains-setting').addEventListener('click', () => {
            this.showDomainsSettings();
        });

        // Modal controls
        document.getElementById('modal-close').addEventListener('click', () => {
            this.hideModal();
        });

        document.getElementById('modal-cancel').addEventListener('click', () => {
            this.hideModal();
        });

        document.getElementById('modal-save').addEventListener('click', () => {
            this.saveModalSettings();
        });

        // Listen for storage changes
        chrome.storage.onChanged.addListener((changes, areaName) => {
            if (areaName === 'local') {
                this.handleStorageChange(changes);
            }
        });

        // Listen for messages from background script
        chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
            this.handleMessage(message, sender, sendResponse);
        });

        // Add click handler for link detection card
        document.getElementById('link-detection-card').addEventListener('click', () => {
            if (!this.isScanning) {
                this.startLinkDetection();
            }
        });
    }

    async handleQuickDownload() {
        try {
            // Get current tab URL
            const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
            
            if (!tab || !tab.url) {
                this.showNotification('无法获取当前页面URL', 'error');
                return;
            }

            // Check if URL is downloadable
            if (this.isDownloadableUrl(tab.url)) {
                await this.sendDownloadRequest(tab.url, tab.title);
                this.showNotification('下载任务已添加', 'success');
            } else {
                // Try to find download links on the page
                chrome.tabs.sendMessage(tab.id, { action: 'findDownloadLinks' }, (response) => {
                    if (response && response.links && response.links.length > 0) {
                        this.showDownloadOptions(response.links);
                    } else {
                        this.showNotification('未找到可下载的链接', 'warning');
                    }
                });
            }
        } catch (error) {
            console.error('Quick download failed:', error);
            this.showNotification('快速下载失败', 'error');
        }
    }

    async openManager() {
        try {
            // First try to communicate with HDM-X client directly
            const response = await this.sendToClient({ action: 'openManager' });
            
            if (response && response.success) {
                this.showNotification('HDM-X 管理器已打开', 'success');
                window.close();
                return;
            }
            
            // Try to open via background script protocol handler
            try {
                const bgResponse = await chrome.runtime.sendMessage({ action: 'openManager' });
                if (bgResponse && bgResponse.success) {
                    this.showNotification('正在打开 HDM-X 管理器...', 'info');
                    setTimeout(() => window.close(), 1000);
                    return;
                }
            } catch (e) {
                console.log('Background script method failed:', e);
            }
            
            // Fallback: Try direct protocol methods
            const protocolUrl = 'hdmx://open';
            
            try {
                // Method 1: Create invisible iframe (most reliable for protocols)
                const iframe = document.createElement('iframe');
                iframe.style.display = 'none';
                iframe.style.width = '1px';
                iframe.style.height = '1px';
                iframe.src = protocolUrl;
                document.body.appendChild(iframe);
                
                this.showNotification('正在尝试打开 HDM-X 管理器...', 'info');
                
                // Clean up iframe and close popup
                setTimeout(() => {
                    try {
                        document.body.removeChild(iframe);
                    } catch (e) {
                        console.log('Could not remove iframe:', e);
                    }
                    window.close();
                }, 2000);
                return;
            } catch (e) {
                console.log('Iframe method failed:', e);
            }
            
            try {
                // Method 2: Use location.href
                window.location.href = protocolUrl;
                this.showNotification('正在尝试打开 HDM-X 管理器...', 'info');
                setTimeout(() => window.close(), 1000);
                return;
            } catch (e) {
                console.log('Location.href method failed:', e);
            }
            
            // If all methods fail
            this.showNotification('无法打开管理器。请确保 HDM-X 客户端已安装并正在运行。', 'warning');
            
        } catch (error) {
            console.error('Failed to open manager:', error);
            this.showNotification('无法打开管理器，请检查 HDM-X 客户端状态', 'error');
        }
    }

    async updateSetting(key, value) {
        try {
            await chrome.storage.local.set({ [key]: value });
            
            // Notify background script
            chrome.runtime.sendMessage({
                action: 'settingChanged',
                key: key,
                value: value
            });

            // Send to client if connected
            if (this.isConnected) {
                await this.sendToClient({
                    action: 'updateSetting',
                    key: key,
                    value: value
                });
            }

            // Notify content script to update settings immediately
            try {
                const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
                if (tab) {
                    chrome.tabs.sendMessage(tab.id, { action: 'updateSettings' });
                }
            } catch (error) {
                console.log('Could not notify content script:', error);
            }
        } catch (error) {
            console.error('Failed to update setting:', error);
        }
    }

    handleStorageChange(changes) {
        if (changes.isConnected) {
            this.isConnected = changes.isConnected.newValue;
            this.updateConnectionStatus();
        }

        // Download count removed as it's not needed

        if (changes.currentSpeed) {
            this.currentSpeed = changes.currentSpeed.newValue;
            this.updateSpeedDisplay();
        }

        if (changes.clientVersion) {
            this.clientVersion = changes.clientVersion.newValue;
            this.updateVersionInfo();
        }
    }

    handleMessage(message, _sender, _sendResponse) {
        switch (message.action) {
            case 'updateStats':
                this.updateStats(message.data);
                break;
            case 'connectionChanged':
                this.isConnected = message.connected;
                this.updateConnectionStatus();
                break;
            case 'showNotification':
                this.showNotification(message.text, message.type);
                break;
            case 'linksFound':
                this.linkCount = message.count || 0;
                this.updateDetectionStatus(
                    this.linkCount > 0 ? `发现 ${this.linkCount} 个下载链接` : '未发现下载链接',
                    this.linkCount
                );
                this.animateProgress(this.linkCount > 0 ? 100 : 0);
                break;
            case 'proxyToggled':
                this.showNotification(
                    message.enabled ? '代理下载已启用' : '代理下载已禁用', 
                    'info'
                );
                break;
        }
    }

    updateUI() {
        this.updateConnectionStatus();
        this.updateSpeedDisplay();
        this.updateVersionInfo();
    }

    updateConnectionStatus() {
        const statusDot = document.querySelector('.status-dot');
        const statusText = document.querySelector('.status-text');
        
        if (this.isConnected) {
            statusDot.classList.remove('disconnected');
            statusText.textContent = '已连接';
            statusText.className = 'status-text connected';
        } else {
            statusDot.classList.add('disconnected');
            statusText.textContent = '未连接';
            statusText.className = 'status-text disconnected';
        }
        
        // Also update footer connection status
        this.updateFooterConnectionStatus();
    }

    updateFooterConnectionStatus() {
        const clientVersionEl = document.getElementById('client-version');
        if (clientVersionEl) {
            if (this.isConnected && this.clientVersion !== 'Unknown') {
                clientVersionEl.textContent = `客户端 v${this.clientVersion}`;
                clientVersionEl.style.color = 'var(--success-color)';
            } else {
                clientVersionEl.textContent = '客户端未连接';
                clientVersionEl.style.color = 'var(--error-color)';
            }
        }
    }

    updateSpeedDisplay() {
        // Speed display removed from UI, but keep method for compatibility
        console.log('Current speed:', this.formatSpeed(this.currentSpeed));
    }

    updateVersionInfo() {
        document.getElementById('extension-version').textContent = `v${this.extensionVersion}`;
        this.updateFooterConnectionStatus();
    }

    animateNumber(element, targetValue) {
        const currentValue = parseInt(element.textContent) || 0;
        const increment = targetValue > currentValue ? 1 : -1;
        const duration = 300;
        const steps = Math.abs(targetValue - currentValue);
        const stepDuration = steps > 0 ? duration / steps : 0;

        let current = currentValue;
        const timer = setInterval(() => {
            current += increment;
            element.textContent = current;
            
            if (current === targetValue) {
                clearInterval(timer);
            }
        }, stepDuration);
    }

    animateStats() {
        // Add subtle animation to stat cards
        const statCards = document.querySelectorAll('.stat-card');
        statCards.forEach((card, index) => {
            setTimeout(() => {
                card.style.opacity = '0';
                card.style.transform = 'translateY(10px)';
                card.style.transition = 'all 0.3s ease';
                
                setTimeout(() => {
                    card.style.opacity = '1';
                    card.style.transform = 'translateY(0)';
                }, 50);
            }, index * 100);
        });
    }

    formatSpeed(bytesPerSecond) {
        if (bytesPerSecond === 0) return '0 KB/s';
        
        const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
        let size = bytesPerSecond;
        let unitIndex = 0;
        
        while (size >= 1024 && unitIndex < units.length - 1) {
            size /= 1024;
            unitIndex++;
        }
        
        return `${size.toFixed(1)} ${units[unitIndex]}`;
    }

    isDownloadableUrl(url) {
        const downloadableExtensions = [
            '.zip', '.rar', '.7z', '.tar', '.gz',
            '.exe', '.msi', '.dmg', '.pkg', '.deb', '.rpm',
            '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv',
            '.mp3', '.wav', '.flac', '.aac', '.ogg',
            '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
            '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg'
        ];
        
        return downloadableExtensions.some(ext => url.toLowerCase().includes(ext));
    }

    async sendDownloadRequest(url, title = '') {
        const downloadData = {
            url: url,
            filename: title || this.extractFilenameFromUrl(url),
            timestamp: Date.now(),
            source: 'browser_extension'
        };

        // Send to background script
        chrome.runtime.sendMessage({
            action: 'addDownload',
            data: downloadData
        });

        // Send to client if connected
        if (this.isConnected) {
            await this.sendToClient({
                action: 'addDownload',
                data: downloadData
            });
        }
    }

    async sendToClient(message) {
        return new Promise((resolve) => {
            chrome.runtime.sendMessage({
                action: 'sendToClient',
                message: message
            }, (response) => {
                resolve(response);
            });
        });
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

    // Download count tracking removed

    showNotification(message, type = 'info') {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.textContent = message;
        
        // Style the notification
        Object.assign(notification.style, {
            position: 'fixed',
            top: '10px',
            right: '10px',
            padding: '12px 16px',
            borderRadius: '8px',
            color: 'white',
            fontSize: '14px',
            fontWeight: '500',
            zIndex: '10000',
            opacity: '0',
            transform: 'translateX(100%)',
            transition: 'all 0.3s ease'
        });

        // Set background color based on type (Hyper theme)
        const colors = {
            success: '#50fa7b',
            error: '#ff5555',
            warning: '#f1fa8c',
            info: '#ff79c6'
        };
        notification.style.backgroundColor = colors[type] || colors.info;

        document.body.appendChild(notification);

        // Animate in
        setTimeout(() => {
            notification.style.opacity = '1';
            notification.style.transform = 'translateX(0)';
        }, 10);

        // Remove after 3 seconds
        setTimeout(() => {
            notification.style.opacity = '0';
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => {
                document.body.removeChild(notification);
            }, 300);
        }, 3000);
    }

    startStatusCheck() {
        // Check connection status every 3 seconds
        setInterval(async () => {
            try {
                // Get current connection status from storage
                const result = await chrome.storage.local.get(['isConnected']);
                const currentStatus = result.isConnected || false;
                
                if (currentStatus !== this.isConnected) {
                    this.isConnected = currentStatus;
                    this.updateConnectionStatus();
                }
            } catch (error) {
                console.error('Error checking connection status:', error);
            }
        }, 3000);
    }

    updateStats(data) {
        if (data.currentSpeed !== undefined) {
            this.currentSpeed = data.currentSpeed;
            this.updateSpeedDisplay();
        }
    }

    async startLinkDetection() {
        try {
            this.isScanning = true;
            this.updateDetectionStatus('正在扫描...', 0);
            
            // Get current tab
            const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
            
            if (!tab || !tab.url || tab.url.startsWith('chrome://') || tab.url.startsWith('chrome-extension://')) {
                this.updateDetectionStatus('无法扫描此页面', 0);
                return;
            }

            // Send message to content script to find links
            chrome.tabs.sendMessage(tab.id, { action: 'findDownloadLinks' }, (response) => {
                if (chrome.runtime.lastError) {
                    this.updateDetectionStatus('页面未加载完成', 0);
                    return;
                }
                
                if (response && response.links) {
                    this.linkCount = response.links.length;
                    this.updateDetectionStatus(
                        this.linkCount > 0 ? `发现 ${this.linkCount} 个下载链接` : '未发现下载链接',
                        this.linkCount
                    );
                    this.animateProgress(this.linkCount > 0 ? 100 : 0);
                } else {
                    this.updateDetectionStatus('扫描完成', 0);
                    this.animateProgress(0);
                }
                
                this.isScanning = false;
            });
            
        } catch (error) {
            console.error('Link detection failed:', error);
            this.updateDetectionStatus('扫描失败', 0);
            this.isScanning = false;
        }
    }

    updateDetectionStatus(status, count) {
        const statusEl = document.getElementById('detection-status');
        const countEl = document.getElementById('link-count');
        
        if (statusEl) statusEl.textContent = status;
        if (countEl) countEl.textContent = count.toString();
    }

    animateProgress(targetPercent) {
        const progressBar = document.getElementById('progress-bar');
        if (!progressBar) return;
        
        let currentPercent = 0;
        const increment = targetPercent / 20; // 20 steps
        
        const timer = setInterval(() => {
            currentPercent += increment;
            if (currentPercent >= targetPercent) {
                currentPercent = targetPercent;
                clearInterval(timer);
            }
            progressBar.style.width = `${currentPercent}%`;
        }, 50);
    }

    showExtensionsSettings() {
        const modalTitle = document.getElementById('modal-title');
        const modalBody = document.getElementById('modal-body');
        
        modalTitle.textContent = '文件扩展名设置';
        
        const extensions = this.allowedExtensions.length > 0 ? this.allowedExtensions : [
            '.zip', '.rar', '.7z', '.exe', '.msi', '.dmg', '.pdf', '.apk', '.iso'
        ];
        
        modalBody.innerHTML = `
            <div class="settings-form">
                <div class="form-group">
                    <label class="form-label">支持的文件扩展名</label>
                    <textarea class="form-input form-textarea" id="extensions-input" placeholder="每行一个扩展名，例如：&#10;.zip&#10;.exe&#10;.pdf">${extensions.join('\n')}</textarea>
                    <div class="form-help">每行输入一个文件扩展名，以点号开头</div>
                </div>
                <div class="tag-list" id="extensions-preview">
                    ${extensions.map(ext => `<span class="tag">${ext}</span>`).join('')}
                </div>
            </div>
        `;
        
        // Update preview on input
        const input = document.getElementById('extensions-input');
        input.addEventListener('input', () => {
            const preview = document.getElementById('extensions-preview');
            const exts = input.value.split('\n').filter(ext => ext.trim()).map(ext => ext.trim());
            preview.innerHTML = exts.map(ext => `<span class="tag">${ext}</span>`).join('');
        });
        
        this.showModal();
    }

    showDomainsSettings() {
        const modalTitle = document.getElementById('modal-title');
        const modalBody = document.getElementById('modal-body');
        
        modalTitle.textContent = '白名单域名设置';
        
        modalBody.innerHTML = `
            <div class="settings-form">
                <div class="form-group">
                    <label class="form-label">允许的域名</label>
                    <textarea class="form-input form-textarea" id="domains-input" placeholder="每行一个域名，例如：&#10;github.com&#10;example.com&#10;&#10;留空表示允许所有域名">${this.whitelistDomains.join('\n')}</textarea>
                    <div class="form-help">每行输入一个域名，留空表示允许所有域名</div>
                </div>
                <div class="tag-list" id="domains-preview">
                    ${this.whitelistDomains.map(domain => `<span class="tag">${domain}</span>`).join('')}
                </div>
            </div>
        `;
        
        // Update preview on input
        const input = document.getElementById('domains-input');
        input.addEventListener('input', () => {
            const preview = document.getElementById('domains-preview');
            const domains = input.value.split('\n').filter(domain => domain.trim()).map(domain => domain.trim());
            preview.innerHTML = domains.map(domain => `<span class="tag">${domain}</span>`).join('');
        });
        
        this.showModal();
    }

    showModal() {
        const modal = document.getElementById('settings-modal');
        modal.style.display = 'flex';
        
        // Animate in
        setTimeout(() => {
            modal.style.opacity = '1';
        }, 10);
    }

    hideModal() {
        const modal = document.getElementById('settings-modal');
        modal.style.display = 'none';
    }

    async saveModalSettings() {
        const modalTitle = document.getElementById('modal-title').textContent;
        
        if (modalTitle.includes('扩展名')) {
            // Save extensions
            const input = document.getElementById('extensions-input');
            const extensions = input.value.split('\n')
                .filter(ext => ext.trim())
                .map(ext => ext.trim())
                .filter(ext => ext.startsWith('.'));
            
            await this.updateSetting('allowedExtensions', extensions);
            this.allowedExtensions = extensions;
            
        } else if (modalTitle.includes('域名')) {
            // Save domains
            const input = document.getElementById('domains-input');
            const domains = input.value.split('\n')
                .filter(domain => domain.trim())
                .map(domain => domain.trim().toLowerCase());
            
            await this.updateSetting('whitelistDomains', domains);
            this.whitelistDomains = domains;
        }
        
        // Notify content script to update settings
        try {
            const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
            if (tab) {
                chrome.tabs.sendMessage(tab.id, { action: 'updateSettings' });
            }
        } catch (error) {
            console.log('Could not notify content script:', error);
        }
        
        this.hideModal();
        this.showNotification('设置已保存', 'success');
    }

    async toggleProxy(enabled) {
        try {
            // Send message to background script
            const response = await chrome.runtime.sendMessage({
                action: 'toggleProxy',
                enabled: enabled
            });

            if (response && response.success) {
                this.showNotification(
                    enabled ? '代理下载已启用' : '代理下载已禁用', 
                    'success'
                );
            } else {
                this.showNotification('设置更新失败', 'error');
            }
        } catch (error) {
            console.error('Failed to toggle proxy:', error);
            this.showNotification('设置更新失败', 'error');
        }
    }
}

// Initialize popup when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    new HDMXPopup();
});

// Handle theme changes
const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
mediaQuery.addEventListener('change', (e) => {
    document.body.classList.toggle('dark-theme', e.matches);
});

// Set initial theme
if (mediaQuery.matches) {
    document.body.classList.add('dark-theme');
}