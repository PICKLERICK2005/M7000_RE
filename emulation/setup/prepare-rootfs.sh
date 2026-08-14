#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
image=${1:-}
work=${M7000_EMU_WORK:-"$repo/emulation/work"}
expected_image=a1be63a6bc8d9a6ed730b294187310b405bd686a5bf59c7e7b4ed9e8a7db56d7
expected_rootfs=5dfddb34e9db5d7be3a82878d4a58d888d62012ebd8e4fb4db957c0564c02af8

[ -n "$image" ] || { echo "usage: $0 UPDATE.BIN" >&2; exit 2; }
case "$work" in ""|/) echo "unsafe emulation work path: $work" >&2; exit 2;; esac
command -v node >/dev/null
command -v unsquashfs >/dev/null
mkdir -p "$work/components"
node "$repo/tools/m7000-fw.mjs" extract "$image" "$work/components"

actual_image=$(sha256sum "$image" | awk '{print $1}')
actual_rootfs=$(sha256sum "$work/components/rootfs.squashfs" | awk '{print $1}')
[ "$actual_image" = "$expected_image" ] || { echo "wrong update.bin hash: $actual_image" >&2; exit 1; }
[ "$actual_rootfs" = "$expected_rootfs" ] || { echo "wrong rootfs hash: $actual_rootfs" >&2; exit 1; }

rm -rf "$work/rootfs.new"
unsquashfs -no-progress -d "$work/rootfs.new" "$work/components/rootfs.squashfs"
rm -rf "$work/rootfs"
mv "$work/rootfs.new" "$work/rootfs"

test -x "$work/rootfs/bin/busybox"
test -x "$work/rootfs/etc/rc.d/S99execute_debug_shell"
printf 'prepared exact 3.0.2 rootfs at %s\n' "$work/rootfs"
