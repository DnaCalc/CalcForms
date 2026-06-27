# W006 Ctrl+V Keyboard-ordering Oracle Capture

Capture id: ctrlv-keyboard-ordering-20260627T222310Z
Bead: `oxforms-0a0.17`
Status: `captured`

Black-box Excel/MSForms evidence for the Ctrl+V keyboard ordering (KeyDown/KeyPress/KeyUp vs BeforeDropOrPaste vs Change). Not an OxForms output comparison and not an exhaustive parity claim. This redoes the oxforms-0a0.17 keyboard-driver blocker on a working-input desktop.

## Facts

- Observed order: `keydown_before_paste`; event names: `Initialize, KeyDown, KeyDown, BeforeDropOrPaste, Change, KeyUp, KeyUp`.
- `ctrlv-keyboard-ordering-event-log.json`/`.csv` are worksheet rows from repo-owned VBA handlers while live Excel handled one injected Ctrl+V.
- `input-actions.json` records the public mouse focus click, the public Windows clipboard seed, and the public user32 SendInput Ctrl+V; `manual_inputs` is empty.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, the public Windows clipboard, public user32 SendInput keyboard input, and worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.
