# Microsoft MS-CFB Revision 12.0 Source Pin

This directory preserves the authoritative input used by the W010 FRX
structural inventory. Microsoft lists revision 12.0, released 2024-04-23, on
the [MS-CFB published-version page](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/53989ce4-7b05-4f8d-829b-d08d6148375b).

## Raw artifact

- File: `[MS-CFB]-240423.docx`
- Official URL:
  `https://winprotocoldocs-bhdugrdyduf5h2e4.b02.azurefd.net/MS-CFB/%5BMS-CFB%5D-240423.docx`
- Length: 220,697 bytes
- SHA-256:
  `2d650184072a148ba98ad0b68072fd5ad7780e46f3528d7f263f3127b2dadab5`

The DOCX is intentionally a raw binary pin. It can be reacquired inside an
OxForms checkout with:

```powershell
Invoke-WebRequest -UseBasicParsing `
  -Uri 'https://winprotocoldocs-bhdugrdyduf5h2e4.b02.azurefd.net/MS-CFB/%5BMS-CFB%5D-240423.docx' `
  -OutFile 'reference/ms-cfb/[MS-CFB]-240423.docx'
```

Review its length and SHA-256 before accepting any replacement. A current
Microsoft landing page is not a substitute for these revision-specific bytes.

## Normalized selection

`ms_cfb_selected_rows.v1.jsonl` contains 83 exact source rows: 80 selected from
sections 2.1 through 2.8 plus three source/revision-identity rows. The deterministic
extractor assigns one-based rows to non-empty top-level WordprocessingML
paragraphs and table rows in document order and selects only the declared row
set. It uses Python's standard library and does not depend on Word automation.

```powershell
python -B tools/forms-persistence/extract_ms_cfb_selected_rows.py
```

The check verifies both the raw DOCX pin and exact committed JSONL bytes:

- JSONL length: 40,792 bytes
- JSONL SHA-256:
  `a4292137cbd8933f6b55398dfc9c8cee366d4f65270c4dd849b6b33afe22b765`

`tools/forms-persistence/ms_cfb_selected_rules.v1.json` binds its concise,
project-derived inventory interpretations to these exact source rows. The raw
and normalized source remain authoritative when an interpretation is audited.
