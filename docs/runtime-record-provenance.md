# Runtime Record Provenance

This note is the human-readable index for the canonical tuples in
[`analysis/runtime-record-provenance.json`](../analysis/runtime-record-provenance.json).
It covers the records that feed the composite modem status, the two validated
narrow WAN getters, and the derived connection-failure model in exact firmware
`3.0.2 Build 241129 Rel.3n`.

## Address convention

`mobile+0xOFFSET` is a byte offset from the beginning of `usr/bin/mobile`, not
an address from a running physical router. The first executable `PT_LOAD` has
ELF virtual address `0x10000`, so an instruction at ELF VA `0x49ef8` is recorded
as `mobile+0x39ef8`. Tuple writer locations identify the call to the common
data-management write wrapper unless a routine range is stated.

## Provenance index

| Record | Meaning | Principal writer | Trigger | Source | Persistence | Important consumers |
| ---: | --- | --- | --- | --- | --- | --- |
| 30 | Flow-limit enabled | `libflowstat.so` `enableLimit` (`0x1938`) | Flow-limit configuration | AP policy | Persistent | `judgeLimit`, `GetCallFailReason` |
| 39 | Limit threshold state | `libflowstat.so` `reachLimit` (`0x1dd8`) | Periodic byte accounting | `ccinet1` counters plus flow policy | Persistent | `judgeLimit`, `GetCallFailReason`, OLED warning |
| 44 | Allow dial once | `libflowstat.so` `allowDialOnce` (`0x1c14`) | Explicit current-boot override | AP flow-limit workflow | Runtime/current boot | `judgeLimit`, `GetCallFailReason` |
| 73 | Mobile-data switch | `mobile+0x3238c` | Setter/configuration | AP policy | Persistent | `GetDataSwitch`, `GetAllStatus`, `wan:0`, backhaul FSM |
| 74 | Roaming switch | `mobile+0x3243c` | Setter/configuration | AP policy | Persistent | `GetRoamSwitch`, `GetAllStatus`, `GetCallFailReason`, backhaul FSM |
| 75 | Preferred network type | `mobile+0x3a2b0`, `mobile+0x3256c` | Reconciliation and setter | Stored preference plus modem response | Persistent plus temporary overlay | `GetPrefNetType`, `GetAllStatus`, `wan:0` |
| 76 | Automatic/manual selection mode | `mobile+0x238a8`, `mobile+0x3a35c`, `mobile+0x325e0` | Selection configuration/workflow | AP policy plus modem workflow | Persistent plus temporary overlay | `GetNetSelMode`, `GetAllStatus`, `wan:0` |
| 78 | Signal level | `mobile+0x3a170` | Signal/status callback | AT-derived signal quality | Runtime | Signal/status presentation, OLED |
| 79 | Connection state | `mobile+0x3a10c` | Backhaul FSM/event | Connect/disconnect and `+CGEV` | Runtime | `GetConnState`, `GetAllStatus`, `GetCallFailReason`, `wan:0`, `status:0` |
| 80 | Roaming state | `mobile+0x39ef8`, `mobile+0x39fdc` | Registration/roaming callback | Registration AT results | Runtime | `GetRoamStat`, `GetCallFailReason`, `status:0` |
| 81 | Registration state | `mobile+0x39ef8` | Indication/query/startup | `CGREG`/`CREG`/`CEREG` | Runtime | `GetRegStat`, `GetAllStatus`, `GetRoamStat`, `GetCallFailReason`, `status:0` |
| 82 | Current network type | `mobile+0x39828` | AT status update | Network/system AT information | Runtime | `GetNetType`, `status:0` |
| 83 | Service status | `mobile+0x39a50`, `mobile+0x39ef8` | Registration state machine | AT-derived status | Runtime | Internal status/backhaul logic, presentation |
| 84 | Network-selection operation status | `mobile+0x32658` | Selection FSM | Modem-selection workflow | Runtime | `GetNetSelStat`, `wan:10` |
| 446 | Selected ISP name | `mobile+0x238a8` | Selection configuration/result | AP ISP metadata | Persistent | `GetSelIspName`, `GetAllStatus`, `wan:0` |

The `tp_data` record table and `libflowstat.so` exports resolve the complete
flow-limit tuple. Record 30 is the persistent `limit_enabled` switch. Record 39
is persistent `limit_reached`: `0` below warning, `1` warning threshold, and
`2` hard limit. Record 44 is temporary `allow_dial_once`, explicitly scoped to
the current boot. Thus `30 == 1 && 39 == 2 && 44 == 0` means exactly “limiting
enabled, hard limit reached, and no one-boot override.” The flowstat daemon
derives record 39 from `ccinet1` byte counters and the configured threshold,
warning percentage, monthly/free-duration policy; none of the three values is
CP or modem state.

The profile family (`47`, `48`, `51`, `52`, `61`-`64`, dynamic user records,
and ISP records starting at `65`) is also represented. Its read expansion and
persistent configuration role are established; exhaustive per-record writer
attribution is the remaining gap.

