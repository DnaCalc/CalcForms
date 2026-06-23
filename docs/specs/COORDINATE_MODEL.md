# OxForms Coordinate Model

Status: W005 coordinate model and calibration surface.
Owning bead: `oxforms-xvx.18`.
Owning workset:
[`W005_input_interaction_model_exploration`](../worksets/W005_input_interaction_model_exploration.md).
Evidence note:
[`coordinate-calibration.md`](../evidence/W005_input_interaction_model_exploration/coordinate-calibration.md).

This document names the coordinate spaces that W005 input, hit-testing,
display-list rendering, event dispatch, screenshots, and comparison artifacts
must use. It is a model and calibration procedure, not runtime layout or input
implementation. Unknowns stay explicit until the W005 oracle fixture and capture
beads produce live MSForms event logs.

## 1. Anchors

- [`INPUT_INTERACTION_MODEL.md`](INPUT_INTERACTION_MODEL.md), sections 5, 8,
  10, 13, and 14.
- [`FM20_EVENT_FACTS.md`](FM20_EVENT_FACTS.md), mouse and drag/drop coordinate
  argument notes.
- W003 Excel/MSForms rectangle-label capture:
  [`oracle-capture-manifest.json`](../evidence/W003_excel_forms_oracle_capture/captures/rectangle-label-20260622T170958Z/oracle-capture-manifest.json).
- W004 text-label capture and pixel facts:
  [`oracle-capture-manifest.json`](../evidence/W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/oracle-capture-manifest.json),
  [`pixel-facts.json`](../evidence/W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/pixel-facts.json).
- Fixture inputs:
  [`rectangle-label/fixture.json`](../../fixtures/office-oracle/excel-msforms/userforms/rectangle-label/fixture.json) and
  [`rectangle-label-text/fixture.json`](../../fixtures/office-oracle/excel-msforms/userforms/rectangle-label-text/fixture.json).

## 2. Coordinate Spaces

Every coordinate-bearing event, rectangle, display command, screenshot crop, or
comparison row must name one of these spaces. New trace schemas must not expose
bare `x`, `y`, `left`, `top`, `width`, or `height` fields without a space tag.

| Space | Unit | Origin | Owner | Notes |
|---|---|---|---|---|
| `screen_pixels` | integer desktop pixels reported by the platform/capture API | desktop virtual-screen top-left | platform adapter and evidence capture tooling | Preserve raw platform values. On Windows this includes `GetWindowRect`-style window bounds and raw pointer diagnostics when available. |
| `window_rect` | `screen_pixels` rectangle | outer top-left of the PAL/top-level window | platform adapter | Includes non-client chrome. W003/W004 captures use the top-level `ThunderDFrame` rectangle. |
| `screenshot_pixels` | integer PNG pixels | top-left pixel of the committed capture image | evidence tooling | For current W003/W004 top-level captures, `screenshot_pixels = screen_pixels - window_rect.left/top`. |
| `client_pixels` | integer or fractional pixels in the window client area | client-area top-left | platform adapter/PAL boundary | Excludes non-client chrome. The exact W003/W004 top-level-to-client offset is observed indirectly, not yet a general rule. |
| `form_logical` | MSForms logical points for W005 fixtures and layout facts | top-left of the UserForm logical design/client surface | reducer/layout model | Fixture `widthPt`, `heightPt`, `leftPt`, and `topPt` values are in this space. Twip data converts exactly to points before use. |
| `control_local` | logical points unless explicitly tagged otherwise | top-left edge of the receiving control's logical bounds | router/reducer and event dispatch | Coordinates may be negative or outside bounds during capture; do not clamp before tracing or event dispatch. |
| `display_list_logical` | logical points for W005 display commands | render target/form logical origin selected by the display-list batch | layout/display-list producer | Renderer converts this space to surface pixels. Display lists must not smuggle screen coordinates for control geometry. |
| `msforms_event_args` | `Single` point values in live MSForms event arguments | expected target left/top edge per public docs, pending W005 event capture | oracle fixture and VBA event dispatch effect | `MouseDown`, `MouseMove`, `MouseUp`, drag/drop `X`/`Y` use this space. Exact pixel relation remains evidence-gated. |

### Twips And Points

W005 uses points as the canonical MSForms logical unit. A point is 1/72 inch.
A twip is 1/20 point. `.frm` or Office data that arrives in twips must be
converted as an exact rational value to points before layout, hit-testing, or
trace comparison. Do not round twips to integer pixels at parse time.

## 3. Rectangles And Bounds

Rectangles in every space use `{ x, y, width, height }` with derived
half-open bounds:

```text
left <= point_x < left + width
top  <= point_y < top  + height
```

`right` and `bottom` are exclusive whenever they are materialized. This applies
to hit-testing, dirty rectangles, display-list clip bounds, and comparison
regions.

Evidence files may report inclusive pixel ranges for readability, such as
`x_range: "40..167"`. Such a range must be converted to the canonical half-open
rectangle `x=40, width=128`, equivalent to `[40, 168)`.

