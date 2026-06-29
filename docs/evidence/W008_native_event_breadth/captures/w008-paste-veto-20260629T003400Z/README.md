# W008 Paste-Veto (BeforeDropOrPaste Cancel) Oracle Capture

Capture id: w008-paste-veto-20260629T003400Z
Bead: `oxforms-esq.17`
Status: `captured`

Black-box Excel/MSForms evidence for whether a vetoing `BeforeDropOrPaste` (Cancel=True)
suppresses a keyboard Ctrl+V paste. Not an OxForms output comparison and not an exhaustive
parity claim.

## Facts

- `paste_veto`: with the veto armed, `KeyDown(17=Ctrl) -> KeyDown(86=V) ->
  BeforeDropOrPaste(Cancel False->True) -> KeyUp(86) -> KeyUp(17)` -- NO `Change` fires and
  `TextBox1.Value` stays empty. A vetoing BeforeDropOrPaste SUPPRESSES the paste.
- `paste_baseline`: without the veto, `KeyDown(17) -> KeyDown(86) ->
  BeforeDropOrPaste(Cancel False->False) -> Change(value=OxFormsPasteSeed) -> KeyUp(86) ->
  KeyUp(17)` -- `Change` fires and the clipboard text is inserted.
- **esq.17 consumes this:** honor the Cancel=True veto by suppressing the paste (no insert, no
  Change). Because OxForms `reduce_clipboard_result` inserts BEFORE BeforeDropOrPaste, the
  veto needs the insert DEFERRED until after the Cancel readback folds back (a two-stage paste,
  analogous to the esq.11 BeforeUpdate veto). The Shift=2 (Ctrl) arg fidelity landed in esq.13.

## Driving method (honest provenance)

Driven by computer-use vision on a background-COM-hosted Excel: the public Windows clipboard was
seeded with `OxFormsPasteSeed`, then a real Ctrl+V keystroke was sent (KeyCode 17/86 are
genuine VK codes, not VK_PACKET). Each scenario was a separate ClearLog -> drive -> export run, so
the per-run worksheet sequence restarts at 1 (the `scenario` column distinguishes the runs).
`generated_workbook` is null -- the throwaway workbook was not retained; the fixture sources +
`tools/office-oracle/New-W008OracleWorkbook.ps1` regenerate it deterministically.

## Clean-room Note

Repo-owned fixture sources, public Excel/VBIDE automation, public Windows input + clipboard, and
worksheet export only. No Office internals, decompilation, disassembly, or OxForms output comparison.