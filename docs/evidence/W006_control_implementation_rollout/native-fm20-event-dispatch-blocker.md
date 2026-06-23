# W006 Native FM20 Event Dispatch Blocker

Status: `resolved` (see Resolution below; superseded by `oxforms-4pn.2`)
Bead: `oxforms-0a0.2`
Date: 2026-06-23

## Outcome

OxForms did not replace the W005 generic `Dispatched` carrier with native
FM20-named VBA handlers in this bead. A small scalar subset was attempted first:

- `MouseDown(Button As Integer, Shift As Integer, X As Single, Y As Single)`;
- `MouseUp(Button As Integer, Shift As Integer, X As Single, Y As Single)`;
- `MouseMove(Button As Integer, Shift As Integer, X As Single, Y As Single)`;
- `Click()`.

The implementation was reverted because the OxVba package-session path faults
before native `WithEvents` handler dispatch for FM20-named events. No forms-only
event runtime, fallback shim, or compatibility shortcut was introduced.

## Attempted Shape

The temporary source fixture used the shared OxVba project event path:

```vb
Option Explicit

Public Event MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseUp(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
Public Event MouseMove(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)

Public Sub RaiseMouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    RaiseEvent MouseDown(Button, Shift, X, Y)
End Sub
```

The temporary sink attached through ordinary `WithEvents`:

```vb
Private WithEvents EventSource As W006NativeFm20EventSource

Private Sub EventSource_MouseDown(ByVal Button As Integer, ByVal Shift As Integer, ByVal X As Single, ByVal Y As Single)
    ' log handler entry
End Sub
```

Rust invoked the source through:

```text
ProjectRuntimeSession.invoke_member_values(source, "RaiseMouseDown", Method, ...)
```

## Observed Failures

Targeted command:

```powershell
cargo test -p oxforms-oxvba-adapter --test oxvba_w005_event_dispatch_smoke -- --nocapture
```

Observed failure with `Click`, mouse events, and an attached `WithEvents` sink:

```text
raise MouseDown for UiEventTarget { form_id: Some(FormId("form-main")), window_id: None, control_id: Some(ControlId("label")) }: Object required
```

Diagnostic refinements:

- Removing the `Click` event and leaving only native-named mouse events still
  faulted with `Object required` when the sink was attached.
- Running the same `RaiseMouseDown` source method without attaching the sink did
  not fault, but no handler could be invoked. This localizes the failure to
  attached native-named `WithEvents` routing rather than the source method alone.
- Widening the temporary event and handler signature to
  `Long, Long, Double, Double` still faulted with the sink attached, so the
  blocker is not just Rust passing `Integer`/`Single` variants.

The previously committed W005 generic carrier smoke still passes and remains
test-only evidence that OxVba can dispatch through `RaiseEvent`/`WithEvents`
for a neutral carrier event. It is not an OxForms runtime event path.

## Blocker

OxForms needs an OxVba-owned shared event-dispatch hook that can invoke native
FM20-named handler procedures for package-session objects without a generic
carrier event. The minimum unblocker is:

1. A source class can declare and raise `MouseDown`, `MouseUp`, `MouseMove`, and
   `Click` events through `ProjectRuntimeSession.invoke_member_values`.
2. A sink class with `Private WithEvents EventSource As <source>` and handlers
   named `EventSource_MouseDown`, `EventSource_MouseUp`, `EventSource_MouseMove`,
   and `EventSource_Click` receives those events.
3. Scalar argument order and values are preserved as recorded in
   `docs/specs/FM20_EVENT_FACTS.md`.
4. Later keyboard, validation, drag/drop, and lifecycle work can also preserve
   `MSForms.Return*` helper-object mutation and scalar cancellation semantics
   without OxForms inventing a private event runtime.

Until that shared OxVba support exists, `crates/oxforms-oxvba-adapter` must keep
the W005 `Dispatched` carrier quarantined as smoke/test infrastructure only.

## Resolution (2026-06-23, `oxforms-4pn.2`)

OxVba landed package-session native-event regressions at `366896f7a081ddb459307d5be7d9e829ca391a0a`
and reported that the error 424 did not reproduce from the minimized shape (even
on the prior `501bf64` baseline). OxForms bumped the pinned baseline to `366896f`
(`oxforms-k1t`) and reconstructed the exact reverted subset above as a committed
gate test:

- fixtures `vba/smoke/fixtures/w006_native_fm20_event_source.cls` and
  `w006_native_fm20_event_sink.cls`;
- test `crates/oxforms-oxvba-adapter/tests/oxvba_w006_native_fm20_event_gate.rs`.

`Click`, `MouseDown`, `MouseUp`, and `MouseMove` now dispatch to the attached
`Private WithEvents` handlers in order, with correct `Integer`/`Single` scalar
args, through `ProjectRuntimeSession.invoke_member_values` — no generic carrier.
The original 424 was therefore either a baseline issue since resolved or an
artifact of the original uncommitted attempt; it is not a current OxVba gap.

This unblocks the W007 runtime path. The remaining native surface (`Change` for
TextBox, keyboard events, and `MSForms.Return*` ByRef helper-mutation semantics)
is ordinary W007 implementation work (`oxforms-4pn.3`+), not a dispatch blocker.
The W005 generic `Dispatched` carrier stays test-only and should be retired from
the runtime path as those native signatures are implemented.