Hit-testing converts an input coordinate into logical space first and then uses
half-open logical bounds. During mouse capture, routing uses the capture owner
even when the converted `control_local` point is outside that owner's half-open
bounds.

## 4. DPI And Scale

Every artifact that crosses between logical units and pixels must record:

- window or target DPI when available;
- whether one or two axes are known (`dpi_x`, `dpi_y`) or only one scalar DPI;
- the source of the DPI value, for example window capture manifest, platform
  event, headless renderer config, or replay script;
- any OS scale factor supplied by the platform separately from DPI;
- the coordinate spaces used before and after conversion.

At DPI 96, the point-to-pixel scale is:

```text
pixels_per_point = dpi / 72 = 96 / 72 = 4 / 3
```

More generally:

```text
pixels = points * dpi / 72
points = pixels * 72 / dpi
```

At non-96 DPI or after a `DpiChanged` event, traces must preserve old and new
DPI/scale metadata. A reducer or comparison must not silently reuse stale scale
values.

## 5. Rounding Policy

Logical coordinates stay fractional until a boundary requires integer pixels.
The required boundaries are screenshot/capture APIs, OS/window APIs that expose
integer pixels, raster targets, and committed pixel artifacts.

For W005:

- Store fixture and layout values in points without early rounding.
- Preserve raw platform/capture pixel values exactly.
- Convert input pixels to logical coordinates as fractional values before
  hit-testing or event argument synthesis.
- Convert logical paint/invalidation rectangles to pixel coverage using
  floor for left/top and ceil for right/bottom.
- Use pixel centers for pixel-to-logical evidence checks:
  `(pixel_index + 0.5 - origin_px) * 72 / dpi`.
- When a future API requires an integer pixel coordinate, the owner of that API
  must name the rounding it applied in diagnostics.

This policy is an OxForms W005 normalization rule. It is not yet a claim that
MSForms rounds every event argument or paint primitive the same way.

## 6. Conversion Ownership

Each boundary has one owner. Other layers may record derived values, but they
must keep the source values and owner visible.

| Boundary | Owner | Required behavior |
|---|---|---|
| OS/window input to PAL input | platform adapter | Capture raw `screen_pixels` and raw platform diagnostics; translate to `client_pixels` when possible; attach window id, window rect, DPI/scale, and unconverted diagnostics. |
| PAL input to reducer/router | PAL contract plus reducer entry | Deliver a named coordinate payload. The reducer/router owns final target selection and the conversion from client/form coordinates to hit-testable logical coordinates. |
| Form logical to control local | router/reducer | After target selection, compute `control_local` by subtracting the target control's logical bounds. Keep outside/negative values for capture and diagnostics. |
| Control local to MSForms event args | `FireVbaEvent` effect preparation | Convert W005 `control_local` points to `msforms_event_args` `Single` values for `X`/`Y`; preserve source logical and raw diagnostic coordinates in the trace. |
| Form state to display list | layout/display-list producer | Emit `display_list_logical` commands from logical state. The display list remains platform-neutral and replayable. |
| Display list to rendered pixels | renderer/PAL backend | Apply target DPI/scale and the rounding policy to produce surface pixels and optional render diagnostics. |
| Evidence screenshot to model facts | evidence tooling/comparison artifact | Use manifest `window_rect`, screenshot size/hash, DPI, fixture geometry, and pixel facts to derive calibration rows. Do not change the runtime model based on a screenshot without recording the derivation. |

## 7. Raw Diagnostic Preservation

Coordinate conversion must be lossless from an evidence perspective. A trace or
oracle log row with coordinates must keep:

- the normalized coordinate payload used by the reducer;
- raw screen/client/window values supplied by the platform or capture tool;
- window rectangle, screenshot dimensions, and DPI/scale metadata when present;
- target form/control id and target space;
- pre-conversion and post-conversion values when an event is dispatched;
- uncertainty labels for values inferred from screenshots rather than supplied
  by a live event log.

Raw diagnostics are not portable contract fields for control behavior, but they
are required for replay, comparison, and future parity investigation.

## 8. Current Calibration Facts

W003 and W004 use Excel/MSForms fixtures with:

- form `widthPt=240`, `heightPt=180`;
- label `leftPt=24`, `topPt=24`, `widthPt=96`, `heightPt=48`;
- top-level captured window bounds `left=800`, `top=420`, `right=1120`,
  `bottom=660`;
- screenshot size `320 x 240`;
- window DPI `96`.

W004 pixel facts observed:

- label border region in `screenshot_pixels`: `x=40`, `y=63`,
  `width=128`, `height=64`;
- exact fill region: `x=41`, `y=64`, `width=126`, `height=62`;
- text candidate region: `x=41`, `y=67`, `width=43`, `height=8`.

Derived sample relations for that capture:

