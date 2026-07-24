from __future__ import annotations

import base64
import hashlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError


PLUGIN_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN_DIR))

from bittorrent_plugin import (  # noqa: E402
    Aria2BackendProvider,
    Aria2Client,
    Aria2RpcError,
    BitTorrentService,
    PluginFailure,
)


class FakeClient:
    def __init__(self, handler):
        self.handler = handler
        self.calls = []

    def call(self, method, params=None):
        actual_params = list(params or [])
        self.calls.append((method, actual_params))
        return self.handler(method, actual_params)


class FakeHttpResponse:
    def __init__(self, payload: bytes):
        self._stream = io.BytesIO(payload)
        self.headers = {"Content-Length": str(len(payload))}

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def read(self, size=-1):
        return self._stream.read(size)


class BitTorrentServiceTests(unittest.TestCase):
    def test_create_magnet_passes_directory_and_paused_option(self):
        fake = FakeClient(lambda method, params: "0123456789abcdef")
        service = BitTorrentService(lambda: fake)

        result = service.create(
            {
                "intent": {
                    "type": "magnet",
                    "normalizedValue": "magnet:?xt=urn:btih:abc",
                },
                "fileName": "Linux ISO",
                "saveDir": "D:/Downloads",
                "startPaused": True,
            },
            "hanabi.official.bittorrent",
        )

        self.assertEqual(result["status"], "paused")
        self.assertEqual(
            result["taskId"],
            "plugin:hanabi.official.bittorrent:0123456789abcdef",
        )
        method, params = fake.calls[0]
        self.assertEqual(method, "aria2.addUri")
        self.assertEqual(params[0], ["magnet:?xt=urn:btih:abc"])
        self.assertEqual(params[1]["dir"], str(Path("D:/Downloads")))
        self.assertEqual(params[1]["pause"], "true")
        self.assertEqual(params[1]["seed-time"], "0")

    def test_create_torrent_base64_encodes_file(self):
        fake = FakeClient(lambda method, params: "fedcba9876543210")
        service = BitTorrentService(lambda: fake)
        with tempfile.TemporaryDirectory() as temporary:
            torrent = Path(temporary) / "sample.torrent"
            torrent.write_bytes(b"d4:infode")

            result = service.create(
                {
                    "intent": {
                        "type": "torrent_file",
                        "normalizedValue": str(torrent),
                    }
                }
            )

        self.assertTrue(result["accepted"])
        method, params = fake.calls[0]
        self.assertEqual(method, "aria2.addTorrent")
        self.assertEqual(base64.b64decode(params[0]), b"d4:infode")

    def test_invalid_magnet_does_not_start_backend(self):
        started = False

        def factory():
            nonlocal started
            started = True
            raise AssertionError("backend should not start")

        service = BitTorrentService(factory)
        with self.assertRaisesRegex(PluginFailure, "magnet: scheme"):
            service.create(
                {"intent": {"type": "magnet", "normalizedValue": "https://x"}}
            )
        self.assertFalse(started)

    def test_status_follows_magnet_metadata_gid_and_keeps_root_gid(self):
        def handler(method, params):
            self.assertEqual(method, "aria2.tellStatus")
            if params[0] == "root-gid":
                return {"gid": "root-gid", "status": "complete", "followedBy": ["data-gid"]}
            return {
                "gid": "data-gid",
                "status": "active",
                "totalLength": "1000",
                "completedLength": "250",
                "downloadSpeed": "100",
                "uploadSpeed": "5",
                "connections": "7",
                "numSeeders": "3",
                "dir": "D:/Downloads",
                "bittorrent": {"info": {"name": "Example"}},
                "files": [],
            }

        service = BitTorrentService(lambda: FakeClient(handler))
        result = service.status(
            {"pluginData": {"gid": "root-gid", "rootGid": "root-gid"}}
        )

        self.assertEqual(result["status"], "downloading")
        self.assertEqual(result["progress"], 0.25)
        self.assertEqual(result["filePath"], str(Path("D:/Downloads") / "Example"))
        self.assertEqual(result["pluginData"]["gid"], "data-gid")
        self.assertEqual(result["pluginData"]["rootGid"], "root-gid")

    def test_missing_status_becomes_terminal_failure(self):
        def handler(method, params):
            raise Aria2RpcError(1, "GID abc is not found")

        service = BitTorrentService(lambda: FakeClient(handler))
        result = service.status({"taskId": "plugin:test:abc"})

        self.assertEqual(result["status"], "failed")
        self.assertIn("no longer exists", result["error"])

    def test_pause_and_resume_are_idempotent(self):
        states = iter(["active", "paused"])

        def handler(method, params):
            if method == "aria2.tellStatus":
                return {"gid": "gid-1", "status": next(states), "totalLength": "100"}
            return "OK"

        fake = FakeClient(handler)
        service = BitTorrentService(lambda: fake)
        paused = service.pause({"pluginData": {"gid": "gid-1"}})
        resumed = service.resume({"pluginData": {"gid": "gid-1"}})

        self.assertEqual(paused["status"], "paused")
        self.assertEqual(resumed["status"], "pending")
        methods = [method for method, _ in fake.calls]
        self.assertIn("aria2.forcePause", methods)
        self.assertIn("aria2.unpause", methods)

    def test_remove_cleans_current_and_root_gid_without_deleting_files(self):
        statuses = {"data-gid": "active", "root-gid": "complete"}

        def handler(method, params):
            gid = params[0] if params else ""
            if method == "aria2.tellStatus":
                return {"gid": gid, "status": statuses[gid]}
            if method == "aria2.forceRemove":
                statuses[gid] = "removed"
                return gid
            if method == "aria2.removeDownloadResult" and gid == "data-gid":
                raise Aria2RpcError(1, "Download result cannot be removed yet")
            return "OK"

        fake = FakeClient(handler)
        service = BitTorrentService(lambda: fake, sleep=lambda _: None)
        result = service.remove(
            {"pluginData": {"gid": "data-gid", "rootGid": "root-gid"}}
        )

        self.assertEqual(result["status"], "removed")
        removed_results = [
            params[0]
            for method, params in fake.calls
            if method == "aria2.removeDownloadResult"
        ]
        self.assertEqual(removed_results, ["data-gid", "root-gid"])


