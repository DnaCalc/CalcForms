# OxForms Control Stack Strategy

Status: `draft_implementation_authority`
Date: 2026-07-01
Workset: `W009_intrinsic_control_breadth`
Bead: `oxforms-zhz.12`; amended by `oxforms-zhz.14` and `oxforms-zhz.15`

This note records the W009 control-stack reassessment after the first
TextBox/CheckBox hazard-gym work and the sibling DNA UI stack review. It does
not replace the MSForms compatibility target. It pins the implementation
strategy that future control lanes must follow before broad control breadth
resumes.

## Decision

OxForms keeps one canonical MSForms runtime path:

```text
input or host event
  -> OxRuntime
  -> OxVba form/document facade
  -> VBA OxReducer and control object model
  -> explicit host-service effects
  -> retained Scene patches
  -> headless reference renderer or Windows PAL backend
```

The core runtime does not migrate to Leptos, Tauri, native OS widgets, or a DOM
control library. Those stacks can host DNA product applications, previews, or
future binders, but they do not own OxForms control semantics, event ordering,
object-model state, `.frm/.frx` materialization, or MSForms parity claims.

The chosen direction is a hybrid control engine:

- OxForms owns MSForms behavior: object model, default members, properties,
  events, focus, tab order, validation, reentrancy, modal/modeless lifecycle,
  persistence, and trace/replay.
- Proven libraries or host APIs may own hard primitive services behind explicit
  seams: text shaping/edit geometry, raster backends, layout helpers,
  accessibility providers, timers, clipboard, image decode, cursor application,
  metrics, DPI, and theme token plumbing.
- A subsystem may move from VBA to Rust only behind the same canonical contract,
  after profiling or correctness evidence shows that migration is the best
  long-term architecture.

## Canonical Runtime/Event-Turn Contract

The concrete W009 contract is named in code as:

- `RuntimeInput` — one normalized host input turn entering `OxRuntime`;
- `OxRuntime::dispatch_event_turn` — the only Rust-side semantic dispatch entry
  for headless and Windows/bootstrap paths;
- `RuntimeEventTurn` — the ordered reducer effect log, explicit host-service
  effect trace, stable action label, and same-turn repaint/readback marker for
  that turn.

One event turn is complete only after this order is preserved:

1. The host/backend queues or receives one input and maps it to `RuntimeInput`.
2. `OxRuntime` dispatches to the OxVba form-document facade
   (`Dispatch`, `DispatchKey`, `DispatchChar`, or `DispatchDrop`).
3. VBA `OxReducer` and the concrete control object model mutate state and raise
   events; any host-service interaction is recorded as a named trace effect.
4. The returned `RuntimeEventTurn` tells the caller whether the reducer already
   repainted in the same turn. If not, and the caller's repaint policy requires a
   fresh frame, the caller drives `OxRuntime::render`, which causes VBA
   self-rendering through `OxForms.Surface` and applies retained `Scene` patches.
5. The caller may read back VBA object-model state and resident `Scene`
   revision/token in the same turn, before accepting the next input.

The deterministic headless runner and the Windows bootstrap both use this same
contract. The headless path adds queue draining, a virtual clock, and JSONL rows;
the Windows path adds PAL event normalization, live clipboard reads for Ctrl+V,
and backend repaint. Neither path owns control state, event ordering, or an
alternate renderer. The lower-level `Dispatch*` facade helpers inside
`OxRuntime` are private implementation details of this contract, not a public
backend/test-runner API.

`HostServices` starts here as an explicit effect trace attached to the turn
(`clipboard.set_text:<len>` for paste). Later service beads extend that trace
shape for cursor, timers, metrics/colors, DPI, image decode, and drag/drop
without bypassing `OxRuntime`.

`oxforms-zhz.15` promotes that trace into a real runtime service object:

- `HostServices::headless()` provides deterministic service stubs for tests and
  profiling.
- `HostServices::windows(reader)` is the visible/bootstrap implementation shape;
  the Windows bootstrap injects the live clipboard reader into this seam.
- Runtime service turns cover clipboard reads/sets, DataObject text snapshots,
  cursor requests, virtual `caret_blink` and `auto_repeat` timer slots, system
  metrics/colors, DPI changes, image-decode handle traces, and drag/drop text.
