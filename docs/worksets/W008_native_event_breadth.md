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
