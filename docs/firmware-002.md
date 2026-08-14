# Firmware RE phase 002

Baseline: **M7000(EU) v3.2**, **3.0.2 Build 241129 Rel.3n**, **EU**.

This phase remained entirely offline. It added reproducible Marvell_FBF inspection/extraction/verification, exact ISP-package decoding, native backend and modem-boundary mapping, and analysis of persistent diagnostic hooks. No router setting, RPC action, USB mode, firmware, or persistent device file was touched.

## Tools

```text
node tools/m7000-fw.mjs info update.bin
node tools/m7000-fw.mjs verify update.bin
node tools/m7000-fw.mjs extract update.bin output-directory
node tools/isp-inspect.mjs NetIspInfo
node tools/isp-inspect.mjs NetIspInfo --decrypt inner.zip
```

`m7000-fw` validates container/filesystem magic and bounds, reports hashes and SquashFS metadata, and extracts the byte-exact rootfs plus a manifest. `verify` checks structural integrity only; no vendor authenticity scheme has been identified. SquashFS unpacking remains delegated to `unsquashfs` or equivalent.

On the exact image it identifies `Marvell_FBF`, a SquashFS 4.0/XZ rootfs at `0x2000`, rootfs size `10806548`, image SHA-256 `a1be63a6bc8d9a6ed730b294187310b405bd686a5bf59c7e7b4ed9e8a7db56d7`, and rootfs SHA-256 `5dfddb34e9db5d7be3a82878d4a58d888d62012ebd8e4fb4db957c0564c02af8`.

## Stable findings

- `/misc/m7000_debug.sh` is an unvalidated, late-boot hook on persistent factory-data storage.
- Ordinary factory reset targets the JFFS2 overlay; the inspected path does not erase `tp_data`/`misc`.
- Debug Log control references collector helpers absent from the SquashFS, leaving its runtime dependency unresolved.
- CATStudio swaps diagnostic configuration, reboots, and can format a separate `swap_flash` partition.
- `rpmServer` exposes a static module registry over a local Unix socket and sources modem status through `libmobile`.
- The ISP updater’s complete salted-envelope/KDF/cipher pipeline was recovered and reproduced offline.

Detailed evidence: [`analysis/debug-hook.md`](../analysis/debug-hook.md), [`analysis/isp-decryption.md`](../analysis/isp-decryption.md), [`analysis/modem-boundary.md`](../analysis/modem-boundary.md), and [`docs/backend-architecture.md`](backend-architecture.md).

## Recommended next experiment

The project has intentionally inserted a [userspace-emulation phase](emulation-001.md) before the lowest-risk live step. Once the sandbox reaches its useful limit, return to a narrowly controlled **read-only RPC pass** limited to stock-equivalent status/capability queries. Debug Log, CATStudio, live `/misc`, and USB diagnostics remain untouched.
