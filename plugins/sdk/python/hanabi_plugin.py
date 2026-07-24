"""Minimal dependency-free SDK for Hanabi JSON-RPC plugins."""

from __future__ import annotations

import asyncio
import inspect
import json
import os
import sys
import traceback
from dataclasses import dataclass
from typing import Any, Callable, Mapping


Handler = Callable[[dict[str, Any], "PluginContext"], Any]


@dataclass(frozen=True)
class PluginContext:
    """Host metadata attached to one plugin invocation."""

    request_id: Any
    method: str
    meta: dict[str, Any]

    @property
    def plugin_id(self) -> str:
        return os.environ.get("HANABI_PLUGIN_ID", "")

    @property
    def plugin_dir(self) -> str:
        return os.environ.get("HANABI_PLUGIN_DIR", "")

    @property
    def data_dir(self) -> str:
        return os.environ.get("HANABI_PLUGIN_DATA_DIR", "")

    @property
    def log_dir(self) -> str:
        return os.environ.get("HANABI_PLUGIN_LOG_DIR", "")


class JsonRpcError(Exception):
    """Return a structured JSON-RPC error to Hanabi."""

    def __init__(
        self,
        code: int,
        message: str,
        data: Any | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.data = data


class HanabiPlugin:
    """One-request plugin dispatcher used by Hanabi API v1."""

    def __init__(self) -> None:
        self._handlers: dict[str, Handler] = {}

    def method(self, name: str) -> Callable[[Handler], Handler]:
        """Register a function using decorator syntax."""

        def decorator(handler: Handler) -> Handler:
            self.register(name, handler)
            return handler

        return decorator

    def register(self, name: str, handler: Handler) -> None:
        normalized = name.strip()
        if not normalized:
            raise ValueError("method name cannot be empty")
        if normalized in self._handlers:
            raise ValueError(f"method already registered: {normalized}")
        self._handlers[normalized] = handler

    def run(self) -> int:
        request_id: Any = None
        try:
            request = self._read_request()
            request_id = request.get("id")
            method = str(request.get("method") or "").strip()
            if not method:
                raise JsonRpcError(-32600, "Request method is required")
            handler = self._handlers.get(method)
            if handler is None:
                raise JsonRpcError(-32601, f"Method not found: {method}")

            raw_params = request.get("params")
            if raw_params is None:
                params: dict[str, Any] = {}
            elif isinstance(raw_params, dict):
                params = raw_params
            else:
                raise JsonRpcError(-32602, "params must be an object")
            raw_meta = request.get("meta")
            meta = raw_meta if isinstance(raw_meta, dict) else {}
            context = PluginContext(request_id=request_id, method=method, meta=meta)
            result = handler(params, context)
            if inspect.isawaitable(result):
                result = asyncio.run(result)
            self._write({"jsonrpc": "2.0", "id": request_id, "result": result})
            return 0
        except JsonRpcError as error:
            payload: dict[str, Any] = {
                "code": error.code,
                "message": error.message,
            }
            if error.data is not None:
                payload["data"] = error.data
            self._write({"jsonrpc": "2.0", "id": request_id, "error": payload})
            return 0
        except Exception as error:  # Keep protocol errors on stdout, logs on stderr.
            traceback.print_exc(file=sys.stderr)
            self._write(
                {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {
                        "code": -32603,
                        "message": str(error) or type(error).__name__,
                    },
                }
            )
            return 0

    @staticmethod
    def _read_request() -> dict[str, Any]:
        raw = sys.stdin.buffer.read()
        if not raw.strip():
            raise JsonRpcError(-32600, "Request body is empty")
        try:
            decoded = json.loads(raw.decode("utf-8-sig"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise JsonRpcError(-32700, f"Invalid JSON: {error}") from error
        if not isinstance(decoded, dict):
            raise JsonRpcError(-32600, "Request must be a JSON object")
        if decoded.get("jsonrpc") not in (None, "2.0"):
            raise JsonRpcError(-32600, "Only JSON-RPC 2.0 is supported")
        return decoded

    @staticmethod
    def _write(response: Mapping[str, Any]) -> None:
        print(
            json.dumps(response, ensure_ascii=False, separators=(",", ":")),
            flush=True,
        )
