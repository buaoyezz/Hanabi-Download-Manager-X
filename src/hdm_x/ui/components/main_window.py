"""
主窗口组件 - 包含整个应用的主要布局
"""

import flet as ft
from .top_bar import TopBar
from .side_bar import SideBar
from .download_area import DownloadArea
from .status_bar import StatusBar
from ..pages.settings_page import SettingsPage
from ..pages.aboutPage import AboutPage


class MainWindow:
    def __init__(self, page: ft.Page, theme_manager, font_manager, data_manager=None, config_manager=None):
        self.page = page
        self.theme_manager = theme_manager
        self.font_manager = font_manager
        self.data_manager = data_manager
        self.config_manager = config_manager
        self.current_view = "main"  # main, settings
        
        # 初始化子组件
        self.top_bar = TopBar(page, theme_manager, self)
        self.side_bar = SideBar(page, font_manager, config_manager)
        self.download_area = DownloadArea(page, font_manager, self.side_bar, data_manager)
        self.status_bar = StatusBar(page, font_manager, data_manager)
        self.settings_page = SettingsPage(page, font_manager, theme_manager, data_manager, config_manager, self.side_bar)
        self.about_page = AboutPage(page)
        
        # 设置顶部栏的数据管理器引用
        self.top_bar.data_manager = self.data_manager
        
        # 设置状态栏的数据管理器引用
        if self.download_area.data_manager:
            self.status_bar.set_data_manager(self.download_area.data_manager)
        
        # 设置状态栏的下载管理器引用（用于NSF-X状态检测）
        if hasattr(self.download_area, 'data_manager') and hasattr(self.download_area.data_manager, 'download_core'):
            self.status_bar.download_manager = self.download_area.data_manager.download_core
        
        # 设置侧边栏的回调
        self.side_bar.settings_callback = self.show_settings
        self.side_bar.about_callback = self.show_about
        
        # 设置侧边栏引用给顶部栏（用于切换按钮）
        self.top_bar.side_bar = self.side_bar
        
        # 设置页面大小变更回调
        self.page.on_resize = self.on_page_resize
    
    def show_settings(self):
        """显示设置页面"""
        self.current_view = "settings"
        self.settings_page.show()
        self.page.update()
        
    def show_about(self):
        """显示关于页面"""
        self.current_view = "about"
        self.about_page.show()
        self.page.update()
        
    def show_main(self):
        """显示主界面"""
        self.current_view = "main"
        self.settings_page.hide()
        self.about_page.hide()
        self.page.update()
    
    def on_page_resize(self, e):
        """页面大小变更处理"""
        if hasattr(e, 'width') and e.width:
            # 通知侧边栏更新布局
            self.side_bar.check_and_update_layout(e.width)
            
            # 通知顶部栏更新（用于显示/隐藏菜单按钮）
            if hasattr(self.top_bar, 'update_menu_button_visibility'):
                self.top_bar.update_menu_button_visibility(e.width)
    
    def cleanup(self):
        """清理资源"""
        if hasattr(self.status_bar, 'cleanup'):
            self.status_bar.cleanup()
        if hasattr(self.download_area, 'cleanup'):
            self.download_area.cleanup()
        
    def build(self):
        """构建主窗口布局"""
        main_content = ft.Column(
            controls=[
                # 顶部工具栏
                self.top_bar.build(),
                
                # 主要内容区域
                ft.Container(
                    content=ft.Row(
                        controls=[
                            # 侧边栏 - 确保占据全高度
                            ft.Container(
                                content=self.side_bar.build(),
                                height=None,  # 自适应高度
                                expand_loose=False  # 不在水平方向扩展
                            ),
                            
                            # 下载区域
                            ft.Container(
                                content=self.download_area.build(),
                                expand=True,
                                padding=ft.padding.all(16)
                            )
                        ],
                        expand=True,
                        spacing=0,
                        alignment=ft.MainAxisAlignment.START,
                        vertical_alignment=ft.CrossAxisAlignment.STRETCH  # 垂直拉伸
                    ),
                    expand=True
                ),
                
                # 底部状态栏
                self.status_bar.build()
            ],
            spacing=0,
            expand=True
        )
        
        return ft.Container(
            content=ft.Stack(
                controls=[
                    main_content,
                    self.settings_page.build(),
                    self.about_page.build()
                ]
            ),
            expand=True
        )