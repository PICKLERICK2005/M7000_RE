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
- Which CP structure or `.nvm` record, if any, persists the `AT*BAND` preferred-RAT policy? AP `mobile_config.net_config.pref_net` is the only confirmed durable owner.
- What are the individual RAT bits in the confirmed multi-RAT modem mask `0x3081`, and what exact ACIPC message sits beneath the CP AT handler?
- What recovery path exists before attempting any writes?
