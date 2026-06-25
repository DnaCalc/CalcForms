# OxForms Spec Index

This index is the reading order for OxForms requirements, architecture, and
planning truth.

## Core Spec

1. [`FORMS_LIBRARY_SPEC_AND_PLAN.md`](FORMS_LIBRARY_SPEC_AND_PLAN.md) - current
   top-level spec, architecture, and work plan for the VBA-first MSForms-compatible
   forms library.

## Focused Specs

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
   `oxforms-pal`, the cross-boundary patch protocol, invalidation/damage, text
   metrics, determinism invariants, the D7 amendment, the desktop backend stack
   (§15), and the render-invocation/frame model (§16) — the Repaint-vs-Re-render
   split, runtime/backend/bootstrap ownership, the pull/lazy frame loop, and the
   resident-Scene seam.

## Source References

1. [`SOURCE_REFERENCES.md`](SOURCE_REFERENCES.md) - current Foundation MS-OFORMS
   pointer, adjacent MS-OVBA pointer, and the pinned OxVba development baseline
   policy.

## Planned Splits
Completed splits are listed above. As work grows, split the top-level document
into additional focused specs and keep them reachable from this index:

- object model and generated fact pack;
- `.frm` / `.frx` persistence;
- reducer state model and event/effect semantics;
- retained-Scene rendering and PAL contract;
- trace/replay and evidence artifacts;
- Excel-host extension controls, starting with `RefEdit`;
- designer.

The top-level spec remains authoritative until a split document exists and is
linked here.
