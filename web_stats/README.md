# Hanabi Download Manager - Online Statistics

Real-time online user statistics system for Hanabi Download Manager.

## Architecture

This system tracks **Flutter desktop application users**, not web visitors:

```
Flutter Client → Statistics Server → Web Dashboard
(Sends heartbeat)   (Stores data)     (Displays stats)
```

### Components

1. **Flutter Client** (`lib/services/user_profile_service.dart`)
   - Generates unique device ID on first launch
   - Saves to `.hdmx/data/User_Profile.json`
   - Sends heartbeat every 5 minutes to server
   - Includes: device_id, platform, version, launch_count

2. **Statistics Server** (`server.js`)
   - Node.js HTTP server
   - Receives heartbeats from Flutter clients
   - Tracks online devices (5-minute timeout)
   - Provides REST API for statistics
   - In-memory storage (no database required)

3. **Web Dashboard** (`index.html`, `devices.html`)
   - Real-time statistics display
   - Online user count chart
   - Device list with details
   - Auto-refresh every 10 seconds

## Quick Start

### 1. Local Testing

```bash
# Start local server
cd web_stats
node server.js

# Or use the batch file (Windows)
test_server.bat
```

Server will run on `http://localhost:3000`

### 2. Test with Flutter Client

Update `lib/services/user_profile_service.dart` for local testing:

```dart
static const String statsServerUrl = 'http://localhost:3000';
```

Run the Flutter app - it will send heartbeats to your local server.

### 3. View Dashboard

Open in browser:
- Main dashboard: `http://localhost:3000` (serve index.html)
- Or open `index.html?server=http://localhost:3000` directly

### 4. Test API Manually

```bash
# Health check
curl http://localhost:3000/health

# Send test heartbeat
curl -X POST http://localhost:3000/api/heartbeat \
  -H "Content-Type: application/json" \
  -d '{"device_id":"test-123","platform":"Windows","version":"1.0.0"}'

# Get statistics
curl http://localhost:3000/api/stats
```

## Production Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

### Quick Deploy to Cloud Server

1. **Upload server to `online.zzbuaoye.top`**:
   ```bash
   scp server.js user@online.zzbuaoye.top:/opt/hanabi-stats/
   ```

2. **Run with PM2**:
   ```bash
   npm install -g pm2
   pm2 start server.js --name hanabi-stats
   pm2 save
   ```

3. **Configure Nginx** (see DEPLOYMENT.md)

4. **Upload web files**:
   ```bash
   scp index.html styles.css app.js devices.html devices.js \
       user@online.zzbuaoye.top:/var/www/hanabi-stats/
   ```

5. **Update Flutter client** to use production URL:
   ```dart
   static const String statsServerUrl = 'https://online.zzbuaoye.top';
   ```

## API Reference

### POST /api/heartbeat

Receive heartbeat from Flutter client.

**Request:**
```json
{
  "device_id": "uuid-v4-string",
  "platform": "Windows|macOS|Linux",
  "version": "1.0.0",
  "launch_count": 1,
  "created_at": "2026-01-17T00:00:00Z",
  "last_launch": "2026-01-17T00:00:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "online_users": 5,
    "unique_devices": 10,
    "device_id": "uuid-v4-string"
  }
}
```

### GET /api/stats

Get current statistics (for web dashboard).

**Response:**
```json
{
  "success": true,
  "data": {
    "current_online": 5,
    "unique_devices": 10,
    "total_devices_ever": 10,
    "history": [
      {"timestamp": "2026-01-17T00:00:00Z", "count": 5}
    ],
    "devices": [
      {
        "device_id": "uuid",
        "platform": "Windows",
        "version": "1.0.0",
        "launch_count": 5,
        "created_at": "2026-01-17T00:00:00Z",
        "last_launch": "2026-01-17T00:00:00Z",
        "first_seen": "2026-01-17T00:00:00Z",
        "last_seen": "2026-01-17T00:05:00Z"
      }
    ]
  }
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "success": true,
  "status": "healthy",
  "uptime": 123.45,
  "devices": 10,
  "online": 5
}
```

## Configuration

### Server Configuration

Edit `server.js`:

```javascript
const PORT = process.env.PORT || 3000;
const HEARTBEAT_TIMEOUT = 5 * 60 * 1000; // 5 minutes
const CLEANUP_INTERVAL = 60 * 1000; // 1 minute
const HISTORY_INTERVAL = 10 * 1000; // 10 seconds
const MAX_HISTORY_POINTS = 60;
```

### Web Dashboard Configuration

Edit `app.js` and `devices.js`:

```javascript
const CONFIG = {
    defaultServerUrl: 'https://online.zzbuaoye.top',
    updateInterval: 10000, // 10 seconds
    maxDataPoints: 60,
};
```

### Flutter Client Configuration

Edit `lib/services/user_profile_service.dart`:

```dart
static const String statsServerUrl = 'https://online.zzbuaoye.top';
static const Duration heartbeatInterval = Duration(minutes: 5);
```

## Files

- `server.js` - Node.js statistics server
- `index.html` - Main dashboard page
- `devices.html` - Device list page
- `styles.css` - Shared styles
- `app.js` - Main dashboard JavaScript
- `devices.js` - Device list JavaScript
- `DEPLOYMENT.md` - Deployment guide
- `README.md` - This file
- `test_server.bat` - Windows test script

## Troubleshooting

### Server not receiving heartbeats

1. Check Flutter client logs
2. Verify server URL is correct
3. Check firewall/network settings
4. Test with curl manually

### Dashboard shows 0 online

1. Check browser console for errors
2. Verify server is running (`/health` endpoint)
3. Check CORS configuration
4. Ensure at least one Flutter client is running

### Devices not appearing in list

1. Verify heartbeat timeout (default 5 minutes)
2. Check server logs for errors
3. Ensure Flutter client is sending heartbeats
4. Test API directly: `curl http://localhost:3000/api/stats`

## Development

### Adding Features

1. **Persistence**: Add Redis or PostgreSQL for data persistence
2. **Authentication**: Add API keys for security
3. **Rate Limiting**: Prevent abuse
4. **Analytics**: Add more detailed analytics
5. **Notifications**: Alert on threshold events

### Testing

```bash
# Run server
node server.js

# In another terminal, send test heartbeats
curl -X POST http://localhost:3000/api/heartbeat \
  -H "Content-Type: application/json" \
  -d '{"device_id":"test-1","platform":"Windows","version":"1.0.0"}'

# Check stats
curl http://localhost:3000/api/stats
```

## License

Part of Hanabi Download Manager project.

## Support

For issues or questions, contact: ZZBuAoYe
