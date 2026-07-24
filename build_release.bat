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
for /F "tokens=2" %%V in ('findstr /B /C:"version:" pubspec.yaml') do set "APP_VERSION=%%V"
if not defined APP_VERSION (
    echo %C_RED%[ERROR] Unable to read version from pubspec.yaml.%C_RESET%
    exit /b 1
)
set "RELEASE_PACKAGE=%RELEASE_DIR%\HanabiDownloadManagerX_Release_Latest.zip"
set "RELEASE_PACKAGE_VERSIONED=%RELEASE_DIR%\HanabiDownloadManagerX_%APP_VERSION%_windows_x64.zip"
set "RELEASE_CHECKSUMS=%RELEASE_DIR%\SHA256SUMS.txt"
set "RHTTP_FIX_SCRIPT=scripts\apply-rhttp-windows-fix.ps1"
set "UPDATER_TEST_SCRIPT=scripts\test-updater-bundle.ps1"
set "NEONSF_BUILD_SCRIPT=neonsf\build_dotnet.ps1"
set "NEONSF_DIST_DIR=build\neonsf\win-x64"

:: Check skip options
set SKIP_FLUTTER=0
set COPY_ONLY=0
set NO_PAUSE=0

for %%A in (%*) do (
    if /I "%%~A"=="--copy-only" (
        set SKIP_FLUTTER=1
        set COPY_ONLY=1
    )
    if /I "%%~A"=="--no-pause" set NO_PAUSE=1
)

if exist "%RHTTP_FIX_SCRIPT%" (
    echo %C_WHITE%[0/3] Applying local rhttp Windows fix...%C_RESET%
    powershell -NoProfile -ExecutionPolicy Bypass -File "%RHTTP_FIX_SCRIPT%"
    if errorlevel 1 (
        echo %C_RED%[ERROR] Failed to apply rhttp Windows fix!%C_RESET%
        call :maybe_pause
        exit /b 1
    )
    echo %C_YELLOW%[OK] rhttp Windows fix ready%C_RESET%
    echo.
)

echo %C_WHITE%[0.5/3] Syncing l10n...%C_RESET%
call dart run tool\sync_l10n.dart
if errorlevel 1 (
    echo %C_RED%[ERROR] l10n sync failed!%C_RESET%
    call :maybe_pause
    exit /b 1
)
echo %C_YELLOW%[OK] l10n synced%C_RESET%
echo.

:: Build NeoNSFX before Flutter tests so integration tests exercise the exact
:: NativeAOT sidecar that will be packaged.
if %SKIP_FLUTTER%==0 (
    if not exist "%NEONSF_BUILD_SCRIPT%" (
        echo %C_RED%[ERROR] NeoNSFX build script is missing.%C_RESET%
        call :maybe_pause
        exit /b 1
    )
    echo %C_WHITE%[0.65/3] Building NativeAOT NeoNSFX engine...%C_RESET%
    powershell -NoProfile -ExecutionPolicy Bypass -File "%NEONSF_BUILD_SCRIPT%"
    if errorlevel 1 (
        echo %C_RED%[ERROR] NeoNSFX build failed!%C_RESET%
        call :maybe_pause
        exit /b 1
    )
    echo %C_YELLOW%[OK] NeoNSFX build ready for integration tests%C_RESET%
    echo.
)

if %SKIP_FLUTTER%==0 (
    echo %C_WHITE%[0.75/3] Running release quality gates...%C_RESET%
    call flutter test --reporter compact
    if errorlevel 1 (
        echo %C_RED%[ERROR] Flutter tests failed!%C_RESET%
        call :maybe_pause
        exit /b 1
    )
    call flutter analyze --no-fatal-infos
    if errorlevel 1 (
        echo %C_RED%[ERROR] Flutter analysis found a warning or error!%C_RESET%
        call :maybe_pause
        exit /b 1
    )
    echo %C_YELLOW%[OK] Release quality gates passed%C_RESET%
    echo.
)

