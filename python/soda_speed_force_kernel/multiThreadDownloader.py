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
from .taskPersistence import TaskPersistence


@dataclass
class Segment:
    index: int
    startByte: int
    endByte: int
    downloadedBytes: int = 0
    speed: float = 0.0
    status: str = "pending"  # pending, downloading, completed, failed
    retryCount: int = 0  # 重试次数
    lastError: str = ""  # 最后一次错误信息


# 动态分段策略配置
class DynamicSegmentConfig:
    """动态分段配置，根据网络状况自动调整"""
    
    # 最小分段大小 (1MB)
    MIN_SEGMENT_SIZE = 1 * 1024 * 1024
    
    # 最大分段大小 (50MB)
    MAX_SEGMENT_SIZE = 50 * 1024 * 1024
    
    # 理想分段大小 (5MB) - 平衡速度和稳定性
    IDEAL_SEGMENT_SIZE = 5 * 1024 * 1024
    
    # 小文件阈值 (10MB以下不分段)
    SMALL_FILE_THRESHOLD = 10 * 1024 * 1024
    
    # 超大文件阈值 (1GB以上使用更多分段)
    LARGE_FILE_THRESHOLD = 1024 * 1024 * 1024


class MultiThreadDownloader:
    def __init__(self, downloadDir: Optional[str] = None, bus=None, threads: int = 8, segments: int = None, mode: str = "auto"):
        """
        初始化下载器
        
        Args:
            downloadDir: 下载目录
            bus: 事件总线
            threads: 线程数 (1-32)，默认8
            segments: 分段数 (1-32)，默认None（自动）
            mode: 模式
                - "auto": 全自动（根据文件大小自动设置线程和分段）
                - "threads_only": 仅设置线程数，分段数自动
                - "segments_only": 仅设置分段数，线程数自动
                - "manual": 手动设置线程和分段
        """
        self.downloadDir = Path(downloadDir) if downloadDir else Path(getDefaultDownloadPath())
        self.downloadDir.mkdir(parents=True, exist_ok=True)
        self.bus = bus or get_event_bus()
        self.tasks: Dict[str, Task] = {}
        self.segments: Dict[str, List[Segment]] = {}  # taskId -> segments
        
        # 限制线程数和分段数在 1-32 之间
        self.threads = max(1, min(32, threads))
        self.segments_count = max(1, min(32, segments)) if segments else None
        self.mode = mode
        self.max_concurrent_tasks = 3  # 默认最大同时下载数
        self.segment_speed_limit = 0   # 分段限速 (bytes/s), 0表示不限速
        
        # 高级配置
        self.chunk_size = 131072  # 128KB 读取块大小（提升IO效率）
        self.connection_timeout = 30  # 连接超时
        self.read_timeout = 60  # 读取超时
        self.max_retries = 5  # 最大重试次数（提升）
        self.retry_delay_base = 2  # 重试延迟基数
        self.enable_dynamic_segments = True  # 启用动态分段
        self.enable_speed_boost = True  # 启用速度提升模式
        
        # 网络状态监控
        self._network_stats = {
            'avg_speed': 0.0,
            'peak_speed': 0.0,
            'failed_connections': 0,
            'successful_connections': 0,
        }
        
        # 初始化任务持久化
        self.persistence = TaskPersistence()
        
        # 加载全局配置
        self._load_global_config()
        
        # 加载已保存的任务
        self._load_persisted_tasks()
        
        self._statusTask = None
        self.isRunning = True
        self.loop = asyncio.new_event_loop()
        
        def _run_loop():
            asyncio.set_event_loop(self.loop)
            self.loop.run_forever()
        
        self._loopThread = threading.Thread(target=_run_loop, daemon=True)
        self._loopThread.start()
        self._statusTask = asyncio.run_coroutine_threadsafe(self._status_loop(), self.loop)
        
        # 启动自动保存任务
        self._save_task = asyncio.run_coroutine_threadsafe(self._auto_save_loop(), self.loop)
        
        logger.info(f"下载器初始化: 模式={mode}, 线程={self.threads}, 分段={self.segments_count or '自动'}")

    def _load_global_config(self):
        """加载全局配置"""
        try:
            config = self.persistence.load_config()
            if config:
                if 'threads' in config:
                    self.threads = max(1, min(32, config['threads']))
                if 'segments' in config:
                    self.segments_count = max(1, min(32, config['segments']))
                if 'mode' in config:
                    self.mode = config['mode']
                if 'max_concurrent_tasks' in config:
                    self.max_concurrent_tasks = config['max_concurrent_tasks']
                if 'segment_speed_limit' in config:
                    self.segment_speed_limit = config['segment_speed_limit']
                logger.info(f"已加载全局配置: {config}")
        except Exception as e:
            logger.error(f"加载全局配置失败: {e}")

    def save_global_config(self):
        """保存全局配置"""
        config = {
            'threads': self.threads,
            'segments': self.segments_count,
            'mode': self.mode,
            'max_concurrent_tasks': self.max_concurrent_tasks,
            'segment_speed_limit': self.segment_speed_limit
        }
        self.persistence.save_config(config)

    def update_config(self, threads: int = None, segments: int = None, mode: str = None, max_concurrent_tasks: int = None, segment_speed_limit: int = None):
        """更新并保存配置"""
        changed = False
        if threads is not None:
            self.threads = max(1, min(32, threads))
            changed = True
        
        if segments is not None:
            self.segments_count = max(1, min(32, segments)) if segments > 0 else None
            changed = True
            
        if mode is not None and mode in ["auto", "threads_only", "segments_only", "manual"]:
            self.mode = mode
            changed = True
            
        if max_concurrent_tasks is not None:
            self.max_concurrent_tasks = max(1, max_concurrent_tasks)
            self._check_queue()
            changed = True
            
        if segment_speed_limit is not None:
            self.segment_speed_limit = max(0, segment_speed_limit)
            logger.info(f"分段限速更新: {self.segment_speed_limit} bytes/s (from input: {segment_speed_limit})")
            changed = True
            
        if changed:
            self.save_global_config()

    def _load_persisted_tasks(self):
        """加载持久化的任务"""
        try:
            self.tasks = self.persistence.load_tasks()
            self.segments = self.persistence.load_segments()
            logger.info(f"已加载 {len(self.tasks)} 个任务, {len(self.segments)} 个任务的分段信息")
        except Exception as e:
            logger.error(f"加载持久化任务失败: {e}")
    
    async def _auto_save_loop(self):
        """自动保存任务循环"""
        while self.isRunning:
            try:
                await asyncio.sleep(5.0)  # 每5秒保存一次
                self._save_tasks()
            except Exception as e:
                logger.error(f"自动保存任务失败: {e}")
                await asyncio.sleep(5.0)
    
    def _save_tasks(self):
        """保存任务到持久化存储"""
        try:
            self.persistence.save_tasks(self.tasks)
            self.persistence.save_segments(self.segments)
        except Exception as e:
            logger.error(f"保存任务失败: {e}")
    
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
        
        ua = data.get("user_agent") or "HDM-X/1.0 NSF-X/1.5.7 (Nextgen Speed Force X)"
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
        
        # 保存任务
        self._save_tasks()
        
        # 检查并发限制
        self._check_queue()
            
        return taskId

    def _get_active_downloads_count(self) -> int:
        """获取当前正在下载（包括正在连接等）的任务数"""
        return sum(1 for t in self.tasks.values() if t.status == TaskStatus.DOWNLOADING)

    def _check_queue(self):
        active_count = self._get_active_downloads_count()
        
        # 1. 如果正在下载的数量小于最大并发数，尝试启动 PENDING 的任务
        if active_count < self.max_concurrent_tasks:
            # 找到所有 PENDING 的任务
            pending_tasks = [t for t in self.tasks.values() if t.status == TaskStatus.PENDING]
            # 按创建时间排序（FIFO）
            pending_tasks.sort(key=lambda x: x.createdTime)
            
            # 启动任务直到填满配额
            slots_available = self.max_concurrent_tasks - active_count
            for i in range(min(len(pending_tasks), slots_available)):
                task = pending_tasks[i]
                logger.info(f"队列调度: 启动任务 {task.filename} (ID: {task.id})")
                asyncio.run_coroutine_threadsafe(self._run_download(task.id), self.loop)

    async def pause_download(self, taskId: str) -> bool:
        t = self.tasks.get(taskId)
        logger.info(f"[暂停请求] taskId={taskId}, 任务存在={t is not None}, 当前状态={t.status if t else 'N/A'}")
        
        if t and t.status == TaskStatus.DOWNLOADING:
            t.status = TaskStatus.PAUSED
            logger.info(f"[暂停成功] 任务 {t.filename} 状态已更新为 PAUSED")
            
            # 更新所有正在下载的分段状态为paused，这样它们会退出下载循环
            segments = self.segments.get(taskId, [])
            for seg in segments:
                if seg.status == "downloading":
                    seg.status = "paused"
                    logger.info(f"暂停分段 {seg.index}")
            
            self.add_progress(t)
            # 任务暂停了，空出一个位置，检查队列
            self._check_queue()
            return True
        
        logger.warning(f"[暂停失败] 任务状态不是DOWNLOADING，当前状态: {t.status if t else 'N/A'}")
        return False

    async def resume_download(self, taskId: str) -> bool:
        t = self.tasks.get(taskId)
        logger.info(f"尝试恢复下载: taskId={taskId}, 任务存在={t is not None}")
        
        if not t:
            logger.warning(f"恢复失败: 找不到任务 {taskId}")
            return False
            
        logger.info(f"任务状态: {t.status}, 文件名: {t.filename}")
        
        if t.status == TaskStatus.PAUSED or t.status == TaskStatus.FAILED:
            # 恢复下载状态
            old_status = t.status
            t.status = TaskStatus.DOWNLOADING
            self.add_progress(t)
            logger.info(f"恢复下载: {t.filename}, 状态: {old_status} -> DOWNLOADING, 已下载: {t.downloadedSize}/{t.totalSize}")
            
            # 检查是否有分段信息
            segments = self.segments.get(taskId)
            if segments:
                logger.info(f"找到 {len(segments)} 个分段，状态: {[seg.status for seg in segments[:5]]}")
            else:
                logger.warning(f"没有找到分段信息")
            
            # 重新启动下载任务（会检测并使用已有的分段）
            try:
                future = asyncio.run_coroutine_threadsafe(self._run_download(taskId), self.loop)
                logger.info(f"已提交恢复下载任务到事件循环")
            except Exception as e:
                logger.error(f"提交恢复任务失败: {e}")
                t.status = old_status
                return False
            
            return True
        else:
            logger.warning(f"无法恢复: 任务状态不是PAUSED或FAILED，当前状态: {t.status}")
            return False

    async def cancel_download(self, taskId: str) -> bool:
        t = self.tasks.get(taskId)
        if t:
            old_status = t.status
            t.status = TaskStatus.CANCELLED
            self.add_progress(t)
            
            # 删除任务和分段信息
            self.tasks.pop(taskId, None)
            self.segments.pop(taskId, None)
            
            # 保存任务
            self._save_tasks()
            
            try:
                p = Path(t.filepath)
                if p.exists():
                    p.unlink()
                
                # 删除临时文件夹及其内容
                temp_folder = self._get_temp_folder(p)
                if temp_folder.exists():
                    import shutil
                    shutil.rmtree(temp_folder)
                    logger.info(f"已删除临时文件夹: {temp_folder.name}")
            except Exception as e:
                logger.error(f"删除文件失败: {e}")
            
            # 如果取消的是正在下载的任务，或者任何任务，都检查一下队列
            if old_status == TaskStatus.DOWNLOADING:
                self._check_queue()
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

    def set_speed_limit(self, limit: int):
        """
        设置分段限速
        
        Args:
            limit: 限速值 (bytes/s)，0表示不限速
        """
        try:
            self.segment_speed_limit = max(0, limit)
            logger.info(f"分段限速已设置为: {self.segment_speed_limit} bytes/s")
            self.save_global_config()
            return True
        except Exception as e:
            logger.error(f"设置分段限速失败: {e}")
            return False

    def _calculate_optimal_config(self, file_size: int) -> tuple[int, int]:
        """
        根据文件大小和模式计算最优的线程数和分段数
        使用更激进的分段策略，媲美 IDM/迅雷
        
        Returns:
            (threads, segments) 元组
        """
        MB = 1024 * 1024
        GB = 1024 * MB
        
        if self.mode == "manual":
            # 手动模式：使用用户指定的值
            threads = self.threads
            segments = self.segments_count or self.threads
            logger.info(f"手动模式: {threads} 线程, {segments} 分段")
            return threads, segments
        
        elif self.mode == "threads_only":
            # 仅设置线程，分段数自动
            threads = self.threads
            # 根据文件大小自动计算分段数（更激进）
            if file_size < 10 * MB:
                segments = min(threads, 4)
            elif file_size < 50 * MB:
                segments = min(threads, 8)
            elif file_size < 200 * MB:
                segments = min(threads, 16)
            elif file_size < 500 * MB:
                segments = min(threads, 32)
            else:
                segments = threads
            logger.info(f"线程优先模式: {threads} 线程, {segments} 分段（自动）")
            return threads, segments
        
        elif self.mode == "segments_only":
            # 仅设置分段，线程数自动
            segments = self.segments_count or 16
            # 根据文件大小自动计算线程数
            if file_size < 10 * MB:
                threads = min(segments, 4)
            elif file_size < 50 * MB:
                threads = min(segments, 8)
            elif file_size < 200 * MB:
                threads = min(segments, 16)
            elif file_size < 500 * MB:
                threads = min(segments, 32)
            else:
                threads = segments
            logger.info(f"分段优先模式: {threads} 线程（自动）, {segments} 分段")
            return threads, segments
        
        else:  # auto mode - 全自动智能模式
            # 使用动态分段策略，根据文件大小和理想分段大小计算
            if self.enable_dynamic_segments:
                return self._calculate_dynamic_segments(file_size)
            
            # 传统固定分段策略（作为后备）
            if file_size < 5 * MB:
                threads, segments = 1, 1
            elif file_size < 10 * MB:
                threads, segments = 4, 4
            elif file_size < 30 * MB:
                threads, segments = 8, 8
            elif file_size < 100 * MB:
                threads, segments = 16, 16
            elif file_size < 300 * MB:
                threads, segments = 24, 24
            else:  # >= 300 MB
                threads, segments = 32, 32
            logger.info(f"自动模式: 文件大小 {file_size/MB:.1f}MB -> {threads} 线程, {segments} 分段")
            return threads, segments
    
    def _calculate_dynamic_segments(self, file_size: int) -> tuple[int, int]:
        """
        动态计算最优分段数，基于理想分段大小
        目标：每个分段 5-10MB，平衡速度和稳定性
        """
        MB = 1024 * 1024
        
        # 小文件不分段
        if file_size < DynamicSegmentConfig.SMALL_FILE_THRESHOLD:
            segments = max(1, file_size // (2 * MB))  # 每2MB一个分段
            segments = min(segments, 8)
            logger.info(f"动态分段(小文件): {file_size/MB:.1f}MB -> {segments} 分段")
            return segments, segments
        
        # 计算理想分段数
        ideal_segments = file_size // DynamicSegmentConfig.IDEAL_SEGMENT_SIZE
        
        # 限制分段数范围 (最大32)
        min_segments = 4
        max_segments = 32
        
        # 超大文件使用更多分段
        if file_size >= DynamicSegmentConfig.LARGE_FILE_THRESHOLD:
            min_segments = 16
            max_segments = 32
        
        segments = max(min_segments, min(max_segments, ideal_segments))
        
        # 确保每个分段不会太小
        segment_size = file_size // segments
        if segment_size < DynamicSegmentConfig.MIN_SEGMENT_SIZE:
            segments = max(1, file_size // DynamicSegmentConfig.MIN_SEGMENT_SIZE)
        
        # 确保每个分段不会太大
        if segment_size > DynamicSegmentConfig.MAX_SEGMENT_SIZE:
            segments = max(segments, file_size // DynamicSegmentConfig.MAX_SEGMENT_SIZE)
        
        segments = max(1, min(32, segments))
        
        logger.info(f"动态分段: 文件大小 {file_size/MB:.1f}MB -> {segments} 分段 (每段约 {file_size/segments/MB:.1f}MB)")
        return segments, segments

    async def _get_file_size(self, url: str, headers: Dict) -> tuple[int, bool]:
        """获取文件大小和是否支持断点续传"""
        timeout = aiohttp.ClientTimeout(total=None, connect=15, sock_read=30)
        
        ssl_configs = [
            {"ssl": True},
            {"ssl": False}
        ]
        
        last_error = None
        
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
                    # 先尝试 HEAD 请求
                    try:
                        async with session.head(url, headers=headers, allow_redirects=True, ssl=ssl_config["ssl"]) as resp:
                            if resp.status == 200:
                                content_length = resp.headers.get("Content-Length")
                                accept_ranges = resp.headers.get("Accept-Ranges", "").lower()
                                supports_range = accept_ranges == "bytes"
                                
                                if content_length:
                                    file_size = int(content_length)
                                    logger.info(f"HEAD 请求成功: 文件大小 {file_size} bytes, 支持Range: {supports_range}")
                                    return file_size, supports_range
                                else:
                                    logger.warning("HEAD 请求成功但没有 Content-Length，尝试 GET 请求")
                    except Exception as head_error:
                        logger.debug(f"HEAD 请求失败: {head_error}，尝试 GET 请求")
                    
                    # 如果 HEAD 失败，尝试 GET 请求（只读取头部）
                    try:
                        range_header = headers.copy()
                        range_header["Range"] = "bytes=0-0"  # 只请求第一个字节
                        
                        async with session.get(url, headers=range_header, allow_redirects=True, ssl=ssl_config["ssl"]) as resp:
                            if resp.status in (200, 206):
                                content_length = resp.headers.get("Content-Length")
                                content_range = resp.headers.get("Content-Range", "")
                                
                                # 从 Content-Range 解析文件大小
                                if content_range:
                                    # Content-Range: bytes 0-0/12345
                                    try:
                                        total_size = int(content_range.split('/')[-1])
                                        logger.info(f"GET 请求成功: 文件大小 {total_size} bytes (从 Content-Range)")
                                        return total_size, True
                                    except:
                                        pass
                                
                                # 从 Content-Length 获取
                                if content_length:
                                    file_size = int(content_length)
                                    supports_range = resp.status == 206
                                    logger.info(f"GET 请求成功: 文件大小 {file_size} bytes, 支持Range: {supports_range}")
                                    return file_size, supports_range
                    except Exception as get_error:
                        logger.debug(f"GET 请求失败: {get_error}")
                        last_error = get_error
                        
            except Exception as e:
                logger.warning(f"获取文件大小失败 (SSL={ssl_config['ssl']}): {e}")
                last_error = e
                continue
        
        # 所有尝试都失败了
        error_msg = f"无法获取文件大小: {last_error}" if last_error else "无法获取文件大小"
        logger.error(error_msg)
        return 0, False

    def _get_temp_folder(self, filepath: Path) -> Path:
        """获取临时文件夹路径，如果存在重名则添加后缀"""
        base_name = filepath.stem  # 文件名（不含扩展名）
        temp_folder = filepath.parent / f"{base_name}_temp"
        
        # 处理重名情况
        counter = 2
        while temp_folder.exists():
            # 检查是否是一个有效的临时文件夹（包含 .part 文件）
            part_files = list(temp_folder.glob("*.part*"))
            if part_files:
                # 如果包含分段文件，说明是之前的下载，可以复用
                break
            # 否则添加后缀
            temp_folder = filepath.parent / f"{base_name}_temp_{counter}"
            counter += 1
        
        return temp_folder

    async def _download_segment(self, semaphore: asyncio.Semaphore, session: aiohttp.ClientSession, taskId: str, segment: Segment, headers: Dict, filepath: Path):
        """
        下载单个分段 (复用 Session 和 Semaphore，带智能重试与退避)
        
        优化点：
        1. 增加重试次数到5次
        2. 使用指数退避 + 抖动
        3. 更大的读取缓冲区 (128KB)
        4. 智能错误分类和处理
        """
        MAX_RETRIES = self.max_retries
        retry_count = 0
        
        async with semaphore:
            while retry_count < MAX_RETRIES:
                t = self.tasks.get(taskId)
                if not t:
                    return
                
                # 检查任务状态
                if t.status == TaskStatus.CANCELLED:
                    segment.status = "cancelled"
                    return
                if t.status == TaskStatus.PAUSED:
                    segment.status = "paused"
                    return
                
                # -------------------------------------------------------------------------
                # 核心修复: 基于磁盘实际文件大小修正下载进度，确保断点续传的准确性
                # -------------------------------------------------------------------------
                temp_folder = self._get_temp_folder(filepath)
                temp_folder.mkdir(parents=True, exist_ok=True)
                temp_file = temp_folder / f"{filepath.name}.part{segment.index}"
                
                segment_size = segment.endByte - segment.startByte
                
                if temp_file.exists():
                    disk_file_size = temp_file.stat().st_size
                    
                    if disk_file_size > segment_size:
                        logger.warning(f"分段 {segment.index}: 临时文件大小 ({disk_file_size}) 超过分段大小 ({segment_size})，重置该分段")
                        try:
                            temp_file.unlink()
                        except:
                            pass
                        segment.downloadedBytes = 0
                    else:
                        segment.downloadedBytes = disk_file_size
                else:
                    segment.downloadedBytes = 0
                    
                # 检查是否已完成
                if segment.downloadedBytes >= segment_size:
                    segment.status = "completed"
                    logger.info(f"分段 {segment.index} 已完成 (从磁盘恢复)")
                    return

                segment.status = "downloading"
                range_header = headers.copy()
                current_start = segment.startByte + segment.downloadedBytes
                range_header["Range"] = f"bytes={current_start}-{segment.endByte - 1}"
                
                logger.info(f"分段 {segment.index} 开始下载: Range={range_header['Range']}, 已下载={segment.downloadedBytes}/{segment_size}")
                
                ssl_configs = [{"ssl": True}, {"ssl": False}]
                
                start_time = time.perf_counter()
                last_update = start_time
                
                # EMA (Exponential Moving Average) 速度平滑因子
                alpha = 0.1
                current_speed = 0.0
                
                for ssl_config in ssl_configs:
                    try:
                        # 构建 SSL 上下文（如果需要）
                        ssl_ctx = ssl_config["ssl"]
                        if not ssl_ctx:
                            import ssl
                            ssl_ctx = ssl.create_default_context()
                            ssl_ctx.check_hostname = False
                            ssl_ctx.verify_mode = ssl.CERT_NONE

                        # 发起请求
                        async with session.get(t.url, headers=range_header, allow_redirects=True, ssl=ssl_ctx) as resp:
                            if resp.status not in (200, 206):
                                raise Exception(f"HTTP {resp.status}")
                            
                            # 检查是否支持 Range
                            if resp.status == 200:
                                if segment.downloadedBytes > 0:
                                    logger.warning(f"分段 {segment.index}: 服务器不支持Range")
                                    segment.status = "failed"
                                    return
                                segment.status = "failed"
                                return
                            
                            mode = "ab" if segment.downloadedBytes > 0 else "wb"
                            
                            async with aiofiles.open(temp_file, mode) as f:
                                bytes_since_last_update = 0
                                virtual_time = time.perf_counter()
                                
                                # 使用更大的 Buffer Size (128KB) 以提高IO效率
                                async for chunk in resp.content.iter_chunked(self.chunk_size):
                                    if t.status == TaskStatus.CANCELLED:
                                        segment.status = "cancelled"
                                        return
                                    
                                    if t.status == TaskStatus.PAUSED or segment.status == "paused":
                                        segment.status = "paused"
                                        return
                                    
                                    remaining = segment_size - segment.downloadedBytes
                                    if remaining <= 0:
                                        break
                                    
                                    chunk_to_write = chunk[:remaining] if len(chunk) > remaining else chunk
                                    chunk_len = len(chunk_to_write)
                                    await f.write(chunk_to_write)
                                    
                                    bytes_since_last_update += chunk_len
                                    segment.downloadedBytes += chunk_len
                                    
                                    # Speed Limiting
                                    if self.segment_speed_limit > 0:
                                        chunk_duration = chunk_len / self.segment_speed_limit
                                        virtual_time += chunk_duration
                                        current_now = time.perf_counter()
                                        if virtual_time > current_now:
                                            await asyncio.sleep(virtual_time - current_now)
                                        else:
                                            virtual_time = current_now
                                    
                                    # 更新速度 (EMA 平滑)
                                    now = time.perf_counter()
                                    if now - last_update >= 0.5:
                                        time_elapsed = now - last_update
                                        if time_elapsed > 0:
                                            instant_speed = bytes_since_last_update / time_elapsed
                                            # 使用 EMA 平滑速度显示
                                            if current_speed == 0:
                                                current_speed = instant_speed
                                            else:
                                                current_speed = (alpha * instant_speed) + ((1 - alpha) * current_speed)
                                            
                                            segment.speed = current_speed
                                            bytes_since_last_update = 0
                                        last_update = now
                                    
                                    if segment.downloadedBytes >= segment_size:
                                        break
                            
                            # 确保文件写入完成
                            await f.flush()
                            
                        # 验证下载完整性
                        if temp_file.exists():
                            actual_size = temp_file.stat().st_size
                            if actual_size == segment_size:
                                segment.status = "completed"
                                segment.downloadedBytes = actual_size
                                logger.info(f"分段 {segment.index} 完成: {actual_size} bytes")
                            else:
                                logger.warning(f"分段 {segment.index} 大小不匹配: 期望 {segment_size}, 实际 {actual_size}")
                                segment.downloadedBytes = actual_size
                                # 如果下载不完整，不标记为完成，让重试机制处理
                                if actual_size < segment_size:
                                    raise Exception(f"分段下载不完整: {actual_size}/{segment_size} bytes")
                                segment.status = "completed"
                        else:
                            raise Exception(f"分段文件不存在: {temp_file}")
                        return
                            
                    except Exception as e:
                        error_str = str(e)
                        logger.warning(f"分段 {segment.index} 异常: {error_str}")
                        segment.lastError = error_str
                        
                        # 分类错误类型
                        is_network_error = any(x in error_str.lower() for x in [
                            'timeout', 'connection', 'reset', 'refused', 'network'
                        ])
                        is_server_error = any(x in error_str for x in ['500', '502', '503', '504'])
                        
                        if ssl_config == ssl_configs[-1]:
                            # 所有SSL配置都尝试失败，增加重试计数
                            retry_count += 1
                            segment.retryCount = retry_count
                            
                            if retry_count < MAX_RETRIES:
                                # 使用指数退避 + 随机抖动
                                import random
                                base_wait = self.retry_delay_base ** retry_count
                                jitter = random.uniform(0, base_wait * 0.3)
                                wait_time = base_wait + jitter
                                
                                # 网络错误等待更长时间
                                if is_network_error:
                                    wait_time *= 1.5
                                elif is_server_error:
                                    wait_time *= 2  # 服务器错误等待更长
                                
                                logger.info(f"分段 {segment.index} 将在 {wait_time:.1f} 秒后重试 ({retry_count}/{MAX_RETRIES})")
                                await asyncio.sleep(wait_time)
                                
                                # 更新网络统计
                                self._network_stats['failed_connections'] += 1
                                
                                break  # 跳出ssl_configs循环，重新开始while循环
                            else:
                                segment.status = "failed"
                                logger.error(f"分段 {segment.index} 重试 {MAX_RETRIES} 次后最终失败: {error_str}")
                                return
                else:
                    # 如果for循环正常结束（没有break），说明下载成功，退出while循环
                    self._network_stats['successful_connections'] += 1
                    break
            
            # 如果while循环结束但分段未完成，标记为失败
            if segment.status != "completed":
                segment.status = "failed"
                logger.error(f"分段 {segment.index} 下载失败")

    async def _merge_segments(self, taskId: str, filepath: Path):
        """合并所有分段并删除临时文件夹"""
        segments = self.segments.get(taskId, [])
        if not segments:
            return
        
        logger.info(f"开始合并 {len(segments)} 个分段...")
        
        # 获取临时文件夹
        temp_folder = self._get_temp_folder(filepath)
        
        # 验证所有分段是否完整
        total_expected = 0
        total_actual = 0
        incomplete_segments = []
        
        for segment in sorted(segments, key=lambda s: s.index):
            expected_size = segment.endByte - segment.startByte
            total_expected += expected_size
            
            temp_file = temp_folder / f"{filepath.name}.part{segment.index}"
            if temp_file.exists():
                actual_size = temp_file.stat().st_size
                total_actual += actual_size
                
                if actual_size != expected_size:
                    incomplete_segments.append({
                        "index": segment.index,
                        "expected": expected_size,
                        "actual": actual_size,
                        "missing": expected_size - actual_size
                    })
                    logger.warning(f"分段 {segment.index} 不完整: 期望 {expected_size} bytes, 实际 {actual_size} bytes, 缺少 {expected_size - actual_size} bytes")
            else:
                incomplete_segments.append({
                    "index": segment.index,
                    "expected": expected_size,
                    "actual": 0,
                    "missing": expected_size
                })
                logger.error(f"分段 {segment.index} 文件不存在!")
        
        if incomplete_segments:
            logger.error(f"发现 {len(incomplete_segments)} 个不完整的分段，总计缺少 {total_expected - total_actual} bytes")
            # 不合并不完整的文件，标记任务失败
            t = self.tasks.get(taskId)
            if t:
                t.status = TaskStatus.FAILED
                t.errorMessage = f"分段下载不完整: {len(incomplete_segments)} 个分段缺少数据"
            return
        
        logger.info(f"所有分段验证通过，总大小: {total_actual} bytes")
        
        async with aiofiles.open(filepath, "wb") as output:
            for segment in sorted(segments, key=lambda s: s.index):
                temp_file = temp_folder / f"{filepath.name}.part{segment.index}"
                if temp_file.exists():
                    async with aiofiles.open(temp_file, "rb") as input_file:
                        content = await input_file.read()
                        await output.write(content)
                    # 删除临时文件
                    temp_file.unlink()
                    logger.debug(f"已删除分段文件: {temp_file.name}")
        
        # 验证合并后的文件大小
        merged_size = filepath.stat().st_size
        if merged_size != total_expected:
            logger.error(f"合并后文件大小不正确: 期望 {total_expected} bytes, 实际 {merged_size} bytes")
        else:
            logger.info(f"文件合并成功，大小: {merged_size} bytes")
        
        # 删除临时文件夹
        try:
            if temp_folder.exists():
                # 确保文件夹为空后再删除
                remaining_files = list(temp_folder.iterdir())
                if remaining_files:
                    logger.warning(f"临时文件夹不为空，包含 {len(remaining_files)} 个文件")
                    for f in remaining_files:
                        logger.warning(f"  - {f.name}")
                else:
                    temp_folder.rmdir()
                    logger.info(f"已删除临时文件夹: {temp_folder.name}")
        except Exception as e:
            logger.error(f"删除临时文件夹失败: {e}")
        
        logger.info("分段合并完成")

    async def _run_download(self, taskId: str):
        logger.info(f"_run_download 开始: taskId={taskId}")
        t = self.tasks.get(taskId)
        if not t:
            logger.error(f"_run_download: 找不到任务 {taskId}")
            return
        
        logger.info(f"_run_download: 任务={t.filename}, 状态={t.status}")
        
        # 如果任务已经在下载中且有分段在运行，不重复启动
        if t.status == TaskStatus.DOWNLOADING and taskId in self.segments:
            existing_segments = self.segments[taskId]
            downloading_count = sum(1 for seg in existing_segments if seg.status == "downloading")
            logger.info(f"检测到已有 {len(existing_segments)} 个分段，其中 {downloading_count} 个正在下载")
            
            if any(seg.status == "downloading" for seg in existing_segments):
                logger.warning(f"任务 {t.filename} 已经在下载中，跳过重复启动")
                return
            else:
                # 重置所有非completed分段的状态为pending，准备重新下载
                logger.info(f"准备重置分段状态...")
                for seg in existing_segments:
                    if seg.status != "completed":
                        old_status = seg.status
                        seg.status = "pending"
                        logger.info(f"重置分段 {seg.index}: {old_status} -> pending, 已下载: {seg.downloadedBytes} bytes")
                logger.info(f"任务 {t.filename} 从暂停/失败恢复，已重置分段状态")
        
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
                # 无法获取文件大小，使用单线程下载（适用于动态生成的文件，如 GitHub 源码下载）
                logger.warning(f"无法获取文件大小，将使用单线程下载: {t.filename}")
                t.totalSize = 0  # 未知大小
                await self._single_thread_download(taskId, headers, filepath)
                self._check_queue()
                return
            
            t.totalSize = file_size
            logger.info(f"文件大小: {file_size} bytes, 支持分段: {supports_range}")
            
            # 检查是否已有分段（恢复下载的情况）
            existing_segments = self.segments.get(taskId)
            
            if existing_segments:
                # 恢复下载，使用已有的分段
                segments = existing_segments
                optimal_threads = len(segments) # 这里的逻辑可能不准确，因为segments可能很多，但threads应该受限
                # 重新计算最优线程数
                calc_threads, _ = self._calculate_optimal_config(file_size)
                optimal_threads = min(len(segments), calc_threads)
                optimal_segments = len(segments)
                logger.info(f"恢复下载: 使用已有的 {optimal_segments} 个分段，线程数: {optimal_threads}")
            else:
                # 新下载，计算最优配置
                optimal_threads, optimal_segments = self._calculate_optimal_config(file_size)
                
                # 尝试分段下载
                if file_size > 1024 * 1024 and optimal_segments > 1:  # 大于1MB且分段数>1才分段
                    # 创建分段
                    segment_size = file_size // optimal_segments
                    segments = []
                    
                    for i in range(optimal_segments):
                        start = i * segment_size
                        end = file_size if i == optimal_segments - 1 else (i + 1) * segment_size
                        segment = Segment(
                            index=i,
                            startByte=start,
                            endByte=end
                        )
                        segments.append(segment)
                    
                    self.segments[taskId] = segments
                    logger.info(f"创建 {optimal_segments} 个下载分段，使用 {optimal_threads} 个线程")
                else:
                    segments = None
            
            # 如果有分段，进行多线程下载
            if segments:
                # 打印分段信息
                print(f"\n{'='*60}")
                print(f"{'恢复' if existing_segments else '开始'}多线程下载: {t.filename}")
                print(f"文件大小: {file_size / (1024*1024):.2f} MB")
                print(f"模式: {self.mode}")
                print(f"线程数: {optimal_threads}")
                print(f"分段数: {optimal_segments}")
                print(f"{'='*60}\n")
                
                # -----------------------------------------------------------------
                # 核心优化: 高性能连接配置，媲美 IDM/迅雷
                # -----------------------------------------------------------------
                timeout = aiohttp.ClientTimeout(
                    total=None,  # 无总超时
                    connect=self.connection_timeout,
                    sock_read=self.read_timeout,
                    sock_connect=self.connection_timeout
                )
                
                # 禁用 SSL 验证以提高速度 (在 connector 级别)
                import ssl
                ssl_context = ssl.create_default_context()
                ssl_context.check_hostname = False
                ssl_context.verify_mode = ssl.CERT_NONE
                
                # 高性能连接器配置
                connector = aiohttp.TCPConnector(
                    limit=optimal_threads * 2,  # 允许更多连接池
                    limit_per_host=min(32, max(1, optimal_threads)),  # 提升单主机并发
                    ttl_dns_cache=600,  # DNS缓存10分钟
                    force_close=False,
                    enable_cleanup_closed=True,
                    ssl=ssl_context,
                    keepalive_timeout=60,  # 保持连接60秒
                )
                
                # 修复：自动模式下所有分段同时开始下载
                # 不再使用慢启动，直接使用目标并发数
                semaphore = asyncio.Semaphore(optimal_threads)
                
                async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
                    # 并发下载所有分段
                    download_tasks = []
                    for segment in segments:
                        # 下载所有未完成的分段
                        if segment.status != "completed":
                            logger.info(f"启动分段 {segment.index} 下载，当前状态: {segment.status}")
                            task_coro = self._download_segment(semaphore, session, taskId, segment, headers, filepath)
                            download_tasks.append(task_coro)
                    
                    if not download_tasks:
                        logger.info("所有分段已下载完成，尝试直接合并")
                    else:
                        # 启动进度监控
                        monitor_task = asyncio.create_task(self._monitor_progress(taskId))
                        
                        logger.info(f"同时启动 {len(download_tasks)} 个分段下载任务，并发数: {optimal_threads}")
                        
                        # 等待所有分段下载完成
                        await asyncio.gather(*download_tasks, return_exceptions=True)
                        
                        # 停止监控
                        monitor_task.cancel()
                
                # 检查任务是否被暂停或取消
                if t.status == TaskStatus.PAUSED:
                    logger.info(f"任务 {t.filename} 已暂停，不进行合并")
                    return
                
                if t.status == TaskStatus.CANCELLED:
                    logger.info(f"任务 {t.filename} 已取消，不进行合并")
                    return
                
                # 检查是否有分段失败
                failed_segments = [seg for seg in segments if seg.status == "failed"]
                if failed_segments:
                    logger.warning(f"检测到 {len(failed_segments)} 个分段失败，尝试智能重试...")
                    
                    # 检查是否是服务器不支持Range的情况
                    range_not_supported = any(
                        "不支持Range" in (seg.lastError or "") or 
                        seg.downloadedBytes == 0 and seg.retryCount >= 2
                        for seg in failed_segments
                    )
                    
                    if range_not_supported:
                        logger.warning(f"服务器不支持分段下载，回退到单线程模式")
                        print(f"\n服务器不支持分段下载，切换到单线程模式...\n")
                        
                        # 清理临时文件夹
                        temp_folder = self._get_temp_folder(filepath)
                        if temp_folder.exists():
                            import shutil
                            shutil.rmtree(temp_folder)
                            logger.info(f"已删除临时文件夹: {temp_folder.name}")
                        
                        # 使用单线程下载
                        t.downloadedSize = 0
                        t.progress = 0.0
                        self.segments.pop(taskId, None)
                        await self._single_thread_download(taskId, headers, filepath)
                        return
                    
                    # 尝试重试失败的分段
                    retry_success = await self._retry_failed_segments(
                        taskId, session, semaphore, headers, filepath
                    )
                    
                    if not retry_success:
                        # 仍有失败的分段，标记任务失败
                        still_failed = [seg for seg in segments if seg.status == "failed"]
                        logger.error(f"任务 {t.filename} 有 {len(still_failed)} 个分段最终失败")
                        t.status = TaskStatus.FAILED
                        t.errorMessage = f"{len(still_failed)} 个分段下载失败"
                        self.add_progress(t)
                        self._check_queue()
                        return
                
                # 检查是否所有分段都已完成
                all_completed = all(seg.status == "completed" for seg in segments)
                if not all_completed:
                    logger.warning(f"任务 {t.filename} 有分段未完成，不进行合并")
                    paused_segments = [seg for seg in segments if seg.status == "paused"]
                    if paused_segments:
                        logger.info(f"任务 {t.filename} 有 {len(paused_segments)} 个分段被暂停")
                    return
                
                # 设置状态为正在合并
                t.status = TaskStatus.MERGING
                t.progress = 100.0  # 保持100%进度
                self.add_progress(t)
                logger.info(f"开始校验和合并分段: {t.filename}")
                
                # 合并分段
                await self._merge_segments(taskId, filepath)
                
                # 下载完成
                t.progress = 100.0
                t.downloadedSize = file_size
                t.status = TaskStatus.COMPLETED
                self.add_complete(t)
                logger.info(f"[下载完成] 文件: {t.filename}, 大小: {file_size/1024/1024:.2f} MB")
                
                print(f"\n{'='*60}")
                print(f"下载完成: {t.filename}")
                print(f"{'='*60}\n")

                # 任务完成，释放位置，检查队列
                self._check_queue()
                
            else:
                # 不支持分段或文件太小，使用单线程下载
                logger.info("使用单线程下载")
                await self._single_thread_download(taskId, headers, filepath)
                
                # 单线程下载完成后也需要检查队列
                self._check_queue()
                
        except Exception as e:
            import traceback
            error_msg = str(e)
            logger.error(f"下载失败 {t.filename}: {error_msg}")
            logger.error(f"详细错误: {traceback.format_exc()}")
            logger.error(f"[下载失败] 文件: {t.filename}, 原因: {error_msg}")
            print(f"\n{'='*60}")
            print(f"下载失败: {t.filename}")
            print(f"错误: {error_msg}")
            print(f"{'='*60}\n")
            
            t.status = TaskStatus.FAILED
            t.errorMessage = error_msg
            self.add_progress(t)
            
            # 任务失败，释放位置，检查队列
            self._check_queue()

    async def _monitor_progress(self, taskId: str):
        """
        监控并显示下载进度
        
        增强功能：
        1. 速度平滑显示 (EMA)
        2. 智能ETA计算
        3. 网络状态监控
        """
        t = self.tasks.get(taskId)
        if not t:
            return
        
        # 速度平滑参数
        speed_history = []
        max_history = 10
        
        try:
            while t.status == TaskStatus.DOWNLOADING:
                segments = self.segments.get(taskId, [])
                if not segments:
                    await asyncio.sleep(0.5)
                    continue
                
                # 计算总进度
                total_downloaded = sum(seg.downloadedBytes for seg in segments)
                total_speed = sum(seg.speed for seg in segments)
                
                # 速度平滑处理
                speed_history.append(total_speed)
                if len(speed_history) > max_history:
                    speed_history.pop(0)
                smoothed_speed = sum(speed_history) / len(speed_history)
                
                # 更新峰值速度
                if smoothed_speed > self._network_stats['peak_speed']:
                    self._network_stats['peak_speed'] = smoothed_speed
                self._network_stats['avg_speed'] = smoothed_speed
                
                t.downloadedSize = total_downloaded
                t.speed = smoothed_speed
                
                if t.totalSize > 0:
                    t.progress = (total_downloaded / t.totalSize) * 100.0
                    remaining = t.totalSize - total_downloaded
                    if smoothed_speed > 0:
                        t.eta = int(remaining / smoothed_speed)
                
                # 将分段信息添加到任务对象（包含更多信息）
                t.segments = [
                    {
                        "index": seg.index,
                        "startByte": seg.startByte,
                        "endByte": seg.endByte,
                        "downloadedBytes": seg.downloadedBytes,
                        "speed": seg.speed,
                        "status": seg.status,
                        "retryCount": seg.retryCount,
                        "progress": (seg.downloadedBytes / (seg.endByte - seg.startByte) * 100) if (seg.endByte - seg.startByte) > 0 else 0
                    }
                    for seg in segments
                ]
                
                # 统计分段状态
                downloading_count = sum(1 for seg in segments if seg.status == "downloading")
                completed_count = sum(1 for seg in segments if seg.status == "completed")
                failed_count = sum(1 for seg in segments if seg.status == "failed")
                
                # 记录下载进度日志
                progress_display = min(t.progress, 100.0)
                logger.info(f"[下载进度] {t.filename}: {progress_display:.1f}% | "
                           f"速度: {smoothed_speed/1024/1024:.2f} MB/s | "
                           f"已下载: {total_downloaded/1024/1024:.1f}/{t.totalSize/1024/1024:.1f} MB | "
                           f"分段: {downloading_count}下载/{completed_count}完成/{failed_count}失败")
                
                # 打印进度到控制台（简化版）
                print(f"\r[{t.filename}] {progress_display:.1f}% | {smoothed_speed/1024/1024:.2f} MB/s | "
                      f"ETA: {t.eta}s | 分段: {downloading_count}/{len(segments)}", end="")
                
                # 发布进度更新
                self.add_progress(t)
                
                await asyncio.sleep(0.5)
                
        except asyncio.CancelledError:
            logger.info(f"[下载监控] 任务 {t.filename} 的进度监控已停止")
            pass

    async def _ramp_up_semaphore(self, taskId: str, semaphore: asyncio.Semaphore, initial_concurrency: int, target_concurrency: int):
        """并发慢启动：逐步提升并发以兼顾稳定性与速度"""
        try:
            current = initial_concurrency
            while current < target_concurrency:
                t = self.tasks.get(taskId)
                if not t or t.status != TaskStatus.DOWNLOADING:
                    break
                await asyncio.sleep(2.0)
                step = min(2, target_concurrency - current)
                for _ in range(step):
                    try:
                        semaphore.release()
                    except Exception:
                        pass
                current += step
        except asyncio.CancelledError:
            return
    
    async def _retry_failed_segments(self, taskId: str, session: aiohttp.ClientSession, semaphore: asyncio.Semaphore, headers: Dict, filepath: Path) -> bool:
        """
        智能重试失败的分段
        
        Returns:
            True 如果所有分段都成功，False 如果仍有失败
        """
        t = self.tasks.get(taskId)
        if not t:
            return False
        
        segments = self.segments.get(taskId, [])
        failed_segments = [seg for seg in segments if seg.status == "failed"]
        
        if not failed_segments:
            return True
        
        logger.info(f"开始重试 {len(failed_segments)} 个失败的分段...")
        
        # 重置失败分段状态
        for seg in failed_segments:
            if seg.retryCount < self.max_retries:
                seg.status = "pending"
                logger.info(f"重置分段 {seg.index} 状态为 pending (已重试 {seg.retryCount} 次)")
        
        # 重新下载失败的分段
        retry_tasks = []
        for seg in failed_segments:
            if seg.status == "pending":
                task_coro = self._download_segment(semaphore, session, taskId, seg, headers, filepath)
                retry_tasks.append(task_coro)
        
        if retry_tasks:
            await asyncio.gather(*retry_tasks, return_exceptions=True)
        
        # 检查是否还有失败的分段
        still_failed = [seg for seg in segments if seg.status == "failed"]
        return len(still_failed) == 0
    
    def get_network_stats(self) -> Dict:
        """获取网络统计信息"""
        return {
            **self._network_stats,
            'active_tasks': self._get_active_downloads_count(),
            'total_tasks': len(self.tasks),
        }
    
    async def _preconnect(self, url: str, headers: Dict) -> bool:
        """
        预连接：在开始下载前建立连接，减少首字节延迟
        """
        try:
            timeout = aiohttp.ClientTimeout(total=5, connect=3)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.head(url, headers=headers, allow_redirects=True) as resp:
                    return resp.status in (200, 206)
        except Exception as e:
            logger.debug(f"预连接失败: {e}")
            return False
    
    def get_config(self) -> Dict:
        """获取当前配置"""
        return {
            'threads': self.threads,
            'segments': self.segments_count,
            'mode': self.mode,
            'max_concurrent_tasks': self.max_concurrent_tasks,
            'segment_speed_limit': self.segment_speed_limit,
            'chunk_size': self.chunk_size,
            'connection_timeout': self.connection_timeout,
            'read_timeout': self.read_timeout,
            'max_retries': self.max_retries,
            'enable_dynamic_segments': self.enable_dynamic_segments,
            'enable_speed_boost': self.enable_speed_boost,
        }
    
    def set_advanced_config(self, 
                           chunk_size: int = None,
                           connection_timeout: int = None,
                           read_timeout: int = None,
                           max_retries: int = None,
                           enable_dynamic_segments: bool = None,
                           enable_speed_boost: bool = None):
        """设置高级配置"""
        if chunk_size is not None:
            self.chunk_size = max(8192, min(1048576, chunk_size))  # 8KB - 1MB
        if connection_timeout is not None:
            self.connection_timeout = max(5, min(120, connection_timeout))
        if read_timeout is not None:
            self.read_timeout = max(10, min(300, read_timeout))
        if max_retries is not None:
            self.max_retries = max(1, min(10, max_retries))
        if enable_dynamic_segments is not None:
            self.enable_dynamic_segments = enable_dynamic_segments
        if enable_speed_boost is not None:
            self.enable_speed_boost = enable_speed_boost
        
        logger.info(f"高级配置已更新: chunk_size={self.chunk_size}, "
                   f"connection_timeout={self.connection_timeout}, "
                   f"read_timeout={self.read_timeout}, "
                   f"max_retries={self.max_retries}, "
                   f"dynamic_segments={self.enable_dynamic_segments}, "
                   f"speed_boost={self.enable_speed_boost}")

    async def _single_thread_download(self, taskId: str, headers: Dict, filepath: Path):
        """
        单线程下载（回退方案）
        
        优化：
        1. 更大的读取缓冲区 (128KB)
        2. 更好的超时配置
        3. 速度平滑显示
        """
        t = self.tasks.get(taskId)
        if not t:
            return
        
        timeout = aiohttp.ClientTimeout(
            total=None, 
            connect=self.connection_timeout,
            sock_read=self.read_timeout
        )
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
                        bytes_since_last_update = 0  # 用于计算瞬时速度
                        virtual_time = time.perf_counter()  # 用于限速
                        speed_alpha = 0.2  # EMA平滑因子
                        smoothed_speed = 0.0
                        
                        async with aiofiles.open(filepath, "wb") as f:
                            # 使用更大的缓冲区 (128KB)
                            async for chunk in resp.content.iter_chunked(self.chunk_size):
                                if t.status == TaskStatus.CANCELLED:
                                    return
                                
                                while t.status == TaskStatus.PAUSED:
                                    await asyncio.sleep(0.1)
                                    if t.status == TaskStatus.CANCELLED:
                                        return
                                
                                chunk_len = len(chunk)
                                await f.write(chunk)
                                t.downloadedSize += chunk_len
                                bytes_since_last_update += chunk_len
                                
                                # 单线程模式限速（如果设置了限速）
                                if self.segment_speed_limit > 0:
                                    chunk_duration = chunk_len / self.segment_speed_limit
                                    virtual_time += chunk_duration
                                    current_now = time.perf_counter()
                                    
                                    if virtual_time > current_now:
                                        sleep_time = virtual_time - current_now
                                        if sleep_time > 0:
                                            await asyncio.sleep(sleep_time)
                                    else:
                                        virtual_time = current_now
                                
                                now = time.time()
                                if t.totalSize > 0:
                                    t.progress = (t.downloadedSize / t.totalSize) * 100.0
                                
                                if now - last_update >= 0.5:
                                    time_elapsed = now - last_update
                                    if time_elapsed > 0:
                                        # 使用EMA平滑速度
                                        instant_speed = bytes_since_last_update / time_elapsed
                                        if smoothed_speed == 0:
                                            smoothed_speed = instant_speed
                                        else:
                                            smoothed_speed = (speed_alpha * instant_speed) + ((1 - speed_alpha) * smoothed_speed)
                                        
                                        t.speed = smoothed_speed
                                        bytes_since_last_update = 0  # 重置计数器
                                        if smoothed_speed > 0 and t.totalSize > 0:
                                            remaining = t.totalSize - t.downloadedSize
                                            t.eta = int(remaining / smoothed_speed)
                                    self.add_progress(t)
                                    last_update = now
                        
                        # 检查任务是否被暂停或取消
                        if t.status == TaskStatus.PAUSED:
                            logger.info(f"任务 {t.filename} 已暂停 (单线程模式)")
                            return
                        
                        if t.status == TaskStatus.CANCELLED:
                            logger.info(f"任务 {t.filename} 已取消 (单线程模式)")
                            return
                        
                        t.progress = 100.0
                        t.status = TaskStatus.COMPLETED
                        self.add_complete(t)
                        logger.info(f"[下载完成] 文件: {t.filename} (单线程模式)")
                        return
                        
            except Exception as e:
                logger.warning(f"[单线程下载] 尝试失败: {e}")
                if ssl_config != ssl_configs[-1]:
                    logger.info(f"[单线程下载] 切换SSL配置重试...")
                    continue
                else:
                    logger.error(f"[单线程下载失败] 文件: {t.filename}, 原因: {e}")
                    raise
