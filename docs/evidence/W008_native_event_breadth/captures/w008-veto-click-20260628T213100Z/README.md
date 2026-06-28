# W008 Exit-Veto Mouse-Click Oracle Capture

Capture id: w008-veto-click-20260628T213100Z
Bead: `oxforms-esq.10` (consumed by `oxforms-esq.11`)
Status: `captured`

Black-box Excel/MSForms evidence for whether a vetoing focus `Exit` absorbs a focus-changing
mouse click. Not an OxForms output comparison and not an exhaustive parity claim.

## Facts

- `nonveto_click_baseline` (no veto): clicking TextBox2 off TextBox1 fires TextBox1 `Exit`
  (Cancel False->False) then TextBox2 `Enter` -> `MouseDown` -> `MouseUp`; focus moves to TextBox2.
- `veto_exit_click` (TextBox1 Exit armed to veto): the SAME click fires only TextBox1 `Exit`
  (Cancel False->True); focus stays on TextBox1 and there are ZERO events on the clicked TextBox2
  (no Enter/MouseDown/MouseUp). The vetoing Exit ABSORBS the click.
- Total rows: `9` across the two scenarios.

## Driving method (honest provenance)

Driven by computer-use vision (precise left clicks) plus a background-COM ready/done sentinel
handshake that held `Excel.Application` visible across the click. The canonical
`tools/office-oracle/Capture-W008VetoClick.ps1` SendInput path was unreliable under foreground
contention (a second user Excel competed for the foreground and the short-rendered form window
mis-aligned the blind coordinate clicks), so the click was vision-driven instead. The two
scenarios were two separate driver invocations merged into one log (rows 1-2 and 7-8 are
per-run setup: Initialize + Enter). `generated_workbook` is null -- the throwaway workbook was
not retained; the fixture sources + capture tool regenerate it deterministically.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, public clicks, and worksheet export
only. No Office internals, decompilation, disassembly, or OxForms output comparison.