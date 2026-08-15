# USB Capture 001 Devices

## Powered-on device

| Property | Sanitized observation |
| --- | --- |
| Product descriptor | `M7000` |
| VID:PID | `3625:0006` |
| Device revision | `0318` |
| Parent class | USB composite device |
| Parent driver | Microsoft `usbccgp`, `usb.inf` |
| Observed child interfaces | One: `MI_00` |
| Child description | `RNDIS` |
| Interface class/subclass/protocol | `E0/01/03` |
| Windows device name | Remote NDIS based Internet Sharing Device |
| Interface driver | Microsoft `usbrndis6`, `wceisvista.inf` |
| Network media / MTU | 802.3 / 1500 |
| Reported link speed | 426 Mbps |
| Addressing | DHCP; IPv4 subnet `192.168.0.0/24`; gateway `192.168.0.1` |

The reported 426 Mbps value is the Windows RNDIS link rate, not a measured USB
bus speed or throughput result.

The device exposed a USB serial string. It is device-unique and is intentionally
omitted. The Windows property pass did not expose configuration count, raw USB
bus speed, or endpoint descriptors, and no descriptor utility was already
installed. Those properties are recorded as unknown rather than inferred.

## Negative observations

No present interface was classified by Windows as:

- COM/serial
- modem
- mass storage
- firmware/download device
- additional vendor-specific child

This is evidence for normal stock powered-on operation only. It does not rule out
interfaces that require another firmware state or special mode; no such mode was
entered during this capture.
