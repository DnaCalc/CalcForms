# Windows form layout comparison

Owner target, run 6 (2026-11-05): **FORMS PARITY** is the headline. Text rendering
will use another stack; identical antialiasing is not a compatibility goal.
Prioritize measured layout, spacing and behaviour failures. Pixel differences
are a coarse regression guard, never a control ranking or acceptance score.

Each form and control has pass/fail rows with native/runtime measurements,
maximum difference, units and tolerance. Layout edges, client sizes and
twips-to-pixel rounding allow 1 px at 100% and 150% form zoom. Visible text ink
allows 2 px for font rendering; baseline, alignment, clipping/wrap offsets and
exact line breaks are separate checks. Line-break offsets and ordered behaviour
must agree exactly. Record insets, row heights, tab sizes, Frame caption gap,
check/radio glyph size and caption gap, focus rectangle, border thickness and
colour classes. Record event order, actual tab traversal, Enter/default,
Esc/cancel, accelerators, hit tests, selection, scrolling, value changes and
Show/Hide/Unload state. A matching TabIndex alone does not establish traversal.

The real `fixtures/workbooks/data-entry/order-entry.xlsm` supplies original
application code with qualified MSForms declarations, dynamic nested controls,
validation and save/cancel handlers. Native initial State/Trace are paired with
VM3 execution. Ten later validation/selection/save/cancel State/Trace steps now
match native at both scales in [the data-entry evidence](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.105.1/README.md).
Native initial focus is NameInput; runtime first-focus still needs a normalized
Tab. Native save/cancel after page change use public MSAA actions, so those
observations establish commands rather than key routing. Broader input,
lifecycle and all geometry remain explicit failed coverage.
Imported source uses a referenced MSForms project, preserving original types and
handler bodies. Native fractional designer twips retain finite/range checks.

An absent measurement is **fail**, with measurement_count=0 and null values;
it is a coverage failure, not an observed product mismatch. Do not invent a
baseline from an ink box or infer exact wrap offsets from a matching line count.
Colour masks on the saved client images measure visible ink in explicit ROIs,
including separate list captions where unambiguous. They ignore light
antialias coverage and keep selected white text separate from white background.
Unmeasured native parent origins prevent nested image measurements. Historical
captures without native qualification retain a failed qualification row.

Run 7 adds [public native drawing records](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.106/README.md).
In-process OleDraw captures whole forms and individual controls as EMF, preserving
literal output, character advances and clipping. Baselines use recorded GDI
alignment and measured font metrics; runtime measurements use the same uniform
device fit, transforms and retained metrics as the rasterizer. Individual control
draws provide local nested coordinates without an inferred parent origin. Exact
line offsets require complete ordered literal fragments. Horizontal clipping
records the first character cell cut by each line's right clip; null means no
horizontal cell clipping, not missing evidence. Glyph contours and vertical
clipping remain separate. Omitted windowed ListBox output stays failed coverage.
These are public native drawing observations; the qualified window images remain
the visible-ink reference, and live colour properties remain the colour source.

The [run-7 behaviour capture](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.107/README.md)
compares explicit programmatic change/repeat/restore phases and selections, then
actual Tab cycles and interior message targets on the owned private desktop.
Repeat the native cycle; preserve multiple control-level visits within a
container. Matching TabIndex is still insufficient. Native public IAccessible
rectangles may supply global nested sites only when live native geometry agrees
with the exact pinned image capture. No event proving a range-control target
remains missing. Native event declarations must match captured FM20 metadata
before injection; the observer adapts to current runtime signatures only within
non-production probes and gives no signature-parity credit for that adaptation.

The [keyboard capture](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.109/README.md)
records command/value notifications for Enter/Escape after each interior target;
it excludes authored runtime visibility where the public property is absent.
Overflow scrolling must exceed the visible list and retain selection and
TopIndex after actual PageDown/Home. An observed unsupported property is a
measured mismatch, not missing data. `.111` fixes programmatic Change/Click
ordering and same-value suppression, and no-default Boolean Enter, against
unchanged native traces. Existing pixels stay historical; new behaviour captures
record their own runtime hash. Full parity is not inferred from these scenarios.

[Qualified tab sizes](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.110/README.md)
compare full native header construction rectangles (including selected overlap)
with runtime primary raised-edge rectangles. Public EMF clipping rectangles
alone are insufficient: require ordered literal captions, matching PATCOPY outer
strokes, shared-body geometry and top/right stroke samples on the same qualified
window images. Accessibility child sizes are not a substitute. Record source
identities, points and scope; reject unsupported transforms or clipped edges.

