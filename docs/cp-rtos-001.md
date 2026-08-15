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

## Ownership assessment

CP firmware clearly implements both the NVM client and consumers of modem,
SIM-lock, diagnostic, band/RAT, and calibration state. This is strong evidence
that substantial modem configuration lives in CP-managed NVM rather than AP
UCI alone. Strings establish representation and code presence, not live
writability or storage offsets.

No identity-changing, NVM, diagnostic, or radio command was sent.

