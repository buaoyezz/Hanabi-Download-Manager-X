import asyncio
import time
import threading
from pathlib import Path
from typing import Dict, Optional
import aiohttp
import aiofiles
import secrets
from .eventBus import get_event_bus
from .taskModel import TaskStatus, Task
from ...utils.logger import logger
from ...utils.pathUtils import getDefaultDownloadPath

class HttpDownloader:
    def __init__(self, downloadDir: Optional[str] = None, bus=None):
        self.downloadDir = Path(downloadDir) if downloadDir else Path(getDefaultDownloadPath())
        self.downloadDir.mkdir(parents=True, exist_ok=True)
        self.bus = bus or get_event_bus()
        self.tasks: Dict[str, Task] = {}
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
        t = Task(id=taskId, url=url, filename=filename, filepath=filepath, status=TaskStatus.PENDING, createdTime=time.time())
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
        try:
            setattr(t, "userAgent", ua)
            setattr(t, "referer", ref)
            setattr(t, "cookies", cookies)
            setattr(t, "headers", headers_extra if isinstance(headers_extra, dict) else {})
        except Exception:
            pass
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
                    try:
                        p.unlink()
                    except Exception:
                        pass
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

    async def _run_download(self, taskId: str):
        t = self.tasks.get(taskId)
        if not t:
            return
        t.status = TaskStatus.DOWNLOADING
        self.add_progress(t)
        ua = getattr(t, "userAgent", "HDM-X/1.0 NSF-X (Nextgen Speed Force X)")
        headers = {
            "User-Agent": ua,
            "Accept": "*/*",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive"
        }
        ref = getattr(t, "referer", "")
        if ref:
            headers["Referer"] = ref
            try:
                from urllib.parse import urlparse
                _rp = urlparse(ref)
                if _rp.scheme and _rp.netloc:
                    headers["Origin"] = f"{_rp.scheme}://{_rp.netloc}"
            except Exception:
                pass
        ck = getattr(t, "cookies", "")
        if ck:
            headers["Cookie"] = ck
        extra = getattr(t, "headers", {})
        if isinstance(extra, dict):
            try:
                headers.update({k: v for k, v in extra.items() if isinstance(k, str)})
            except Exception:
                pass
        resumeBytes = 0
        p = Path(t.filepath)
        logger.debug(f"检查文件路径: {t.filepath}")
        logger.debug(f"文件是否存在: {p.exists()}")
        
        if p.exists():
            try:
                resumeBytes = p.stat().st_size
                logger.debug(f"现有文件大小: {resumeBytes} bytes")
                if resumeBytes > 0:
                    headers["Range"] = f"bytes={resumeBytes}-"
                    logger.debug(f"设置断点续传: {resumeBytes} bytes")
            except Exception as e:
                logger.warning(f"获取文件大小失败: {e}")
                resumeBytes = 0
        timeout = aiohttp.ClientTimeout(total=None, connect=15)
        
        # 尝试两种SSL配置：先尝试安全连接，失败后尝试不安全连接
        ssl_configs = [
            {"ssl": True, "description": "安全SSL连接"},
            {"ssl": False, "description": "不验证SSL证书"}
        ]
        
        last_error = None
        
        for ssl_config in ssl_configs:
            try:
                logger.debug(f"尝试{ssl_config['description']}: {t.url}")
                
                connector_kwargs = {}
                if not ssl_config["ssl"]:
                    import ssl
                    ssl_context = ssl.create_default_context()
                    ssl_context.check_hostname = False
                    ssl_context.verify_mode = ssl.CERT_NONE
                    connector_kwargs["ssl"] = ssl_context
                
                connector = aiohttp.TCPConnector(**connector_kwargs)
                async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
                    ssl_param = ssl_config["ssl"]
                    logger.debug(f"发送请求: {t.url}, headers: {headers}")
                    async with session.get(t.url, headers=headers, allow_redirects=True, ssl=ssl_param) as resp:
                        logger.debug(f"收到响应: {resp.status} {resp.reason}")
                        if resp.status == 416:
                            logger.warning(f"收到HTTP 416错误，删除部分文件并重新开始下载: {t.filepath}")
                            try:
                                p = Path(t.filepath)
                                if p.exists():
                                    try:
                                        p.unlink()
                                        logger.debug(f"已删除部分文件: {t.filepath}")
                                    except Exception as e:
                                        logger.warning(f"删除部分文件失败: {e}")
                            except Exception as e:
                                logger.warning(f"处理部分文件时出错: {e}")
                            
                            # 移除Range头并重新请求
                            if "Range" in headers:
                                try:
                                    del headers["Range"]
                                    logger.debug("已移除Range头，重新开始完整下载")
                                except Exception:
                                    pass
                            
                            async with session.get(t.url, headers=headers, allow_redirects=True, ssl=ssl_param) as resp2:
                                if resp2.status not in (200, 206):
                                    raise Exception(f"重试后仍收到HTTP {resp2.status}")
                                resp = resp2
                                logger.debug(f"重试成功，状态码: {resp2.status}")
                        elif resp.status not in (200, 206):
                            raise Exception(f"HTTP {resp.status}")
                        total = resp.headers.get("Content-Length")
                        if total:
                            total = int(total)
                            if resp.status == 206:
                                t.totalSize = resumeBytes + total
                            else:
                                t.totalSize = total
                        cd = resp.headers.get("Content-Disposition", "")
                        if "filename=" in cd and not t.filename:
                            part = cd.split("filename=")[1].strip('"\'')

                            if ";" in part:
                                part = part.split(";")[0].strip()
                            t.filename = part
                            t.filepath = str(self.downloadDir / part)
                            p = Path(t.filepath)
                        if resp.status == 200:
                            mode = "wb"
                            t.downloadedSize = 0
                        else:
                            mode = "ab"
                            t.downloadedSize = resumeBytes
                        p.parent.mkdir(parents=True, exist_ok=True)
                        start = time.time()
                        last = start
                        async with aiofiles.open(p, mode) as f:
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
                                if now - last >= 0.5:
                                    elapsed = now - start
                                    if elapsed > 0:
                                        t.speed = t.downloadedSize / elapsed
                                        if t.speed > 0 and t.totalSize > 0:
                                            rem = t.totalSize - t.downloadedSize
                                            t.eta = int(rem / t.speed)
                                    self.add_progress(t)
                                    last = now
                        if t.status == TaskStatus.DOWNLOADING:
                            t.progress = 100.0
                            t.status = TaskStatus.COMPLETED
                            self.add_complete(t)
                            logger.info(f"下载成功完成: {t.filename}")
                            return  # 成功完成，退出重试循环
                    
            except Exception as e:
                last_error = e
                error_msg = str(e)
                logger.warning(f"使用{ssl_config['description']}下载失败: {error_msg}")
                
                # 如果是SSL相关错误且还有其他配置可尝试，继续下一个配置
                if ("SSL" in error_msg or "certificate" in error_msg.lower()) and ssl_config != ssl_configs[-1]:
                    logger.info(f"检测到SSL错误，尝试下一个配置...")
                    continue
                else:
                    # 非SSL错误或已是最后一个配置，直接失败
                    break
        
        # 所有SSL配置都失败了
        if last_error:
            import traceback
            error_msg = str(last_error)
            logger.error(f"所有连接方式都失败 {t.filename}: {error_msg}")
            logger.debug(f"详细错误信息: {traceback.format_exc()}")
            
            t.status = TaskStatus.FAILED
            t.errorMessage = error_msg
            self.add_progress(t)