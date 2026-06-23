# W006 Modeless Lifecycle Close Slice

Status: implemented-subset with shared-runtime blocker.
Bead: `oxforms-0a0.3`
Date: 2026-06-23

## Implemented Subset

`crates/oxforms-core` now models the first modeless close tail through the
shared W005 interaction path:

```text
CloseRequest
  -> reducer close_flow state
  -> FireVbaEvent(QueryClose)
  -> QueryCloseCompleted(cancelled=false)
  -> HideForm
  -> WindowHidden
  -> UnloadForm
  -> Unloaded
```

The close flow is reducer-owned state (`FormState.close_flow`), not adapter
side-channel state. `CloseRequestOrigin::CloseButton` and
`CloseRequestOrigin::SystemMenu` are mapped to `CloseMode=0`, matching the W005
modeless MSForms oracle close-button observation. `Unloaded` records logical
unload completion and returns the form to hidden/unloaded interaction state; it
does not claim object-lifetime `Terminate` parity. Only an explicit
`Terminated` normalized event moves the core state to `terminated`.

`QueryCloseCompleted` is accepted only for the current form while the reducer is
still in the pending query-close state and has an active `close_flow`. Foreign
or stale completions are ignored and cannot authorize `HideForm` or
`UnloadForm`. A cancelled `QueryCloseCompleted` consumes the pending close
authority, records `close_cancelled`, and leaves any later uncancelled stale
completion unable to continue the close tail.

The deterministic headless replay golden now includes a modeless close script
step after the existing probe interactions. It records normalized
`close_request`, `query_close_completed`, `window_hidden`, and `unloaded` rows,
the reducer `close_flow` summaries, `HideForm` and `UnloadForm` effects, and
lifecycle/pump rows for `close_unload_cancellation`.

## Evidence

- W005 modeless Office/MSForms oracle:
  `docs/evidence/W005_input_interaction_model_exploration/captures/interaction-events-20260623T004914Z/modeless-event-log.json`.
- W005 modeless CSV row 1114 observes `QueryClose` with
  `cancel_before=0`, `cancel_after=0`, and `close_mode=0`.
- W005 modeless CSV row 1116 observes a later `Terminate` row for that fixture,
  but this bead does not implement or claim `Terminate` timing parity.
- Updated OxForms headless replay golden:
  `docs/evidence/W005_input_interaction_model_exploration/trace-replay/w005-headless-probe-replay.golden.v1.json`.

## Blocker

Actual `QueryClose` handler execution, cancellation, and scalar ByRef mutation
remain blocked by the shared OxVba native FM20-named event path documented in
`docs/evidence/W006_control_implementation_rollout/native-fm20-event-dispatch-blocker.md`.
The headless replay supplies an uncancelled `QueryCloseCompleted` event with a
blocker diagnostic; it does not execute VBA and is not a production event
runtime.

This bead does not introduce a forms-only event runtime, fake production
`QueryClose` handler, or generic carrier fallback. The W005 `Dispatched`
carrier remains smoke/test infrastructure only.

## Non-claims

- No nested modal forms.
- No `DoEvents`-like yielding.
- No full modal return semantics.
- No object-lifetime `Terminate` parity.
- No broad reentrant dispatch behavior.
