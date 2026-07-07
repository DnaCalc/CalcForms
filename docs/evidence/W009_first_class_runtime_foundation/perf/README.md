# W009 TextBox Repeat/Paste Responsiveness

Beads: `oxforms-aghp`, `oxforms-zhz.36`, `oxforms-zhz.37`

This directory records a host-specific baseline for TextBox repeat and repeated
paste behavior after the visible W009 TextBox smoke proved that both the
showcase and materialized `.frm` routes are live.

Generate the baseline JSON report with:

```powershell
$env:OXFORMS_TEXTBOX_PERF_OUT = "$PWD\docs\evidence\W009_first_class_runtime_foundation\perf\w009-textbox-repeat-paste-baseline-20260704.json"
cargo test -p oxforms-headless-runner --test headless_textbox_perf textbox_repeat_paste_baseline_writes_json_report -- --ignored --nocapture
```

Generate the paste attribution JSON report with:

```powershell
$env:OXFORMS_PROFILE_TIMINGS = "1"
$env:OXFORMS_TEXTBOX_ATTRIBUTION_OUT = "$PWD\docs\evidence\W009_first_class_runtime_foundation\perf\w009-textbox-paste-dispatch-attribution-20260704.json"
cargo test -p oxforms-headless-runner --test headless_textbox_perf textbox_paste_dispatch_attribution_writes_json_report -- --ignored --nocapture
```

The harness runs headlessly over the same `OxRuntime` + VBA `OxReducer` +
`OxForms.Surface` path used by the visible bootstrap, with
`RepaintPolicy::VisibleBootstrap` so plain text keydown/keyup turns do not cause
extra headless-only renders. It records per-turn `dispatch_us`, runner
`render_us`, `snapshot_us`, service effects, final TextBox state, and cumulative
surface call counts. `dispatch_us` includes the VBA reducer call and any
reducer-owned repaint, so it is the current combined bucket for TextBox mutation,
VBA event handling, self-render, and text shaping.

## Baseline

Artifact:
`w009-textbox-repeat-paste-baseline-20260704.json`

| Scenario | Rows | Repaints | Surface calls | Dispatch p50 us | Dispatch p95 us | Max us | Snapshot p95 us |
|---|---:|---:|---:|---:|---:|---:|---:|
| `burst_typing_40_chars` | 120 | 40 | 89 | 3873 | 97633 | 130664 | 188 |
| `held_char_repeat_30` | 61 | 30 | 69 | 6783 | 76915 | 85366 | 90 |
| `backspace_repeat_20` | 81 | 40 | 91 | 4503 | 69098 | 77949 | 123 |
| `paste_fragment_repeat_20` | 20 | 20 | 49 | 116483 | 195100 | 195100 | 135 |

## Interpretation

Ranked finding:

| Rank | Area | Evidence | Interpretation |
|---:|---|---|---|
| 1 | Repeated paste dispatch | `paste_fragment_repeat_20` p50 116483 us, p95/max 195100 us | Matches the visible observation that repeated paste of a word fragment feels slow. |
| 2 | Dispatch-owned repaint/text path | Snapshot p95 stays under 188 us in all scenarios | The hot bucket is before/inside dispatch-owned repaint, not resident Scene snapshot extraction. |
| 3 | Surface crossing volume | Paste uses 49 total surface calls versus 89 for burst typing | Raw `MeasureBatch`/`SubmitPatch` count alone does not explain paste slowness. |
| 4 | Repeat-key rendering | Backspace repeat rows repaint and mutate state; held character rows repaint on character turns | Correctness is present headlessly, but high p95 dispatch spikes can still make visible repeat feel uneven. |

## Paste Attribution

Artifact:
`w009-textbox-paste-dispatch-attribution-20260704.json`

`oxforms-zhz.36` split the repeated paste path into host clipboard, VBA
`SetClipboardText`, inclusive `DispatchKey` Ctrl+V, Rust-side surface crossings,
and snapshot cost. The remaining `DispatchKey minus Rust surface` bucket is
still deliberately combined: current seams do not separate TextBox paste
mutation, event handlers, `UserForm.Render` scene building, and VM/COM
marshalling.

| Bucket | p50 us | p95 us | Interpretation |
|---|---:|---:|---|
| Total paste turn dispatch | 128858 | 204225 | The repeated paste turn is still visibly large. |
| `DispatchKey:keydown:Ctrl+V` inclusive | 128763 | 204129 | Almost all paste cost is inside the Ctrl+V reducer turn. |
| `DispatchKey` minus Rust surface | 94702 | 177450 | Dominant remaining bucket; contains VBA paste mutation/events/render scene-building/VM marshalling. |
| Rust surface crossings | 30032 | 37705 | Real cost, mostly `SubmitPatch`, but not the dominant source. |
| `SubmitPatch` | 29912 | 37443 | Surface implementation cost inside repaint. |
| `MeasureBatch` | 251 | 553 | Text measurement is not the slow paste source in this harness. |
| VBA `SetClipboardText` | 51 | 190 | Clipboard push into the reducer is negligible. |
| HostServices clipboard write | 3 | 8 | Headless host clipboard write is negligible. |
| Resident Scene snapshot | 120 | 322 | Snapshot extraction remains negligible. |

