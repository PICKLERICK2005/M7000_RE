# Persistent debug and diagnostic paths (3.0.2)

All findings below come from the extracted `3.0.2 Build 241129 Rel.3n` filesystem. Nothing was invoked on the router.

## `/misc/m7000_debug.sh`

Observed facts:

- `etc/init.d/execute_debug_shell` is an `rc.common` service with `START=99`.
- Its `start()` tests only `-e /misc/m7000_debug.sh` and then executes that path with no arguments.
- No signature, hash, ownership, or content check is present in the script.
- `etc/init.d/check_device_code` attaches the `tp_data` UBI volume as `ubi2_0` at `/misc`. On a production-mode unit with its required factory data present it remounts that volume read-only.
- The same volume contains factory-burned identity/region files and persistent ISP profile files. Device-specific contents were neither acquired nor recorded.
- The normal reset-button path runs `jffs2reset`; the inspected reset scripts do not format or erase `tp_data`. This is evidence that `/misc` survives an ordinary factory reset, not a guarantee for every recovery/update path.

Inference: the late, unvalidated hook is likely a factory/service mechanism and normally executes with init-service/root authority. Its exact inherited environment has not been reproduced. Creating the file would require remounting sensitive persistent storage and is not an acceptable first experiment.

## Debug Log RPC

`rpmServer` contains `/usr/bin/start_mdlog`, `/usr/bin/stop_mdlog`, `pgrep diag_mdlog`, and `mdLogState`. The referenced helpers and `diag_mdlog` executable are absent from the shipped SquashFS. Therefore `log:4` is state-changing but its complete runtime dependency/source remains unresolved; it may expect a dynamically supplied or persistent component. `log:5` is the state query. Normal `log:2` collection is separate and builds `/cache/savelog.tar.gz` from system/configuration/network logs.

## CATStudio

`etc/init.d/use_flash_to_save_CATStudio_log.sh` is a manual command script, not a normal `rc.common` service. `start` swaps the Marvell diagnostic configuration, writes `/cache/enable_diag`, and reboots. `clean_and_start` first runs `ubiformat` on the `swap_flash` MTD partition. `stop` removes the marker, restores the config, and reboots.

`sbin/mrvl_init_aquila` starts `sulog`, `cp_load`, and `diag`, configures Marvell diagnostic/debug USB gadget functions, then delays `u3start` specifically for CATStudio image-ID timing. This establishes a CP/Marvell diagnostic path but does not show that the stock user USB mode exposes it.

Classification: CATStudio is a deeper, rebooting diagnostic mode; `clean_and_start` is explicitly destructive to `swap_flash`. It must remain inactive.
