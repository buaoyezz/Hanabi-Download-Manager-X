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
echo %C_CYAN%  Hanabi Popup Build + Copy Script%C_RESET%
echo %C_CYAN%========================================%C_RESET%
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

echo %C_WHITE%[1/2] Building Hanabi Popup...%C_RESET%
cd /d "%POPUP_DIR%"
call npm run tauri:build
if errorlevel 1 (
    echo %C_RED%[ERROR] Popup build failed!%C_RESET%
    cd /d "%ROOT%"
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)
cd /d "%ROOT%"
echo %C_YELLOW%[OK] Popup build done%C_RESET%
echo.

if not exist "%POPUP_EXE%" (
    echo %C_RED%[ERROR] Popup exe not found: %POPUP_EXE%%C_RESET%
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

if "%BUILD_ONLY%"=="1" (
    echo %C_GRAY%[SKIP] Copy step (--build-only)%C_RESET%
    echo.
    echo %C_YELLOW%========================================%C_RESET%
    echo %C_YELLOW%  Popup Build Complete!%C_RESET%
    echo %C_YELLOW%========================================%C_RESET%
    echo.
    if "%NO_PAUSE%"=="0" pause
    exit /b 0
)

echo %C_WHITE%[2/2] Copying popup exe...%C_RESET%

call :copy_to "%ROOT%build\\windows\\x64\\runner\\Release"
call :copy_to "%ROOT%build\\windows\\x64\\runner\\Debug"

copy /Y "%POPUP_EXE%" "%ROOT%hanabi-popup.exe" >nul
echo   %C_GREEN%+%C_RESET% hanabi-popup.exe -^> repo root

echo.
echo %C_YELLOW%========================================%C_RESET%
echo %C_YELLOW%  Popup Build Complete!%C_RESET%
echo %C_YELLOW%========================================%C_RESET%
echo.

if "%NO_PAUSE%"=="0" pause
exit /b 0

:copy_to
set "BASE=%~1"
if not exist "%BASE%" (
    echo   %C_GRAY%-%C_RESET% %BASE% not found, skip
    goto :eof
)
set "ASSETS=%BASE%\\data\\zzbuaoye_assets"
if not exist "%ASSETS%" (
    mkdir "%ASSETS%"
    echo   %C_GREEN%+%C_RESET% Created %ASSETS%
)
copy /Y "%POPUP_EXE%" "%ASSETS%\\" >nul
echo   %C_GREEN%+%C_RESET% hanabi-popup.exe -^> %ASSETS%
goto :eof