:: ========== Flutter Build ==========
if %SKIP_FLUTTER%==0 (
    echo %C_WHITE%[1/3] Building Flutter app...%C_RESET%
    call flutter build windows --release
    if errorlevel 1 (
        echo %C_RED%[ERROR] Flutter build failed!%C_RESET%
        call :maybe_pause
        exit /b 1
    )
    echo %C_YELLOW%[OK] Flutter build done%C_RESET%
) else (
    echo %C_GRAY%[SKIP] Flutter build%C_RESET%
)
echo.

:: ========== Updater Build ==========
if %SKIP_FLUTTER%==0 (
    if exist "updater\build_dotnet.ps1" (
        echo %C_WHITE%[1.5/3] Building NativeAOT updater...%C_RESET%
        powershell -NoProfile -ExecutionPolicy Bypass -File "updater\build_dotnet.ps1"
        if errorlevel 1 (
            echo %C_RED%[ERROR] Updater build failed!%C_RESET%
            call :maybe_pause
            exit /b 1
        )
        echo %C_YELLOW%[OK] Updater build done%C_RESET%
        echo.
    )
) else (
    echo %C_GRAY%[SKIP] Updater build%C_RESET%
    echo.
)

if not exist "%NEONSF_DIST_DIR%\HanabiNeoNSF.exe" (
    echo %C_RED%[ERROR] HanabiNeoNSF.exe is required for release builds.%C_RESET%
    call :maybe_pause
    exit /b 1
)

echo %C_WHITE%[1.7/3] Probing NeoNSFX without opening a window...%C_RESET%
"%NEONSF_DIST_DIR%\HanabiNeoNSF.exe" --probe >nul
if errorlevel 1 (
    echo %C_RED%[ERROR] NeoNSFX launch probe failed!%C_RESET%
    call :maybe_pause
    exit /b 1
)
echo %C_YELLOW%[OK] NeoNSFX sidecar is launchable%C_RESET%
echo.

if not exist "updater\dist\HanabiUpdater.exe" (
    echo %C_RED%[ERROR] HanabiUpdater.exe is required for release builds.%C_RESET%
    call :maybe_pause
    exit /b 1
)

if not exist "%UPDATER_TEST_SCRIPT%" (
    echo %C_RED%[ERROR] Updater launch probe script is missing.%C_RESET%
    call :maybe_pause
    exit /b 1
)

echo %C_WHITE%[1.75/3] Testing updater bundle without opening a window...%C_RESET%
powershell -NoProfile -ExecutionPolicy Bypass -File "%UPDATER_TEST_SCRIPT%" -BundleDirectory "updater\dist"
if errorlevel 1 (
    echo %C_RED%[ERROR] Updater bundle launch probe failed!%C_RESET%
    call :maybe_pause
    exit /b 1
)
echo %C_YELLOW%[OK] Updater bundle is launchable%C_RESET%
echo.

:: ========== Copy Files ==========
echo %C_WHITE%[2/3] Copying assets...%C_RESET%

:: Create zzbuaoye_assets folder
if not exist "%ASSETS_DIR%" (
    mkdir "%ASSETS_DIR%"
    echo   %C_GREEN%+%C_RESET% Created %ASSETS_DIR%
)

:: Copy HanabiUpdater bundle to zzbuaoye_assets (NativeAOT Avalonia updater)
if exist "updater\dist\HanabiUpdater.exe" (
    if exist "%ASSETS_DIR%\updater" rmdir /S /Q "%ASSETS_DIR%\updater"
    mkdir "%ASSETS_DIR%\updater"
    xcopy /E /I /Y "updater\dist\*" "%ASSETS_DIR%\updater\" >nul
    echo   %C_GREEN%+%C_RESET% HanabiUpdater bundle -^> data\zzbuaoye_assets\updater\
) else (
    echo   %C_RED%[ERROR] HanabiUpdater bundle disappeared before packaging.%C_RESET%
    call :maybe_pause
    exit /b 1
)

