import asyncio
import sys
import os
from aiohttp import web

sys.path.insert(0, os.path.dirname(__file__))

from soda_speed_force_kernel import NsfXCoreBridge
from websocket_server import WebSocketServer

bridge = None
ws_server = None

async def init_bridge(app):
    global bridge, ws_server
    download_dir = os.path.join(os.path.expanduser("~"), "Downloads")
    bridge = NsfXCoreBridge(downloadDir=download_dir, threads=8)
    
    # 初始化 WebSocket 服务器
    ws_server = WebSocketServer(bridge)
    await ws_server.start_broadcasting(app)
    
    print(f"Soda Speed Force Kernel started")
    print(f"Download directory: {download_dir}")
    print(f"Multi-thread download: 8 threads")
    print(f"WebSocket server initialized")

async def cleanup_bridge(app):
    global bridge, ws_server
    if ws_server:
        await ws_server.stop_broadcasting(app)
    if bridge:
        bridge.cleanup()
        print("Soda Speed Force Kernel stopped")

pending_popup_downloads = []

async def add_download(request):
    try:
        data = await request.json()
        print(f"[bridge] add_download received: url={data.get('url')} filename={data.get('filename')} from_browser={data.get('from_browser', False)} use_mini_window={data.get('use_mini_window', False)}")
        
        # 检查是否来自浏览器插件（需要弹窗确认）
        from_browser = data.get('from_browser', False)
        
        if from_browser:
            # 添加到待弹窗队列，不立即下载
            pending_popup_downloads.append({
                'url': data.get('url'),
                'filename': data.get('filename'),
                'referer': data.get('referer', ''),
                'user_agent': data.get('user_agent', ''),
                'headers': data.get('headers', {}),
            })
            print(f"[bridge] queued for popup. queue_len={len(pending_popup_downloads)}")
            return web.json_response({
                "success": True, 
                "data": {"message": "Added to popup queue"}
            })
        else:
            # 直接添加下载任务
            result = await bridge.add_download(data)
            task_id = result.get('id')
            print(f"[bridge] direct add_download succeeded: id={task_id}")
            
            # 如果启用小窗口，返回 WebSocket URL
            use_mini_window = data.get('use_mini_window', False)
            if use_mini_window:
                result['websocket_url'] = f"ws://127.0.0.1:9710/ws/progress/{task_id}"
            
            return web.json_response({"success": True, "data": result})
    except Exception as e:
        print(f"[bridge] add_download error: {e}")
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def get_pending_popup(request):
    # 获取待弹窗的下载任务
    try:
        print(f"[bridge] pending_popup requested. queue_len={len(pending_popup_downloads)}")
        if pending_popup_downloads:
            download = pending_popup_downloads.pop(0)
            print(f"[bridge] pending_popup served: url={download.get('url')} filename={download.get('filename')} queue_len={len(pending_popup_downloads)}")
            return web.json_response({"success": True, "data": download})
        else:
            return web.json_response({"success": True, "data": None})
    except Exception as e:
        print(f"[bridge] pending_popup error: {e}")
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def pause_download(request):
    try:
        data = await request.json()
        task_id = data.get("id")
        print(f"[bridge_server] pause_download called: task_id={task_id}")
        result = await bridge.pause_download(task_id)
        print(f"[bridge_server] pause_download result: {result}")
        return web.json_response({"success": result})
    except Exception as e:
        print(f"[bridge_server] pause_download error: {e}")
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def resume_download(request):
    try:
        data = await request.json()
        task_id = data.get("id")
        print(f"[bridge_server] resume_download called: task_id={task_id}")
        result = await bridge.resume_download(task_id)
        print(f"[bridge_server] resume_download result: {result}")
        return web.json_response({"success": result})
    except Exception as e:
        print(f"[bridge_server] resume_download error: {e}")
        import traceback
        traceback.print_exc()
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def cancel_download(request):
    try:
        data = await request.json()
        task_id = data.get("id")
        result = await bridge.cancel_download(task_id)
        return web.json_response({"success": result})
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def get_statistics(request):
    try:
        stats = bridge.get_statistics()
        return web.json_response({"success": True, "data": stats})
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def get_all_tasks(request):
    try:
        tasks = bridge.get_all_tasks()
        tasks_data = [task.to_dict() for task in tasks]
        
        # 调试：打印任务状态和segments信息
        for task_dict in tasks_data:
            print(f"[bridge] Task {task_dict['id']}: status={task_dict['status']}, progress={task_dict['progress']:.1f}%")
            if 'segments' in task_dict and task_dict['segments']:
                print(f"[bridge]   └─ {len(task_dict['segments'])} segments")
        
        return web.json_response({"success": True, "data": tasks_data})
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def set_download_dir(request):
    try:
        data = await request.json()
        download_dir = data.get("path")
        if not download_dir:
            return web.json_response({"success": False, "error": "path required"}, status=400)
        
        result = bridge.set_download_dir(download_dir)
        return web.json_response({"success": result})
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def get_download_dir(request):
    try:
        download_dir = bridge.get_download_dir()
        return web.json_response({"success": True, "data": {"path": download_dir}})
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def set_download_config(request):
    try:
        data = await request.json()
        threads = data.get("threads")
        segments = data.get("segments")
        mode = data.get("mode")
        max_concurrent_tasks = data.get("max_concurrent_tasks")
        segment_speed_limit = data.get("segment_speed_limit")
        proxy_config = data.get("proxy")
        
        print(f"[bridge_server] set_download_config: limit={segment_speed_limit}, proxy={proxy_config is not None}")
        
        config = bridge.set_download_config(
            threads=threads, 
            segments=segments, 
            mode=mode,
            max_concurrent_tasks=max_concurrent_tasks,
            segment_speed_limit=segment_speed_limit,
            proxy_config=proxy_config
        )
        return web.json_response({"success": True, "data": config})
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def get_download_config(request):
    try:
        config = bridge.get_download_config()
        return web.json_response({"success": True, "data": config})
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def clear_all_data(request):
    """清除所有下载任务和历史记录"""
    try:
        print("[bridge_server] clear_all_data called")
        result = bridge.clear_all_data()
        print(f"[bridge_server] clear_all_data result: {result}")
        return web.json_response({"success": result})
    except Exception as e:
        print(f"[bridge_server] clear_all_data error: {e}")
        import traceback
        traceback.print_exc()
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def cleanup_temp_files(request):
    """清理所有临时文件"""
    try:
        print("[bridge_server] cleanup_temp_files called")
        result = bridge.cleanup_temp_files()
        print(f"[bridge_server] cleanup_temp_files result: {result}")
        return web.json_response({"success": result['success'], "data": result})
    except Exception as e:
        print(f"[bridge_server] cleanup_temp_files error: {e}")
        import traceback
        traceback.print_exc()
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def retry_failed_segments(request):
    """重试失败的分段"""
    try:
        data = await request.json()
        task_id = data.get("id")
        print(f"[bridge_server] retry_failed_segments called: task_id={task_id}")
        
        if not task_id:
            return web.json_response({"success": False, "error": "task_id required"}, status=400)
        
        # 调用bridge的重试方法
        result = await bridge.retry_failed_segments(task_id)
        print(f"[bridge_server] retry_failed_segments result: {result}")
        return web.json_response({"success": result})
    except Exception as e:
        print(f"[bridge_server] retry_failed_segments error: {e}")
        import traceback
        traceback.print_exc()
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def retry_segment(request):
    """重试特定分段"""
    try:
        data = await request.json()
        task_id = data.get("id")
        segment_index = data.get("segment_index")
        print(f"[bridge_server] retry_segment called: task_id={task_id}, segment_index={segment_index}")
        
        if not task_id or segment_index is None:
            return web.json_response({"success": False, "error": "task_id and segment_index required"}, status=400)
        
        # 调用bridge的重试方法
        result = await bridge.retry_segment(task_id, segment_index)
        print(f"[bridge_server] retry_segment result: {result}")
        return web.json_response({"success": result})
    except Exception as e:
        print(f"[bridge_server] retry_segment error: {e}")
        import traceback
        traceback.print_exc()
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def test_proxy_connection(request):
    """测试代理连接"""
    try:
        data = await request.json()
        proxy_type = data.get("type")
        host = data.get("host")
        port = data.get("port")
        username = data.get("username")
        password = data.get("password")
        
        print(f"[bridge_server] test_proxy_connection: {proxy_type}://{host}:{port}")
        
        # 对于系统代理，不需要检查host和port
        if proxy_type == 'system':
            if not proxy_type:
                return web.json_response({"success": False, "error": "proxy type required"}, status=400)
        else:
            # 对于手动代理，需要检查所有参数
            if not all([proxy_type, host, port]):
                return web.json_response({"success": False, "error": "type, host and port required"}, status=400)
        
        # 调用bridge的代理测试方法
        result = await bridge.test_proxy_connection(
            proxy_type=proxy_type,
            host=host,
            port=port,
            username=username,
            password=password
        )
        print(f"[bridge_server] test_proxy_connection result: {result}")
        return web.json_response({"success": result})
    except Exception as e:
        print(f"[bridge_server] test_proxy_connection error: {e}")
        import traceback
        traceback.print_exc()
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def check_url_status(request):
    """检查 URL 状态"""
    try:
        data = await request.json()
        url = data.get("url")
        
        if not url:
            return web.json_response({"success": False, "error": "URL is required"}, status=400)
        
        print(f"[bridge_server] check_url_status: {url}")
        
        import aiohttp
        import socket
        import time
        from datetime import datetime
        from urllib.parse import urlparse
        
        result = {
            "url": url,
            "timestamp": datetime.now().isoformat(),
            "redirects": [],
            "final_url": url,
            "status_code": None,
            "headers": {},
            "content_type": None,
            "content_length": None,
            "server": None,
            "response_time": None,
            "dns_time": None,
            "connect_time": None,
            "ip_address": None,
            "hostname": None,
            "port": None,
            "protocol": None,
            "ssl_info": None,
            "cookies": [],
            "error": None
        }
        
        try:
            # 解析 URL
            parsed = urlparse(url)
            
            # 验证 URL 格式
            if not parsed.scheme:
                result["error"] = "Invalid URL: missing protocol (http:// or https://)"
                return web.json_response({"success": True, "data": result})
            
            if not parsed.hostname:
                result["error"] = "Invalid URL: missing hostname"
                return web.json_response({"success": True, "data": result})
            
            result["hostname"] = parsed.hostname
            result["port"] = parsed.port or (443 if parsed.scheme == 'https' else 80)
            result["protocol"] = parsed.scheme
            
            # DNS 解析
            dns_start = time.time()
            try:
                ip_address = socket.gethostbyname(parsed.hostname)
                result["ip_address"] = ip_address
                result["dns_time"] = round((time.time() - dns_start) * 1000, 2)  # ms
            except socket.gaierror as e:
                result["error"] = f"DNS resolution failed: {str(e)}"
                return web.json_response({"success": True, "data": result})
            except Exception as e:
                result["error"] = f"DNS error: {str(e)}"
                return web.json_response({"success": True, "data": result})
            
            # HTTP 请求
            timeout = aiohttp.ClientTimeout(total=10, connect=5)
            connector = aiohttp.TCPConnector(use_dns_cache=False)
            
            request_start = time.time()
            async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
                async with session.get(url, allow_redirects=True) as response:
                    result["response_time"] = round((time.time() - request_start) * 1000, 2)  # ms
                    
                    # 记录最终状态
                    result["status_code"] = response.status
                    result["final_url"] = str(response.url)
                    
                    # 记录响应头
                    result["headers"] = dict(response.headers)
                    result["content_type"] = response.headers.get('Content-Type', '')
                    result["content_length"] = response.headers.get('Content-Length', '')
                    result["server"] = response.headers.get('Server', '')
                    
                    # 记录 Cookies
                    for cookie in response.cookies.values():
                        result["cookies"].append({
                            "name": cookie.key,
                            "value": cookie.value,
                            "domain": cookie.get('domain', ''),
                            "path": cookie.get('path', ''),
                        })
                    
                    # SSL 信息
                    if parsed.scheme == 'https':
                        try:
                            import ssl
                            import certifi
                            ssl_context = ssl.create_default_context(cafile=certifi.where())
                            with socket.create_connection((parsed.hostname, result["port"]), timeout=5) as sock:
                                with ssl_context.wrap_socket(sock, server_hostname=parsed.hostname) as ssock:
                                    cert = ssock.getpeercert()
                                    result["ssl_info"] = {
                                        "version": ssock.version(),
                                        "cipher": ssock.cipher()[0] if ssock.cipher() else None,
                                        "issuer": dict(x[0] for x in cert.get('issuer', [])),
                                        "subject": dict(x[0] for x in cert.get('subject', [])),
                                        "not_before": cert.get('notBefore', ''),
                                        "not_after": cert.get('notAfter', ''),
                                    }
                        except Exception as ssl_error:
                            result["ssl_info"] = {"error": str(ssl_error)}
                    
                    # 记录重定向历史
                    for hist in response.history:
                        redirect_info = {
                            "url": str(hist.url),
                            "status_code": hist.status,
                            "location": hist.headers.get('Location', '')
                        }
                        result["redirects"].append(redirect_info)
                    
                    print(f"[bridge_server] check_url_status result: status={response.status}, time={result['response_time']}ms")
                    
        except aiohttp.ClientError as e:
            result["error"] = f"Connection error: {str(e)}"
            print(f"[bridge_server] check_url_status error: {e}")
        except Exception as e:
            result["error"] = f"Unexpected error: {str(e)}"
            print(f"[bridge_server] check_url_status error: {e}")
        
        return web.json_response({"success": True, "data": result})
        
    except Exception as e:
        print(f"[bridge_server] check_url_status error: {e}")
        import traceback
        traceback.print_exc()
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def scan_lan(request):
    """扫描局域网设备"""
    try:
        print("[bridge_server] scan_lan: starting")
        
        import socket
        import asyncio
        from concurrent.futures import ThreadPoolExecutor
        
        def get_local_ip():
            """获取本机 IP"""
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect(("8.8.8.8", 80))
                local_ip = s.getsockname()[0]
                s.close()
                return local_ip
            except:
                return "127.0.0.1"
        
        def check_host(ip, port=80, timeout=0.5):
            """检查主机是否在线"""
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(timeout)
                result = sock.connect_ex((ip, port))
                sock.close()
                return result == 0
            except:
                return False
        
        def get_hostname(ip):
            """获取主机名"""
            try:
                return socket.gethostbyaddr(ip)[0]
            except:
                return None
        
        # 获取本机 IP 和网段
        local_ip = get_local_ip()
        ip_parts = local_ip.split('.')
        network = f"{ip_parts[0]}.{ip_parts[1]}.{ip_parts[2]}"
        
        print(f"[bridge_server] scan_lan: network={network}.0/24")
        
        # 扫描网段
        devices = []
        
        # 使用线程池并发扫描
        with ThreadPoolExecutor(max_workers=50) as executor:
            futures = []
            for i in range(1, 255):
                ip = f"{network}.{i}"
                future = executor.submit(check_host, ip)
                futures.append((ip, future))
            
            for ip, future in futures:
                try:
                    if future.result(timeout=2):
                        hostname = get_hostname(ip)
                        devices.append({
                            "ip": ip,
                            "hostname": hostname,
                            "is_local": ip == local_ip
                        })
                        print(f"[bridge_server] scan_lan: found {ip} ({hostname})")
                except:
                    pass
        
        result = {
            "local_ip": local_ip,
            "network": f"{network}.0/24",
            "devices": devices,
            "total": len(devices)
        }
        
        print(f"[bridge_server] scan_lan: found {len(devices)} devices")
        return web.json_response({"success": True, "data": result})
        
    except Exception as e:
        print(f"[bridge_server] scan_lan error: {e}")
        import traceback
        traceback.print_exc()
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def health_check(request):
    return web.json_response({
        "status": "ok",
        "service": "Soda Speed Force Kernel",
        "version": "1.6.5"
    })

