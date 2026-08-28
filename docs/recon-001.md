# Recon 001 - Physical Identification

Date: 2026-08-14

## Confirmed target

- **Model:** TP-Link M7000(EU)
- **Hardware:** Ver 3.20
- **Connector:** USB-C
- **Cellular module:** Quectel EC200A-EL
- **Battery:** 2100 mAh
- **Advertised LTE throughput:** 150 Mbps down / 50 Mbps up
- **Observed market provenance:** UAE / TDRA-labeled retail packaging

## Physical observations

The main populated side of the PCB contains a large shielded Quectel EC200A-EL module, SIM socket, USB-C connector, battery/contact connector, antenna contacts, RF test connectors, exposed test pads, and an additional shielded subsystem whose exact function is not yet confirmed.

### Interesting silkscreen labels

Observed around the modem/module area:

- `CP_TXD`
- `CP_RXD`
- `AP_TXD`
- `AP_RTS`
- `AP_CTS`

Other visible labels include multiple `TPxx`, `ANTxx`, `Jxx`, and switch/component references.

## Working architectural hypothesis

The Quectel EC200A-EL owns the cellular/baseband side and is the primary candidate for modem NV, calibration data, and cellular identity storage. The TP-Link application/UI layer likely queries the module rather than owning those values directly.

This remains a hypothesis until confirmed through firmware, USB, UART, or storage analysis.

## Electrical caution

Do not attach a generic 3.3 V UART transmitter to unknown pads. Characterize ground and idle voltages first. The EC200A family uses low-voltage UART signaling, so 1.8 V operation should be assumed until measured/verified.

## Software follow-up

### Stock admin interface characterization

Before USB or hardware diagnostics, record the running software versions and map the stock administration interface using only normal UI navigation. Capture the frontend's own network activity without manually invoking undocumented endpoints or changing settings.

Store sanitized notes and endpoint metadata in `captures/http/soft-capture-001/`. Raw HAR files and session material must remain in its ignored `raw/` directory.

This characterization was completed on 2026-08-15 and followed by offline frontend/RPC analysis. See `docs/soft-capture-002.md`. The current recommendation is exact official firmware acquisition and offline dissection before Debug Log activation, USB diagnostics, or hardware probing.

## Photo handling

Raw photos contain private device identifiers and must remain under `photos/private/`, which is excluded from Git. Only sanitized copies belong in `photos/public/`.
