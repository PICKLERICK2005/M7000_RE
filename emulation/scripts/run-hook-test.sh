#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=${M7000_EMU_WORK:-"$repo/emulation/work"}
fixture_dir="$repo/emulation/fixtures/debug-hook"
case_name=${1:-all}
case "$work" in ""|/) echo "unsafe emulation work path: $work" >&2; exit 2;; esac

run_case() {
  name=$1
  misc="$work/overlays/misc"
  trace="$repo/emulation/traces/$name"
  rm -rf "$misc" "$work/overlays/cache" "$work/overlays/tmp" "$work/overlays/dev" "$trace"
  mkdir -p "$misc" "$work/overlays/cache" "$work/overlays/tmp" "$work/overlays/dev" "$trace"

  case "$name" in
    absent) ;;
    empty) cp "$fixture_dir/empty.sh" "$misc/m7000_debug.sh"; chmod 755 "$misc/m7000_debug.sh" ;;
    exit-0) cp "$fixture_dir/exit-0.sh" "$misc/m7000_debug.sh"; chmod 755 "$misc/m7000_debug.sh" ;;
    diagnostic) cp "$fixture_dir/diagnostic.sh" "$misc/m7000_debug.sh"; chmod 755 "$misc/m7000_debug.sh" ;;
    failing) cp "$fixture_dir/failing.sh" "$misc/m7000_debug.sh"; chmod 755 "$misc/m7000_debug.sh" ;;
    blocking) cp "$fixture_dir/blocking.sh" "$misc/m7000_debug.sh"; chmod 755 "$misc/m7000_debug.sh" ;;
    non-executable) cp "$fixture_dir/exit-0.sh" "$misc/m7000_debug.sh"; chmod 644 "$misc/m7000_debug.sh" ;;
    *) echo "unknown case: $name" >&2; exit 2 ;;
  esac

  set +e
  M7000_TRACE_DIR="$trace" "$repo/emulation/scripts/run-arm.sh" \
    /etc/rc.d/S99execute_debug_shell boot >"$trace/console.log" 2>"$trace/syscalls.log"
  rc=$?
  set -e
  printf '%s\n' "$rc" >"$trace/exit-status.txt"
  printf '%-16s exit=%s\n' "$name" "$rc"
}

if [ "$case_name" = all ]; then
  for item in absent empty exit-0 diagnostic failing blocking non-executable; do run_case "$item"; done
else
  run_case "$case_name"
fi
