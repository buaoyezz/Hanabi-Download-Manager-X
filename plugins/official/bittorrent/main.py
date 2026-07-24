from __future__ import annotations

from functools import wraps
from typing import Any, Callable

from bittorrent_plugin import BitTorrentService, PluginFailure
from hanabi_plugin import HanabiPlugin, JsonRpcError, PluginContext


plugin = HanabiPlugin()
service = BitTorrentService()


def expose(handler: Callable[[dict[str, Any], PluginContext], dict[str, Any]]):
    @wraps(handler)
    def wrapped(params: dict[str, Any], context: PluginContext) -> dict[str, Any]:
        try:
            return handler(params, context)
        except PluginFailure as error:
            raise JsonRpcError(error.code, error.message, error.data) from error

    return wrapped


@plugin.method("hanabi.download.create")
@expose
def create(params: dict[str, Any], context: PluginContext) -> dict[str, Any]:
    return service.create(params, context.plugin_id)


@plugin.method("hanabi.download.status")
@expose
def status(params: dict[str, Any], context: PluginContext) -> dict[str, Any]:
    return service.status(params)


@plugin.method("hanabi.download.pause")
@expose
def pause(params: dict[str, Any], context: PluginContext) -> dict[str, Any]:
    return service.pause(params)


@plugin.method("hanabi.download.resume")
@expose
def resume(params: dict[str, Any], context: PluginContext) -> dict[str, Any]:
    return service.resume(params)


@plugin.method("hanabi.download.remove")
@expose
def remove(params: dict[str, Any], context: PluginContext) -> dict[str, Any]:
    return service.remove(params)


if __name__ == "__main__":
    raise SystemExit(plugin.run())
