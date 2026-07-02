# W009 Foundation Oracle Matrix

Status: `phase-0 ideal-seam refresh`
Bead: `oxforms-zhz.23`
Date: 2026-07-02

This matrix is the W009 oracle routing surface for the first-class runtime
foundation. It does not create compatibility claims from OxForms output. It
separates:

- **MSForms oracle facts**: repo-owned Excel/MSForms captures or public facts
  that implementation beads may consume as compatibility evidence.
- **Local OxForms proofs**: tests/evidence that prove the current ideal seams
  carry behavior through `OxRuntime`, the VBA object model, `OxInteractionManager`,
  services, and retained Scene snapshots.
- **Unknowns/blockers**: facts that must become live captures, precise blockers,
  or explicit non-claims before representative control beads use them for parity.

## Consumed MSForms Oracle Facts

| Hazard area | Oracle status | Evidence | W009 consumption |
|---|---|---|---|
| Printable TextBox key turn | Captured | `docs/evidence/W008_native_event_breadth/captures/w008-focus-validation-20260627T223020Z`: `KeyDown -> KeyPress -> Change -> KeyUp` for printable text before Tab transfer. | TextBox key/char order and same-turn value mutation use this ordering. |
| Dirty TextBox focus-out by Tab | Captured | `w008-focus-validation-20260627T223020Z`: `KeyDown(Tab) -> BeforeUpdate -> AfterUpdate -> Exit -> Enter -> KeyUp(Tab on new control)`. | Focus transfer remains synchronous in the interaction manager; `KeyUp` may route to the new focus owner. |
| Exit veto | Captured | `w008-focus-validation-20260627T223020Z`: `Exit(Cancel=True)` keeps focus and suppresses candidate `Enter`. | Validation vetoes absorb attempted focus transfer/input turns. |
| BeforeUpdate veto | Captured | `w008-focus-validation-20260627T223020Z`: `BeforeUpdate(Cancel=True)` keeps focus; no `AfterUpdate`, `Exit`, or target `Enter`. | Dirty value validation is a two-stage gate. |
| Sticky dirty after edit-revert | Captured | `docs/evidence/W008_native_event_breadth/captures/w008-checkbox-update-20260629T003700Z`: type then Backspace to original text still fires `BeforeUpdate -> AfterUpdate`. | Value controls use an edited-since flag, not only a net-value comparison. |
| CheckBox mouse toggle order | Captured | `docs/evidence/W006_control_implementation_rollout/captures/checkbox-click-change-20260627T162407Z`. | Mouse click toggles value before `Change` and `Click`. |
| CheckBox discrete keyboard toggle | Captured | `docs/evidence/W006_control_implementation_rollout/captures/checkbox-keyboard-toggle-20260627T220935Z`. | Space/Enter keyboard activation uses value-first discrete ordering. |
| CheckBox dirty focus-out | Captured | `w008-checkbox-update-20260629T003700Z`: dirty CheckBox fires `BeforeUpdate -> AfterUpdate -> Exit`. | CheckBox participates in the same dirty focus-out model as TextBox. |
| Held Space on CheckBox | Captured | `docs/evidence/W008_native_event_breadth/captures/w008-held-key-20260628T213500Z`: held Space toggles exactly once. | Auto-repeat must not multiply CheckBox activation. |
| Held Enter on default button | Captured | `docs/evidence/W008_native_event_breadth/captures/w008-held-enter-20260629T004000Z`: held Enter activates default once. | Default-button Enter activation must be repeat-gated. |
| Paste veto | Captured | `docs/evidence/W008_native_event_breadth/captures/w008-paste-veto-20260629T003400Z`. | Clipboard paste mutates only after `BeforeDropOrPaste` cancel readback. |
| Drag-drop veto | Captured | `docs/evidence/W008_native_event_breadth/captures/w008-dragdrop-veto-20260629T103500Z`. | Drop and paste share the same target veto path; richer `DataObject` parity remains later. |
| Text service transfer/OLE transfer surface | Captured | `docs/evidence/W006_control_implementation_rollout/captures/text-service-transfer-*` and `ole-drag-drop-transfer-20260623T093507Z`. | HostServices/DataObject lanes can consume the text-only transfer shape; binary/rich formats are not covered. |
| Modeless/modal lifecycle and DoEvents reentrancy | Captured | `nested-modal-lifecycle-20260627T141239Z`, `doevents-yield-20260627T161225Z`, `terminate-lifetime-20260627T144316Z`. | `.30` may consume these for lifecycle/reentrancy ordering; they do not decide focused control deletion. |
| Selected `.frm` materialization subset | Implemented evidence, not broad parity | `docs/evidence/W006_control_implementation_rollout/frm-frx-interaction-slice.md`. | `.22` may consume the small current-control `.frm` geometry/property subset only. |

## Local OxForms Proofs

These rows are conformance evidence for the current implementation seams, not
new MSForms facts.

