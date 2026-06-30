# Hit-testing & the message loop: a Rust-offload design thought

Status: `DESIGN NOTE` (exploration; not a committed plan — see [Open questions](#open-questions-before-this-could-become-a-plan))
Context: follows the 2026-06-29 decision to move control interaction/behavior (the reducer) into
VBA and delete `oxforms-core` (memory `oxforms-reducer-home-decision`). This note answers a narrower
owner question: **is there a perf argument for putting hit-testing on the Rust side, and can
hit-testing + the primary message loop be offloaded to Rust while control code stays in VBA?**

This note was adversarially reviewed; §[Boundary](#the-hard-boundary-what-rust-must-never-do) and
§[Crossing contract](#the-crossing-contract-rust-routes-vba-reacts) exist specifically to resolve the
review's load-bearing objections (control-semantics leakage, move-coalescing breakage, and "is this
just a Rust reducer again").

## The distinction: geometric routing vs behavioral reduction

A reducer does two separable jobs per input:

1. **Geometric routing** — *which* node is under the pointer (the pick), hover/cursor tracking,
   move filtering, routing captured drags. Needs only geometry + a few per-node flags. The
   **high-frequency, hot** part (every mouse-move).
2. **Behavioral reduction** — *what happens* to control X: value transitions, the
   `MouseDown→Change→Click` / `Enter→BeforeUpdate→AfterUpdate→Exit` orderings, validation, vetoes,
   accelerators, default/cancel, focus/capture *state*. Control-specific.

The reducer-pivot decision is about (2). (1) is geometry. Putting (1) in Rust does not contradict
"VBA owns controls" **provided Rust routes by region + opaque flags, never by control type** — and
provided (2) stays entirely in VBA. The `OxForms.Surface` seam already reserves a deferred `HitTest`
crossing for this.

## How control semantics reach Rust without leaking types

The review's central objection is correct: a usable hit-test needs to know *enabled / visible /
focusable / hit-transparent / modal-scope* — and those are control semantics, not geometry. The
resolution is the same pattern the renderer already uses: **VBA, which knows the control type,
projects the semantic OUTCOME into control-agnostic per-node fields in the `ScenePatch`. Rust reads
fields, never types.** Just as VBA projects appearance into prims (the kernel never sees "CheckBox",
only a FillRect + glyph), it projects hit-semantics into node flags:

| Node field | Set by VBA from… | Rust uses it for… |
|---|---|---|
| `visible` (exists today) | the control's Visible | skip in the pick |
| `enabled` | the control's Enabled | a hit on a disabled node routes nowhere (or to its container) |
| `hit_mode` = `opaque \| passthrough \| none` | control type + transparency | `passthrough` lets the pick descend to the node below (transparent Label over a TextBox); `none` = decorative sub-part (glyph, focus ring, caption) is never a target |
| `control_id` (the interactive target) | the adapter's NodeId↔control map | resolve a hit to the *control*, not a sub-part node |
| `focusable` | focusable-by-type (Label = false) | focus-by-click target selection |
| `wants_move` | the control has a `MouseMove` handler / holds capture | decide whether a move must cross to VBA (see the crossing contract) |

These ride the existing `ScenePatch` (VBA sets them during the self-render it already does — **no new
crossing**, and they update for free whenever a control moves/hides/disables and re-renders). Modal
scope is an `active_root: NodeId` the backend confines the pick to (a subtree bound, still geometric).
This keeps the kernel control-blind: it does `pick(point) → control_id` + flag-filtering; VBA encodes
the meaning into the flags. (Open: the exact flag set + how `hit_mode`/`control_id` are carried in the
patch — listed below.)

## The linchpin: the resident Scene is the hit index

A `SceneNode` ([`../../crates/oxforms-pal/src/scene.rs`](../../crates/oxforms-pal/src/scene.rs))
already carries `id`, `bounds`, `z`, `transform`, `clip`, `children` — a z-ordered, clipped,
hierarchical region tree, produced as a side effect of rendering. With the flags above added, that
tree IS the hit index: no separate registration, no sync — when VBA re-renders, the index updates
with the frame. The render output doubles as the hit geometry; the flags carry the semantics.

## The crossing contract: "Rust routes, VBA reacts"

The real hazard is not hit-test compute — it is crossing into VBA for **every raw OS event**,
including high-frequency mouse-moves. The backend already owns the OS pump (§16). The contract:

- **Button & key events cross INDIVIDUALLY.** A `MouseDown`/`MouseUp`/key crosses once each, carrying
  the Rust-resolved `control_id` + control-local point. Rust does **not** merge them and does **not**
  synthesize `Click` — VBA's reducer produces `Click` and the `MouseDown→Change→Click` order, with
  full re-entrancy (a `MouseDown` handler may change state before `Click`). Buttons/keys are
  low-frequency, so a crossing each is cheap.
- **Moves are coalesced to frame rate and delivered ONLY to interested controls.** Rust does the pick
  + updates hover/cursor every move natively. A move crosses to VBA only when the target control
  `wants_move` (it has a `MouseMove` handler or holds capture), coalesced to ~frame cadence so drag
  thresholds and per-move cursor logic still see moves *within the control*. Moves over decorative or
  non-`wants_move` regions never cross. This is the offload's win: the hot path stays native; user
  `MouseMove` handlers still fire (at frame rate); nothing user code observes is silently dropped.
- **Capture & focus STATE stay in VBA.** VBA sets capture via an effect (`RequestCapture(control_id)`)
  in a handler; the backend *caches* that target to route subsequent moves/up (a §16.4-style
  producer/consumer seam — the backend consumes a target VBA produced, it does not own the state).
  Focus state + `Enter`/`Exit` ordering are VBA. The backend never decides capture/focus *policy*.

```
OS pump (Rust)  →  normalize  →  pick over the resident Scene + flag-filter (Rust, every event)
   ├─ move, target !wants_move → update hover/cursor in Rust; do NOT cross
   ├─ move, target wants_move / captured → coalesce to frame; cross (control_id, localX, localY)
   └─ button/key → cross individually (control_id, local pt, kind)
         → VBA behavioral reduce: value transition + ordered FM20 events + effects   (control code is VBA)
         → VBA self-render → resident Scene revision (+ updated hit flags)
   → backend Repaint (resident Scene → pixels)
```

## The hard boundary: what Rust must NEVER do

This is the line that keeps the design a *refinement* of the reducer-pivot, not a reversal of it.
Rust (the geometric router) does: the pick, flag-filtering, move-coalescing, hover/cursor, routing
captured moves, delivering resolved events. **Rust must never:** change a control value; order or
synthesize FM20 events (incl. `Click`); run validation/vetoes; *decide* enabled/focusable/modal
(it only reads VBA-set flags); or own focus/capture/value *state*. Those are behavioral reduction →
VBA. The §16 frame model already separates the backend pump from the reducer; this design assigns the
*geometric* pump work to Rust and keeps *all* behavior in VBA. If a change here would require Rust to
do any of the "never" list, it is out of scope.

## Prior art: Avalonia (v11 compositor) — verified from source

Avalonia is the closest mature analog (managed C# controls + a server-side compositor/render thread +
Skia). From the `AvaloniaUI/Avalonia` source:

- **Crossing = batched scene diff + readback.** `Compositor.Commit` serializes change-sets
  (`ICompositorSerializable`) via `BatchStreamWriter` into a `CompositionBatch` enqueued to the
  `ServerCompositor` — structurally our `ScenePatch`. Committed transforms/visibility flow *back* to
  the UI thread via a revision-picked **readback** (`ServerCompositionVisual.Readback {Matrix,
  Revision, Visible}`) — our Scene-revision seam (§16.4).
- **Hit-testing stays MANAGED, against a committed-scene snapshot; the render thread does NOT
  hit-test.** `CompositingRenderer : IHitTester` → `CompositionTarget.TryHitTest` walks the
  **UI-thread** `CompositionVisual` tree (the render-thread `ServerCompositionVisual` has *no*
  hit-test method). The geometry it tests is the render thread's **committed** per-visual data,
  published into a revision-picked MVCC **readback** (`{Matrix, Visible, TransformedSubtreeBounds}`) —
  so the scene literally carries per-node hit data (corroborating our per-node flags) and the UI
  thread reads it without crossing to the render thread. Acceleration is staged: a subtree-bounds
  AABB pre-reject, then a spatial index (`CompositionHitTestAabbTree`) only once a container has **≥32
  children** (linear below). The **geometry test and the control-semantic filter are separate**: the
  tester is explicitly documented to ignore `IsHitTestVisible`; `IsVisible`/`IsEffectivelyEnabled`/
  `IsHitTestVisible` ride in as a **managed predicate** (`InputExtensions`); per-visual precision is
  the recorded draw-ops or a control's `ICustomHitTest`. The hit-test is computed **once per
  dispatched event** and attached to it (`RawPointerEventArgs.InputHitTestResult`), reused downstream.
- **Move coalescing — without dropping points.** `RawEventGrouper` merges a burst of raw moves into
  **one** dispatched event that carries the skipped points (`GetIntermediatePoints`), so one hit-test
  fires per dispatched move while drag-threshold / ink handlers that need every point still get them.
  Coalescing drops *crossings/hit-tests*, never *points* — this is the pattern that makes move-offload
  safe.

**Lesson + caveat.** A render-threaded framework deliberately keeps the pick *with the controls*
(managed), accelerated by a retained scene + spatial index, rather than offloading it to the core —
and keeps control-semantic filtering managed-side (validating that those semantics belong with the
control author, i.e. our per-node flags are VBA-set). The decisive difference for us: Avalonia's
managed layer is **compiled C#** (a managed AABB scan is cheap); ours is **interpreted vm3** (a far
larger per-op constant), so "keep it managed" may not survive the interpreter — the benchmark
decides. Two corollaries: (a) before any Rust offload, try a **spatial index in VBA** (Avalonia's
actual move, not the naïve linear scan the benchmark measures); (b) unlike Avalonia we need **no
readback** — VBA authored the geometry it would hit-test, so it can pick against its own Scene
directly. Avalonia also settles the review's move-coalescing worry: coalescing is safe when the one
dispatched move **carries its intermediate points** — adopt that, never drop points. And note
Avalonia keeps *both* the geometry test and the semantic filter managed; our Rust-pick option splits
them (Rust geometry over the Scene + a VBA semantic predicate), a divergence justified only by the
interpreter.

## What lives where

| Concern | Owner |
|---|---|
| OS pump, raw input normalization, Repaint | Rust backend (unchanged, §16) |
| `pick(point)→control_id`, flag-filtering, hover/cursor, move-coalescing, routing captured moves | **Rust kernel** (control-agnostic) |
| Per-node hit flags (`enabled`/`hit_mode`/`focusable`/`wants_move`/`control_id`) | VBA (projected into the ScenePatch) |
| Value transitions, FM20 event ordering + `Click`, validation/vetoes, accelerators | **VBA** |
| Focus/capture **state**, control object model, self-render, theme | VBA |

## Tensions / edge cases

- **Sub-parts vs controls:** `hit_mode=none` on glyph/focus-ring/caption nodes; the control node
  carries `control_id`. Resolves "the focus ring is not a hit target."
- **Transparent overlaps:** `hit_mode=passthrough` lets the pick fall through to the node below.
- **Disabled-but-visible:** `enabled=false` node is skipped (or routes to its container, TBD by
  oracle).
- **Coordinate space:** Rust returns the control-local point by applying the control node's transform
  chain (uses `control_id`'s node, not a sub-part).
- **Move semantics (the review's sharpest point):** the `wants_move` + frame-coalesce contract is
  what keeps user `MouseMove` handlers, drag thresholds, and per-move cursor working. This MUST be
  proven with a fixture (a control counting moves; a drag-threshold) before committing — listed
  below.

## Benchmark: VBA hit-test on vm3 vs native Rust

Probe: `crates/oxforms-oxvba-adapter/tests/oxvba_lex_hittest_bench.rs` +
`vba/smoke/fixtures/lex_hittest_bench_form.cls` (`#[ignore]`d). Per control-count N, over a fixed
click stream on the **vm3 interpreter** (`enable_jit=false`): native Rust hit-test/op; VBA
`HitTestAll`/op (compute + one crossing); bare `Noop` crossing/op; `vba_compute ≈ vba − noop`.

Results (vm3 interpreter, `enable_jit=false`, iters=20):

| N | rust/op | vba/op | crossing (`noop`)/op | `vba_compute`/op |
|---|---|---|---|---|
| 25 | 315 ns | 9.7 ms | 5.6 µs | 9.7 ms |
| 50 | 560 ns | 35.0 ms | 5.7 µs | 35.0 ms |
| 100 | 1.1 µs | 130.4 ms | 7.8 µs | 130.4 ms |
| 200 | 1.8 µs | 569.5 ms | 8.7 µs | 569.5 ms |
| 400 | 6.1 µs | 2226 ms | 6.7 µs | 2226 ms |

### Results — the crossing is cheap; the VBA loop is O(N²)

Two findings, the second decisive and unexpected:

1. **The crossing is cheap and flat (~5–9 µs), independent of N.** The message-loop tax is negligible
   per event — so the offload's value is purely in *not crossing per raw move*; crossing once per
   *dispatched* event (button/key, or a coalesced move) is fine. Confirms recommendation 1.
2. **The VBA hit-test compute is O(N²), not O(N).** Doubling N ~quadruples the time; the *per-element*
   cost itself doubles with N (0.39 → 0.70 → 1.30 → 2.85 → 5.57 ms/element at N=25→400). The loop body
   is all O(1) `Long` ops **except dynamic-array element access (`arr(i)`)**, so by elimination
   `arr(i)` is **O(N)** on the vm3 interpreter → array loops are **O(N²)**. At N=100 a single hit-test
   is **130 ms** (vs Rust's 1.1 µs). This is a **general vm3 array-loop pathology**, not specific to
   hit-testing. An isolation probe confirms it directly: a single `arr(idx)` read is O(N) (~71 µs at
   N=25 → 1.1 ms at N=400), while the same loop without the array read is flat (~9 µs/iter).

**This supersedes the "is an indexed VBA pick fast enough" framing and BLOCKS the VBA-vs-Rust
decision.** With O(N) array access, even a spatial index *in VBA* is crippled (it too indexes arrays).
The fix belongs in vm3, not OxForms — filed as
[`../handovers/HANDOVER_OxVba_vm3_dynamic_array_access_perf.md`](../handovers/HANDOVER_OxVba_vm3_dynamic_array_access_perf.md)
per `oxvba-vm3-handover-policy`. **Re-benchmark after the vm3 fix**, then choose indexed-VBA (the
Avalonia default) vs a Rust pick on representative numbers. (These are interpreter numbers; a JIT path
may differ — but an O(N²) algorithm is a JIT-independent problem.)

### Update — post-fix re-benchmark (OxVba `30099710`, "round 2", 2026-06-30)

The vm3 fix landed in two rounds: round 1 (`019a39df`) made *general* dynamic arrays O(1) but left
**class-field** arrays — exactly what this bench uses (`Private mX()` in a class) — O(N); the OxForms
probe caught that, OxVba reopened (bead `bd-us4v`, commit `20225701`) and shipped **round 2
(`30099710`) = O(1) class-field element access**. Re-run on the same probe (min-of-9 isolation for
per-read; iters=20 for `HitTestAll`):

| N | per array read — round 2 | per array read — round 1 | `HitTestAll`/op — round 2 | per-element — round 2 |
|---|---|---|---|---|
| 50 | 3.75 µs | 25.6 µs | 1.65 ms | 32.8 µs |
| 100 | 4.04 µs | 42.4 µs | 3.22 ms | 32.1 µs |
| 200 | 3.88 µs | 113.5 µs | 6.65 ms | 33.2 µs |
| 400 | 3.95 µs | 173.0 µs | 13.20 ms | 33.0 µs |
| 800 | 3.94 µs | 322.2 µs | — | — |

per-read is flat ~3.9 µs across a 16× N sweep → **O(1) element access**; `HitTestAll` per-element is
flat ~33 µs → the loop is now **O(N)** (was O(N²)). **Finding 2 above is superseded and the block on
the VBA-vs-Rust decision is lifted** (handover RESOLVED). What the numbers now say: the array
pathology is gone, but the **interpreter per-op constant remains** (~8.5 µs/iter loop overhead +
~3.9 µs/array read), so a *naïve linear* VBA scan is ~33 µs × N (≈3.2 ms at N=100) — fine for
click-frequency, too slow for per-move at high N. **What is measured stops here:** only the linear scan
was benchmarked. The plausible next lever is an **index** (Avalonia's move): a spatial index should cut
the per-pick candidate set toward O(1) — but this is *not yet measured*, and three costs decide it:
(i) no indexed pick is implemented in the fixture; (ii) the index *build/maintenance* runs in the same
interpreter (~8.5 µs/iter), so an O(N) per-frame rebuild over 100–400 controls is itself milliseconds
unless the index is built once per layout and held static between layouts; (iii) the per-frame budget
it must fit (≈16.6 ms at 60 Hz, less the render share) has not been measured against. So an indexed-VBA
pick is **plausible but unproven** — the recommendation below keeps it *provisional*, not settled.

## Recommendation (post array-fix)

1. **Independent of the hit-test numbers:** the backend should own the pump and **not cross into VBA
   on every raw move** — coalesce + deliver only to `wants_move` targets. Crossing per raw move is the
   clearest waste; this stands even if VBA hit-test is cheap.
2. **The pick** has a progression, not a binary: (a) naïve VBA linear scan → (b) **VBA scan + a
   spatial index (AABB)** — Avalonia's actual choice, keeping the pick managed — → (c) the pick in
   Rust over the Scene index. Avalonia (compiled managed) stops at (b); we may need (c) only because
   vm3 is interpreted. Gate on the benchmark per §4.6: if an indexed VBA pick is fast enough
   per-frame, stay managed (b); if interpreted cost dominates even indexed, offload to Rust (c). (c)
   reuses geometry the render already produces and *simplifies* the VBA reducer, but per the Avalonia
   precedent it is the fallback, not the default. **PROVISIONAL (post round-2 re-benchmark,
   `oxforms-bqr`): planned default = (b), an indexed VBA pick — not yet firm.** The re-benchmark removed
   the blocker (array access O(1); linear scan O(N) at ~33 µs/control) and the Avalonia precedent
   favours keeping the pick managed, so (b) is the working assumption. It is **not settled**, because
   the deciding numbers are unmeasured: no indexed pick exists in the fixture, the interpreter index
   build/maintenance cost is unquantified, and nothing has been measured against a stated per-frame
   budget (≈16.6 ms at 60 Hz, less render). A firm (b)-vs-(c) decision needs an indexed-pick +
   per-frame benchmark with intermediate-point move traces (Open question 3) — increment-2 work, for
   which `oxforms-bqr` stays open. The Rust geometric pick (c) remains the documented fallback.
   Crucially, **the choice is a localized ROUTE-stage detail: either home leaves the message-handling
   pipeline/contract (the spec) unchanged**, so it does not gate the reducer port.
3. **Sequencing:** this does **not** block the reducer port. Port control *behavior* to VBA first
   (bead-driven); land the Rust geometric router as a separate kernel slice when the numbers + the
   move-semantics fixture justify it. Per `oxvba-vm3-handover-policy`, any vm3 limitation found while
   exercising the VBA path is an OxVba handover, not a workaround.

## Open questions before this could become a plan

1. **The flag set + patch encoding.** Pin the exact per-node fields (`enabled`/`hit_mode`/`focusable`/
   `wants_move`/`control_id`/`active_root`) and how they ride the `ScenePatch` — and confirm VBA can
   set them at render time with no extra crossing.
2. **The move contract, proven not to break user code.** A fixture proving a control's `MouseMove`
   handler still fires (at frame rate), a drag threshold still trips, and per-move cursor logic still
   works under coalescing. The burden is showing it does NOT break, not that the crossing is slow.
3. **Benchmark completeness.** Per-frame numbers (not just per-op), a JIT run alongside the
   interpreter, and a realistic move-trace to quantify the coalescing saving.

Until 1–3 are resolved this is exploration, not a committed bead.
