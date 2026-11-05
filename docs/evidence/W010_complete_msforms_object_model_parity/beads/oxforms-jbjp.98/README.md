# Measured border and toggle corrections

The [before](before/forms-parity.md) / [after](after/forms-parity.md) reports
cover four forms at both scales. All 32 previously failed measured border rows
now pass: layout tolerance 1px, ordered colour classes exact. The after report
records 617 pass / 981 fail, with 904 missing measurements still failed.
Pixels remain a coarse guard and do not rank work.

| Measurement | 100% before → after maximum difference | 150% before → after |
|---|---|---|
| Greeter field border depths | 2 → 0px | 3 → 0px |
| Default-button border depths | 2 → 0px | 2 → 1px |
| ComboBox button face bounds | 3 → 0px | 2 → 0px |
| ComboBox arrow bounds | 1 → 0px | 1 → 0px |
| Measured border colour classes | fail → pass | fail → pass |
| Pressed ToggleButton fill class | white → control-face | white → control-face |

VBA owns the two 0.75pt raised/sunken shade layers, default outline, drop-button
enclosing highlight and asymmetric shadows. Unlatched toggles now use the
observed raised orientation. Default changes repaint and remove old outlines.
The pressed toggle keeps a solid control-face approximation; the native checker
pattern, other effects and focus-rectangle details are not claimed complete.

The first layered capture exposed a generic rasterizer error: tiny-skia rounds
origin and width separately. Shared device edges now round together, so thin
adjoining strips do not expose face pixels. A regression covers half-pixel
bounds and collapsed narrow fills; existing incremental/full comparisons pass.
The kernel still knows no control kinds. Canonical cross-boundary Scene tests
retain exact hashes with the measured primitive structure, and caret/selection
tests check actual colours instead of counting unrelated border fills.

`build_border_reference.py` uses the reviewed `.102` before inputs and fresh
owned captures. `validate_border_reference.py` checks all image identities,
scan coordinates, measured depths/classes, retained paint and both reports.
Native geometry is unchanged before reusing its recorded colour properties.
One owned Excel PID 20232 is reused, hidden on the private desktop. No owner
input, Computer Use, security/registration changes or sibling edits occur.
Font advances and full behaviour coverage remain open; `.95` keeps lifetime
residuals distinct from these geometry corrections.

Verification: fmt/clippy and 210 Rust tests passed, seven existing ignored;
aggregate evidence 54/54, whitespace and bead-cycle checks passed. The strict
source census remains 836 public declarations, with four internal optional
parameters. Reviewed source/manifest pins and canonical Scene expectations were
regenerated; full W010 stays red at 2,452 verified / 4,682 gaps / 620 unexpected.
