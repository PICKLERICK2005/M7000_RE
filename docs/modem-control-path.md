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
  are local shared-state/configuration reads. Offline disassembly now separates
  their producers: data and roaming switches (`73`, `74`), network-selection
  mode (`76`), and selected ISP (`446`) use persistent writes; connection state
  (`79`) uses a temporary runtime write; and registration state (`81`) is
  updated temporarily by the AT-facing status state machine. Preferred network
  type (`75`) has both a persistent setter and a temporary normalization path.
  Exact refresh latency and callback entry points remain unresolved. See
  [`analysis/shared-record-producers.json`](../analysis/shared-record-producers.json).
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

The narrow live getters are local projections too. `wan:10` reads shared record
`84` through `GetNetSelStat`. `wan:11` does not read a single failure-reason
record: `GetCallFailReason` derives its result from seven records (`81`, `79`,
`74`, `30`, `39`, `44`, and `80`). Thus neither getter inherently forces a new
AT transaction when the web UI calls it.

## Refresh path

The runtime model is primarily event-driven rather than web-request-driven.
During modem setup, `mobile` enables `CGREG`, `CREG`, `CEREG`, `CGEREP`, and
`BANDIND` indications. The AT manager parses these unsolicited messages and
solicited forms of the corresponding queries; `mobile_status_at.cpp` normalizes
registration/network state before temporary shared-record writes. Packet-domain
detach/deactivation indications feed the backhaul FSM, which updates connection
state and sends WAN connect/disconnect notifications. Consequently, calling a
web getter reads the latest shared snapshot and does not itself refresh the
modem.

Solicited query vocabulary is also present for signal, operator, activation,
band, registration, location, RF mode, runtime IP, and system information. This
supports initialization, explicit direct-modem reads, and fallback/reconciliation
paths. Timer infrastructure and a backhaul-check timer are confirmed, but their
exact polling intervals and worst-case web-visible propagation latency remain
unresolved. See
[`analysis/modem-refresh-path.json`](../analysis/modem-refresh-path.json).

The canonical per-record view—including writer offsets, triggers, upstream
sources, transformations, persistence, consumers, confidence, and explicit
unknowns—is maintained in
[`runtime-record-provenance.md`](runtime-record-provenance.md) and
[`analysis/runtime-record-provenance.json`](../analysis/runtime-record-provenance.json).

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

## Runtime state normalization

The registration callback at `mobile+0x39ab0-mobile+0x39f24` retains three raw
registration-domain values, treats home (`1`) and roaming (`5`) as registered,
emits roaming separately in record 80, and collapses the domains into record
81. Record 81 value `2` can mean either searching or secondary-domain
registration, so it is not a lossless copy of any one AT result.

The backhaul FSM at `mobile+0x364bc-mobile+0x37004` owns record 79's source
field. Its enum is `0` disabled, `1` disconnected, `2` connecting,
`3` disconnecting, and `4` connected. Registration/service state, data and
roaming policy, flow-limit state, network-selection activity, profile changes,
and packet detach/deactivation all feed this FSM.

For configured RAT policy, record 75 illustrates the reverse direction. The UI
enum (`1` 3G only, `2` 4G only, `3` 4G/LTE preferred) enters libmobile event
`0x33` unchanged. `mobile` stages it at status-object offset `0x194`, invokes
the modem-manager operation, and persists record 75 only after immediate
acceptance. Startup also repairs an invalid stored preference to `3`.

The lower boundary is the Marvell/ASR `AT*BAND` model. The AP firmware contains
both `AT*BAND?` and setters with separate network-mode and preferred-mode
arguments. Its direct read event `0x46` returns the modem scalar that the
callback normalizes: `1` GSM -> hidden AP value `0`, `2` UMTS -> UI value `1`,
`3` LTE -> UI value `2`, and multi-RAT `0x3081` (or fallback `0`) -> UI value
`3`. Consequently the configured policy conversion is 3G-only -> modem mode
`2`, 4G-only -> mode `3`, and LTE-preferred -> multi-RAT mask `0x3081` with
preferred mode LTE (`3`). The CP `AT*BAND` handler logs `NwMode` and
`PreferMode`, checks the two for equality, and explicitly accepts preferred
mode `CI_DEV_NW_GSM`, `CI_DEV_NW_UMTS`, or `CI_DEV_NW_LTE`.

This establishes the strongest static control chain currently available:

```text
networkMode UI
  -> wan configured preferred-network policy
  -> libmobile SetPrefNetType / event 0x33
  -> mobile modem-manager AT*BAND operation
  -> AP AT/RIL channel
  -> CP AT*BAND handler (networkMode + preferredMode)
  -> CP RAT/service-manager state
  -> registration/service indications
  -> records 81 (registration), 83 (service), 82 (current RAT)
```

The AP owns durable record 75 in `mobile_config.net_config.pref_net`. The CP
image contains `SystemControl.nvm`, `LTE_Cfg.nvm`, the NVM client, and named
NRAM2 PLMN/band-order records, but static evidence does not tie the preferred
RAT setting to a particular `.nvm` record. It may be runtime CP state reapplied
from AP policy at startup. This gap is retained rather than assigning false CP
persistence. No setter or AT command was executed.
