# W006 CheckBox Space/Enter Keyboard-toggle Oracle Capture

Capture id: checkbox-keyboard-toggle-20260627T220935Z
Bead: `oxforms-0a0.12`
Status: `captured`

Black-box Excel/MSForms evidence for the CheckBox Space/Enter keyboard activation ordering (Click/Change/KeyDown/KeyUp) and the toggle timing (value_at_keydown vs value_at_keyup). Not an OxForms output comparison and not an exhaustive parity claim.

## Facts

- Event names: `Initialize, Change, Click, KeyDown, KeyUp, Change, Click, KeyDown, KeyUp`; value_at_keydown: `True`; value_at_keyup: `True`.
- `checkbox-keyboard-toggle-event-log.json`/`.csv` are worksheet rows from repo-owned VBA handlers while live Excel handled a focus click then injected Space then injected Enter.
- `input-actions.json` records the public mouse focus click and the public user32 SendInput Space then Enter; `manual_inputs` is empty.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, public Windows mouse and user32 SendInput keyboard input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.
