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
