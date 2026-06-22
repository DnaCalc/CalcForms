# W004 Text Label Pixel Facts

Capture ID: `rectangle-label-text-20260622T191013Z`
Bead: `oxforms-kgn.4`
Status: sample observation only

This report records observed pixels from a live Excel/MSForms UserForm with one
text-bearing `Forms.Label.1`. It is black-box Office/MSForms evidence, not an
OxForms text-rendering comparison or parity claim.

## Fixture

- Fixture input:
  `fixtures/office-oracle/excel-msforms/userforms/rectangle-label-text/fixture.json`
- Fixture SHA-256:
  `76376f506c614e68fa88d18022cd0e039d36259981b0b589099d4b898b920432`
- Form caption: `OxForms W004 Text Label Oracle`
- Label caption: `OxForms`
- Label geometry: left 24 pt, top 24 pt, width 96 pt, height 48 pt
- Label colors: fill `#2070C0`, foreground `#FFFFFF`
- Requested font: regular Tahoma, 8.25 pt, applied by generated VBA before
  `Show`

## Capture

- Screenshot:
  `docs/evidence/W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/window-capture.png`
- Screenshot SHA-256:
  `26bb56776ac048d5f2e263d35e37df3110a2546e2bbd6819fbd34c7ba3e19ef0`
- Screenshot size: 320 x 240 pixels
- Window title/class/process:
  `OxForms W004 Text Label Oracle` / `ThunderDFrame` / `EXCEL`
- Window bounds: left 800, top 420, right 1120, bottom 660
- DPI: 96
- Excel file version: 16.0.20026.20182

## Observed Pixels

Exact fill color `#2070C0`:

- Region: x=41..166, y=64..125
- Size: 126 x 62
- Exact-fill pixels: 7588

Exact border color `#646464`:

- Region: x=40..167, y=63..126
- Size: 128 x 64
- Exact-border pixels: 380

Exact foreground color `#FFFFFF`:

- Region: x=43..81, y=67..74
- Size: 39 x 8
- Exact-white pixels: 22

Text candidate pixels inside the exact fill region:

- Method: pixels inside the exact `#2070C0` fill bounding box that are not exact
  `#2070C0`
- Region: x=41..83, y=67..74
- Size: 43 x 8
- Non-fill pixels: 224

Top text-candidate colors:

- `#208AE0`: 33 pixels
- `#DEE9E0`: 29 pixels
- `#4C70C0`: 27 pixels
- `#FFFFFF`: 22 pixels
- `#7470C0`: 9 pixels
- `#BCFFFF`: 9 pixels
- `#4CBAF5`: 8 pixels
- `#2070D5`: 8 pixels
- `#FFFFEA`: 8 pixels
- `#998AC0`: 7 pixels

Top full-capture colors:

- `#F0F0F0`: 53001 pixels
- `#F3F3F3`: 8460 pixels
- `#2070C0`: 7588 pixels
- `#646464`: 380 pixels

## Assumptions And Limits

- The text candidate region corresponds to the rendered Label caption because
  it is the only non-fill content inside the exact fill bounding box.
- Coordinates are screenshot coordinates in the captured top-level window, not
  calibrated UserForm client coordinates.
- The generated VBA requests Tahoma 8.25 regular before showing the form; this
  capture does not independently prove there was no font substitution.
- This one sample does not define text metrics, ClearType policy, pass/fail
  tolerances, or OxForms text rendering parity.