## Recovered enum semantics

Record 81 is a normalized aggregate, not a raw registration value. The
AT-facing object retains three raw domain states. Raw values `0..5` are handled
as not-registered/not-searching, registered-home, searching, denied,
unknown/not-registered, and registered-roaming. The normalizer at
`mobile+0x39ab0-mobile+0x39f24` then emits:

| Record 81 | Meaning |
| ---: | --- |
| 0 | Not registered |
| 1 | Registered on the primary packet-service domain |
| 2 | Searching, or registered on the secondary service domain |
| 3 | Registration denied |

Value `2` therefore collapses two internal conditions. Record 80 is derived
separately: any retained raw registration value of `5` makes it roaming. Record
83 is the parallel service-status field: `0` no service, `1` limited service,
`2` available, and `3` limited area. Record 78 is likewise no longer anonymous:
it is the normalized signal level (`0` none/unknown through `4` great).

Record 79 and the shipped UI share `0` disabled, `1` disconnected,
`2` connecting, `3` disconnecting, and `4` connected. The real `BackHaulFsm`
at `mobile+0x364bc-mobile+0x37004` dispatches all five states and covers
enable/disable, connect, completion, failure, automatic retry, disconnect, and
profile-change reconnect paths.

Record 84 is independently named by frontend and backend evidence: `0` idle,
`1` registering, `2` registered, `3` searching, `4` search-finished, `5` search
failure, `6` registration failure, `7` denied, `8` illegal SIM/ME, `9` saving,
`10` saved, `11` canceling, `12` canceled, and `13` search blocked by SMS
activity. This operation enum is separate from record 76's persistent
automatic/manual policy and temporary workflow overlay.

Preferred-network record 75 exposes a numeric-space boundary. Configured UI
values are `1` = 3G only, `2` = 4G only, and `3` = 4G/LTE preferred. The
libmobile setter puts that configured scalar unchanged in synchronous event
`0x33`; `mobile` hands it to the modem manager and persists it only if the
request is immediately accepted. The modem read path is event `0x46` and maps
response `1/2/3 -> record 0/1/2`, while `0`, `0x3081`, and other values become
record `3`. Correlation with the CP-side `CI_DEV_NW_GSM/UMTS/LTE` assertion
identifies response `1` as GSM (hidden record 0), `2` as UMTS and `3` as LTE.
That readback space is *not* the `AT*BAND` `NwMode` space: the values actually
sent are `0`, `1`, `5` and `11` (default `99`), and the values the response
parser recognises are `0`, `4`, `5`, `8`, `11` and `15`. `0x3081` occurs only
in the readback normalizer, only as an equality comparison, and nowhere in the
CP image; its bit structure is unresolved and no evidence supports calling it a
mask. See [`modem-control-path.md`](modem-control-path.md) and
[`analysis/modem-control-paths.json`](../analysis/modem-control-paths.json).

Record 75 has exactly one permanent writer (commit ELF VA `0x4256c`) and one
temporary normalizer (commit `0x4a2b0`). Persistence happens only after the
modem-manager operation returns success, so a rejected request never becomes
durable policy.

Every numeric record ID in this document resolves through the `usr/bin/tp_data`
name table at file offset `0x1d40` (450 entries, 64-byte stride), indexed in
[`analysis/tp-data-record-map.json`](../analysis/tp-data-record-map.json). That
table independently reproduces every record ID asserted here, and it also names
records `200`-`207` as the raw RF metrics (`rat`, `rssi`, `rsrp`, `rsrq`, `snr`,
`ecio`, `band`, `channel`) that sit alongside the normalized level in record 78.
The record-78 writer copies its input verbatim, so the normalization is upstream
of it and still unlocated.

The dense tables and transition graph are in
[`modem-state-enums.json`](../analysis/modem-state-enums.json) and
[`modem-state-machines.json`](../analysis/modem-state-machines.json).

## Derived disconnect reason

`CMobileClient::GetCallFailReason` at libmobile ELF VA `0xbc2c-0xbe10` takes a
single seven-record snapshot. Its precedence is:

1. Unless `81 == 1` and `79 == 1`, return `0`.
2. If roaming is disabled (`74 != 1`) while roaming is active (`80 == 1`),
   return `1` (roaming-policy disconnect).
3. If `30 == 1`, `39 == 2`, and `44 == 0`, return `2` (flow-limit disconnect).
4. Otherwise return `0`.

## Architectural consequence

The web layer observes a mixture of state classes:

- AP-owned persistent policy: data, roaming, selection mode, ISP/profile data.
- Policy reconciled with runtime modem state: preferred network type and
  selection workflow overlays.
- CP-derived runtime state normalized by `mobile`: registration, roaming,
  network type, connection state, and selection progress.
- Locally derived values: `GetCallFailReason` combines seven records rather than
  reading one modem error scalar.

This distinction must be preserved before considering any writable experiment.
A web-visible integer is not sufficient evidence that the same subsystem owns
its persistence or that changing its underlying record would be safe.
