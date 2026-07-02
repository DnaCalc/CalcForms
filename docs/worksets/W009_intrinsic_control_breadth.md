# W009 — Complete MSForms Intrinsic Control Breadth

Status: `IN PROGRESS` (phase-0 first-class runtime foundation active; broad control breadth is
gated behind it)
Epic: `oxforms-zhz`. The `oxforms-zhz.*` beads are the live phase-0 execution truth;
the older suffix plan below is retained as the broad-control roadmap until the foundation gate
rewrites the broad lanes.
Depends on:
`W006_control_implementation_rollout` (CLOSED — the reviewed control-rollout pattern + the first
control lanes),
`W007_production_runtime_vertical_slice` (CLOSED — the Scene / VBA self-render runtime),
`W008_native_event_breadth` (OPEN — current native-dispatch baseline is usable, but remaining
oracle/repeat/breadth facts must be respected; W009 parity claims depend on either closure or precise
blockers).
Realizes: the **P4 (Control breadth)** phase of
[`../FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md) §11 — taking the full
`FM20.dll` intrinsic control set to the proven subset depth.

## Purpose

Take OxForms from four end-to-end controls (`Label`, `CommandButton`, `TextBox`, and
`CheckBox`) to the **complete MSForms 2.0 intrinsic control set** — all fourteen —
systematically, **batched by control family**, at the proven subset depth (events + value +
render + native dispatch, each oracle-backed or precisely blocked). Advanced per-control features
(multi-select, dropdown, page switching, auto-repeat) are carried as **explicit sub-lanes within
this workset**, not deferred. **No control category is pushed out of scope.** Where a control needs
machinery that does not exist yet, W009 schedules a **de-risking research / spike bead immediately
before that control's lane** — risk is surfaced and met at the right time, never used as a reason to
drop a control.

This is deliberately a large workset: it is the project's P4 phase. It is organized into internal
phases (foundations → morph family → simple controls → containers → completeness) so each batch
stays small and reviewable, but it is one workset with one closure condition: the intrinsic set is
complete.

W009 was drafted **plan-first** from a multi-perspective design pass (four lenses) whose load-bearing
architecture claims were **adversarially verified against the code**; the verified findings are in
[What The Planning Pass Established](#what-the-planning-pass-established).

The W009 baseline is the same spine W006/W007/W008 used:

```text
real or synthetic input
  -> normalized UiEvent
  -> OxRuntime dispatch into the VBA form-document facade
  -> VBA OxReducer hit-test / focus / capture / keyboard routing
  -> concrete IOxControl Perform* methods raising native FM20-shaped events
  -> inline mutable Return* helper readback in VBA
  -> VBA self-render (IOxControl.Render -> OxSceneBuilder Scene) -> rasterize
  -> trace/replay + live-oracle comparison evidence
```

**Living showcase.** `vba/smoke/fixtures/full_surface_showcase_form.cls` is the evolving
current-state super-app for this workset. Entering W009 it renders the four implemented controls,
lists the remaining FM20 intrinsics as pending rows, exposes `RunSelfTest` to drive the current
method/event surface through `OxRuntime`/`OxReducer` headlessly, and now surfaces the TextBox
caret/selection/editing lane as a live conformance row. Each W009 control lane should add its new
control, method rows, event handlers, and deterministic self-test coverage to this fixture instead
of creating a separate demo island.

**Phase-0 hazard gym (owner directive, 2026-07-01).** Before broad control lanes resume, W009 must
make the runtime first-class enough that later controls cannot hide structural surprises. Phase 0
therefore exercises the highest-risk mechanisms up front: a reusable headless runner over the real
`OxRuntime`/`SurfaceFactory` path; focus/tab/default/cancel/accelerator/capture/cursor routing;
host-service seams for clipboard, cursor, timers, system metrics/colors, DPI, and image decode;
caret/selection/focus rendering hazards; capability descriptors and object-model side effects;
`.frm/.frx` materialization; handler reentrancy/lifecycle; and representative list/container/image/
timer spikes. These are not separate demos or alternate backends. They are gates on the same VBA
reducer, Scene seam, and Windows acceptance path that production uses.

**Control-stack reassessment gate (owner directive, 2026-07-01).** W009 also records the DNA UI
stack consolidation decision in
[`../specs/CONTROL_STACK_STRATEGY.md`](../specs/CONTROL_STACK_STRATEGY.md) and
[`../evidence/W009_first_class_runtime_foundation/control-stack-reassessment.md`](../evidence/W009_first_class_runtime_foundation/control-stack-reassessment.md).
OxForms does not migrate its core controls to Leptos/Tauri, DOM widgets, or native OS controls.
Instead, it keeps `OxRuntime` + OxVba + retained Scene + PAL as the canonical path and adds explicit
internal seams (`TextService`, `ThemeTokens`/`ThemePainter`, `AccessibilityService`,
`RendererBackend`, `HostServices`, `InteractionManager`, and `CapabilityDescriptor`) so hard
subsystems can be implemented or optimized without creating a second object model.

**Initial-development rework doctrine (owner directive, 2026-07-01).** OxForms is still in initial
development. Internal draft APIs, helper shapes, runner/bootstrap contracts, fixture formats,
documentation wording, and tests have no legacy-preservation or internal compatibility promise. W009
must get to the correct representative architecture now, even if that means deleting, renaming,
replacing, or quarantining earlier scaffolds. The compatibility target is MSForms/FM20 observed
behavior plus supported VBA semantics, not prior OxForms implementation shapes.

Every architecture-rework bead carries this required review instruction:

> At the end of the bead, check over everything again with fresh eyes, looking for any blunders,
> mistakes, errors, oversights, omissions, logical issues, problems, misconceptions, confusion,
> bugs, etc. and rework accordingly. After there are no more issues raised by such a review, do a
> commit of the work.

**Ideal architecture rework bead set.** The live rework graph is `oxforms-zhz.13` through
`oxforms-zhz.33`. The older generic phase-0 placeholders remain as roll-ups and are blocked behind
these detailed beads where applicable.

| Bead | Purpose | Main dependencies / role |
|---|---|---|
| `oxforms-zhz.13` | Make the no-legacy-preservation doctrine explicit and reconcile older placeholders with the new graph. | First ready architecture-rework bead after `oxforms-zhz.12`. |
| `oxforms-zhz.14` | Define and implement the canonical runtime/event-turn contract for headless and Windows paths: `RuntimeInput`, `OxRuntime::dispatch_event_turn`, and `RuntimeEventTurn`. | Depends on `.13`; later seams depend on this. |
| `oxforms-zhz.15` | Build `HostServices` for clipboard/DataObject, cursor, timers, metrics/colors, DPI, image decode, drag/drop, and traces. | Depends on `.14`; landed representative headless + Windows service spine behind `OxRuntime`. |
| `oxforms-zhz.16` | Extract `TextService` for shaping, caret stops, hit testing, selection geometry, clipping, and horizontal scroll. | Depends on `.15` and `.17`; landed v1 single-line `OxTextService` plus clipped TextBox text viewport. |
| `oxforms-zhz.17` | Close `RendererBackend`/Scene determinism: primitive emitters, headless raster coverage, no silent primitive drops. | Depends on `.14`. |
| `oxforms-zhz.18` | Add representative `ThemeTokens`/`ThemePainter` for MSForms properties and control states. | Depends on `.17`; landed v1 in `OxTheme.bas` with Scene assertions for selected text/background, disabled text, pressed face, caret color, and edge effects. |
| `oxforms-zhz.19` | Rebuild `InteractionManager` for focus, tab, capture, hover/cursor, validation, mutation, wheel/double-click, and invalidation. | Depends on `.14`; landed `OxInteractionManager` as the state owner behind the stable `OxReducer` facade, with representative focus/capture/hover/cursor/tab/default/cancel/accelerator/mutation coverage. |
| `oxforms-zhz.20` | Unify capability descriptors and object-model property side effects. | Depends on `.14`; landed flat `Controls.Remove`, live-name lookup, structural Scene rebuilds after add/remove, capability-driven toggle policy, and stale focus/capture/hover clearing for hide/disable/remove. |
| `oxforms-zhz.21` | Add representative `AccessibilityService` snapshots/traces. | Depends on `.19` and `.20`. |
| `oxforms-zhz.22` | Implement representative `.frm/.frx` materialization directly into the VBA object model. | Depends on `.15`, `.17`, and `.20`. |
| `oxforms-zhz.23` | Refresh the W009 oracle matrix around the ideal seams and representative controls. | Depends on `.13`; representative controls consume it. |
| `oxforms-zhz.24` | Rebuild TextBox as the first representative complex control on all ideal seams. | Depends on `.15`-`.21` and `.23`; roll-up `oxforms-zhz.9` depends on this. |
| `oxforms-zhz.25` | Rebuild CheckBox as the representative boolean/value control on ideal seams. | Depends on `.15`, `.17`-`.21`, and `.23`. |
| `oxforms-zhz.26` | Implement a representative ListBox/list-data spike. | Depends on `.15`-`.21` and `.23`; roll-up `oxforms-zhz.6` depends on this. |
| `oxforms-zhz.27` | Implement a representative Frame/container coordinate spike. | Depends on `.15`, `.17`-`.21`, and `.23`; roll-up `oxforms-zhz.6` depends on this. |
| `oxforms-zhz.28` | Implement a representative Image binary/`.frx` spike. | Depends on `.15`, `.17`-`.23`; roll-up `oxforms-zhz.6` depends on this. |
| `oxforms-zhz.29` | Implement a representative SpinButton/ScrollBar timer-repeat spike. | Depends on `.15`, `.17`-`.21`, and `.23`; roll-up `oxforms-zhz.6` depends on this. |
| `oxforms-zhz.30` | Prove reentrancy, modal/lifecycle, handler mutation, queued input, and repaint coherence. | Depends on `.15`, `.17`-`.23`; roll-up `oxforms-zhz.7` depends on this. |
| `oxforms-zhz.31` | Emit performance reports and budget bands for the ideal architecture. | Depends on representative controls/spikes `.24`-`.30`; roll-up `oxforms-zhz.8` depends on this. |
| `oxforms-zhz.32` | Rebuild the full-surface showcase as a conformance dashboard over the ideal architecture. | Depends on representative controls/spikes `.24`-`.30`, accessibility, and materialization; roll-up `oxforms-zhz.8` depends on this. |
| `oxforms-zhz.33` | Final fresh-eyes architecture review, scaffold retirement/quarantine, and broad-control lane rewrite. | Depends on `.31` and `.32`; roll-up `oxforms-zhz.8` depends on this. |

## The Complete Intrinsic Control Set

The set is bounded and mechanically enumerable from `FM20.dll` + [MS-OFORMS]
([`../FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md) §5.1). W009 commits to
every row below.

