# Soft Capture 001: Visible UI Map

Observe only. Do not change a setting merely to generate traffic.

| Menu path | Page/tab | Status fields | Configurable fields | Related requests | Notes |
| --- | --- | --- | --- | --- | --- |
| Status | Status | Connection, network type, SIM state, band, RSRP, RSRQ, SNR/RSSI, Wi-Fi, clients, traffic, region | None observed in static handler | `status` model | Runtime visibility pending login |
| SMS | Inbox | Message list and message detail | Read/delete/reply controls | `message` model | Feature present in bundle |
| SMS | New Message | Recipient and message body | Send message | `message` model | Feature present in bundle |
| SMS | Outbox | Sent-message list | Read/delete controls | `message` model | Feature present in bundle |
| Advanced / Dial-up | Dial-up Settings | Connection and profile state | Connection/profile settings | `wan` model | Runtime visibility pending login |
| Advanced / Dial-up | Network Settings | Network mode | Network mode selection | `wan` model | Runtime visibility pending login |
| Advanced / Dial-up | PIN Management | SIM/PIN status | PIN controls | `simLock` model | Runtime visibility pending login |
| Advanced / Dial-up | ISP Update | ISP/profile update state | ISP update | `wan` model | Supported by feature list |
| Advanced / Dial-up | USSD | USSD response | USSD input | `wan` model | Supported by feature list |
| Advanced / Wireless | Wireless Settings | SSID, region, band, wireless mode | Wi-Fi configuration | `wlan` model | Device feature list disables 5 GHz |
| Advanced / Wireless | Online Clients | Connected client list | Client management | `connectedDevices` model | Public status reported one client; identifiers not recorded |
| Advanced / Wireless | Blacklist | Denied clients | Add/remove entries | `macFilters` model | Feature present in bundle |
| Advanced | DHCP Server | LAN/DHCP state | IP, mask, pool, lease, DNS | `lan` model | Feature present in bundle |
| Advanced | Data Settings | Usage totals/limits | Usage settings | `flowstat` model | Feature present in bundle |
| Advanced | Power Saving | Battery/power state | Sleep/power-saving settings | `power_save` model | Feature present in bundle |
| Advanced / Device | Software Update | Current/new firmware metadata | Local or cloud update controls | `update` model | Cloud update supported; do not trigger |
| Advanced / Device | Restore Configuration | Restore state | Factory restore | `restoreDefaults` model | Destructive; do not trigger |
| Advanced / Device | Login Password | None | Change admin password | `authenticator` model | Do not trigger during capture |
| Advanced / Device | Shutdown | Power state | Shutdown/reboot | `reboot` model | Do not trigger during capture |
| Advanced / Device | Time Settings | Current device time | Time/timezone settings | `time` model | Feature present in bundle |
| Advanced / Device | System Log | Log type, log level, log entries | Clear and `Debug Log` controls | `log` model | Debug-log behavior not activated |
| Advanced / Device | Device Information | Model, firmware/hardware version, IMEI, MAC, IMSI, SIM number | None observed | `status` model | Unique values must be redacted |

## Capability checklist

- [x] Device/status overview identified statically
- [x] Mobile network and connection mode identified statically
- [x] Signal and LTE band information identified statically
- [x] SIM/PIN management identified statically
- [x] APN/operator settings identified statically
- [x] SMS and USSD identified statically
- [x] Wi-Fi settings identified statically
- [x] LAN/DHCP settings identified statically
- [x] Connected clients identified statically
- [x] Statistics and logs identified statically
- [ ] Dedicated diagnostics page
- [x] Firmware update identified statically
- [x] Factory restore identified; backup/restore disabled by runtime feature list
- [x] Reboot/shutdown and factory-reset controls identified statically
- [x] Battery information identified statically
- [x] Authenticated runtime visibility of feature-gated pages

The generic frontend bundle also contains WPS, AP Bridge, storage sharing, and NAT-forwarding handlers. The device's runtime feature list disables or hides these capabilities; bundle presence alone is not evidence that they are usable on this M7000 configuration.
