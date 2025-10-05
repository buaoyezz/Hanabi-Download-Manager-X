#!/usr/bin/env python3
"""
Hanabi Download Manager X
Version: 1.0.0[X]
Developer: ZZBUAOYE
"""

import sys
import os
from pathlib import Path

# 确保项目根目录在Python路径中
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

try:
    import flet as ft
    from src.hdm_x.core.managers.app_manager import AppManager
    from src.hdm_x.utils.logger import logger
    
    def main(page: ft.Page):
        # 设置窗口图标
        logo_path = Path("src/hdm_x/assets/resources/logo/logo.ico").resolve()
        page.window_icon = str(logo_path)
        
        page.theme = ft.Theme(
            scrollbar_theme=ft.ScrollbarTheme(
                thumb_visibility=False,
                track_visibility=False,
                thickness=0
            )
        )
        try:
            # 初始化应用程序管理器
            app_manager = AppManager()
            
            # 初始化应用程序
            main_content = app_manager.initialize_app(page)
            page.add(main_content)
            
            # 设置窗口关闭事件处理
            def on_window_close(e):
                app_manager.cleanup()
            
            page.on_window_event = on_window_close
            
        except Exception as e:
            print(f"应用程序启动失败: {e}")
            # 显示错误信息
            page.add(
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.Icon(ft.Icons.ERROR, size=64, color=ft.Colors.RED),
                            ft.Text(
                                "应用程序启动失败",
                                size=24,
                                weight=ft.FontWeight.BOLD,
                                color=ft.Colors.RED
                            ),
                            ft.Text(
                                str(e),
                                size=14,
                                color=ft.Colors.ON_SURFACE_VARIANT
                            )
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=16
                    ),
                    alignment=ft.alignment.center,
                    expand=True
                )
            )

    if __name__ == "__main__":
        print("=" * 60)
        print("Hanabi Download Manager X")
        print("Redefining the download experience, where efficiency meets elegance")
        print("1.0.0[X]")
        print("Powered By NextSpeedForce-X")
        print("=" * 60)
        
        ft.app(target=main)

except ImportError as e:
    print(f"导入错误: {e}")
    print("请确保已安装所有依赖: pip install -r requirements.txt")
    sys.exit(1)
except Exception as e:
    print(f"启动失败: {e}")
    sys.exit(1)