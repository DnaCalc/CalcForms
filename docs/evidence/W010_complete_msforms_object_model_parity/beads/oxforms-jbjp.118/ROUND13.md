# ListBox Height: the snapping rule (round 13)

Source: `native-round13.json` (Excel 16.0.20527, one owned Excel on a private desktop, pid recorded in the
file, `tools/office-oracle/capture_round13_native.py`, 160 ordered operation sequences at 100% and 150%) read
together with the 456-row sweep in `../oxforms-jbjp.131/native-round12.json`. `tools/office-oracle/
listbox_height_rule.py` replays all 616 rows and finds no disagreement.

The ListBox keeps two heights. The public Height `H` is what the property returns. A layout height `L` is
undefined until the first snap.

| Event | Effect |
|---|---|
| `Height = v` | `H = v`. Never snaps. `L` is untouched. |
| Font name or size changes, `BorderStyle` changes, or `IntegralHeight` goes False to True, while `IntegralHeight` is True | Snap down to whole rows. The input is `L` when defined, otherwise `H`. The result becomes `H` and `L`, and is never above the input. |
| Write of the value a property already holds | Nothing (default font Tahoma 8.25, border 0 and IntegralHeight True do not snap). |
| The same changes while `IntegralHeight` is False | Nothing. |
| First Show | `H = L` when `L` is defined; `H` unchanged when it is not. |
| `Height = v` after Show | Sticks (`reset` equals the value written in all 456 sweep rows). |

What this explains in the 456-row sweep: the sweep writes font and border, then `IntegralHeight`, then Height, then
Shows. Every configuration with a non-default font or a border snaps once (72 to 69.75, 62.95, 61.45, 57, 55.45) and
then Show puts that snapped value back whatever Height was written, so `shown` is constant. Only Tahoma 8.25 with
no border never snaps, so Show keeps the written Height. That is why the first Show "did not follow the requested
Height or the IntegralHeight flag alone": it follows whether a snap ever happened. Four sequences discriminate the
input: `S,F10,R,H30,R,B0,R,B1` snaps to 61.45 after Height 30 was written, which is only possible from `L` = 62.95.

Snap sizes read from the sequences (Tahoma 8.25, border 0, IntegralHeight False to True):

| Zoom | Written | Became | Whole rows (row, chrome) |
|---|---|---|---|
| 100 | 30 / 50 / 72 / 100 / 120 | 22.5 / 41.8 / 71.25 / 91 / 110.25 | 2 / 4 / 7 / 9 / 11 of 9.75pt plus 3pt |
| 150 | 30 / 50 / 72 / 100 / 120 | 22 / 41 / 69.5 / 97.95 / 116.95 | 2 / 4 / 7 / 10 / 12 of 9.5pt plus 3pt |

Residuals up to 0.25pt (41.8 for 42, 91 for 90.75) and one exact multiple that loses a row (120 at 100%: 12 rows
would fit exactly, 11 are returned) are not modelled; they look like pixel and twip rounding and are not fitted.

Not changed in the runtime: the VBA ListBox exposes no public `Font` or `BorderStyle` (both are ledger gaps), so only
the `IntegralHeight` trigger could be driven, and the runtime row height does not yet change between 100% (9.75pt)
and 150% (9.5pt). Implementing the table above needs those two members and a zoom-aware row first. `.118` stays open
with this rule as its specification.
