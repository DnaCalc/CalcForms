# FORMS PARITY: observed behaviour and nested geometry

**975 pass / 635 fail, including 522 missing measurements.** Run 7 has filled
382 of the original 904 missing rows. This bead adds 190 measured rows to `.106`;
native measurements reveal failures as well as matches. Pixels remain a coarse
guard, and neither these scenarios nor the W010 member ledger establish parity.

`behaviour/` preserves native and VM3 source, literal observations and file hashes
for six authored form/zoom cases. TextBox, Boolean, list, tab and range controls
are read, changed, assigned the same value again and restored. Actual Change/
Click/range events are recorded in order. Text replacement and list/tab selection
have separate observations. Runtime original strings and native event transcripts
remain independent. Several programmatic setters omit native notifications;
these are measured failures, not missing evidence.

`input/` records actual native Tab traversal and interior message targets at both
scales. Keys and clicks are posted only to exact owned private HWNDs; no system
input, pointer movement, foreground call, SetFocus call or input-desktop switch
is used. Each complete native Tab cycle is repeated and must agree. MultiPage
has two successive control-level visits before leaving; both are preserved.
The first control must have a distinct non-container identity. Initial focus is
recorded separately: the authored VM3 driver establishes its first focus with
one normalized Tab, so these comparisons do not claim initial-Show focus parity.

MouseDown identifies an interior target. Where public range-control sources
lack MouseDown, an observed range event can identify it; no native event leaves
that target unmeasured. This does not establish edge hits, every click/event,
keyboard accelerators, scrolling or Show/Hide/Unload. Those rows remain failed.

Public IAccessible.accLocation rectangles are read through its standard COM ABI
and matched to the exact native geometry of the pinned `.106` images. They give
measured global nested rectangles without guessed parent insets. Frame-child
ink, alignment and insets can consequently be compared with VBA paint origins.
Check/radio spacing compares emitted native symbolic glyph cells with retained
outer glyphs, and the gap to each emitted caption origin; it does not claim
identical font contours.

One incorrect native TabStrip/MultiPage probe omitted MouseDown's Index argument.
The first owned hidden Excel 27884 was stopped after the resulting compile state
could not be reset. Recovery Excel 29860 was launched only after that stop and
is reused; total run launches are two. Failed stages remain under ignored target
paths and supply no parity credit. Native event signatures now validate against
the captured FM20 facts before Office execution; `.108` retains automatic recovery
and the production four-argument tab/multipage MouseDown gap as open work.

Replay `python -B tools/office-oracle/validate_behaviour_reference.py`. It checks
source generation, hashes, complete action phases, repeated traversal, observed
points, the pinned image reference and report regeneration without Excel.
Captured source and transcript files use UTF-8/LF with matching Git attributes,
so their exact file hashes survive a Windows checkout.
Fresh review preserved real repeated MultiPage visits, rejected incomplete
cycles and unknown range targets, and required native geometry to match before
using accessibility origins. The tools are non-production observers only.
