@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Get ESC character for ANSI colors
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

echo %ESC%[96m========================================%ESC%[0m
echo %ESC%[96m  Hanabi Download Manager Build Script%ESC%[0m
echo %ESC%[96m========================================%ESC%[0m
echo.

set "OUTPUT_DIR=build\windows\x64\runner\Release"
set "ASSETS_DIR=%OUTPUT_DIR%\data\zzbuaoye_assets"

:: Check skip options
set SKIP_PYTHON=0
set SKIP_POPUP=0
set SKIP_FLUTTER=0
set COPY_ONLY=0

if "%1"=="--skip-python" set SKIP_PYTHON=1
if "%1"=="--skip-popup" set SKIP_POPUP=1
if "%1"=="--flutter-only" (
    set SKIP_PYTHON=1
    set SKIP_POPUP=1
)
if "%1"=="--copy-only" (
    set SKIP_PYTHON=1
    set SKIP_POPUP=1
    set SKIP_FLUTTER=1
    set COPY_ONLY=1
)

:: ========== Python Build ==========
if %SKIP_PYTHON%==0 (
    echo %ESC%[97m[1/4] Building Python core...%ESC%[0m
    cd python
    python -m nuitka --standalone --onefile --windows-console-mode=disable --enable-plugin=anti-bloat --nofollow-import-to=unittest --nofollow-import-to=pytest --nofollow-import-to=test --include-package=aiohttp --include-package=aiofiles --include-package-data=soda_speed_force_kernel --output-dir=../build/python --output-filename=soda_bridge_server.exe soda_bridge_server.py
    if errorlevel 1 (
        echo %ESC%[91m[ERROR] Python build failed!%ESC%[0m
        cd ..
        pause
        exit /b 1
    )
    cd ..
    echo %ESC%[93m[OK] Python build done%ESC%[0m
) else (
    echo %ESC%[90m[SKIP] Python build%ESC%[0m
)
echo.

:: ========== Tauri Popup Build ==========
if %SKIP_POPUP%==0 (
    echo %ESC%[97m[2/4] Building Hanabi Popup...%ESC%[0m
    cd hanabi-popup
    call npm run tauri build
    if errorlevel 1 (
        echo %ESC%[91m[ERROR] Popup build failed!%ESC%[0m
        cd ..
        pause
        exit /b 1
    )
    cd ..
    echo %ESC%[93m[OK] Popup build done%ESC%[0m
) else (
    echo %ESC%[90m[SKIP] Popup build%ESC%[0m
)
echo.

:: ========== Flutter Build ==========
if %SKIP_FLUTTER%==0 (
    echo %ESC%[97m[3/4] Building Flutter app...%ESC%[0m
    flutter build windows --release
    if errorlevel 1 (
        echo %ESC%[91m[ERROR] Flutter build failed!%ESC%[0m
        pause
        exit /b 1
    )
    echo %ESC%[93m[OK] Flutter build done%ESC%[0m
) else (
    echo %ESC%[90m[SKIP] Flutter build%ESC%[0m
)
echo.

:: ========== Copy Files ==========
echo %ESC%[97m[4/4] Copying assets...%ESC%[0m

:: Create zzbuaoye_assets folder
if not exist "%ASSETS_DIR%" (
    mkdir "%ASSETS_DIR%"
    echo   %ESC%[92m+%ESC%[0m Created %ASSETS_DIR%
)

:: Copy soda_bridge_server.exe
if exist "build\python\soda_bridge_server.exe" (
    copy /Y "build\python\soda_bridge_server.exe" "%OUTPUT_DIR%\" >nul
    echo   %ESC%[92m+%ESC%[0m soda_bridge_server.exe
) else (
    echo   %ESC%[91m-%ESC%[0m soda_bridge_server.exe not found
)

:: Copy hanabi-popup.exe to zzbuaoye_assets
if exist "hanabi-popup\src-tauri\target\release\hanabi-popup.exe" (
    copy /Y "hanabi-popup\src-tauri\target\release\hanabi-popup.exe" "%ASSETS_DIR%\" >nul
    echo   %ESC%[92m+%ESC%[0m hanabi-popup.exe -^> data\zzbuaoye_assets\
) else (
    echo   %ESC%[91m-%ESC%[0m hanabi-popup.exe not found
)

:: Copy Update.exe to zzbuaoye_assets
if exist "assets\update\Update.exe" (
    copy /Y "assets\update\Update.exe" "%ASSETS_DIR%\" >nul
    echo   %ESC%[92m+%ESC%[0m Update.exe -^> data\zzbuaoye_assets\
) else (
    echo   %ESC%[91m-%ESC%[0m Update.exe not found
)

echo.
echo %ESC%[93m========================================%ESC%[0m
echo %ESC%[93m  Build Complete!%ESC%[0m
echo %ESC%[93m========================================%ESC%[0m
echo.
echo Output: %OUTPUT_DIR%
echo Assets: %ASSETS_DIR%
echo.

pause
