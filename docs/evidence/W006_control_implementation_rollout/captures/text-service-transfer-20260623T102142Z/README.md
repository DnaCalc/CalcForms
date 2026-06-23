# W006 Text-service Transfer Oracle Capture

Capture id: text-service-transfer-20260623T102142Z
Bead: `oxforms-0a0.17`

This directory contains black-box Excel/MSForms evidence for a focused text-only clipboard paste attempt. It is not an OxForms output comparison and it does not claim exhaustive MSForms parity.

## Observed Facts

- `w006-transfer-event-log.json` and `w006-transfer-event-log.csv` contain worksheet rows emitted by the fixture VBA event handlers.
- `input-actions.json` records the public Windows clipboard and keyboard actions used to drive the form; `manual_inputs` is empty.
- `window/` records the top-level Excel/MSForms window metadata before the paste attempt.
- Public `TextBox.Paste` fallback completed and produced `BeforeDropOrPaste` before `Change` for the repo-owned seed.

## Blocked Or Non-observed Surfaces

- Ctrl+V keyboard delivery was blocked: `SetForegroundWindow=False`, public `user32 SendInput` sent 0 of 4 requested keyboard inputs with last Win32 error 87, and `SendKeys.SendWait("^v")` failed with access denied.
- No `KeyDown`, `KeyPress`, or `KeyUp` rows were observed for the blocked Ctrl+V attempts.
- IME/composition was not driven by this capture.
- Dead-key preedit was not driven by this capture.
- True OLE drag/drop was not driven by this capture.
- Missing `BeforeDragOver` or `BeforeDropOrPaste` rows are non-claims, not negative facts about all MSForms behavior.

## Clean-room Note

The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, the public Windows clipboard, public Windows keyboard input APIs, and public top-level window capture. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.
