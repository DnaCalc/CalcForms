# Public IntegralHeight: 48 pass / 22 fail

Run 9 exposes the Boolean ListBox IntegralHeight getter/setter, default True.
Same-value writes preserve scroll origin; changed flags reset it. False permits
the partial final row, while True establishes the existing whole-row viewport.
First Show respects the selected flag. Explicit Height writes still refresh the
viewport. The required genuine inventory test checks all flag readbacks and the
native initial whole/partial TopIndex values at both scales.

The complete paired native/runtime report compares every Height, IntegralHeight
and TopIndex observation: **48 pass / 22 fail; zero missing measurements**.
Native false-to-true transitions can normalize public Height; the runtime still
retains the requested Height. Later resize/TopIndex behavior also differs. These
fields remain failures, rather than being excluded from the report. `.118` stays
open, with no new headline layout credit or full setter-parity claim.

The separate native step matrix drains messages after each property write and
retains immediate/post-drain/post-scroll states. Its fractional public heights
vary with scale and call sequence (including 71.05 and 78.95). This exploratory
matrix has no runtime parity credit; it prevents inventing one rounding formula
from an isolated 71.25 observation. Native source and raw results remain pinned.

Fresh review checked default/readback, same-value suppression, scroll reset,
first Show, raw explicit resize and every reported mismatch. Adding IntegralHeight
raised the source census to 841 declarations. The full-library ledger remains
red: 2,452 verified, 4,682 gaps and 622 unexpected-public rows. A declaration alone does not
prove all required ABI, behavioral and persistence dimensions.