| Ideal seam / hazard | Local status | Evidence | Remaining oracle need |
|---|---|---|---|
| Canonical runtime/event turn | Passing | `RuntimeInput`/`RuntimeEventTurn`; `headless_runner_showcase::*`; bootstrap dispatch through `OxRuntime::dispatch_event_turn`. | None for seam existence; per-control parity still needs oracle rows. |
| HostServices spine | Passing representative seam | `host_services::tests::*`; `runner_host_services_probe_covers_representative_spine`; timer/clipboard/cursor/DPI/image/drop service traces. | Native cursor application, real timers, rich DataObject formats, and real image decode remain control-lane claims. |
| RendererBackend/Scene vocabulary | Passing representative seam | `scene::tests::headless_reference_rasterizes_every_primitive_variant`; `vba_scene_builder_records_full_primitive_vocabulary`; image placeholder raster tests. | Exact image pixels wait for `.28`; pixel-perfect MSForms rendering remains non-claim. |
| TextService v1 | Passing single-line seam | `OxTextService`; `textbox_textservice_scrolls_and_clips_long_text_to_caret`; shaped caret/selection tests. | Multiline, IME/dead keys, undo/redo, grapheme editing: `oxforms-zhz.34`. |
| ThemePainter tokens | Passing representative seam | `OxTheme`; disabled text, edge, pressed face, selection/caret Scene assertions. | Theme tokens are internal; no alternate skin or pixel-perfect claim. |
| InteractionManager state/maps | Passing representative seam | `OxInteractionManager`; capture/hover/cursor/tab/default/cancel/accelerator tests. | Wheel, double-click, drag threshold, native cursor application, and nested tab scopes remain unknown. |
| Object-model side effects | Passing representative seam | `Controls.Remove`, live-name lookup, structural add/remove full render, stale focus/capture/hover clearing. Tests: `object_model_add_remove_and_name_lookup_drive_structural_state`, `focused_hide_disable_and_remove_clear_stale_interaction_state`. | Exact MSForms event ordering for focused hide/disable/delete and error behavior remains unknown. |
| AccessibilityService semantic snapshot | Passing representative seam | `OxAccessibilityService`; `IOxControl` accessibility projection members; `runner_accessibility_snapshot_tracks_focus_value_and_selection`; showcase `AccessibilitySnapshot`. | Windows UIA/MSAA provider adapter, provider notifications, platform client tests, and MSForms accessibility parity remain follow-up work in `oxforms-zhz.35`. |
| `.frm/.frx` selected materialization | Passing selected-slice seam | `OxFrmMaterializer`; `fixtures/frm/w009-materialization/w009-representative.frm`; `oxvba_frm_materialization::representative_frm_materializes_into_live_vba_object_model` proves current controls materialize into `UserForm.Controls.Add`, render, and expose `.frx` image-reference metadata. | Full MS-OFORMS codec, broad MorphData parsing, save/roundtrip, and decoded Image control bytes remain later persistence/Image-lane claims. |
| TextBox edit/value commands | Passing local representative slice | selection replace, Backspace/Delete/Home/End/Left, Ctrl+A/C/X/V, paste/drop, drag selection, long-text horizontal scroll, `Value` alias, programmatic selection setter, `SelText`, `HideSelection`, materialized `.frm` `Value`, and diagnostics tests. | Exact MSForms setter ordering/coercion/error behavior and burst/post oracle behavior remain non-claims; pixel parity remains unknown. |
| CheckBox keyboard path | Passing local/headless path | `runner_keyboard_space_toggles_focused_checkbox`; reducer CheckBox mouse/keyboard tests. | Focus adorner, disabled/hidden/tab-stop behavior, cursor, and live oracle notes remain before broader CheckBox parity. |

## Representative Bead Routing

| Bead | May consume now | Must not claim yet / required blocker |
|---|---|---|
| `oxforms-zhz.21` AccessibilityService | Local object model exposes role-like kind/name/value/enabled/visible/focused/selected state; focus/value/selection transitions are observable headlessly. | Full Windows UIA/MSAA provider parity is not required for `.21`; file provider wiring as a follow-up if omitted. |
| `oxforms-zhz.22` `.frm/.frx` materialization | W006 `.frm` subset, current VBA factory/object model, `.20` structural add/name/tab/default/cancel side effects, and HostServices image-handle stubs. The W009 fixture now proves `UserForm`, `Label`, `TextBox`, `CommandButton`, and `CheckBox` materialize into live VBA controls, while unsupported `MSForms.Image` records `.frx` metadata. | Full MS-OFORMS codec, broad MorphData, save/roundtrip, and real binary image decode are not proven; `.frx` support is metadata/indirection only until `.28`. |
| `oxforms-zhz.24` representative TextBox | W008 key/change/focus/paste/drop facts; local TextService, ThemePainter, HostServices clipboard/drop, InteractionManager, object-model side effects, `.21` accessibility snapshots, `Value` alias/materialization, and local property diagnostics. | Multiline/IME/undo/grapheme are `oxforms-zhz.34`; pixel-level caret/selection parity, exact setter ordering/coercion/errors, and burst/post behavior remain explicit non-claims unless newly captured. |
| `oxforms-zhz.25` representative CheckBox | W006/W008 value-first mouse/keyboard/dirty-focus facts; local ThemePainter/InteractionManager/object-model side effects. | Focus rectangle/adorners, disabled/hidden/TabStop mutation ordering, cursor, and precise focused-delete behavior need capture or explicit blockers. |
| `oxforms-zhz.26` ListBox/list data | HostServices/DataObject text trace shape and RendererBackend vocabulary. | Selection matrix, multi-select modes, type-ahead, list storage, and keyboard Escape/type-ahead reachability need capture/blocker rows. |
| `oxforms-zhz.27` Frame/container | RendererBackend clipping primitives and object-model structural rebuild. | Nested coordinate origin, clipping, hit-test recursion, tab scopes, and Enter/Exit boundary ordering need a container capture/model. |
| `oxforms-zhz.28` Image/`.frx` | HostServices image-decode handle trace and `DrawImage` placeholder determinism. | Real image decode, binary wire decision, `.frx` bytes, `PictureSizeMode`, and alignment need implementation evidence and/or oracle rows. |
| `oxforms-zhz.29` SpinButton/ScrollBar timer repeat | HostServices timer slots/traces and held-key single-activation facts. | Button hold repeat rate is still a documented oracle limitation; single-step value/event facts need capture before parity. |
| `oxforms-zhz.30` reentrancy/lifecycle | W006 modal, DoEvents, terminate captures; `.20` stale-owner clearing. | Handler-driven mutation ordering for add/remove/hide/disable during active dispatch still needs representative proof and explicit MSForms unknowns. |

