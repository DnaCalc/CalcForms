# FORMS PARITY: Frame gap and measured tab text

**1,122 pass / 496 fail; 418 missing measurements.** There are 1,618 rows:
eight explicit character-advance checks are new. Four previously missing tab
caption ink measurements are now qualified. W010 remains red.

Frame caption gaps now match native left/width exactly: 10/40 px at 100% and
15/64 px at 150%. The mask has 3pt padding on each side; the literal caption
origin and child geometry are preserved. The generic Windows text service uses
public DirectWrite GDI-classic advances. Details advances are independently
measured as 32/52px; no caption-specific font scaling is used.

TabStrip and MultiPage header sizes now match 37×21 / 47×17px at 100% and
57×33 / 71×27px at 150%. VBA uses measured line heights, caption advances,
selected overlap and shared pointer geometry. Selected headers paint last.
An empty tab set uses the scalar measured height, avoiding an unallocated array
read found by the existing FRM materialization regression.

The [final replay](final/forms-parity.md) pairs fresh owned runtime windows and
Scenes with the unchanged, qualified `.106` native windows/drawings inherited by
`.113`. It retains full capture identities, binary/source pins and ownership.
The inherited owner describes historical native captures; `runtime-ownership.json`
records this run's one hidden Excel, PID 68232. Fresh blank native candidates
supply no replacement pixels or measurement credit.

The [same qualification against the old runtime](../oxforms-jbjp.116/before/forms-parity.md)
has 1,115 pass / 503 fail. Comparing equal measurement methods gives 25 newly
passing checks and 18 smaller ink regressions: seven net rendering gains.
The regressions remain failed in `.101`; differing native 150% font heights,
full glyph rasterization, complex scripts and live DPI/resize remeasurement stay
open. No full font or pixel parity claim is made.

The public [GDI-compatible glyph metric API](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nf-dwrite-idwritefontface-getgdicompatibleglyphmetrics)
defines the device metric mode. Safe dwrote wrappers keep COM faces on the
shaping thread. Device context enters run identity, while old device-independent
ids retain their encoding. The rasterizer uses the same fitted font em.

Historical `.111` source bytes are archived from 25f9ff3 against its unchanged
capture hashes. Its replay verifies those exact bytes; current setter/key tests
still assert the independent native traces. No historical report was rewritten.
Fresh review checked clipping, caption identity, empty tabs, overlap hit testing,
run identity, unchanged native sources and all retained regressions.

Validation: 219 Rust tests pass, seven existing ignored; fmt/clippy and 55
oracle tests pass. All 62 evidence checks are green after the repaired pin and
historical-source checks were rerun. Both qualified before/after reports replay;
58 local links, whitespace and bead cycles pass. The W010 member ledger remains
2,452 verified / 4,682 gaps / 621 unexpected public rows.
