# CalcForms Spec Index

Restart direction (2026-11-04): [CalcVBA review](CALCVBA_REVIEW_20261104.md).
UserForms remain a VBA-first library responsibility. Use `calcvba-office` for
Office ingestion and `calcvba-engine` VM3 object sessions. Active crates use
`calcforms-*`, the library is `vba/calcforms/CalcForms.basproj`, and retained
Scene submission uses `CalcForms.Surface`. Historical evidence keeps its names.

This index is the reading order for CalcForms requirements, architecture, and
planning truth.

Run 8 pins [CalcVBA a4bf9792](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.75/README.md).
Required-outcome VM3 checks replace the qualified-default/Friend discrepancy
assertions and cover typed Nothing defaults and real portable Surface calls with
variable arguments. This supplies no forms measurement or full-facade credit.
Workbook language Load/Unload uses a non-exposed, host-owned lifecycle interface
in the composed application project; its implementations and helpers remain
private. Typed control/Core locals preserve internal calls. Chained-result type
loss remains [CalcVBA follow-up .115](handovers/HANDOVER_CalcVBA_chained_typed_dispatch.md).

Run 9 pins CalcVBA `8840f391676d0796870e9c486ba2ca6586c5b8c7`.
The adapter now uses non-creating default reset and explicit host release/draining.
Accepted Unload raises Terminate once per loaded episode, matching the
[held-reference native observations](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.95/README.md).
The private unload notification also checks its compiler-resolved event id,
so an application event with an identical payload cannot reset the default slot
([`.95.1` regression](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.95/event-identity.md)).
The `.95` residual scope remains explicit; this supplies no headline layout credit.

Run 9 also adds a [genuine planner workbook](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.126/README.md)
with 208 matching state/event/error fields for spin, scroll, toggle and tab controls.
Public range assignments now reject invalid values with error 380. The
[IntegralHeight report](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.118/README.md)
remains partial at 48 pass / 22 fail; the Boolean flag is public, while Height
normalization and later TopIndex behavior stay open. The source census is 842
public declarations; canonical full-library row status remains red and unchanged.

## Core Spec

Run 9's [current replay](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.130/forms-parity.md)
reports **1,203 pass / 415 fail; 346 missing measurements**. Thirty-two greeter
fields now use original-handler setter/event/selection/lifecycle observations.
The latest production behavior/input/keyboard replay retains all earlier native facts.
Frame background MouseDown now exposes and raises the public four-scalar event;
both native hit-testing observations match, with child routing preserved.
Root UserForm MouseDown (.132) now exposes and raises the canonical four-scalar event
when disabled controls reject pointer input, matching native hit fallthrough.
The [font replay](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.101/final/forms-parity.md)
was 1,169/449 with 378 missing measurements. Native font sizing
and retained DirectWrite raster are bounded to the recorded contexts; 17 gains
and 14 regressions stay explicit. Full font/DPI parity remains `.101` work.

The original order-entry BeforeUpdate veto, accepted Tab, Escape, retained
Hide/Show and replacement-default reload now match all 308 captured fields.
TabIndex sorting stays within each container, and host Show attaches the current
compiler-owned default before making it visible. Geometry, scrolling and broader
control/focus/lifetime behavior remain open in `.105/.105.1` and `.95`.

Run 8's [replay](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.122/forms-parity.md)
reports **1,166 pass / 452 fail; 378 missing measurements**. The
[rendering correction](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.114/README.md)
makes Frame caption gaps and four tab header size rows match at both scales. Independent caption cells
qualify four former unknowns and eight new advance checks. Equal-method replay
shows seven net rendering gains, retaining eighteen smaller ink regressions in
`.101`. Pixels remain a coarse guard and full W010/font parity is unclaimed.

1. [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](FORMS_LIBRARY_SPEC_AND_PLAN.md) - current
   top-level spec, architecture, and work plan for the VBA-first MSForms-compatible
   forms library.

## Focused Specs

