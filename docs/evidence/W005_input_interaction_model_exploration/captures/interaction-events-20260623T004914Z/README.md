# W005 Interaction Event Oracle Capture

Capture id: interaction-events-20260623T004914Z
Bead: oxforms-xvx.3

This directory contains black-box Excel/MSForms event evidence for the W005 interaction fixture. It is not an OxForms output comparison and it does not claim exhaustive MSForms event parity.

## Observed Facts

- `modeless-event-log.json` and `modeless-event-log.csv` contain observed worksheet rows emitted by the fixture's VBA event handlers.
- `modeless-input-actions.json` records the automated public Windows input used to drive the form; `manual_inputs` is empty.
- `modeless-coordinate-calibration.json` records screenshot-to-fixture coordinate derivations using the W005 coordinate vocabulary and scopes border-color detection to the probe-label fill neighborhood.
- Actual label-center input used the repaired calibration: screenshot pixel `x=104`, `y=95` and screen pixel `x=904`, `y=515`.
- `modeless-event-log.json` records target/event counts. The `OracleProbeLabel` rows are `MouseMove=201`, `MouseDown=5`, `MouseUp=5`, and `Click=4`.

## Assumptions

- Input target points are derived from fixture point geometry and the scoped probe-label calibration rectangle.
- Missing event rows are not negative facts about MSForms; they are simply unobserved in this run.
- The automation helper is evidence infrastructure only and not runtime architecture.

## Clean-room Note

The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, and public Windows desktop input/capture APIs. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.
