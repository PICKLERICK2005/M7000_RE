# Read-Only Physical Validation - Result (Phase 1)

Date: 2026-08-16. Target: TP-Link M7000(EU) v3.20, firmware 3.0.2 Build 241129 Rel.3n.
Specification: [readonly-validation-plan.md](readonly-validation-plan.md).

**Outcome: the structural and enum predictions were confirmed. The operator /
PLMN predictions could not be exercised, because the device had no SIM
installed.** No setter was issued and no state was intentionally changed.

## 1. Method

| Item | Value |
| --- | --- |
| Connection | Wi-Fi to the device's own SSID; analyst host on a DHCP lease in the router's LAN subnet, gateway at the stock `192.168.0.1` |
| Interface | Stock authenticated management UI (`lighttpd/1.4.67`, `/cgi-bin/web_cgi`) |
| Browser | Edge 151 in an isolated, gitignored profile (`emulation/work/edge-rpc-profile/`) |
| Credential handling | The operator typed the admin password directly into the browser. It was never read, stored, transported or logged by tooling. |
| USB / UART / diagnostics | Not used. No `/dev/msocket` tap, no ptrace, no hooks in device processes, no rootfs change. |

### Why observation had to happen in-page

The plan assumed responses could be read at the network layer. They cannot. After
login the frontend wraps every RPC in TP-Link's `{"data":…,"sign":…}` envelope,
AES-encrypted with a session key and RSA-signed - so bodies are opaque on the wire.
Only the first two pre-auth calls are plain base64.

Observation therefore happened where the stock frontend itself decrypts: **inside the
analyst's own browser**, which is the same boundary `live-rpc-001` used. A passive
tap wrapped `JSON.parse` in the page, sanitized each decrypted RPC envelope to schema
in-page, and exposed only that schema over CDP. It generated **no traffic of its own**
and altered nothing. Raw values never left the page.

This is client-side instrumentation on the analyst machine. It is not instrumentation
of the device, and none of the prohibitions in the plan's out-of-scope list were
touched.

## 2. Deviation from the plan, recorded honestly

- **Load count.** The plan specified 7 page loads. Roughly 15 were issued, because the
  observer had to be re-armed at document-creation time after two failed capture
  attempts. All were the same allowlisted read-only type; none was a new action class.
- **`wan:10` and `simLock:0` were never observed.** No stock route reached them: the
  navigation surface exposed only Wizard, Status, SMS, Dial-up Settings, Network
  Expansion, Wireless Settings and Data Usage Settings. `#Wizard` (setup flow) and
  `#SMS/Inbox` (message content) were deliberately avoided.
- **Precondition not met: no SIM.** See §5.

## 3. Actions exercised

Only stock page loads. Nothing submitted, no form saved, no confirmation dialog
encountered or accepted.

| Action | Type |
| --- | --- |
| Status page load / reload | stock page |
| Dial-up Settings page load | stock route change |
| Root page `GET` (unauthenticated) | health check only |

Getters observed being issued *by the frontend itself*: `status:0`, `wan:0`, `wan:11`,
plus roughly eight capability/feature-flag getters (`cloud`, `macFilters`,
`natforwarding`, `oled`, `others`, `sdcard`, `tools`, and `wan`/`wlan` support flags).

## 4. Predictions and observations

| # | Prediction | Observation | Result | Confidence |
| --- | --- | --- | --- | --- |
| P1 | `status:0` schema matches the statically recovered model | Root keys exactly `result, factoryDefault, battery, connectedDevices, deviceInfo, loginMode, message, wan, wlan` - identical to `live-rpc-001` | **Confirmed** | high |
| P2 | `wan:0` carries connection/data/roaming state, preferred and selected network modes, ISP metadata and a profile list | All present: `connectStatus, dataSwitchStatus, roamingEnabled, networkPreferredMode, networkSelectionMode, ispVersion, selectedIspName, profileSettings{activeProfile, defaultProfile, maxProfileNum, list[]}, cardType` | **Confirmed** | high |
| P3 | Record 78 → normalized signal level 0–4 | `signalStrength = 0` | **Consistent** (in range; idle device cannot exercise the upper range) | medium |
| P4 | Record 79 → backhaul enum 0–4 | `connectStatus = 1` (disconnected) | **Consistent** (in range) | medium |
| P5 | Record 81 → normalized registration state | `registerStatus = 0` | **Consistent** | medium |
| P6 | Record 80 → roaming derived separately from registration | `roaming = 0`, `roamingEnabled = false`, both distinct fields | **Consistent** | medium |
| P7 | Record 75 → UI preferred-RAT policy enum 0–3 | `networkPreferredMode = 3` | **Confirmed** in range; 3 is the all-RAT "auto" policy an untouched device should hold | high |
| P8 | Record 76 → network-selection mode **booleanised to 0/1** by the readback writer at `mobile 0x4a350` | `networkSelectionMode = 0` (automatic) | **Consistent** with the prediction; a single sample cannot prove booleanisation | medium |
| P9 | Cross-getter consistency: the same record projected into two getters agrees | `connectStatus = 1` in both `status:0` and `wan:0` | **Confirmed** | high |
| P10 | `wan:11` exposes a derived failure reason | `callFailReason = 0`, `result = 0` | **Confirmed** structurally | high |
| P11 | Repeated reads return a stable projection | 6 like-for-like `status:0` samples across the run: **0 changed value paths, 18 stable** | **Consistent** | medium |
| P12 | Numeric PLMN is decimal-only (BCD model) | No numeric PLMN was exposed - no SIM | **Not exercised** | - |
| P13 | Current-operator structure (`<mode>`, `<format>`, long/short name, AcT) | No current operator - no SIM | **Not exercised** | - |
| P14 | Record 84 workflow state (`networkSelectionStatus`) | `wan:10` never issued by any page exercised in this pass | **Not exercised** - superseded by [hardware-validation-002.md](hardware-validation-002.md), where the Network Settings page does issue it and it returns state 0 (idle) | - |

