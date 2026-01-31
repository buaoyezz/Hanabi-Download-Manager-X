"""
WebSocket 服务器 - 用于实时推送下载进度到小窗口
"""
import asyncio
import json
from aiohttp import web
import aiohttp
from typing import Dict, Set

class WebSocketServer:
    def __init__(self, bridge):
        self.bridge = bridge
        self.connections: Dict[str, Set[web.WebSocketResponse]] = {}  # task_id -> set of websockets
        self.progress_task = None
        
    async def websocket_handler(self, request):
        """WebSocket 连接处理器"""
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        
        # 从路径获取 task_id
        task_id = request.match_info.get('task_id')
        
        if not task_id:
            await ws.send_json({
                'type': 'error',
                'message': 'task_id is required'
            })
            await ws.close()
            return ws
        
        # 注册连接
        if task_id not in self.connections:
            self.connections[task_id] = set()
        self.connections[task_id].add(ws)
        
        print(f"[WebSocket] Client connected for task: {task_id}")
        
        # 发送初始状态
        await self._send_task_status(task_id, ws)
        
        try:
            async for msg in ws:
                if msg.type == aiohttp.WSMsgType.TEXT:
                    try:
                        data = json.loads(msg.data)
                        await self._handle_command(task_id, data, ws)
                    except json.JSONDecodeError:
                        await ws.send_json({
                            'type': 'error',
                            'message': 'Invalid JSON'
                        })
                elif msg.type == aiohttp.WSMsgType.ERROR:
                    print(f'[WebSocket] Connection closed with exception {ws.exception()}')
        finally:
            # 清理连接
            if task_id in self.connections:
                self.connections[task_id].discard(ws)
                if not self.connections[task_id]:
                    del self.connections[task_id]
            print(f"[WebSocket] Client disconnected for task: {task_id}")
        
        return ws
    
    async def _handle_command(self, task_id: str, data: dict, ws: web.WebSocketResponse):
        """处理客户端命令"""
        action = data.get('action')
        
        if action == 'pause':
            result = await self.bridge.pause_download(task_id)
            await ws.send_json({
                'type': 'command_result',
                'action': 'pause',
                'success': result
            })
        elif action == 'resume':
            result = await self.bridge.resume_download(task_id)
            await ws.send_json({
                'type': 'command_result',
                'action': 'resume',
                'success': result
            })
        elif action == 'cancel':
            result = await self.bridge.cancel_download(task_id)
            await ws.send_json({
                'type': 'command_result',
                'action': 'cancel',
                'success': result
            })
        else:
            await ws.send_json({
                'type': 'error',
                'message': f'Unknown action: {action}'
            })
    
    async def _send_task_status(self, task_id: str, ws: web.WebSocketResponse):
        """发送任务状态"""
        try:
            tasks = self.bridge.get_all_tasks()
            task = next((t for t in tasks if t.id == task_id), None)
            
            if task:
                task_dict = task.to_dict()
                await ws.send_json({
                    'type': 'status',
                    'data': task_dict
                })
            else:
                await ws.send_json({
                    'type': 'error',
                    'message': f'Task not found: {task_id}'
                })
        except Exception as e:
            print(f"[WebSocket] Error sending task status: {e}")
            await ws.send_json({
                'type': 'error',
                'message': str(e)
            })
    
    async def broadcast_progress(self):
        """定期广播进度更新"""
        while True:
            try:
                await asyncio.sleep(0.5)  # 每 500ms 更新一次
                
                if not self.connections:
                    continue
                
                # 获取所有任务
                tasks = self.bridge.get_all_tasks()
                
                # 为每个有连接的任务发送更新
                for task_id, ws_set in list(self.connections.items()):
                    task = next((t for t in tasks if t.id == task_id), None)
                    
                    if not task:
                        continue
                    
                    task_dict = task.to_dict()
                    
                    # 构建进度消息
                    message = {
                        'type': 'progress',
                        'task_id': task_id,
                        'status': task_dict['status'],
                        'progress': task_dict['progress'],
                        'speed': task_dict.get('speed', 0),
                        'downloaded': task_dict.get('downloaded', 0),
                        'file_size': task_dict.get('file_size', 0),
                        'time_left': task_dict.get('time_left', 0),
                        'filename': task_dict.get('filename', ''),
                        'url': task_dict.get('url', ''),
                        'segments': task_dict.get('segments', [])
                    }
                    
                    # 发送给所有连接的客户端
                    dead_ws = set()
                    for ws in ws_set:
                        try:
                            if ws.closed:
                                dead_ws.add(ws)
                            else:
                                await ws.send_json(message)
                        except Exception as e:
                            print(f"[WebSocket] Error sending to client: {e}")
                            dead_ws.add(ws)
                    
                    # 清理死连接
                    for ws in dead_ws:
                        ws_set.discard(ws)
                    
                    if not ws_set:
                        del self.connections[task_id]
                        
            except Exception as e:
                print(f"[WebSocket] Error in broadcast_progress: {e}")
                import traceback
                traceback.print_exc()
    
    async def start_broadcasting(self, app):
        """启动广播任务"""
        self.progress_task = asyncio.create_task(self.broadcast_progress())
        print("[WebSocket] Progress broadcasting started")
    
    async def stop_broadcasting(self, app):
        """停止广播任务"""
        if self.progress_task:
            self.progress_task.cancel()
            try:
                await self.progress_task
            except asyncio.CancelledError:
                pass
        
        # 关闭所有连接
        for ws_set in self.connections.values():
            for ws in ws_set:
                await ws.close()
        
        self.connections.clear()
        print("[WebSocket] Progress broadcasting stopped")
