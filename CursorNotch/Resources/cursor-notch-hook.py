#!/usr/bin/python3
"""Cursor user-hook relay. Reads hook JSON on stdin and forwards a small
event to Cursor Notch over a local Unix socket. Always exits 0 and prints
`{}` so Cursor is never blocked if the app is not running.
"""
from __future__ import annotations

import json
import os
import socket
import sys

SOCKET_PATH = os.path.expanduser(
    "~/Library/Application Support/CursorNotch/cursor-notch.sock"
)


def _first(payload: dict, *keys: str) -> str:
    for key in keys:
        value = payload.get(key)
        if isinstance(value, str) and value:
            return value
    return ""


def main() -> None:
    raw = sys.stdin.buffer.read()
    payload: dict = {}
    if raw:
        try:
            decoded = json.loads(raw.decode("utf-8"))
            if isinstance(decoded, dict):
                payload = decoded
        except Exception:
            payload = {}

    event = {
        "hook_event_name": _first(
            payload, "hook_event_name", "hookEventName"
        ),
        "conversation_id": _first(
            payload,
            "conversation_id",
            "conversationId",
            "session_id",
            "sessionId",
        ),
        "generation_id": _first(payload, "generation_id", "generationId"),
        "status": _first(payload, "status"),
    }

    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(0.4)
        sock.connect(SOCKET_PATH)
        sock.sendall((json.dumps(event, separators=(",", ":")) + "\n").encode())
        sock.close()
    except Exception:
        pass

    sys.stdout.write("{}\n")
    sys.stdout.flush()


if __name__ == "__main__":
    main()