November layout work: [`LAYOUT_COMPARISON.md`](specs/LAYOUT_COMPARISON.md)
defines FORMS PARITY reports at 100%/150%, layout/text/spacing/colour/behaviour
measurements, failed missing coverage, per-window capture and owned hidden
Excel reuse. Pixels remain a coarse regression guard.
Public native OLE drawing now supplies replayable baselines, literal line offsets
and horizontal character-cell clipping, including nested text in local control
coordinates; omitted ListBox output remains failed coverage.
Run 7's [behaviour report](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.111/README.md)
has 1,089 passes / 521 failures, including 428 missing measurements. Independent
event, traversal, key and overflow observations precede 34 measured corrections.
The subsequent [tab drawing qualification](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.110/README.md)
fills four further unknown rows, all failures: the latest report has 1,089 passes /
521 failures and 424 missing measurements. Native header construction rectangles
must have caption-paired public drawing strokes and qualified-window confirmation.
The latest [Frame caption-gap report](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.113/README.md)
has **1,089 passes / 521 failures, including 422 missing measurements**. The
horizontal border interruption requires a caption exclusion, both etched border
strokes and confirmation of both boundaries in the same saved native window.

The real data-entry workbook now runs original qualified MSForms source through
the Office importer and referenced source library. Native State/Trace match all
ten measured validation/selection/save/cancel steps at both scales. Initial Show
focus and broader input, lifecycle and geometry remain open in `.105`.
See [the measured scope](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.105.1/README.md).

1. [`specs/INPUT_INTERACTION_MODEL.md`](specs/INPUT_INTERACTION_MODEL.md) -
   W005 input/event architecture surface for normalized `UiEvent`, interaction
   `FormState`, effects, ordering, trace/replay, and the fact/model homes for
   event signatures, coordinates, and lifecycle/pump semantics.
2. [`specs/FM20_EVENT_FACTS.md`](specs/FM20_EVENT_FACTS.md) - W005
   FM20/MSForms event signature and argument fact matrix, with public
   type-library metadata, public documentation anchors, W005 probe subset
   status, mutation semantics, coordinate argument notes, and explicit unknowns.
3. [`specs/COORDINATE_MODEL.md`](specs/COORDINATE_MODEL.md) - W005
   coordinate-space model and calibration procedure for PAL input, reducer
   routing, Scene rendering, MSForms event arguments, screenshots,
   trace/replay, and comparison artifacts.
4. [`specs/LIFECYCLE_PUMP_MODEL.md`](specs/LIFECYCLE_PUMP_MODEL.md) - W005
   form lifecycle, modal/modeless pump, activation, close/query/hide/unload,
   terminate, reentrancy, and downstream oracle/smoke/reducer guidance.
5. [`specs/TRACE_REPLAY_SCHEMA.md`](specs/TRACE_REPLAY_SCHEMA.md) - W005
   trace/replay artifact schema for normalized input, coordinate tags, reducer
   transitions, effects, VBA dispatches, lifecycle/pump rows, invalidation,
   display-list/render references, environment metadata, ordering, nesting,
   sample artifacts, and validator checks.
6. [`specs/RUNTIME_ACCESSIBILITY_MODEL.md`](specs/RUNTIME_ACCESSIBILITY_MODEL.md) -
   W006 design-only gate for future runtime accessibility/UIA/MSAA semantics,
   separating product-required provider behavior from W005 diagnostics-only
   top-level metadata probes.
7. [`specs/RENDERING_ARCHITECTURE.md`](specs/RENDERING_ARCHITECTURE.md) - the
   rendering + VBA control-rendering architecture: immediate-mode VBA authoring
   over a control-agnostic keyed retained primitive tree (the Scene) in
   `calcforms-pal`, the cross-boundary patch protocol, invalidation/damage, text
   metrics, determinism invariants, the D7 amendment, the desktop backend stack
   (§15), and the render-invocation/frame model (§16) — the Repaint-vs-Re-render
   split, runtime/backend/bootstrap ownership, the pull/lazy frame loop, and the
   resident-Scene seam.