### The core question: cached projection vs fresh modem query

P11 shows six identical samples, and no read triggered any observable modem
workflow. That is **consistent with** the cached/shared-state model and gives no
reason to abandon it.

It is not proof, and the plan anticipated this. With an idle, unregistered modem, a
cached projection and a fresh query would both return the same constant values, so
the observation cannot discriminate between them. The load-bearing evidence remains
the static call graph - none of the eight `GetAllStatus` component getters constructs
a `CMobileEvent`. Timing was not used as evidence, per the specification.

**The cached/shared-state model survives validation. It was not independently
confirmed by it.**

## 5. Precondition deviation: no SIM installed

Every sample showed `imsi` empty (length 0), `simNumber` empty, `registerStatus = 0`,
`networkType = 0`, `signalStrength = 0`, and `ipv4`/`dns` fields of length 7
(`0.0.0.0`). `simStatus` read 1.

Confirmed with the operator: the device has no SIM in it.

This is a limitation on scope, not a contradiction. It removes P12–P14 from reach and
it means P3–P6 were observed only at their idle values - the enums were shown to be
*in range*, not to span their range.

## 6. Falsification checks

None of the §14 failure criteria fired.

- No read changed state; no workflow was triggered.
- No response schema contradicted the static structure.
- No enum fell outside its predicted set.
- The BCD/PLMN check could not run. The in-page probe for a non-decimal hex digit
  fired only on `wlan.region`, a two-character region code that is not a PLMN. This is
  recorded as *not exercised*, not as passed.
- The router did not reboot; registration did not change.

### One operational event

The management session expired partway through, after which the SPA stopped rendering
and captures returned empty. The device was verified healthy immediately afterwards:
unauthenticated root `GET` returned 200 with byte-identical content length, TCP/80
open, Wi-Fi link and IP unchanged.

This is a frontend session timeout, not a device fault and not a falsification. No
recovery was improvised; the live phase was stopped and the operator was asked before
re-authenticating.

## 7. Sanitization

Sanitization ran **at capture time, inside the page**. Raw values never crossed to
tooling or disk.

Deny by default: values were retained only for an explicit allowlist of
non-identifying enums the static model predicts. Everything else was reduced to type,
length and character class.

Not retained: IMEI (recorded only as `digits, len 15`), IMSI, SIM number, MAC,
firmware/hardware version strings, product ID, operator name, ISP name, ISP version,
APN, APN username, SSID. APN passwords and any field matching
`passw|pwd|token|cookie|session|stok|secret|credential|signature|key|auth` were
hard-redacted before schema extraction.

One sanitizer defect was found and fixed mid-run: a bare `sign` pattern matched
**signal**Strength and redacted a prediction field. The pattern was anchored and the
sample retaken. No sensitive value was exposed by the defect - it was over-redaction,
not under-redaction.

Raw captures live under `emulation/work/`, which is gitignored. Only this sanitized
document is published.

## 8. Post-test state

After re-authenticating, one further read-only pass (status reload plus the settings
route) was taken and compared field-for-field against pre-test:

| Field | Pre-test | Post-test |
| --- | ---: | ---: |
| `networkPreferredMode` | 3 | 3 |
| `networkSelectionMode` | 0 | 0 |
| `dataSwitchStatus` | 1 | 1 |
| `roamingEnabled` | false | false |
| `connectStatus` (both getters) | 1 | 1 |
| `registerStatus` | 0 | 0 |
| `signalStrength` | 0 | 0 |
| `simStatus` | 1 | 1 |
| `roaming` | 0 | 0 |
| `networkType` | 0 | 0 |

**Every policy and state field is unchanged.** Management access over WLAN remained
available. No setter was issued at any point, so no rollback was needed or attempted.

This pass also contributed a sixth `status:0` and a third `wan:0` sample, all
consistent with the earlier ones, which strengthens P11 to six like-for-like samples
with zero changed value paths.

## 9. Conclusion

Phase 1 succeeded for what it could reach: the recovered getter models, the record
projections and the enum ranges all matched the static model, with no contradiction
anywhere.

It did **not** exercise the operator, PLMN or network-selection-workflow predictions.
Those remain untested against hardware.

This result **does not authorize a write phase**, and nothing here changes the two
standing blockers: `AT+COPS=0` resets the RAT policy to all-RAT, and record 76 has no
rollback path. A SIM-present read-only pass should precede any write design.

---

Continued in [Hardware Validation 002](hardware-validation-002.md): SIM-backed Gate A validation and the first reversible preferred-RAT write.
