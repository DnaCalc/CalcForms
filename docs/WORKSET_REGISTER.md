# CalcForms Workset Register

2026-11-04 owner-directed restart: `oxforms-jbjp.73` restores the renamed crates
and current CalcVBA build. W010 execution now prioritizes loading a real workbook
UserForm and running its controls and code-behind on Windows/VM3 before expanding
member inventories. See [the short review](CALCVBA_REVIEW_20261104.md).
September raw facts and captures remain historical; the existing parity generator
now writes the current-source comparison under `oxforms-jbjp.73`, preserving
the `.4` ledger bytes referenced by the `.5` oracle and `.6` facade contract.

The real-workbook Windows/VM3 greeter slice `.74` and bounded two-scale
comparison command `.79` are closed. Measured layout/painting corrections
(`.76`, `.81`, `.83`, `.85`) precede wider W010 parity; see
[the comparison contract](specs/LAYOUT_COMPARISON.md) and
[greeter paint measurements](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.76/README.md).
Run 3 also supplies the [all-intrinsic two-scale corpus](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.79/README.md)
and preserves the saved font face with design-em sizing (`.82`). Its measured
gaps remain work in the existing control lanes; authored coverage is not parity.
`.81` fixes lost damage between consecutive Windows input events; VBA's focus
state was correct. See the [focus-paint evidence](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.81/README.md).
`.83` aligns the default textbox line and measured empty-field caret; see
[its two-scale evidence](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.83/README.md).
`.84` qualifies native MultiPage backgrounds against live color and visible
pixels, selecting a whole captured image or rejecting an invalid comparison.
`.85` restores Frame caption/border painting and aligns nested child origins;
its separate child clip and two-scale pixel improvements are recorded in
[the Frame evidence](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.85/README.md).
`.86` adds root-control pixel rankings and Office-independent replay; the
recorded corpus puts ListBox row painting first at both scales. Its source
cause and measurement limits remain recorded in the `.23`/`.33` lanes.
Run 4 `.87` fixes separate ListBox row runs through the same measurement batch,
selected text and clipping; its [two-scale measurements](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.87/README.md)
reduce the ranked Choices region from about 30% to 9.45%/9.90% different pixels.
Full ListBox parity remains `.23`.
`.88` paints separate caption-sized TabStrip headers, reducing its region
differences to 6.27%/4.97%; `.33` remains open. `.89` rejects blank Frame
captures even when the page background passes. See the [tab measurements](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.88/README.md)
and [capture replay](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.89/README.md).
`.92` replaces square radio glyphs with ellipses, improving both scales.
`.93` restores MultiPage headers/border outside its selected Page clip and
matches measured interior dimensions. Its 100% border error rises slightly;
150% improves. See [the measured limits](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.93/README.md).
Run 4 ended after the user stopped Computer Use. `.77` now has native original-
workbook identity/Hide/Show/Unload observations but no runtime implementation.
`.91` retains prepared input probes; physical accelerator and drag parity
remain unproved. Owned Excel/runtime were stopped; workbook bytes are unchanged.

Run 5 implements `.77`'s shared workbook default singleton, standard-module entry,
modeless Show/Hide/Unload and QueryClose-veto subset. Native eight-row lifetime
and private-desktop veto observations now pass on VM3. `.94` also fixes native
programmatic Text/Value/SelText Change notifications and same-value suppression.
`.77` remains open: `.95` tracks non-creating default lookup and exact held-object
release/Terminate behavior. No Computer Use or owner input/focus is used in run 5.

Run 6 changes the target to FORMS PARITY (`.96`): layout/text geometry, spacing,
colour classes and ordered behaviour at 100%/150% replace pixel priorities.
The [first replay report](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.96/forms-parity.md)
uses the existing eight comparisons. Missing native measurements fail coverage;
it does not claim a measured mismatch or parity for absent evidence. New live
summaries use the same report. Historical pixel rankings remain replayable only
as regression evidence. No Computer Use or owner pointer/keyboard/focus is allowed.
Fresh `.97` [ComboBox measurements](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.97/README.md)
reduce text origin errors from 7/13px to 1px at both scales, align the outer drop
button/arrow and share its width with hit testing. The inner border fill boundary
still fails by 2–3px; broader ComboBox parity and clipped-label wrapping remain open.
`.90` now preserves literal ampersands across captions/edit/list strings. Native
observations establish that Accelerator is separate; CommandButton now exposes
that property and shaping receives an explicit generic index. The [paired report](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.90/README.md)
covers two forms at both scales. Remaining caption spacing and full keyboard-cue
behaviour stay open. Current ledger: 2,452 verified / 4,682 gaps / 620 unexpected
public rows (7,754 total); it remains red.

