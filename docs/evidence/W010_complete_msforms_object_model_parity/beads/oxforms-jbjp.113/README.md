# FORMS PARITY: measured Frame caption gap

**1,089 pass / 521 fail, including 422 missing measurements.** Run 7 fills 482
of the original 904 unknown rows. Both new Frame gap rows fail. The report has
1,610 rows, including twelve nested text rows introduced with `.107`. W010 is red.
The headline covers the existing eight greeter/authored-corpus cases. The real
order-entry workbook's historical 210 geometry/input/lifecycle unknowns remain
separate; its new exact State/Trace scenarios are documented in `.105.1`.

The metric is the horizontal interruption in the Frame's top border: its left
offset from the control site and its width. The native public EMF has one
caption exclusion rectangle before the two etched top-border strokes. The
literal Details caption belongs inside that rectangle. Actual saved native
window pixels must show border immediately outside each boundary and face
padding immediately inside. Child bitmap/vector drawing is outside this metric.

At 100%, native left/width is 10/40 px and runtime is 12/36.651 px. At 150%,
native is 15/64 px and runtime is 18/54.976 px. The maximum width difference
is 9.024 px. The runtime measurement comes from its retained caption mask;
the mask must use the opaque Frame face, follow the top border, precede the
literal caption and fit its visible, untransformed node and root clips.
No gap height, full font, child layout or pixel-equality claim follows.

Emitted character-cell advances separate padding from font width. Native padding
is 4/4 px at 100% and 6/6 px at 150% (3 pt each side); runtime is 2/2 and 3/3 px
(1.5 pt). At 100%, the width difference is −0.651 px in caption advance plus
4 px in padding. At 150%, it is 3.024 px in advance plus 6 px in padding.
Thus correcting padding alone still leaves a measured text-advance difference.
The components are preserved and must add to the observed gap-width difference.

The comparison pins `.110` and the original `.106` public drawings, qualified
images and retained Scene. All images remain historical coarse guards; no
production rendering change or new Excel launch is made. Replay with
`python -B tools/office-oracle/validate_frame_gap_reference.py`.
Negative tests reject wrong captions/boundaries, blank windows, incorrect mask
paint and drawing order. Fresh review kept the extra child text at 150% separate
from the unique outer caption and required actual window boundary confirmation.

The public [ExcludeClipRect contract](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-excludecliprect)
defines removal of this rectangle from the clip region. Pairing it with the
caption and border gap is an inference checked against emitted border strokes
and the saved window, rather than a private Office structure.

Validation passed: 51 oracle tests, 61/61 aggregate evidence, fmt/clippy,
whitespace and bead cycles. The unchanged production build has 213 passing
Rust tests and seven existing ignored. Follow-up `.114` owns the measured
padding/width correction; `.101` retains the general device-advance mismatch.
