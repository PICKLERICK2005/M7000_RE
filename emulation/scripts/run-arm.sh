#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=${M7000_EMU_WORK:-"$repo/emulation/work"}
rootfs=${M7000_ROOTFS:-"$work/rootfs"}
trace_dir=${M7000_TRACE_DIR:-"$repo/emulation/traces/manual"}

[ "$#" -gt 0 ] || { echo "usage: $0 /guest/program [args...]" >&2; exit 2; }
case "$work" in ""|/) echo "unsafe emulation work path: $work" >&2; exit 2;; esac
for tool in proot qemu-arm; do command -v "$tool" >/dev/null || { echo "missing $tool" >&2; exit 2; }; done
test -x "$rootfs/bin/busybox" || { echo "prepare rootfs first: $rootfs" >&2; exit 2; }

mkdir -p "$work/overlays/misc" "$work/overlays/cache" "$work/overlays/tmp" "$work/overlays/dev" "$trace_dir"

stub_binds=
for name in reboot poweroff halt flash_erase ubiformat ubiupdatevol nandwrite mkfs mkfs.ext2 mkfs.ext3 mkfs.ext4 mkfs.ubifs mkfs.vfat jffs2reset firstboot mtd; do
  stub="$repo/emulation/stubs/$name"
  [ -f "$stub" ] || continue
  for target in "/sbin/$name" "/usr/sbin/$name" "/bin/$name" "/usr/bin/$name"; do
    [ -e "$rootfs$target" ] && stub_binds="$stub_binds -b $stub:$target"
  done
done

# Word splitting is intentional for the generated, repository-controlled bind list.
# shellcheck disable=SC2086
exec env -i QEMU_STRACE="${QEMU_STRACE:-1}" \
  proot -0 -q "$(command -v qemu-arm)" -r "$rootfs" -w / \
  -b "$work/overlays/misc:/misc" -b "$work/overlays/cache:/cache" \
  -b "$work/overlays/tmp:/tmp" -b "$work/overlays/dev:/dev" \
  -b "$trace_dir:/traces" -b "$repo/emulation/stubs:/sandbox-stubs" \
  $stub_binds \
  /usr/bin/env -i HOME=/ USER=root LOGNAME=root SHELL=/bin/sh \
  PATH=/sandbox-stubs:/usr/sbin:/usr/bin:/sbin:/bin TERM=dumb "$@"