async def empty_normal(request):
    return web.json_response({
        "desc" : "Soda Kernel",
        "htu" : "Look Docs",
        "For U" : "Server is running"
    })

async def cors_middleware(app, handler):
    async def middleware_handler(request):
        # 处理 OPTIONS 预检请求
        if request.method == 'OPTIONS':
            response = web.Response()
        else:
            response = await handler(request)
        
        # 添加 CORS 头
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
        return response
    return middleware_handler

def create_app():
    app = web.Application(middlewares=[cors_middleware])
    
    app.router.add_get('', empty_normal)
    app.router.add_get('/health', health_check)
    app.router.add_post('/download/add', add_download)
    app.router.add_post('/download/pause', pause_download)
    app.router.add_post('/download/resume', resume_download)
    app.router.add_post('/download/cancel', cancel_download)
    app.router.add_post('/download/retry-segments', retry_failed_segments)
    app.router.add_post('/download/retry-segment', retry_segment)
    app.router.add_get('/download/statistics', get_statistics)
    app.router.add_post('/proxy/test', test_proxy_connection)
    app.router.add_get('/download/tasks', get_all_tasks)
    app.router.add_get('/download/pending-popup', get_pending_popup)
    app.router.add_post('/settings/download-dir', set_download_dir)
    app.router.add_get('/settings/download-dir', get_download_dir)
    app.router.add_post('/settings/download-config', set_download_config)
    app.router.add_get('/settings/download-config', get_download_config)
    app.router.add_post('/settings/clear-all-data', clear_all_data)
    app.router.add_post('/settings/cleanup-temp-files', cleanup_temp_files)
    app.router.add_post('/debug/check-url', check_url_status)
    app.router.add_post('/debug/scan-lan', scan_lan)
    
    # WebSocket 路由
    app.router.add_get('/ws/progress/{task_id}', lambda req: ws_server.websocket_handler(req))
    
    app.on_startup.append(init_bridge)
    app.on_cleanup.append(cleanup_bridge)
    
    return app

