# Hardware Validation 003 — Forced RAT Transition and Recovery

Date: 2026-08-16. Target: TP-Link M7000(EU) v3.20, firmware 3.0.2 Build 241129 Rel.3n.
Predecessors: [readonly-validation-result.md](readonly-validation-result.md) (no SIM),
[hardware-validation-002.md](hardware-validation-002.md) (SIM-backed, first reversible write).

**Outcome: a preferred-RAT change to `3G Only` was accepted by real hardware, the modem
re-registered on 3G, and restoring `4G Preferred` produced a fully observed
deregistration-and-recovery cycle. Configuration was restored exactly.**

## 1. Objective

Validation 002 changed `4G Preferred → 4G Only` while the device was already on 4G, so
service never dropped and the runtime transition path remained weakly validated. This
test forces the running registration state to become incompatible with the configured
RAT policy, and observes the resulting transition and recovery.

## 2. Independently verified SIM-good state

Before this session the operator independently verified the SIM after validation 002:
M7000 powered off normally, SIM removed, inserted into the operator's normal phone,
recognised normally, normal cellular service, no PIN/PUK or security issue. The SIM was
then reinserted into the M7000. This session therefore starts from a SIM known good
*after* the previous write experiment.

## 3. Method and boundary

Unchanged from validation 002: Wi-Fi to the device's own SSID, stock authenticated
management UI, isolated gitignored Edge profile, operator typing the admin password
directly. No USB, UART, Fastboot, CATStudio/ICAT, `/dev/msocket` tap, ptrace, or
device-side hooks. No hand-crafted RPC, no AT, no CI.

### Observation rate

The stock SPA polls `status:0` **once per ~10 s** on its own. That natural polling was
used as the sole observation source; no reads were forced and the router was not
polled faster than it already polls itself. Reading the in-page observer over CDP
generates no router traffic.

**This bounds timeline resolution to ~10 s.** Intermediate states shorter than that are
not observable here, and their absence is not evidence they did not occur.

### What was deliberately not touched

`PINConfig` was never opened. The `networkSearchSection` control (automatic/manual
selection and scan) sits on the same page as the control under test and was never
operated. No data-switch, roaming, APN or profile setter was issued.

## 4. Phase 0 — fresh baseline

UI showed **4G Preferred**, the required starting condition.

| Field | Baseline |
| --- | ---: |
| `networkPreferredMode` | 3 |
| `networkSelectionMode` | 0 |
| `networkSelectionStatus` | 0 |
| `dataSwitchStatus` | 1 |
| `roamingEnabled` | false |
| `connectStatus` | 4 |
| `registerStatus` | 1 |
| `networkType` | 3 |
| `signalStrength` | 4 |
| `simStatus` | 3 |
| `roaming` | 0 |
| SIM recognised | yes |
| `operatorName` present | yes |
| management UI | stable |

The stock control offered exactly three options — `3 = 4G Preferred`, `2 = 4G Only`,
`1 = 3G Only` — with hidden value 0 not exposed. **`3G Only` was visibly offered as
value 1**, matching the static expectation, so no value was injected manually.

One correction carried into this session: `operatorName` is carried at
`wan.operatorName`, not under `deviceInfo`. An initial probe looked under `deviceInfo`
and wrongly reported it absent. Corrected before the baseline was accepted.

## 5. Phase 2 — forcing 3G Only

The stock page requires two steps for this setter: the section's **Save** button, then a
**Continue** button in a `#disconnectPopup` warning ("the network might be disconnected").

The dropdown widget was driven by clicking its own list item, so the widget and the
underlying `<select>` could not desync — the ambiguity that stopped a write in
validation 002. Both read `3G Only` / value 1 before Save.

### An honest gap in the forward capture

The forward write was performed across two tool invocations: Save was clicked in one,
and the popup was found already dismissed in the next. **The `wan:1` setter carrying
`networkPreferredMode = 1` was not captured in any observation window**, and the exact
moment and trigger of its submission is unknown.

The *effect* is not in doubt — the device's own `wan:0` readback subsequently reported
`networkPreferredMode = 1`, and `networkType` moved from 3 to 2. But the request itself
was not observed, so for the forward direction only the outcome is evidence, not the
submission. Recorded as **inconclusive** for the setter, **confirmed** for the effect.

The restore direction was then performed as a single uninterrupted sequence and *was*
fully captured; it is the authoritative observation of the setter schema.

### Settled 3G-only outcome — Outcome A

