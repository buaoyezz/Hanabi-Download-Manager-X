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
        result = await bridge.pause_download(task_id)
        return web.json_response({"success": result})
    except Exception as e:
        return web.json_response({"success": False, "error": str(e)}, status=400)

async def resume_download(request):
    try:
        data = await request.json()
        task_id = data.get("id")
        result = await bridge.resume_download(task_id)
        return web.json_response({"success": result})
    except Exception as e:
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
        
        # 调试：打印segments信息
        for task_dict in tasks_data:
            if 'segments' in task_dict and task_dict['segments']:
                print(f"[bridge] Task {task_dict['id']}: {len(task_dict['segments'])} segments")
        
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

async def health_check(request):
    return web.json_response({
        "status": "ok",
        "service": "Soda Speed Force Kernel",
        "version": "1.0.0"
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
    
    app.on_startup.append(init_bridge)
    app.on_cleanup.append(cleanup_bridge)
    
    return app

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
    
    web.run_app(app, host=host, port=port, print=None)