| Control | Family | Status entering W009 | W009 work |
|---|---|---|---|
| `UserForm` | container (the form) | done (W006/W007) | — |
| `Label` | simple | done | — |
| `CommandButton` | simple | done | — |
| `TextBox` | morph / data | implemented subset plus phase-0 single-line caret/selection/editing slice (`oxforms-zhz.4`), quick typing fix (`oxforms-zhz.10`), shaped caret/drag repair (`oxforms-zhz.11`), and TextService/horizontal-scroll seam (`oxforms-zhz.16`) | remaining hardening: `oxforms-zhz.9` for setter side effects and burst/post oracle behavior; `oxforms-zhz.34` for multiline/IME/undo/grapheme follow-ups; pixel-level selection parity still needs oracle evidence |
| `CheckBox` | morph / data | implemented subset (`oxforms-ih6.2`/`.5`/`.7`; VBA class, render, mouse/keyboard toggle, native events); W009 headless runner now covers tab-to-CheckBox plus Space toggle/value-first event order | remaining phase-0 hardening: focus visibility/adorners, disabled/hidden/tab-stop mutations, cursor behavior, validation edge cases, and live oracle notes |
| `OptionButton` | morph / data | none | full lane |
| `ToggleButton` | morph / data | none | full lane |
| `ComboBox` | morph / data | none | full lane (list-data + dropdown) |
| `ListBox` | morph / data | none | full lane (list-data + multi-select) |
| `Image` | simple | none | full lane (image decode + `.frx`) |
| `ScrollBar` | simple | none | full lane (value + auto-repeat) |
| `SpinButton` | simple | none | full lane (value + auto-repeat) |
| `Frame` | container | none | full lane (nested children) |
| `MultiPage` (+ `Page`, `Pages`) | container | none | full lane (paged children) |
| `TabStrip` (+ `Tab`, `Tabs`) | container | none | full lane (tab re-skin) |

