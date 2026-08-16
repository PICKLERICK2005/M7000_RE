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

The AP/CP boundary is now resolved: AT text does not cross it. `atcmdsrv` parses the command and converts it into a binary CI primitive (`CI_DEV_PRIM_SET_BAND_MODE_REQ` for `AT*BAND`) carried over `/dev/msocket`, `/dev/acipc` and `/dev/cpmem`; the CP receives a structure. The CP/RTOS image load base is confirmed at `0x06800000` from four independent structures, `MP_NetSel` is fully decoded, and record 78's signal normalization is recovered as a RAT-dependent 0-4 level that is composite on LTE.

Because AT text stops at `atcmdsrv`, the CI primitive set is the real AP-to-CP control surface. All ten service-group name tables are catalogued in `analysis/ci-primitives.json`, anchored on `CI_DEV_PRIM_SET_BAND_MODE_REQ`, whose CP handler, request-structure field bounds, and RAT enum constraints are recovered using the confirmed base. Network-selection result semantics are closed: record 84's fourteen states are confirmed from both the frontend enum and the daemon call sites, and the pre-flight gate is explained by record 19 being SMS send status with state 13 named `search_failure_sending_sms`. GRBI is characterized but deliberately not anchored: it is not ARM/Thumb code and needs its target ISA identified first. All of this is static recovery; no event, AT command, CI primitive, or modem operation was executed.

Detailed findings are recorded in [Recon 001](docs/recon-001.md), [Soft Capture 001](captures/http/soft-capture-001/), [Soft Capture 002](docs/soft-capture-002.md), [Firmware RE 002](docs/firmware-002.md), [Userspace Emulation 001](docs/emulation-001.md), [Live RPC 001](docs/live-rpc-001.md), [Early-Boot USB](docs/usb-early-boot.md), [U-Boot USB Map](docs/uboot-usb-map.md), [CP/RTOS Architecture](docs/cp-rtos-001.md), [RF/Baseband Architecture](docs/rf-baseband-001.md), [AP-to-Modem Control Path](docs/modem-control-path.md), and [Runtime Record Provenance](docs/runtime-record-provenance.md).

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

This project is in an early reconnaissance stage. Findings may be incomplete or revised as additional evidence becomes available.
