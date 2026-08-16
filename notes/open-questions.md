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
- How does `atcmdsrv` translate the textual `AT*BAND` `NwMode` (sent `0`/`1`/`5`/`11`, default `99`; parsed `0`/`4`/`5`/`8`/`11`/`15`) into the CP CI `networkMode` enum, which the handler bounds to `0`-`6`? The two spaces are now known to be different; the mapping between them is not.
- Which CI value is `CI_DEV_NW_GSM` / `UMTS` / `LTE` individually? The set is proven to be `{0, 1, 3}` and the assignment `GSM=0, UMTS=1, LTE=3` follows the assertion's symbol order, but the enum definition itself was not recovered.
- What does `0x3081` encode? It is only ever equality-compared in the AP readback normalizer and is absent from the CP image entirely, so its bit structure cannot currently be proven.
- What is the numeric wire ID of `CI_DEV_PRIM_SET_BAND_MODE_REQ`? Its index in the DEV group is 50, but none of the ten CI name tables is reached by an absolute pointer, PIC pair, or `movw`/`movt` immediate, so the indexing code is unlocated. The `(group << 8) | index` hypothesis was tested and refuted.
- What are the CP request fields at `+0x14`, `+0x15`, `+0x16`, `+0x18` and `+0x1c` of the SET_BAND_MODE request? Their bounds (`<3`, `<5`, `<3`, branch selector) are known; their names are not.
- How is `operatorState` / "forbidden" represented on the wire for scan results (`GetAvailableNet`, event `0x23`)? That path uses `MP_NetInfo`, a different structure from `MP_NetSel`.
- Which code paths write record 84 values `6`, `7`, `8` and `9`? Two of the fifteen setter call sites pass a computed register rather than an immediate.
- Is the dBm-to-level function at `mobile` VA `0x3a50c` reachable in this build? No direct call site was found for it, unlike the CSQ and LTE-composite variants.
- What instruction set does the GRBI Layer-1 image target? It is not ARM or Thumb (≈5% decode density against ARBI's ≈70%), has no string-pointer tables and effectively no ASCII, so no load base can be anchored by the methods that fixed ARBI. Identifying the ISA is the prerequisite for any further GRBI work.
- What recovery path exists before attempting any writes?
