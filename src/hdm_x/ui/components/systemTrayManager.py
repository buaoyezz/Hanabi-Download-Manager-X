import pystray
from PIL import Image, ImageDraw
import threading
import time
from ...utils.logger import logger


class SystemTrayManager:
    def __init__(self, page, main_window):
        self.page = page
        self.main_window = main_window
        self.tray_icon = None
        self.is_hidden = False
        self.running = False
        
    def create_icon_image(self):
        width = 64
        height = 64
        image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        
        draw.ellipse([16, 16, 48, 48], fill=(33, 150, 243, 255))
        draw.polygon([(32, 24), (28, 32), (36, 32)], fill=(255, 255, 255, 255))
        draw.rectangle([30, 32, 34, 40], fill=(255, 255, 255, 255))
        
        return image
        
    def create_tray_icon(self):
        try:
            if self.tray_icon or self.running:
                return
                
            icon_image = self.create_icon_image()
            
            menu = pystray.Menu(
                pystray.MenuItem("显示窗口", self.show_window, default=True),
                pystray.MenuItem("隐藏窗口", self.hide_window),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("退出程序", self.exit_app)
            )
            
            self.tray_icon = pystray.Icon(
                "HDM_X",
                icon_image,
                "Hanabi Download Manager X",
                menu
            )
            
            def run_tray():
                self.running = True
                self.tray_icon.run()
                
            threading.Thread(target=run_tray, daemon=True).start()
            time.sleep(0.1)
            logger.info("系统托盘图标创建成功")
            
        except Exception as e:
            logger.error(f"创建系统托盘图标失败: {e}")
    
    def show_window(self, icon=None, item=None):
        try:
            def show():
                self.page.window.visible = True
                self.page.window.minimized = False
                self.page.window.to_front = True
                self.is_hidden = False
                self.page.update()
                
            threading.Thread(target=show, daemon=True).start()
            logger.info("窗口已从托盘恢复")
        except Exception as ex:
            logger.error(f"恢复窗口失败: {ex}")
    
    def hide_window(self, icon=None, item=None):
        try:
            def hide():
                self.page.window.visible = False
                self.is_hidden = True
                self.page.update()
                
            threading.Thread(target=hide, daemon=True).start()
            logger.info("窗口已隐藏到托盘")
        except Exception as ex:
            logger.error(f"隐藏窗口失败: {ex}")
    
    def exit_app(self, icon=None, item=None):
        try:
            self.cleanup()
            def close():
                self.page.window.close()
            threading.Thread(target=close, daemon=True).start()
        except Exception as ex:
            logger.error(f"退出应用程序失败: {ex}")
    
    def cleanup(self):
        try:
            if self.tray_icon and self.running:
                self.tray_icon.stop()
                self.running = False
                self.tray_icon = None
                logger.info("系统托盘资源已清理")
        except Exception as e:
            logger.error(f"清理托盘资源失败: {e}")