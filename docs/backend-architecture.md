# Backend architecture

This map combines sanitized live observations from Soft Capture 002 with offline evidence from the exact 3.0.2 firmware.

```text
Browser (encrypted module/action RPC)
  -> auth_cgi / web_cgi
  -> Unix datagram IPC: /tmp/tp_rpm_server.sock
  -> rpmServer static module registry
     -> UCI/system/network/WLAN libraries
     -> libmobile client API
        -> mobile daemon IPC
        -> Marvell RIL and CP/modem services
```

`rpmServer` contains a static-looking registry of 19 module names; the sanitized inventory and known action meanings are in [`analysis/rpmserver-map.json`](../analysis/rpmserver-map.json). `web_cgi` and `rpmServer` both contain socket operations, while the latter embeds the Unix-socket path and JSON parse/error strings. This supports CGI-to-daemon forwarding; request framing beyond the already observed JSON/RPC wrapper remains to be reconstructed.

`status:0` calls the `libmobile` composite status API and supplements it with other subsystem data. The returned browser model spans product/firmware identity, SIM and radio, WAN/IP, battery, WLAN, connected clients, SMS and storage. See [`analysis/status-model.json`](../analysis/status-model.json) for the field-level live map and [`analysis/modem-boundary.md`](../analysis/modem-boundary.md) for native evidence.

Capability names are compiled into `rpmServer`, while actual values are returned at runtime. WPS has both a backend module and WLAN configuration despite being hidden on this model, so it is model/capability-gated. WISP frontend/config remnants exist, but `apBridge` is absent from the exact backend registry. NAT forwarding frontend assets exist while their expected RPC modules are absent. The RTL8192ES WLAN driver is 2.4 GHz-class hardware evidence, consistent with 5 GHz/11ac being physically unavailable. SD-card backend/logging support exists but requires unconfirmed hardware.

These classifications are version-specific negative evidence, not universal claims about all M7000 variants.
