// Configuration
const CONFIG = {
    // 统计服务器地址 - 使用相对路径，自动使用当前协议
    defaultServerUrl: window.location.origin,
    updateInterval: 10000, // 10 seconds
    maxDataPoints: 60, // 显示最近60个数据点
    adminToken: '', // 管理员令牌，从 localStorage 读取
};

// Get server URL from query parameter or use default
const urlParams = new URLSearchParams(window.location.search);
const SERVER_URL = urlParams.get('server') || CONFIG.defaultServerUrl;

// Load admin token from localStorage
CONFIG.adminToken = localStorage.getItem('admin_token') || '';

// State
let chart = null;
let updateTimer = null;
let isOnline = false;
let historyData = [];

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
    // 检查是否有令牌
    if (!CONFIG.adminToken) {
        showTokenPrompt();
        return;
    }
    
    initChart();
    updateServerInfo();
    await fetchStats();
    startAutoUpdate();
});

// Show token prompt
function showTokenPrompt() {
    const token = prompt('请输入管理员令牌以访问统计页面：');
    if (token) {
        CONFIG.adminToken = token;
        localStorage.setItem('admin_token', token);
        location.reload();
    } else {
        document.body.innerHTML = '<div style="display: flex; align-items: center; justify-content: center; height: 100vh; font-family: system-ui; color: #666;">访问被拒绝：需要管理员令牌</div>';
    }
}

// Initialize Chart
function initChart() {
    const ctx = document.getElementById('onlineChart').getContext('2d');
    
    chart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [{
                label: '在线用户数',
                data: [],
                borderColor: 'rgb(0, 120, 212)',
                backgroundColor: 'rgba(0, 120, 212, 0.1)',
                borderWidth: 3,
                fill: true,
                tension: 0.4,
                pointRadius: 4,
                pointHoverRadius: 6,
                pointBackgroundColor: 'rgb(96, 205, 255)',
                pointBorderColor: 'rgb(0, 120, 212)',
                pointBorderWidth: 2,
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                intersect: false,
                mode: 'index',
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: 'rgba(43, 43, 43, 0.95)',
                    titleColor: '#FFFFFF',
                    bodyColor: '#AAAAAA',
                    borderColor: '#3A3A3A',
                    borderWidth: 1,
                    padding: 12,
                    displayColors: false,
                    callbacks: {
                        title: function(context) {
                            return context[0].label;
                        },
                        label: function(context) {
                            return `${context.parsed.y} 人在线`;
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: {
                        color: 'rgba(58, 58, 58, 0.3)',
                        drawBorder: false,
                    },
                    ticks: {
                        color: '#808080',
                        maxRotation: 0,
                        autoSkipPadding: 20,
                    }
                },
                y: {
                    beginAtZero: true,
                    grid: {
                        color: 'rgba(58, 58, 58, 0.3)',
                        drawBorder: false,
                    },
                    ticks: {
                        color: '#808080',
                        precision: 0,
                    }
                }
            }
        }
    });
}

// Fetch Statistics
async function fetchStats() {
    try {
        // 只读取统计数据，不发送心跳
        const url = `${SERVER_URL}/api/stats?token=${encodeURIComponent(CONFIG.adminToken)}`;
        const response = await fetch(url);
        
        if (response.status === 403) {
            // 令牌无效，清除并重新提示
            localStorage.removeItem('admin_token');
            alert('令牌无效或已过期，请重新输入');
            location.reload();
            return;
        }
        
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
        console.error('Failed to fetch stats:', error);
        setOnlineStatus(false);
    }
}

// Update UI
function updateUI(data) {
    // Update current online count
    const currentOnline = data.current_online || 0;
    updateElement('onlineCount', currentOnline);
    
    // Update unique devices count
    const uniqueDevices = data.unique_devices || 0;
    updateElement('uniqueDevices', uniqueDevices);
    
    // Update history data
    if (data.history && Array.isArray(data.history)) {
        historyData = data.history.slice(-CONFIG.maxDataPoints);
        updateChart();
        updateStatistics();
    }
    
    // Update data points count
    updateElement('dataPointsCount', historyData.length);
    
    // Update last update time
    updateElement('lastUpdate', formatTime(new Date()));
}

// Update Chart
function updateChart() {
    if (!chart || historyData.length === 0) return;
    
    const labels = historyData.map(item => formatTime(new Date(item.timestamp)));
    const data = historyData.map(item => item.count);
    
    chart.data.labels = labels;
    chart.data.datasets[0].data = data;
    chart.update('none'); // Update without animation for smoother experience
}

// Update Statistics
function updateStatistics() {
    if (historyData.length === 0) {
        updateElement('maxOnline', 0);
        updateElement('minOnline', 0);
        updateElement('avgOnline', '0.0');
        return;
    }
    
    const counts = historyData.map(item => item.count);
    const max = Math.max(...counts);
    const min = Math.min(...counts);
    const avg = counts.reduce((a, b) => a + b, 0) / counts.length;
    
    updateElement('maxOnline', max);
    updateElement('minOnline', min);
    updateElement('avgOnline', avg.toFixed(1));
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

// Update Server Info
function updateServerInfo() {
    updateElement('serverUrl', SERVER_URL);
}

// Start Auto Update
function startAutoUpdate() {
    if (updateTimer) {
        clearInterval(updateTimer);
    }
    
    updateTimer = setInterval(() => {
        fetchStats();
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
            // Animate number changes
            animateNumber(element, value);
        } else {
            element.textContent = value;
        }
    }
}

function animateNumber(element, targetValue) {
    const currentValue = parseInt(element.textContent) || 0;
    
    if (currentValue === targetValue) return;
    
    const duration = 500; // ms
    const steps = 20;
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

// Handle visibility change (pause updates when tab is hidden)
document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
        stopAutoUpdate();
    } else {
        fetchStats();
        startAutoUpdate();
    }
});

// Handle page unload
window.addEventListener('beforeunload', () => {
    stopAutoUpdate();
});

// Export for debugging
window.statsApp = {
    fetchStats,
    updateUI,
    setOnlineStatus,
    historyData,
    CONFIG,
    SERVER_URL,
};