## Blockers And Unknowns

| Hazard area | Current state | Exact blocker / follow-up |
|---|---|---|
| TextBox setter side effects | Local `Value`, `SelStart`/`SelLength`, `SelText`, and `HideSelection` setters clamp/update and the covered programmatic path does not dispatch `Change`; no fresh oracle row. | Exact MSForms setter ordering, `Change` semantics, coercion, and error behavior remain non-claims until captured. |
| TextBox burst/post behavior | Headless drain is deterministic and treated as a local implementation choice; MSForms posted-input behavior unknown. | Capture or explicitly scope any future parity claim before using posted-input behavior as an oracle fact. |
| TextBox pixel caret/selection parity | Scene proof exists. | Needs live pixel oracle before any pixel-perfect claim. |
| CheckBox focus/disabled/hidden/tab-stop | Local object model clears stale state safely. | Need live oracle or explicit blocker for focus rectangle visibility and event ordering when a focused CheckBox is hidden, disabled, removed, or has `TabStop=False`. |
| MouseMove/capture routing | Local TextBox drag selection path exists. | Capture MSForms MouseMove with and without capture, including move outside the control after MouseDown, before pointer-heavy controls claim parity. |
| Double-click | Signature known; ordering not captured for W009. | Capture `MouseDown -> MouseUp -> Click -> DblClick` ordering per representative control and any cancellation effect. |
| Wheel | No committed FM20 foundation fact. | Determine whether the target source exposes wheel events or whether wheel is host/PAL-only for list/scroll controls; capture or record non-claim before list/scroll lanes. |
| Cursor application | Descriptor and HostServices trace only. | Native cursor setting, custom `MouseIcon`, and visual cursor capture are later HostServices/control claims. |
| Held Escape/cancel and Alt accelerator repeat | Open follow-up. | `oxforms-uvh` remains the capture bead for held Escape/cancel and held Alt+accelerator repeat gating. |
| Runtime add/remove and focused-control deletion | Local flat seam exists. | MSForms ordering is unknown: whether focused hide/disable/remove transfers focus, fires `Exit`, or clears silently must remain a blocker until captured. |
| `.frx` binary/image materialization | Selected metadata path exists for one Image `Picture` reference; no decode or Image control exists. | `.28` must turn representative `.frx` bytes into an image decode handle/Scene path or record exact wire/codec blockers. |
| Frame/container coordinates | Unknown. | Container coordinate, clipping, hit-test, tab-scope, and boundary-event facts belong to `.27` before container lanes consume them. |
| Accessibility provider parity | Runtime snapshots exist as local OxForms proof; no platform provider is wired. | `.21` defines the data model; Windows UIA/MSAA provider wiring is tracked by `oxforms-zhz.35`. |

## Immediate Implementation Guidance

- `.21` should build snapshots/traces from the current object model and interaction state, then
  file provider follow-ups if Windows UIA/MSAA is not wired.
- `.22` should materialize directly into `UserForm.Controls.Add` and concrete `IOxControl`
  objects. It must not recreate a Rust-side form/control projection.
- `.24` may use the local single-line TextBox implementation as the representative control, but
  its parity claims must stay bounded by the consumed facts above.
- `.25` and later controls must add live oracle rows or exact blockers before claiming behavior
  beyond the facts already consumed here.
- No row may use OxForms output as an MSForms oracle. OxForms tests prove seam behavior only.

## Clean-Room Note

All consumed evidence above comes from repo-owned fixture source, public
Excel/VBIDE automation, public Windows input, public specifications, and worksheet
exports already committed under `docs/evidence`. No private Office internals or
OxForms-output comparisons are used as oracle evidence.
