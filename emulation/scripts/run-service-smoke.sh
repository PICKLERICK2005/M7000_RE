#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=${M7000_EMU_WORK:-"$repo/emulation/work"}
name=${1:-}
duration=${2:-5}
shift 2 2>/dev/null || true

[ -n "$name" ] && [ "$#" -gt 0 ] || { echo "usage: $0 NAME SECONDS /guest/program [args...]" >&2; exit 2; }
case "$work" in ""|/) echo "unsafe emulation work path: $work" >&2; exit 2;; esac
command -v setsid >/dev/null

trace="$repo/emulation/traces/$name"
rm -rf "$work/overlays/cache" "$work/overlays/tmp" "$work/overlays/dev" "$trace"
mkdir -p "$work/overlays/cache" "$work/overlays/tmp" "$work/overlays/dev" "$trace"

M7000_TRACE_DIR="$trace" M7000_SYSCALL_TRACE="${M7000_SYSCALL_TRACE:-1}" \
  setsid "$repo/emulation/scripts/run-arm.sh" "$@" \
  >"$trace/console.log" 2>"$trace/syscalls.log" &
pid=$!
printf '%s\n' "$pid" >"$trace/host-session-pid.txt"
sleep "$duration"
find "$work/overlays/tmp" -maxdepth 2 -ls >"$trace/tmp-listing.txt" 2>&1 || true

kill -TERM "-$pid" 2>/dev/null || true
sleep 1
kill -KILL "-$pid" 2>/dev/null || true
set +e
wait "$pid"
rc=$?
set -e
printf '%s\n' "$rc" >"$trace/exit-status.txt"
printf '%s session=%s exit=%s\n' "$name" "$pid" "$rc"
