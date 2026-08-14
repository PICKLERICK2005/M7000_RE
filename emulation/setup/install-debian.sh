#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "run as root: sudo $0" >&2
  exit 2
fi

apt-get update
apt-get install -y nodejs proot qemu-user squashfs-tools
command -v qemu-arm >/dev/null
command -v proot >/dev/null
command -v unsquashfs >/dev/null
