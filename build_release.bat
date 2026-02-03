@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ╔════════════════════════════════════════════╗
echo ║     Hanabi Download Manager 统一编译脚本    ║
echo ╚════════════════════════════════════════════╝
echo.

set "OUTPUT_DIR=build\windows\x64\runner\Release"
set "ASSETS_DIR=%OUTPUT_DIR%\data\zzbuaoye_assets"

:: 检查是否跳过某些步骤
set SKIP_PYTHON=0
set SKIP_POPUP=0
set SKIP_FLUTTER=0

if "%1"=="--skip-python" set SKIP_PYTHON=1
if "%1"=="--skip-popup" set SKIP_POPUP=1
if "%1"=="--flutter-only" (
    set SKIP_PYTHON=1
    set SKIP_POPUP=1
)

:: ========== Python 编译 ==========
if %SKIP_PYTHON%==0 (
    echo [1/4] 编译 Python 下载核心...
    cd python
    python -m nuitka --standalone --onefile --windows-console-mode=disable --enable-plugin=anti-bloat --nofollow-import-to=unittest --nofollow-import-to=pytest --nofollow-import-to=test --include-package=aiohttp --include-package=aiofiles --include-package-data=soda_speed_force_kernel --output-dir=../build/python --output-filename=soda_bridge_server.exe soda_bridge_server.py
    if errorlevel 1 (
        echo [错误] Python 编译失败！
        cd ..
        pause
        exit /b 1
    )
    cd ..
    echo [完成] Python 编译成功
) else (
    echo [跳过] Python 编译
)
echo.

:: ========== Tauri 弹窗编译 ==========
if %SKIP_POPUP%==0 (
    echo [2/4] 编译 Hanabi Popup 弹窗...
    cd hanabi-popup
    call npm run tauri:build
    if errorlevel 1 (
        echo [错误] Popup 编译失败！
        cd ..
        pause
        exit /b 1
    )
    cd ..
    echo [完成] Popup 编译成功
) else (
    echo [跳过] Popup 编译
)
echo.

:: ========== Flutter 编译 ==========
if %SKIP_FLUTTER%==0 (
    echo [3/4] 编译 Flutter 主程序...
    flutter build windows --release
    if errorlevel 1 (
        echo [错误] Flutter 编译失败！
        pause
        exit /b 1
    )
    echo [完成] Flutter 编译成功
) else (
    echo [跳过] Flutter 编译
)
echo.

:: ========== 复制文件到指定位置 ==========
echo [4/4] 复制资源文件...

:: 创建 zzbuaoye_assets 目录
if not exist "%ASSETS_DIR%" mkdir "%ASSETS_DIR%"

:: 复制 soda_bridge_server.exe
if exist "build\python\soda_bridge_server.exe" (
    copy /Y "build\python\soda_bridge_server.exe" "%OUTPUT_DIR%\" >nul
    echo   √ soda_bridge_server.exe
) else (
    echo   × soda_bridge_server.exe 未找到
)

:: 复制 hanabi-popup.exe 到 zzbuaoye_assets
if exist "hanabi-popup\src-tauri\target\release\hanabi-popup.exe" (
    copy /Y "hanabi-popup\src-tauri\target\release\hanabi-popup.exe" "%ASSETS_DIR%\" >nul
    echo   √ hanabi-popup.exe -^> data\zzbuaoye_assets\
) else (
    echo   × hanabi-popup.exe 未找到
)

:: 复制 Update.exe 到 zzbuaoye_assets
if exist "assets\update\Update.exe" (
    copy /Y "assets\update\Update.exe" "%ASSETS_DIR%\" >nul
    echo   √ Update.exe -^> data\zzbuaoye_assets\
) else (
    echo   × Update.exe 未找到 (assets\update\Update.exe)
)

echo.
echo ╔════════════════════════════════════════════╗
echo ║              编译完成！                     ║
echo ╚════════════════════════════════════════════╝
echo.
echo 输出目录: %OUTPUT_DIR%
echo 资源目录: %ASSETS_DIR%
echo.
echo 目录结构:
echo   Release\
echo   ├── hanabi_download_manager.exe
echo   ├── soda_bridge_server.exe
echo   └── data\
echo       └── zzbuaoye_assets\
echo           ├── hanabi-popup.exe
echo           └── Update.exe
echo.

pause
