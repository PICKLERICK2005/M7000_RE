# AP to Modem Control Path

```text
stock web UI
  -> web_cgi / auth_cgi
  -> /tmp/tp_rpm_server.sock
  -> rpmServer
  -> libmobile.so
  -> mobile daemon (/tmp/mobile_msg_server.sock and related sockets)
  -> libmarvellril.so / rild / atcmdsrv
  -> /dev/smd0, /dev/ttyS1 and ACIPC-backed services
  -> CP/RTOS NVM, SIM, network and diagnostic handlers
  -> GRBI Layer-1 / RF execution
```

## Confirmed AP-side links

- `rpmServer` imports `GetAllStatus` and narrower SIM, signal, registration,
  operator, connection, and RF-band getters from `libmobile.so`.
- The mobile daemon names `/tmp/mobile_msg_server.sock`,
  `/tmp/wm_lte_wifi.sock`, `/tmp/ha_wm.sock`, and `/tmp/mp_clnt_*` paths.
- `/etc/config/at_channel` maps channels to `/dev/ttyS1` and `/dev/smd0`.
- `/etc/telinit` starts `cp_load`, `nvmproxy`, `atcmdsrv`, and `rild` in the
  normal CP-enabled path.
- `libmarvellril.so` contains RIL request handlers and `/tmp/atcmd` vocabulary.
- CP `ARBI` contains matching ACIPC, NVM-client, diagnostic, SIM, and cellular
  control subsystems.

## Supported inference

The AP and CP meet through more than one logical channel: an ACIPC/shared-memory
transport underneath Linux CP services, SMD/serial AT channels for command
traffic, and dedicated diagnostic paths. The exact packet framing and RPC IDs
remain to be recovered from `mobile`, `libmobile.so`, `libmarvellril.so`,
`atcmdsrv`, and the CP handlers.

AP UCI owns UI policy and profiles such as APN selection, while CP NVM owns or
consumes radio, calibration, lock, and low-level modem state. SIM-derived and
runtime network fields remain dynamically sourced.

