# W006 Nested Modal Lifecycle Oracle Capture

Capture id: nested-modal-lifecycle-20260627T141239Z
Bead: `oxforms-0a0.19`
Status: `captured`

This directory contains black-box Excel/MSForms nested modal lifecycle evidence. It is not an OxForms output comparison and it does not claim exhaustive MSForms parity.

## Facts

- `oracle-capture-manifest.json` records the capture status, fixture hashes, command logs, clean-room notes, and trace/replay implications.
- `input-actions.json` records public Windows input actions; `manual_inputs` is empty.
- `nested-modal-event-log.json` and `.csv`, when present, contain worksheet rows emitted by repo-owned VBA handlers while live Excel/MSForms handled the forms.
- `*-window/` directories, when present, record top-level UserForm window metadata and screenshots.

## Assumptions

- Input target points are derived from fixture point geometry and screenshot anchor labels.
- Fixture action rows identify the public VBA path taken by the scenario; they are not extra MSForms events.

## Unknowns And Blockers

- Missing event rows are unobserved rows in this run, not negative facts about MSForms.
- If `blocker.json` is present, it names the exact public automation or fixture capability that prevented a full recording.

## Clean-room Note

The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, public Windows desktop input/capture APIs, and worksheet export. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.
