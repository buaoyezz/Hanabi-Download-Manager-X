"""
引擎设置组件
允许用户选择和切换下载引擎
"""

import flet as ft
import asyncio
import os
import sys
from pathlib import Path
from ...core.managers.data_manager_unified import get_data_manager
from ...utils.logger import logger
from ...utils.pathUtils import getDefaultDownloadPath


class EngineSettingsCard(ft.Container):
    """引擎设置卡片"""
    
    def __init__(self, page: ft.Page, font_manager):
        super().__init__()
        self.page = page
        self.font_manager = font_manager
        self.data_manager = get_data_manager()
        if hasattr(self.data_manager, "initialize_async"):
            self.data_manager.initialize_async()
        
        # 引擎选择
        self.engine_dropdown = None
        self.engine_info_container = None
        self.switch_button = None
        self.status_text = None
        
        # 当前引擎信息
        self.current_engine_info = {}
        
        # 自动初始化引擎信息
        self._initialize_engine_info()
        
        # 目录选择器与显示
        self.dir_picker = ft.FilePicker(on_result=self.on_pick_dir)
        current_dir = self.data_manager.get_settings().get('download_dir', getDefaultDownloadPath())
        self.download_dir_display = ft.Text(current_dir, size=12, color=ft.Colors.ON_SURFACE_VARIANT)
        if self.dir_picker not in self.page.overlay:
            self.page.overlay.append(self.dir_picker)
        
        # 构建界面
        self.build()
    
    def build(self):
        """构建引擎设置界面"""
        # 获取引擎信息
        tmp_info = self.data_manager.get_engine_info()
        if tmp_info:
            self.current_engine_info = tmp_info
        current_engine = self.data_manager.get_settings().get('download_engine', 'go')
        if current_engine not in self.current_engine_info:
            current_engine = next(iter(self.current_engine_info.keys()), 'go')
        
        # 引擎选择下拉框
        engine_options = []
        for engine_key, info in self.current_engine_info.items():
            # 使用图标+文字状态
            if info['available']:
                status_icon = "✅"
                status_text = "可用"
            else:
                status_icon = "❌"
                status_text = "不可用"
            
            engine_options.append(
                ft.dropdown.Option(
                    key=engine_key,
                    text=f"{status_icon} {info['name']} ({status_text})"
                )
            )
        
        self.engine_dropdown = ft.Dropdown(
            label="选择下载引擎",
            value=current_engine,
            options=engine_options,
            on_change=self.on_engine_change,
            width=300
        )
        
        # 引擎信息显示
        self.engine_info_container = ft.Container(
            content=self._build_engine_info(current_engine),
            padding=ft.padding.all(16),
            bgcolor=ft.Colors.SURFACE,
            border_radius=8,
            margin=ft.margin.only(top=16)
        )
        
        # 切换按钮
        self.switch_button = ft.ElevatedButton(
            text="应用更改",
            icon=ft.Icons.SWAP_HORIZ,
            on_click=self.on_switch_engine,
            disabled=True
        )
        
        # 状态文本
        self.status_text = ft.Text(
            "",
            size=12,
            color=ft.Colors.ON_SURFACE_VARIANT
        )
        
        card = ft.Card(
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        # 标题
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.SETTINGS_APPLICATIONS, size=24),
                                ft.Text(
                                    "下载引擎设置",
                                    size=18,
                                    weight=ft.FontWeight.BOLD
                                )
                            ],
                            spacing=8
                        ),
                        
                        ft.Divider(),
                        
                        # 引擎选择
                        ft.Text("选择下载引擎:", size=14, weight=ft.FontWeight.W_500),
                        self.engine_dropdown,
                        
                        # 引擎信息
                        self.engine_info_container,
                        
                        # 操作按钮
                        ft.Row(
                            controls=[
                                self.switch_button,
                                ft.TextButton(
                                    text="刷新状态",
                                    icon=ft.Icons.REFRESH,
                                    on_click=self.on_refresh_status
                                ),
                                ft.ElevatedButton(
                                    text="🔨 编译引擎",
                                    icon=ft.Icons.BUILD,
                                    on_click=self.on_compile_engine,
                                    bgcolor=ft.Colors.ORANGE,
                                    color=ft.Colors.WHITE
                                )
                            ],
                            spacing=16
                        ),
                        
                        ft.Column(
                            controls=[
                                ft.Text("下载目录", size=14, weight=ft.FontWeight.W_500),
                                ft.Row(
                                    controls=[
                                        self.download_dir_display,
                                        ft.TextButton(
                                            text="选择目录",
                                            icon=ft.Icons.FOLDER_OPEN,
                                            on_click=lambda e: self.dir_picker.get_directory_path()
                                        ),
                                        ft.TextButton(
                                            text="打开目录",
                                            icon=ft.Icons.FOLDER,
                                            on_click=self.on_open_download_dir
                                        )
                                    ],
                                    spacing=12
                                )
                            ],
                            spacing=8
                        ),
                        
                        # 状态信息
                        self.status_text,
                        
                        # 性能对比
                        self._build_performance_comparison()
                    ],
                    spacing=16
                ),
                padding=ft.padding.all(20)
            ),
            elevation=2
        )
        
        self.content = card
    
    def _initialize_engine_info(self):
        """初始化引擎信息"""
        try:
            self.current_engine_info = self.data_manager.get_engine_info()
            if not self.current_engine_info:
                # 如果没有引擎信息，提供默认信息
                self.current_engine_info = {
                    'go': {
                        'name': 'NSF-X Go引擎',
                        'description': '新一代NSF-X内核，Go语言实现，高性能且易维护',
                        'performance_score': 5,
                        'stability_score': 5,
                        'available': True,
                        'status': '可用',
                        'current': True
                    },

                    'python': {
                        'name': 'Python引擎',
                        'description': '纯Python实现，兼容性最好，易于调试',
                        'performance_score': 3,
                        'stability_score': 4,
                        'available': True,
                        'status': '可用',
                        'current': False
                    }
                }
        except Exception as e:
            logger.error(f"初始化引擎信息失败: {e}")
            # 提供默认信息
            self.current_engine_info = {
                'go': {
                    'name': 'NSF-X Go引擎',
                    'description': '新一代NSF-X内核，Go语言实现，高性能且易维护',
                    'performance_score': 5,
                    'stability_score': 5,
                    'available': True,
                    'status': '可用',
                    'current': True
                }
            }
    
    def _build_engine_info(self, engine_key: str) -> ft.Control:
        """构建引擎信息显示"""
        if engine_key not in self.current_engine_info:
            return ft.Text("引擎信息不可用", color=ft.Colors.ERROR)
        
        info = self.current_engine_info[engine_key]
        
        # 状态颜色和图标
        if info['available']:
            status_color = ft.Colors.GREEN
            status_icon = "✅"
        else:
            status_color = ft.Colors.RED
            status_icon = "❌"
        
        # 性能星级
        def create_stars(score):
            stars = []
            for i in range(5):
                if i < score:
                    stars.append(ft.Icon(ft.Icons.STAR, size=16, color=ft.Colors.AMBER))
                else:
                    stars.append(ft.Icon(ft.Icons.STAR_BORDER, size=16, color=ft.Colors.GREY))
            return ft.Row(controls=stars, spacing=2)
        
        return ft.Column(
            controls=[
                # 引擎名称和状态
                ft.Row(
                    controls=[
                        ft.Text(
                            info['name'],
                            size=16,
                            weight=ft.FontWeight.BOLD
                        ),
                        ft.Container(
                            content=ft.Row(
                                controls=[
                                    ft.Text(
                                        status_icon,
                                        size=12,
                                        color=ft.Colors.WHITE
                                    ),
                                    ft.Text(
                                        info['status'],
                                        size=12,
                                        color=ft.Colors.WHITE
                                    )
                                ],
                                spacing=4,
                                tight=True
                            ),
                            bgcolor=status_color,
                            padding=ft.padding.symmetric(horizontal=8, vertical=4),
                            border_radius=12
                        )
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN
                ),
                
                # 描述
                ft.Text(
                    info['description'],
                    size=12,
                    color=ft.Colors.ON_SURFACE_VARIANT
                ),
                
                # 性能评分
                ft.Row(
                    controls=[
                        ft.Column(
                            controls=[
                                ft.Text("性能", size=12, weight=ft.FontWeight.W_500),
                                create_stars(info['performance_score'])
                            ],
                            spacing=4
                        ),
                        ft.Column(
                            controls=[
                                ft.Text("稳定性", size=12, weight=ft.FontWeight.W_500),
                                create_stars(info['stability_score'])
                            ],
                            spacing=4
                        )
                    ],
                    spacing=32
                ),
                
                # 当前状态
                ft.Row(
                    controls=[
                        ft.Icon(
                            ft.Icons.RADIO_BUTTON_CHECKED if info['current'] else ft.Icons.RADIO_BUTTON_UNCHECKED,
                            size=16,
                            color=ft.Colors.BLUE if info['current'] else ft.Colors.GREY
                        ),
                        ft.Text(
                            "当前使用" if info['current'] else "未使用",
                            size=12,
                            color=ft.Colors.BLUE if info['current'] else ft.Colors.GREY
                        )
                    ],
                    spacing=4
                )
            ],
            spacing=8
        )
    
    def _build_performance_comparison(self) -> ft.Control:
        """构建性能对比表"""
        if not self.current_engine_info:
            return ft.Container(
                content=ft.Text("暂无引擎信息", color=ft.Colors.ON_SURFACE_VARIANT),
                margin=ft.margin.only(top=16)
            )
        
        # 创建数据行
        data_rows = []
        for engine_key, info in self.current_engine_info.items():
            # 使用图标而不是emoji
            status_icon = ft.Icon(
                ft.Icons.CHECK_CIRCLE if info['available'] else ft.Icons.CANCEL,
                size=16,
                color=ft.Colors.GREEN if info['available'] else ft.Colors.RED
            )
            
            # 当前使用标识
            current_icon = ft.Icon(
                ft.Icons.RADIO_BUTTON_CHECKED if info.get('current', False) else ft.Icons.RADIO_BUTTON_UNCHECKED,
                size=16,
                color=ft.Colors.BLUE if info.get('current', False) else ft.Colors.GREY
            )
            
            data_rows.append(
                ft.DataRow(
                    cells=[
                        ft.DataCell(
                            ft.Row([
                                current_icon,
                                ft.Text(info['name'], size=12)
                            ], spacing=8)
                        ),
                        ft.DataCell(ft.Text(f"{info['performance_score']}/5", size=12)),
                        ft.DataCell(ft.Text(f"{info['stability_score']}/5", size=12)),
                        ft.DataCell(
                            ft.Row([
                                status_icon,
                                ft.Text(info['status'], size=12)
                            ], spacing=4)
                        )
                    ]
                )
            )
        
        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Text(
                        "引擎性能对比",
                        size=14,
                        weight=ft.FontWeight.W_500
                    ),
                    ft.DataTable(
                        columns=[
                            ft.DataColumn(ft.Text("引擎", size=12, weight=ft.FontWeight.BOLD)),
                            ft.DataColumn(ft.Text("性能", size=12, weight=ft.FontWeight.BOLD)),
                            ft.DataColumn(ft.Text("稳定性", size=12, weight=ft.FontWeight.BOLD)),
                            ft.DataColumn(ft.Text("状态", size=12, weight=ft.FontWeight.BOLD))
                        ],
                        rows=data_rows,
                        border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT),
                        border_radius=8,
                        vertical_lines=ft.border.BorderSide(1, ft.Colors.OUTLINE_VARIANT),
                        horizontal_lines=ft.border.BorderSide(1, ft.Colors.OUTLINE_VARIANT)
                    )
                ],
                spacing=8
            ),
            margin=ft.margin.only(top=16)
        )
    
    def on_engine_change(self, e):
        """引擎选择改变"""
        selected_engine = e.control.value
        current_engine = self.data_manager.get_settings().get('download_engine', 'go')
        
        # 更新引擎信息显示
        self.engine_info_container.content = self._build_engine_info(selected_engine)
        
        # 启用/禁用切换按钮
        self.switch_button.disabled = (selected_engine == current_engine)
        
        # 更新状态文本
        if selected_engine != current_engine:
            self.status_text.value = f"将切换到: {self.current_engine_info[selected_engine]['name']}"
            self.status_text.color = ft.Colors.ORANGE
        else:
            self.status_text.value = "当前引擎"
            self.status_text.color = ft.Colors.GREEN
        
        self.update()
    
    def on_switch_engine(self, e):
        """切换引擎"""
        selected_engine = self.engine_dropdown.value
        
        if not selected_engine:
            self.show_error("请先选择要切换的引擎")
            return
        
        engine_info = self.current_engine_info.get(selected_engine, {})
        if not engine_info.get('available', False):
            engine_name = engine_info.get('name', selected_engine)
            status = engine_info.get('status', '未知状态')
            
            # 提供编译建议
            if status == "需要编译":
                self.show_compile_suggestion(engine_name, selected_engine)
            else:
                self.show_error(f"❌ {engine_name} 不可用\n状态: {status}\n请检查安装或尝试编译")
            return
        
        # 显示加载状态
        self.switch_button.disabled = True
        self.switch_button.text = "切换中..."
        self.status_text.value = "正在切换引擎，请稍候..."
        self.status_text.color = ft.Colors.BLUE
        self.update()
        
        # 异步切换引擎
        self._run_async(self._switch_engine_async(selected_engine))
    
    def _run_async(self, coro):
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(coro)
        except RuntimeError:
            import threading
            def runner():
                asyncio.run(coro)
            threading.Thread(target=runner, daemon=True).start()
    
    async def _switch_engine_async(self, engine_key: str):
        """异步切换引擎"""
        try:
            # 切换引擎
            success = await self.data_manager.switch_engine(engine_key)
            
            if success:
                # 更新设置
                settings = self.data_manager.get_settings()
                settings['download_engine'] = engine_key
                self.data_manager.update_settings(settings)
                
                # 更新UI状态
                self.status_text.value = f"✅ 成功切换到 {self.current_engine_info[engine_key]['name']}"
                self.status_text.color = ft.Colors.GREEN
                self.switch_button.disabled = True
                
                # 刷新引擎信息
                self.on_refresh_status(None)
                
                logger.info(f"用户切换引擎到: {engine_key}")
            else:
                self.status_text.value = "❌ 引擎切换失败"
                self.status_text.color = ft.Colors.ERROR
                
        except Exception as ex:
            self.status_text.value = f"❌ 切换失败: {str(ex)}"
            self.status_text.color = ft.Colors.ERROR
            logger.error(f"引擎切换异常: {ex}")
        
        finally:
            # 恢复按钮状态
            self.switch_button.text = "应用更改"
            self.switch_button.disabled = False
            self.update()
    
    def on_refresh_status(self, e):
        """刷新引擎状态"""
        self.status_text.value = "正在刷新核心状态..."
        self.status_text.color = ft.Colors.BLUE
        self.update()

        async def do_refresh():
            try:
                if not getattr(self.data_manager, "is_initialized", False):
                    if hasattr(self.data_manager, "initialize_async"):
                        self.data_manager.initialize_async()
                    for _ in range(20):
                        await asyncio.sleep(0.25)
                        if getattr(self.data_manager, "is_initialized", False):
                            break

                tmp_info = self.data_manager.get_engine_info()
                if not tmp_info:
                    self.status_text.value = "未获取到核心信息，请稍后重试"
                    self.status_text.color = ft.Colors.ERROR
                    self.update()
                    return

                self.current_engine_info = tmp_info

                engine_options = []
                for engine_key, info in self.current_engine_info.items():
                    if info['available']:
                        status_icon = "✅"
                        status_text = "可用"
                    else:
                        status_icon = "❌"
                        status_text = "不可用"
                    engine_options.append(
                        ft.dropdown.Option(
                            key=engine_key,
                            text=f"{status_icon} {info['name']} ({status_text})"
                        )
                    )

                self.engine_dropdown.options = engine_options

                current_selection = self.engine_dropdown.value
                if current_selection:
                    self.engine_info_container.content = self._build_engine_info(current_selection)

                self.status_text.value = "✅ 状态已刷新"
                self.status_text.color = ft.Colors.GREEN
                self.update()

            except Exception as ex:
                self.show_error(f"刷新状态失败: {str(ex)}")

        self._run_async(do_refresh())
    
    def show_error(self, message: str):
        """显示错误信息"""
        self.status_text.value = f"❌ {message}"
        self.status_text.color = ft.Colors.ERROR
        self.update()
        
        # 显示错误对话框
        def close_dialog(e):
            dialog.open = False
            self.page.update()
        
        dialog = ft.AlertDialog(
            title=ft.Row([
                ft.Icon(ft.Icons.ERROR, color=ft.Colors.ERROR),
                ft.Text("错误")
            ], spacing=8),
            content=ft.Text(message),
            actions=[
                ft.TextButton("确定", on_click=close_dialog)
            ]
        )
        
        self.page.dialog = dialog
        dialog.open = True
        self.page.update()
    
    def show_compile_suggestion(self, engine_name: str, engine_key: str):
        """显示编译建议对话框"""
        self.status_text.value = f"⚠️ {engine_name} 需要编译"
        self.status_text.color = ft.Colors.ORANGE
        self.update()
        
        def close_dialog(e):
            dialog.open = False
            self.page.update()
        
        def start_compile(e):
            dialog.open = False
            self.page.update()
            self._start_compile(engine_key)
        
        dialog = ft.AlertDialog(
            title=ft.Row([
                ft.Icon(ft.Icons.WARNING, color=ft.Colors.ORANGE),
                ft.Text("引擎需要编译")
            ], spacing=8),
            content=ft.Column([
                ft.Text(f"{engine_name} 尚未编译，无法使用。"),
                ft.Text("您可以选择:", weight=ft.FontWeight.BOLD),
                ft.Text("• 点击'立即编译'自动编译引擎"),
                ft.Text("• 点击'取消'选择其他可用引擎")
            ], spacing=8, tight=True),
            actions=[
                ft.TextButton("取消", on_click=close_dialog),
                ft.ElevatedButton(
                    "🔨 立即编译",
                    icon=ft.Icons.BUILD,
                    on_click=start_compile,
                    bgcolor=ft.Colors.ORANGE,
                    color=ft.Colors.WHITE
                )
            ]
        )
        
        self.page.dialog = dialog
        dialog.open = True
        self.page.update()
    
    def on_compile_engine(self, e):
        """编译引擎"""
        selected_engine = self.engine_dropdown.value
        if not selected_engine:
            self.show_error("请先选择要编译的引擎")
            return
        
        engine_info = self.current_engine_info.get(selected_engine, {})
        if engine_info.get('available', False):
            self.show_info(f"✅ {engine_info['name']} 已经可用，无需编译")
            return
        
        # 显示编译确认对话框
        def confirm_compile(e):
            dialog.open = False
            self.page.update()
            self._start_compile(selected_engine)
        
        def cancel_compile(e):
            dialog.open = False
            self.page.update()
        
        dialog = ft.AlertDialog(
            title=ft.Row([
                ft.Icon(ft.Icons.BUILD, color=ft.Colors.ORANGE),
                ft.Text("编译引擎")
            ], spacing=8),
            content=ft.Column([
                ft.Text(f"确定要编译 {engine_info.get('name', selected_engine)} 吗？"),
                ft.Text("编译过程可能需要几分钟时间。", size=12, color=ft.Colors.ON_SURFACE_VARIANT)
            ], spacing=8, tight=True),
            actions=[
                ft.TextButton("取消", on_click=cancel_compile),
                ft.ElevatedButton(
                    "🔨 开始编译",
                    icon=ft.Icons.BUILD,
                    on_click=confirm_compile,
                    bgcolor=ft.Colors.ORANGE,
                    color=ft.Colors.WHITE
                )
            ]
        )
        
        self.page.dialog = dialog
        dialog.open = True
        self.page.update()
    
    def _start_compile(self, engine_key: str):
        """开始编译引擎"""
        self.status_text.value = f"🔨 正在编译 {self.current_engine_info[engine_key]['name']}..."
        self.status_text.color = ft.Colors.ORANGE
        self.update()
        
        # 异步编译
        self._run_async(self._compile_engine_async(engine_key))
    
    async def _compile_engine_async(self, engine_key: str):
        """异步编译引擎"""
        try:
            if engine_key == 'go':
                success = await self._compile_go_engine()
            else:
                success = False
                self.status_text.value = f"❌ 不支持编译 {engine_key} 引擎"
                self.status_text.color = ft.Colors.ERROR
                self.update()
                return
            
            if success:
                self.status_text.value = f"✅ {self.current_engine_info[engine_key]['name']} 编译成功"
                self.status_text.color = ft.Colors.GREEN
                # 刷新引擎状态
                self.on_refresh_status(None)
            else:
                self.status_text.value = f"❌ {self.current_engine_info[engine_key]['name']} 编译失败"
                self.status_text.color = ft.Colors.ERROR
                
        except Exception as ex:
            self.status_text.value = f"❌ 编译异常: {str(ex)}"
            self.status_text.color = ft.Colors.ERROR
            logger.error(f"编译引擎异常: {ex}")
        
        self.update()
    

    
    async def _compile_go_engine(self) -> bool:
        """编译Go引擎"""
        try:
            import subprocess
            
            # 获取Go项目路径
            go_path = Path(__file__).parent.parent.parent / "core" / "download_engine" / "go_engine"
            if not go_path.exists():
                logger.error(f"Go项目路径不存在: {go_path}")
                return False
            
            # 执行编译命令
            process = await asyncio.create_subprocess_exec(
                "go", "build", "-o", "hdm-x-engine.exe", ".",
                cwd=str(go_path),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                logger.info("Go引擎编译成功")
                return True
            else:
                logger.error(f"Go引擎编译失败: {stderr.decode()}")
                return False
                
        except Exception as e:
            logger.error(f"编译Go引擎异常: {e}")
            return False
    
    def show_info(self, message: str):
        """显示信息"""
        self.status_text.value = message
        self.status_text.color = ft.Colors.BLUE
        self.update()
    
    def on_pick_dir(self, e: ft.FilePickerResultEvent):
        try:
            if hasattr(e, "path") and e.path:
                p = e.path
                s = self.data_manager.get_settings()
                s["download_dir"] = p
                self.data_manager.update_settings(s)
                self.download_dir_display.value = p
                self.status_text.value = "已更新下载目录"
                self.status_text.color = ft.Colors.GREEN
                self.update()
        except Exception as ex:
            self.show_error(str(ex))
    
    def on_open_download_dir(self, e):
        try:
            p = self.data_manager.get_settings().get("download_dir", getDefaultDownloadPath())
            if os.name == "nt":
                os.startfile(p)
            elif sys.platform == "darwin":
                import subprocess
                subprocess.Popen(["open", p])
            else:
                import subprocess
                subprocess.Popen(["xdg-open", p])
        except Exception as ex:
            self.show_error(str(ex))
