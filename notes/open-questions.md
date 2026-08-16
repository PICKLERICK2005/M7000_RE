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
- How is `operatorState` / "forbidden" represented on the wire for scan results (`GetAvailableNet`, event `0x23`)? That path uses `MP_NetInfo`, a different structure from `MP_NetSel`.
- Which code paths write record 84 values `6`, `7`, `8` and `9`? Two of the fifteen setter call sites pass a computed register rather than an immediate.
- Is the dBm-to-level function at `mobile` VA `0x3a50c` reachable in this build? No direct call site was found for it, unlike the CSQ and LTE-composite variants.
- What instruction set does the GRBI Layer-1 image target? It is 16-bit granular with the opcode in each halfword's high byte (dominant families `0xe1`, `0x60`, `0x30`, `0xe4`, `0xe6`), which refutes ARM, Thumb and any fixed 32-bit VLIW encoding. An ARCompact-style 16/32 hypothesis was tested and scored only 3.485 bits against a 3.823-bit baseline, so it stays a candidate rather than a result. Identification now needs a real decoder, not more statistics.
- Which AP component sends `CI_DEV_PRIM_SET_BAND_MODE_REQ` with the operation selector at `+0x18` set to `1`, `2` or `3`? `AT*BAND` always sends `0`, so it only ever exercises the GSM band branch of the CP handler, and the RAT mode-change branch (`3`) has no located sender.
- Why does the CI request builder overwrite bits 20-23 of the request handle with the CI `networkMode` for the setter, and with the literal primitive id for the two getters?
- What occupies the 4 reserved bytes at offset `0x18` of the CI wire header, between the request handle and the payload? Nothing on the send path writes them.
- Does any CI traffic use `/dev/cpmem` or `/dev/acipc` directly? The `atcmdsrv` CI send path uses only `/dev/msocket`, and copies the payload inline; the other two nodes are referenced from unrelated code.
- What are the engineering units of the raw values in records 200-207? The records are confirmed to be stored raw with no AP-side arithmetic, so the units are set by the CP report producer, which was not traced.
- Which code path writes record 208 (`mobile_status.rf_info.cell_id`)? It is named in the `tp_data` table but no writer was found alongside the rest of the family.
- What recovery path exists before attempting any writes?
