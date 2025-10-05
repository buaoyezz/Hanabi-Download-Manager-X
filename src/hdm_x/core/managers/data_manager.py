"""
DataManager 
"""

import json
import os
import time
import asyncio
from typing import List, Dict, Optional
from pathlib import Path
# 不再直接导入下载引擎，而是通过依赖注入
from ...utils.logger import logger
from ...utils.pathUtils import getDefaultDownloadPath


class DataManager:
    """数据管理器"""
    
    def __init__(self, data_file: str = "data/downloads.json"):
        self.data_file = Path(data_file)
        self.data_file.parent.mkdir(parents=True, exist_ok=True)
        self._data = self._load_data()
        
        # 下载核心将通过依赖注入设置
        self.download_core = None
        
        # UI刷新回调列表
        self.ui_refresh_callbacks = []
    
    def add_ui_refresh_callback(self, callback):
        """添加UI刷新回调"""
        if callback not in self.ui_refresh_callbacks:
            self.ui_refresh_callbacks.append(callback)
            logger.debug("UI刷新回调已添加")
    
    def remove_ui_refresh_callback(self, callback):
        """移除UI刷新回调"""
        if callback in self.ui_refresh_callbacks:
            self.ui_refresh_callbacks.remove(callback)
            logger.debug("UI刷新回调已移除")
    
    def _trigger_ui_refresh(self):
        """触发UI刷新"""
        for callback in self.ui_refresh_callbacks:
            try:
                callback()
                logger.debug("UI刷新回调执行成功")
            except Exception as e:
                logger.error(f"UI刷新回调执行失败: {e}")
    
    def set_download_core(self, download_core):
        """设置下载核心引用"""
        self.download_core = download_core
        if download_core:
            logger.info("下载核心已设置，回调已注册")
        else:
            logger.warning("下载核心未设置，无法注册回调")
    
    def _start_task_monitor(self):
        """启动任务状态监控器"""
        import threading
        
        def monitor_tasks():
            """监控任务状态，处理卡住的任务"""
            import time
            
            while self.download_core:
                try:
                    # 每5秒检查一次状态同步
                    time.sleep(5)
                    
                    # 同步Go引擎状态到UI
                    asyncio.run(self._sync_engine_status())
                    
                    # 每30秒检查长时间pending的任务
                    if int(time.time()) % 30 == 0:
                        self._check_stuck_tasks()
                            
                except Exception as e:
                    logger.error(f"任务监控器错误: {e}")
        
        monitor_thread = threading.Thread(target=monitor_tasks, daemon=True)
        monitor_thread.start()
        logger.info("任务状态监控器已启动")
    
    async def _sync_engine_status(self):
        """同步引擎状态到UI"""
        if not self.download_core:
            return
        
        # 本地格式化方法：自适应单位
        def _fmt_bytes(v):
            try:
                v = int(v or 0)
            except Exception:
                v = 0
            units = ["B", "KB", "MB", "GB", "TB"]
            size = float(v)
            idx = 0
            while size >= 1024 and idx < len(units) - 1:
                size /= 1024.0
                idx += 1
            if idx == 0:
                return f"{int(size)} B"
            return f"{size:.1f} {units[idx]}"
        
        def _fmt_speed(v):
            try:
                v = float(v or 0.0)
            except Exception:
                v = 0.0
            units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
            speed = float(v)
            idx = 0
            while speed >= 1024 and idx < len(units) - 1:
                speed /= 1024.0
                idx += 1
            if idx == 0:
                return f"{int(speed)} B/s"
            return f"{speed:.1f} {units[idx]}"
        
        try:
            # 获取引擎中的所有任务（兼容同步/异步）
            import asyncio as _asyncio
            _get_all = getattr(self.download_core, "get_all_tasks", None)
            if _get_all:
                if _asyncio.iscoroutinefunction(_get_all):
                    go_tasks = await _get_all()
                else:
                    go_tasks = _get_all()
            else:
                go_tasks = []
            
            # 更新UI中的任务状态
            downloads = self._data.get("downloads", [])
            updated = False
            
            for go_task in go_tasks:
                # 查找对应的UI任务
                for i, download in enumerate(downloads):
                    if download.get("core_id") == go_task.id:
                        # 检查状态是否需要更新
                        current_status = download.get("status")
                        go_status = go_task.status.value
                        
                        if current_status != go_status or download.get("progress", 0) != go_task.progress:
                            # 更新任务状态
                            downloads[i].update({
                                "status": go_status,
                                "progress": go_task.progress,
                                "speed": _fmt_speed(go_task.speed),
                                "downloaded": _fmt_bytes(go_task.downloaded_size),
                                "size": _fmt_bytes(go_task.total_size) if go_task.total_size > 0 else "未知",
                                "timeRemaining": f"{go_task.eta}s" if go_task.eta > 0 else "",
                                "fileName": go_task.filename,  # 更新真实文件名
                                "filename": go_task.filename,
                                "filepath": go_task.filepath if hasattr(go_task, 'filepath') else ""
                            })
                            updated = True
                            
                            logger.info(f"同步状态更新: {go_task.filename} - {go_status} - {go_task.progress:.1f}%")
                        break
            
            # 如果有更新，保存数据并触发UI刷新
            if updated:
                self._save_data()
                self._trigger_ui_refresh()
                
        except Exception as e:
            logger.error(f"状态同步失败: {e}")
    
    def _check_stuck_tasks(self):
        """检查卡住的任务"""
        downloads = self.get_downloads()
        current_time = time.time()
        
        for download in downloads:
            status = download.get('status')
            created_time = download.get('created_time', current_time)
            task_id = download.get('id')
            core_id = download.get('core_id')
            
            # 如果任务pending超过5分钟且没有core_id，标记为失败
            if (status == 'pending' and 
                not core_id and 
                current_time - created_time > 300):  # 5分钟
                
                logger.warning(f"检测到长时间pending任务，标记为失败: {task_id}")
                self.update_download(task_id, {
                    'status': 'failed',
                    'speed': '启动超时',
                    'error_message': '任务启动超时，可能是网络问题或引擎异常'
                })
    
    def _load_data(self) -> Dict:
        """加载数据文件"""
        if self.data_file.exists():
            try:
                with open(self.data_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except (json.JSONDecodeError, FileNotFoundError):
                pass
        
        # 返回默认数据结构
        return {
            "downloads": [],
            "settings": {
                "max_concurrent_downloads": 3,
                "download_path": getDefaultDownloadPath(),
                "auto_start": True,
                "notifications": True
            }
        }
    

    
    def _save_data(self):
        """保存数据到文件"""
        try:
            with open(self.data_file, 'w', encoding='utf-8') as f:
                json.dump(self._data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            logger.error(f"保存数据失败: {e}")
    
    def get_downloads(self) -> List[Dict]:
        """获取所有下载项"""
        return self._data.get("downloads", [])
    
    def get_download(self, download_id: str) -> Optional[Dict]:
        """根据ID获取下载项"""
        downloads = self.get_downloads()
        for download in downloads:
            if download.get("id") == download_id:
                return download
        return None

    def get_download_by_core_id(self, core_id: str) -> Optional[Dict]:
        """根据核心任务ID获取下载项，兼容 core_id/ui_id/id 匹配"""
        try:
            downloads = self._data.get("downloads", [])
            for d in downloads:
                if (d.get("core_id") == core_id or
                    d.get("ui_id") == core_id or
                    d.get("id") == core_id):
                    return d
            return None
        except Exception as e:
            logger.error(f"get_download_by_core_id 失败: {e}")
            return None
    
    def add_download(self, download_data: Dict) -> bool:
        """添加新的下载项"""
        try:
            if "downloads" not in self._data:
                self._data["downloads"] = []
            
            # 先添加到数据中
            self._data["downloads"].append(download_data)
            self._save_data()
            
            # 如果有URL，尝试启动真实下载
            url = download_data.get('url')
            filename = download_data.get('fileName', '')
            original_id = download_data.get('id')
            
            if url:
                try:
                    # 创建异步任务来启动下载
                    import asyncio
                    
                    async def start_download():
                        try:
                            # 先更新状态为准备中
                            downloads = self._data.get("downloads", [])
                            for i, d in enumerate(downloads):
                                if d.get('id') == original_id:
                                    downloads[i]['status'] = 'pending'
                                    downloads[i]['speed'] = '准备中...'
                                    break
                            self._save_data()
                            
                            # 等待下载核心初始化完成
                            max_wait = 30  # 最多等待30秒
                            wait_count = 0
                            while not self.download_core and wait_count < max_wait:
                                await asyncio.sleep(1)
                                wait_count += 1
                                
                                # 更新状态显示等待时间
                                downloads = self._data.get("downloads", [])
                                for i, d in enumerate(downloads):
                                    if d.get('id') == original_id:
                                        downloads[i]['speed'] = f'等待引擎启动... ({wait_count}s)'
                                        break
                                self._save_data()
                            
                            if not self.download_core:
                                raise Exception("下载核心初始化超时")
                            
                            # 启动下载核心任务
                            result = await self.download_core.add_download({
                                'url': url,
                                'filename': filename,
                                'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                                'referer': download_data.get('referer'),
                                'cookies': download_data.get('cookies', ''),
                                'headers': download_data.get('headers', {})
                            })
                            task_id = result['id'] if isinstance(result, dict) else result
                            
                            # 更新数据中的ID - 保持UI和核心同步
                            downloads = self._data.get("downloads", [])
                            for i, d in enumerate(downloads):
                                if d.get('id') == original_id:
                                    # 保持原始ID不变，添加核心ID映射
                                    downloads[i]['core_id'] = task_id  # 保存核心ID
                                    downloads[i]['ui_id'] = original_id  # 保存UI ID
                                    downloads[i]['status'] = 'downloading'
                                    downloads[i]['speed'] = '连接中...'
                                    break
                            
                            self._save_data()
                            logger.info(f"启动真实下载任务: {filename} (UI ID: {original_id} -> 核心ID: {task_id})")
                            
                        except Exception as e:
                            logger.error(f"启动下载任务失败: {e}")
                            # 更新状态为失败
                            downloads = self._data.get("downloads", [])
                            for i, d in enumerate(downloads):
                                if d.get('id') == original_id:
                                    downloads[i]['status'] = 'failed'
                                    downloads[i]['speed'] = '启动失败'
                                    downloads[i]['error_message'] = str(e)
                                    break
                            self._save_data()
                    
                    # 使用更稳定的异步任务启动方式
                    import threading
                    def run_async():
                        try:
                            # 创建新的事件循环来运行异步任务
                            loop = asyncio.new_event_loop()
                            asyncio.set_event_loop(loop)
                            loop.run_until_complete(start_download())
                            loop.close()
                        except Exception as e:
                            logger.error(f"异步任务执行失败: {e}")
                    
                    thread = threading.Thread(target=run_async, daemon=True)
                    thread.start()
                    logger.info(f"异步启动下载任务: {filename} (UI ID: {original_id})")
                        
                except Exception as e:
                    logger.error(f"启动下载任务失败: {e}")
                    download_data['status'] = 'failed'
                    self._save_data()
            
            return True
        except Exception as e:
            logger.error(f"添加下载项失败: {e}")
            return False
    
    def update_download(self, download_id: str, update_data: Dict) -> bool:
        """更新下载项"""
        try:
            downloads = self._data.get("downloads", [])
            for i, download in enumerate(downloads):
                # 支持通过UI ID或核心ID查找
                if (download.get("id") == download_id or 
                    download.get("ui_id") == download_id or 
                    download.get("core_id") == download_id):
                    downloads[i].update(update_data)
                    self._save_data()
                    return True
            return False
        except Exception as e:
            logger.error(f"更新下载项失败: {e}")
            return False
    
    def remove_download(self, download_id: str) -> bool:
        """删除下载项"""
        try:
            # 先从数据中移除
            downloads = self._data.get("downloads", [])
            original_length = len(downloads)
            
            # 找到要删除的项目并获取核心ID
            core_id = None
            for d in downloads:
                if (d.get("id") == download_id or 
                    d.get("ui_id") == download_id or 
                    d.get("core_id") == download_id):
                    core_id = d.get("core_id") or d.get("id")
                    break
            
            # 从列表中移除
            self._data["downloads"] = [d for d in downloads if not (
                d.get("id") == download_id or 
                d.get("ui_id") == download_id or 
                d.get("core_id") == download_id
            )]
            
            if len(self._data["downloads"]) < original_length:
                self._save_data()
                
                # 异步取消下载核心中的任务
                if core_id:
                    try:
                        import asyncio
                        
                        async def cancel_core_task():
                            try:
                                if self.download_core:
                                    await self.download_core.cancel_download(core_id)
                                    logger.info(f"下载核心任务已取消: {core_id}")
                                else:
                                    logger.warning("下载核心未设置，无法取消任务")
                            except Exception as e:
                                logger.warning(f"取消下载核心任务失败: {e}")
                        
                        # 尝试在当前事件循环中取消
                        try:
                            loop = asyncio.get_running_loop()
                            loop.create_task(cancel_core_task())
                        except RuntimeError:
                            # 没有运行的事件循环，忽略
                            pass
                            
                    except Exception as e:
                        logger.warning(f"异步取消任务失败: {e}")
                
                logger.info(f"删除成功: {download_id}")
                return True
            else:
                logger.warning(f"未找到要删除的下载项: {download_id}")
                return False
                
        except Exception as e:
            logger.error(f"删除下载项失败: {e}")
            return False
    
    async def pause_download(self, download_id: str) -> bool:
        """暂停下载"""
        try:
            logger.debug(f"开始暂停下载: {download_id}")
            
            # 检查任务是否存在于数据中
            download_data = self.get_download(download_id)
            if not download_data:
                logger.warning(f"未找到下载任务: {download_id}")
                return False
            
            current_status = download_data.get("status")
            if current_status != "downloading":
                logger.warning(f"任务状态不是下载中，无法暂停: {current_status}")
                return False
            
            # 获取核心ID
            core_id = download_data.get("core_id") or download_data.get("id")
            
            # 尝试暂停下载核心中的任务
            if self.download_core:
                success = await self.download_core.pause_download(core_id)
            else:
                logger.warning("下载核心未设置，无法暂停下载")
                success = False
            
            if success:
                logger.info(f"下载核心暂停成功: {core_id}")
            else:
                logger.warning(f"下载核心中未找到任务: {core_id}")
                # 即使下载核心中没有找到，也认为暂停成功（可能是UI状态管理）
                success = True
            
            # 更新数据状态
            if success:
                self.update_download(download_id, {
                    "status": "paused",
                    "speed": "已暂停"
                })
                logger.info(f"暂停下载成功: {download_id}")
            
            return success
            
        except Exception as e:
            logger.error(f"暂停下载失败: {e}")
            return False
    
    async def resume_download(self, download_id: str) -> bool:
        """恢复下载"""
        try:
            logger.debug(f"开始恢复下载: {download_id}")
            
            # 检查任务是否存在于数据中
            download_data = self.get_download(download_id)
            if not download_data:
                logger.warning(f"未找到下载任务: {download_id}")
                return False
            
            current_status = download_data.get("status")
            if current_status != "paused":
                logger.warning(f"任务状态不是暂停中，无法恢复: {current_status}")
                return False
            
            # 获取核心ID
            core_id = download_data.get("core_id") or download_data.get("id")
            
            # 尝试恢复下载核心中的任务
            if self.download_core:
                success = await self.download_core.resume_download(core_id)
            else:
                logger.warning("下载核心未设置，无法恢复下载")
                success = False
            
            # 如果下载核心中没有任务，尝试重新创建下载任务
            if not success:
                logger.info(f"下载核心中未找到任务，尝试重新创建: {core_id}")
                
                url = download_data.get("url")
                filename = download_data.get("fileName")
                if url and filename:
                    try:
                        if self.download_core:
                            result = await self.download_core.add_download({
                                'url': url,
                                'filename': filename,
                                'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                                'referer': download_data.get('referer'),
                                'cookies': download_data.get('cookies', ''),
                                'headers': download_data.get('headers', {})
                            })
                            new_task_id = result['id'] if isinstance(result, dict) else result
                        else:
                            raise Exception("下载核心未初始化")
                        
                        # 更新数据中的核心ID
                        self.update_download(download_id, {
                            "core_id": new_task_id,
                            "status": "downloading",
                            "speed": "恢复中..."
                        })
                        
                        logger.info(f"重新创建下载任务成功: {filename} (新核心ID: {new_task_id})")
                        success = True
                        
                    except Exception as e:
                        logger.error(f"重新创建下载任务失败: {e}")
                        success = False
            
            # 更新数据状态
            if success:
                self.update_download(download_id, {
                    "status": "downloading",
                    "speed": "恢复中..."
                })
                logger.info(f"恢复下载成功: {download_id}")
            else:
                logger.error(f"恢复下载失败: {download_id}")
            
            return success
             
        except Exception as e:
            logger.error(f"恢复下载失败: {e}")
            return False

    async def restart_download(self, download_id: str) -> bool:
        """重启下载任务（适用于失败/取消等状态）"""
        try:
            download_data = self.get_download(download_id)
            if not download_data:
                logger.warning(f"未找到下载任务: {download_id}")
                return False

            core_id = download_data.get("core_id") or download_data.get("id")

            if self.download_core and core_id:
                try:
                    await self.download_core.cancel_download(core_id)
                except Exception as e:
                    logger.warning(f"取消旧任务失败: {e}")

            url = download_data.get("url")
            filename = download_data.get("fileName")
            referer = download_data.get("referer")
            user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

            if not url:
                logger.error("重启下载失败: 缺少URL")
                return False

            if not self.download_core:
                logger.error("重启下载失败: 下载核心不可用")
                return False

            result = await self.download_core.add_download({
                'url': url,
                'filename': filename,
                'user_agent': user_agent,
                'referer': referer or ''
            })
            new_task_id = result['id'] if isinstance(result, dict) else result

            self.update_download(download_id, {
                "core_id": new_task_id,
                "status": "downloading",
                "progress": 0.0,
                "downloaded": "0 B",
                "speed": "重新开始..."
            })

            logger.info(f"重启下载成功: {download_id} -> 新核心ID: {new_task_id}")
            return True

        except Exception as e:
            logger.error(f"重启下载失败: {e}")
            return False
    
    async def cancel_download(self, download_id: str) -> bool:
        """取消下载"""
        try:
            # 检查任务是否存在于数据中
            download_data = self.get_download(download_id)
            if not download_data:
                logger.warning(f"未找到下载任务: {download_id}")
                return False
            
            # 获取核心ID
            core_id = download_data.get("core_id") or download_data.get("id")
            
            # 取消下载核心中的任务
            if self.download_core:
                success = await self.download_core.cancel_download(core_id)
            else:
                logger.warning("下载核心未设置，无法取消下载")
                success = False
            
            if success:
                logger.info(f"下载核心取消成功: {core_id}")
            else:
                logger.warning(f"下载核心中未找到任务: {core_id}")
                # 即使下载核心中没有找到，也认为取消成功
                success = True
            
            # 更新数据状态
            if success:
                self.update_download(download_id, {
                    "status": "cancelled",
                    "speed": "已取消"
                })
                logger.info(f"取消下载成功: {download_id}")
            
            return success
            
        except Exception as e:
            logger.error(f"取消下载失败: {e}")
            return False
    
    async def restart_download(self, download_id: str) -> bool:
        try:
            download_data = self.get_download(download_id)
            if not download_data:
                logger.warning(f"未找到下载任务: {download_id}")
                return False
            
            url = download_data.get("url")
            filename = download_data.get("fileName") or ""
            if not url:
                logger.warning("任务缺少URL，无法重启")
                return False
            
            ok = await self.cancel_download(download_id)
            if not ok:
                logger.warning(f"取消旧任务失败或未找到: {download_id}，继续尝试重启")
            
            try:
                new_core_id = await self.start_download(url, filename)
            except Exception as e:
                logger.error(f"重启下载失败: {e}")
                return False
            
            if new_core_id:
                self.update_download(download_id, {
                    "core_id": new_core_id,
                    "status": "downloading",
                    "speed": "重新开始..."
                })
                return True
            return False
        except Exception as e:
            logger.error(f"重启下载异常: {e}")
            return False

    def get_settings(self) -> Dict:
        """获取设置"""
        return self._data.get("settings", {})
    
    def update_settings(self, settings: Dict) -> bool:
        """更新设置"""
        try:
            if "settings" not in self._data:
                self._data["settings"] = {}
            
            self._data["settings"].update(settings)
            self._save_data()
            return True
        except Exception as e:
            logger.error(f"更新设置失败: {e}")
            return False
    
    def get_downloads_by_category(self, category: str) -> List[Dict]:
        """根据分类获取下载项"""
        downloads = self.get_downloads()
        
        if category == "all":
            return downloads
        elif category in ["downloading", "completed", "paused", "failed"]:
            return [d for d in downloads if d.get("status") == category]
        else:
            return [d for d in downloads if d.get("fileType") == category]
    
    def get_category_counts(self) -> Dict[str, int]:
        """获取各分类的数量统计"""
        downloads = self.get_downloads()
        counts = {
            "all": len(downloads),
            "downloading": 0,
            "completed": 0,
            "paused": 0,
            "failed": 0,
            "video": 0,
            "audio": 0,
            "image": 0,
            "document": 0,
            "archive": 0,
            "other": 0
        }
        
        for download in downloads:
            status = download.get("status", "")
            file_type = download.get("fileType", "other")
            
            if status in counts:
                counts[status] += 1
            
            if file_type in counts:
                counts[file_type] += 1
        
        return counts
    
    def setup_download_callbacks(self):
        """设置下载核心回调"""
        if not self.download_core:
            logger.warning("下载核心未设置，无法注册回调")
            return
        
        def on_progress(task):
            """下载进度回调"""
            try:
                logger.info(f"🔄 收到进度回调: {task.id[:8]} - {task.filename} - {task.status.value} - {task.progress:.1f}%")
                
                # 更新内存中的数据
                task_dict = task.to_dict()
                downloads = self._data.get("downloads", [])
                
                # 调试信息：显示当前所有任务的ID映射
                logger.debug(f"查找任务 {task.id} 在 {len(downloads)} 个下载项中")
                for i, download in enumerate(downloads):
                    logger.debug(f"  [{i}] id={download.get('id')}, core_id={download.get('core_id')}, ui_id={download.get('ui_id')}")
                
                # 通过核心ID查找对应的下载项
                found = False
                for i, download in enumerate(downloads):
                    # 优先通过core_id匹配，然后通过id匹配
                    if (download.get("core_id") == task.id or 
                        download.get("id") == task.id or
                        download.get("ui_id") == task.id):
                        
                        # 检查当前UI状态，如果用户手动暂停了，不要覆盖状态
                        current_ui_status = download.get("status")
                        core_status = task_dict.get("status")
                        
                        # 如果UI显示已暂停，但核心状态是下载中，保持UI状态
                        if current_ui_status == "paused" and core_status == "downloading":
                            # 只更新进度和速度，不更新状态
                            downloads[i].update({
                                "progress": task_dict.get("progress", 0),
                                "downloaded": task_dict.get("downloaded", "0 B"),
                                "size": task_dict.get("size", "未知"),
                                "timeRemaining": task_dict.get("timeRemaining", ""),
                                "speed": "已暂停"  # 保持暂停状态的速度显示
                            })
                            logger.debug(f"保持UI暂停状态: {task.id}")
                        else:
                            # 正常更新所有字段，但保持原始 UI ID
                            original_id = downloads[i].get('id')
                            downloads[i].update(task_dict)
                            downloads[i]['id'] = original_id  # 恢复原始 UI ID
                        
                        # 保持ID映射
                        downloads[i]["core_id"] = task.id
                        found = True
                        break
                
                if not found:
                    # 如果不存在，添加新任务
                    task_dict["core_id"] = task.id
                    downloads.append(task_dict)
                
                # 保存到文件
                self._save_data()
                self._trigger_ui_refresh()
                
            except Exception as e:
                logger.error(f"进度回调处理失败: {e}")
                import traceback
                traceback.print_exc()
        
        def on_completion(task):
            """下载完成回调"""
            try:
                # 更新最终状态
                on_progress(task)
                self._trigger_ui_refresh()
                logger.info(f"下载完成: {task.filename}")
            except Exception as e:
                logger.error(f"完成回调处理失败: {e}")
        
        # 添加回调到下载核心
        try:
            self.download_core.add_progress_callback(on_progress)
            self.download_core.add_completion_callback(on_completion)
            logger.info("下载核心回调设置成功")
        except Exception as e:
            logger.error(f"设置下载核心回调失败: {e}")
    
    def sync_from_core_progress(self, task_id: str, info: dict):
        try:
            def _size_to_str(v):
                try:
                    n = int(v or 0)
                except Exception:
                    n = 0
                units = ["B", "KB", "MB", "GB", "TB"]
                size = float(n)
                idx = 0
                while size >= 1024 and idx < len(units) - 1:
                    size /= 1024.0
                    idx += 1
                if idx == 0:
                    return f"{int(size)} B"
                return f"{size:.1f} {units[idx]}"
            def _speed_to_str(v):
                try:
                    n = float(v or 0.0)
                except Exception:
                    n = 0.0
                units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
                spd = float(n)
                idx = 0
                while spd >= 1024 and idx < len(units) - 1:
                    spd /= 1024.0
                    idx += 1
                if idx == 0:
                    return f"{int(spd)} B/s"
                return f"{spd:.1f} {units[idx]}"
            downloads = self._data.get("downloads", [])
            idx = -1
            for i, d in enumerate(downloads):
                if d.get("core_id") == task_id or d.get("id") == task_id or d.get("ui_id") == task_id:
                    idx = i
                    break
            status_val = info.get("status", "downloading")
            try:
                if hasattr(status_val, "value"):
                    status_val = status_val.value
            except Exception:
                pass
            prog = info.get("progress", 0.0)
            try:
                prog = float(prog)
            except Exception:
                prog = 0.0
            spd_str = _speed_to_str(info.get("speed", 0.0))
            dl_str = _size_to_str(info.get("downloaded_size", 0))
            total_sz = int(info.get("total_size", 0) or 0)
            size_str = _size_to_str(total_sz) if total_sz > 0 else "未知"
            eta_v = int(info.get("eta", 0) or 0)
            eta_str = f"{eta_v}s" if eta_v > 0 else ""
            filename = info.get("filename", "")
            filepath = info.get("filepath", "")
            if idx == -1:
                rec = {
                    "id": task_id,
                    "core_id": task_id,
                    "url": info.get("url", ""),
                    "fileName": filename,
                    "filename": filename,
                    "filepath": filepath,
                    "status": status_val,
                    "progress": prog,
                    "speed": spd_str,
                    "downloaded": dl_str,
                    "size": size_str,
                    "timeRemaining": eta_str
                }
                downloads.append(rec)
            else:
                rec = downloads[idx]
                rec.update({
                    "status": status_val,
                    "progress": prog,
                    "speed": spd_str,
                    "downloaded": dl_str,
                    "size": size_str,
                    "timeRemaining": eta_str,
                    "fileName": filename or rec.get("fileName", ""),
                    "filename": filename or rec.get("filename", ""),
                    "filepath": filepath or rec.get("filepath", "")
                })
            self._data["downloads"] = downloads
            self._save_data()
            self._trigger_ui_refresh()
        except Exception as e:
            logger.error(f"sync_from_core_progress error: {e}")

    async def start_download(self, url: str, filename: str = "", **kwargs) -> str:
        """启动新的下载任务"""
        try:
            if self.download_core:
                result = await self.download_core.add_download({
                    'url': url,
                    'filename': filename,
                    'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                    **kwargs
                })
                return result['id'] if isinstance(result, dict) else result
            else:
                logger.error("下载核心未设置")
                return ""
        except Exception as e:
            logger.error(f"启动下载失败: {e}")
            return ""
    
    async def pause_download_task(self, task_id: str) -> bool:
        """暂停下载任务"""
        if self.download_core:
            return await self.download_core.pause_download(task_id)
        return False
    
    async def resume_download_task(self, task_id: str) -> bool:
        """恢复下载任务"""
        if self.download_core:
            return await self.download_core.resume_download(task_id)
        return False
    
    async def cancel_download_task(self, task_id: str) -> bool:
        """取消下载任务"""
        if self.download_core:
            return await self.download_core.cancel_download(task_id)
        return False
    
    async def get_download_statistics(self) -> Dict:
        """获取下载统计信息"""
        if self.download_core:
            return await self.download_core.get_statistics()
        return {}
    
    async def cleanup_download_core(self):
        """清理下载核心资源"""
        if self.download_core:
            await self.download_core.cleanup()