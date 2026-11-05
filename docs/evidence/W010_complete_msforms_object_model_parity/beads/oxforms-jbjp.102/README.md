# Property and paint colour classes

The [fresh FORMS PARITY report](forms-parity.md) covers four forms at 100%/150%
from the `.100` qualified clients. It records 577 pass / 1,011 fail, of which
936 are missing measurements. These counts describe coverage and observed
differences; they are not a full-parity claim or a pixel ranking.

Native BackColor/ForeColor and ListBox selected rows were read from public
properties in the same owned Excel PID 20232, with no launch. Before reading,
each reloaded form's native geometry must exactly match its saved facts.
System colours are resolved on that desktop: the disabled button's configured
text is black, but its effective grey-text colour is [109,109,109]. Selected
ListBox text uses the live highlight-text colour. Raw OLE_COLOR and resolved
RGB values remain in each row. Excel stays hidden on its private desktop.

CalcForms colour classes come from opaque DrawText/FillRect paint in the actual
retained Scene, including the ListBox's clipped row child and enclosing fills
for transparent controls. Individual control descendants keep their own text.
No screenshot fringe colour is a colour-parity input. The ink masks, bounding
boxes and their failures are unchanged. The regression test proves that tinted
subpixel edges no longer create a false chromatic text failure or duplicate row.

Text classes agree for every measured control in both scales. The pressed
ToggleButton fill remains failed: native control-face versus runtime white;
`.103` owns that actual theme difference. Full border and checker-pattern
behaviour remain separate work. Historical report replay is preserved.

`validate_colour_reference.py` replays image identities, Scene paint, paired
classes and the complete report. The native reader restores its worker thread's
desktop before closing its handle; it never changes the input desktop. All
intrinsic layout/report replays and seven parity failure-case tests pass.
