# Watchdog process-exit race

The recovery aggregate reproduced the earlier StrictMode failure: a process can
exit after Get-Process returns but before MainModule.FileName is read. The
aggregate reported 53/54, with only the member oracle failing. An isolated run
of the original member check then passed, consistent with the scheduling race.

The watchdog now reads identity through one helper shared by polling,
authorization and timeout termination. If a module read fails or returns null,
the helper refreshes and checks HasExited. Only a confirmed exit returns no
identity; an alive process with missing identity or another error still fails.
Authorization records that exit as unexpected and never acknowledges it.
Timeout handling never kills a process without the exact start/path identity.

The existing watchdog test extracts the actual nested helper and deterministically
simulates exit during MainModule access, both null and throwing reads. It also
checks that an alive process with a missing module fails, and that a successful
read preserves exact start time and path. Existing disposable-process cases
continue to cover authorization races, PID/path mismatch, containment,
descendant cleanup, abrupt supervisor death and terminal records.
No Excel launches or Office changes are used by these checks.

Verification: focused watchdog checks and a fresh aggregate evidence run passed
54/54 after the fix. The recovery Rust floor passed 208 tests, seven existing
ignored, plus fmt/clippy, whitespace and bead-cycle checks.
