# Individual tab captions

Owned Excel 16.0 build 20527, 2026-11-05, Tahoma 8.25, 100%/150% form zoom.
Native Frame and MultiPage backgrounds are both checked. At 100% the complete
parent capture passed; at 150% the complete child composite passed. The older
150% native Frame capture was invalid and is excluded. Both runtime versions
are compared against the same qualified native image at each scale.

| TabStrip region | Before different pixels | After different pixels |
|---|---|---|
| 100% | 4,770 / 31,552 (15.12%) | 1,979 (6.27%) |
| 150% | 10,972 / 70,992 (15.46%) | 3,530 (4.97%) |

TabStrip supplies each caption to the shared text-fragment batch and paints
its own run. Default headers now follow measured caption widths plus 10.5pt
padding, with a 15pt header band, raised body and connected selected header.
The complete control clips its paint. Pointer routing uses those same widths
and leaves selection unchanged when clicking unused header space. Caption
mutation and empty captions rebuild metrics; the regression checks both.

Native second-tab padding, device rounding, alternate styles, overflow and
exact focus/border pixels remain .33. The default geometry is an improvement,
not full TabStrip parity. MultiPage rendering is a separate .35 correction.
The VM3 regression verifies separate runs in one crossing, mutation, empty
captions and hit testing. Existing fixture clicks now target the intended
caption-sized second tab while preserving their event assertions.

Fresh review checked the caption batch, changed click coordinates, empty-state
replacement and complete-image selection. Validation: 198 Rust tests passed,
seven existing ignored; format/clippy, 53/53 aggregate evidence checks,
image/hash replay, whitespace and bead graph pass.
