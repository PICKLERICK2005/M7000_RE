# Stock firmware archive

This directory inventories immutable TP-Link vendor downloads used by the project. `manifest.json` records the source URL, acquisition date, original filename, size, and hashes for each archive layer. `SHA256SUMS` provides a quick integrity check.

The original downloads are deliberately excluded from Git history to avoid permanently adding roughly 65 MiB of opaque binaries to every clone. Preserve them byte-for-byte as GitHub Release assets using their original filenames; do not recompress or rename them. Extracted root filesystems and other reproducible working files belong under the ignored `firmware/work/` tree.

Until release assets are published, the manifest and official source URLs are the canonical acquisition record. A downloaded file is accepted only when its SHA-256 matches `SHA256SUMS`.

No hash in this directory constitutes a vendor signature or proof of authenticity.
