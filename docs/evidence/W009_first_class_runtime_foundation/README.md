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
Object-model side-effect seam: `oxforms-zhz.20`
AccessibilityService seam: `oxforms-zhz.21`
Form materialization seam: `oxforms-zhz.22`
Oracle matrix refresh: `oxforms-zhz.23`
Image/FRX representative seam: `oxforms-zhz.28`

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

`oxforms-zhz.20` tightens the representative object-model mutation contract:

- `Controls.Remove` by name detaches a control, updates lookup, invalidates the interaction
  revision, and forces the next render to rebuild the retained root child list;
- `UserForm.ControlByName`/`HasControl` read live `OxControlCore.Name` values, so representative
  runtime name mutation is not trapped behind the original `Controls.Add` key;
- structural add/remove after the first render rebuilds the `Scene`, while ordinary property
  changes continue to use dirty-node incremental patches;
- `OxInteractionManager` reconciles focus, capture, pressed, hover, and cursor owners against the
  live object model before dispatch/readback, so focused hide/disable/remove does not leave a stale
  control receiving keyboard or pointer input;
- representative reducer tests prove add/remove/name lookup, structural retained-Scene rebuild,
  focused hide/disable/remove state clearing, z-order hit routing, and capability-driven policy.

`oxforms-zhz.21` adds the representative `AccessibilityService` semantic snapshot:

- `IOxControl` now exposes host-neutral accessibility projection members for role, name, value,
  selected state, selection range/text, and supported patterns;
- `OxAccessibilityService` builds deterministic form/control rows from the live VBA object model
  plus `OxInteractionManager` focus state, including role/name/value/enabled/visible/focused/
  selected/selection/pattern fields;
- `OxReducer.AccessibilitySnapshot` keeps the runtime facade stable, and the full-surface showcase
  exposes the snapshot alongside its capability and interaction diagnostics;
- headless trace rows now carry `accessibility_snapshot`, so each `OxRuntime` input turn can prove
  focus, value, and selection changes without consulting pixels or a platform provider echo;
- Windows UIA/MSAA provider wiring is intentionally not claimed by this bead and is tracked as
  `oxforms-zhz.35`.

`oxforms-zhz.22` adds a representative selected-slice `.frm/.frx` materialization path:

- `OxFrmMaterializer` parses the current `.frm` subset in VBA and builds the live object model with
  `New UserForm` plus `Controls.Add`, not a Rust-side form/control projection;
- the representative fixture covers form caption/client size; `Label`, `TextBox`, `CommandButton`,
  and `CheckBox` controls; twip-to-point geometry; captions/text/value; tab order; colors; border
  style; enabled/visible state; and default/cancel flags;
- the initial unsupported `MSForms.Image` block was recorded as image metadata with its `.frx`
  `Picture` reference, so the Image lane could consume real binary indirection without reviving a
  Rust-side form projection;
- `frm_materialization_probe_form` proves the materialized form renders through
  `UserForm.Render`/`OxForms.Surface` and projects accessibility rows from the live controls.

`oxforms-zhz.28` consumes that image lane through the same live object-model path:

- `Forms.Image.1` now creates a non-focusable click-capable `Image` control with `Picture`,
  `PictureOffset`, `PictureSha256`, `PictureHandle`, `PictureSizeMode`, and `ImageDiagnostics`;
- `OxFrmMaterializer` now materializes the W009 fixture's `MSForms.Image` block into that live
  control, preserving the `.frx` path/offset and assigning a deterministic opaque handle;
- the materialized form and full-surface showcase both emit `DrawImage` Scene primitives, and the
  headless/visible renderers paint deterministic image placeholders so the primitive cannot be
  silently dropped;
- HostServices image-decode turns prove the handle-trace shape for representative bytes. Real
  decoded image pixels, exact MSForms size/alignment oracle behavior, and full Picture object
  parity remain explicit non-claims.

`oxforms-zhz.24` makes the current single-line `TextBox` the representative complex control:

