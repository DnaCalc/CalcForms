# W005 Coordinate Calibration Evidence

Status: calibration model and procedure defined; live W005 event calibration is
blocked on downstream oracle fixture/capture beads.
Owning bead: `oxforms-xvx.18`.
Spec: [`../../specs/COORDINATE_MODEL.md`](../../specs/COORDINATE_MODEL.md).

This note records the current coordinate evidence available before W005
interaction capture. It separates observed W003/W004 screenshot facts from the
procedure that later beads must run for MSForms event argument calibration.

## Current Evidence Inputs

W003 blank rectangle-label capture:

- Manifest:
  [`../W003_excel_forms_oracle_capture/captures/rectangle-label-20260622T170958Z/oracle-capture-manifest.json`](../W003_excel_forms_oracle_capture/captures/rectangle-label-20260622T170958Z/oracle-capture-manifest.json)
- Screenshot:
  [`../W003_excel_forms_oracle_capture/captures/rectangle-label-20260622T170958Z/window-capture.png`](../W003_excel_forms_oracle_capture/captures/rectangle-label-20260622T170958Z/window-capture.png)
- Fixture:
  [`../../../fixtures/office-oracle/excel-msforms/userforms/rectangle-label/fixture.json`](../../../fixtures/office-oracle/excel-msforms/userforms/rectangle-label/fixture.json)

W004 text-label capture:

- Manifest:
  [`../W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/oracle-capture-manifest.json`](../W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/oracle-capture-manifest.json)
- Pixel facts:
  [`../W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/pixel-facts.json`](../W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/pixel-facts.json)
- Screenshot:
  [`../W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/window-capture.png`](../W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/window-capture.png)
- Fixture:
  [`../../../fixtures/office-oracle/excel-msforms/userforms/rectangle-label-text/fixture.json`](../../../fixtures/office-oracle/excel-msforms/userforms/rectangle-label-text/fixture.json)

## Observed Facts

Both committed captures record:

- Excel/MSForms top-level window class: `ThunderDFrame`;
- top-level window bounds: left `800`, top `420`, right `1120`,
  bottom `660`;
- screenshot size: `320 x 240`;
- window DPI: `96`;
- fixture form geometry: `widthPt=240`, `heightPt=180`;
- fixture label geometry: `leftPt=24`, `topPt=24`, `widthPt=96`,
  `heightPt=48`.

W004 records these screenshot-pixel regions:

| Region | Half-open rectangle | Inclusive range as recorded |
|---|---|---|
| label border | `x=40`, `y=63`, `width=128`, `height=64` | `x=40..167`, `y=63..126` |
| exact fill | `x=41`, `y=64`, `width=126`, `height=62` | `x=41..166`, `y=64..125` |
| text candidate | `x=41`, `y=67`, `width=43`, `height=8` | `x=41..83`, `y=67..74` |

Derived W004 sample calibration:

```text
pixels_per_point_x = 128 / 96 = 4 / 3
pixels_per_point_y = 64 / 48 = 4 / 3
form_origin_screenshot_x ~= 40 - (24 * 4 / 3) = 8
form_origin_screenshot_y ~= 63 - (24 * 4 / 3) = 31
```

These facts are evidence for the captured fixture, DPI, Windows theme, Excel
version, and screenshot method. They are not a final rule for every MSForms
window, nor do they settle mouse event `X`/`Y` rounding.

## Required W005 Calibration Procedure

Downstream W005 oracle and visible-smoke beads must:

1. Reuse or reproduce the W004 one-label geometry, or record any changed point
   geometry in the fixture manifest.
2. Capture the top-level window manifest, screenshot, checksums, DPI, and
   platform/Excel notes.
3. Detect a high-contrast control border/fill rectangle in `screenshot_pixels`
   and convert any inclusive pixel ranges to half-open rectangles.
4. Compute `pixels_per_point` and form origin from fixture point geometry.
5. Log mouse input rows with separate fields for raw `screen_pixels`,
   `window_rect`, `screenshot_pixels`, derived `form_logical`,
   derived `control_local`, and live MSForms `msforms_event_args`.
6. Include at least top-left-near, center, and captured/out-of-bounds rows if
   the fixture supports capture.
7. Preserve raw event arguments and derived values even when the derived
   relation does not match the expected equation in the coordinate model.

## Current Blocker

Live MSForms event argument calibration cannot be completed in this bead because
the interaction oracle fixture and event capture are owned by `oxforms-xvx.2`
and `oxforms-xvx.3`. This bead leaves no runtime behavior implemented; it
defines the vocabulary and required evidence shape those beads must use.
