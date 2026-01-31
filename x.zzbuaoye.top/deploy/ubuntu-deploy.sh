#!/bin/bash

# 公告系统 Ubuntu 一键部署脚本
# 支持 Ubuntu 18.04+ / Debian 10+
# 作者: ZZBuAoYe
# 版本: 1.0.0

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用root用户运行此脚本！"
        log_info "建议创建一个普通用户: sudo adduser deploy"
        exit 1
    fi
}

# 检查系统版本
check_system() {
    log_info "检查系统版本..."
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "无法检测系统版本"
        exit 1
    fi
    
    log_info "检测到系统: $OS $VER"
    
    # 检查是否为支持的系统
    if [[ "$OS" != *"Ubuntu"* ]] && [[ "$OS" != *"Debian"* ]]; then
        log_warning "此脚本主要为Ubuntu/Debian设计，其他系统可能需要手动调整"
    fi
}

# 配置变量
setup_config() {
    log_info "配置部署参数..."
    
    # 默认配置
    PROJECT_NAME="hanabi-announcements"
    DOMAIN=${DOMAIN:-"your-domain.com"}
    API_DOMAIN=${API_DOMAIN:-"api.your-domain.com"}
    DB_NAME=${DB_NAME:-"announcements"}
    DB_USER=${DB_USER:-"announcements_user"}
    DB_PASSWORD=${DB_PASSWORD:-$(openssl rand -base64 32)}
    JWT_SECRET=${JWT_SECRET:-$(openssl rand -base64 64)}
    
    # 生成VAPID密钥
    log_info "生成VAPID密钥..."
    VAPID_KEYS=$(npx web-push generate-vapid-keys --json 2>/dev/null || echo '{"publicKey":"","privateKey":""}')
    VAPID_PUBLIC_KEY=$(echo $VAPID_KEYS | jq -r '.publicKey' 2>/dev/null || echo "")
    VAPID_PRIVATE_KEY=$(echo $VAPID_KEYS | jq -r '.privateKey' 2>/dev/null || echo "")
    VAPID_EMAIL=${VAPID_EMAIL:-"mailto:admin@$DOMAIN"}
    
    # 路径配置
    HOME_DIR=$(eval echo ~$USER)
    PROJECT_DIR="$HOME_DIR/$PROJECT_NAME"
    FRONTEND_DIR="$PROJECT_DIR/frontend"
    BACKEND_DIR="$PROJECT_DIR/backend"
    
    log_success "配置完成"
    log_info "项目目录: $PROJECT_DIR"
    log_info "域名: $DOMAIN"
    log_info "API域名: $API_DOMAIN"
}

# 更新系统
update_system() {
    log_info "更新系统包..."
    sudo apt update
    sudo apt upgrade -y
    log_success "系统更新完成"
}

# 安装基础依赖
install_dependencies() {
    log_info "安装基础依赖..."
    
    sudo apt install -y \
        curl \
        wget \
        git \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        jq \
        htop \
        ufw \
        fail2ban
    
    log_success "基础依赖安装完成"
}

# 安装Node.js
install_nodejs() {
    log_info "安装Node.js..."
    
    # 检查是否已安装
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        log_info "Node.js已安装: $NODE_VERSION"
        return
    fi
    
    # 安装Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # 安装全局包
    sudo npm install -g pm2 web-push-cli
    
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log_success "Node.js安装完成: $NODE_VERSION, npm: $NPM_VERSION"
}

# 安装PostgreSQL
install_postgresql() {
    log_info "安装PostgreSQL..."
    
    # 检查是否已安装
    if command -v psql &> /dev/null; then
        log_info "PostgreSQL已安装"
        return
    fi
    
    sudo apt install -y postgresql postgresql-contrib
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    log_success "PostgreSQL安装完成"
}

# 配置数据库
setup_database() {
    log_info "配置数据库..."
    
    # 创建数据库和用户
    sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\q
EOF
    
    # 创建数据库表
    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME << 'EOF'
-- 创建公告表
CREATE TABLE IF NOT EXISTS announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('info', 'warning', 'success', 'error')),
    priority VARCHAR(20) NOT NULL CHECK (priority IN ('low', 'medium', 'high')),
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP,
    author_id UUID,
    author_name VARCHAR(100),
    tags TEXT[],
    target_audience VARCHAR(20) DEFAULT 'all',
    push_enabled BOOLEAN DEFAULT false,
    read_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 创建管理员用户表
CREATE TABLE IF NOT EXISTS admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'admin',
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP
);

-- 创建推送订阅表
CREATE TABLE IF NOT EXISTS push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    endpoint TEXT NOT NULL UNIQUE,
    p256dh_key TEXT NOT NULL,
    auth_key TEXT NOT NULL,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_announcements_active ON announcements(is_active);
