import flet as ft
import webbrowser
import os
from ...utils.path_helper import get_logo_path, get_avatar_path

class AboutPage:
    def __init__(self, page: ft.Page):
        self.page = page
        self.is_visible = False
        self._container = None

    def _open_url(self, url):
        """打开URL链接"""
        try:
            webbrowser.open(url)
        except Exception as e:
            print(f"无法打开链接: {e}")

    def _create_link_card(self, title, description, icon, url, color=ft.Colors.BLUE):
        """创建带链接的卡片 - 支持暗色模式"""
        return ft.Container(
            content=ft.Row(
                controls=[
                    ft.Container(
                        content=ft.Icon(icon, size=24, color=color),
                        width=48,
                        height=48,
                        border_radius=24,
                        bgcolor=ft.Colors.with_opacity(0.1, color),
                        alignment=ft.alignment.center
                    ),
                    ft.Column(
                        controls=[
                            ft.Text(title, size=16, weight=ft.FontWeight.BOLD),
                            ft.Text(description, size=12, color=ft.Colors.ON_SURFACE_VARIANT)
                        ],
                        spacing=2,
                        expand=True
                    ),
                    ft.IconButton(
                        icon=ft.Icons.OPEN_IN_NEW,
                        icon_size=20,
                        tooltip="访问链接",
                        on_click=lambda e: self._open_url(url)
                    )
                ],
                spacing=12
            ),
            padding=ft.padding.all(16),
            border_radius=8,
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT),
            margin=ft.margin.only(bottom=12),
            ink=True,
            on_click=lambda e: self._open_url(url)
        )

    def build(self):
        self._container = ft.Container(
            content=ft.Column(
                controls=[
                    # 标题栏
                    ft.Container(
                        content=ft.Row(
                            controls=[
                                ft.WindowDragArea(
                                    content=ft.Container(
                                        content=ft.Row(
                                            controls=[
                                                ft.Icon(ft.Icons.INFO_OUTLINE, size=24, color=ft.Colors.BLUE),
                                                ft.Text(
                                                    "关于 HDM-X",
                                                    size=24,
                                                    weight=ft.FontWeight.BOLD
                                                )
                                            ],
                                            spacing=12
                                        ),
                                        expand=True
                                    ),
                                    expand=True
                                ),
                                ft.IconButton(
                                    icon=ft.Icons.CLOSE,
                                    icon_size=20,
                                    tooltip="关闭",
                                    on_click=lambda e: self.hide()
                                )
                            ],
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                        ),
                        padding=ft.padding.all(20),
                        border=ft.border.only(
                            bottom=ft.BorderSide(1, ft.Colors.OUTLINE_VARIANT)
                        )
                    ),
                    # 主要内容
                    ft.Container(
                        content=ft.Tabs(
                            selected_index=0,
                            animation_duration=300,
                            indicator_color=ft.Colors.BLUE,
                            label_color=ft.Colors.BLUE,
                            unselected_label_color=ft.Colors.ON_SURFACE_VARIANT,
                            tabs=[
                                # 软件信息标签页
                                ft.Tab(
                                    text="软件信息",
                                    icon=ft.Icons.APPS,
                                    content=ft.Container(
                                        content=ft.Column(
                                            controls=[
                                                # Logo占位区域
                                                ft.Container(
                                                    content=ft.Column(
                                                        controls=[
                                                            ft.Container(
                                                                content=ft.Image(
                                                                    src=r"E:\HDMX\HDMX_0807\gui_examp\src\hdm_x\assets\resources\logo\logo.png",
                                                                    width=150,
                                                                    height=150,
                                                                    fit=ft.ImageFit.CONTAIN,
                                                                    error_content=ft.Icon(
                                                                        ft.Icons.DOWNLOAD_FOR_OFFLINE,
                                                                        size=80,
                                                                        color=ft.Colors.BLUE
                                                                    )
                                                                ),
                                                                
                                                                
                                                                
                                                                
                                                                alignment=ft.alignment.center,
                                                                tooltip="HDM-X Logo",
                                                                
                                                            ),
                                                            ft.Text(
                                                                "Hanabi Download Manager X",
                                                                size=24,
                                                                weight=ft.FontWeight.BOLD,
                                                                text_align=ft.TextAlign.CENTER
                                                            ),
                                                            ft.Text(
                                                                "重新定义下载体验，性能与优雅并存",
                                                                size=14,
                                                                color=ft.Colors.ON_SURFACE_VARIANT,
                                                                text_align=ft.TextAlign.CENTER
                                                            ),
                                                            ft.Container(
                                                                content=ft.Text(
                                                                    "Version 1.0.0[X]",
                                                                    size=12,
                                                                    color=ft.Colors.WHITE,
                                                                    weight=ft.FontWeight.BOLD
                                                                ),
                                                                padding=ft.padding.symmetric(horizontal=16, vertical=8),
                                                                bgcolor=ft.Colors.GREEN,
                                                                border_radius=20,
                                                                margin=ft.margin.only(top=8)
                                                            )
                                                        ],
                                                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                                                        spacing=12
                                                    ),
                                                    alignment=ft.alignment.center,
                                                    margin=ft.margin.only(bottom=24)
                                                ),
                                                
                                                # 技术栈标签
                                                ft.Text("技术栈", size=16, weight=ft.FontWeight.BOLD),
                                                ft.Container(
                                                    content=ft.Row(
                                                        controls=[
                                                            ft.Container(
                                                                content=ft.Text("Python", size=12, color=ft.Colors.WHITE, weight=ft.FontWeight.BOLD),
                                                                padding=ft.padding.symmetric(horizontal=12, vertical=6),
                                                                bgcolor=ft.Colors.BLUE,
                                                                border_radius=16,
                                                                margin=ft.margin.only(right=8, bottom=8)
                                                            ),
                                                            ft.Container(
                                                                content=ft.Text("Rust", size=12, color=ft.Colors.WHITE, weight=ft.FontWeight.BOLD),
                                                                padding=ft.padding.symmetric(horizontal=12, vertical=6),
                                                                bgcolor=ft.Colors.ORANGE,
                                                                border_radius=16,
                                                                margin=ft.margin.only(right=8, bottom=8)
                                                            ),
                                                            ft.Container(
                                                                content=ft.Text("Go", size=12, color=ft.Colors.WHITE, weight=ft.FontWeight.BOLD),
                                                                padding=ft.padding.symmetric(horizontal=12, vertical=6),
                                                                bgcolor=ft.Colors.CYAN,
                                                                border_radius=16,
                                                                margin=ft.margin.only(right=8, bottom=8)
                                                            ),
                                                            ft.Container(
                                                                content=ft.Text("Flet", size=12, color=ft.Colors.WHITE, weight=ft.FontWeight.BOLD),
                                                                padding=ft.padding.symmetric(horizontal=12, vertical=6),
                                                                bgcolor=ft.Colors.PURPLE,
                                                                border_radius=16,
                                                                margin=ft.margin.only(right=8, bottom=8)
                                                            ),
                                                        ],
                                                        wrap=True
                                                    ),
                                                    margin=ft.margin.only(bottom=20)
                                                ),
                                                
                                                # 核心特性
                                                ft.Text("核心特性", size=16, weight=ft.FontWeight.BOLD),
                                                ft.Container(
                                                    content=ft.Column(
                                                        controls=[
                                                            ft.Row(
                                                                controls=[
                                                                    ft.Icon(ft.Icons.SPEED, size=24),
                                                                    ft.Column(
                                                                        controls=[
                                                                            ft.Text("极致性能", size=14, weight=ft.FontWeight.BOLD),
                                                                            ft.Text("NSF-X多引擎架构，Rust/Go/Python三重保障", size=12)
                                                                        ],
                                                                        spacing=2,
                                                                        expand=True
                                                                    )
                                                                ],
                                                                spacing=12
                                                            ),
                                                            ft.Divider(height=16),
                                                            ft.Row(
                                                                controls=[
                                                                    ft.Icon(ft.Icons.DOWNLOAD, size=24),
                                                                    ft.Column(
                                                                        controls=[
                                                                            ft.Text("智能下载", size=14, weight=ft.FontWeight.BOLD),
                                                                            ft.Text("多线程分段下载，断点续传，充分利用带宽", size=12)
                                                                        ],
                                                                        spacing=2,
                                                                        expand=True
                                                                    )
                                                                ],
                                                                spacing=12
                                                            ),
                                                            ft.Divider(height=16),
                                                            ft.Row(
                                                                controls=[
                                                                    ft.Icon(ft.Icons.SECURITY, size=24),
                                                                    ft.Column(
                                                                        controls=[
                                                                            ft.Text("安全可靠", size=14, weight=ft.FontWeight.BOLD),
                                                                            ft.Text("内存安全的Rust内核，完善的错误处理机制", size=12)
                                                                        ],
                                                                        spacing=2,
                                                                        expand=True
                                                                    )
                                                                ],
                                                                spacing=12
                                                            ),
                                                        ]
                                                    ),
                                                    padding=ft.padding.all(16),
                                                    border_radius=8,
                                                    border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT)
                                                )
                                            ],
                                            scroll=ft.ScrollMode.AUTO
                                        ),
                                        padding=ft.padding.all(24),
                                    )
                                ),
                                
                                # 开发者标签页
                                ft.Tab(
                                    text="开发者",
                                    icon=ft.Icons.PERSON,
                                    content=ft.Container(
                                        content=ft.Column(
                                            controls=[
                                                # 开发者信息
                                                ft.Container(
                                                    content=ft.Column(
                                                        controls=[
                                                            ft.Container(
                                                                content=ft.Image(
                                                                    src=r"E:\HDMX\HDMX_0807\gui_examp\src\hdm_x\assets\resources\avatar\normal.jpg",
                                                                    width=80,
                                                                    height=80,
                                                                    fit=ft.ImageFit.COVER,
                                                                    border_radius=ft.border_radius.all(40),
                                                                    error_content=ft.Icon(
                                                                        ft.Icons.ACCOUNT_CIRCLE,
                                                                        size=64,
                                                                        color=ft.Colors.BLUE
                                                                    )
                                                                ),
                                                                width=80,
                                                                height=80,
                                                                border_radius=40,
                                                                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                                                                alignment=ft.alignment.center,
                                                                border=ft.border.all(2, ft.Colors.OUTLINE_VARIANT)
                                                            ),
                                                            ft.Text(
                                                                "ZZBUAOYE",
                                                                size=20,
                                                                weight=ft.FontWeight.BOLD
                                                            ),
                                                            ft.Text(
                                                                "主要开发者 & 项目维护者",
                                                                size=14,
                                                                color=ft.Colors.ON_SURFACE_VARIANT
                                                            )
                                                        ],
                                                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                                                        spacing=8
                                                    ),
                                                    alignment=ft.alignment.center,
                                                    margin=ft.margin.only(bottom=32)
                                                ),
                                                
                                                # 项目鸣谢
                                                ft.Text("项目鸣谢", size=16, weight=ft.FontWeight.BOLD),
                                                ft.Container(
                                                    content=ft.Column(
                                                        controls=[
                                                            ft.Row(
                                                                controls=[
                                                                    ft.Icon(ft.Icons.FAVORITE, size=20, color=ft.Colors.RED),
                                                                    ft.Text("感谢开源社区的无私贡献", size=14)
                                                                ],
                                                                spacing=8
                                                            ),
                                                            ft.Row(
                                                                controls=[
                                                                    ft.Icon(ft.Icons.ROCKET_LAUNCH, size=20, color=ft.Colors.ORANGE),
                                                                    ft.Text("感谢Rust、Go、Python社区的技术支持", size=14)
                                                                ],
                                                                spacing=8
                                                            ),
                                                            ft.Row(
                                                                controls=[
                                                                    ft.Icon(ft.Icons.LIGHTBULB, size=20, color=ft.Colors.YELLOW),
                                                                    ft.Text("感谢所有测试用户的反馈和建议", size=14)
                                                                ],
                                                                spacing=8
                                                            ),
                                                            ft.Row(
                                                                controls=[
                                                                    ft.Icon(ft.Icons.PEOPLE, size=20, color=ft.Colors.BLUE),
                                                                    ft.Text("感谢每一位关注和支持HDM-X的朋友", size=14)
                                                                ],
                                                                spacing=8
                                                            ),
                                                        ],
                                                        spacing=12
                                                    ),
                                                    padding=ft.padding.all(16),
                                                    border_radius=8,
                                                    bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                                                    border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT)
                                                )
                                            ],
                                            scroll=ft.ScrollMode.AUTO
                                        ),
                                        padding=ft.padding.all(24),
                                    )
                                ),
                                
                                # 许可证标签页
                                ft.Tab(
                                    text="许可证",
                                    icon=ft.Icons.GAVEL,
                                    content=ft.Container(
                                        content=ft.Column(
                                            controls=[
                                                # HDM-X项目
                                                self._create_link_card(
                                                    "HDM-X 项目",
                                                    "Hanabi Download Manager X - GitHub仓库",
                                                    ft.Icons.CODE,
                                                    "https://github.com/buaoyezz/Hanabi-Download-Manager-X",
                                                    ft.Colors.BLACK
                                                ),
                                                
                                                # MIT许可证
                                                self._create_link_card(
                                                    "MIT License",
                                                    "开源、自由、商业友好的许可证",
                                                    ft.Icons.VERIFIED,
                                                    "https://github.com/buaoyezz/Hanabi-Download-Manager-X/blob/main/LICENSE",
                                                    ft.Colors.GREEN
                                                ),
                                                
                                                # Flet框架
                                                self._create_link_card(
                                                    "Flet Framework",
                                                    "现代化的Python GUI框架 - Apache License 2.0",
                                                    ft.Icons.FLUTTER_DASH,
                                                    "https://flet.dev",
                                                    ft.Colors.PURPLE
                                                ),
                                                
                                                # Flet许可证
                                                self._create_link_card(
                                                    "Flet License",
                                                    "Flet框架的开源许可证",
                                                    ft.Icons.DESCRIPTION,
                                                    "https://github.com/flet-dev/flet",
                                                    ft.Colors.PURPLE
                                                ),
                                                
                                                # HDMX官网
                                                self._create_link_card(
                                                    "HDMX 官网",
                                                    "HDM-X官方网站 - 获取最新信息",
                                                    ft.Icons.WEB,
                                                    "https://X.ZZBUAOYE.TOP",
                                                    ft.Colors.BLUE
                                                ),
                                                
                                                # 许可证声明
                                                ft.Container(
                                                    content=ft.Column(
                                                        controls=[
                                                            ft.Row(
                                                                controls=[
                                                                    ft.Icon(ft.Icons.DESCRIPTION, size=20, color=ft.Colors.BLUE),
                                                                    ft.Text("许可证声明", size=14, weight=ft.FontWeight.BOLD)
                                                                ],
                                                                spacing=8
                                                            ),
                                                            ft.Text(
                                                                "本软件基于MIT许可证发布，您可以自由使用、修改和分发。"
                                                                "详细条款请参阅项目根目录下的LICENSE文件。",
                                                                size=12,
                                                                color=ft.Colors.ON_SURFACE_VARIANT
                                                            ),
                                                            ft.Text(
                                                                "使用的第三方库均遵循其各自的开源许可证。",
                                                                size=12,
                                                                color=ft.Colors.ON_SURFACE_VARIANT
                                                            )
                                                        ],
                                                        spacing=8
                                                    ),
                                                    padding=ft.padding.all(16),
                                                    border_radius=8,
                                                    bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                                                    border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT),
                                                    margin=ft.margin.only(top=12)
                                                )
                                            ],
                                            scroll=ft.ScrollMode.AUTO
                                        ),
                                        padding=ft.padding.all(24),
                                    )
                                ),
                            ],
                            expand=True
                        ),
                        expand=True
                    )
                ],
                spacing=0
            ),
            visible=self.is_visible,
            expand=True,
            bgcolor=ft.Colors.SURFACE,
            border_radius=12,
            border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT)
        )
        return self._container

    def show(self):
        self.is_visible = True
        if self._container:
            self._container.visible = True
        self.page.update()

    def hide(self):
        self.is_visible = False
        if self._container:
            self._container.visible = False
        self.page.update()