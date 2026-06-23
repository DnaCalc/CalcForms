# W005 Interaction Event Oracle Capture

Capture id: interaction-events-20260623T001238Z
Bead: oxforms-xvx.3

Status: superseded diagnostic capture. The authoritative corrected modeless
capture is
[`../interaction-events-20260623T004914Z/`](../interaction-events-20260623T004914Z/).
This directory preserves the actual injected coordinates from the original run;
do not treat its label-intended mouse inputs as current oracle input.

This directory contains black-box Excel/MSForms event evidence for the W005 interaction fixture. It is not an OxForms output comparison and it does not claim exhaustive MSForms event parity.

## Observed Facts

- `modeless-event-log.json` and `modeless-event-log.csv` contain observed worksheet rows emitted by the fixture's VBA event handlers.
- `modeless-input-actions.json` records the automated public Windows input used to drive the form; `manual_inputs` is empty.
- `modeless-coordinate-calibration.json` records screenshot-to-fixture coordinate derivations using the W005 coordinate vocabulary. The accepted probe label border is the scoped exact border-color rectangle at x=40, y=63, width=128, height=64 in screenshot pixels; the unscoped global border-color rectangle at x=18, y=11, width=262, height=116 is retained only as a rejected diagnostic.
- The original automated label-center input was injected at screenshot pixel `x=82`, `y=43`; after the calibration repair the fixture-derived center is `x=104`, `y=95`. This mismatch is why this run is superseded.

## Assumptions

- The automated input coordinates are preserved as the actual coordinates injected during the original modeless capture. Corrected fixture-derived target points after the calibration repair are recorded separately in `modeless-input-actions.json`.
- Missing event rows are not negative facts about MSForms; they are simply unobserved in this run.
- The automation helper is evidence infrastructure only and not runtime architecture.

## Clean-room Note

The capture used repo-owned fixture sources, public Excel/VBIDE automation, public VBA event handlers, and public Windows desktop input/capture APIs. It did not use private Office internals, decompilation, disassembly, or OxForms output comparison.
