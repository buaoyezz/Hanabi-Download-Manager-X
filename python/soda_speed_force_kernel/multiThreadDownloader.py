import asyncio
import time
import threading
from pathlib import Path
from typing import Dict, Optional, List
import aiohttp
import aiofiles
import secrets
from dataclasses import dataclass
from .eventBus import get_event_bus
from .taskModel import TaskStatus, Task
from .utils.logger import logger
from .utils.pathUtils import getDefaultDownloadPath


@dataclass
class Segment:
    index: int
    startByte: int
    endByte: int
    downloadedBytes: int = 0
    speed: float = 0.0
    status: str = "pending"  # pending, downloading, completed, failed


class MultiThreadDownloader:
    def __init__(self, downloadDir: Optional[str] = None, bus=None, threads: int = 8):
        self.downloadDir = Path(downloadDir) if downloadDir else Path(getDefaultDownloadPath())
        self.downloadDir.mkdir(parents=True, exist_ok=True)
        self.bus = bus or get_event_bus()
        self.tasks: Dict[str, Task] = {}
        self.segments: Dict[str, List[Segment]] = {}  # taskId -> segments
        self.threads = threads
        self._statusTask = None
        self.isRunning = True
        self.loop = asyncio.new_event_loop()
        
        def _run_loop():
            asyncio.set_event_loop(self.loop)
            self.loop.run_forever()
        
        self._loopThread = threading.Thread(target=_run_loop, daemon=True)
        self._loopThread.start()
        self._statusTask = asyncio.run_coroutine_threadsafe(self._status_loop(), self.loop)

    async def _status_loop(self):
        while self.isRunning:
            try:
                self.bus.publish("stats", self.get_statistics())
                await asyncio.sleep(1.0)
            except Exception:
                await asyncio.sleep(1.0)

    def add_progress(self, task: Task):
        self.bus.publish("progress", task)

    def add_complete(self, task: Task):
        self.bus.publish("complete", task)

    async def add_download(self, data: Dict) -> str:
        url = data.get("url", "")
        if not url:
            raise ValueError("url required")
        
        filename = data.get("filename") or data.get("fileName") or ""
        if not filename:
            from urllib.parse import urlparse, unquote
            try:
                p = urlparse(url)
                name = unquote(p.path.split("/")[-1])
                if not name or "." not in name:
                    name = f"download_{int(time.time())}"
                filename = name
            except Exception:
                filename = f"download_{int(time.time())}"
        
        taskId = secrets.token_hex(8)
        filepath = str(self.downloadDir / filename)
        t = Task(
            id=taskId,
            url=url,
            filename=filename,
            filepath=filepath,
            status=TaskStatus.PENDING,
            createdTime=time.time()
        )
        
        ua = data.get("user_agent") or "HDM-X/1.0 NSF-X (Nextgen Speed Force X)"
        ref = data.get("referer") or data.get("referrer") or ""
        cookies = data.get("cookies") or ""
        headers_extra = data.get("headers") or {}
        
        if not ref:
            try:
                from urllib.parse import urlparse
                _p = urlparse(url)
                if _p.scheme and _p.netloc:
                    ref = f"{_p.scheme}://{_p.netloc}/"
            except Exception:
                ref = ""
        
        setattr(t, "userAgent", ua)
        setattr(t, "referer", ref)
        setattr(t, "cookies", cookies)
        setattr(t, "headers", headers_extra if isinstance(headers_extra, dict) else {})
        
        self.tasks[taskId] = t
        asyncio.run_coroutine_threadsafe(self._run_download(taskId), self.loop)
        return taskId

    async def pause_download(self, taskId: str) -> bool:
        t = self.tasks.get(taskId)
        if t and t.status == TaskStatus.DOWNLOADING:
            t.status = TaskStatus.PAUSED
            self.add_progress(t)
            return True
        return False

    async def resume_download(self, taskId: str) -> bool:
        t = self.tasks.get(taskId)
        if t and t.status == TaskStatus.PAUSED:
            t.status = TaskStatus.DOWNLOADING
            self.add_progress(t)
            return True
        return False

    async def cancel_download(self, taskId: str) -> bool:
        t = self.tasks.get(taskId)
        if t and t.status in {TaskStatus.PENDING, TaskStatus.DOWNLOADING, TaskStatus.PAUSED}:
            t.status = TaskStatus.CANCELLED
            self.add_progress(t)
            try:
                p = Path(t.filepath)
                if p.exists():
                    p.unlink()
            except Exception:
                pass
            return True
        return False

    def get_statistics(self) -> Dict:
        active = 0
        totalSpeed = 0.0
        totalDownloaded = 0
        for t in self.tasks.values():
            if t.status == TaskStatus.DOWNLOADING:
                active += 1
                totalSpeed += t.speed
            totalDownloaded += t.downloadedSize
        return {
            "totalTasks": len(self.tasks),
            "activeDownloads": active,
            "totalSpeed": totalSpeed,
            "totalDownloaded": totalDownloaded,
        }

    def set_download_dir(self, download_dir: str) -> bool:
        try:
            new_dir = Path(download_dir)
            new_dir.mkdir(parents=True, exist_ok=True)
            self.downloadDir = new_dir
            logger.info(f"Download directory changed to: {download_dir}")
            return True
        except Exception as e:
            logger.error(f"Failed to set download directory: {e}")
            return False

    async def _get_file_size(self, url: str, headers: Dict) -> tuple[int, bool]:
        """获取文件大小和是否支持断点续传"""
        timeout = aiohttp.ClientTimeout(total=None, connect=15)
        
        ssl_configs = [
            {"ssl": True},
            {"ssl": False}
        ]
        
        for ssl_config in ssl_configs:
            try:
                connector_kwargs = {}
                if not ssl_config["ssl"]:
                    import ssl
                    ssl_context = ssl.create_default_context()
                    ssl_context.check_hostname = False
                    ssl_context.verify_mode = ssl.CERT_NONE
                    connector_kwargs["ssl"] = ssl_context
                
                connector = aiohttp.TCPConnector(**connector_kwargs)
                async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
                    async with session.head(url, headers=headers, allow_redirects=True, ssl=ssl_config["ssl"]) as resp:
                        if resp.status == 200:
                            content_length = resp.headers.get("Content-Length")
                            accept_ranges = resp.headers.get("Accept-Ranges", "").lower()
                            supports_range = accept_ranges == "bytes"
                            
                            if content_length:
                                return int(content_length), supports_range
                            return 0, False
            except Exception as e:
                logger.debug(f"HEAD request failed: {e}")
                continue
        
        return 0, False

    async def _download_segment(self, taskId: str, segment: Segment, headers: Dict, filepath: Path):
        """下载单个分段"""
        t = self.tasks.get(taskId)
        if not t:
            return
        
        segment.status = "downloading"
        range_header = headers.copy()
        current_start = segment.startByte + segment.downloadedBytes
        range_header["Range"] = f"bytes={current_start}-{segment.endByte - 1}"
        
        timeout = aiohttp.ClientTimeout(total=None, connect=15)
        ssl_configs = [{"ssl": True}, {"ssl": False}]
        
        start_time = time.time()
        last_update = start_time
        segment_size = segment.endByte - segment.startByte
        
        for ssl_config in ssl_configs:
            try:
                connector_kwargs = {}
                if not ssl_config["ssl"]:
                    import ssl
                    ssl_context = ssl.create_default_context()
                    ssl_context.check_hostname = False
                    ssl_context.verify_mode = ssl.CERT_NONE
                    connector_kwargs["ssl"] = ssl_context
                
                connector = aiohttp.TCPConnector(**connector_kwargs)
                async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
                    async with session.get(t.url, headers=range_header, allow_redirects=True, ssl=ssl_config["ssl"]) as resp:
                        if resp.status not in (200, 206):
                            raise Exception(f"HTTP {resp.status}")
                        
                        # 检查是否真的支持Range
                        if resp.status == 200:
                            # 服务器不支持Range，返回了完整文件
                            logger.warning(f"分段 {segment.index}: 服务器不支持Range请求，收到完整文件")
                            segment.status = "failed"
                            return
                        
                        # 打开文件进行写入
                        temp_file = filepath.parent / f"{filepath.name}.part{segment.index}"
                        async with aiofiles.open(temp_file, "wb") as f:
                            bytes_written = 0
                            async for chunk in resp.content.iter_chunked(8192):
                                if t.status == TaskStatus.CANCELLED:
                                    return
                                
                                while t.status == TaskStatus.PAUSED:
                                    await asyncio.sleep(0.1)
                                    if t.status == TaskStatus.CANCELLED:
                                        return
                                
                                # 限制写入的字节数，不超过分段大小
                                remaining = segment_size - segment.downloadedBytes
                                if remaining <= 0:
                                    break
                                
                                chunk_to_write = chunk[:remaining] if len(chunk) > remaining else chunk
                                await f.write(chunk_to_write)
                                bytes_written += len(chunk_to_write)
                                segment.downloadedBytes += len(chunk_to_write)
                                
                                # 更新速度
                                now = time.time()
                                if now - last_update >= 0.5:
                                    elapsed = now - start_time
                                    if elapsed > 0:
                                        segment.speed = bytes_written / elapsed
                                    last_update = now
                                
                                # 如果已经下载完这个分段，停止
                                if segment.downloadedBytes >= segment_size:
                                    break
                        
                        segment.status = "completed"
                        logger.info(f"分段 {segment.index} 下载完成: {segment.downloadedBytes}/{segment_size} bytes")
                        return
                        
            except Exception as e:
                logger.warning(f"分段 {segment.index} 下载失败: {e}")
                if ssl_config != ssl_configs[-1]:
                    continue
                else:
                    segment.status = "failed"
                    raise

    async def _merge_segments(self, taskId: str, filepath: Path):
        """合并所有分段"""
        segments = self.segments.get(taskId, [])
        if not segments:
            return
        
        logger.info(f"开始合并 {len(segments)} 个分段...")
        
        async with aiofiles.open(filepath, "wb") as output:
            for segment in sorted(segments, key=lambda s: s.index):
                temp_file = filepath.parent / f"{filepath.name}.part{segment.index}"
                if temp_file.exists():
                    async with aiofiles.open(temp_file, "rb") as input_file:
                        content = await input_file.read()
                        await output.write(content)
                    # 删除临时文件
                    temp_file.unlink()
        
        logger.info("分段合并完成")

    async def _run_download(self, taskId: str):
        t = self.tasks.get(taskId)
        if not t:
            return
        
        t.status = TaskStatus.DOWNLOADING
        self.add_progress(t)
        
        # 准备请求头
        ua = getattr(t, "userAgent", "HDM-X/1.0 NSF-X (Nextgen Speed Force X)")
        headers = {
            "User-Agent": ua,
            "Accept": "*/*",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Connection": "keep-alive"
        }
        
        ref = getattr(t, "referer", "")
        if ref:
            headers["Referer"] = ref
        
        ck = getattr(t, "cookies", "")
        if ck:
            headers["Cookie"] = ck
        
        extra = getattr(t, "headers", {})
        if isinstance(extra, dict):
            headers.update({k: v for k, v in extra.items() if isinstance(k, str)})
        
        filepath = Path(t.filepath)
        filepath.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            # 获取文件大小和是否支持分段
            file_size, supports_range = await self._get_file_size(t.url, headers)
            
            if file_size == 0:
                raise Exception("无法获取文件大小")
            
            t.totalSize = file_size
            logger.info(f"文件大小: {file_size} bytes, 支持分段: {supports_range}")
            
            # 尝试分段下载（即使服务器没有明确支持）
            if file_size > 1024 * 1024:  # 大于1MB才分段
                # 创建分段
                segment_size = file_size // self.threads
                segments = []
                
                for i in range(self.threads):
                    start = i * segment_size
                    end = file_size if i == self.threads - 1 else (i + 1) * segment_size
                    segment = Segment(
                        index=i,
                        startByte=start,
                        endByte=end
                    )
                    segments.append(segment)
                
                self.segments[taskId] = segments
                logger.info(f"创建 {self.threads} 个下载分段")
                
                # 打印分段信息
                print(f"\n{'='*60}")
                print(f"开始多线程下载: {t.filename}")
                print(f"文件大小: {file_size / (1024*1024):.2f} MB")
                print(f"线程数: {self.threads}")
                print(f"{'='*60}\n")
                
                # 并发下载所有分段
                download_tasks = []
                for segment in segments:
                    task_coro = self._download_segment(taskId, segment, headers, filepath)
                    download_tasks.append(task_coro)
                
                # 启动进度监控
                monitor_task = asyncio.create_task(self._monitor_progress(taskId))
                
                # 等待所有分段下载完成
                await asyncio.gather(*download_tasks, return_exceptions=True)
                
                # 停止监控
                monitor_task.cancel()
                
                # 检查是否有分段失败（服务器不支持Range）
                failed_segments = [seg for seg in segments if seg.status == "failed"]
                if failed_segments:
                    logger.warning(f"检测到 {len(failed_segments)} 个分段失败，回退到单线程下载")
                    print(f"\n服务器不支持分段下载，切换到单线程模式...\n")
                    
                    # 清理临时文件
                    for seg in segments:
                        temp_file = filepath.parent / f"{filepath.name}.part{seg.index}"
                        if temp_file.exists():
                            temp_file.unlink()
                    
                    # 使用单线程下载
                    t.downloadedSize = 0
                    t.progress = 0.0
                    self.segments.pop(taskId, None)
                    await self._single_thread_download(taskId, headers, filepath)
                    return
                
                # 合并分段
                await self._merge_segments(taskId, filepath)
                
                # 下载完成
                t.progress = 100.0
                t.downloadedSize = file_size
                t.status = TaskStatus.COMPLETED
                self.add_complete(t)
                logger.info(f"下载完成: {t.filename}")
                
                print(f"\n{'='*60}")
                print(f"下载完成: {t.filename}")
                print(f"{'='*60}\n")
                
            else:
                # 不支持分段或文件太小，使用单线程下载
                logger.info("使用单线程下载")
                await self._single_thread_download(taskId, headers, filepath)
                
        except Exception as e:
            import traceback
            error_msg = str(e)
            logger.error(f"下载失败 {t.filename}: {error_msg}")
            logger.debug(f"详细错误: {traceback.format_exc()}")
            
            t.status = TaskStatus.FAILED
            t.errorMessage = error_msg
            self.add_progress(t)

    async def _monitor_progress(self, taskId: str):
        """监控并显示下载进度"""
        t = self.tasks.get(taskId)
        if not t:
            return
        
        try:
            while t.status == TaskStatus.DOWNLOADING:
                segments = self.segments.get(taskId, [])
                if not segments:
                    await asyncio.sleep(0.5)
                    continue
                
                # 计算总进度
                total_downloaded = sum(seg.downloadedBytes for seg in segments)
                total_speed = sum(seg.speed for seg in segments)
                
                t.downloadedSize = total_downloaded
                t.speed = total_speed
                
                if t.totalSize > 0:
                    t.progress = (total_downloaded / t.totalSize) * 100.0
                    remaining = t.totalSize - total_downloaded
                    if total_speed > 0:
                        t.eta = int(remaining / total_speed)
                
                # 将分段信息添加到任务对象
                t.segments = [
                    {
                        "index": seg.index,
                        "startByte": seg.startByte,
                        "endByte": seg.endByte,
                        "downloadedBytes": seg.downloadedBytes,
                        "speed": seg.speed,
                        "status": seg.status
                    }
                    for seg in segments
                ]
                
                # 调试输出
                if len(segments) > 0:
                    logger.debug(f"任务 {taskId}: 设置了 {len(segments)} 个分段到Task对象")
                
                # 打印进度
                progress_display = min(t.progress, 100.0)  # 限制显示不超过100%
                print(f"\r总进度: {progress_display:.1f}% | 速度: {total_speed/1024/1024:.2f} MB/s | "
                      f"已下载: {total_downloaded/1024/1024:.1f}/{t.totalSize/1024/1024:.1f} MB", end="")
                
                # 打印每个分段的进度
                for seg in segments:
                    seg_total = seg.endByte - seg.startByte
                    seg_progress = min((seg.downloadedBytes / seg_total * 100) if seg_total > 0 else 0, 100.0)
                    print(f"\n  线程{seg.index+1}: {seg_progress:.1f}% | "
                          f"{seg.speed/1024/1024:.2f} MB/s | "
                          f"{min(seg.downloadedBytes, seg_total)/1024/1024:.1f}/{seg_total/1024/1024:.1f} MB | "
                          f"{seg.status}", end="")
                
                print("\n", end="")
                
                # 发布进度更新
                self.add_progress(t)
                
                await asyncio.sleep(0.5)
                
        except asyncio.CancelledError:
            pass

    async def _single_thread_download(self, taskId: str, headers: Dict, filepath: Path):
        """单线程下载（回退方案）"""
        t = self.tasks.get(taskId)
        if not t:
            return
        
        timeout = aiohttp.ClientTimeout(total=None, connect=15)
        ssl_configs = [{"ssl": True}, {"ssl": False}]
        
        for ssl_config in ssl_configs:
            try:
                connector_kwargs = {}
                if not ssl_config["ssl"]:
                    import ssl
                    ssl_context = ssl.create_default_context()
                    ssl_context.check_hostname = False
                    ssl_context.verify_mode = ssl.CERT_NONE
                    connector_kwargs["ssl"] = ssl_context
                
                connector = aiohttp.TCPConnector(**connector_kwargs)
                async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
                    async with session.get(t.url, headers=headers, allow_redirects=True, ssl=ssl_config["ssl"]) as resp:
                        if resp.status not in (200, 206):
                            raise Exception(f"HTTP {resp.status}")
                        
                        start_time = time.time()
                        last_update = start_time
                        
                        async with aiofiles.open(filepath, "wb") as f:
                            async for chunk in resp.content.iter_chunked(8192):
                                if t.status == TaskStatus.CANCELLED:
                                    return
                                
                                while t.status == TaskStatus.PAUSED:
                                    await asyncio.sleep(0.1)
                                    if t.status == TaskStatus.CANCELLED:
                                        return
                                
                                await f.write(chunk)
                                t.downloadedSize += len(chunk)
                                
                                now = time.time()
                                if t.totalSize > 0:
                                    t.progress = (t.downloadedSize / t.totalSize) * 100.0
                                
                                if now - last_update >= 0.5:
                                    elapsed = now - start_time
                                    if elapsed > 0:
                                        t.speed = t.downloadedSize / elapsed
                                        if t.speed > 0 and t.totalSize > 0:
                                            remaining = t.totalSize - t.downloadedSize
                                            t.eta = int(remaining / t.speed)
                                    self.add_progress(t)
                                    last_update = now
                        
                        t.progress = 100.0
                        t.status = TaskStatus.COMPLETED
                        self.add_complete(t)
                        logger.info(f"下载完成: {t.filename}")
                        return
                        
            except Exception as e:
                logger.warning(f"单线程下载失败: {e}")
                if ssl_config != ssl_configs[-1]:
                    continue
                else:
                    raise