def check_port_usage(port):
    try:
        import subprocess
        if sys.platform == "win32":
            # Windows
            result = subprocess.run(['netstat', '-ano'], capture_output=True, text=True, timeout=10)
            lines = result.stdout.split('\n')
            for line in lines:
                if f':{port}' in line and 'LISTENING' in line:
                    parts = line.split()
                    if len(parts) >= 5:
                        pid = parts[-1]
                        try:
                            proc_result = subprocess.run(['tasklist', '/FI', f'PID eq {pid}'], capture_output=True, text=True, timeout=5)
                            proc_lines = proc_result.stdout.split('\n')
                            for proc_line in proc_lines:
                                if pid in proc_line:
                                    proc_name = proc_line.split()[0]
                                    print(f"Port {port} is being used by: {proc_name} (PID: {pid})")
                                    return True
                        except subprocess.TimeoutExpired:
                            print(f"Port {port} is being used by PID: {pid} (timeout getting process name)")
                            return True
                        except Exception:
                            print(f"Port {port} is being used by PID: {pid}")
                            return True
                    break
        else:
            # macOS/Linux
            result = subprocess.run(['lsof', '-i', f':{port}'], capture_output=True, text=True, timeout=10)
            if result.stdout:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    # 跳过标题行
                    for line in lines[1:]:
                        parts = line.split()
                        if len(parts) >= 2:
                            proc_name = parts[0]
                            pid = parts[1]
                            print(f"Port {port} is being used by: {proc_name} (PID: {pid})")
                            return True
                else:
                    print(f"Port {port} is in use, but couldn't identify the process")
                    return True
    except subprocess.TimeoutExpired:
        print(f"Timeout while checking port {port} usage")
        return True
    except Exception as ex:
        print(f"Error checking port {port} usage: {ex}")
        return True
    return False
