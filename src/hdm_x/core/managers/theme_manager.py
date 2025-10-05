"""
ThemeManager

"""

import flet as ft


class ThemeManager:
    
    def __init__(self, page: ft.Page):
        self.page = page
        self.is_dark_mode = True  # 默认暗色模式
        
    def toggle_theme(self):
        """切换主题模式"""
        self.is_dark_mode = not self.is_dark_mode
        self.apply_theme()
        
    def apply_theme(self):
        """应用当前主题"""
        if self.is_dark_mode:
            self.page.theme_mode = ft.ThemeMode.DARK
            self.page.theme = ft.Theme(
                color_scheme_seed=ft.Colors.BLUE,
                use_material3=True
            )
        else:
            self.page.theme_mode = ft.ThemeMode.LIGHT
            self.page.theme = ft.Theme(
                color_scheme_seed=ft.Colors.BLUE,
                use_material3=True
            )
        self.page.update()
        
    def get_current_theme_icon(self):
        """获取当前主题对应的图标"""
        return ft.Icons.DARK_MODE if self.is_dark_mode else ft.Icons.LIGHT_MODE