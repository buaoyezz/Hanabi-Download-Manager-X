import asyncio
import sys
import os
from aiohttp import web

sys.path.insert(0, os.path.dirname(__file__))

from soda_speed_force_kernel import NsfXCoreBridge

bridge = None

async def init_bridge(app):
    global bridge
    download_dir = os.path.join(os.path.expanduser("~"), "Downloads")
    bridge = NsfXCoreBridge(downloadDir=download_dir, threads=8)
    print(f"Soda Speed Force Kernel started")
    print(f"Download directory: {download_dir}")
    print(f"Multi-thread download: 8 threads")

async def cleanup_bridge(app):
    global bridge
    if bridge:
        bridge.cleanup()
        print("Soda Speed Force Kernel stopped")

pending_popup_downloads = []

async def add_download(request):
    try:
        data = await request.json()
        print(f"[bridge] add_download received: url={data.get('url')} filename={data.get('filename')} from_browser={data.get('from_browser', False)}")
        
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
            print(f"[bridge] direct add_download succeeded: id={result.get('id')}")
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
        
        print(f"[bridge_server] set_download_config: limit={segment_speed_limit}")
        
        config = bridge.set_download_config(
            threads=threads, 
            segments=segments, 
            mode=mode,
            max_concurrent_tasks=max_concurrent_tasks,
            segment_speed_limit=segment_speed_limit
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

async def health_check(request):
    return web.json_response({
        "status": "ok",
        "service": "Soda Speed Force Kernel",
        "version": "1.5.5"
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
    app.router.add_get('/download/statistics', get_statistics)
    app.router.add_get('/download/tasks', get_all_tasks)
    app.router.add_get('/download/pending-popup', get_pending_popup)
    app.router.add_post('/settings/download-dir', set_download_dir)
    app.router.add_get('/settings/download-dir', get_download_dir)
    app.router.add_post('/settings/download-config', set_download_config)
    app.router.add_get('/settings/download-config', get_download_config)
    app.router.add_post('/settings/clear-all-data', clear_all_data)
    
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
