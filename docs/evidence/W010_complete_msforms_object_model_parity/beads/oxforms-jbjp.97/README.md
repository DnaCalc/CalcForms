# ComboBox edit and button spacing

One hidden owned Excel, PID 23192 on private desktop CalcFormsOracle_41abe35c61bd,
is reused for before/after observations. No extra Excel launch, owner input,
foreground-window operation, desktop switch, Computer Use or security change.
The original workbook hash remains a64bfc3126a3cee6510c3622e11c74806f4a5664e1251e396408e1ed71e92120.

| Measurement | 100% before → after | 150% before → after | Tolerance |
|---|---|---|---|
| Text ink maximum edge difference | 7 → 1px | 13 → 1px | 2px, pass |
| Outer button edge difference | 4.667 → 0.333px | 7 → 0px | 1px, pass |
| Arrow ink edge difference | 2 → 1px | 3 → 1px | 1px, pass |
| Inner button fill edge difference | wrong colour class → 3px | wrong colour class → 2px | 1px, fail |
| Fill/text classes | white/dark text → same | white/dark text → same | exact, pass |
| Control height | 21 → 21pt | 21 → 21pt | 1px, pass |

The [before](before/forms-parity.md) and [after](after/forms-parity.md) reports
retain the full form/control coverage failures. Text is top-aligned to one
measured line at (9,3)pt. Long values are clipped before the button. The control
passes its single 14.5pt button width to the theme painter, sharing paint/hit
geometry; the measured outer rectangle and smaller arrow now fit native bounds.

`combo_spacing.py` recomputes native outer bounds from colour-class transitions,
runtime outer bounds from the retained primitive, arrow/fill bounds from images,
and all report values/hashes. It preserves the failed inner border measurement.
The Rust regression drives opposite sides of the button boundary without the
real mouse and verifies the clipped text viewport uses measured line height.

Remaining: native multi-shade edge thickness/colour classes, exact clipping
character offset, editable selection/caret, popup rows/scrolling and complete
ComboBox behaviour. These observations establish this paint/layout subset only.