Hypothesis ledger:

| Hypothesis | Verdict | Evidence |
|---|---|---|
| Host clipboard write dominates paste | Rejects | host p95 8 us vs total dispatch p95 204225 us |
| VBA `SetClipboardText` dominates paste | Rejects | `SetClipboardText` p95 190 us vs total dispatch p95 204225 us |
| Rust surface implementation dominates paste | Rejects | surface p95 37705 us vs total dispatch p95 204225 us |
| Remaining Ctrl+V dispatch/VBA render bucket dominates paste | Supports | dispatch-minus-surface p95 177450 us vs total dispatch p95 204225 us |

Next instrumentation should split the remaining Ctrl+V/VBA bucket into TextBox
paste mutation/events versus `UserForm.Render` scene-building/VM marshalling
before any optimization. Do not optimize clipboard or surface policy from these
numbers: both have now been ruled out as the primary repeated-paste source for
this harness.

## TextBox Dispatch/Render Optimization

Artifacts:
`w009-textbox-dispatch-render-optimization-20260707.json`,
`w009-textbox-repeat-paste-optimized-20260707.json`

`oxforms-zhz.37` added profiling-only VBA phase markers for visible/TextBox
turns, then optimized the proven hot path. The two retained changes are:

1. `OxTextService` caches the parsed caret-stop list for the current measured
   run, so TextBox render pays the CSV boundary once per run instead of once per
   caret/selection geometry query.
2. `OxForms.Surface.SubmitPatch` no longer computes a headless framebuffer
   report on the live submit path. Pixel-proof tests now render from the
   retained `Scene` snapshot only when they explicitly need oracle evidence.

Final uninstrumented benchmark:

| Scenario | Dispatch p50 us | Dispatch p95 us | Max us | Snapshot p95 us |
|---|---:|---:|---:|---:|
| `burst_typing_40_chars` | 3553 | 22973 | 44110 | 81 |
| `held_char_repeat_30` | 4229 | 19423 | 22755 | 65 |
| `backspace_repeat_20` | 4208 | 18376 | 19696 | 61 |
| `paste_fragment_repeat_20` | 20896 | 26563 | 26563 | 58 |

Optimized attribution for repeated paste:

| Bucket | p50 us | p95 us | Interpretation |
|---|---:|---:|---|
| Total paste turn dispatch | 28743 | 83687 | Profiling markers add noise; use the uninstrumented benchmark for acceptance. |
| `DispatchKey` minus Rust surface | 27699 | 81692 | Remaining cost is now mostly VBA-side TextBox mutation/render work. |
| Rust surface crossings | 1044 | 1582 | Eager headless report generation is no longer in the submit hot path. |
| `SubmitPatch` | 664 | 1170 | Patch parse/apply is not the current repeated-paste bottleneck. |
| `MeasureBatch` | 185 | 412 | Text measurement remains negligible for this harness. |

Result: the original repeated-paste p95 moved from 195100 us to 26563 us, and
repeat-key repaint scenarios now render during repeat turns within the same
sub-50 ms dispatch budget. Further TextBox performance work should focus on the
remaining VBA-side paint/mutation bucket only after a visible scenario shows a
new problem.

## W009 Ideal Architecture Budget Report

Artifact:
`w009-ideal-architecture-budget-20260707.json`

Generated for `oxforms-zhz.31` with `OXFORMS_PROFILE_TIMINGS=1`. This is a
host-specific headless report over the canonical `OxRuntime` + VBA `OxReducer`
+ `SurfaceFactory` path. It is measurement evidence only; no optimization was
made in this bead.

| Scenario | Rows | Repaints | Surface calls incl. profile marks | Dispatch p50 us | Dispatch p95 us | Max us | Snapshot p95 us |
|---|---:|---:|---:|---:|---:|---:|---:|
| `input_to_state_render_paste` | 8 | 8 | 194 | 19383 | 21234 | 21234 | 76 |
| `burst_typing_40_chars` | 120 | 40 | 770 | 3005 | 19147 | 22053 | 354 |
| `backspace_repeat_20` | 81 | 40 | 743 | 4472 | 20392 | 26481 | 265 |
| `tab_traversal_12` | 24 | 12 | 353 | 16364 | 23172 | 26574 | 180 |
| `mouse_cursor_moves_40` | 41 | 0 | 130 | 15553 | 20767 | 21670 | 149 |
| `spinbutton_auto_repeat_virtual_timer` | 7 | 2 timer fires | n/a | 11104 | 32356 | 32356 | 90 |

