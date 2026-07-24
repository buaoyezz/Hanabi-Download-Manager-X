from __future__ import annotations

import base64
import hashlib
import io
import json
import os
import platform
import re
import secrets
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Callable, Iterator, Mapping


PLUGIN_ID = "hanabi.official.bittorrent"
MAX_TORRENT_BYTES = 8 * 1024 * 1024
MAX_ENGINE_ARCHIVE_BYTES = 8 * 1024 * 1024

ENGINE_ASSETS = {
    "win-x64": {
        "name": "aria2-1.37.0-win-64bit-build1",
        "url": "https://github.com/aria2/aria2/releases/download/"
        "release-1.37.0/aria2-1.37.0-win-64bit-build1.zip",
        "sha256": "67d015301eef0b612191212d564c5bb0a14b5b9c4796b76454276a4d28d9b288",
    },
    "win-x86": {
        "name": "aria2-1.37.0-win-32bit-build1",
        "url": "https://github.com/aria2/aria2/releases/download/"
        "release-1.37.0/aria2-1.37.0-win-32bit-build1.zip",
        "sha256": "35f6514cc5dd7e98a87b3c4c2d25a0754b9b063dbe59bc0f22d483464f61e5b6",
    },
}

STATUS_KEYS = [
    "gid",
    "status",
    "totalLength",
    "completedLength",
    "downloadSpeed",
    "uploadSpeed",
    "connections",
    "numSeeders",
    "dir",
    "files",
    "bittorrent",
    "followedBy",
    "errorCode",
    "errorMessage",
]


