# Default first-Show ListBox viewport

The genuine inventory workbook independently observes native TopIndex=16 when
selecting row 22, while the earlier prepared static-control boundary capture
requires 15. Both raw captures remain unchanged. Native default Tahoma is 8.25;
IntegralHeight=True exposes seven complete rows at Height=72. False exposes the
partial eighth row. Public Height and the effective first-Show viewport differ.

ListBox now initializes a private effective viewport once through a Friend hook
inside the library, using complete default rows and Tahoma 8.25. Public Height
is preserved. Explicit size changes refresh the viewport; same-value assignments
retain it. Core-based internal resizes are detected before paint arguments are
read, then TopIndex is clamped. Rendering, clipping and hit testing use the same
height. The new paint/hit regression caught and corrected a stale TopIndex read
during argument evaluation after an internal resize.

All sixteen inventory State/Trace results now match native at both scales,
including row22/top16; the previous 16 failed fields remain in .119/before.
All 54 prepared-control boundary observations still match, including invalid
and empty errors, repeat quietness and resize behavior. A separate test checks
complete rows, the bottom remainder, same-height assignment and internal resize.
Full IntegralHeight setters, public Height rounding and other fonts are .118;
this bounded correction does not close those claims. .123 retains cancel focus.
Fresh review checked source ownership, Friend visibility, old outcomes, viewport
invalidation and that no native expectation or failure was erased.

Validation: 225 Rust tests pass, seven existing ignored; fmt/clippy and all
64 evidence checks pass, including the unchanged 95 ledger and 55 oracle unit
tests. Local links, whitespace and the bead graph were reviewed.
