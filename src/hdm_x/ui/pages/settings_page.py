"""
设置页面组件 - 提供字体、样式和引擎自定义功能
"""

import flet as ft


class SettingsPage:
    def __init__(self, page: ft.Page, font_manager, theme_manager, data_manager=None, config_manager=None, sidebar=None):
        self.page = page
        self.font_manager = font_manager
        self.theme_manager = theme_manager
        self.data_manager = data_manager
        self.config_manager = config_manager
        self.sidebar = sidebar
        self.is_visible = False
        self._container = None
        self.close_callback = None
        self.current_tab = 0
        
    def on_font_family_change(self, e):
        """字体族改变事件"""
        print(f"🎨 设置页面：用户选择字体 {e.control.value}")  # 调试信息
        self.font_manager.set_font_family(e.control.value)
        
    def on_theme_toggle(self, e):
        """主题切换事件"""
        self.theme_manager.toggle_theme()
    
    def on_sidebar_remember_toggle(self, e):
        """侧边栏记忆状态切换"""
        if self.sidebar:
            self.sidebar.update_sidebar_config(remember_state=e.control.value)
    
    def on_sidebar_default_expanded_toggle(self, e):
        """侧边栏默认展开状态切换"""
        if self.sidebar:
            self.sidebar.update_sidebar_config(default_expanded=e.control.value)
    
    def on_tab_change(self, e):
        """Tab切换事件"""
        self.current_tab = e.control.selected_index
        
    def build(self):
        """构建设置页面"""
        # 创建Tab内容
        tabs = [
            ft.Tab(
                text="外观设置",
                icon=ft.Icons.PALETTE,
                content=ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.Card(
                                content=ft.Container(
                                    content=ft.Column(
                                        controls=[
                                            ft.Row(
                                                controls=[
                                                    ft.Icon(ft.Icons.PALETTE, size=24),
                                                    ft.Text(
                                                        "外观设置",
                                                        size=18,
                                                        weight=ft.FontWeight.BOLD
                                                    )
                                                ],
                                                spacing=8
                                            ),
                                            
                                            ft.Divider(),
                                            
                                            # 主题切换
                                            ft.Row(
                                                controls=[
                                                    ft.Text("深色模式", size=14),
                                                    ft.Switch(
                                                        value=self.theme_manager.is_dark_mode,
                                                        on_change=self.on_theme_toggle
                                                    )
                                                ],
                                                alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                                            ),
                                            
                                            ft.Divider(),
                                            
                                            # 字体族选择
                                            ft.Column(
                                                controls=[
                                                    ft.Text("字体", size=14, weight=ft.FontWeight.W_500),
                                                    ft.Dropdown(
                                                        value=self.font_manager.get_font_family(),
                                                        options=[
                                                            ft.dropdown.Option(font)
                                                            for font in self.font_manager.get_available_fonts()
                                                        ],
                                                        on_change=self.on_font_family_change,
                                                        width=200
                                                    )
                                                ],
                                                spacing=8
                                            )
                                        ],
                                        spacing=16
                                    ),
                                    padding=ft.padding.all(20)
                                ),
                                elevation=2
                            )
                        ],
                        scroll=ft.ScrollMode.AUTO
                    ),
                    padding=ft.padding.all(20)
                )
            ),
            ft.Tab(
                text="UI设置",
                icon=ft.Icons.DASHBOARD_CUSTOMIZE,
                content=ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.Card(
                                content=ft.Container(
                                    content=ft.Column(
                                        controls=[
                                            ft.Row(
                                                controls=[
                                                    ft.Icon(ft.Icons.DASHBOARD_CUSTOMIZE, size=24),
                                                    ft.Text(
                                                        "UI设置",
                                                        size=18,
                                                        weight=ft.FontWeight.BOLD
                                                    )
                                                ],
                                                spacing=8
                                            ),
                                            
                                            ft.Divider(),
                                            
                                            # 侧边栏设置
                                            ft.Text("侧边栏设置", size=16, weight=ft.FontWeight.W_500),
                                            
                                            # 记忆侧边栏状态
                                            ft.Row(
                                                controls=[
                                                    ft.Column(
                                                        controls=[
                                                            ft.Text("记忆侧边栏状态", size=14),
                                                            ft.Text("记住侧边栏的折叠/展开状态", size=12, color=ft.Colors.OUTLINE)
                                                        ],
                                                        spacing=2
                                                    ),
                                                    ft.Switch(
                                                        value=self.sidebar.remember_state if self.sidebar else True,
                                                        on_change=self.on_sidebar_remember_toggle
                                                    )
                                                ],
                                                alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                                            ),
                                            
                                            ft.Divider(),
                                            
                                            # 默认展开模式
                                            ft.Row(
                                                controls=[
                                                    ft.Column(
                                                        controls=[
                                                            ft.Text("默认展开模式", size=14),
                                                            ft.Text("应用启动时侧边栏是否默认展开", size=12, color=ft.Colors.OUTLINE)
                                                        ],
                                                        spacing=2
                                                    ),
                                                    ft.Switch(
                                                        value=self.sidebar.default_expanded if self.sidebar else True,
                                                        on_change=self.on_sidebar_default_expanded_toggle
                                                    )
                                                ],
                                                alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                                            )
                                        ],
                                        spacing=16
                                    ),
                                    padding=ft.padding.all(20)
                                ),
                                elevation=2
                            )
                        ],
                        scroll=ft.ScrollMode.AUTO
                    ),
                    padding=ft.padding.all(20)
                )
            )
        ]
        
        self._container = ft.Container(
            content=ft.Column(
                controls=[
                    # 页面标题
                    ft.Container(
                        content=ft.Row(
                            controls=[
                                ft.WindowDragArea(
                                    content=ft.Container(
                                        content=ft.Text(
                                            "设置",
                                            size=24,
                                            weight=ft.FontWeight.BOLD
                                        ),
                                        expand=True
                                    ),
                                    expand=True
                                ),
                                ft.IconButton(
                                    icon=ft.Icons.CLOSE,
                                    on_click=lambda e: self.hide()
                                )
                            ],
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                        ),
                        padding=ft.padding.all(20),
                        border=ft.border.only(
                            bottom=ft.BorderSide(1, ft.Colors.ON_SURFACE_VARIANT)
                        )
                    ),
                    
                    # Tabs内容
                    ft.Container(
                        content=ft.Tabs(
                            selected_index=self.current_tab,
                            on_change=self.on_tab_change,
                            tabs=tabs,
                            expand=True
                        ),
                        expand=True
                    )
                ],
                spacing=0
            ),
            visible=self.is_visible,
            expand=True,
            bgcolor=ft.Colors.SURFACE
        )
        
        return self._container
        
    def show(self):
        """显示设置页面"""
        self.is_visible = True
        # 更新容器的visible属性
        if self._container:
            self._container.visible = True
        self.page.update()
        
    def hide(self):
        """隐藏设置页面"""
        self.is_visible = False
        # 更新容器的visible属性
        if self._container:
            self._container.visible = False
        self.page.update()
        
    def set_close_callback(self, callback):
        """设置关闭回调函数"""
        self.close_callback = callback
