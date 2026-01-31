#!/bin/bash

# 公告系统 Root用户部署脚本
# 适用于 Ubuntu 18.04+ / Debian 10+
# 注意：此脚本允许root用户运行，但会创建专用用户来运行应用

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo bash root-deploy.sh"
        exit 1
    fi
    log_info "Root权限检查通过"
}

# 配置变量
setup_config() {
    log_info "配置部署参数..."
    
    # 基础配置
    PROJECT_NAME="hanabi-announcements"
    APP_USER="announcements"
    DOMAIN=${DOMAIN:-"x.zzbuaoye.top"}
    API_DOMAIN=${API_DOMAIN:-"api.zzbuaoye.top"}
    
    # 数据库配置
    DB_NAME="announcements"
    DB_USER="announcements_user"
    DB_PASSWORD=$(openssl rand -base64 32)
    
    # 安全配置
    JWT_SECRET=$(openssl rand -base64 64)
    
    # 路径配置
    PROJECT_DIR="/opt/$PROJECT_NAME"
    CURRENT_DIR=$(pwd)
    
    log_success "配置完成"
    log_info "项目目录: $PROJECT_DIR"
    log_info "当前目录: $CURRENT_DIR"
    log_info "域名: $DOMAIN"
}

# 更新系统
update_system() {
    log_info "更新系统..."
    apt update && apt upgrade -y
    log_success "系统更新完成"
}

# 安装基础依赖
install_dependencies() {
    log_info "安装基础依赖..."
    
    apt install -y \
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
        fail2ban \
        nginx \
        postgresql \
        postgresql-contrib
    
    log_success "基础依赖安装完成"
}

# 创建应用用户
create_app_user() {
    log_info "创建应用用户..."
    
    if ! id "$APP_USER" &>/dev/null; then
        useradd -r -s /bin/bash -d /home/$APP_USER -m $APP_USER
        log_success "用户 $APP_USER 创建成功"
    else
        log_info "用户 $APP_USER 已存在"
    fi
}

# 检查Node.js
check_nodejs() {
    log_info "检查Node.js环境..."
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js未安装，请先安装Node.js"
        exit 1
    fi
    
    NODE_VERSION=$(node --version)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'v' -f2 | cut -d'.' -f1)
    
    log_info "检测到Node.js版本: $NODE_VERSION"
    
    if [ "$NODE_MAJOR" -lt 16 ]; then
        log_error "Node.js版本过低，需要16+，当前版本: $NODE_VERSION"
        exit 1
    fi
    
    log_success "Node.js版本检查通过: $NODE_VERSION"
    
    # 检查并安装全局包
    if ! command -v pm2 &> /dev/null; then
        log_info "安装PM2..."
        npm install -g pm2
    else
        log_info "PM2已安装: $(pm2 --version)"
    fi
    
    if ! command -v web-push &> /dev/null; then
        log_info "安装web-push-cli..."
        npm install -g web-push-cli
    else
        log_info "web-push-cli已安装"
    fi
    
    # 配置PM2
    pm2 install pm2-logrotate 2>/dev/null || true
    pm2 set pm2-logrotate:max_size 10M 2>/dev/null || true
    pm2 set pm2-logrotate:retain 30 2>/dev/null || true
    
    log_success "Node.js环境配置完成"
}

# 配置PostgreSQL
setup_postgresql() {
    log_info "配置PostgreSQL..."
    
    systemctl start postgresql
    systemctl enable postgresql
    
    # 创建数据库和用户
    sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER CREATEDB;
\q
EOF
    
    # 初始化数据库
    PGPASSWORD=$DB_PASSWORD psql -h localhost -U $DB_USER -d $DB_NAME -f "$CURRENT_DIR/deploy/init.sql"
    
    log_success "PostgreSQL配置完成"
}