if __name__ == '__main__':
    print("=" * 60)
    print("Soda Speed Force Kernel Bridge Server")
    print("=" * 60)
    
    app = create_app()
    
    host = '127.0.0.1'
    port = 9710
    
    print(f"\nServer: http://{host}:{port}")
    print("\nAPI endpoints:")
    print(f"  GET  /health")
    print(f"  POST /download/add")
    print(f"  POST /download/pause")
    print(f"  POST /download/resume")
    print(f"  POST /download/cancel")
    print(f"  POST /download/retry-segments")
    print(f"  POST /download/retry-segment")
    print(f"  GET  /download/statistics")
    print(f"  GET  /download/tasks")
    print(f"  POST /settings/download-dir")
    print(f"  GET  /settings/download-dir")
    print("\nPress Ctrl+C to stop\n")
    
    try:
        web.run_app(app, host=host, port=port, print=None)
    except OSError as e:
        if e.errno == 48 or e.errno == 10048 or "Address already in use" in str(e) or "通常每个套接字地址" in str(e):
            print(f"\nError: Port {port} is already in use!")
            # 检查端口占用
            if not check_port_usage(port):
                print(f"Could not identify the process using port {port}")
            print(f"Please stop the process using port {port} or use a different port.")
        else:
            print(f"Error starting server: {e}")
