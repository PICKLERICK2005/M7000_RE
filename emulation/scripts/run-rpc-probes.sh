#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=${M7000_EMU_WORK:-"$repo/emulation/work"}
trace="$repo/emulation/traces/rpc-probes"
server="$work/overlays/tmp/tp_rpm_server.sock"
case "$work" in ""|/) echo "unsafe emulation work path: $work" >&2; exit 2;; esac

rm -rf "$work/overlays/cache" "$work/overlays/tmp" "$work/overlays/dev" "$trace"
mkdir -p "$work/overlays/cache" "$work/overlays/tmp" "$work/overlays/dev" "$trace"

guest_stack=0
if [ "${M7000_IPC_MODE:-none}" != "none" ]; then
  case "$M7000_IPC_MODE" in
    zero) guest_stack=1 ;;
    *) echo "invalid M7000_IPC_MODE: $M7000_IPC_MODE" >&2; exit 2 ;;
  esac
  M7000_EMU_WORK="$work" "$repo/emulation/setup/build-ipc-stub.sh"
  cp "$work/build/status-zero.so" "$work/rootfs/usr/lib/status-zero.so"
fi

if [ "$guest_stack" = 1 ]; then
  guest_command='LD_PRELOAD=/usr/lib/status-zero.so exec /usr/bin/rpmServer'
  M7000_TRACE_DIR="$trace" M7000_SYSCALL_TRACE=1 \
    setsid "$repo/emulation/scripts/run-arm.sh" /bin/sh -c "$guest_command" \
    >"$trace/console.log" 2>"$trace/syscalls.log" &
else
  M7000_TRACE_DIR="$trace" M7000_SYSCALL_TRACE=1 \
    setsid "$repo/emulation/scripts/run-arm.sh" /usr/bin/rpmServer \
    >"$trace/console.log" 2>"$trace/syscalls.log" &
fi
pid=$!

cleanup() {
  kill -TERM "-$pid" 2>/dev/null || true
  sleep 1
  kill -KILL "-$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

attempt=0
while [ ! -S "$server" ] && [ "$attempt" -lt 50 ]; do
  sleep 0.1
  attempt=$((attempt + 1))
done
[ -S "$server" ] || { echo "rpmServer socket did not appear" >&2; exit 1; }

for name in invalid-json empty-object status-0 log-5; do
  python3 "$repo/emulation/scripts/rpc-probe.py" "$name" "$server" "$work/overlays/tmp/probe-$name.sock" >>"$trace/results.jsonl"
done

echo "completed allowlisted local rpmServer probes"
