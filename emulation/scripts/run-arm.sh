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
touch "$work/overlays/dev/null"
test -x "$work/stubs/reboot" || { echo "prepare rootfs/stubs first: $work" >&2; exit 2; }

trace_env=
[ "${M7000_SYSCALL_TRACE:-1}" = "0" ] || trace_env=QEMU_STRACE=1

# Word splitting is intentional for the optional single environment entry.
# shellcheck disable=SC2086
exec env -i $trace_env PROOT_NO_SECCOMP="${PROOT_NO_SECCOMP:-1}" \
  HOME=/ USER=root LOGNAME=root SHELL=/bin/sh \
  PATH=/sandbox-stubs:/usr/sbin:/usr/bin:/sbin:/bin TERM=dumb \
  proot -0 -q "$(command -v qemu-arm)" -r "$rootfs" -w / \
  -b "$work/overlays/misc:/misc" -b "$work/overlays/cache:/cache" \
  -b "$work/overlays/tmp:/tmp" -b "$work/overlays/dev:/dev" -b /dev/null:/dev/null \
  -b "$trace_dir:/traces" -b "$work/stubs:/sandbox-stubs" \
  "$@"
