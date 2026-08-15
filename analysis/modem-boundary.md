# Modem boundary (3.0.2)

The offline evidence refines the working data path to:

```text
web_cgi -> /tmp/tp_rpm_server.sock -> rpmServer
          -> libmobile.so client API -> mobile daemon IPC
          -> Marvell RIL / modem services -> CP/modem
```

Observed evidence:

- `rpmServer` imports `GetAllStatus` and narrower calls including signal, registration, operator, SIM, connection and RF-band getters from `libmobile.so`.
- The `GetAllStatus` import is at `0x13bdc`; a call site is at `0x177c4` in the status-building region.
- `libmobile.so` exports `GetAllStatus`, `GetSimIMSI`, `GetSimNumber`, `GetSimStatusForWebStatus`, `GetRegStat`, `GetSigInfo`, `GetOperatorName`, `GetNetType`, and related functions.
- The mobile daemon contains `/tmp/mobile_msg_server.sock`, `/tmp/wm_lte_wifi.sock`, `/tmp/ha_wm.sock`, `/tmp/mp_svr_file`, and client paths beginning `/tmp/mp_clnt_`.
- Many `libmobile` getters use numbered records from `libdata_management.so` rather than issuing a fresh modem request. `GetAllStatus` locally aggregates eight getters: data switch, roaming switch, connection state, registration state, preferred network type, network-selection mode, selected ISP name, and profile list.
- The separate asynchronous event channel uses Unix datagrams and a 12-byte little-endian header containing correlation ID, event ID, and payload length, followed by the payload. Symbol-backed event families and their read/change classification are mapped in [`mobile-events.json`](mobile-events.json); some payload structures remain unresolved.
- `libmarvellril.so` contains RIL request handlers for device and subscriber reads, `/tmp/atcmd`, and a high-speed serial endpoint. The underlying AT service exposes ICCID query vocabulary. No live command was sent.
- `/tmp/atcmd` is an `AF_UNIX` stream distinct from the mobile event datagram socket. `mobile` writes carriage-return-terminated ASCII AT commands and parses line-oriented final results. The fail-closed sandbox stub and framing evidence are recorded in [`atcmd-ipc.json`](atcmd-ipc.json).

The composite `status:0` model therefore uses `libmobile` as one high-level backend abstraction, but that library itself combines shared data-management records and an asynchronous command/event path. `rpmServer` adds system, WLAN, IP, battery, storage, client, and message data. It is not justified to claim every status field—or even every modem field—originates in `GetAllStatus`.

The sanitized live getter pass adds three narrower confirmations. `wan:10`
returns a `networkSelectionStatus` scalar and corresponds structurally to the
exported `GetNetSelStat` API. `wan:11` returns `callFailReason` and corresponds
to exported `GetCallFailReason`. `simLock:0` returns card state, PIN state,
remaining PIN/PUK attempts, and the auto-unlock flag; `libmobile` exports the
matching SIM/PIN getter family. These correlations establish the available API
models, while the exact field-to-call sites in stripped `rpmServer` remain an
explicit gap.

Factory-state ownership is distinct but related: `etc/init.d/check_device_code` reads factory-burned identity and region files from persistent `/misc`, validates their shape, and seeds UCI product configuration when defaults are present. It also records that the device-code set includes MAC, IMEI, region, and optional device metadata. No device-specific value is present here.

The binaries contain both read and write-oriented factory/RIL symbols. This document intentionally records only architectural ownership and read paths; operational identity-writing commands or tooling are out of scope.
