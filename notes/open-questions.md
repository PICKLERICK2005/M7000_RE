# Working Notes

## Open questions

- What modem/baseband and ISP profile versions are currently installed?
- What does the stock UI's `Debug Log` control retrieve or enable?
- Is transient `2ECC:3001` (`NEZHAS`) owned by immutable ASR BootROM or an omitted flash-resident primary loader?
- Does the confirmed U-Boot `2ECC:4E11` gadget accept any protocol during its automatic window, and what are its full descriptors? (Do not test until descriptor-only capture is complete.)
- Are normal-operation USB functions beyond the observed RNDIS interface disabled, unrouted, or absent?
- Which chipset/subsystem is under the second shield?
- What do `CP_*` and `AP_*` test points map to electrically?
- Is there an accessible boot/debug console?
- What firmware/container/partition formats are used?
- Which persistent fields survive factory reset?
- Where are benign factory/configuration fields stored?
- Where does the application layer obtain modem identity data?
- Which CP structure or `.nvm` record, if any, persists the `AT*BAND` preferred-RAT policy? AP `mobile_config.net_config.pref_net` is the only confirmed durable owner, and none of the 132 CP `.nvm` names is tied to RAT selection by any recovered reference.
- What is the authoritative CP `AT*BAND` `NwMode` enumeration? The AP sends `0`/`1`/`5`/`11` (default `99`) and recognises `0`/`4`/`5`/`8`/`11`/`15` on readback, so the two directions overlap without matching. Policy value `1` does not round-trip.
- What does `0x3081` encode? It is only ever equality-compared in the AP readback normalizer and is absent from the CP image entirely, so its bit structure cannot currently be proven.
- What exact ACIPC message, if any, sits beneath the CP AT handler, and does `AT*BAND` stay textual across the AP/CP link?
- What is the CP image load base? Without it, no CP call graph can be reconstructed from `05-ARBI.bin`; no self-consistent base could be derived from string pointers.
- Where does the record-78 signal-level normalization happen? The writing handler copies its input verbatim, and the raw metrics live separately in records `200`-`207`.
- What is the field layout of the 56-byte `MP_NetSel` event `0x34` payload, and what is the full record-84 workflow enumeration beyond `1` registering, `3` searching and `11` canceling COPS?
- Why do the two network-touching setters gate on `sms.sms_send_result.result == 4` while the data and roaming switches do not gate at all?
- What recovery path exists before attempting any writes?
