from __future__ import annotations

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
from types import SimpleNamespace
from unittest.mock import patch


PLUGIN_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PLUGIN_DIR))

from ed2k_plugin import (  # noqa: E402
    AmuleBackendProvider,
    AmuleClient,
    AmuleTask,
    BackendSession,
    Ed2kLink,
    Ed2kService,
    PluginFailure,
)


FILE_HASH = "ABCDEF0123456789ABCDEF0123456789"
LINK = f"ed2k://|file|Hanabi%20Archive.bin|10|{FILE_HASH}|/"


class FakeAmuleClient:
    def __init__(self, tasks=None):
        self.tasks = dict(tasks or {})
        self.commands = []

    def show_downloads(self):
        return dict(self.tasks)

    def run(self, command, require_success=False):
        self.commands.append((command, require_success))
        if command.startswith("Add "):
            link = Ed2kLink.parse(command[4:])
            self.tasks[link.file_hash] = AmuleTask(
                link.file_hash, link.file_name, 0, "Waiting"
            )
        elif command.startswith("Pause "):
            file_hash = command.split()[-1]
            task = self.tasks[file_hash]
            self.tasks[file_hash] = AmuleTask(
                task.file_hash, task.file_name, task.progress, "Paused"
            )
        elif command.startswith("Resume "):
            file_hash = command.split()[-1]
            task = self.tasks[file_hash]
            self.tasks[file_hash] = AmuleTask(
                task.file_hash, task.file_name, task.progress, "Waiting"
            )
        elif command.startswith("Cancel "):
            self.tasks.pop(command.split()[-1], None)
        return "Succeeded! Connection established\n > Operation was successful."


class FakeHttpResponse:
    def __init__(self, payload: bytes, status: int):
        self.stream = io.BytesIO(payload)
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def read(self, size=-1):
        return self.stream.read(size)

    def getcode(self):
        return self.status


class Ed2kLinkTests(unittest.TestCase):
    def test_parses_file_link(self):
        link = Ed2kLink.parse(LINK.lower())

        self.assertEqual(link.file_hash, FILE_HASH)
        self.assertEqual(link.file_name, "hanabi archive.bin")
        self.assertEqual(link.size, 10)
        self.assertIn(FILE_HASH, link.normalized)

    def test_rejects_server_link(self):
        with self.assertRaisesRegex(PluginFailure, "Only ED2K file links"):
            Ed2kLink.parse("ed2k://|server|127.0.0.1|4661|/")

    def test_rejects_line_breaks(self):
        with self.assertRaisesRegex(PluginFailure, "cannot contain line breaks"):
            Ed2kLink.parse(LINK.replace("Hanabi", "Hanabi\nStatus"))


class AmuleClientTests(unittest.TestCase):
    def test_parses_show_download_queue(self):
        output = (
            "This is amulecmd 3.0.0\r\n"
            "Succeeded! Connection established to aMule 3.0.0\r\n"
            f" > {FILE_HASH} Hanabi Archive.bin\r\n"
            " > \t [37.5%]    2/   5 - Downloading - 001.part.met - Auto [Hi]\r\n"
        )
        client = AmuleClient("amulecmd", "127.0.0.1", 4712, "secret")
        with patch.object(client, "run", return_value=output):
            tasks = client.show_downloads()

        task = tasks[FILE_HASH]
        self.assertEqual(task.file_name, "Hanabi Archive.bin")
        self.assertEqual(task.progress, 0.375)
        self.assertEqual(task.state, "Downloading")
        self.assertEqual(task.part_file, "001.part.met")

    def test_connection_failure_is_detected_even_with_zero_exit_code(self):
        completed = SimpleNamespace(
            returncode=0,
            stdout=b"Creating client...\nConnection Failed. Unable to connect",
            stderr=b"",
        )
        client = AmuleClient("amulecmd", "127.0.0.1", 4712, "secret")
        with patch("ed2k_plugin.subprocess.run", return_value=completed):
            with self.assertRaisesRegex(PluginFailure, "Cannot connect"):
                client.run("Status")


