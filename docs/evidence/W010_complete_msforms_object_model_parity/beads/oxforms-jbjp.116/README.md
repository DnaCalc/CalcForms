# Independent tab caption qualification

The previous whole-control ink mask counted 105-grey native header corners as
letters, producing apparent 8–9px caption errors. Native public EMF text records
provide each literal's character cells, font ascent/descent and actual clip.
Header strokes and saved native window samples independently qualify placement.

The new measurement bounds ink inside each side's own character-cell extent and
clip. Runtime cells come only from retained runs. Four missing caption components
at 150% become measured; eight explicit advance checks are added. This establishes
cell-clipped ink and advances, not glyph overhang, arbitrary scripts or AA equality.

The [old-runtime replay](before/forms-parity.md) is 1,115 pass / 503 fail, with
418 missing measurements. The `.113` report remains byte-identical. The fresh
[corrected runtime](../oxforms-jbjp.114/final/forms-parity.md) uses precisely the
same independently derived native regions, so measurement corrections are not
misreported as product fixes.

`tab_text_cells.py` replays raw EMFs, rejects changed cells/literals, validates
clips and requires actual ink in the qualified native window. Four negative and
independence tests reject border-only crops, forged native advances, wrong
runtime captions and invalid/invisible cells. Fresh review checked both scales,
selected overlap, unchanged image identities and separate native/runtime origins.