New colour parity rows use actual native BackColor/ForeColor and live system
colour resolution, compared with opaque retained Scene paint. Disabled text
uses the observed system grey-text colour; selected ListBox text uses the
system highlight-text colour. Transparent controls inherit an enclosing Scene
fill. Keep raw OLE_COLOR/RGB and paint provenance in the report inputs. Ink masks
remain geometry diagnostics: ClearType fringe colours must not turn black text
into a chromatic-colour compatibility failure. Historical reports retain their
original mask-based method; `.102` supplies the fresh eight-input report.

Replay `python -B tools/office-oracle/forms_parity.py --reference
docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.79/comparison.json
--out <report.json>` to create JSON and a readable `.md` report. The committed
[first report](../evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.96/forms-parity.md)
reuses the existing eight compare inputs; it describes those historical builds.
Live `layout_compare.py` snapshots and v2 summaries now use the same report.
Never use Computer Use, SendInput, a real pointer/keyboard, a foreground-window
call, or a desktop switch. Use per-window capture and in-process/UI Automation
driving. Keep one owned hidden Excel, reuse it, count launches and stop only
the owned process before ending. The default private desktop supports this.

The compatibility reference is the same owned/authored form in Excel MSForms.
Capture each engine's complete window with PrintWindow and crop the client area
using GetClientRect and ClientToScreen. Store both coordinate descriptions;
never infer the client origin from a screenshot border or compare differently
sized client areas by stretching them.
MSForms can omit its populated F3 child server from the parent's WM_PRINT.
Capture visible child HWNDs owned by that same PID separately and composite
them in sibling z order, clipped to each parent's client area. Retain the raw
parent and every child image/hash as well as the composited client reference.
This needs no activation and prevents blank ListBox content from being mistaken
for native behavior.

Live qualification also reads the shown form through its public Controls
collection. Every visible, nonempty root caption/edit/list/tab region must
contain foreground ink in its recorded text ROI. Disabled grey and selected
white text are included; dotted focus and long straight borders are excluded.
Choose only a complete parent/composite candidate satisfying all applicable
background and text probes. A failed candidate stays unverified; never patch
missing content into it. This checks text presence in each root region, not
complete glyph identity, every list row, or unmeasured nested text origins.
The `.100` replay rejects both interrupted 150% variants and passes new native
100%/150% clients without owner input or another Excel launch.

Compare 100% and a second form zoom on the same desktop DPI. The initial second
zoom is 150%. Excel's Zoom scales contents; enlarge its client area separately
using InsideWidth/InsideHeight. The CalcForms host's `--scale` changes window
size while the retained Scene remains in form points. This checks form zoom,
not a change in Windows monitor DPI. The workbook's twips and persisted
HIMETRIC control bounds remain the source geometry.

Record client and outer sizes, origins, styles, source control bounds, fonts,
tab indices, original-handler state, image hashes, fraction of different
pixels and mean absolute channel errors. Keep title bars separate from client
metrics. A lower pixel error is an improvement, not a parity claim. Keep focus,
caret, active/inactive state and input method explicit when interpreting pixels.

Build `cargo build -p calcforms-bootstrap --bin calcforms-workbook --example
layout_probe`, then run `python -B tools/office-oracle/layout_compare.py --out
<fresh-directory>`. This one command captures the real workbook greeter and
three authored forms at 100% and 150%, covering all 14 intrinsic kinds and
nested Frame children. `--forms` and `--scales` select a smaller run. The default
uses a private desktop and one owned Excel, and closes only its own processes.
The authored source is generated from `layout-corpus.v1.json`; the Windows
example uses the same VBA library, reducer and window host as the real workbook.
This exercises live controls, not binary persistence of the authored controls.

Each case records native and VBA bounds, font size, tab indices, nested paint
origins, retained text-run metrics and text rectangles alongside image errors.
The real greeter's control names map to its verified persisted site order.
Duplicate paths are rejected. Native ComboBox height coercion and fractional
coordinate rounding remain visible in the measurements. Initial Scene exports
describe the initial state only; later input snapshots must not be interpreted
as newly exported text geometry.

Historical run 3/4 comparisons ranked root-control regions by total absolute RGB
error. Their replay remains a historical regression check. It used the union
of native/runtime bounds, rounded outward, and clipped to the client. It derived
pixels per point from native client/form dimensions. Regions may overlap and
their errors must not be added. It excluded nested sites
until the native parent client origin is measured; never infer it from the
runtime or guess an inset. Unequal clients or failed native qualification
produced no ranking. These rankings no longer drive new session summaries.
`layout_pixels.py --reference <intrinsic-comparison.json> --out <ranking.json>`
replays saved references without Office or desktop use. Preserve a missing
historical qualification flag as null rather than claiming new live validation.

