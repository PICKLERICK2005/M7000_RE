# Early-Boot USB Ownership and Timeline

Date: 2026-08-15

Target: TP-Link M7000(EU) V3.20, firmware `3.0.2 Build 241129 Rel.3n`

## Scope

This note correlates passive USB enumeration with every available component of
the exact official firmware image. No USB endpoint was opened, no undocumented
command was sent, and no boot, recovery, diagnostic, flash, or factory mode was
activated.

One timing correction is important: the measured transient occurred when USB
was connected to the powered-off router. Time zero below is the first USB
arrival observed by the 100 ms Windows PnP watcher, not a precisely instrumented
electrical power-on edge.

## Measured timeline

| Relative time | USB state | Evidence |
| --- | --- | --- |
| `t=0` | `2ECC:3001`, revision `0000`, product `NEZHAS`, vendor class `FF/FF/FF` | Arrival captured by Windows PnP |
| `t=+1.81-2.33 s` | `NEZHAS` disconnects | Five-cycle mean lifetime: 2.001 s |
| `t=+3.20-3.81 s` | `2ECC:4E11`, revision `0321`, product `Openwrt`, vendor class `FF/42/03` | Appears after a 1.356-1.702 s gap |
| `t=+5.74-6.25 s` | `Openwrt` disconnects | Five-cycle mean lifetime: 2.624 s |
| after final disconnect | No USB device remains; router settles into charging mode | Windows inventory and operator LED observation |
| normal power-on from charging | Router visibly completes normal boot; later `3625:0006` appears | Repeated 150 s PnP capture |
| stable operation | `Quectel` / `M7000`, USB 2.1 at High-Speed, two-interface RNDIS function | USBTreeView descriptor report |

The stable device contains one configuration with RNDIS control interface
`E0/01/03` and CDC data interface `0A/00/00`. Its endpoints are interrupt IN
`0x82`, bulk IN `0x81`, and bulk OUT `0x01`.

### Five-cycle repeatability capture

Five cold connects reproduced the same ordered sequence without exception. The
figures below are measured from Windows PnP arrival/removal timestamps; polling
and host enumeration latency mean they should not be interpreted as electrical
edge timing.

| Cycle | `NEZHAS` present | Inter-stage gap | `Openwrt` present |
| --- | ---: | ---: | ---: |
| 1 | 1.825 s | 1.371 s | 2.542 s |
| 2 | 2.326 s | 1.484 s | 2.341 s |
| 3 | 2.203 s | 1.356 s | 2.674 s |
| 4 | 1.835 s | 1.702 s | 2.710 s |
| 5 | 1.815 s | 1.487 s | 2.855 s |
| **Mean** | **2.001 s** | **1.480 s** | **2.624 s** |
| **Range** | **1.815-2.326 s** | **1.356-1.702 s** | **2.341-2.855 s** |

Standard descriptor reads captured both transient configurations:

- `NEZHAS`: USB 2.0 High-Speed; device and sole interface `FF/FF/FF`; one
  32-byte configuration; bulk IN `0x81` and bulk OUT `0x02`, 512-byte packets;
  self-powered; 10 mA requested.
- `Openwrt`: USB 2.0 High-Speed; device class `00/00/00`, sole interface
  `FF/42/03`; one 32-byte configuration; bulk IN `0x81` and bulk OUT `0x02`,
  512-byte packets; bus-powered; 256 mA requested.

Serial-like descriptor values remain intentionally omitted.

Repeating the transition from charging to normal power-on did not reproduce
either `2ECC` identity. This is consistent with the device already residing in
the loader's charging branch and continuing directly toward Linux when the
normal power-on condition occurs.

Normal shutdown while USB remained connected did reproduce the loader sequence:
Linux `3625:0006` disconnected, then `NEZHAS` appeared, then `Openwrt`, followed
by charging. This confirms that the two stages belong to the charging/power-state
path rather than only initial cable insertion.

USBPcap captured stable Linux enumeration but did not retain either early
identity, even during an approved three-minute whole-root capture. Windows PnP
and USBTreeView continued to observe both. This is treated as a host-tool
limitation, not evidence that the early stages lack USB transactions.

## Firmware component map