- Virtual timer ticks (`RuntimeInput::AdvanceTime`) pass through `OxRuntime`,
  not the headless runner alone.

This is still a representative spine. Cursor application, native timer
registration, image decoding, and rich DataObject formats can be filled in by
later beads behind the same API.

## Initial-Development Rework Doctrine

OxForms is still in initial development. Internal draft APIs, temporary helper
objects, runner/bootstrap shapes, fixture formats, documentation wording, and
test scaffolds have no compatibility or legacy-preservation promise. The
compatibility target is MSForms/FM20 observed behavior plus supported VBA
semantics, not an earlier OxForms implementation.

W009 should therefore optimize for the correct representative architecture:

- delete, rename, replace, or quarantine temporary scaffolds when they conflict
  with the ideal `OxRuntime`/OxVba/Scene/PAL path;
- keep only one semantic path for representative controls;
- use the representative implementation to evaluate the strategy before broad
  control breadth resumes;
- record obsolete surfaces as historical notes only when they help explain
  provenance, not because later code must preserve them;
- prefer rework now over carrying compatibility shims into twenty later control
  implementations.

The W009 rework bead set (`oxforms-zhz.13` through `oxforms-zhz.33`) is the live
execution graph for this doctrine.

## Sibling Stack Findings

The sibling DNA applications are useful comparison points, not replacement
targets.

| Repo | Chosen UI stack | OxForms takeaway |
|---|---|---|
| `DnaOneCalc` | Shared Rust app/UI core in Leptos, browser WASM, and a thin Tauri desktop shell; custom product widgets and CSS custom properties. | Reuse the thin-host-wrapper discipline and design-token idea for DNA product shells. Do not replace OxForms' MSForms runtime with Leptos widgets. |
| `DnaTreeCalc` | Same Leptos/Tauri baseline, plus a typed skin framework: `WorkspaceSkin`, `SkinContext`, manifest/capabilities, theme tokens, accessibility helpers, typed intents/deltas, and headless/session concepts. | Borrow the contract shape: typed capability surfaces, host-owned focus, typed intents/effects, theme/accessibility tokens, and possible future binder vocabulary. |

Read-only evidence:

- `../../../../DnaOneCalc/docs/APP_IMPLEMENTATION_LAYOUT_AND_TDD.md`
- `../../../../DnaTreeCalc/docs/ux/TECHNICAL.md`
- `../../../../DnaTreeCalc/docs/ux/SKINS.md`
- `../../../../DnaTreeCalc/src/dnatreecalc-skin-framework/src/skin.rs`
- `../../../../DnaTreeCalc/src/dnatreecalc-skin-framework/src/theme.rs`
- `../../../../DnaTreeCalc/docs/ux/THREE_FRONTENDS_PLAN.md`

## Internal Service Seams

These are OxForms-owned seams. They are not new alternate object models.

| Seam | Owner | Contract |
|---|---|---|
| `TextService` | PAL/host service behind OxRuntime | Shape text, return caret stops, map hit-test x to character offset, support selection geometry, and leave room for IME/dead keys, multiline, undo/redo, and grapheme-aware editing. VBA TextBox owns value, selection state, MSForms properties, and event order. |
| `ThemeTokens` / `ThemePainter` | OxForms runtime policy plus PAL drawing primitives | Map MSForms properties (`BackColor`, `ForeColor`, `SpecialEffect`, `BorderStyle`, `Enabled`, focus state, selection state) onto DNA-style tokens and Scene primitives. Tokens are an implementation aid; MSForms properties stay authoritative. |
| `AccessibilityService` | Runtime exposes roles/states; PAL/backend provides provider integration | Publish control roles, names, values, focus, disabled/hidden state, selection state, table/list patterns, and focus events. It follows `RUNTIME_ACCESSIBILITY_MODEL.md` and can borrow DnaTreeCalc helper patterns. |
| `RendererBackend` | `oxforms-pal` | Keep Scene as the canonical primitive contract. The Windows backend and headless renderer consume Scene snapshots. Any future DOM/WebView renderer consumes the same semantic output and must not bypass OxRuntime or the VBA reducer. |
| `HostServices` | PAL adapters and headless runner stubs | `HostServices` owns clipboard/DataObject, cursor requests, timers, caret blink, auto-repeat, system colors/metrics, DPI, image-decode handle traces, drag/drop traces, and virtual-clock service behavior behind `OxRuntime`. |
| `InteractionManager` | VBA reducer plus small cached indexes | Own focus owner, capture owner, hover/cursor target, tab maps, default/cancel buttons, accelerators, validation transfer, invalidation state, and focused-control hide/disable/delete behavior. |
| `CapabilityDescriptor` | VBA control policy source | Declare control capabilities once per kind/control: focusable, default tab stop, click, pressed visual, text editing, value editing, paste/drop, cursor, default/cancel, accelerator, list/container/image/timer needs. |

