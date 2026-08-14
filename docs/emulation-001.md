# Userspace emulation 001

## Objective and boundary

The current phase diverts from—but does not abandon—live read-only RPC probing. Its milestone is execution of the exact 3.0.2 firmware path that checks and launches `/misc/m7000_debug.sh`, using only synthetic storage and intercepted destructive operations. The physical router, USB interface, Debug Log, CATStudio, and live `/misc` remain out of scope.

## Static execution model

The normal path is:

```text
OpenWrt boot ordering
  -> /etc/rc.d/S99execute_debug_shell boot
  -> vendor /etc/init.d/execute_debug_shell
  -> shebang: /bin/sh /etc/rc.common
  -> synchronous start()
  -> test -e /misc/m7000_debug.sh
  -> /misc/m7000_debug.sh
```

Facts established without emulation:

- the checker is the vendor init script, dispatched by the vendor `rc.common`;
- timing priority is `START=99`;
- execution is synchronous, so a long-running script blocks completion of this service call;
- the script receives no explicit arguments;
- `rc.common` invokes the action as its final command, so the hook’s status propagates from `start()`;
- existence is tested, but executable permission and the file’s interpreter are left to normal `execve`/shell behavior;
- expected boot context is root with `/` as the working directory, but UID/GID, exact environment and working directory must be confirmed dynamically;
- persistent `/misc` and writable `/cache` are expected from the real boot ordering, while device nodes and proc/sys state cannot be assumed in userspace emulation.

## Harness

[`emulation/`](../emulation/README.md) contains exact-image preparation, a PRoot/QEMU runner, destructive-command stubs, harmless hook fixtures, and trace routing. The runner clears the host environment and supplies a deterministic root-style guest environment. QEMU `QEMU_STRACE` output is captured for each matrix case.

The exact BusyBox is ARM32 little-endian EABI5, dynamically linked with musl hard-float through `/lib/ld-musl-armhf.so.1`. This supports `qemu-arm` user-mode execution once a Linux host layer is available.

## Execution status

Actual ARM execution is pending. The current Windows host has neither QEMU user mode nor WSL; an attempted `wsl --install --no-distribution` did not enable it and Windows reports that WSL is not installed. Shell syntax, dependency failure behavior, exact hashes and rootfs preparation logic were validated locally. Files beneath `emulation/traces/` are explicitly labeled expectations rather than observations.

## Resume criteria

After WSL/Linux becomes available:

1. prepare the exact rootfs and verify its hashes;
2. execute BusyBox `true`, `id`, and `env` as representative smoke tests;
3. run the complete hook matrix;
4. inspect syscall traces for interpreter resolution, permissions, blocking and path access;
5. only then attempt `rpmServer` startup with no external network and stubbed mobile/WLAN IPC.

Full-system emulation is not currently justified: userspace execution addresses the hook question directly, and no verified board-machine model or bootable kernel/DTB pairing has yet been demonstrated.
