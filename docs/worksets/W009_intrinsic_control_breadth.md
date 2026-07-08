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
current-state conformance dashboard for this workset. It renders the live representative controls,
lists the remaining FM20 intrinsics as pending rows, exposes `RunSelfTest` to drive the current
method/event surface through `OxRuntime`/`OxReducer` headlessly, and exposes
`ConformanceDashboard` plus compact supported/pending/perf/self-test summaries. Each W009 control
lane should move its control from pending to supported, add method/property/event rows and
deterministic self-test coverage, and prove the dashboard through the real runtime path instead of
creating a separate demo island.

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
| `oxforms-zhz.21` | Add representative `AccessibilityService` snapshots/traces. | Depends on `.19` and `.20`; landed `IOxControl` accessibility projection members, `OxAccessibilityService`, showcase `AccessibilitySnapshot`, and headless trace rows that prove value/focus/selection changes. Windows UIA/MSAA provider wiring is tracked by `oxforms-zhz.35`. |
| `oxforms-zhz.22` | Implement representative `.frm/.frx` materialization directly into the VBA object model. | Depends on `.15`, `.17`, and `.20`; landed selected-slice `OxFrmMaterializer` that builds live `UserForm.Controls.Add` controls for Label/TextBox/CommandButton/CheckBox and initially recorded Image `.frx` metadata without reviving the Rust projection. `oxforms-zhz.28` consumes that metadata path into a live Image control. |
| `oxforms-zhz.23` | Refresh the W009 oracle matrix around the ideal seams and representative controls. | Depends on `.13`; refreshed `oracle-foundation-matrix.md` to split MSForms oracle facts, local OxForms proofs, per-representative-bead consumption rules, and blockers before `.24`/later control claims. |
| `oxforms-zhz.24` | Rebuild TextBox as the first representative complex control on all ideal seams. | Depends on `.15`-`.21` and `.23`; landed `Value` alias/materialization, local property/selection setter diagnostics, and showcase `TextBoxDiagnostics` over the existing single-line TextService, interaction, host-service, theme, render, object-model, and accessibility seams. |
| `oxforms-zhz.25` | Rebuild CheckBox as the representative boolean/value control on ideal seams. | Depends on `.15`, `.17`-`.21`, and `.23`; landed CheckBox-owned `Value`/focus/event/dirty state, ThemePainter glyph/focus rendering, and reducer Scene assertions. |
| `oxforms-zhz.26` | Implement a representative ListBox/list-data spike. | Depends on `.15`-`.21` and `.23`; landed a single-select ListBox with VBA-owned `AddItem`/`List`/`ListCount`/`ListIndex`/`Value`, reducer click/keyboard/focus validation, Scene selection rendering, accessibility row counts, and showcase diagnostics. Multi-select, columns, type-ahead, wheel/scroll, and virtualization remain explicit follow-up depth. |
| `oxforms-zhz.27` | Implement a representative Frame/container coordinate spike. | Depends on `.15`, `.17`-`.21`, and `.23`; landed `Frame` as a control/container owner with nested `Controls.Add`, relative child coordinates, recursive hit-test/tab/accessibility traversal, parented Scene nodes, child invalidation bubbling, and showcase `FrameDiagnostics`. Full MultiPage/TabStrip and exact MSForms container edge ordering remain later claims. |
| `oxforms-zhz.28` | Implement a representative Image binary/`.frx` spike. | Depends on `.15`, `.17`-`.23`; landed `Image` as a non-focusable click-capable live control with `Picture`/`PictureHandle`/`PictureSizeMode` diagnostics, `.frm` Image materialization, `DrawImage` Scene output, HostServices decode-handle evidence for fixture bytes, and headless/visible placeholder rendering. Real decoded pixels and full Picture object parity remain later claims. |
| `oxforms-zhz.29` | Implement a representative SpinButton/ScrollBar timer-repeat spike. | Depends on `.15`, `.17`-`.21`, and `.23`; landed `SpinButton` as the representative smaller repeat lane with VBA-owned value/range/event state, `OxRuntime` auto-repeat timer dispatch, and headless virtual-time proofs for single press, held repeat, cancellation, disabled mutation, event ordering, and timer trace. Windows/native timer wake-up remains a precise blocker before visible held-repeat claims. |
| `oxforms-zhz.30` | Prove reentrancy, modal/lifecycle, handler mutation, queued input, and repaint coherence. | Depends on `.15`, `.17`-`.23`; landed a representative `ReducerReentrancyForm` that found and fixed nested reducer effect-log clobbering, proves handler-side mutation/repaint, nested dispatch from inside a click handler, later queued validation veto, lifecycle callbacks/query-close, hide/unload state separation, and records nested modal pump as an explicit `OxRuntime` blocker. |
| `oxforms-zhz.31` | Emit performance reports and budget bands for the ideal architecture. | Depends on representative controls/spikes `.24`-`.30`; landed a machine-readable W009 budget report over the canonical headless runtime path covering input/render, burst typing, repeat, tab, mouse/cursor, timer, Scene/surface timings, and 10/50/100-control scale crossings. Slowest non-scale representative p95 on this host is `32356 us`; 10/50/100 one-control changes stay at `MeasureBatch:1` + `SubmitPatch:1`; scaled hit-testing is the top follow-up (`432473 us` p95 at 100 controls, feeding `oxforms-bqr`). |
| `oxforms-zhz.32` | Rebuild the full-surface showcase as a conformance dashboard over the ideal architecture. | Depends on representative controls/spikes `.24`-`.30`, accessibility, and materialization; landed dashboard properties for supported/pending controls, properties, methods, events, focus/cursor/services/accessibility, perf report, and `RunSelfTest`; adapter/headless tests prove it through `OxRuntime`; roll-up `oxforms-zhz.8` depends on this. |
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
| `TextBox` | morph / data | implemented subset plus phase-0 single-line caret/selection/editing slice (`oxforms-zhz.4`), quick typing fix (`oxforms-zhz.10`), shaped caret/drag repair (`oxforms-zhz.11`), TextService/horizontal-scroll seam (`oxforms-zhz.16`), and representative `Value`/property diagnostics slice (`oxforms-zhz.24`) | remaining hardening is oracle-level: exact setter event ordering/coercion/error behavior, burst/post behavior, and pixel-level selection parity; `oxforms-zhz.34` owns multiline/IME/undo/grapheme follow-ups |
| `CheckBox` | morph / data | implemented subset (`oxforms-ih6.2`/`.5`/`.7`; VBA class, render, mouse/keyboard toggle, native events); W009 headless runner now covers tab-to-CheckBox plus Space toggle/value-first event order | remaining phase-0 hardening: focus visibility/adorners, disabled/hidden/tab-stop mutations, cursor behavior, validation edge cases, and live oracle notes |
| `ToggleButton` | morph / data | implemented local lane (`oxforms-zhz.39`) | live `Forms.ToggleButton.1` factory/control class, Boolean `Value`, latched pressed visual, CheckBox-shaped Change/Click ordering, keyboard toggle, materialization, accessibility, and dashboard proof; exact MSForms ToggleButton oracle parity remains a later fact-capture depth claim |
| `OptionButton` | morph / data | implemented local lane (`oxforms-zhz.40`) | live `Forms.OptionButton.1` factory/control lane, Boolean `Value`, `GroupName`, same-container mutual exclusion, radio-glyph state rendered through stable scene primitives, keyboard/mouse selection, materialization, accessibility, and dashboard proof; exact MSForms cross-sibling event ordering and arrow-key group navigation remain oracle-gated depth claims |
| `ListBox` | morph / data | implemented local depth lane (`oxforms-zhz.26`, `oxforms-zhz.41`) | live `Forms.ListBox.1` object state covers `AddItem`, `AddRow`, `List`, `Column`, `ListCount`, `ListIndex`, `Value`, `MultiSelect`, `Selected(index)`, `ColumnCount`, `BoundColumn`, single/multi/extended row selection, multi-row render selection, accessibility, dashboard, and `.frm` property materialization; type-ahead, wheel/scrollbars, virtualization, full column width/list-data loading, and exact MSForms selection-order parity remain oracle-gated |
| `ComboBox` | morph / data | implemented local lane (`oxforms-zhz.42`) | live `Forms.ComboBox.1` factory/control lane, editable `Text`/`Value`, list collection, `ListIndex`, dropdown open/close state, `DropButtonClick`, arrow selection, paste/drop edit mutation, materialization, accessibility, dashboard, and self-test proof; native popup, type-ahead/autocomplete, wheel/scrollbars, full list-data loading, and exact MSForms event-order parity remain oracle-gated |
| `Image` | simple | implemented local depth lane (`oxforms-zhz.28`, `oxforms-zhz.43`) | live `Forms.Image.1` control now carries `Picture`, `PictureHandle`, `PictureSizeMode`, `.frx` materialization, `DrawImage`, accessibility, dashboard proof, and first-class Scene `ImageMode::Zoom`; real decoded pixels, full Picture object parity, `.frx` binary ownership/roundtrip, and exact MSForms alignment/pixel behavior remain explicit blockers |
| `SpinButton` | simple | implemented local depth lane (`oxforms-zhz.29`, `oxforms-zhz.44`) | live `Forms.SpinButton.1` control now covers `Value`, `Min`, `Max`, `SmallChange`, mouse up/down halves, Up/Down keyboard stepping, `KeyDown`/`KeyUp`, `SpinUp`/`SpinDown`/`Change`, clamped no-op turns, disabled/hidden routing, `.frm` materialization, accessibility, diagnostics, dashboard proof, and headless virtual repeat; native visible timer wake-up, repeat cadence, exhaustive key matrix, and exact MSForms visual/event parity remain oracle-gated |
| `ScrollBar` | simple | implemented local lane (`oxforms-zhz.45`) | live `Forms.ScrollBar.1` control now covers `Value`, `Min`, `Max`, `SmallChange`, `LargeChange`, horizontal button/page/thumb regions, thumb drag, Left/Right/Home/End keyboard paths, `Scroll` before `Change`, clamped no-op turns, disabled/hidden routing, `.frm` materialization, accessibility, diagnostics, and dashboard proof; held repeat cadence/native timer wake-up, vertical orientation, exact `fmScrollAction` metadata, and exact MSForms visual/event parity remain oracle-gated |
| `Frame` | container | representative coordinate/container spike (`oxforms-zhz.27`) | `oxforms-zhz.46` extends to exact caption/border blockers or proof, clipping edges, nested focus boundary, child mutation/reparent/index semantics, and dashboard proof |
| `TabStrip` (+ `Tab`, `Tabs`) | container | implemented local lane (`oxforms-zhz.47`) | live `Forms.TabStrip.1` control now covers `Tabs.Add`, `Tabs.Item`, `Tabs.Count`, `Tab.Caption`, `Tab.Selected`, `Value`/`ListIndex`, `SelectedCaption`, pointer and keyboard selection, `Change` order, disabled/hidden routing, accessibility, diagnostics, dashboard proof, and empty `.frm` materialization; serialized tab-item persistence, per-tab text-run rendering, style variants, exact source-event index args, and pixel parity remain oracle-gated |
| `MultiPage` (+ `Page`, `Pages`) | container | implemented local lane (`oxforms-zhz.48`) | live `Forms.MultiPage.1` control now covers `Pages.Add`, `Pages.Item`, `Pages.Count`, `Page.Caption`, `Page.Selected`, `Page.Controls`, `Value`/`ListIndex`, `SelectedCaption`, per-page child ownership, selected-page show/hide, pointer/keyboard page switching, `Change` order, selected-page focus scopes, accessibility, diagnostics, dashboard proof, and empty `.frm` materialization; serialized page-item persistence, nested page controls from `.frm`, per-page text-run rendering, style variants, exact source-event index args, and pixel parity remain oracle-gated |

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
MS-OFORMS round-trip (that is P3 / OxDoc — W009 extends the subset loader per control and has a
representative `.frx` indirection/opaque-handle/`DrawImage` path for `Image`, while real decoded
pixels remain a later claim); the designer (P8); `RefEdit`/host controls
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
- **F5 — Auto-repeat timer service**. The PAL contract names timers incl. auto-repeat (§6.2).
  `oxforms-zhz.29` wires the representative held-button path through `HostServices` virtual timers
  and a VBA `DispatchTimer` facade. The single-step value+event facts are oracle-reachable; the
  **repeat rate** and native Windows timer wake-up remain explicit blocker/non-claim territory before
  visible held-repeat parity. *Before the full `ScrollBar` lane and deeper `SpinButton` parity.*
