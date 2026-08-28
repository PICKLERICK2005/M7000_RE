# Hardware Validation 002 - SIM-Backed Validation and First Reversible Write

Date: 2026-08-16. Target: TP-Link M7000(EU) v3.20, firmware 3.0.2 Build 241129 Rel.3n.
Predecessor: [readonly-validation-result.md](readonly-validation-result.md) (Phase 1,
no SIM installed).

**Outcome: Gate A passed with a SIM installed, and Gate B - one reversible
preferred-RAT change through the stock UI - completed and was fully restored.**
No SIM-persistent operation was issued. No PIN or PUK interaction occurred.

## 1. Method and boundary

Identical boundary to Phase 1: Wi-Fi to the device's own SSID, stock authenticated
management UI, isolated gitignored Edge profile, operator typing the admin password
directly. No USB, UART, Fastboot, CATStudio/ICAT, `/dev/msocket` tap, ptrace, process
injection or device-side hooks.

Observation again happened in-page, where the stock frontend decrypts its own AES/RSA
wrapped RPCs. Phase 2 added a **request-side tap** that records only a module/action
tag and argument key names, so the setter could be identified without reading
credentials. Session tokens were hard-redacted before schema extraction.

### What was deliberately not touched

`#Advanced/Dialup/PINConfig` (SIM PIN management) was identified in the navigation
surface and **never opened**. The `networkSearchSection` control (automatic/manual
selection, scan, and its operator-list popup) was identified on the same page as the
control under test and **never operated**, because record 76 still has no demonstrated
rollback path.

## 2. Gate A - SIM-backed read-only validation

The SIM was inserted by the operator with the router powered off, then powered on
normally. It was recognised without any PIN or PUK prompt.

| # | Prediction | Observation | Result | Confidence |
| --- | --- | --- | --- | --- |
| A1 | SIM recognised, identity fields populate | `imsi` present (15 digits), `simNumber` present, `simStatus` 1 → **3** | **Confirmed** | high |
| A2 | Record 78 → normalized signal 0–4 | `signalStrength = 3` - a non-idle value, unlike Phase 1's 0 | **Confirmed** in range | high |
| A3 | Record 79 → backhaul enum, 4 = connected | `connectStatus = 4` | **Confirmed** | high |
| A4 | Record 81 → 1 = primary packet-domain registered | `registerStatus = 1` | **Confirmed** | high |
| A5 | Record 80 → roaming projected separately | `roaming = 0` with `roamingEnabled = false` as a distinct field | **Consistent** | medium |
| A6 | Record 75 → UI preferred-RAT enum 0–3 | `networkPreferredMode = 3` | **Confirmed** | high |
| A7 | Record 76 → selection mode booleanised | `networkSelectionMode = 0` (automatic) | **Consistent** | medium |
| A8 | Record 84 reachable and idle | `wan:10` **is** issued by the Network Settings page; returns `{networkSelectionStatus: 0, result: 0}` - state 0, the terminal/idle state in the recovered producer map | **Confirmed** | high |
| A9 | Numeric PLMN is decimal-only (BCD model) | No numeric PLMN is exposed anywhere on the stock surface; the frontend carries the operator only as a text name | **Not exercised** | - |
| A10 | Current-operator structure (`<mode>`, `<format>`, long/short name, AcT) | Frontend surfaces only `operatorName` plus the selection-mode category; the structured CI fields are not projected to the UI | **Not exercised** | - |

### A8 closes a Phase 1 gap

Phase 1 recorded `wan:10` as "not reachable from the exercised stock frontend surface".
That was a consequence of which pages were visited, not a product limit: with a SIM
installed, the **Network Settings** page issues `wan:10` as part of its normal load.
The Phase 1 note is superseded.

### A9/A10 are a product-surface limit, not a contradiction

The BCD falsification test still cannot run, for a reason that is now clear and is
itself a finding: **this frontend never displays a numeric PLMN.** It shows a resolved
operator name. With no numeric MCC/MNC anywhere in the stock surface, there is nothing
to test the decimal-only prediction against. Inducing one would require a network scan,
which is out of scope.

The in-page probe for a non-decimal hex digit fired only on `wlan.region`, a
two-character region code that is not a PLMN. Recorded as *not exercised*, not passed.

## 3. Gate B - first reversible write

### The UI enum, confirmed directly

The stock control `networkModeSelect` offers exactly three options, which match the
statically recovered enum:

| Option | Value | Label |
| --- | ---: | --- |
| `networkModeLTE` | 3 | 4G Preferred |
| `networkMode4G` | 2 | 4G Only |
| `networkMode3G` | 1 | 3G Only |

Hidden value 0 is **not offered by the UI**, consistent with the static finding that it
is a non-exposed value. `wan:0`'s `networkPreferredMode` matched the selected option in
every sample.

### B1 - pre-write snapshot

UI = "4G Preferred" (value 3). `networkPreferredMode 3`, `networkSelectionMode 0`,
`dataSwitchStatus 1`, `roamingEnabled false`, `connectStatus 4`, `registerStatus 1`,
`signalStrength 3`, `simStatus 3`, `roaming 0`, `networkType 3`, SIM present.

### B2/B3 - the single authorized write