Supporting objects already exist or were delivered earlier: the `Controls` collection, the current
`IOxControl` contract, and the by-ref event-arg objects currently used by the runtime
(`ReturnBoolean`/`ReturnInteger`). Additional helper/value objects such as `ReturnSingle`,
`ReturnString`, `ReturnEffect`, `Font`, `Picture`, and `DataObject` are created only when a later
control lane needs them.

**Scope boundary (not deferral).** "Complete MSForms intrinsic set" means the `FM20.dll` controls
above. `RefEdit` and other host / windowed-ActiveX controls are **not FM20 intrinsics** — they are
Excel-host territory served by the extension-control seam (P2.5 / §4.7 / decision D12), out of W009
by definition. The morph six (`TextBox`/`ComboBox`/`ListBox`/`CheckBox`/`OptionButton`/
`ToggleButton`) share one MS-OFORMS serialization (MorphData, §7.3), which is why the morph family
is batched first.

## Start Reading

- `CHARTER.md` §§1, 3, 3.1, 4, 5, 7; `OPERATIONS.md` §§4, 5, 6, 7, 10.
- [`../FORMS_LIBRARY_SPEC_AND_PLAN.md`](../FORMS_LIBRARY_SPEC_AND_PLAN.md) — especially §5
  (object-model scope + the §5.6 appearance defaults), §6 (PAL contract incl. timers/image-decode),
  §7 (`.frm`/`.frx` + the morph codec), §11 (the P4 phase this realizes), §12 (open questions:
  MultiPage/TabStrip representation; `.frx` parsing split).
- [`W006_control_implementation_rollout.md`](W006_control_implementation_rollout.md) (the rollout
  pattern + the CheckBox lane history) and
  [`W008_native_event_breadth.md`](W008_native_event_breadth.md) (native event/helper facts that
  the post-pivot VBA reducer now consumes inline).
- Specs: [`../specs/RENDERING_ARCHITECTURE.md`](../specs/RENDERING_ARCHITECTURE.md) (§5 control
  render, §6 the Surface seam + primitive vocabulary, §14 deferred virtualization — **W009
  un-defers it for list/scroll controls**, §16 the frame model),
  [`../specs/CONTROL_STACK_STRATEGY.md`](../specs/CONTROL_STACK_STRATEGY.md) (the W009
  control-stack reassessment and DNA UI consolidation gate),
  [`../specs/FM20_EVENT_FACTS.md`](../specs/FM20_EVENT_FACTS.md),
  [`../specs/COORDINATE_MODEL.md`](../specs/COORDINATE_MODEL.md) (the container foundation touches
  this), [`../specs/INPUT_INTERACTION_MODEL.md`](../specs/INPUT_INTERACTION_MODEL.md),
  [`../specs/TRACE_REPLAY_SCHEMA.md`](../specs/TRACE_REPLAY_SCHEMA.md).
- The CheckBox lane as it stands: the control behavior (Boolean `Value`, the value-before-Click
  toggle, the two-stage `BeforeUpdate`/`AfterUpdate` dirty path, the bespoke box-glyph `Render`) in
  [`../../vba/oxforms/CheckBox.cls`](../../vba/oxforms/CheckBox.cls); the interaction routing
  (mouse capture + pressed-visual arming, the Space/Enter keyboard activation via
  `TryKeyboardActivate`) in [`../../vba/oxforms/OxInteractionManager.cls`](../../vba/oxforms/OxInteractionManager.cls)
  behind the stable [`../../vba/oxforms/OxReducer.cls`](../../vba/oxforms/OxReducer.cls) facade;
  the VBA factory in [`../../vba/oxforms/OxFormsModel.bas`](../../vba/oxforms/OxFormsModel.bas); the
  recorder set in [`../../vba/oxforms/OxSceneBuilder.cls`](../../vba/oxforms/OxSceneBuilder.cls); the
  `Prim` enum + headless reference sink in
  [`../../crates/oxforms-pal/src/scene.rs`](../../crates/oxforms-pal/src/scene.rs); the conformance
  coverage in [`../../crates/oxforms-oxvba-adapter/tests/oxvba_reducer_cmdbutton.rs`](../../crates/oxforms-oxvba-adapter/tests/oxvba_reducer_cmdbutton.rs).
