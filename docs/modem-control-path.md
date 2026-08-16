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

## The CI primitive layer as a control surface

Because AT text stops at `atcmdsrv`, the CI primitive set — not the AT vocabulary
— is the real AP/CP control surface. `atcmdsrv` carries the whole enumeration as
name tables, one array per service group, extracted in
[`ci-primitives.json`](../analysis/ci-primitives.json):

| Group | Table VA | Entries |
| --- | --- | ---: |
| `CI_CC` | `0x0b1d54` | 165 |
| `CI_DAT` | `0x0b1fec` | 30 |
| `CI_DEV` (+ `CI_ERR`) | `0x0b2068` | 255 |
| `CI_MM` | `0x0b2468` | 196 |
| `CI_PB` | `0x0b277c` | 48 |
| `CI_PS` | `0x0b2840` | 249 |
| `CI_SIM` | `0x0b2c28` | 136 |
| `CI_MSG` | `0x0b2e4c` | 86 |
| `CI_SS` | `0x0b2fe8` | 113 |

A separate `CI_SG_ID` table at `0x0b2fa8` gives the service-group IDs:
`CC`=0, `SS`=1, `MM`=2, `PB`=3, `SIM`=4, `MSG`=5, `PS`=6, `DAT`=7, `DEV`=8,
`HSCSD`=9, `DEB`=10, `ATPI`=11, `PL`=12, `OAM`=13. The `CI_DEV` array holds that
group at indices 0–245 and then `CI_ERR` at 246–254; `CI_ERR` has no table of its
own.

`CI_DEV_PRIM_SET_BAND_MODE_REQ` is index 50 in the DEV group, its `_CNF` 51, and
the `GET`/`GET_SUPPORTED` pairs follow at 52–55.

The numeric on-wire ID is still unknown, and one plausible encoding was tested
and **refuted**. If IDs were `(group << 8) | index`, the compiler would hold a
biased table pointer of `table − 4·(sg<<8)`; for DEV that is
`0x0b2068 − 0x2000 = 0x0b0068`, and a word with exactly that value does exist at
VA `0x7ad10`. But `0x0b0068` turns out to be the address of the string
`mrvl_gps_integrity_test`, inside an unrelated AT handler — a collision, not an
encoding. Only 1 of 9 groups matched at that shift, and shifts 9, 10, 12 and 16
produced nothing better. None of the ten tables is reached by an absolute
pointer, a PIC pair, or a `movw`/`movt` immediate, so the indexing code remains
unlocated.

## Network-selection results, closed

Record 84's enumeration is confirmed from two independent directions. The shipped
frontend defines it outright — `idle:0, registering:1, registered:2, searching:3,
searchFinish:4, search_generic_failure:5, register_generic_failure:6,
register_denied_by_network:7, register_illegal_sim_or_me:8, saving:9, saved:10,
canceling:11, canceled:12, search_failure_sending_sms:13` — and enumerating the
fifteen call sites of the daemon's single setter at VA `0x425ec` recovers the
immediates `0`, `2`, `3`, `4`, `5`, `10`, `11`, `12`, `13`, with two sites passing
a computed register.

The three states that block `SetPrefNetType` and `SetNetSel` are exactly `1`
registering, `3` searching and `11` canceling — each with its own refusal string.

That leaves value `13`, `search_failure_sending_sms`, which closes the last open
question about the pre-flight gate. Record 19 is the SMS send status: the
decisive evidence is that `GetAvailableNet` reads record 19 *alone*, and its
failure message is literally *"Retriving sms sending status data failed."* So an
in-flight SMS send blocking a network operation is not an inference — it is a
condition the firmware models and names. `GetAvailableNet` gates on record 19
only; the two setters gate on both 19 and 84.

## The AT-to-CI translation, recovered

The last gap in the AP-to-CP chain is closed. `atcmdsrv`'s `AT*BAND` handler at
`0x3813c` — reached from the command table entry at `0x0db8ac`, which also
records that the command takes nine parameters — converts the textual `NwMode`
into the CI pair `(networkMode, preferredMode)` through a plain switch. Each arm
falls into one of two builders that emit `CI_DEV_PRIM_SET_BAND_MODE_REQ`.

| AT `NwMode` | CI `networkMode` | CI `preferredMode` | Meaning |
| ---: | ---: | ---: | --- |
| 0 | 0 | 0 | GSM only |
| 1 | 1 | 1 | UMTS only |
| 2 | 2 | 2 | GSM+UMTS, no preference |
| 3 | 2 | 0 | GSM+UMTS, prefer GSM |
| 4 | 2 | 1 | GSM+UMTS, prefer UMTS |
| 5 | 3 | 3 | LTE only |
| 6 | 4 | 4 | GSM+LTE, no preference |
| 7 | 4 | 0 | GSM+LTE, prefer GSM |
| 8 | 4 | 3 | GSM+LTE, prefer LTE |
| 9 | 5 | 5 | UMTS+LTE, no preference |
| 10 | 5 | 1 | UMTS+LTE, prefer UMTS |
| 11 | 5 | 3 | UMTS+LTE, prefer LTE |
| 12 | 6 | 6 | all, no preference |
| 13 | 6 | 0 | all, prefer GSM |
| 14 | 6 | 1 | all, prefer UMTS |
| 15 | 6 | 3 | all, prefer LTE |
| omitted (240) | 6 | 1 | all, prefer UMTS |

