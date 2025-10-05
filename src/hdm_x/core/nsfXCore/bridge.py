import asyncio
from typing import Callable, Dict, Any
from .eventBus import EventBus
from .httpDownloader import HttpDownloader
from .taskModel import Task

class NsfXCoreBridge:
    def __init__(self, downloadDir: str = None):
        self.bus = EventBus()
        self.downloader = HttpDownloader(downloadDir, self.bus)
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

    def cleanup(self):
        self.downloader.isRunning = False