- `TextBox.Value` is a first-class alias for the authoritative `Text`/display string, so MSForms
  form sources can use either property without taking a parallel object-model path;
- the `.frm` fixture now uses `Value = "seed"` for its `TextBox`, and `OxFrmMaterializer` routes
  `Value` by control type so `TextBox.Value` and `CheckBox.Value` both materialize correctly;
- reducer fixture diagnostics prove programmatic `Value`, `SelStart`, `SelLength`, `SelText`, and
  `HideSelection` mutations update the live control, clamp selection to the current text, avoid
  user `Change` dispatch in the covered local path, and expose the capability descriptor;
- the full-surface showcase exposes `InputValue` and `TextBoxDiagnostics`, including value,
  selection, capability, and accessibility projection data through `OxRuntime`.

Focused acceptance:

```powershell
cargo test -p oxforms-pal
cargo test -p oxforms-pal-win
cargo test -p oxforms-oxvba-adapter --test oxvba_surface_render_smoke
cargo test -p oxforms-headless-runner --test headless_runner_showcase
cargo test -p oxforms-oxvba-adapter host_services
cargo test -p oxforms-oxvba-adapter --test oxvba_reducer_cmdbutton
cargo test -p oxforms-oxvba-adapter --test oxvba_frm_materialization
cargo test -p oxforms-oxvba-adapter --test oxvba_full_surface_showcase
```

## Coverage Seed

