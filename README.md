# M7000RE

M7000RE is an open reverse-engineering project for the TP-Link M7000(EU) V3.20 mobile LTE router. It documents the device's hardware, firmware, diagnostic interfaces, and recovery paths through cautious, evidence-driven research.

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

The project currently covers:

- PCB layout and hardware identification
- USB, UART, and boot/debug interfaces
- Firmware containers, partitions, and persistent configuration
- Boundaries between the application processor and cellular modem
- Recovery and unbrick procedures
- Safe, reversible experiments with benign configuration fields

Research may identify where cellular identity information is sourced or validated. This repository does not provide operational instructions for changing cellular identity identifiers.

## Progress

Initial hardware reconnaissance identified the Quectel EC200A-EL module, RF connections, test points, and pads labeled `CP_TXD`, `CP_RXD`, `AP_TXD`, `AP_RTS`, and `AP_CTS`.

The next milestone is read-only USB enumeration on Windows. Active probing, soldering, shield removal, and firmware writes are intentionally deferred until the relevant interfaces and recovery options are understood.

Detailed findings are recorded in [Recon 001](docs/recon-001.md). A sanitized template for the next experiment is available at [USB Capture 001](captures/usb/capture-001-template.md).

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

## Safety and responsible use

Work on embedded hardware can permanently damage a device. Confirm voltage levels before connecting an active interface, preserve and hash original data, retain recovery copies, and prefer read-only observation before modification.

Do not publish serial numbers, IMEI/IMSI/ICCID values, MAC addresses, default credentials, session tokens, or other unique identifiers. Use this material only on hardware you own or are authorized to examine, and comply with applicable laws and network rules.

## Project status

This project is in an early reconnaissance stage. Findings may be incomplete or revised as additional evidence becomes available.
