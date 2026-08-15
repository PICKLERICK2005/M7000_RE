#!/usr/bin/env python3
"""Self-test for the query-only AT stub; never uses the firmware daemon."""

from __future__ import annotations

import argparse
import importlib.util
import socket
import threading
import time
from pathlib import Path


def transact(path: Path, commands: tuple[bytes, ...]) -> tuple[bytes, ...]:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(str(path))
    try:
        replies = []
        for command in commands:
            client.sendall(command + b"\r")
            replies.append(client.recv(4096))
        return tuple(replies)
    finally:
        client.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("socket", nargs="?", type=Path)
    parser.add_argument("--local", action="store_true",
                        help="start the stub inside the repo's ignored work area")
    args = parser.parse_args()
    thread = None
    if args.local:
        repo = Path(__file__).resolve().parents[2]
        work = repo / "emulation" / "work" / "atcmd-stub-test"
        work.mkdir(parents=True, exist_ok=True)
        path = work / "at.sock"
        log = work / "at.jsonl"
        log.unlink(missing_ok=True)
        spec = importlib.util.spec_from_file_location(
            "atcmd_query_stub", repo / "emulation" / "stubs" / "atcmd-query-stub.py")
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        thread = threading.Thread(target=module.serve, args=(path, log, True))
        thread.start()
        for _ in range(50):
            if path.exists():
                break
            time.sleep(0.02)
        else:
            raise RuntimeError("AT stub did not create its repo-local socket")
    else:
        if args.socket is None:
            parser.error("socket is required unless --local is used")
        path = args.socket
        log = None

    allowed, rejected = transact(path, (b"AT+CSQ", b"AT+CFUN=0"))
    assert allowed == b"\r\n+CSQ: 99,99\r\nOK\r\n", allowed
    assert rejected == b"\r\nERROR\r\n", rejected
    if thread:
        thread.join(timeout=2)
        assert not thread.is_alive()
        text = log.read_text(encoding="utf-8")
        assert text.count('"allowed": true') == 1
        assert text.count('"allowed": false') == 1
        assert "CFUN=0" not in text
    print("AT stub self-test passed")


if __name__ == "__main__":
    main()
