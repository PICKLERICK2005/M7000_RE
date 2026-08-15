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

## Reference model: preferred RAT (record 75)

Record 75 is the project's reference example of an AP→CP configuration path,
because every stage of it is recoverable. The dense machine-readable form,
including payloads, gating and per-stage confidence, is in
[`modem-control-paths.json`](../analysis/modem-control-paths.json).

**Configuration direction.** The UI enum (`1` 3G only, `2` 4G only,
`3` 4G/LTE preferred) reaches `CMobileClient::SetPrefNetType`. That function
range-checks the value against `3`, requires a non-NULL result pointer, and then
performs a pre-flight read of records `19` and `84`. It refuses the request when
an SMS send is in flight (record 19 == 4) or when network selection is busy —
record 84 values `3` searching, `11` canceling COPS, `1` registering, each with
its own log line and result code. Only then is a `CMobileEvent` built: event ID
`0x33` at object offset `0x54`, a four-byte little-endian payload holding the
policy scalar unchanged, and a response that must be exactly four bytes or the
client rejects it as corrupted.

Inside `mobile`, `ProcUserEventComm` reads the payload, stages the value at
status-object offset `0x194`, invokes the modem-manager operation through
virtual slot `+0x24`, and persists record 75 **only if that call returns 0**.
The AT layer persists the staged value a second time once the transaction
completes. A request the modem rejects therefore never becomes durable policy.

The AT builder appends a decimal literal to `AT*BAND=` under a jump table:

| Record 75 | Command sent |
| ---: | --- |
| `0` (hidden) | `AT*BAND=0` |
| `1` 3G only | `AT*BAND=1` |
| `2` 4G only | `AT*BAND=5` |
| `3` LTE preferred | `AT*BAND=11` |
| out of range | `AT*BAND=99` |

A second builder emits the six-field form `AT*BAND=%d,,,,,%d`, mapping the same
policy values to `0`, `1`, `5` and `14` with a separate `0`/`1` prefer flag. Its
argument registers do not match the surrounding calling convention and it
contains an always-taken trap before the `snprintf`, so the single-argument
builder is treated as the live setter; the anomaly is recorded verbatim in the
JSON rather than smoothed over.

**Readback direction.** `AT*BAND?` returns
`*BAND: <NwMode>, <f2>, <f3>, <f4>, <f5>, <PreferMode>`. The parser consumes
only fields 1 and 6 and maps `NwMode` back into policy space: `0`→`0`, `4`→`1`,
`5`→`2`, `8`/`11`/`15`→`3`, anything else→`-1`. Policy values `0`, `2` and `3`
round-trip; policy `1` sends `NwMode 1`, which the parser does not recognise.

Event `0x46` is a distinct path with **no request payload** and a four-byte
response. Its normalizer maps `1`→`0`, `2`→`1`, `3`→`2`, and `0`, `0x3081` or
anything else→`3`, writing record 75 temporarily. Raw `1`/`2`/`3` line up
exactly with the CP assertion on `CI_DEV_NW_GSM`, `CI_DEV_NW_UMTS` and
`CI_DEV_NW_LTE`, so this is the CI preferred-mode space — **not** the `AT*BAND`
`NwMode` space.

That distinction matters: there are four numeric spaces here, and they must not
be merged.

```text
networkMode UI enum        1 / 2 / 3          (+ hidden 0)
  -> record 75 policy      0 / 1 / 2 / 3
  -> AT*BAND NwMode sent   0 / 1 / 5 / 11     (default 99)
  -> AT*BAND NwMode parsed 0 / 4 / 5 / 8 / 11 / 15
  -> CI preferred-mode     0 / 1 / 2 / 3 / 0x3081
```

**On `0x3081`.** It appears once, as a `movw` immediate at `mobile` VA
`0x4a2f0`, and is only ever compared for equality — never masked or shifted. It
does **not** occur anywhere in the CP image as an ARM or Thumb-2 `movw`
immediate or as a literal word; the one apparent hit sits inside a consecutive
run (`0x307e`…`0x3084`) that is an assertion line-number table. So its bit
allocation cannot be proven, and no evidence supports calling it a RAT mask. The
strongest supported reading is a distinguished "no single preferred RAT" value
in the CI preferred-mode space that the AP folds into LTE-preferred. An earlier
draft that mapped configured `1`/`2`/`3` to modem values `2`/`3`/`0x3081` is
superseded by the builder disassembly above.

**CP side.** The image logs `AT*BAND, NwMode=%d, PreferMode=%d`, asserts
`pSig->preferredMode == pSig->networkMode` on the equality fast path, restricts
a standalone preferred mode to the three `CI_DEV_NW_*` values, and carries
`L1CSetRat` with an invalid-mode assertion. The CP load base is not established,
so no CP call graph was reconstructed; the CP contributes vocabulary and
constraints here, not control flow.

