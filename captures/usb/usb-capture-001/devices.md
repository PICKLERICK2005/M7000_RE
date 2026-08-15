# USB Capture 001 Devices

## Powered-on device

| Property | Sanitized observation |
| --- | --- |
| Product descriptor | `M7000` |
| VID:PID | `3625:0006` |
| Device revision | `0318` |
| Manufacturer string | `Quectel` |
| USB descriptor / connection | USB 2.1 / High-Speed 480 Mbit/s |
| Advertised capability | SuperSpeed; not negotiated in this capture |
| Power descriptor | Bus-powered, 2 mA requested |
| Parent class | USB composite device |
| Parent driver | Microsoft `usbccgp`, `usb.inf` |
| Configurations / interfaces | One / two |
| Child description | `RNDIS` |
| Interface 0 | RNDIS control `E0/01/03`; interrupt IN `0x82`, 8 bytes |
| Interface 1 | CDC data `0A/00/00`; bulk IN `0x81` and OUT `0x01`, 512 bytes |
| Windows device name | Remote NDIS based Internet Sharing Device |
| Interface driver | Microsoft `usbrndis6`, `wceisvista.inf` |
| Network media / MTU | 802.3 / 1500 |
| Reported link speed | 426 Mbps |
| Addressing | DHCP; IPv4 subnet `192.168.0.0/24`; gateway `192.168.0.1` |

The reported 426 Mbps value is the Windows RNDIS link rate, not a measured USB
bus speed or throughput result.

The device exposed a USB serial string. It is device-unique and is intentionally
omitted.

## Powered-off connection transients

| Order | VID:PID | Product | Class/subclass/protocol | Duration | Windows binding |
| --- | --- | --- | --- | --- | --- |
| 1 | `2ECC:3001` | `NEZHAS` | `FF/FF/FF` | mean 2.001 s (1.815-2.326 s) | None |
| 2 | `2ECC:4E11` | `Openwrt` | `FF/42/03` | mean 2.624 s (2.341-2.855 s) | None |

Both disappeared automatically as the powered-off router settled into charging
mode. The inter-stage gap averaged 1.480 s across five cold connects. Both have
one vendor-specific interface with bulk IN `0x81` and bulk OUT `0x02`, using
512-byte packets at High-Speed. Serial-like strings remain private.

## Negative observations

No present interface was classified by Windows as:

- COM/serial
- modem
- mass storage
- firmware/download device
- additional vendor-specific child

This negative list applies to the stable powered-on configuration. Windows did
not classify the State B transients as COM, modem, storage, or firmware devices.