The `NwMode` parameter is parsed with range `0..30` and default `240`. Values
`16`–`30` pass the range check and then fall out of the switch into the CME error
path, so the parser is more permissive than the dispatcher.

### This settles the RAT enum by itself

The table proves the individual assignment that the CP assertions could only
constrain as a set. Read the multi-RAT rows: `preferredMode` 0 is offered for
`networkMode` 2, 4 and 6; `preferredMode` 1 for 2, 5 and 6; `preferredMode` 3 for
4, 5 and 6. Under the bitmask-minus-one reading those are exactly the
combinations containing GSM, UMTS and LTE. The intersection is unique, so

    CI_DEV_NW_GSM = 0,  CI_DEV_NW_UMTS = 1,  CI_DEV_NW_LTE = 3

is now **confirmed**, not inferred, and `networkMode` is confirmed as the RAT
bitmask minus one with GSM=1, UMTS=2, LTE=4.

The four values the daemon actually sends read cleanly in this light:
`AT*BAND=0` is GSM only, `=1` UMTS only, `=5` LTE only, and `=11` UMTS+LTE
preferring LTE — the "auto" policy.

### The remaining eight parameters

Parameters 1–4 are the four band masks and 5–8 are selectors. Their AT-side
bounds were recovered independently of the CP, and they match its validation
exactly: parameter 5 has range `0..2` against the CP's `< 3`, parameter 6 has
`0..4` against `< 5`, and parameter 7 has `0..2` against `< 3`. Two independently
recovered sides of a boundary agreeing on three arbitrary bounds is about as
strong as static evidence gets.

Parameter 7 is only forwarded when the requested mode includes LTE; for
`NwMode` 0–4 the builder substitutes 0.

## The numeric CI primitive encoding

The wire encoding is confirmed, and it is simpler than the hypothesis that was
refuted last phase. There is no packing at all: `(service group, primitive id)`
travel as two separate wire fields, and

> the numeric primitive id is the 1-based index into that service group's own
> name table.

The tell is that every group table's slot 0 holds the same pointer — a shared
empty string — and the dispatcher at `0x7ddec` loads each table from a base
biased by −4 and indexes it with the raw primitive id. A previous revision of
the catalogue counted that placeholder as entry 0, which is why the indices
recorded there were all one too low.

`CI_ERR` is a separate global range, not part of DEV as previously recorded.
The dispatcher tests `primId <= 0xF007` before it ever looks at the service
group, and indexes a table of its own. That also explains a loose end from the
CP side: the handler's `0xF001` failure code is not an ad-hoc error number, it
is `CI_ERR_PRIM_HASINVALIDPARAS_CNF`.

Service groups are numbered from 1: CC=1, SS=2, MM=3, PB=4, SIM=5, MSG=6, PS=7,
DAT=8, DEV=9, HSCSD=10, DEB=11, ATPI=12, PL=13, OAM=14.

The anchor resolves to:

| Primitive | Group | Id | Payload |
| --- | ---: | ---: | ---: |
| `CI_DEV_PRIM_SET_BAND_MODE_REQ` | DEV = 9 | 51 (`0x33`) | 32 |
| `CI_DEV_PRIM_SET_BAND_MODE_CNF` | DEV = 9 | 52 (`0x34`) | 4 |
| `CI_DEV_PRIM_GET_BAND_MODE_REQ` | DEV = 9 | 53 (`0x35`) | 0 |
| `CI_DEV_PRIM_GET_BAND_MODE_CNF` | DEV = 9 | 54 (`0x36`) | 28 |
| `CI_DEV_PRIM_GET_SUPPORTED_BAND_MODE_REQ` | DEV = 9 | 55 (`0x37`) | 0 |
| `CI_DEV_PRIM_GET_SUPPORTED_BAND_MODE_CNF` | DEV = 9 | 56 (`0x38`) | 28 |

Five of those numbers appear as literal immediates in code on both sides of the
boundary — `0x33`, `0x35` and `0x37` emitted by AP builders, `0x34` and `0xF001`
emitted by the CP handler — and the payload sizes come from a separate set of
per-group `u16` tables that the AP consults when allocating. The size table says
32 for primitive 51; the builder allocates `0x20`. Nothing here rests on a single
coincidence.

One trap worth naming: `CI_DEV_PRIM_SET_BAND_MODE_REQ` is primitive `0x33` and
the AP's preferred-RAT `CMobileEvent` is also `0x33`. They are unrelated numbers
in unrelated namespaces.

## How a CI primitive actually reaches the CP

