# W008 — Native FM20-named Event Breadth and ByRef Return* Mutation

Epic: `oxforms-esq`
Depends on: `W006_control_implementation_rollout` (CLOSED — the oracle orderings),
`W007_production_runtime_vertical_slice` (CLOSED — the proven dispatch gate).

## Purpose

Carry the W006 live MSForms oracle orderings into **full native FM20-named event
dispatch** through the OxForms runtime. This is implementation/verification work,
not new architecture: the runtime already dispatches `FireVbaEvent` effects by
native event name and the dispatch mechanism is proven.

## The dispatch mechanism is already proven (not an OxVba blocker)

- `oxforms-4pn.2` (W007) committed
  [`crates/oxforms-oxvba-adapter/tests/oxvba_w006_native_fm20_event_gate.rs`](../../crates/oxforms-oxvba-adapter/tests/oxvba_w006_native_fm20_event_gate.rs):
  native `Click`/`MouseDown`/`MouseUp`/`MouseMove` dispatch through
  `RaiseEvent` → `WithEvents` with correct `Integer`/`Single` scalar args.
- [`HANDOVER_OxVba_w005_fm20_event_raise.md`](../handovers/HANDOVER_OxVba_w005_fm20_event_raise.md)
  is **Resolved**; the error-424 fault does not reproduce.
- `crates/oxforms-oxvba-adapter/src/runtime_runner.rs` dispatches `FireVbaEvent`
  by native name via `ProjectRuntimeSession.invoke_member_values`. The W005
  generic `Dispatched` carrier is **absent from `src/`** (test fixtures only).
- The blocker note
  [`native-fm20-event-dispatch-blocker.md`](../evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md)
  is `resolved` (superseded by `oxforms-4pn.2`).

## Lanes (child beads)

| Bead | Lane |
|---|---|
| `oxforms-esq.1` (A) | Prove or precisely block ByRef `MSForms.Return*` (Cancel/KeyCode) helper-mutation readback through the RaiseEvent path — the one detail that could still surface a genuine OxVba handover. Scalar IN-args are proven; ByRef object mutation-readback is not. Do this FIRST. |
| `oxforms-esq.2` (B) | Wire the remaining native named-event surface (Change for TextBox/CheckBox, KeyDown/KeyUp/KeyPress, focus Enter/Exit, QueryClose, lifecycle) with repo-owned WithEvents fixtures. Blocked on A (ByRef mutation either consumed or kept a non-claim). |
| `oxforms-esq.3` (C) | Conformance-test the dispatched event orderings against the committed W006 oracle captures (CheckBox `Change`-before-`Click`; `MouseUp`→`Change`→`Click`; nested-modal `QueryClose(CloseMode)`→`Terminate`, Hide-no-Terminate; DoEvents reentrancy depth 2). Blocked on B. |

W006 oracle source captures (`docs/evidence/W006_control_implementation_rollout/captures/`):
`checkbox-click-change-20260627T162407Z`, `nested-modal-lifecycle-20260627T141239Z`,
`doevents-yield-20260627T161225Z`, `terminate-lifetime-20260627T144316Z`.

## Status

- **`oxforms-esq.1` (A): PROVEN** — gate
  [`crates/oxforms-oxvba-adapter/tests/oxvba_w008_byref_return_mutation_gate.rs`](../../crates/oxforms-oxvba-adapter/tests/oxvba_w008_byref_return_mutation_gate.rs)
  shows a `Return*` helper object's `.Value`, mutated by a `WithEvents` handler,
  is read back by the raiser through the OxVba `RaiseEvent`/`invoke_member_values`
  path on the same shared instance (KeyDown swallow `65`→`0`; QueryClose veto
  `0`→`-1`; no-handler control stays `65`). **No OxVba handover needed** — the
  `Cancel`/`KeyCode` helper-mutation mechanism is supported. Non-claims: true VBA
  ByRef-SCALAR copyback and the real `MSForms.ReturnInteger`/`ReturnBoolean` COM
  types crossing the foreign-COM boundary (vs the repo-owned `W008ReturnValue`
  stand-in) are not exercised. `oxforms-esq.2` (B) is unblocked.