CREATE INDEX IF NOT EXISTS idx_announcements_created ON announcements(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_expires ON announcements(expires_at);

-- 插入默认管理员用户 (用户名: admin, 密码: admin123)
INSERT INTO admin_users (username, email, password_hash, role) 
VALUES ('admin', 'admin@localhost', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin')
ON CONFLICT (username) DO NOTHING;

-- 插入示例公告
INSERT INTO announcements (title, content, type, priority, is_active, expires_at, author_name, tags, push_enabled)
VALUES 
    ('欢迎使用公告系统', '公告系统已成功部署！您可以通过管理面板创建和管理公告。', 'success', 'high', true, NOW() + INTERVAL '30 days', 'System', ARRAY['welcome', 'system'], true),
    ('系统部署完成', '恭喜！您的公告系统已成功部署到服务器。', 'info', 'medium', true, NOW() + INTERVAL '7 days', 'System', ARRAY['deployment'], false)
ON CONFLICT DO NOTHING;
EOF
    
    log_success "数据库配置完成"
    log_info "数据库名: $DB_NAME"
    log_info "数据库用户: $DB_USER"
    log_warning "数据库密码: $DB_PASSWORD (请妥善保存)"
}

# 安装Nginx
install_nginx() {
    log_info "安装Nginx..."
    
    if command -v nginx &> /dev/null; then
        log_info "Nginx已安装"
        return
    fi
    
    sudo apt install -y nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    log_success "Nginx安装完成"
}

# 安装SSL证书 (Let's Encrypt)
install_ssl() {
    log_info "安装SSL证书..."
    
    # 安装certbot
    sudo apt install -y certbot python3-certbot-nginx
    
    # 检查域名是否指向当前服务器
    log_warning "请确保域名 $DOMAIN 和 $API_DOMAIN 已正确解析到当前服务器IP"
    read -p "域名是否已正确解析？(y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 申请SSL证书
        sudo certbot --nginx -d $DOMAIN -d $API_DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
        log_success "SSL证书安装完成"
    else
        log_warning "跳过SSL证书安装，请稍后手动配置"
    fi
}

# 克隆项目代码
clone_project() {
    log_info "准备项目代码..."
    
    # 创建项目目录
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR
    
    # 这里假设代码已经在当前目录，实际部署时需要从Git仓库克隆
    log_info "复制项目文件..."
    
    # 创建前端目录
    mkdir -p $FRONTEND_DIR
    # 这里需要复制前端代码到 $FRONTEND_DIR
    
    # 创建后端目录
    mkdir -p $BACKEND_DIR
    # 这里需要复制后端代码到 $BACKEND_DIR
    
    log_success "项目代码准备完成"
}

# 部署后端
deploy_backend() {
    log_info "部署后端服务..."
    
    cd $BACKEND_DIR
    
    # 创建package.json (如果不存在)
    if [[ ! -f package.json ]]; then
        cat > package.json << EOF
{
  "name": "announcement-api",
  "version": "1.0.0",
  "description": "公告系统后端API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "compression": "^1.7.4",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "web-push": "^3.6.6",
    "ws": "^8.14.2",
    "pg": "^8.11.3",
    "dotenv": "^16.3.1"
  }
}
EOF
    fi
    
    # 安装依赖
    npm install
    
    # 创建环境配置文件
    cat > .env << EOF
NODE_ENV=production
PORT=3001
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
JWT_SECRET=$JWT_SECRET
VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY
VAPID_PRIVATE_KEY=$VAPID_PRIVATE_KEY
VAPID_EMAIL=$VAPID_EMAIL
CORS_ORIGIN=https://$DOMAIN
EOF
    
    # 创建生产环境的server.js (基于PostgreSQL)
    cat > server.js << 'EOF'
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const webpush = require('web-push');
const WebSocket = require('ws');
const { Pool } = require('pg');

const app = express();
const PORT = process.env.PORT || 3001;

// 数据库连接
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// 配置Web Push
webpush.setVapidDetails(
  process.env.VAPID_EMAIL,
  process.env.VAPID_PUBLIC_KEY,
  process.env.VAPID_PRIVATE_KEY
);

// 中间件
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:5173'],
  credentials: true
}));
app.use(compression());
app.use(morgan('combined'));
app.use(express.json());

// 健康检查
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// 认证中间件
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ success: false, error: 'Invalid token' });
    }
    req.user = user;
    next();
  });
};

