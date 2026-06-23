# W006 Text-service Transfer Oracle Capture

Capture id: text-service-transfer-20260623T084627Z
Bead: `oxforms-0a0.13`

This directory contains black-box Excel/MSForms evidence for a focused text-only clipboard paste attempt. It is not an OxForms output comparison and it does not claim exhaustive MSForms parity.

## Observed Facts

- `w006-transfer-event-log.json` and `w006-transfer-event-log.csv` contain worksheet rows emitted by the fixture VBA event handlers.
- `input-actions.json` records the public Windows clipboard and SendKeys actions used to drive the form; `manual_inputs` is empty.
- `window/` records the top-level Excel/MSForms window metadata before the paste attempt.

## Blocked Or Non-observed Surfaces

- IME/composition was not driven by this capture.
- Dead-key preedit was not driven by this capture.
- True OLE drag/drop was not driven by this capture.
- Missing `BeforeDragOver` or `BeforeDropOrPaste` rows are non-claims, not negative facts about all MSForms behavior.

## Clean-room Note

The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, the public Windows clipboard, SendKeys, and public top-level window capture. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.
