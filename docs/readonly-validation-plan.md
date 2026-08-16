# Read-Only Physical Validation Plan (Phase 1)

**Status: NOT EXECUTED.** This document defines a plan. Nothing in it has been run,
and it must not be run without an explicit decision to begin.

## 1. Purpose and limits

The AP-to-CP control path has been reconstructed statically end to end. Phase 1 exists
to answer one question and no others:

> Does the device, observed only through stock management paths, behave as the static
> model predicts?

It is deliberately **not** an attempt to reach the CI layer. No CI primitive is sent,
no `/dev/msocket` traffic is generated or observed, and no diagnostic mode is enabled.
Every observation is made through interfaces the shipped product already exposes to a
normal user.

### Explicitly out of scope for this phase

Sending any CI primitive; issuing any AT command directly; writing any record; changing
RAT, bands, network selection, APN, data switch or roaming policy; SMS; NVM access;
CATStudio/ICAT; USB experiments of any kind; Fastboot; firmware writes; UART or shield
removal.

## 2. Why the getters were chosen

`GET_BAND_MODE` (DEV 53) and `GET_CURRENT_OPERATOR_INFO` (MM 32) are the reference
targets because both have a **zero-byte request payload** — confirmed from the CI size
tables — so neither can carry a value that changes state, and both have fully recovered
confirmation layouts to check answers against.

They are *not* invoked directly. They are reached only as the incidental consequence of
a stock read, which is what makes this phase read-only in the strong sense: the only
thing under our control is a management-interface GET.

## 3. Pre-state requirements

Record before anything else, from the stock web UI only:

| Item | Why it matters |
| --- | --- |
| Firmware version and build | The whole static model is tied to 3.0.2 Build 241129 Rel.3n |
| Preferred network type (UI) | Must be unchanged at the end; the AT+COPS=0 coupling makes this the field most at risk |
| Network selection mode (UI) | Record 76's overlay has no rollback path |
| Registered operator and signal bars | Baseline for the derived values |
| Battery level, uptime | Rules out a reboot or power event confounding a reading |
| SIM present / locked state | Several paths gate on SIM readiness |

Preconditions: device idle, no SMS being sent (record 19 gates the selection setters
and state 13 exists precisely for that case), no active data transfer, mains power
connected, and no configuration change in the preceding five minutes.

Take the pre-state twice, at least sixty seconds apart, and require the two to agree.
A field that moves on its own before the test has begun invalidates any inference drawn
from it afterwards.

## 4. The read-only requests

All requests are stock management-interface reads issued from an ordinary authenticated
browser session. No custom RPC, no undocumented parameter, no direct socket.

| # | Action | Repetitions |
| ---: | --- | ---: |
| R1 | Load the status/overview page | 3, at 60 s spacing |
| R2 | Load the network-settings page (shows selection mode and preferred network type) | 2 |
| R3 | Load the SIM/device information page | 1 |
| R4 | Re-load the status page after 5 minutes idle | 1 |

Nothing is submitted. No form is saved. If any page presents a confirmation dialog, the
test stops.

## 5. Predicted internal path

For R1 and R2, the prediction is that the read is served entirely from shared records
and does **not** reach the CI layer at all:

```
browser GET
  -> web_cgi / auth_cgi
  -> rpmServer
  -> libmobile getters
  -> libdata_management shared records (75, 76, 78, 79, 81, 83, 84, 200-207, 446)
  -> response
```

The static evidence for that is direct: none of the eight `GetAllStatus` component
getters constructs a `CMobileEvent`, and the refresh model is event-driven — the modem
pushes, the web read does not pull.

The CI getters appear on a different, *asynchronous* path that the daemon runs on its
own schedule:

```
mobile status refresh
  -> AT+COPS?           -> atcmdsrv 0x18e2c (type 2) -> 0x1b518
                        -> MM 32 GET_CURRENT_OPERATOR_INFO_REQ, 0-byte payload
                        -> msocket -> CP -> CNF 33 (80 bytes)
                        -> RX dispatcher 0x7ee28 -> MM handler 0x01fd28
                        -> +COPS: <mode>,<format>,"<oper>",<AcT>
                        -> mobile -> records 76 / 446

  -> AT*BAND?           -> atcmdsrv 0x3813c (type 2) -> 0x40c90
                        -> DEV 53 GET_BAND_MODE_REQ, 0-byte payload
                        -> CP 0x068afbf6, CNF 54 (28 bytes) built at 0x068b0156
                        -> internal RAT state translated 0,1,3,2,4,5,6 -> CI space
                        -> mobile record 75
```

So the concrete prediction is: **the web reads are projections of state the daemon
refreshed earlier, not triggers.** That is the single most testable claim in the whole
static model.

## 6. Success criteria

The phase succeeds if all of the following hold:

1. **Stability.** Every field in the pre-state list is identical before and after. Any
   change to preferred network type or selection mode is an outright failure, not a
   curiosity.
2. **Consistency.** The three R1 samples agree except for fields the model says are
   event-driven (signal level, registration state). Those may move; policy fields may
   not.
3. **Enum conformance.** Preferred network type reads as one of the four UI policy
   values; selection mode reads as automatic or manual only — consistent with record 76
   being booleanised by the readback writer at `0x4a350`.
4. **Operator plausibility.** The displayed operator is self-consistent across pages,
   and if a numeric PLMN is shown anywhere it is a valid MCC/MNC — which, given the BCD
   encoding, means it must contain no hex digits a–f.
5. **No latency signature.** R4 after five minutes idle returns without a visible delay
   attributable to a modem round trip, supporting the "read is a projection" prediction.

## 7. Failure criteria — stop immediately

- Any policy field differs from pre-state.
- Selection mode reads a value other than automatic or manual.
- Record-84-derived workflow state appears non-idle without a user action.
- Any page triggers a scan, registration or deregistration.
- The device reboots, drops registration, or loses the SIM.
- A numeric PLMN containing a hex digit appears, which would falsify the BCD reading and
  mean the static model is wrong somewhere it was believed confirmed.

On any of these: stop, record the raw observation, and return to static analysis. Do not
attempt a second run to "see if it repeats".

## 8. Sanitization requirements

Nothing leaves the device unsanitized. Before any capture is committed:

- **Never record**: IMEI, IMSI, ICCID, MSISDN, SIM serial, WAN IP, exact GPS/cell
  identifiers, session cookies, CSRF tokens, admin password or its hash.
- **Redact**: operator name and MCC/MNC to a placeholder if the goal is only to confirm
  *shape*; record only "valid 3-digit MCC, 2-digit MNC" rather than the digits.
- **Redact**: LAN addresses, MAC addresses, hostnames, and the device's own SSID.
- **Keep**: enum values, field presence/absence, ordering, timing, HTTP status codes,
  and structural shape.
- Run the repository's existing sensitive-pattern scan over any new capture before it is
  staged, and treat a hit as blocking.

Captures go under `captures/` with a note stating which fields were redacted and why —
never a raw dump "to be cleaned later".

## 9. What this phase does not establish

Success here does **not** authorize a write phase. It confirms the read model only. Two
findings block writes independently of anything Phase 1 could show:

- `AT+COPS=0` resets the RAT policy to all-RAT before registering, so any
  network-selection write perturbs the preferred-RAT state.
- Record 76 has no rollback: its workflow commit is non-persistent and a stale overlay
  is corrected only when the modem readback next arrives.

Both would need a designed recovery procedure before any write is contemplated, and
that design is not part of this phase.
