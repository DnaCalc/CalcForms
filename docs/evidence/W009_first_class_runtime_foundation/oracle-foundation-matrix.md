# W009 Foundation Oracle Matrix

Status: `phase-0 coverage pass; zhz.4/zhz.10/zhz.11 implementation notes appended`
Bead: `oxforms-zhz.3` baseline, updated by `oxforms-zhz.4`, `oxforms-zhz.10`, `oxforms-zhz.11`
Date: 2026-07-01

This matrix is the first W009 oracle pass for the runtime foundation. It does
not create new compatibility claims from OxForms output. It classifies public
MSForms facts and repo-owned Excel/MSForms captures that W009 may consume, and
it marks the remaining foundation hazards as explicit blockers or follow-up
capture requirements before implementation lanes rely on them.

## Consumed Facts

| Hazard area | Status | Evidence | W009 consumption |
|---|---|---|---|
| TextBox typed key turn | Captured | `w008-focus-validation-20260627T223020Z`: `KeyDown -> KeyPress -> Change -> KeyUp` for printable text before Tab transfer. | Current reducer key/char ordering remains the baseline. |
| Dirty TextBox focus-out via Tab | Captured | `w008-focus-validation-20260627T223020Z`: `KeyDown(Tab) -> BeforeUpdate -> AfterUpdate -> Exit -> Enter -> KeyUp(Tab on new control)`. | Focus transfer remains synchronous in the reducer; KeyUp may route to the new focus owner. |
| Exit veto | Captured | `w008-focus-validation-20260627T223020Z`: `Exit(Cancel=True)` keeps focus and no `Enter` on the candidate target. | Validation vetoes must absorb the attempted transfer/input turn. |
| BeforeUpdate veto | Captured | `w008-focus-validation-20260627T223020Z`: `BeforeUpdate(Cancel=True)` keeps focus; no `AfterUpdate`, `Exit`, or target `Enter`. | Dirty value validation is a two-stage gate. |
| Sticky dirty after edit-revert | Captured | `w008-checkbox-update-20260629T003700Z`: type then Backspace to the original text still fires `BeforeUpdate -> AfterUpdate`. | OxForms must keep an edited-since flag, not a net-value baseline gate. |
| CheckBox mouse toggle order | Captured | `checkbox-click-change-20260627T162407Z`. | Mouse click toggles value before `Change`/`Click`. |
| CheckBox discrete keyboard toggle | Captured | `checkbox-keyboard-toggle-20260627T220935Z`. | Space/Enter keyboard activation uses the value-first discrete ordering already in the reducer. |
| CheckBox dirty focus-out | Captured | `w008-checkbox-update-20260629T003700Z`: dirty CheckBox fires `BeforeUpdate -> AfterUpdate -> Exit`. | CheckBox participates in the same dirty focus-out model as TextBox. |
| Held Space on CheckBox | Captured | `w008-held-key-20260628T213500Z`: held Space toggles exactly once. | Auto-repeat must not multiply CheckBox activation. |
| Held Enter on default button | Captured | `w008-held-enter-20260629T004000Z`: held Enter activates the default button exactly once. | Default-button Enter activation must be repeat-gated. |
| Paste veto | Captured | `w008-paste-veto-20260629T003400Z`. | Text paste must defer mutation until `BeforeDropOrPaste` cancel readback. |
| Drag-drop veto | Captured | `w008-dragdrop-veto-20260629T103500Z`. | Drop and paste share the same target veto path; broad `DataObject` parity remains later. |
| `.frm` selected materialization | Implemented subset evidence | `docs/evidence/W006_control_implementation_rollout/frm-frx-interaction-slice.md`. | W009 may consume the small `.frm` geometry/property subset for current controls only. |

## Local Implementation Proofs Added After The Oracle Pass

These rows are OxForms conformance evidence, not new MSForms oracle facts. They prove that the
phase-0 runtime path now carries the corresponding hazard through `OxRuntime`, the VBA reducer,
host services, Scene patches, and snapshots.

| Hazard area | Status | Evidence | Remaining oracle need |
|---|---|---|---|
| TextBox selection replacement and edit commands | Implemented first slice | `oxvba_reducer_cmdbutton::textbox_character_input_replaces_selection_and_moves_caret`, `textbox_backspace_delete_and_navigation_edit_at_the_caret`, `textbox_shift_arrow_selection_and_backspace_repeat_are_headless_stateful`, `textbox_ctrl_a_paste_copy_and_cut_use_selection_and_clipboard_stub`, `textbox_mouse_down_places_caret_from_control_local_x`. | Capture/confirm MSForms edge details for `SelStart`/`SelLength` setters and burst/post behavior before claiming parity beyond the current single-line slice. |
| TextBox same-turn repaint for dirty key/focus turns | Implemented first slice | Existing focus/default/accelerator tests now assert repaint when a TextBox caret/focus visual changes; edit-command tests assert `keydown:...|repaint`; headless rapid typing/backspace proves queued turns mutate in order. | Burst/key-repeat drain policy still needs an oracle note. |
| TextBox caret/selection visuals | Implemented shaped-scene proof | `oxvba_reducer_cmdbutton::textbox_scene_emits_caret_and_selection_fill_primitives`, `textbox_selection_geometry_uses_shaped_caret_stops_and_recolors_text`. | Pixel-level MSForms selection/caret parity still needs live oracle evidence. |
| TextBox mouse drag selection | Implemented local path | `oxvba_reducer_cmdbutton::textbox_mouse_drag_extends_selection_through_mousemove_capture`, `headless_runner_showcase::runner_mouse_drag_selects_textbox_text_through_mousemove`. | Capture exact MSForms drag-selection edge behavior before claiming full parity. |

