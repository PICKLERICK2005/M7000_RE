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

## The AP/CP boundary is a CI primitive, not AT text

`AT*BAND` does **not** stay textual across the AP/CP link. It is parsed on the
AP and converted into a binary CI (Common Interface) primitive. The evidence is
one-sided enough to state plainly:

```text
mobile                 ASCII AT text, 512-byte buffer, sender at VA 0x3f6a4
  -> /tmp/atcmd        ASCII, CR-terminated AF_UNIX stream
  -> atcmdsrv          AT parser + command server
                       '*BAND' token at VA 0x98eea, dispatch entry at VA 0xdb8ac,
                       Thumb handler at VA 0x3813c
  -> NECCI / CCI stub  binary CI primitive with primId + reqHandle
                       CI_DEV_PRIM_SET_BAND_MODE_REQ / _CNF
  -> /dev/msocket, /dev/acipc, /dev/cpmem   shared-memory transport
  -> CP                pSig->networkMode / pSig->preferredMode
  -> L1CSetRat
```

What makes this decisive is the *absence* on the CP side. The CP image contains
no `*BAND` command token and no `CI_DEV_PRIM_*` name strings whatsoever; a sweep
of the entire CI/CCI/msocket vocabulary across all 7.7 MB returns a single
unrelated hit, `BAND_MODE_CHANGE`. Its handler asserts on struct fields
(`pSig->preferredMode == pSig->networkMode`), never on parsed text. Meanwhile
`atcmdsrv` holds the complete 249-entry `CI_DEV_PRIM_*` enumeration, the CI
client stub (`ciClientStubInit`, `ciStubEventHandler`,
`clientCiConfirmCallback_transfer: primId:%d;tem->reqHandle:0x%x;...`), and every
shared-memory device node. The `AT*BAND` in the CP log string names the
originating command, not the wire format.

The primitive name table sits at `atcmdsrv` VA `0xb2068`, 255 entries, index 0 =
`CI_DEV_PRIM_STATUS_IND`. `SET_BAND_MODE_REQ` is index 50, `_CNF` 51,
`GET_BAND_MODE_REQ` 52, `_CNF` 53. The numeric wire ID remains unknown: no
absolute, PIC, or Thumb `movw`/`movt` reference to the table base was found, so
the code that indexes it was not located and any group encoding is unrecovered.

Two AP components sit alongside this. `libmarvellril.so` is a RIL implementation
that *also* formats `AT*BAND` text, in richer forms than `mobile` uses
(`AT*BAND=%d,%d,%d` through `AT*BAND=%d,%d,%d,%d,%d,2,4,%d`), and references
`/tmp/atcmd`, `/tmp/atcmdni`, `/dev/mux1`-`6` and `/dev/ttyHSI3`. `libril.so`
carries `RIL_REQUEST_SEND_ATCMD`, `RIL_REQUEST_SET_BANDMODE`,
`RIL_REQUEST_GET_BANDMODE` and `RIL_UNSOL_BANDIND`. `rild` and `atcmdsrv` are
separate processes in `/etc/telinit`; which one serves `/tmp/atcmd` in the
running system is supported by the `atcmdsrv` AT-server evidence but was not
confirmed live.

## The six-field AT*BAND builder is a defect, not a decoding artifact

The anomalous builder at VA `0x3336c` is now explained, and it is **not**
promoted to the active path.

Disassembly-mode confusion is ruled out: the enclosing function decodes
coherently as ARM end to end - prologue, four-entry jump table, matching
epilogue. Literal-pool misinterpretation is ruled out: the pool word at
`0x33470` is `0x1fde4`, and `0x333d8 + 8 + 0x1fde4` is exactly `0x531c4`, where
the format string lives.

The explanation is an argument-order defect, and the AT+COPS builder proves it.
At VA `0x33830` the same `snprintf` stub is called correctly: `r0` = buffer,
`r1` = `0x200` size, `r2` = format, `r3` = first vararg, second on the stack.
Builder B instead sets `r0` = buffer, `r1` = format, `r2` = mode, `r3` = flag -
the `sprintf(buf, fmt, a, b)` argument list, shifted one register left, while the
call still resolves through GOT slot `0x68dcc` to `snprintf`. Both `sprintf` and
`snprintf` are imported separately, so this is not symbol aliasing. Because `r1`
then holds a pointer rather than `0x200`, the compiler's `cmp r1,#0x200 / bhi`
bound check is unsatisfiable and the `udf` trap always fires.

Neither builder has a direct `bl` call site; both are reached through a
function-pointer table (builder A at index 25, builder B at index 26), and no
control-flow evidence selects builder B. Its value mapping is recorded for
completeness but should not be read as describing commands the device emits.

