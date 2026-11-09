# ListBox heights, whole-row snap and zoom-aware rows (round 14)

Code for the rule found in `ROUND13.md`, replayed by `crates/calcforms-calcvba-adapter/tests/listbox_height_rule.rs`
against all 160 ordered sequences of `native-round13.json` and all 456 rows of `../oxforms-jbjp.131/native-round12.json`.

## What the runtime now does

* `UserForm.Zoom` (percent, 10 to 400, default 100; error 380 outside) reaches every control through
  `IOxControlHost.Zoom`. The host application does not set it yet (its DPI input only reaches the Rust host services),
  so a form is at 100% unless its code or a test sets `Zoom`.
* `ListBox.Font` (new class `Font`: Name, Size as Currency, Bold, Italic, Underline, Strikethrough, Weight, Charset;
  default Tahoma 8.25) and `ListBox.BorderStyle`. A Font write that changes the name or size reaches the core
  (`OxControlCore.NoteFontChanged`), which keeps `FontSize` as the one value the painters read and calls the ListBox.
  Writing the value a property already holds is quiet. Only the ListBox has `Font` so far.
* Two heights: `Height` is the public height; the layout height is set by a snap. A snap happens on a Font name or
  size change, a BorderStyle change, or IntegralHeight False to True, while IntegralHeight is True. Its input is the
  layout height when there is one, otherwise the written Height; the result becomes both heights and never exceeds
  the input. A `Height` write changes the public height only. The first Show puts the layout height back as
  `Height`.
* Row height is measured in device pixels at the form's zoom: em = trunc(size * dpi / 72); row = round(em * 1.207)
  for Tahoma (and any family not measured), round(em * 1.117) for Arial. Tahoma 8.25 gives 13px/19px at 100%/150%
  (9.75pt/9.5pt), Tahoma 10 gives 16px/24px, Arial 12 gives 18px/27px. Border chrome is 2px for a single line at any
  dpi, and the sunken default is 4px at 96 dpi, scaled with the dpi.
* Snap arithmetic: a BorderStyle change measures at 96 dpi and reads the available height with the old chrome; Font and
  IntegralHeight changes measure at the form's zoom. A written height that is an exact multiple of the row loses a row
  (Height 120 at 100% gives 11 rows); a snapped one keeps it (stored heights carry up to 0.3px of rounding).
* Scroll range (`TopIndex` maximum and the ListIndex landing): with a layout height, whole rows at the dpi that
  produced it; without one and IntegralHeight True, the written Height at 96 dpi row metrics (a 150% form behaves like
  100%) where a leftover under a tenth of a row is not a row (Height 72 holds 7 rows, 73 holds 8); without one and
  IntegralHeight False, the partial row counts at the form's zoom.
* Designer versus Controls.Add. The run-8 record (`../oxforms-jbjp.112/native`, a designer ListBox, 23 rows) scrolls
  Height 72 as 8 rows (TopIndex 99 gives 15 of 23). The same sequence rebuilt on a Controls.Add ListBox
  (`../oxforms-jbjp.105/native-round14.json`, `listbox_dynamic`: 23 or 30 rows, Clear or not, Show or not) scrolls it as
  7 rows (16 of 23), like the sweep and sequence records. A ListBox the FRM materializer creates is marked
  (`ListBox.MarkFromDesigner`) and counts any leftover as a row; the run-8 test marks its control the same way. Why a
  designer control differs (its first Show moves Height from 72 to 71.25, so it carries a layout height from load) is not
  settled; the marked behaviour reproduces run 8, not a rule.

## What does not match, listed in the tests

* 150%, Tahoma 10, border single, then Font 8.25 back: native 61.00, runtime 58.00 (the native snap reads the row of the
  font being left). One configuration at five Height values.
* 150%, IntegralHeight False and a single-line border, scroll range: native shows one row more (Tahoma 10 and Arial 12,
  19 Height values each), and the exact-multiple Height 60 at Tahoma 8.25 without border (one row).
* Apart from the first item, every Height value of all 616 native rows matches within 0.26pt. Residuals up to 0.25pt in the
  native numbers (41.8 for 42, 62.95 for 63) are pixel and twip rounding and are not modelled.
* Painting still uses the 1.5pt inset and a sunken edge for every BorderStyle, and the Font name changes no glyphs; the
  runtime has one UI face. Hit-testing keeps the earlier viewport.
