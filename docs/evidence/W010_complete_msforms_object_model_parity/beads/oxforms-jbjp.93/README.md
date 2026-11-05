# MultiPage paint and page interior

The old container clip excluded its own tabs and border. MultiPage now paints
inside the whole site; the selected Page retains a separate client clip and
its page-local child coordinates. Each caption uses its own run in the same
shared measurement batch. Caption-sized pointer routing matches that geometry.

Native Page.InsideWidth/InsideHeight read 159/126.75pt for the 162×144pt
authored control. Page Left/Top/Width/Height and MultiPage Client* are absent
(438). The symmetric 1.5pt side/bottom margins and 15.75pt top origin are
inferred from these dimensions and visible border/header positions, rather
than claimed as direct Page.Left/Top readbacks. Alternate font/style origins
remain unproved. The nested VM3 test pins the chosen geometry and switches
page subtrees without retaining the previous page's paint.

| MultiPage region | Before different pixels | After different pixels |
|---|---|---|
| 100% | 2,032 / 41,472 (4.90%) | 2,083 (5.02%) |
| 150% | 4,174 / 93,312 (4.47%) | 3,504 (3.76%) |

Captions/border are now present and page dimensions match the readback.
The 100% pixel/RGB error increases slightly: native borders use two shades
(160/105), while the generic single edge still uses 128. The 150% error drops.
This is a corrected clipping/layout subset, not two-scale pixel parity.
Exact border painting and full .35 parity remain open. Capture qualification
checks both Frame and empty page backgrounds before any comparison.

Fresh review checked circular selected/unselected glyphs, the separate Page
clip, page-subtree switching and changed header click coordinates. Validation:
200 Rust tests passed, seven existing ignored; format/clippy and all 54
aggregate evidence checks passed, plus reference hashes, whitespace and graph.
