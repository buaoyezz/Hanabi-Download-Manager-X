// HDM X 内容脚本 - 页面下载检测

(function() {
    'use strict';
    
    // 检测页面中的下载链接
    function detectDownloadLinks() {
        const downloadLinks = [];
        const links = document.querySelectorAll('a[href]');
        
        links.forEach(link => {
            const href = link.href;
            const text = link.textContent.trim();
            
            // 检测常见的下载文件扩展名
            const downloadExtensions = [
                '.zip', '.rar', '.7z', '.tar', '.gz',
                '.exe', '.msi', '.dmg', '.pkg',
                '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
                '.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv',
                '.mp3', '.wav', '.flac', '.aac',
                '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg',
                '.iso', '.img', '.bin'
            ];
            
            const hasDownloadExtension = downloadExtensions.some(ext => 
                href.toLowerCase().includes(ext.toLowerCase())
            );
            
            const hasDownloadAttribute = link.hasAttribute('download');
            const hasDownloadText = /download|下载|获取|get/i.test(text);
            
            if (hasDownloadExtension || hasDownloadAttribute || hasDownloadText) {
                downloadLinks.push({
                    url: href,
                    text: text,
                    filename: link.getAttribute('download') || extractFilenameFromUrl(href)
                });
            }
        });
        
        return downloadLinks;
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
    
    // 检测视频链接
    function detectVideoLinks() {
        const videoLinks = [];
        const videos = document.querySelectorAll('video[src], video source[src]');
        
        videos.forEach(video => {
            const src = video.src || video.getAttribute('src');
            if (src && !src.startsWith('blob:')) {
                videoLinks.push({
                    url: src,
                    type: 'video',
                    filename: extractFilenameFromUrl(src) || 'video'
                });
            }
        });
        
        return videoLinks;
    }
    
    // 检测图片链接
    function detectImageLinks() {
        const imageLinks = [];
        const images = document.querySelectorAll('img[src]');
        
        images.forEach(img => {
            const src = img.src;
            if (src && !src.startsWith('data:') && !src.startsWith('blob:')) {
                // 只包含较大的图片
                if (img.naturalWidth > 200 && img.naturalHeight > 200) {
                    imageLinks.push({
                        url: src,
                        type: 'image',
                        filename: extractFilenameFromUrl(src) || 'image',
                        alt: img.alt || ''
                    });
                }
            }
        });
        
        return imageLinks;
    }
    
    // 监听来自popup的消息
    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
        if (message.action === 'detect_downloads') {
            const downloadLinks = detectDownloadLinks();
            const videoLinks = detectVideoLinks();
            const imageLinks = detectImageLinks();
            
            sendResponse({
                success: true,
                data: {
                    downloads: downloadLinks,
                    videos: videoLinks,
                    images: imageLinks,
                    total: downloadLinks.length + videoLinks.length + imageLinks.length
                }
            });
        }
        
        if (message.action === 'batch_download') {
            const urls = message.urls || [];
            chrome.runtime.sendMessage({
                action: 'batch_download',
                urls: urls,
                referer: window.location.href
            }, response => {
                sendResponse(response);
            });
            return true; // 保持消息通道开放
        }
    });
    
    // 页面加载完成后，检查是否有可下载内容
    if (document.readyState === 'complete') {
        setTimeout(checkForDownloadableContent, 1000);
    } else {
        window.addEventListener('load', () => {
            setTimeout(checkForDownloadableContent, 1000);
        });
    }
    
    function checkForDownloadableContent() {
        const downloadLinks = detectDownloadLinks();
        const videoLinks = detectVideoLinks();
        const imageLinks = detectImageLinks();
        
        const totalDownloadable = downloadLinks.length + videoLinks.length + imageLinks.length;
        
        if (totalDownloadable > 0) {
            // 存储检测到的下载内容
            chrome.storage.local.set({
                [`downloadable_${window.location.hostname}`]: {
                    url: window.location.href,
                    title: document.title,
                    downloads: downloadLinks,
                    videos: videoLinks,
                    images: imageLinks,
                    total: totalDownloadable,
                    timestamp: Date.now()
                }
            });
        }
    }
    
    // 监听页面变化（SPA应用）
    let lastUrl = location.href;
    new MutationObserver(() => {
        const url = location.href;
        if (url !== lastUrl) {
            lastUrl = url;
            setTimeout(checkForDownloadableContent, 2000);
        }
    }).observe(document, { subtree: true, childList: true });
    
})();