The resumed run 6 preserves `.99` Label word wrapping and fixes `.78`'s watchdog
exit race. `.100` rejects blank native text captures. `.102` compares actual
colour properties and retained paint classes. `.98`/`.103`/`.104` correct measured
border layers and shared edge rounding: 32 measured failures now pass across
the eight comparisons. The latest report has 617 passes / 981 failures, including
904 missing measurements; font rendering remains a separate failed geometry row.
`.105` imports a genuine data-entry workbook and runs original qualified MSForms
handlers. Initial State/Trace match native Excel; later runtime validation,
option groups, selections and Enter/Esc pass regression checks. Nested control
IDs now come from one form allocator, avoiding Page/MultiPage overflow. Initial
focus, later native scenarios and two-scale geometry remain `.105.1` work, with
210 missing data-entry measurements retained as failures. `.105` and `.77` stay
open. The current source census is 839 public declarations and the W010 ledger
stays red at 2,452 verified / 4,682 gaps / 621 unexpected-public rows.

Run 7 `.106` fills 192 missing text rows with raw public OLE drawing records and
GDI font measurements at both scales. The [current eight-case report](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.106/README.md)
has 804 passes / 794 failures, including 712 missing measurements. Baselines,
literal line breaks and horizontal character-cell clipping use independent
native output and retained Scene geometry. Empty windowed ListBox drawing stays
missing. Remaining spacing and ordered behaviour observations precede product
fixes; no broad parity claim is made.

`.107` adds [paired programmatic events, actual traversal and interior targets](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.107/README.md).
The report is now 975 passes / 635 failures, including 522 missing measurements:
382 of the initial 904 missing rows are filled. Public native accessibility
rectangles establish nested image origins. Native MultiPage traversal visits
the control twice, and several runtime setters omit native events; failures stay
visible. A bad probe signature required one sequential Excel recovery; `.108`
tracks containment and exact tab/multipage event signatures. Remaining keyboard,
scrolling, lifetime and spacing measurements continue before product fixes.

`.109` adds [Enter/Escape and genuine overflow](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.109/README.md),
filling 94 further rows: 476 of the original 904 missing rows now have measurements.
Native PageDown/Home establishes actual ListBox selection and TopIndex; runtime
PageDown and unsupported TopIndex remain failures. `.111` then corrects 22 setter
notification and twelve Boolean Enter failures against those independent traces.
The [current report](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.111/README.md)
is **1,089 pass / 521 fail, including 428 missing measurements**. Font geometry,
tab-header sizes, broader events, lifetime and input still prevent parity.

`.105.1` now preserves [ten native real-workbook steps](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.105.1/README.md)
at both scales and compares complete State/Trace after each original handler.
Native initial focus is NameInput; runtime's initial focus remains open, and its
scenario still establishes focus with normalized Tab. Broader `.105.1` acceptance
and the historical 210 geometry/input/lifecycle unknowns remain open. Owned Excel
was stopped after two sequential launches; the cleanup handle-release error is
retained. No owner input/focus or sibling edits were used. W010 member-ledger
counts remain 2,452 verified / 4,682 gaps / 621 unexpected-public rows.

`.110` subsequently [qualifies native tab drawing sizes](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.110/README.md)
from the pinned public EMF header rectangles, literal captions, border strokes
and saved qualified-window samples. Rejected MSAA child sizes supply no credit.
All four newly measured rows fail. The latest FORMS PARITY report is **1,089 pass /
521 fail, including 424 missing measurements**; run 7 fills 480 of the original
904. The existing captures and Scene remain historical coarse guards. No further
Excel launch or product rendering change was needed.

`.113` [measures the horizontal Frame caption gap](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.113/README.md)
from public caption exclusion/border records and actual native window boundaries.
Its two missing rows become measured failures, up to 9.024 px at 150%. The latest
FORMS PARITY is **1,089 pass / 521 fail, including 422 missing measurements**.
Run 7 fills 482 of the original 904 unknown rows and fixes 34 independently
measured behaviour failures. Frame padding/text advance correction is `.114`;
the planned text stack remains `.101`, and genuine ListBox overflow is `.112`.
Native drawing and image measurements remain bounded to their stated scenarios.

Worksets are coarse planned pushes. Live execution truth is in `.beads/` through
`br`; this register is the roadmap and history.

Run 9 takes up CalcVBA `8840f391` in `.95`. Non-creating exact-instance reset,
private event identity validation (`.95.1`),
host release/draining and once-per-load Unload/Terminate now pass required VM3
checks against the new native held-form/control observations. Held-object reload,
old-control events/detachment and loaded-object final release remain open.
FORMS PARITY remains **1,166 pass / 452 fail; 378 missing measurements** here.

Run 9's [current replay](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.130/forms-parity.md)
is **1,203 pass / 415 fail; 346 missing measurements**. `.125/.129` fill 32 fields
using original workbook handlers, state/event traces, selection and typed
held-control lifecycle readbacks. Eighteen production behavior/input/keyboard
scenarios were re-executed against unchanged independent native observations.
The [font replay](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.101/final/forms-parity.md)
is **1,169 pass / 449 fail; 378 missing measurements**. Retained glyph drawing
and measured root edit sizing give 17 gains and 14 retained regressions. Ninety-six
native size/context cases preserve button/Frame differences; `.101` remains open.
The generic measure record adds one unexpected public nested field: the canonical
ledger stays red at 2,452 verified / 4,682 gaps / 622 unexpected-public rows.

