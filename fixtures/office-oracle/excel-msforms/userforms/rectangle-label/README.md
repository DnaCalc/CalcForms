# Rectangle Label Excel UserForm Oracle Fixture

This is the first repo-owned Excel/MSForms oracle fixture for W003. It is
source-like input, not generated evidence and not OxForms runtime code.

## Fixture Shape

Input manifest:

- `fixture.json`

The manifest describes one Excel-hosted `UserForm`:

- form name: `OxFormsRectangleOracleForm`
- form caption: `OxForms W003 Rectangle Oracle`
- form size: `240 x 180` points
- startup position: `2` / `CenterScreen`

The form contains one rectangle-like `MSForms.Label`:

- control name: `OracleRectangleLabel`
- type/prog id: `Forms.Label.1`
- caption: empty string
- position: `Left 24`, `Top 24` points
- size: `Width 96`, `Height 48` points
- fill: OLE color `&H00C07020&`, RGB `(32, 112, 192)`
- border: `1` / `fmBorderStyleSingle`

MSForms automation geometry is in points. Pixel dimensions are intentionally not
claimed here because they depend on the Windows desktop session, DPI/scaling,
theme, window chrome, and Excel/MSForms rendering. Those observations belong to
the capture artifacts from `oxforms-fg9.5`.

The label caption is empty so label font metrics do not influence the rectangle
target. The form caption is still controlled because the capture primitive can
find the top-level UserForm window by title.

## Generate Or Open In Excel

Preferred command from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\rectangle-label -Open -HoldSeconds 300
```

The command generates an `.xlsm` workbook under
`docs/evidence/W003_excel_forms_oracle_capture/captures/generated-workbooks/`
and uses public Excel/VBIDE automation to create the UserForm and show it
modelessly. It prints the generated workbook path and SHA-256 hash.

Use this safe dry run when Excel is not available or when only validating repo
inputs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\rectangle-label -DryRun
```

Prerequisites for the live Excel command:

- Windows desktop session with Microsoft Excel installed.
- Excel macro execution allowed for the generated workbook.
- Excel option "Trust access to the VBA project object model" enabled.
- Microsoft Forms 2.0 UserForm designer available through Excel/VBA.

If automation is blocked by local policy, manually create a macro-enabled
workbook, add a UserForm and standard module in the VBA editor, and copy the
properties from `fixture.json`. Record the manual steps and any generated
workbook hash under W003 evidence if the workbook is preserved.

Do not commit a generated workbook here as the only source of truth.
