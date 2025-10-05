// HDM-X Browser Extension Content Script - Simplified Direct Link Detection
class HDMXContent {
    constructor() {
        console.log('HDM-X: Initializing HDMXContent class');
        this.downloadLinks = [];
        this.observer = null;
        this.settings = {
            allowedExtensions: [],
            whitelistDomains: [],
            enableDetection: true
        };
        this.init();
    }

    async init() {
        console.log('HDM-X: Starting initialization...');

        // Load user settings first
        await this.loadSettings();

        this.setupMessageListener();

        // Only scan and add buttons if detection is enabled
        if (this.settings.enableDetection) {
            console.log('HDM-X: Detection enabled, scanning for links...');
            this.scanForDownloadLinks();
            this.setupMutationObserver();
            this.addDownloadButtons();
        } else {
            console.log('HDM-X: Link detection is disabled');
        }

        console.log('HDM-X: Initialization complete');
    }

    async loadSettings() {
        try {
            const result = await chrome.storage.local.get([
                'allowedExtensions',
                'whitelistDomains',
                'enableDetection'
            ]);

            // Default file extensions - expanded list
            this.settings.allowedExtensions = result.allowedExtensions || [
                // 压缩文件
                '.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.lzma', '.z',
                // 可执行文件
                '.exe', '.msi', '.dmg', '.pkg', '.deb', '.rpm', '.appimage', '.run', '.app',
                // 安装包
                '.apk', '.ipa', '.xap', '.cab', '.msu',
                // 文档文件
                '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.odt', '.ods', '.odp',
                // 系统镜像
                '.iso', '.img', '.bin', '.vhd', '.vmdk',
                // 字体文件
                '.ttf', '.otf', '.woff', '.woff2', '.eot',
                // 电子书
                '.epub', '.mobi', '.azw', '.azw3', '.fb2',
                // 其他常见下载文件
                '.torrent', '.jar', '.war', '.ear', '.deb', '.snap'
            ];

            // Default whitelist domains (empty means all domains allowed)
            this.settings.whitelistDomains = result.whitelistDomains || [];

            this.settings.enableDetection = result.enableDetection !== false;

            console.log('HDM-X: Settings loaded:', {
                enableDetection: this.settings.enableDetection,
                allowedExtensions: this.settings.allowedExtensions.length,
                whitelistDomains: this.settings.whitelistDomains.length
            });

        } catch (error) {
            console.error('Failed to load HDM-X settings:', error);
        }
    }

