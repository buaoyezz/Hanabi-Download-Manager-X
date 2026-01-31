# 部署指南 - online.zzbuaoye.top

## 部署方案选择

### 方案 1: Nginx 静态托管（推荐）

最简单、性能最好的方案。

#### 步骤 1: 上传文件

将 `web_stats` 目录下的所有文件上传到服务器:

```bash
scp -r web_stats/* user@online.zzbuaoye.top:/var/www/online
```

#### 步骤 2: 配置 Nginx

创建 Nginx 配置文件 `/etc/nginx/sites-available/online.zzbuaoye.top`:

```nginx
server {
    listen 80;
    server_name online.zzbuaoye.top;
    
    root /var/www/online;
    index index.html;
    
    # Gzip 压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # 缓存静态资源
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg)$ {
        expires 7d;
        add_header Cache-Control "public, immutable";
    }
    
    # HTML 不缓存
    location ~* \.html$ {
        expires -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
    }
    
    # 所有请求返回 index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

#### 步骤 3: 启用站点

```bash
sudo ln -s /etc/nginx/sites-available/online.zzbuaoye.top /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### 步骤 4: 配置 HTTPS (Let's Encrypt)

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d online.zzbuaoye.top
```

### 方案 2: Apache 静态托管

#### 步骤 1: 上传文件

```bash
scp -r web_stats/* user@online.zzbuaoye.top:/var/www/online
```

#### 步骤 2: 配置 Apache

创建配置文件 `/etc/apache2/sites-available/online.zzbuaoye.top.conf`:

```apache
<VirtualHost *:80>
    ServerName online.zzbuaoye.top
    DocumentRoot /var/www/online
    
    <Directory /var/www/online>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # 启用压缩
    <IfModule mod_deflate.c>
        AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript application/javascript application/json
    </IfModule>
    
    # 缓存控制
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType text/css "access plus 7 days"
        ExpiresByType application/javascript "access plus 7 days"
        ExpiresByType text/html "access plus 0 seconds"
    </IfModule>
    
    ErrorLog ${APACHE_LOG_DIR}/online_error.log
    CustomLog ${APACHE_LOG_DIR}/online_access.log combined
</VirtualHost>
```

#### 步骤 3: 启用站点

```bash
sudo a2ensite online.zzbuaoye.top
sudo a2enmod rewrite expires deflate
sudo systemctl reload apache2
```

### 方案 3: Vercel 部署（免费）

#### 步骤 1: 安装 Vercel CLI

```bash
npm install -g vercel
```

#### 步骤 2: 部署

```bash
cd web_stats
vercel --prod
```

#### 步骤 3: 配置自定义域名

在 Vercel 控制台添加 `online.zzbuaoye.top` 域名。

### 方案 4: Netlify 部署（免费）

#### 步骤 1: 安装 Netlify CLI

```bash
npm install -g netlify-cli
```

#### 步骤 2: 部署

```bash
cd web_stats
netlify deploy --prod
```

#### 步骤 3: 配置自定义域名

在 Netlify 控制台添加 `online.zzbuaoye.top` 域名。

### 方案 5: GitHub Pages

#### 步骤 1: 创建仓库

创建一个新的 GitHub 仓库，例如 `hanabi-stats`

#### 步骤 2: 推送代码

```bash
cd web_stats
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/yourusername/hanabi-stats.git
git push -u origin main
```

#### 步骤 3: 启用 GitHub Pages

在仓库设置中启用 GitHub Pages，选择 `main` 分支。

#### 步骤 4: 配置自定义域名

在仓库根目录创建 `CNAME` 文件:
```
online.zzbuaoye.top
```

## 配置 API 服务器地址

### 方法 1: 使用 URL 参数（推荐）

用户访问时带上服务器参数:
```
https://online.zzbuaoye.top?server=http://your-api-server:9710
```

### 方法 2: 修改默认配置

编辑 `app.js`，修改默认服务器地址:

```javascript
const CONFIG = {
    defaultServerUrl: 'http://your-api-server:9710',
    // ...
};
```

### 方法 3: 使用环境变量（构建时）

如果使用构建工具，可以在构建时注入环境变量。

## DNS 配置

### A 记录（指向 IP）

```
Type: A
Name: online
Value: 你的服务器IP
TTL: 3600
```

### CNAME 记录（指向域名）

```
Type: CNAME
Name: online
Value: your-server.example.com
TTL: 3600
```

## 防火墙配置

确保服务器防火墙允许 HTTP/HTTPS 流量:

```bash
# UFW
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

## API 服务器 CORS 配置

确保 API 服务器允许来自 `online.zzbuaoye.top` 的请求。

在 `lib/services/kernel/next/server/http_server.dart` 中:

```dart
// 已经配置为允许所有来源
request.response.headers.add('Access-Control-Allow-Origin', '*');
```

如果需要限制特定域名:

```dart
request.response.headers.add('Access-Control-Allow-Origin', 'https://online.zzbuaoye.top');
```

## 性能优化

### 1. 启用 Gzip 压缩

Nginx 配置已包含，确保启用。

### 2. 配置 CDN

使用 Cloudflare 或其他 CDN 服务加速访问:

1. 在 Cloudflare 添加域名
2. 更新 DNS 记录指向 Cloudflare
3. 启用缓存和优化功能

### 3. 压缩资源文件

```bash
# 压缩 CSS
npx cssnano styles.css styles.min.css

# 压缩 JS
npx terser app.js -o app.min.js

# 更新 index.html 中的引用
```

### 4. 使用 HTTP/2

Nginx 配置:
```nginx
listen 443 ssl http2;
```

## 监控和日志

### Nginx 访问日志

```bash
tail -f /var/log/nginx/access.log
```

### Nginx 错误日志

```bash
tail -f /var/log/nginx/error.log
```

### 使用 Google Analytics

在 `index.html` 的 `<head>` 中添加:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_MEASUREMENT_ID');
</script>
```

## 安全建议

### 1. 使用 HTTPS

强制使用 HTTPS，Nginx 配置:

```nginx
server {
    listen 80;
    server_name online.zzbuaoye.top;
    return 301 https://$server_name$request_uri;
}
```

### 2. 设置安全头

Nginx 配置:

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval';" always;
```

### 3. 限制请求频率

Nginx 配置:

```nginx
limit_req_zone $binary_remote_addr zone=stats:10m rate=10r/s;

location / {
    limit_req zone=stats burst=20 nodelay;
    # ...
}
```

## 备份

定期备份网站文件:

```bash
#!/bin/bash
# backup.sh
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf /backup/online_${DATE}.tar.gz /var/www/online
find /backup -name "online_*.tar.gz" -mtime +30 -delete
```

设置 cron 任务:
```bash
0 2 * * * /path/to/backup.sh
```

## 故障排除

### 问题: 502 Bad Gateway

**原因**: Nginx 无法连接到后端服务

**解决**: 检查 Nginx 配置和服务状态

### 问题: 403 Forbidden

**原因**: 文件权限问题

**解决**:
```bash
sudo chown -R www-data:www-data /var/www/online
sudo chmod -R 755 /var/www/online
```

### 问题: 页面无法访问

**原因**: DNS 未生效或防火墙阻止

**解决**:
1. 检查 DNS 解析: `nslookup online.zzbuaoye.top`
2. 检查防火墙规则
3. 检查 Nginx 状态: `sudo systemctl status nginx`

## 更新部署

### 方法 1: 直接替换文件

```bash
scp -r web_stats/* user@online.zzbuaoye.top:/var/www/online
```

### 方法 2: Git 部署

在服务器上:
```bash
cd /var/www/online
git pull origin main
```

### 方法 3: 自动化部署

使用 GitHub Actions 或其他 CI/CD 工具自动部署。

## 联系支持

如有问题，请联系:
- GitHub: https://github.com/yourusername/hanabi-download-manager
- Email: your-email@example.com

## 检查清单

部署前检查:
- [ ] 文件已上传到服务器
- [ ] Nginx/Apache 配置正确
- [ ] DNS 记录已配置
- [ ] HTTPS 证书已安装
- [ ] CORS 配置正确
- [ ] API 服务器地址已配置
- [ ] 防火墙规则已设置
- [ ] 测试访问正常
- [ ] 监控和日志已配置
- [ ] 备份策略已实施
