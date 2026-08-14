# Firmware version comparison

All comparisons are offline against the official UAE V3.20 packages acquired on 2026-08-15. Counts based on Windows extraction omit symlink aliases; conclusions below rely on regular-file hashes and directly observed additions.

| Release | `update.bin` bytes | Rootfs bytes | Rootfs inodes |
| --- | ---: | ---: | ---: |
| 3.0.1 Build 240902 | 25,616,384 | 10,805,836 | 1,383 |
| 3.0.2 Build 241129 | 25,616,384 | 10,806,548 | 1,383 |
| 3.0.4 Build 250814 | 26,025,984 | 11,220,382 | 1,439 |

## 3.0.1 to 3.0.2

This is a narrow maintenance release. The FBF and inode counts are unchanged and the rootfs grows by only 712 bytes. Fourteen common regular files differ in the local comparison; notable changes include `etc/NetIspInfo.ini`, product/version metadata, and the opkg trust key. This is consistent with the vendor's stability-oriented release note, but static differences alone do not identify the fixed defect.

## 3.0.2 to 3.0.4

This is a broader security/UI release: `update.bin` grows by 409,600 bytes and the rootfs adds 56 inodes. Direct additions include HTTPS/lighttpd OpenSSL configuration and module, `cloud_https`, `libssh.so.4.8.7`, security/console/accessibility configuration, an accessibility asset tree, a security page, certificate-download CGI, and a welcome flow. Core frontend bundles, all principal CGI handlers, `rpmServer`, `mobile`, USB/update configuration, and ISP data also changed.

The Debug Log architecture remains present in 3.0.4, but changed hashes mean behavior should not be assumed byte-identical without disassembly. The 3.0.4 additions align with the official release note's security claim and show that the security work materially touched HTTPS and the management UI.

## ISP package

The separately published `ISP_upgrade_asr(EU)` ZIP contains a 42-byte attachment record and a 37,895-byte `NetIspInfo` payload. The payload begins with Base64 `U2FsdGVkX1`, decoding to OpenSSL's `Salted__` envelope. It is therefore an encrypted update object rather than a drop-in plaintext replacement for the 237,735-byte `/etc/NetIspInfo.ini`. No attempt was made to submit it to a device or bypass its installer.