Observed over 70 s with no further change:

| Field | Settled on 3G Only |
| --- | ---: |
| `networkPreferredMode` | 1 |
| `networkType` | **2** (was 3) |
| `connectStatus` | 4 |
| `registerStatus` | 1 |
| `signalStrength` | 4 |
| `simStatus` | 3 |
| `roaming` | 0 |
| `networkSelectionStatus` | 0 |
| `networkSelectionMode` | 0 |

3G was available and the modem **registered on it**. `networkType 2` is therefore
confirmed as the 3G/UMTS-associated projection of record 77, distinct from the LTE
value 3. Policy fields other than the intended one did not move — in particular
`networkSelectionMode` stayed 0.

## 6. Phase 5/6 — restoration and re-registration

Restored through the same stock control, in one uninterrupted run. Fully captured:

```
T0        click Save -> #disconnectPopup shown -> click Continue
T0+0.005  request  module "wan", action 1
                   args: action, module, networkPreferredMode = 3, token (redacted)
T0+0.84   response result = 0
T0+0.84   request  wan:0  (frontend's own readback)
T0+5.76   request  status:0
```

This reproduces the validation-002 setter schema exactly, in the opposite direction.

### The transition sequence

| Time | Source | Observation |
| ---: | --- | --- |
| T0+1.1 s | `wan:0` | `networkPreferredMode` **3** applied; `connectStatus` 4 → **1** (disconnected) |
| T0+5.9 s | `status:0` | `registerStatus` 1 → **0** (not registered); `networkType` 2 → **0**; `signalStrength` 4 → **0** |
| T0+25.9 s | `status:0` | `connectStatus` → **4**; `registerStatus` → **1**; `networkType` → **3** (LTE); `signalStrength` → **4** |
| T0+44.8 s | `status:0` | `signalStrength` 4 → 3 |
| T0+65.9 s | `status:0` | `signalStrength` 3 → 4 |

Collapsed per field:

```
connectStatus    4 -> 1 -> 4
registerStatus   1 -> 0 -> 1
networkType      2 -> 0 -> 3
signalStrength   4 -> 0 -> 4
simStatus        3 throughout   (never dropped)
```

Lowest state reached: **`registerStatus 0`, `networkType 0`, `signalStrength 0`** — a
genuine total loss of registration and service, which validation 002 never produced.

Rounded timings, bounded by the ~10 s polling grid:

- setter → preferred-mode readback: **~1 s**
- setter → service loss visible: **≤ 6 s**
- setter → registration and connection recovered on LTE: **> 6 s and ≤ 26 s**

The signal 4 → 3 → 4 movement after recovery is ordinary RF variation, not a policy effect.

## 7. Phase 7 — proof of restoration

| Field | Baseline | Final | |
| --- | ---: | ---: | --- |
| UI label / value | 4G Preferred / 3 | 4G Preferred / 3 | match |
| `networkPreferredMode` | 3 | 3 | match |
| `networkSelectionMode` | 0 | 0 | match |
| `networkSelectionStatus` | 0 | 0 | match |
| `dataSwitchStatus` | 1 | 1 | match |
| `roamingEnabled` | false | false | match |
| `simStatus` | 3 | 3 | match |
| SIM present | true | true | match |
| `operatorName` present | true | true | match |
| `connectStatus` | 4 | 4 | match |
| `registerStatus` | 1 | 1 | match |
| `networkType` | 3 | 3 | match |
| `signalStrength` | 4 | 4 | match |
| `roaming` | 0 | 0 | match |

**Configuration fully restored.** Every configuration invariant matches; the dynamic RF
and network values also happened to return to identical readings, though they were not
required to.

## 8. SIM integrity

| Check | Result |
| --- | --- |
| PIN / PIN2 / PUK / PUK2 interaction | none — no prompt appeared at any point |
| SIM security setter | none — `PINConfig` never opened |
| SIM filesystem / EF / APDU write | none |
| SIM Toolkit / provisioning / identity change | none |
| SIM-stored SMS operation | none — SMS pages never opened |
| SIM recognised throughout | yes — `simStatus 3` in every sample, including during total service loss |
| SIM state after the experiment | recognised, registered, connected on LTE |

`simStatus` remained 3 even at the point where registration, network type and signal
had all dropped to 0, which is itself useful: the service loss was a radio/registration
event and did not disturb UICC presence.

Exactly **two** setter requests were issued this session, both `wan:1`, whose only
non-token argument was `networkPreferredMode` (values 1 then 3). Nothing addressed the
UICC.

