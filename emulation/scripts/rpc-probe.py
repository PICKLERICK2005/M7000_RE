#!/usr/bin/env python3
"""Allowlisted local datagram probes for an emulated M7000 rpmServer."""

import argparse
import json
import os
import socket
from pathlib import Path

PAYLOADS = {
    "invalid-json": b"not-json",
    "empty-object": b"{}",
    "status-0": json.dumps({"module": "status", "action": 0}, separators=(",", ":")).encode(),
    "log-5": json.dumps({"module": "log", "action": 5}, separators=(",", ":")).encode(),
}

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("case", choices=PAYLOADS)
parser.add_argument("server", type=Path, help="physical path backing /tmp/tp_rpm_server.sock")
parser.add_argument("client", type=Path, help="disposable client socket path")
args = parser.parse_args()

args.client.unlink(missing_ok=True)
result = {"case": args.case, "request_hex": PAYLOADS[args.case].hex(), "response": None}
sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
try:
    sock.bind(os.fspath(args.client))
    timeout = {"status-0": 15.0, "log-5": 5.0}.get(args.case, 1.5)
    sock.settimeout(timeout)
    sock.sendto(PAYLOADS[args.case], os.fspath(args.server))
    try:
        data = sock.recv(65535)
        result["response"] = {"size": len(data), "hex": data.hex(), "utf8": data.decode("utf-8", "replace")}
    except TimeoutError:
        result["response"] = {"timeout": True}
finally:
    sock.close()
    args.client.unlink(missing_ok=True)

print(json.dumps(result, sort_keys=True))