```text
label_width_px / label_width_pt   = 128 / 96 = 4 / 3
label_height_px / label_height_pt =  64 / 48 = 4 / 3
form_origin_in_screenshot_x ~= 40 - (24 * 4 / 3) = 8 px
form_origin_in_screenshot_y ~= 63 - (24 * 4 / 3) = 31 px
```

These are sample black-box observations for the captured Windows theme,
Excel/MSForms version, DPI, and top-level window. They prove the current
fixture geometry is consistent with 96 DPI point scaling, and they give a
concrete screenshot-to-form offset for W004. They do not prove final MSForms
event coordinate rounding or all UserForm chrome/client offsets.

## 9. MSForms Mouse Event Arguments

Public event docs and the FM20 type-library facts identify mouse and drag/drop
`X`/`Y` arguments as `Single` values in points from the left/top edge of the
receiving target. W005 treats live MSForms `X`/`Y` values as
`msforms_event_args` until the oracle capture bead records actual event logs.

The expected comparison equation for a point inside a known control is:

```text
predicted_event_x_pt =
  (screenshot_pixel_x_center - control_left_screenshot_px) * 72 / dpi

predicted_event_y_pt =
  (screenshot_pixel_y_center - control_top_screenshot_px) * 72 / dpi
```

Where `control_left_screenshot_px` and `control_top_screenshot_px` come from a
calibrated border or fill region in the same screenshot. The W005 oracle must
record both the raw screenshot/input coordinate and the MSForms event argument
so later comparison can classify differences as rounding, origin, capture, or
targeting differences.

If a mouse event is routed to a captured control while the pointer is outside
that control, the event arguments remain target-local and may be negative or
greater than the control width/height. Do not clamp such values before logging.

## 10. Smallest Calibration Procedure

The smallest useful W005 calibration fixture/procedure is:

1. Generate a repo-owned Excel/MSForms UserForm fixture with one visible control
   of known point geometry and high-contrast colors. The existing W004
   rectangle-label fixture is sufficient for screenshot geometry; the W005
   interaction fixture should reuse the same size/position or record any
   changes.
2. Capture the top-level window with `tools/office-oracle/Capture-Window.ps1`
   and commit the window manifest, screenshot, checksums, and platform/Excel
   notes under `docs/evidence/W005_input_interaction_model_exploration/`.
3. Detect the control border/fill rectangle in `screenshot_pixels`, recording
   half-open coordinates and the exact color/method used.
4. Compute `pixels_per_point` from observed control width/height and fixture
   point width/height. Compare it with `dpi / 72`.
5. Compute the form logical origin in `screenshot_pixels` from the observed
   control rectangle and fixture `leftPt`/`topPt`.
6. Drive or manually perform at least three mouse inputs on the same control:
   near top-left, center, and outside the bounds while capture is active if the
   fixture supports capture. Log raw screen/screenshot coordinates and MSForms
   event `X`/`Y` arguments.
7. Classify the observed MSForms argument relation as exact, rounded, offset,
   target-dependent, or still unknown. Keep the raw rows even if the relation is
   surprising.

W005 completion status: the interaction oracle fixture and live event capture
beads produced modeless and modal calibration artifacts under
[`../evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/`](../evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/)
and
[`../evidence/W005_input_interaction_model_exploration/captures/interaction-events-modal-20260623T045300Z/`](../evidence/W005_input_interaction_model_exploration/captures/interaction-events-modal-20260623T045300Z/).
This document remains the coordinate vocabulary and calibration procedure for
downstream oracle, visible-smoke, trace/replay, and comparison work; it still
does not claim final MSForms coordinate rounding or chrome/client parity.

## 11. Downstream Requirements

- PAL input (`oxforms-xvx.4`) must expose coordinate payloads with explicit
  `screen_pixels`, `client_pixels`, `form_logical`, and raw diagnostic fields
  where applicable.
- Oracle fixtures (`oxforms-xvx.2` and `oxforms-xvx.3`) must log
  `msforms_event_args`, fixture point geometry, screenshot/window metadata, and
  raw input coordinates in separate fields.
- Trace/replay (`oxforms-xvx.5` and `oxforms-xvx.12`) must serialize coordinate
  spaces as tags and must preserve enough raw diagnostics to regenerate
  comparison rows.
- Hit-testing/focus/capture (`oxforms-xvx.7`) must use `form_logical` and
  `control_local` half-open bounds, not screen-pixel shortcuts.
- Windows visible input smoke (`oxforms-xvx.11`) must emit coordinate
  translation evidence from raw platform input through normalized/reducer
  spaces. The current capture at
  [`../evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/`](../evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/)
  records driver-side `screen_pixels`/`client_pixels` action targets and
  smoke-side normalized `client_pixels`/`form_logical` payloads. Its 1:1
  client-to-logical projection is W005 smoke infrastructure, not an MSForms
  point/DPI parity claim.
- Comparison (`oxforms-xvx.13`) must classify coordinate differences by named
  spaces, DPI/scale, rounding, origin, bounds, target, and capture state.
