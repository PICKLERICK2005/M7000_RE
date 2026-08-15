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
| 73 | Mobile-data switch | `mobile+0x3238c` | Setter/configuration | AP policy | Persistent | `GetDataSwitch`, `GetAllStatus`, `wan:0`, backhaul FSM |
| 74 | Roaming switch | `mobile+0x3243c` | Setter/configuration | AP policy | Persistent | `GetRoamSwitch`, `GetAllStatus`, `GetCallFailReason`, backhaul FSM |
| 75 | Preferred network type | `mobile+0x3a2b0`, `mobile+0x3256c` | Reconciliation and setter | Stored preference plus modem response | Persistent plus temporary overlay | `GetPrefNetType`, `GetAllStatus`, `wan:0` |
| 76 | Automatic/manual selection mode | `mobile+0x238a8`, `mobile+0x3a35c`, `mobile+0x325e0` | Selection configuration/workflow | AP policy plus modem workflow | Persistent plus temporary overlay | `GetNetSelMode`, `GetAllStatus`, `wan:0` |
| 78 | Unresolved adjacent mobile status | `mobile+0x3a170` | Status callback | Unknown callback source | Runtime | Internal consumers unresolved |
| 79 | Connection state | `mobile+0x3a10c` | Backhaul FSM/event | Connect/disconnect and `+CGEV` | Runtime | `GetConnState`, `GetAllStatus`, `GetCallFailReason`, `wan:0`, `status:0` |
| 80 | Roaming state | `mobile+0x39ef8`, `mobile+0x39fdc` | Registration/roaming callback | Registration AT results | Runtime | `GetRoamStat`, `GetCallFailReason`, `status:0` |
| 81 | Registration state | `mobile+0x39ef8` | Indication/query/startup | `CGREG`/`CREG`/`CEREG` | Runtime | `GetRegStat`, `GetAllStatus`, `GetRoamStat`, `GetCallFailReason`, `status:0` |
| 82 | Current network type | `mobile+0x39828` | AT status update | Network/system AT information | Runtime | `GetNetType`, `status:0` |
| 83 | Derived service/registration substate | `mobile+0x39a50`, `mobile+0x39ef8` | Registration state machine | AT-derived status | Runtime | Internal status/backhaul logic |
| 84 | Network-selection operation status | `mobile+0x32658` | Selection FSM | Modem-selection workflow | Runtime | `GetNetSelStat`, `wan:10` |
| 446 | Selected ISP name | `mobile+0x238a8` | Selection configuration/result | AP ISP metadata | Persistent | `GetSelIspName`, `GetAllStatus`, `wan:0` |

Records `30`, `39`, and `44` are confirmed inputs to `GetCallFailReason`, but
their individual meanings, writers, and persistence remain unresolved. They are
included as explicit unknown tuples so future write-oriented analysis cannot
accidentally treat an inference as established fact.

The profile family (`47`, `48`, `51`, `52`, `61`-`64`, dynamic user records,
and ISP records starting at `65`) is also represented. Its read expansion and
persistent configuration role are established; exhaustive per-record writer
attribution is the remaining gap.

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
