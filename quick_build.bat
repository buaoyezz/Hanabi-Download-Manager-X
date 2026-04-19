@echo off
chcp 65001 >nul
echo 快速编译中...

echo 同步多语言中...
call dart run tool\sync_l10n.dart
if errorlevel 1 (
  echo 多语言同步失败！
  pause
  exit /b 1
)

:: Flutter 编译（独立 popup 已内置到 Windows runner）
flutter build windows --release

echo.
echo 编译完成！
echo 输出目录: build\windows\x64\runner\Release\
pause