8. [`specs/CONTROL_STACK_STRATEGY.md`](specs/CONTROL_STACK_STRATEGY.md) -
   W009 control-stack reassessment: CalcForms keeps `OxRuntime` + CalcVBA + Scene/PAL
   as the canonical MSForms runtime, borrows sibling DNA UI stack concepts only
   through explicit service seams, and gates any future DOM/WebView binder behind
   the same runtime contract.
9. [`specs/FM20_TYPELIB_FACT_SCHEMA.md`](specs/FM20_TYPELIB_FACT_SCHEMA.md) -
   W010's deterministic full FM20/referenced-typelib fact schema, pinned source
   identities, dual-interface and stdole closure rules, stable identities,
   descriptor/flag/default encoding, W005 structural reconciliation, and
   validator contract.
10. [`specs/MSFORMS_PERSISTENCE_MODEL.md`](specs/MSFORMS_PERSISTENCE_MODEL.md) -
    W010's deterministic MS-OFORMS binary-persistence/default fact model plus
    the established independent `.frm`/`.frx` export-fact contract: genuine
    Excel/VBE export evidence, strict Office/VB6/legacy profile separation,
    MS-OVBA DesignerProperties, MS-VBAL class-header/code boundary, opaque FRX
    prefix and embedded-CFB inventory, 98 property mappings, unknown policy,
    and codec/runtime/API non-claims.
11. [`specs/MSFORMS_OBJECT_MODEL_PARITY.md`](specs/MSFORMS_OBJECT_MODEL_PARITY.md) -
    W010's deterministic raw-contract/current-overlay parity ledger and the
    versioned, ledger-linked live Excel/MSForms member-oracle contract for
    properties, methods, defaults, coercions/errors, events, screenshots, and
    preserved Office exports. The representative `.5` canonical capture is
    replay-valid and supplies the first committed rows under that contract;
    exhaustive full-library behavior remains later W010 work.
12. [`specs/MSFORMS_FACADE_CONTRACT.md`](specs/MSFORMS_FACADE_CONTRACT.md) -
    unchanged-project target, MSForms identity and exact type/member mapping,
    per-control site and host-event obligations, hidden accessor probes, ProgIDs,
    and one non-public runtime bridge. `.6` acceptance remains blocked by the
    recorded CalcVBA and live Office observations.

## Source References

1. [`SOURCE_REFERENCES.md`](SOURCE_REFERENCES.md) - current Foundation MS-OFORMS
   pointer, adjacent MS-OVBA pointer, and the pinned CalcVBA development baseline
   policy.

## Planned Splits
Completed splits are listed above. As work grows, split the top-level document
into additional focused specs and keep them reachable from this index:

- production `.frm` / `.frx` parser, serializer, resource codec, and round-trip
  behavior (the independent export-fact and MS-OFORMS contracts are now
  specified above, while implementation remains later W010 work);
- reducer state model and event/effect semantics;
- retained-Scene rendering and PAL contract;
- trace/replay and evidence artifacts;
- Excel-host extension controls, starting with `RefEdit`;
- designer.

The top-level spec remains authoritative until a split document exists and is
linked here.

Run 8 input correction: ListBox PageDown and TopIndex share a measured viewport;
invalid/empty and resize/repeat behavior is retained in
[.112 evidence](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.112/README.md).
Runtime Controls.Add appends TabIndex, while FRM omitted values restore zero.
The first modeless Show establishes reducer focus; the real order-entry form
requires immediate default-button routing from NameInput. Broader focus and
scrolling behavior remains unmeasured.

TabStrip/MultiPage mouse events carry the native Index argument and preserve
pre-change MouseDown / post-change MouseUp Value timing. Empty MultiPage bodies
forward through Page to their owner. See [.108 evidence](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.108/README.md).

[The genuine inventory workbook](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.119/README.md)
runs original handlers and compares every State, Trace and focus field. Run 8's
316 matching / 4 failing fields remain archived. Run 9's
[Escape correction](evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.123/README.md)
requires all **320 fields** to match, including Cancel focus after Escape and
reshow. Dirty text rollback, Change and Exit/Enter/Click order match five native
cases at both scales. Native preparation-update differences remain `.124`.
