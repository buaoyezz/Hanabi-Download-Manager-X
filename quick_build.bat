@echo off
chcp 65001 >nul
echo 快速编译中...

:: Tauri 弹窗编译
echo 编译 Hanabi Popup...
call build_popup.bat --build-only --no-pause

:: Flutter 编译
flutter build windows --release

:: 复制文件
copy hanabi-popup\src-tauri\target\release\hanabi-popup.exe build\windows\x64\runner\Release\ >nul

echo.
echo 编译完成！
echo 输出目录: build\windows\x64\runner\Release\
pause
