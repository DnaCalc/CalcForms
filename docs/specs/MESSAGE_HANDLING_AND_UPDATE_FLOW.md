# Forms-core message handling & update flow

Status: `DESIGN SPEC` (engineering spec for the reducer pivot; increment 0 of the ladder below).
Revised after an adversarial review — routing completeness, the sync-effects tier, state location, and
the conformance/deletion/modal gates below are the review's load-bearing fixes.
Realizes: the 2026-06-29 decision to move the control reducer/interaction into VBA and delete
`oxforms-core` (memory `oxforms-reducer-home-decision`), shaped by
[`HIT_TEST_AND_MESSAGE_LOOP_OFFLOAD.md`](HIT_TEST_AND_MESSAGE_LOOP_OFFLOAD.md), the §16 frame model in
[`RENDERING_ARCHITECTURE.md`](RENDERING_ARCHITECTURE.md), and the now-resolved vm3 array-access work
(`HANDOVER_OxVba_vm3_dynamic_array_access_perf.md`: element access is **O(1)** as of OxVba round 2,
`30099710`; RESOLVED). The design below is deliberately **independent of array-access cost** — it holds
whether access is O(1) or not — so this resolution does not change it.

> **STATUS — LADDER COMPLETED, `oxforms-core` DELETED (epic `oxforms-ih6`, delete commit `17785f2`;
> epic closed `08084fc`).** The migration ladder below ran to completion. Control behavior now lives
> ENTIRELY in VBA: `OxInteractionManager` owns interaction state/routing behind the stable
> [`vba/oxforms/OxReducer.cls`](../../vba/oxforms/OxReducer.cls) facade, plus the four control
> classes implementing the expanded `IOxControl` contract. The Rust side is the thin
> driver `OxRuntime` in
> [`crates/oxforms-oxvba-adapter/src/runtime.rs`](../../crates/oxforms-oxvba-adapter/src/runtime.rs):
> it holds the OxVba session + form-document, calls the VBA reducer facade
> (`Dispatch`/`DispatchKey`/`DispatchChar`/`DispatchDrop`), drives lifecycle (`Perform*` /
> `PerformQueryClose`), pushes the clipboard (`SetClipboardText`), and drives the VBA self-render
> (`Render`). There is **no Rust reducer** in the loop — `reduce()`/`FormState`/`ReducerOutput`/
> `RuntimeRunner` are gone with the crate. The fold-back machinery and the `*Completed` UiEvent
> variants are retired; vetoes/Return\* are handled INLINE in VBA, as the design predicted. Conformance
> coverage of the FM20 orderings was re-homed onto the VBA reducer:
> `crates/oxforms-oxvba-adapter/tests/oxvba_reducer_cmdbutton.rs` (28 tests) +
> `oxvba_runtime_greeter.rs`.
>
> **GATE NOT SATISFIED — `.frm` loader / `trace_replay` home was DROPPED, not settled.** The ladder's
> step-3 gate "settle the `.frm`/`trace_replay` home" (and the "What happens to `oxforms-core`" open
> item below) was **not** met by re-homing those capabilities — they were **dropped** with the crate.
> The `.frm` loader (`materialize_form_from_frm`) and `trace_replay.rs` are gone; the `fixtures/frm/*`
> files remain on disk but nothing in Rust reads them. The committed trace-replay goldens under
> `docs/evidence/W00{5,6}_*/trace-replay/` are now **frozen**: there is **no regeneration path**, since
> the code that produced them was deleted. Treat them as historical artifacts.
>
> Everything below this banner is the original DESIGN SPEC, preserved as-is for the contract and the
> historical ladder; where it speaks of `oxforms-core`/`RuntimeRunner`/`reduce()` as present or of the
> deletion as a future gated step, read it against this banner.

## Principle

Two separable jobs, split by the architecture principle (the vm3 perf finding reinforced this but does
not drive it — the design below is **independent of array-access cost**; assume OxVba makes element
access O(1)):
- **Geometric routing** (which control under the pointer; when to bother VBA) is control-agnostic and
  the hot path → **Rust kernel/backend**.
- **Behavioral reduction** (what a control does) is control-specific → **VBA** (the OxForms library),
  which also **owns all reducer state** (the `FormState`-equivalent: focus owner, capture owner, per-
  control value/dirty, validation, pending paste, modal depth).

