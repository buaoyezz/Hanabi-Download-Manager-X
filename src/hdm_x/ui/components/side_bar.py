"""
侧边栏组件 - 微软Fluent Design风格
"""

import flet as ft
from ...utils.logger import logger


class SideBar:
    def __init__(self, page: ft.Page, font_manager, config_manager=None):
        self.page = page
        self.font_manager = font_manager
        self.config_manager = config_manager
        self.selected_category = "all"
        self.category_callbacks = []
        self.category_items = []  # 存储分类项引用
        self.settings_callback = None  # 设置页面回调
        self.about_callback = None # 关于页面回调
        self.category_counts = {}  # 分类计数
        self.sidebar_container = None  # 存储侧边栏容器引用
        
        # 从配置加载侧边栏状态
        if self.config_manager:
            self.is_collapsed = self.config_manager.get_config('sidebar_collapsed', False)
            self.remember_state = self.config_manager.get_config('sidebar_remember_state', True)
            self.default_expanded = self.config_manager.get_config('sidebar_default_expanded', True)
        else:
            self.is_collapsed = False
            self.remember_state = True
            self.default_expanded = True
            
        self.min_width_for_sidebar = 800  # 显示侧边栏的最小窗口宽度
        self.min_width_for_counts = 900  # 显示计数徽章的最小窗口宽度
        self.current_window_width = 1200  # 当前窗口宽度
        
        # 注册字体变更回调
        self.font_manager.add_font_change_callback(self.on_font_change)
        
        # 不在这里直接设置页面回调，避免覆盖其他组件的回调
        
    def add_category_callback(self, callback):
        """添加分类变更回调"""
        self.category_callbacks.append(callback)
        
    def update_category_counts(self, counts):
        """更新分类计数"""
        old_counts = self.category_counts.copy()
        self.category_counts = counts
        
        # 检查计数是否有变化，如果有变化则更新UI
        if old_counts != counts:
            logger.debug(f"分类计数更新: {counts}")
            # 强制重新构建内容以确保计数徽章正确显示
            self.update_sidebar_ui()
            self.page.update()
        
    def on_category_select(self, e):
        """分类选择事件处理"""
        # 更新选中状态
        old_category = self.selected_category
        self.selected_category = e.control.data
        
        # 通知所有回调
        for callback in self.category_callbacks:
            if callable(callback):
                callback(self.selected_category)
            
        self.page.update()
        
    def create_category_item(self, icon, title, category, count=0):
        """创建分类项 - Fluent Design风格"""
        is_selected = category == self.selected_category
        
        # Fluent Design 左侧指示条 - 更现代的设计
        indicator = ft.Container(
            width=4,
            height=36,
            bgcolor=ft.Colors.BLUE if is_selected else ft.Colors.TRANSPARENT,
            border_radius=ft.border_radius.only(
                top_right=3,
                bottom_right=3
            ),
            animate=ft.Animation(400, ft.AnimationCurve.EASE_IN_OUT_CUBIC_EMPHASIZED)
        )
        
        # 图标容器 - Fluent Design风格
        icon_container = ft.Container(
            content=ft.Icon(
                icon,
                size=18,
                color=ft.Colors.BLUE if is_selected else ft.Colors.OUTLINE
            ),
            width=36,
            height=36,
            bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.BLUE) if is_selected else ft.Colors.TRANSPARENT,
            border_radius=8,
            alignment=ft.alignment.center,
            animate=ft.Animation(350, ft.AnimationCurve.EASE_IN_OUT_CUBIC)
        )
        
        # 文本标签
        text_label = ft.Container(
            content=self.font_manager.create_text(
                title,
                "normal",
                color=ft.Colors.ON_SURFACE if is_selected else ft.Colors.ON_SURFACE,
                weight=ft.FontWeight.W_500 if is_selected else ft.FontWeight.W_400
            ),
            expand=True,
            margin=ft.margin.only(left=12)
        )
        
        # 计数徽章 - Fluent Design风格，根据窗口大小决定是否显示
        should_show_count = count > 0 and self.current_window_width >= self.min_width_for_counts
        count_badge = ft.Container(
            content=ft.Text(
                str(count) if should_show_count else "",
                size=11,
                color=ft.Colors.WHITE,
                weight=ft.FontWeight.W_600
            ),
            bgcolor=ft.Colors.BLUE if should_show_count else ft.Colors.TRANSPARENT,
            padding=ft.padding.symmetric(horizontal=6, vertical=2),
            border_radius=10,
            visible=should_show_count,
            animate=200
        )
        
        # 主要内容容器 - Fluent Design悬停效果
        main_content = ft.Container(
            content=ft.Row(
                controls=[icon_container, text_label, count_badge],
                spacing=0,
                alignment=ft.MainAxisAlignment.START
            ),
            padding=ft.padding.symmetric(horizontal=12, vertical=6),
            bgcolor=ft.Colors.with_opacity(0.06, ft.Colors.ON_SURFACE) if is_selected else ft.Colors.TRANSPARENT,
            border_radius=8,
            on_click=lambda e, cat=category: self.on_category_click(cat),
            ink=True,
            animate=ft.Animation(200, ft.AnimationCurve.EASE_OUT),
            expand=True
        )
        
        return ft.Container(
            content=ft.Row(
                controls=[indicator, main_content],
                spacing=0
            ),
            margin=ft.margin.symmetric(horizontal=8, vertical=2)
        )
        
    def on_category_click(self, category):
        """处理分类点击"""
        logger.debug(f"侧边栏分类点击: {category}")
        
        # 特殊处理设置按钮
        if category == "settings":
            if self.settings_callback and callable(self.settings_callback):
                self.settings_callback()
            return
        if category == "about":
            if self.about_callback and callable(self.about_callback):
                self.about_callback()
            return
        
        if self.selected_category != category:
            old_category = self.selected_category
            self.selected_category = category
            
            logger.debug(f"分类切换: {old_category} -> {category}")
            
            # 通知所有回调
            for callback in self.category_callbacks:
                if callable(callback):
                    try:
                        callback(self.selected_category)
                        logger.debug(f"回调执行成功: {callback}")
                    except Exception as e:
                        logger.error(f"回调执行失败: {e}")
            
            # 更新侧边栏UI
            self.update_sidebar_ui()
            
            # 更新页面
            self.page.update()
            
    def on_settings_click(self, e):
        """设置按钮点击事件"""
        if self.settings_callback and callable(self.settings_callback):
            self.settings_callback()
    
    def on_about_click(self, e):
        """关于按钮点击事件"""
        if self.about_callback and callable(self.about_callback):
            self.about_callback()

    def update_sidebar_ui(self):
        """更新侧边栏UI显示"""
        if self.sidebar_container:
            # 计算新的侧边栏宽度
            new_width = self._get_sidebar_width()
            
            # 重新构建侧边栏内容
            new_content = self._build_sidebar_content()
            
            # 更新容器宽度和内容
            self.sidebar_container.width = new_width
            self.sidebar_container.content = new_content
    
    def on_font_change(self):
        """字体变更回调"""
        logger.debug("侧边栏接收到字体变更通知")
        self.update_sidebar_ui()
    
    def on_page_resize(self, e):
        """页面大小变更回调"""
        new_width = None
        if hasattr(e, 'width') and e.width:
            new_width = e.width
        elif hasattr(self.page, 'width') and self.page.width:
            new_width = self.page.width
        
        if new_width:
            self.check_and_update_layout(new_width)
    
    def check_and_update_layout(self, window_width):
        """检查并更新布局"""
        old_width = self.current_window_width
        old_collapsed = self.is_collapsed
        
        # 安全地更新窗口宽度
        if window_width and window_width > 0:
            self.current_window_width = window_width
        else:
            logger.warning(f"无效的窗口宽度: {window_width}，保持当前宽度: {old_width}")
            return
        
        should_collapse = window_width < self.min_width_for_sidebar
        should_show_counts = window_width >= self.min_width_for_counts
        old_show_counts = old_width >= self.min_width_for_counts
        
        # 只有在记忆状态关闭时才根据窗口大小自动调整侧边栏状态
        # 如果记忆状态开启，只在窗口太小时强制折叠
        if self.remember_state:
            # 记忆状态开启时，只在窗口太小时强制折叠
            if should_collapse and not self.is_collapsed:
                self.is_collapsed = True
                logger.debug(f"窗口太小，强制折叠侧边栏: 窗口宽度={window_width}")
            elif not should_collapse and window_width >= self.min_width_for_sidebar:
                # 窗口足够大时，恢复用户设置的状态
                saved_collapsed = self.config_manager.get_config('sidebar_collapsed', False) if self.config_manager else False
                if self.is_collapsed != saved_collapsed:
                    self.is_collapsed = saved_collapsed
                    logger.debug(f"恢复用户设置的侧边栏状态: 折叠={self.is_collapsed}")
        else:
            # 记忆状态关闭时，根据窗口大小和默认展开设置决定状态
            if should_collapse:
                self.is_collapsed = True
            else:
                self.is_collapsed = not self.default_expanded
        
        # 检查是否需要更新布局
        layout_changed = (
            self.is_collapsed != old_collapsed or
            should_show_counts != old_show_counts or
            abs(window_width - old_width) > 50  # 窗口宽度变化超过50px时也更新
        )
        
        if layout_changed:
            logger.debug(f"侧边栏布局更新: 折叠={self.is_collapsed}, 显示计数={should_show_counts}, 窗口宽度={window_width}")
            
            # 计算新的侧边栏宽度
            new_width = self._get_sidebar_width()
            
            # 更新侧边栏容器宽度和内容
            if self.sidebar_container:
                self.sidebar_container.width = new_width
                self.sidebar_container.content = self._build_sidebar_content()
            
            # 直接更新页面，避免重复调用update_sidebar_ui
            self.page.update()
    
    def toggle_sidebar(self):
        """切换侧边栏显示状态"""
        self.is_collapsed = not self.is_collapsed
        logger.debug(f"手动切换侧边栏: {'折叠' if self.is_collapsed else '展开'}")
        
        # 如果启用了状态记忆，保存当前状态
        if self.remember_state and self.config_manager:
            self.config_manager.update_config('sidebar_collapsed', self.is_collapsed)
        
        # 计算新的侧边栏宽度
        new_width = self._get_sidebar_width()
        
        # 更新侧边栏容器宽度和内容
        if self.sidebar_container:
            self.sidebar_container.width = new_width
            self.sidebar_container.content = self._build_sidebar_content()
        
        self.update_sidebar_ui()
        self.page.update()
    
    def update_sidebar_config(self, remember_state=None, default_expanded=None):
        """更新侧边栏配置"""
        if remember_state is not None:
            self.remember_state = remember_state
            if self.config_manager:
                self.config_manager.update_config('sidebar_remember_state', remember_state)
        
        if default_expanded is not None:
            self.default_expanded = default_expanded
            if self.config_manager:
                self.config_manager.update_config('sidebar_default_expanded', default_expanded)
                
        logger.debug(f"侧边栏配置更新: 记忆状态={self.remember_state}, 默认展开={self.default_expanded}")
        
    def _build_sidebar_content(self):
        """构建侧边栏内容 - Fluent Design风格"""
        # 清空之前的分类项数据
        self.category_items = []
        
        if self.is_collapsed:
            return self._build_collapsed_content()
        
        # 创建所有控件列表
        controls = [
            # 顶部间距
            ft.Container(height=16),
            
            # 展开/折叠按钮 - 和其他图标对齐
            self._create_toggle_button_expanded(),
            
            # 下载状态分组
            ft.Container(
                content=ft.Column(
                    controls=[
                        # 分组标题
                        ft.Container(
                            content=self.font_manager.create_text(
                                "下载状态",
                                "small",
                                weight=ft.FontWeight.W_600,
                                color=ft.Colors.OUTLINE
                            ),
                            padding=ft.padding.symmetric(horizontal=20, vertical=8)
                        ),
                        
                        # 状态项目
                        self.create_category_item(
                            ft.Icons.ALL_INCLUSIVE, "全部", "all", 
                            self.category_counts.get("all", 0)
                        ),
                        self.create_category_item(
                            ft.Icons.DOWNLOAD, "下载中", "downloading", 
                            self.category_counts.get("downloading", 0)
                        ),
                        self.create_category_item(
                            ft.Icons.CHECK_CIRCLE, "已完成", "completed", 
                            self.category_counts.get("completed", 0)
                        ),
                        self.create_category_item(
                            ft.Icons.PAUSE_CIRCLE, "已暂停", "paused", 
                            self.category_counts.get("paused", 0)
                        ),
                        self.create_category_item(
                            ft.Icons.ERROR, "失败", "failed", 
                            self.category_counts.get("failed", 0)
                        ),
                    ],
                    spacing=4
                )
            ),
            
            # 分组间距
            ft.Container(height=24),
            
            # 文件类型分组
            ft.Container(
                content=ft.Column(
                    controls=[
                        # 分组标题
                        ft.Container(
                            content=self.font_manager.create_text(
                                "文件类型",
                                "small",
                                weight=ft.FontWeight.W_600,
                                color=ft.Colors.OUTLINE
                            ),
                            padding=ft.padding.symmetric(horizontal=20, vertical=8)
                        ),
                        
                        # 文件类型项目
                        self.create_category_item(
                            ft.Icons.VIDEO_FILE, "视频", "video", 
                            self.category_counts.get("video", 0)
                        ),
                        self.create_category_item(
                            ft.Icons.AUDIO_FILE, "音频", "audio", 
                            self.category_counts.get("audio", 0)
                        ),
                        self.create_category_item(
                            ft.Icons.IMAGE, "图片", "image", 
                            self.category_counts.get("image", 0)
                        ),
                        self.create_category_item(
                            ft.Icons.DESCRIPTION, "文档", "document", 
                            self.category_counts.get("document", 0)
                        ),
                        self.create_category_item(
                            ft.Icons.ARCHIVE, "压缩包", "archive", 
                            self.category_counts.get("archive", 0)
                        ),
                        self.create_category_item(
                            ft.Icons.FOLDER, "其他", "other", 
                            self.category_counts.get("other", 0)
                        ),
                    ],
                    spacing=4
                )
            ),
            
            # 底部弹性空间
            ft.Container(height=50),
            
            # 设置按钮 - Fluent Design风格
            ft.Container(
                content=self.create_category_item(
                    ft.Icons.SETTINGS, "设置", "settings", 0
                ),
                margin=ft.margin.only(bottom=16)
            ),
            # 关于按钮 - Fluent Design风格
            ft.Container(
                content=self.create_category_item(
                    ft.Icons.INFO, "关于", "about", 0
                ),
                margin=ft.margin.only(bottom=16)
            )
        ]
        
        # 使用Container包装Column来实现更好的滚动控制，完全隐藏滚动条
        return ft.Container(
            content=ft.Column(
                controls=controls,
                spacing=4,
                expand=True,
                scroll=ft.ScrollMode.HIDDEN,
                auto_scroll=False
            ),
            expand=True,
            clip_behavior=ft.ClipBehavior.HARD_EDGE
        )
    
    def build(self):
        """构建侧边栏 - Fluent Design风格"""
        # 设置初始窗口宽度
        page_width = getattr(self.page, 'width', None)
        if page_width:
            self.current_window_width = page_width
        else:
            self.current_window_width = 1200  # 默认宽度

        if not getattr(self.page, "theme", None):
            self.page.theme = ft.Theme()
        self.page.theme.scrollbar_theme = ft.ScrollbarTheme(
            thickness=0,
            thumb_visibility=False,
            track_visibility=False,
            interactive=False
        )
        
        # 设置初始侧边栏状态
        if self.remember_state:
            # 记忆状态开启时，使用保存的状态
            saved_collapsed = self.config_manager.get_config('sidebar_collapsed', False) if self.config_manager else False
            # 如果窗口太小，强制折叠
            if self.current_window_width < self.min_width_for_sidebar:
                self.is_collapsed = True
            else:
                self.is_collapsed = saved_collapsed
        else:
            # 记忆状态关闭时，根据窗口大小和默认展开设置决定
            if self.current_window_width < self.min_width_for_sidebar:
                self.is_collapsed = True
            else:
                self.is_collapsed = not self.default_expanded
        
        # 如果有页面宽度，进行布局检查（但不会覆盖上面设置的状态）
        if page_width:
            self.check_and_update_layout(page_width)
        
        content = self._build_sidebar_content()
        
        # 响应式宽度
        sidebar_width = self._get_sidebar_width()
        
        self.sidebar_container = ft.Container(
            content=content,
            width=sidebar_width,
            height=None,
            bgcolor=ft.Colors.SURFACE,
            border=ft.border.only(
                right=ft.BorderSide(1, ft.Colors.with_opacity(0.12, ft.Colors.ON_SURFACE))
            ),
            shadow=ft.BoxShadow(
                spread_radius=0,
                blur_radius=8,
                color=ft.Colors.with_opacity(0.1, ft.Colors.BLACK),
                offset=ft.Offset(2, 0)
            ),
            visible=True,
            animate_size=ft.Animation(350, ft.AnimationCurve.EASE_OUT_CUBIC),
            expand_loose=True
        )
        
        return self.sidebar_container
    
    def _build_collapsed_content(self):
        """构建折叠状态的侧边栏内容 - Fluent Design风格"""
        # 创建所有控件列表
        controls = [
            # 顶部间距
            ft.Container(height=16),
            
            # 展开按钮 - Fluent Design风格
            ft.Container(
                content=ft.Row(
                    controls=[
                        ft.Container(
                            width=4,
                            height=40,
                            bgcolor=ft.Colors.TRANSPARENT,
                            border_radius=ft.border_radius.only(
                                top_right=3,
                                bottom_right=3
                            )
                        ),
                        ft.Container(
                            content=ft.IconButton(
                                icon=ft.Icons.MENU,
                                tooltip="展开侧边栏",
                                on_click=lambda e: self.toggle_sidebar(),
                                icon_size=18,
                                style=ft.ButtonStyle(
                                    color=ft.Colors.OUTLINE,
                                    bgcolor=ft.Colors.TRANSPARENT
                                )
                            ),
                            width=40,
                            height=40,
                            border_radius=8,
                            alignment=ft.alignment.center
                        )
                    ],
                    spacing=0
                ),
                margin=ft.margin.symmetric(horizontal=8, vertical=4)
            ),
            
            # 分类图标列表
            self._create_collapsed_category_item(ft.Icons.ALL_INCLUSIVE, "all", "全部"),
            self._create_collapsed_category_item(ft.Icons.DOWNLOAD, "downloading", "下载中"),
            self._create_collapsed_category_item(ft.Icons.CHECK_CIRCLE, "completed", "已完成"),
            self._create_collapsed_category_item(ft.Icons.PAUSE_CIRCLE, "paused", "已暂停"),
            self._create_collapsed_category_item(ft.Icons.ERROR, "failed", "失败"),
            
            # 分隔线
            ft.Container(
                height=1,
                bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.ON_SURFACE),
                margin=ft.margin.symmetric(horizontal=12, vertical=8)
            ),
            
            self._create_collapsed_category_item(ft.Icons.VIDEO_FILE, "video", "视频"),
            self._create_collapsed_category_item(ft.Icons.AUDIO_FILE, "audio", "音频"),
            self._create_collapsed_category_item(ft.Icons.IMAGE, "image", "图片"),
            self._create_collapsed_category_item(ft.Icons.DESCRIPTION, "document", "文档"),
            self._create_collapsed_category_item(ft.Icons.ARCHIVE, "archive", "压缩包"),
            self._create_collapsed_category_item(ft.Icons.FOLDER, "other", "其他"),
            
            # 底部弹性空间
            ft.Container(height=50),
            
            # 设置按钮 - Fluent Design风格
            ft.Container(
                content=ft.Row(
                    controls=[
                        ft.Container(
                            width=4,
                            height=40,
                            bgcolor=ft.Colors.TRANSPARENT,
                            border_radius=ft.border_radius.only(
                                top_right=3,
                                bottom_right=3
                            )
                        ),
                        ft.Container(
                            content=ft.IconButton(
                                icon=ft.Icons.SETTINGS,
                                tooltip="设置",
                                on_click=self.on_settings_click,
                                icon_size=18,
                                style=ft.ButtonStyle(
                                    color=ft.Colors.OUTLINE,
                                    bgcolor=ft.Colors.TRANSPARENT
                                )
                            ),
                            width=40,
                            height=40,
                            border_radius=8,
                            alignment=ft.alignment.center
                        )
                    ],
                    spacing=0
                ),
                margin=ft.margin.symmetric(horizontal=8, vertical=4)
            ),
            
            # 关于按钮 - Fluent Design风格
            ft.Container(
                content=ft.Row(
                    controls=[
                        ft.Container(
                            width=4,
                            height=40,
                            bgcolor=ft.Colors.TRANSPARENT,
                            border_radius=ft.border_radius.only(
                                top_right=3,
                                bottom_right=3
                            )
                        ),
                        ft.Container(
                            content=ft.IconButton(
                                icon=ft.Icons.INFO,
                                tooltip="关于",
                                on_click=self.on_about_click,
                                icon_size=18,
                                style=ft.ButtonStyle(
                                    color=ft.Colors.OUTLINE,
                                    bgcolor=ft.Colors.TRANSPARENT
                                )
                            ),
                            width=40,
                            height=40,
                            border_radius=8,
                            alignment=ft.alignment.center
                        )
                    ],
                    spacing=0
                ),
                margin=ft.margin.symmetric(horizontal=8, vertical=4)
            ),
            
            # 底部间距
            ft.Container(height=16)
        ]
        
        # 使用Container包装Column来实现更好的滚动控制，完全隐藏滚动条
        return ft.Container(
            content=ft.Column(
                controls=controls,
                spacing=4,
                expand=True,
                scroll=ft.ScrollMode.HIDDEN,
                auto_scroll=False
            ),
            expand=True,
            clip_behavior=ft.ClipBehavior.HARD_EDGE
        )
    
    def _create_toggle_button_expanded(self):
        """创建展开状态的折叠按钮 - 和其他图标对齐"""
        return ft.Container(
            content=ft.Row(
                controls=[
                    # 左侧蓝色指示条 - 透明（不选中状态）
                    ft.Container(
                        width=4,
                        height=40,
                        bgcolor=ft.Colors.TRANSPARENT,
                        border_radius=ft.border_radius.only(
                            top_right=3,
                            bottom_right=3
                        )
                    ),
                    # 图标按钮区域
                    ft.Container(
                        content=ft.IconButton(
                            icon=ft.Icons.MENU_OPEN,
                            tooltip="折叠侧边栏",
                            on_click=lambda e: self.toggle_sidebar(),
                            icon_size=18,
                            style=ft.ButtonStyle(
                                color=ft.Colors.OUTLINE,
                                bgcolor=ft.Colors.TRANSPARENT
                            )
                        ),
                        width=40,
                        height=40,
                        border_radius=8,
                        alignment=ft.alignment.center
                    ),
                    # 右侧空白区域
                    ft.Container(expand=True)
                ],
                spacing=0
            ),
            margin=ft.margin.symmetric(horizontal=8, vertical=2)
        )

    def _create_collapsed_category_item(self, icon, category, tooltip):
        """创建折叠状态的分类项 - Fluent Design风格"""
        is_selected = self.selected_category == category
        count = self.category_counts.get(category, 0)
        
        return ft.Container(
            content=ft.Row(
                controls=[
                    # 左侧蓝色指示条 - Fluent Design风格
                    ft.Container(
                        width=4,
                        height=40,
                        bgcolor=ft.Colors.BLUE if is_selected else ft.Colors.TRANSPARENT,
                        border_radius=ft.border_radius.only(
                            top_right=3,
                            bottom_right=3
                        ),
                        animate=ft.Animation(400, ft.AnimationCurve.EASE_IN_OUT_CUBIC_EMPHASIZED)
                    ),
                    # 图标按钮区域
                    ft.Container(
                        content=ft.Stack(
                            controls=[
                                # 主图标按钮
                                ft.Container(
                                    content=ft.IconButton(
                                        icon=icon,
                                        tooltip=f"{tooltip} ({count})",
                                        on_click=lambda e, cat=category: self.on_category_click(cat),
                                        icon_size=18,
                                        style=ft.ButtonStyle(
                                            color=ft.Colors.BLUE if is_selected else ft.Colors.OUTLINE,
                                            bgcolor=ft.Colors.TRANSPARENT
                                        )
                                    ),
                                    width=40,
                                    height=40,
                                    bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.BLUE) if is_selected else ft.Colors.TRANSPARENT,
                                    border_radius=8,
                                    alignment=ft.alignment.center,
                                    animate=ft.Animation(350, ft.AnimationCurve.EASE_IN_OUT_CUBIC)
                                ),
                                # 计数徽章 - 根据窗口大小决定是否显示
                                ft.Container(
                                    content=ft.Container(
                                        content=ft.Text(
                                            str(count) if count > 0 and self.current_window_width >= self.min_width_for_counts else "",
                                            size=9,
                                            color=ft.Colors.WHITE,
                                            weight=ft.FontWeight.W_600
                                        ),
                                        bgcolor=ft.Colors.BLUE if count > 0 and self.current_window_width >= self.min_width_for_counts else ft.Colors.TRANSPARENT,
                                        border_radius=8,
                                        padding=ft.padding.symmetric(horizontal=4, vertical=1),
                                        visible=count > 0 and self.current_window_width >= self.min_width_for_counts,
                                        animate=200,
                                        alignment=ft.alignment.center,
                                        width=16 if count > 0 and self.current_window_width >= self.min_width_for_counts else 0,
                                        height=16 if count > 0 and self.current_window_width >= self.min_width_for_counts else 0
                                    ),
                                    right=2,
                                    top=2
                                )
                            ]
                        ),
                        expand=True
                    )
                ],
                spacing=0
            ),
            margin=ft.margin.symmetric(horizontal=8, vertical=2)
        )
    
    def _get_sidebar_width(self):
        """获取侧边栏宽度 - Fluent Design规范"""
        if self.is_collapsed:
            return 56  # Fluent Design标准的折叠宽度
        
        # 根据窗口大小调整宽度 - 更平滑的响应式调整
        width = self.current_window_width
        
        if width < 800:
            return 240
        elif width < 1000:
            return 260
        elif width < 1200:
            return 280
        elif width < 1400:
            return 300
        elif width < 1600:
            return 320
        elif width < 1800:
            return 340
        else:
            return 360
        
        return 320  # 默认宽度