## Network selection: MP_NetSel decoded

The 56-byte event `0x34` payload is `MP_NetSel` copied verbatim - libmobile
spills `r1`-`r3` to `sp+0x94`, the caller supplies bytes 12-55 above that, and
four `ldm`/`stm` pairs move all `0x38` bytes into the payload buffer with no
transformation. Every byte is now accounted for:

| Offset | Size | Field | Notes |
| ---: | ---: | --- | --- |
| `0x00` | 4 | `mode` | `0` automatic, `1` manual, `2` deregister |
| `0x04` | 4 | `mcc` | `%u` in `AT+COPS=1,2,"%u%02u"`; record 447 |
| `0x08` | 4 | `mnc` | `%02u`; record 448 |
| `0x0C` | 44 | `operator_name` | string pointer; record 446 |

`4 + 4 + 4 + 44 = 56`, so no unknown fields remain. There is no RAT or
access-technology field, which matches the daemon never emitting an `<AcT>`
argument to `AT+COPS`.

Mode `2` is worth noting: the libmobile client range-checks the field against
`1`, so deregister is rejected by the public API and is reachable only inside
the daemon, which emits `AT+COPS=2` for it.

After building the manual-selection command the same routine writes records 446,
447, 448 and 76 and commits all four permanently in one call at VA `0x338a8`.
Network selection therefore persists four records atomically from the AT layer -
the opposite arrangement from preferred RAT, where the event handler persists a
single record. The shipped frontend model corroborates the field set:
`networkSelectionMode`, `networkSelectionStatus`, and an `operatorList` whose
entries carry `operatorNumeric`, `operatorAlphaShort` and `operatorState`.

## Record 78: signal normalization located

The record-78 handler copies its input verbatim, so the normalization is
upstream - in `src/comm/manager_comm_at.cpp`. It is RAT-dependent, selected by
the current network type staged at status-object offset `0x190`: value `2` takes
the `+CSQ` path, value `3` takes the `*CESQ` path.

Three normalization functions were recovered:

- **`0x3a4c8`, CSQ to level.** `0-2` or `99` gives `0`; `3-4` gives `1`; `5-7`
  gives `2`; `8-11` gives `3`; `12` and above gives `4`. The `99` case is 3GPP's
  "not known or not detectable". These breakpoints are firmware-specific - this
  is *not* the generic CSQ-to-bars mapping.
- **`0x3a50c`, dBm to level.** Outside `-120..-25` gives `0`; `>= -48` gives `4`;
  `>= -72` gives `3`; `-96..-73` gives `2`; `<= -97` gives `1`. No direct call
  site was found, so its reachability in this build is unknown.
- **`0x3a550`, LTE composite.** It computes an RSRP-derived level (`>= -98` to 4,
  `>= -108` to 3, `>= -118` to 2, `>= -128` to 1, else 0, with `>= -43` as an
  invalid marker) and an SNR-derived level (SNR x10 `> 129` to 4, `> 44` to 3,
  `> 9` to 2, `>= -30` to 1), then returns the **minimum of the two**. If RSRP is
  the invalid marker the SNR level is used alone; if SNR is out of range it falls
  back to a CSQ-style table on the raw first field.

So record 78 is a 0-4 bars level, RAT-dependent, and on LTE genuinely composite -
derived from RSRP and SNR together, not from any single metric. It is not a
percentage.

The unit conversions feeding records 200-205 came out alongside: `rssi = 2*csq -
111` on the CSQ path, and on `*CESQ`, field 5 becomes `x/2 - 20` (the 3GPP RSRQ
formula, record 203), field 6 becomes `x - 141` (the 3GPP RSRP formula, record
202), and field 7 becomes `x * 10` (record 204). The AT layer stages a six-word
struct - `rat`, `rssi`, `rsrp`, `rsrq`, `snr`, `ecio` - matching records 200-205
in order.

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
binary retains log strings and `__FILE__` paths, and then `atcmdsrv`, which is
where AT text becomes a CI primitive and is therefore the real AP/CP semantic
boundary. Raw ACIPC framing is the *least* productive layer to attack, because
the CI primitive layer sitting above it is fully symbolized by name.

The CP load base is now established at `0x06800000`, so CP cross-referencing is
no longer blocked in principle. What remains missing there is not the base but
call-graph anchors: the CP is mixed ARM/Thumb with interleaved literal pools, and
its assertion strings are not reached by plain absolute pointers, so locating a
specific handler still requires per-case work rather than a global sweep.