Run 12 (2026-11-09) measured native Variant `Value` coercion for ToggleButton and CheckBox
(`.128`, [evidence](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.128/README.md)):
Null/Empty give Null, Integer and Long map only 0 and 1 (every other number, including -1,
gives Null), other numeric subtypes map zero to False, strings map by name or rounded
numeric text. ToggleButton, CheckBox and OptionButton now hold a Variant Value and replay 448 of 448 native rows.
`.131` found that an Image has no TabIndex and takes no slot natively (Frame 0, Spinner 1,
Slider 2, TabStrip 3, MultiPage 4); `Controls.Add` now matches (new `container_tab_index` test) and the
layout corpus offers `native_tab_slots=True` for new runs. The retained TabStrip 3/4 and MultiPage 4/5
`tab_index` report rows stay as recorded until a new paired layout run uses it.

Run 13 (2026-11-09) made the ledger read the repository instead of fixing `oracle` and `tests` to `missing`
([method](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.73/README.md)):
2,452 verified / 4,682 gaps / 622 unexpected-public became 2,469 / 4,665 / 622. Seventeen member and event rows
are verified because a committed test drives them (11 events, 4 members, and 2 default-member rows after
`Attribute Value.VB_UserMemId = 0` was added to nine controls and `default_member.rs` showed the bare-variable read and
Let work). Measured and recorded without runtime change: the ListBox Height snapping rule (`.118`, a two-height model,
replayed against 616 native rows), why Enter/Exit/Update events cannot be observed on a private desktop (`.124`), and
that a MultiPage is two Tab stops, header then page client, when its selected page has no tab-stop control (`.133`).
`.124` could not isolate update events: the private-desktop form never became the active
window, so Enter/Exit/BeforeUpdate/AfterUpdate did not fire; the partial log is retained.
The `.118` sweep (456 rows) shows First-Show height snapping does not follow the flag or the
requested Height alone, so no rounding rule is claimed. Canonical row statuses are unchanged.

Run 9 `.126` imports a genuine planner with spin, scroll, toggle and tabs:
208 native state/event/error fields match, including public error-380 range
rejection (`.127`). `.118` now exposes IntegralHeight but retains every measured
Height/TopIndex residual: 48 pass / 22 fail. Its broader rounding scope stays open.
The IntegralHeight step raised the source census to 841 declarations; Frame
MouseDown (`.130`) raised it to 842, and root UserForm MouseDown (`.132`) raises
it to 843 declarations (116 public events), with canonical row statuses unchanged.
`.108` records bounded helper timeout, canary cleanup and real-dialog recovery
against the same hidden Excel PID and preserves the earlier visibility diagnostic.
`.105.1` now matches 308 original order-entry BeforeUpdate/focus/reuse/reload
fields. Sibling-local TabIndex sorting corrects the root/nested order; `.95.2`
resolves the current default before host Show. Broader scope stays open.
`.130` wires the native Frame background MouseDown signature and scalar callback.
The fresh eighteen-scenario replay adds two measured gains and no regressions.
`.123` matches all 320 real inventory fields and five Escape/rollback/veto cases
at both scales. `.124` retains differing native preparation-update prefixes.

Run 8's [current input replay](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.122/forms-parity.md)
gives **1,166 pass / 452 fail, with 378 missing measurements** across 1,618 rows.
Both Frame gaps and all four header size rows match. `.116` fills four caption
unknowns and adds eight advance checks. The same qualified method on the old
runtime gives 1,115/503: 25 gains and 18 retained smaller ink regressions mean
seven net rendering gains. `.101` stays open for those regressions, differing
native font heights, full glyph rendering and live DPI/resize remeasurement.

Run 8 takes up [CalcVBA a4bf9792](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.75/README.md):
required VM3 probes establish typed Nothing defaults, portable variable arguments,
qualified scalar defaults and external Friend rejection. `.75` and `o0fp` own
this bounded integration; `.7`'s internal facade and `.95` lifetime work remain
open. FORMS PARITY starts at 1,089 pass / 521 fail, with 422 measurements missing.

Current W010 execution note: `oxforms-jbjp.5` produced the replay-valid
canonical `W010RepresentativeMemberOracleV1` live capture through its reusable,
manifest-driven MSForms member oracle, immutable `.4` ledger slice, and
Office-independent replay contract. Its five-family, eleven-result/two-event
representative slice is observed; it is not exhaustive full-library parity,
which remains in the later W010 bead graph.
`.5` closed on 2026-09-21 after its
[closure verification](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.5/verification-2026-09-21.md)
was committed as `5b70696`. Execution is at the requested stock-take; `.6`
remains open and untouched.

Status values: `OPEN`, `IN PROGRESS`, `CLOSED`, `BLOCKED`.

