# ListBox row painting

Owned Excel 16.0 build 20527, 2026-11-05, Tahoma 8.25, unchanged authored
LayoutSelection at 100%/150% form zoom. One Excel launch (PID 56892), reused
by run 4. Raw captures remain under the directory in comparison.json; the six
compact client images here are sufficient to replay the measurements.

| Choices region | Before different pixels | After different pixels | RGB absolute error before / after |
|---|---|---|---|
| 100% | 5,012 / 16,704 (30.00%) | 1,578 (9.45%) | 1,803,258 / 276,220 |
| 150% | 11,205 / 37,440 (29.93%) | 3,707 (9.90%) | 4,243,576 / 1,024,051 |

Native pixels were identical before/after at each scale. The solid blue band
is 13 pixels high at 100% and 19 at 150%; fractional zoom rounding remains
visible. The bounded default uses FontSize+1.5pt row spacing, a 1.5pt inner
border and 8.25pt text origin. This measures Tahoma 8.25, not all font metrics.

ListBox supplies independent text fragments to Core. The form submits all
fragments through its existing single MeasureBatch crossing. Friend members
keep this derived render data internal to the VBA project. Rows and selected
white text paint inside a separate clipped child node. List hit testing uses
the same spacing. Empty rows retain space, and clearing repaints the same
child node without stale text. The showcase click now targets the second
row's corrected center, preserving the original Green-then-Blue event test.

The text_fragments integration test exercises the real VM3/VBA batch, row
boundaries, selected text, clipping, empty rows and clearing. The headless
validator recomputes full/region errors and hashes without Office. Border,
focus, device rounding, alternate fonts, columns and scrolling remain .23;
this grants no full ListBox member parity. The generic Scene/PAL stays blind
to control types. Fresh review checked clipping and render-state invalidation.

Validation: 197 Rust tests passed, seven existing ignored; format and clippy
passed. The aggregate evidence pass was 51/52: the census test still pinned
the source hash before the narrow-width guard. Correcting that reviewed hash
left all 59 preceding CLI/ledger tests green; all 36 surface tests passed on
rerun. Strict ledger validation, canonical regeneration, checksum and the new
row replay pass. Ledger totals remain 2,452 verified / 4,682 gaps / 619
unexpected-public, green=false. The final normal-width images are unchanged.
