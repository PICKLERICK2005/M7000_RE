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

Stock administration-interface characterization and offline frontend/RPC analysis are complete. The recommended next milestone is acquisition and offline dissection of the exact official V3.20 firmware branch. USB enumeration remains pending. Active probing, soldering, shield removal, and firmware writes are intentionally deferred until the relevant interfaces and recovery options are understood.

Detailed findings are recorded in [Recon 001](docs/recon-001.md), [Soft Capture 001](captures/http/soft-capture-001/), and [Soft Capture 002](docs/soft-capture-002.md).

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
