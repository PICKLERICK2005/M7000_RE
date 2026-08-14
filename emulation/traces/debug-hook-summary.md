# Debug-hook trace summary

Observed under WSL 2 with QEMU 10.2.1, PRoot 5.4.0, and the exact verified `3.0.2 Build 241129 Rel.3n` rootfs. Raw per-run syscall logs are locally retained under ignored subdirectories and are reproducible with `run-hook-test.sh all`.

The tested entry point was `/etc/rc.d/S99execute_debug_shell boot`. The preserved symlink reached the vendor `execute_debug_shell` init script, which was interpreted through the vendor `/etc/rc.common`; fixtures were not invoked directly.

| Case | Exit | Observation |
|---|---:|---|
| absent | 0 | `stat64("/misc/m7000_debug.sh")` returned `ENOENT`; no fixture execution. |
| empty executable | 1 | Existence succeeded, `execve` was attempted, and the service returned 1. This may be a QEMU/PRoot empty-script edge case and should not be generalized to hardware. |
| `exit 0` | 0 | `execve` opened the fixture and both child and service returned 0. |
| diagnostic | 0 | Commands ran successfully where the minimal namespace supplied their inputs. |
| `exit 42` | 42 | The fixture’s exact failure status propagated through `start()` and `rc.common`. |
| two-second sleep | 0 | Epoch markers differed by three seconds (one-second granularity plus overhead), proving synchronous blocking. |
| mode 0644 | 126 | `execve` returned `EACCES`; `rc.common` reported permission denied. |

## Execution context

- emulated primary identity: UID 0, GID 0;
- supplementary group numbers came from the unprivileged WSL host and are a PRoot artifact, not a device finding;
- working directory: `/`;
- fixture interpreter: `/bin/sh`, the firmware BusyBox/musl shell;
- explicit fixture arguments: none;
- controlled inherited environment: `HOME=/`, `USER=root`, `LOGNAME=root`, `SHELL=/bin/sh`, `TERM=dumb`, and `PATH=/sandbox-stubs:/usr/sbin:/usr/bin:/sbin:/bin`; QEMU/PRoot control variables and shell bookkeeping were also inherited;
- `/misc`, `/cache`, and `/tmp` were writable: the diagnostic fixture created a harmless 18-byte sentinel in each synthetic directory;
- `/dev` contained only the explicitly bound null device;
- `/proc` was not mounted, so `mount` reported no `/proc/mounts` and `ps` had no process entries beyond its header.

The hook inherits its caller’s environment; the firmware script does not sanitize or augment it. This harness establishes behavior for the controlled environment, while the exact physical PID 1 environment remains an inference from OpenWrt boot conventions.

## Containment qualification

Destructive command interception was verified with an absolute `/sbin/reboot --fixture-only`: it logged the request and exited 125 without rebooting. PRoot requires and exposes an internal `/host-rootfs` view, so this is suitable for reviewed firmware/fixtures but is not a hardened boundary for an unknown hostile script.
