"""
一言组件 - 显示来自 xiaoy.asia 的随机句子
"""

import flet as ft
import requests
import threading
import time
from ...utils.logger import logger


class HitokotoWidget:
    def __init__(self, font_manager):
        self.font_manager = font_manager
        self.hitokoto_text = ""  # 不显示任何内容
        self.container = None
        self.is_loading = False
        self.last_fetch_time = 0
        self.fetch_interval = 30  # 30秒刷新间隔
        
    def fetch_hitokoto(self, callback=None):
        """异步获取一言数据 - 已注释，强制显示菜单栏"""
        # 注释掉网络请求部分，不显示任何内容
        self.hitokoto_text = ""
        if callback:
            callback()
        
        # # 原始的网络请求代码（已注释）
        # if self.is_loading:
        #     return
        #     
        # current_time = time.time()
        # if current_time - self.last_fetch_time < self.fetch_interval:
        #     return
        #     
        # self.is_loading = True
        # 
        # def _fetch():
        #     try:
        #         response = requests.get(
        #             "https://api.xiaoy.asia/api/v1/",
        #             params={"name": "saying"},
        #             timeout=5
        #         )
        #         
        #         if response.status_code == 200:
        #             # 新API直接返回文本，不是JSON
        #             self.hitokoto_text = response.text.strip()
        #             self.last_fetch_time = current_time
        #             logger.debug(f"一言获取成功: {self.hitokoto_text}")
        #         else:
        #             self.hitokoto_text = "网络连接失败"
        #             
        #     except requests.exceptions.Timeout:
        #         self.hitokoto_text = "请求超时"
        #         logger.warning("一言请求超时")
        #     except Exception as e:
        #         self.hitokoto_text = "获取失败"
        #         logger.error(f"一言获取失败: {e}")
        #     finally:
        #         self.is_loading = False
        #         if callback:
        #             callback()
        # 
        # # 在新线程中执行请求
        # thread = threading.Thread(target=_fetch, daemon=True)
        # thread.start()
    
    def on_click_refresh(self, e):
        """点击刷新按钮 - 已注释，强制显示菜单栏"""
        # 注释掉刷新功能，不显示任何内容
        self.hitokoto_text = ""
        if self.container:
            self.update_content()
        
        # # 原始的刷新代码（已注释）
        # if not self.is_loading:
        #     self.hitokoto_text = "刷新中..."
        #     if self.container:
        #         self.update_content()
        #     self.fetch_hitokoto(self.update_content)
    
    def update_content(self):
        """更新显示内容"""
        if self.container:
            self.container.content = self._build_content()
            if hasattr(self.container, 'page') and self.container.page:
                self.container.page.update()
    
    def _build_content(self):
        """构建一言显示内容 - 分层布局"""
        # 分割一言文本为两行（如果文本较长）
        lines = self._split_text_into_lines(self.hitokoto_text)
        
        # 创建文本控件列表
        text_controls = []
        for i, line in enumerate(lines):
            if line.strip():  # 只添加非空行
                # 第一行：『开头
                # 中间行：逐渐增加缩进
                # 最后一行：』结尾
                if i == 0:
                    # 第一行
                    display_text = f"『{line.strip()}"
                    if len(lines) == 1:  # 只有一行时直接加结尾
                        display_text += "』"
                    margin_left = 0
                elif i == len(lines) - 1:
                    # 最后一行
                    display_text = f"{line.strip()}』"
                    # 最后一行的缩进根据行数调整
                    margin_left = min(8 + (i - 1) * 4, 20)
                else:
                    # 中间行
                    display_text = line.strip()
                    # 中间行逐渐增加缩进，营造层次感
                    margin_left = min(8 + (i - 1) * 4, 20)
                
                text_controls.append(
                    ft.Container(
                        content=self.font_manager.create_text(
                            display_text,
                            "small",
                            color=ft.Colors.ON_SURFACE,
                            weight=ft.FontWeight.W_400,
                            text_align=ft.TextAlign.LEFT
                        ),
                        padding=ft.padding.symmetric(horizontal=2, vertical=0),
                        margin=ft.margin.only(left=margin_left)
                    )
                )
        
        return ft.Container(
            content=ft.Column(
                controls=text_controls,
                spacing=2,
                tight=True,
                alignment=ft.MainAxisAlignment.START
            ),
            expand=True,
            padding=ft.padding.symmetric(horizontal=4, vertical=2)
        )
    
    def _split_text_into_lines(self, text, max_length=18):
        """将文本智能分割为多行"""
        if not text:
            return [text]
        
        # 如果文本不长，直接返回
        if len(text) <= max_length:
            return [text]
        
        lines = []
        remaining_text = text
        
        # 分割标点符号
        break_chars = ['，', '。', '！', '？', '；', '：', ',', '.', '!', '?', ';', ':', ' ']
        
        while len(remaining_text) > max_length:
            # 寻找最佳分割点
            best_split = max_length
            
            # 在合理范围内寻找标点符号
            search_start = max(max_length - 8, max_length // 2)
            search_end = min(max_length + 4, len(remaining_text))
            
            for i in range(search_end - 1, search_start - 1, -1):
                if i < len(remaining_text) and remaining_text[i] in break_chars:
                    best_split = i + 1
                    break
            
            # 如果没找到合适的分割点，就按最大长度分割
            if best_split == max_length and len(remaining_text) > max_length:
                # 避免在单词中间分割（对英文）
                for i in range(max_length - 1, max_length - 6, -1):
                    if i < len(remaining_text) and remaining_text[i] == ' ':
                        best_split = i + 1
                        break
            
            # 添加当前行
            current_line = remaining_text[:best_split].strip()
            if current_line:
                lines.append(current_line)
            
            # 更新剩余文本
            remaining_text = remaining_text[best_split:].strip()
        
        # 添加最后一行
        if remaining_text:
            lines.append(remaining_text)
        
        # 如果分行太多，合并一些短行
        if len(lines) > 4:
            lines = self._merge_short_lines(lines, max_length)
        
        return lines
    
    def _merge_short_lines(self, lines, max_length):
        """合并过短的行"""
        if len(lines) <= 2:
            return lines
        
        merged_lines = []
        i = 0
        
        while i < len(lines):
            current_line = lines[i]
            
            # 如果当前行很短，尝试与下一行合并
            if i + 1 < len(lines) and len(current_line) + len(lines[i + 1]) <= max_length:
                merged_line = current_line + lines[i + 1]
                merged_lines.append(merged_line)
                i += 2
            else:
                merged_lines.append(current_line)
                i += 1
        
        return merged_lines
    
    def build(self):
        """构建一言组件 - 无背景分层布局"""
        self.container = ft.Container(
            content=self._build_content(),
            padding=ft.padding.all(6),
            margin=ft.margin.symmetric(horizontal=4, vertical=2),
            # 去掉背景和边框
            bgcolor=ft.Colors.TRANSPARENT,
            animate=ft.Animation(200, ft.AnimationCurve.EASE_OUT)
        )
        
        # 初始化时获取一言
        self.fetch_hitokoto(self.update_content)
        
        return self.container