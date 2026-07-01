# W009 First-Class Runtime Foundation Evidence

Status: `SEED`
Workset: `W009_intrinsic_control_breadth`
Epic: `oxforms-zhz`
Active slice: `oxforms-zhz.4`
Input-turn bugfix slice: `oxforms-zhz.10`
Geometry/drag slice: `oxforms-zhz.11`
CheckBox hardening slice: `oxforms-zhz.5`
Control-stack gate: `oxforms-zhz.12`
Ideal architecture rework graph: `oxforms-zhz.13` through `oxforms-zhz.33`

This directory accumulates evidence for the phase-0 hazard gym that must pass before
broad W009 control breadth resumes. The first committed slice creates the reusable
headless runner over the real `OxRuntime` + `OxForms.Surface` path; later slices add
oracle captures, conformance matrices, visual proofs, and perf reports.

## Current Proof

`crates/oxforms-headless-runner` now provides a deterministic test/profiling harness
that:

- attaches a VBA form-document through `OxRuntime`;
- registers the normal `OxForms.Surface` seam and captures resident `Scene` snapshots;
- dispatches scripted mouse, key, character, paste, drop, tick, and render actions;
- supports one-action and all-action queue draining;
- applies a repaint policy without introducing a second reducer or renderer;
- reads back VBA properties for assertions;
- emits JSONL trace rows with action, effect log, Scene revision/token, node count,
  virtual time, and dispatch/render timings.

`oxforms-zhz.2` extends the same path with the first interaction-manager scaffold:

- `OxControlCore` now exposes an intrinsic capability descriptor for the implemented
  controls (`focusable`, tab stop, click, pressed visual, text/paste/value/toggle,
  accelerator/default/cancel eligibility, and mouse pointer code);
- concrete `IOxControl` policy getters delegate to that descriptor where the answer is
  static, while dynamic `CommandButton.Default`/`Cancel` still live on the button;
- `UserForm` now has a monotonic interaction revision, separate from render invalidation;
- `OxReducer` builds lazy cached maps for tab next/previous, first/last tab stop,
  default/cancel buttons, Alt accelerators, hover target, cursor target, and cursor code;
- the full-surface showcase exposes `CapabilityCatalog`, `InteractionIndexSummary`, and
  `InteractionIndexBuildCount` as conformance-dashboard diagnostics.

`oxforms-zhz.4` upgrades the single-line TextBox from append-only input to a first-class
editing slice:

- `TextBox` owns `SelStart`, `SelLength`, `SelText`, `HideSelection`, caret/focus state,
  selection replacement, Backspace/Delete, Home/End, Left, Ctrl+A, copy, cut, paste, and drop;
- the reducer repaints dirty key/focus turns immediately, so caret movement, selection changes,
  deletion, paste, cut, and focus loss are visible in the same dispatch turn;
- the reducer clipboard stub now supports Ctrl+C/Ctrl+X alongside Ctrl+V;
- the TextBox scene node emits deterministic caret and selection `FillRect` primitives in the
  canonical `OxRuntime` -> VBA reducer -> `OxForms.Surface` path;
- the full-surface showcase catalog names the current TextBox editing surface instead of treating
  caret/focus adornment as pending.

`oxforms-zhz.10` addresses the first visible quick-typing feedback on that slice:

- the bootstrap no longer reads the OS clipboard for every keydown; it reads it only for Ctrl+V;
- the bootstrap does not issue a second render when the VBA reducer already emitted a `repaint`
  effect and updated the resident Scene;
- ordinary printable `KeyDown`/`KeyUp` refreshes are deferred around `CharacterInput`, reducing
  visible-window churn during rapid typing;
- the headless runner now has a rapid `abcdef` plus repeated-Backspace regression test.

`oxforms-zhz.11` makes the TextBox selection/caret failures headless-reproducible and fixes the
geometry path:

- `MeasureBatch` now returns shaped-run caret stops to VBA (`CaretStopsMilliPtCsv`), and TextBox
  caret placement, selection rectangles, and mouse hit-testing consume those stops;
- selected TextBox text is recolored by a clipped child Scene node that redraws the same shaped
  text run in the selection foreground over an opaque selection background;
- `MouseMove` now routes through bootstrap, `OxRuntime`, `OxReducer`, and `IOxControl`; capture
  routes drag moves back to the pressed TextBox;
- the headless runner has first-class `MouseMove` script/trace rows and a drag-selection test.

`oxforms-zhz.5` now has a headless runner regression for the current CheckBox keyboard path:

- Tab traversal moves focus from the startup TextBox through the current tab sequence to the
  CheckBox;
- Space activation toggles the focused CheckBox through the reducer's `TryKeyboardActivate` path;
- the test asserts value-first event order (`Change`, `Click`, `KeyDown`, then `KeyUp`) and records
  the Space down/up rows in the JSONL headless trace.

`oxforms-zhz.12` records the control-stack reassessment after the sibling DNA UI stack review:

- `docs/specs/CONTROL_STACK_STRATEGY.md` keeps `OxRuntime` + OxVba + retained Scene + PAL as the
  canonical MSForms runtime path;
- `control-stack-reassessment.md` records that DnaOneCalc and DnaTreeCalc use Leptos/WASM/Tauri
  product shells, while OxForms must retain its MSForms object-model/runtime role;
- the accepted consolidation boundary is concept-level and seam-level reuse: `TextService`,
  `ThemeTokens`/`ThemePainter`, `AccessibilityService`, `RendererBackend`, `HostServices`,
  `InteractionManager`, and `CapabilityDescriptor`;
- a DOM/WebView binder remains possible only as a later first-class backend/binder that consumes
  the same `OxRuntime` state/effects and passes conformance against the Scene path.