The `Marvell_FBF` header contains a ten-entry table. All ten entries carry packed,
8 KiB-aligned payloads in the official update. Four-character IDs are stored in
file byte order; their numeric/little-endian reading is shown separately.

| Raw ID | Numeric ID | Bundle offset | Size | Classification and evidence |
| --- | --- | --- | --- | --- |
| `JSYS` | `SYSJ` | `0x2000` | 10,806,548 | SquashFS root filesystem |
| `GMIZ` | `ZIMG` | `0xA52000` | 3,928,872 | Linux zImage; contains appended DTBs naming `mv-udc` at `udc@d4208000` |
| `OLSO` | `OSLO` | `0xE12000` | 459,168 | U-Boot 2014.01, built 2024-11-29; owns early USB gadget/fastboot code |
| `IBFR` | `RFBI` | `0xE84000` | 32,768 | Quectel/ASR RF parameter or RF firmware material |
| `IBRG` | `GRBI` | `0xE8C000` | 2,621,440 | ASR Falcon LTE Layer-1/baseband image |
| `IBRA` | `ARBI` | `0x110C000` | 7,707,288 | CP/RTOS image; load table, OS tasks, cellular stack |
| `1MIT` | `TIM1` | `0x1866000` | 2,436 | Image-chain metadata naming the preceding FBF components and release |
| `VTOF` | `FOTV` | `0x1868000` | 51 | EC200A-ELAA modem build/version string |
| `IASR` | `RSAI` | `0x186A000` | 256 | Signature-sized high-entropy material; verification relationship unresolved |
| `I5DM` | `MD5I` | `0x186C000` | 16 | Digest-sized material; covered range unresolved |

All ten entries have packed payloads. Earlier work misread a component attribute
as the payload-size field and incorrectly classified the final three entries as
empty. Their names and sizes support version, RSA, and MD5 roles, but signed or
hashed ranges and enforcement policy remain unresolved.

An earlier signature scan reported an ELF marker at bundle offset `0xE6A7DB`.
Context shows it is embedded in U-Boot ramdump error text, not the start of an
ELF component.

The package exposes U-Boot, kernel, rootfs, and substantial CP/RF firmware, but
does not expose an identifiable BootROM image or a separate first-stage loader.
BootROM is normally immutable, and another flash-resident stage could also be
excluded from this field-update package. The current evidence cannot distinguish
those two possibilities.

## Personality ownership

### `2ECC:3001` / `NEZHAS`

Best classification: **pre-U-Boot ASR stage; exact owner unresolved**.

Evidence:

- It is the first captured identity and disappears before the U-Boot identity.
- Neither the exact little-endian `2ECC:3001` value nor ASCII/UTF-16 `NEZHAS`
  occurs anywhere in the 25.6 MB official update.
- The same absence holds in the preserved predecessor and successor images.
- Windows saw no driver, service, interface class binding, or persistent node.
- Generic external device-ID material associates `2ECC:3001` with ASR/Quectel
  download tooling, but this is supporting context rather than device proof.

The most plausible owners are the ASR SoC BootROM or an earlier flash-resident
loader omitted from the FBF update. Calling it definitively BootROM, recovery, or
download mode would exceed the evidence.

### `2ECC:4E11` / `Openwrt`

Best classification: **U-Boot USB gadget**, high confidence.

Evidence inside the `OSLO` component:

- exact little-endian VID/PID `2ECC:4E11` at bundle offset `0xE7846A`
- descriptor strings `ASRMicro`, `Openwrt`, `ASRF001`, and `mv_udc`
- `U-Boot 2014.01 (Nov 29 2024 - 04:01:11)`
- fastboot command and client strings
- `usb_gadget_connect`, `usb enum done`, USB receive, and gadget-disconnect paths
- `vbus offline, return and boot to linux`
- charger detection and `check_sys_boot_or_pd`
- `Boot up, turn on all LED!`, matching the observed all-LED interval
- a U-Boot charging-only path and normal kernel-start paths

The exact VID/PID constant occurs at the same component-relative location in
official 3.0.1, 3.0.2, and 3.0.4 images; each release contains a newly dated
U-Boot build. No observed transient descriptor match occurs in the CP firmware
regions.