class Ed2kServiceTests(unittest.TestCase):
    def backend(self, client, incoming=None):
        return lambda: BackendSession(client, incoming, True)

    def test_create_adds_and_pauses_task(self):
        client = FakeAmuleClient()
        service = Ed2kService(self.backend(client), now=lambda: 100)

        result = service.create(
            {
                "intent": {"type": "ed2k", "normalizedValue": LINK},
                "saveDir": "D:/Downloads",
                "startPaused": True,
            },
            "hanabi.official.ed2k",
        )

        self.assertEqual(result["status"], "paused")
        self.assertEqual(result["taskId"], f"plugin:hanabi.official.ed2k:{FILE_HASH}")
        self.assertEqual(client.commands[0][0], f"Add {LINK}")
        self.assertEqual(client.commands[1][0], f"Pause {FILE_HASH}")
        self.assertTrue(all(required for _, required in client.commands))

    def test_create_is_idempotent_by_ed2k_hash(self):
        task = AmuleTask(FILE_HASH, "Hanabi Archive.bin", 0.2, "Waiting")
        client = FakeAmuleClient({FILE_HASH: task})
        service = Ed2kService(self.backend(client), now=lambda: 100)

        result = service.create(
            {"intent": {"type": "ed2k", "normalizedValue": LINK}}
        )

        self.assertEqual(result["status"], "pending")
        self.assertEqual(client.commands, [])

    def test_create_does_not_pause_an_already_completed_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            incoming = root / "incoming"
            incoming.mkdir()
            (incoming / "Hanabi Archive.bin").write_bytes(b"0123456789")
            client = FakeAmuleClient()
            service = Ed2kService(self.backend(client, incoming), now=lambda: 100)

            result = service.create(
                {
                    "intent": {"type": "ed2k", "normalizedValue": LINK},
                    "saveDir": str(root / "destination"),
                    "startPaused": True,
                },
                "hanabi.official.ed2k",
            )

            self.assertEqual(result["status"], "completed")
            self.assertEqual(client.commands, [])

    def test_status_maps_progress_and_sizes(self):
        task = AmuleTask(FILE_HASH, "Hanabi Archive.bin", 0.4, "Downloading")
        client = FakeAmuleClient({FILE_HASH: task})
        service = Ed2kService(self.backend(client))

        result = service.status(
            {
                "pluginData": {
                    "ed2kHash": FILE_HASH,
                    "fileName": "Hanabi Archive.bin",
                    "totalSize": 10,
                    "saveDir": "D:/Downloads",
                }
            }
        )

        self.assertEqual(result["status"], "downloading")
        self.assertEqual(result["progress"], 0.4)
        self.assertEqual(result["downloadedSize"], 4)
        self.assertEqual(result["totalSize"], 10)

    def test_completed_file_moves_to_requested_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            incoming = root / "incoming"
            destination = root / "destination"
            incoming.mkdir()
            (incoming / "Hanabi Archive.bin").write_bytes(b"0123456789")
            client = FakeAmuleClient()
            service = Ed2kService(self.backend(client, incoming), now=lambda: 100)

            result = service.status(
                {
                    "pluginData": {
                        "ed2kHash": FILE_HASH,
                        "fileName": "Hanabi Archive.bin",
                        "totalSize": 10,
                        "saveDir": str(destination),
                        "incomingDir": str(incoming),
                    }
                }
            )

            final_path = destination / "Hanabi Archive.bin"
            self.assertEqual(result["status"], "completed")
            self.assertEqual(result["filePath"], str(final_path))
            self.assertTrue(final_path.is_file())
            self.assertFalse((incoming / "Hanabi Archive.bin").exists())

    def test_same_sized_destination_does_not_mask_completed_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            incoming = root / "incoming"
            destination = root / "destination"
            incoming.mkdir()
            destination.mkdir()
            source = incoming / "Hanabi Archive.bin"
            existing = destination / "Hanabi Archive.bin"
            source.write_bytes(b"new-result")
            existing.write_bytes(b"old-result")
            client = FakeAmuleClient()
            service = Ed2kService(self.backend(client, incoming), now=lambda: 100)

            result = service.status(
                {
                    "pluginData": {
                        "ed2kHash": FILE_HASH,
                        "fileName": "Hanabi Archive.bin",
                        "totalSize": 10,
                        "saveDir": str(destination),
                        "incomingDir": str(incoming),
                    }
                }
            )

            alternate = destination / "Hanabi Archive (ABCDEF01).bin"
            self.assertEqual(result["status"], "completed")
            self.assertEqual(result["filePath"], str(alternate))
            self.assertEqual(existing.read_bytes(), b"old-result")
            self.assertEqual(alternate.read_bytes(), b"new-result")
            self.assertFalse(source.exists())

    def test_missing_task_uses_grace_period_then_fails(self):
        client = FakeAmuleClient()
        data = {
            "ed2kHash": FILE_HASH,
            "fileName": "Hanabi Archive.bin",
            "totalSize": 10,
            "missingSinceEpoch": 100,
        }
        pending = Ed2kService(self.backend(client), now=lambda: 110).status(
            {"pluginData": data}
        )
        failed = Ed2kService(self.backend(client), now=lambda: 131).status(
            {"pluginData": data}
        )

        self.assertEqual(pending["status"], "pending")
        self.assertEqual(failed["status"], "failed")

    def test_remove_is_idempotent_when_task_is_missing(self):
        client = FakeAmuleClient()
        service = Ed2kService(self.backend(client))
        result = service.remove(
            {
                "pluginData": {
                    "ed2kHash": FILE_HASH,
                    "fileName": "Hanabi Archive.bin",
                    "totalSize": 10,
                }
            }
        )

        self.assertEqual(result["status"], "removed")
        self.assertEqual(client.commands, [])