`--interactive --serve` accepts `pair`, `snapshot`, `macro` and `close` JSON
commands in its output directory's `commands.jsonl`. An additional capture
session can use `--interactive --attach-owned <ownership.json> --keep-excel` to
reuse the live original session. It verifies the exact process path, PID and
creation time, launches no Excel, closes its authored book and runtime, and
leaves Excel for the original session to close. Never start another Excel when
the existing owned instance can be reused. A shared-desktop operation waits
outside the lock while another worker owns it; each exclusive hold stays short.

The theme/control VBA owns paint and control layout; the PAL retains generic
primitives, text metrics, rasterization and window services. The November
greeter correction uses form-background/black labels, top-aligned label text,
smaller white checkbox glyphs with a check mark, a 13.5pt caption offset and a
caption-sized focus rectangle. Border style, font rasterization and exact
focus-dot matching remain separate measured differences.

Workbook font names now survive decoding. A homogeneous form loads its named
Tahoma or Microsoft Sans Serif face; mixed faces are rejected explicitly until
per-control font identities are supported. Legacy bitmap MS Sans Serif currently
uses a reported Microsoft Sans Serif substitution. Point sizes refer to the
font's design em, so the ab_glyph ascent/descent scale is converted consistently
for shaping and rasterization. Monitor DPI/form zoom is applied once when the
Scene is rasterized. This does not claim GDI hinting or exact baseline parity.
Disabled/button/image faces and selection blue use the observed Windows colors;
the native pressed-toggle checker pattern is still approximated by a solid fill.

Real Ctrl+A exposed a Windows text normalization error: winit's `KeyEvent.text`
ignores Control, so a correct select-all KeyDown was followed by an unwanted
`a` CharacterInput. The backend now uses `text_with_all_modifiers()` and filters
non-printing control characters. Printable AltGr text remains eligible. This
normalizes platform input; shortcut/edit semantics continue to belong to VBA.

Real greeter clicks also exposed coalesced-frame damage loss. A Windows input
callback can replace the consumed Scene several times before RedrawRequested;
each producer snapshot describes only its latest patch. The consumer must retain
all damage not yet presented, including across an empty final resubmit, then
clear it only after a successful presentation. The `.81` regression reproduces
two independent updates before one 150% frame and compares incremental pixels
with a full raster. A separate workbook test verifies that VBA removes old
caret/focus primitives. This fixes stale painting without changing focus rules.

The default single-line TextBox uses a 3pt base inset plus the observed 6pt
selection margin on the left, and 3pt top/right insets. Text, caret, selection
and scroll hit testing share that viewport. Its text rectangle is one measured
font line rather than the full field interior, which places its baseline near
the native top alignment. Measure empty TextBox runs too: clearing a field must
retain the same font line and caret height. Configurable SelectionMargin,
gutter-selection behavior and full multiline rendering remain W010 work.

The run-6 ComboBox edit line uses a 9pt left inset and a 3pt top inset, with
one measured line height. It clips before the drop button. The measured
drop-button site occupies the last 14.5pt; its painted rectangle has a 1.5pt
top and 1pt right/bottom inset. The same width drives VBA pointer routing.
The arrow is 5.25×3pt. At both scales, text ink, outer button edges and arrow
bounds now agree within their 2px/1px tolerances. The inner multi-shade edge
still has a measured 2–3px fill-boundary mismatch and is a failed spacing row.
Current native height readback is 21pt at both scales; the historical 21.75pt
readback is not treated as a general coercion rule.

The `.98` follow-up paints measured classic edges in VBA: two 0.75pt layers
for raised/sunken fields and buttons, and an outer outline for the assigned
default button. The ComboBox drop button has a 0.5pt enclosing highlight, a
white top/left layer and two bottom/right shadow layers. Native border depth
and ordered colour classes are measured on recorded clear scan lines; the
button's face bounds and arrow remain separate numeric rows. These checks
pass at both scales within 1px and exact class tolerance. Frame/other effects,
focus adorners and complete control-state styling remain separate coverage.
An unlatched ToggleButton is raised; a latched one is sunken. Its representative
solid fill now has the native control-face class; checker-pattern parity is
still unclaimed. Changing CommandButton.Default invalidates its outline.

