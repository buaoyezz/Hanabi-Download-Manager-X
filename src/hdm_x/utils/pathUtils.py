import os
from pathlib import Path

def getUserDownloadDir():
    """获取用户下载目录"""
    return str(Path.home() / "Downloads" / "HDM_X")

def getUserHomeDir():
    """获取用户主目录"""
    return str(Path.home())

def ensureDir(dirPath):
    """确保目录存在，如果不存在则创建"""
    Path(dirPath).mkdir(parents=True, exist_ok=True)
    return dirPath

def getDefaultDownloadPath():
    """获取默认下载路径并确保目录存在"""
    downloadDir = getUserDownloadDir()
    ensureDir(downloadDir)
    return downloadDir