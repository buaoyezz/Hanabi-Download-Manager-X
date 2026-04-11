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
set "RELEASE_DIR=build\release"
set "RELEASE_STAGE_DIR=%RELEASE_DIR%\HanabiDownloadManagerX"
set "RELEASE_PACKAGE=%RELEASE_DIR%\HanabiDownloadManagerX_Release_Latest.zip"
set "RHTTP_FIX_SCRIPT=scripts\apply-rhttp-windows-fix.ps1"

:: Check skip options
set SKIP_FLUTTER=0
set COPY_ONLY=0

if "%1"=="--copy-only" (
    set SKIP_FLUTTER=1
    set COPY_ONLY=1
)

if exist "%RHTTP_FIX_SCRIPT%" (
    echo %C_WHITE%[0/3] Applying local rhttp Windows fix...%C_RESET%
    powershell -NoProfile -ExecutionPolicy Bypass -File "%RHTTP_FIX_SCRIPT%"
    if errorlevel 1 (
        echo %C_RED%[ERROR] Failed to apply rhttp Windows fix!%C_RESET%
        pause
        exit /b 1
    )
    echo %C_YELLOW%[OK] rhttp Windows fix ready%C_RESET%
    echo.
)

:: ========== Flutter Build ==========
if %SKIP_FLUTTER%==0 (
    echo %C_WHITE%[1/3] Building Flutter app...%C_RESET%
    call flutter build windows --release
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
echo %C_WHITE%[2/3] Copying assets...%C_RESET%

:: Create zzbuaoye_assets folder
if not exist "%ASSETS_DIR%" (
    mkdir "%ASSETS_DIR%"
    echo   %C_GREEN%+%C_RESET% Created %ASSETS_DIR%
)

:: Copy Update.exe to zzbuaoye_assets
if exist "assets\update\Update.exe" (
    copy /Y "assets\update\Update.exe" "%ASSETS_DIR%\" >nul
    echo   %C_GREEN%+%C_RESET% Update.exe -^> data\zzbuaoye_assets\
) else (
    echo   %C_RED%-%C_RESET% Update.exe not found
)

echo.
echo %C_WHITE%[3/3] Packaging release...%C_RESET%

if not exist "%RELEASE_DIR%" (
    mkdir "%RELEASE_DIR%"
    echo   %C_GREEN%+%C_RESET% Created %RELEASE_DIR%
)

if exist "%RELEASE_STAGE_DIR%" (
    rmdir /S /Q "%RELEASE_STAGE_DIR%"
)
mkdir "%RELEASE_STAGE_DIR%"

for %%F in (
    flutter_acrylic_plugin.dll
    flutter_windows.dll
    HanabiDownloadManagerX.exe
    rhttp.dll
    screen_retriever_plugin.dll
    system_tray_plugin.dll
    url_launcher_windows_plugin.dll
    window_render.log
) do (
    if exist "%OUTPUT_DIR%\%%F" (
        copy /Y "%OUTPUT_DIR%\%%F" "%RELEASE_STAGE_DIR%\" >nul
    )
)

xcopy "%OUTPUT_DIR%\data" "%RELEASE_STAGE_DIR%\data\" /E /I /Y >nul

if exist "%RELEASE_PACKAGE%" (
    del /Q "%RELEASE_PACKAGE%"
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%CD%\%RELEASE_STAGE_DIR%\*' -DestinationPath '%CD%\%RELEASE_PACKAGE%' -CompressionLevel Optimal -Force"
if errorlevel 1 (
    echo %C_RED%[ERROR] Release packaging failed!%C_RESET%
    pause
    exit /b 1
)
echo   %C_GREEN%+%C_RESET% HanabiDownloadManagerX_Release_Latest.zip

echo.
echo %C_YELLOW%========================================%C_RESET%
echo %C_YELLOW%  Build Complete!%C_RESET%
echo %C_YELLOW%========================================%C_RESET%
echo.
echo Output: %OUTPUT_DIR%
echo Assets: %ASSETS_DIR%
echo Package: %RELEASE_PACKAGE%
echo.

pause
