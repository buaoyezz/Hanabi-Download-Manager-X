/**
 * Hanabi Download Manager - Online Statistics Server
 * 
 * This server receives heartbeats from Flutter clients and provides
 * statistics API for the web dashboard.
 * 
 * Deploy to: online.zzbuaoye.top
 */

const http = require('http');
const url = require('url');

// Configuration
const PORT = process.env.PORT || 3000;
const HEARTBEAT_TIMEOUT = 5 * 60 * 1000; // 5 minutes
const CLEANUP_INTERVAL = 60 * 1000; // 1 minute
const HISTORY_INTERVAL = 10 * 1000; // 10 seconds
const MAX_HISTORY_POINTS = 60;

// Access control - 只有管理员可以查看统计页面
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'hanabi_admin_2024'; // 可以通过环境变量设置

// In-memory storage
const devices = new Map(); // device_id -> device info
const history = []; // Array of {timestamp, count}

// Start cleanup timer
setInterval(cleanupInactiveDevices, CLEANUP_INTERVAL);

// Start history recording
setInterval(recordHistory, HISTORY_INTERVAL);

// Create HTTP server
const server = http.createServer((req, res) => {
    // Enable CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    // Handle preflight
    if (req.method === 'OPTIONS') {
        res.writeHead(200);
        res.end();
        return;
    }
    
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    
    // Route handling
    if (pathname === '/api/heartbeat' && req.method === 'POST') {
        handleHeartbeat(req, res);
    } else if (pathname === '/api/stats' && req.method === 'GET') {
        handleStats(req, res);
    } else if (pathname === '/health' && req.method === 'GET') {
        handleHealth(req, res);
    } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'Not found' }));
    }
});

// Handle heartbeat from Flutter client
function handleHeartbeat(req, res) {
    let body = '';
    
    req.on('data', chunk => {
        body += chunk.toString();
    });
    
    req.on('end', () => {
        try {
            const data = JSON.parse(body);
            const { device_id, platform, version, launch_count, created_at, last_launch } = data;
            
            // 添加调试日志
            console.log(`[${new Date().toISOString()}] Received heartbeat:`, JSON.stringify(data, null, 2));
            
            if (!device_id) {
                res.writeHead(400, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: false, error: 'Missing device_id' }));
                return;
            }
            
            // Update or create device record
            const now = Date.now();
            const existingDevice = devices.get(device_id);
            
            devices.set(device_id, {
                device_id,
                platform: platform || 'unknown',
                version: version || '1.0.0',
                launch_count: launch_count || 1,
                created_at: created_at || new Date().toISOString(),
                last_launch: last_launch || new Date().toISOString(),
                last_heartbeat: now,
                first_seen: existingDevice ? existingDevice.first_seen : now,
            });
            
            console.log(`[${new Date().toISOString()}] Heartbeat from ${device_id} (${platform})`);
            
            // Send response
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({
                success: true,
                data: {
                    online_users: getOnlineCount(),
                    unique_devices: devices.size,
                    device_id,
                }
            }));
        } catch (error) {
            console.error('Error handling heartbeat:', error);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ success: false, error: 'Internal server error' }));
        }
    });
}

// Handle stats request from web dashboard
function handleStats(req, res) {
    try {
        // 验证访问令牌
        const parsedUrl = url.parse(req.url, true);
        const token = parsedUrl.query.token;
        
        if (token !== ADMIN_TOKEN) {
            res.writeHead(403, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ 
                success: false, 
                error: 'Forbidden: Invalid or missing admin token' 
            }));
            console.log(`[${new Date().toISOString()}] Unauthorized stats access attempt`);
            return;
        }
        
        const onlineCount = getOnlineCount();
        const devicesList = Array.from(devices.values())
            .filter(device => isDeviceOnline(device))
            .map(device => ({
                device_id: device.device_id,
                platform: device.platform,
                version: device.version,
                launch_count: device.launch_count,
                created_at: device.created_at,
                last_launch: device.last_launch,
                first_seen: new Date(device.first_seen).toISOString(),
                last_seen: new Date(device.last_heartbeat).toISOString(),
            }));
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            success: true,
            data: {
                current_online: onlineCount,
                unique_devices: devices.size,
                total_devices_ever: devices.size,
                history: history.slice(-MAX_HISTORY_POINTS),
                devices: devicesList,
            }
        }));
    } catch (error) {
        console.error('Error handling stats:', error);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: false, error: 'Internal server error' }));
    }
}

// Health check endpoint
function handleHealth(req, res) {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
        success: true,
        status: 'healthy',
        uptime: process.uptime(),
        devices: devices.size,
        online: getOnlineCount(),
    }));
}

// Get online device count
function getOnlineCount() {
    let count = 0;
    for (const device of devices.values()) {
        if (isDeviceOnline(device)) {
            count++;
        }
    }
    return count;
}

// Check if device is online
function isDeviceOnline(device) {
    const now = Date.now();
    return (now - device.last_heartbeat) < HEARTBEAT_TIMEOUT;
}

// Cleanup inactive devices
function cleanupInactiveDevices() {
    const now = Date.now();
    const inactiveThreshold = 24 * 60 * 60 * 1000; // 24 hours
    
    for (const [deviceId, device] of devices.entries()) {
        // Remove devices that haven't sent heartbeat in 24 hours
        if ((now - device.last_heartbeat) > inactiveThreshold) {
            devices.delete(deviceId);
            console.log(`[${new Date().toISOString()}] Removed inactive device: ${deviceId}`);
        }
    }
}

// Record history point
function recordHistory() {
    const count = getOnlineCount();
    history.push({
        timestamp: new Date().toISOString(),
        count,
    });
    
    // Keep only last MAX_HISTORY_POINTS
    if (history.length > MAX_HISTORY_POINTS) {
        history.shift();
    }
}

// Start server
server.listen(PORT, () => {
    console.log(`Hanabi Online Statistics Server running on port ${PORT}`);
    console.log(`Heartbeat timeout: ${HEARTBEAT_TIMEOUT / 1000}s`);
    console.log(`Cleanup interval: ${CLEANUP_INTERVAL / 1000}s`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down gracefully...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
