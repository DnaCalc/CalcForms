# W006 OLE Drag/drop Transfer Oracle Capture

Capture id: ole-drag-drop-transfer-20260623T093507Z
Bead: `oxforms-0a0.16`

This capture observed true OLE/MSForms drag/drop rows.

## Observed Facts Or Blocker

- `w006-ole-drag-drop-event-log.json` and `.csv` contain worksheet rows emitted by fixture VBA event handlers.
- `input-actions.json` records public `MSForms.DataObject.StartDrag` fixture intent plus public `user32 SendInput` mouse input.
- `coordinate-derivation.json` records screenshot/manifest-derived source and target mouse points; live event X/Y values remain only the logged MSForms event arguments.
- `.13` paste observations are referenced only as adjacent evidence and are not mixed into this true drag/drop capture.

## Clean-room Note

The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, public MSForms DataObject methods, public Windows desktop input/capture APIs, and worksheet export. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.
