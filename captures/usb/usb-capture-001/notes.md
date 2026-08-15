# USB Capture 001 Notes

Target: TP-Link M7000(EU) V3.20

Firmware: `3.0.2 Build 241129 Rel.3n`

Host: Windows laptop

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
- Recent Windows driver-install metadata contained no new matching device.
- The sounds and LED sequence are evidence of transient link/power activity, but
  no descriptor identity was captured for that transient state.

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

### State D — connect USB after normal boot

Not performed. States B and C already distinguish charging-only settled behavior
from the powered-on RNDIS function, so another physical cycle was not justified.