| Area | Status | Evidence |
|---|---|---|
| Headless attach/render/snapshot | Passing | `headless_runner_showcase::runner_attaches_renders_and_records_trace_rows` |
| Queued keyboard input order | Passing subset | `headless_runner_showcase::runner_drains_key_turns_against_the_current_vba_state` proves each key turn mutates TextBox state before the next turn is reduced |
| Burst draining | Passing scaffold | `headless_runner_showcase::runner_can_step_a_burst_one_action_at_a_time` |
| Capability descriptor | Passing scaffold | `oxvba_reducer_cmdbutton::capability_catalog_is_the_single_policy_source_for_current_controls` |
| Object model side effects | Passing representative seam | `vba/oxforms/Controls.cls`; `vba/oxforms/UserForm.cls`; `oxvba_reducer_cmdbutton::object_model_add_remove_and_name_lookup_drive_structural_state`; `focused_hide_disable_and_remove_clear_stale_interaction_state`; `overlapping_controls_route_by_z_order_then_last_added` |
| InteractionManager state | Passing representative seam | `vba/oxforms/OxInteractionManager.cls`; `oxvba_reducer_cmdbutton::capture_routes_mouseup_to_the_pressed_control_across_a_sibling`; `interaction_manager_tracks_hover_and_cursor_without_capture`; `interaction_manager_rebuilds_tab_maps_after_mutations` |
| Interaction maps + invalidation | Passing representative seam | `oxvba_reducer_cmdbutton::interaction_index_caches_tab_default_cancel_and_accelerator_maps`; `interaction_manager_rebuilds_tab_maps_after_mutations` |
| AccessibilityService snapshots/traces | Passing representative seam | `vba/oxforms/OxAccessibilityService.cls`; `headless_runner_showcase::runner_attaches_renders_and_records_trace_rows`; `headless_runner_showcase::runner_accessibility_snapshot_tracks_focus_value_and_selection`; `oxvba_full_surface_showcase::showcase_catalog_lists_current_live_surface_and_future_rows` |
| `.frm/.frx` materialization | Passing selected-slice seam | `vba/oxforms/OxFrmMaterializer.cls`; `fixtures/frm/w009-materialization/w009-representative.frm`; `oxvba_frm_materialization::representative_frm_materializes_into_live_vba_object_model` |
| Image/FRX representative spike | Passing representative seam | `vba/oxforms/Image.cls`; materialized `LogoImage`; showcase `ImageDiagnostics`; `DrawImage` Scene assertions in `oxvba_frm_materialization` and `oxvba_full_surface_showcase`; HostServices decode traces |
| Showcase diagnostics | Passing scaffold | `headless_runner_showcase::runner_attaches_renders_and_records_trace_rows` reads `CapabilityCatalog`, `InteractionIndexSummary`, `InteractionStateSummary`, and `AccessibilitySnapshot` through `OxRuntime`; `oxvba_full_surface_showcase::showcase_catalog_lists_current_live_surface_and_future_rows` reads `TextBoxDiagnostics` |
| Foundation oracle matrix | Refreshed ideal-seam routing | `oracle-foundation-matrix.md` separates MSForms oracle facts, local OxForms proofs, representative-bead consumption rules, and explicit blockers for `.21`, `.22`, `.24`, and later spikes |
| TextBox selection/edit commands | Passing first slice | `oxvba_reducer_cmdbutton::textbox_character_input_replaces_selection_and_moves_caret`; `textbox_backspace_delete_and_navigation_edit_at_the_caret`; `textbox_ctrl_a_paste_copy_and_cut_use_selection_and_clipboard_stub`; `textbox_mouse_down_places_caret_from_control_local_x` |
| TextBox value/property setters | Passing local representative slice | `vba/oxforms/TextBox.cls`; `vba/oxforms/OxFrmMaterializer.cls`; `oxvba_reducer_cmdbutton::textbox_programmatic_value_selection_and_diagnostics_are_side_effect_safe`; `oxvba_frm_materialization::representative_frm_materializes_into_live_vba_object_model` |
| TextBox rapid selection/delete state | Passing | `oxvba_reducer_cmdbutton::textbox_shift_arrow_selection_and_backspace_repeat_are_headless_stateful` |
| TextBox caret/selection visuals | Passing shaped-scene proof | `oxvba_reducer_cmdbutton::textbox_scene_emits_caret_and_selection_fill_primitives`; `textbox_selection_geometry_uses_shaped_caret_stops_and_recolors_text` |
| TextBox TextService + horizontal scroll | Passing single-line v1 | `vba/oxforms/OxTextService.cls`; `oxvba_reducer_cmdbutton::textbox_textservice_scrolls_and_clips_long_text_to_caret`; render-smoke canonical scene covers the clipped TextBox text child node |
| TextBox mouse drag selection | Passing headless path | `oxvba_reducer_cmdbutton::textbox_mouse_drag_extends_selection_through_mousemove_capture`; `headless_runner_showcase::runner_mouse_drag_selects_textbox_text_through_mousemove` |
| Rapid TextBox key sequences | Passing scaffold | `headless_runner_showcase::runner_handles_rapid_letter_sequence_and_backspace_repeat` |
| Runtime/event-turn contract | Passing | `RuntimeInput`/`RuntimeEventTurn` in `crates/oxforms-oxvba-adapter/src/runtime.rs`; headless and bootstrap both call `OxRuntime::dispatch_event_turn` |
| Host-service effect trace | Passing first slice | `headless_runner_showcase::runner_records_service_effect_and_same_turn_readback_repaint` proves paste records `clipboard.set_text:<len>`, mutates VBA TextBox state, and advances the Scene revision in the same event turn |
| HostServices spine | Passing representative spine | `host_services::tests::*`; `headless_runner_showcase::runner_host_services_probe_covers_representative_spine`; `runner_virtual_timer_and_clipboard_pass_through_oxruntime`; `runner_traces_cursor_dpi_image_and_drag_drop_services` |
| RendererBackend/Scene determinism | Passing representative spine | `scene::tests::headless_reference_rasterizes_every_primitive_variant`; `raster::tests::draw_image_placeholder_is_visible_until_decode_lands`; `oxvba_surface_render_smoke::vba_scene_builder_records_full_primitive_vocabulary`; existing `geometry_showcase_has_a_stable_golden_hash`, `text_draws_glyph_coverage_when_a_font_is_available`, and `incremental_damage_repaint_is_pixel_identical_to_full_repaint` |
| ThemePainter tokens | Passing representative seam | `vba/oxforms/OxTheme.bas`; `OxPaintStandardControl`; `OxThemePaintCheckBox`; `oxvba_reducer_cmdbutton::command_button_mouse_click_runs_the_vba_reducer`; `theme_painter_maps_disabled_text_and_edges_for_standard_controls`; `textbox_scene_emits_caret_and_selection_fill_primitives`; `textbox_selection_geometry_uses_shaped_caret_stops_and_recolors_text` |
| CheckBox keyboard/focus/value path | Passing headless path | `headless_runner_showcase::runner_keyboard_space_toggles_focused_checkbox` tabs to the CheckBox, presses Space, and asserts value/event/trace state; `oxvba_reducer_cmdbutton::checkbox_mouse_click_toggles_value_with_change_before_click` proves reducer-routed focus invalidation and a Scene focus adorner |
| ListBox list-data spike | Passing representative single-select seam | `vba/oxforms/ListBox.cls`; `OxThemePaintListBox`; `reducer_listbox_form.cls`; `oxvba_reducer_cmdbutton::listbox_object_model_and_capability_descriptor_live_on_the_vba_control`; `listbox_mouse_click_selects_a_row_and_renders_selection`; `listbox_keyboard_focus_and_accessibility_rows_are_exposed`; showcase `ListBoxDiagnostics` |
| Frame/container coordinate spike | Passing representative seam | `vba/oxforms/Frame.cls`; `IOxControlContainer`; recursive `OxInteractionManager` and `OxAccessibilityService` traversal; `reducer_frame_form.cls`; `oxvba_reducer_cmdbutton::frame_owns_nested_controls_and_renders_a_parented_scene_subtree`; `frame_routes_hit_testing_tab_focus_and_accessibility_recursively`; showcase `FrameDiagnostics` |
| Control-stack reassessment | Implemented doc gate | `docs/specs/CONTROL_STACK_STRATEGY.md`; `control-stack-reassessment.md`; `oxforms-zhz.12` |
| Showcase TextBox editing dashboard | Passing | `oxvba_full_surface_showcase::showcase_catalog_lists_current_live_surface_and_future_rows` proves catalog and `TextBoxDiagnostics`; `headless_runner_showcase::runner_attaches_renders_and_records_trace_rows` proves the runtime path |
| Full cursor/timer/DataObject/image parity | Representative spine only | `oxforms-zhz.15` provides deterministic traces and API stubs; `oxforms-zhz.28` applies the image handle/DrawImage path; later depth applies native cursor hooks, control timers, richer DataObject formats, and real image pixel decode |
| New W009 MSForms oracle rows | Not captured in this slice | Future focused captures must cover unresolved TextBox edge facts plus `oxforms-zhz.5`/`.6` hazards before parity claims consume them |
| TextBox repeat/paste responsiveness | Baseline + attribution captured | `perf/w009-textbox-repeat-paste-baseline-20260704.json`; `perf/w009-textbox-paste-dispatch-attribution-20260704.json`; `headless_textbox_perf::textbox_repeat_paste_baseline_writes_json_report`; `headless_textbox_perf::textbox_paste_dispatch_attribution_writes_json_report` |
| Perf budgets | Scaffold only | Broad budget report remains future `oxforms-zhz.31` |