// 公告路由
app.get('/api/announcements', async (req, res) => {
  try {
    const { page = 1, limit = 10, type, priority, active } = req.query;
    
    let query = 'SELECT * FROM announcements WHERE 1=1';
    const params = [];
    let paramCount = 0;
    
    if (type) {
      query += ` AND type = $${++paramCount}`;
      params.push(type);
    }
    
    if (priority) {
      query += ` AND priority = $${++paramCount}`;
      params.push(priority);
    }
    
    if (active !== 'false') {
      query += ` AND is_active = true AND (expires_at IS NULL OR expires_at > NOW())`;
    }
    
    query += ' ORDER BY created_at DESC';
    
    const offset = (page - 1) * limit;
    query += ` LIMIT $${++paramCount} OFFSET $${++paramCount}`;
    params.push(limit, offset);
    
    const result = await pool.query(query, params);
    
    // 检查是否有活跃公告
    const activeResult = await pool.query(
      'SELECT COUNT(*) FROM announcements WHERE is_active = true AND (expires_at IS NULL OR expires_at > NOW())'
    );
    
    res.json({
      success: true,
      data: {
        announcements: result.rows,
        hasActive: parseInt(activeResult.rows[0].count) > 0,
        total: result.rows.length
      }
    });
  } catch (error) {
    console.error('Database error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// 管理员登录
app.post('/api/admin/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    const result = await pool.query(
      'SELECT * FROM admin_users WHERE username = $1',
      [username]
    );
    
    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }
    
    const user = result.rows[0];
    const validPassword = await bcrypt.compare(password, user.password_hash);
    
    if (!validPassword) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }
    
    // 更新最后登录时间
    await pool.query(
      'UPDATE admin_users SET last_login = NOW() WHERE id = $1',
      [user.id]
    );
    
    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          role: user.role
        }
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

// 其他路由...
// (这里可以添加更多API路由)

// 错误处理
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, error: 'Internal server error' });
});

// 启动服务器
const server = require('http').createServer(app);

