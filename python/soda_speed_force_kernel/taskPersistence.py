import json
import os
from pathlib import Path
from typing import Dict, List, Optional
from .taskModel import Task, TaskStatus
from .utils.logger import logger


class TaskPersistence:
    """任务持久化管理器"""
    
    def __init__(self, storage_dir: Optional[str] = None):
        """
        初始化任务持久化管理器
        
        Args:
            storage_dir: 存储目录，默认为用户数据目录
        """
        if storage_dir:
            self.storage_dir = Path(storage_dir)
        else:
            # 使用用户目录下的.hdmx文件夹
            self.storage_dir = Path.home() / '.hdmx'
        
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        self.tasks_file = self.storage_dir / 'tasks.json'
        self.segments_file = self.storage_dir / 'segments.json'
        self.config_file = self.storage_dir / 'config.json'
        
        logger.info(f"任务持久化存储目录: {self.storage_dir}")
    
    def save_config(self, config: Dict) -> bool:
        """
        保存全局配置到文件
        
        Args:
            config: 配置字典
        
        Returns:
            是否保存成功
        """
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(config, f, ensure_ascii=False, indent=2)
            return True
        except Exception as e:
            logger.error(f"保存配置失败: {e}")
            return False

    def load_config(self) -> Dict:
        """
        从文件加载全局配置
        
        Returns:
            配置字典
        """
        if not self.config_file.exists():
            return {}
        
        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"加载配置失败: {e}")
            return {}

    def save_tasks(self, tasks: Dict[str, Task]) -> bool:
        """
        保存所有任务到文件
        
        Args:
            tasks: 任务字典 {taskId: Task}
        
        Returns:
            是否保存成功
        """
        try:
            tasks_data = []
            for task_id, task in tasks.items():
                task_dict = {
                    'id': task.id,
                    'url': task.url,
                    'filename': task.filename,
                    'filepath': task.filepath,
                    'status': task.status.value,
                    'progress': task.progress,
                    'totalSize': task.totalSize,
                    'downloadedSize': task.downloadedSize,
                    'speed': task.speed,
                    'createdTime': task.createdTime,
                    'errorMessage': task.errorMessage,
                    # 保存额外属性
                    'userAgent': getattr(task, 'userAgent', ''),
                    'referer': getattr(task, 'referer', ''),
                    'cookies': getattr(task, 'cookies', ''),
                    'headers': getattr(task, 'headers', {}),
                }
                tasks_data.append(task_dict)
            
            with open(self.tasks_file, 'w', encoding='utf-8') as f:
                json.dump(tasks_data, f, ensure_ascii=False, indent=2)
            
            logger.info(f"已保存 {len(tasks_data)} 个任务到 {self.tasks_file}")
            return True
            
        except Exception as e:
            logger.error(f"保存任务失败: {e}")
            return False
    
    def load_tasks(self) -> Dict[str, Task]:
        """
        从文件加载所有任务
        
        Returns:
            任务字典 {taskId: Task}
        """
        tasks = {}
        
        if not self.tasks_file.exists():
            logger.info("任务文件不存在，返回空任务列表")
            return tasks
        
        try:
            with open(self.tasks_file, 'r', encoding='utf-8') as f:
                tasks_data = json.load(f)
            
            for task_dict in tasks_data:
                try:
                    # 重建Task对象
                    task = Task(
                        id=task_dict['id'],
                        url=task_dict['url'],
                        filename=task_dict['filename'],
                        filepath=task_dict['filepath'],
                        status=TaskStatus(task_dict['status']),
                        createdTime=task_dict.get('createdTime', 0)
                    )
                    
                    # 恢复进度信息
                    task.progress = task_dict.get('progress', 0.0)
                    task.totalSize = task_dict.get('totalSize', 0)
                    task.downloadedSize = task_dict.get('downloadedSize', 0)
                    task.speed = task_dict.get('speed', 0.0)
                    task.errorMessage = task_dict.get('errorMessage')
                    
                    # 恢复额外属性
                    setattr(task, 'userAgent', task_dict.get('userAgent', ''))
                    setattr(task, 'referer', task_dict.get('referer', ''))
                    setattr(task, 'cookies', task_dict.get('cookies', ''))
                    setattr(task, 'headers', task_dict.get('headers', {}))
                    
                    # 如果任务状态是DOWNLOADING，改为PAUSED（因为程序重启了）
                    if task.status == TaskStatus.DOWNLOADING:
                        task.status = TaskStatus.PAUSED
                        logger.info(f"任务 {task.filename} 状态从 DOWNLOADING 改为 PAUSED")
                    
                    tasks[task.id] = task
                    
                except Exception as e:
                    logger.error(f"加载任务失败: {e}, 任务数据: {task_dict}")
                    continue
            
            logger.info(f"已加载 {len(tasks)} 个任务")
            return tasks
            
        except Exception as e:
            logger.error(f"读取任务文件失败: {e}")
            return {}
    
    def save_segments(self, segments: Dict[str, List]) -> bool:
        """
        保存所有分段信息到文件
        
        Args:
            segments: 分段字典 {taskId: [Segment]}
        
        Returns:
            是否保存成功
        """
        try:
            segments_data = {}
            for task_id, segment_list in segments.items():
                segments_data[task_id] = [
                    {
                        'index': seg.index,
                        'startByte': seg.startByte,
                        'endByte': seg.endByte,
                        'downloadedBytes': seg.downloadedBytes,
                        'speed': seg.speed,
                        'status': seg.status,
                    }
                    for seg in segment_list
                ]
            
            with open(self.segments_file, 'w', encoding='utf-8') as f:
                json.dump(segments_data, f, ensure_ascii=False, indent=2)
            
            logger.info(f"已保存 {len(segments_data)} 个任务的分段信息")
            return True
            
        except Exception as e:
            logger.error(f"保存分段信息失败: {e}")
            return False
    
    def load_segments(self) -> Dict[str, List]:
        """
        从文件加载所有分段信息
        
        Returns:
            分段字典 {taskId: [Segment]}
        """
        from .multiThreadDownloader import Segment
        
        segments = {}
        
        if not self.segments_file.exists():
            logger.info("分段文件不存在，返回空分段列表")
            return segments
        
        try:
            with open(self.segments_file, 'r', encoding='utf-8') as f:
                segments_data = json.load(f)
            
            for task_id, segment_list in segments_data.items():
                try:
                    segments[task_id] = [
                        Segment(
                            index=seg['index'],
                            startByte=seg['startByte'],
                            endByte=seg['endByte'],
                            downloadedBytes=seg.get('downloadedBytes', 0),
                            speed=seg.get('speed', 0.0),
                            status=seg.get('status', 'pending'),
                        )
                        for seg in segment_list
                    ]
                except Exception as e:
                    logger.error(f"加载任务 {task_id} 的分段信息失败: {e}")
                    continue
            
            logger.info(f"已加载 {len(segments)} 个任务的分段信息")
            return segments
            
        except Exception as e:
            logger.error(f"读取分段文件失败: {e}")
            return {}
    
    def clear_all(self) -> bool:
        """清除所有持久化数据"""
        try:
            if self.tasks_file.exists():
                self.tasks_file.unlink()
            if self.segments_file.exists():
                self.segments_file.unlink()
            logger.info("已清除所有持久化数据")
            return True
        except Exception as e:
            logger.error(f"清除持久化数据失败: {e}")
            return False
