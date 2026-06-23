# W006 Terminate Lifetime Excel UserForm Oracle Fixture

This is the repo-owned Excel/MSForms fixture input for `oxforms-0a0.21`.
It isolates `UserForm_Terminate` timing relative to `Hide`, `Unload`, a
modeless window close, modal return, held references, and explicit reference
release. It is oracle evidence infrastructure, not OxForms runtime code.

## Fixture Shape

Input files:

- `fixture.json` - manifest, form geometry, clean-room notes, and scenario list.
- `form-code-behind.bas` - UserForm lifecycle event handlers.
- `standard-module-extra.bas` - scenario macros, reference-state logging, and
  log worksheet helpers inserted into the generated standard module.

The generated workbook contains one Excel-hosted `UserForm`:

- form name: `OxFormsW006TerminateForm`
- caption: `OxForms W006 Terminate Oracle`
- form size: `260 x 132` points
- startup position: `2` / `CenterScreen`

The worksheet `W006TerminateLog` records one sequence across all scenarios. Each
row includes the scenario name, instance id, show mode, row kind
(`fixture_action` or `msforms_event`), event/action name, close origin,
`QueryClose` values when present, active control/window hints, form visibility,
and explicit fixture reference state columns:

- `local_ref_state`
- `held_ref_state`
- `default_instance_state`
- `release_phase`

Those columns are fixture state around public VBA variables and calls; they are
not private Office reference counts.

## Generate Or Validate

Safe dry run from the repo root, no Excel required:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\terminate-lifetime -DryRun
```

Stable live capture for this bead:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-W006TerminateLifetime.ps1 -SkipModelessCloseAttempt -SkipModalReturnAttempt
```

The capture script generates the workbook, drives the bounded macro scenarios,
exports `W006TerminateLog`, and writes the manifest/checksum evidence directory.
Without the skip flags it also attempts the public `WM_CLOSE` and modal-return
branches; those branches must produce rows or precise blockers, not inferred
Terminate timing.

## Scenarios

- `hide_held_release`: show modeless, call `Hide`, release local reference,
  then release the global held reference.
- `unload_held_release`: show modeless, call `Unload`, release local reference,
  then release the global held reference.
- `modeless_system_close_held_release`: show modeless, release the local
  reference, send public window close while the global held reference remains,
  then release the global held reference.
- `modal_hide_return_held_release`: show modal, call `Hide` from `Activate` so
  the modal `Show` returns, then release local and held references.
- `modal_unload_return_held_release`: show modal, call `Unload` from `Activate`
  so the modal `Show` returns, then release local and held references.

## Non-claims

Do not infer OxForms runtime behavior from this source file. Live worksheet
output under W006 evidence is the oracle observation. Missing rows are
unobserved rows in that run, not negative MSForms facts.
