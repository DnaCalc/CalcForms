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
Canonical event-turn contract: `oxforms-zhz.14`
HostServices spine: `oxforms-zhz.15`
Renderer primitive determinism: `oxforms-zhz.17`
TextService seam: `oxforms-zhz.16`
ThemePainter seam: `oxforms-zhz.18`
InteractionManager seam: `oxforms-zhz.19`

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

`oxforms-zhz.14` names and wires the canonical runtime/event-turn contract:

- `RuntimeInput` is the normalized input turn entering `OxRuntime`;
- `OxRuntime::dispatch_event_turn` is now the shared semantic dispatch entry for
  the headless runner and Windows/bootstrap path;
- `RuntimeEventTurn` returns the stable action label, ordered reducer effect log,
  explicit host-service effects, and same-turn repaint marker;
- the headless JSONL trace now records `host_service_effects`, while
  `HeadlessRunner::dispatch` still reads VBA state and observes the resident
  `Scene` revision in the same turn without issuing a second explicit render when
  the reducer already repainted;
- the bootstrap maps PAL events, including Ctrl+V clipboard reads, into the same
  contract before asking the backend to repaint.

`oxforms-zhz.15` adds the representative HostServices spine behind that contract:

- `HostServices` is owned by `OxRuntime`, with `headless()` and `windows(reader)`
  constructors;
- the Windows bootstrap injects `oxforms_pal_win::read_clipboard_text` into
  `HostServices::windows`, so live Ctrl+V reads are part of the runtime turn;
- `RuntimeInput` now has service turns for `PasteFromClipboard`, service probe,
  cursor requests, timer arm/cancel/advance, DPI changes, image-decode handle
  traces, and drop/DataObject text traces;
- `HeadlessRunner::Tick` now advances virtual time through `OxRuntime` instead
  of remaining runner-local bookkeeping;
- deterministic headless traces cover clipboard, DataObject, cursor, timer
  slots/fires, system metrics/colors, DPI, image decode handle shape, and
  drag/drop.

`oxforms-zhz.17` closes the representative RendererBackend/Scene primitive
contract:

- `OxSceneBuilder` now records the representative primitive vocabulary emitted by
  current and near-term controls: rects, rounded rects, ellipses, lines,
  polygons, gradients, text, images, and edges;
- the headless reference sink rasterizes every `Prim` variant deterministically,
  including text/image placeholders and real edge composition, so supported
  primitives cannot disappear from `framebuffer_hash`;
- the visible tiny-skia backend paints a deterministic `DrawImage` placeholder
  until decoded image bytes land behind the HostServices image lane;
- the OxVba surface smoke proves VBA-emitted primitive bytes round-trip through
  `ScenePatch` into the matching `Prim` variants, and that a non-rect primitive
  fixture perturbs the headless framebuffer hash.

`oxforms-zhz.16` adds the first-class single-line `TextService` seam for TextBox:

- `OxTextService` consumes `MeasureBatch` metrics/caret-stop responses for caret
  placement, x-to-index hit testing, selection geometry, max-scroll, and caret-visible
  horizontal scroll;
- `TextBox` keeps MSForms-owned value, selection, focus, validation, and event order in VBA,
  while delegating text geometry to the service instead of local ad hoc parsing/measurement;
- TextBox text now paints through a clipped text child node, with the existing selected-text
  recolor overlay using the same scrolled text rect and shaped run;
- headless/OxVba tests cover long single-line scroll/clipped draw, Home reset to origin,
  proportional shaped selection geometry, drag selection, repeated delete/backspace, and
  the full showcase/runtime path;
- deferred TextService v2 hazards are filed as `oxforms-zhz.34`: IME/dead keys, multiline,
  undo/redo, and grapheme-cluster-aware editing.

`oxforms-zhz.18` adds the representative internal `ThemeTokens`/`ThemePainter` seam:

- `OxTheme` now resolves common MSForms appearance bands (`BackColor`, `ForeColor`,
  `BorderColor`, `SpecialEffect`, `Enabled`, and pressed state) through named
  ThemePainter helpers instead of per-control shortcuts;
- standard controls paint their face, border/edge, and text through `OxThemePaintControlFrame`
  and `OxThemePaintTextRun`;
- TextBox and CheckBox keep their bespoke parts but consume the same token resolvers for
  frames, text, selection background/foreground, caret, checkbox face, and check mark;
