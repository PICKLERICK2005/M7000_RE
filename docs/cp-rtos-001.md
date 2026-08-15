# CP/RTOS Preliminary Architecture

## Component identity

`ARBI` is a 7,707,288-byte little-endian ARM image. Its first instructions are
valid ARM branch/load sequences and its early pointer table clusters around
`0x06800000`-`0x08000000`, supporting an approximately `0x06800000` execution
region. Exact segment boundaries and the entry-point contract remain unresolved.

The image is not ELF. It is a linked RTOS image containing source paths, task
names, assertions, configuration filenames, and diagnostic messages. Evidence
names ASR/Marvell ACIPC, an NVM client, LTE/telephony tasks, USIM handling, and
an ICAT diagnostic stack.

## Confirmed subsystems

- AP/CP IPC: `ACIPCDHISR`, `ACIPCRDHISR`, `acipcTx`, `IPCHISR`, and
  `IPCThreadState`.
- CP NVM service: `nvmClient_ttc.c`, `NVM Rec Queue`, `NVMC_LinkStatus`, and
  explicit `.nvm` filenames.
- Diagnostics: `diag_rx.c`, `diag_port.c`, `diag_comm_EXTif.c`,
  `diag_comm_INTif.c`, `WS_IPCICATFunc.c`, and ICAT-ready messages.
- Cellular state: USIM code, LTE configuration, network/IP configuration,
  MEP/SIM-lock material, and an explicit `web imei` formatting path.
- Calibration: ADC, voltage, DCXO, antenna tuner, RF performance, power
  reduction, GSM calibration, and fast-calibration NVM names.

Representative persistent names include `CommonCfg.nvm`, `LTE_Cfg.nvm`,
`SystemControl.nvm`, `diagCfg.nvm`, `MEP.nvm`, `GsmCalData.nvm`,
`Dcxo_Calibration.nvm`, `AntTunerConfig.nvm`, and `RfPerformanceData.nvm`.

## Image load base

The ARBI image loads at **`0x06800000`**, giving a virtual range of
`0x06800000`–`0x06f59a98`. This is treated as CONFIRMED because four
independent structures agree.

The TIM image table does *not* supply it. ARBI's descriptor carries
`FlashEntryAddr = 0x005c0000` and `LoadAddr = 0xffffffff`, and the same
`0xffffffff` appears for TIM1, GRBI and RFBI. The chain metadata describes flash
placement only.

The base was instead recovered by shape-matching pointer tables. If a table
holds pointers to consecutive strings, the differences between successive
pointers equal the successive string lengths. That delta sequence is
base-independent, so matching it against the image's own string layout fixes the
base without having to guess an alignment. Eight pointer runs match at
`0x06800000` with a weighted vote of 93; the next-best candidate scores 22, is
unaligned, and rests on two runs.

Four checks then confirm it:

- The table at file `0x5bba0` resolves to `GetRTCPThreshold`, `GetRTCPInterval`,
  `GetRTCPBandWidth`, `GetRTCPAdaptation`, `GetRTPProfile`, `GetRTCPCName`.
- The table at `0x5c9bc` resolves to `releaseCodecResource`, `startReceive`,
  `pauseReceive`, `resumeReceive`, `startSend`, `pauseSend`, `resumeSend`,
  `DoSetDirection`.
- The tables at `0x7455e8` and `0x745638` resolve to the 3GPP system-information
  block names `SIB1`–`SIB18` and `SIB15_1`–`SIB15_5`, in order.
- The three-word stub at image offset 0 is `nop; ldr pc,[pc,#-4]; .word
  0x06e88c40`. Under this base that entry maps to file offset `0x688c40`, which
  disassembles as `nop; msr cpsr_c, #0xd3; b ...` — the canonical ARM
  supervisor-mode-with-interrupts-masked boot entry.

Additionally, the assertion string at file `0x6d4104` is referenced by the
absolute pointer word `0x06ed4104` at file `0xb039c`, which resolves correctly.

Two negative results are worth keeping. A plain histogram of pointer-to-string
deltas is *not* decisive on its own: it produces a noise floor of roughly 5,000
hits spread across many unaligned candidates between `0x0687xxxx` and
`0x06f3xxxx`. And an attempt to intersect candidate bases derived from assertion
*condition* strings returned the empty set, because those strings are not
referenced by plain absolute pointers. Neither weighs against the base above.

This base applies to ARBI only. No load base is established or claimed for GRBI.

## RAT policy and AT boundary

The CP image contains the receiving side of the AP's preferred-RAT path. Its
`AT*BAND` handler logs both `NwMode` and `PreferMode`, has an equality fast path,
and asserts that a standalone preferred mode is one of `CI_DEV_NW_GSM`,
`CI_DEV_NW_UMTS`, or `CI_DEV_NW_LTE`. Downstream strings distinguish
`NMODE_GSM`, `NMODE_UMTS`, and `NMODE_LTE`, plus state-manager values
`SM_RAT_MODE_NULL` and `SM_RAT_MODE_LTE`. This is the CP-side enum family that
correlates with AP modem responses `1`, `2`, and `3` respectively.

The CP also exposes `L1CSetRat`; its invalid-mode assertion confirms a lower
Layer-1 RAT transition API. Registration and service results return through the
CI/MM/SAC state machines, whose named states include home, roaming, searching,
denied, limited-service variants, and CSFB/SMS-only variants. `mobile` then
collapses those richer results into AP records 81 and 83.

A significant correction follows from the AP side: the CP does **not** parse
`AT*BAND` text. It contains no `*BAND` command token and no `CI_DEV_PRIM_*`
name strings at all — a search of the whole CI/CCI/msocket vocabulary across
ARBI returns one unrelated hit, `BAND_MODE_CHANGE`. The handler works on
`pSig->networkMode` and `pSig->preferredMode`, i.e. a already-decoded structure.
The AT text is parsed on the AP by `atcmdsrv` and converted into the binary CI
primitive `CI_DEV_PRIM_SET_BAND_MODE_REQ`. The `AT*BAND` in the CP log string
names the originating command, not the wire format. See
[AP-to-Modem Control Path](modem-control-path.md).

Named persistence associated with this area includes `SystemControl.nvm`,
`LTE_Cfg.nvm`, `NRAM2_PLMN_MATCH_BAND_ORDER_DATA`, and
`TTPCom_NRAM2_UECONFIGURATIONR10_DATA.gki`. None is statically proven to store
the preferred RAT value itself. The most defensible model is therefore: AP UCI
is the confirmed durable policy owner, CP receives `AT*BAND` policy into runtime
RAT state, and CP persistence for that particular field is unresolved. The
ACIPC symbols establish the AP/CP transport substrate, but the exact ACIPC
message ID beneath this AT request is not recoverable from strings alone.

## Ownership assessment

CP firmware clearly implements both the NVM client and consumers of modem,
SIM-lock, diagnostic, band/RAT, and calibration state. This is strong evidence
that substantial modem configuration lives in CP-managed NVM rather than AP
UCI alone. Strings establish representation and code presence, not live
writability or storage offsets.

No identity-changing, NVM, diagnostic, or radio command was sent.
