# Circular OptionButton glyphs

The owned default Tahoma 8.25 references show a circular glyph with a round
selected dot. VBA now emits generic ellipses for the white highlight, shadow
ring and dot, and aligns captions at the same 13.5pt offset as CheckBox.
The glyph's 9.75pt outer extent follows the observed 100% pixel footprint.
The Scene/PAL remains unaware of OptionButton state or control identity.

The two control regions improve at both 100% and 150%; comparison.json keeps
the exact changed pixels and RGB errors against the same native image for
both runtime versions. Independent VM3 tests require a round selected dot,
no square selection fill, and no selected dot on an unchecked option.
Exact shading, focus dots, disabled colors and alternate styles remain .21.
Different pixels and total RGB error decrease; the blue-channel error of the
unchecked option at 150% rises slightly. This is not an all-channel parity claim.

Fresh review checked circular selected/unselected glyphs, the separate Page
clip, page-subtree switching and changed header click coordinates. Validation:
200 Rust tests passed, seven existing ignored; format/clippy and all 54
aggregate evidence checks passed, plus reference hashes, whitespace and graph.