Test value: **2, "4G Only"** - the least disruptive visible option, since the device was
already operating on 4G.

The change was made through the ordinary stock UI. The frontend built and submitted its
own setter; the observed request was:

```
module "wan", action 1
arguments: action, module, networkPreferredMode = 2, token (redacted)
response: result = 0
followed by a wan:0 readback
```

A confirmation dialog - *"The network might be disconnected, are you sure you want to
continue?"* - is presented by the stock page for this setter and was accepted, as the
authorized path for this change.

### B4 - actual transition behaviour

The anticipated temporary deregistration **did not occur**. Because the device was
already on 4G and the change only removed the fallback RATs, service was retained
throughout: `connectStatus` stayed 4, `registerStatus` stayed 1, `networkType` stayed 3.

This is a weaker exercise of the transition path than a RAT change that forces a
re-registration would have been. It is recorded as such rather than claimed as evidence
that RAT changes are always non-disruptive.

### B5 - new state

| Field | Pre-write | Post-write |
| --- | ---: | ---: |
| UI / `networkPreferredMode` | 3 | **2** |
| `connectStatus` | 4 | 4 |
| `registerStatus` | 1 | 1 |
| `networkType` | 3 | 3 |
| `simStatus` | 3 | 3 |
| `networkSelectionMode` | 0 | 0 |
| `dataSwitchStatus` | 1 | 1 |
| `roamingEnabled` | false | false |

Only the intended field moved. No neighbouring policy was disturbed - in particular
the network-selection mode did **not** shift, which is the coupling the static model
warns about for the `AT+COPS=0` path (not exercised here).

### B6/B7 - restoration

Restored through the same stock control. Observed setter: `wan:1` with
`networkPreferredMode = 3`.

Configuration comparison against the pre-write snapshot:

| Field | Pre-write | Restored | |
| --- | ---: | ---: | --- |
| `ui_selected_value` / text | 3 / "4G Preferred" | 3 / "4G Preferred" | match |
| `networkPreferredMode` | 3 | 3 | match |
| `networkSelectionMode` | 0 | 0 | match |
| `dataSwitchStatus` | 1 | 1 | match |
| `roamingEnabled` | false | false | match |
| `simStatus` | 3 | 3 | match |
| SIM present | true | true | match |

Dynamic network state (`connectStatus`, `registerStatus`, `signalStrength`, `roaming`,
`networkType`) also returned identical values, though those are permitted to vary.

**Configuration fully restored.**

## 4. What this does and does not establish

**Externally observed hardware behaviour:** the stock UI enum values; that selecting
"4G Only" submits `wan:1` carrying `networkPreferredMode = 2`; that the setter returns
`result = 0`; that the readback reflects the new value; that the change is reversible
through the same control; that no adjacent policy field moved.

**Static internal-path evidence, NOT observed here:** record 75, `CMobileEvent 0x33`,
`AT*BAND`, `CI_DEV_PRIM_SET_BAND_MODE_REQ`, `/dev/msocket`, the CP dispatcher, handler
`0x068afdf0`, `L1CSetRat`. None of these was instrumented, and none was physically
observed.

The correct statement is therefore: **the externally observed behaviour is consistent
with the statically recovered control path.** The head of the chain - UI enum to the
`networkPreferredMode` argument - is now confirmed on hardware. Everything below
`rpmServer` remains static-only evidence.

## 5. SIM safety

| Check | Result |
| --- | --- |
| PIN counter interaction | none - no PIN prompt at any point |
| PUK interaction | none |
| SIM security setting changed | none - `PINConfig` never opened |
| SIM filesystem / APDU write | none |
| SIM-stored SMS operation | none - SMS pages never opened |
| SIM identity / provisioning modification | none |
| SIM still detected | yes - `simStatus 3`, IMSI present, unchanged before and after |
| Modem registers normally in restored mode | yes - `registerStatus 1`, `connectStatus 4` |

Exactly two setter requests were issued in the entire session, both `wan:1`, whose only
non-token argument was `networkPreferredMode`. Nothing addressed the UICC.

## 6. Sanitization

Capture-time, deny-by-default, in-page - the corrected sanitizer from Phase 1 (the
anchored pattern that no longer over-redacts `signalStrength`) was verified in place
before starting.

Not retained: IMEI, IMSI, SIM number, MAC, operator name, ISP profile names, APN, APN
username, firmware/hardware version strings, product ID, WAN IP, DNS addresses, SSID.
APN passwords and session tokens were hard-redacted.

One handling note, recorded for completeness: during DOM discovery of the page controls,
an unsanitized element dump surfaced ISP profile names - carrier identifiers - into the
operator's console. Nothing was written to disk and no published artifact contains them;
DOM inspection was switched to shape-only for the remainder of the session.

Raw captures remain under the gitignored `emulation/work/`. Only sanitized observations
are published.

## 7. Conclusion and limits

This establishes the project's **first known-good reversible control experiment** on
hardware: a stock-supported configuration change, observed, verified, and returned
exactly to its original value, with the SIM untouched.

It does not authorize further writes. The remaining write-path concerns are unchanged:
`AT+COPS=0` resets the RAT policy to all-RAT, and record 76 has no rollback path. The
transition path was also only weakly exercised, since service never dropped.

No second write was attempted.
