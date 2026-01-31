@echo off
echo ========================================
echo Hanabi Statistics Server - Local Test
echo ========================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Node.js is not installed!
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

echo Node.js version:
node --version
echo.

echo Starting server on http://localhost:3000
echo.
echo Press Ctrl+C to stop the server
echo.
echo Test URLs:
echo   Health: http://localhost:3000/health
echo   Stats:  http://localhost:3000/api/stats
echo   Web:    Open index.html?server=http://localhost:3000
echo.

node server.js
