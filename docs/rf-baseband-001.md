# RF/Baseband Preliminary Architecture

## Components

`GRBI` is a 2,621,440-byte raw LTE Layer-1/baseband image. It is not recognized
as ARM by available format tools and its leading words do not decode like the
ARM vectors in `ARBI`. Embedded source paths and module names include
`V:\lte_fw`, LTE scheduling, HARQ, measurements, channel decoding, uplink,
digital RF, and configuration code. The safest classification is a linked
baseband/DSP image for a non-AP execution core; the precise DSP ISA remains
unresolved.

`RFBI` is a 32,768-byte opaque RF data/firmware block. A generic format scanner
mistook its header for COFF, but no usable sections or symbols were recovered;
it should not be described as COFF without further structural proof.

## Relationship to CP

`ARBI` contains the control-plane NVM and calibration consumers, including
DCXO, antenna, RF performance, power reduction, GSM calibration, and LTE RF
configuration names. `GRBI` contains real-time Layer-1 implementation names.
This supports a split where CP/RTOS owns policy/control and persistent NVM while
the baseband image executes timing-critical L1/RF work.

The exact RFBI lookup format, GRBI load address, IPC boundary, and calibration
record layouts remain open.

