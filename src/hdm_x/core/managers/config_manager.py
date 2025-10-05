"""
ConfigManager

"""

import json
from pathlib import Path
import os
from typing import Dict, Any
from ...utils.logger import logger
from ...utils.pathUtils import getDefaultDownloadPath


class ConfigManager:
    
    def __init__(self):
        self.config_dir = Path.home() / '.hdm_x'
        self.config_file = self.config_dir / 'config.json'
        self.default_config = {
            'app_title': 'Hanabi Download Manager X',
            'window_width': 1200,
            'window_height': 800,
            'window_min_width': 800,
            'window_min_height': 600,
            'theme': 'auto',
            'download_path': getDefaultDownloadPath(),
            'max_concurrent_downloads': 3,
            'websocket_port': 8890,
            'auto_start_downloads': True,
            'show_notifications': True,
            'sidebar_collapsed': False,
            'sidebar_remember_state': True,
            'sidebar_default_expanded': True,
            'download_engine': 'go'
        }
        self.ensure_config_dir()
    
    def ensure_config_dir(self):
        """确保配置目录存在"""
        self.config_dir.mkdir(parents=True, exist_ok=True)
    
    def load_config(self):
        """加载配置"""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                return {**self.default_config, **config}
            except Exception:
                return self.default_config.copy()
        else:
            self.save_config(self.default_config)
            return self.default_config.copy()
    
    def save_config(self, config):
        """保存配置"""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, indent=2, ensure_ascii=False)
            return True
        except Exception:
            return False
    
    def update_config(self, key, value):
        """更新配置项"""
        config = self.load_config()
        config[key] = value
        return self.save_config(config)
    
    def get_config(self, key, default=None):
        """获取配置项"""
        config = self.load_config()
        return config.get(key, default)
    
    def reset_config(self):
        """重置配置"""
        return self.save_config(self.default_config)