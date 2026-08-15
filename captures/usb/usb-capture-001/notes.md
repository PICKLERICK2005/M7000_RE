# USB Capture 001 Notes

Target: TP-Link M7000(EU) V3.20

Firmware: `3.0.2 Build 241129 Rel.3n`

Host: Windows laptop

Descriptor tool: USBTreeView 4.7.2 x64 from the publisher's official site;
archive SHA-256 `2E2E44EEED022670043967820FBEA91A8F13ECA6F5BA4F49B4394F5A79B91261`.

## Safety boundary

Passive Windows enumeration only. Do not open discovered ports, send USB
payloads or control transfers, change driver bindings, enter a special boot
mode, authenticate to the web UI, or write to the router.

## State observations

### State A — USB disconnected

- No present COM-port or modem-class devices.
- Existing USB and network devices were retained as the comparison baseline.

### State B — router off, then USB connected

- Windows played two USB sounds.
- All router LEDs illuminated briefly, after which the router entered charging
  mode without a normal boot.
- No new USB, COM, modem, or network device remained present after the device
  settled into charging mode.
- A repeat with USBTreeView open and a 100 ms PnP watcher captured two transient
  vendor-specific identities:
  1. `2ECC:3001`, `NEZHAS`, `FF/FF/FF`, present for about 1.7 seconds.
  2. `2ECC:4E11`, `Openwrt`, `FF/42/03`, present for about 2.8 seconds.
- The first disappeared about 1.5 seconds before the second appeared. Neither
  received a Windows driver, service, or class binding.
- No endpoint was opened and no payload was sent. Their functions remain
  unclassified.

### State C — router powered on with USB connected

- The router completed a normal boot while USB remained connected.
- The operator reported that normal boot visibly completed before the host-side
  USB interface was noticed.
- A USB composite `M7000` device appeared later, exposing an RNDIS-compatible
  network interface.
- The two-minute PnP watch observed no COM, modem, storage, or additional
  vendor-specific interface.
- Windows automatically performed DHCP on the new adapter. No manual traffic,
  browsing, ping, port access, or web authentication was performed.
- The operator was unsure whether Windows played a further connection sound at
  interface appearance.
- USBTreeView identified USB 2.1 descriptors, a High-Speed 480 Mbit/s
  connection, one configuration, two interfaces, and three non-control
  endpoints. The device advertises SuperSpeed capability but connected at
  High-Speed in this setup.
- Repeating the charging-to-powered-on transition produced only the normal
  `3625:0006` RNDIS composite after boot; the transient identities did not
  reappear during this transition.

## Offline correlation

The exact `3.0.2` firmware image contains the adjacent strings `ASRMicro`,
`Openwrt`, `ASRF001`, `mv_udc`, endpoint names, and charger-type names. This
associates the `Openwrt` identity with code shipped in the exact firmware, but
does not establish what commands the interface accepts.

External device-ID material associates `2ECC:3001` with ASR/Quectel download
tooling. Because that evidence is generic and no protocol interaction occurred,
an early download/ROM personality remains a hypothesis rather than a finding.

### State D — connect USB after normal boot

Not performed. States B and C already distinguish charging-only settled behavior
from the powered-on RNDIS function, so another physical cycle was not justified.
