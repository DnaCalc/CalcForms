# OxForms Runtime Accessibility Model

Status: W006 design-only surface, updated by W009 semantic snapshot seam `oxforms-zhz.21`.
Owning workset:
[`W006_control_implementation_rollout`](../worksets/W006_control_implementation_rollout.md).

This document defines the gate for future runtime accessibility semantics for
OxForms controls. It does not implement UI Automation, MSAA, or any other
accessibility provider. The current W006 runtime still makes no accessibility
parity claim.

## 1. Purpose

Runtime accessibility is a product feature only when a scoped product
requirement needs it, for example assistive-technology support, automated
accessibility testing, host compliance, or compatibility with a named client API.
It must not appear by accident because a diagnostics probe can see a top-level
window.

If a future bead implements accessibility behavior, it must name:

- target user or client need;
- platform API target, such as Windows UI Automation, MSAA, or a host-specific
  accessibility API adapter or provider integration;
- supported form/control subset;
- source of compatibility evidence when MSForms parity is claimed;
- provider ownership across core state, PAL/window adapters, and host
  integrations;
- tests and evidence that validate the runtime semantic tree, not only pixels or
  top-level window metadata.

## 2. Non-goals

Current W006 does not:

- expose an OxForms runtime accessibility provider;
- claim UIA, MSAA, assistive-technology, or Office accessibility parity;
- infer control semantics from screenshots, top-level window enumeration,
  window class names, UIA control types, UIA supported patterns, or child counts;
- treat W005 `minifb` probe controls as accessible controls;
- use W005 UIA metadata as FM20 behavior truth;
- replace reducer state, event facts, trace/replay, or live MSForms event logs
  with accessibility inspection;
- require MSAA traversal for W005 or W006 diagnostics.

## 3. Allowed Evidence Classes

Runtime accessibility claims need evidence that is specific to the claimed
surface.

Allowed evidence for future implementation beads:

- public UIA or MSAA API documentation and conformance rules;
- public FM20 type-library metadata or Microsoft documentation where it actually
  describes accessibility-relevant public surface;
- black-box Office/MSForms accessibility observations captured with tool,
  Windows, Office, DPI/theme, and fixture provenance;
- OxForms unit tests for semantic snapshots derived from `FormState` and control
  definitions;
- adapter tests that query the implemented provider through public UIA/MSAA
  APIs;
- trace/evidence artifacts that record accessibility tree changes, focus, names,
  values, states, actions, and bounding rectangles for the implemented subset.

Rejected as standalone runtime semantics evidence:

- W003/W004/W005 screenshots or crop pixels;
- W005 visible-smoke frame artifacts;
- top-level Win32 window metadata;
- W005 optional UIA metadata probe output;
- foreground/focus diagnostics around input delivery;
- injected coordinate scripts;
- existence or absence of UIA children in Office or `minifb` windows without a
  scoped accessibility fixture and runtime provider test.

## 4. Semantic Source Of Truth

Accessible control semantics, if implemented, must be derived from OxForms
runtime state, not from the rendered bitmap or a platform inspection echo.

The durable source model is:

```text
loaded form/control definitions
  + reducer-owned FormState
  + layout/coordinate model
  + focus/capture/lifecycle state
  -> accessibility semantic snapshot
  -> platform provider adapter
  -> public UIA/MSAA client query
```

The semantic snapshot should be value-shaped and serializable enough for tests.
It may include:

- stable form/control identifiers;
- parent/child relationships matching the logical control tree;
- role/control type selected by explicit mapping;
- name and description sources, such as caption, label relationship, or
  documented property;
- value and state, including checked, pressed, focused, enabled, visible,
  read-only, selected, expanded, or invalid where the scoped control supports
  them;
- supported actions or patterns;
- bounding rectangles with coordinate-space provenance from
  [`COORDINATE_MODEL.md`](COORDINATE_MODEL.md);
- focus and selection relationship to the reducer state;
- provenance fields that distinguish implemented behavior, public facts,
  assumptions, unknowns, and blockers.

Core `FormState` must not store platform UIA elements, MSAA `IAccessible`
objects, window handles, COM automation objects, or assistive-technology client
objects. Platform providers live behind adapter or host capability boundaries.

## 5. Implementation Path

Future runtime accessibility work must proceed through small beads.

1. Requirements gate: name the product need, platform/API target, control
   subset, and compatibility claim level. If the need is only diagnostics, keep
   it outside runtime architecture.
2. Semantic snapshot: add a host-neutral value-shaped tree derived from
   canonical OxForms state for the named controls. Include unit tests for names,
   roles, states, values, focus, and bounds.
3. Provider adapter: map the snapshot to the selected public platform API. On
   Windows, UIA should be considered the primary modern provider surface; MSAA
   should be added only when a named product requirement or compatibility target
   requires it.
4. Runtime notifications: emit focus, structure, property, value, and action
   notifications only after the snapshot and provider mapping are tested.
5. Evidence: query the implemented provider through public APIs and record
   artifacts that prove the claimed subset. If MSForms parity is claimed, capture
   a comparable MSForms oracle with the same fixture shape and environment
   metadata.

No implementation bead may skip directly from W005 diagnostics to provider
behavior. W005 UIA metadata can help debug top-level window discoverability, but
it cannot define OxForms control roles, names, values, actions, or event
ordering.

## 6. Current W006 Decision

`oxforms-0a0.7` is design-only. No runtime accessibility behavior is attempted,
so no UIA/MSAA provider tests or live accessibility oracle captures are required
for this bead. The current checked-in W005 accessibility metadata tool is
diagnostics infrastructure only and has no committed output artifacts in
`docs/evidence/`.

The next accessibility bead, if one becomes product-required, should start from
this document and create a scoped runtime/evidence plan before touching control
behavior.

## 7. W009 Semantic Snapshot Update

`oxforms-zhz.21` implements step 2 of the path above: a host-neutral semantic
snapshot derived from canonical OxForms state.

Implemented scope:

- `IOxControl` projection members for role, name, value, selected state,
  selection start/length/text, and supported patterns;
- `OxAccessibilityService` rows for the current `UserForm`, `Label`,
  `TextBox`, `CommandButton`, and `CheckBox` subset;
- focus state from `OxInteractionManager`, not from platform focus APIs;
- TextBox value and selection state from the VBA control's authoritative
  object model;
- headless JSONL trace rows carrying the current accessibility snapshot after
  each runtime input turn.

Still out of scope:

- Windows UIA provider implementation;
- MSAA provider implementation;
- provider focus/value/selection notifications;
- platform client tests through public UIA/MSAA APIs;
- MSForms accessibility parity claims or oracle captures.

The current snapshot is therefore valid evidence that OxForms has a serializable
runtime accessibility data model for representative controls. It is not evidence
that the runtime is visible to assistive technology or compatible with any
specific platform accessibility API. Windows UIA/MSAA provider wiring is tracked
as `oxforms-zhz.35`.
