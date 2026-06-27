# W006 DoEvents-Yield Oracle Capture

Capture id: doevents-yield-20260627T161225Z
Bead: `oxforms-0a0.23`
Status: `captured`

Black-box Excel/MSForms evidence for reentrant event dispatch during a `DoEvents` pump. Not an OxForms output comparison and not an exhaustive parity claim.

## Facts

- `doevents-yield-event-log.json`/`.csv` are worksheet rows from repo-owned VBA handlers while live Excel handled two injected clicks.
- The outer `YieldButton_Click` (handler_depth 1) logs `BeforeDoEvents`, pumps `DoEvents`, then logs `AfterDoEvents`. A second click injected during the pump reenters the handler at `handler_depth` 2 (`ReentrantClick`), sandwiched between those rows.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, public Windows input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.
