"""
Hanabi Download Manager X
主程序入口

Version: 2.0.0[A]
Developer: <ZZBuAoYe>
"""

import sys
import os
from pathlib import Path

# 添加项目根目录到Python路径
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

import flet as ft
from src.hdm_x.core.managers.app_manager import AppManager


def main(page: ft.Page):
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
                            color=ft.Colors.OUTLINE
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
    print("启动 Hanabi Download Manager X")
    ft.app(target=main)