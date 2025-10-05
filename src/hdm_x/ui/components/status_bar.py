"""
状态栏组件 - 显示全局状态信息
"""

import flet as ft
import asyncio
import time
from typing import Optional


class StatusBar:
    def __init__(self, page: ft.Page, font_manager, data_manager=None):
        self.page = page
        self.font_manager = font_manager
        self.data_manager = data_manager
        
        # 状态文本控件引用
        self.total_tasks_text = None
        self.download_speed_text = None
        self.remaining_time_text = None
        self.connection_status_icon = None
        self.connection_status_text = None
        
        # 更新定时器
        self.update_timer = None
        
    def set_data_manager(self, data_manager):
        """设置数据管理器"""
        self.data_manager = data_manager
        self.start_update_timer()
    
    def start_update_timer(self):
        """启动状态更新定时器"""
        if self.update_timer:
            return
            
        async def update_status():
            while True:
                try:
                    await self.update_status_info()
                    await asyncio.sleep(1)  # 每秒更新一次
                except Exception as e:
                    print(f"状态栏更新错误: {e}")
                    await asyncio.sleep(5)  # 出错时等待5秒再重试
        
        try:
            loop = asyncio.get_running_loop()
            self.update_timer = loop.create_task(update_status())
        except RuntimeError:
            # 没有运行的事件循环，在新线程中运行
            import threading
            def run_async():
                asyncio.run(update_status())
            
            thread = threading.Thread(target=run_async)
            thread.daemon = True
            thread.start()
    
    async def update_status_info(self):
        """更新状态信息"""
        if not self.data_manager:
            return
        
        try:
            # 获取下载统计信息
            downloads = self.data_manager.get_downloads()
            total_tasks = len(downloads)
            
            # 计算活跃下载的统计信息
            active_downloads = [d for d in downloads if d.get('status') == 'downloading']
            total_speed = 0.0
            total_remaining_bytes = 0
            total_downloaded_bytes = 0
            total_size_bytes = 0
            
            for download in active_downloads:
                # 解析速度（从字符串转换为字节/秒）
                speed_str = download.get('speed', '0 B/s')
                speed_bytes = self._parse_speed_to_bytes(speed_str)
                total_speed += speed_bytes
                
                # 解析大小信息
                downloaded_str = download.get('downloaded', '0 B')
                size_str = download.get('size', '0 B')
                
                downloaded_bytes = self._parse_size_to_bytes(downloaded_str)
                size_bytes = self._parse_size_to_bytes(size_str)
                
                if size_bytes > 0:
                    remaining_bytes = size_bytes - downloaded_bytes
                    total_remaining_bytes += remaining_bytes
                    total_downloaded_bytes += downloaded_bytes
                    total_size_bytes += size_bytes
            
            # 计算剩余时间
            remaining_time_str = "未知"
            if total_speed > 0 and total_remaining_bytes > 0:
                remaining_seconds = int(total_remaining_bytes / total_speed)
                remaining_time_str = self._format_time(remaining_seconds)
            elif len(active_downloads) == 0:
                remaining_time_str = "无下载任务"
            
            # 格式化显示文本
            total_tasks_str = f"总下载: {total_tasks} 个任务"
            download_speed_str = f"下载速度: {self._format_speed(total_speed)}"
            remaining_time_display = f"剩余时间: {remaining_time_str}"
            
            # 更新UI控件
            if self.total_tasks_text:
                self.total_tasks_text.value = total_tasks_str
            if self.download_speed_text:
                self.download_speed_text.value = download_speed_str
            if self.remaining_time_text:
                self.remaining_time_text.value = remaining_time_display
            
            # 更新连接状态（简单的网络检测）
            connection_status = await self._check_connection_status()
            if self.connection_status_icon and self.connection_status_text:
                if connection_status:
                    self.connection_status_icon.name = ft.Icons.WIFI
                    self.connection_status_icon.color = ft.Colors.GREEN
                    self.connection_status_text.value = "已连接"
                else:
                    self.connection_status_icon.name = ft.Icons.WIFI_OFF
                    self.connection_status_icon.color = ft.Colors.RED
                    self.connection_status_text.value = "未连接"
            
            # 刷新页面
            if self.page:
                self.page.update()
                
        except Exception as e:
            print(f"更新状态信息失败: {e}")
    
    def _parse_speed_to_bytes(self, speed_str: str) -> float:
        """将速度字符串转换为字节/秒"""
        try:
            if not speed_str or speed_str in ["0 B/s", "已暂停", "已完成", "失败", "恢复中...", "暂停中...", "下载中"]:
                return 0.0
            
            # 移除 "/s" 后缀
            size_str = speed_str.replace("/s", "").strip()
            return self._parse_size_to_bytes(size_str)
        except:
            return 0.0
    
    def _parse_size_to_bytes(self, size_str: str) -> float:
        """将大小字符串转换为字节"""
        try:
            if not size_str or size_str in ["未知", "0 B"]:
                return 0.0
            
            # 分离数字和单位
            parts = size_str.strip().split()
            if len(parts) != 2:
                return 0.0
            
            value = float(parts[0])
            unit = parts[1].upper()
            
            # 转换为字节
            multipliers = {
                'B': 1,
                'KB': 1024,
                'MB': 1024 ** 2,
                'GB': 1024 ** 3,
                'TB': 1024 ** 4
            }
            
            return value * multipliers.get(unit, 1)
        except:
            return 0.0
    
    def _format_speed(self, speed_bytes: float) -> str:
        """格式化速度显示"""
        if speed_bytes == 0:
            return "0 B/s"
        
        units = ['B/s', 'KB/s', 'MB/s', 'GB/s']
        unit_index = 0
        
        while speed_bytes >= 1024 and unit_index < len(units) - 1:
            speed_bytes /= 1024
            unit_index += 1
        
        return f"{speed_bytes:.1f} {units[unit_index]}"
    
    def _format_time(self, seconds: int) -> str:
        """格式化时间显示"""
        if seconds <= 0:
            return "未知"
        
        if seconds < 60:
            return f"{seconds}秒"
        elif seconds < 3600:
            minutes = seconds // 60
            return f"{minutes}分钟"
        else:
            hours = seconds // 3600
            minutes = (seconds % 3600) // 60
            if minutes > 0:
                return f"{hours}小时{minutes}分钟"
            else:
                return f"{hours}小时"
    
    async def _check_connection_status(self) -> bool:
        """检查NSF-X引擎连接状态"""
        try:
            if hasattr(self.data_manager, 'download_core') and getattr(self.data_manager.download_core, 'is_running', False):
                return True
            if hasattr(self.data_manager, 'engine_manager') and getattr(self.data_manager, 'is_initialized', False):
                return True
            return False
        except Exception as e:
            print(f"检查NSF-X引擎状态失败: {e}")
            return False
    
    def build(self):
        """构建状态栏"""
        # 创建文本控件并保存引用
        self.total_tasks_text = self.font_manager.create_text(
            "总下载: 0 个任务",
            "small",
                            color=ft.Colors.OUTLINE
        )
        
        self.download_speed_text = self.font_manager.create_text(
            "下载速度: 0 B/s",
            "small",
            color=ft.Colors.ON_SURFACE_VARIANT
        )
        
        self.remaining_time_text = self.font_manager.create_text(
            "剩余时间: 无下载任务",
            "small",
            color=ft.Colors.ON_SURFACE_VARIANT
        )
        
        self.connection_status_icon = ft.Icon(
            ft.Icons.ERROR_OUTLINE,
            size=16,
            color=ft.Colors.ORANGE
        )
        
        self.connection_status_text = self.font_manager.create_text(
            "NSF-X 检测中...",
            "small",
            color=ft.Colors.ON_SURFACE_VARIANT
        )
        
        return ft.Container(
            content=ft.Row(
                controls=[
                    # 左侧状态信息
                    ft.Row(
                        controls=[
                            ft.Icon(
                                ft.Icons.DOWNLOAD,
                                size=16,
                                color=ft.Colors.PRIMARY
                            ),
                            self.total_tasks_text,
                            ft.VerticalDivider(width=1),
                            self.download_speed_text,
                            ft.VerticalDivider(width=1),
                            self.remaining_time_text
                        ],
                        spacing=8
                    ),
                    
                    # 右侧版本信息
                    ft.Row(
                        controls=[
                            self.font_manager.create_text(
                                "Hanabi Download Manager X",
                                "small",
                                color=ft.Colors.ON_SURFACE_VARIANT
                            ),
                            ft.VerticalDivider(width=1),
                            self.connection_status_icon,
                            self.connection_status_text
                        ],
                        spacing=8
                    )
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN
            ),
            padding=ft.padding.symmetric(horizontal=16, vertical=8),
            bgcolor=ft.Colors.SURFACE,
            border=ft.border.only(
                top=ft.BorderSide(1, ft.Colors.OUTLINE_VARIANT)
            ),
            height=40
        )
    
    def cleanup(self):
        """清理资源"""
        if self.update_timer:
            self.update_timer.cancel()
            self.update_timer = None
