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
- Which code path writes record 208 (`mobile_status.rf_info.cell_id`)? It is named in the `tp_data` table but no writer was found alongside the rest of the family.
- What do the four `operatorState` values at `+0x02` of the 80-byte operator-info confirmation mean, and what does the mapping table at `atcmdsrv 0x85601` (`00 01 02 01`) translate them into? The field and the table are confirmed; neither enum is named, and the mapping is not the identity and never emits 3.
- What do the two unnamed bytes of the 38-byte operator name descriptor mean? `+0x24` is read and copied out when a preceding value equals 11; `+0x25` selects between descriptor A and descriptor B and is distinct from the `+0x01` encoding discriminator. Both value spaces are unrecovered.
- What do the values `6` and `13` mean in the normalized AT-error enum at `mobile 0x41110`? They select record-84 state 7 over state 6, but they are internal codes, not 3GPP `+CME` numbers, and the internal-to-CME mapping was not completed.
- How is record 76's temporary network-selection overlay restored after a cancelled manual search? The cancel primitive itself is recovered; the AP-side cleanup is not.
- Which modules register the per-service-group CI receive handlers? The table at `atcmdsrv .bss 0x000eeb94` is filled at run time by the type-3 control message handled at `0x7da76`, so the pointers are not statically resolvable. Only the MM handler (`0x1d644`) has been identified, via its primitive-id bound check.
- Does the CP read any field of `reqHandle`, or only echo it? All four AP-side fields are recovered; the CP side was not audited.
- What is msocket envelope type `5`, handled at `atcmdsrv 0x7da26`? Types 3 (handler registration) and 4 (CI primitive) are known.
- What recovery path exists before attempting any writes?
