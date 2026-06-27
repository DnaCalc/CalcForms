# W008 Key-Mutation Oracle Capture

Capture id: w008-key-mutation-20260627T220715Z
Bead: `oxforms-esq.3`
Status: `captured`

Black-box Excel/MSForms evidence for UserForm keyboard fold-back (KeyCode/KeyAscii swallow), default-button Enter, and Change timing. Not an OxForms output comparison and not an exhaustive parity claim.

## Facts

- Observed scenarios: `arrow_swallow, change_timing, default_button_enter, swallow_keydown, swallow_keypress`; total rows: `20`.
- `w008-key-mutation-event-log.json`/`.csv` are W008BreadthLog rows from repo-owned VBA handlers while live Excel handled injected keyboard input.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, public Windows input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.
