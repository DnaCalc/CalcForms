# W005 Interaction Comparison Artifacts

Comparison manifests and reports relating W005 MSForms oracle evidence to
current OxForms traces belong here.

These artifacts are observations. They are not runtime APIs, final pass/fail
oracles, or full MSForms parity claims.

## Current Comparisons

- `interaction-events-modeless-vs-headless-probe.json`
- `interaction-events-modeless-vs-headless-probe.md`

Validate the current comparison manifest from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\evidence\Test-W005InteractionComparison.ps1 -ManifestPath docs\evidence\W005_input_interaction_model_exploration\comparisons\interaction-events-modeless-vs-headless-probe.json
```
