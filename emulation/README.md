# M7000 userspace sandbox

This harness runs binaries from the exact `3.0.2 Build 241129 Rel.3n` ARM root filesystem under QEMU Linux user mode. Its immediate target is the real OpenWrt boot-service path that reaches `/misc/m7000_debug.sh`; it does not emulate the M7000 board or touch a physical router.

## Safety model

The rootfs is disposable. Synthetic writable directories are bound at `/misc`, `/cache`, `/tmp`, and `/traces`; `/dev` contains only a host-backed null device. All generated rootfs, overlay, socket, build, and log artifacts stay beneath the ignored repo-local `emulation/work/` area or tracked `emulation/` paths. Destructive utilities are shadowed in `PATH`, and existing absolute command entries are replaced with logging stubs in the disposable rootfs after its original hash is verified. A stub records the request in `/traces/destructive.log` and exits 125. Do not weaken these controls to make a vendor script “work.”

This is containment for known firmware behavior, not a hardened boundary against a deliberately hostile binary. PRoot exposes an internal `/host-rootfs` view required by its QEMU loader; masking it prevents ARM execution. Run only reviewed fixtures here. Unknown scripts require a disposable VM or a separate mount namespace with Windows drives and sensitive files absent.

## Host setup

The scripts require a Linux host with `qemu-arm`, `proot`, `unsquashfs`, and Node.js. On Windows, use WSL 2. From the repository in Linux:

```sh
sudo emulation/setup/install-debian.sh
emulation/setup/prepare-rootfs.sh firmware/work/inner/3.0.2/update.bin
emulation/scripts/run-arm.sh /bin/busybox uname -a
emulation/scripts/run-hook-test.sh all
```

`prepare-rootfs.sh` calls the repository’s firmware extractor and then `unsquashfs`, preserving Linux symlinks and modes that a Windows extraction cannot represent. It verifies the expected exact-image and rootfs hashes before proceeding.

The representative BusyBox and `rpmServer` executables are ELF32 ARM little-endian EABI5, dynamically linked through `/lib/ld-musl-armhf.so.1`; BusyBox needs `libgcc_s.so.1` and musl `libc.so`. The exact BusyBox SHA-256 is `2fa3aeb712caaad7a7317d5e2b655bfc394eb2230abf653006b7f94761b32f3d`. Successful ARM execution and loader resolution are confirmed.

## Real hook path

Tests execute `/etc/rc.d/S99execute_debug_shell boot` inside the guest namespace. That symlink reaches the vendor `etc/init.d/execute_debug_shell`, whose shebang delegates to the vendor `/etc/rc.common`. This is the normal late-boot service path—not a direct call to the fixture.

The fixtures cover absence, empty content, explicit success, diagnostic-only commands, failure, synchronous blocking, and missing execute permission. Per-case stdout/stderr and QEMU syscall traces are written beneath `emulation/traces/`; generated traces are ignored, while `debug-hook-summary.md` records stable observations.

Set `M7000_SYSCALL_TRACE=0` for a quiet service smoke test. Hook tests intentionally leave tracing enabled.

Long-running services must use `scripts/run-service-smoke.sh`, which creates a separate process group and force-reaps it after the requested interval. This avoids leaving PRoot/QEMU descendants behind when a daemon ignores `SIGTERM`.

`scripts/run-rpc-probes.sh` starts `rpmServer` and sends only four compiled-in local test cases: invalid JSON, an empty object, known read-only `status:0`, and known read-only `log:5`. The client has no arbitrary module/action or raw-payload option.

Set `M7000_IPC_MODE=zero` to build and preload the minimal synthetic flow/WLAN providers used for the validated zero-state `status:0` round-trip. The wire-level responder is retained as a protocol reference; PRoot does not reliably deliver pathname datagrams between separate emulated processes.

## Current status

WSL 2 and QEMU 10.2.1 now execute the exact firmware rootfs. The complete hook matrix is characterized, destructive-command interception is verified, and a synthetic zero-state `status:0` round-trip succeeds through the real `rpmServer`. See the tracked summaries under `emulation/traces/`; raw generated traces remain ignored.

## Next boundary

The `rpmServer` sandbox has reached its useful limit, but static recovery has
made a bounded `mobile` daemon experiment plausible. Do not start the real
daemon until `/tmp/atcmd`, network-manager notification, CP-reset/NVM-switch,
and writable data-management boundaries are fail-closed. See
[`traces/mobile-sandbox-gate-summary.md`](traces/mobile-sandbox-gate-summary.md).
The standalone query-only AT stub can be checked without starting firmware code:

```sh
emulation/scripts/test-atcmd-stub.sh
```

On Windows, run `python emulation/scripts/test-atcmd-stub.py --local` with a
native Python build that supports `AF_UNIX`. WSL cannot place a Unix socket on
the repository's Windows-mounted filesystem; the test intentionally does not
fall back to `/tmp` or any location outside the repository.

`emulation/setup/build-ipc-stub.sh` also builds `mobile-containment.so`. That
libc-free ARM interposer blocks IP sockets, external commands, deletion, WAN
notifications, and WLAN-control calls while allowing only the repo-backed Unix
socket paths needed by the planned smoke test. It does not make PRoot a hardened
sandbox, and its presence alone does not authorize launching `mobile`.

The authorized synthetic startup uses `scripts/preflight-mobile.sh` followed by
`scripts/run-mobile-smoke.sh`. The runner creates private ephemeral tmpfs mounts
at repo-local `emulation/work/` mountpoints because DrvFS cannot host pathname
Unix sockets or case-distinct firmware files. It validates and re-extracts the
known SquashFS on every run, applies destructive stubs, runs for a fixed cutoff,
and reaps the complete process group. Stable observations are recorded in
[`traces/mobile-startup-summary.md`](traces/mobile-startup-summary.md); raw traces
remain ignored.

The queued narrowly scoped live read-only RPC plan remains the next live-device
phase; it has not been abandoned.