`/dev/msocket` is the message transport. `/dev/acipc` and `/dev/cpmem` are
referenced by `atcmdsrv` but not from this path, and are not interchangeable
with it. The payload is copied inline into a single socket write; nothing on
this path hands the CP a shared-memory pointer.

The buffer that gets written is:

| Offset | Size | Field |
| --- | ---: | --- |
| `0x00` | 4 | envelope tag, constant 1 |
| `0x04` | 4 | envelope type, constant 4 for CI primitives |
| `0x08` | 4 | inner length, `0x10 + payloadLen` |
| `0x0c` | 4 | service group id |
| `0x10` | 2 | primitive id |
| `0x12` | 2 | pad |
| `0x14` | 4 | request handle |
| `0x18` | 4 | reserved, never written on this path |
| `0x1c` | … | primitive payload |

The primitive id is 16-bit on the wire, which is what makes the `0xF000` error
range representable alongside small per-group ids.

The request handle is built in the AT handler prologue from a wrapping 12-bit
counter — which wraps `0xfff` to `0x0b`, not to 0 — and the builder then
overwrites bits 20–23 with the CI `networkMode` for the setter, or with the
literal primitive id for the two getters. Why those bits are overloaded is
unresolved.

## The CP dispatch table

With the base fixed, the CP side resolves cleanly. The DEV request dispatcher is
a flat table at ARBI `0x06f394fc`: 76 entries of `{u32 primId, u32 handler|1}`.
Primitive `0x33` pairs with `0x068afdf1`, and every one of the 76 ids resolves to
a `CI_DEV_PRIM_*_REQ` name under the confirmed numbering — including `0x47`,
`CI_DEV_PRIM_ENABLE_HSDPA_REQ`, which is precisely the primitive the AP's size
function special-cases.

Confirmations are emitted from a second, separate table around `0x06f39840`
whose ids are CP-internal signal numbers near `0x00090c1b`, not CI primitive ids.
`CI_DEV_PRIM_GET_BAND_MODE_CNF` is built there, which fits a request that has to
wait on lower layers before it can answer.

## A correction to the SET_BAND_MODE handler reading

The handler validates `networkMode < 7`, `preferredMode < 7`, and the three
selectors at `+0x14`, `+0x15`, `+0x16`, then branches on the operation selector
at `+0x18`. The earlier description of that branch was incomplete in a way that
matters:

- `0` or `5` → GSM band branch
- `1` or `2` → UMTS band branch
- `3` → the RAT mode-change branch, and **only** this branch contains the
  `networkMode`/`preferredMode` assertions at lines 3760 and 3767
- anything else → assertion failure at line 3789

The AT`*`BAND path always sends `0`. So the assertions that were previously
treated as the primary evidence for the CI RAT enum are not on the AT`*`BAND path
at all; they corroborate the enum rather than establishing it. The enum now rests
on the AP-side translation table instead, which is stronger.

Two further field results: `+0x17` is **never read** by the CP handler and is
always sent as 0 by the AP, yet the AT read response reports it — so the field
exists in the structure but nothing in this firmware assigns it meaning. `+0x18`
is likewise always 0 from AT, meaning the RAT-change branch is reachable only
from some other CI sender that was not located.

## The readback path, and a sixth numeric space

`CI_DEV_PRIM_GET_BAND_MODE_CNF` is built at ARBI `0x068b0156`, and it contains an
explicit translation table — `tbb` bytes `03 05 07 09 0f 0d` at `0x068b0192` and
again at `0x068b01c2` — that converts a CP-internal RAT state into the CI value:

    internal 0→0, 1→1, 2→3, 3→2, 4→4, 5→5, ≥6→6

Internal 2 and 3 swap places relative to CI. Combined with the CI encoding, that
fixes the CP internal ordering as singletons first and then pairs: GSM, UMTS,
LTE, GSM+UMTS, GSM+LTE, UMTS+LTE, all. Every pair position agrees with the
bitmask reading, which is a fully independent corroboration of the CI
assignment.

This is a sixth distinct numeric space for the same concept, and it differs from
the CI space only in where LTE sits — the kind of difference that would be very
easy to conflate silently.

## `0x3081`, closed

The constant lives in the AP readback normalizer at `mobile 0x4a254`, entry 11 of
the modem-status handler table at `0x68b9c`, which writes record 75. The whole
normalizer is:

    modem 1 → 0,  2 → 1,  3 → 2,  0 → 3,  0x3081 → 3,  anything else → 3

The `0x3081` branch produces the same result as the default branch, so deleting
the comparison would not change behaviour. The constant is never masked, shifted
or added to — only compared for equality, exactly once. A sweep of the whole
userspace stack finds a single ARM `movw` in `mobile` and zero occurrences in
`atcmdsrv`, `libmobile` or `libdata_management`; it is absent from the CP image
too.

So the honest answer is that `0x3081` encodes nothing this firmware acts on. Its
bit structure cannot be recovered because no code decomposes it, and its meaning
cannot be recovered because no code distinguishes it. It is recorded as a closed
negative result rather than an open question.
