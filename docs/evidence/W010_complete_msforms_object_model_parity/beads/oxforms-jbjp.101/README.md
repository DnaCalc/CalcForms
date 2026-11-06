# FORMS PARITY: retained Windows glyph raster and font sizing

Run 9: **1,169 pass / 449 fail; 378 missing measurements**. The same method
on `.122` gives 1,166/452. There are 17 gains and 14 retained regressions;
the report does not turn an unmeasured row into a pass. Pixels stay coarse.

Windows device-fitted runs now rasterize their retained glyph ids, advances
and baseline through public DirectWrite/GDI drawing. Safe `dwrote` wrappers own
the font face, memory DC and bitmap; the backend still forbids unsafe code.
The coverage surface is checked clear before drawing and clipped while blending.
Device-independent shaping/rendering remains supported. No control kind enters
the Rust renderer, and repaint never shapes the caption again.

The two native font sweeps retain 96 size/context cases and 320 raw control
metafiles. Thirty-two root edit observations establish nearest-pixel font sizing
with midpoint values down. VBA selects that generic sizing option for root
TextBoxes. The shaper retains the supplied scale rather than reconstructing an
exact 4/3 from rounded micro-units; an explicit fitted device em participates in
run identity when it differs from the ordinary size. At Tahoma 8.25/150%, the
root edit line is 19px, while nested drawing remains 21px.

The private measure request record adds one field; the canonical ledger retains
it as an additional unexpected public nested field. W010 remains red at 2,452
verified / 4,682 gaps / 622 unexpected public rows; 839 public declarations.

Native Frame font setter readback can differ from the requested size, and button
font sizes differ across contexts. All such observations stay in the sweeps.
The 14 new ink/line-band failures remain visible. Full font/property behavior,
complex scripts, glyph identity and live DPI/resize remain open in `.101`.
The earlier raster and sizing attempts are diagnostics; the final report pins
fresh windows/Scenes against unchanged qualified native windows and drawings.

Native capture reused hidden Excel PID 22924. No owner input/focus, security,
registration or sibling edits were used. `validate_run9_parity.py` replays the
report and public drawing records without starting Office. Native caption bounds
and root edit character cells also have required Rust assertions.
