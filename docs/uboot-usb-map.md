# U-Boot USB Gadget Map

Baseline: M7000(EU) v3.2, `3.0.2 Build 241129 Rel.3n`

## Confirmed

The `OSLO` component is U-Boot 2014.01 built on 2024-11-29. It contains the
exact `2ECC:4E11` descriptor identity observed during powered-off USB
enumeration, along with `ASRMicro`, `Openwrt`, `ASRF001`, and `mv_udc` strings.
The observed configuration has one bulk IN endpoint (`0x81`) and one bulk OUT
endpoint (`0x02`), with interface class/subclass/protocol `FF/42/03`.

That interface tuple is the standard Fastboot USB interface tuple. The same
binary contains:

- `fastboot.c`, the `fastboot` command, and `android fastboot client application`
- `usb_gadget_connect` and `usb_gadget_disconnect` paths
- charger/VBUS detection and `check_sys_boot_or_pd`
- `vbus offline, return and boot to linux`
- flash/read/erase/write and image-download vocabulary

## Supported inference

The automatically exposed `2ECC:4E11` gadget is wired to U-Boot's Fastboot
transport rather than being an unrelated gadget beside dormant Fastboot code.
The exact descriptor tuple, descriptor strings, controller name, connection
path, and dispatcher all coexist in the same small U-Boot image.

This does **not** prove that a command is accepted during the short automatic
window, which command set is reachable, or that mutation commands lack further
policy checks. No Fastboot request was sent to the device.

## Boot decision boundary

Passive captures consistently show `Openwrt` disappearing after roughly 2.6
seconds. Static strings tie this interval to charger/VBUS and system-boot
selection. Normal shutdown while USB remains connected also produces Linux
disconnect followed by `NEZHAS` and then `Openwrt`; therefore the sequence is a
power-state/charging boot path, not only a first-attachment anomaly.

## USBPcap limitation

USBPcap 1.5.4.0 on the research host captured the stable Linux gadget but did
not retain either pre-userspace identity, even with a three-minute whole-root
capture. Windows PnP and USBTreeView continued to observe both identities.
Descriptor evidence therefore remains sourced from standard USBTreeView reads,
not USBPcap transaction records. Raw whole-root captures remain private.

