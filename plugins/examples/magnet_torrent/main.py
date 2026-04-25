import base64
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request


RPC_URL = os.environ.get("HANABI_ARIA2_RPC", "http://127.0.0.1:6800/jsonrpc")
RPC_TOKEN = os.environ.get("HANABI_ARIA2_RPC_TOKEN") or os.environ.get(
    "ARIA2_RPC_TOKEN"
)


def respond(request_id, result=None, error=None):
    payload = {"jsonrpc": "2.0", "id": request_id}
    if error is not None:
        payload["error"] = {"code": -32000, "message": error}
    else:
        payload["result"] = result or {}
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def aria2_params(params):
    if RPC_TOKEN:
        return [f"token:{RPC_TOKEN}", *params]
    return params


def aria2_call(method, params=None, timeout=8):
    body = json.dumps(
        {
            "jsonrpc": "2.0",
            "id": str(int(time.time() * 1000)),
            "method": method,
            "params": aria2_params(params or []),
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        RPC_URL,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = json.loads(response.read().decode("utf-8"))
    if "error" in data:
        message = data["error"].get("message", data["error"])
        raise RuntimeError(str(message))
    return data.get("result")


def ensure_aria2(save_dir=None):
    try:
        aria2_call("aria2.getVersion", timeout=2)
        return
    except Exception:
        pass

    aria2c = shutil.which("aria2c")
    if not aria2c:
        raise RuntimeError(
            "aria2c not found. Install aria2 and make sure aria2c is in PATH, "
            "or start your own aria2 RPC server and set HANABI_ARIA2_RPC."
        )

    args = [
        aria2c,
        "--enable-rpc=true",
        "--rpc-listen-all=false",
        "--rpc-listen-port=6800",
        "--continue=true",
        "--auto-file-renaming=true",
        "--allow-overwrite=false",
        "--summary-interval=0",
        "--console-log-level=warn",
    ]
    if RPC_TOKEN:
        args.append(f"--rpc-secret={RPC_TOKEN}")
    if save_dir:
        args.append(f"--dir={save_dir}")

    creationflags = 0
    if os.name == "nt":
        creationflags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP

    subprocess.Popen(
        args,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=creationflags,
    )

    last_error = None
    for _ in range(20):
        time.sleep(0.25)
        try:
            aria2_call("aria2.getVersion", timeout=2)
            return
        except Exception as exc:
            last_error = exc
    raise RuntimeError(f"aria2 RPC did not become ready: {last_error}")


def create_task(params):
    intent = params.get("intent") or {}
    intent_type = intent.get("type")
    value = intent.get("normalizedValue") or intent.get("rawValue")
    file_name = params.get("fileName") or "plugin-download"
    save_dir = params.get("saveDir")

    if intent_type not in {"magnet", "torrent_file"}:
        raise RuntimeError(f"Unsupported intent type: {intent_type}")
    if not value:
        raise RuntimeError("Empty intent value")

    ensure_aria2(save_dir)

    options = {}
    if save_dir:
        options["dir"] = save_dir

    if intent_type == "magnet":
        gid = aria2_call("aria2.addUri", [[value], options])
    else:
        with open(value, "rb") as file:
            torrent = base64.b64encode(file.read()).decode("ascii")
        gid = aria2_call("aria2.addTorrent", [torrent, [], options])

    return {
        "accepted": True,
        "taskId": f"plugin:hanabi.example.magnet_torrent:{gid}",
        "status": "pending",
        "fileName": file_name,
        "pluginData": {"gid": gid, "aria2Rpc": RPC_URL},
    }


def task_gid(params):
    plugin_data = params.get("pluginData") or {}
    gid = plugin_data.get("gid")
    if not gid:
        task_id = params.get("taskId", "")
        gid = task_id.rsplit(":", 1)[-1] if ":" in task_id else task_id
    if not gid:
        raise RuntimeError("Missing aria2 gid")
    return gid


def status_task(params):
    gid = task_gid(params)
    ensure_aria2(params.get("saveDir"))
    raw = aria2_call(
        "aria2.tellStatus",
        [
            gid,
            [
                "gid",
                "status",
                "totalLength",
                "completedLength",
                "downloadSpeed",
                "files",
                "errorMessage",
            ],
        ],
    )
    total = int(raw.get("totalLength") or 0)
    done = int(raw.get("completedLength") or 0)
    progress = done / total if total > 0 else 0
    files = raw.get("files") or []
    first_path = ""
    if files and isinstance(files[0], dict):
        first_path = files[0].get("path") or ""
    return {
        "status": map_status(raw.get("status")),
        "totalSize": total if total > 0 else None,
        "downloadedSize": done,
        "speed": float(raw.get("downloadSpeed") or 0),
        "progress": progress,
        "filePath": first_path,
        "error": raw.get("errorMessage") or "",
        "pluginData": {"gid": gid, "aria2Rpc": RPC_URL},
    }


def map_status(status):
    return {
        "active": "downloading",
        "waiting": "pending",
        "paused": "paused",
        "complete": "completed",
        "error": "failed",
        "removed": "removed",
    }.get(status or "", "pending")


def pause_task(params):
    gid = task_gid(params)
    ensure_aria2(params.get("saveDir"))
    try:
        aria2_call("aria2.pause", [gid])
    except RuntimeError as exc:
        if "not found" not in str(exc).lower():
            raise
    return {"status": "paused", "pluginData": {"gid": gid, "aria2Rpc": RPC_URL}}


def resume_task(params):
    gid = task_gid(params)
    ensure_aria2(params.get("saveDir"))
    aria2_call("aria2.unpause", [gid])
    return {"status": "pending", "pluginData": {"gid": gid, "aria2Rpc": RPC_URL}}


def remove_task(params):
    gid = task_gid(params)
    ensure_aria2(params.get("saveDir"))
    for method in ("aria2.remove", "aria2.removeDownloadResult"):
        try:
            aria2_call(method, [gid])
        except RuntimeError:
            pass
    return {"status": "removed", "pluginData": {"gid": gid, "aria2Rpc": RPC_URL}}


def main():
    line = sys.stdin.readline()
    if not line:
        return

    request = json.loads(line)
    request_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}

    try:
        if method == "hanabi.download.create":
            respond(request_id, create_task(params))
        elif method == "hanabi.download.status":
            respond(request_id, status_task(params))
        elif method == "hanabi.download.pause":
            respond(request_id, pause_task(params))
        elif method == "hanabi.download.resume":
            respond(request_id, resume_task(params))
        elif method == "hanabi.download.remove":
            respond(request_id, remove_task(params))
        else:
            respond(request_id, error=f"Unsupported method: {method}")
    except (RuntimeError, OSError, urllib.error.URLError) as exc:
        respond(request_id, error=str(exc))


if __name__ == "__main__":
    main()