Native `.90` captures show literal `&`, `&&` and trailing `&` in Label,
CommandButton, CheckBox, OptionButton, ToggleButton, TextBox, ListBox and
ComboBox strings. Accelerator is a separate property, not Caption markup.
The retained run keeps the literal string and its complete caret positions;
generic shaping receives a separate explicit accelerator index. Captured
text/value reads and two-scale images are retained with the before/after reports.

Label WordWrap defaults to True and survives workbook decoding. Captions with
explicit breaks or overflowing words use individually measured tokens in the
same form text batch. The observed 70pt label breaks before character offset
19 at both scales, matching native lines `Long clipped label` / `AgjpQy`.
The first line keeps its top origin when another line is clipped. These facts
establish the recorded word-boundary case, not arbitrary long-word, tab or
mixed-script wrapping. The saved ink-width mismatch remains a failed text row;
line breaks must be evaluated separately from font advance differences.

ListBox rows now provide separate text fragments through Core's project-internal
Friend methods. UserForm measures all fragments in its existing one batch;
no row-level Rust control logic or extra crossing is introduced. The measured
Tahoma 8.25 subset uses FontSize+1.5pt row spacing, a 1.5pt inner border and an
8.25pt text origin. Paint and hit testing share the spacing. Selected text is
white on the observed blue, with rows clipped inside a separate child node.
Empty rows keep their spacing. Exact font/device metrics, borders, focus,
columns and scrolling remain the full ListBox lane's work.

The default Frame uses an etched edge and separates its full-site paint clip
from a generic clipped child group. Native Tahoma 8.25 readback gives 1.5pt
side/bottom margins and an inferred 5.65pt top margin. VBA currently uses a
half-em plus 1.5pt top margin (5.625pt), retaining the 0.025pt residual in the
comparison. Children retain local Left/Top values; paint and hit testing add
the client origin. Changed clip margins invalidate interaction geometry.
The caption/border remain outside the child clip. This measured default case
does not establish alternate effects, scrolling or complete Frame parity.

Native MultiPage page backgrounds can differ between parent/child PrintWindow
captures despite unchanged authored data. Read MultiPage.BackColor (Page has no
BackColor member) and resolve system colors on the live Windows host. At the
center of an empty authored page, require the captured pixel to match that
color. Prefer the complete child-composited image when it passes; otherwise
select the complete parent capture if it passes. Retain both raw images and
the chosen source. If neither passes, report the pixel comparison as unverified.
Never paint an expected color into a reference. `.84` records a visible native
capture and replay of the white-child/grey-parent failure.
`.89` also checks Frame.BackColor at an empty inside corner of the authored
Frame: a valid page cannot qualify a blank Frame. Every applicable probe must
pass in the same complete candidate. This detects the observed blank-white
capture; it does not verify every descendant's content.

TabStrip captions use the same project-internal text fragments as list rows.
Caption-based widths are shared with pointer routing; unused header space
does not select the final tab. The measured default header band is 15pt, with
10.5pt caption padding. Exact second-tab padding, overflow, alternate styles
and focus/border details remain the full TabStrip lane's work.

OptionButton uses circular highlight/ring/dot primitives and the measured
caption offset. MultiPage's own clip covers its complete site, while its
selected Page keeps a separate client clip. For the authored 162×144pt case,
native Page.InsideWidth/InsideHeight are 159/126.75pt. Symmetric 1.5pt side/
bottom margins and a 15.75pt top origin are inferred from those dimensions
and visible header/border positions; native Page.Left/Top are absent. The
VBA child tree and input share these margins. Exact border shades remain
different, including a small 100% error increase despite restored painting.

Historical run 3/4 input-desktop protocol (superseded by run 6's no-owner-input
requirement): use the exclusive shared desktop.lock for every
operation that may activate or inject input. Fail while a live lock exists;
only a lock older than five minutes is stale. Keep each hold below two minutes
and perform no input outside the owner window (stop by 06:55 machine time).
The file lease independently expires after 110 seconds or at the input cutoff;
the returned guard rejects further desktop operations after expiry. A blocked
Excel call is not cancelled by this timer. New native probe entries must contain
their own local On Error handler; an outer Application.Run handler did not
prevent a native error dialog. Source validation rejects unprotected entries
before adding a module. Capture helpers return explicit errors rather than
silently accepting failed property reads.
Prefer private-desktop batch capture when physical input is unnecessary. Never
change Office security, registrations or another process's state. Record the
owned Excel launch count and final exact-process cleanup.