| ID | Title | Status | Epic bead | Depends on | Purpose | Spec sections | Closure condition | Initial lanes | Verification |
|---|---|---|---|---|---|---|---|---|---|
| `W001_repo_bootstrap` | Repository bootstrap and first spec import | `CLOSED` | `oxforms-rzk` | none | Create the standalone OxForms repo with root doctrine, bead store, workset register, and the first spec document imported from OxVba planning. | `docs/SPEC.md`, `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`, `docs/SOURCE_REFERENCES.md` | Root docs exist; `.beads/` initialized; W001 epic and bootstrap child bead exist; spec paths are adjusted for the standalone repo; Foundation MS-OFORMS and OxVba baseline pointers are explicit. | docs/doctrine seed; spec import; source-reference baseline; bead initialization | read-through; path/link scan; `git diff --check`; `br ready --json`; `br dep cycles` |
| `W002_initial_windows_rectangle` | Initial Windows PAL rectangle smoke | `CLOSED` | `oxforms-dwm` | `W001_repo_bootstrap` | Prove the first executable OxForms slice (a rectangle-render PAL smoke driven end to end from VBA, not yet a runnable form): a VBA app project loads the OxForms VBA library, the library submits a minimal display-list command through a host-injected PAL canvas, Rust PAL renders a rectangle headlessly, and a Windows visible smoke path paints the same command. | `docs/worksets/W002_initial_windows_rectangle.md`, `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`, `docs/SOURCE_REFERENCES.md`, `docs/evidence/W002_initial_windows_rectangle.md` | Closed by `oxforms-dwm.11` review: `oxforms-pal` is host-runtime independent and passes `cargo test -p oxforms-pal --no-default-features`; `oxforms-oxvba-adapter` owns the OxVba `PortableDispatch`/`Variant` adapter/marshalling layer, with W002 `OxForms.SmokeCanvas` scoped under `smoke_canvas`; OxVba loads `RectangleSmokeApp.basproj` plus referenced `OxForms.basproj`; the app creates an OxForms smoke form, the library creates `OxForms.SmokeCanvas`, calls `CreateSurface`/`FillRect`/`Flush`, and Rust renders on `Flush`; Windows visible smoke was verified on Windows; evidence and fresh-eyes review are recorded. | workset plan; workspace scaffold; display-list/headless renderer; OxVba app -> library -> adapter -> PAL core smoke; Windows visible smoke; evidence/review | read-through; path/link scan; `cargo test -p oxforms-pal --no-default-features`; `cargo test -p oxforms-oxvba-adapter --test oxvba_rectangle_smoke -- --nocapture`; `cargo fmt --check`; `cargo clippy --workspace -- -D warnings`; `cargo test --workspace`; targeted Windows rectangle smoke; `br dep cycles`; `br ready --json` |
| `W003_excel_forms_oracle_capture` | Excel Forms oracle and Windows capture plumbing | `CLOSED` | `oxforms-fg9` | `W002_initial_windows_rectangle` | Created the first reproducible black-box oracle path against real Excel/MSForms so future OxForms rendering work has a measured target before backend or render-architecture expansion. | `docs/worksets/W003_excel_forms_oracle_capture.md`, `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`, `docs/SOURCE_REFERENCES.md`, `docs/evidence/W002_initial_windows_rectangle.md`, `docs/evidence/W003_excel_forms_oracle_capture/README.md` | Closed by `oxforms-fg9.7`: repo-owned rectangle-label Excel UserForm fixture exists; live Windows/Excel capture records screenshot pixels, window metadata, platform and Excel notes, preserved command logs, workbook/screenshot/input hashes, and rerun commands under `docs/evidence/W003_excel_forms_oracle_capture/captures/rectangle-label-20260622T170958Z/`; first comparison manifest/report `rectangle-label-vs-w002-smoke` relates the oracle to W002 smoke as calibration-only and explicitly defers exact pixel matching; fresh-eyes review recorded no W003-blocking follow-up. | workset plan; harness scaffold; first Excel UserForm fixture; Windows discovery/capture primitives; oracle artifact capture; comparison manifest; evidence/review | `tools\office-oracle\Test-OfficeOracleScaffold.ps1`; fixture dry run; `tools\office-oracle\Test-OracleComparisonManifest.ps1`; `cargo fmt --check`; `cargo clippy --workspace -- -D warnings`; `cargo test --workspace`; path/read-through review; `git diff --check`; `br dep cycles`; `br ready --json` |
| `W004_text_label_oracle_pixels` | Text-bearing MSForms Label oracle pixels | `CLOSED` | `oxforms-kgn` | `W003_excel_forms_oracle_capture` | Added simple normal-size text to the Excel/MSForms Label oracle and recorded the resulting screenshot pixels, text crop, anti-aliasing/color facts, platform notes, logs, and hashes before OxForms implements text rendering. | `docs/worksets/W004_text_label_oracle_pixels.md`, `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`, `docs/evidence/W003_excel_forms_oracle_capture/README.md`, `docs/evidence/W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/oracle-capture-manifest.json`, `docs/evidence/W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/pixel-facts.json` | Closed by `oxforms-kgn.5`: repo-owned text-bearing Excel/MSForms Label fixture exists; live Windows/Excel capture artifacts exist under `docs/evidence/W004_text_label_oracle_pixels/captures/rectangle-label-text-20260622T191013Z/`; pixel facts record observed label/text crops and representative text colors while separating facts from assumptions; docs remain clear that W004 is oracle/capture work, not OxForms text parity; residual calibration/rendering planning is filed as `oxforms-54n`. | workset plan; harness generalization; text Label fixture; live capture; pixel-fact report; evidence/review | fixture dry run; targeted Excel fixture/capture command; checksum validation; path/read-through review; `git diff --check`; `br dep cycles`; `br ready --json` |
| `W005_input_interaction_model_exploration` | Input and interaction model exploration | `CLOSED` | `oxforms-xvx` | `W004_text_label_oracle_pixels` | Settled the durable OxForms input/event architecture before control breadth: normalized input, FM20 event signature/argument facts, coordinate systems/calibration, lifecycle/modal pump behavior, hit-testing, focus/tab, mouse capture, keyboard/char routing, accelerators, default/cancel buttons, validation/event ordering, reducer effects, trace/replay, MSForms event oracles, Windows input smoke, and Label/CommandButton/TextBox probes. | `docs/worksets/W005_input_interaction_model_exploration.md`, `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`, `docs/specs/INPUT_INTERACTION_MODEL.md`, `docs/specs/FM20_EVENT_FACTS.md`, `docs/specs/COORDINATE_MODEL.md`, `docs/specs/LIFECYCLE_PUMP_MODEL.md`, `docs/specs/TRACE_REPLAY_SCHEMA.md`, `docs/evidence/W005_input_interaction_model_exploration/coordinate-calibration.md`, `docs/evidence/W005_input_interaction_model_exploration/lifecycle-pump-model.md`, `docs/evidence/W005_input_interaction_model_exploration/trace-replay/synthetic-click-trace.v1.json`, `docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-replay.golden.v1.json`, `docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-display-list.golden.v1.json`, `docs/evidence/W005_input_interaction_model_exploration/event-dispatch-smoke.v1.json`, `docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/`, `docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-modal-20260623T045300Z/`, `docs/evidence/W005_input_interaction_model_exploration/captures/visible-input-smoke-20260623T035500Z/`, `docs/evidence/W005_input_interaction_model_exploration/comparisons/interaction-events-modeless-vs-headless-probe.json`, W003/W004 oracle evidence | Closed by `oxforms-xvx.14`: W005 produced the interaction spec surface, FM20 event facts, coordinate model/calibration, lifecycle/pump model, MSForms modeless and modal oracle evidence, PAL/input contract, trace schema, reducer/effects, routing, probe controls, event dispatch smoke, visible input smoke, trace/replay golden, comparison artifact, automation/inspection decision, and W006 residual beads. No full UserForm/control parity, pixel-perfect rendering parity, runtime accessibility semantics, native FM20-named OxVba dispatch, or final pass/fail parity oracle is claimed. | workset plan; interaction spec; FM20 event facts; coordinate calibration; lifecycle/pump model; MSForms event oracles; PAL input contract; trace/replay schema; reducer/effects; hit/focus/capture/tab; keyboard/accelerator/default/cancel; Label/Button/TextBox probes; OxVba event dispatch smoke; Windows smoke; automation inspection; comparison; closure; W006 residual beads | read-through/path scan; event fact citation review; coordinate/lifecycle calibration review; modeless and modal Office/MSForms evidence validation; trace schema validation; replay/golden checks; comparison validation; visible smoke checksum validation; targeted Rust/OxVba tests; `git diff --check`; `br dep cycles`; `br ready --json`; `br list --json`; `br sync --flush-only` |
| `W006_control_implementation_rollout` | Control implementation rollout from W005 interaction spine | `CLOSED` | `oxforms-0a0` | `W005_input_interaction_model_exploration` | Carry W005's normalized input, reducer/effects, event facts, coordinate model, lifecycle/pump model, trace/replay schema, and evidence posture into implementation through a gated rollout: the first ready W006 child is planning/review hardening, and implementation/design beads depend on that gate plus any support-lane dependencies discovered by it. | `docs/worksets/W006_control_implementation_rollout.md`, `docs/worksets/W005_input_interaction_model_exploration.md`, `docs/specs/INPUT_INTERACTION_MODEL.md`, `docs/specs/FM20_EVENT_FACTS.md`, `docs/specs/COORDINATE_MODEL.md`, `docs/specs/LIFECYCLE_PUMP_MODEL.md`, `docs/specs/TRACE_REPLAY_SCHEMA.md`, `docs/specs/RUNTIME_ACCESSIBILITY_MODEL.md`, W005 evidence directory, W006 evidence directory | Closed by `oxforms-0a0`: the gated rollout completed with every child bead implemented or precisely blocked with evidence. Delivered: planning/review gate; harness/comparison hardening (incl. `oxforms-k1i` bounded screenshot retry); `.frm`/`.frx` interaction slice; first single-line TextBox editing slice; CheckBox boolean-value lane with **oracle-confirmed** Click-vs-Change ordering (`oxforms-p41`, value-change-first); modeless lifecycle close slice; shared modal/DoEvents/Terminate ownership contract; and live MSForms oracle captures — nested-modal lifecycle (42 rows; nested entry/parent_row_id, Hide vs Unload(CloseMode=1) vs Alt+F4(CloseMode=0) Terminate timing), `DoEvents`-yield reentrancy (reentrant dispatch at handler-depth 2 during a DoEvents pump), Terminate object-lifetime (held-reference Hide/Unload observed; modeless-system-close and modal-return paths narrowed to the held-reference residual with the ordering covered by the nested-modal/W005 captures), and text-service/clipboard/OLE drag-drop oracles. Precise non-claims preserved (NOT live OxVba blockers): the `oxforms-0a0.2` native-FM20 dispatch fault is **RESOLVED** by `oxforms-4pn.2` (handover `HANDOVER_OxVba_w005_fm20_event_raise.md` Resolved; committed gate proves native Click/MouseDown/MouseUp/MouseMove dispatch via RaiseEvent/WithEvents with correct scalar args, no generic carrier — the runtime dispatches FireVbaEvent by native name), so the residual is W007+ OxForms implementation work (full named-event breadth: Change/keyboard/focus/QueryClose, plus ByRef `Return*` Cancel/KeyCode helper-mutation), not an OxVba dependency; IME/composition + dead-key (`oxforms-0a0.18`, engine-driven/not publicly injectable); runtime accessibility (design-gated). Rust-correctness follow-ups landed: `oxforms-mau` (PumpFrameExited derives modal depth from tracked state) and `oxforms-p41`. Process: lightweight blocked-capture-note template (`oxforms-sut`). No full UserForm/control parity, pixel-perfect rendering parity, full native FM20-named event breadth (the dispatch mechanism is proven; broad event wiring + ByRef `Return*` mutation is W007+ work), runtime accessibility semantics, or final pass/fail parity oracle is claimed. Floor green; `tools/Run-EvidenceChecks.ps1` 21/21. | rollout planning/review gate; harness/comparison hardening; native FM20-named OxVba dispatch; `.frm`/`.frx` integration; first single-line TextBox editing slice; first modeless lifecycle close slice; nested modal/reentrant pump follow-up design; first intrinsic-control lane splitter; IME/clipboard/paste/drag-drop design; runtime accessibility design | read-through/path scan; `br dep cycles`; `br ready --json`; `br list --json`; W005 replay/checks as regression floor; targeted Rust/OxVba/fixture checks for touched lanes; Office/MSForms oracle evidence where parity is claimed; trace/replay and comparison validation; fresh-eyes review before closure |
| `W007_production_runtime_vertical_slice` | Production runtime vertical slice | `CLOSED` | `oxforms-4pn` | `W005_input_interaction_model_exploration`; closed W006 spine beads `oxforms-0a0.1`, `oxforms-0a0.3`, `oxforms-0a0.4`; W005 visible smoke bead `oxforms-xvx.11` | Build the first runnable production-shaped OxForms/OxVba slice: an OxVba project loads the OxForms VBA library, creates a small form with `Label`, `TextBox`, and `CommandButton`, shows it in a real Windows window through a tiny bootstrap, accepts text/button input, runs native VBA event handlers, and updates a label from VBA code. | `docs/worksets/W007_production_runtime_vertical_slice.md`, `docs/worksets/W005_input_interaction_model_exploration.md`, `docs/worksets/W006_control_implementation_rollout.md`, `docs/specs/INPUT_INTERACTION_MODEL.md`, `docs/specs/FM20_EVENT_FACTS.md`, `docs/specs/COORDINATE_MODEL.md`, `docs/specs/LIFECYCLE_PUMP_MODEL.md`, `docs/specs/TRACE_REPLAY_SCHEMA.md`, `docs/handovers/HANDOVER_OxVba_w005_fm20_event_raise.md`, `docs/handovers/HANDOVER_OxVba_w006_modal_reentrant_pump.md` | Closed by `oxforms-4pn` (2026-06-26): the W007 production-runtime vertical slice is COMPLETE — real VBA form code runs on OxVba, self-renders across `OxForms.Surface` into a control-blind retained Scene, the desktop backend (winit+softbuffer+tiny-skia+ab_glyph) rasterizes to a live window, and live OS input drives native VBA handlers (type+click → greeting; AutoSize label hugs+re-fits). All 14 sub-beads done with adversarial review loops; gate fmt + clippy `-D warnings` + 138 tests/17 suites green; closure evidence `docs/evidence/W007_production_runtime_vertical_slice/W007-verification-closure.md`. The later rendering migration (`oxforms-rq5`) and batched MeasureText (`oxforms-98v`) also landed on top. Residual native-event breadth (`Change`/keyboard/focus/`QueryClose` + ByRef `Return*` mutation) is follow-up implementation tracked in `W008_native_event_breadth`, NOT an OxVba blocker. **GATE CLEARED (2026-06-23): the native OxVba class-event gate (`oxforms-4pn.2`) is proven on baseline `366896f` — `Click`/`MouseDown`/`MouseUp`/`MouseMove` dispatch through `WithEvents` via `crates/oxforms-oxvba-adapter/tests/oxvba_w006_native_fm20_event_gate.rs`; the prior error-424 blocker did not reproduce. W007 implementation beads (`oxforms-4pn.3`..`.9`) may now proceed. Native `Change`/keyboard/`Return*` signatures are implementation work, not a dispatch blocker.** W007 closes only when native OxVba class events work or are precisely blocking the workset; the minimal VBA object model, form materialization, runtime effect runner, Windows backend, tiny bootstrap, runnable demo, and headless/visible evidence exist for the scoped slice; docs/register/beads agree about non-claims and follow-ups. | workset plan/bead graph; native OxVba class event gate; minimal VBA object model; form materialization; runtime effect runner; Windows backend; tiny bootstrap executable; runnable demo; verification/evidence and architecture review | read-through/path scan; `cargo fmt --check`; `cargo clippy --workspace --all-targets -- -D warnings`; `cargo test --workspace`; `pwsh -File tools/Run-EvidenceChecks.ps1`; targeted OxVba event gate; headless runtime test; Windows visible demo run or exact blocker; trace/evidence validation; `git diff --check`; `br dep cycles`; `br ready --json`; `br list --json`; `br sync --flush-only` |
| `W008_native_event_breadth` | Native FM20-named event breadth and ByRef `Return*` mutation | `CLOSED` | `oxforms-esq` | `W006_control_implementation_rollout` (CLOSED — oracle orderings); `W007_production_runtime_vertical_slice` (CLOSED — proven dispatch gate `oxforms-4pn.2`) | Carried the W006 live MSForms oracle orderings into native FM20-named dispatch, mutable `Return*` readback/fold-back, validation and paste veto, clipboard, held-key gates, and lifecycle/query-close paths. | `docs/worksets/W008_native_event_breadth.md`, `docs/evidence/W008_native_event_breadth/`, `docs/evidence/W006_control_implementation_rollout/`, `docs/handovers/HANDOVER_OxVba_w005_fm20_event_raise.md`, `docs/specs/FM20_EVENT_FACTS.md`, adapter/runtime tests and source | Closed by `oxforms-esq` on 2026-06-29: all 17 children completed; native Click/Change/key/mouse/focus/update/QueryClose/lifecycle dispatch, ByRef helper mutation/fold-back, focus validation, paste veto, clipboard and oracle-ordering pins landed; no generic runtime carrier remains. Full library-wide event parity remains W010 scope. | ByRef helper gate/fold-back; native named dispatch; focus/update/keyboard/paste/clipboard behavior; oracle conformance | targeted OxVba/Rust WithEvents and ordering tests; fmt/clippy/workspace tests; evidence checks; graph checks; fresh-eyes review |
| `W009_intrinsic_control_breadth` | First-class runtime foundation, then complete MSForms intrinsic control breadth | `CLOSED` | `oxforms-zhz` | `W006_control_implementation_rollout` (CLOSED); `W007_production_runtime_vertical_slice` (CLOSED); `W008_native_event_breadth` (CLOSED) | Built the first-class runtime foundation before broad control breadth: control-stack/DNA UI consolidation gate, explicit no-legacy-preservation architecture rework graph, headless runner, interaction manager, capability descriptor, oracle pass, representative controls, hazard spikes, perf gate, showcase dashboard, and a factory/runtime lane for every intrinsic control at W009 subset depth. | `docs/worksets/W009_intrinsic_control_breadth.md`, `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`, focused specs, `docs/evidence/W009_first_class_runtime_foundation/` | Closed by `oxforms-zhz.49`: foundation and broad-control graphs completed; every intrinsic category has a representative factory/control lane at W009 subset depth; pending-control dashboard rows are empty. This is not full member parity; W010 owns the exhaustive surface. | architecture/foundation graph; representative control lanes; TextBox/accessibility follow-ups; perf/showcase | headless/adapter/showcase tests; fmt/clippy/workspace tests; evidence and graph checks; visible showcase when available |
| `W010_complete_msforms_object_model_parity` | Complete MSForms full-library object-model and behavior parity | `IN PROGRESS` | `oxforms-jbjp` | `W008_native_event_breadth` (CLOSED); `W009_intrinsic_control_breadth` (CLOSED) | Generate the complete FM20 plus referenced-typelib, MS-OFORMS, independent `.frm`/`.frx` export, and public-doc surfaces; close every accepted callable property, setter, method, default member, event, enum/alias, error/coercion, rendering, and persistence row. This includes the intrinsic global `UserForms` collection, all ten actual HTML families, versioned/supporting-object and callable hidden/designer-band rows; exclusions require authoritative non-callable/restricted evidence and blockers do not count as completion. | `docs/worksets/W010_complete_msforms_object_model_parity.md`, `docs/specs/FM20_TYPELIB_FACT_SCHEMA.md`, `docs/specs/MSFORMS_PERSISTENCE_MODEL.md`, `docs/specs/MSFORMS_OBJECT_MODEL_PARITY.md`, `docs/FORMS_LIBRARY_SPEC_AND_PLAN.md`, `docs/SOURCE_REFERENCES.md`, `docs/evidence/W010_complete_msforms_object_model_parity/`, `docs/handovers/HANDOVER_OxVba_w010_form_module_integration.md`, generated facts/ledger | W010 closes only when clean regeneration reports no missing, partial, unknown, unexpected-public, prose-only, or accepted-blocked-as-done full-library rows; all generated bind/behavior/event/render/persistence corpora and the full verification floor pass; all 72 children completed the exact fresh-eyes review and post-review commit; the production FormModule gate is delivered; docs/register/beads agree. `oxforms-jbjp.2` established the validated 220-view FM20/stdole metadata baseline and exact W005 structural reconciliation. `oxforms-jbjp.3` established the independently pinned 8,024-row MS-OFORMS persistence/default baseline, including typed fields/defaults/masks/value maps, composite dependencies, algorithms/examples/product-note linkage, and explicit non-claims. `oxforms-jbjp.43` closed in reviewed commit `9572f7a` with a strict v2 capture of three genuine Excel export pairs, exact Excel/VBE binary provenance, fifteen MS-OVBA DesignerProperties, full byte-accounted CFB inventories, 98 property rows/245 family pairs, and a source-pinned 43-field binary length/count contract; it makes no parser, codec, runtime API, decoded-live-property, nonzero-offset, or VB6 claim. `oxforms-jbjp.4` established the deterministic 7,753-row raw-contract/current-overlay ledger: 2,452 verified baseline rows, 4,682 gap rows, 619 unexpected-public rows, 20,046 gating dimension cells, and `green = false`. It pins the complete source/generator/test dependency closure, rejects dead/commented loader evidence and alternate-artifact bypasses, preserves exact non-dispatch vtable slots/layout, and keeps owner/logical summaries row-derived. `.5` established the generalized live property/method/error/event oracle and its representative canonical capture; `.6` has generated the facade/site/event contract but remains blocked by pinned OxVba default-member/Friend visibility failures (`oxforms-o0fp`) and the live Excel startup dialog; its evidence distinguishes infrastructure checks from unmet acceptance. The broader unchanged-project target includes Microsoft-supplied controls beyond MSForms (`oxforms-tst7` inventory), with third-party controls excluded. | referenced facts/ledger/oracle; explicit OxVba handover/late gate; facade/supporting objects and `UserForms`; atomic Control/collections/persistence lanes; paired control capture/implementation; actual HTML families plus shared-band gate; exact event/render/corpus/stress lanes; independent closure audit | deterministic generators/validators; generated VBA bind and semantic/error/event tests; live MSForms differentials; `.frm/.frx` export and roundtrip corpora; fmt/clippy/workspace tests with sufficient timeout; evidence/graph/hygiene checks |
| `W011_microsoft_controls_beyond_msforms` | Microsoft-supplied controls beyond MSForms | `OPEN` | `oxforms-tst7` | `W010_complete_msforms_object_model_parity` | Inventory, plan, and deliver clean-room implementations of Microsoft-supplied controls outside FM20 (Excel RefEdit, Common Controls 6.0/5.0 MSCOMCTL/MSCOMCT2, RichTextBox) without original OCX binaries. | `docs/specs/MICROSOFT_CONTROLS_BEYOND_MSFORMS.md`, `docs/worksets/W011_microsoft_controls_beyond_msforms.md` | Public typelib facts, persistence stream decoders, RefEdit Excel host provider seam, and common controls are implemented and conformant across 32-bit and 64-bit profiles without OCX dependencies. | typelib facts; persistence/export decoders; RefEdit host integration; Common Controls suite; conformance corpus | targeted compilation/binding tests; RefEdit host mock/differential; roundtrip persistence; workspace checks |

