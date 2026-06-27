# W006 Terminate Lifetime Oracle Capture

Capture id: terminate-lifetime-20260627T144316Z
Bead: `oxforms-0a0.21`
Status: captured

This directory contains black-box Excel/MSForms evidence for focused UserForm object-lifetime scenarios. It is not an OxForms output comparison and it does not claim exhaustive lifecycle parity.

## Observed Facts

- `w006-terminate-lifetime-event-log.json` and `.csv` contain worksheet rows emitted by the fixture VBA handlers and action macros.
- `input-actions.json` records macro calls, optional public window-message attempts, and explicit skipped-path blockers; `manual_inputs` is empty.
- Terminate rows, when present, include the fixture reference-state columns visible at handler entry.

## Run Observations

- Live Excel/MSForms export produced 25 W006TerminateLog rows.
- Observed scenarios: hide_held_release, unload_held_release.
- Terminate rows exported: 1.

## Assumptions

- Fixture reference-state columns are explicit repo-owned VBA state, not private Office reference counts.
- Public `WM_CLOSE` is treated as a modeless close request only when it is sent to the visible UserForm window and the run can still export its worksheet evidence.

## Blockers

- `modeless_system_close_held_release`: Run with -SkipModelessCloseAttempt. PostMessage(WM_CLOSE) does close the modeless UserForm (wm_close_status=completed) but then leaves Excel COM unavailable (RPC 0x800706BA / DISP_E_EXCEPTION on the next excel.Run), so the held-reference release/export step cannot complete. Reconfirmed on a 2026-06-27 live attempt.
- `modal_hide_return_held_release`: Run with -SkipModalReturnAttempt: a macro-driven Show vbModal blocks the COM thread (excel.Run does not return until the modal closes), so the capture cannot hold the modal open and drive/export it from the same thread. This is a structural limit of the macro-driven path, not an Excel availability flake.
- `modal_unload_return_held_release`: Run with -SkipModalReturnAttempt: a macro-driven Show vbModal blocks the COM thread (excel.Run does not return until the modal closes), so the capture cannot hold the modal open and drive/export it from the same thread. This is a structural limit of the macro-driven path, not an Excel availability flake.

## Non-claims

- No OxForms runtime Terminate timing behavior is implemented or claimed.
- Missing rows are unobserved in this run, not negative MSForms facts.
- `Unloaded` and `Terminated` remain separate trace/replay concepts.

## Clean-room Note

The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, optional public user32 window messaging when attempted, and public worksheet export. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.
