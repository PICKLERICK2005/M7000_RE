# AP to Modem Control Path

```text
stock web UI
  -> web_cgi / auth_cgi
  -> /tmp/tp_rpm_server.sock
  -> rpmServer
  -> libmobile.so
     -> libdata_management.so numbered shared-state records (many getters)
     -> asynchronous mobile event client
  -> mobile daemon (/tmp/mp_svr_file, per-process /tmp/mp_clnt_* paths,
     /tmp/mobile_msg_server.sock, and related sockets)
  -> libmarvellril.so / rild / atcmdsrv
  -> /dev/smd0, /dev/ttyS1 and ACIPC-backed services
  -> CP/RTOS NVM, SIM, network and diagnostic handlers
  -> GRBI Layer-1 / RF execution
```

## Confirmed AP-side links

- `rpmServer` imports `GetAllStatus` and narrower SIM, signal, registration,
  operator, connection, and RF-band getters from `libmobile.so`.
- Many getters read typed, numbered records through `libdata_management.so`.
  For example, `GetSimIMSI` requests record `24`; this is an internal data-model
  key, not a web RPC action.
- `GetAllStatus` zeroes a 5,364-byte result and composes it from exactly eight
  getters: data switch, roaming switch, connection state, registration state,
  preferred network type, network-selection mode, selected ISP name, and
  profile list. It is a local aggregate, not one monolithic modem RPC.
- The scalar/string components read records `73` (data switch), `74` (roaming
  switch), `79` (connection state), `81` (registration), `75` (preferred
  network type), `76` (network-selection mode), and `446` (selected ISP name).
  The profile list combines metadata records `47`, `48`, `51`, `52`, and
  `61`-`64`, dynamically selected user records (`stored index + 53`), and
  sequential ISP profile records beginning at `65`.
- None of these eight getter implementations constructs a `CMobileEvent`; they
  are local shared-state/configuration reads. The writer and refresh source for
  each CP-derived runtime record remain unresolved.
- The event client uses Unix datagrams, `/tmp/mp_svr_file`, and per-process
  `/tmp/mp_clnt_*` paths (including `_resp`). The daemon also names
  `/tmp/mobile_msg_server.sock`, `/tmp/wm_lte_wifi.sock`, and
  `/tmp/ha_wm.sock`; the relationship between the first two mobile IPC names
  remains unresolved.
- `/etc/config/at_channel` maps channels to `/dev/ttyS1` and `/dev/smd0`.
- `/etc/telinit` starts `cp_load`, `nvmproxy`, `atcmdsrv`, and `rild` in the
  normal CP-enabled path.
- `libmarvellril.so` contains RIL request handlers and `/tmp/atcmd` vocabulary.
- Static client tracing identifies `/tmp/atcmd` as a separate Unix stream: an
  ASCII command terminated by one carriage return, followed by line-oriented
  responses whose confirmed final tokens include `OK`, `ERROR`, `+CME ERROR`,
  and `+CMS ERROR`. See [`analysis/atcmd-ipc.json`](../analysis/atcmd-ipc.json).
- CP `ARBI` contains matching ACIPC, NVM-client, diagnostic, SIM, and cellular
  control subsystems.

## Supported inference

The AP and CP meet through more than one logical channel: an ACIPC/shared-memory
transport underneath Linux CP services, SMD/serial AT channels for command
traffic, and dedicated diagnostic paths. The asynchronous mobile event frame
is three little-endian 32-bit words (correlation ID, event ID, payload
length), followed by the payload at byte 12. Deserialization checks both the
12-byte minimum and declared length; the receive path uses a 20 KiB buffer.
The symbol-backed event enumeration is grouped into profile, backhaul/network
scan, network configuration, modem-read, voice/USSD, SIM/PIN, and SMS families.
Some payload layouts and lower-layer RPC IDs remain to be recovered. See
[`analysis/mobile-ipc.json`](../analysis/mobile-ipc.json) and
[`analysis/mobile-events.json`](../analysis/mobile-events.json).

## Synthetic startup observation

A fail-closed QEMU userspace run of the exact 3.0.2 `mobile` daemon confirmed
that startup initializes disposable SMS files and reads the `mobile_config` and
`mobile_status` UCI/data-management models before bringing up its asynchronous
Unix-datagram server. Four worker threads and `/tmp/mp_svr_file` were observed.
No AT request, mobile event datagram, reset/NVM switch, or WAN/WLAN notification
occurred before the controlled cutoff. See
[`mobile-startup-summary.md`](../emulation/traces/mobile-startup-summary.md).

This runtime ordering supports—but does not extend—the static architecture:
`mobile -> libdata_management/UCI -> event IPC -> AT/ACIPC -> CP`. Internal
record IDs are library-call arguments and were not visible at syscall level;
the existing static record map remains the evidence for those IDs.

AP UCI owns UI policy and profiles such as APN selection, while CP NVM owns or
consumes radio, calibration, lock, and low-level modem state. SIM-derived and
runtime network fields remain dynamically sourced. Static setter symbols remain
code-presence evidence only; they do not establish web reachability, safety, or
persistence.
