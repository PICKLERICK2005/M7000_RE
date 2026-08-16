# M7000RE

This is an open reverse-engineering project for the TP-Link M7000(EU) V3.20 mobile LTE router. It is an attempt at documenting the device's hardware, firmware, diagnostic interfaces, and recovery paths. Basically poking at it and seeing what happens, with the main goal of modifying vendor-locked settings like modem configs and such.

## Target hardware

| Field | Value |
| --- | --- |
| Product | TP-Link M7000(EU) |
| Hardware revision | V3.20 |
| Cellular module | Quectel EC200A-EL |
| USB connector | USB-C |
| LTE class | Cat 4 |
| Advertised throughput | 150 Mbps down / 50 Mbps up |
| Battery | 2100 mAh |
| Observed market | UAE retail / TDRA-labeled packaging |

## Research scope

The project scope currently covers:

- PCB layout and hardware identification
- USB, UART, and boot/debug interfaces
- Firmware containers, partitions, and persistent configuration
- Boundaries between the application processor and cellular modem
- Recovery and unbrick procedures
- Safe, reversible experiments with benign configuration fields

## Progress

Initial hardware reconnaissance identified the Quectel EC200A-EL module, RF connections, test points, and pads labeled `CP_TXD`, `CP_RXD`, `AP_TXD`, `AP_RTS`, and `AP_CTS`.

Stock administration-interface characterization, frontend/RPC analysis, offline dissection of the exact running firmware, userspace hook emulation, narrowly scoped live getter validation, and passive USB enumeration are complete. Normal powered-on USB operation exposes one two-interface RNDIS function. Connecting USB while powered off briefly exposes a likely ROM/primary-loader identity followed by a confirmed U-Boot Fastboot-class gadget before charging. Preliminary CP/RTOS analysis identifies ARM code, ACIPC, CP-managed NVM, ICAT diagnostics, cellular state, and RF-calibration subsystems; the separate GRBI component contains LTE Layer-1/baseband code. No serial, modem, or storage interface appeared in normal USB mode. Active diagnostics, soldering, shield removal, special USB modes, and firmware writes remain intentionally deferred.

Offline runtime-state analysis also maps the registration normalization pipeline, the five-state mobile backhaul FSM, all fourteen network-selection workflow states, configured-versus-effective network-mode numeric spaces, and the exact derived disconnect-reason precedence. The canonical per-record tuples remain in `analysis/runtime-record-provenance.json`.

The preferred-RAT path is now reconstructed end to end and serves as the project's reference model for an AP-to-CP configuration path: UI enum, persistent record 75, libmobile validation and pre-flight gating, mobile event `0x33` with a four-byte payload, daemon staging and conditional persistence, the `AT*BAND` command, and the CP handler, plus a separate event `0x46` readback with its own numeric space. Network selection, data switch, and roaming switch are mapped against the same template. Control-path tuples are in `analysis/modem-control-paths.json`, and every numeric record ID resolves through the complete `tp_data` index in `analysis/tp-data-record-map.json`.

The AP/CP boundary is now resolved: AT text does not cross it. `atcmdsrv` parses the command and converts it into a binary CI primitive (`CI_DEV_PRIM_SET_BAND_MODE_REQ` for `AT*BAND`) carried over `/dev/msocket`; the CP receives a structure. `/dev/acipc` and `/dev/cpmem` exist on the device but are not demonstrated carriers for this transaction. The CP/RTOS image load base is confirmed at `0x06800000` from four independent structures, `MP_NetSel` is fully decoded, and record 78's signal normalization is recovered as a RAT-dependent 0-4 level that is composite on LTE.

Because AT text stops at `atcmdsrv`, the CI primitive set is the real AP-to-CP control surface. All ten service-group name tables are catalogued in `analysis/ci-primitives.json`, anchored on `CI_DEV_PRIM_SET_BAND_MODE_REQ`, whose CP handler, request-structure field bounds, and RAT enum constraints are recovered using the confirmed base. Network-selection result semantics are closed: record 84's fourteen states are confirmed from both the frontend enum and the daemon call sites, and the pre-flight gate is explained by record 19 being SMS send status with state 13 named `search_failure_sending_sms`.

