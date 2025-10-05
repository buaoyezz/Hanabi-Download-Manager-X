"""
WebSocket Server
"""

import asyncio
import websockets
import json
import logging
from typing import Dict, Any, Callable
from pathlib import Path
from ...utils.logger import logger


class WebSocketServer:
    
    def __init__(self, host="127.0.0.1", port=8080):
        self.host = host
        self.port = port
        self.server = None
        self.is_running = False
        self.download_callback = None
        self.batch_download_callback = None
        self.clients = set()  # 存储连接的客户端
        
        # 设置日志
        log_dir = Path.home() / '.hdm_x' / 'logs'
        log_dir.mkdir(parents=True, exist_ok=True)
        logging.basicConfig(
            filename=log_dir / 'websocket.log',
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
    
    def set_download_callback(self, callback: Callable):
        """设置下载回调"""
        self.download_callback = callback
    
    def set_batch_download_callback(self, callback: Callable):
        """设置批量下载回调"""
        self.batch_download_callback = callback
    
    async def handle_client(self, websocket, path):
        """处理客户端连接"""
        self.clients.add(websocket)
        self.logger.info(f"Client connected from {websocket.remote_address}")
        logger.info(f"HDM-X: 浏览器扩展已连接 {websocket.remote_address}")
        
        # 发送版本信息
        try:
            version_info = {
                "type": "version",
                "clientVersion": "2.0.0",
                "timestamp": asyncio.get_event_loop().time()
            }
            await websocket.send(json.dumps(version_info))
        except Exception as e:
            self.logger.error(f"Failed to send version info: {e}")
        
        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    response = await self.process_message(data, websocket)
                    if response:  # 只有需要响应的消息才发送响应
                        await websocket.send(json.dumps(response))
                    
                except json.JSONDecodeError:
                    error_response = {'success': False, 'error': 'Invalid JSON format'}
                    await websocket.send(json.dumps(error_response))
                    
                except Exception as e:
                    self.logger.error(f"Error processing message: {e}")
                    error_response = {'success': False, 'error': str(e)}
                    await websocket.send(json.dumps(error_response))
                    
        except websockets.exceptions.ConnectionClosed:
            self.logger.info("Client disconnected")
            logger.info("HDM-X: 浏览器扩展已断开连接")
        except Exception as e:
            self.logger.error(f"Client handler error: {e}")
        finally:
            self.clients.discard(websocket)
    
    async def process_message(self, data: Dict[str, Any], websocket) -> Dict[str, Any]:
        """处理消息"""
        message_type = data.get('type')
        action = data.get('action')
        message_id = data.get('messageId')
        
        # 处理浏览器扩展的消息格式
        if message_type == 'ping':
            # 心跳响应
            return {
                "type": "pong",
                "timestamp": asyncio.get_event_loop().time()
            }
        
        elif message_type == 'download':
            # 浏览器扩展的代理下载请求
            if self.download_callback:
                try:
                    # 转换浏览器扩展的数据格式到HDM-X格式
                    download_data = {
                        'url': data.get('url'),
                        'fileName': data.get('filename'),
                        'referer': data.get('referer', ''),
                        'headers': data.get('headers', {}),
                        'fileSize': data.get('fileSize', 0),
                        'source': 'browser_extension'
                    }
                    
                    result = await self.download_callback(download_data)
                    logger.info(f"HDM-X: 代理下载已添加 - {download_data['fileName']}")
                    
                    return {
                        "type": "download_response",
                        "success": True,
                        "download_id": result.get('id'),
                        "message": "下载任务已添加到HDM-X"
                    }
                except Exception as e:
                    self.logger.error(f"Failed to add proxy download: {e}")
                    return {
                        "type": "download_response",
                        "success": False,
                        "error": str(e)
                    }
            else:
                return {
                    "type": "download_response",
                    "success": False,
                    "error": "Download callback not set"
                }
        
        # 处理原有的action格式（向后兼容）
        elif action:
            # 基础响应结构
            response = {'messageId': message_id} if message_id else {}
            
            if action == 'ping':
                response.update({'success': True, 'message': 'HDM X WebSocket server is running'})
                return response
            
            elif action == 'add_download':
                if self.download_callback:
                    try:
                        download_data = data.get('data', {})
                        result = await self.download_callback(download_data)
                        response.update({
                            'success': True, 
                            'download_id': result.get('id'), 
                            'message': 'Download added successfully'
                        })
                        return response
                    except Exception as e:
                        response.update({'success': False, 'error': f'Failed to add download: {str(e)}'})
                        return response
                else:
                    response.update({'success': False, 'error': 'Download callback not set'})
                    return response
            
            elif action == 'batch_download':
                if self.batch_download_callback:
                    try:
                        urls = data.get('urls', [])
                        referer = data.get('referer', '')
                        results = await self.batch_download_callback(urls, referer)
                        response.update({
                            'success': True, 
                            'results': results, 
                            'message': f'Added {len(results)} downloads'
                        })
                        return response
                    except Exception as e:
                        response.update({'success': False, 'error': f'Failed to add batch downloads: {str(e)}'})
                        return response
                else:
                    response.update({'success': False, 'error': 'Batch download callback not set'})
                    return response
            
            else:
                response.update({'success': False, 'error': f'Unknown action: {action}'})
                return response
        
        else:
            # 未知消息类型
            self.logger.warning(f"Unknown message type: {message_type or 'none'}")
            return None  # 不响应未知消息
    
    async def start(self):
        """启动服务器"""
        if self.is_running:
            return
        
        try:
            logger.info(f"正在启动HDM-X WebSocket服务器 {self.host}:{self.port}...")
            logger.info("支持浏览器扩展代理下载功能")
            
            self.server = await websockets.serve(
                self.handle_client,
                self.host,
                self.port,
                ping_interval=30,
                ping_timeout=10
            )
            self.is_running = True
            logger.info(f"✅ HDM-X WebSocket服务器已启动: ws://{self.host}:{self.port}/ws")
            logger.info("浏览器扩展现在可以连接并转发下载任务")
            
            # 等待服务器关闭
            await self.server.wait_closed()
            
        except Exception as e:
            self.logger.error(f"Failed to start WebSocket server: {e}")
            logger.error(f"❌ WebSocket服务器启动失败: {e}")
            raise
    
    def stop(self):
        """停止服务器"""
        if self.server:
            self.server.close()
            self.is_running = False
            self.logger.info("WebSocket server stopped")
            print("WebSocket server stopped")