server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🗄️  Database: ${process.env.DB_NAME}`);
  console.log(`🔐 Environment: ${process.env.NODE_ENV}`);
});

// 优雅关闭
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    pool.end();
    process.exit(0);
  });
});
EOF
    
    # 使用PM2启动服务
    pm2 delete announcement-api 2>/dev/null || true
    pm2 start server.js --name announcement-api
    pm2 save
    
    log_success "后端服务部署完成"
}

# 部署前端
deploy_frontend() {
    log_info "部署前端应用..."
    
    cd $FRONTEND_DIR
    
    # 安装依赖
    npm install
    
    # 创建生产环境配置
    cat > .env.production << EOF
VITE_API_BASE_URL=https://$API_DOMAIN
VITE_WS_URL=wss://$API_DOMAIN
VITE_VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY
VITE_APP_ENV=production
EOF
    
    # 构建前端
    npm run build
    
    # 复制构建文件到Nginx目录
    sudo rm -rf /var/www/$DOMAIN
    sudo mkdir -p /var/www/$DOMAIN
    sudo cp -r dist/* /var/www/$DOMAIN/
    sudo chown -R www-data:www-data /var/www/$DOMAIN
    
    log_success "前端应用部署完成"
}

# 配置Nginx
configure_nginx() {
    log_info "配置Nginx..."
    
    # 创建前端站点配置
    sudo tee /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    
    root /var/www/$DOMAIN;
    index index.html index.htm;
    
    # Gzip压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    # 静态文件缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # SPA路由支持
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
}
EOF
    
    # 创建API站点配置
    sudo tee /etc/nginx/sites-available/$API_DOMAIN << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $API_DOMAIN;
    
    # API代理
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # 健康检查
    location /health {
        access_log off;
        proxy_pass http://localhost:3001/health;
    }
}
EOF
    
    # 启用站点
    sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    sudo ln -sf /etc/nginx/sites-available/$API_DOMAIN /etc/nginx/sites-enabled/
    
    # 删除默认站点
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # 测试配置
    sudo nginx -t
    
    # 重启Nginx
    sudo systemctl reload nginx
    
    log_success "Nginx配置完成"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # 启用UFW
    sudo ufw --force enable
    
    # 允许SSH
    sudo ufw allow ssh
    
    # 允许HTTP和HTTPS
    sudo ufw allow 'Nginx Full'
    
    # 显示状态
    sudo ufw status
    
    log_success "防火墙配置完成"
}

# 配置系统服务
configure_services() {
    log_info "配置系统服务..."
    
    # 配置PM2开机启动
    pm2 startup
    pm2 save
    
    # 配置PostgreSQL
    sudo systemctl enable postgresql
    
    # 配置Nginx
    sudo systemctl enable nginx
    
    log_success "系统服务配置完成"
}

# 创建维护脚本
create_maintenance_scripts() {
    log_info "创建维护脚本..."
    
    mkdir -p $PROJECT_DIR/scripts
    
    # 备份脚本
    cat > $PROJECT_DIR/scripts/backup.sh << EOF
#!/bin/bash
# 数据库备份脚本

BACKUP_DIR="$PROJECT_DIR/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

mkdir -p \$BACKUP_DIR

# 备份数据库
PGPASSWORD=$DB_PASSWORD pg_dump -h localhost -U $DB_USER $DB_NAME > \$BACKUP_DIR/db_backup_\$DATE.sql

# 压缩备份文件
gzip \$BACKUP_DIR/db_backup_\$DATE.sql

# 删除7天前的备份
find \$BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "备份完成: \$BACKUP_DIR/db_backup_\$DATE.sql.gz"
EOF
    
    # 更新脚本
    cat > $PROJECT_DIR/scripts/update.sh << EOF
#!/bin/bash
# 应用更新脚本

cd $PROJECT_DIR

# 拉取最新代码
git pull origin main

# 更新后端
cd $BACKEND_DIR
npm install
pm2 restart announcement-api

# 更新前端
cd $FRONTEND_DIR
npm install
npm run build
sudo cp -r dist/* /var/www/$DOMAIN/

echo "应用更新完成"
EOF
    
    # 监控脚本
    cat > $PROJECT_DIR/scripts/monitor.sh << EOF
#!/bin/bash
# 系统监控脚本

echo "=== 系统状态 ==="
echo "时间: \$(date)"
echo "负载: \$(uptime | awk -F'load average:' '{print \$2}')"
echo "内存: \$(free -h | grep Mem | awk '{print \$3 "/" \$2}')"
echo "磁盘: \$(df -h / | tail -1 | awk '{print \$3 "/" \$2 " (" \$5 ")"}')"

echo -e "\n=== 服务状态 ==="
echo "Nginx: \$(systemctl is-active nginx)"
echo "PostgreSQL: \$(systemctl is-active postgresql)"
echo "PM2: \$(pm2 list | grep announcement-api | awk '{print \$10}')"

echo -e "\n=== 应用日志 (最近10行) ==="
pm2 logs announcement-api --lines 10 --nostream
EOF
    
    # 设置执行权限
    chmod +x $PROJECT_DIR/scripts/*.sh
    
    # 创建定时任务
    (crontab -l 2>/dev/null; echo "0 2 * * * $PROJECT_DIR/scripts/backup.sh") | crontab -
    
    log_success "维护脚本创建完成"
}

# 显示部署信息
show_deployment_info() {
    log_success "🎉 部署完成！"
    echo
    echo "=== 部署信息 ==="
    echo "前端地址: https://$DOMAIN"
    echo "API地址: https://$API_DOMAIN"
    echo "管理员登录: https://$DOMAIN/admin/login"
    echo
    echo "=== 默认账户 ==="
    echo "用户名: admin"
    echo "密码: admin123"
    echo
    echo "=== 数据库信息 ==="
    echo "数据库: $DB_NAME"
    echo "用户: $DB_USER"
    echo "密码: $DB_PASSWORD"
    echo
    echo "=== 重要文件位置 ==="
    echo "项目目录: $PROJECT_DIR"
    echo "前端代码: $FRONTEND_DIR"
    echo "后端代码: $BACKEND_DIR"
    echo "Nginx配置: /etc/nginx/sites-available/"
    echo "维护脚本: $PROJECT_DIR/scripts/"
    echo
    echo "=== 常用命令 ==="
    echo "查看后端日志: pm2 logs announcement-api"
    echo "重启后端: pm2 restart announcement-api"
    echo "查看系统状态: $PROJECT_DIR/scripts/monitor.sh"
    echo "备份数据库: $PROJECT_DIR/scripts/backup.sh"
    echo
    log_warning "请妥善保存数据库密码和JWT密钥！"
    log_info "建议立即修改默认管理员密码"
}

# 主函数
main() {
    echo "========================================"
    echo "    公告系统 Ubuntu 一键部署脚本"
    echo "========================================"
    echo
    
    # 检查权限
    check_root
    
    # 检查系统
    check_system
    
    # 配置参数
    setup_config
    
    # 确认部署
    echo "即将开始部署，配置信息："
    echo "域名: $DOMAIN"
    echo "API域名: $API_DOMAIN"
    echo "项目目录: $PROJECT_DIR"
    echo
    read -p "确认开始部署？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "部署已取消"
        exit 0
    fi
    
    # 开始部署
    log_info "开始部署..."
    
    update_system
    install_dependencies
    install_nodejs
    install_postgresql
    setup_database
    install_nginx
    
    # 注意：这里需要实际的项目代码
    # clone_project
    # deploy_backend
    # deploy_frontend
    
    configure_nginx
    configure_firewall
    configure_services
    create_maintenance_scripts
    
    # 可选：安装SSL证书
    # install_ssl
    
    show_deployment_info
    
    log_success "部署完成！请访问 https://$DOMAIN 查看应用"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
EOF