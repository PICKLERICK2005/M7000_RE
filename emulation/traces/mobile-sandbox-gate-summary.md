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

## Decision

Partial `mobile` emulation remains practical, but launching the unmodified daemon
now would not improve the evidence enough to justify the side-effect surface.
Continue static recovery of `/tmp/atcmd` and the event dispatcher first. Full
system emulation remains unwarranted.