class BackendProviderTests(unittest.TestCase):
    def test_verified_engine_archive_installs_only_expected_files(self):
        archive_stream = io.BytesIO()
        with zipfile.ZipFile(archive_stream, "w") as bundle:
            bundle.writestr("aria2-test/aria2c.exe", b"exe")
            bundle.writestr("aria2-test/COPYING", b"license")
            bundle.writestr("aria2-test/unexpected.dll", b"unexpected")
        archive = archive_stream.getvalue()
        asset = {
            "name": "aria2-test",
            "url": "https://example.invalid/aria2.zip",
            "sha256": hashlib.sha256(archive).hexdigest(),
        }

        with tempfile.TemporaryDirectory() as temporary:
            provider = Aria2BackendProvider(
                plugin_dir=PLUGIN_DIR,
                data_dir=temporary,
                log_dir=Path(temporary) / "logs",
                environ={},
            )
            with patch.object(provider, "_engine_asset", return_value=asset), patch(
                "bittorrent_plugin.urllib.request.urlopen",
                return_value=FakeHttpResponse(archive),
            ):
                executable = provider._install_engine()

            self.assertEqual(executable.read_bytes(), b"exe")
            self.assertTrue((executable.parent / "COPYING").is_file())
            self.assertFalse((executable.parent / "unexpected.dll").exists())

    def test_invalid_config_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            Path(temporary, "config.json").write_text("[]", encoding="utf-8")
            provider = Aria2BackendProvider(
                plugin_dir=PLUGIN_DIR,
                data_dir=temporary,
                environ={},
            )
            with self.assertRaisesRegex(PluginFailure, "must contain an object"):
                provider.client()


class Aria2ClientTests(unittest.TestCase):
    def test_http_400_json_rpc_error_remains_structured(self):
        payload = json.dumps(
            {
                "jsonrpc": "2.0",
                "id": "test",
                "error": {"code": 1, "message": "GID abc is not found"},
            }
        ).encode("utf-8")
        http_error = HTTPError(
            "http://127.0.0.1:6800/jsonrpc",
            400,
            "Bad Request",
            {},
            io.BytesIO(payload),
        )
        client = Aria2Client("http://127.0.0.1:6800/jsonrpc")

        with patch(
            "bittorrent_plugin.urllib.request.urlopen", side_effect=http_error
        ), self.assertRaises(Aria2RpcError) as caught:
            client.call("aria2.tellStatus", ["abc"])

        self.assertEqual(caught.exception.rpc_code, 1)
        self.assertEqual(caught.exception.rpc_message, "GID abc is not found")


class ProtocolTests(unittest.TestCase):
    def test_main_returns_structured_error_without_starting_backend(self):
        request = {
            "jsonrpc": "2.0",
            "id": "test-1",
            "method": "hanabi.download.create",
            "params": {"intent": {"type": "custom", "normalizedValue": "x"}},
        }
        environment = dict(os.environ)
        environment["HANABI_PLUGIN_ID"] = "hanabi.official.bittorrent"
        completed = subprocess.run(
            [sys.executable, str(PLUGIN_DIR / "main.py")],
            input=json.dumps(request),
            text=True,
            capture_output=True,
            check=False,
            cwd=PLUGIN_DIR,
            env=environment,
            timeout=10,
        )

        self.assertEqual(completed.returncode, 0, completed.stderr)
        response = json.loads(completed.stdout)
        self.assertEqual(response["id"], "test-1")
        self.assertEqual(response["error"]["code"], -32010)
        self.assertIn("Unsupported intent type", response["error"]["message"])


if __name__ == "__main__":
    unittest.main()