## Known Non-Claims

- The runner is infrastructure, not an alternate backend.
- Accessibility snapshots are a host-neutral runtime data model only. They do not implement or
  claim Windows UIA/MSAA provider behavior, assistive-technology compatibility, provider event
  notifications, bounding-rectangle parity, or MSForms accessibility parity. Provider wiring is
  tracked by `oxforms-zhz.35`.
- HostServices now provides API stubs and deterministic traces for cursor, timers,
  DataObject, metrics/colors, DPI, image-decode handles, and drag/drop. It does
  not yet claim native cursor application, control-driven timer behavior, rich
  DataObject format parity, real image decode, full `.frm/.frx` persistence, or
  modal/nested pump semantics.
- The `.frm/.frx` path is a selected-slice materializer for current controls and a representative
  Image `.frx` reference-to-handle-to-Scene path. It is not a full MS-OFORMS codec, broad MorphData
  parser, save/roundtrip implementation, designer loader, full Picture object model, or real image
  pixel decode.
- `DrawImage` now participates in deterministic headless and visible placeholder
  rendering so it cannot be silently dropped from hashes, but decoded image
  pixels and exact MSForms image/text pixel parity remain later claims.
- The cursor scaffold records built-in mouse-pointer policy, the current routed
  target, and service requests; no custom `MouseIcon` support is claimed.
