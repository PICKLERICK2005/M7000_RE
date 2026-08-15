# rpmServer RPC probe summary

## Boundary

These observations come from the exact extracted `3.0.2 Build 241129 Rel.3n` userspace under QEMU/PRoot. No request reached the physical router. The harness sent only malformed input and two actions already classified as read-only from the stock frontend: `status:0` and `log:5`.

Raw syscall logs and complete responses remain local and ignored. Device-identity-shaped defaults are deliberately omitted here.

## Wire format

`rpmServer` binds an `AF_UNIX`, `SOCK_DGRAM` socket at `/tmp/tp_rpm_server.sock`. A request is a UTF-8 JSON object sent directly as one datagram; no HTTP, length prefix, or additional envelope is present. The response is another JSON datagram returned to the caller's bound Unix socket.

| Probe | Observed result |
| --- | --- |
| non-JSON bytes | Structured JSON error: result `1`, no response string |
| empty JSON object | Same structured error |
| `status:0` | Result `0` and the composite status model |
| `log:5` | Result `0`, `mdLogState` `2` |

`mdLogState: 2` is an observed emulated value only. Its user-facing meaning remains unclassified until its frontend mapping or backend enum is recovered.

## Composite status behavior

The emulated `status:0` response preserves the stock model shape and exact build identity, but runtime values fall back to factory/default placeholders because modem, flow-state, and WLAN peers are absent. The returned groups include:

- factory-default state and product/region/build metadata;
- device information, including modem/SIM identity-shaped fields;
- battery state;
- WAN, radio, operator, addressing, and traffic state;
- WLAN state;
- connected-device and unread-message counts;
- login-mode state.

The committed record contains field categories rather than raw identity-shaped values. The successful default response establishes that one `status:0` request aggregates several backend providers and tolerates missing peers.

## Downstream IPC observed

During `status:0`, the real binary attempted only local Unix IPC:

- mobile support created per-process `/tmp/mp_clnt_*` datagram paths;
- flow statistics targeted `/tmp/flowstate.sock`, using two-byte requests `FM`, `FD`, `FT`, and `FR`, with `/tmp/flowstate_client.sock` as its local path;
- WLAN support created `/tmp/wlan_local.sock` and attempted to connect to the absent WLAN-manager peer; static strings identify `/tmp/ha_wm.sock` as that peer.

No Internet-domain socket was observed in this run. These endpoints are candidates for passive logging substitutes, but deterministic replies must wait until their response layouts are recovered.

Offline disassembly of the exact `flowstat` daemon narrows that layout further: it receives into a 110-byte buffer, classifies the two command bytes, and sends a fixed 32-byte datagram back to the caller. At least some numeric replies retain the two-byte command prefix and parse ASCII data beginning at byte offset 3. That is sufficient to build a strict parser and capture stub, but not yet sufficient to synthesize every command's reply safely.

## Assessment

The proprietary frontend RPC boundary is reproducible in userspace, and partial backend-service emulation is practical. The safe next step is offline recovery of the flow-state and WLAN response structures, followed by narrow logging stubs. Full-system emulation is still unjustified.