- The W008 oracle harness: [`../../tools/office-oracle/New-W008OracleWorkbook.ps1`](../../tools/office-oracle/New-W008OracleWorkbook.ps1)
  and the fixture/evidence layout.

## Doctrine And Non-Claims

W009 inherits the charter's clean-room, evidence-first, VBA-first doctrine. The oracle uses only
public Excel/VBIDE/Windows APIs; a behavioral claim is backed by a live MSForms capture or a precise
blocker; a `docs/specs/...` citation in code or a manifest must be true. Rust stays
control-agnostic; each control's behavior and appearance live in a VBA `.cls` implementing
`IOxControl`.

**Post-`oxforms-ih6` baseline.** The old "runtime models four kinds, but CheckBox is not
VBA-rendered" caveat is retired. `CheckBox.cls` exists, `OxCreateControl` returns a live control for
`Forms.CheckBox.1`, the VBA reducer owns mouse/keyboard/focus routing, and `CheckBox` toggles its
Boolean `Value` before raising `Change` then `Click`. The true end-to-end count entering W009 is
four controls. W009 starts with the next missing intrinsic control, not by re-closing CheckBox.

**What "complete" means here.** Every intrinsic control reaches the proven subset depth (events +
value + render + native dispatch, oracle-backed). Advanced per-control behavior is implemented as
**named sub-lanes**, each oracle-backed or carrying a precise blocker — never a silent omission.
W009 does **not** claim: pixel-perfect rendering parity; the full `.frm`/`.frx` persistence codec or
MS-OFORMS round-trip (that is P3 / OxDoc — W009 extends the subset loader per control and does a
*minimal* `.frx` image decode where `Image` needs it); the designer (P8); `RefEdit`/host controls
(extension track); held-button **auto-repeat rate** capture (uvh-class oracle-unreachable — Excel
intercepts held-key repeat before the form; see
[`../evidence/W008_native_event_breadth/FOLLOWUP_CAPTURE_PLAN.md`](../evidence/W008_native_event_breadth/FOLLOWUP_CAPTURE_PLAN.md));
and any list type-ahead / dropdown-Escape behavior that the same app-level key interception blocks
(probed once, then recorded as a precise blocker, not guessed).

