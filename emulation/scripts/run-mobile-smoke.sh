#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=${M7000_EMU_WORK:-"$repo/emulation/work"}
trace=$repo/emulation/traces/mobile-startup
duration=${M7000_MOBILE_DURATION:-5}

case "$work" in "$repo"/emulation/work|"$repo"/emulation/work/*) :;;
  *) echo "mobile smoke: work path must be repo-local" >&2; exit 2;;
esac

if [ "${M7000_PRIVATE_MOUNT_NS:-0}" != 1 ]; then
  mkdir -p "$work/overlays/tmp" "$work/runtime-rootfs"
  exec unshare -Urnm env M7000_PRIVATE_MOUNT_NS=1 sh "$0"
fi

# DrvFS does not implement pathname Unix sockets. Use an ephemeral tmpfs at the
# repo-local overlay mountpoint inside this private mount namespace only.
mount -t tmpfs -o mode=700,size=4m tmpfs "$work/overlays/tmp"
mount -t tmpfs -o mode=700,size=64m tmpfs "$work/runtime-rootfs"
mkdir -p "$work/overlays/cache" "$work/overlays/dev" "$trace"
rm -f "$trace"/*

"$repo/emulation/scripts/prepare-runtime-rootfs.sh" >"$trace/runtime-rootfs.txt"
M7000_ROOTFS="$work/runtime-rootfs" \
  "$repo/emulation/scripts/preflight-mobile.sh" >"$trace/preflight.txt"

at_pid=
mobile_pid=
cleanup() {
  if [ -n "$mobile_pid" ]; then
    kill -TERM "-$mobile_pid" 2>/dev/null || true
    sleep 1
    kill -KILL "-$mobile_pid" 2>/dev/null || true
    wait "$mobile_pid" 2>/dev/null || true
  fi
  if [ -n "$at_pid" ]; then
    kill "$at_pid" 2>/dev/null || true
    wait "$at_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

python3 "$repo/emulation/stubs/atcmd-query-stub.py" \
  --socket "$work/overlays/tmp/atcmd" --log "$trace/atcmd.jsonl" &
at_pid=$!
i=0
while [ ! -S "$work/overlays/tmp/atcmd" ]; do
  i=$((i + 1))
  [ "$i" -lt 50 ] || { echo "mobile smoke: AT stub did not start" >&2; exit 1; }
  sleep 0.05
done

guest='LD_PRELOAD=/usr/lib/mobile-containment.so exec /usr/bin/mobile'
M7000_ROOTFS="$work/runtime-rootfs" M7000_TRACE_DIR="$trace" M7000_SYSCALL_TRACE=1 \
  setsid "$repo/emulation/scripts/run-arm.sh" /bin/sh -c "$guest" \
  >"$trace/console.log" 2>"$trace/syscalls.log" &
mobile_pid=$!
printf '%s\n' "$mobile_pid" >"$trace/session-pid.txt"
sleep "$duration"
find "$work/overlays/tmp" -maxdepth 2 -printf '%y %f\n' | sort \
  >"$trace/tmp-listing.txt"

kill -TERM "-$mobile_pid" 2>/dev/null || true
sleep 1
kill -KILL "-$mobile_pid" 2>/dev/null || true
set +e
wait "$mobile_pid"
rc=$?
set -e
mobile_pid=
printf '%s\n' "$rc" >"$trace/exit-status.txt"
echo "mobile smoke complete: exit=$rc trace=$trace"
