#!/usr/bin/env python3
"""Self-test for the query-only AT stub; never uses the firmware daemon."""

from __future__ import annotations

import argparse
import socket
from pathlib import Path


def transact(path: Path, command: bytes) -> bytes:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.connect(str(path))
    try:
        client.sendall(command + b"\r")
        return client.recv(4096)
    finally:
        client.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("socket", type=Path)
    args = parser.parse_args()
    allowed = transact(args.socket, b"AT+CSQ")
    rejected = transact(args.socket, b'AT+CFUN=0')
    assert allowed == b"\r\n+CSQ: 99,99\r\nOK\r\n", allowed
    assert rejected == b"\r\nERROR\r\n", rejected
    print("AT stub self-test passed")


if __name__ == "__main__":
    main()
