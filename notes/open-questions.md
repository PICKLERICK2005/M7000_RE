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
- What do the SET_BAND_MODE selectors at `+0x14`, `+0x15`, `+0x16` and the word at `+0x1c` mean? Their bounds are confirmed from both sides (`0..2`, `0..4`, `0..2`) and `+0x16` is only populated for LTE-bearing modes, but none of them has a recovered name. `+0x17` is a stronger negative: never read by the CP, always sent as 0 by the AP, yet reported by the AT read response.
- Is the dBm-to-level function at `mobile` VA `0x3a50c` reachable in this build? No direct call site was found for it, unlike the CSQ and LTE-composite variants.
- What instruction set does the GRBI Layer-1 image target? It is 16-bit granular with the opcode in each halfword's high byte (dominant families `0xe1`, `0x60`, `0x30`, `0xe4`, `0xe6`), which refutes ARM, Thumb and any fixed 32-bit VLIW encoding. An ARCompact-style 16/32 hypothesis was tested and scored only 3.485 bits against a 3.823-bit baseline, so it stays a candidate rather than a result. Identification now needs a real decoder, not more statistics.
- Does any CI traffic use `/dev/cpmem` or `/dev/acipc` directly? The `atcmdsrv` CI send path uses only `/dev/msocket`, and copies the payload inline; the other two nodes are referenced from unrelated code.
- What are the engineering units of the raw values in records 200-207? The records are confirmed to be stored raw with no AP-side arithmetic, so the units are set by the CP report producer, which was not traced.
- What are the CI-side names of the four values of the network-selection mode field at `+0x02` of the 80-byte operator record? The field is confirmed to feed the AT `<mode>` position through the table at `atcmdsrv 0x85601` (0->automatic, 1->manual, 2->deregister, 3->manual), but the CI enum itself is unnamed.
- Does the CP read any field of `reqHandle`, or only echo it? All four AP-side fields are recovered; the CP side was not audited.
- What does the descriptor-selector byte at `+0x25` of the current-operator name descriptor encode? Its role is confirmed (the handler prefers the descriptor whose value is 2, falling back to 0) but no producer was located, so the enum is unnamed. This is the last unresolved field in either operator structure.
- What is msocket control message type `10`, sent from `atcmdsrv 0x5b450`? Types 3, 4, 5 and 6 are decoded.
- What are the CI-side names of the four values of the network-selection mode field at `+0x02` of the current-operator record? The field is confirmed to feed the AT `<mode>` position through the table at `atcmdsrv 0x85601`, but the CI enum itself is unnamed.
- What recovery path exists before attempting any writes?
- Can the `/tmp/atcmd` AT transaction be observed on hardware? Not with current access: host-side capture cannot see an AF_UNIX socket inside the router, there is no shell/telnet/SSH in the firmware, and the only stock diagnostic facilities (`log:4` mdLog, CATStudio) are the wrong layer (CP diag, not the AT socket), non-functional as shipped (`diag_mdlog`/`start_mdlog`/`stop_mdlog` absent), and state-changing. The blocking question is legitimate device-side execution, not the capture technique. See [atcmd-observation-design.md](../docs/atcmd-observation-design.md).
