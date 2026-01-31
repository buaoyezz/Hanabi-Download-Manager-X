#!/bin/bash

# 公告系统快速部署脚本
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
PROJECT_NAME="hanabi-announcements"
DOMAIN=${DOMAIN:-"localhost"}
API_PORT=${API_PORT:-3001}
WEB_PORT=${WEB_PORT:-5173}

# 获取当前目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

log_info "项目根目录: $PROJECT_ROOT"

# 检查Node.js
check_nodejs() {
    if ! command -v node &> /dev/null; then
        log_error "Node.js未安装，请先安装Node.js 16+"
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 16 ]; then
        log_error "Node.js版本过低，需要16+，当前版本: $(node --version)"
        exit 1
    fi
    
    log_success "Node.js检查通过: $(node --version)"
}

# 安装全局依赖
install_global_deps() {
    log_info "安装全局依赖..."
    
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
    fi
    
    if ! command -v web-push &> /dev/null; then
        npm install -g web-push-cli
    fi
    
    log_success "全局依赖安装完成"
}

# 生成配置
generate_config() {
    log_info "生成配置文件..."
    
    # 生成随机密钥
    JWT_SECRET=$(openssl rand -base64 64 2>/dev/null || echo "your-super-secret-jwt-key-$(date +%s)")
    DB_PASSWORD=$(openssl rand -base64 32 2>/dev/null || echo "password123")
    
    # 生成VAPID密钥
    if command -v web-push &> /dev/null; then
        VAPID_OUTPUT=$(web-push generate-vapid-keys --json 2>/dev/null || echo '{"publicKey":"","privateKey":""}')
        VAPID_PUBLIC_KEY=$(echo "$VAPID_OUTPUT" | grep -o '"publicKey":"[^"]*"' | cut -d'"' -f4)
        VAPID_PRIVATE_KEY=$(echo "$VAPID_OUTPUT" | grep -o '"privateKey":"[^"]*"' | cut -d'"' -f4)
    else
        VAPID_PUBLIC_KEY="your-vapid-public-key"
        VAPID_PRIVATE_KEY="your-vapid-private-key"
    fi
    
    # 创建后端环境配置
    cat > "$PROJECT_ROOT/backend-example/.env" << EOF
NODE_ENV=development
PORT=$API_PORT
JWT_SECRET=$JWT_SECRET
VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY
VAPID_PRIVATE_KEY=$VAPID_PRIVATE_KEY
VAPID_EMAIL=mailto:admin@$DOMAIN
CORS_ORIGIN=http://$DOMAIN:$WEB_PORT,http://localhost:$WEB_PORT
EOF
    
    # 创建前端环境配置
    cat > "$PROJECT_ROOT/.env.local" << EOF
VITE_API_BASE_URL=http://$DOMAIN:$API_PORT
VITE_WS_URL=ws://$DOMAIN:$API_PORT
VITE_VAPID_PUBLIC_KEY=$VAPID_PUBLIC_KEY
VITE_APP_ENV=development
EOF
    
    log_success "配置文件生成完成"
}

# 安装后端依赖
install_backend() {
    log_info "安装后端依赖..."
    
    cd "$PROJECT_ROOT/backend-example"
    
    if [ ! -f package.json ]; then
        log_error "backend-example/package.json 不存在"
        exit 1
    fi
    
    npm install
    
    log_success "后端依赖安装完成"
}

# 安装前端依赖
install_frontend() {
    log_info "安装前端依赖..."
    
    cd "$PROJECT_ROOT"
    
    if [ ! -f package.json ]; then
        log_error "package.json 不存在"
        exit 1
    fi
    
    npm install
    
    log_success "前端依赖安装完成"
}

# 启动后端服务
start_backend() {
    log_info "启动后端服务..."
    
    cd "$PROJECT_ROOT/backend-example"
    
    # 停止已存在的进程
    pm2 delete announcement-api 2>/dev/null || true
    
    # 启动新进程
    pm2 start server.js --name announcement-api
    pm2 save
    
    # 等待服务启动
    sleep 3
    
    # 检查服务状态
    if pm2 list | grep -q "announcement-api.*online"; then
        log_success "后端服务启动成功 (端口: $API_PORT)"
    else
        log_error "后端服务启动失败"
        pm2 logs announcement-api --lines 10
        exit 1
    fi
}

