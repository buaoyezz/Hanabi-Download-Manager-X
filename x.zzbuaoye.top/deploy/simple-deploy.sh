#!/bin/bash

# 公告系统简化部署脚本
# 适用于已有Node.js环境的服务器

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

# 配置变量
DOMAIN=${DOMAIN:-"x.zzbuaoye.top"}
API_DOMAIN=${API_DOMAIN:-"api.zzbuaoye.top"}
PROJECT_DIR="/opt/hanabi-announcements"
CURRENT_DIR=$(pwd)
APP_USER="announcements"

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    log_error "此脚本需要root权限运行"
    exit 1
fi

# 检查Node.js
check_nodejs() {
    log_info "检查Node.js环境..."
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js未安装"
        exit 1
    fi
    
    NODE_VERSION=$(node --version)
    log_success "Node.js版本: $NODE_VERSION"
    
    # 安装必要的全局包
    npm list -g pm2 &>/dev/null || npm install -g pm2
    npm list -g web-push-cli &>/dev/null || npm install -g web-push-cli
}

# 安装系统依赖
install_system_deps() {
    log_info "安装系统依赖..."
    
    apt update
    apt install -y postgresql postgresql-contrib nginx jq curl
    
    systemctl start postgresql nginx
    systemctl enable postgresql nginx
}

# 创建用户
create_user() {
    if ! id "$APP_USER" &>/dev/null; then
        useradd -r -s /bin/bash -d /home/$APP_USER -m $APP_USER
        log_success "用户 $APP_USER 创建成功"
    fi
}

# 配置数据库
setup_database() {
    log_info "配置数据库..."
    
    DB_PASSWORD=$(openssl rand -base64 32)
    
    sudo -u postgres psql << EOF
CREATE DATABASE announcements;
CREATE USER announcements_user WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE announcements TO announcements_user;
ALTER USER announcements_user CREATEDB;
\q
EOF
    
    # 初始化数据库
    PGPASSWORD=$DB_PASSWORD psql -h localhost -U announcements_user -d announcements -f "$CURRENT_DIR/deploy/init.sql"
    
    echo "$DB_PASSWORD" > /tmp/db_password
    log_success "数据库配置完成，密码已保存到 /tmp/db_password"
}

# 部署应用
deploy_app() {
    log_info "部署应用..."
    
    # 准备项目目录
    mkdir -p $PROJECT_DIR
    cp -r "$CURRENT_DIR"/* $PROJECT_DIR/
    chown -R $APP_USER:$APP_USER $PROJECT_DIR
    
    cd $PROJECT_DIR
    
    # 生成配置
    JWT_SECRET=$(openssl rand -base64 64)
    VAPID_OUTPUT=$(sudo -u $APP_USER npx web-push generate-vapid-keys --json 2>/dev/null || echo '{"publicKey":"placeholder","privateKey":"placeholder"}')
    VAPID_PUBLIC_KEY=$(echo "$VAPID_OUTPUT" | jq -r '.publicKey')
    VAPID_PRIVATE_KEY=$(echo "$VAPID_OUTPUT" | jq -r '.privateKey')
    DB_PASSWORD=$(cat /tmp/db_password)
    
    # 后端配置
    cd $PROJECT_DIR/backend-example
    cat > .env << EOF
NODE_ENV=production
PORT=3001
DB_HOST=localhost
DB_PORT=5432
DB_NAME=announcements
DB_USER=announcements_user
DB_PASSWORD=$DB_PASSWORD
JWT_SECRET=$JWT_SECRET
VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY
VAPID_PRIVATE_KEY=$VAPID_PRIVATE_KEY
VAPID_EMAIL=mailto:admin@$DOMAIN
CORS_ORIGIN=https://$DOMAIN
EOF
    
    sudo -u $APP_USER npm install
    sudo -u $APP_USER pm2 delete announcement-api 2>/dev/null || true
    sudo -u $APP_USER pm2 start server.js --name announcement-api
    
    # 前端配置
    cd $PROJECT_DIR
    cat > .env.production << EOF
VITE_API_BASE_URL=https://$API_DOMAIN
VITE_WS_URL=wss://$API_DOMAIN
VITE_VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY
VITE_APP_ENV=production
EOF
    
    sudo -u $APP_USER npm install
    sudo -u $APP_USER npm run build
    
    # 部署到nginx
    rm -rf /var/www/$DOMAIN
    mkdir -p /var/www/$DOMAIN
    cp -r dist/* /var/www/$DOMAIN/
    chown -R www-data:www-data /var/www/$DOMAIN
    
    sudo -u $APP_USER pm2 save
}

# 配置Nginx
setup_nginx() {
    log_info "配置Nginx..."
    
    # 前端配置
    cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root /var/www/$DOMAIN;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    # API配置
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
    rm -f /etc/nginx/sites-enabled/default
    
    nginx -t && systemctl reload nginx
}

# 显示信息
show_info() {
    DB_PASSWORD=$(cat /tmp/db_password)
    
    log_success "🎉 部署完成！"
    echo
    echo "访问地址: http://$DOMAIN"
    echo "API地址:  http://$API_DOMAIN"
    echo "管理面板: http://$DOMAIN/admin/login"
    echo
    echo "默认账户: admin / admin123"
    echo "数据库密码: $DB_PASSWORD"
    echo
    echo "管理命令:"
    echo "  查看状态: sudo -u $APP_USER pm2 status"
    echo "  查看日志: sudo -u $APP_USER pm2 logs"
    echo "  重启应用: sudo -u $APP_USER pm2 restart all"
    echo
    log_warning "请立即修改默认管理员密码！"
    
    # 清理临时文件
    rm -f /tmp/db_password
}

# 主函数
main() {
    echo "=========================================="
    echo "      公告系统简化部署脚本"
    echo "=========================================="
    echo
    echo "域名: $DOMAIN"
    echo "API域名: $API_DOMAIN"
    echo
    read -p "确认开始部署？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    check_nodejs
    install_system_deps
    create_user
    setup_database
    deploy_app
    setup_nginx
    show_info
}

main "$@"