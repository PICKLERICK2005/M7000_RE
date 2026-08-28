# Userspace emulation 001

## Objective and boundary

The current phase diverts from - but does not abandon - live read-only RPC probing. Its milestone is execution of the exact 3.0.2 firmware path that checks and launches `/misc/m7000_debug.sh`, using only synthetic storage and intercepted destructive operations. The physical router, USB interface, Debug Log, CATStudio, and live `/misc` remain out of scope.

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

## Execution results

WSL 2, QEMU user mode, and PRoot now execute the exact firmware userspace. Representative BusyBox commands resolve the stock musl loader and run as ARMv7. The real `S99execute_debug_shell boot` path passed the full fixture matrix, establishing permission behavior, exit propagation, synchronous blocking, controlled environment, and write access to synthetic persistent/runtime paths. See [`emulation/traces/debug-hook-summary.md`](../emulation/traces/debug-hook-summary.md).

An `rpmServer` startup smoke test also bound the real `/tmp/tp_rpm_server.sock` datagram socket and remained running until the harness reaped it. Missing log devices and live UCI/mobile state are now bounded partial-emulation targets. See [`emulation/traces/rpmserver-summary.md`](../emulation/traces/rpmserver-summary.md).

Allowlisted local probes subsequently confirmed that this socket carries one raw JSON request and response per Unix datagram. Malformed input produces a structured error; known read-only `status:0` returns the composite model with offline defaults, and `log:5` reports `mdLogState` `2`. The status call also exposes dependencies on mobile, flow-state, and WLAN Unix IPC. See [`emulation/traces/rpc-probe-summary.md`](../emulation/traces/rpc-probe-summary.md).

Offline disassembly recovered the flow and WLAN reply layouts needed by `status:0`. A minimal provider shim then produced a clean synthetic zero-state response through the real `rpmServer`, without downstream socket or device access. See [`emulation/traces/synthetic-status-summary.md`](../emulation/traces/synthetic-status-summary.md).

## Resume criteria

The userspace sandbox has reached its useful limit for the present objective. The next phase is the previously queued narrowly scoped live read-only RPC probing; the physical-device restrictions and sanitization rules remain in force.

Full-system emulation is not currently justified: userspace execution addresses the hook question directly, and no verified board-machine model or bootable kernel/DTB pairing has yet been demonstrated.
