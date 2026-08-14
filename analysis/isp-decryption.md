# ISP package consumer (3.0.2)

The official `ISP_upgrade_asr(EU)` package was analyzed entirely offline.

## Recovered pipeline

`usr/lib/libispupdate.so` unpacks the outer update into `/tmp`, invokes:

```text
mbedtls_aes-128-ecb <encrypted input> <decrypted ZIP> <embedded passphrase>
```

and then extracts `NetIspInfo.ini`. It verifies the profile MD5, remounts `ubi2_0` at `/misc` read-write, installs the profile plus `md5.txt`, remounts read-only, and reloads the mobile ISP data.

Relevant strings are at file offsets `0x214d` (command template), `0x2119`–`0x218d` (temporary and persistent paths), and `0x21b9` (embedded passphrase) in `libispupdate.so`. The consumer function begins near `0x11a4`; command construction occurs around `0x13b4`–`0x13d8`.

`usr/bin/mbedtls_aes-128-ecb` recognizes the OpenSSL `Salted__` envelope, derives one 16-byte key as `MD5(passphrase || salt)`, and decrypts AES-128-ECB with PKCS#7 padding. This was confirmed by reproducing the exact inner ZIP:

- encrypted Base64 payload SHA-256: `2ac3152a690ebbf71a1856536a3f8cf65392e7cda2de7cba07358af68c2847b8`
- decrypted ZIP SHA-256: `5793981a41cbe97511dc5bd69233357aa76d1a7138c81780ced7dec995c4ec3a`
- extracted profile SHA-256: `1ee62f67723793276351892e7139f48d2ea0f53997b790b82863460a4eb52ae6`
- extracted profile MD5 matches the outer attachment metadata: `72dfc58e300a8e3edcd9fdf095a4cc0a`

`tools/isp-inspect.mjs` reproduces this format without guessing. The embedded passphrase is intentionally not printed in normal output, although exact decoding necessarily incorporates it. Decrypted vendor artifacts remain ignored and are not committed.
