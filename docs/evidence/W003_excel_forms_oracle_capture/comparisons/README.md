# W003 Comparison Manifests

Comparison manifests and reports relating Excel/MSForms oracle captures to
current OxForms outputs belong here.

These artifacts are observational evidence. They are not OxForms runtime APIs,
adapters, bridges, fallback paths, or final pass/fail pixel oracles.

## Format

The first manifest format is `oxforms.office_oracle.comparison_manifest.v1`.
Each manifest should keep the comparison small and explicit:

- `schema`, `bead`, `comparison_id`, `status`, and `linked_report` identify the
  artifact.
- `purpose` states the comparison question and its limits.
- `evidence_files` lists every source artifact used by path, role, and SHA-256
  where available.
- `excel_oracle` records the captured Excel/MSForms fixture, screenshot,
  window metadata, platform notes, and observed pixel facts.
- `oxforms_counterpart` records the current OxForms output, command result,
  render diagnostics, and source hashes.
- `comparison` separates what is meaningful now from what is explicitly not a
  pixel parity claim.
- `observed_facts`, `assumptions`, and `deferred_items` keep facts, judgement,
  and future tolerances separate.

The seed comparison is:

- `rectangle-label-vs-w002-smoke.json`
- `rectangle-label-vs-w002-smoke.md`

Validate committed paths and hashes with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Test-OracleComparisonManifest.ps1 -ManifestPath docs\evidence\W003_excel_forms_oracle_capture\comparisons\rectangle-label-vs-w002-smoke.json
```
