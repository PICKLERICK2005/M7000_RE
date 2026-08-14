# Soft Capture 001: Frontend Endpoint Map

Record only requests made by normal stock-UI navigation. Do not manually invoke undocumented endpoints during this capture.

| UI trigger | Method | Path | Request type | Response type | Authentication | Parameters/fields | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Login page load | POST | `/cgi-bin/web_cgi` | Base64-wrapped JSON | Base64-wrapped JSON | None | `module=webServer`, `action=5` | Returns API version and feature gates |
| Login page load/status refresh | POST | `/cgi-bin/web_cgi` | Base64-wrapped JSON | Base64-wrapped JSON | None | `module=webServer`, `action=6` | Returns sanitized pre-auth device/network summary |
| Login initialization | POST | `/cgi-bin/auth_cgi` | Base64-wrapped JSON | Base64-wrapped JSON | None | `module=authenticator`, `action=0` | Returns nonce/RSA/session initialization metadata; values not recorded |
| Login-attempt status | POST | `/cgi-bin/auth_cgi` | Base64-wrapped JSON | Base64-wrapped JSON | None | `module=authenticator`, `action=2` | Returns remaining/total attempts and lock interval |
| Login submission | POST | `/cgi-bin/auth_cgi` | Frontend-encrypted JSON | Frontend-encrypted JSON | Login digest | `module=authenticator`, `action=1` | One rejected attempt; credential and payload not recorded |
| Authenticated model calls | POST | `/cgi-bin/web_cgi` | AES-wrapped JSON in GDPR mode | AES-wrapped JSON | `tpweb_token` plus encrypted session state | Module/action varies | Capture through normal UI navigation after verified login |

## Authenticated read-only calls observed during normal navigation

The frontend RPC wrapper was instrumented to record module/action pairs only. Parameters, tokens, response bodies, and unique values were not captured.

| Module | Actions observed | Triggered by |
| --- | --- | --- |
| `status` | `0` | Status and Device Information |
| `message` | `2` | SMS pages |
| `wan` | `0`, `10`, `11` | Dial-up, network, ISP/USSD-related pages |
| `simLock` | `0` | PIN Management |
| `voice` | `0`, `3` | USSD-related page behavior |
| `wlan` | `0` | Wireless Settings |
| `connectedDevices` | `0` | Online Clients |
| `macFilters` | `0` | Blacklist |
| `lan` | `0` | DHCP Server |
| `flowstat` | `0` | Data Usage Settings |
| `power_save` | `0` | Power Saving |
| `update` | `0` | Software Update |
| `time` | `0`, `2` | Time Settings |
| `log` | `0`, `3`, `5` | System Log |

Action meanings should be assigned only after corroborating them against frontend model definitions. Navigation did not click save, clear, update, restore, shutdown, send, delete, or other mutating controls.

## Transport observations

| Item | Observation |
| --- | --- |
| Base URL/origin | `http://192.168.0.1/` |
| HTTP or HTTPS | HTTP |
| Session mechanism | Token plus RSA/AES frontend encryption when GDPR feature is enabled |
| Cookies used | `tpweb_token` name observed; value never recorded |
| CSRF mechanism | |
| Payload encoding/encryption | Base64-wrapped JSON before authentication; encrypted JSON for protected calls in GDPR mode |
| REST/CGI/RPC/WebSocket pattern | Proprietary module/action RPC over two CGI endpoints |

## Privacy check before commit

- [x] No passwords, cookies, tokens, or authorization values
- [x] No IMEI, IMSI, ICCID, serial number, or full MAC address
- [x] No default SSID or Wi-Fi password
- [x] No subscriber-specific phone number or APN credentials
- [x] No raw request/response bodies containing unique identifiers
