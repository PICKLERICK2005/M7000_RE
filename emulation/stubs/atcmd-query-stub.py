#!/usr/bin/env python3
"""Fail-closed synthetic /tmp/atcmd server for the M7000 sandbox.

This server never opens a device or forwards a command. Only exact, argument-free
read queries in RESPONSES receive synthetic data. Everything else receives ERROR
and is logged as a redacted verb plus a digest of the original bytes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import socket
from pathlib import Path


RESPONSES = {
    b"AT": (),
    b"AT+CPIN?": (b"+CPIN: READY",),
    b"AT+CFUN?": (b"+CFUN: 1",),
    b"AT+CSQ": (b"+CSQ: 99,99",),
    b"AT+COPS?": (b'+COPS: 0,2,"00000",7',),
    b"AT+CREG?": (b"+CREG: 1,0",),
    b"AT+CGREG?": (b"+CGREG: 1,0",),
    b"AT+CEREG?": (b"+CEREG: 1,0",),
    b"AT+CGACT?": (b"+CGACT: 1,0", b"+CGACT: 2,0"),
    b"AT+CGDCONT?": (),
    b"AT+CNUM": (),
}


def redacted_record(command: bytes, allowed: bool) -> dict[str, object]:
    verb = command.split(b"=", 1)[0].split(b"?", 1)[0][:48]
    return {
        "allowed": allowed,
        "verb": verb.decode("ascii", "replace"),
        "length": len(command),
        "sha256": hashlib.sha256(command).hexdigest(),
    }


def send_response(conn: socket.socket, lines: tuple[bytes, ...], ok: bool) -> None:
    body = b"\r\n".join(lines + ((b"OK" if ok else b"ERROR"),))
    conn.sendall(b"\r\n" + body + b"\r\n")


def serve(socket_path: Path, log_path: Path, once: bool) -> None:
    socket_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    if socket_path.exists() or socket_path.is_socket():
        socket_path.unlink()

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(socket_path))
    os.chmod(socket_path, 0o600)
    server.listen(1)
    try:
        while True:
            conn, _ = server.accept()
            with conn, log_path.open("a", encoding="utf-8") as log:
                pending = bytearray()
                while True:
                    chunk = conn.recv(4096)
                    if not chunk:
                        break
                    pending.extend(chunk)
                    while b"\r" in pending:
                        raw, _, remainder = pending.partition(b"\r")
                        pending[:] = remainder
                        command = bytes(raw)
                        allowed = command in RESPONSES
                        log.write(json.dumps(redacted_record(command, allowed)) + "\n")
                        log.flush()
                        send_response(conn, RESPONSES.get(command, ()), allowed)
            if once:
                break
    finally:
        server.close()
        if socket_path.exists() or socket_path.is_socket():
            socket_path.unlink()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket", required=True, type=Path)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    serve(args.socket.resolve(), args.log.resolve(), args.once)


if __name__ == "__main__":
    main()