Scale/crossing budget:

| Controls | First-paint nodes | First-paint crossings | One-control change crossings | Mouse-move hit-test p95 us |
|---:|---:|---|---|---:|
| 10 | 11 | `BeginScene:4`, `MeasureBatch:1`, `SubmitPatch:1` | `MeasureBatch:1`, `SubmitPatch:1` | 9053 |
| 50 | 51 | `BeginScene:4`, `MeasureBatch:1`, `SubmitPatch:1` | `MeasureBatch:1`, `SubmitPatch:1` | 126007 |
| 100 | 101 | `BeginScene:4`, `MeasureBatch:1`, `SubmitPatch:1` | `MeasureBatch:1`, `SubmitPatch:1` | 432473 |

Ranked findings:

| Rank | Area | Evidence | Interpretation |
|---:|---|---|---|
| 1 | Scaled VBA hit-test mouse move | 100-control p95 `432473 us` | Mouse-move hit testing scales poorly and is the top follow-up target; this feeds `oxforms-bqr`. |
| 2 | Slowest representative dispatch | timer p95 `32356 us` | The broad headless representative set remains under the current sub-50 ms dispatch budget on this host, excluding the scale hit-test probe. |
| 3 | Scale one-control change crossings | `2` crossings at 10/50/100 controls | Incremental render crossing count is independent of control count for the label-scale fixture. |
| 4 | Timer virtual repeat dispatch | timer p95 `32356 us` | Auto-repeat uses the same `OxRuntime` event-turn path; no parallel timer runtime was needed. |

Hypothesis ledger:

| Hypothesis | Verdict | Evidence |
|---|---|---|
| Scene crossing count scales with control count for one-control changes | Rejects | 10/50/100-control change all emit `MeasureBatch:1`, `SubmitPatch:1`. |
| VBA hit-test cost is already settled for broad forms | Supports follow-up | 100-control mouse move p95 is `432473 us`; settle indexed VBA pick vs Rust Scene pick in `oxforms-bqr`. |
| Timer repeat needs a parallel runtime path | Rejects | The timer budget scenario dispatches `auto_repeat` through `OxRuntime`. |
| Further optimization should proceed without scenario-specific evidence | Rejects | This bead records budgets only; optimization requires a ranked follow-up target. |

## Hit-Test Home Settlement

Artifact:
`w009-hittest-home-settlement-20260707.json`

`oxforms-bqr` extends the OxVba hit-test probe with a VBA-owned layout index and
a frame-budget scenario. The benchmark is still ignored/timing-only:

```powershell
$env:OXFORMS_HITTEST_BQR_OUT = "$PWD\docs\evidence\W009_first_class_runtime_foundation\perf\w009-hittest-home-settlement-20260707.json"
cargo test -p oxforms-oxvba-adapter --test oxvba_lex_hittest_bench -- --ignored --nocapture
```

Frame model: 240 raw pointer points/sec, 60 Hz dispatch frame, 4 raw
points/frame. The intended contract is one dispatched move per frame with
intermediate points attached.

| Controls | Linear pick/op us | Indexed pick/op us | Crossing noop/op us | Index build min-of-5 us | Coalesced indexed frame us | Raw 4x indexed frame us | Raw 4x linear frame us |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 50 | 2062 | 69 | 6 | 2541 | 69 | 275 | 8249 |
| 100 | 3693 | 81 | 6 | 4527 | 81 | 324 | 14773 |
| 200 | 10485 | 74 | 6 | 10266 | 74 | 297 | 41942 |
| 400 | 17828 | 96 | 7 | 17520 | 96 | 384 | 71313 |

Decision:

| Question | Answer | Evidence |
|---|---|---|
| Should broad W009 lanes use naïve VBA linear hit-testing? | No. | Linear reaches `17828 us` for one 400-control pick and exceeds the frame budget if raw moves cross individually. |
| Should broad W009 lanes use a VBA-owned indexed pick first? | Yes. | Steady indexed pick stays `69`-`96 us` from 50 to 400 controls, comfortably under a 16.6 ms frame budget. |
| Should Rust Scene picking replace VBA routing now? | No. | The indexed VBA path is fast enough and keeps layout/control semantics owned by VBA; Rust Scene pick remains a fallback if real index invalidation churn misses budget. |
| When is index rebuild acceptable? | Layout/visibility/z-order invalidation only. | Build cost is O(N) and reaches `17520 us` at 400 controls, so it must not run during steady mouse move. |
