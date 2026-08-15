# Mobile daemon synthetic startup

## Scope and containment

The physical router was disconnected. The test used the exact official
`3.0.2 Build 241129 Rel.3n` update image (`a1be63a6...56d7`) and verified
SquashFS component (`5dfddb34...02af8`). Both the extraction mountpoint and all
overlays were beneath ignored repo-local `emulation/work/` paths.

The complete userspace rootfs was extracted to an ephemeral, case-sensitive
tmpfs at `emulation/work/runtime-rootfs` inside a private WSL user/mount
namespace. This was necessary because the Windows filesystem cannot represent
seven case-distinct kernel/iptables filename pairs. `/dev/console` was excluded;
no device nodes were created. The mount vanished with the namespace.

The preflight resolved every direct dependency and required all containment
symbols before launch. The interposer denied IP sockets, arbitrary raw syscalls,
external commands, deletion, device/host-root paths, WAN notifications, and
WLAN-control calls. Only `/tmp/atcmd` stream connections and pathname Unix
datagrams beneath the synthetic `/tmp` were eligible to pass. Logs contained
fixed event names only.

## Dependency order observed

The dynamic loader opened these direct dependencies:

1. `libstdc++.so.6`
2. `liblog.so`
3. `libdata_management.so`
4. `libcjson.so`
5. `libwmcomm.so`
6. `libnetmanager.so`
7. `libgcc_s.so.1`
8. `libc.so`

Transitive startup dependencies observed were `libprop2uci.so`,
`libubox.so.20210516`, `libuci.so`, and `libset_get.so`.

## Runtime observations

The first five-second attempt on the Windows-hosted extracted tree did not
reach firmware initialization; it was still loading `libset_get.so` at cutoff.
The case-sensitive ephemeral-rootfs iteration reached the following sequence:

1. create disposable `/etc/config/sms_raw.db` and `/etc/config/sms.db`;
2. attempt four blocked device-path opens;
3. attempt one blocked non-AT Unix connection;
4. read `/etc/config/mobile_config` and `/etc/config/mobile_status` through the
   UCI/data-management stack;
5. attempt `/misc/NetIspInfo.ini`, which was absent;
6. read `/etc/CountryInfo.ini`;
7. create four worker threads;
8. create two `AF_UNIX/SOCK_DGRAM` sockets and attempt their pathname binds.

`/tmp/mp_svr_file` was present during capture. `/tmp/atcmd` remained the
synthetic listener. No raw device-specific value was captured.

Containment recorded, in order, four `device-path-open-denied` events, one
`connect-denied`, and two `unlink-denied` events. Static string correlation
shows that `liblog.so` owns `/dev/log_main`, `/dev/log_radio`,
`/dev/log_events`, `/dev/log_system`, and `/dev/kmsg`; the four early opens are
therefore likely logging initialization, but QEMU tracing cannot prove the
individual path because the interposer intentionally does not log arguments.
The blocked connection target remains unresolved. It was not `/tmp/atcmd`,
which is the sole allowed stream destination.

The eight-second iteration was stopped at its planned cutoff and its process
group reaped. The wrapper reported status 0 after termination; this is not
evidence that the daemon naturally exited. A subsequent process audit found no
`mobile`, QEMU, PRoot, or AT-stub process.

## Negative observations

During the captured window there were:

- no AT commands, including no rejected mutation;
- no mobile event datagrams and therefore no runtime event IDs;
- no CP reset or NVM-switch attempt;
- no WAN/network-manager notification;
- no WLAN-control call;
- no `sendto()` or `recvfrom()` traffic; and
- no modem, serial, SMD, MTD, or UBI node access.

The runtime proves that `mobile` initializes the UCI/data-management storage
layer before its event and modem paths. Syscall tracing does not reveal the
internal numbered record IDs passed between `mobile` and
`libdata_management`; only the backing `mobile_config` and `mobile_status`
models were observed. Existing static evidence remains authoritative for known
record IDs such as IMSI record 24.

## Architectural correlation and decision

The observed order is consistent with:

```text
mobile
  -> libdata_management / UCI shared state
  -> mobile Unix-datagram event server
  -> AT/ACIPC boundary (not reached during this window)
  -> CP
```

The run validates the first two layers without touching a CP or physical
device. Advancing farther would require emulating additional logging and
mobile-internal peers, and would no longer be a minimal observation harness.
Another emulation iteration is not presently justified. Preserve the harness
and return to the separately prepared, fixed-allowlist live read-only RPC
validation when the user explicitly reconnects the router for that phase.

