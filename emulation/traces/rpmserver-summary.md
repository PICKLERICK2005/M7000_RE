# `rpmServer` startup summary

A three-second, syscall-traced startup of the exact firmware binary was run with clean synthetic runtime directories. The process group was then force-reaped; exit 137 is the harness termination status, not an application crash.

Observed:

- all required shipped shared libraries resolved from the extracted rootfs;
- `rpmServer` unlinked any stale `/tmp/tp_rpm_server.sock`;
- it created an `AF_UNIX`, `SOCK_DGRAM` socket;
- it successfully bound `/tmp/tp_rpm_server.sock` and changed its mode to 0777;
- it continued running and reading real UCI files including `mobile_status` and `wlan`;
- absent runtime dependencies included `/dev/log_main`, `/dev/log_radio`, `/dev/log_events`, `/dev/log_system`, and transient `/tmp/.uci` state;
- no external network listener was observed in this startup trace.

This makes partial backend-service emulation practical. The next sandbox task should add narrow logging stubs for mobile/WLAN IPC and send only malformed or known read-only datagrams to the local socket. Full-system emulation is still unjustified.
