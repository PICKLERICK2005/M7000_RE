# Firmware Capture 001: Official firmware dissection

Date: 2026-08-15

## Scope and provenance

This phase used only official packages from the [TP-Link UAE M7000 V3.20 support page](https://www.tp-link.com/ae/support/download/m7000/v3.20/). The exact running release (`3.0.2 Build 241129 Rel.3n`), its predecessor, successor, and the ASR EU ISP update were preserved locally. Original and inner hashes are recorded in [`firmware/stock/manifest.json`](../firmware/stock/manifest.json); vendor binaries and extracted trees are gitignored.

No router request, setting change, firmware operation, reset, or USB experiment occurred.

## Container and userland

`update.bin` is a fixed-layout `Marvell_FBF` image. At offset `0x2000`, all three releases contain an XZ-compressed SquashFS 4.0 root filesystem. The running image's rootfs is 10,806,548 bytes, has 1,383 inodes, and hashes to `5dfddb34e9db5d7be3a82878d4a58d888d62012ebd8e4fb4db957c0564c02af8`.

The rootfs is an ARM little-endian, hard-float musl/OpenWrt-style userland. It includes lighttpd, the full stock web application, dedicated CGI handlers, `rpmServer`, modem/RIL services, diagnostic binaries, USB gadget services, SD/storage scripts, update tooling, and recovery/default-reset logic. See [`analysis/firmware-layout.json`](../analysis/firmware-layout.json) for reproducible offsets and hashes and [`tools/fbf-extract.mjs`](../tools/fbf-extract.mjs) for the read-only carver.

## Web/RPC implementation

The rootfs contains distinct `auth_cgi`, `web_cgi`, `down_log_cgi`, `isp_update_cgi`, and `update_cgi` ARM binaries plus `/usr/bin/rpmServer`. This validates that the RPC frontend mapped in Soft Capture 002 is backed by native firmware components rather than being only a generic static bundle. Static evidence does not prove every gated action is accepted on this SKU.

The firmware preserves the same architecture already documented in [`analysis/rpc-actions.json`](../analysis/rpc-actions.json): authentication uses `auth_cgi`; authenticated module/action traffic uses `web_cgi`; `rpmServer` contains model names and operational paths. The frontend still structurally performs RSA/session setup and AES wrapping in GDPR mode. No secret or device-derived cryptographic material is published.

## Debug Log: behavior and risk

The stock page exposes three separate operations:

- `log:5` reads `mdLogState`.
- `log:4` accepts `{mdLogState: boolean}` and enables or disables the diagnostic collector.
- `log:2` stages a conventional log archive; `down_log_cgi` serves it as `tplink_log.tar.gz` from `/cache/savelog.tar.gz`.

Firmware strings tie `log:4` to `/usr/bin/start_mdlog` and `/usr/bin/stop_mdlog`. `rpmServer` names a persistent `/cache/exported_log` directory and collectors for `logread`, `dmesg`, `logcat`, network state, and USB state. This makes the switch state-changing, not a passive download control. It may write flash-backed `/cache`, start long-running collectors, and increase storage use.

A second, deeper CATStudio/Marvell diagnostic mode exists in `use_flash_to_save_CATStudio_log.sh`. It swaps diagnostic configuration, creates `/cache/enable_diag`, and reboots; its stop path also reboots, while `clean_and_start` formats the `swap_flash` MTD partition. This mechanism is materially more invasive and must not be confused with the ordinary UI toggle.

The firmware also auto-executes `/misc/m7000_debug.sh` at late boot if that file exists. This is a dormant service/debug hook, not a supported public interface.

## TP-Link to modem boundary

Evidence supports a layered boundary:

1. TP-Link's web frontend calls the module/action RPC server.
2. `rpmServer` and libraries such as `libmobile.so` expose high-level operations (`GetModemConnState`, registration, signal, preferred network, and `SetModemMode`).
3. `mobile`, `rild`, `libmarvellril.so`, `libril.so`, `atcmdsrv`, and Quectel common libraries bridge those requests to RIL and AT-command channels.
4. Named endpoints include `/tmp/atcmd*`, `/dev/ttymodem0`, and `/dev/ttyS1`.

Thus the composite `status:0` response is a TP-Link abstraction over several subsystems; modem identity, SIM, registration, radio, and signal values are plausibly sourced through the mobile/RIL layer. Exact call graphs remain an inference until symbol-aware disassembly or runtime tracing.

## Dormant and gated capability classification

| Capability | Firmware evidence | Best current classification |
| --- | --- | --- |
| Debug logging | UI actions, `rpmServer`, collector paths, diagnostic binaries | Backend present; UI toggle state-changing |
| WISP | Full AP Bridge UI/model and `network_wisp` config | Frontend and configuration present, model-gated; backend path likely present but untested |
| WPS | Full UI/model and WLAN tooling | Frontend present, model-gated; backend acceptance untested |
| 5 GHz | Shared UI logic but `disable5G`; RTL8192ES driver | Frontend gate plus probable 2.4 GHz hardware constraint |
| NAT/forwarding | UI/RPC models and iptables stack | Backend plumbing present, SKU feature-gated; action handlers unverified |
| SD/storage | Storage UI/model, mount/WebDAV/NTFS scripts | Backend present, physical capability or exposed slot absent/unconfirmed |
| USB modes | Gadget service, `usb_daemon`, USB configs and diagnostic USB strings | Backend/hardware support present below the web UI; modes not yet enumerated |
| Backup/restore | Factory reset/recovery paths; no config-export UI | Reset present; backup/restore workflow absent from this frontend |
| Band selection | RIL preferred-network/mode operations; no band-lock UI | Modem controls present; manual band selection not established |
| AT/Quectel interface | `atcmdsrv`, serial clients, RIL/Quectel libraries and FIFOs | Backend interface present, hidden from web UI; access controls unknown |
| Firmware recovery | local/cloud updater, redundant-config copy and state-control paths | Normal update and recovery plumbing present; emergency recovery entry unconfirmed |
| NVRAM/factory | NVM tools, factory flags, cross-partition config copy | Backend present and sensitive; no safe public write interface established |

## Status model conclusion

The firmware reinforces the Soft Capture 002 finding that `status:0` is a single backend abstraction covering product/firmware identity, battery, WAN and radio/SIM, WLAN/WISP, clients, messages, and SD-card state. The frontend-returned fields and hidden consumers remain catalogued in [`analysis/status-model.json`](../analysis/status-model.json). Firmware strings identify the likely mobile/RIL producers but do not yet bind every JSON field to a specific native function.

## GPL source status

Each firmware archive includes TP-Link's GPL license notice, but this capture did not locate a verified M7000(EU) V3.20 source bundle on TP-Link's public download page or in indexed official results. The license notice is not source code. A formal source request remains worthwhile because build recipes and corresponding OpenWrt/kernel sources would materially improve reproducibility; proprietary `rpmServer`, CGI, modem, and vendor RIL components may remain excluded.

## Recommendation

Proceed next with **B: deeper read-only RPC probing**, narrowly limited to stock-equivalent reads and especially feature/capability queries. Firmware analysis has already established that Debug Log writes persistent storage and starts collectors, while CATStudio logging can reboot or format `swap_flash`. Before any controlled Debug Log capture, use offline disassembly and exact read-only state queries to distinguish the ordinary collector from the invasive diagnostic path and estimate archive/storage behavior.

USB Capture 001 is a reasonable following phase, but the newly exposed backend paths make a short, controlled read-only pass the highest-value next step.