- `Controls.Add`/`Controls.Remove` and live-name lookup are covered for the flat form collection,
  including retained-Scene structural rebuilds and stale interaction-owner clearing. Exact MSForms
  event ordering for focused hide/disable/delete, index-based removal, reparenting, nested
  container tab scopes, and full error behavior remain later oracle-backed claims.
- `OxInteractionManager` owns current focus/capture/pointer/tab/default/cancel/accelerator
  state for the flat control collection. Wheel routing, double-click, drag threshold, and native
  cursor application remain later representative-control work.
- TextBox caret/selection geometry and single-line horizontal scroll now use shaped text-run
  caret stops through `OxTextService`; selected foreground recolor and clipped/scrolled normal
  text are represented in Scene. Pixel-level MSForms parity is still not claimed without a live
  oracle capture.
- The ListBox spike is single-select and representative. It proves `AddItem`, `List(index)`,
  `ListCount`, `ListIndex`, `Value`, click selection, arrow selection, dirty focus-out,
  disabled/hidden routing exclusion, Scene selection paint, capability descriptors, and
  accessibility row counts. It does not yet claim multi-select modes, columns/bound-column,
  type-ahead, wheel/scroll, virtualization, per-row provider objects, or exact MSForms
  selection-event parity beyond the local order pinned by tests.
- The Frame spike is representative container architecture, not full container parity. It proves
  nested `Controls.Add`, child ownership/removal, relative child coordinates, recursive hit-test
  and tab traversal, child-local pointer coordinates, parented Scene nodes, recursive
  accessibility rows, and child invalidation bubbling. It does not yet claim exact MSForms
  border/caption pixels, all clipping edge cases, nested focus edge-order oracle behavior,
  reparenting, index removal, or MultiPage/TabStrip behavior.
- Theme tokens are internal implementation vocabulary only. MSForms properties and runtime state
  remain authoritative, and `.18` does not claim alternate skin/theme product behavior or
  pixel-perfect MSForms rendering.
- TextBox is still a visible single-line representative slice. Local `Value`,
  `SelStart`/`SelLength`/`SelText`, `HideSelection`, diagnostics, selection/caret editing,
  paste/drop, drag selection, and horizontal scroll/clipping are covered, but exact MSForms setter
  event ordering, coercion/error cases, burst/post behavior, and pixel-level caret/selection parity
  remain non-claims without a live oracle capture. IME/dead keys, multiline, undo/redo, and
  grapheme-cluster editing are tracked as `oxforms-zhz.34`.
- CheckBox Space activation, focus adornment, disabled/hidden/tab-stop interaction rebuilds,
  value-first ordering, validation, and accessibility/value traces are locally covered through
  the headless runner and reducer Scene tests. Native cursor application and live MSForms oracle
  recapture remain later parity work before a broader CheckBox compatibility claim.
- Hit testing still scans the current flat control collection. The interaction index
  removes repeated tab/default/cancel/accelerator scans, while spatial indexing remains
  with the phase-0 perf/hit-test lane.
- No new MSForms compatibility claim is made without a live oracle capture or a
  precise blocker.