The approximately 2.8-second lifetime therefore represents a U-Boot gadget
window or U-Boot-controlled charger/boot decision boundary. Static strings show
that fastboot support exists, but passive enumeration does not prove that this
particular automatic window accepts fastboot commands.

### `3625:0006` / `Quectel M7000`

Best classification: **Linux userspace-configured RNDIS gadget**, high confidence.

The normal `PRODMODE=0` path in `/etc/telinit` starts `/sbin/usb_init`. That
script reads TP-Link product configuration and writes:

- VID/PID `3625:0006`
- revision `0318`
- manufacturer `Quectel`
- product `M7000`
- RNDIS-only normal functions

It enables the gadget through `/sys/class/android_usb/android0`. The kernel zImage
contains appended DTB evidence for the Marvell UDC, while `usb_daemon` manages
the resulting `rndis0`/`usbnet0` state later in userspace. This accounts for the
normal identity appearing after visible boot rather than at initial VBUS.

## Reconstructed boot chain

```text
USB VBUS reaches powered-off device
  -> pre-U-Boot ASR personality: 2ECC:3001 / NEZHAS
  -> disconnect and approximately 1.5 s transition
  -> U-Boot OSLO USB gadget: 2ECC:4E11 / Openwrt
  -> U-Boot charger/boot decision
       -> no normal power-on: gadget disconnect, charging-only state
       -> normal power-on: validate/load ZIMG, start Linux
  -> kernel initializes Marvell UDC
  -> OpenWrt telinit selects normal user mode
  -> /sbin/usb_init configures 3625:0006 / M7000 RNDIS
```

This assigns the second and stable personalities to specific layers. It narrows
the first personality to a pre-U-Boot ASR stage but cannot yet distinguish ROM
from an omitted primary loader.

## Dormant recovery and factory functionality

U-Boot contains real fastboot infrastructure, flash read/erase/write commands,
`bootsp` support for a special application, A/B and ASR flags, kernel hash
verification, and a `PINTEST OR FASTBOOT OR DEBUG` decision path involving GPIO.
These are sensitive factory/recovery capabilities. Their presence does not prove
that the automatic 2.8-second gadget window exposes every command.

Linux contains separate dormant USB modes:

- production mode can expose RNDIS, Marvell diagnostic, ACM, modem, and ADB
- ramdump mode uses `2C7C:6005` with RNDIS, ACM, Marvell diagnostic/debug, and ADB
- normal burned-device user mode deliberately reduces the gadget to RNDIS

CATStudio logging is a later Linux mechanism: `/cache/enable_diag` is created,
diagnostic configuration is swapped, and the device reboots. No `CATStudio` or
`/cache/enable_diag` selector was found in U-Boot. Likewise,
`/misc/m7000_debug.sh` is a late userspace hook and is unrelated to the captured
pre-userspace personalities.

No live recovery, production, ramdump, fastboot, CATStudio, or GPIO-triggered
mode was activated.

## Confirmed facts, inferences, and gaps

Confirmed:

- five powered-off cold connects produced the same two sequential vendor
  identities before charging
- U-Boot contains the exact `2ECC:4E11` value and matching `Openwrt` descriptor
- Linux userspace configures the exact stable `3625:0006` RNDIS identity
- the FBF includes U-Boot, Linux, rootfs, and CP/RF components but no identified
  BootROM image

Strong inference:

- the `Openwrt` identity is U-Boot's gadget
- its disconnect marks U-Boot's charger/boot decision or Linux handoff boundary

Working hypothesis:

- `NEZHAS` is an immutable ASR BootROM download personality or an omitted
  primary loader

Unresolved:

- whether `2ECC:3001` is ROM or flash-resident first stage
- whether U-Boot's automatic gadget window accepts fastboot or only enumeration
- the exact GPIO/flag conditions for persistent factory and recovery modes
- precise time from electrical VBUS and power-button edges to each stage

## Safest highest-value next experiment

The five-cycle descriptor-only experiment is complete. The remaining ambiguity
is the first stage's exact owner. The safest next measurement is a passive USB
bus capture synchronized to the VBUS edge and, separately, the power-button/LED
edge. Request only standard descriptors and send no class/vendor payloads. This
would replace host-PnP timing with bus-level timing and show whether the first
identity is active immediately after VBUS, strengthening or weakening the
BootROM hypothesis without interacting with its protocol.
