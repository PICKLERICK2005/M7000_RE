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
