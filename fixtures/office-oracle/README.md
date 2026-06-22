# Office Oracle Fixtures

This directory contains repo-owned inputs for black-box Office oracle work.

Inputs here should be source-like and reproducible: VBA modules, form source
exports, generation manifests, small scripts, or other text artifacts that
explain how a real Office fixture is produced or opened.

Generated evidence does not belong here. Screenshots, window metadata, logs,
hashes, and generated binary Office artifacts for W003 belong under
`docs/evidence/W003_excel_forms_oracle_capture/`.

The fixture tree is intentionally separate from `vba/oxforms` and `vba/smoke`.
It observes Microsoft Forms behavior in Excel; it is not the OxForms runtime
library and is not a compatibility API.
