@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Get ESC character for ANSI colors
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"

echo %ESC%[96m========================================%ESC%[0m
echo %ESC%[96m  Hanabi Popup Build + Copy Script%ESC%[0m
echo %ESC%[96m========================================%ESC%[0m
echo.

set "ROOT=%~dp0"
set "POPUP_DIR=%ROOT%hanabi-popup"
set "POPUP_EXE=%POPUP_DIR%\\src-tauri\\target\\release\\hanabi-popup.exe"

set "NO_PAUSE=0"
set "BUILD_ONLY=0"
for %%A in (%*) do (
    if /I "%%~A"=="--no-pause" set "NO_PAUSE=1"
    if /I "%%~A"=="--build-only" set "BUILD_ONLY=1"
)

echo %ESC%[97m[1/2] Building Hanabi Popup...%ESC%[0m
cd /d "%POPUP_DIR%"
call npm run tauri:build
if errorlevel 1 (
    echo %ESC%[91m[ERROR] Popup build failed!%ESC%[0m
    cd /d "%ROOT%"
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)
cd /d "%ROOT%"
echo %ESC%[93m[OK] Popup build done%ESC%[0m
echo.

if not exist "%POPUP_EXE%" (
    echo %ESC%[91m[ERROR] Popup exe not found: %POPUP_EXE%%ESC%[0m
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

if "%BUILD_ONLY%"=="1" (
    echo %ESC%[90m[SKIP] Copy step (--build-only)%ESC%[0m
    echo.
    echo %ESC%[93m========================================%ESC%[0m
    echo %ESC%[93m  Popup Build Complete!%ESC%[0m
    echo %ESC%[93m========================================%ESC%[0m
    echo.
    if "%NO_PAUSE%"=="0" pause
    exit /b 0
)

echo %ESC%[97m[2/2] Copying popup exe...%ESC%[0m

call :copy_to "%ROOT%build\\windows\\x64\\runner\\Release"
call :copy_to "%ROOT%build\\windows\\x64\\runner\\Debug"

copy /Y "%POPUP_EXE%" "%ROOT%hanabi-popup.exe" >nul
echo   %ESC%[92m+%ESC%[0m hanabi-popup.exe -^> repo root

echo.
echo %ESC%[93m========================================%ESC%[0m
echo %ESC%[93m  Popup Build Complete!%ESC%[0m
echo %ESC%[93m========================================%ESC%[0m
echo.

if "%NO_PAUSE%"=="0" pause
exit /b 0

:copy_to
set "BASE=%~1"
if not exist "%BASE%" (
    echo   %ESC%[90m-%ESC%[0m %BASE% not found, skip
    goto :eof
)
set "ASSETS=%BASE%\\data\\zzbuaoye_assets"
if not exist "%ASSETS%" (
    mkdir "%ASSETS%"
    echo   %ESC%[92m+%ESC%[0m Created %ASSETS%
)
copy /Y "%POPUP_EXE%" "%ASSETS%\\" >nul
echo   %ESC%[92m+%ESC%[0m hanabi-popup.exe -^> %ASSETS%
goto :eof