The headless runner and Windows backend must both drive these seams through
`OxRuntime`. A headless proof that bypasses `OxRuntime`, the VBA reducer, host
services, Scene patches, or VBA state readback does not count as W009
conformance evidence.

## DNA Consolidation Rules

Allowed consolidation:

- Reuse DnaOneCalc's thin-host-shell discipline for future preview/showcase hosts.
- Reuse DnaTreeCalc-style typed theme tokens where they help keep skins/themes
  coherent, while mapping back to MSForms property semantics.
- Reuse DnaTreeCalc-style manifest/capability/intent vocabulary when defining
  future host/binder contracts.
- Reuse accessibility helper patterns if they can be expressed through OxForms'
  roles/states/events rather than DOM-only assumptions.
- Keep a future `SurfaceBinder` idea alive as an interface concept: `SceneBinder`
  is canonical now; possible future `DomBinder`, `OxFormsBinder`, or `CliBinder`
  consume the same runtime state/effects.

Disallowed consolidation:

- Do not make Leptos components the primary implementation of MSForms controls.
- Do not use Tauri/WebView as the core OxForms acceptance backend.
- Do not create a second object model for DOM controls, product-shell widgets, or
  a showcase UI.
- Do not accept visual fidelity from a skinnable library as a substitute for
  MSForms behavior, event order, property side effects, or `.frm/.frx` facts.
- Do not keep a convenience bridge alive after it stops being the best long-term
  architecture.

## DOM/WebView Feasibility Gate

A DOM/WebView binder is allowed only as a later feasibility spike, not as a W009
phase-0 escape hatch. The spike may start only after the native/headless hazard
gym proves TextBox and CheckBox through the canonical path.

Minimum acceptance for a DOM/WebView binder spike:

- It consumes `OxRuntime` output and host-service effects; it does not own
  control state or event ordering.
- The same scripted headless input sequence produces the same VBA state, event
  log, effect log, focus owner, and value changes as the Scene path.
- Divergent visuals are recorded as backend tolerance, not semantic behavior.
- The spike is deleted, quarantined as non-pattern test infrastructure, or
  promoted as a first-class backend with explicit tests. It must not remain as a
  hidden fallback.

## W009 Implementation Impact

W009 phase 0 remains the hazard gym:

- TextBox for editing, caret, selection, hit testing, clipboard/drop, and repaint.
- CheckBox for focus, keyboard value editing, disabled/tab-stop/cursor, and event
  ordering.
- List/container/image/timer representative spikes before broad controls.
- `.frm/.frx` materialization and reentrancy/modal/lifecycle hazards.
- Perf numbers for input-to-state, input-to-render, burst typing, tab traversal,
  cursor routing, hit testing, timer jitter, and 10/50/100-control forms.
- Full-surface showcase as a conformance dashboard, not a separate product UI.

Broad control lanes must depend on this foundation rather than spending control
after control rediscovering TextBox-class hazards.

## Non-Claims

- This note does not claim pixel-perfect MSForms visual parity.
- This note does not claim Leptos/Tauri, browser DOM, or native OS controls are
  rejected forever. It rejects them as the core MSForms runtime implementation.
- This note does not add a cross-repo shared crate. Shared crates can be proposed
  only after the OxForms service seams and sibling DNA APIs stabilize enough to
  avoid dependency churn.
- This note does not close any TextBox, CheckBox, accessibility, image, list,
  timer, or performance lane by prose.
