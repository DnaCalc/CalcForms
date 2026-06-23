Status: Open
Target: OxVba
Ask: Investigate and fix or document the OxVba package-session gap that prevents a W005 class fixture from raising native FM20-named probe events directly.

Context: `oxforms-xvx.10` wires OxForms reducer `FireVbaEvent` effects into an OxVba smoke using `ProjectRuntimeSession.invoke_member_values -> VBA RaiseEvent -> WithEvents handler`. A generic carrier event named `Dispatched` works and is committed as the W005 subset smoke. During implementation, a fixture class shaped like the intended event source failed before handler dispatch with VBA runtime error 424 `Object required` when invoked through `ProjectRuntimeSession.invoke_member_values`.

Minimal failing shape observed in OxForms:

```vb
Option Explicit

Public Event Click()
Public Event ProbeClick()

Public Sub RaiseClick()
    RaiseEvent ProbeClick
End Sub
```

Invoking `RaiseClick` on a `W005ProbeEventSource` package-session instance produced `PhaseDiagnostic { phase: Runtime, message: "Object required", vba_error_number: Some(424) }`. The same failure happened before any useful handler log for the direct FM20-style event source. OxVba has a passing package-session smoke for a neutral class event (`Public Event Changed(ByVal value As Long)`), so the gap may be tied to this fixture/event shape rather than all project events.

Evidence: OxForms committed the working partial smoke in
`crates/oxforms-oxvba-adapter/tests/oxvba_w005_event_dispatch_smoke.rs` and
`docs/evidence/W005_input_interaction_model_exploration/event-dispatch-smoke.v1.json`.
The workaround deliberately uses one generic carrier event only as test
infrastructure; OxForms should replace it with native form/control event
procedures once OxVba can dispatch the required event shapes. Native FM20
keyboard dispatch must derive `KeyDown`/`KeyUp` `Shift As Integer` from the
reducer's normalized `modifiers` payload at that future boundary; the generic
W005 carrier intentionally preserves normalized keyboard arguments instead of
exposing a partial native signature.