    setupMessageListener() {
        chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
            switch (message.action) {
                case 'findDownloadLinks':
                    this.scanForDownloadLinks();
                    sendResponse({ links: this.downloadLinks });
                    break;

                case 'highlightDownloads':
                    this.highlightDownloadLinks();
                    sendResponse({ success: true });
                    break;

                case 'removeHighlight':
                    this.removeHighlight();
                    sendResponse({ success: true });
                    break;

                case 'updateSettings':
                    this.loadSettings().then(() => {
                        // First remove all existing buttons
                        this.removeAllDownloadButtons();

                        // Stop mutation observer if detection is disabled
                        if (!this.settings.enableDetection && this.observer) {
                            this.observer.disconnect();
                            this.observer = null;
                        }

                        // Then rescan and add new buttons if detection is enabled
                        if (this.settings.enableDetection) {
                            this.scanForDownloadLinks();
                            this.addDownloadButtons();
                            // Restart mutation observer if needed
                            if (!this.observer) {
                                this.setupMutationObserver();
                            }
                        } else {
                            // Clear download links when detection is disabled
                            this.downloadLinks = [];
                            this.notifyPopupOfLinks();
                        }
                    });
                    sendResponse({ success: true });
                    break;
            }
        });
    }

    scanForDownloadLinks() {
        // Clear existing download links
        this.downloadLinks = [];

        if (!this.settings.enableDetection) {
            // Remove all existing HDM-X buttons when detection is disabled
            this.removeAllDownloadButtons();
            this.notifyPopupOfLinks();
            return;
        }

        // Only scan for direct download links (a[href] with downloadable files)
        const links = document.querySelectorAll('a[href]');
        console.log(`HDM-X: Scanning ${links.length} links on page`);

        links.forEach(link => {
            const href = link.href;
            const text = link.textContent.trim();

            console.log(`HDM-X: Checking link: ${href}`);

            if (this.isDirectDownloadLink(href)) {
                console.log(`HDM-X: ✅ Found direct download link: ${href}`);
                this.downloadLinks.push({
                    url: href,
                    text: text || this.extractFilenameFromUrl(href),
                    element: link,
                    type: 'direct_link'
                });
            } else {
                console.log(`HDM-X: ❌ Not a direct download link: ${href}`);
            }
        });

        // Remove duplicates based on URL
        this.downloadLinks = this.downloadLinks.filter((link, index, self) =>
            index === self.findIndex(l => l.url === link.url)
        );

        console.log(`HDM-X: Detection enabled: ${this.settings.enableDetection}, Found ${this.downloadLinks.length} direct download links:`, this.downloadLinks);

        // Notify popup about the link count
        this.notifyPopupOfLinks();
    }

    isDirectDownloadLink(url) {
        try {
            console.log(`HDM-X: Checking if direct download: ${url}`);

            const urlObj = new URL(url);
            const pathname = urlObj.pathname.toLowerCase();
            const hostname = urlObj.hostname.toLowerCase();

            console.log(`HDM-X: Parsed URL - hostname: ${hostname}, pathname: ${pathname}`);

            // Skip javascript: and data: URLs
            if (url.startsWith('javascript:') || url.startsWith('data:')) {
                console.log('HDM-X: Skipping javascript/data URL');
                return false;
            }

            // Check whitelist domains if configured
            if (this.settings.whitelistDomains.length > 0) {
                const isWhitelisted = this.settings.whitelistDomains.some(domain =>
                    hostname === domain.toLowerCase() || hostname.endsWith('.' + domain.toLowerCase())
                );
                if (!isWhitelisted) {
                    console.log('HDM-X: Domain not whitelisted');
                    return false;
                }
            }

            // Check if URL ends with allowed file extensions
            const hasAllowedExtension = this.settings.allowedExtensions.some(ext => {
                const lowerExt = ext.toLowerCase();
                const hasExt = pathname.endsWith(lowerExt) ||
                    pathname.includes(lowerExt + '?') ||
                    pathname.includes(lowerExt + '#');

                if (hasExt) {
                    console.log(`HDM-X: Found matching extension: ${ext}`);
                }

                return hasExt;
            });

            if (!hasAllowedExtension) {
                console.log('HDM-X: No matching file extension found');
                console.log('HDM-X: Available extensions:', this.settings.allowedExtensions);
                return false;
            }

            // Exclude common non-direct-download patterns
            const excludePatterns = [
                '/thumb/', '/preview/', '/small/', '/medium/', '/large/',
                '/gallery/', '/album/', '/photos/', '/images/',
                '/view/', '/show/', '/display/', '/page/',
                'thumbnail', 'preview', 'avatar', 'profile',
                'action=view', 'action=show', 'mode=view'
            ];

            const isExcluded = excludePatterns.some(pattern => url.toLowerCase().includes(pattern));
            if (isExcluded) {
                console.log('HDM-X: URL matches exclusion pattern');
                return false;
            }

            console.log('HDM-X: ✅ URL is a direct download link');
            return true;

        } catch (error) {
            // URL parsing failed
            console.warn('HDM-X: Failed to parse URL:', url, error);
            return false;
        }
    }

    setupMutationObserver() {
        // Only setup observer if detection is enabled
        if (!this.settings.enableDetection) {
            return;
        }

        // Watch for dynamically added content
        this.observer = new MutationObserver((mutations) => {
            // Double check if detection is still enabled
            if (!this.settings.enableDetection) {
                return;
            }

            let shouldRescan = false;

            mutations.forEach(mutation => {
                if (mutation.type === 'childList') {
                    mutation.addedNodes.forEach(node => {
                        if (node.nodeType === Node.ELEMENT_NODE) {
                            const hasLinks = node.querySelectorAll &&
                                node.querySelectorAll('a[href]').length > 0;
                            if (hasLinks) {
                                shouldRescan = true;
                            }
                        }
                    });
                }
            });

            if (shouldRescan) {
                setTimeout(() => {
                    if (this.settings.enableDetection) {
                        this.scanForDownloadLinks();
                        this.addDownloadButtons();
                    }
                }, 500);
            }
        });

        this.observer.observe(document.body, {
            childList: true,
            subtree: true
        });
    }

    notifyPopupOfLinks() {
        // Notify popup about link count changes
        chrome.runtime.sendMessage({
            action: 'linksFound',
            count: this.downloadLinks.length
        }).catch(() => {
            // Popup might not be open, ignore error
        });
    }

    addDownloadButtons() {
        // Remove all existing buttons first
        this.removeAllDownloadButtons();

        console.log(`HDM-X: Adding buttons for ${this.downloadLinks.length} download links`);

        // Add HDM-X download buttons to detected download links
        this.downloadLinks.forEach((linkData, index) => {
            console.log(`HDM-X: Processing link ${index + 1}:`, linkData.url);

            if (linkData.element && !this.hasDownloadButton(linkData.element)) {
                console.log(`HDM-X: Adding button for: ${linkData.url}`);
                this.addDownloadButton(linkData);
            } else {
                console.log(`HDM-X: Skipping button for: ${linkData.url} (element missing or button exists)`);
            }
        });

        console.log(`HDM-X: Button addition complete. Total containers: ${document.querySelectorAll('.hdmx-button-container').length}`);
    }

    removeAllDownloadButtons() {
        // Remove all existing HDM-X button containers
        const existingContainers = document.querySelectorAll('.hdmx-button-container');
        console.log(`HDM-X: Removing ${existingContainers.length} existing buttons`);

        existingContainers.forEach(container => {
            try {
                if (container.parentNode) {
                    container.parentNode.removeChild(container);
                }
            } catch (error) {
                console.error('Error removing HDM-X button:', error);
            }
        });
    }

    hasDownloadButton(element) {
        // Check if element already has a download button nearby
        const parent = element.parentNode;
        if (!parent) return false;

        // Check next sibling for button container
        const nextSibling = element.nextSibling;
        if (nextSibling && nextSibling.classList && nextSibling.classList.contains('hdmx-button-container')) {
            return true;
        }

        // Check for any existing button in the parent
        return parent.querySelector('.hdmx-download-btn') !== null;
    }

    addDownloadButton(linkData) {
        // Create container for the button
        const container = document.createElement('div');
        container.className = 'hdmx-button-container';
        container.style.cssText = `
            position: relative;
            display: inline-block;
            margin-left: 8px;
            vertical-align: middle;
        `;

        const button = document.createElement('button');
        button.className = 'hdmx-download-btn';
        button.setAttribute('data-url', linkData.url); // Store URL for identification

        // Create beautiful button with enhanced styling
        button.innerHTML = `
            <div class="hdmx-btn-content">
                <svg class="hdmx-btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none">
                    <path d="M21 15V19A2 2 0 0 1 19 21H5A2 2 0 0 1 3 19V15" stroke="currentColor" stroke-width="2"/>
                    <polyline points="7,10 12,15 17,10" stroke="currentColor" stroke-width="2"/>
                    <line x1="12" y1="15" x2="12" y2="3" stroke="currentColor" stroke-width="2"/>
                </svg>
                <span class="hdmx-btn-text">HDM-X</span>
            </div>
        `;

        // Enhanced styling with modern design - COMPLETELY HIDDEN BY DEFAULT
        Object.assign(button.style, {
            position: 'relative',
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '6px 12px',
            fontSize: '11px',
            fontWeight: '600',
            fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
            color: '#ffffff',
            background: 'linear-gradient(135deg, #ff79c6, #bd93f9)',
            border: 'none',
            borderRadius: '6px',
            cursor: 'pointer',
            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
            zIndex: '10000',
            boxShadow: '0 2px 8px rgba(255, 121, 198, 0.3)',
            opacity: '0',
            transform: 'translateY(8px) scale(0.8)',
            pointerEvents: 'none',
            minWidth: '70px',
            height: '28px',
            visibility: 'hidden'  // Extra hiding
        });

        // Add internal styling for content
        const style = document.createElement('style');
        style.textContent = `
            .hdmx-button-container {
                position: relative !important;
                display: inline-block !important;
                margin-left: 8px !important;
                vertical-align: middle !important;
                z-index: 10000 !important;
            }
            .hdmx-download-btn {
                all: initial !important;
                position: relative !important;
                display: inline-flex !important;
                align-items: center !important;
                justify-content: center !important;
                padding: 6px 12px !important;
                font-size: 11px !important;
                font-weight: 600 !important;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif !important;
                color: #ffffff !important;
                background: linear-gradient(135deg, #ff79c6, #bd93f9) !important;
                border: none !important;
                border-radius: 6px !important;
                cursor: pointer !important;
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1) !important;
                z-index: 10000 !important;
                box-shadow: 0 2px 8px rgba(255, 121, 198, 0.3) !important;
                min-width: 70px !important;
                height: 28px !important;
                text-decoration: none !important;
                line-height: 1 !important;
                /* Default completely hidden state */
                opacity: 0 !important;
                transform: translateY(8px) scale(0.8) !important;
                pointer-events: none !important;
                visibility: hidden !important;
            }
            .hdmx-btn-content {
                display: flex !important;
                align-items: center !important;
                gap: 4px !important;
                pointer-events: none !important;
            }
            .hdmx-btn-icon {
                flex-shrink: 0 !important;
                transition: transform 0.2s ease !important;
                pointer-events: none !important;
            }
            .hdmx-btn-text {
                font-size: 11px !important;
                font-weight: 600 !important;
                white-space: nowrap !important;
                pointer-events: none !important;
            }
            .hdmx-download-btn:hover .hdmx-btn-icon {
                transform: translateY(-1px) !important;
            }
            .hdmx-download-btn.loading .hdmx-btn-icon {
                animation: hdmx-spin 1s linear infinite !important;
            }
            @keyframes hdmx-spin {
                from { transform: rotate(0deg) !important; }
                to { transform: rotate(360deg) !important; }
            }
        `;

        if (!document.head.querySelector('#hdmx-button-styles')) {
            style.id = 'hdmx-button-styles';
            document.head.appendChild(style);
        }

        // Add hover effects with enhanced animations
        button.addEventListener('mouseenter', () => {
            if (!button.classList.contains('loading')) {
                button.style.transform = 'translateY(0) scale(1.05)';
                button.style.boxShadow = '0 4px 16px rgba(255, 121, 198, 0.4)';
                button.style.background = 'linear-gradient(135deg, #ff6ac1, #a855f7)';
            }
        });

        button.addEventListener('mouseleave', () => {
            if (!button.classList.contains('loading')) {
                button.style.transform = 'translateY(0) scale(1)';
                button.style.boxShadow = '0 2px 8px rgba(255, 121, 198, 0.3)';
                button.style.background = 'linear-gradient(135deg, #ff79c6, #bd93f9)';
            }
        });

        // Add click handler with proper button identification
        button.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            this.downloadWithHDMX(linkData, button);
        });

        container.appendChild(button);

        // Setup hover detection for the parent element - ONLY SHOW ON HOVER
        this.setupHoverDetection(linkData.element, container);

        // Insert container next to the link
        try {
            if (linkData.element.parentNode) {
                linkData.element.parentNode.insertBefore(container, linkData.element.nextSibling);
            }
        } catch (error) {
            console.error('Error adding download button:', error);
        }
    }

    setupHoverDetection(targetElement, buttonContainer) {
        let hoverTimeout;
        let isNearButton = false;

        const showButton = () => {
            const button = buttonContainer.querySelector('.hdmx-download-btn');
            if (button) {
                console.log('HDM-X: Showing button for:', targetElement.href);
                button.style.visibility = 'visible';
                button.style.opacity = '1';
                button.style.transform = 'translateY(0) scale(1)';
                button.style.pointerEvents = 'auto';
            }
        };

        const hideButton = () => {
            if (!isNearButton) {
                const button = buttonContainer.querySelector('.hdmx-download-btn');
                if (button && !button.classList.contains('loading')) {
                    console.log('HDM-X: Hiding button for:', targetElement.href);
                    button.style.opacity = '0';
                    button.style.transform = 'translateY(8px) scale(0.8)';
                    button.style.pointerEvents = 'none';
                    // Hide completely after animation
                    setTimeout(() => {
                        if (button.style.opacity === '0') {
                            button.style.visibility = 'hidden';
                        }
                    }, 300);
                }
            }
        };

        // Target element hover - more responsive
        targetElement.addEventListener('mouseenter', () => {
            console.log('HDM-X: Mouse entered target element:', targetElement.href);
            clearTimeout(hoverTimeout);
            showButton();
        });

        targetElement.addEventListener('mouseleave', () => {
            console.log('HDM-X: Mouse left target element:', targetElement.href);
            hoverTimeout = setTimeout(hideButton, 200);  // Faster hide
        });

        // Button container hover
        buttonContainer.addEventListener('mouseenter', () => {
            console.log('HDM-X: Mouse entered button container');
            isNearButton = true;
            clearTimeout(hoverTimeout);
            showButton();
        });

        buttonContainer.addEventListener('mouseleave', () => {
            console.log('HDM-X: Mouse left button container');
            isNearButton = false;
            hoverTimeout = setTimeout(hideButton, 200);  // Faster hide
        });
    }

    async downloadWithHDMX(linkData, clickedButton) {
        try {
            // Use the specific button that was clicked
            const button = clickedButton;
            if (!button) return;

            // Show loading state
            button.classList.add('loading');
            button.style.opacity = '1';
            button.style.pointerEvents = 'none';
            button.style.background = 'linear-gradient(135deg, #6b7280, #9ca3af)';
            button.innerHTML = `
                <div class="hdmx-btn-content">
                    <svg class="hdmx-btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none">
                        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                        <path d="M12 6V12L16 14" stroke="currentColor" stroke-width="2"/>
                    </svg>
                    <span class="hdmx-btn-text">处理中</span>
                </div>
            `;

            // Send download request to background script
            const response = await chrome.runtime.sendMessage({
                action: 'addDownload',
                data: {
                    url: linkData.url,
                    filename: linkData.text,
                    timestamp: Date.now(),
                    source: 'content_script'
                }
            });

            if (response && response.success) {
                this.showNotification('下载任务已添加到 HDM-X', 'success');

                // Show success state
                button.style.background = 'linear-gradient(135deg, #10b981, #059669)';
                button.innerHTML = `
                    <div class="hdmx-btn-content">
                        <svg class="hdmx-btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none">
                            <path d="M20 6L9 17L4 12" stroke="currentColor" stroke-width="2"/>
                        </svg>
                        <span class="hdmx-btn-text">已添加</span>
                    </div>
                `;
            } else {
                this.showNotification('添加下载任务失败', 'error');

                // Show error state
                button.style.background = 'linear-gradient(135deg, #ef4444, #dc2626)';
                button.innerHTML = `
                    <div class="hdmx-btn-content">
                        <svg class="hdmx-btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none">
                            <path d="M18 6L6 18" stroke="currentColor" stroke-width="2"/>
                            <path d="M6 6L18 18" stroke="currentColor" stroke-width="2"/>
                        </svg>
                        <span class="hdmx-btn-text">失败</span>
                    </div>
                `;
            }

            // Restore button state after delay
            setTimeout(() => {
                button.classList.remove('loading');
                button.style.pointerEvents = 'auto';
                button.style.background = 'linear-gradient(135deg, #ff79c6, #bd93f9)';
                button.innerHTML = `
                    <div class="hdmx-btn-content">
                        <svg class="hdmx-btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none">
                            <path d="M21 15V19A2 2 0 0 1 19 21H5A2 2 0 0 1 3 19V15" stroke="currentColor" stroke-width="2"/>
                            <polyline points="7,10 12,15 17,10" stroke="currentColor" stroke-width="2"/>
                            <line x1="12" y1="15" x2="12" y2="3" stroke="currentColor" stroke-width="2"/>
                        </svg>
                        <span class="hdmx-btn-text">HDM-X</span>
                    </div>
                `;
            }, 2000);

        } catch (error) {
            console.error('Error downloading with HDM-X:', error);
            this.showNotification('下载失败', 'error');

            // Restore button on error
            if (clickedButton) {
                clickedButton.classList.remove('loading');
                clickedButton.style.pointerEvents = 'auto';
                clickedButton.style.background = 'linear-gradient(135deg, #ff79c6, #bd93f9)';
                clickedButton.innerHTML = `
                    <div class="hdmx-btn-content">
                        <svg class="hdmx-btn-icon" width="14" height="14" viewBox="0 0 24 24" fill="none">
                            <path d="M21 15V19A2 2 0 0 1 19 21H5A2 2 0 0 1 3 19V15" stroke="currentColor" stroke-width="2"/>
                            <polyline points="7,10 12,15 17,10" stroke="currentColor" stroke-width="2"/>
                            <line x1="12" y1="15" x2="12" y2="3" stroke="currentColor" stroke-width="2"/>
                        </svg>
                        <span class="hdmx-btn-text">HDM-X</span>
                    </div>
                `;
            }
        }
    }

    highlightDownloadLinks() {
        this.downloadLinks.forEach(linkData => {
            if (linkData.element) {
                linkData.element.style.outline = '2px solid #ff79c6';
                linkData.element.style.outlineOffset = '2px';
                linkData.element.style.backgroundColor = 'rgba(255, 121, 198, 0.1)';
            }
        });
    }

    removeHighlight() {
        this.downloadLinks.forEach(linkData => {
            if (linkData.element) {
                linkData.element.style.outline = '';
                linkData.element.style.outlineOffset = '';
                linkData.element.style.backgroundColor = '';
            }
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

    showNotification(message, type = 'info') {
        // Create a temporary notification element
        const notification = document.createElement('div');
        notification.textContent = message;

        Object.assign(notification.style, {
            position: 'fixed',
            top: '20px',
            right: '20px',
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
                if (notification.parentNode) {
                    document.body.removeChild(notification);
                }
            }, 300);
        }, 3000);
    }
}

// Initialize content script when DOM is ready
console.log('HDM-X: Content script loaded, DOM state:', document.readyState);

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        console.log('HDM-X: DOM loaded, initializing...');
        new HDMXContent();
    });
} else {
    console.log('HDM-X: DOM already ready, initializing...');
    new HDMXContent();
}