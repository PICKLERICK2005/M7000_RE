# Synthetic status round-trip summary

## Result

The exact `3.0.2 Build 241129 Rel.3n` `rpmServer` completed one local `status:0` request with result `0` while receiving deterministic zero-state flow and WLAN provider values. No request reached the physical router, and the syscall trace contained no access to `flowstate.sock`, `ha_wm.sock`, or `wlan_local.sock` during the shimmed run.

The response retained the normal composite status shape and exact public build identity. Raw response material remains ignored; identity-shaped defaults are not committed.

## Recovered flow response

The flow client sends one of four two-byte commands to `/tmp/flowstate.sock`:

| Command | Meaning inferred from caller | Reply model |
| --- | --- | --- |
| `FM` | monthly flow | 32 bytes |
| `FD` | daily flow | 32 bytes |
| `FT` | transmit speed | 32 bytes |
| `FR` | receive speed | 32 bytes |

The daemon preserves the two-byte command, places `:` at byte 2 and an ASCII numeric value from byte 3, then NUL-pads the fixed 32-byte reply. This layout is established by daemon/client disassembly; the semantic labels are inferred from the importing function names.

## Recovered WLAN response

The WLAN protocol uses an 8192-byte request buffer with a four-word little-endian header:

```text
offset  size  field
0x00    4     command
0x04    4     kind/result (1 in requests, 0 in successful replies)
0x08    4     result/reserved (0 for these calls)
0x0c    4     payload length
0x10    n     payload
```

`status:0` uses only these reads:

| Command | Provider call | Zero-state payload | Total reply |
| --- | --- | --- | --- |
| `0` | WLAN switch | 4 bytes | 20 bytes |
| `4` | WLAN configuration | `0x198` bytes | 424 bytes |
| `3` | associated station count | 4 bytes | 20 bytes |

The client verifies the echoed command, two zero status words, exact payload length, and that the received buffer contains the declared payload before copying it.

## Minimal implementation

[`emulation/stubs/ipc-zero.c`](../stubs/ipc-zero.c) is a strict wire-level reference responder. It accepts only the four observed flow commands and three observed WLAN read commands and emits only zero-state replies.

PRoot exposes the socket files but does not deliver these pathname datagrams reliably between separate emulated processes. The validated harness therefore uses [`emulation/stubs/status-zero.c`](../stubs/status-zero.c), a provider-level `LD_PRELOAD` shim implementing only the corresponding imported read functions. It performs no configuration or device access.

Run the validated case with:

```sh
M7000_IPC_MODE=zero emulation/scripts/run-rpc-probes.sh
```

## Phase decision

The sandbox has reached its useful limit for this objective. It is sufficient for isolated backend experiments and hook work, but additional service emulation would add complexity without improving the next read-only questions. Partial service emulation is practical; full-system emulation is not warranted. Resume the previously queued narrowly scoped live read-only RPC plan next.