# 启动前端服务
start_frontend() {
    log_info "启动前端服务..."
    
    cd "$PROJECT_ROOT"
    
    # 停止已存在的进程
    pm2 delete announcement-web 2>/dev/null || true
    
    # 启动开发服务器
    pm2 start npm --name announcement-web -- run dev
    pm2 save
    
    # 等待服务启动
    sleep 5
    
    # 检查服务状态
    if pm2 list | grep -q "announcement-web.*online"; then
        log_success "前端服务启动成功 (端口: $WEB_PORT)"
    else
        log_error "前端服务启动失败"
        pm2 logs announcement-web --lines 10
        exit 1
    fi
}

# 创建管理脚本
create_scripts() {
    log_info "创建管理脚本..."
    
    mkdir -p "$PROJECT_ROOT/scripts"
    
    # 启动脚本
    cat > "$PROJECT_ROOT/scripts/start.sh" << EOF
#!/bin/bash
cd "$PROJECT_ROOT"
pm2 start announcement-api announcement-web
echo "服务已启动"
pm2 status
EOF
    
    # 停止脚本
    cat > "$PROJECT_ROOT/scripts/stop.sh" << EOF
#!/bin/bash
pm2 stop announcement-api announcement-web
echo "服务已停止"
EOF
    
    # 重启脚本
    cat > "$PROJECT_ROOT/scripts/restart.sh" << EOF
#!/bin/bash
pm2 restart announcement-api announcement-web
echo "服务已重启"
pm2 status
EOF
    
    # 查看日志脚本
    cat > "$PROJECT_ROOT/scripts/logs.sh" << EOF
#!/bin/bash
echo "=== 后端日志 ==="
pm2 logs announcement-api --lines 20
echo -e "\n=== 前端日志 ==="
pm2 logs announcement-web --lines 20
EOF
    
    # 状态检查脚本
    cat > "$PROJECT_ROOT/scripts/status.sh" << EOF
#!/bin/bash
echo "=== PM2 进程状态 ==="
pm2 status

echo -e "\n=== 端口占用情况 ==="
netstat -tlnp | grep -E ":($API_PORT|$WEB_PORT) "

echo -e "\n=== 服务健康检查 ==="
if curl -s http://localhost:$API_PORT/health > /dev/null; then
    echo "✅ 后端服务正常"
else
    echo "❌ 后端服务异常"
fi

if curl -s http://localhost:$WEB_PORT > /dev/null; then
    echo "✅ 前端服务正常"
else
    echo "❌ 前端服务异常"
fi
EOF
    
    # 设置执行权限
    chmod +x "$PROJECT_ROOT/scripts"/*.sh
    
    log_success "管理脚本创建完成"
}

# 显示部署信息
show_info() {
    log_success "🎉 快速部署完成！"
    echo
    echo "=== 访问地址 ==="
    echo "前端地址: http://$DOMAIN:$WEB_PORT"
    echo "API地址: http://$DOMAIN:$API_PORT"
    echo "管理面板: http://$DOMAIN:$WEB_PORT/admin/login"
    echo
    echo "=== 默认账户 ==="
    echo "用户名: admin"
    echo "密码: admin123"
    echo
    echo "=== 管理命令 ==="
    echo "查看状态: $PROJECT_ROOT/scripts/status.sh"
    echo "查看日志: $PROJECT_ROOT/scripts/logs.sh"
    echo "重启服务: $PROJECT_ROOT/scripts/restart.sh"
    echo "停止服务: $PROJECT_ROOT/scripts/stop.sh"
    echo
    echo "=== PM2 命令 ==="
    echo "查看进程: pm2 list"
    echo "查看日志: pm2 logs"
    echo "重启服务: pm2 restart all"
    echo "停止服务: pm2 stop all"
    echo
    log_warning "这是开发环境部署，生产环境请使用完整部署脚本"
}

# 主函数
main() {
    echo "========================================"
    echo "      公告系统快速部署脚本"
    echo "========================================"
    echo
    
    log_info "开始快速部署..."
    
    check_nodejs
    install_global_deps
    generate_config
    install_backend
    install_frontend
    start_backend
    start_frontend
    create_scripts
    
    show_info
    
    log_success "部署完成！请访问 http://$DOMAIN:$WEB_PORT"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi