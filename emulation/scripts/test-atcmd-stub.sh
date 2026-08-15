#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
python3 "$repo/emulation/scripts/test-atcmd-stub.py" --local
