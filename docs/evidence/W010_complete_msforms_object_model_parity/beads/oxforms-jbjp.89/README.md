# Blank Frame capture rejection

The run 4 150% native Frame appeared as a blank white rectangle while the
MultiPage background was grey. A page-only qualification incorrectly allowed
that complete image. New live Frame.BackColor probes sample the authored
Frame's empty inside corner, in addition to the empty MultiPage center.
Both complete capture candidates must satisfy every applicable probe; choose
a whole passing candidate or report unverified. No expected pixels are painted
into native references. This is a capture correction, not a rendering change.

The committed 100%/150% bad parent/composite pairs fail the new probes. Later
unchanged authored instances produced passing complete captures at both scales.
The valid 100% parent and 150% composite are retained. Live OLE system-color
readbacks, coordinates, samples and all image hashes replay without Office.
The Computer Use per-window visible capture independently corroborates grey
Frame and page interiors. Its returned JPEG is used only for corroboration,
not pixel-error comparison; the exact-color samples lie away from JPEG edge
ringing. Cropping uses the captured origin and actual client screen origin.

The corner is deliberately empty in this authored corpus. This does not prove
all Frame descendants or arbitrary reference content. The existing .84 page
capture replay remains byte-for-byte reproducible; historical qualification
scope is retained when its probes contain no Frame kind.

Fresh review checked the caption batch, changed click coordinates, empty-state
replacement and complete-image selection. Validation: 198 Rust tests passed,
seven existing ignored; format/clippy, 53/53 aggregate evidence checks,
image/hash replay, whitespace and bead graph pass.
