# FORMS PARITY: native text drawing measurements

Eight fresh, qualified client pairs use the same four forms at 100%/150%.
The report is **804 pass / 794 fail, including 712 missing measurements**.
This fills 192 of the previous 904 missing rows. Missing evidence remains a
failure; the report does not establish full forms or W010 parity.

The native observer calls public `OleDraw`/`IViewObject` inside the single owned,
hidden Excel 27884 on its private desktop. It records complete form and control
metafiles. Public EMR_EXTTEXTOUTW records supply literal fragments, origins,
clipping rectangles and character advances. GDI GetTextMetricsW measures the
selected public LOGFONTs. Raw EMF bytes, hashes, font measurements, native colour
properties, production Scene and client images are retained in `comparison.json`.
No Office implementation or proprietary binary is inspected.

Baselines use the recorded text alignment and GDI ascent/descent, compared with
the rasterizer's retained metrics, uniform device fit, transforms, clips and
alignment. Individual control draws give local coordinates, including nested
Frame text; no parent origin is guessed. Line fragments must reproduce every
non-whitespace character in order. Breaks are offsets in each original caption.
`clipping_point` records the first horizontal character cell cut by the right
clip for each drawn line; a null entry means no such clipping was observed.
It does not measure visible glyph contours or vertical glyph clipping.

OLE drawing can omit a windowed ListBox's text despite a populated, qualified
window image. Both current ListBox text-record captures are empty and their
eight baseline/break/clipping rows remain missing. Its image-based line and row
measurements remain separate. Disabled drawing includes a white embossed shadow;
foreground colour class selects the grey text layer. OLE output can use classic
shades, so the window's live colour properties still supply colour parity.

Replay `python -B tools/office-oracle/validate_drawing_reference.py` without Excel.
Negative tests reject malformed records, unknown font metrics, glyph-index text,
invalid offsets and missing/reordered literal fragments. Future layout captures
collect the same public drawings and report these measurements automatically.
The observer is durable non-production tooling; production code never loads it.

Fresh review corrected uniform runtime scaling, excluded nested child output
from a Frame's caption and preserved omitted ListBox output as failed coverage.
Remaining behaviour and spacing measurements are tracked separately before
product fixes. Pixels remain a coarse regression guard.

Public API/format references: [OleDraw](https://learn.microsoft.com/en-us/windows/win32/api/ole2/nf-ole2-oledraw),
[EmrText](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-emf/dd585d0a-5d7c-4034-963a-1141af836972),
and [GetTextMetricsW](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-gettextmetricsw).
