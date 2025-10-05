"""
FontManager

"""

import flet as ft
import json
import os


class FontManager:
    
    def __init__(self, page: ft.Page):
        self.page = page
        self.config_file = "config/font_config.json"
        self.default_config = {
            "font_family": "Microsoft YaHei",
            "font_size": {
                "small": 12,
                "normal": 14,
                "large": 16,
                "title": 18,
                "header": 20
            },
            "font_weight": {
                "normal": "normal",
                "medium": "w_500",
                "bold": "bold"
            }
        }
        self.config = self.load_config()
        self.font_change_callbacks = []  # 添加字体变更回调列表
        
    def load_config(self):
        """加载字体配置"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                    # 合并默认配置，确保所有键都存在
                    for key, value in self.default_config.items():
                        if key not in config:
                            config[key] = value
                        elif isinstance(value, dict):
                            for subkey, subvalue in value.items():
                                if subkey not in config[key]:
                                    config[key][subkey] = subvalue
                    return config
            else:
                return self.default_config.copy()
        except Exception:
            return self.default_config.copy()
            
    def save_config(self):
        """保存字体配置"""
        try:
            os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, ensure_ascii=False, indent=2)
        except Exception:
            pass
            
    def get_font_family(self):
        """获取字体族"""
        return self.config["font_family"]
        
    def get_font_size(self, size_type="normal"):
        """获取字体大小"""
        return self.config["font_size"].get(size_type, 14)
        
    def get_font_weight(self, weight_type="normal"):
        """获取字体粗细"""
        weight_map = {
            "normal": ft.FontWeight.NORMAL,
            "w_500": ft.FontWeight.W_500,
            "bold": ft.FontWeight.BOLD
        }
        weight_str = self.config["font_weight"].get(weight_type, "normal")
        return weight_map.get(weight_str, ft.FontWeight.NORMAL)
        
    def add_font_change_callback(self, callback):
        """添加字体变更回调"""
        self.font_change_callbacks.append(callback)
    
    def remove_font_change_callback(self, callback):
        """移除字体变更回调"""
        if callback in self.font_change_callbacks:
            self.font_change_callbacks.remove(callback)
    
    def set_font_family(self, font_family):
        """设置字体族"""
        print(f"🔤 字体管理器：设置字体族为 {font_family}")  # 调试信息
        
        old_font = self.config["font_family"]
        self.config["font_family"] = font_family
        self.save_config()
        
        print(f"📝 字体变更：{old_font} → {font_family}")  # 调试信息
        
        # 通知所有回调
        self.notify_font_change()
        
    def notify_font_change(self):
        """通知字体变更"""
        print(f"📢 通知字体变更，回调数量: {len(self.font_change_callbacks)}")  # 调试信息
        
        for callback in self.font_change_callbacks:
            try:
                callback()
                print(f"✅ 字体变更回调执行成功")  # 调试信息
            except Exception as e:
                print(f"❌ 字体变更回调执行失败: {e}")  # 调试信息
        
        # 更新页面
        self.page.update()
        
    def apply_fonts(self):
        """应用字体设置到页面"""
        self.notify_font_change()
        
    def create_text(self, text, size_type="normal", weight_type="normal", **kwargs):
        """创建带有字体设置的文本控件"""
        # 避免weight参数重复传递
        if 'weight' in kwargs:
            kwargs.pop('weight')
        
        return ft.Text(
            text,
            font_family=self.get_font_family(),
            size=self.get_font_size(size_type),
            weight=self.get_font_weight(weight_type),
            **kwargs
        )
        
    def get_available_fonts(self):
        """获取可用字体列表"""
        return [
            "Microsoft YaHei",
            "SimHei",
            "SimSun",
            "KaiTi",
            "FangSong",
            "Arial",
            "Times New Roman",
            "Courier New",
            "Verdana",
            "Tahoma",
            "Georgia",
            "Comic Sans MS"
        ]