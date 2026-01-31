#!/bin/bash

# Hanabi 在线统计 - 本地打包脚本
# 用于宝塔面板部署

echo "========================================"
echo "Hanabi 在线统计 - 打包部署文件"
echo "========================================"
echo ""

# 检查文件
echo "[1/3] 检查文件..."
FILES=(
    "server.js"
    "index.html"
    "styles.css"
    "app.js"
    "devices.html"
    "devices.js"
    "test_api.html"
    "README.md"
    "deploy_to_server.sh"
    "QUICK_DEPLOY.md"
    "NGINX_CONFIG.md"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file"
    else
        echo "✗ $file (缺失)"
        exit 1
    fi
done

# 创建部署包
echo ""
echo "[2/3] 创建部署包..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PACKAGE_NAME="hanabi-stats-${TIMESTAMP}.zip"

# 使用 zip 命令打包
if command -v zip &> /dev/null; then
    zip -q "$PACKAGE_NAME" "${FILES[@]}"
    echo "✓ 已创建: $PACKAGE_NAME"
else
    echo "✗ 未找到 zip 命令"
    echo "请手动打包以下文件："
    for file in "${FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

# 显示说明
echo ""
echo "[3/3] 部署说明"
echo "========================================"
echo ""
echo "1. 上传到宝塔面板："
echo "   - 上传 $PACKAGE_NAME 到服务器"
echo "   - 解压到 /opt/hanabi-stats/ (服务器端)"
echo "   - 解压到 /var/www/hanabi-stats/ (网页端)"
echo ""
echo "2. 安装 Node.js (如果未安装)："
echo "   - 在宝塔面板 -> 软件商店 -> 搜索 Node.js"
echo "   - 安装 Node.js 18.x 或更高版本"
echo ""
echo "3. 安装 PM2："
echo "   npm install -g pm2"
echo ""
echo "4. 启动服务："
echo "   cd /opt/hanabi-stats"
echo "   pm2 start server.js --name hanabi-stats"
echo "   pm2 save"
echo "   pm2 startup"
echo ""
echo "5. 配置 Nginx (在宝塔面板)："
echo "   - 网站 -> 添加站点"
echo "   - 域名: online.zzbuaoye.top"
echo "   - 根目录: /var/www/hanabi-stats"
echo "   - 配置反向代理 (见 DEPLOYMENT.md)"
echo ""
echo "6. 申请 SSL 证书："
echo "   - 在宝塔面板 -> SSL -> Let's Encrypt"
echo ""
echo "完成！"
echo "========================================"