- **`oxforms-esq.2` (B): COMPLETE** — every targeted FM20 event was wired through
  the then-current `crates/oxforms-oxvba-adapter/src/runtime_runner.rs`
  `dispatch_fire_vba_event`, each reaching a real `WithEvents` handler via the
  control's `Perform*` member (never the W005 `RaiseDispatch` carrier), proven by
  the historical RuntimeRunner tests in
  `oxvba_w007_runtime_runner.rs`. Current-code note: `runtime_runner.rs` and that test file were
  deleted in `oxforms-ih6`; equivalent coverage now lives in the VBA-reducer adapter tests such as
  [`oxvba_reducer_cmdbutton.rs`](../../crates/oxforms-oxvba-adapter/tests/oxvba_reducer_cmdbutton.rs)
  and [`oxvba_runtime_greeter.rs`](../../crates/oxforms-oxvba-adapter/tests/oxvba_runtime_greeter.rs):
  - `Click` → `PerformClick`, `Change` → `ApplyUserText` (W007, prior).
  - `KeyDown` → `PerformKeyDown`, `KeyUp` → `PerformKeyUp`, `KeyPress` →
    `PerformKeyPress` — each reading back the post-handler `KeyCode`/`KeyAscii`
    through the `MSForms.ReturnInteger` helper (consuming the esq.1 mechanism in the
    real runtime). The reducer's `key_event_arguments` emits dispatch-ready `Shift`
    (mask) + mutable `KeyCode` (VK); the KeyPress char-code arg was renamed
    `key_ascii_placeholder` → `KeyAscii`. Commits `d6a5ae5` (KeyDown), `dcb5699`
    (KeyUp), `331f88f` (KeyPress).
  - `MouseDown` → `PerformMouseDown`, `MouseUp` → `PerformMouseUp` (clean Button/
    Shift/X-Y args, X/Y as Single); a form-background press (no control target) is
    acknowledged. New control events added to CommandButton/TextBox/Label. Commits
    `dcfeec7` (MouseDown), `dcb5699` (MouseUp). The W007 mouse fence was split
    accordingly (MouseDown/MouseUp/KeyPress now assert native dispatch).
  - W005 trace-replay golden + interaction-comparison hash chain regenerated for the
    KeyDown/KeyPress reducer-arg changes; floor + 21/21 evidence checks green each
    increment.
  - **focus `[Exit]`** → `PerformExit`, reading back the post-handler `Cancel` via the
    `MSForms.ReturnBoolean` helper — the *other* half of esq.1 in the real runtime.
    The reducer now emits `Exit` on the control losing focus before `TransferFocus` at
    both transition sites (`reduce_mouse_down`, `reduce_tab_key_down`); the legacy W005
    event-dispatch carrier maps `Exit` → `RaiseDispatch` so its smoke test stays green.
    Commit `a9d54aa` (W005 golden + hash chain regenerated for the inserted `Exit`
    effects).
  - **form-level `QueryClose` + lifecycle** → the form module's `Perform*` surface
    (owner-ratified: five `Perform*` members, not a single dispatcher). The runner
    retains the form object (`form_module`) and routes form-targeted events
    (`control_id == None`) to `dispatch_form_event` before the control lookup:
    `QueryClose` → `PerformQueryClose(CloseMode)` reading back the post-handler `Cancel`
    (Integer, via `ReturnInteger`; the fixture vetoes CloseMode 0, allows 1);
    `Initialize`/`Activate`/`Deactivate`/`Terminate` → the matching no-arg `Perform*`.
    The reducer's missing `Terminate` emission was added. Form events use a sentinel
    `<form>` control_id in the dispatch record.
  - **Non-claims / follow-ups (not blockers):** focus `Enter` is not emitted/dispatched
    (needs a new control `Enter` event — a documented gap, not in the targeted set);
    every Return* readback (KeyCode/KeyAscii/Cancel) is **recorded** in
    `NativeDispatchRecord.returned`, not yet **folded back into reducer state** (a
    swallowed key/char or vetoed Exit/QueryClose does not yet change downstream reducer
    behavior — the fold-back loop is the natural next step).
  - **Explicit non-claims (all wired events):** Return* readbacks are **recorded**,
    not yet **folded back into reducer state** (a swallowed key/char or vetoed
    Cancel does not yet change downstream reducer behavior); `KeyCode` is the OS
    virtual key (faithful for standard keys; exotic/platform VK variance untested);
    readback rides the repo-owned `ReturnInteger`/`ReturnBoolean` stand-ins, not the
    real `MSForms.*` COM types or literal VBA ByRef-scalar copyback (per esq.1).

## Non-claims (preserved from W006/W007)

No full UserForm/control event parity; no pixel-perfect rendering; no
IME/composition or dead-key (`oxforms-0a0.18` capability blocker); no runtime
accessibility (design-gated). Native event dispatch is claimed only for the
wired and oracle-verified subset — not exhaustively.

## Closure Conditions

W008 closes only when:

1. `oxforms-esq.1`/`.2`/`.3` are each completed or precisely blocked with evidence;
2. any native-event breadth claim is backed by a wired WithEvents fixture test
   AND conforms to a W006 oracle ordering, or carries an explicit blocker;
3. ByRef `Return*` mutation is proven through the dispatch path or a precise OxVba
   handover names the exact failing shape/baseline/call path;
4. the generic `Dispatched` carrier stays out of the runtime path;
5. register/workset/beads agree about remaining scope and next work.

## Verification Shape

| Surface | Check |
|---|---|
| Docs/workset/register | read-through, path/link scan, `git diff --check` |
| Bead graph | `br dep cycles`, `br ready --json`, `br list --json` |
| Native dispatch | targeted OxVba/Rust gate + fixture tests (WithEvents) |
| Oracle conformance | reducer/runtime ordering asserted against the W006 captures |
| Floor | `cargo fmt --check` + `cargo clippy --workspace --all-targets -- -D warnings` + `cargo test --workspace` + `tools/Run-EvidenceChecks.ps1` |