- adapter tests inspect the resident Scene to prove selected text/background, disabled text,
  pressed face, caret color, and edge effects are emitted deterministically.

`oxforms-zhz.19` promotes the interaction manager to a first-class VBA subsystem:

- `OxInteractionManager` owns focus, capture, pressed state, hover/cursor target, tab maps,
  default/cancel buttons, accelerators, validation transfer, and interaction-index rebuilds;
- `OxReducer` remains as the stable runtime/form facade and delegates every dispatch and
  diagnostic property to the manager;
- representative reducer tests prove capture/pressed/hover/cursor state, z-order hit routing,
  validation vetoes, tab/default/cancel/accelerator maps, disabled/hidden/tab-stop mutation, and
  runtime `Controls.Add` index invalidation;
- the full-surface showcase exposes `InteractionStateSummary` alongside
  `InteractionIndexSummary`.

Focused acceptance:

```powershell
cargo test -p oxforms-pal
cargo test -p oxforms-pal-win
cargo test -p oxforms-oxvba-adapter --test oxvba_surface_render_smoke
cargo test -p oxforms-headless-runner --test headless_runner_showcase
cargo test -p oxforms-oxvba-adapter host_services
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
| InteractionManager state | Passing representative seam | `vba/oxforms/OxInteractionManager.cls`; `oxvba_reducer_cmdbutton::capture_routes_mouseup_to_the_pressed_control_across_a_sibling`; `interaction_manager_tracks_hover_and_cursor_without_capture`; `interaction_manager_rebuilds_tab_maps_after_mutations` |
| Interaction maps + invalidation | Passing representative seam | `oxvba_reducer_cmdbutton::interaction_index_caches_tab_default_cancel_and_accelerator_maps`; `interaction_manager_rebuilds_tab_maps_after_mutations` |
| Showcase diagnostics | Passing scaffold | `headless_runner_showcase::runner_attaches_renders_and_records_trace_rows` reads `CapabilityCatalog`, `InteractionIndexSummary`, and `InteractionStateSummary` through `OxRuntime` |
| Foundation oracle matrix | Coverage pass | `oracle-foundation-matrix.md` classifies consumed W006/W008 facts and phase-0 blockers |
| TextBox selection/edit commands | Passing first slice | `oxvba_reducer_cmdbutton::textbox_character_input_replaces_selection_and_moves_caret`; `textbox_backspace_delete_and_navigation_edit_at_the_caret`; `textbox_ctrl_a_paste_copy_and_cut_use_selection_and_clipboard_stub`; `textbox_mouse_down_places_caret_from_control_local_x` |
| TextBox rapid selection/delete state | Passing | `oxvba_reducer_cmdbutton::textbox_shift_arrow_selection_and_backspace_repeat_are_headless_stateful` |
| TextBox caret/selection visuals | Passing shaped-scene proof | `oxvba_reducer_cmdbutton::textbox_scene_emits_caret_and_selection_fill_primitives`; `textbox_selection_geometry_uses_shaped_caret_stops_and_recolors_text` |
| TextBox TextService + horizontal scroll | Passing single-line v1 | `vba/oxforms/OxTextService.cls`; `oxvba_reducer_cmdbutton::textbox_textservice_scrolls_and_clips_long_text_to_caret`; render-smoke canonical scene covers the clipped TextBox text child node |
| TextBox mouse drag selection | Passing headless path | `oxvba_reducer_cmdbutton::textbox_mouse_drag_extends_selection_through_mousemove_capture`; `headless_runner_showcase::runner_mouse_drag_selects_textbox_text_through_mousemove` |
| Rapid TextBox key sequences | Passing scaffold | `headless_runner_showcase::runner_handles_rapid_letter_sequence_and_backspace_repeat` |
| Runtime/event-turn contract | Passing | `RuntimeInput`/`RuntimeEventTurn` in `crates/oxforms-oxvba-adapter/src/runtime.rs`; headless and bootstrap both call `OxRuntime::dispatch_event_turn` |
| Host-service effect trace | Passing first slice | `headless_runner_showcase::runner_records_service_effect_and_same_turn_readback_repaint` proves paste records `clipboard.set_text:<len>`, mutates VBA TextBox state, and advances the Scene revision in the same event turn |
| HostServices spine | Passing representative spine | `host_services::tests::*`; `headless_runner_showcase::runner_host_services_probe_covers_representative_spine`; `runner_virtual_timer_and_clipboard_pass_through_oxruntime`; `runner_traces_cursor_dpi_image_and_drag_drop_services` |
| RendererBackend/Scene determinism | Passing representative spine | `scene::tests::headless_reference_rasterizes_every_primitive_variant`; `raster::tests::draw_image_placeholder_is_visible_until_decode_lands`; `oxvba_surface_render_smoke::vba_scene_builder_records_full_primitive_vocabulary`; existing `geometry_showcase_has_a_stable_golden_hash`, `text_draws_glyph_coverage_when_a_font_is_available`, and `incremental_damage_repaint_is_pixel_identical_to_full_repaint` |
| ThemePainter tokens | Passing representative seam | `vba/oxforms/OxTheme.bas`; `oxvba_reducer_cmdbutton::command_button_mouse_click_runs_the_vba_reducer`; `theme_painter_maps_disabled_text_and_edges_for_standard_controls`; `textbox_scene_emits_caret_and_selection_fill_primitives`; `textbox_selection_geometry_uses_shaped_caret_stops_and_recolors_text` |
| CheckBox keyboard toggle | Passing headless path | `headless_runner_showcase::runner_keyboard_space_toggles_focused_checkbox` tabs to the CheckBox, presses Space, and asserts value/event/trace state |
| Control-stack reassessment | Implemented doc gate | `docs/specs/CONTROL_STACK_STRATEGY.md`; `control-stack-reassessment.md`; `oxforms-zhz.12` |
| Showcase TextBox editing dashboard | Passing | `oxvba_full_surface_showcase::showcase_catalog_lists_current_live_surface_and_future_rows`; `headless_runner_showcase::runner_attaches_renders_and_records_trace_rows` |
| Full cursor/timer/DataObject/image parity | Representative spine only | `oxforms-zhz.15` provides deterministic traces and API stubs; later representative control beads apply native cursor hooks, control timers, richer DataObject formats, and real image decode |
| New W009 MSForms oracle rows | Not captured in this slice | Future focused captures must cover unresolved TextBox edge facts plus `oxforms-zhz.5`/`.6` hazards before parity claims consume them |
| Perf budgets | Scaffold only | Future `oxforms-zhz.8` |

## Known Non-Claims

- The runner is infrastructure, not an alternate backend.
- HostServices now provides API stubs and deterministic traces for cursor, timers,
  DataObject, metrics/colors, DPI, image-decode handles, and drag/drop. It does
  not yet claim native cursor application, control-driven timer behavior, rich
  DataObject format parity, real image decode, `.frm/.frx` materialization, or
  modal/nested pump semantics.
- `DrawImage` now participates in deterministic headless and visible placeholder
  rendering so it cannot be silently dropped from hashes, but decoded image
  pixels and exact MSForms image/text pixel parity remain later claims.
- The cursor scaffold records built-in mouse-pointer policy, the current routed
  target, and service requests; no custom `MouseIcon` support is claimed.
- `OxInteractionManager` owns current focus/capture/pointer/tab/default/cancel/accelerator
  state for the flat control collection. Full structural remove/reparent semantics, nested
  container tab scopes, wheel routing, double-click, drag threshold, and native cursor
  application remain later representative-control work.
- TextBox caret/selection geometry and single-line horizontal scroll now use shaped text-run
  caret stops through `OxTextService`; selected foreground recolor and clipped/scrolled normal
  text are represented in Scene. Pixel-level MSForms parity is still not claimed without a live
  oracle capture.
- Theme tokens are internal implementation vocabulary only. MSForms properties and runtime state
  remain authoritative, and `.18` does not claim alternate skin/theme product behavior or
  pixel-perfect MSForms rendering.
- TextBox is still a visible single-line slice. `oxforms-zhz.9` continues to own
  `SelStart`/`SelLength`/`SelText` setter oracle details and burst/post oracle behavior.
  IME/dead keys, multiline, undo/redo, and grapheme-cluster editing are tracked as
  `oxforms-zhz.34`.
- CheckBox Space activation is locally covered through the headless runner. Focus adornment,
  disabled/hidden/tab-stop mutations, cursor application, and live MSForms oracle capture remain
  `oxforms-zhz.5` scope before a broader parity claim.
- Hit testing still scans the current flat control collection. The interaction index
  removes repeated tab/default/cancel/accelerator scans, while spatial indexing remains
  with the phase-0 perf/hit-test lane.
- No new MSForms compatibility claim is made without a live oracle capture or a
  precise blocker.
