# Debug-hook test expectations

These are hypotheses pending execution, not captured results.

| Case | Expected result |
|---|---|
| absent | Existence test fails; service returns success without executing a fixture. |
| empty | The executable empty file may be handled by BusyBox shell after `ENOEXEC`; trace decides. |
| exit-0 | Script executes as emulated root from `/` and service returns 0. |
| diagnostic | Context is recorded at `/traces/hook-context.txt`; no state-changing command is used. |
| failing | Exit 42 propagates through `start()` and `rc.common`; an OpenWrt boot caller may log/ignore it. |
| blocking | The service call takes at least the fixture's two-second sleep, demonstrating synchronous execution. |
| non-executable | Existence test passes but execution fails with permission denied, likely status 126. |

The trace must establish interpreter resolution, UID/GID, working directory, environment, blocking behavior, and accesses to persistent paths. Boot timing is statically `START=99`; userspace emulation cannot reproduce wall-clock timing relative to hardware initialization.
