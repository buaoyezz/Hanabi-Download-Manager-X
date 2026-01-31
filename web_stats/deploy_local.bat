@echo off
chcp 65001 >nul
echo ========================================
echo Hanabi 在线统计 - 打包部署文件
echo ========================================
echo.

REM 检查文件
echo [1/3] 检查文件...
set FILES=server.js index.html styles.css app.js devices.html devices.js README.md

for %%f in (%FILES%) do (
    if exist "%%f" (
        echo ✓ %%f
    ) else (
        echo ✗ %%f (缺失)
        pause
        exit /b 1
    )
)

REM 创建部署包
echo.
echo [2/3] 创建部署包...

REM 生成时间戳
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%
set PACKAGE_NAME=hanabi-stats-%TIMESTAMP%.zip

REM 检查是否有 PowerShell
where powershell >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    powershell -Command "Compress-Archive -Path server.js,index.html,styles.css,app.js,devices.html,devices.js,README.md -DestinationPath %PACKAGE_NAME% -Force"
    echo ✓ 已创建: %PACKAGE_NAME%
) else (
    echo ✗ 未找到 PowerShell
    echo 请手动打包以下文件为 ZIP:
    for %%f in (%FILES%) do echo   - %%f
    pause
    exit /b 1
)

REM 显示说明
echo.
echo [3/3] 部署说明
echo ========================================
echo.
echo 1. 上传到宝塔面板:
echo    - 登录宝塔面板
echo    - 文件 -^> 上传 %PACKAGE_NAME%
echo    - 解压到两个位置:
echo      * /opt/hanabi-stats/ (只需 server.js)
echo      * /var/www/hanabi-stats/ (网页文件)
echo.
echo 2. 安装 Node.js (如果未安装):
echo    - 软件商店 -^> 搜索 "Node.js"
echo    - 安装 Node.js 18.x 或更高版本
echo.
echo 3. 安装 PM2:
echo    - 终端 -^> npm install -g pm2
echo.
echo 4. 启动服务:
echo    cd /opt/hanabi-stats
echo    pm2 start server.js --name hanabi-stats
echo    pm2 save
echo    pm2 startup
echo.
echo 5. 配置网站 (在宝塔面板):
echo    - 网站 -^> 添加站点
echo    - 域名: online.zzbuaoye.top
echo    - 根目录: /var/www/hanabi-stats
echo    - PHP版本: 纯静态
echo.
echo 6. 配置反向代理:
echo    - 网站设置 -^> 反向代理 -^> 添加反向代理
echo    - 代理名称: hanabi-api
echo    - 目标URL: http://127.0.0.1:3000
echo    - 发送域名: $host
echo    - 配置规则:
echo      位置: /api/
echo      目标: http://127.0.0.1:3000
echo.
echo 7. 申请 SSL 证书:
echo    - 网站设置 -^> SSL -^> Let's Encrypt
echo    - 勾选域名 -^> 申请
echo.
echo 完成！访问 https://online.zzbuaoye.top
echo ========================================
echo.
pause
