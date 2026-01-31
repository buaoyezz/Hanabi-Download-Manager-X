import asyncio
from typing import Callable, Dict, Any
from .eventBus import EventBus
from .multiThreadDownloader import MultiThreadDownloader
from .taskModel import Task

class NsfXCoreBridge:
    def __init__(self, downloadDir: str = None, threads: int = 8, segments: int = None, mode: str = "auto"):
        """
        初始化下载桥接
        
        Args:
            downloadDir: 下载目录
            threads: 线程数 (1-32)
            segments: 分段数 (1-32)，None表示自动
            mode: 模式 ("auto", "threads_only", "segments_only", "manual")
        """
        self.bus = EventBus()
        self.downloader = MultiThreadDownloader(
            downloadDir, 
            self.bus, 
            threads=threads,
            segments=segments,
            mode=mode
        )
        self._progress_callbacks = []
        self._completion_callbacks = []
        self._bind_bus()

    def _bind_bus(self):
        def on_progress(task: Task):
            for cb in self._progress_callbacks:
                try:
                    cb(task)
                except Exception:
                    pass
        def on_complete(task: Task):
            for cb in self._completion_callbacks:
                try:
                    cb(task)
                except Exception:
                    pass
        self.bus.subscribe("progress", on_progress)
        self.bus.subscribe("complete", on_complete)

    def add_progress_callback(self, cb: Callable):
        self._progress_callbacks.append(cb)

    def add_completion_callback(self, cb: Callable):
        self._completion_callbacks.append(cb)

    @property
    def is_running(self) -> bool:
        return True

    async def add_download(self, download_data: Dict[str, Any]):
        tid = await self.downloader.add_download(download_data)
        return {"id": tid}

    async def pause_download(self, download_id: str) -> bool:
        return await self.downloader.pause_download(download_id)

    async def resume_download(self, download_id: str) -> bool:
        return await self.downloader.resume_download(download_id)

    async def cancel_download(self, download_id: str) -> bool:
        return await self.downloader.cancel_download(download_id)

    def get_statistics(self) -> Dict[str, Any]:
        return self.downloader.get_statistics()

    def get_all_tasks(self):
        return list(self.downloader.tasks.values())

    def set_download_dir(self, download_dir: str) -> bool:
        return self.downloader.set_download_dir(download_dir)

    def get_download_dir(self) -> str:
        return str(self.downloader.downloadDir)

    def set_download_config(self, threads: int = None, segments: int = None, mode: str = None, max_concurrent_tasks: int = None, segment_speed_limit: int = None, proxy_config: Dict = None) -> Dict[str, Any]:
        """
        动态设置下载配置
        
        Args:
            threads: 线程数 (1-32)
            segments: 分段数 (1-32)
            mode: 模式 ("auto", "threads_only", "segments_only", "manual")
            max_concurrent_tasks: 最大同时下载任务数
            segment_speed_limit: 分段限速 (bytes/s), 0表示不限速
            proxy_config: 代理配置
        
        Returns:
            当前配置信息
        """
        self.downloader.update_config(
            threads=threads,
            segments=segments,
            mode=mode,
            max_concurrent_tasks=max_concurrent_tasks,
            segment_speed_limit=segment_speed_limit,
            proxy_config=proxy_config
        )
        
        return self.get_download_config()

    def get_download_config(self) -> Dict[str, Any]:
        """获取当前下载配置"""
        return {
            "threads": self.downloader.threads,
            "segments": self.downloader.segments_count,
            "mode": self.downloader.mode,
            "max_concurrent_tasks": self.downloader.max_concurrent_tasks,
            "segment_speed_limit": self.downloader.segment_speed_limit,
            "proxy": self.downloader.proxy_config,
            "mode_description": {
                "auto": "全自动（根据文件大小自动设置）",
                "threads_only": "仅设置线程数，分段数自动",
                "segments_only": "仅设置分段数，线程数自动",
                "manual": "手动设置线程和分段"
            }.get(self.downloader.mode, "未知模式")
        }

    def clear_all_data(self) -> bool:
        """清除所有下载任务和历史记录"""
        try:
            # 取消所有正在进行的任务
            task_ids = list(self.downloader.tasks.keys())
            for task_id in task_ids:
                import asyncio
                asyncio.run_coroutine_threadsafe(
                    self.downloader.cancel_download(task_id),
                    self.downloader.loop
                ).result(timeout=5)
            
            # 清除持久化数据
            self.downloader.persistence.clear_all()
            
            # 清空内存中的任务
            self.downloader.tasks.clear()
            self.downloader.segments.clear()
            
            return True
        except Exception as e:
            from .utils.logger import logger
            logger.error(f"清除所有数据失败: {e}")
            return False
    
    def cleanup_temp_files(self) -> Dict[str, Any]:
        """清理所有临时文件"""
        return self.downloader.cleanup_all_temp_files()

    async def retry_failed_segments(self, task_id: str) -> bool:
        """重试失败的分段"""
        try:
            return await self.downloader.retry_failed_segments(task_id)
        except Exception as e:
            from .utils.logger import logger
            logger.error(f"重试失败分段失败: {e}")
            return False

    async def retry_segment(self, task_id: str, segment_index: int) -> bool:
        """重试特定分段"""
        try:
            return await self.downloader.retry_segment(task_id, segment_index)
        except Exception as e:
            from .utils.logger import logger
            logger.error(f"重试分段失败: {e}")
            return False

    async def test_proxy_connection(self, proxy_type: str, host: str, port: int, username: str = None, password: str = None) -> bool:
        """测试代理连接"""
        try:
            return await self.downloader.test_proxy_connection(
                proxy_type=proxy_type,
                host=host,
                port=port,
                username=username,
                password=password
            )
        except Exception as e:
            from .utils.logger import logger
            logger.error(f"代理连接测试失败: {e}")
            return False
    
    def cleanup(self):
        self.downloader.isRunning = False
