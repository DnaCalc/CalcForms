# W005 Coordinate Calibration Evidence

Status: calibration model and procedure defined; modeless live W005 event
calibration captured by `oxforms-xvx.3`; modal-show calibration remains tracked
by `oxforms-xvx.20`.
Owning bead: `oxforms-xvx.18`.
Spec: [`../../specs/COORDINATE_MODEL.md`](../../specs/COORDINATE_MODEL.md).

This note records the current coordinate evidence available to W005. It
separates observed W003/W004 screenshot facts, observed modeless W005
interaction facts, and the residual procedure that later beads must run where
the capture surface is still incomplete.

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

W005 modeless interaction capture:

- Manifest:
  [`captures/interaction-events-20260623T001238Z/oracle-capture-manifest.json`](captures/interaction-events-20260623T001238Z/oracle-capture-manifest.json)
- Event log:
  [`captures/interaction-events-20260623T001238Z/modeless-event-log.json`](captures/interaction-events-20260623T001238Z/modeless-event-log.json)
- Coordinate calibration:
  [`captures/interaction-events-20260623T001238Z/modeless-coordinate-calibration.json`](captures/interaction-events-20260623T001238Z/modeless-coordinate-calibration.json)
- Input actions:
  [`captures/interaction-events-20260623T001238Z/modeless-input-actions.json`](captures/interaction-events-20260623T001238Z/modeless-input-actions.json)
- Screenshot:
  [`captures/interaction-events-20260623T001238Z/modeless-window/window-capture.png`](captures/interaction-events-20260623T001238Z/modeless-window/window-capture.png)

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

The modeless W005 capture records the same top-level window class
`ThunderDFrame`, top-level window bounds `800,420,1120,660`, screenshot size
`320 x 240`, and DPI `96`. Its repaired coordinate calibration records the
`OracleProbeLabel` exact fill rectangle at `x=41`, `y=64`, `width=126`,
`height=62`, then scopes exact border-color matching to that label-fill
neighborhood. The accepted label border is `x=40`, `y=63`, `width=128`,
`height=64`, which gives `form_origin_screenshot_pixels x=8, y=31`. The old
unscoped global border-color match (`x=18`, `y=11`, `width=262`,
`height=116`) is retained only as a rejected diagnostic because it includes
unrelated window/title/sibling-control pixels.

Its event log preserves raw `msforms_event_args`; the input action artifact
preserves the actual `screen_pixels` and `screenshot_pixels` values injected
during the original modeless run. Because those historical inputs were driven
before the calibration repair, corrected fixture-derived target points are
recorded separately under `post_capture_calibration_repair` instead of
rewriting the actual injected coordinates.

The event log marks `observed_facts`, `assumptions`, and `manual_input`; the
captured modeless run recorded zero manual inputs.

These W005 rows are black-box Office/MSForms observations for one modeless run.
They are not an OxForms comparison, not an exhaustive event-parity claim, and
not a modal pump observation.

## Residual W005 Calibration Procedure

Downstream W005 oracle and visible-smoke beads must still:

1. Reuse or reproduce the captured fixture geometry, or record any changed point
   geometry in the fixture manifest.
2. Capture the top-level window manifest, screenshot, checksums, DPI, and
   platform/Excel notes for any new run.
3. Detect a high-contrast control fill rectangle in `screenshot_pixels`, then
   scope border-color matching to the expected control neighborhood before
   converting any inclusive pixel ranges to half-open rectangles. Do not use a
   whole-window border-color bounding box as a control rectangle.
4. Compute `pixels_per_point` and form origin from fixture point geometry.
5. Log mouse input rows with separate fields for raw `screen_pixels`,
   `window_rect`, `screenshot_pixels`, derived `form_logical`,
   derived `control_local`, and live MSForms `msforms_event_args`.
6. Include at least top-left-near, center, and captured/out-of-bounds rows if
   the fixture supports capture.
7. Preserve raw event arguments and derived values even when the derived
   relation does not match the expected equation in the coordinate model.

## Residual Blocker

The `oxforms-xvx.3` run completed modeless event-argument capture but did not
complete a modal-show run. Modal Excel/MSForms interaction capture is filed as
`oxforms-xvx.20` so later work can preserve modal workbook, event log,
screenshot, window metadata, command logs, checksums, and platform notes without
mixing that residual into the modeless evidence above.
