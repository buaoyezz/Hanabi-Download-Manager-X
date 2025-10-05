"""
顶部工具栏组件
"""

import flet as ft
import threading
import time
from ...utils.logger import logger
from .systemTrayManager import SystemTrayManager


class TopBar:
    def __init__(self, page: ft.Page, theme_manager, main_window):
        self.page = page
        self.theme_manager = theme_manager
        self.main_window = main_window
        self.data_manager = None
        self.dialog_open = False
        self.last_click_time = 0
        self.tray_manager = SystemTrayManager(page, main_window)
        self.tray_manager.create_tray_icon()
        self.side_bar = None  # 侧边栏引用
        self.menu_button = None  # 菜单按钮引用
        
    def on_theme_toggle(self, e):
        """主题切换事件处理"""
        self.theme_manager.toggle_theme()
        # 更新主题图标
        e.control.icon = self.theme_manager.get_current_theme_icon()
        self.page.update()
        
    def on_new_download(self, e):
        """新建下载事件处理"""
        import time
        current_time = time.time()
        
        # 防抖：500ms内只允许一次点击
        if current_time - self.last_click_time < 0.5:
            return
        
        self.last_click_time = current_time
        
        if self.dialog_open:
            return
        
        logger.info("打开新建下载对话框")
        self.show_new_download_dialog()
    
    def show_new_download_dialog(self):
        """显示新建下载对话框"""
        if self.dialog_open:
            return
        
        self.dialog_open = True
        
        # 创建输入字段
        url_field = ft.TextField(
            label="下载链接",
            hint_text="请输入要下载的文件链接",
            width=350,
            autofocus=True
        )
        
        filename_field = ft.TextField(
            label="文件名（可选）",
            hint_text="留空将自动从链接中提取文件名",
            width=350
        )
        
        def on_dialog_result(e):
            """处理对话框结果"""
            try:
                if e.control.text == "下载":
                    url = url_field.value.strip() if url_field.value else ""
                    filename = filename_field.value.strip() if filename_field.value else ""
                    
                    if not url:
                        self.show_error_message("请输入下载链接")
                        self.page.close(dialog)
                        self.dialog_open = False
                        return
                    
                    if not self.is_valid_url(url):
                        self.show_error_message("请输入有效的URL")
                        self.page.close(dialog)
                        self.dialog_open = False
                        return
                    
                    # 添加下载任务
                    self.add_download_task(url, filename)
                
            except Exception as ex:
                logger.error(f"处理对话框结果时出错: {ex}")
                self.show_error_message(f"操作失败: {str(ex)}")
            finally:
                # 关闭对话框
                self.page.close(dialog)
                self.dialog_open = False
        
        # 创建对话框
        dialog = ft.AlertDialog(
            modal=True,
            title=ft.Text("新建下载任务"),
            content=ft.Column(
                controls=[
                    url_field,
                    filename_field,
                ],
                spacing=16,
                tight=True
            ),
            actions=[
                ft.TextButton("取消", on_click=on_dialog_result),
                ft.ElevatedButton("下载", on_click=on_dialog_result),
            ],
            actions_alignment=ft.MainAxisAlignment.END,
            on_dismiss=lambda e: setattr(self, 'dialog_open', False)
        )
        
        # 使用官方推荐的方式显示对话框
        self.page.open(dialog)
    
    def is_valid_url(self, url: str) -> bool:
        """验证URL是否有效"""
        try:
            from urllib.parse import urlparse
            result = urlparse(url)
            return all([result.scheme, result.netloc])
        except Exception:
            return False
    
    def add_download_task(self, url: str, filename: str = ""):
        """添加下载任务"""
        try:
            if not self.data_manager:
                # 尝试从主窗口获取数据管理器
                if hasattr(self.main_window, 'download_area') and hasattr(self.main_window.download_area, 'data_manager'):
                    self.data_manager = self.main_window.download_area.data_manager
                else:
                    logger.error("无法获取数据管理器")
                    self.show_error_message("系统错误：无法添加下载任务")
                    return
            
            # 创建下载数据
            import time
            import secrets
            
            download_data = {
                "id": f"dl_{secrets.token_hex(4)}",
                "fileName": filename or self.extract_filename_from_url(url),
                "url": url,
                "progress": 0.0,
                "speed": "准备中...",
                "size": "未知",
                "downloaded": "0 B",
                "status": "pending",  # 使用与下载核心一致的状态
                "timeRemaining": "",
                "fileType": self.get_file_type_from_url(url),
                "createdTime": time.strftime("%Y-%m-%dT%H:%M:%SZ")
            }
            
            # 添加到数据管理器
            success = self.data_manager.add_download(download_data)
            
            if success:
                logger.info(f"下载任务添加成功: {download_data['fileName']}")
                self.show_success_message(f"下载任务已添加: {download_data['fileName']}")
                
                # 立即刷新下载列表以显示新任务
                if hasattr(self.main_window, 'download_area'):
                    self.main_window.download_area.refresh_downloads()
                    
                # 短暂延迟后再次刷新，确保状态同步
                def delayed_refresh():
                    import time
                    time.sleep(0.5)  # 等待500ms让下载核心启动
                    if hasattr(self.main_window, 'download_area'):
                        self.main_window.download_area.refresh_downloads()
                
                import threading
                threading.Thread(target=delayed_refresh, daemon=True).start()
            else:
                logger.error("下载任务添加失败")
                self.show_error_message("添加下载任务失败")
                
        except Exception as e:
            logger.error(f"添加下载任务时出错: {e}")
            self.show_error_message(f"添加下载任务失败: {str(e)}")
    
    def extract_filename_from_url(self, url: str) -> str:
        """从URL提取文件名"""
        try:
            from urllib.parse import urlparse, unquote
            parsed = urlparse(url)
            filename = unquote(parsed.path.split('/')[-1])
            
            if filename and '.' in filename:
                return filename
            
            # 如果无法提取，生成默认文件名
            import time
            return f"download_{int(time.time())}"
            
        except Exception:
            import time
            return f"download_{int(time.time())}"
    
    def get_file_type_from_url(self, url: str) -> str:
        """从URL获取文件类型"""
        try:
            filename = self.extract_filename_from_url(url)
            ext = filename.lower().split('.')[-1] if '.' in filename else ''
            
            type_mapping = {
                'video': ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v'],
                'audio': ['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a'],
                'image': ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'svg', 'webp'],
                'document': ['pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx'],
                'archive': ['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz']
            }
            
            for file_type, extensions in type_mapping.items():
                if ext in extensions:
                    return file_type
            
            return 'other'
        except Exception:
            return 'other'
    
    def show_success_message(self, message: str):
        """显示成功消息"""
        snack_bar = ft.SnackBar(
            content=ft.Text(message),
            bgcolor=ft.Colors.GREEN,
            duration=3000
        )
        self.page.snack_bar = snack_bar
        snack_bar.open = True
        self.page.update()
    
    def show_error_message(self, message: str):
        """显示错误消息"""
        snack_bar = ft.SnackBar(
            content=ft.Text(message),
            bgcolor=ft.Colors.RED,
            duration=3000
        )
        self.page.snack_bar = snack_bar
        snack_bar.open = True
        self.page.update()
        
    def on_settings(self, e):
        """设置事件处理"""
        self.main_window.show_settings()
        
    def on_minimize_to_tray(self, e):
        """最小化到托盘"""
        self.tray_manager.hide_window()
        
    def on_maximize(self, e):
        """最大化/还原窗口"""
        if hasattr(self.page, '_is_maximized') and self.page._is_maximized:
            self.page.window.maximized = False
            self.page._is_maximized = False
            e.control.icon = ft.Icons.CROP_SQUARE
        else:
            self.page.window.maximized = True
            self.page._is_maximized = True
            e.control.icon = ft.Icons.FILTER_NONE
        self.page.update()
        
    def on_close(self, e):
        """关闭窗口"""
        self.tray_manager.cleanup()
        self.page.window.close()
        
    def cleanup(self):
        """清理资源"""
        if hasattr(self, 'tray_manager'):
            self.tray_manager.cleanup()
    
    def on_toggle_sidebar(self, e):
        """切换侧边栏显示"""
        if self.side_bar:
            self.side_bar.toggle_sidebar()
    
    def update_menu_button_visibility(self, window_width):
        """更新菜单按钮的可见性"""
        if self.menu_button:
            should_show = window_width < 800
            self.menu_button.visible = should_show
            self.page.update()
        
    def build(self):
        """构建顶部工具栏"""
        # 创建菜单按钮
        self.menu_button = ft.IconButton(
            icon=ft.Icons.MENU,
            tooltip="切换侧边栏",
            on_click=self.on_toggle_sidebar,
            visible=False,  # 初始隐藏
            style=ft.ButtonStyle(
                shape=ft.RoundedRectangleBorder(radius=8)
            )
        )
        
        # 工具按钮组（不可拖拽区域）
        button_group = ft.Row(
            controls=[
                # 菜单按钮（小屏幕时显示）
                self.menu_button,
                ft.IconButton(
                    icon=ft.Icons.ADD,
                    tooltip="新建下载",
                    on_click=self.on_new_download,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=8)
                    )
                ),
                ft.IconButton(
                    icon=ft.Icons.PAUSE,
                    tooltip="暂停所有",
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=8)
                    )
                ),
                ft.IconButton(
                    icon=ft.Icons.PLAY_ARROW,
                    tooltip="开始所有",
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=8)
                    )
                ),
                ft.VerticalDivider(width=1),
                ft.IconButton(
                    icon=self.theme_manager.get_current_theme_icon(),
                    tooltip="切换主题",
                    on_click=self.on_theme_toggle,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=8)
                    )
                ),
                ft.IconButton(
                    icon=ft.Icons.SETTINGS,
                    tooltip="设置",
                    on_click=self.on_settings,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=8)
                    )
                ),
                ft.IconButton(
                    icon=ft.Icons.KEYBOARD_ARROW_DOWN,
                    tooltip="最小化到托盘",
                    on_click=self.on_minimize_to_tray,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=8)
                    )
                ),
                ft.VerticalDivider(width=1),
                ft.IconButton(
                    icon=ft.Icons.CROP_SQUARE,
                    tooltip="最大化/还原",
                    on_click=self.on_maximize,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=8)
                    )
                ),
                ft.IconButton(
                    icon=ft.Icons.CLOSE,
                    tooltip="关闭",
                    on_click=self.on_close,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=8),
                        overlay_color={
                            ft.ControlState.HOVERED: ft.Colors.RED_400
                        },
                        color={
                            ft.ControlState.HOVERED: ft.Colors.WHITE
                        }
                    )
                )
            ],
            spacing=4
        )
        
        return ft.WindowDragArea(
            content=ft.Container(
                content=ft.Row(
                    controls=[
                        # 应用标题和图标区域
                        ft.Row(
                            controls=[
                                ft.Image(
                                    src="src/hdm_x/assets/resources/logo/logo.png",
                                    width=38,
                                    height=38,
                                    fit=ft.ImageFit.CONTAIN
                                ),
                                ft.Text(
                                    "Hanabi Download Manager X",
                                    size=18,
                                    weight=ft.FontWeight.W_500
                                )
                            ],
                            spacing=8
                        ),
                        
                        # 工具按钮组
                        button_group
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                ),
                padding=ft.padding.symmetric(horizontal=16, vertical=12),
                bgcolor=ft.Colors.SURFACE,
                border=ft.border.only(
                    bottom=ft.BorderSide(1, ft.Colors.OUTLINE_VARIANT)
                )
            ),
            maximizable=True
        )