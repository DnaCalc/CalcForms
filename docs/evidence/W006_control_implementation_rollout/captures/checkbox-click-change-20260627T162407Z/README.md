# W006 CheckBox Click-vs-Change Oracle Capture

Capture id: checkbox-click-change-20260627T162407Z
Bead: `oxforms-p41`
Status: `captured`

Black-box Excel/MSForms evidence for the CheckBox Click-vs-Change ordering. Not an OxForms output comparison and not an exhaustive parity claim.

## Facts

- Observed order: `change_before_click`; CheckBox .Value seen by the Click handler: `True`.
- `checkbox-click-change-event-log.json`/`.csv` are worksheet rows from repo-owned VBA handlers while live Excel handled one injected click.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, public Windows input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.
