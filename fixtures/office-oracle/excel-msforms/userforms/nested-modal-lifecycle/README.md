# W006 Nested Modal Lifecycle Excel UserForm Oracle Fixture

This is the repo-owned Excel/MSForms fixture input for `oxforms-0a0.19`.
It is not OxForms runtime code and its source is not itself oracle evidence.

## Fixture Shape

Input files:

- `fixture.json` - manifest, form geometry, control geometry, source paths,
  clean-room notes, and the intended automation script.
- `outer-form-code-behind.bas` - outer UserForm lifecycle handlers and button
  handlers that enter the inner modal form.
- `inner-form-code-behind.bas` - inner UserForm lifecycle handlers and public
  hide/unload button handlers.
- `standard-module.bas` - shared worksheet logging and public show/clear
  macros.

The generated workbook contains two Excel-hosted `UserForm` instances:

- `OxFormsW006NestedOuter`, caption `OxForms W006 Nested Outer`.
- `OxFormsW006NestedInner`, caption `OxForms W006 Nested Inner`.

The nested modal path is intentionally entered from outer CommandButton Click
handlers. Those handlers call the inner form with `Show vbModal`, and the
shared logger assigns the outer `BeforeInnerShowModal` row as the
`parent_row_id` for inner rows.

## Generate Or Validate

Safe dry run from the repo root, no Excel required:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-W006NestedModalLifecycle.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\nested-modal-lifecycle -DryRun
```

Live capture shape:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Capture-W006NestedModalLifecycle.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\nested-modal-lifecycle -OutDir docs\evidence\W006_control_implementation_rollout\captures\<capture-id>
```

The capture script records automated public Windows input, exported worksheet
rows, window manifests/screenshots, command/progress logs, fixture hashes, and
clean-room notes under the chosen W006 capture directory. If Excel, VBIDE, or
public input automation cannot drive the scenario reproducibly, it writes a
precise blocker artifact instead of inferring MSForms behavior.
