@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo   Hanabi Download Manager Build Script
echo ========================================
echo.

set "OUTPUT_DIR=build\windows\x64\runner\Release"
set "ASSETS_DIR=%OUTPUT_DIR%\data\zzbuaoye_assets"

:: Check skip options
set SKIP_PYTHON=0
set SKIP_POPUP=0
set SKIP_FLUTTER=0

if "%1"=="--skip-python" set SKIP_PYTHON=1
if "%1"=="--skip-popup" set SKIP_POPUP=1
if "%1"=="--flutter-only" (
    set SKIP_PYTHON=1
    set SKIP_POPUP=1
)

:: ========== Python Build ==========
if %SKIP_PYTHON%==0 (
    echo [1/4] Building Python core...
    cd python
    python -m nuitka --standalone --onefile --windows-console-mode=disable --enable-plugin=anti-bloat --nofollow-import-to=unittest --nofollow-import-to=pytest --nofollow-import-to=test --include-package=aiohttp --include-package=aiofiles --include-package-data=soda_speed_force_kernel --output-dir=../build/python --output-filename=soda_bridge_server.exe soda_bridge_server.py
    if errorlevel 1 (
        echo [ERROR] Python build failed!
        cd ..
        pause
        exit /b 1
    )
    cd ..
    echo [OK] Python build done
) else (
    echo [SKIP] Python build
)
echo.

:: ========== Tauri Popup Build ==========
if %SKIP_POPUP%==0 (
    echo [2/4] Building Hanabi Popup...
    cd hanabi-popup
    call npm run tauri:build
    if errorlevel 1 (
        echo [ERROR] Popup build failed!
        cd ..
        pause
        exit /b 1
    )
    cd ..
    echo [OK] Popup build done
) else (
    echo [SKIP] Popup build
)
echo.

:: ========== Flutter Build ==========
if %SKIP_FLUTTER%==0 (
    echo [3/4] Building Flutter app...
    flutter build windows --release
    if errorlevel 1 (
        echo [ERROR] Flutter build failed!
        pause
        exit /b 1
    )
    echo [OK] Flutter build done
) else (
    echo [SKIP] Flutter build
)
echo.

:: ========== Copy Files ==========
echo [4/4] Copying assets...

:: Create zzbuaoye_assets folder
if not exist "%ASSETS_DIR%" mkdir "%ASSETS_DIR%"

:: Copy soda_bridge_server.exe
if exist "build\python\soda_bridge_server.exe" (
    copy /Y "build\python\soda_bridge_server.exe" "%OUTPUT_DIR%\" >nul
    echo   + soda_bridge_server.exe
) else (
    echo   - soda_bridge_server.exe not found
)

:: Copy hanabi-popup.exe to zzbuaoye_assets
if exist "hanabi-popup\src-tauri\target\release\hanabi-popup.exe" (
    copy /Y "hanabi-popup\src-tauri\target\release\hanabi-popup.exe" "%ASSETS_DIR%\" >nul
    echo   + hanabi-popup.exe -^> data\zzbuaoye_assets\
) else (
    echo   - hanabi-popup.exe not found
)

:: Copy Update.exe to zzbuaoye_assets
if exist "assets\update\Update.exe" (
    copy /Y "assets\update\Update.exe" "%ASSETS_DIR%\" >nul
    echo   + Update.exe -^> data\zzbuaoye_assets\
) else (
    echo   - Update.exe not found
)

echo.
echo ========================================
echo   Build Complete!
echo ========================================
echo.
echo Output: %OUTPUT_DIR%
echo Assets: %ASSETS_DIR%
echo.

pause
