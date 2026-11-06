# FORMS PARITY: qualified tab drawing sizes

**1,089 pass / 521 fail, including 424 missing measurements.** Run 7 fills 480
of the original 904 unknown rows. These four newly measured tab-size rows all
fail; measurements do not imply a product match. W010 remains red.

The already pinned `.106` public OLE drawings emit a separate exclusion rectangle
after each literal First/Second caption. Each rectangle has matching PATCOPY
left/right/top border strokes; the final exclusion describes the shared body.
The selected header overlaps its neighbour and body. We measure these complete
header construction rectangles, including that overlap, rather than treating an
accessibility child rectangle as the painted header. Native widths/heights are
37×21 and 47×17 px at 100%, and 57×33 and 71×27 px at 150%, for both TabStrip
and MultiPage. The previously observed 150% MSAA child sizes remain rejected.

The parser requires exact caption/drawing/exclusion order, positive rectangles,
the outer strokes, the shared body and an unmapped device coordinate system.
Saved qualified native window images must contain the top/right strokes at
recorded sample points. Thus raw drawing geometry is checked against actual
window paint. The runtime uses the paired primary raised-edge rectangles,
matching face and literal text, with the rasterizer's uniform device fit.
Hidden/transformed ancestry and clipped runtime edges reject qualification.
This measures header rectangle sizes, not every rounded corner, border colour,
text contour, hit-test edge or selection state.

The images and retained Scene are the historical `.106` captures inherited by
`.111`; neither the behaviour fixes nor this measurement change rendering code.
No new pixels, Excel launch, owner input/focus or product correction are claimed.
The comparison pins both references and all raw EMF identities. Replay with
`python -B tools/office-oracle/validate_tab_reference.py`. Negative tests corrupt
captions, exclusions, strokes, raster operations, window paint and transforms.

Public format sources: [MS-EMF EMR_BITBLT](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-emf/347d1c44-1847-47ec-8762-7059e9e9b185)
defines destination rectangles and raster operations; [ExcludeClipRect](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-excludecliprect)
defines subtraction from the clip region. Associating each rectangle with its
preceding header is an inference qualified by literal order, matching strokes
and saved window samples, not a private Office structure.

Fresh review checked selected overlap, multiple identical initial MultiPage clip
records, caption identity, ancestor transforms/clips and the historical Scene
scope. Validation passed: 45 oracle tests, fmt/clippy, 60/60 aggregate evidence,
whitespace and bead cycles. The last production build has 213 passing Rust tests
and seven existing ignored; this bead changes no production code.
