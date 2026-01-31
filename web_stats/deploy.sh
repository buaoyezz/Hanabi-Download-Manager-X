#!/bin/bash

# Hanabi Download Manager - 在线统计 Web 应用部署脚本
# 使用方法: ./deploy.sh [server_address]

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Hanabi 在线统计 - 部署脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查参数
if [ -z "$1" ]; then
    echo -e "${YELLOW}使用方法: ./deploy.sh user@server:/path/to/deploy${NC}"
    echo -e "${YELLOW}示例: ./deploy.sh root@online.zzbuaoye.top:/var/www/online${NC}"
    exit 1
fi

DEPLOY_TARGET=$1

# 确认部署
echo -e "${YELLOW}即将部署到: ${DEPLOY_TARGET}${NC}"
read -p "确认继续? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}部署已取消${NC}"
    exit 1
fi

# 检查必要文件
echo -e "${GREEN}[1/5] 检查文件...${NC}"
REQUIRED_FILES=("index.html" "styles.css" "app.js" "README.md")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 缺少文件 $file${NC}"
        exit 1
    fi
    echo "  ✓ $file"
done

# 创建临时目录
echo -e "${GREEN}[2/5] 准备文件...${NC}"
TEMP_DIR=$(mktemp -d)
cp index.html styles.css app.js README.md "$TEMP_DIR/"
echo "  ✓ 文件已复制到临时目录"

# 压缩文件（可选）
echo -e "${GREEN}[3/5] 压缩文件...${NC}"
cd "$TEMP_DIR"
tar -czf deploy.tar.gz *
echo "  ✓ 文件已压缩"

# 上传文件
echo -e "${GREEN}[4/5] 上传文件...${NC}"
scp deploy.tar.gz "$DEPLOY_TARGET/"
if [ $? -eq 0 ]; then
    echo "  ✓ 文件上传成功"
else
    echo -e "${RED}  ✗ 文件上传失败${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 解压文件（在服务器上）
echo -e "${GREEN}[5/5] 解压文件...${NC}"
SERVER_PATH=$(echo "$DEPLOY_TARGET" | cut -d':' -f2)
SERVER_HOST=$(echo "$DEPLOY_TARGET" | cut -d':' -f1)

ssh "$SERVER_HOST" "cd $SERVER_PATH && tar -xzf deploy.tar.gz && rm deploy.tar.gz && chmod -R 755 ."
if [ $? -eq 0 ]; then
    echo "  ✓ 文件解压成功"
else
    echo -e "${RED}  ✗ 文件解压失败${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "访问地址: ${YELLOW}http://online.zzbuaoye.top${NC}"
echo -e "API 配置: ${YELLOW}http://online.zzbuaoye.top?server=YOUR_API_SERVER${NC}"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "1. 配置 Nginx/Apache"
echo "2. 设置 HTTPS 证书"
echo "3. 配置 DNS 记录"
echo "4. 测试访问"
echo ""