Network selection is now mapped at the same depth, and the CI layer generalizes. A rule — the CI client-object slot is `4 x service group id` — resolves 392 of the 397 CI send sites in `atcmdsrv` to named primitives, giving a catalogue instead of one-off recovery. On that basis: scanning is an AP-driven count-then-iterate poll (`GET_NUM_NETWORK_OPERATORS` then a loop of 80-byte per-operator confirmations), not an array or an indication stream; automatic registration resets the preferred-RAT policy to all-RAT before registering; manual registration sends MCC and MNC as two 16-bit BCD-packed fields with an explicit digit count, rather than the 3GPP interleaved PLMN-ID or text; and cancellation is a zero-payload global abort that cannot target a request. The AP-side confirmation demultiplexer, its runtime-registered per-group handler table, and the four `reqHandle` fields are in `analysis/ci-transport.json`. Record 84's producer map is closed for thirteen of fourteen states, with state 8 shown unreachable in this build. The current-operator record resolves into a status word, the network-selection mode field and two equal 38-byte name descriptors, each a union of a length-prefixed name or BCD MCC/MNC. Because every CI payload is allocated by a debug allocator that carries the builder's own symbol and source line, 357 of the 397 send sites are now named, and the per-group source files agree with the client-object rule on all 356 joined senders with no conflicts. The `SET_BAND_MODE` operation selector is closed as a negative result: no AP component sends anything but zero, so two branches of the CP handler are unreachable from this firmware. Record 76 turns out never to be restored because nothing is saved: it has three writers with three meanings, of which the workflow commit is the only non-persistent one, and a stale overlay is superseded by the modem readback rather than rolled back. The internal AT-error enum is fully mapped, placing record-84 state 7 on CME 30/32 and CMS 331 specifically. Two earlier labels are corrected: the scan-list and current-operator confirmations are two different 80-byte structures, not one, and the field at `+0x02` of the current-operator record is the network-selection mode feeding the AT `<mode>` position rather than an availability status. The list record is now fully partitioned, with `<stat>` passed through unmapped at `+0x02` and `<AcT>` at `+0x4e`. The CI receive handlers turn out to be static after all: one registrar installs them from a table indexed by service group, so all nine implemented handlers plus the shared stub for the five unimplemented groups are named. Control message types 5 and 6 register and clear a global catch-all callback that only logs. Record 208 has no writer at all. AP/modem characterization is frozen for the first hardware phase. The read-only plan in [Read-Only Validation Plan](docs/readonly-validation-plan.md) has been executed against the physical device twice: once with no SIM ([Read-Only Validation Result](docs/readonly-validation-result.md)) and once SIM-backed, which also carried the project's first reversible write ([Hardware Validation 002](docs/hardware-validation-002.md)). Schemas, record projections and enum ranges matched the static model with no contradiction, and the stock preferred-network control was confirmed to offer exactly the recovered enum (3 = 4G Preferred, 2 = 4G Only, 1 = 3G Only, with hidden value 0 not exposed). One stock-UI preferred-RAT change was made and fully restored: the frontend submitted `wan:1` carrying `networkPreferredMode`, the readback reflected it, no adjacent policy moved, and the SIM was never addressed. That first write was non-disruptive, so a third pass ([Hardware Validation 003](docs/hardware-validation-003.md)) forced a real transition by selecting `3G Only`: the modem accepted policy value 1 and re-registered on 3G with `networkType` moving to 2, and restoring `4G Preferred` produced a fully observed deregistration cycle — `connectStatus 4 -> 1 -> 4`, `registerStatus 1 -> 0 -> 1`, `networkType 2 -> 0 -> 3` — with LTE service recovered within about twenty-six seconds and configuration restored exactly. `simStatus` stayed 3 even during total loss of registration, so UICC presence is independent of radio state. The forward setter request itself was not captured, so for that direction only the effect is evidence; the restore direction was captured in full and is the authoritative observation of the setter schema. The operator/PLMN predictions remain unexercised because this frontend never displays a numeric PLMN. Further write validation is deferred and separately authorized.

The chain is now complete end to end. `atcmdsrv`'s `AT*BAND` handler translates all sixteen textual `NwMode` values into CI `networkMode`/`preferredMode` pairs, which proves the RAT enum outright (`GSM=0, UMTS=1, LTE=3`, the RAT bitmask minus one) rather than merely constraining it. The numeric primitive encoding is confirmed as a 1-based per-group index with a separate global `0xF000` error range, validated across five primitives on both sides of the boundary; the earlier packed-id hypothesis stays refuted. The wire envelope, the payload-size tables, and `/dev/msocket` as the sole transport for this path are in `analysis/ci-transport.json`, and the CP-side 76-entry DEV request dispatcher is anchored. `0x3081` is closed as a negative result: it occurs exactly once in the whole userspace stack and takes the same branch as the default. Records 200-207 are confirmed to store raw RF values with no AP-side conversion. GRBI is narrowed to a 16-bit-granular instruction set with the opcode in each halfword's high byte, which refutes ARM/Thumb and any fixed 32-bit encoding, but no ISA is claimed. All of this is static recovery; no event, AT command, CI primitive, or modem operation was executed.

Detailed findings are recorded in [Recon 001](docs/recon-001.md), [Soft Capture 001](captures/http/soft-capture-001/), [Soft Capture 002](docs/soft-capture-002.md), [Firmware RE 002](docs/firmware-002.md), [Userspace Emulation 001](docs/emulation-001.md), [Live RPC 001](docs/live-rpc-001.md), [Early-Boot USB](docs/usb-early-boot.md), [U-Boot USB Map](docs/uboot-usb-map.md), [CP/RTOS Architecture](docs/cp-rtos-001.md), [RF/Baseband Architecture](docs/rf-baseband-001.md), [AP-to-Modem Control Path](docs/modem-control-path.md), [Runtime Record Provenance](docs/runtime-record-provenance.md), [Read-Only Validation Plan](docs/readonly-validation-plan.md), [Hardware Validation 002](docs/hardware-validation-002.md), and [Hardware Validation 003](docs/hardware-validation-003.md).

## Repository contents

| Path | Contents |
| --- | --- |
| `docs/` | Research reports and hardware maps |
| `captures/` | Sanitized USB, UART, and web-interface captures |
| `analysis/` | Structured device and firmware analysis |
| `firmware/stock/` | Archived vendor firmware |
| `photos/public/` | Sanitized photographs suitable for publication |
| `tools/` | Scripts and research utilities |
| `notes/` | Open questions and working notes |

Raw device dumps, private photographs, credentials, session data, and unique device identifiers are excluded from version control.

## Project status

AP/modem characterization is frozen; physical validation has completed read-only passes with and without a SIM, one reversible non-disruptive preferred-RAT write, and one forced RAT transition with a fully observed deregistration and recovery; further write validation is deferred and separately authorized. Hardware, boot and RF areas remain at an earlier stage. Findings may be incomplete or revised as additional evidence becomes available.
