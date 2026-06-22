# W004 Text Label Capture

This folder contains the first successful live Excel/MSForms text-bearing Label
oracle capture for fixture:

`fixtures/office-oracle/excel-msforms/userforms/rectangle-label-text/fixture.json`

The UserForm was generated/opened through public Excel/VBIDE automation and then
captured through public Win32/.NET screenshot APIs.

## Key Files

- `oracle-capture-manifest.json` is the durable entry point.
- `window-capture.png` is the live Excel/MSForms screenshot.
- `pixel-facts.json` and `pixel-facts.md` record text pixel observations.
- `checksums.sha256` records hashes for committed artifacts.
- `open-fixture.*` and `capture-window.*` preserve rerun commands and logs.

This is Office/MSForms oracle evidence only. It is not an OxForms text parity
claim.
