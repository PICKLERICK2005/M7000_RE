# M7000RE

Reverse engineering notes and tooling for a TP-Link M7000(EU) V3.20 mobile LTE router.

## Project goals

M7000RE is focused on understanding the parts of the device that are not normally exposed to the user:

- hardware architecture and board layout
- boot/debug interfaces
- firmware and partition layout
- undocumented configuration and NVRAM state
- factory identifiers and feature flags
- modem/application processor boundaries
- recovery and unbrick paths
- safe, reversible modification of benign hidden parameters

The project may document where cellular identity information is sourced and validated, but does not include operational instructions for rewriting cellular identity identifiers.

## Target device

| Field | Value |
|---|---|
| Product | TP-Link M7000 |
| Region | EU |
| Hardware revision | V3.20 |
| USB connector | USB-C |
| Cellular module | Quectel EC200A-EL |
| LTE class | Cat 4 |
| Advertised throughput | 150 Mbps down / 50 Mbps up |
| Battery | 2100 mAh, advertised up to 8 h |
| Market provenance | UAE retail unit / TDRA-labeled box |

Private identifiers such as the full serial number, IMEI, MAC address, default SSID, Wi-Fi password, ICCID, IMSI, and session material must never be committed.

## Current state

Hardware reconnaissance has identified the Quectel EC200A-EL cellular module and several exposed debug/test labels, including:

- `CP_TXD`
- `CP_RXD`
- `AP_TXD`
- `AP_RTS`
- `AP_CTS`
- multiple `TPxx` test points
- RF test connectors / antenna contacts

The current next step is non-invasive USB enumeration on Windows before any soldering, shield removal, firmware writes, or active probing.

See [`docs/recon-001.md`](docs/recon-001.md).

## Repository layout

```text
M7000RE/
├── docs/                 Research notes and hardware maps
├── photos/
│   ├── public/           Sanitized images safe for publication
│   └── private/          Local-only raw photos; ignored by Git
├── firmware/
│   ├── stock/            Archived vendor firmware
│   └── dumps/            Device dumps; ignored by Git by default
├── captures/
│   ├── http/             Sanitized web/API captures
│   ├── usb/              USB enumeration data
│   └── uart/             UART logs
├── analysis/             Binary/firmware analysis results
├── tools/                Scripts and utilities
└── notes/                Working notes
```

## Rules for evidence

1. Preserve originals and hash acquired firmware/dumps.
2. Never overwrite the only copy of a dump.
3. Record hardware and firmware revision with every capture.
4. Keep raw/private identifiers out of Git.
5. Prefer read-only characterization before modification.
6. Document voltage levels before connecting active interfaces.
7. Keep recovery paths documented before attempting writes.

## Status

**Phase 0 — Identification:** in progress  
**Phase 1 — USB/software reconnaissance:** next  
**Phase 2 — firmware acquisition/analysis:** pending  
**Phase 3 — UART/test-point characterization:** pending  
**Phase 4 — factory/NVRAM mapping:** pending  
**Phase 5 — reversible benign modifications:** pending
