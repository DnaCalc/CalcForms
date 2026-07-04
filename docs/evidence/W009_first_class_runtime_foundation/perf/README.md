# W009 TextBox Repeat/Paste Responsiveness Baseline

Bead: `oxforms-aghp`

This directory records a host-specific baseline for TextBox repeat and repeated
paste behavior after the visible W009 TextBox smoke proved that both the
showcase and materialized `.frm` routes are live.

Generate the JSON report with:

```powershell
$env:OXFORMS_TEXTBOX_PERF_OUT = "$PWD\docs\evidence\W009_first_class_runtime_foundation\perf\w009-textbox-repeat-paste-baseline-20260704.json"
cargo test -p oxforms-headless-runner --test headless_textbox_perf -- --ignored --nocapture
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

Next instrumentation should split the paste dispatch bucket into
`SetClipboardText`, `DispatchKey`, TextBox paste mutation/event handlers,
`UserForm.Render`, and surface measurement/submission. Do not optimize clipboard
or rendering policy until that split is available.