`oxforms-zhz.13` through `oxforms-zhz.33` define the execution graph for reworking W009 into the
ideal architecture. The graph is intentionally not a legacy-preservation plan: OxForms is still in
initial development, so internal draft APIs, temporary helper shapes, runner/bootstrap contracts,
fixture formats, and tests may be deleted, renamed, replaced, or quarantined when they conflict with
the representative `OxRuntime`/OxVba/Scene/PAL design. The goal is a representative implementation
that proves the strategy before broad FM20 control breadth resumes.

Focused acceptance:

```powershell
cargo test -p oxforms-headless-runner --test headless_runner_showcase
cargo test -p oxforms-oxvba-adapter --test oxvba_reducer_cmdbutton
cargo test -p oxforms-oxvba-adapter --test oxvba_full_surface_showcase
```

## Coverage Seed

| Area | Status | Evidence |
|---|---|---|
| Headless attach/render/snapshot | Passing | `headless_runner_showcase::runner_attaches_renders_and_records_trace_rows` |
| Queued keyboard input order | Passing subset | `headless_runner_showcase::runner_drains_key_turns_against_the_current_vba_state` proves each key turn mutates TextBox state before the next turn is reduced |
| Burst draining | Passing scaffold | `headless_runner_showcase::runner_can_step_a_burst_one_action_at_a_time` |
| Capability descriptor | Passing scaffold | `oxvba_reducer_cmdbutton::capability_catalog_is_the_single_policy_source_for_current_controls` |
| Interaction maps + invalidation | Passing scaffold | `oxvba_reducer_cmdbutton::interaction_index_caches_tab_default_cancel_and_accelerator_maps` |
| Showcase diagnostics | Passing scaffold | `headless_runner_showcase::runner_attaches_renders_and_records_trace_rows` reads `CapabilityCatalog` and `InteractionIndexSummary` through `OxRuntime` |
| Foundation oracle matrix | Coverage pass | `oracle-foundation-matrix.md` classifies consumed W006/W008 facts and phase-0 blockers |
| TextBox selection/edit commands | Passing first slice | `oxvba_reducer_cmdbutton::textbox_character_input_replaces_selection_and_moves_caret`; `textbox_backspace_delete_and_navigation_edit_at_the_caret`; `textbox_ctrl_a_paste_copy_and_cut_use_selection_and_clipboard_stub`; `textbox_mouse_down_places_caret_from_control_local_x` |
| TextBox rapid selection/delete state | Passing | `oxvba_reducer_cmdbutton::textbox_shift_arrow_selection_and_backspace_repeat_are_headless_stateful` |
| TextBox caret/selection visuals | Passing shaped-scene proof | `oxvba_reducer_cmdbutton::textbox_scene_emits_caret_and_selection_fill_primitives`; `textbox_selection_geometry_uses_shaped_caret_stops_and_recolors_text` |
| TextBox mouse drag selection | Passing headless path | `oxvba_reducer_cmdbutton::textbox_mouse_drag_extends_selection_through_mousemove_capture`; `headless_runner_showcase::runner_mouse_drag_selects_textbox_text_through_mousemove` |
| Rapid TextBox key sequences | Passing scaffold | `headless_runner_showcase::runner_handles_rapid_letter_sequence_and_backspace_repeat` |
| CheckBox keyboard toggle | Passing headless path | `headless_runner_showcase::runner_keyboard_space_toggles_focused_checkbox` tabs to the CheckBox, presses Space, and asserts value/event/trace state |
| Control-stack reassessment | Implemented doc gate | `docs/specs/CONTROL_STACK_STRATEGY.md`; `control-stack-reassessment.md`; `oxforms-zhz.12` |
| Showcase TextBox editing dashboard | Passing | `oxvba_full_surface_showcase::showcase_catalog_lists_current_live_surface_and_future_rows`; `headless_runner_showcase::runner_attaches_renders_and_records_trace_rows` |
| Cursor, timers, DataObject, system metrics/colors, image decode | Not implemented | Future `oxforms-zhz.*` lanes |
| New W009 MSForms oracle rows | Not captured in this slice | Future focused captures must cover unresolved TextBox edge facts plus `oxforms-zhz.5`/`.6` hazards before parity claims consume them |
| Perf budgets | Scaffold only | Future `oxforms-zhz.8` |

## Known Non-Claims

- The runner is infrastructure, not an alternate backend.
- It does not yet implement cursor application, timer firing, DataObject formats,
  image decode, `.frm/.frx` materialization, or modal/nested pump semantics.
- The cursor scaffold records built-in mouse-pointer policy and the current routed
  target; no host cursor application or custom `MouseIcon` support is claimed.
- TextBox caret/selection geometry now uses shaped text-run caret stops in the runtime path, and
  the selected foreground recolor is represented in Scene. Pixel-level MSForms parity is still not
  claimed without a live oracle capture.
- TextBox is still a visible single-line first slice without horizontal scrolling. `oxforms-zhz.9`
  continues to own long-text horizontal scroll/clipped draw plus `SelStart`/`SelLength`/`SelText`
  setter oracle details. IME/dead keys, multiline, undo/redo, and grapheme-cluster editing remain
  explicit follow-up hazards.
- CheckBox Space activation is locally covered through the headless runner. Focus adornment,
  disabled/hidden/tab-stop mutations, cursor application, and live MSForms oracle capture remain
  `oxforms-zhz.5` scope before a broader parity claim.
- Hit testing still scans the current flat control collection. The interaction index
  removes repeated tab/default/cancel/accelerator scans, while spatial indexing remains
  with the phase-0 perf/hit-test lane.
- No new MSForms compatibility claim is made without a live oracle capture or a
  precise blocker.