- **F6 — Binary/image interop + `.frx` indirection** (research + spike). Image bytes (and
  list-data blobs) do not fit the current JSON-string VBA↔Rust channel
  ([`OxSceneBuilder.cls`](../../vba/oxforms/OxSceneBuilder.cls) `ToPatchJson` is the wire format).
  This is the standing wire-format concern surfacing under load. The spike evaluates the channel for
  binary payloads (extend JSON minimally vs. a typed/binary path), proves the
  `DecodeImage(bytes) -> opaque handle` PAL service trace, and connects the representative `.frx`
  `Picture` reference to a live Image control and `DrawImage` Scene primitive. Real decoded pixels
  and the final binary wire decision remain explicit follow-up depth. *Before `Image`.*
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
| `oxforms-zhz.3` | MSForms oracle pass for foundation hazards. | Coverage pass recorded in `docs/evidence/W009_first_class_runtime_foundation/oracle-foundation-matrix.md`, now refreshed by `oxforms-zhz.23`: existing W006/W008 captures are classified as consumed facts, local OxForms seam proofs are separate from oracle facts, and TextBox, CheckBox, pointer/cursor, wheel, focused deletion/hide/disable, `.frx`, accessibility, and container unknowns are explicit blockers for the lanes that need them. |
| `oxforms-zhz.12` | Control-stack reassessment and DNA UI consolidation gate. | `docs/specs/CONTROL_STACK_STRATEGY.md` and `docs/evidence/W009_first_class_runtime_foundation/control-stack-reassessment.md` record the sibling DnaOneCalc/DnaTreeCalc stack findings, keep OxRuntime/OxVba/Scene/PAL canonical, reject Leptos/Tauri/DOM/native-widget migration as the core runtime path, and name the service seams and future DOM/WebView binder gate. |
| `oxforms-zhz.4` | TextBox first-class editing hazard lane. | Implemented first slice: `SelStart`/`SelLength`/`SelText`/`HideSelection`, selection replacement, Backspace/Delete/Home/End/Left, Ctrl+A, Ctrl+C/Ctrl+X/Ctrl+V, paste/drop replacement, same-turn repaint for dirty key/focus turns, and initial caret/selection scene proof. Non-claims narrowed by `.10`/`.11`/`.16`/`.24`: multiline, IME/dead keys, undo/redo, grapheme-aware editing, exact setter oracle behavior, and pixel-level MSForms selection parity remain open. |
| `oxforms-zhz.10` | TextBox quick key-sequence repair. | Bootstrap avoids per-key clipboard reads, avoids redundant renders after reducer repaint, defers ordinary printable KeyDown/KeyUp redraws around CharacterInput, and headless covers rapid `abcdef` plus repeated Backspace. |
| `oxforms-zhz.11` | TextBox shaped caret geometry, selected-text recolor, and drag-selection repair. | MeasureBatch returns caret stops to VBA; TextBox caret/selection/hit-testing consumes shaped stops; selected text is recolored through a clipped Scene child; MouseMove routes through bootstrap/headless/reducer capture; adapter and headless tests reproduce Shift+arrow/Backspace, proportional-font selection geometry, and mouse drag selection. |
| `oxforms-zhz.9` | TextBox horizontal scroll, setter side effects, and deeper editing follow-up. | Narrowed by `.16` and `.24`: horizontal scrolling/clipped draw for long single-line text is implemented through `OxTextService`; `Value`, `SelStart`/`SelLength`, `SelText`, `HideSelection`, diagnostics, and `.frm` `Value` materialization have local coverage. Remaining scope is exact MSForms setter ordering/coercion/error behavior and burst/post oracle behavior. IME/dead keys, multiline, undo/redo, and grapheme-aware editing are split to `oxforms-zhz.34`. |
| `oxforms-zhz.5` | CheckBox focus/value hardening lane. | Partial local proof: `headless_runner_showcase::runner_keyboard_space_toggles_focused_checkbox` tabs to the CheckBox, presses Space, and asserts value-first `Change`/`Click` before `KeyDown` plus `KeyUp` and trace rows. Remaining scope: focus visibility/adorners, disabled/hidden/tab-stop mutations, cursor behavior, validation edge cases, and live oracle notes. |
| `oxforms-zhz.6` | List/container/image/timer representative spikes. | Representative slices prove list selection, nested coordinates, image/binary rendering, and headless timer/repeat services before broad lanes. |
| `oxforms-zhz.7` | Reentrancy lifecycle hazard lane. | Handler mutation, nested reducer dispatch, focus veto, close/query-close, hide/unload, modal/nested pump blocker, and queued input keep reducer state coherent. |
| `oxforms-zhz.8` | Perf + showcase conformance gate. | Runner emits perf reports (`oxforms-zhz.31`) and the full-surface showcase acts as a conformance dashboard for supported surface, known gaps, perf follow-ups, and deterministic self-tests (`oxforms-zhz.32`). |

