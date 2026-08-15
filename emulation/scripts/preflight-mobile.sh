#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=${M7000_EMU_WORK:-"$repo/emulation/work"}
rootfs=${M7000_ROOTFS:-$work/rootfs}
image=$repo/firmware/work/inner/3.0.2/update.bin
expected_image=a1be63a6bc8d9a6ed730b294187310b405bd686a5bf59c7e7b4ed9e8a7db56d7
expected_rootfs=5dfddb34e9db5d7be3a82878d4a58d888d62012ebd8e4fb4db957c0564c02af8

fail() { echo "mobile preflight: FAIL: $*" >&2; exit 1; }
pass() { echo "mobile preflight: $*"; }

case "$work" in "$repo"/emulation/work|"$repo"/emulation/work/*) :;;
  *) fail "work path is not beneath repo-local emulation/work";;
esac
case "$rootfs" in "$work"/rootfs|"$work"/runtime-rootfs) :;;
  *) fail "rootfs is not an approved repo-local path";;
esac
[ "$(sha256sum "$image" | awk '{print $1}')" = "$expected_image" ] || fail "firmware hash mismatch"
[ -f "$work/components/00-SYSJ.bin" ] || fail "verified rootfs component absent"
[ "$(sha256sum "$work/components/00-SYSJ.bin" | awk '{print $1}')" = "$expected_rootfs" ] || fail "rootfs hash mismatch"
[ -x "$rootfs/usr/bin/mobile" ] || fail "mobile binary absent"
[ -f "$work/build/mobile-containment.so" ] || fail "containment interposer absent"
[ -f "$repo/emulation/stubs/atcmd-query-stub.py" ] || fail "AT stub absent"
find "$rootfs/dev" -type b -o -type c 2>/dev/null | grep -q . &&
  fail "device node present in extracted rootfs"

seen=' '
resolved=0
resolve_tree() {
  local object=$1 parent=$2 needed library found directory
  needed=$(arm-linux-gnueabihf-readelf -d "$object" 2>/dev/null |
    sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
  for library in $needed; do
    case "$seen" in *" $library "*) continue;; esac
    found=
    for directory in lib usr/lib; do
      [ -e "$rootfs/$directory/$library" ] && found=$rootfs/$directory/$library
    done
    [ -n "$found" ] || fail "unresolved dependency: $library (required by $parent)"
    seen="$seen$library "
    resolved=$((resolved + 1))
    printf 'dependency\t%s\t%s\t%s\n' "$parent" "$library" "${found#"$rootfs"/}"
    resolve_tree "$found" "$library"
  done
}
resolve_tree "$rootfs/usr/bin/mobile" mobile
[ "$resolved" -gt 0 ] || fail "no dynamic dependencies recovered"

exports=$(arm-linux-gnueabihf-nm -D --defined-only "$work/build/mobile-containment.so" |
  awk '{print $3}')
for symbol in socket connect sendto open syscall system unlink remove \
  send_wan_ipv4_connect_msg send_wan_ipv4_disconnect_msg \
  send_wan_ipv6_connect_msg send_wan_ipv6_disconnect_msg send_set_wan_mtu_msg \
  wm_connect wm_disconnect wm_lte_wifi_coex_notify; do
  echo "$exports" | grep -qx "$symbol" || fail "missing intercept: $symbol"
done

[ ! -e "$rootfs/usr/bin/nvm_switch.sh" ] || grep -q 'system-denied' "$repo/emulation/stubs/mobile-containment.c" || fail "NVM switch is not gated"
find "$work/overlays/dev" -mindepth 1 ! -type f -print -quit 2>/dev/null |
  grep -q . && fail "non-regular synthetic device entry present"
for forbidden in ttym modem acipc smd mtd ubi; do
  find "$work/overlays/dev" -iname "*$forbidden*" -print -quit 2>/dev/null |
    grep -q . && fail "forbidden device entry present: $forbidden"
done

pass "PASS (exact image/rootfs, dependencies resolved, intercepts complete, synthetic devices empty)"
