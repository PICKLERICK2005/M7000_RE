# Live RPC 001: Fixed Read-Only Getter Pass

Dates: 2026-08-15 and narrowly scoped modem follow-up on 2026-08-16

## Scope and safeguards

This pass used the stock authenticated frontend on the physical M7000 and a fixed
allowlist recovered during static analysis. It issued only getter actions. No
setters, configuration changes, Debug Log controls, firmware operations, USB
operations, or arbitrary module/action calls were available to the probe.

Response sanitization ran inside the browser. Only object keys, scalar types,
array lengths, transport outcomes, and numeric RPC result codes crossed the
browser-debug boundary. Device-specific values, credentials, session material,
network addresses, identifiers, and storage-sharing values were not exported.

Canonical target:

| Field | Value |
| --- | --- |
| Hardware | `M7000(EU) v3.2` |
| Firmware | `3.0.2 Build 241129 Rel.3n` |
| Region | `EU` |

## Results

| Getter | Live result | Classification |
| --- | --- | --- |
| `status:0` | `result:0` | Implemented composite status provider |
| `wan:0` | `result:0`; connection/profile/network-selection schema retained without values | Implemented modem/network configuration getter |
| `simLock:0` | `result:0`; card/PIN/PUK state schema retained without values | Implemented SIM-lock state getter |
| `wan:10` | `result:0`; field `networkSelectionStatus` | Implemented network-selection progress/status getter |
| `wan:11` | `result:0`; field `callFailReason` | Implemented connection-failure reason getter |
| `log:5` | `result:0`; fields `mdLogState`, `result` | Implemented Debug Log state getter |
| `wps:0` | `result:0`; fields `enable`, `status`, `result` | Backend getter present despite the UI feature gate |
| `storageShare:0` | `result:0`; fields `ftproot`, `login`, `mode`, `password`, `rwPermission`, `username`, `result` | Backend getter present despite the UI feature gate; no values retained |
| `apBridge:0` | `result:1`; structured error | Request rejected; no working getter demonstrated |
| `upnp:0` | `result:1`; structured error | Request rejected; no working getter demonstrated |
| `dmz:0` | `result:1`; structured error | Request rejected; no working getter demonstrated |
| `alg:0` | `result:1`; structured error | Request rejected; no working getter demonstrated |
| `virtualServer:0` | `result:1`; structured error | Request rejected; no working getter demonstrated |
| `portTrigger:0` | `result:1`; structured error | Request rejected; no working getter demonstrated |
| `webServer:4`, `webServer:5` | No schema result retained; the stock page navigated during this prefix | Inconclusive in this authenticated pass; not retried |

The `result:1` cases prove only that the authenticated CGI returned a structured
error. Combined with their absence from the statically recovered `rpmServer`
module table, this is strong evidence that these generic frontend features are
not implemented by this firmware backend. It does not prove hardware absence.

## Live `status:0` response structure

The successful response contained these sections and fields:

- Root: `result`, `factoryDefault`
- `battery`: `charging`, `connected`, `voltage`
- `connectedDevices`: `number`
- `deviceInfo`: `firmwareVer`, `hardwareVer`, `imei`, `imsi`, `mac`, `model`,
  `productId`, `productRegion`, `simNumber`
- `loginMode`: `invalidPassword`, `version`
- `message`: `unreadMessages`
- `wan`: `band`, `connectStatus`, `dailyStatistics`, `dataLimit`, IPv4/IPv6 and
  DNS fields, limit/payment flags, `limitation`, `networkType`, `operatorName`,
  `registerStatus`, roaming fields, RSRP/RSRQ/RSSI/SNR, traffic rates/totals,
  `signalStrength`, and `simStatus`
- `wlan`: `bandType`, `channel`, `enable`, `mode`, `region`, `ssid`

All identity and network values were reduced to the type `string` before leaving
the browser. The live response confirms that device identity, SIM identity,
radio/network state, traffic state, WLAN state, battery state, message count, and
client count are delivered through one backend abstraction.

In the follow-up, three `status:0` samples spaced two seconds apart returned
`result:0` in approximately 150-210 ms. The browser-side sanitizer reported no
changed field paths across those two intervals. This only describes a short,
apparently steady observation window; it does not establish backend refresh
frequency.

The follow-up also validated the stock frontend's modem-adjacent getters. The
`wan:0` model includes connection/data/roaming state, preferred and selected
network modes, ISP metadata, and a profile list. Values inside the profile list,
including APN and credential fields, were reduced to types before crossing the
debug boundary. `wan:10` and `wan:11` align with exported `libmobile` APIs
`GetNetSelStat` and `GetCallFailReason`. The SIM-lock model aligns with the
exported SIM/PIN getter family, although exact field-to-call binding in stripped
`rpmServer` remains unresolved.

Unlike the generic frontend mapping documented earlier, this particular live
response did not contain an `sdcard` section or WISP connected-network fields.
That is an observation about this response, not proof that those fields can never
be emitted under another capability state.

## Conclusions

The most interesting dormant functionality is now WPS and storage sharing:
their pages are feature-gated in the UI, but their backend read providers are
present and return successful models. The NAT/forwarding and AP Bridge group has
the opposite profile: generic frontend code ships, while live getters fail and
the modules are absent from the recovered backend table.

No further live action is implied by these results. Any setter, especially WPS,
storage-sharing, or `log:4`, requires a separate controlled experiment and was
outside this pass.

The machine-readable, value-free record of this pass is
[`analysis/live-rpc-readonly.json`](../analysis/live-rpc-readonly.json).
