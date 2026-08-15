#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work=${M7000_EMU_WORK:-"$repo/emulation/work"}
rootfs=$work/runtime-rootfs
component=$work/components/00-SYSJ.bin
expected=5dfddb34e9db5d7be3a82878d4a58d888d62012ebd8e4fb4db957c0564c02af8

[ -f "$component" ] || { echo "runtime rootfs: component absent" >&2; exit 1; }
[ "$(sha256sum "$component" | awk '{print $1}')" = "$expected" ] || {
  echo "runtime rootfs: component hash mismatch" >&2; exit 1;
}
mountpoint -q "$rootfs" || {
  echo "runtime rootfs: expected private tmpfs mount absent" >&2; exit 1;
}

unsquashfs -no-progress -d "$rootfs" -ex dev/console ';' "$component" >/dev/null

for name in reboot poweroff halt flash_erase ubiformat ubiupdatevol nandwrite \
  mkfs mkfs.ext2 mkfs.ext3 mkfs.ext4 mkfs.ubifs mkfs.vfat jffs2reset \
  firstboot mtd; do
  stub=$repo/emulation/stubs/$name
  [ -f "$stub" ] || continue
  for target in /sbin/$name /usr/sbin/$name /bin/$name /usr/bin/$name; do
    if [ -e "$rootfs$target" ] || [ -L "$rootfs$target" ]; then
      rm -f "$rootfs$target"
      cp "$stub" "$rootfs$target"
      chmod 755 "$rootfs$target"
    fi
  done
done

cp "$work/build/mobile-containment.so" "$rootfs/usr/lib/mobile-containment.so"
test -x "$rootfs/usr/bin/mobile"
echo "prepared verified ephemeral runtime rootfs"