```text
networkMode UI
  -> record 75 persistent policy
  -> libmobile SetPrefNetType (validate, gate on records 19 and 84)
  -> mobile event 0x33, 4-byte payload
  -> ProcUserEventComm: stage +0x194, modem-manager virtual slot +0x24
  -> AT*BAND=<NwMode> over /tmp/atcmd
  -> CP AT*BAND handler (NwMode + PreferMode)
  -> CP RAT / service-manager state, L1CSetRat
  -> registration/service indications
  -> records 81 (registration), 83 (service), 82 (current RAT)
  -> event 0x46 readback -> CI preferred-mode -> temporary record 75 overlay
```

The AP owns durable record 75 in `mobile_config.net_config.pref_net`, written
permanently by exactly one routine (commit at ELF VA `0x4256c`). Four call sites
reach it, including a 3GPP2-card repair path in `mobile_status.cpp` that forces
the policy to `3` and logs *"Insert 3GPP2 card, net change net type to 4G
prefered."* — that path, not a generic startup validity check, is what an
earlier draft recorded as an invalid-value fallback.

The CP image contains a full NVM client and 132 distinct `.nvm` file names,
including `SystemControl.nvm`, `LTE_Cfg.nvm`, `comBasicCfg.nvm` and
`ipcfg.nvm`, but none is named for RAT or network-mode selection and none is
tied to the preferred RAT by any recovered reference. The negative result is
retained rather than assigning false CP persistence. No setter, AT command or
NVM access was executed.

## Generalizing the model

The record-75 chain gives a template with seven recoverable stages: UI enum →
persistent AP record → libmobile API with its own validation → mobile event ID
and payload → daemon handler and persistence rule → AT representation → CP
handler, plus a separate readback path with its own numeric space. Applying that
template to the other configuration families produced the following, all static.

| Path | Policy record | Event | Request payload | Pre-flight gate | Permanent writer |
| --- | ---: | ---: | ---: | --- | --- |
| Preferred RAT | 75 | `0x33` | 4 bytes | records 19 + 84 | commit `0x4256c` |
| Network selection | 76 (workflow 84) | `0x34` | 56 bytes | records 19 + 84 | commit `0x338a8` |
| Data switch | 73 (effective 79) | `0x31` | 4 bytes | none | commit `0x4238c` |
| Roaming switch | 74 | `0x32` | 4 bytes | none | commit `0x4243c` |

The pre-flight gate is the structurally interesting result. It is not a generic
setter preamble: only the two network-touching setters perform it, and both use
the identical record pair and the identical four refusal codes. The data and
roaming switches construct their events immediately. This is firmware-visible
evidence that RAT policy and network selection are treated as belonging to the
same serialized modem-level operation class, while the two switches are not.

Network selection persists record 76 from inside the AT layer rather than from
the event handler, which is the opposite arrangement from preferred RAT. Its
56-byte `MP_NetSel` payload has not been decomposed, and the record 84 workflow
enumeration is known only at values `1`, `3` and `11` — the three the block
messages name. Scan initiation, result delivery, timeout, cancel and restore
transitions remain unmapped.

## Record identity

Every numeric record ID used across this project resolves through one table:
`usr/bin/tp_data` file offset `0x1d40`, 450 entries, fixed 64-byte stride, one
`package.section.option` string each, so `record_id = (offset - 0x1d40) / 0x40`.
The full index is in
[`tp-data-record-map.json`](../analysis/tp-data-record-map.json). It reproduces
every record ID previously asserted from independent disassembly, which
retroactively confirms the earlier provenance work rather than replacing it.

Two results fall directly out of that table. Records `200`–`207` are
`mobile_status.rf_info.rat`, `rssi`, `rsrp`, `rsrq`, `snr`, `ecio`, `band` and
`channel`: the firmware keeps the raw per-RAT metrics separately from the
normalized level in record 78. And the handler that writes record 78 performs a
straight 32-bit copy with no threshold logic at all, so the normalization it
implies happens strictly upstream and is still unlocated. No standard CSQ-to-bars
mapping should be assumed for record 78.

## Where to aim next

`AT*BAND` gives a concrete, fully textual AP path: `mobile` formats commands into
a 512-byte buffer, hands them to a sender at ELF VA `0x3f6a4` with a numeric AT
command ID and a correlation cookie, and parses replies with `sscanf` against
literal formats in one large dispatcher in `src/comm/manager_comm_at.cpp`. The AT
text stays textual on the AP side from builder to parser; whatever conversion
happens does so at or below `/tmp/atcmd`.

What that means for future work is that the productive layers, in order, are the
libmobile event API — typed, validated and gated — then the `mobile` AT
builder/parser layer, which is unusually well symbolized because the shipped
binary retains log strings and `__FILE__` paths. Only below that does the
RIL/ACIPC transport matter. Whether `AT*BAND` remains textual across the AP/CP
link or becomes an ACIPC binary message is still unresolved, and the specific
ACIPC message ID beneath it was not recovered. The CP image is currently useful
for vocabulary and assertions but not for control flow, because its load base is
not established and no self-consistent base could be derived from string
pointers.
