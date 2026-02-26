@echo off
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion

:: Color setup (set NO_COLOR=1 to disable)
set "C_RESET="
set "C_WHITE="
set "C_CYAN="
set "C_YELLOW="
set "C_RED="
set "C_GREEN="
set "C_GRAY="
if not defined NO_COLOR (
    for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
    set "C_RESET=%ESC%[0m"
    set "C_WHITE=%ESC%[97m"
    set "C_CYAN=%ESC%[96m"
    set "C_YELLOW=%ESC%[93m"
    set "C_RED=%ESC%[91m"
    set "C_GREEN=%ESC%[92m"
    set "C_GRAY=%ESC%[90m"
)

echo %C_CYAN%========================================%C_RESET%
echo %C_CYAN%  Hanabi Download Manager Build Script%C_RESET%
echo %C_CYAN%========================================%C_RESET%
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
    echo %C_WHITE%[1/4] Building Python core...%C_RESET%
    cd python
    python -m nuitka --standalone --onefile --windows-console-mode=disable --enable-plugin=anti-bloat --nofollow-import-to=unittest --nofollow-import-to=pytest --nofollow-import-to=test --include-package=aiohttp --include-package=aiofiles --include-package-data=soda_speed_force_kernel --output-dir=../build/python --output-filename=soda_bridge_server.exe soda_bridge_server.py
    if errorlevel 1 (
        echo %C_RED%[ERROR] Python build failed!%C_RESET%
        cd ..
        pause
        exit /b 1
    )
    cd ..
    echo %C_YELLOW%[OK] Python build done%C_RESET%
) else (
    echo %C_GRAY%[SKIP] Python build%C_RESET%
)
echo.

:: ========== Tauri Popup Build ==========
if %SKIP_POPUP%==0 (
    echo %C_WHITE%[2/4] Building Hanabi Popup...%C_RESET%
    call build_popup.bat --build-only --no-pause
    if errorlevel 1 (
        echo %C_RED%[ERROR] Popup build failed!%C_RESET%
        pause
        exit /b 1
    )
    echo %C_YELLOW%[OK] Popup build done%C_RESET%
) else (
    echo %C_GRAY%[SKIP] Popup build%C_RESET%
)
echo.

:: ========== Flutter Build ==========
if %SKIP_FLUTTER%==0 (
    echo %C_WHITE%[3/4] Building Flutter app...%C_RESET%
    flutter build windows --release
    if errorlevel 1 (
        echo %C_RED%[ERROR] Flutter build failed!%C_RESET%
        pause
        exit /b 1
    )
    echo %C_YELLOW%[OK] Flutter build done%C_RESET%
) else (
    echo %C_GRAY%[SKIP] Flutter build%C_RESET%
)
echo.

:: ========== Copy Files ==========
echo %C_WHITE%[4/4] Copying assets...%C_RESET%

:: Create zzbuaoye_assets folder
if not exist "%ASSETS_DIR%" (
    mkdir "%ASSETS_DIR%"
    echo   %C_GREEN%+%C_RESET% Created %ASSETS_DIR%
)

:: Copy soda_bridge_server.exe
if exist "build\python\soda_bridge_server.exe" (
    copy /Y "build\python\soda_bridge_server.exe" "%OUTPUT_DIR%\" >nul
    echo   %C_GREEN%+%C_RESET% soda_bridge_server.exe
) else (
    echo   %C_RED%-%C_RESET% soda_bridge_server.exe not found
)

:: Copy hanabi-popup.exe to zzbuaoye_assets
if exist "hanabi-popup\src-tauri\target\release\hanabi-popup.exe" (
    copy /Y "hanabi-popup\src-tauri\target\release\hanabi-popup.exe" "%ASSETS_DIR%\" >nul
    echo   %C_GREEN%+%C_RESET% hanabi-popup.exe -^> data\zzbuaoye_assets\
) else (
    echo   %C_RED%-%C_RESET% hanabi-popup.exe not found
)

:: Copy Update.exe to zzbuaoye_assets
if exist "assets\update\Update.exe" (
    copy /Y "assets\update\Update.exe" "%ASSETS_DIR%\" >nul
    echo   %C_GREEN%+%C_RESET% Update.exe -^> data\zzbuaoye_assets\
) else (
    echo   %C_RED%-%C_RESET% Update.exe not found
)

echo.
echo %C_YELLOW%========================================%C_RESET%
echo %C_YELLOW%  Build Complete!%C_RESET%
echo %C_YELLOW%========================================%C_RESET%
echo.
echo Output: %OUTPUT_DIR%
echo Assets: %ASSETS_DIR%
echo.

pause
