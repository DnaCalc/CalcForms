# W005 Trace Replay Evidence

Status: schema/sample evidence plus headless replay golden for W005.

This directory holds W005 trace/replay artifacts and samples. The curated schema
contract is [`../../../specs/TRACE_REPLAY_SCHEMA.md`](../../../specs/TRACE_REPLAY_SCHEMA.md).

## Current Artifacts

- [`synthetic-click-trace.v1.json`](synthetic-click-trace.v1.json) is a small
  synthetic trace that validates the v1 schema and exercises the required row
  families: normalized input, coordinate tags, reducer transition, effect
  request/completion, VBA dispatch, lifecycle/pump, invalidation, display-list
  reference, render reference, and reentrant nesting.
- [`reducer-skeleton-transition-log.v1.json`](reducer-skeleton-transition-log.v1.json)
  is a synthetic `oxforms-xvx.6` transition log showing the first
  `oxforms-core` reducer/model skeleton's ordered
  focus/capture/effect/invalidation output for a CommandButton-shaped mouse
  down. It consumes the `oxforms-pal` normalized input contract, but the PAL
  does not own or re-export reducer behavior. This is trace-schema integration
  evidence only; it is not a replay-runner golden trace.
- [`w005-headless-probe-replay.golden.v1.json`](w005-headless-probe-replay.golden.v1.json)
  is the deterministic OxForms golden trace created by `oxforms-xvx.12` and
  updated by `oxforms-0a0.1` and `oxforms-0a0.3`. It replays a repo-authored
  script through the W005 headless probe path: show modeless, click the TextBox
  probe, type committed text `AB`, run the `ArrowLeft`, `Delete`, `Home`, `End`,
  and `Backspace` single-line editing keys, click the default `CommandButton`
  probe, and close the modeless form through the first lifecycle close subset.
  The trace records normalized input events, routing decisions, reducer
  transition summaries including TextBox text length plus caret anchor/active
  offsets, close-flow state, effect request/completion rows, VBA dispatch
  metadata reconstructed from `FireVbaEvent` effects, text mutation and
  `text_selection_changed` invalidations, and clean-room/path policy metadata.
  It does not require Excel/MSForms, OxVba execution, or a live desktop. (The
  probe display-list/render rows this golden once carried were dropped in
  oxforms-rq5.1, when the probe display-list renderer was deleted and rendering
  moved to VBA self-render; the separate display-list golden was removed.)
- [`checksums.sha256`](checksums.sha256) records SHA-256 hashes for committed
  trace-replay evidence files in this directory.

`oxforms-xvx.8` extended the reducer test surface, not this historical JSON
sample. Keyboard assertions then in `crates/oxforms-core` covered serialized
`KeyDown`/`KeyUp` effect diagnostics, printable `CharacterInput` TextBox
mutation, `KeyPress`/`Change` effects, Enter default routing, Escape cancel
routing, and `Alt+Character` caption accelerators. (Historical: `oxforms-core`
was later deleted; the equivalent coverage now lives in the adapter's VBA-reducer
tests under `crates/oxforms-oxvba-adapter/tests/`.) The full replay-runner
golden trace remained scoped to `oxforms-xvx.12`.

`oxforms-xvx.9` also extended the reducer test surface rather than this
historical JSON sample. Probe assertions then in `crates/oxforms-core` covered
Label mouse click routing, TextBox focus and committed character input,
CommandButton activation, render invalidation, a serializable core-owned probe
display reference with text/focus/caret placeholders, and a PAL `FillRect`
smoke projection. (Historical: see the note above — that coverage now lives in
the adapter's VBA-reducer tests.) The full replay-runner golden trace remained
scoped to `oxforms-xvx.12`.

`oxforms-0a0.1` intentionally updates the replay-runner golden for the first
reviewable TextBox editing slice. The evidence covers committed single-line
text, caret movement, collapsed or Shift-extended anchor/active selection
state, Backspace/Delete deletion, and `Change` rows for actual text mutation.
It remains non-oracle OxForms regression evidence, not live MSForms parity
evidence. Multiline, password mode, scrolling, IME/composition, dead keys,
clipboard, paste/DataObject, drag/drop, full validation ordering, full
selection UI parity, and native FM20-named event dispatch remain non-claims.

`oxforms-0a0.3` intentionally updates the replay-runner golden for the first
modeless lifecycle close subset. The evidence covers normalized
`CloseRequest`, `FireVbaEvent(QueryClose)` request metadata, replayed
`QueryCloseCompleted(cancelled=false)` with `CloseMode=0`, `HideForm`,
`WindowHidden`, `UnloadForm`, and `Unloaded` rows/effects for the W005 modeless
fixture scenario. It is grounded in the W005 modeless Office/MSForms oracle row
that observed `QueryClose` with `cancel_before=0`, `cancel_after=0`, and
`close_mode=0`, but it remains OxForms regression evidence. Actual
`QueryClose` handler execution and cancellation are blocked by
`docs/evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md`.
Object-lifetime `Terminate`, nested modal forms, `DoEvents`-like yielding, full
modal return semantics, and broad reentrant dispatch remain non-claims.

The synthetic samples are not Office/MSForms oracle evidence and are not
OxForms runtime traces. The headless replay golden is OxForms regression
evidence for the implemented W005 subset only; it is not an MSForms parity
claim and does not define global comparison tolerances.

## Validation

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\trace-replay\Test-TraceReplaySchema.ps1
```

The validator checks the committed schema and sample for required sections,
logical ordering, coordinate-space tags, effect and VBA-dispatch causality,
existing repo-relative artifact paths when a path is present, explicit clean-room
notes, and absence of machine-local absolute paths in the canonical sample.

Validate the `oxforms-xvx.12` golden trace:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\trace-replay\Test-TraceReplaySchema.ps1 -TracePath docs\evidence\W005_input_interaction_model_exploration\trace-replay\w005-headless-probe-replay.golden.v1.json
```

These goldens are now FROZEN artifacts. The `oxforms-core` crate (and its
`w005_trace_replay` example/test) that once regenerated and re-checked them was
deleted when control behavior moved into VBA (the `vba/oxforms/OxReducer.cls`
reducer driven by the thin `OxRuntime` in
`crates/oxforms-oxvba-adapter/src/runtime.rs`); the historical Rust runner no
longer exists. The committed JSON is validated only by the PowerShell schema
validator above. Live interaction coverage now lives in the adapter's reducer
tests (`crates/oxforms-oxvba-adapter/tests/oxvba_reducer_cmdbutton.rs` and
`oxvba_runtime_greeter.rs`).

Validate the committed checksum file from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\evidence\Test-ChecksumManifest.ps1 -Directory docs\evidence\W005_input_interaction_model_exploration\trace-replay -GitTrackedOnly
```

Checksum entries are relative to this directory and use forward slashes for
nested paths.