## Blockers And Unknowns

| Hazard area | Status | Exact blocker / follow-up |
|---|---|---|
| TextBox precise parity after the first slice | Partially implemented locally; oracle details still open. | `oxforms-zhz.4` implements a deterministic single-line caret/selection/edit-command slice; `oxforms-zhz.10` covers rapid key sequencing; `oxforms-zhz.11` wires shaped caret geometry, selected-text recolor overlay, and mouse-drag selection through headless tests. `oxforms-zhz.9` remains for horizontal scroll/clipped long-text behavior and setter side effects. Remaining blockers also include burst/post oracle behavior, multiline/IME/dead keys/undo/grapheme editing, and pixel-level caret/selection parity. |
| TextBox burst/post behavior | Unknown. | The headless runner can drain queued turns, but MSForms burst behavior under OS key-repeat or posted input still needs an oracle note before the reducer's drain policy is finalized. |
| CheckBox focus adorners/disabled/tab-stop side effects | Unknown. | `oxforms-zhz.5` must capture focus rectangle visibility, Space/Enter when disabled or `TabStop=False`, and what happens when a focused CheckBox is hidden or disabled by a handler/property setter. |
| MouseMove/capture routing | Implemented local TextBox drag path; oracle capture still needed. | `oxforms-zhz.11` routes MouseMove through bootstrap/headless/reducer capture and proves TextBox drag selection. Before broad pointer-heavy controls, capture MSForms MouseMove with and without capture, including move outside the control after MouseDown. |
| Double-click | Event signature known; ordering/cancel effect not captured for W009. | Capture `MouseDown -> MouseUp -> Click -> DblClick` ordering per supported control and whether `Cancel=True` changes the second click handling. |
| Wheel | No committed MSForms foundation fact. | First determine whether the target FM20 source interfaces expose a wheel event or whether wheel is only host/PAL input for controls such as ListBox/ScrollBar; capture or record a precise non-claim before list/scroll lanes. |
| Cursor application | Descriptor scaffold only. | `OxControlCore.MousePointer` records built-in cursor policy for routing, but no Windows host cursor application, custom `MouseIcon`, or visual cursor capture is claimed. Host cursor service proof belongs to the cursor/timer/service lanes. |
| Cancel button held repeat and Alt accelerator held repeat | Open follow-up. | `oxforms-uvh` remains the capture bead for held Escape/cancel and held Alt+accelerator repeat gating. |
| Runtime add/remove and focused-control deletion | Unknown. | No current `Controls.Remove` implementation or oracle fact. Reentrancy/lifecycle lane must decide whether deletion, hiding, or disabling a focused control transfers focus, fires `Exit`, or clears focus silently. |
| `.frx` binary/image materialization | Not implemented. | W006 selected `.frm` fixture intentionally has no `.frx` binary references. Image/binary `.frx` materialization is a W009 representative spike, not a current foundation claim. |
| Frame/container coordinate origin and clipping | Unknown for implementation. | Container coordinate/hit-test/tab-scope facts belong to the list/container/image/timer representative spike before any container lane consumes them. |

## Immediate Implementation Guidance

- `oxforms-zhz.4` consumed the existing TextBox key/change/focus-out facts and added
  local conformance evidence for the first single-line caret/selection/edit-command slice.
  It still must not claim precise MSForms TextBox parity for the remaining blockers above.
- `oxforms-zhz.5` may consume the CheckBox mouse/keyboard/dirty-focus facts, but
  it must add focus adorner, disabled, tab-stop, and cursor facts before closing.
- `oxforms-zhz.6` must not rely on `.frx` images, nested coordinates, list
  selection, or timer repeat rates from W006/W008; those are still explicit
  phase-0 spike facts.
- The current reducer interaction index may consume focus/tab/default/accelerator
  routing facts for existing controls, but spatial hit-test indexing and focused
  control deletion/hiding semantics are still open hazards.

## Clean-Room Note

All consumed evidence above comes from repo-owned fixture source, public
Excel/VBIDE automation, public Windows input, and worksheet exports already
committed under `docs/evidence`. No private Office internals or OxForms output
comparison are used as oracle evidence.
