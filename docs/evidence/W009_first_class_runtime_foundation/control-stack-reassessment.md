# W009 Control Stack Reassessment And DNA UI Consolidation

Status: `implemented-doc-gate`
Date: 2026-07-01
Bead: `oxforms-zhz.12`
Spec: `../../specs/CONTROL_STACK_STRATEGY.md`

This evidence note records the read-only sibling-repo review that shaped the W009
control-stack strategy. It is evidence for an architecture decision, not an
MSForms compatibility claim.

## Question

After the first TextBox and CheckBox hazard-gym work exposed the size of a
first-class controls implementation, should OxForms keep implementing its own
controls over Scene/PAL, or should it consolidate around the UI stacks chosen by
`DnaOneCalc` and `DnaTreeCalc`?

## Sources Read

| Source | Finding |
|---|---|
| `../../../../DnaOneCalc/docs/APP_IMPLEMENTATION_LAYOUT_AND_TDD.md` | DnaOneCalc uses a shared Rust app/UI core with Leptos, browser WASM, and a thin Tauri desktop shell. It deliberately owns a custom widget vocabulary and design-token layer rather than adopting a generic widget kit. |
| `../../../../DnaOneCalc/src/dnaonecalc-desktop/src/main.rs` | The desktop app is a thin Tauri wrapper; product behavior stays in the shared host crate. |
| `../../../../DnaTreeCalc/docs/ux/TECHNICAL.md` | DnaTreeCalc inherits the OneCalc Leptos/Tauri stack and extends it with canvas/vector primitives, virtualized lists, and a native shell for capabilities the browser cannot provide. |
| `../../../../DnaTreeCalc/docs/ux/SKINS.md` | DnaTreeCalc's strongest reusable idea is the skin architecture: typed skins, host-owned workspace state, typed intents, persisted per-skin state, shared state, theme tokens, and focus as a host contract. |
| `../../../../DnaTreeCalc/src/dnatreecalc-skin-framework/src/skin.rs` | The implementation exposes `WorkspaceSkin`, `SkinContext`, `RegisteredSkin`, erased factories, theme tokens, dispatch, selection, and mount lifecycle as code, not just prose. |
| `../../../../DnaTreeCalc/src/dnatreecalc-skin-framework/src/theme.rs` | `ThemeTokens` are concrete typed values exported as CSS custom properties; the idea can inform OxForms theme-token plumbing even though MSForms properties stay authoritative. |
| `../../../../DnaTreeCalc/docs/ux/THREE_FRONTENDS_PLAN.md` | The plan sketches `SurfaceHost`/`SurfaceBinder` ideas including `OxFormsBinder` and `DomBinder`; that pattern fits OxForms as a future binder concept, not as a replacement runtime. |

## Decision

OxForms keeps `OxRuntime` + OxVba + retained Scene + PAL as the canonical
runtime for MSForms compatibility.

DnaOneCalc and DnaTreeCalc are product UI hosts. Their Leptos/Tauri stack is a
good DNA application-shell direction, but OxForms has a different job: exact
MSForms object model, property side effects, event ordering, `.frm/.frx`
materialization, and VBA execution. Replacing OxForms controls with Leptos or DOM
widgets would trade the core compatibility target for a nicer visible widget
toolkit.

The adopted consolidation boundary is therefore:

- share concepts first: typed capabilities, theme tokens, host-owned focus,
  intent/effect discipline, accessibility helpers, and possible future binder
  vocabulary;
- keep crates separate until an interface is stable enough to avoid churn;
- treat a DOM/WebView binder as a future first-class backend only if it consumes
  the same OxRuntime state/effects and passes conformance against the Scene path.

## Accepted Seams

The reassessment turns "self-painted controls" into explicit subsystem seams:

| Seam | Immediate W009 pressure |
|---|---|
| `TextService` | TextBox caret stops, selection geometry, mouse hit testing, rapid input, paste/drop, local multiline/undo/composition-preedit behavior, and future native OS IME/dead-key and pixel multiline parity. |
| `ThemeTokens` / `ThemePainter` | Focus rings, disabled state, selected text/background, classic MSForms edge effects, future DNA-consistent previews. |
| `AccessibilityService` | Focus, roles, names, selection, value/state changes, list/table patterns, future UIA/MSAA provider work. |
| `RendererBackend` | Scene remains canonical; backends consume Scene. DOM/WebView, if built, must be a backend/binder, not a second reducer. |
| `HostServices` | Clipboard/DataObject, cursor, timers/caret blink/auto-repeat, system colors/metrics, DPI, image decode, traces, virtual clock. |
| `InteractionManager` | Tab maps, focus transfer, capture, hover/cursor routing, default/cancel, accelerators, validation vetoes, invalidation. |
| `CapabilityDescriptor` | Single policy source for focusability, tab stop, click/pressed visual, text/value editing, paste/drop, cursor, default/cancel, accelerator, list/container/image/timer needs. |

## Non-Claims

- This note does not claim TextBox, CheckBox, list, image, timer, accessibility,
  or performance parity.
- This note does not claim visual fidelity with MSForms; oracle-backed visual
  facts still belong in the relevant lanes.
- This note does not ban Leptos/Tauri or DOM forever. It bans them as a shortcut
  around the canonical OxForms runtime path.
- This note does not create a shared DNA UI crate.
- This note does not authorize editing sibling repos from OxForms.

## Follow-Up Hooks

- `oxforms-zhz.4`, `.10`, `.11`, and `.9` keep driving the TextBox/TextService
  pressure.
- `oxforms-zhz.5` keeps driving CheckBox focus/value/cursor/service pressure.
- `oxforms-zhz.6` must meet list/container/image/timer hazards through the named
  seams before broad controls consume them.
- `oxforms-zhz.8` must report performance through the canonical headless runner
  and visible Windows path.
- Any future DOM/WebView binder must get its own spike bead after phase-0 native
  and headless hazards pass.
