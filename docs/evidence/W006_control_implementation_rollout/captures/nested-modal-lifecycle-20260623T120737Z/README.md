# W006 Nested Modal Lifecycle Oracle Capture

Capture id: `nested-modal-lifecycle-20260623T120737Z`
Bead: `oxforms-0a0.19`
Status: `blocked`

This directory records a precise blocker for the nested modal lifecycle oracle
capture. It does not infer MSForms behavior from missing rows.

## Facts

- `oracle-capture-manifest.json` records the capture status, fixture hashes,
  command logs, clean-room notes, and trace/replay implications.
- `blocker.json` records the decisive blocker: the bounded live Office capture
  timed out after 184.1 seconds before `workbook_generated`.
- `input-actions.json` records that no manual input and no public Windows input
  actions reached a visible UserForm.
- `capture.command.txt`, `capture-progress.log`, and
  `capture-timeout-notes.txt` preserve the attempted command and timeout notes.

## Assumptions

- The timeout occurred during or before public Excel/VBIDE workbook generation
  because the progress log did not reach `workbook_generated`.
- The added fixture remains a repo-owned plan for the desired oracle scenario:
  an outer modeless UserForm enters an inner modal UserForm from outer button
  handlers, then drives inner hide, inner unload, inner system close, outer
  hide, and outer unload paths.

## Unknowns And Blockers

- No event sequence, outer/inner form identity rows, show-mode rows, active
  form/window/control rows, close-origin rows, `QueryClose` `Cancel` values,
  `CloseMode` values, hide/unload rows, or `Terminate` rows were observed.
- Missing rows are unobserved in this run, not negative MSForms facts.

## Clean-room Note

The attempt used repo-owned fixture sources, public Excel/VBIDE automation,
public Windows process metadata, and local command/progress logs. It did not
use private Office internals, decompilation, disassembly, or OxForms output
comparison.