Run 8 input evidence: `.112` requires the full native PageDown/TopIndex
transcript and 54 boundary observations; paint and hit targets use that viewport.
`.105.1` records initial NameInput and dynamic TabIndex append order, and the
original workbook scenario requires Enter without a preparatory Tab. Its broader
acceptance stays open. `.117` records the separate CalcVBA inline-Case defect.

Run 8 real-workbook follow-up: `.122` fills forty greeter input unknowns. `.119`
delivers the genuine inventory workbook and complete 316-match / 4-failure
comparison; `.121` corrects the initial whole-row viewport; `.123` retains cancel-focus discrepancies.
One Excel launch was reused and stopped through its retained handle. All eighteen
runtime handles closed, the worker desktop was restored and the private desktop
closed without the former error 170. `.108` keeps broader cancellation/recovery open.
Round 14 (2026-11-09) codes the round 13 rules: `.133` MultiPage as two Tab stops, `.118` ListBox two heights with
`UserForm.Zoom`, a Font object and zoom-aware rows, and adds the measured Font object, common IControl members, TabIndex
renumbering and twip geometry (`.101`, `.105`). See the `ROUND14.md` files in those bead folders; the replays are
`multipage_tab_stops.rs`, `listbox_height_rule.rs` and `round14_replay.rs`.
