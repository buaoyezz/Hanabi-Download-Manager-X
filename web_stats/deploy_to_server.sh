#!/bin/bash

# Hanabi 在线统计 - 服务器端部署脚本
# 在服务器上运行此脚本

echo "========================================"
echo "Hanabi 在线统计 - 服务器部署"
echo "========================================"
echo ""

# 检查是否在正确的目录
if [ ! -f "server.js" ]; then
    echo "错误：未找到 server.js"
    echo "请在包含 server.js 的目录中运行此脚本"
    exit 1
fi

# 创建目录
echo "[1/5] 创建目录..."
mkdir -p /opt/hanabi-stats
mkdir -p /www/wwwroot/hanabi-stats
echo "✓ 目录已创建"

# 复制服务器文件
echo ""
echo "[2/5] 复制服务器文件..."
cp server.js /opt/hanabi-stats/
echo "✓ server.js -> /opt/hanabi-stats/"

# 复制网页文件
echo ""
echo "[3/5] 复制网页文件..."
cp index.html /www/wwwroot/hanabi-stats/
cp styles.css /www/wwwroot/hanabi-stats/
cp app.js /www/wwwroot/hanabi-stats/
cp devices.html /www/wwwroot/hanabi-stats/
cp devices.js /www/wwwroot/hanabi-stats/
cp test_api.html /www/wwwroot/hanabi-stats/
cp logo.png /www/wwwroot/hanabi-stats/ 2>/dev/null || echo "  (logo.png 不存在，跳过)"
echo "✓ 网页文件已复制"

# 检查 Node.js
echo ""
echo "[4/5] 检查 Node.js..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo "✓ Node.js 已安装: $NODE_VERSION"
else
    echo "✗ 未找到 Node.js"
    echo "请在宝塔面板安装 Node.js 18.x 或更高版本"
    exit 1
fi

# 检查 PM2
echo ""
echo "[5/5] 检查 PM2..."
if command -v pm2 &> /dev/null; then
    PM2_VERSION=$(pm2 --version)
    echo "✓ PM2 已安装: $PM2_VERSION"
else
    echo "! PM2 未安装，正在安装..."
    npm install -g pm2
    if [ $? -eq 0 ]; then
        echo "✓ PM2 安装成功"
    else
        echo "✗ PM2 安装失败"
        exit 1
    fi
fi

# 启动服务
echo ""
echo "========================================"
echo "部署完成！"
echo "========================================"
echo ""
echo "下一步："
echo ""
echo "1. 启动服务："
echo "   cd /opt/hanabi-stats"
echo "   pm2 start server.js --name hanabi-stats"
echo "   pm2 save"
echo "   pm2 startup"
echo ""
echo "2. 在宝塔面板配置网站："
echo "   - 网站 -> 添加站点"
echo "   - 域名: online.zzbuaoye.top"
echo "   - 根目录: /www/wwwroot/hanabi-stats"
echo ""
echo "3. 配置反向代理 (在网站设置 -> 反向代理)："
echo "   代理名称: api"
echo "   目标URL: http://127.0.0.1:3000"
echo "   发送域名: \$host"
echo "   内容替换: 留空"
echo ""
echo "4. 申请 SSL 证书 (在网站设置 -> SSL)："
echo "   - 选择 Let's Encrypt"
echo "   - 点击申请"
echo ""
echo "完成后访问: https://online.zzbuaoye.top"
echo "========================================"

