"""
AppManager
"""

import flet as ft
import threading
import asyncio
from ...ui.components.main_window import MainWindow
from .theme_manager import ThemeManager
from .font_manager import FontManager
from .config_manager import ConfigManager
from .websocket_server import WebSocketServer
from .data_manager import DataManager
from ...utils.logger import logger
from pathlib import Path
from ..nsfXCore.bridge import NsfXCoreBridge


class AppManager:
    
    def __init__(self):
        self.theme_manager = None
        self.font_manager = None
        self.config_manager = None
        self.websocket_server = None
        self.data_manager = None
        self.main_window = None
        
    def initialize_app(self, page: ft.Page):
        """初始化应用程序"""
        # 初始化配置管理器
        self.config_manager = ConfigManager()
        config = self.config_manager.load_config()
        
        # 初始化核心管理器
        self.theme_manager = ThemeManager(page)
        self.font_manager = FontManager(page)
        
        # 初始化数据管理器（直连 Python NSF 内核）
        self.data_manager = DataManager()

        # 后台初始化并注入 NsfXCoreBridge
        def init_core_in_background():
            try:
                from ...utils.pathUtils import getDefaultDownloadPath
                download_dir = self.data_manager.get_settings().get('download_dir', getDefaultDownloadPath())
                bridge = NsfXCoreBridge(download_dir)
                self.data_manager.set_download_core(bridge)
                self.data_manager.setup_download_callbacks()
                logger.info("✅ NSF-X 下载核心已就绪")
            except Exception as e:
                logger.error(f"下载核心初始化异常: {e}")

        threading.Thread(target=init_core_in_background, daemon=True).start()
        
        # 初始化WebSocket服务器
        self.websocket_server = WebSocketServer()
        
        async def ws_add_download_wrapper(download_data: dict):
            try:
                import secrets
                import time
                from urllib.parse import urlparse, unquote

                url = download_data.get("url", "")
                if not url:
                    raise Exception("missing url")

                if not download_data.get("id"):
                    download_data["id"] = f"dl_{secrets.token_hex(4)}"

                if not download_data.get("fileName"):
                    try:
                        parsed = urlparse(url)
                        name = unquote(parsed.path.split("/")[-1])
                        if not name or "." not in name:
                            name = f"download_{int(time.time())}"
                    except Exception:
                        name = f"download_{int(time.time())}"
                    download_data["fileName"] = name

                download_data.setdefault("progress", 0.0)
                download_data.setdefault("speed", "等待中")
                download_data.setdefault("size", "未知")
                download_data.setdefault("downloaded", "0 B")
                download_data.setdefault("status", "downloading")
                download_data.setdefault("timeRemaining", "")
                download_data.setdefault("fileType", "other")
                download_data.setdefault("createdTime", time.strftime("%Y-%m-%dT%H:%M:%SZ"))

                ok = self.data_manager.add_download(download_data)
                if ok:
                    return {"id": download_data["id"]}
                else:
                    raise Exception("add failed")
            except Exception as e:
                raise e

        async def ws_batch_download_wrapper(urls, referer=None):
            results = []
            for url in urls:
                try:
                    r = await ws_add_download_wrapper({"url": url, "referer": referer or ""})
                    results.append({"url": url, "success": True, "id": r.get("id", "")})
                except Exception as e:
                    results.append({"url": url, "success": False, "error": str(e)})
            return results
        
        self.websocket_server.set_download_callback(ws_add_download_wrapper)
        self.websocket_server.set_batch_download_callback(ws_batch_download_wrapper)
        self.start_websocket_server()
        
        # 初始化主窗口
        self.main_window = MainWindow(page, self.theme_manager, self.font_manager, self.data_manager, self.config_manager)
        
        # 设置页面属性
        self.setup_page_properties(page, config)
        self.theme_manager.apply_theme()
        
        # 设置响应式布局
        self.setup_responsive_layout(page)
        
        # 注册UI刷新回调（在主窗口构建完成后）
        if hasattr(self.main_window, 'download_area') and hasattr(self.main_window.download_area, 'refresh_downloads'):
            self.data_manager.add_ui_refresh_callback(self.main_window.download_area.refresh_downloads)
            logger.info("UI刷新回调已注册")
        
        return self.main_window.build()
    
    def setup_page_properties(self, page: ft.Page, config: dict):
        """设置页面属性"""
        page.title = config.get('app_title', 'Hanabi Download Manager X')
        page.window_width = config.get('window_width', 1200)
        page.window_height = config.get('window_height', 800)
        page.window_min_width = config.get('window_min_width', 800)
        page.window_min_height = config.get('window_min_height', 600)
        page.window_frameless = True
        page.window.title_bar_hidden = True
        page.window.title_bar_buttons_hidden = True
        page.padding = 0
        page.spacing = 0
    
    def setup_responsive_layout(self, page: ft.Page):
        """设置响应式布局"""
        def on_resize(e):
            """窗口大小改变时的处理"""
            page.update()
        
        page.on_resize = on_resize
    
    def start_websocket_server(self):
        """启动WebSocket服务器"""
        import asyncio
        
        def run_server():
            try:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                loop.run_until_complete(self.websocket_server.start())
                loop.run_forever()
            except Exception as e:
                print(f"WebSocket服务器启动失败: {e}")
        
        server_thread = threading.Thread(target=run_server, daemon=True)
        server_thread.start()
    
    
    def cleanup(self):
        """清理资源"""
        if self.main_window:
            self.main_window.cleanup()
        if self.websocket_server:
            self.websocket_server.stop()
        if self.data_manager:
            try:
                self.data_manager.cleanup()
            except Exception:
                pass
