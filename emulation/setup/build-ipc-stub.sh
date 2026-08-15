#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=${M7000_EMU_WORK:-"$repo/emulation/work"}
mkdir -p "$work/build"
command -v arm-linux-gnueabihf-gcc >/dev/null || {
  echo "missing arm-linux-gnueabihf-gcc" >&2
  exit 2
}
cc=arm-linux-gnueabihf-gcc
"$cc" -Os -nostdlib -fno-builtin -fno-stack-protector -fPIE -pie \
  -Wall -Wextra -Werror -Wl,-e,_start \
  -Wl,--dynamic-linker=/lib/ld-musl-armhf.so.1 \
  "$repo/emulation/stubs/ipc-zero.c" -o "$work/build/ipc-zero-arm"

"$cc" -Os -nostdlib -fno-builtin -fno-stack-protector -fPIC -shared \
  -Wall -Wextra -Werror "$repo/emulation/stubs/status-zero.c" \
  -o "$work/build/status-zero.so"
