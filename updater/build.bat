@echo off
chcp 65001 >nul
setlocal

echo [1/2] Restoring and building solution...
dotnet build "%~dp0dotnet\Hanabi.Updater.sln" -c Release
if errorlevel 1 (
    echo [FAIL] Solution build failed.
    pause
    exit /b 1
)

echo.
echo [2/2] Publishing updater (bundle + standalone)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_dotnet.ps1"
if errorlevel 1 (
    echo [FAIL] Publish failed.
    pause
    exit /b 1
)

echo.
echo [OK] Updater build complete.
pause
