// HDM X 浏览器扩展弹窗脚本

document.addEventListener('DOMContentLoaded', function() {
    const statusElement = document.getElementById('status');
    const downloadBtn = document.getElementById('downloadBtn');
    const downloadUrlInput = document.getElementById('downloadUrl');
    const filenameInput = document.getElementById('filename');
    const downloadCurrentPageBtn = document.getElementById('downloadCurrentPage');
    const testConnectionBtn = document.getElementById('testConnection');
    const messageElement = document.getElementById('message');
    
    // 检查连接状态
    function updateConnectionStatus() {
        chrome.storage.local.get(['hdm_connected'], function(result) {
            const isConnected = result.hdm_connected || false;
            
            if (isConnected) {
                statusElement.textContent = '✅ HDM X 已连接';
                statusElement.className = 'status connected';
                downloadBtn.disabled = false;
                downloadCurrentPageBtn.disabled = false;
            } else {
                statusElement.textContent = '❌ HDM X 未连接';
                statusElement.className = 'status disconnected';
                downloadBtn.disabled = true;
                downloadCurrentPageBtn.disabled = true;
            }
        });
    }
    
    // 显示消息
    function showMessage(text, type = 'success') {
        messageElement.textContent = text;
        messageElement.className = `message ${type}`;
        messageElement.style.display = 'block';
        
        setTimeout(() => {
            messageElement.style.display = 'none';
        }, 3000);
    }
    
    // 添加下载
    function addDownload(url, filename = '') {
        chrome.runtime.sendMessage({
            action: 'download',
            url: url,
            filename: filename,
            referer: window.location.href
        }, function(response) {
            if (response && response.success) {
                showMessage('下载添加成功！', 'success');
                downloadUrlInput.value = '';
                filenameInput.value = '';
            } else {
                showMessage(response?.error || '下载添加失败', 'error');
            }
        });
    }
    
    // 测试连接
    function testConnection() {
        testConnectionBtn.disabled = true;
        testConnectionBtn.textContent = '测试中...';
        
        chrome.runtime.sendMessage({
            action: 'ping'
        }, function(response) {
            testConnectionBtn.disabled = false;
            testConnectionBtn.textContent = '测试连接';
            
            if (response && response.success) {
                showMessage('连接测试成功！', 'success');
                updateConnectionStatus();
            } else {
                showMessage('连接测试失败，请确保HDM X正在运行', 'error');
            }
        });
    }
    
    // 事件监听器
    downloadBtn.addEventListener('click', function() {
        const url = downloadUrlInput.value.trim();
        const filename = filenameInput.value.trim();
        
        if (!url) {
            showMessage('请输入下载链接', 'error');
            return;
        }
        
        if (!isValidUrl(url)) {
            showMessage('请输入有效的URL', 'error');
            return;
        }
        
        addDownload(url, filename);
    });
    
    downloadCurrentPageBtn.addEventListener('click', function() {
        chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
            if (tabs[0]) {
                const url = tabs[0].url;
                const title = tabs[0].title;
                addDownload(url, title);
            }
        });
    });
    
    testConnectionBtn.addEventListener('click', testConnection);
    
    // URL输入框回车事件
    downloadUrlInput.addEventListener('keypress', function(e) {
        if (e.key === 'Enter') {
            downloadBtn.click();
        }
    });
    
    // URL验证
    function isValidUrl(string) {
        try {
            new URL(string);
            return true;
        } catch (_) {
            return false;
        }
    }
    
    // 检测页面下载内容
    function detectPageDownloads() {
        chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
            if (tabs[0]) {
                chrome.tabs.sendMessage(tabs[0].id, {action: 'detect_downloads'}, function(response) {
                    if (response && response.success && response.data.total > 0) {
                        const data = response.data;
                        downloadCurrentPageBtn.textContent = `检测到 ${data.total} 个下载项`;
                        downloadCurrentPageBtn.style.backgroundColor = '#4CAF50';
                    }
                });
            }
        });
    }
    
    // 自动填充当前页面URL
    chrome.tabs.query({active: true, currentWindow: true}, function(tabs) {
        if (tabs[0] && tabs[0].url && !tabs[0].url.startsWith('chrome://')) {
            downloadUrlInput.placeholder = '或点击"下载当前页面"';
            // 检测页面下载内容
            setTimeout(detectPageDownloads, 500);
        }
    });
    
    // 初始化
    updateConnectionStatus();
    
    // 定期更新连接状态
    setInterval(updateConnectionStatus, 2000);
});