The Rust side is a pump + router + rasterizer that never decides control behavior and never owns
behavioral state. Its only routing-relevant state is the **capture target** (below) and the resident
Scene (geometry + VBA-projected flags).

## The pipeline

```
[OS] -> PUMP (Rust backend) --- normalize raw OS input -> UiEvent (oxforms-pal UiEventKind)
     -> ROUTE (Rust kernel) --- positional events: pick over the Scene + per-node flags -> target;
                                non-positional: forward to VBA (it routes by its own state);
                                capture active: route to the captured target; coalesce moves
     -> REDUCE (VBA) --------- the reducer (owns FormState): ordered FM20 events, vetoes inline,
                                value transitions; emits Effects
     -> EFFECTS (VBA->Rust) -- immediate effects = synchronous host calls; deferred effects =
                                requests whose completions return as UiEvents; render = ScenePatch
     -> REPAINT (Rust backend) resident Scene revision -> pixels (§16); never enters VBA
```

## Stage contracts

### 1. PUMP — Rust backend (`oxforms-pal-win`, exists)
Owns the OS loop; normalizes raw input into the `oxforms-pal` `UiEvent` taxonomy (`UiEventKind`). No
control knowledge.

### 2. ROUTE — Rust kernel (NEW; control-agnostic). Routing is **by event class**:

- **Positional (`MouseMove/Down/Up/DoubleClick/Wheel`, `DragOver/DropOrPaste`):** geometric `pick`
  over the resident Scene (`SceneNode` `bounds/z/transform/clip/children`) + the per-node hit flags
  VBA projects into the `ScenePatch` (no new crossing): `control_id`, `hit_mode`
  (`opaque|passthrough|none`), `enabled`, `visible`, `wants_move`, `active_root` (modal scope).
  Resolves a `ResolvedInput { target_control_id, kind, local_point, modifiers, intermediate_points? }`.
  **Move coalescing preserves intermediate points** (Avalonia's `GetIntermediatePoints` — coalesce
  *crossings*, never *points*); a move crosses only to a `wants_move` target.
- **Keyboard (`KeyDown/Up`, `CharacterInput`) + form-global (accelerators, Tab):** there is no
  position, so the router does **not** resolve a target and holds **no focus state**. It forwards the
  event into the VBA reducer, which routes it to **its** focus owner / matches it against **its**
  accelerator + tab maps (all O(1), see REDUCE). This is what makes the router control-agnostic for
  keyboard — it never reads focus/tab/accelerator state.
