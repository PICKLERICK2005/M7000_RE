# Recon 001 — Physical Identification

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

## Next experiment

### USB enumeration

1. Reassemble the router.
2. Open Device Manager and USBTreeView.
3. Record the baseline with the router disconnected.
4. Connect USB-C with the router powered off.
5. Record every newly enumerated device/interface.
6. Power the router on while still connected.
7. Record any changes.
8. Save VID/PID, interface class/subclass/protocol, product/manufacturer strings, COM ports, and driver names.
9. Do not send modem commands yet.

Store the sanitized result in `captures/usb/`.

## Photo handling

Raw photos contain private device identifiers and must remain under `photos/private/`, which is excluded from Git. Only sanitized copies belong in `photos/public/`.