class PluginFailure(RuntimeError):
    def __init__(
        self,
        code: int,
        message: str,
        data: Mapping[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.data = dict(data) if data is not None else None


class Aria2RpcError(PluginFailure):
    def __init__(self, rpc_code: Any, message: str) -> None:
        super().__init__(
            -32021,
            f"aria2 RPC error: {message}",
            {"aria2Code": rpc_code},
        )
        self.rpc_code = rpc_code
        self.rpc_message = message


class Aria2Client:
    def __init__(self, url: str, secret: str = "", timeout: float = 8) -> None:
        parsed = urllib.parse.urlparse(url)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise PluginFailure(-32020, "aria2 RPC URL must use HTTP or HTTPS")
        self.url = url
        self.secret = secret
        self.timeout = timeout

    def call(self, method: str, params: list[Any] | None = None) -> Any:
        rpc_params = list(params or [])
        if self.secret:
            rpc_params.insert(0, f"token:{self.secret}")
        body = json.dumps(
            {
                "jsonrpc": "2.0",
                "id": secrets.token_hex(8),
                "method": method,
                "params": rpc_params,
            },
            separators=(",", ":"),
        ).encode("utf-8")
        request = urllib.request.Request(
            self.url,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read()
        except urllib.error.HTTPError as error:
            raw = error.read()
            try:
                decoded_error = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                decoded_error = None
            if isinstance(decoded_error, dict) and isinstance(
                decoded_error.get("error"), dict
            ):
                rpc_error = decoded_error["error"]
                raise Aria2RpcError(
                    rpc_error.get("code"),
                    str(rpc_error.get("message") or rpc_error),
                ) from error
            detail = raw.decode("utf-8", errors="replace").strip()
            raise PluginFailure(
                -32021,
                f"aria2 RPC returned HTTP {error.code}: {detail or error.reason}",
            ) from error
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            raise PluginFailure(-32020, f"Cannot connect to aria2 RPC: {error}") from error

        try:
            decoded = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise PluginFailure(-32021, "aria2 RPC returned invalid JSON") from error
        if not isinstance(decoded, dict):
            raise PluginFailure(-32021, "aria2 RPC response must be an object")
        rpc_error = decoded.get("error")
        if rpc_error is not None:
            if isinstance(rpc_error, dict):
                raise Aria2RpcError(
                    rpc_error.get("code"),
                    str(rpc_error.get("message") or rpc_error),
                )
            raise Aria2RpcError(None, str(rpc_error))
        return decoded.get("result")


class Aria2BackendProvider:
    def __init__(
        self,
        *,
        plugin_dir: str | os.PathLike[str] | None = None,
        data_dir: str | os.PathLike[str] | None = None,
        log_dir: str | os.PathLike[str] | None = None,
        environ: Mapping[str, str] | None = None,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self.environ = dict(os.environ if environ is None else environ)
        module_dir = Path(__file__).resolve().parent
        self.plugin_dir = Path(
            plugin_dir or self.environ.get("HANABI_PLUGIN_DIR") or module_dir
        ).resolve()
        self.data_dir = Path(
            data_dir
            or self.environ.get("HANABI_PLUGIN_DATA_DIR")
            or (self.plugin_dir / ".hanabi-data")
        ).resolve()
        self.log_dir = Path(
            log_dir
            or self.environ.get("HANABI_PLUGIN_LOG_DIR")
            or (self.data_dir / "logs")
        ).resolve()
        self.sleep = sleep

    def client(self) -> Aria2Client:
        config = self._load_config()
        external_url = self._text_setting("ARIA2_RPC_URL", config, "rpcUrl")
        external_secret = self._text_setting(
            "ARIA2_RPC_SECRET", config, "rpcSecret"
        )
        if external_url:
            client = Aria2Client(external_url, external_secret)
            client.call("aria2.getVersion")
            return client

        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.log_dir.mkdir(parents=True, exist_ok=True)
        with self._startup_lock():
            running = self._managed_client()
            if running is not None:
                return running

            executable = self._find_executable(config)
            if executable is None and self._bool_setting(
                "ARIA2C_AUTO_INSTALL", config, "autoInstallEngine", True
            ):
                executable = self._install_engine()
            if executable is None:
                raise PluginFailure(
                    -32020,
                    "aria2c is unavailable. Allow the verified Windows engine "
                    "download, place aria2c in the plugin bin directory, set "
                    "ARIA2C_PATH, or configure ARIA2_RPC_URL.",
                )
            return self._start_managed(executable, config)

    def _load_config(self) -> dict[str, Any]:
        path = self.data_dir / "config.json"
        if not path.exists():
            return {}
        try:
            decoded = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
            raise PluginFailure(-32020, f"Invalid plugin config.json: {error}") from error
        if not isinstance(decoded, dict):
            raise PluginFailure(-32020, "Plugin config.json must contain an object")
        return decoded

    def _text_setting(
        self,
        environment_name: str,
        config: Mapping[str, Any],
        config_name: str,
    ) -> str:
        environment_value = self.environ.get(environment_name)
        if environment_value is not None:
            return environment_value.strip()
        value = config.get(config_name)
        return "" if value is None else str(value).strip()

    def _bool_setting(
        self,
        environment_name: str,
        config: Mapping[str, Any],
        config_name: str,
        fallback: bool,
    ) -> bool:
        value: Any = self.environ.get(environment_name)
        if value is None:
            value = config.get(config_name, fallback)
        if isinstance(value, bool):
            return value
        normalized = str(value).strip().lower()
        if normalized in {"1", "true", "yes", "on"}:
            return True
        if normalized in {"0", "false", "no", "off"}:
            return False
        return fallback

    def _managed_client(self) -> Aria2Client | None:
        state_path = self.data_dir / "managed-runtime.json"
        if not state_path.exists():
            return None
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
            url = str(state.get("rpcUrl") or "")
            secret = str(state.get("rpcSecret") or "")
            client = Aria2Client(url, secret, timeout=1)
            client.call("aria2.getVersion")
            return client
        except (OSError, ValueError, PluginFailure, json.JSONDecodeError):
            return None

    def _find_executable(self, config: Mapping[str, Any]) -> Path | None:
        configured = self._text_setting("ARIA2C_PATH", config, "aria2cPath")
        candidates = [
            Path(configured).expanduser() if configured else None,
            self.plugin_dir / "bin" / ("aria2c.exe" if os.name == "nt" else "aria2c"),
            self.plugin_dir / ("aria2c.exe" if os.name == "nt" else "aria2c"),
        ]
        for candidate in candidates:
            if candidate is not None and candidate.is_file():
                return candidate.resolve()
        discovered = shutil.which("aria2c")
        return Path(discovered).resolve() if discovered else None

    def _install_engine(self) -> Path | None:
        asset = self._engine_asset()
        if asset is None:
            return None
        install_dir = self.data_dir / "engine" / asset["name"]
        executable = install_dir / "aria2c.exe"
        if executable.is_file():
            return executable

        try:
            request = urllib.request.Request(
                asset["url"],
                headers={"User-Agent": "Hanabi-BitTorrent-Plugin/0.1.0"},
            )
            chunks: list[bytes] = []
            total = 0
            with urllib.request.urlopen(request, timeout=60) as response:
                content_length = response.headers.get("Content-Length")
                if content_length and int(content_length) > MAX_ENGINE_ARCHIVE_BYTES:
                    raise PluginFailure(-32020, "aria2 engine archive is unexpectedly large")
                while True:
                    chunk = response.read(64 * 1024)
                    if not chunk:
                        break
                    total += len(chunk)
                    if total > MAX_ENGINE_ARCHIVE_BYTES:
                        raise PluginFailure(
                            -32020, "aria2 engine archive exceeded the size limit"
                        )
                    chunks.append(chunk)
        except PluginFailure:
            raise
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as error:
            raise PluginFailure(
                -32020, f"Failed to download the verified aria2 engine: {error}"
            ) from error

        archive = b"".join(chunks)
        actual_hash = hashlib.sha256(archive).hexdigest()
        if actual_hash != asset["sha256"]:
            raise PluginFailure(
                -32020,
                "Downloaded aria2 engine failed SHA-256 verification",
                {"expected": asset["sha256"], "actual": actual_hash},
            )

        temporary = install_dir.with_name(
            f".{install_dir.name}.tmp-{os.getpid()}-{secrets.token_hex(4)}"
        )
        temporary.mkdir(parents=True, exist_ok=False)
        try:
            with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
                members = {
                    Path(name).name.lower(): name
                    for name in bundle.namelist()
                    if not name.endswith("/")
                }
                for output_name in ("aria2c.exe", "COPYING", "LICENSE.OpenSSL"):
                    member = members.get(output_name.lower())
                    if member is None:
                        if output_name == "aria2c.exe":
                            raise PluginFailure(
                                -32020, "aria2 engine archive does not contain aria2c.exe"
                            )
                        continue
                    with bundle.open(member) as source, (temporary / output_name).open(
                        "wb"
                    ) as target:
                        shutil.copyfileobj(source, target)
            _write_json_atomic(
                temporary / "source.json",
                {
                    "url": asset["url"],
                    "sha256": asset["sha256"],
                    "downloadedAt": _utc_timestamp(),
                },
            )
            install_dir.parent.mkdir(parents=True, exist_ok=True)
            if install_dir.exists():
                for item in temporary.iterdir():
                    item.replace(install_dir / item.name)
                temporary.rmdir()
            else:
                temporary.replace(install_dir)
        except (OSError, zipfile.BadZipFile) as error:
            raise PluginFailure(-32020, f"Failed to install aria2 engine: {error}") from error
        finally:
            if temporary.exists():
                shutil.rmtree(temporary, ignore_errors=True)
        return executable

    @staticmethod
    def _engine_asset() -> Mapping[str, str] | None:
        if os.name != "nt":
            return None
        machine = platform.machine().strip().lower()
        if machine in {"amd64", "x86_64"}:
            return ENGINE_ASSETS["win-x64"]
        if machine in {"x86", "i386", "i686"}:
            return ENGINE_ASSETS["win-x86"]
        return None

    def _start_managed(
        self, executable: Path, config: Mapping[str, Any]
    ) -> Aria2Client:
        port = _available_loopback_port()
        secret = secrets.token_hex(32)
        session_path = self.data_dir / "aria2.session"
        session_path.touch(exist_ok=True)
        aria2_config = self.data_dir / "aria2.conf"
        config_lines = [
            "enable-rpc=true",
            "rpc-listen-all=false",
            f"rpc-listen-port={port}",
            f"rpc-secret={secret}",
            "continue=true",
            "allow-overwrite=false",
            "auto-file-renaming=true",
            "file-allocation=none",
            "seed-time=0",
            "bt-save-metadata=true",
            "bt-metadata-only=false",
            "save-session-interval=30",
            "auto-save-interval=30",
            "max-download-result=1000",
            "keep-unfinished-download-result=true",
            "summary-interval=0",
            "console-log-level=warn",
            "rpc-max-request-size=16M",
            f"input-file={session_path.as_posix()}",
            f"save-session={session_path.as_posix()}",
        ]
        aria2_config.write_text("\n".join(config_lines) + "\n", encoding="utf-8")

        log_path = self.log_dir / "aria2.log"
        creation_flags = 0
        popen_options: dict[str, Any] = {}
        if os.name == "nt":
            creation_flags = getattr(subprocess, "DETACHED_PROCESS", 0x00000008)
            creation_flags |= getattr(
                subprocess, "CREATE_NEW_PROCESS_GROUP", 0x00000200
            )
        else:
            popen_options["start_new_session"] = True
        try:
            with log_path.open("ab") as log_file:
                process = subprocess.Popen(
                    [str(executable), f"--conf-path={aria2_config}"],
                    cwd=str(self.data_dir),
                    stdin=subprocess.DEVNULL,
                    stdout=log_file,
                    stderr=log_file,
                    creationflags=creation_flags,
                    **popen_options,
                )
        except OSError as error:
            raise PluginFailure(-32020, f"Failed to start aria2c: {error}") from error

        url = f"http://127.0.0.1:{port}/jsonrpc"
        client = Aria2Client(url, secret, timeout=1)
        startup_seconds = _bounded_int(config.get("startupTimeoutSeconds"), 12, 2, 60)
        deadline = time.monotonic() + startup_seconds
        last_error = "process did not become ready"
        while time.monotonic() < deadline:
            if process.poll() is not None:
                last_error = f"aria2c exited with code {process.returncode}"
                break
            try:
                client.call("aria2.getVersion")
                _write_json_atomic(
                    self.data_dir / "managed-runtime.json",
                    {
                        "rpcUrl": url,
                        "rpcSecret": secret,
                        "pid": process.pid,
                        "executable": str(executable),
                        "startedAt": _utc_timestamp(),
                    },
                )
                return client
            except PluginFailure as error:
                last_error = error.message
                self.sleep(0.2)
        if process.poll() is None:
            process.terminate()
        raise PluginFailure(-32020, f"aria2c did not become ready: {last_error}")

    @contextmanager
    def _startup_lock(self) -> Iterator[None]:
        lock_path = self.data_dir / "startup.lock"
        deadline = time.monotonic() + 15
        descriptor: int | None = None
        while descriptor is None:
            try:
                descriptor = os.open(
                    lock_path,
                    os.O_CREAT | os.O_EXCL | os.O_WRONLY,
                    0o600,
                )
                os.write(descriptor, str(os.getpid()).encode("ascii"))
            except FileExistsError:
                try:
                    if time.time() - lock_path.stat().st_mtime > 60:
                        lock_path.unlink(missing_ok=True)
                        continue
                except OSError:
                    pass
                if time.monotonic() >= deadline:
                    raise PluginFailure(-32020, "Timed out waiting for aria2 startup lock")
                self.sleep(0.1)
        try:
            yield
        finally:
            os.close(descriptor)
            lock_path.unlink(missing_ok=True)


class BitTorrentService:
    def __init__(
        self,
        client_factory: Callable[[], Aria2Client] | None = None,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self._provider = None if client_factory else Aria2BackendProvider()
        self._client_factory = client_factory or self._provider.client
        self._sleep = sleep

    def create(self, params: Mapping[str, Any], plugin_id: str = "") -> dict[str, Any]:
        intent = params.get("intent")
        if not isinstance(intent, Mapping):
            raise PluginFailure(-32010, "Download intent is required")
        intent_type = str(intent.get("type") or "").strip().lower()
        value = str(
            intent.get("normalizedValue") or intent.get("rawValue") or ""
        ).strip()
        if intent_type not in {"magnet", "torrent_file"}:
            raise PluginFailure(-32010, f"Unsupported intent type: {intent_type or 'empty'}")
        if not value:
            raise PluginFailure(-32010, "Download intent value is empty")

        save_dir = str(params.get("saveDir") or "").strip()
        options: dict[str, str] = {"seed-time": "0"}
        if save_dir:
            options["dir"] = str(Path(save_dir).expanduser())
        start_paused = bool(params.get("startPaused"))
        if start_paused:
            options["pause"] = "true"

        if intent_type == "magnet":
            if urllib.parse.urlparse(value).scheme.lower() != "magnet":
                raise PluginFailure(-32010, "Magnet intent must use the magnet: scheme")
            client = self._client_factory()
            gid = client.call("aria2.addUri", [[value], options])
        else:
            torrent_path = Path(value).expanduser()
            if not torrent_path.is_file():
                raise PluginFailure(-32010, f"Torrent file does not exist: {torrent_path}")
            size = torrent_path.stat().st_size
            if size <= 0:
                raise PluginFailure(-32010, "Torrent file is empty")
            if size > MAX_TORRENT_BYTES:
                raise PluginFailure(
                    -32010,
                    f"Torrent file exceeds the {MAX_TORRENT_BYTES // 1024 // 1024} MiB limit",
                )
            encoded = base64.b64encode(torrent_path.read_bytes()).decode("ascii")
            client = self._client_factory()
            gid = client.call("aria2.addTorrent", [encoded, [], options])

        backend_id = str(gid or "").strip()
        if not backend_id:
            raise PluginFailure(-32021, "aria2 did not return a task GID")
        data = _plugin_data(backend_id, backend_id)
        return {
            "accepted": True,
            "taskId": f"plugin:{plugin_id or PLUGIN_ID}:{backend_id}",
            "status": "paused" if start_paused else "pending",
            "fileName": str(params.get("fileName") or "BitTorrent download"),
            "pluginData": data,
        }

    def status(self, params: Mapping[str, Any]) -> dict[str, Any]:
        original_gid, root_gid = _task_identity(params)
        client = self._client_factory()
        try:
            gid, raw = _effective_status(client, original_gid)
        except Aria2RpcError as error:
            if _is_missing_task(error):
                return {
                    "status": "failed",
                    "error": "The aria2 task no longer exists",
                    "pluginData": _plugin_data(original_gid, root_gid),
                }
            raise

        total = _integer(raw.get("totalLength"))
        completed = _integer(raw.get("completedLength"))
        speed = _integer(raw.get("downloadSpeed"))
        progress = completed / total if total > 0 else 0.0
        status = _map_status(str(raw.get("status") or ""), total)
        return {
            "status": status,
            "totalSize": total,
            "downloadedSize": completed,
            "speed": speed,
            "progress": max(0.0, min(progress, 1.0)),
            "filePath": _download_path(raw),
            "error": str(raw.get("errorMessage") or ""),
            "uploadSpeed": _integer(raw.get("uploadSpeed")),
            "peerCount": _integer(raw.get("connections")),
            "seeders": _integer(raw.get("numSeeders")),
            "pluginData": _plugin_data(gid, root_gid),
        }

    def pause(self, params: Mapping[str, Any]) -> dict[str, Any]:
        original_gid, root_gid = _task_identity(params)
        client = self._client_factory()
        gid, raw = _effective_status(client, original_gid)
        aria_status = str(raw.get("status") or "")
        if aria_status in {"active", "waiting"}:
            client.call("aria2.forcePause", [gid])
            status = "paused"
        else:
            status = _map_status(aria_status, _integer(raw.get("totalLength")))
        return {"status": status, "pluginData": _plugin_data(gid, root_gid)}

    def resume(self, params: Mapping[str, Any]) -> dict[str, Any]:
        original_gid, root_gid = _task_identity(params)
        client = self._client_factory()
        gid, raw = _effective_status(client, original_gid)
        aria_status = str(raw.get("status") or "")
        if aria_status == "paused":
            client.call("aria2.unpause", [gid])
            status = "pending"
        else:
            status = _map_status(aria_status, _integer(raw.get("totalLength")))
        return {"status": status, "pluginData": _plugin_data(gid, root_gid)}

    def remove(self, params: Mapping[str, Any]) -> dict[str, Any]:
        original_gid, root_gid = _task_identity(params)
        client = self._client_factory()
        gids = [original_gid]
        if root_gid != original_gid:
            gids.append(root_gid)
        try:
            effective_gid, _ = _effective_status(client, original_gid)
            if effective_gid != original_gid:
                gids.insert(0, effective_gid)
        except Aria2RpcError as error:
            if not _is_missing_task(error):
                raise

        for gid in gids:
            try:
                raw = client.call("aria2.tellStatus", [gid, ["status"]])
                aria_status = str(raw.get("status") or "") if isinstance(raw, dict) else ""
                if aria_status in {"active", "waiting", "paused"}:
                    client.call("aria2.forceRemove", [gid])
                    for _ in range(10):
                        self._sleep(0.05)
                        try:
                            state = client.call("aria2.tellStatus", [gid, ["status"]])
                            if isinstance(state, dict) and state.get("status") == "removed":
                                break
                        except Aria2RpcError as error:
                            if _is_missing_task(error):
                                break
                            raise
                try:
                    client.call("aria2.removeDownloadResult", [gid])
                except Aria2RpcError:
                    pass
            except Aria2RpcError as error:
                if not _is_missing_task(error):
                    raise
        return {"status": "removed", "pluginData": _plugin_data(gids[0], root_gid)}


def _effective_status(client: Aria2Client, gid: str) -> tuple[str, dict[str, Any]]:
    current = gid
    visited: set[str] = set()
    for _ in range(8):
        if current in visited:
            raise PluginFailure(-32021, "aria2 returned a cyclic followedBy chain")
        visited.add(current)
        raw = client.call("aria2.tellStatus", [current, STATUS_KEYS])
        if not isinstance(raw, dict):
            raise PluginFailure(-32021, "aria2 tellStatus returned an invalid result")
        followed = raw.get("followedBy")
        if not isinstance(followed, list) or not followed:
            return current, raw
        next_gid = str(followed[0] or "").strip()
        if not next_gid:
            return current, raw
        current = next_gid
    raise PluginFailure(-32021, "aria2 followedBy chain is too deep")


def _task_identity(params: Mapping[str, Any]) -> tuple[str, str]:
    plugin_data = params.get("pluginData")
    gid = ""
    root_gid = ""
    if isinstance(plugin_data, Mapping):
        root_gid = str(plugin_data.get("rootGid") or "").strip()
        gid = str(plugin_data.get("gid") or root_gid).strip()
    if not gid:
        task_id = str(params.get("taskId") or "").strip()
        gid = task_id.rsplit(":", 1)[-1] if ":" in task_id else task_id
    if not gid:
        raise PluginFailure(-32010, "Task does not contain an aria2 GID")
    return gid, root_gid or gid


def _plugin_data(gid: str, root_gid: str) -> dict[str, Any]:
    return {
        "backend": "aria2",
        "schemaVersion": 1,
        "gid": gid,
        "rootGid": root_gid,
    }


def _map_status(status: str, total_size: int) -> str:
    if status == "active":
        return "downloading" if total_size > 0 else "pending"
    return {
        "waiting": "pending",
        "paused": "paused",
        "complete": "completed",
        "error": "failed",
        "removed": "removed",
    }.get(status, "pending")


def _download_path(raw: Mapping[str, Any]) -> str:
    directory = str(raw.get("dir") or "").strip()
    bittorrent = raw.get("bittorrent")
    if isinstance(bittorrent, Mapping):
        info = bittorrent.get("info")
        if isinstance(info, Mapping):
            name = str(info.get("name") or "").strip()
            if name and directory:
                return str(Path(directory) / name)
    files = raw.get("files")
    paths = [
        str(item.get("path") or "").strip()
        for item in files
        if isinstance(item, Mapping) and str(item.get("path") or "").strip()
    ] if isinstance(files, list) else []
    if len(paths) == 1:
        return paths[0]
    if len(paths) > 1:
        try:
            return os.path.commonpath(paths)
        except ValueError:
            pass
    return directory


def _is_missing_task(error: Aria2RpcError) -> bool:
    message = error.rpc_message.lower()
    return "gid" in message and (
        "not found" in message
        or "not exist" in message
        or "cannot be found" in message
    )


def _integer(value: Any) -> int:
    try:
        return max(0, int(value or 0))
    except (TypeError, ValueError):
        return 0


def _bounded_int(value: Any, fallback: int, minimum: int, maximum: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return fallback
    return max(minimum, min(parsed, maximum))


def _available_loopback_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


def _write_json_atomic(path: Path, value: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp-{os.getpid()}-{secrets.token_hex(4)}")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def _utc_timestamp() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
