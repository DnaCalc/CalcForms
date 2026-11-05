# Frame client layout

The owned native Tahoma Frame reports Width=174, Height=72, InsideWidth=171,
InsideHeight=64.85, SpecialEffect=3 (etched), BorderStyle=0 at both 100% and
150%. Its children retain local Label(12,18) and TextBox(12,39) coordinates.
CalcForms previously added 6pt horizontally and 18pt vertically, and clipped
the Frame's own border/caption to that client region. This hid the frame paint
and misplaced/clipped its nested input.

The VBA Frame now uses 1.5pt side/bottom borders and a half-em plus 1.5pt top
inset: 5.625pt for this font, versus the native readback's inferred 5.65pt.
This 0.025pt rounding residual is retained explicitly. A generic child Scene
group clips descendants; the Frame's full site clips its own etched border
and caption. Child-local object-model bounds remain unchanged. Changing clip
margins invalidates interaction geometry too. No control logic moved to Rust.

| Zoom | Whole-client different pixels before → after | Frame-region mean RGB error before → after |
|---|---|---|
| 100% | 9.17% → 7.83% | 13.85 → 13.00 |
| 150% | 9.16% → 7.19% | 13.67 → 7.54 |

Both comparisons use the identical new native image, which passes live native
page-background qualification. `comparison.json` records all channel errors,
ROI bounds, image hashes, native readback, old/new child geometry and the four
relevant Scene nodes. The validator recomputes image errors and checks the
separate child clip, caption and etched edge. Compact references show both
scales. Raw captures and native probe requests remain in
`C:/Work/DnaCalc/codex-runs/forms-captures/round3-final-input/`.

The headless Frame regression checks nested input routing, clipped hits,
child removal, parent IDs and full Frame versus client clips. Showcase counts
increase by one generic clip node. Native caption/font rasterization, exact
border pixels, alternate effects, scrolling and full Frame API parity remain
in `.55`; this change grants no new ledger compatibility credit. Other corpus
gaps include square radio glyphs, list/tab text and missing MultiPage paint.

Fresh review checked both scales against native pixels, local/paint coordinate
separation, input clipping, font-dependent invalidation, unchanged public
declaration counts and original workbook regressions. The source ledger remains
2,452 verified / 4,682 gaps / 619 unexpected-public, green=false.

Verification: 196 Rust tests passed (seven existing ignored), format/clippy,
51/51 evidence checks, source regeneration, image metrics, document links,
whitespace and bead graph. The final `.79` cleanup record confirms one owned
Excel launch, its retained-handle fallback and both final owned processes gone.
