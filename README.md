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