class BackendProviderTests(unittest.TestCase):
    def test_resumes_and_verifies_engine_archive(self):
        archive_stream = io.BytesIO()
        with zipfile.ZipFile(archive_stream, "w") as bundle:
            bundle.writestr("amule-portable/bin/amuled.exe", b"daemon")
            bundle.writestr("amule-portable/bin/amulecmd.exe", b"command")
            bundle.writestr("amule-portable/share/LICENSE.md", b"license")
        archive = archive_stream.getvalue()
        split = len(archive) // 2
        asset = {
            "name": "amule-test",
            "url": "https://example.invalid/amule.zip",
            "sha256": hashlib.sha256(archive).hexdigest(),
            "size": len(archive),
        }

        with tempfile.TemporaryDirectory() as temporary:
            provider = AmuleBackendProvider(
                plugin_dir=PLUGIN_DIR,
                data_dir=temporary,
                log_dir=Path(temporary) / "logs",
                environ={},
            )
            part = Path(temporary) / "engine" / ".downloads" / "amule-test.zip.part"
            part.parent.mkdir(parents=True)
            part.write_bytes(archive[:split])
            with patch.object(provider, "_engine_asset", return_value=asset), patch(
                "ed2k_plugin.urllib.request.urlopen",
                return_value=FakeHttpResponse(archive[split:], 206),
            ):
                engine = provider._install_engine()

            self.assertEqual(engine.amuled.read_bytes(), b"daemon")
            self.assertEqual(engine.amulecmd.read_bytes(), b"command")
            self.assertTrue((engine.amuled.parents[1] / "share" / "LICENSE.md").is_file())
            self.assertFalse(part.exists())

    def test_managed_config_hashes_password_and_binds_ec_to_loopback(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config_path = root / "core" / "amule.conf"
            AmuleBackendProvider._write_amule_config(
                config_path,
                password="plain-secret",
                ec_port=4712,
                client_port=4662,
                udp_port=4672,
                core_dir=root / "core",
                incoming_dir=root / "incoming",
                temporary_dir=root / "temporary",
                auto_connect=True,
            )
            content = config_path.read_text(encoding="utf-8")

        self.assertIn("ECAddress=127.0.0.1", content)
        self.assertIn(
            f"ECPassword={hashlib.md5(b'plain-secret').hexdigest()}", content
        )
        self.assertNotIn("ECPassword=plain-secret", content)


class ProtocolTests(unittest.TestCase):
    def test_main_returns_structured_error_without_starting_backend(self):
        request = {
            "jsonrpc": "2.0",
            "id": "test-1",
            "method": "hanabi.download.create",
            "params": {"intent": {"type": "magnet", "normalizedValue": "x"}},
        }
        environment = dict(os.environ)
        environment["HANABI_PLUGIN_ID"] = "hanabi.official.ed2k"
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
        self.assertEqual(response["error"]["code"], -32010)
        self.assertIn("Unsupported intent type", response["error"]["message"])


if __name__ == "__main__":
    unittest.main()