`oxforms-zhz.33` rewrote the broad-control plan into live post-foundation beads. These are the
execution lanes after the phase-0 ideal architecture gate:

| Bead | Purpose | Depends on | Acceptance summary |
|---|---|---|---|
| `oxforms-zhz.39` | ToggleButton intrinsic lane on ideal architecture. | `.33`, `oxforms-bqr` | `Forms.ToggleButton.1` follows the VBA-owned boolean/value pattern with latched pressed visual, methods/properties/events, materialization, accessibility, showcase dashboard update, native-dispatch fixture, and oracle-backed or blocked ordering. |
| `oxforms-zhz.40` | OptionButton intrinsic lane with grouping. | `.39` | `Forms.OptionButton.1` implements `Value`/`GroupName`, mutual exclusion, radio glyph rendering, focus/keyboard/group behavior, materialization, accessibility, dashboard update, and oracle-backed or blocked order facts. |
| `oxforms-zhz.41` | ListBox full selection and columns lane. | `.40` | Existing ListBox spike grows to multi-select, richer selection/navigation, column/bound-column depth where scoped, type-ahead/wheel blockers or implementation, row accessibility, dashboard update, and oracle-backed or blocked selection events. |
| `oxforms-zhz.42` | ComboBox intrinsic lane with dropdown. | `.41` | `Forms.ComboBox.1` uses the ListBox/TextBox seams for edit value, list collection, dropdown open/close, `DropButtonClick`, selection `Change`, keyboard blockers or implementation, materialization, accessibility, and dashboard update. |
| `oxforms-zhz.43` | Image full Picture and decoded-pixel lane. | `.42` | Representative Image grows into decoded-pixel/Picture depth or precise blockers, exact size/alignment facts or blockers, `.frx` binary ownership, accessibility, and dashboard update while preserving `DrawImage` Scene determinism. |
| `oxforms-zhz.44` | SpinButton full range and repeat lane. | `.43` | Landed local SpinButton depth: range/value/SmallChange, mouse halves, Up/Down keyboard stepping, key/spin/change event order, clamped no-op turns, disabled/hidden routing, materialized `.frm` `CountSpin`, accessibility, diagnostics, and dashboard text. Native visible timer wake-up and exact repeat cadence remain oracle-gated blockers. |
| `oxforms-zhz.45` | ScrollBar intrinsic lane. | `.44` | Landed local ScrollBar lane: range/value/SmallChange/LargeChange, horizontal button/page/thumb regions, thumb drag, keyboard stepping, `Scroll` before `Change`, materialized `.frm` `AmountScroll`, accessibility, diagnostics, and dashboard text. Held repeat/native cadence, vertical orientation, exact `fmScrollAction`, and pixel parity remain oracle-gated blockers. |
| `oxforms-zhz.46` | Frame full container parity lane. | `.45` | Landed Frame container parity depth for the representative seam: core-owned child clip margins, render/input clipping to the same client rectangle, nested tab/focus/accessibility traversal, child-local coordinates, nested removal, and retained-scene rebuild after container structural mutation. Exact MSForms border/caption pixels, reparenting/index removal, and broader container oracle edge ordering remain non-claims. |
| `oxforms-zhz.47` | TabStrip intrinsic lane. | `.46` | Landed local TabStrip lane: `Forms.TabStrip.1`, `Tabs`, and `Tab` expose collection/selection behavior, selected value, pointer/keyboard selection, `Change` order, disabled/hidden routing, accessibility, diagnostics, empty `.frm` materialization, and dashboard update. Serialized tab-item persistence, per-tab text-run rendering, style variants, exact source-event index args, and pixel parity remain oracle-gated blockers. |
| `oxforms-zhz.48` | MultiPage/Page intrinsic lane. | `.47` | Landed local MultiPage/Page lane: `Forms.MultiPage.1`, `Pages`, and `Page` expose collection/selection behavior, per-page child ownership via `Page.Controls`, selected page show/hide, pointer/keyboard page switching, `Change` order, selected-page focus scopes, accessibility, diagnostics, empty `.frm` materialization, and dashboard update. Serialized page-item persistence, nested page controls from `.frm`, per-page text-run rendering, style variants, exact source-event index args, and pixel parity remain oracle-gated blockers. |
| `oxforms-zhz.49` | Intrinsic completeness and fact-pack closure. | `.39`-`.48` | Cross-control FM20/MS-OFORMS fact-pack and dashboard reconciliation; every intrinsic ProgID has an implemented lane or precise blocker; full floor/evidence checks pass before W009 close. |

