"""
下载区域组件 - 显示下载任务列表
"""

import flet as ft
from .download_item import DownloadItem
from ...core.managers.data_manager import DataManager
from ...utils.logger import logger


class DownloadArea:
    def __init__(self, page: ft.Page, font_manager, side_bar, data_manager=None):
        self.page = page
        self.font_manager = font_manager
        self.side_bar = side_bar
        self.download_items = []
        self.current_category = "all"
        self.data_manager = data_manager or DataManager()
        self.download_area_container = None  # 存储下载区域容器引用
        self._last_progress_update = 0.0
        
        # 批量管理相关状态
        self.batchMode = False  # 批量管理模式
        self.selectedItems = set()  # 选中的项目ID集合
        
        # 注册分类变更回调
        self.side_bar.add_category_callback(self.on_category_change)
        
        # 注册字体变更回调
        self.font_manager.add_font_change_callback(self.on_font_change)
        
        # 初始化下载项
        self.load_downloads()
        
        # 设置进度回调
        self.setup_progress_callbacks()
        
    def on_category_change(self, category):
        """分类变更处理"""
        logger.debug(f"下载区域接收到分类变更: {category}")
        
        old_category = self.current_category
        self.current_category = category
        
        logger.debug(f"下载区域分类切换: {old_category} -> {category}")
        
        # 重新加载下载项以确保数据是最新的
        self.load_downloads()
        
        # 更新下载区域UI
        self.update_download_area_ui()
        
        # 更新页面显示
        self.page.update()
        
    def get_file_type(self, file_name):
        """根据文件名获取文件类型"""
        ext = file_name.lower().split('.')[-1] if '.' in file_name else ''
        
        video_exts = ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'm4v']
        audio_exts = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a']
        image_exts = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'svg', 'webp']
        document_exts = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx']
        archive_exts = ['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz']
        
        if ext in video_exts:
            return 'video'
        elif ext in audio_exts:
            return 'audio'
        elif ext in image_exts:
            return 'image'
        elif ext in document_exts:
            return 'document'
        elif ext in archive_exts:
            return 'archive'
        else:
            return 'other'
        
    def load_downloads(self):
        """从数据管理器加载下载项"""
        self.download_items = []
        downloads = self.data_manager.get_downloads()
        
        for data in downloads:
            download_item = DownloadItem(
                self.page, 
                self.font_manager, 
                data, 
                self.data_manager,
                refresh_callback=self.refresh_downloads  # 传递刷新回调
            )
            self.download_items.append(download_item)
    
    def refresh_downloads(self):
        """刷新下载列表"""
        logger.info("刷新下载列表...")
        
        # 重新加载数据
        self.load_downloads()
        
        # 更新UI
        self.update_download_area_ui()
        
        # 同时更新侧边栏计数
        if hasattr(self.side_bar, 'update_sidebar_ui'):
            try:
                self.side_bar.update_sidebar_ui()
                logger.debug("侧边栏UI更新成功")
            except Exception as e:
                logger.error(f"侧边栏UI更新失败: {e}")
        
        # 强制刷新页面
        try:
            self.page.update()
            logger.debug("页面更新成功")
        except Exception as e:
            logger.error(f"页面更新失败: {e}")
        
        logger.info(f"下载列表刷新完成，当前项目数: {len(self.download_items)}")
    
    def add_new_download(self, url: str, filename: str = ""):
        """添加新的下载任务"""
        import time
        import secrets
        
        download_data = {
            "id": f"dl_{secrets.token_hex(4)}",
            "fileName": filename or self.extract_filename(url),
            "url": url,
            "progress": 0.0,
            "speed": "等待中",
            "size": "未知",
            "downloaded": "0 B",
            "status": "downloading",
            "timeRemaining": "",
            "fileType": self.get_file_type(filename or url),
            "createdTime": time.strftime("%Y-%m-%dT%H:%M:%SZ")
        }
        
        if self.data_manager.add_download(download_data):
            self.refresh_downloads()
            return True
        return False
    
    def extract_filename(self, url: str) -> str:
        """从URL提取文件名"""
        try:
            from urllib.parse import urlparse, unquote
            parsed = urlparse(url)
            filename = unquote(parsed.path.split('/')[-1])
            
            if filename and '.' in filename:
                return filename
            
            return f"download_{int(time.time())}"
        except Exception:
            import time
            return f"download_{int(time.time())}"
    
    def clear_completed(self):
        """清空已完成的下载任务"""
        downloads = self.data_manager.get_downloads()
        completed_ids = [d["id"] for d in downloads if d.get("status") == "completed"]
        
        for download_id in completed_ids:
            self.data_manager.remove_download(download_id)
        
        if completed_ids:
            self.refresh_downloads()
    
    def update_download_area_ui(self):
        """更新下载区域UI"""
        if self.download_area_container:
            logger.debug(f"更新下载区域UI，当前分类: {self.current_category}")
            # 重新构建内容
            new_content = self._build_download_area_content()
            self.download_area_container.content = new_content
            logger.debug("下载区域UI更新完成")
    
    def on_font_change(self):
        """字体变更回调"""
        logger.debug("下载区域接收到字体变更通知")
        self.update_download_area_ui()
            
    def get_filtered_items(self):
        """获取过滤后的下载项"""
        if self.current_category == "all":
            return self.download_items
        elif self.current_category in ["downloading", "completed", "paused", "failed"]:
            return [item for item in self.download_items if item.data["status"] == self.current_category]
        else:
            return [item for item in self.download_items if item.data["fileType"] == self.current_category]
    
    def _build_toolbar_buttons(self):
        """构建工具栏按钮"""
        buttons = [
            ft.IconButton(
                icon=ft.Icons.REFRESH,
                tooltip="刷新",
                on_click=lambda e: self.refresh_downloads(),
                style=ft.ButtonStyle(
                    shape=ft.RoundedRectangleBorder(radius=8)
                )
            )
        ]
        
        # 仅在全部分类显示批量管理按钮
        if self.current_category == "all":
            if self.batchMode:
                # 批量管理模式下的按钮
                buttons.extend([
                    ft.IconButton(
                        icon=ft.Icons.SELECT_ALL,
                        tooltip="全选",
                        on_click=lambda e: self.select_all(),
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=8)
                        )
                    ),
                    ft.IconButton(
                        icon=ft.Icons.DESELECT,
                        tooltip="全不选",
                        on_click=lambda e: self.deselect_all(),
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=8)
                        )
                    ),
                    ft.IconButton(
                        icon=ft.Icons.DELETE_SWEEP,
                        tooltip="批量删除",
                        on_click=lambda e: self.batch_delete(),
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=8)
                        )
                    ),
                    ft.IconButton(
                        icon=ft.Icons.CLOSE,
                        tooltip="退出批量管理",
                        on_click=lambda e: self.toggle_batch_mode(),
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=8)
                        )
                    )
                ])
            else:
                # 普通模式下的按钮
                buttons.extend([
                    ft.IconButton(
                        icon=ft.Icons.CHECKLIST,
                        tooltip="批量管理",
                        on_click=lambda e: self.toggle_batch_mode(),
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=8)
                        )
                    )
                ])
        
        # 清空已完成按钮始终显示
        buttons.append(
            ft.IconButton(
                icon=ft.Icons.CLEAR_ALL,
                tooltip="清空已完成",
                on_click=lambda e: self.clear_completed(),
                style=ft.ButtonStyle(
                    shape=ft.RoundedRectangleBorder(radius=8)
                )
            )
        )
        
        return buttons
    
    def toggle_batch_mode(self):
        """切换批量管理模式"""
        self.batchMode = not self.batchMode
        if not self.batchMode:
            # 退出批量管理模式时清空选中项
            self.selectedItems.clear()
        
        # 更新UI
        self.update_download_area_ui()
        self.page.update()
        
        logger.info(f"批量管理模式: {'开启' if self.batchMode else '关闭'}")
    
    def on_item_selection_change(self, item_id, is_selected):
        """处理下载项选中状态变更"""
        if is_selected:
            self.selectedItems.add(item_id)
        else:
            self.selectedItems.discard(item_id)
        
        logger.debug(f"选中项目变更: {item_id} -> {'选中' if is_selected else '取消选中'}，当前选中数量: {len(self.selectedItems)}")
    
    def _build_download_item(self, item):
        """构建下载项，传递批量管理相关参数"""
        item_id = item.data.get("id")
        is_selected = item_id in self.selectedItems
        
        # 更新下载项的批量管理状态
        item.batchMode = self.batchMode
        item.isSelected = is_selected
        item.onSelectionChange = self.on_item_selection_change
        
        return item.build()
    
    def select_all(self):
        """全选所有项目"""
        filtered_items = self.get_filtered_items()
        for item in filtered_items:
            item_id = item.data.get("id")
            if item_id:
                self.selectedItems.add(item_id)
        
        # 更新UI
        self.update_download_area_ui()
        self.page.update()
        
        logger.info(f"全选完成，选中项目数量: {len(self.selectedItems)}")
    
    def deselect_all(self):
        """全不选"""
        self.selectedItems.clear()
        
        # 更新UI
        self.update_download_area_ui()
        self.page.update()
        
        logger.info("全不选完成")
    
    def batch_delete(self):
        """批量删除选中的项目"""
        if not self.selectedItems:
            logger.warning("没有选中任何项目")
            return
        
        selected_count = len(self.selectedItems)
        
        # 显示确认对话框
        def confirm_delete(e):
            # 执行批量删除
            deleted_count = 0
            failed_items = []
            
            for item_id in list(self.selectedItems):
                try:
                    if self.data_manager.remove_download(item_id):
                        deleted_count += 1
                    else:
                        failed_items.append(item_id)
                except Exception as ex:
                    logger.error(f"删除项目 {item_id} 失败: {ex}")
                    failed_items.append(item_id)
            
            # 清空选中项
            self.selectedItems.clear()
            
            # 刷新列表
            self.refresh_downloads()
            
            # 关闭对话框
            self.page.close(confirm_dialog)
            
            # 显示结果
            if failed_items:
                logger.warning(f"批量删除完成: 成功 {deleted_count} 个，失败 {len(failed_items)} 个")
            else:
                logger.info(f"批量删除完成: 成功删除 {deleted_count} 个项目")
        
        def cancel_delete(e):
            self.page.close(confirm_dialog)
        
        confirm_dialog = ft.AlertDialog(
            modal=True,
            title=ft.Text("确认批量删除"),
            content=ft.Text(f"确定要删除选中的 {selected_count} 个下载任务吗？\n\n此操作不可撤销。"),
            actions=[
                ft.TextButton("取消", on_click=cancel_delete),
                ft.TextButton("确定删除", on_click=confirm_delete, style=ft.ButtonStyle(color=ft.Colors.RED)),
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        
        self.page.open(confirm_dialog)
            
    def _build_download_area_content(self):
        """构建下载区域内容"""
        # 获取过滤后的项目
        filtered_items = self.get_filtered_items()
        
        # 获取分类统计
        counts = self.data_manager.get_category_counts()
        
        # 更新侧边栏的分类计数
        self.side_bar.category_counts = counts
        
        # 触发侧边栏UI更新
        if hasattr(self.side_bar, 'update_sidebar_ui'):
            self.side_bar.update_sidebar_ui()
        
        logger.debug(f"构建下载区域内容，分类: {self.current_category}, 过滤后项目数: {len(filtered_items)}")
        
        if not filtered_items:
            # 空状态
            category_name = {
                "all": "全部",
                "downloading": "下载中",
                "completed": "已完成", 
                "paused": "已暂停",
                "failed": "失败",
                "video": "视频",
                "audio": "音频",
                "image": "图片",
                "document": "文档",
                "archive": "压缩包",
                "other": "其他"
            }.get(self.current_category, "未知")
            
            return ft.Column(
                controls=[
                    ft.Icon(
                        ft.Icons.FOLDER_OPEN,
                        size=64,
                        color=ft.Colors.OUTLINE
                    ),
                    self.font_manager.create_text(
                        f"该分类下暂无任务",
                        "title",
                        color=ft.Colors.OUTLINE
                    ),
                    self.font_manager.create_text(
                        f"当前分类：{category_name}",
                        "normal",
                        color=ft.Colors.OUTLINE
                    )
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=16
            )
        else:
            # 下载列表
            category_name = {
                "all": "全部",
                "downloading": "下载中",
                "completed": "已完成", 
                "paused": "已暂停",
                "failed": "失败",
                "video": "视频",
                "audio": "音频",
                "image": "图片",
                "document": "文档",
                "archive": "压缩包",
                "other": "其他"
            }.get(self.current_category, "未知")
            
            return ft.Column(
                controls=[
                    # 工具栏 - 固定在顶部
                    ft.Container(
                        content=ft.Row(
                            controls=[
                                self.font_manager.create_text(
                                    f"{category_name} ({len(filtered_items)})",
                                    "large",
                                    "medium"
                                ),
                                ft.Row(
                                    controls=self._build_toolbar_buttons()
                                )
                            ],
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                        ),
                        padding=ft.padding.only(bottom=16)
                    ),
                    
                    # 下载项列表 - 可滚动区域
                    ft.Container(
                        content=ft.ListView(
                            controls=[self._build_download_item(item) for item in filtered_items],
                            spacing=8,
                            padding=ft.padding.all(0),
                            auto_scroll=False,  # 禁用自动滚动
                            first_item_prototype=True  # 优化性能
                        ),
                        expand=True
                    )
                ],
                expand=True,
                spacing=0
            )
    
    def build(self):
        """构建下载区域"""
        content = self._build_download_area_content()
        
        self.download_area_container = ft.Container(
            content=content,
            alignment=ft.alignment.center if not self.get_filtered_items() else None,
            expand=True,
            height=None  # 让容器自适应高度
        )
        
        return self.download_area_container
    
    def setup_progress_callbacks(self):
        """设置下载核心的进度回调"""
        if hasattr(self.data_manager, 'download_core') and self.data_manager.download_core:
            # 添加进度回调
            def on_progress(task):
                logger.info(f"🔄 收到进度回调: {task.id[:8]} - {task.filename} - {task.status.value} - {task.progress:.1f}%")
                
                try:
                    import time as _t
                    now = _t.time()
                    if now - getattr(self, "_last_progress_update", 0) >= 0.5:
                        self._last_progress_update = now
                        self.refresh_downloads()
                except Exception:
                    self.refresh_downloads()
            
            def on_completion(task):
                logger.info(f"✅ 下载完成回调: {task.id[:8]} - {task.filename}")
                # 刷新UI
                self.refresh_downloads()
            
            self.data_manager.download_core.add_progress_callback(on_progress)
            self.data_manager.download_core.add_completion_callback(on_completion)
            
            logger.info("下载核心回调设置成功")
        else:
            logger.warning("下载核心未设置，无法注册回调")