for %%F in (HanabiUpdater.exe av_libglesv2.dll libHarfBuzzSharp.dll libSkiaSharp.dll) do (
    if not exist "%ASSETS_DIR%\updater\%%F" (
        echo %C_RED%[ERROR] Packaged updater dependency missing: %%F%C_RESET%
        call :maybe_pause
        exit /b 1
    )
)

if exist "%ASSETS_DIR%\neonsf" rmdir /S /Q "%ASSETS_DIR%\neonsf"
mkdir "%ASSETS_DIR%\neonsf"
xcopy /E /I /Y "%NEONSF_DIST_DIR%\*" "%ASSETS_DIR%\neonsf\" >nul
if not exist "%ASSETS_DIR%\neonsf\HanabiNeoNSF.exe" (
    echo %C_RED%[ERROR] Packaged NeoNSFX executable is missing.%C_RESET%
    call :maybe_pause
    exit /b 1
)
echo   %C_GREEN%+%C_RESET% NeoNSFX bundle -^> data\zzbuaoye_assets\neonsf\

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

for %%F in ("%OUTPUT_DIR%\*.dll") do (
    copy /Y "%%~fF" "%RELEASE_STAGE_DIR%\" >nul
)

for %%F in (
    HanabiDownloadManagerX.exe
) do (
    if exist "%OUTPUT_DIR%\%%F" (
        copy /Y "%OUTPUT_DIR%\%%F" "%RELEASE_STAGE_DIR%\" >nul
    )
)

xcopy "%OUTPUT_DIR%\data" "%RELEASE_STAGE_DIR%\data\" /E /I /Y >nul

if exist "%RELEASE_PACKAGE%" (
    del /Q "%RELEASE_PACKAGE%"
)
if exist "%RELEASE_PACKAGE_VERSIONED%" (
    del /Q "%RELEASE_PACKAGE_VERSIONED%"
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%CD%\%RELEASE_STAGE_DIR%\*' -DestinationPath '%CD%\%RELEASE_PACKAGE_VERSIONED%' -CompressionLevel Optimal -Force"
if errorlevel 1 (
    echo %C_RED%[ERROR] Release packaging failed!%C_RESET%
    call :maybe_pause
    exit /b 1
)
copy /Y "%RELEASE_PACKAGE_VERSIONED%" "%RELEASE_PACKAGE%" >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$files = @('%CD%\%RELEASE_PACKAGE_VERSIONED%', '%CD%\%RELEASE_PACKAGE%'); $lines = foreach ($file in $files) { $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant(); $hash + '  ' + [IO.Path]::GetFileName($file) }; [IO.File]::WriteAllLines('%CD%\%RELEASE_CHECKSUMS%', $lines, [Text.Encoding]::ASCII)"
if errorlevel 1 (
    echo %C_RED%[ERROR] Failed to generate release checksums!%C_RESET%
    call :maybe_pause
    exit /b 1
)
echo   %C_GREEN%+%C_RESET% HanabiDownloadManagerX_%APP_VERSION%_windows_x64.zip
echo   %C_GREEN%+%C_RESET% HanabiDownloadManagerX_Release_Latest.zip
echo   %C_GREEN%+%C_RESET% SHA256SUMS.txt

echo.
echo %C_YELLOW%========================================%C_RESET%
echo %C_YELLOW%  Build Complete!%C_RESET%
echo %C_YELLOW%========================================%C_RESET%
echo.
echo Output: %OUTPUT_DIR%
echo Assets: %ASSETS_DIR%
echo Package: %RELEASE_PACKAGE%
echo Versioned: %RELEASE_PACKAGE_VERSIONED%
echo Checksums: %RELEASE_CHECKSUMS%
echo.

call :maybe_pause
exit /b 0

:maybe_pause
if "%NO_PAUSE%"=="0" pause
exit /b 0
