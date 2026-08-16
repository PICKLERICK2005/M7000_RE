# CP/RTOS Preliminary Architecture

## Component identity

`ARBI` is a 7,707,288-byte little-endian ARM image. Its load base is now
confirmed at `0x06800000` (see [Image load base](#image-load-base)), giving a
virtual range of `0x06800000`-`0x06f59a98`, and its entry point is `0x06e88c40`
via the three-word stub at image offset 0. Internal segment boundaries remain
unresolved.

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
`SM_RAT_MODE_NULL` and `SM_RAT_MODE_LTE`.

An earlier draft equated this CP enum family with AP modem responses `1`, `2`
and `3`. That is superseded: disassembling the handler shows the CI values are
`{0, 1, 3}`, a different space from the AP readback. See
[The CI RAT enum](#the-ci-rat-enum-constrained-from-the-assertions) below.

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

## The CI primitive layer

With the base fixed, the CP side of the preferred-RAT path resolves properly.
The handler entry is at VA `0x068afdf0`, reached from the `AT*BAND` log string at
`0x068b03cc` (an `ADR` at `0x068b0134`) and from the two assertion strings
referenced at `0x068b009c` and `0x068b0082`.

Critically, it is **not** reached by parsing AT text. `atcmdsrv` converts the
command into the CI primitive `CI_DEV_PRIM_SET_BAND_MODE_REQ`, and the handler
receives a structure. Its validated request fields are:

| Offset | Size | Field | Check |
| --- | ---: | --- | --- |
| `0x00` | 1 | `networkMode` | `< 7` |
| `0x01` | 1 | `preferredMode` | `< 7` |
| `0x04` | 4 | band mask A (GSM candidate) | helper at `0x068afdb4`; bit 9 tested |
| `0x08` | 4 | band mask B (UMTS candidate) | masked against a capability word |
| `0x0C` | 8 | band mask C/D (LTE pair, `ldrd`) | not decomposed |
| `0x14` | 1 | unnamed selector | `< 3` |
| `0x15` | 1 | unnamed selector | `< 5` |
| `0x16` | 1 | unnamed selector | `< 3` |
| `0x18` | 1 | operation selector | branches on 0/5, 1/2, else |
| `0x1C` | 4 | unnamed word | copied to local state |

Out-of-range fields fail at `0x068afe7a` with code `0xf001`.

### The CI RAT enum, now confirmed

The handler's two assertions constrain the enum. When `networkMode` is `0`, `1`
or `3` it requires `preferredMode == networkMode` (assertion
`pSig->preferredMode == pSig->networkMode`, line 3767). When `networkMode` is `2`
or `≥ 4` it instead requires `preferredMode` to be one of `0`, `1`, `3` (the
`CI_DEV_NW_GSM || CI_DEV_NW_UMTS || CI_DEV_NW_LTE` assertion, line 3760).

So `CI_DEV_NW_GSM`, `CI_DEV_NW_UMTS` and `CI_DEV_NW_LTE` are exactly the set
`{0, 1, 3}`, and `{2, 4, 5, 6}` are the multi-RAT combinations.

**Important scoping correction.** Both assertions sit behind
`request[+0x18] == 3`, the RAT mode-change branch. The `AT*BAND` path always
sends `0` in that field, so these assertions are *not* on the `AT*BAND` path.
They corroborate the enum; they do not establish it.

The individual assignment is established instead by the AP-side translation
table, which offers a `preferredMode` for every multi-RAT `networkMode`: `0`
appears for `networkMode` 2, 4 and 6; `1` for 2, 5 and 6; `3` for 4, 5 and 6.
Those are exactly the combinations containing GSM, UMTS and LTE, and the
intersection is unique. So `GSM = 0`, `UMTS = 1`, `LTE = 3` is **confirmed**, and
with it the encoding of `networkMode` as `bitmask − 1` with GSM=1, UMTS=2, LTE=4:
GSM=0, UMTS=1, GSM+UMTS=2, LTE=3, GSM+LTE=4, UMTS+LTE=5, all=6.

A third, fully independent corroboration comes from the readback path below.

**This 0–6 CI space is not the `AT*BAND` textual `NwMode` space**, and the
translation between them is now recovered in full — see
[AP-to-Modem Control Path](modem-control-path.md).

### The readback path and the CP internal RAT state

`CI_DEV_PRIM_GET_BAND_MODE_CNF` (primitive `0x36`) is built at VA `0x068b0156`,
which reaches the CP from the internal signal table rather than the CI request
table — consistent with a query that must wait on lower layers. It carries the
mode pair at `+0x02` and `+0x03` rather than `+0x00`/`+0x01`.

It also contains an explicit translation: identical `tbb` byte tables
`03 05 07 09 0f 0d` at `0x068b0192` and `0x068b01c2` map a CP-internal RAT state
onto the CI value as `0→0, 1→1, 2→3, 3→2, 4→4, 5→5, ≥6→6`. Internal 2 and 3 swap
places relative to CI. That fixes the CP internal ordering as singletons first
and then pairs — GSM, UMTS, LTE, GSM+UMTS, GSM+LTE, UMTS+LTE, all — and every
pair position agrees with the bitmask reading of the CI space.

This is a **sixth** numeric namespace for the same concept, differing from the CI
space only in where LTE sits.

### The CP request dispatcher

The DEV request dispatcher is a flat table at `0x06f394fc`: 76 entries of
`{u32 primId, u32 handler|1}`, extending to `0x06f3977c`. Primitive `0x33` pairs
with `0x068afdf1`, and every one of the 76 ids resolves to a `CI_DEV_PRIM_*_REQ`
name under the confirmed 1-based numbering.

The handler's failure return is also now readable: `movs r0, #9` is
`CI_SG_ID_DEV` and `movw r1, #0xf001` is `CI_ERR_PRIM_HASINVALIDPARAS_CNF` — a
primitive id from the global error range, not an ad-hoc error code. On success
`0x068b0108` emits primitive `0x34`, `CI_DEV_PRIM_SET_BAND_MODE_CNF`.

Two field notes. `+0x17` is never read by this handler and is always sent as `0`
by the AP, though the AT read response reports it. And `+0x18` selects the
operation: `0`/`5` the GSM band branch, `1`/`2` the UMTS band branch, `3` the RAT
mode-change branch, anything else an assertion failure at line 3789. Since
`AT*BAND` always sends `0`, the RAT-change branch is reachable only from some
other CI sender, which was not located.

`L1CSetRat` sits below this: its invalid-mode assertion at VA `0x06905cbc` is
reached by an `ADR` at `0x06905a6c`, line 2257, inside a small RAT-state
dispatcher that returns 1 or 2 for different radio states.

## GRBI: characterized, deliberately not anchored

GRBI was examined after ARBI and the honest result is that none of the methods
that anchored ARBI apply to it.

- It contains **no string-pointer tables at all** — zero qualifying pointer runs,
  so the delta-shape method that fixed the ARBI base has nothing to match.
- It has essentially **no ASCII strings**; the few printable runs are binary
  coincidence.
- It is **not ARM or Thumb code**. Across five 1 KiB windows, Thumb decodes 120
  instructions of a possible ~2,560 and ARM 40 of ~1,280. The same measurement on
  ARBI yields 1,802 — roughly a 70% density against GRBI's ~5%.
- Entropy is 5.84 overall and ranges from 0.02 to 6.86 across 128 KiB blocks,
  with a zero-filled tail from `0x260000`. That rules out encryption or whole-image
  compression; it is plain content for a different instruction set, mixed with
  large coefficient and table regions.

This is consistent with the existing classification of GRBI as the ASR Falcon LTE
Layer-1 image: firmware for a DSP/vector core rather than the ARM CP. No load
base is claimed for it. Progress there requires identifying the target ISA first,
which is a different kind of problem from the pointer-anchoring used for ARBI.

### What the instruction stream does say

A byte-position frequency analysis over the code region narrows the field
without naming it. The image has a clear **period-2** signature: odd byte
positions are strongly enriched in `0xe1` (82,107 occurrences) while even
positions are not, and positions 1 and 3 behave identically, as do 0 and 2.
There is no period-3 or period-4 differentiation.

That means instructions are **16-bit granular**, with the opcode field in the
high byte of each little-endian halfword. The dominant families are `0xe1`,
`0x60`, `0x30`, `0xe4`, `0xe6`, `0x0c`, `0x32`, `0x18`, `0xd1` and `0xe3`, and
the most common individual halfwords after `0x0000`/`0xffff` are `0xe148`,
`0xe108`, `0xe149`, `0xe109`, `0xe180` — a tight cluster differing in low bits,
which is what one opcode with a small register or immediate field looks like.

This refutes any fixed 32-bit encoding with a per-word parallel bit — the TI C6x
family shape — which would show a period-4 signature and an LSB skew. Neither is
present.

An ARCompact-style mixed 16/32-bit hypothesis was tested and **not confirmed**.
Walking the stream under its length rule and comparing the major-opcode
distribution at instruction boundaries against the unconditional halfword
distribution gave 3.485 bits against a 3.823-bit baseline: a marginal
concentration, nowhere near enough to promote. (Self-synchronisation from
misaligned starts was immediate, but that happens for any variable-length rule on
any data and is not discriminating.) It is recorded as a candidate only.

Identification now needs a real decoder for a candidate ISA, not more statistics.
Nothing here should be inferred from vendor lineage: the Falcon classification
rests on strings and container structure, not on any decoded instruction.

## Ownership assessment

CP firmware clearly implements both the NVM client and consumers of modem,
SIM-lock, diagnostic, band/RAT, and calibration state. This is strong evidence
that substantial modem configuration lives in CP-managed NVM rather than AP
UCI alone. Strings establish representation and code presence, not live
writability or storage offsets.

No identity-changing, NVM, diagnostic, or radio command was sent.