The older broad-control suffix plan below is retained as historical planning context only. Its
generic `.5`-`.19` rows are superseded by the live bead IDs above.

| Phase | Bead | Purpose | Depends on | Acceptance summary |
|---|---|---|---|---|
| 0 | `.1` | **Planning/review gate.** Reread the spec P4 + the four findings; ratify control sequence, the seven foundations, per-control non-claims; resolve the [open decisions](#open-decisions); split each control lane into ground+capture + implement; confirm dependency edges (glyph→F2, value→F7, list→F4, container→F3, repeat→F5, Image→F6). | epic parent | graph coherent; foundations + lanes scoped; impl beads blocked behind the gate; `br dep cycles` clean; W009 stays open. **Do not close W009 from the gate.** |
| F | `.2` | **F1 capability descriptor.** Authoritative per-kind/control capability surface in VBA; route reducer policy predicates through it. | `.1` | one declared capability source; existing 4-control behavior byte/ordering unchanged; adding a dummy kind requires an intentional capability entry; floor green. |
| F | `.3` | **F2 primitive-vocab + headless-sink closure.** Historical placeholder now implemented by `oxforms-zhz.17`: missing `OxSceneBuilder` recorders landed, the headless reference sink rasterizes the full representative vocabulary, and placeholder `DrawEdge` is retired. | `.1` | VBA-emitted bytes round-trip to the matching `Prim`; a non-rect prim perturbs `framebuffer_hash`; damage==full and immediate==applied-patch hold for a fixture with each new prim; floor green. |
| F | `.4` | **F7 uniform value/event helper pattern.** Document and test the CheckBox/TextBox pattern as the required implementation shape for new value controls. | `.1` | TextBox and CheckBox user/programmatic value semantics remain unchanged; the next value-control lane has an explicit recipe for dirty state, `Change`, and mutable helper readback; floor green. |
| A | `.5` | **ToggleButton lane** (cheapest new kind — boolean value, no grouping; latched pressed-face from CommandButton paint; no new primitive). | `.1`, `.2`, `.4` | oracle confirms `Value`-latched pressed appearance + CheckBox-equivalent ordering (or blocker); reuses the toggle spine; per-lane tests + native-dispatch fixture + floor green. |
| A | `.6` | **OptionButton lane** (boolean value + group mutual-exclusion via GroupName; radio state rendered through stable Scene primitives). Captures or precisely blocks cross-sibling Change/Click ordering on re-select plus arrow-key group navigation. | `.1`, `.2`, `.3`, `.4` | same-container mutual exclusion is proven locally; exact ordering/navigation parity is oracle-gated; group keyed by GroupName (parentage grouping routes to F3); per-lane tests + native-dispatch fixture + floor green. |
| B | `.7` | **F4 list-data + selection model** (design + research spike). Collection state + selection matrix + dropdown popup surface; probe the type-ahead/Escape key-interception risk once; design the list-data shape kept out of the kernel. | `.1` | facts/assumptions/blockers separated (W006 `0a0.10` style); dropdown-keyboard reachability recorded; ComboBox/ListBox impl lanes split with named captures; no reducer code yet. |
| B | `.8` | **ListBox lane** (list-data + single & multi-select modes `fmMultiSelect*`; Ctrl/Shift/Space selection; arrow/Shift-arrow nav). | `.1`, `.2`, `.3`, `.4`, `.7` | selection matrix conforms to the capture; multi-select state modeled per F4; per-lane tests + native-dispatch fixture + floor green; column/bound-column advanced bands as named sub-claims. |
| B | `.9` | **ComboBox lane** (ListBox list-data + edit field + dropdown popup; `DropButtonClick`, open/close, selection Change). | `.1`, `.2`, `.3`, `.4`, `.7`, `.8` | dropdown lifecycle + selection ordering conform to the capture (or precise blocker for key-intercepted parts); per-lane tests + native-dispatch fixture + floor green. |
| C | `.10` | **F6 image interop + `.frx` spike** (research). Evaluate the VBA↔Rust channel for binary image bytes ([[oxforms-wire-format-concern]]); implement `DecodeImage` PAL service trace + representative `.frx` indirection. | `.1`, `.3` | representative fixture bytes produce an opaque decode-handle trace; the materialized Image carries the `.frx` reference/handle to `DrawImage`; final binary wire decision and real pixel decode are recorded as follow-up depth rather than silently claimed. |
| C | `.11` | **Image lane** (`DrawImage` render + `PictureSizeMode`/alignment; static, non-focusable, click-only). | `.1`, `.2`, `.3`, `.10` | `Controls.Add "Forms.Image.1"` renders a deterministic placeholder from an opaque handle; size/alignment oracle and real decoded pixels remain later claims; headless sink rasterizes `DrawImage`; floor green. |
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
