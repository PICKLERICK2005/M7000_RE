# Mobile daemon sandbox gate

## Scope

This is a static startup-safety review of `usr/bin/mobile` and its immediate
dependencies from firmware `3.0.2 Build 241129 Rel.3n`. The daemon was **not**
started, and the physical router was disconnected.

## Why startup remains gated

The real daemon is not a passive status server. Its shipped strings and imports
show normal initialization paths for:

- SIM and operator queries;
- packet attach/detach and PDP-context activation;
- `AT+CFUN` modem-mode changes;
- automatic and manual operator selection;
- Quectel reset-level configuration;
- CP reset/reinitialization handling;
- `/usr/bin/nvm_switch.sh`;
- WAN/network-manager notifications and UCI updates.

The current PRoot/QEMU harness redirects the firmware filesystem and destructive
utilities, but it is not a network namespace or hardened security boundary.
Starting `mobile` merely to observe failure would therefore be low-value until
its modem-facing local interfaces are intercepted.

## Required minimum stubs

Before a controlled startup smoke test, provide fail-closed substitutes for:

1. `/tmp/atcmd`, using the recovered stream framing and query-only stub;
2. network-manager calls that can alter or announce WAN state;
3. CP reset and NVM-switch paths;
4. writable data-management/UCI state in the disposable overlay.

The implemented AT substitute accepts only an explicit, argument-free query
allowlist, returns deterministic synthetic responses, rejects all other
commands, and logs rejected input without its arguments. It never forwards
traffic to a serial, SMD, ACIPC, MTD, or host network interface. Its standalone
self-test covers both an allowed query and rejected `CFUN` mutation; this does
not yet authorize starting `mobile`.

The provider-level `mobile-containment.so` interposer now supplies the next
fail-closed boundary. It has no libc dependency and:

- permits `AF_UNIX` socket creation but denies IP socket creation;
- permits `connect()` only to the synthetic `/tmp/atcmd` endpoint;
- permits pathname-datagram `sendto()` only below the sandbox `/tmp` overlay
  and rejects abstract or non-Unix destinations;
- rejects `system()`, `unlink()`, and `remove()` without recording arguments;
- rejects the imported WAN notification and WLAN-control entry points; and
- writes only fixed event names to `/traces/mobile-containment.jsonl`.

This closes the currently identified host-network, NVM-script, deletion, and
network-manager call surfaces. The fixed-name logging intentionally sacrifices
argument visibility to avoid retaining identifiers or command contents.

## Current local-artifact gap

The exact extracted rootfs is not currently present under the repository's
ignored `emulation/work/` directory. Per the repository-only containment rule,
no older rootfs outside the checkout was used. The interposer compiles as an
ARM EABI5 shared object with no `DT_NEEDED` libraries, but the daemon must remain
unstarted until the byte-exact rootfs is restored inside `emulation/work/` and
the full preflight can be repeated there.

## Decision

Partial `mobile` emulation remains practical. The next step is to restore the
verified rootfs in the ignored repo-local work area, confirm loader compatibility
and imported-symbol coverage, then perform one time-bounded smoke test with the
AT stub and containment interposer. Full-system emulation remains unwarranted.
