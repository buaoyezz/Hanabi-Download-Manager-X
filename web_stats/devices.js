// Configuration
const CONFIG = {
    defaultServerUrl: window.location.origin,
    updateInterval: 5000, // 5 seconds for devices page
};

// Get server URL from query parameter or use default
const urlParams = new URLSearchParams(window.location.search);
const SERVER_URL = urlParams.get('server') || CONFIG.defaultServerUrl;

// State
let updateTimer = null;
let isOnline = false;

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    fetchDevices();
    startAutoUpdate();
    setupRefreshButton();
});

// Fetch Devices
async function fetchDevices() {
    try {
        // 只读取统计数据，不发送心跳
        const response = await fetch(`${SERVER_URL}/api/stats`);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const result = await response.json();
        
        if (result.success) {
            updateUI(result.data);
            setOnlineStatus(true);
        } else {
            throw new Error('API returned success: false');
        }
    } catch (error) {
        console.error('Failed to fetch devices:', error);
        setOnlineStatus(false);
        showError();
    }
}

// Update UI
function updateUI(data) {
    // Update statistics
    updateElement('activeDevices', data.unique_devices || 0);
    updateElement('totalDevices', data.total_devices_ever || 0);
    updateElement('activeSessions', data.current_online || 0);
    
    // Update devices list
    if (data.devices && Array.isArray(data.devices)) {
        renderDevicesList(data.devices);
    } else {
        showEmptyState();
    }
    
    // Update last update time
    updateElement('lastUpdate', formatTime(new Date()));
}

// Render Devices List
function renderDevicesList(devices) {
    const devicesList = document.getElementById('devicesList');
    
    if (devices.length === 0) {
        showEmptyState();
        return;
    }
    
    devicesList.innerHTML = devices.map(device => {
        const lastSeen = new Date(device.last_seen);
        const firstSeen = new Date(device.first_seen);
        const deviceIdShort = device.device_id ? device.device_id.substring(0, 8) : 'Unknown';
        
        // 计算在线时长
        const onlineDuration = Math.floor((Date.now() - firstSeen.getTime()) / 1000 / 60); // 分钟
        
        return `
            <div class="device-card">
                <div class="device-card-header">
                    <div class="device-info">
                        <div class="device-fingerprint">${deviceIdShort}</div>
                        <div class="device-summary">${device.platform || 'Unknown'} Device</div>
                    </div>
                    <div class="device-status">
                        <span class="device-status-dot"></span>
                        在线
                    </div>
                </div>
                <div class="device-details">
                    <div class="device-detail-item">
                        <div class="device-detail-label">平台</div>
                        <div class="device-detail-value">${device.platform || 'Unknown'}</div>
                    </div>
                    <div class="device-detail-item">
                        <div class="device-detail-label">版本</div>
                        <div class="device-detail-value">${device.version || 'Unknown'}</div>
                    </div>
                    <div class="device-detail-item">
                        <div class="device-detail-label">启动次数</div>
                        <div class="device-detail-value">${device.launch_count || 1}</div>
                    </div>
                    <div class="device-detail-item">
                        <div class="device-detail-label">首次访问</div>
                        <div class="device-detail-value">${formatDateTime(firstSeen)}</div>
                    </div>
                    <div class="device-detail-item">
                        <div class="device-detail-label">最后活跃</div>
                        <div class="device-detail-value">${formatRelativeTime(lastSeen)}</div>
                    </div>
                    <div class="device-detail-item">
                        <div class="device-detail-label">在线时长</div>
                        <div class="device-detail-value">${onlineDuration} 分钟</div>
                    </div>
                </div>
            </div>
        `;
    }).join('');
}

// Show Empty State
function showEmptyState() {
    const devicesList = document.getElementById('devicesList');
    devicesList.innerHTML = `
        <div class="empty-state">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M20 7H4C2.89543 7 2 7.89543 2 9V19C2 20.1046 2.89543 21 4 21H20C21.1046 21 22 20.1046 22 19V9C22 7.89543 21.1046 7 20 7Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M16 21V5C16 4.46957 15.7893 3.96086 15.4142 3.58579C15.0391 3.21071 14.5304 3 14 3H10C9.46957 3 8.96086 3.21071 8.58579 3.58579C8.21071 3.96086 8 4.46957 8 5V21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
            <p>暂无在线设备</p>
        </div>
    `;
}

// Show Error
function showError() {
    const devicesList = document.getElementById('devicesList');
    devicesList.innerHTML = `
        <div class="empty-state">
            <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/>
                <path d="M12 8V12M12 16H12.01" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
            </svg>
            <p>无法连接到服务器</p>
        </div>
    `;
}

// Set Online Status
function setOnlineStatus(online) {
    isOnline = online;
    const badge = document.getElementById('statusBadge');
    const statusText = badge.querySelector('.status-text');
    
    if (online) {
        badge.classList.add('online');
        badge.classList.remove('offline');
        statusText.textContent = '在线';
    } else {
        badge.classList.remove('online');
        badge.classList.add('offline');
        statusText.textContent = '离线';
    }
}

// Setup Refresh Button
function setupRefreshButton() {
    const refreshButton = document.getElementById('refreshButton');
    refreshButton.addEventListener('click', async () => {
        refreshButton.classList.add('refreshing');
        await fetchDevices();
        setTimeout(() => {
            refreshButton.classList.remove('refreshing');
        }, 500);
    });
}

// Start Auto Update
function startAutoUpdate() {
    if (updateTimer) {
        clearInterval(updateTimer);
    }
    
    updateTimer = setInterval(() => {
        fetchDevices();
    }, CONFIG.updateInterval);
}

// Stop Auto Update
function stopAutoUpdate() {
    if (updateTimer) {
        clearInterval(updateTimer);
        updateTimer = null;
    }
}

// Utility Functions
function updateElement(id, value) {
    const element = document.getElementById(id);
    if (element) {
        if (typeof value === 'number') {
            animateNumber(element, value);
        } else {
            element.textContent = value;
        }
    }
}

function animateNumber(element, targetValue) {
    const currentValue = parseInt(element.textContent) || 0;
    
    if (currentValue === targetValue) return;
    
    const duration = 300;
    const steps = 10;
    const stepValue = (targetValue - currentValue) / steps;
    const stepDuration = duration / steps;
    
    let currentStep = 0;
    
    const timer = setInterval(() => {
        currentStep++;
        
        if (currentStep >= steps) {
            element.textContent = targetValue;
            clearInterval(timer);
        } else {
            const newValue = Math.round(currentValue + (stepValue * currentStep));
            element.textContent = newValue;
        }
    }, stepDuration);
}

function formatTime(date) {
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    const seconds = date.getSeconds().toString().padStart(2, '0');
    return `${hours}:${minutes}:${seconds}`;
}

function formatDateTime(date) {
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
}

function formatRelativeTime(date) {
    const now = new Date();
    const diff = Math.floor((now - date) / 1000);
    
    if (diff < 60) return `${diff}秒前`;
    if (diff < 3600) return `${Math.floor(diff / 60)}分钟前`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}小时前`;
    return `${Math.floor(diff / 86400)}天前`;
}

// Handle visibility change
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        stopAutoUpdate();
    } else {
        fetchDevices();
        startAutoUpdate();
    }
});

// Handle page unload
window.addEventListener('beforeunload', () => {
    stopAutoUpdate();
});

// Export for debugging
window.devicesApp = {
    fetchDevices,
    updateUI,
    setOnlineStatus,
    CONFIG,
    SERVER_URL,
};
