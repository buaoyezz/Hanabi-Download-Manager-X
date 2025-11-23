import asyncio
import inspect

class EventBus:
    def __init__(self):
        self._handlers = {}

    def subscribe(self, event, handler):
        self._handlers.setdefault(event, []).append(handler)

    def unsubscribe(self, event, handler):
        if event in self._handlers:
            try:
                self._handlers[event].remove(handler)
            except ValueError:
                pass

    def publish(self, event, payload):
        handlers = list(self._handlers.get(event, []))
        try:
            loop = asyncio.get_running_loop()
            for h in handlers:
                if inspect.iscoroutinefunction(h):
                    loop.create_task(h(payload))
                else:
                    h(payload)
        except RuntimeError:
            for h in handlers:
                h(payload)

_singleton = None

def get_event_bus():
    global _singleton
    if _singleton is None:
        _singleton = EventBus()
    return _singleton