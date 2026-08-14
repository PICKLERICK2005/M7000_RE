# Soft Capture 002: Frontend and RPC Analysis

Date: 2026-08-15

## Scope

This phase analyzed privately preserved copies of the stock frontend assets and the sanitized module/action trace from Soft Capture 001. No router setting was changed, no firmware operation was started, and no previously unobserved RPC action was invoked.

Canonical software identifiers:

| Field | Value |
| --- | --- |
| Hardware | `M7000(EU) v3.2` |
| Firmware | `3.0.2 Build 241129 Rel.3n` |
| Product region | `EU` |

## RPC architecture

The UI uses a proprietary module/action RPC protocol over HTTP `POST` requests:

- `cgi-bin/auth_cgi` handles the `authenticator` module.
- `cgi-bin/web_cgi` handles all other modules.
- Calls contain a module name, numeric action, optional parameters, and—when authenticated—a token.
- Public pre-authentication calls are Base64-wrapped JSON.
- The device advertises `supportGDPR=true`. In that mode the frontend establishes RSA-derived session material and AES-wraps protected payloads. This describes the frontend structure, not a cryptographic audit.
- `tpweb_token` is the observed session-cookie name. No value was retained.

The complete statically recovered action table is stored in [`analysis/rpc-actions.json`](../analysis/rpc-actions.json). Function names in that file come from the shipped frontend; they do not independently prove that every generic handler is implemented by this device's backend.

### Model-to-page map

| Module/model | Read actions observed | Primary response model | UI consumer |
| --- | --- | --- | --- |
| `status` | `0` | Composite device, battery, WAN/radio/SIM, WLAN, clients, messages, SD card | Status, Device Information, global status bar, feature routing |
| `wan` | `0`, `10`, `11` | Connection/profile settings, operators, roaming, selection/search and disconnect state | Wizard, Dial-up Settings, Network Settings, ISP Update |
| `simLock` | `0` | Card/PIN state, remaining attempts, auto-unlock | PIN Management |
| `message` | `2` | Paginated inbox/outbox message metadata | SMS pages |
| `voice` | `0`, `3` | USSD capability/session and send state | USSD |
| `wlan` | `0` | SSID, region/channel/band/mode/security and region channel table | Wizard, Wireless Settings |
| `connectedDevices` | `0` | Station count and station list | Online Clients |
| `macFilters` | `0` | Filter mode, limits, and deny list | Blacklist |
| `lan` | `0` | LAN address/mask and DHCP configuration | DHCP Server |
| `flowstat` | `0` | Data-limit, billing-day, alert, correction, and free-period settings | Data Usage Settings |
| `power_save` | `0` | Power-saving enable, Wi-Fi range, auto-disable time | Power Saving |
| `update` | `0` | Current/latest firmware metadata and update state | Software Update and global update indicator |
| `time` | `0`, `2` | Timezone/region expectations and current time | Wizard and Time Settings |
| `log` | `0`, `3`, `5` | Paginated logs and debug-log state | System Log |
| `webServer` | `5`, `6`; `2` is the static heartbeat handler | Feature flags and pre-auth status summary | Global shell and login page |

The normal navigation trace did not reach feature-gated NAT, WPS, storage, or AP Bridge models. Their action definitions and response mappings still exist in the shared bundle.

## Debug Log classification

System Log contains two distinct mechanisms:

1. The normal download control calls `log:2` (`saveLog`) synchronously. On success, the frontend points the browser at `cgi-bin/down_log_cgi?token=...`. This appears to prepare and download the existing system log.
2. The `Debug Log` switch calls `log:4` (`setMdLog`) with `{mdLogState: <boolean>}`. System Log page load calls `log:5` (`getMdLog`) to read the current toggle state.

The localized error paths for `setMdLog` say that an SD card must be installed and in the correct mode. The UI displays “Opening Debug log” or “Closing Debug log” while the request runs.

Classification:

- `log:5` is a read-only state query and was already produced by normal page navigation.
- `log:4` changes diagnostic logging state and is not read-only.
- `log:2` likely creates or stages a downloadable artifact before `down_log_cgi` serves it; it is separate from enabling Debug Log.
- Debug Log was not activated and Download Log was not clicked.

This is a promising diagnostic path, but it is coupled to SD-card support that the M7000 feature list reports as disabled. Whether the backend action is usable without exposed storage hardware remains unconfirmed.

## Shared status model

The frontend obtains its composite status through `status:0`. One response is divided into these sections:

- root: `result`, `factoryDefault`
- `deviceInfo`: `model`, `productRegion`, `hardwareVer`, `firmwareVer`, `mac`, `imei`, `imsi`, `simNumber`
- `battery`: `connected`, `charging`, `voltage`
- `wan`: connection, IP/DNS, radio/SIM, roaming, traffic, and signal fields
- `wlan`: local WLAN and WISP connection fields
- `connectedDevices`: client count
- `message`: unread-message count
- `sdcard`: status, mode, capacity, and usage

This confirms that the TP-Link frontend receives modem identity, SIM/radio state, firmware/hardware metadata, network state, WLAN state, battery state, and peripheral summaries through one backend abstraction. It does not establish where the backend stores or originally obtains those values.

### Displayed or behaviorally consumed

- Device Information displays model, firmware version, hardware version, MAC, IMEI, IMSI, and SIM number. `productRegion` gates region-related UI behavior.
- Status consumes connection state, IPv4/IPv6, radio type/band and signal measurements, SIM state, roaming state, traffic totals/rates, WLAN security/region/band, and client count.
- The top status bar consumes battery, signal, roaming, WLAN, unread-message, and optional SD-card summaries.
- `factoryDefault` controls first-run Wizard routing.

### Retained but not consumed by the shipped desktop frontend

Static reference analysis found no consumer beyond model assignment for:

- `wan.dns1v4`
- `wan.dns2v4`
- `wan.dns1v6`
- `wan.dns2v6`
- `wan.registerStatus`
- `wlan.connectedSecurity`
- `wlan.connectedSignal`

These are backend-returned fields hidden or ignored by this frontend build. Their presence does not imply a hidden page.

## Dormant and gated capabilities

| Capability | Evidence | Classification |
| --- | --- | --- |
| WPS | Complete frontend model/actions and page handler; `disableWPS=true`; menu removed | Frontend present, runtime feature-gated; backend availability untested |
| WISP / AP Bridge | Complete model/actions; `supportWISP=false`; forced route returned to Status | Frontend present, runtime feature-gated; backend availability untested |
| 5 GHz / 802.11ac | Generic channel/mode logic includes 5 GHz and 11ac; `disable5G=true` hides band control | Frontend present, model capability-gated; hardware/backend support unproven |
| NAT forwarding | ALG, virtual-server, port-trigger, DMZ, and UPnP models/pages exist; `supportnatforwarding=false` removes group | Frontend present, runtime feature-gated; backend availability untested |
| SD-card/storage sharing | Storage model/page and status fields exist; `supportSdcard=false` removes page | Frontend present, runtime feature-gated; physical/backend support unproven |
| Backup/restore | Feature response reports backup/restore unsupported; shipped UI implements factory reset but no configuration export/import workflow | Configuration backup absent from this frontend; factory reset is separate and destructive |
| Debug logging | `log:4` toggle, `log:5` query, SD-card error paths | Backend-facing diagnostic control present; state-changing; not activated |
| Firmware update/recovery | Local upload and cloud-update state machine present; current page reports no newer release | Update functionality present; no dedicated recovery/emergency-mode frontend found |
| USB mode | No matching route, model, action, label, or handler found | No frontend evidence |
| Quectel/AT/tty/modem command interface | No Quectel, AT-command, serial-device, or modem-console handler found | No frontend evidence; generic “tty” substring was unrelated text |
| NVRAM/factory configuration | Factory-default state and reset action exist; no NVRAM/config-partition API names found | Reset behavior present; storage architecture not exposed |
| Manual LTE band selection | Status displays the current band; Network Settings exposes network mode/search, not a band-lock control | Current-band observation present; no band-selection UI found |

“Frontend present” means code ships in the shared bundle. It is not proof of compatible hardware or a reachable backend implementation.

## Firmware/update observations

The update model exposes local-upload and cloud-update operations, progress polling, cache clearing, deferred reminders, and immediate upgrade controls. The normal read-only update view reported:

- current version `3.0.2 Build 241129 Rel.3n`
- `hasNewVersion=0`
- no latest-version string, download URL, package size, or release note

No update-related state-changing action was invoked.

## Recommended next step

Proceed with **D: official firmware acquisition and offline dissection**.

Debug Log is interesting, but its enable action changes device state and expects SD-card storage that this model reports as unsupported. The frontend RPC map is already broad enough that speculative probing offers less value than locating the exact V3.20 firmware and inspecting its CGI handlers, log implementation, storage paths, modem integration, and update/recovery code offline. Firmware analysis can determine whether `log:4`, `down_log_cgi`, dormant modules, or USB/diagnostic interfaces are genuinely implemented before the device is asked to do more.
