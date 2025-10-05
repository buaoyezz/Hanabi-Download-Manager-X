"""
路径辅助工具
处理资源文件路径的统一管理
"""

from pathlib import Path
import os


class PathHelper:
    """路径辅助类"""
    
    @staticmethod
    def get_project_root():
        """获取项目根目录"""
        # 从当前文件向上查找项目根目录
        current = Path(__file__).parent
        while current.parent != current:
            if (current / "main.py").exists():
                return current
            current = current.parent
        return Path.cwd()
    
    @staticmethod
    def get_assets_path():
        """获取assets目录路径"""
        return PathHelper.get_project_root() / "src" / "hdm_x" / "assets"
    
    @staticmethod
    def get_logo_path(filename="logo.png"):
        """获取logo文件路径"""
        logo_path = PathHelper.get_assets_path() / "resources" / "logo" / filename
        if logo_path.exists():
            return str(logo_path)
        else:
            # 返回相对路径，让Flet处理
            return f"assets/resources/logo/{filename}"
    
    @staticmethod
    def get_avatar_path(filename="normal.jpg"):
        """获取avatar文件路径"""
        avatar_path = PathHelper.get_assets_path() / "resources" / "avatar" / filename
        if avatar_path.exists():
            return str(avatar_path)
        else:
            # 返回相对路径，让Flet处理
            return f"assets/resources/avatar/{filename}"
    
    @staticmethod
    def get_resource_path(resource_type, filename):
        """获取通用资源文件路径"""
        resource_path = PathHelper.get_assets_path() / "resources" / resource_type / filename
        if resource_path.exists():
            return str(resource_path)
        else:
            # 返回相对路径，让Flet处理
            return f"assets/resources/{resource_type}/{filename}"


# 便捷函数
def get_logo_path(filename="logo.png"):
    """获取logo路径的便捷函数"""
    return PathHelper.get_logo_path(filename)


def get_avatar_path(filename="normal.jpg"):
    """获取avatar路径的便捷函数"""
    return PathHelper.get_avatar_path(filename)