- **Lifecycle / non-positional (`CloseRequest`, `Resize`, `DpiChanged`, `Activate/Deactivate`,
  `TimerFired`, `ServiceResult`, `WindowShown`, completions, …):** bypass the pick; forwarded to the
  VBA reducer with the form as target (from the `UiEvent`'s own target metadata).
- **Capture (the router's only behavioral-routing state):** while a drag capture is active, mouse
  move/up route to the **captured control** rather than the pick. The capture target is set/cleared
  **synchronously** via the host seam (the `CaptureMouse`/`ReleaseMouse` immediate effects, below), so
  there is no stale-cache race: the target is current before the dispatch that needs it returns.

### 3. REDUCE — VBA (NEW home; the reducer pivot)
The OxForms VBA library exposes the reducer entry the runtime calls per routed event (working name
`OxRuntime.Dispatch(kind, controlId?, localX, localY, modifiers)`). It:

- **owns the reducer state in VBA** (focus owner, capture owner, per-control value/dirty, validation,
  pending paste-commit, modal depth) — there is no Rust-side `FormState` after the pivot;
- routes keyboard to its focus owner, matches accelerators/Tab via O(1) maps (below), and produces the
  ordered FM20 events (the oracle-confirmed `MouseDown→Change→Click`, `Enter→BeforeUpdate→AfterUpdate→
  Exit`) by calling the control's `Perform*`/raise members;
- **handles Return\*/veto INLINE — fold-back is retired.** Because the reducer *is* VBA and owns the
  state, raising an event, reading the mutated `Return*` helper, and continuing the reduction all
  happen in one synchronous call stack. Worked example (KeyDown swallow):

  ```vba
  ' inside OxRuntime.Dispatch for a KeyDown:
  newCode = ctl.PerformKeyDown(code, shift)   ' raises KeyDown; handler may set KeyCode.Value = 0
  If newCode = 0 And KeyMayProduceCharacter(code, shift) Then
      mState.SwallowNextChar = True           ' VBA state; no round-trip
  End If
  ' ... a later Dispatch(CharacterInput):
  If mState.SwallowNextChar Then mState.SwallowNextChar = False : Exit Sub   ' suppressed inline
  ```

  The same shape covers the `Exit`/`BeforeUpdate` focus veto (keep focus in VBA state) and the
  `BeforeDropOrPaste` veto (drop the pending paste). This **removes** the Rust `dispatch_with_foldback`
  + the synthesized `*Completed` UiEvents (`FocusValidationCompleted`, `KeyDownSwallowed`,
  `BeforeDropOrPasteCompleted`) — they existed only because the Rust reducer could not call VBA
  mid-reduce.
- emits **Effects** (stage 4) and re-renders the changed control(s).

**Perf constraint (good design regardless of the array fix).** A `Dispatch` must be **O(1) in the
control count** — not because element access is O(N) (assume OxVba makes that O(1)) but because a
per-input O(N) *iteration* over all controls is wasteful at the interpreter's per-op constant
(~9 µs/iter, measured even with no array access). So the reducer uses O(1)-lookup structures: control
lookup by id via a **keyed `Collection`/`Dictionary`** (hashed key, not a linear scan); tab traversal
via a **prebuilt next/prev link per control**; accelerator dispatch via a **form-level accelerator
map** (`key=Alt+X → control_id`); default/cancel buttons held as **direct references**. This holds
whether or not element access is O(1).

### 4. EFFECTS + UPDATE — VBA → Rust, in two tiers
The host-effects seam is a new injected `OxForms.Host` object, **modelled on `OxForms.Surface`** —
which already proves a *synchronous* VBA→Rust call that returns a value (`Surface.MeasureText`
returns `id:advance:…`). Effects split by whether the reducer needs the result mid-dispatch:

- **Immediate (synchronous host call, returns inline):** `SetCursor`, `CaptureMouse`/`ReleaseMouse`
  (sets the router's capture target before returning), `ClipboardGet` (returns the text so a paste
  reduces inline — no completion event). These must apply before the next input.
- **Deferred (request now, completion later as a `UiEvent`):** `ShowFormModal`/`Modeless`,
  `StartTimer`/`StopTimer`, `HideForm`/`CloseForm`/`UnloadForm`, `HostCapabilityRequest`,
  `MaterializeForm`. Completions return as the existing `UiEvent`s (`ServiceResult`, `WindowShown`,
  `PumpFrameExited`, `Unloaded`, …) fed into the next `Dispatch`.
- **Render:** a visual change re-renders the affected subtree into an `OxSceneBuilder` `ScenePatch`
  and `SubmitPatch`es it → a new resident Scene revision (§16 Re-render). Exists today.

Today's `EffectKind` (in `oxforms-core`) becomes the **vocabulary of this contract**, not a Rust
reducer output; the canonical definition can live in `oxforms-pal` (control-agnostic) or as the host
seam's schema (decide in inc. 2).

### 5. REPAINT — Rust backend (§16, unchanged)
The window consumes resident Scene revisions → pixels. Never enters VBA.

## State ownership

| State | Owner |
|---|---|
| OS loop, raw input | Rust backend |
| Resident Scene + per-node hit flags | Rust kernel (authored by VBA via ScenePatch) |
| Hover/cursor, move coalescing | Rust kernel |
| **Capture target** (routing) | Rust kernel cache — set/cleared **synchronously** by Capture/Release effects |
| **focus owner, value, dirty, validation, pending-paste, modal depth, tab order, accelerators** | **VBA** (authoritative; the reducer state) |
| FM20 event ordering, vetoes, accelerators, default/cancel | **VBA** |
| Control object model, self-render, theme | **VBA** |

No focus/value/validation cache exists in Rust — keyboard is routed *inside* VBA by its own focus
owner, so there is nothing to keep coherent across the boundary except the synchronously-set capture
target.

## Conformance migration (gate before deleting `oxforms-core`)

Today the W005/W006/W008 oracle orderings are asserted as **pure Rust reducer** tests
(`reduce(FormState,UiEvent)->ReducerOutput` goldens in `trace_replay.rs` + the `oxvba_*` conformance
tests). Deleting `oxforms-core` removes `reduce()`, so those would lose coverage. Required:

- The VBA reducer exposes an inspectable **state/effect summary** (e.g. `OxRuntime.GetStateSummary` +
  an emitted-effect log) so the same oracle orderings (event order, effects, focus/validation stage)
  are re-asserted against `OxRuntime.Dispatch` via OxVba integration tests, re-homed from the pure-
  reduce goldens.
- A **conformance bead** must prove the VBA reduce path reproduces the committed W006/W008 orderings
  (or document an owner-blessed divergence, re-traced as a bead) **before** `oxforms-core` is deleted.
- No silent coverage loss: each W005/W006 test is explicitly re-homed or retired-with-reason.

## Modal pump coordination (open — gates the modal increment, not increment 1)

A modal `Show` from a VBA handler enters a **nested pump** (§16; `EnterModalFrame`), which dispatches
input while the outer handler is suspended — i.e. dispatch reentrancy at handler-depth ≥2. This must
not violate the frame model's "re-render between handler returns, never synchronously mid-handler"
rule. This spec does **not** resolve it; options to settle when the modal increment is scheduled: (a)
the pump stays Rust/backend and serializes nested input through the same queue, deferring re-render to
the modal frame boundary; (b) re-render is scoped per modal frame. **Increment 1 is a single,
non-modal control and is unaffected**; the modal model is a prerequisite only for the modal-bearing
increment.

## What happens to `oxforms-core` (gated, not assumed done)

Deletion is the *end state*, gated on the replacements existing + conformance migrated — it is not a
single step:
- `reduce` + `FormState` + control state/toggle/validation/two-stage logic → **VBA** (inc. 1, 3).
- `EffectKind`/event-arg vocabulary → the **effects contract** (inc. 2); canonical home TBD (pal vs
  host-seam schema).
- `UiEventKind` already in `oxforms-pal` — **stays**; the `*Completed` fold-back variants retire with
  the fold-back machinery (inc. 3).
- `.frm` loader + form materialization + `trace_replay` → VBA, or a minimal kept Rust helper (D6:
  binary stays Rust). **Open** — pinned in inc. 1/3. Until then `oxforms-core` stays.

## Migration ladder

0. **This spec** (the contract).
1. **VBA reducer skeleton** — `OxRuntime.Dispatch` for ONE non-modal control (CheckBox/button)
   receiving a `ResolvedInput`, owning its state in VBA, producing ordered FM20 events + a render on
   vm3, with **inline** veto/Return\* handling (proving fold-back is unneeded). Grows the
   `oxforms-lex` spike. Blocked on: defining the VBA control-model that publishes the hit flags.
2. **Rust geometric router + host-effects seam** — `pick`/coalesce/route over the Scene + flags; the
   `OxForms.Host` seam (immediate + deferred tiers); rewire `oxforms-bootstrap` to `input → route →
   Dispatch → effects → render → repaint`.
3. **Migrate the 4 controls + conformance + delete `oxforms-core`** — re-home the W005/W006/W008
   orderings against the VBA reducer (conformance bead), settle the `.frm`/`trace_replay` home, then
   delete the crate + retire the fold-back machinery.
4. then **W009 control breadth** on this foundation.

Each increment: floor green + the bead loop; any vm3 limitation hit → an OxVba handover, never a
workaround (`oxvba-vm3-handover-policy`).

## Open questions / per-increment blockers

- **inc. 1 blocked on:** the VBA control-model that publishes routing flags into the ScenePatch; the
  reducer's O(1) state structures (keyed Collection / tab links / accelerator map).
- **inc. 2 blocked on:** the effects vocabulary home + wire shape; the `ResolvedInput` + hit-flag
  fields and their ScenePatch encoding (pin against an oracle); the immediate-vs-deferred effect split.
- **inc. 3 blocked on:** the conformance migration proven; the `.frm` loader / `trace_replay` home.
- **modal increment blocked on:** the modal-pump reentrancy model (above).
- vm3 element access is now **O(1)** (OxVba round 2, `30099710`; handover RESOLVED). The design is
  access-cost-independent, so this does not change it — it only informs the inc-2 hit-test-home choice
  (Rust pick vs indexed VBA pick), which is **provisional** (planned default = indexed VBA pick,
  pending an indexed-pick + per-frame benchmark; `oxforms-bqr` open). Both homes leave the
  pipeline/contract identical.
- Out of scope here: list/selection controls, container nested-coordinate model (W009/W010),
  pixel-perfect rendering, the array-perf fix itself (OxVba).
