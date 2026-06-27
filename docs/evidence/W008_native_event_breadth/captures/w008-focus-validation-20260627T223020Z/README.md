# W008 Focus/Validation Oracle Capture

Capture id: w008-focus-validation-20260627T223020Z
Bead: `oxforms-esq.3`
Status: `captured`

Black-box Excel/MSForms evidence for UserForm focus transfer and validation (Exit/BeforeUpdate) fold-back. Not an OxForms output comparison and not an exhaustive parity claim.

## Facts

- Observed scenarios: `before_update_veto, exit_veto_keeps_focus, tab_transfer`; total rows: `30`.
- `w008-focus-validation-event-log.json`/`.csv` are W008BreadthLog rows from repo-owned VBA handlers while live Excel handled injected focus/key input.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, public Windows input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.
