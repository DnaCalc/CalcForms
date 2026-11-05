# Default TextBox layout

2026-11-05, same owned Excel PID 49844 and real workbook greeter, Windows/VM3.
Native InputName reports SelectionMargin=True, MultiLine=False, left alignment,
sunken effect, no flat border, EnterFieldBehavior=0 and Tahoma 8.25. Changing only
the native selection-margin setting shifts dark text pixels by 8px at 100% and
12px at 150%: six form points. Four compact calibration images and their hashes
make that shift independently measurable. Original workbook bytes are unchanged.

CalcForms now uses 9pt on the left (3pt base plus 6pt selection area), 3pt on the
right and top, and one measured font line for text/selection painting. Caret,
hit testing and scrolling use the same viewport. Empty TextBox runs are measured
so clearing text retains the same caret line height. All behavior remains VBA.
Configurable SelectionMargin, selection-gutter behavior and full multiline
painting are still W010 work; this is the default single-line layout correction.

| Zoom | Client, both engines | Textbox interior mean RGB error before → after | Whole-client different pixels before → after |
|---|---|---|---|
| 100% | 384×174 | 4.55 → 1.19 | 4.77% → 4.69% |
| 150% | 576×261 | 4.97 → 2.97 | 3.75% → 3.68% |

Both comparisons use the same new native image for the old `.79` and corrected
CalcForms images. This holds native caret/activation pixels constant. The text
interior excludes the border; exact ROI bounds, channel errors, image hashes,
text rectangles and equal original Initialize-handler states are recorded in
`comparison.json`. The validator recomputes errors and the calibration shift.
Font hinting, label/checkbox baselines, borders and dotted focus remain visible.
No whole-form pixel parity or new ledger compatibility credit is claimed.

Raw eight-case corpus capture is under
`C:/Work/DnaCalc/codex-runs/forms-captures/round3-textbox-fixed/`; native property
and margin calibration is in `round3-text-facts/`. The broader corpus exposed
variable native MultiPage backgrounds, tracked separately by `.84`; those totals
are not used to assess this textbox correction. Both sessions launch zero new
Excel processes, close their own windows/books, and retain the one original
Excel until the run's final cleanup. No security/registry settings were changed.

Review checked default native properties, both zooms, line-height clipping,
empty-field metrics, selection overlays, caret hit tests, scroll bounds and the
canonical Scene expectation. Targeted tests keep real font line metrics,
empty/populated caret geometry, control-local hit testing and drag text ranges
explicit rather than weakening their assertions to accept arbitrary rectangles.
Verification passed: 196 Rust tests (seven existing ignored), format/clippy,
49/49 evidence checks, source regeneration, checksums, path scan and bead graph.
The source census remains 832 declarations and the ledger status totals remain
2,452 verified / 4,682 gaps / 619 unexpected-public, green=false.
