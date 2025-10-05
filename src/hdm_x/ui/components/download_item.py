"""
下载项组件 - 单个下载任务的显示
"""

import flet as ft
import os
import platform
import subprocess
from pathlib import Path
from ...utils.logger import logger
from ...utils.pathUtils import getDefaultDownloadPath


class DownloadItem:
    def __init__(self, page: ft.Page, font_manager, data, data_manager=None, refresh_callback=None, batch_mode=False, is_selected=False, on_selection_change=None):
        self.page = page
        self.font_manager = font_manager
        self.data = data
        self.data_manager = data_manager
        self.refresh_callback = refresh_callback  # 刷新回调
        self.batchMode = batch_mode  # 批量管理模式
        self.isSelected = is_selected  # 是否被选中
        self.onSelectionChange = on_selection_change  # 选中状态变更回调
        
    def get_status_icon(self):
        """根据状态获取图标"""
        status = self.data.get("status", "unknown")
        icons = {
            "downloading": ft.Icons.DOWNLOAD,
            "completed": ft.Icons.CHECK,
            "paused": ft.Icons.PAUSE,
            "failed": ft.Icons.ERROR,
            "waiting": ft.Icons.SCHEDULE
        }
        return icons.get(status, ft.Icons.HELP)
        
    def get_status_color(self):
        """根据状态获取颜色"""
        status = self.data.get("status", "unknown")
        colors = {
            "downloading": ft.Colors.BLUE,
            "completed": ft.Colors.GREEN,
            "paused": ft.Colors.ORANGE,
            "failed": ft.Colors.RED,
            "waiting": ft.Colors.GREY
        }
        return colors.get(status, ft.Colors.GREY)
    
    def get_file_type_icon(self):
        """根据文件类型获取图标"""
        file_name = self.data.get("fileName", "")
        if not file_name or '.' not in file_name:
            return ft.Icons.INSERT_DRIVE_FILE
        
        ext = file_name.lower().split('.')[-1]
        
        icon_mapping = {
            'video': ft.Icons.MOVIE,
            'audio': ft.Icons.MUSIC_NOTE,
            'image': ft.Icons.IMAGE,
            'document': ft.Icons.DESCRIPTION,
            'archive': ft.Icons.ARCHIVE
        }
        
        type_mapping = {
            'video': ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v'],
            'audio': ['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a'],
            'image': ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'svg', 'webp'],
            'document': ['pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx'],
            'archive': ['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz']
        }
        
        for file_type, extensions in type_mapping.items():
            if ext in extensions:
                return icon_mapping.get(file_type, ft.Icons.INSERT_DRIVE_FILE)
        
        return ft.Icons.INSERT_DRIVE_FILE
    
    def get_progress_bar_color(self):
        """获取进度条颜色"""
        status = self.data.get("status", "unknown")
        progress = self.data.get("progress", 0)
        
        # 完成状态或进度100%时使用绿色
        if status == "completed" or progress >= 100:
            return ft.Colors.GREEN
        
        # 其他状态使用对应的状态颜色
        return self.get_status_color()
    
    def _get_action_buttons(self):
        """根据状态获取操作按钮"""
        status = self.data.get("status", "unknown")
        buttons = []
        
        # 播放/暂停按钮
        if status in ["downloading", "paused"]:
            buttons.append(
                ft.IconButton(
                    icon=ft.Icons.PLAY_ARROW if status == "paused" else ft.Icons.PAUSE,
                    icon_size=16,
                    tooltip="恢复下载" if status == "paused" else "暂停下载",
                    on_click=self.on_play_pause,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=6),
                        color=ft.Colors.PRIMARY
                    )
                )
            )
        
        # 重新开始按钮（失败或取消状态）
        if status in ["failed", "cancelled"]:
            buttons.append(
                ft.IconButton(
                    icon=ft.Icons.REFRESH,
                    icon_size=16,
                    tooltip="重新开始下载",
                    on_click=self.on_restart,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=6),
                        color=ft.Colors.ORANGE
                    )
                )
            )
        
        # 打开文件按钮（已完成状态）
        if status == "completed":
            buttons.append(
                ft.IconButton(
                    icon=ft.Icons.OPEN_IN_NEW,
                    icon_size=16,
                    tooltip="打开文件",
                    on_click=self.on_open_file,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=6),
                        color=ft.Colors.GREEN
                    )
                )
            )
        
        # 删除按钮（所有状态都有）
        buttons.append(
            ft.IconButton(
                icon=ft.Icons.DELETE_OUTLINE,
                icon_size=16,
                tooltip="删除任务",
                on_click=self.on_delete,
                style=ft.ButtonStyle(
                    shape=ft.RoundedRectangleBorder(radius=6),
                    color=ft.Colors.RED_400
                )
            )
        )
        
        return buttons
    
    def _on_checkbox_change(self, e):
        """复选框状态变更处理"""
        self.isSelected = e.control.value
        if self.onSelectionChange:
            self.onSelectionChange(self.data.get("id"), self.isSelected)
        
    def on_play_pause(self, e):
        """播放/暂停按钮事件"""
        if not self.data_manager:
            return
            
        current_status = self.data.get("status")
        download_id = self.data.get("id")
        file_name = self.data.get("fileName", "未知文件")
        
        logger.info(f"下载操作: {file_name} - {current_status} -> {'恢复' if current_status == 'paused' else '暂停'}")
        
        # 显示处理中状态（仅UI反馈，不改变实际状态）
        processing_text = "恢复中..." if current_status == "paused" else "暂停中..."
        original_speed = self.data.get("speed")
        
        # 临时更新速度显示
        self.data["speed"] = processing_text
        
        # 立即刷新UI显示处理状态
        if self.refresh_callback:
            try:
                self.refresh_callback()
                logger.debug("处理状态UI刷新成功")
            except Exception as e:
                logger.error(f"处理状态UI刷新失败: {e}")
        
        # 创建异步任务来处理暂停/恢复
        async def handle_pause_resume():
            try:
                success = False
                
                # 使用原始状态进行异步操作
                if current_status == "paused":
                    # 恢复下载
                    success = await self.data_manager.resume_download(download_id)
                    if success:
                        final_status = "downloading"
                        final_speed = "下载中"
                        logger.info(f"恢复下载成功: {file_name}")
                    else:
                        # 恢复失败，回滚到暂停状态
                        final_status = "paused"
                        final_speed = "已暂停"
                        logger.error(f"恢复下载失败: {file_name}")
                    
                elif current_status == "downloading":
                    # 暂停下载
                    success = await self.data_manager.pause_download(download_id)
                    if success:
                        final_status = "paused"
                        final_speed = "已暂停"
                        logger.info(f"暂停下载成功: {file_name}")
                    else:
                        # 暂停失败，回滚到下载状态
                        final_status = "downloading"
                        final_speed = "下载中"
                        logger.error(f"暂停下载失败: {file_name}")
                
                # 更新最终状态
                self.data["status"] = final_status
                self.data["speed"] = final_speed
                self.data_manager.update_download(download_id, {
                    "status": final_status,
                    "speed": final_speed
                })
                
            except Exception as ex:
                logger.error(f"异步操作失败: {ex}")
                # 操作失败，恢复原始状态
                self.data["status"] = current_status
                self.data["speed"] = original_speed
                self.data_manager.update_download(download_id, {
                    "status": current_status,
                    "speed": original_speed
                })
            
            finally:
                # 无论成功还是失败，都要刷新UI
                if self.refresh_callback:
                    try:
                        self.refresh_callback()
                        logger.info("异步操作完成后UI刷新成功")
                    except Exception as e:
                        logger.error(f"异步操作完成后UI刷新失败: {e}")
        
        # 启动异步任务
        import asyncio
        try:
            # 尝试在现有事件循环中创建任务
            loop = asyncio.get_running_loop()
            loop.create_task(handle_pause_resume())
        except RuntimeError:
            # 如果没有事件循环，在新线程中运行
            import threading
            def run_async():
                asyncio.run(handle_pause_resume())
            
            thread = threading.Thread(target=run_async)
            thread.daemon = True
            thread.start()
        
    def on_delete(self, e):
        """删除按钮事件"""
        if not self.data_manager:
            return
            
        download_id = self.data.get("id")
        file_name = self.data.get("fileName", "未知文件")
        
        logger.info(f"删除操作: {file_name}")
        
        # 显示确认对话框
        def confirm_delete(confirm_e):
            if confirm_e.control.text == "确认":
                # 执行删除
                success = self.data_manager.remove_download(download_id)
                if success:
                    logger.info(f"删除成功: {file_name}")
                    # 立即触发刷新回调
                    if self.refresh_callback:
                        try:
                            self.refresh_callback()
                            logger.debug("刷新回调执行成功")
                        except Exception as e:
                            logger.error(f"刷新回调执行失败: {e}")
                else:
                    logger.error(f"删除失败: {file_name}")
            
            # 使用官方方式关闭对话框
            self.page.close(dialog)
        
        # 创建确认对话框
        dialog = ft.AlertDialog(
            modal=True,
            title=ft.Text("确认删除"),
            content=ft.Text(f"确定要删除 '{file_name}' 吗？\n此操作无法撤销。"),
            actions=[
                ft.TextButton("取消", on_click=confirm_delete),
                ft.TextButton("确认", on_click=confirm_delete),
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        
        # 使用官方推荐的方式显示对话框
        self.page.open(dialog)
        
    def on_restart(self, e):
        """重新开始下载"""
        if not self.data_manager:
            return
            
        download_id = self.data.get("id")
        file_name = self.data.get("fileName", "未知文件")
        
        logger.info(f"重启下载: {file_name}")
        
        # 立即更新数据管理器中的状态（乐观更新）
        self.data["status"] = "downloading"
        self.data["progress"] = 0.0
        self.data["downloaded"] = "0 B"
        self.data["speed"] = "重新开始..."
        
        # 同时更新数据管理器
        self.data_manager.update_download(download_id, {
            "status": "downloading",
            "progress": 0.0,
            "downloaded": "0 B",
            "speed": "重新开始..."
        })
        
        # 立即触发UI刷新
        if self.refresh_callback:
            try:
                self.refresh_callback()
                logger.debug("重启下载立即UI刷新成功")
            except Exception as e:
                logger.error(f"重启下载立即UI刷新失败: {e}")
        
        # 创建异步任务来处理重启
        async def handle_restart():
            try:
                success = await self.data_manager.restart_download(download_id)
                if success:
                    self.data_manager.update_download(download_id, {
                        "status": "downloading",
                        "progress": 0.0,
                        "downloaded": "0 B",
                        "speed": "重新开始..."
                    })
                    if self.refresh_callback:
                        try:
                            self.refresh_callback()
                            logger.debug("重启下载最终UI刷新成功")
                        except Exception as e:
                            logger.error(f"重启下载最终UI刷新失败: {e}")
                else:
                    raise Exception("restart_download 返回 False")
            except Exception as ex:
                logger.error(f"重启下载失败: {ex}")
                self.data["status"] = "failed"
                self.data["speed"] = "重启失败"
                self.data_manager.update_download(download_id, {
                    "status": "failed",
                    "speed": "重启失败"
                })
                if self.refresh_callback:
                    self.refresh_callback()
        
        # 启动异步任务
        import asyncio
        try:
            # 尝试在现有事件循环中创建任务
            loop = asyncio.get_running_loop()
            loop.create_task(handle_restart())
        except RuntimeError:
            # 如果没有事件循环，在新线程中运行
            import threading
            def run_async():
                asyncio.run(handle_restart())
            
            thread = threading.Thread(target=run_async)
            thread.daemon = True
            thread.start()
        
    def _find_actual_file(self, file_name: str) -> Path:
        """智能查找实际文件位置"""
        try:
            # 1. 检查记录的文件路径
            recorded_path = self.data.get("filepath", "")
            if recorded_path:
                path_obj = Path(recorded_path)
                
                # 如果是绝对路径且存在
                if path_obj.is_absolute() and path_obj.exists() and path_obj.is_file():
                    return path_obj
                
                # 如果是相对路径，尝试不同的基础路径
                if not path_obj.is_absolute():
                    base_paths = [
                        Path.cwd(),  # 当前工作目录
                        Path.home() / "Downloads",  # 用户下载目录
                    ]
                    
                    for base_path in base_paths:
                        full_path = base_path / recorded_path
                        if full_path.exists() and full_path.is_file():
                            return full_path
            
            # 2. 在用户设置的下载目录中查找
            if self.data_manager:
                download_dir = Path(self.data_manager.get_settings().get('download_dir', getDefaultDownloadPath()))
            else:
                download_dir = Path(getDefaultDownloadPath())
            
            if download_dir.exists():
                # 精确匹配
                exact_path = download_dir / file_name
                if exact_path.exists() and exact_path.is_file():
                    return exact_path
                
                # 模糊匹配（处理文件名变化）
                base_name = Path(file_name).stem
                suffix = Path(file_name).suffix
                
                for file_path in download_dir.iterdir():
                    if file_path.is_file():
                        file_base = file_path.stem
                        file_suffix = file_path.suffix
                        
                        # 检查是否匹配（考虑可能的数字后缀）
                        if (file_suffix.lower() == suffix.lower() and 
                            (file_base == base_name or 
                             file_base.startswith(base_name + "_"))):
                            return file_path
            
            # 3. 在常见下载位置查找
            common_paths = [
                Path.home() / "Downloads" / file_name,
                Path.home() / "Desktop" / file_name,
                Path.cwd() / file_name,
            ]
            
            for path in common_paths:
                if path.exists() and path.is_file():
                    return path
            
            # 4. 返回预期路径（即使不存在）
            return download_dir / file_name
            
        except Exception as e:
            logger.error(f"查找文件失败: {e}")
            # 返回默认路径
            return Path(getDefaultDownloadPath()) / file_name

    def on_open_file(self, e):
        """打开文件夹并选中文件"""
        file_name = self.data.get("fileName", "未知文件")
        
        logger.info(f"打开文件: {file_name}")
        
        try:
            # 智能文件查找逻辑
            download_path = self._find_actual_file(file_name)
            
            if download_path.exists():
                # 根据操作系统打开文件夹并选中文件
                system = platform.system()
                if system == "Windows":
                    # Windows: 使用多种方法尝试打开文件
                    success = False
                    
                    # 方法1: 尝试使用 explorer /select 选中文件
                    try:
                        subprocess.run(['explorer', '/select,', str(download_path.resolve())], 
                                     check=True, timeout=10)
                        success = True
                        logger.info("使用 explorer /select 成功打开文件")
                    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
                        logger.warning(f"explorer /select 失败: {e}")
                    
                    # 方法2: 如果方法1失败，尝试直接打开文件夹
                    if not success:
                        try:
                            subprocess.run(['explorer', str(download_path.parent.resolve())], 
                                         check=True, timeout=10)
                            success = True
                            logger.info("使用 explorer 成功打开文件夹")
                        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
                            logger.warning(f"explorer 打开文件夹失败: {e}")
                    
                    # 方法3: 使用 os.startfile 作为最后的备选方案
                    if not success:
                        try:
                            import os
                            os.startfile(str(download_path.parent.resolve()))
                            success = True
                            logger.info("使用 os.startfile 成功打开文件夹")
                        except Exception as e:
                            logger.error(f"os.startfile 失败: {e}")
                    
                    if not success:
                        raise Exception("所有打开方法都失败了")
                elif system == "Darwin":  # macOS
                    # macOS: 使用Finder选中文件
                    subprocess.run(['open', '-R', str(download_path)], check=True)
                else:  # Linux
                    # Linux: 打开包含文件的文件夹
                    subprocess.run(['xdg-open', str(download_path.parent)], check=True)
                
                logger.info(f"文件打开成功: {download_path}")
            else:
                logger.warning(f"文件不存在: {download_path}")
                
                # 显示错误对话框
                error_dialog = ft.AlertDialog(
                    modal=True,
                    title=ft.Text("文件不存在"),
                    content=ft.Text(f"文件 '{file_name}' 不存在或已被移动。\n\n搜索路径: {download_path}"),
                    actions=[
                        ft.TextButton("确定", on_click=lambda e: self.page.close(error_dialog)),
                    ],
                    actions_alignment=ft.MainAxisAlignment.END,
                )
                
                # 使用官方推荐的方式显示对话框
                self.page.open(error_dialog)
                
        except Exception as ex:
            logger.error(f"打开文件失败: {ex}")
    

        
    def build(self):
        """构建下载项"""
        progress = self.data.get("progress", 0)
        
        return ft.Container(
            content=ft.Row(
                controls=[
                    # 左侧：文件类型图标区域
                    ft.Container(
                        content=ft.Column(
                            controls=[
                                # 复选框（仅在批量管理模式下显示）
                                ft.Container(
                                    content=ft.Checkbox(
                                        value=self.isSelected,
                                        on_change=self._on_checkbox_change,
                                        scale=0.8
                                    ) if self.batchMode else None,
                                    height=20 if self.batchMode else 0,
                                    alignment=ft.alignment.center
                                ),
                                # 文件类型图标
                                ft.Container(
                                    content=ft.Icon(
                                        self.get_file_type_icon(),
                                        size=48,
                                        color=ft.Colors.PRIMARY
                                    ),
                                    alignment=ft.alignment.center,
                                    expand=True
                                )
                            ],
                            spacing=4,
                            alignment=ft.MainAxisAlignment.CENTER
                        ),
                        width=80,
                        height=80,
                        alignment=ft.alignment.center,
                        border_radius=12
                    ),
                    
                    # 右侧：内容区域
                    ft.Container(
                        content=ft.Column(
                            controls=[
                                # 第一行：文件名 + 状态图标
                                ft.Row(
                                    controls=[
                                        ft.Container(
                                            content=self.font_manager.create_text(
                                                self.data.get("fileName", "未知文件"),
                                                "normal",
                                                "medium",
                                                overflow=ft.TextOverflow.ELLIPSIS
                                            ),
                                            expand=True
                                        ),
                                        ft.Icon(
                                            self.get_status_icon(),
                                            size=20,
                                            color=self.get_status_color()
                                        ),
                                        # 操作按钮
                                        ft.Row(
                                            controls=self._get_action_buttons(),
                                            spacing=4
                                        )
                                    ],
                                    spacing=8,
                                    alignment=ft.MainAxisAlignment.START
                                ),
                                
                                # 第二行：Link信息
                                ft.Container(
                                    content=self.font_manager.create_text(
                                        f"Link: {self.data.get('url', '')}",
                                        "small",
                                        color=ft.Colors.OUTLINE,
                                        overflow=ft.TextOverflow.ELLIPSIS
                                    ),
                                    bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.SECONDARY_CONTAINER),
                                    padding=ft.padding.symmetric(horizontal=12, vertical=6),
                                    border_radius=12,
                                    margin=ft.margin.only(top=4)
                                ),
                                
                                # 第三行：进度条
                                ft.Container(
                                    content=ft.Column(
                                        controls=[
                                            ft.ProgressBar(
                                                value=(progress or 0) / 100.0,
                                                height=10,
                                                bgcolor=ft.Colors.BLUE_GREY_50,
                                                color=self.get_progress_bar_color(),
                                                border_radius=5
                                            ),
                                            ft.Row(
                                                controls=[
                                                    self.font_manager.create_text(
                                                        f"{int(progress)}%" if (progress > 0 or self.data.get("status") == "downloading") else "等待中",
                                                        "small",
                                                        color=ft.Colors.OUTLINE
                                                    ),
                                                    self.font_manager.create_text(
                                                        self.data.get("speed", "0 KB/s"),
                                                        "small",
                                                        color=ft.Colors.OUTLINE
                                                    ),
                                                    self.font_manager.create_text(
                                                        f"{self.data.get('downloaded', '0 B')} / {self.data.get('size', '0 B')}",
                                                        "small",
                                                        color=ft.Colors.OUTLINE
                                                    )
                                                ],
                                                alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                                            )
                                        ],
                                        spacing=4
                                    ),
                                    margin=ft.margin.only(top=8)
                                )
                            ],
                            spacing=0,
                            alignment=ft.MainAxisAlignment.START
                        ),
                        expand=True
                    )
                ],
                spacing=16,
                alignment=ft.MainAxisAlignment.START
            ),
            padding=ft.padding.all(16),
            margin=ft.margin.only(bottom=8),
            bgcolor=ft.Colors.SURFACE,
            border_radius=12,
            border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT)
        )