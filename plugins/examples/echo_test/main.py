import json
import sys


def main() -> int:
    raw_request = sys.stdin.read().strip()
    request = json.loads(raw_request) if raw_request else {}
    response = {
        "jsonrpc": "2.0",
        "id": request.get("id"),
        "result": {
            "handled": True,
            "method": request.get("method", ""),
            "params": request.get("params") or {},
            "message": "Hanabi echo test plugin is reachable.",
        },
    }
    print(json.dumps(response, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