# 准备项目文件
prepare_project() {
    log_info "准备项目文件..."
    
    # 创建项目目录
    mkdir -p $PROJECT_DIR
    
    # 复制项目文件
    cp -r "$CURRENT_DIR"/* $PROJECT_DIR/
    
    # 设置权限
    chown -R $APP_USER:$APP_USER $PROJECT_DIR
    
    log_success "项目文件准备完成"
}

# 生成VAPID密钥
generate_vapid_keys() {
    log_info "生成VAPID密钥..."
    
    cd $PROJECT_DIR
    
    # 生成VAPID密钥
    VAPID_OUTPUT=$(sudo -u $APP_USER npx web-push generate-vapid-keys --json 2>/dev/null || echo '{"publicKey":"","privateKey":""}')
    VAPID_PUBLIC_KEY=$(echo "$VAPID_OUTPUT" | jq -r '.publicKey' 2>/dev/null || echo "")
    VAPID_PRIVATE_KEY=$(echo "$VAPID_OUTPUT" | jq -r '.privateKey' 2>/dev/null || echo "")
    
    if [[ -z "$VAPID_PUBLIC_KEY" || "$VAPID_PUBLIC_KEY" == "null" ]]; then
        log_warning "VAPID密钥生成失败，使用占位符"
        VAPID_PUBLIC_KEY="your-vapid-public-key"
        VAPID_PRIVATE_KEY="your-vapid-private-key"
    fi
    
    log_success "VAPID密钥生成完成"
}

# 部署后端
deploy_backend() {
    log_info "部署后端..."
    
    cd $PROJECT_DIR/backend-example
    
    # 创建环境配置
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
VAPID_EMAIL=mailto:admin@$DOMAIN
CORS_ORIGIN=https://$DOMAIN
EOF
    
    # 安装依赖
    sudo -u $APP_USER npm install
    
    # 启动服务
    sudo -u $APP_USER pm2 delete announcement-api 2>/dev/null || true
    sudo -u $APP_USER pm2 start server.js --name announcement-api
    sudo -u $APP_USER pm2 save
    
    log_success "后端部署完成"
}

# 部署前端
deploy_frontend() {
    log_info "部署前端..."
    
    cd $PROJECT_DIR
    
    # 创建环境配置
    cat > .env.production << EOF
VITE_API_BASE_URL=https://$API_DOMAIN
VITE_WS_URL=wss://$API_DOMAIN
VITE_VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY
VITE_APP_ENV=production
EOF
    
    # 安装依赖并构建
    sudo -u $APP_USER npm install
    sudo -u $APP_USER npm run build
    
    # 部署到Nginx
    rm -rf /var/www/$DOMAIN
    mkdir -p /var/www/$DOMAIN
    cp -r dist/* /var/www/$DOMAIN/
    chown -R www-data:www-data /var/www/$DOMAIN
    
    log_success "前端部署完成"
}

# 配置Nginx
configure_nginx() {
    log_info "配置Nginx..."
    
    # 备份默认配置
    if [[ -f /etc/nginx/sites-enabled/default ]]; then
        mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak
    fi
    
    # 创建前端站点配置
    cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    root /var/www/$DOMAIN;
    index index.html;
    
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
    
    # Service Worker
    location /sw.js {
        expires 0;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    
    # SPA路由支持
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF
    
    # 创建API站点配置
    cat > /etc/nginx/sites-available/$API_DOMAIN << EOF
server {
    listen 80;
    server_name $API_DOMAIN;
    
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
    }
}
EOF
    
    # 启用站点
    ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    ln -sf /etc/nginx/sites-available/$API_DOMAIN /etc/nginx/sites-enabled/
    
    # 测试并重启Nginx
    nginx -t && systemctl restart nginx
    systemctl enable nginx
    
    log_success "Nginx配置完成"
}

# 配置SSL证书
setup_ssl() {
    log_info "配置SSL证书..."
    
    # 安装certbot
    apt install -y certbot python3-certbot-nginx
    
    log_warning "请确保域名 $DOMAIN 和 $API_DOMAIN 已正确解析到当前服务器"
    read -p "域名是否已正确解析？继续安装SSL证书？(y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        certbot --nginx -d $DOMAIN -d www.$DOMAIN -d $API_DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN || {
            log_warning "SSL证书安装失败，将继续使用HTTP"
        }
    else
        log_info "跳过SSL证书安装"
    fi
}

# 配置防火墙
setup_firewall() {
    log_info "配置防火墙..."
    
    ufw --force enable
    ufw allow ssh
    ufw allow 'Nginx Full'
    ufw allow 22
    ufw allow 80
    ufw allow 443
    
    log_success "防火墙配置完成"
}

# 配置系统服务
setup_services() {
    log_info "配置系统服务..."
    
    # 配置PM2开机启动
    sudo -u $APP_USER pm2 startup systemd -u $APP_USER --hp /home/$APP_USER
    sudo -u $APP_USER pm2 save
    
    # 启用服务
    systemctl enable postgresql nginx
    
    log_success "系统服务配置完成"
}

# 创建管理脚本
create_management_scripts() {
    log_info "创建管理脚本..."
    
    mkdir -p $PROJECT_DIR/scripts
    
    # 状态检查脚本
    cat > $PROJECT_DIR/scripts/status.sh << EOF
#!/bin/bash
echo "=== 系统状态 ==="
echo "时间: \$(date)"
echo "负载: \$(uptime | awk -F'load average:' '{print \$2}')"
echo "内存: \$(free -h | grep Mem | awk '{print \$3 "/" \$2}')"
echo "磁盘: \$(df -h / | tail -1 | awk '{print \$3 "/" \$2 " (" \$5 ")"}')"

echo -e "\n=== 服务状态 ==="
echo "Nginx: \$(systemctl is-active nginx)"
echo "PostgreSQL: \$(systemctl is-active postgresql)"

echo -e "\n=== PM2状态 ==="
sudo -u $APP_USER pm2 status

echo -e "\n=== 端口监听 ==="
netstat -tlnp | grep -E ":(80|443|3001|5432) "
EOF
    
    # 重启脚本
    cat > $PROJECT_DIR/scripts/restart.sh << EOF
#!/bin/bash
echo "重启应用服务..."
sudo -u $APP_USER pm2 restart all
systemctl restart nginx
echo "服务重启完成"
EOF
    
    # 备份脚本
    cat > $PROJECT_DIR/scripts/backup.sh << EOF
#!/bin/bash
BACKUP_DIR="$PROJECT_DIR/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
mkdir -p \$BACKUP_DIR

echo "备份数据库..."
PGPASSWORD=$DB_PASSWORD pg_dump -h localhost -U $DB_USER $DB_NAME > \$BACKUP_DIR/db_backup_\$DATE.sql
gzip \$BACKUP_DIR/db_backup_\$DATE.sql

echo "清理旧备份..."
find \$BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "备份完成: \$BACKUP_DIR/db_backup_\$DATE.sql.gz"
EOF
    
    # 设置权限
    chmod +x $PROJECT_DIR/scripts/*.sh
    
    # 添加定时任务
    (crontab -l 2>/dev/null; echo "0 2 * * * $PROJECT_DIR/scripts/backup.sh") | crontab -
    
    log_success "管理脚本创建完成"
}

# 显示部署信息
show_deployment_info() {
    log_success "🎉 部署完成！"
    echo
    echo "=========================================="
    echo "           部署信息"
    echo "=========================================="
    echo
    echo "🌐 访问地址:"
    echo "   前端: http://$DOMAIN"
    echo "   API:  http://$API_DOMAIN"
    echo "   管理: http://$DOMAIN/admin/login"
    echo
    echo "👤 默认账户:"
    echo "   用户名: admin"
    echo "   密码:   admin123"
    echo
    echo "🗄️  数据库信息:"
    echo "   数据库: $DB_NAME"
    echo "   用户:   $DB_USER"
    echo "   密码:   $DB_PASSWORD"
    echo
    echo "🔐 重要密钥:"
    echo "   JWT密钥: $JWT_SECRET"
    echo
    echo "📁 重要路径:"
    echo "   项目目录: $PROJECT_DIR"
    echo "   网站目录: /var/www/$DOMAIN"
    echo "   Nginx配置: /etc/nginx/sites-available/"
    echo
    echo "🛠️  管理命令:"
    echo "   查看状态: $PROJECT_DIR/scripts/status.sh"
    echo "   重启服务: $PROJECT_DIR/scripts/restart.sh"
    echo "   备份数据: $PROJECT_DIR/scripts/backup.sh"
    echo "   查看日志: sudo -u $APP_USER pm2 logs"
    echo
    echo "=========================================="
    log_warning "请妥善保存数据库密码和JWT密钥！"
    log_warning "建议立即修改默认管理员密码！"
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo
        log_info "SSL证书安装命令:"
        echo "certbot --nginx -d $DOMAIN -d www.$DOMAIN -d $API_DOMAIN"
    fi
}

# 主函数
main() {
    echo "=========================================="
    echo "    公告系统 Root用户部署脚本"
    echo "=========================================="
    echo
    
    check_root
    setup_config
    
    echo "即将开始部署，配置信息："
    echo "域名: $DOMAIN"
    echo "API域名: $API_DOMAIN"
    echo "项目目录: $PROJECT_DIR"
    echo "应用用户: $APP_USER"
    echo
    read -p "确认开始部署？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "部署已取消"
        exit 0
    fi
    
    log_info "开始部署..."
    
    update_system
    install_dependencies
    create_app_user
    check_nodejs
    setup_postgresql
    prepare_project
    generate_vapid_keys
    deploy_backend
    deploy_frontend
    configure_nginx
    setup_firewall
    setup_services
    create_management_scripts
    
    # 可选SSL配置
    setup_ssl
    
    show_deployment_info
}

# 错误处理
trap 'log_error "部署过程中发生错误，请检查日志"; exit 1' ERR

# 脚本入口
main "$@"