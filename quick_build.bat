@echo off
chcp 65001 >nul
echo 快速编译中...

:: Python 编译
cd python
python -m nuitka --standalone --onefile --windows-console-mode=disable --enable-plugin=anti-bloat --nofollow-import-to=unittest --nofollow-import-to=pytest --nofollow-import-to=test --include-package=aiohttp --include-package=aiofiles --include-package-data=soda_speed_force_kernel --output-dir=../build/python --output-filename=soda_bridge_server.exe soda_bridge_server.py
cd ..

:: Tauri 弹窗编译
echo 编译 Hanabi Popup...
cd hanabi-popup
call npm run tauri:build
cd ..

:: Flutter 编译
flutter build windows --release

:: 复制文件
copy build\python\soda_bridge_server.exe build\windows\x64\runner\Release\ >nul
copy hanabi-popup\src-tauri\target\release\hanabi-popup.exe build\windows\x64\runner\Release\ >nul

echo.
echo 编译完成！
echo 输出目录: build\windows\x64\runner\Release\
pause