**Risk doctrine (your directive).** No control *category* is beyond scope. Where a control needs
machinery that does not exist, the lane is preceded by a **research / spike bead** that proves the
mechanism (or records a precise blocker) before the implementation bead — see
[Foundations And De-Risking Research](#foundations-and-de-risking-research). The category ships; the
risk is retired at the right time.

## What The Planning Pass Established

Four findings, each checked against the committed code (the working tree was confirmed clean
afterward — a probe that added a 5th `ControlKind` variant to test exhaustiveness was reverted):

1. **`CheckBox` is now the proof-of-pattern (confirmed, high confidence).** The CheckBox gap
   identified by the original planning pass was closed by `oxforms-ih6`: the concrete
   `CheckBox.cls` implements `IOxControl`, renders its box/caption, participates in the VBA
   reducer's mouse/keyboard/focus paths, and raises `Change` before `Click` with `Value` already
   updated. W009 should preserve that as regression coverage while using it as the pattern for
   additional Boolean/value controls.

2. **The dispatch seam moved from Rust `ControlKind` matches to the VBA factory/interface
   surface (severity major).** Adding a kind now requires updating `OxControlKind`,
   `OxKindFromProgId`, `OxCreateControl`, the concrete class implementing `IOxControl`, and any
   reducer policy the new control needs. The silent-misroute risk is no longer Rust
   non-exhaustive `match` drift; it is duplicated VBA policy such as focusability, pressed visual,
   default/cancel eligibility, accelerator eligibility, dirty/update behavior, and paste/edit
   support. → **Fix with a per-kind/control capability descriptor on the VBA side** before adding
   the next kind, so `OxReducer` reads one declared policy surface instead of scattered predicates.

3. **The old Rust per-kind state-store finding is obsolete; VBA object state is the base.** The
   deleted `oxforms-core` `FormState`/`ControlNode` vectors no longer own runtime behavior. Current
   durable state lives in `UserForm`, `Controls`, `OxControlCore`, concrete control fields, and the
   `OxReducer` interaction fields. Incremental state remains the right plan for scalar controls
   (`OptionButton`/`ToggleButton` can follow CheckBox's shape), but list-data controls
   (`ComboBox`/`ListBox`) need a first-class VBA collection/selection model and dropdown surface.

4. **The primitive vocabulary had a determinism hole for glyph/image controls (verified, now
   closed by `oxforms-zhz.17`).** The original planning finding was that the kernel `Prim` enum
   defined `RoundRect`, `Ellipse`, `Polygon`, `DrawImage`, and other vocabulary that
   [`OxSceneBuilder.cls`](../../vba/oxforms/OxSceneBuilder.cls) could not yet emit, while the
   **headless reference sink** (`render_headless_*`, the golden/determinism oracle) dropped several
   non-rect primitives from the framebuffer hash. `oxforms-zhz.17` adds the missing builder
   recorders and deterministic headless/visible placeholder coverage so glyph/image controls cannot
   pass by silently omitting those prims. Real decoded image pixels remain the later image lane.

## Foundations And De-Risking Research

Cross-cutting work, each scheduled **just before the batch that needs it** (not all up front):

- **F0 — Control-stack architecture gate** (`oxforms-zhz.12`). Confirm the W009 strategy after
  the sibling DNA stack review: OxForms keeps `OxRuntime`/OxVba/Scene/PAL as the canonical runtime;
  Leptos/Tauri remain sibling product-shell inspiration and possible future binder context, not the
  core MSForms control implementation. The gate names the internal service seams that later code
  must converge on.
- **F1 — Capability descriptor** (finding 2). One authoritative VBA capability surface for each
  implemented kind/control; route reducer policy queries such as focusable, tab-stop, click,
  pressed visual, toggleable, text-editing, default/cancel, accelerator, dirty/update, and paste
  support through it.
  *Before any new kind.*
- **F2 — Primitive-vocabulary + determinism closure** (finding 4, landed by `oxforms-zhz.17`). Add
  the missing `OxSceneBuilder` recorders (`Line`/`RoundRect`/`Ellipse`/`Polygon`/`Gradient`/
  `DrawImage`) byte-aligned to the serde `Prim` wire format; make the headless reference sink
  rasterize the full vocabulary and replace the placeholder `DrawEdge`. *Before any glyph/image
  control.*
- **F3 — Container / coordinate model** (research + design). The control tree is flat today;
  containers need nested coordinate origins, clipping, hit-test recursion, and tab-scoping. A live
  oracle spike captures the structural facts (child coordinate origin, clip behavior, Enter/Exit
  across the boundary, tab order) and resolves the §12 open question on MultiPage/TabStrip
  representation; then the [COORDINATE_MODEL](../specs/COORDINATE_MODEL.md) is extended. *Before
  `Frame`/`MultiPage`/`TabStrip`.* This is a foundation point — treat with the care the owner
  expects at foundations.
- **F4 — List-data + selection model** (research + design). Current VBA control state handles only
  scalar values; lists are collections (`AddItem`/`List`/`ListIndex`/`Column*`/`MultiSelect`) plus a
  dropdown popup surface for `ComboBox`. A spike captures the selection-event matrix and dropdown
  lifecycle (flagging the uvh-class key-interception risk for type-ahead/Escape) and designs the
  collection state that stays out of the control-agnostic kernel. *Before `ComboBox`/`ListBox`.*
- **F5 — Auto-repeat timer service**. The PAL contract names timers incl. auto-repeat (§6.2) but the
  reducer does not drive a repeat timer yet. Wire the held-button repeat path, reusing the held-key
  once-gate pattern (esq.12/esq.15). The single-step value+event facts are oracle-reachable; the
  **repeat rate** is uvh-class unreachable (documented non-claim, probed once). *Before
  `ScrollBar`/`SpinButton`.*
- **F6 — Binary/image interop + minimal `.frx` decode** (research + spike). Image bytes (and
  list-data blobs) do not fit the current JSON-string VBA↔Rust channel
  ([`OxSceneBuilder.cls`](../../vba/oxforms/OxSceneBuilder.cls) `ToPatchJson` is the wire format).
  This is the standing wire-format concern surfacing under load. The spike evaluates the channel for
  binary payloads (extend JSON minimally vs. a typed/binary path), implements the
  `DecodeImage(bytes) -> opaque handle` PAL service (image decode is Rust per D6) and a minimal
  `.frx` picture decode for the fixture. *Before `Image`.*
- **F7 — Uniform value/event helper pattern.** The old Rust runner value-push seam is gone. For new
  value controls, keep the CheckBox/TextBox pattern explicit in VBA: programmatic property set
  updates state without a user `Change`; user interaction mutates the value, marks dirty where
  appropriate, raises `Change` in the oracle-backed order, then reads mutable helper objects inline.
  List controls add supplemental selection/list setters on top.

## Dependency Shape

Gate first (mirrors W006's `0a0.9`); all executable beads depend on it. Foundations land just before
the batch that needs them: F1/F2/F7 before the morph-toggle batch; F4 before the list batch;
F5/F6 before the simple batch; F3 before the container batch. Each control lane is, per the
W006/W008 rhythm, a **ground+capture** bead then an **implement** bead (the gate splits the
single-row lanes below into those two). Glyph/image lanes depend on F2; value lanes on F7; list
lanes on F4; container lanes on F3; auto-repeat lanes on F5; `Image` on F6.

## Bead Plan

Live phase-0 beads, created 2026-07-01:

| Bead | Purpose | Acceptance summary |
|---|---|---|
| `oxforms-zhz.1` | Foundation gate + headless runner scaffold. | Reusable runner attaches a VBA form, dispatches queued input, applies deterministic repaint policy, snapshots the resident Scene, reads VBA state, and emits JSONL trace rows; W009 docs/register name the hazard-gym gate. |
| `oxforms-zhz.2` | Capability descriptor + interaction manager. | Implemented scaffold: `OxControlCore.CapabilityDescriptor`; concrete policy getters route through core for the static axes; `UserForm.InteractionRevision`; lazy `OxReducer` maps for tab next/prev, first/last tab stop, default/cancel, accelerators, hover/cursor target/code; showcase diagnostics expose the catalog and index. Remaining phase-0 hazards: host cursor application, spatial hit-test indexing/perf, deletion/hide/disable oracle semantics. |
| `oxforms-zhz.3` | MSForms oracle pass for foundation hazards. | Coverage pass recorded in `docs/evidence/W009_first_class_runtime_foundation/oracle-foundation-matrix.md`: existing W006/W008 captures are classified as consumed facts, and TextBox caret/selection, CheckBox focus/disabled, pointer/cursor, wheel, focused deletion/hide/disable, `.frx`, and container unknowns are explicit blockers for the lanes that need them. |
| `oxforms-zhz.12` | Control-stack reassessment and DNA UI consolidation gate. | `docs/specs/CONTROL_STACK_STRATEGY.md` and `docs/evidence/W009_first_class_runtime_foundation/control-stack-reassessment.md` record the sibling DnaOneCalc/DnaTreeCalc stack findings, keep OxRuntime/OxVba/Scene/PAL canonical, reject Leptos/Tauri/DOM/native-widget migration as the core runtime path, and name the service seams and future DOM/WebView binder gate. |
| `oxforms-zhz.4` | TextBox first-class editing hazard lane. | Implemented first slice: `SelStart`/`SelLength`/`SelText`/`HideSelection`, selection replacement, Backspace/Delete/Home/End/Left, Ctrl+A, Ctrl+C/Ctrl+X/Ctrl+V, paste/drop replacement, same-turn repaint for dirty key/focus turns, and initial caret/selection scene proof. Non-claims narrowed by `.10`/`.11`/`.16`: multiline, IME/dead keys, undo/redo, grapheme-aware editing, setter side effects, and pixel-level MSForms selection parity remain open. |
| `oxforms-zhz.10` | TextBox quick key-sequence repair. | Bootstrap avoids per-key clipboard reads, avoids redundant renders after reducer repaint, defers ordinary printable KeyDown/KeyUp redraws around CharacterInput, and headless covers rapid `abcdef` plus repeated Backspace. |
| `oxforms-zhz.11` | TextBox shaped caret geometry, selected-text recolor, and drag-selection repair. | MeasureBatch returns caret stops to VBA; TextBox caret/selection/hit-testing consumes shaped stops; selected text is recolored through a clipped Scene child; MouseMove routes through bootstrap/headless/reducer capture; adapter and headless tests reproduce Shift+arrow/Backspace, proportional-font selection geometry, and mouse drag selection. |
| `oxforms-zhz.9` | TextBox horizontal scroll, setter side effects, and deeper editing follow-up. | Narrowed by `.16`: horizontal scrolling/clipped draw for long single-line text is implemented through `OxTextService`; remaining scope is `SelStart`/`SelLength`/`SelText` setter side effects against MSForms and burst/post oracle behavior. IME/dead keys, multiline, undo/redo, and grapheme-aware editing are split to `oxforms-zhz.34`. |
| `oxforms-zhz.5` | CheckBox focus/value hardening lane. | Partial local proof: `headless_runner_showcase::runner_keyboard_space_toggles_focused_checkbox` tabs to the CheckBox, presses Space, and asserts value-first `Change`/`Click` before `KeyDown` plus `KeyUp` and trace rows. Remaining scope: focus visibility/adorners, disabled/hidden/tab-stop mutations, cursor behavior, validation edge cases, and live oracle notes. |
| `oxforms-zhz.6` | List/container/image/timer representative spikes. | Representative slices prove list selection, nested coordinates, image/binary rendering, and timer/repeat services before broad lanes. |
| `oxforms-zhz.7` | Reentrancy lifecycle hazard lane. | Handler mutation, focus veto, close/query-close, hide/unload, modal/nested pump probe, and queued input keep reducer state coherent. |
| `oxforms-zhz.8` | Perf + showcase conformance gate. | Runner emits perf reports and the full-surface showcase acts as a conformance dashboard for supported surface and known gaps. |

The older broad-control plan below remains the roadmap after phase 0. Its suffixes are historical
placeholders until the phase-0 gate rewrites/splits the broad lanes with live bead IDs.

| Phase | Bead | Purpose | Depends on | Acceptance summary |
|---|---|---|---|---|
| 0 | `.1` | **Planning/review gate.** Reread the spec P4 + the four findings; ratify control sequence, the seven foundations, per-control non-claims; resolve the [open decisions](#open-decisions); split each control lane into ground+capture + implement; confirm dependency edges (glyph→F2, value→F7, list→F4, container→F3, repeat→F5, Image→F6). | epic parent | graph coherent; foundations + lanes scoped; impl beads blocked behind the gate; `br dep cycles` clean; W009 stays open. **Do not close W009 from the gate.** |
| F | `.2` | **F1 capability descriptor.** Authoritative per-kind/control capability surface in VBA; route reducer policy predicates through it. | `.1` | one declared capability source; existing 4-control behavior byte/ordering unchanged; adding a dummy kind requires an intentional capability entry; floor green. |
| F | `.3` | **F2 primitive-vocab + headless-sink closure.** Historical placeholder now implemented by `oxforms-zhz.17`: missing `OxSceneBuilder` recorders landed, the headless reference sink rasterizes the full representative vocabulary, and placeholder `DrawEdge` is retired. | `.1` | VBA-emitted bytes round-trip to the matching `Prim`; a non-rect prim perturbs `framebuffer_hash`; damage==full and immediate==applied-patch hold for a fixture with each new prim; floor green. |
| F | `.4` | **F7 uniform value/event helper pattern.** Document and test the CheckBox/TextBox pattern as the required implementation shape for new value controls. | `.1` | TextBox and CheckBox user/programmatic value semantics remain unchanged; the next value-control lane has an explicit recipe for dirty state, `Change`, and mutable helper readback; floor green. |
| A | `.5` | **ToggleButton lane** (cheapest new kind — boolean value, no grouping; latched pressed-face from CommandButton paint; no new primitive). | `.1`, `.2`, `.4` | oracle confirms `Value`-latched pressed appearance + CheckBox-equivalent ordering (or blocker); reuses the toggle spine; per-lane tests + native-dispatch fixture + floor green. |
| A | `.6` | **OptionButton lane** (boolean value + group mutual-exclusion via GroupName; radio `Ellipse` glyph). Captures the cross-sibling Change/Click ordering on re-select + arrow-key group nav. | `.1`, `.2`, `.3`, `.4` | mutual-exclusion ordering conforms to the capture; group keyed by GroupName (parentage grouping routes to F3); per-lane tests + native-dispatch fixture + floor green. |
| B | `.7` | **F4 list-data + selection model** (design + research spike). Collection state + selection matrix + dropdown popup surface; probe the type-ahead/Escape key-interception risk once; design the list-data shape kept out of the kernel. | `.1` | facts/assumptions/blockers separated (W006 `0a0.10` style); dropdown-keyboard reachability recorded; ComboBox/ListBox impl lanes split with named captures; no reducer code yet. |
| B | `.8` | **ListBox lane** (list-data + single & multi-select modes `fmMultiSelect*`; Ctrl/Shift/Space selection; arrow/Shift-arrow nav). | `.1`, `.2`, `.3`, `.4`, `.7` | selection matrix conforms to the capture; multi-select state modeled per F4; per-lane tests + native-dispatch fixture + floor green; column/bound-column advanced bands as named sub-claims. |
| B | `.9` | **ComboBox lane** (ListBox list-data + edit field + dropdown popup; `DropButtonClick`, open/close, selection Change). | `.1`, `.2`, `.3`, `.4`, `.7`, `.8` | dropdown lifecycle + selection ordering conform to the capture (or precise blocker for key-intercepted parts); per-lane tests + native-dispatch fixture + floor green. |
| C | `.10` | **F6 image interop + `.frx` spike** (research). Evaluate the VBA↔Rust channel for binary image bytes ([[oxforms-wire-format-concern]]); implement `DecodeImage` PAL service + minimal `.frx` picture decode. | `.1`, `.3` | a binary image payload crosses the channel and decodes to an opaque handle; the channel decision is recorded with rationale; minimal `.frx` decode works for the fixture or carries an exact blocker. |
| C | `.11` | **Image lane** (`DrawImage` render + `PictureSizeMode`/alignment; static, non-focusable, click-only). | `.1`, `.2`, `.3`, `.10` | `Controls.Add "Forms.Image.1"` blits a decoded image; size modes oracle-confirmed; headless sink rasterizes `DrawImage`; floor green. |
| C | `.12` | **F5 auto-repeat timer service.** Wire the held-button repeat path (PAL timer §6.2) reusing the held-key gate; single-step reachable, repeat-rate a documented uvh-class non-claim. | `.1` | a held-button single-step fires the value+event once per step deterministically; repeat-rate recorded as captured-once-or-blocked; floor green. |
| C | `.13` | **SpinButton lane** (value clamp Min/Max/SmallChange; SpinUp/SpinDown/Change; two-zone hit-test). | `.1`, `.2`, `.4`, `.12` | single-step value+event subset conforms to the capture; held-repeat is the documented non-claim; per-lane tests + native-dispatch fixture + floor green. |
| C | `.14` | **ScrollBar lane** (thumb-drag Scroll vs Change distinction; LargeChange page region; Min/Max clamp). | `.1`, `.2`, `.4`, `.12`, `.13` | thumb/page value subset + Scroll/Change distinction conform to the capture; held page-repeat the documented non-claim; floor green. |
| D | `.15` | **F3 container/coordinate model** (design + research spike). Nested coordinate origin, clipping, hit-test recursion, tab-scoping, Enter/Exit boundary; resolves §12 MultiPage/TabStrip representation; extends COORDINATE_MODEL. | `.1` | structural facts captured from a nested fixture; the coordinate/parentage model recorded; Frame/MultiPage/TabStrip impl lanes split; no container code lands without this bead authorizing the model. |
| D | `.16` | **Frame lane** (nested children with true containment per F3; edge + caption; OptionButton parentage grouping now expressible). | `.1`, `.2`, `.6`, `.15` | a Frame renders edge+caption and owns child NodeIds with nested coordinates + clipping per F3; tab order across the boundary conforms to the capture; floor green. |
| D | `.17` | **TabStrip lane** (`Tabs`/`Tab` collections; tab strip re-skinning a shared client area; Change on tab switch). | `.1`, `.2`, `.15`, `.16` | tab switch fires Change in the captured order; the shared client area re-skins per tab; collections exposed; per-lane tests + floor green. |
| D | `.18` | **MultiPage lane** (`Pages`/`Page` collections; each page owns a child control tree; page-switch show/hide; Change on page switch). | `.1`, `.2`, `.15`, `.16` | page switch shows the right child tree and fires Change in the captured order; per-page child trees materialize; collections exposed; per-lane tests + floor green. |
| E | `.19` | **Completeness sweep + close.** Cross-control conformance against the FM20 typelib / MS-OFORMS fact-pack rows (§5.5); confirm every intrinsic ProgID has an implemented factory/control lane or a precise blocker; verify each lane's oracle-backing or blocker; close W009. | all lanes | every intrinsic control at the proven subset depth with evidence or a precise blocker; fact-pack parity rows green; no impl bead "done by prose"; register/workset/beads agree; W009 closes. |

## Open Decisions

Recorded for the gate. Per your steer, the defaults below are my best plan (resolve by judgment) or
checked against the live MSForms oracle; I'll proceed on them unless you redirect:

1. **Control order** *(my call — batched by family)*: morph-toggle (ToggleButton→
   OptionButton, with CheckBox retained as the regression pattern) → morph-list (ListBox→ComboBox) → simple (Image→SpinButton→ScrollBar) → containers
   (Frame→TabStrip→MultiPage) → completeness. Rationale: shared morph codec first; cheapest-reuse
   within each family first; ComboBox after ListBox (it is ListBox + edit + popup); containers last
   because they carry the coordinate-model foundation.
2. **Uniform value/event helper pattern** — see F7. New value controls should follow the current
   VBA-owned CheckBox/TextBox shape unless a lane proves a better local pattern.
3. **OptionButton grouping** *(oracle-checked + best plan: GroupName first, container parentage via
   F3)*. MSForms supports both; the capture drives which the reducer models first.
4. **List-data state shape** *(F4 design + oracle)*: a collection state kept out of the
   control-agnostic kernel; multi-select modes as named sub-claims.
5. **Image interop / wire-format** *(F6 spike, scheduled at the Image lane per your "sort it out at
   the right time" steer)*: evaluate extending the JSON channel minimally vs. a typed/binary path for
   image bytes; decision recorded in the spike. Connects to [[oxforms-wire-format-concern]].
6. **Container model depth** *(F3 design)*: true nested coordinates + clipping are in scope (required
   by MultiPage/TabStrip); the spike sets how far the first slice goes.
7. **Capability descriptor axes** *(best plan, extensible)*: `focusable`, `tab_stop_default`,
   `has_pressed_visual`, `supports_click`, `accepts_text_editing`, `toggleable`,
   `accelerator_eligible`, `default_special_effect`, plus list/value axes as the list batch needs.

If you have other questions or want a different cut on any of these, the gate bead is where they
get ratified before code starts.

## Closure Conditions

W009 closes only when:

1. the phase-0 first-class runtime foundation (`oxforms-zhz.1` through `oxforms-zhz.8`, the
   `oxforms-zhz.12` control-stack gate, and the ideal architecture rework graph
   `oxforms-zhz.13` through `oxforms-zhz.33`) has completed, precisely blocked, or moved to a later
   workset with explicit owner acceptance;
2. the planning/review gate has closed and every executable bead is completed, precisely blocked, or
   moved to a later workset with clear bead state;
3. the existing four-control baseline is preserved — including `Controls.Add "Forms.CheckBox.1"`
   returning a live control that self-renders and dispatches;
4. **every** FM20 intrinsic control (the [complete set table](#the-complete-intrinsic-control-set))
   is implemented to the proven subset depth, each backed by a live oracle capture conforming to the
   captured ordering or carrying an explicit blocker, with advanced sub-lanes named and resolved;
5. the foundations (F1–F7) landed without behavior regression on the existing kinds (golden + trace
   byte-parity), with the descriptor compile-tripwire and the sink prim-perturbs-hash guards in
   place;
6. every intrinsic ProgID/factory/control lane is either implemented to the W009 subset depth or
   carries a precise blocker, and the §5.5 fact-pack parity rows are green for the intrinsic set;
7. W009 docs/register/beads agree; no implementation bead remains open but accepted as "done" by
   prose.

Do not close W009 from the planning/review gate, nor from a single control lane.

## Verification Shape

| Surface | Check |
|---|---|
| Docs/workset/register | read-through, path/link scan, `git diff --check` |
| Bead graph | `br dep cycles`, `br ready --json`, `br list --json` |
| Control-stack gate | `docs/specs/CONTROL_STACK_STRATEGY.md` and `docs/evidence/W009_first_class_runtime_foundation/control-stack-reassessment.md` agree that `OxRuntime`/OxVba/Scene/PAL remain canonical and any DOM/WebView binder is future gated work |
| Ideal architecture graph | `br show oxforms-zhz.13 --json` through `br show oxforms-zhz.33 --json` show self-contained scope, acceptance, dependencies, and the required fresh-eyes/commit instruction; `br dep cycles` reports no cycles |
| Foundations | 4-kind golden + trace byte-parity (no behavior change); descriptor compile-tripwire test; headless-sink non-rect-prim-perturbs-`framebuffer_hash` test; recorder round-trip (`apply_patch`); the F6 channel round-trip for a binary payload |
| Control lanes | per-lane VBA-reducer/render tests through the adapter + a native-dispatch `WithEvents` fixture + oracle-ordering conformance against the committed capture (esq.3 pattern) |
| Showcase | `cargo test -p oxforms-oxvba-adapter --test oxvba_full_surface_showcase`; visible run with `cargo run -p oxforms-bootstrap -- showcase` when the desktop is available |
| Evidence/oracles | live Office/MSForms capture or exact blocker, with manifest + verifier + `checksums.sha256` |
| Trace/replay | schema validator; replay-generator work only where a new runner has been explicitly re-homed after the `oxforms-core` deletion |
| Headless runner | `cargo test -p oxforms-headless-runner`; JSONL trace rows include action, effect log, Scene revision/token, node count, and timings |
| Completeness | FM20 typelib / MS-OFORMS fact-pack parity rows (§5.5) for the intrinsic set; every intrinsic ProgID has an implemented factory/control lane or a precise blocker |
| Floor | `cargo fmt --all` + `cargo clippy --workspace --all-targets -- -D warnings` + `cargo test --workspace` + the pre-commit hook + `tools/Run-EvidenceChecks.ps1` |
| Clean-room posture | public facts vs assumptions; no private Office internals; no comparison against OxForms's own output |
