# Greeter paint comparison

2026-11-04/05, Excel 16.0 build 20527, Windows/CalcVBA VM3. One owned Excel
PID 49844 is reused for this run. These compact client images are selected from
`C:/Work/DnaCalc/codex-runs/forms-captures/round3/`; that directory retains full
windows, differences, commands and input diagnostics. No Office security or
registration changes were made.

| Form zoom | Client size, both engines | Different pixels before | After paint correction | Mean absolute RGB error before → after |
|---|---|---|---|---|
| 100% | 384 × 174 | 26.80% | 7.87% | 28.34 → 4.54 |
| 150% | 576 × 261 | 25.93% | 7.04% | 27.68 → 4.13 |

The VBA theme now gives default labels the observed form background and black
text. Labels use their left edge and a top-aligned text line. CheckBox glyphs
are smaller, use a check mark, and place the caption at the observed offset.
Its focus rectangle encloses the caption instead of the entire control site.
The complete site still receives clicks. Production rendering remains VBA-owned.

`comparison.json` records native control bounds, Tahoma 8.25 font facts,
window/client geometry, image hashes and numeric pixel differences. Each row
has equal original Initialize-handler state. The six-state headless workbook
test still agrees with the earlier owned Excel oracle. This capture does not
claim six-state physical-input equivalence: the separate input work is ongoing.

At this capture, residuals included the wrong selected font face and em sizing, font hinting and
subpixel antialiasing, label baselines, one- versus two-line border colors,
solid versus dotted focus outlines, initial focus, and native title bars.
This is a measured paint improvement, not pixel parity or complete W010 parity.

Reproduce with `cargo build -p calcforms-bootstrap --bin calcforms-workbook`,
then `python -B tools/office-oracle/layout_compare.py --out <fresh-directory>`.
It captures 100% and 150% on a private desktop, reuses one owned Excel and closes
only its owned processes. `--interactive --serve` uses the authorized input
desktop and accepts `pair`, `snapshot`, `macro` and `close` JSON commands in
`commands.jsonl`. Window activation is protected by the shared desktop lock.
Do not start another session while an existing owned Excel can be reused.

The later [.79 corpus](../oxforms-jbjp.79/README.md) retains Tahoma/design-em
sizing from `.82` and further palette corrections. Its greeter errors are
4.77%/3.75%. [.81](../oxforms-jbjp.81/README.md) fixes stale focus pixels.
The bounded default-color/checkbox correction `.76` is complete; text insets
continue in `.83`, with other control/border/font details in W010.

Fresh review checked the client crop against both Windows coordinate APIs,
recomputed image errors, inspected both scales, and retained the original
handler regression and full checks. The broader layout/input work remains open.