## 9. Findings

| # | Finding | Classification |
| --- | --- | --- |
| 1 | `3G Only` is exposed by the stock UI as value 1 | **Confirmed** |
| 2 | Preferred-RAT policy value 1 is accepted by real hardware | **Confirmed** |
| 3 | The setter is `wan:1` carrying `networkPreferredMode`, returning `result 0` | **Confirmed** (restore direction fully captured) |
| 4 | The forward `wan:1` request carrying value 1 | **Inconclusive** — effect observed, request not captured |
| 5 | A RAT-policy change can force full deregistration and service loss | **Confirmed** |
| 6 | Restoring policy 3 reliably recovers LTE registration and service | **Confirmed** |
| 7 | `networkType 2` is the 3G/UMTS projection, distinct from LTE 3 | **Confirmed** |
| 8 | `registerStatus 0` / `connectStatus 1` reachable as predicted by the record model | **Confirmed** |
| 9 | Changing preferred RAT does not disturb `networkSelectionMode` or other policy fields | **Confirmed** |
| 10 | `simStatus` is independent of registration state | **Confirmed** |
| 11 | Practical reversibility under a genuinely disruptive condition | **Confirmed** |
| 12 | `registerStatus 2` (searching) intermediate state | **Not exercised** — 10 s polling grid did not sample it |
| 13 | `connectStatus 2/3` (connecting / disconnecting) intermediates | **Not exercised** — same reason |
| 14 | `networkSelectionStatus` movement during a RAT change | **Confirmed** unchanged at 0 |
| 15 | Numeric PLMN / BCD decimal-only prediction | **Not exercised** — frontend never displays a numeric PLMN |
| 16 | Current-operator structure (`<format>`, long/short name, AcT) | **Not exercised** — not projected to the UI |

No contradiction with the static model was found.

## 10. Evidence boundary

**Physically observed:** the stock UI enum; that the frontend submits `wan:1` with
`networkPreferredMode`; the success code; the readback; the full runtime transition
sequence across `connectStatus`, `registerStatus`, `networkType` and `signalStrength`;
recovery on LTE; exact configuration restoration.

**NOT observed — static-model evidence only:** record 75, `CMobileEvent 0x33`, `mobile`,
`AT*BAND`, `atcmdsrv`, `CI DEV group 9 SET_BAND_MODE_REQ` (primId 51), `/dev/msocket`,
CP handler `0x068afdf0`, `L1CSetRat`. None of these was instrumented.

The correct statement remains: **the observed external behaviour is consistent with the
recovered internal control path.** This session confirms the head of the chain and now
also its runtime consequence, but everything below the `rpmServer` RPC boundary is still
static inference and must not be reported as hardware-confirmed.

## 11. Limitations

- Timeline resolution is ~10 s, set by the SPA's own polling. Fast intermediate states
  are unobservable and their absence proves nothing.
- The forward setter request was not captured (finding 4).
- The management session expired once mid-test and the operator re-authenticated
  manually. The device remained on 3G, registered and connected, throughout; no
  credential was read, stored or reused by tooling.
- A single carrier, a single location, and one 3G-capable network. "3G was available
  here" does not generalise.
- Outcome B (no 3G available → searching / no service) was not exercised, because this
  network provided 3G.

## 12. Sanitization

Capture-time, deny-by-default, in-page, using the corrected sanitizer (anchored so it no
longer over-redacts `signalStrength`). DOM inspection was shape-only throughout — no
broad unsanitized dumps, correcting the handling error noted in validation 002. Button
labels of the confirmation dialog were read, which are generic UI strings.

Not retained: IMEI, IMSI, ICCID, SIM number, MSISDN, MAC, SSID, WAN IP, DNS, APN and APN
credentials, operator name, ISP profile names, firmware/hardware version strings.
Session tokens hard-redacted. Pattern audit over all captured artifacts: **0 hits**.
Raw captures remain under the gitignored `emulation/work/`.

## 13. Conclusion

The preferred-RAT control path is now validated under a genuinely disruptive condition:
a policy value that contradicts the current registration is accepted, forces a complete
loss of registration and service, settles on the commanded RAT, and is fully reversible
with LTE service recovering within ~26 s. The SIM was never addressed and remained
recognised even during total service loss.

No further setter was attempted. Operator selection, data switch, roaming, APN/profile,
hidden enum 0, band masks, direct AT/CI and modem reset all remain unexercised and
separately authorized.
