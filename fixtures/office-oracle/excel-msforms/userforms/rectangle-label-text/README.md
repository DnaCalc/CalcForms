# Text-bearing Rectangle Label Excel UserForm Oracle Fixture

This is the first W004 repo-owned Excel/MSForms oracle fixture for observing
simple `Label` text pixels. It is source-like input, not generated evidence and
not OxForms runtime code.

## Fixture Shape

Input manifest:

- `fixture.json`

The manifest describes one Excel-hosted `UserForm`:

- form name: `OxFormsTextLabelOracleForm`
- form caption: `OxForms W004 Text Label Oracle`
- form size: `240 x 180` points
- startup position: `2` / `CenterScreen`

The form contains one text-bearing `MSForms.Label`:

- control name: `OracleTextLabel`
- type/prog id: `Forms.Label.1`
- caption: `OxForms`
- position: `Left 24`, `Top 24` points
- size: `Width 96`, `Height 48` points
- fill: OLE color `&H00C07020&`, RGB `(32, 112, 192)`
- foreground: OLE color `&H00FFFFFF&`, RGB `(255, 255, 255)`
- border: `1` / `fmBorderStyleSingle`
- text alignment: `1` / `fmTextAlignLeft`
- wrapping: `False`
- auto-size: `False`
- font: regular `Tahoma`, `8.25` points

MSForms automation geometry is in points. Pixel dimensions, text baseline,
anti-aliasing colors, and font substitution behavior are intentionally not
claimed here. Those observations belong to W004 capture artifacts.

White foreground text is used on the same blue fill as the W003 rectangle label
so glyph pixels can be distinguished from the fill in the first pixel analysis.

## Generate Or Open In Excel

Safe dry run from the repo root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\rectangle-label-text -DryRun
```

Live generation/opening shape:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\office-oracle\Open-ExcelUserFormFixture.ps1 -FixtureDir fixtures\office-oracle\excel-msforms\userforms\rectangle-label-text -OutputWorkbook docs\evidence\W004_text_label_oracle_pixels\captures\<capture-id>\rectangle-label-text-oracle.xlsm -Open -HoldSeconds 300
```

Prerequisites for live Excel generation match W003:

- Windows desktop session with Microsoft Excel installed.
- Excel macro execution allowed for the generated workbook.
- Excel option "Trust access to the VBA project object model" enabled.
- Microsoft Forms 2.0 UserForm designer available through Excel/VBA.

Do not commit a generated workbook here as the only source of truth.
When `-OutputWorkbook` is omitted, this fixture defaults generated workbooks to
`docs/evidence/W004_text_label_oracle_pixels/captures/generated-workbooks/`.
